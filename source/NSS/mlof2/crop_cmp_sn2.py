"""Side-by-side crops on SN2: GT f-1 | FSR4 | MLOF2 | blend(f-2, f), for given frames and box (y0 y1 x0 x1)."""
import os, sys
import numpy as np
from PIL import Image
cap, rep, out = sys.argv[1], sys.argv[2], sys.argv[3]
frames = [int(x) for x in sys.argv[4].split(",")]
y0, y1, x0, x1 = (int(v) for v in sys.argv[5].split(","))
def gt(f):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(1080, 1920)
    return np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.uint8)
rows = []
for f in frames:
    ims = [gt(f - 1), np.asarray(Image.open(f"{rep}/k_fsr4_s1_t0_h0_{f:03d}_1.ppm").convert("RGB")),
           np.asarray(Image.open(f"{rep}/k_mlof2_e16k_{f:03d}_1.ppm").convert("RGB")),
           ((gt(f - 2).astype(np.float32) + gt(f).astype(np.float32)) / 2).astype(np.uint8)]
    rows.append(np.concatenate([i[y0:y1, x0:x1] for i in ims], 1))
Image.fromarray(np.concatenate(rows, 0)).save(out)
