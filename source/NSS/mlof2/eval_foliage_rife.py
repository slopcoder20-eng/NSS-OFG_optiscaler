"""RIFE 4.25 (Practical-RIFE, MIT, colour only) on the eval_foliage_mfg.py protocol: real frames every N-th Spring frame,
generated t = k/N scored against the frames in between; error on all px and on the foliage region (where the exact flow
differs from its 65x65 box mean by > 1.5 px = the motion a game leaves out of its MV), plus sharpness there.
  [MFG=4] python eval_foliage_rife.py <spring crop safetensors> [<spring crop> ...]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from data_v2 import chain_backward
from selector import luma

sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
from train_log.IFNet_HDv3 import IFNet

dev = "cuda"
NM = int(os.environ.get("MFG", "4"))
net = IFNet().to(dev).eval()
sd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
net.load_state_dict({k.replace("module.", ""): v for k, v in sd.items()}, strict=False)


@torch.no_grad()
def interp(a, b, t):
    h, w = a.shape[-2:]
    ph, pw = (64 - h % 64) % 64, (64 - w % 64) % 64
    a, b = F.pad(a, (0, pw, 0, ph), mode="replicate"), F.pad(b, (0, pw, 0, ph), mode="replicate")
    _, _, merged = net(torch.cat((a, b), 1), t, [16, 8, 4, 2, 1])
    return merged[-1][..., :h, :w].clamp(0, 1)


grad_m = lambda l, r: float(((l[:, 2:] - l[:, :-2]).abs()[1:-1, :] + (l[2:, :] - l[:-2, :]).abs()[:, 1:-1])[r[1:-1, 1:-1]].mean())
for fn in sys.argv[1:]:
    s = safe_open(fn, "pt")
    T = s.get_slice("ground_truth_srgb8").get_shape()[0]
    H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
    hm = s.get_slice("motion_lr").get_shape()[-2]
    col = lambda i: (s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0).to(dev)
    nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
    up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
    err, err_r, shp_r = [], [], []
    for a in range(0, T - NM, NM):
        b = a + NM
        mv = up(chain_backward(nat(x) for x in range(b, a, -1))).to(dev)
        r = 32
        sm = F.avg_pool2d(F.pad(mv, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        drop = ((mv - sm).norm(dim=1, keepdim=True) > 1.5).float()
        reg = F.max_pool2d(drop, 17, 1, 8)[0, 0] > 0.5
        ca, cb = col(a), col(b)
        for k in range(1, NM):
            o = interp(ca, cb, k / NM)
            lg, lo = luma(col(a + k))[0, 0], luma(o)[0, 0]
            e = (lo - lg).abs() * 255
            err.append(float(e.mean()))
            if reg.any():
                err_r.append((float(e[reg].sum()), float(reg.sum())))
                shp_r.append(grad_m(lo, reg) / max(grad_m(lg, reg), 1e-6))
    name = "/".join(fn.split("/")[-2:])
    fol = sum(x for x, _ in err_r) / max(sum(n for _, n in err_r), 1)
    print(f"RIFE {name}: MFG {NM}x all {np.mean(err):.2f} | foliage region error {fol:.2f} sharpness {np.nanmean(shp_r):.3f}", flush=True)
