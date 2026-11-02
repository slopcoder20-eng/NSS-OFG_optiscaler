import sys, numpy as np
H = 448; n = int(sys.argv[2])
img = lambda p: np.fromfile(p, np.uint8).reshape(H, H, 4)[..., :3].astype(np.float32) / 255
ps = lambda x, y: -10 * np.log10(((x - y) ** 2).mean())
print(round(float(np.mean([ps(img(f"{sys.argv[1]}/{i:04d}_clean_fsr.bin"), img(f"{sys.argv[1]}/{i:04d}_clean_color_g.bin")) for i in range(n)])), 2))
