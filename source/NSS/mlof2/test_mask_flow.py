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

gpu_col = torch.from_numpy(np.fromfile(f"{io_dir}/op_059.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].float()
gpu_fa = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_m1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_055.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2)[:, :1].float()
gpu_vis = torch.sigmoid(gpu_m1)

print("Flow diff vs PyTorch ref_fa_lk:")
print("  mean:", (gpu_fa - ref_fa_lk).norm(dim=1).mean().item())
print("  median:", (gpu_fa - ref_fa_lk).norm(dim=1).median().item())
print("  max:", (gpu_fa - ref_fa_lk).norm(dim=1).max().item())

print("Mask diff vs PyTorch ref3['vis']:")
print("  mean:", (gpu_vis - ref3["vis"]).abs().mean().item())
print("  median:", (gpu_vis - ref3["vis"]).abs().median().item())
print("  max:", (gpu_vis - ref3["vis"]).abs().max().item())

                                                
wa_gpu = warp(ca, gpu_fa)
                                        
                                       
                     
                                            
diff_wa = (warp(ca, gpu_fa) - warp(ca, ref_fa_lk)).abs()
mse_wa = (diff_wa ** 2).mean().item()
psnr_wa = -10.0 * math.log10(max(mse_wa, 1e-10))
print(f"PSNR of warp(ca, gpu_fa) vs warp(ca, ref_fa_lk): {psnr_wa:.2f} dB")

