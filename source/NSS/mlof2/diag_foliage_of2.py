"""Foliage OF error, signed: on the foliage region (as diag_foliage_of.py) split the OF B->A error into the component along
the exact flow (projection p = OF . ex / |ex|^2: 1 = right length, < 1 = too short) and across it (angle), by exact
magnitude bin; plus how often the OF is closer to the MV-free "background" (the 65x65 box mean of the exact flow) than to
the exact flow itself (= it follows the surrounding motion, not the blade). Saves a 2x2 picture of one pair:
colour B | exact flow | OF | EPE (0..16 px).
  python diag_foliage_of2.py <spring crop safetensors> <OF ckpt> <out png> [N=4] [pair index=6]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from data_v2 import depth_feature, chain_backward
from nfru_head import up4

fn, ck, out_png = sys.argv[1:4]
N = int(sys.argv[4]) if len(sys.argv) > 4 else 4
PI = int(sys.argv[5]) if len(sys.argv) > 5 else 6
dev = "cuda"
s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)),
                                size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
MAG = [0, 2, 4, 8, 16, 32, 1e9]


def flow_rgb(f, mx):
    fx, fy = f[0], f[1]
    ang = (torch.atan2(fy, fx) / (2 * np.pi) + 0.5)
    mag = (f.norm(dim=0) / mx).clamp(0, 1)
    h6 = ang * 6
    i = h6.floor() % 6
    fr = h6 - h6.floor()
    q, t_ = 1 - fr, fr
    one = torch.ones_like(fr)
    r = torch.stack([one, q, 0 * one, 0 * one, t_, one])
    g = torch.stack([t_, one, one, q, 0 * one, 0 * one])
    b = torch.stack([0 * one, 0 * one, t_, one, one, q])
    idx = i.long()[None]
    rgb = torch.stack([r.gather(0, idx)[0], g.gather(0, idx)[0], b.gather(0, idx)[0]])
    return 1 - mag[None] * (1 - rgb)                                                                    


stat = {}
def add(k, v, msk):
    a = stat.setdefault(k, [0.0, 0.0]); a[0] += float(v[msk].sum()); a[1] += float(msk.sum())


pic = None
with torch.no_grad():
    for pi, a in enumerate(range(0, T - N, N)):
        b = a + N
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        ex = pad(mv_ba(a, b)).to(dev)
        r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        reg = F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8)[0, 0, :H] > 0.5
        pr = m.pair(m.enc(ca, da), m.enc(cb, db), ex, torch.ones_like(ex[:, :1]), ca, cb)
        of = pr["of_ba_full"] if pr.get("of_ba_full") is not None else pr["of_ba"]
        of = up4(of, *ca.shape[-2:])
        e2, o2, s2 = ex[0, :, :H], of[0, :, :H], sm[0, :, :H]
        mag = e2.norm(dim=0)
        epe = (o2 - e2).norm(dim=0)
        proj = (o2 * e2).sum(0) / mag.clamp_min(1e-3) ** 2
        cosv = (o2 * e2).sum(0) / (mag * o2.norm(dim=0)).clamp_min(1e-3)
        closer_bg = ((o2 - s2).norm(dim=0) < epe).float()
        moving = mag >= 4
        for i in range(len(MAG) - 1):
            mk = reg & (mag >= MAG[i]) & (mag < MAG[i + 1])
            tag = f"mag {MAG[i]:g}-{MAG[i + 1]:g}"
            add(f"{tag} EPE", epe, mk)
            add(f"{tag} closer to box-mean flow", closer_bg, mk)
            if MAG[i] >= 4:
                add(f"{tag} length ratio (proj)", proj, mk)
                add(f"{tag} cos(angle)", cosv, mk)
        add("fol |OF| / |exact| (moving >= 4 px)", o2.norm(dim=0) / mag.clamp_min(1e-3), reg & moving)
        add("fol closer to box-mean flow (all)", closer_bg, reg)
        add("non-fol EPE", epe, ~reg)
        if pi == PI:
            mx = float(torch.quantile(mag[reg], 0.98)) if reg.any() else 16.0
            top = torch.cat((cb[0, :, :H], flow_rgb(e2, mx)), 2)
            emap = (epe / 16).clamp(0, 1)[None].repeat(3, 1, 1)
            bot = torch.cat((flow_rgb(o2, mx), emap), 2)
            pic = torch.cat((top, bot), 1)
            pic_info = (a, b, mx)

for k, (x, n) in stat.items():
    print(f"  {k:45s} {x / max(n, 1):7.3f}   (n {int(n)})")
if pic is not None:
    from PIL import Image
    arr = (pic.clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
    Image.fromarray(arr).resize((arr.shape[1] // 2, arr.shape[0] // 2)).save(out_png)
    print(f"saved {out_png}: pair A={pic_info[0]} B={pic_info[1]} | colour B, exact flow / OF (white = still, full colour = "
          f"{pic_info[2]:.1f} px), EPE 0..16 px")
