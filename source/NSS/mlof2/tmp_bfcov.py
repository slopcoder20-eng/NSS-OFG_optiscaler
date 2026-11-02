import numpy as np
from PIL import Image
R = "/home/sh/mlof2_runs/render_1031"
rd = lambda p: np.asarray(Image.open(p)).astype(np.float32)
for f in (2, 44, 46):
    base = rd(f"{R}/cut3_{f:03d}_1.ppm")
    out = []
    for v in ("cut3_bfarg", "cut3_bfedge", "cut3_bfedge4"):
        d = np.abs(rd(f"{R}/{v}_{f:03d}_1.ppm") - base).max(-1)
        out.append(f"{v} changed px {100 * (d > 8).mean():5.1f}%")
    print(f"frame {f}: " + " | ".join(out))
for f, x, y in ((46, 0, 300), (2, 1290, 0)):
    base = rd(f"{R}/cut3_{f:03d}_1.ppm")[y:y + 270, x:x + 480]
    print(f"crop f{f}: " + " | ".join(f"{v} {100 * (np.abs(rd(f'{R}/{v}_{f:03d}_1.ppm')[y:y + 270, x:x + 480] - base).max(-1) > 8).mean():5.1f}%" for v in ("cut3_bfarg", "cut3_bfedge", "cut3_bfedge4")))
