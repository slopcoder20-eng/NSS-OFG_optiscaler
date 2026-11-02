"""Does the gate 'trust the MV, let the OF patch its failures' on the real game? SN2 pairs (A = f-GAP, B = f), full
MLOF2 pair (gate c: 1 = game MV, 0 = OF; flow = c MV + (1 - c) OF). Photometric error = mean |luma(B) - luma(A pulled
by the flow)| (8-bit). Regions:
  background by |MV| bin (no viewmodel, valid MV): c, share of pixels the OF overrides (c < 0.5), photometric gated/MV/OF
  'MV right' (MV error < 6): override share and the harm (gated - MV)
  'MV fails, OF better' (MV error > 20 and OF error < MV error - 10): c and the gain (MV - gated)
  viewmodel inner / band in / band out (8 px from its edge)
  python diag_sn2_gate.py <ckpt> <capture dir>      (env GAP=2 skip pairs, 1 consecutive)"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp, resize_flow
from data_v2 import chain_backward

ck, cap = sys.argv[1], sys.argv[2]
GAP = int(os.environ.get("GAP", "2"))
dev = "cuda"
DW, DH, RW, RH, RP, PH = 1920, 1080, 1129, 636, 1132, 1088
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))


def colour(fr):
    a = np.fromfile(os.path.join(cap, f"{fr:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    return torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0)


def rawdepth(fr):
    return np.fromfile(os.path.join(cap, f"{fr:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]


def depth(fr):
    d = torch.from_numpy(rawdepth(fr).copy()).clamp_min(1e-7)
    return F.interpolate(((torch.log2(1.0 / d) / 16.0).clamp(0, 1))[None, None], size=(DH, DW), mode="bilinear", align_corners=False)[0]


def mv_one(fr):
    m = np.fromfile(os.path.join(cap, f"{fr:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < 1000)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m)) * torch.tensor(meta[fr]).view(2, 1, 1) * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    return F.interpolate(m[None], size=(DH, DW), mode="bilinear", align_corners=False)[0], F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0]


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
luma = lambda c: (c * torch.tensor([.299, .587, .114], device=c.device).view(3, 1, 1)).sum(0) * 255
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
bins = [0, 8, 32, 64, 128, 256, 1e9]
acc = {}


def add(key, c, sel, eg, em, eo):
    if sel.sum() < 300:
        return
    a = acc.setdefault(key, {"c": [], "ovr": [], "g": [], "mv": [], "of": [], "n": 0})
    a["c"].append(float(c[sel].mean())); a["ovr"].append(float((c[sel] < 0.5).float().mean()))
    a["g"].append(float(eg[sel].mean())); a["mv"].append(float(em[sel].mean())); a["of"].append(float(eo[sel].mean()))
    a["n"] += 1


with torch.no_grad():
    for f in range(2, 40, 2):
        ca, cb = pad(colour(f - GAP))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - GAP))[None].to(dev), pad(depth(f))[None].to(dev)
        m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
        if GAP == 2:
            mv = chain_backward([m1, m0]); mvv = v1 * (warp(v0[None], m1[None])[0] > 0.999).float()
        else:
            mv, mvv = m1, v1
        mvp, mvvp = pad(mv)[None].to(dev), pad(mvv)[None].to(dev)
        fa, fb = m.enc(ca, da), m.enc(cb, db)
        pair = m.pair(fa, fb, mvp, mvvp, ca, cb)
        g = resize_flow(pair["f_ba"], PH, DW)[0, :, :DH]
        of = (pair["of_ba_full"] if pair.get("of_ba_full") is not None else resize_flow(pair["of_ba"], PH, DW))[0, :, :DH]
        c = F.interpolate(pair["gate"][:1], size=(PH, DW), mode="bilinear", align_corners=False)[0, 0, :DH]
        mv, mvv = mv.to(dev), mvv[0].to(dev) > 0.5
        A, B = ca[0, :, :DH], cb[0, :, :DH]
        lB = luma(B)
        err = lambda fl: (lB - luma(warp(A[None], fl[None])[0])).abs()
        eg, em, eo = err(g), err(mv), err(of)
        ones = torch.ones(1, 1, DH, DW, device=dev)
        inb = lambda fl: warp(ones, fl[None])[0, 0] > 0.999
        vm = torch.from_numpy(rawdepth(f) > 0.1).float()
        vm = (F.interpolate(vm[None, None], size=(DH, DW), mode="nearest")[0, 0] > 0.5).to(dev)
        ok = mvv & inb(mv) & inb(of) & inb(g)
        bg = ok & ~vm
        mm = mv.norm(dim=0)
        for i in range(len(bins) - 1):
            s = bg & (mm >= bins[i]) & (mm < bins[i + 1])
            add(("bg", i), c, s, eg, em, eo)
            add(("bg MV right", i), c, s & (em < 6), eg, em, eo)
            add(("bg MV fails", i), c, s & (em > 20) & (eo < em - 10), eg, em, eo)
        vmf = vm.float()[None, None]
        grown = F.max_pool2d(vmf, 17, 1, 8)[0, 0] > 0.5
        shrunk = -F.max_pool2d(-vmf, 17, 1, 8)[0, 0] > 0.5
        for rn, rm in (("vm inner", vm & shrunk), ("vm band in", vm & ~shrunk), ("vm band out", grown & ~vm)):
            add((rn, -1), c, rm & ok, eg, em, eo)
            add((rn + " MV fails", -1), c, rm & ok & (em > 20) & (eo < em - 10), eg, em, eo)

print(f"{ck}  GAP {GAP}   c: 1 = game MV, 0 = OF | override = share of pixels with c < 0.5 | photometric 8-bit gated / MV / OF")
mean = lambda v: float(np.mean(v))
for key in ("bg", "bg MV right", "bg MV fails"):
    print(f"== {key}")
    for i in range(len(bins) - 1):
        a = acc.get((key, i))
        if a:
            print(f"  |MV| {bins[i]:>4.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf':>4}: frames {a['n']:2d} | c {mean(a['c']):.3f} "
                  f"| override {100 * mean(a['ovr']):5.1f}% | ph {mean(a['g']):6.2f} / {mean(a['mv']):6.2f} / {mean(a['of']):6.2f}")
print("== viewmodel")
for rn in ("vm inner", "vm band in", "vm band out", "vm inner MV fails", "vm band in MV fails", "vm band out MV fails"):
    a = acc.get((rn, -1))
    if a:
        print(f"  {rn:21s}: frames {a['n']:2d} | c {mean(a['c']):.3f} | override {100 * mean(a['ovr']):5.1f}% "
              f"| ph {mean(a['g']):6.2f} / {mean(a['mv']):6.2f} / {mean(a['of']):6.2f}")
