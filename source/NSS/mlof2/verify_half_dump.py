import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp
from model_v2 import resize_flow
from diag_oft_int8 import build_fake_quant_oft, run_fake_quant_forward

def psnr(a, b):
    mse = F.mse_loss(a, b).item()
    return -10.0 * math.log10(max(mse, 1e-10))

def main():
    print("=" * 60)
    print("Verifying Fused Half-Res Vulkan Engine GPU Output vs PyTorch Variant J")
    print("=" * 60)
    dev = "cpu"
    ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
    out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_half_v2_int8"

                 
    ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    t = torch.tensor([0.5], device=dev)

                             
                                              
    raw_col = np.fromfile(f"{io_dir}/op_069.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)
    gpu_col = torch.from_numpy(raw_col).permute(0, 3, 1, 2)[:, :3].float()

                                                        
    raw_fa = np.fromfile(f"{io_dir}/op_068.bin", dtype=np.float16).reshape(1, 544, 960, 2)
    gpu_fa_s2 = torch.from_numpy(raw_fa).permute(0, 3, 1, 2).float()
    gpu_fa_s1 = resize_flow(gpu_fa_s2, 1088, 1920)

                                                                
    net_half = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net_half.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net_half.eval()

    H2, W2 = 544, 960
    ca_h = F.interpolate(ca, size=(H2, W2), mode="area")
    cb_h = F.interpolate(cb, size=(H2, W2), mode="area")

    with torch.no_grad():
        oh4 = net_half(t, ca_h, cb_h, of_ab, of_ba)
        rh4_a, rh4_b, _ = lk_refine(ca_h, cb_h, oh4["f_ta"], oh4["f_tb"], t, scales=(1,), iters=3, k=9)
        vh4 = F.interpolate(oh4["vis"], size=(1088, 1920), mode="bilinear", align_corners=False)
        fa_h4 = resize_flow(rh4_a, 1088, 1920)
        fb_h4 = resize_flow(rh4_b, 1088, 1920)
        col_h4 = (vh4 * warp(ca, fa_h4) + (1.0 - vh4) * warp(cb, fb_h4)).clamp(0, 1)

    print("\nVulkan Fused Half-Res GPU Output vs PyTorch Half-Res FP32 (Variant J):")
    color_psnr = psnr(gpu_col, col_h4)
    flow_epe = (gpu_fa_s1 - fa_h4).norm(dim=1).median().item()
    flow_epe_max = (gpu_fa_s1 - fa_h4).norm(dim=1).max().item()
    print(f"  Color PSNR:       {color_psnr:.2f} dB")
    print(f"  Flow EPE median:  {flow_epe:.4f} px")
    print(f"  Flow EPE 95th:    {(gpu_fa_s1 - fa_h4).norm(dim=1).quantile(0.95).item():.4f} px")
    print(f"  Flow EPE max:     {flow_epe_max:.4f} px")

if __name__ == "__main__":
    main()
