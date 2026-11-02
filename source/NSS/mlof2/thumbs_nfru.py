"""Contact sheet of NFRU-format captures (to pick scenes by content): python thumbs_nfru.py <out.png> <file[:frame]> ..."""
import sys
import numpy as np
import torch
import cv2
from safetensors import safe_open
from data_v2 import TONE_CURVES, srgb_encode

tiles = []
for arg in sys.argv[2:]:
    fn, fr = (arg.rsplit(":", 1) + ["0"])[:2] if ":" in arg.rsplit("/", 1)[-1] else (arg, "0")
    s = safe_open(fn, "pt")
    T = s.get_slice("rgb_linear").get_shape()[0]
    fr = str(min(int(fr), T - 1))
    x = s.get_slice("rgb_linear")[int(fr):int(fr) + 1].float()
    lum = (0.2126 * x[:, 0] + 0.7152 * x[:, 1] + 0.0722 * x[:, 2]).clamp_min(1e-6)
    e = 0.18 / torch.exp(torch.log(lum).mean())
    im = srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * e).clamp(0, 1))[0].permute(1, 2, 0).numpy()
    im = cv2.resize((im[..., ::-1] * 255).astype(np.uint8), (640, 360), interpolation=cv2.INTER_AREA)
    lb = f"{fn.split('datasets/')[-1]} f{fr} / {T}"
    cv2.rectangle(im, (0, 0), (12 + 9 * len(lb), 24), (0, 0, 0), -1)
    cv2.putText(im, lb, (5, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
    tiles.append(im)
while len(tiles) % 3:
    tiles.append(np.zeros_like(tiles[0]))
rows = [np.hstack(tiles[i:i + 3]) for i in range(0, len(tiles), 3)]
cv2.imwrite(sys.argv[1], np.vstack(rows))
print("wrote", sys.argv[1])
