"""Does the recurrent 1/8 block use the information we think? Final 1/4 flow foliage / dev-bin EPE (full res, exact
Spring flow) of a model with its block inputs ablated: none | c8 (1/8 corr zero) | c16 | teacher (SEA-RAFT features
instead of the MatchEncoder's) | shuffle (MatchEncoder features spatially shuffled) | norec (block skipped).
  python diag_rec_ablate.py <crop> <ckpt> <modes comma>"""
import sys, torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from data_v2 import depth_feature, chain_backward
fn, ck, modes = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
N, dev = 4, "cuda"; s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]; H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]; PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)), size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
sd = torch.load(ck, map_location=dev); m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
import os
if os.environ.get("PROJ"):                                                                              
    w = torch.load(os.environ["PROJ"], map_location=dev)
    m.pair.rec.proj = torch.nn.Conv2d(w["weight"].shape[1], w["weight"].shape[0], 1).to(dev).eval(); m.pair.rec.proj.load_state_dict(w)
full = lambda f: F.interpolate(f, size=(PH, W), mode="bilinear", align_corners=False) * (W / f.shape[-1])
DEV = [0, 2, 4, 8, 16, 1e9]; acc = {}
with torch.no_grad():
    for a in range(0, T - N, N):
        b = a + N
        ca, cb, da, db = (pad(x).to(dev) for x in (col(a), col(b), dfeat(a), dfeat(b)))
        ex = pad(up(chain_backward(nat(x) for x in range(b, a, -1)))).to(dev); r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        dv = (ex - sm).norm(dim=1)[0, :H]
        reg = (F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5)[0, 0, :H]
        masks = {"all": torch.ones_like(reg), "fol": reg}
        for i in range(len(DEV) - 1):
            masks[f"dev{DEV[i]:g}-{DEV[i+1]:g}"] = (dv >= DEV[i]) & (dv < DEV[i + 1])
        fa, fb = m.enc(ca, da), m.enc(cb, db)
        for md in modes:
            rec = m.pair.rec
            m.pair.rec = None if md == "norec" else rec
            if rec is not None:
                rec.ablate = () if md in ("none", "norec", "skip4", "skip4c16") else (md,)
                rec.no16 = md == "skip4c16"
            m.pair.skip4 = md.startswith("skip4")
            o = m.pair.of_forward(fa, fb, ca, cb)[4]["of"][:1]
            m.pair.rec = rec
            e = (full(o) - ex).norm(dim=1)[0, :H]
            for mk, msk in masks.items():
                v = acc.setdefault((md, mk), [0.0, 0.0]); v[0] += float(e[msk].sum()); v[1] += float(msk.sum())
mks = ["all", "fol"] + [f"dev{DEV[i]:g}-{DEV[i+1]:g}" for i in range(len(DEV) - 1)]
print(f"  {'':10s}" + "".join(f"{k:>10s}" for k in mks))
for md in modes:
    print(f"  {md:10s}" + "".join(f"{acc[(md, k)][0] / max(acc[(md, k)][1], 1):10.2f}" for k in mks))
