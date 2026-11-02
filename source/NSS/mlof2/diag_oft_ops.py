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

print("=" * 80)
print(f"{'Op':6s} | {'Name':15s} | {'Tensor':18s} | {'Shape':15s} | {'Max Diff':10s} | {'Mean Diff':10s} | Note")
print("=" * 80)

def report(op_idx, gpu_tensor, pt_tensor, note=""):
    op = g["ops"][op_idx]
    t_desc = g["tensors"][op["out"]]
    diff = (gpu_tensor - pt_tensor).abs()
    max_d = diff.max().item()
    mean_d = diff.mean().item()
    print(f"op_{op_idx:03d} | {op.get('name'):15s} | {t_desc['name']:18s} | {str(list(pt_tensor.shape)):15s} | {max_d:10.5f} | {mean_d:10.5f} | {note}")

                            
gpu_luma_a = torch.from_numpy(np.fromfile(f"{io_dir}/op_000.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2)[:, :1].float()
pt_luma_a = 0.299 * ca[:, 0:1] + 0.587 * ca[:, 1:2] + 0.114 * ca[:, 2:3]
report(0, gpu_luma_a, pt_luma_a, "FP16 rounding")

                             
gpu_luma_a_s2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_002.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2)[:, :1].float()
pt_luma_a_s2 = F.interpolate(pt_luma_a, size=(544, 960), mode="area")
report(2, gpu_luma_a_s2, pt_luma_a_s2, "Area avg")

                        
gpu_a_s8 = torch.from_numpy(np.fromfile(f"{io_dir}/op_008.bin", dtype=np.float16).reshape(1, 136, 240, 4)).permute(0, 3, 1, 2)[:, :3].float()
pt_a_s8 = F.interpolate(ca, size=(136, 240), mode="area")
report(8, gpu_a_s8, pt_a_s8, "Area avg")

                                  
gpu_fa_s8 = torch.from_numpy(np.fromfile(f"{io_dir}/op_010.bin", dtype=np.float16).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).float()
pt_fa_init = -(1 - tt) * tt * of_ab + tt * tt * of_ba
pt_fb_init = (1 - tt) ** 2 * of_ab - tt * (1 - tt) * of_ba
report(10, gpu_fa_s8, pt_fa_init, "Init formula")

                                            
                                 
gpu_x_in_s8 = torch.from_numpy(np.fromfile(f"{io_dir}/op_011.bin", dtype=np.int8).reshape(1, 136, 240, 16)).permute(0, 3, 1, 2).float() * qscales["b0_s8.x_in"]
pt_b_s8 = F.interpolate(cb, size=(136, 240), mode="area")
wa_s8 = warp(pt_a_s8, pt_fa_init)
wb_s8 = warp(pt_b_s8, pt_fb_init)
diff_s8 = (wa_s8 - wb_s8).abs().mean(1, keepdim=True) * 4.0
m_s8 = torch.zeros_like(diff_s8)
pt_x_in_s8_unq = torch.cat([wa_s8, wb_s8, diff_s8, pt_fa_init / 16.0, pt_fb_init / 16.0, m_s8 / 4.0, tt.expand(1, 1, 136, 240)], dim=1)
pt_x_in_s8 = _q(pt_x_in_s8_unq, qscales["b0_s8.x_in"])
report(11, gpu_x_in_s8[:, :13], pt_x_in_s8, "oft_prep int8")

                                     
gpu_out80_s8 = torch.from_numpy(np.fromfile(f"{io_dir}/op_020.bin", dtype=np.float16).reshape(1, 34, 60, 80)).permute(0, 3, 1, 2).float()
                                       
blk0 = net.blocks[0]
d1_in = _q(pt_x_in_s8_unq, qscales["b0_s8.x_in"])
w_d1 = _q(blk0.d1.weight, blk0.d1.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
y_d1 = F.leaky_relu(F.conv2d(d1_in, w_d1, blk0.d1.bias, stride=2, padding=1), 0.1)
y_d1_q = _q(y_d1, qscales["b0_s8.d1_out"])
w_d2 = _q(blk0.d2.weight, blk0.d2.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
y_d2 = F.leaky_relu(F.conv2d(y_d1_q, w_d2, blk0.d2.bias, stride=2, padding=1), 0.1)
cur = _q(y_d2, qscales["b0_s8.d2_out"])
for ri, resc in enumerate(blk0.body):
    wa = _q(resc.a.weight, resc.a.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
    ya = F.leaky_relu(F.conv2d(cur, wa, resc.a.bias, padding=1), 0.1)
    ya_q = _q(ya, qscales[f"b0_s8.body_{ri}.a_out"])
    wb = _q(resc.b.weight, resc.b.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
    if ri < len(blk0.body) - 1:
        yb = F.conv2d(ya_q, wb, resc.b.bias, padding=1) + cur
        cur = _q(yb, qscales[f"b0_s8.body_{ri}.res_add"])
    else:
        yb = F.leaky_relu(F.conv2d(ya_q, wb, resc.b.bias, padding=1) + cur, 0.1)
        cur = _q(yb, qscales["b0_s8.body_out"])
w_out = _q(blk0.out.weight, blk0.out.weight.abs().amax(dim=(1,2,3), keepdim=True) / 127.0)
pt_out80_s8 = F.conv2d(cur, w_out, blk0.out.bias, padding=1)
report(20, gpu_out80_s8, pt_out80_s8, "Block 0 out80")

                              
gpu_fa_acc_s8 = torch.from_numpy(np.fromfile(f"{io_dir}/op_021.bin", dtype=np.float16).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).float()
d_s8 = F.pixel_shuffle(pt_out80_s8, 4)
pt_fa_acc_s8 = pt_fa_init + d_s8[:, 0:2]
pt_fb_acc_s8 = pt_fb_init + d_s8[:, 2:4]
pt_m_acc_s8 = d_s8[:, 4:5]
report(21, gpu_fa_acc_s8, pt_fa_acc_s8, "Block 0 fa_acc")

                                         
gpu_b2_fa = torch.from_numpy(np.fromfile(f"{io_dir}/op_049.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                      
gpu_lk0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_050.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                      
gpu_lk2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_052.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                               
gpu_fa_s1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_053.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
                                 
gpu_fa_s1_final = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
                   
gpu_col = torch.from_numpy(np.fromfile(f"{io_dir}/op_059.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].float()

print("=" * 80)
print(f"GPU vs GPU delta in LK s=2 (it0 - input): max={(gpu_lk0 - gpu_b2_fa).abs().max().item():.5f}, mean={(gpu_lk0 - gpu_b2_fa).abs().mean().item():.5f}")
print(f"GPU vs GPU delta in LK s=2 (it2 - input): max={(gpu_lk2 - gpu_b2_fa).abs().max().item():.5f}, mean={(gpu_lk2 - gpu_b2_fa).abs().mean().item():.5f}")
print(f"GPU vs GPU delta in LK s=1 (final - input): max={(gpu_fa_s1_final - gpu_fa_s1).abs().max().item():.5f}, mean={(gpu_fa_s1_final - gpu_fa_s1).abs().mean().item():.5f}")
