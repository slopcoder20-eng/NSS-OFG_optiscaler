"""SN2 capture: which MV interpretation actually moves frame f-1 onto frame f? (4x-downsampled PSNR, like skip_quality)"""
import os, sys, numpy as np, torch
from torch.nn import functional as F
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import warp
cap = sys.argv[1]
DW, DH, RW, RH = 1920, 1080, 1129, 636
def col(f):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    return torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023)[None]
def mv(f, name):
    m = np.fromfile(os.path.join(cap, f"{f:03d}_{name}.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    return torch.from_numpy(m).permute(2, 0, 1)[None]
def up(m, sx, sy):
    m = m * torch.tensor([sx, sy]).view(1, 2, 1, 1)
    return F.interpolate(m, size=(DH, DW), mode="bilinear", align_corners=False)
def ps(a, b):
    a, b = F.avg_pool2d(a, 4), F.avg_pool2d(b, 4)
    return -10 * torch.log10(((a - b) ** 2)[..., 8:-8, 8:-8].mean()).item()
for f in (1, 9, 15, 16, 17, 25):
    A, B = col(f - 1), col(f)
    m = mv(f, "mv")
    print(f"frame {f}: |mv| render-px max {m.abs().amax():.1f} mean {m.abs().mean():.2f}")
    res = {"no warp": ps(A, B)}
    for name in ("mv", "fixed_mv"):
        mm = mv(f, name)
        for lab, sx, sy in (("px*disp/render", DW / RW, DH / RH), ("px*disp/render, -y", DW / RW, -DH / RH),
                            ("-(px*disp/render)", -DW / RW, -DH / RH), ("uv*display", DW, DH), ("-uv*display", -DW, -DH)):
            res[f"{name} {lab}"] = ps(warp(A, up(mm, sx, sy)), B)
    best = max(res, key=res.get)
    print("   " + " | ".join(f"{k} {v:.2f}" for k, v in res.items()) + f"   -> best: {best}")
