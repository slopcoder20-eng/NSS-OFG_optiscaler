"""Sanity check of a converted Spring file: pulling frame x-1 by the stored B->A flow of frame x (data_v2 convention
-m.flip(0), upsampled to 1080p) should reproduce frame x far better than no warp or the negated flow."""
import sys, torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import warp
p = sys.argv[1]
with safe_open(p, "pt") as s:
    T = s.get_slice("motion").get_shape()[0]
    for x in (10, T // 2, T - 5):
        c = s.get_slice("ground_truth_srgb8")[x - 1:x + 1].float() / 255.0
        m = s.get_slice("motion")[x:x + 1].float()
        f = F.interpolate(-m.flip(1) * 2.0, size=(1080, 1920), mode="bilinear", align_corners=False)
        ps = lambda a, b: -10 * torch.log10(((a - b) ** 2)[..., 16:-16, 16:-16].mean()).item()
        A, B = c[0:1], c[1:2]
        print(f"frame {x}: |flow| median {f.norm(dim=1).median():.1f}px max {f.norm(dim=1).max():.0f} | PSNR B vs A {ps(A, B):.2f}, "
              f"vs warp(A, flow) {ps(warp(A, f), B):.2f}, vs warp(A, -flow) {ps(warp(A, -f), B):.2f}")
    d = s.get_slice("depth")[0:1]; print("depth d range", float(d.min()), float(d.max()), "T", T)
