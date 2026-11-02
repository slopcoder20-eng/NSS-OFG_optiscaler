"""Practical-RIFE 4.25 (MIT, hzwer) as a candidate teacher, colour-only (no MV / depth).
  sn2   : python eval_rife.py sn2 <capture dir> <out prefix>     -> <prefix>_<f:03d>_1.ppm for skip_quality.py (f-2, f -> t 0.5)
  bench : python eval_rife.py bench <bench dir>                   -> <idx>_<ver>_rife.bin (RGBA8) next to export_fsr_bench.py files
RIFE code: /home/sh/third_party/Practical-RIFE (train_log = the 4.25 release)."""
import os
import sys
import numpy as np
import torch
from torch.nn import functional as F

sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
from train_log.IFNet_HDv3 import IFNet

dev = "cuda"
net = IFNet().to(dev).eval()
sd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
net.load_state_dict({k.replace("module.", ""): v for k, v in sd.items()}, strict=False)


@torch.no_grad()
def interp(a, b, t=0.5, scale=1.0):
    """a, b: (1,3,H,W) [0,1]. Pads to a multiple of 64 like the RIFE inference script."""
    h, w = a.shape[-2:]
    ph, pw = (64 - h % 64) % 64, (64 - w % 64) % 64
    a, b = F.pad(a, (0, pw, 0, ph)), F.pad(b, (0, pw, 0, ph))
    sl = [16 / scale, 8 / scale, 4 / scale, 2 / scale, 1 / scale]
    _, _, merged = net(torch.cat((a, b), 1), t, sl)
    return merged[-1][..., :h, :w].clamp(0, 1)


mode = sys.argv[1]
if mode == "sn2":
    cap, pre = sys.argv[2], sys.argv[3]
    def col(f):
        x = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(1080, 1920)
        c = np.stack([((x >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0
        return torch.from_numpy(c)[None].to(dev)
    for f in range(2, 40, 2):
        tr = {int(l.split()[0]): float(l.split()[1]) for l in open(os.environ["T_REAL"])} if os.environ.get("T_REAL") else {}
        out = interp(col(f - 2), col(f), tr.get(f, 0.5))[0]
        img = (out * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
        with open(f"{pre}_{f:03d}_1.ppm", "wb") as fh:
            fh.write(b"P6\n1920 1080\n255\n"); fh.write(img.tobytes())
    print("sn2 done")
else:
    d = sys.argv[2]
    lines = open(f"{d}/index.txt").read().split("\n")
    H, W = int(lines[0].split()[1]), int(lines[0].split()[3])
    ld = lambda p: torch.from_numpy(np.fromfile(p, np.uint8).reshape(H, W, 4)[..., :3].astype(np.float32) / 255).permute(2, 0, 1)[None].to(dev)
    n = 0
    for i in (l.split()[0] for l in lines[1:] if l.strip()):
        for ver in ("clean", "aug"):
            p = f"{d}/{i}_{ver}_"
            out = interp(ld(p + "color_a.bin"), ld(p + "color_b.bin"))[0]
            o = (out * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
            np.concatenate([o, np.full((H, W, 1), 255, np.uint8)], -1).tofile(p + "rife.bin")
            n += 1
    print("bench done", n)
