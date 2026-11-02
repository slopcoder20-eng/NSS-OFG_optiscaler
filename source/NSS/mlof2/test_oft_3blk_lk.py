import sys, os, json, torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from diag_oft_int8 import OFTNet, build_fake_quant_oft, run_fake_quant_forward
from lk_refine import lk_refine, warp

def psnr(a, b):
    mse = F.mse_loss(a, b).item()
    return -10 * np.log10(mse + 1e-10)

def main():
    print("=" * 60)
    print("Testing OFT 3-Block (s=8, 4, 2) + LK Refinement")
    print("=" * 60)
    
    dev = "cuda" if torch.cuda.is_available() else "cpu"
                                                                                           
    dev = "cpu"
    
    ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    qstats_path = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/qstats_oft_int8.json"
    
                 
    net4 = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net4.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net4.eval()
    
    with open(qstats_path) as f:
        qstats = json.load(f)
    qscales = {k: v / 127.0 for k, v in qstats.items()}
    wq4 = build_fake_quant_oft(net4, qstats)
    
                      
    io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
    ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    t = torch.tensor([0.5], device=dev)
    
                                    
    with torch.no_grad():
        ref4 = net4(t, ca, cb, of_ab, of_ba)
    
                                
    with torch.no_grad():
        fq4 = run_fake_quant_forward(net4, t, ca, cb, of_ab, of_ba, qscales, wq4)
    print(f"4-Block FQ vs FP32: PSNR = {psnr(fq4['color'], ref4['color']):.2f} dB, Flow EPE = {(fq4['f_ta'] - ref4['f_ta']).norm(dim=1).median().item():.4f} px")
    
                                 
    net3 = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net3.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net3.blocks = net3.blocks[:3]
    net3.SCALES = (8, 4, 2)
    net3.eval()
    
    with torch.no_grad():
        ref3 = net3(t, ca, cb, of_ab, of_ba)
    print(f"3-Block FP32 (no LK) vs 4-Block FP32: PSNR = {psnr(ref3['color'], ref4['color']):.2f} dB, Flow EPE = {(ref3['f_ta'] - ref4['f_ta']).norm(dim=1).median().item():.4f} px")
    
                                     
    with torch.no_grad():
        fa_lk, fb_lk, _ = lk_refine(ca, cb, ref3['f_ta'], ref3['f_tb'], t, scales=(2, 1), iters=3, k=9)
        v = ref3['vis']
        col_lk = (v * warp(ca, fa_lk) + (1.0 - v) * warp(cb, fb_lk)).clamp(0, 1)
    print(f"3-Block FP32 + LK vs 4-Block FP32: PSNR = {psnr(col_lk, ref4['color']):.2f} dB, Flow EPE = {(fa_lk - ref4['f_ta']).norm(dim=1).median().item():.4f} px")

                                                
    wq3 = build_fake_quant_oft(net3, qstats)
    with torch.no_grad():
        fq3 = run_fake_quant_forward(net3, t, ca, cb, of_ab, of_ba, qscales, wq3)
        fq_fa_lk, fq_fb_lk, _ = lk_refine(ca, cb, fq3['f_ta'], fq3['f_tb'], t, scales=(2, 1), iters=3, k=9)
        v_fq = fq3['vis']
        fq_col_lk = (v_fq * warp(ca, fq_fa_lk) + (1.0 - v_fq) * warp(cb, fq_fb_lk)).clamp(0, 1)
    print(f"3-Block W8A8 + LK vs 4-Block FP32: PSNR = {psnr(fq_col_lk, ref4['color']):.2f} dB, Flow EPE = {(fq_fa_lk - ref4['f_ta']).norm(dim=1).median().item():.4f} px")
    print(f"3-Block W8A8 + LK vs 3-Block FP32+LK: PSNR = {psnr(fq_col_lk, col_lk):.2f} dB, Flow EPE = {(fq_fa_lk - fa_lk).norm(dim=1).median().item():.4f} px")

if __name__ == "__main__":
    main()
