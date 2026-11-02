import os, sys
import numpy as np
from PIL import Image

cap = "/home/sh/sn2_cap/nfru_capture_19620640"
rdir = "/home/sh/sn2_replay"
W, H, DW = 1129, 636, 1132
raw = lambda f, n: np.fromfile(os.path.join(cap, f"{f:03d}_{n}.bin"), dtype=np.uint32).reshape(1080, 1920)
to8 = lambda a: np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.float32)
luma = lambda a: a @ np.float32([.299, .587, .114])

def align(out, gt):
    def l(a, k): return (a @ np.float32([.299, .587, .114])).reshape(1080 // k, k, 1920 // k, k).mean((1, 3))
    a, b = l(out, 4), l(gt, 4)
    a = a - a.mean(); b = b - b.mean()
    c = np.fft.irfft2(np.fft.rfft2(a) * np.conj(np.fft.rfft2(b)), a.shape)
    dy, dx = np.unravel_index(np.argmax(c), c.shape)
    dy = dy - a.shape[0] if dy > a.shape[0] // 2 else dy; dx = dx - a.shape[1] if dx > a.shape[1] // 2 else dx
    best = None
    for ry in range(dy * 4 - 3, dy * 4 + 4):
        for rx in range(dx * 4 - 3, dx * 4 + 4):
            g = np.roll(gt, (ry, rx), (0, 1))
            e = np.abs(l(out, 8) - l(g, 8))[4:-4, 8:-8].mean()
            if best is None or e < best[0]: best = (e, ry, rx)
    return best[1], best[2]

for name, pfx in [("oft_py", "k_oft_only"), ("ofg_eng", "k_ofg")]:
    errs = []
    for f in range(4, 40, 2):
        gf = f - 1
        gt0 = to8(raw(gf, "hudless"))
        out = np.asarray(Image.open(f"{rdir}/{pfx}_{f:03d}_1.ppm").convert("RGB")).astype(np.float32)
        dy, dx = align(out, gt0)
        gt_shifted = np.roll(gt0, (dy, dx), (0, 1))
        e = np.abs(luma(out) - luma(gt_shifted)).mean()
        errs.append(e)
    print(f"{name} (frames 4..38, 18 frames): mean luma error = {np.mean(errs):.2f}")

