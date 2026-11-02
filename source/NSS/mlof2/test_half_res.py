import os, sys, torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp
from model_v2 import resize_flow

def main():
    dev = "cpu"
    ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

    ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
    of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
    t = torch.tensor([0.5], device=dev)

                                     
    net_full = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net_full.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net_full.blocks = net_full.blocks[:3]
    net_full.SCALES = (8, 4, 2)
    net_full.eval()

    with torch.no_grad():
        ref3 = net_full(t, ca, cb, of_ab, of_ba)
        ref_fa, ref_fb, _ = lk_refine(ca, cb, ref3["f_ta"], ref3["f_tb"], t, scales=(2, 1), iters=3, k=9)
        ref_col = (ref3["vis"] * warp(ca, ref_fa) + (1.0 - ref3["vis"]) * warp(cb, ref_fb)).clamp(0, 1)

                                                         
    net_half4 = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net_half4.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net_half4.eval()

    H2, W2 = 544, 960
    ca_h = F.interpolate(ca, size=(H2, W2), mode="area")
    cb_h = F.interpolate(cb, size=(H2, W2), mode="area")

    with torch.no_grad():
        oh4 = net_half4(t, ca_h, cb_h, of_ab, of_ba)
        rh4_a, rh4_b, _ = lk_refine(ca_h, cb_h, oh4["f_ta"], oh4["f_tb"], t, scales=(1,), iters=3, k=9)
        vh4 = F.interpolate(oh4["vis"], size=(1088, 1920), mode="bilinear", align_corners=False)
        fa_h4 = resize_flow(rh4_a, 1088, 1920)
        fb_h4 = resize_flow(rh4_b, 1088, 1920)
        col_h4 = (vh4 * warp(ca, fa_h4) + (1.0 - vh4) * warp(cb, fb_h4)).clamp(0, 1)

                                                                      
    net_half3 = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
    net_half3.load_state_dict(torch.load(ckpt_path, map_location=dev))
    net_half3.blocks = net_half3.blocks[:3]
    net_half3.SCALES = (8, 4, 2)
    net_half3.eval()

    with torch.no_grad():
        oh3 = net_half3(t, ca_h, cb_h, of_ab, of_ba)
                                             
        rh3_a, rh3_b, _ = lk_refine(ca_h, cb_h, oh3["f_ta"], oh3["f_tb"], t, scales=(1,), iters=3, k=9)
        vh3 = F.interpolate(oh3["vis"], size=(1088, 1920), mode="bilinear", align_corners=False)
        fa_h3 = resize_flow(rh3_a, 1088, 1920)
        fb_h3 = resize_flow(rh3_b, 1088, 1920)
        col_h3 = (vh3 * warp(ca, fa_h3) + (1.0 - vh3) * warp(cb, fb_h3)).clamp(0, 1)

    def psnr(a, b):
        return -10.0 * np.log10(max(F.mse_loss(a, b).item(), 1e-10))

    epe4 = (fa_h4 - ref_fa).norm(dim=1).median().item()
    psnr4 = psnr(col_h4, ref_col)
    epe3 = (fa_h3 - ref_fa).norm(dim=1).median().item()
    psnr3 = psnr(col_h3, ref_col)

    print("=" * 60)
    print("Half-Res Evaluation vs Full-Res 3-Block + LK Reference:")
    print(f"Half-Res 4-Block + LK (10.2 GMAC): Flow EPE = {epe4:.4f} px, Color PSNR = {psnr4:.2f} dB")
    print(f"Half-Res 3-Block + LK ( 4.3 GMAC): Flow EPE = {epe3:.4f} px, Color PSNR = {psnr3:.2f} dB")
    print("=" * 60)

if __name__ == "__main__":
    main()

