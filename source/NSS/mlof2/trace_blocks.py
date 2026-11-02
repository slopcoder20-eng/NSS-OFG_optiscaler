import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, lk_step, warp, luma
from model_v2 import resize_flow
from diag_oft_int8 import build_fake_quant_oft

dev = "cpu"
ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
t = torch.tensor([0.5], device=dev)
tt = t.view(1, 1, 1, 1)

net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
net.load_state_dict(torch.load(ckpt_path, map_location=dev))
net.blocks = net.blocks[:3]
net.SCALES = (8, 4, 2)
net.eval()

with open(f"{out_dir}/qstats_oft_int8.json") as f:
    qstats = json.load(f)
qscales = {k: v / 127.0 for k, v in qstats.items()}
wq = build_fake_quant_oft(net, qstats)

def _q(x, s):
    return torch.clamp(torch.round(x / s), -127, 127) * s

g = json.load(open(f"{out_dir}/mlof2_oft.json"))

def report(op_idx, gpu_tensor, pt_tensor, note=""):
    op = g["ops"][op_idx]
    t_desc = g["tensors"][op["out"]]
    diff = (gpu_tensor - pt_tensor).abs()
    max_d = diff.max().item()
    mean_d = diff.mean().item()
    print(f"op_{op_idx:03d} | {op.get('name'):15s} | {t_desc['name']:18s} | {str(list(pt_tensor.shape)):15s} | {max_d:10.5f} | {mean_d:10.5f} | {note}")

                                   
pt_fa_init = -(1 - tt) * tt * of_ab + tt * tt * of_ba
pt_fb_init = (1 - tt) ** 2 * of_ab - tt * (1 - tt) * of_ba
fa_cur, fb_cur = pt_fa_init, pt_fb_init
m_cur = torch.zeros(1, 1, 136, 240)

scales = (8, 4, 2)
orig_scales = (8, 4, 2)

for bi, (blk, s) in enumerate(zip(net.blocks, scales)):
    h, w = 1088 // s, 1920 // s
    prefix = f"b{bi}_s{s}"
    q_prefix = f"b{bi}_s{orig_scales[bi]}"
    a_s = F.interpolate(ca, size=(h, w), mode="area")
    b_s = F.interpolate(cb, size=(h, w), mode="area")
    wa = warp(a_s, fa_cur)
    wb = warp(b_s, fb_cur)
    diff = (wa - wb).abs().mean(1, keepdim=True) * 4.0
    x_in_unq = torch.cat([wa, wb, diff, fa_cur / 16.0, fb_cur / 16.0, m_cur / 4.0, tt.expand(1, 1, h, w)], dim=1)
    x_in = _q(x_in_unq, qscales[f"{q_prefix}.x_in"])
    
    w_d1 = _q(blk.d1.weight, blk.d1.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
    y_d1 = F.leaky_relu(F.conv2d(x_in, w_d1, blk.d1.bias, stride=2, padding=1), 0.1)
    y_d1_q = _q(y_d1, qscales[f"{q_prefix}.d1_out"])
    
    w_d2 = _q(blk.d2.weight, blk.d2.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
    y_d2 = F.leaky_relu(F.conv2d(y_d1_q, w_d2, blk.d2.bias, stride=2, padding=1), 0.1)
    cur = _q(y_d2, qscales[f"{q_prefix}.d2_out"])
    
    for ri, resc in enumerate(blk.body):
        wa_ = _q(resc.a.weight, resc.a.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
        ya = F.leaky_relu(F.conv2d(cur, wa_, resc.a.bias, padding=1), 0.1)
        ya_q = _q(ya, qscales[f"{q_prefix}.body_{ri}.a_out"])
        wb_ = _q(resc.b.weight, resc.b.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
        if ri < len(blk.body) - 1:
            yb = F.conv2d(ya_q, wb_, resc.b.bias, padding=1) + cur
            cur = _q(yb, qscales[f"{q_prefix}.body_{ri}.res_add"])
        else:
            yb = F.leaky_relu(F.conv2d(ya_q, wb_, resc.b.bias, padding=1) + cur, 0.1)
            cur = _q(yb, qscales[f"{q_prefix}.body_out"])
            
    w_out = _q(blk.out.weight, blk.out.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
    out80 = F.conv2d(cur, w_out, blk.out.bias, padding=1)
    
                 
    out80_op_idx = {0: 20, 1: 34, 2: 48}[bi]
    gpu_out80 = torch.from_numpy(np.fromfile(f"{io_dir}/op_{out80_op_idx:03d}.bin", dtype=np.float16).reshape(1, h//4, w//4, 80)).permute(0, 3, 1, 2).float()
    report(out80_op_idx, gpu_out80, out80, f"Block {bi} out80")
    
    d = F.pixel_shuffle(out80, 4)
    fa_acc = fa_cur + d[:, 0:2]
    fb_acc = fb_cur + d[:, 2:4]
    m_acc = m_cur + d[:, 4:5]
    
    fa_acc_op_idx = {0: 21, 1: 35, 2: 49}[bi]
    gpu_fa_acc = torch.from_numpy(np.fromfile(f"{io_dir}/op_{fa_acc_op_idx:03d}.bin", dtype=np.float16).reshape(1, h, w, 2)).permute(0, 3, 1, 2).float()
    report(fa_acc_op_idx, gpu_fa_acc, fa_acc, f"Block {bi} fa_acc")
    
    if s > 2:
        next_s = s // 2
        fa_cur = resize_flow(fa_acc, 1088 // next_s, 1920 // next_s)
        fb_cur = resize_flow(fb_acc, 1088 // next_s, 1920 // next_s)
        m_cur = F.interpolate(m_acc, scale_factor=2, mode="bilinear", align_corners=False)
    else:
        fa_cur, fb_cur, m_cur = fa_acc, fb_acc, m_acc

print("=" * 80)
print(f"End of Block 2 (scale 2, 544x960): fa diff max={(gpu_fa_acc - fa_cur).abs().max().item():.5f}, mean={(gpu_fa_acc - fa_cur).abs().mean().item():.5f}")

