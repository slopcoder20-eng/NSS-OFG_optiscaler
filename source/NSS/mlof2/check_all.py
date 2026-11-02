import numpy as np
from PIL import Image
for f in range(2, 40, 2):
    try:
        im = np.array(Image.open(f"/home/sh/sn2_replay/k_ofg_{f:03d}_1.ppm"))
        print(f"{f:03d}: min={im.min()} max={im.max()} mean={im.mean():.1f}")
    except Exception as e:
        print(f"{f:03d}: {e}")

