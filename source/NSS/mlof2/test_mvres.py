"""Check data_v2.resample_mv: MV-warp PSNR of B vs A per render scale (same windows), CPU."""
import random, torch
import data_v2
from data_v2 import WindowDataset, resample_mv, MV_SCALES
from model_v2 import warp
ds = WindowDataset(["forest15", "lyra15"], "validation", crop=448, windows_per_file=4)
ps = lambda x, y, m: -10 * torch.log10((((x - y) ** 2) * m).sum() / (3 * m.sum()).clamp_min(1) + 1e-10).item()
res = {}
for i in range(0, len(ds), max(1, len(ds) // 12)):
    s = ds[i]
    ca, cb, mv = s["color_a"][None], s["color_b"][None], s["mv_ba"]
    m = (warp(torch.ones_like(ca[:, :1]), mv[None]) > 0.999).float()
    for sc in MV_SCALES:
        for up in ("bilinear", "nearest"):
            for dil in (False, True):
                d = torch.rand(1, 64, 64) if dil else None
                r = resample_mv(mv, sc, up, d)
                res.setdefault((sc, up, dil), []).append(ps(warp(ca, r[None]), cb, m))
    res.setdefault("orig", []).append(ps(warp(ca, mv[None]), cb, m))
for k, v in res.items():
    print(k, f"{sum(v) / len(v):.2f} dB (n={len(v)})")
