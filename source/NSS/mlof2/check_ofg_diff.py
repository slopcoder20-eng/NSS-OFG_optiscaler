import numpy as np
from PIL import Image

f = 2
img_eng = np.array(Image.open(f"/home/sh/sn2_replay/k_ofg_{f:03d}_1.ppm")).astype(np.float32)
img_py = np.array(Image.open(f"/home/sh/sn2_replay/k_oft_only_{f:03d}_1.ppm")).astype(np.float32)

diff = np.abs(img_eng - img_py)
print(f"Frame {f:03d}: mean diff = {diff.mean():.2f}, max diff = {diff.max():.2f}")
print(f"img_eng shape = {img_eng.shape}, range = [{img_eng.min()}, {img_eng.max()}]")
print(f"img_py shape = {img_py.shape}, range = [{img_py.min()}, {img_py.max()}]")

                                                             
diff_bgr = np.abs(img_eng[:, :, ::-1] - img_py)
print(f"diff if RGB swapped with BGR: mean = {diff_bgr.mean():.2f}")

                     
diff_flip = np.abs(img_eng[::-1, :, :] - img_py)
print(f"diff if vertically flipped: mean = {diff_flip.mean():.2f}")

