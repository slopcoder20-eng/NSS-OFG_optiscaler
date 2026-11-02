import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp

dev = "cpu"
ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
t = torch.tensor([0.5], device=dev)

net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
net.load_state_dict(torch.load(ckpt_path, map_location=dev))
net.blocks = net.blocks[:3]
net.SCALES = (8, 4, 2)
net.eval()

with torch.no_grad():
    ref3 = net(t, ca, cb, of_ab, of_ba)
    ref_fa_lk, ref_fb_lk, _ = lk_refine(ca, cb, ref3["f_ta"], ref3["f_tb"], t, scales=(2, 1), iters=3, k=9)

gpu_fa = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()

err = (gpu_fa - ref_fa_lk).norm(dim=1).squeeze(0)               
print("Max error:", err.max().item())
y_max, x_max = np.unravel_index(err.argmax().numpy(), err.shape)
print(f"Max error position: y={y_max}, x={x_max}")
print(f"  gpu_fa at ({y_max}, {x_max}): {gpu_fa[0, :, y_max, x_max].tolist()}")
print(f"  ref_fa at ({y_max}, {x_max}): {ref_fa_lk[0, :, y_max, x_max].tolist()}")

                                                  
err_interior = err[16:-16, 16:-16]
print("Interior (exclude 16px border) max error:", err_interior.max().item(), "mean:", err_interior.mean().item(), "median:", err_interior.median().item())

err_interior32 = err[32:-32, 32:-32]
print("Interior (exclude 32px border) max error:", err_interior32.max().item(), "mean:", err_interior32.mean().item(), "median:", err_interior32.median().item())

                                      
                  
                                              
gpu_fa_s1_in = torch.from_numpy(np.fromfile(f"{io_dir}/op_053.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
                                 
err_before_lk = (gpu_fa_s1_in - ref3["f_ta"]).norm(dim=1).squeeze(0)
print("\nBefore LK (at 1088x1920):")
print("  all max error:", err_before_lk.max().item(), "mean:", err_before_lk.mean().item(), "median:", err_before_lk.median().item())
print("  interior 32px max error:", err_before_lk[32:-32, 32:-32].max().item(), "median:", err_before_lk[32:-32, 32:-32].median().item())

