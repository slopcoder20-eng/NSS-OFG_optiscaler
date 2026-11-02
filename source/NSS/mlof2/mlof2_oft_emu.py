"""Engine emulator for OFTNet (Contract v2 W8A8).
Executes mlof2_oft.json + mlof2_oft.bin on a byte arena and verifies op-level accuracy.
"""
import sys, os, json, struct, math
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import resize_flow, warp
from lk_refine import lk_step, luma

DT = {0: torch.float32, 1: torch.float16, 2: torch.int8, 3: torch.float8_e4m3fn}
ESZ = {0: 4, 1: 2, 2: 1, 3: 1}

class OFTEmu:
    def __init__(self, out_dir, H=1088, W=1920, device="cpu"):
        self.H, self.W = H, W
        self.dev = device
        self.unit = H * W // 4096
        with open(os.path.join(out_dir, "mlof2_oft.json")) as f:
            self.j = json.load(f)
        self.blob = np.fromfile(os.path.join(out_dir, "mlof2_oft.bin"), dtype=np.uint32)
        self.T = self.j["tensors"]
        self.arena = torch.full((self.j["arena_units"] * 16 * self.unit,), 255, dtype=torch.uint8, device=device)

    def raw(self, t):
        d = self.T[t]
        h, w = self.H // d["s"], self.W // d["s"]
        o = d["off_units"] * 16 * self.unit
        nb = d["n"] * h * w * d["c_alloc"] * ESZ[d["fmt"]]
        return self.arena[o:o + nb].view(DT[d["fmt"]]).view(d["n"], h, w, d["c_alloc"])

    def decode(self, t, r):
        d = self.T[t]
        return r.float() * d["scale"] if d["fmt"] >= 2 else r.float()

    def encode(self, t, x):
        d = self.T[t]
        if d["fmt"] == 2:
            return torch.clamp(torch.round(x / d["scale"]), -127, 127).to(torch.int8)
        return x.to(DT[d["fmt"]])

    def view(self, t):
        d = self.T[t]
        return self.decode(t, self.raw(t)[..., :d["c"]])

    def put(self, t, c0, y):
        d = self.T[t]
        r = self.raw(t)
        r[..., c0:c0 + y.shape[-1]] = self.encode(t, y)
        if c0 + y.shape[-1] == d["c"] and d["c_alloc"] > d["c"]:
            r[..., d["c"]:] = torch.zeros((), dtype=torch.float32, device=r.device).to(r.dtype)

    def read_tensor(self, t_idx):
                                    
        return self.view(t_idx).permute(0, 3, 1, 2)

    def write_tensor(self, t_idx, y):
                           
        self.put(t_idx, 0, y.permute(0, 2, 3, 1))

    def run_conv(self, op):
                                      
        oc = op["out_c"]
        kh, kw, stride, pad, dil, act, res_t, res_c = op["ip"]
        w_off = op["w_off"]
        kw_words = op["kw_words"]
        scale_off = op["scale_off"]
        bias_off = op["bias_off"]

                               
        sc = torch.from_numpy(self.blob[scale_off:scale_off + oc].view(np.float32)).to(self.dev).view(1, oc, 1, 1)
        b = torch.from_numpy(self.blob[bias_off:bias_off + oc].view(np.float32)).to(self.dev)

                                                          
        w_words = self.blob[w_off:w_off + oc * kw_words]
        w_u8 = torch.from_numpy(w_words.view(np.uint8)).view(oc, kh, kw, -1).permute(0, 3, 1, 2).to(self.dev)
        w_i8 = w_u8.to(torch.int8).float()

                             
        inp_parts = []
        for si in range(op["seg0"], op["seg0"] + op["nseg"]):
            t, c0, c, sw = self.j["segs"][si]
            x = self.view(t)[..., c0:c0 + c].permute(0, 3, 1, 2)
            inp_parts.append(x)
        x = torch.cat(inp_parts, dim=1)
                                                       
        ic = x.shape[1]
        if ic < w_i8.shape[1]:
            x = torch.cat([x, torch.zeros(x.shape[0], w_i8.shape[1] - ic, x.shape[2], x.shape[3], device=self.dev)], dim=1)

                                                          
        in_inv_scale = op["fp"][0]
        xq = torch.clamp(torch.round(x * in_inv_scale), -127, 127)
        acc = F.conv2d(xq, w_i8, None, stride=stride, padding=pad, dilation=dil)
        y = acc * sc + b.view(1, -1, 1, 1)

                           
        if res_t >= 0:
            res_val = self.read_tensor(res_t)
            if res_c < 0:                         
                y = y + res_val
                y = F.leaky_relu(y, 0.1) if act == 1 else (F.relu(y) if act == 2 else y)
            else:                        
                y = F.leaky_relu(y, 0.1) if act == 1 else (F.relu(y) if act == 2 else y)
                y = y + res_val
        else:
            y = F.leaky_relu(y, 0.1) if act == 1 else (F.relu(y) if act == 2 else y)

        self.put(op["out"], op["out_coff"], y.permute(0, 2, 3, 1))

    def execute(self, t_val, color_a, color_b, of_ab, of_ba):
                    
        self.write_tensor(0, color_a)
        self.write_tensor(1, color_b)
        self.write_tensor(2, of_ab)
        self.write_tensor(3, of_ba)

                     
        for i, op in enumerate(self.j["ops"]):
            k = op["kind"]
            kind_str = op.get("name", "")
            if not kind_str:
                from export_oft_engine import KIND_NAME_MAP
                kind_str = KIND_NAME_MAP.get(k, "unknown")

            if kind_str == "resize_area":
                si = op["seg0"]
                t, c0, c, _ = self.j["segs"][si]
                x = self.view(t)[..., c0:c0 + c].permute(0, 3, 1, 2)
                s_out = op["ip"][0]
                h_out, w_out = self.H // s_out, self.W // s_out
                y = F.interpolate(x, size=(h_out, w_out), mode="area")
                self.put(op["out"], op["out_coff"], y.permute(0, 2, 3, 1))

            elif kind_str == "resize_bil":
                si = op["seg0"]
                t, c0, c, _ = self.j["segs"][si]
                x = self.view(t)[..., c0:c0 + c].permute(0, 3, 1, 2)
                s_out = op["ip"][0]
                h_out, w_out = self.H // s_out, self.W // s_out
                mul = op["fp"][:2]
                y = F.interpolate(x, size=(h_out, w_out), mode="bilinear", align_corners=False)
                y[:, 0:1] = y[:, 0:1] * mul[0]
                y[:, 1:2] = y[:, 1:2] * mul[1]
                self.put(op["out"], op["out_coff"], y.permute(0, 2, 3, 1))

            elif kind_str == "oft_init":
                fab = self.read_tensor(self.j["segs"][op["seg0"]][0])
                fba = self.read_tensor(self.j["segs"][op["seg0"] + 1][0])
                tt = float(t_val)
                f_ta = -(1.0 - tt) * tt * fab + (tt ** 2) * fba
                f_tb = ((1.0 - tt) ** 2) * fab - tt * (1.0 - tt) * fba
                mask = torch.zeros(1, 1, fab.shape[2], fab.shape[3], device=self.dev)
                self.write_tensor(op["out"], f_ta)
                self.write_tensor(op["ip"][0], f_tb)
                self.write_tensor(op["ip"][1], mask)

            elif kind_str == "oft_prep":
                                                   
                segs = [self.j["segs"][op["seg0"] + j] for j in range(5)]
                a_s = self.read_tensor(segs[0][0])[:, :3]
                b_s = self.read_tensor(segs[1][0])[:, :3]
                fa_s = self.read_tensor(segs[2][0])
                fb_s = self.read_tensor(segs[3][0])
                m_s = self.read_tensor(segs[4][0])

                wa = warp(a_s, fa_s)
                wb = warp(b_s, fb_s)
                diff = (wa - wb).abs().mean(1, keepdim=True) * 4.0
                tt = torch.full_like(diff, float(t_val))
                pad3 = torch.zeros(1, 3, a_s.shape[2], a_s.shape[3], device=self.dev)
                                  
                x16 = torch.cat([wa, wb, diff, fa_s / 16.0, fb_s / 16.0, m_s / 4.0, tt, pad3], dim=1)
                self.write_tensor(op["out"], x16)

            elif kind_str == "conv":
                self.run_conv(op)

            elif kind_str == "oft_out":
                out80 = self.read_tensor(self.j["segs"][op["seg0"]][0])
                fa_prev = self.read_tensor(self.j["segs"][op["seg0"] + 1][0])
                fb_prev = self.read_tensor(self.j["segs"][op["seg0"] + 2][0])
                m_prev = self.read_tensor(self.j["segs"][op["seg0"] + 3][0])

                d = F.pixel_shuffle(out80, 4)
                fa_acc = fa_prev + d[:, 0:2]
                fb_acc = fb_prev + d[:, 2:4]
                m_acc = m_prev + d[:, 4:5]

                self.write_tensor(op["out"], fa_acc)
                self.write_tensor(op["ip"][0], fb_acc)
                self.write_tensor(op["ip"][1], m_acc)

            elif kind_str == "oft_lk":
                segs = [self.j["segs"][op["seg0"] + j] for j in range(4)]
                ca = self.read_tensor(segs[0][0])[:, :3]
                cb = self.read_tensor(segs[1][0])[:, :3]
                fa = self.read_tensor(segs[2][0])
                fb = self.read_tensor(segs[3][0])
                la = luma(ca)
                lb = luma(cb)
                fa_new, fb_new, _ = lk_step(la, lb, fa, fb, t_val, k=9)
                self.write_tensor(op["out"], fa_new)
                self.write_tensor(op["ip"][0], fb_new)

            elif kind_str == "oft_final":
                segs = [self.j["segs"][op["seg0"] + j] for j in range(5)]
                ca = self.read_tensor(segs[0][0])[:, :3]
                cb = self.read_tensor(segs[1][0])[:, :3]
                f_ta = self.read_tensor(segs[2][0])
                f_tb = self.read_tensor(segs[3][0])
                mask = self.read_tensor(segs[4][0])

                v = torch.sigmoid(mask)
                wa = warp(ca, f_ta)
                wb = warp(cb, f_tb)
                col = (v * wa + (1.0 - v) * wb).clamp(0.0, 1.0)
                                        
                col4 = torch.cat([col, torch.ones_like(col[:, :1])], dim=1)
                self.write_tensor(op["out"], col4)

                        
        final_op = [op for op in self.j["ops"] if op.get("name") == "oft_final" or op["kind"] == 67][0]
        col_tid = final_op["out"]
        f_ta_tid = self.j["segs"][final_op["seg0"] + 2][0]
        f_tb_tid = self.j["segs"][final_op["seg0"] + 3][0]
        mask_tid = self.j["segs"][final_op["seg0"] + 4][0]
        return {
            "color": self.read_tensor(col_tid)[:, :3],
            "f_ta": self.read_tensor(f_ta_tid),
            "f_tb": self.read_tensor(f_tb_tid),
            "mask": self.read_tensor(mask_tid)
        }

def main():
    import gc
    print("Running OFT Engine Emulator verification...")
    out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8"

                                  
    from diag_oft_int8 import OFTNet, build_fake_quant_oft, run_forward_with_collect, StatCollector, run_fake_quant_forward
    from lk_refine import lk_refine
    net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3))
    net.load_state_dict(torch.load("/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt", map_location="cpu"))
    net.blocks = net.blocks[:3]
    net.SCALES = (8, 4, 2)
    net.eval()
    with open(os.path.join(out_dir, "qstats_oft_int8.json")) as f:
        qstats = json.load(f)
    qscales = {k: v / 127.0 for k, v in qstats.items()}
    wq = build_fake_quant_oft(net, qstats)

                                            
    sd = torch.load("/mnt/e/nss_VK/NSS/mlof2/cache_oft_samples.pt", map_location="cpu")
    sample0 = sd[0]
    del sd
    gc.collect()

    name, t_val, ca, cb, of_ab, of_ba = sample0
    print(f"Testing on sample {name} (t={float(t_val):.2f})...")

                         
    with torch.no_grad():
        fp_ref = net(t_val, ca, cb, of_ab, of_ba)
        fa_lk, fb_lk, _ = lk_refine(ca, cb, fp_ref["f_ta"], fp_ref["f_tb"], t_val, scales=(2, 1), iters=3, k=9)
        v = fp_ref["vis"]
        fp_ref["color"] = (v * warp(ca, fa_lk) + (1.0 - v) * warp(cb, fb_lk)).clamp(0, 1)
        fp_ref["f_ta"] = fa_lk
        fp_ref["f_tb"] = fb_lk

        fq_ref = run_fake_quant_forward(net, t_val, ca, cb, of_ab, of_ba, qscales, wq)
        fq_fa_lk, fq_fb_lk, _ = lk_refine(ca, cb, fq_ref["f_ta"], fq_ref["f_tb"], t_val, scales=(2, 1), iters=3, k=9)
        v_fq = fq_ref["vis"]
        fq_ref["color"] = (v_fq * warp(ca, fq_fa_lk) + (1.0 - v_fq) * warp(cb, fq_fb_lk)).clamp(0, 1)
        fq_ref["f_ta"] = fq_fa_lk
        fq_ref["f_tb"] = fq_fb_lk

                                 
    emu = OFTEmu(out_dir, 1088, 1920)
    ca4 = torch.cat([ca, torch.ones_like(ca[:, :1])], dim=1)
    cb4 = torch.cat([cb, torch.ones_like(cb[:, :1])], dim=1)
    with torch.no_grad():
        out = emu.execute(t_val, ca4, cb4, of_ab, of_ba)

                             
    mse_fq = ((out["color"] - fq_ref["color"]) ** 2).mean().item()
    psnr_fq = -10.0 * math.log10(max(mse_fq, 1e-10))
    flow_err_a = (out["f_ta"] - fq_ref["f_ta"]).norm(dim=1).view(-1)
    flow_err_b = (out["f_tb"] - fq_ref["f_tb"]).norm(dim=1).view(-1)
    flow_med_fq = float(torch.median(torch.cat([flow_err_a, flow_err_b])))
    mask_l1_fq = float((out["mask"] - fq_ref["mask"]).abs().mean())

    print(f"Engine Emulator vs W8A8 PyTorch Fake-Quant:")
    print(f"  Color PSNR:   {psnr_fq:.2f} dB")
    print(f"  Flow EPE med: {flow_med_fq:.4f} px")
    print(f"  Mask L1:      {mask_l1_fq:.6f}")

                                 
    mse_fp = ((out["color"] - fp_ref["color"]) ** 2).mean().item()
    psnr_fp = -10.0 * math.log10(max(mse_fp, 1e-10))
    flow_err_a_fp = (out["f_ta"] - fp_ref["f_ta"]).norm(dim=1).view(-1)
    flow_err_b_fp = (out["f_tb"] - fp_ref["f_tb"]).norm(dim=1).view(-1)
    flow_med_fp = float(torch.median(torch.cat([flow_err_a_fp, flow_err_b_fp])))
    mask_l1_fp = float((out["mask"] - fp_ref.get("mask", fp_ref.get("vis"))).abs().mean())

    print(f"\nEngine Emulator vs FP32 Reference:")
    print(f"  Color PSNR:   {psnr_fp:.2f} dB (Target: >= 45.0 dB)")
    print(f"  Flow EPE med: {flow_med_fp:.4f} px (Target: <= 0.1 px)")
    print(f"  Mask L1:      {mask_l1_fp:.6f}")

if __name__ == "__main__":
    main()
