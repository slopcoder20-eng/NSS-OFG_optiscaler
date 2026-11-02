"""Why does the OF fail on foliage? Spring sequence, real frames N apart (as eval_foliage_mfg.py), OF B->A vs the exact
(chained Spring) flow. Prints for the whole frame and the foliage region (exact flow differs from its 65x65 box mean
by > 1.5 px, dilated 8 px = eval_foliage_mfg MV_SMOOTH=32,1.5):
  - OF EPE (OF_CAP=1 and 2)
  - representation floor: the exact flow area-reduced to the OF's output grid (1/4, 1/8 of the frame) and bilinear back
    up (no estimator can beat it with that output resolution)
  - OF EPE by exact-flow magnitude and by local flow spread (std of the exact flow in a 9x9 window)
  - occlusion share: pixels whose B->A flow lands where the A->B... (forward-backward check of the exact flow)
  python diag_foliage_of.py <spring crop safetensors> <OF ckpt> [N=4,2]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import depth_feature, chain_backward
from nfru_head import up4

fn, ck = sys.argv[1:3]
NS = [int(v) for v in (sys.argv[3] if len(sys.argv) > 3 else "4,2").split(",")]
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
fwd = lambda x: s.get_slice("motion_lr")[x].float().flip(0)                                                  
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))

sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False

MAG = [0, 2, 4, 8, 16, 32, 1e9]
DEV = [0, 1, 2, 4, 8, 12, 16, 24, 32, 48, 1e9]                                                        
CAPS = [int(v) for v in os.environ.get("CAPS", "1,2").split(",")]                                                   
SPR = [0, 0.5, 1, 2, 4, 1e9]


_teacher = None


def run_of(ca, da, cb, db, mv, cap):
    global _teacher
    if cap in (98, 99):                                                                                         
        if _teacher is None:
            from teacher_searaft import SeaRaftTeacher
            _teacher = SeaRaftTeacher(dev)
        return _teacher.flow_ba(cb, ca, 1.0 if cap == 99 else 0.5)[0]
    if cap < 0:                                                                                                              
        k = -cap
        u = lambda x: F.interpolate(x, scale_factor=k, mode="bilinear", align_corners=False)
        pr = m.pair(m.enc(u(ca), u(da)), m.enc(u(cb), u(db)), u(mv) * k, torch.ones_like(u(mv)[:, :1]), u(ca), u(cb))
        pr["of_ba_full"] = None
        of = up4(pr["of_ba"], ca.shape[-2] * k, ca.shape[-1] * k)
        return F.avg_pool2d(of, k) / k
    if cap > 1:
        dn = lambda x: F.avg_pool2d(x, cap)
        pr = m.pair(m.enc(dn(ca), dn(da)), m.enc(dn(cb), dn(db)), dn(mv) / cap, torch.ones_like(dn(mv)[:, :1]), dn(ca), dn(cb))
        pr["of_ba_full"] = None
    else:
        pr = m.pair(m.enc(ca, da), m.enc(cb, db), mv, torch.ones_like(mv[:, :1]), ca, cb)
    of = pr["of_ba_full"] if pr.get("of_ba_full") is not None else pr["of_ba"]
    return up4(of, *ca.shape[-2:])


with torch.no_grad():
    for N in NS:
        acc = {}
        def add(k, e, msk):
            v = acc.setdefault(k, [0.0, 0.0]); v[0] += float(e[msk].sum()); v[1] += float(msk.sum())
        for a in range(0, T - N, N):
            b = a + N
            ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
            da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
            ex = pad(mv_ba(a, b)).to(dev)
            r = 32
            sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
            reg = F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8)[0, 0, :H] > 0.5
            al = torch.ones_like(reg)
            mag = ex.norm(dim=1)[0, :H]
            mu = F.avg_pool2d(F.pad(ex, (4, 4, 4, 4), mode="replicate"), 9, 1)
            mu2 = F.avg_pool2d(F.pad(ex * ex, (4, 4, 4, 4), mode="replicate"), 9, 1)
            spr = (mu2 - mu * mu).clamp_min(0).sum(1).sqrt()[0, :H]
                                                                                                                   
                                                                                                                        
            ph = (warp(ca, ex) - cb).abs().mean(1)[0, :H] * 255                                               
            occ = ph > 24
            for cap in CAPS:
                of = run_of(ca, da, cb, db, ex, cap)
                e = (of - ex).norm(dim=1)[0, :H]
                add(f"of{cap} all", e, al); add(f"of{cap} fol", e, reg)
                add(f"of{cap} fol non-occ", e, reg & ~occ)
                dev_ = (ex - sm).norm(dim=1)[0, :H]                                                                  
                for i in range(len(DEV) - 1):
                    add(f"of{cap} dev {DEV[i]:g}-{DEV[i + 1]:g}", e, (dev_ >= DEV[i]) & (dev_ < DEV[i + 1]))
                for i in range(len(MAG) - 1):
                    add(f"of{cap} fol mag {MAG[i]:g}-{MAG[i + 1]:g}", e, reg & (mag >= MAG[i]) & (mag < MAG[i + 1]))
                for i in range(len(SPR) - 1):
                    add(f"of{cap} fol spread {SPR[i]:g}-{SPR[i + 1]:g}", e, reg & (spr >= SPR[i]) & (spr < SPR[i + 1]))
            for f_ in (4, 8):
                fl = up4(F.avg_pool2d(ex, f_) / f_, *ex.shape[-2:])
                e = (fl - ex).norm(dim=1)[0, :H]
                add(f"floor 1/{f_} all", e, al); add(f"floor 1/{f_} fol", e, reg)
            add("occl share fol (warp residual > 24)", occ.float(), reg)
            add("occl share all", occ.float(), al)
            add("fol px share", reg.float(), al)
            add("exact |flow| fol", mag, reg); add("exact |flow| all", mag, al)
        print(f"== N = {N} ({(T - N) // N + (1 if (T - N) % N else 0)} pairs)")
        for k, (x, n) in acc.items():
            share = f"   ({100 * n / acc[next(iter(acc))][1]:.1f}% of px)" if " mag " in k or " spread " in k or " dev " in k else ""
            print(f"  {k:42s} {x / max(n, 1):7.3f}{share}")
