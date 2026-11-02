import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp
from diag_oft_int8 import build_fake_quant_oft, run_fake_quant_forward

def psnr(a, b):
    mse = F.mse_loss(a, b).item()
    return -10.0 * math.log10(max(mse, 1e-10))

def main():
    print("=" * 60)
    print("Verifying Vulkan Engine GPU Output vs PyTorch References")
    print("=" * 60)
    dev = "cpu"
    ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
    out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8"

                 
    ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    t = torch.tensor([0.5], device=dev)

                             
                                              
    raw_col = np.fromfile(f"{io_dir}/op_059.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)
    gpu_col = torch.from_numpy(raw_col).permute(0, 3, 1, 2)[:, :3].float()

                                                                            
    raw_fa = np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)
    gpu_fa = torch.from_numpy(raw_fa).permute(0, 3, 1, 2).float()

                                                       
    net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net.blocks = net.blocks[:3]
    net.SCALES = (8, 4, 2)
    net.eval()

    with torch.no_grad():
        ref3 = net(t, ca, cb, of_ab, of_ba)
        ref_fa_lk, ref_fb_lk, _ = lk_refine(ca, cb, ref3["f_ta"], ref3["f_tb"], t, scales=(2, 1), iters=3, k=9)
        ref_v = ref3["vis"]
        ref_col = (ref_v * warp(ca, ref_fa_lk) + (1.0 - ref_v) * warp(cb, ref_fb_lk)).clamp(0, 1)

    print("\nVulkan GPU Output vs PyTorch 3-Block FP32 + LK:")
    color_psnr_fp = psnr(gpu_col, ref_col)
    flow_epe_fp = (gpu_fa - ref_fa_lk).norm(dim=1).median().item()
    print(f"  Color PSNR:   {color_psnr_fp:.2f} dB (Target: >= 45.0 dB)")
    print(f"  Flow EPE med: {flow_epe_fp:.4f} px (Target: <= 0.1 px)")

                                                        
    with open(f"{out_dir}/qstats_oft_int8.json") as f:
        qstats = json.load(f)
    qscales = {k: v / 127.0 for k, v in qstats.items()}
    wq = build_fake_quant_oft(net, qstats)
    with torch.no_grad():
        fq3 = run_fake_quant_forward(net, t, ca, cb, of_ab, of_ba, qscales, wq)
        fq_fa_lk, fq_fb_lk, _ = lk_refine(ca, cb, fq3["f_ta"], fq3["f_tb"], t, scales=(2, 1), iters=3, k=9)
        fq_v = fq3["vis"]
        fq_col = (fq_v * warp(ca, fq_fa_lk) + (1.0 - fq_v) * warp(cb, fq_fb_lk)).clamp(0, 1)

    print("\nVulkan GPU Output vs PyTorch 3-Block W8A8 Fake-Quant + LK:")
    color_psnr_fq = psnr(gpu_col, fq_col)
    flow_epe_fq = (gpu_fa - fq_fa_lk).norm(dim=1).median().item()
    print(f"  Color PSNR:   {color_psnr_fq:.2f} dB")
    print(f"  Flow EPE med: {flow_epe_fq:.4f} px")

if __name__ == "__main__":
    main()

