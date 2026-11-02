"""Blur check on the SN2 skip outputs: high-frequency energy (Laplacian variance of luma) of each method relative to
the skipped real frame f-1, overall and around the hands (bottom-centre box), per method prefix.
  python sharpness_sn2.py <capture dir> <replay dir> <prefix> [<prefix> ...]"""
import os, sys
import numpy as np
from PIL import Image
cap, rep = sys.argv[1], sys.argv[2]
def gt(f):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(1080, 1920)
    return np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.float32)
def lap(img):
    y = img @ np.array([0.299, 0.587, 0.114], np.float32)
    return (4 * y[1:-1, 1:-1] - y[:-2, 1:-1] - y[2:, 1:-1] - y[1:-1, :-2] - y[1:-1, 2:])
HB = (slice(700, 1078), slice(560, 1360))                                                  
for pre in sys.argv[3:]:
    r_all, r_h = [], []
    for f in range(2, 40, 2):
        p = os.path.join(rep, f"{pre}_{f:03d}_1.ppm")
        if not os.path.exists(p): continue
        o, g = np.asarray(Image.open(p).convert("RGB"), np.float32), gt(f - 1)
        lo, lg = lap(o), lap(g)
        r_all.append(lo.var() / lg.var()); r_h.append(lo[HB].var() / lg[HB].var())
    print(f"{pre:22s} frames {len(r_all)} | HF energy vs GT: all {np.mean(r_all):.2f}  hands box {np.mean(r_h):.2f}")
