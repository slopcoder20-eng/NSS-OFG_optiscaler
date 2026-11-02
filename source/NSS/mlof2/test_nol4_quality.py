import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp
from model_v2 import resize_flow

def psnr(a, b):
    mse = F.mse_loss(a, b).item()
    return -10.0 * math.log10(max(mse, 1e-10))

dev = "cpu"
ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
of_ab_l4 = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
of_ba_l4 = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
t = torch.tensor([0.5], device=dev)

                                                                               
of_ab_l8 = F.interpolate(of_ab_l4, size=(68, 120), mode="bilinear", align_corners=False) * 0.5
of_ba_l8 = F.interpolate(of_ba_l4, size=(68, 120), mode="bilinear", align_corners=False) * 0.5

net_half = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
net_half.load_state_dict(torch.load(ckpt_path, map_location=dev))
net_half.eval()

H2, W2 = 544, 960
ca_h = F.interpolate(ca, size=(H2, W2), mode="area")
cb_h = F.interpolate(cb, size=(H2, W2), mode="area")

with torch.no_grad():
                                 
    oh4_std = net_half(t, ca_h, cb_h, of_ab_l4, of_ba_l4)
    rh4_a_std, rh4_b_std, _ = lk_refine(ca_h, cb_h, oh4_std["f_ta"], oh4_std["f_tb"], t, scales=(1,), iters=3, k=9)
    vh4_std = F.interpolate(oh4_std["vis"], size=(1088, 1920), mode="bilinear", align_corners=False)
    fa_std = resize_flow(rh4_a_std, 1088, 1920)
    fb_std = resize_flow(rh4_b_std, 1088, 1920)
    col_std = (vh4_std * warp(ca, fa_std) + (1.0 - vh4_std) * warp(cb, fb_std)).clamp(0, 1)

                                                       
                                                         
                                                 
    oh4_nol4 = net_half(t, ca_h, cb_h, of_ab_l8, of_ba_l8)
    rh4_a_nol4, rh4_b_nol4, _ = lk_refine(ca_h, cb_h, oh4_nol4["f_ta"], oh4_nol4["f_tb"], t, scales=(1,), iters=3, k=9)
    vh4_nol4 = F.interpolate(oh4_nol4["vis"], size=(1088, 1920), mode="bilinear", align_corners=False)
    fa_nol4 = resize_flow(rh4_a_nol4, 1088, 1920)
    fb_nol4 = resize_flow(rh4_b_nol4, 1088, 1920)
    col_nol4 = (vh4_nol4 * warp(ca, fa_nol4) + (1.0 - vh4_nol4) * warp(cb, fb_nol4)).clamp(0, 1)

print("Comparison: Standard (pair with L4) vs MLOF2_OFT_NO_L4=1 (pair without L4):")
color_psnr = psnr(col_nol4, col_std)
flow_epe = (fa_nol4 - fa_std).norm(dim=1).median().item()
flow_epe_max = (fa_nol4 - fa_std).norm(dim=1).max().item()
print(f"  Color PSNR:       {color_psnr:.2f} dB")
print(f"  Flow EPE median:  {flow_epe:.4f} px")
print(f"  Flow EPE max:     {flow_epe_max:.4f} px")
print(f"  Mask diff median: {(vh4_nol4 - vh4_std).abs().median().item():.4f}")

