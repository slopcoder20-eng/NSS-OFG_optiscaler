"""Brightness step at the off-frame band seam: per skipped frame, mean luma of A (f-2), B (f), the real G (f-1) over the
whole frame, and the output's signed luma error vs the real frame (aligned as sn2_vs_fsr4.py) inside the band and in a
32-px ring just outside it (non-HUD). A step = band and ring signed errors differ.
  python diag_band_luma.py <capture dir> <replay dir> <band mask prefix> <name=prefix> [...]"""
import os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation

cap, rdir, mpre = sys.argv[1:4]
methods = [a.split("=", 1) for a in sys.argv[4:]]
raw = lambda f, n: np.fromfile(os.path.join(cap, f"{f:03d}_{n}.bin"), dtype=np.uint32).reshape(1080, 1920)
to8 = lambda a: np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.float32)
luma = lambda a: a @ np.float32([.299, .587, .114])


def align(out, gt):
    def l(a, k): return luma(a).reshape(1080 // k, k, 1920 // k, k).mean((1, 3))
    a, b = l(out, 4), l(gt, 4)
    a = a - a.mean(); b = b - b.mean()
    c = np.fft.irfft2(np.fft.rfft2(a) * np.conj(np.fft.rfft2(b)), a.shape)
    dy, dx = np.unravel_index(np.argmax(c), c.shape)
    dy = dy - a.shape[0] if dy > a.shape[0] // 2 else dy; dx = dx - a.shape[1] if dx > a.shape[1] // 2 else dx
    best = None
    for ry in range(dy * 4 - 3, dy * 4 + 4):
        for rx in range(dx * 4 - 3, dx * 4 + 4):
            e = np.abs(l(out, 8) - l(np.roll(gt, (ry, rx), (0, 1)), 8))[4:-4, 8:-8].mean()
            if best is None or e < best[0]: best = (e, ry, rx)
    return best[1], best[2]


print("frame |  A     G     B   (mean luma, 8-bit) | " + " | ".join(f"{n}: band  ring  step" for n, _ in methods))
tot = {n: [] for n, _ in methods}
for f in range(2, 40, 2):
    A, G, B = (to8(raw(g, "hudless")) for g in (f - 2, f - 1, f))
    nohud = np.ones((1080, 1920), bool)
    for g in (f - 2, f - 1, f):
        nohud &= raw(g, "backbuffer") == raw(g, "hudless")
    band = np.load(f"{mpre}_{f:03d}.npy")
    ring = binary_dilation(band, iterations=32) & ~band
    cells = []
    for n, p in methods:
        o = np.asarray(Image.open(os.path.join(rdir, f"{p}_{f:03d}_1.ppm")).convert("RGB")).astype(np.float32)
        sy, sx = align(o, G)
        g = np.roll(G, (sy, sx), (0, 1))
        valid = np.zeros((1080, 1920), bool); valid[max(sy, 0):1080 + min(sy, 0), max(sx, 0):1920 + min(sx, 0)] = True
        d = luma(o) - luma(g)
        b_, r_ = band & nohud & valid, ring & nohud & valid
        eb, er = (float(d[b_].mean()) if b_.any() else np.nan), (float(d[r_].mean()) if r_.any() else np.nan)
        tot[n].append((eb, er))
        cells.append(f"{eb:+6.2f} {er:+6.2f} {eb - er:+6.2f}")
    print(f"{f - 1:5d} | {luma(A).mean():5.1f} {luma(G).mean():5.1f} {luma(B).mean():5.1f}             | " + " | ".join(cells))
for n, v in tot.items():
    v = np.array(v); v = v[~np.isnan(v).any(1)]
    print(f"{n}: mean signed err band {v[:, 0].mean():+.2f} ring {v[:, 1].mean():+.2f} | mean |step| {np.abs(v[:, 0] - v[:, 1]).mean():.2f}")
