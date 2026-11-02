"""Task 1: OFTNet fp32 reference and int8 fake-quantization analysis.
Measures activation ranges, builds qstats, and evaluates PSNR / EPE / mask L1.
"""
import os, sys, json, math
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet, ResC, OFTBlk
from model_v2 import warp, resize_flow

def quant_sym(x, scale, qmin=-127, qmax=127):
    """Symmetric quantization to integer code and dequantization."""
    q = torch.clamp(torch.round(x / scale), qmin, qmax)
    return q * scale

class StatCollector:
    def __init__(self):
        self.stats = {}

    def observe(self, name, x):
        if not isinstance(x, torch.Tensor):
            return
        ax = x.detach().abs().float()
        m = float(ax.max())
                                                                                         
        flat = ax.view(-1)
        if flat.numel() > 100000:
            step = flat.numel() // 50000
            sub = flat[::step]
            q9999 = float(torch.quantile(sub, 0.9999))
        elif flat.numel() > 1000:
            q9999 = float(torch.quantile(flat, 0.9999))
        else:
            q9999 = m
        cur = self.stats.get(name, {"max": 0.0, "q9999": 0.0, "count": 0})
        cur["max"] = max(cur["max"], m)
        cur["q9999"] = max(cur["q9999"], q9999)
        cur["count"] += 1
        self.stats[name] = cur

def build_fake_quant_oft(net, stats):
    """Create a forward hook or wrapper that fake-quantizes activations and weights."""
                                                    
    wq = {}
    for name, m in net.named_modules():
        if isinstance(m, nn.Conv2d):
            w = m.weight.detach()
            w_max = w.abs().amax(dim=(1, 2, 3), keepdim=True).clamp(min=1e-8)
            scale = w_max / 127.0
            w_quant = torch.clamp(torch.round(w / scale), -127, 127) * scale
            wq[name] = (scale, w_quant)
    return wq

def run_forward_with_collect(net, t, color_a, color_b, of_ab, of_ba, collector):
    """Run OFTNet while collecting activation statistics."""
    n, _, H, W = color_a.shape
    tt = t.view(n, 1, 1, 1)
    fab, fba = resize_flow(of_ab, H, W), resize_flow(of_ba, H, W)
    f_ta = -(1 - tt) * tt * fab + tt * tt * fba
    f_tb = (1 - tt) ** 2 * fab - tt * (1 - tt) * fba
    mask = torch.zeros(n, 1, H, W, device=color_a.device, dtype=color_a.dtype)

    collector.observe("init.f_ta", f_ta)
    collector.observe("init.f_tb", f_tb)

    for bi, (blk, s) in enumerate(zip(net.blocks, net.SCALES)):
        prefix = f"b{bi}_s{s}"
        h, w = H // s, W // s
        a_s = color_a if s == 1 else F.interpolate(color_a, size=(h, w), mode="area")
        b_s = color_b if s == 1 else F.interpolate(color_b, size=(h, w), mode="area")
        fa_s = f_ta if s == 1 else resize_flow(f_ta, h, w)
        fb_s = f_tb if s == 1 else resize_flow(f_tb, h, w)
        m_s = mask if s == 1 else F.interpolate(mask, size=(h, w), mode="area")
        wa, wb = warp(a_s, fa_s), warp(b_s, fb_s)
        diff = (wa - wb).abs().mean(1, keepdim=True) * 4.0
        
        collector.observe(f"{prefix}.wa", wa)
        collector.observe(f"{prefix}.wb", wb)
        collector.observe(f"{prefix}.diff", diff)
        collector.observe(f"{prefix}.fa_s_16", fa_s / 16.0)
        collector.observe(f"{prefix}.fb_s_16", fb_s / 16.0)
        collector.observe(f"{prefix}.m_s_4", m_s / 4.0)

        x = torch.cat((wa, wb, diff, fa_s / 16.0, fb_s / 16.0, m_s / 4.0, tt.expand(n, 1, h, w)), 1)
        collector.observe(f"{prefix}.x_in", x)

            
        y1 = F.leaky_relu(blk.d1(x), 0.1)
        collector.observe(f"{prefix}.d1_out", y1)

            
        y2 = F.leaky_relu(blk.d2(y1), 0.1)
        collector.observe(f"{prefix}.d2_out", y2)

              
        cur = y2
        for ri, resc in enumerate(blk.body):
            r_prefix = f"{prefix}.body_{ri}"
            act_a = F.leaky_relu(resc.a(cur), 0.1)
            collector.observe(f"{r_prefix}.a_out", act_a)
            out_b = resc.b(act_a)
            collector.observe(f"{r_prefix}.b_out", out_b)
            cur = cur + out_b
            collector.observe(f"{r_prefix}.res_add", cur)

        y_body = F.leaky_relu(cur, 0.1)
        collector.observe(f"{prefix}.body_out", y_body)

             
        out80 = blk.out(y_body)
        collector.observe(f"{prefix}.out80", out80)
        d = F.pixel_shuffle(out80, 4)
        collector.observe(f"{prefix}.d_ps", d)

        if s == 1:
            f_ta = f_ta + d[:, 0:2]
            f_tb = f_tb + d[:, 2:4]
            mask = mask + d[:, 4:5]
        else:
            f_ta = f_ta + resize_flow(d[:, 0:2], H, W)
            f_tb = f_tb + resize_flow(d[:, 2:4], H, W)
            mask = mask + F.interpolate(d[:, 4:5], size=(H, W), mode="bilinear", align_corners=False)

        collector.observe(f"{prefix}.cum_f_ta", f_ta)
        collector.observe(f"{prefix}.cum_f_tb", f_tb)
        collector.observe(f"{prefix}.cum_mask", mask)

    v = torch.sigmoid(mask)
    collector.observe("final.v", v)
    wa, wb = warp(color_a, f_ta), warp(color_b, f_tb)
    color = (v * wa + (1 - v) * wb).clamp(0, 1)
    collector.observe("final.color", color)

    return {"color": color, "f_ta": f_ta, "f_tb": f_tb, "vis": v, "mask": mask}

def run_fake_quant_forward(net, t, color_a, color_b, of_ab, of_ba, qscales, wq):
    """Run OFTNet with simulated W8A8 fake-quantization."""
    n, _, H, W = color_a.shape
    tt = t.view(n, 1, 1, 1)
    fab, fba = resize_flow(of_ab, H, W), resize_flow(of_ba, H, W)
    f_ta = -(1 - tt) * tt * fab + tt * tt * fba
    f_tb = (1 - tt) ** 2 * fab - tt * (1 - tt) * fba
    mask = torch.zeros(n, 1, H, W, device=color_a.device, dtype=color_a.dtype)

    def conv_fq(layer_name, x, conv_module):
                                                
        w_scale, w_q = wq[layer_name]
        return F.conv2d(x, w_q, conv_module.bias, conv_module.stride, conv_module.padding, conv_module.dilation)

    for bi, (blk, s) in enumerate(zip(net.blocks, net.SCALES)):
        prefix = f"b{bi}_s{s}"
        h, w = H // s, W // s
        a_s = color_a if s == 1 else F.interpolate(color_a, size=(h, w), mode="area")
        b_s = color_b if s == 1 else F.interpolate(color_b, size=(h, w), mode="area")
        fa_s = f_ta if s == 1 else resize_flow(f_ta, h, w)
        fb_s = f_tb if s == 1 else resize_flow(f_tb, h, w)
        m_s = mask if s == 1 else F.interpolate(mask, size=(h, w), mode="area")
        wa, wb = warp(a_s, fa_s), warp(b_s, fb_s)
        diff = (wa - wb).abs().mean(1, keepdim=True) * 4.0

        x = torch.cat((wa, wb, diff, fa_s / 16.0, fb_s / 16.0, m_s / 4.0, tt.expand(n, 1, h, w)), 1)
                           
        x_q = quant_sym(x, qscales[f"{prefix}.x_in"])

                               
        y1 = F.leaky_relu(conv_fq(f"blocks.{bi}.d1", x_q, blk.d1), 0.1)
        y1_q = quant_sym(y1, qscales[f"{prefix}.d1_out"])

                               
        y2 = F.leaky_relu(conv_fq(f"blocks.{bi}.d2", y1_q, blk.d2), 0.1)
        y2_q = quant_sym(y2, qscales[f"{prefix}.d2_out"])

                      
        cur_q = y2_q
        for ri, resc in enumerate(blk.body):
            r_prefix = f"{prefix}.body_{ri}"
                               
            ya = F.leaky_relu(conv_fq(f"blocks.{bi}.body.{ri}.a", cur_q, resc.a), 0.1)
            ya_q = quant_sym(ya, qscales[f"{r_prefix}.a_out"])

                                     
            yb = conv_fq(f"blocks.{bi}.body.{ri}.b", ya_q, resc.b)
                               
            cur = cur_q + yb
            cur_q = quant_sym(cur, qscales[f"{r_prefix}.res_add"])

                                           
        y_body = F.leaky_relu(cur_q, 0.1)
        y_body_q = quant_sym(y_body, qscales[f"{prefix}.body_out"])

                          
        out80 = conv_fq(f"blocks.{bi}.out", y_body_q, blk.out)
                                                                     
        d = F.pixel_shuffle(out80, 4)

        if s == 1:
            f_ta = f_ta + d[:, 0:2]
            f_tb = f_tb + d[:, 2:4]
            mask = mask + d[:, 4:5]
        else:
            f_ta = f_ta + resize_flow(d[:, 0:2], H, W)
            f_tb = f_tb + resize_flow(d[:, 2:4], H, W)
            mask = mask + F.interpolate(d[:, 4:5], size=(H, W), mode="bilinear", align_corners=False)

    v = torch.sigmoid(mask)
    wa, wb = warp(color_a, f_ta), warp(color_b, f_tb)
    color = (v * wa + (1 - v) * wb).clamp(0, 1)

    return {"color": color, "f_ta": f_ta, "f_tb": f_tb, "vis": v, "mask": mask}

def main():
    device = "cpu"
    print("Loading OFTNet checkpoint...")
    net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(device)
    sd = torch.load("/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt", map_location=device)
    net.load_state_dict(sd)
    net.eval()

                                                                                
    of_ckpt_path = "/home/sh/mlof2_runs/v2_of_menc/s1500.pt"
    m_of = None
    if os.path.isfile(of_ckpt_path):
        from model_v2 import build_mlof2
        m_sd = torch.load(of_ckpt_path, map_location=device)
        m_of = build_mlof2(m_sd).to(device).eval()
        m_of.load_state_dict(m_sd.get("model", m_sd))
        m_of.pair.seeded = False
        print(f"Loaded frozen OF model from {of_ckpt_path}")

                                              
                            
    test_samples = []
    d0_path = "/mnt/e/nss_VK/NSS/harness/nfru/dataset_0000"
    if os.path.isdir(d0_path):
        def load_color(fn):
            raw = np.fromfile(fn, dtype=np.uint8)
                                                 
            img = raw.reshape((1080, 1920, 4))[:, :, :3].astype(np.float32) / 255.0
            t = torch.from_numpy(img).permute(2, 0, 1).unsqueeze(0)
            return F.pad(t, (0, 0, 0, 8), mode="replicate")
        c0 = load_color(os.path.join(d0_path, "color_000.bin"))
        c1 = load_color(os.path.join(d0_path, "color_001.bin"))
        c2 = load_color(os.path.join(d0_path, "color_002.bin"))
        c3 = load_color(os.path.join(d0_path, "color_003.bin"))
                                  
        test_samples.append(("d0000_pair02_t05", torch.tensor([0.5]), c0, c2))
        test_samples.append(("d0000_pair02_t025", torch.tensor([0.25]), c0, c2))
        test_samples.append(("d0000_pair02_t075", torch.tensor([0.75]), c0, c2))
        test_samples.append(("d0000_pair13_t05", torch.tensor([0.5]), c1, c3))

                                       
    spring_path = "/home/sh/spring_mlof/validation/SP_0045/crop_00.safetensors"
    if not os.path.exists(spring_path):
        spring_path = "/home/sh/spring_mlof/validation/SP_0045/crop_01.safetensors"
    if os.path.isfile(spring_path):
        from safetensors import safe_open
        s = safe_open(spring_path, "pt")
        gt = s.get_slice("ground_truth_srgb8")
        ca = (gt[0:1].float() / 255.0)
        cb = (gt[4:5].float() / 255.0)
        H, W = ca.shape[-2:]
        PH = (H + 63) // 64 * 64
        PW = (W + 63) // 64 * 64
        ca = F.pad(ca, (0, PW - W, 0, PH - H), mode="replicate")
        cb = F.pad(cb, (0, PW - W, 0, PH - H), mode="replicate")
        test_samples.append(("spring_SP0045_t05", torch.tensor([0.5]), ca, cb))
        test_samples.append(("spring_SP0045_t025", torch.tensor([0.25]), ca, cb))

    print(f"Total test samples: {len(test_samples)}")

    cache_path = "/mnt/e/nss_VK/NSS/mlof2/cache_oft_samples.pt"
    if os.path.exists(cache_path):
        print(f"Loading cached sample data from {cache_path}...")
        sample_data = torch.load(cache_path, map_location="cpu")
    else:
                                          
        sample_data = []
        for name, t_val, ca, cb in test_samples:
            print(f"Computing OF for {name}...")
            H, W = ca.shape[-2:]
            if m_of is not None:
                h2, w2 = H // 2, W // 2
                ph, pw = (64 - h2 % 64) % 64, (64 - w2 % 64) % 64
                dn = lambda x: F.pad(F.avg_pool2d(x, 2), (0, pw, 0, ph), mode="replicate")
                with torch.no_grad():
                    dummy_d = torch.full_like(ca[:, :1], 0.5)
                    fa, fb = m_of.enc(dn(ca), dn(dummy_d)), m_of.enc(dn(cb), dn(dummy_d))
                    dummy_mv = torch.zeros(1, 2, dn(ca).shape[-2], dn(ca).shape[-1])
                    dummy_mvv = torch.zeros(1, 1, dn(ca).shape[-2], dn(ca).shape[-1])
                    p = m_of.pair(fa, fb, dummy_mv, dummy_mvv, dn(ca), dn(cb))
                    of_ab = p["of_ab"][..., :h2 // 4, :w2 // 4]
                    of_ba = p["of_ba"][..., :h2 // 4, :w2 // 4]
            else:
                of_ab = torch.zeros(1, 2, H // 8, W // 8)
                of_ba = torch.zeros(1, 2, H // 8, W // 8)
            sample_data.append((name, t_val, ca, cb, of_ab, of_ba))
        torch.save(sample_data, cache_path)
        print(f"Saved cached sample data to {cache_path}")

    collector = StatCollector()
    for name, t_val, ca, cb, of_ab, of_ba in sample_data:
                       
        with torch.no_grad():
            fp32_out = run_forward_with_collect(net, t_val, ca, cb, of_ab, of_ba, collector)

    print("\n--- Activation Statistics (max and 99.99% quantile) ---")
    qstats = {}
    for k, v in sorted(collector.stats.items()):
                                     
        stat_val = max(v["q9999"], 1e-4)
        qstats[k] = stat_val
        print(f"  {k:30s}: max={v['max']:8.4f}, q9999={v['q9999']:8.4f} -> stat={stat_val:8.4f}")

                             
    qscales = {k: v / 127.0 for k, v in qstats.items()}
    wq = build_fake_quant_oft(net, qstats)

                 
    os.makedirs("/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8", exist_ok=True)
    qstats_path = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/qstats_oft_int8.json"
    with open(qstats_path, "w") as f:
        json.dump(qstats, f, indent=2)
    print(f"\nSaved qstats to {qstats_path}")

                                                                   
    print("\n--- FP32 vs W8A8 Fake-Quant Evaluation ---")
    psnr_list, epe_list, mask_l1_list = [], [], []

    for name, t_val, ca, cb, of_ab, of_ba in sample_data:
        with torch.no_grad():
            fp_out = run_forward_with_collect(net, t_val, ca, cb, of_ab, of_ba, StatCollector())
            fq_out = run_fake_quant_forward(net, t_val, ca, cb, of_ab, of_ba, qscales, wq)

            mse = ((fp_out["color"] - fq_out["color"]) ** 2).mean().item()
            psnr = -10.0 * math.log10(max(mse, 1e-10))
            
                                           
            flow_err_a = (fp_out["f_ta"] - fq_out["f_ta"]).norm(dim=1).view(-1)
            flow_err_b = (fp_out["f_tb"] - fq_out["f_tb"]).norm(dim=1).view(-1)
            flow_epe_med = float(torch.median(torch.cat([flow_err_a, flow_err_b])))
            flow_epe_mean = float(0.5 * (flow_err_a.mean() + flow_err_b.mean()))

                     
            mask_l1 = float((fp_out["mask"] - fq_out["mask"]).abs().mean())

            psnr_list.append(psnr)
            epe_list.append(flow_epe_med)
            mask_l1_list.append(mask_l1)

            print(f"[{name}] PSNR: {psnr:.2f} dB | Flow EPE med: {flow_epe_med:.4f} px (mean {flow_epe_mean:.4f}) | Mask L1: {mask_l1:.5f}")

    avg_psnr = sum(psnr_list) / len(psnr_list)
    avg_epe = sum(epe_list) / len(epe_list)
    avg_mask_l1 = sum(mask_l1_list) / len(mask_l1_list)
    print(f"\n=== Overall Average ===")
    print(f"Color PSNR:   {avg_psnr:.2f} dB (Target: >= 45.0 dB)")
    print(f"Flow EPE med: {avg_epe:.4f} px (Target: <= 0.1 px)")
    print(f"Mask L1:      {avg_mask_l1:.5f} (Target: <= 0.01)")

if __name__ == "__main__":
    main()
