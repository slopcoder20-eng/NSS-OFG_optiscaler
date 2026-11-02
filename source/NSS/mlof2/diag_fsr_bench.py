"""Diagnose the FSR run: what does the FSR output resemble (A, B, G, shifted)? Montage of a few windows."""
import sys
import numpy as np
from PIL import Image
d = sys.argv[1]; H = W = 448
img = lambda p: np.fromfile(p, np.uint8).reshape(H, W, 4)[..., :3].astype(np.float32) / 255
ps = lambda x, y: -10 * np.log10(max(((x - y) ** 2).mean(), 1e-10))
rows = []
for i in ["0000", "0003", "0010", "0020"]:
    p = f"{d}/{i}_clean_"
    a, b, g, f, o = (img(p + n + ".bin") for n in ("color_a", "color_b", "color_g", "fsr", "ours"))
    mv = np.fromfile(p + "mv_ba.bin", np.float16).reshape(H, W, 2).astype(np.float32)
    print(i, f"fsr vs A {ps(f,a):.2f} vs B {ps(f,b):.2f} vs G {ps(f,g):.2f} | mean fsr {f.mean():.3f} G {g.mean():.3f} | |mv| median {np.median(np.linalg.norm(mv,axis=-1)):.1f}px")
    rows.append(np.concatenate([a, b, g, f, o], 1))
Image.fromarray((np.concatenate(rows, 0) * 255).astype(np.uint8)).save(sys.argv[2])
