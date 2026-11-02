"""MV-pair ghosts: can a cheap rule pick the right side? SN2 skip pairs, head (+ rel_t rule) as diag_ghost.py. On the
MV-pair ghost pixels (MV->A and MV->B both > 0.25 in the output and showing different content) the oracle side is the
one closer to the real frame. Candidate rules, each a hard pick between MV->A and MV->B on those pixels only:
  head      the side with the larger head weight
  near/far  depth z-test: the side whose sampled depth (log2 1/d) is nearer / farther
  OF vote   the side closer in colour to the OF pair's blend (the OF never sees the MV, so it is an independent vote)
  OF+far    OF vote where it is decisive (sides differ by > 2x in distance to the OF blend), else far
Per region: share of pixels where the rule agrees with the oracle and the output error had it been applied.
  python diag_mvpick.py <capture dir> <OF ckpt> <head ckpt> [rel_t 0/1]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import load_head_c2
from selector import rule_rel, luma

cap, ck, hk = sys.argv[1:4]
use_rule = len(sys.argv) <= 4 or sys.argv[4] == "1"
dev = "cuda"
DW, DH, RW, RH, RP, PH = 1920, 1080, 1129, 636, 1132, 1088
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))
n_fr = max(meta) + 1
rawu = lambda f, n: np.fromfile(os.path.join(cap, f"{f:03d}_{n}.bin"), dtype=np.uint32).reshape(1080, 1920)


def colour(fr):
    a = rawu(fr, "hudless")
    return torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0)


def depth(fr):
    d = np.fromfile(os.path.join(cap, f"{fr:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
    d = torch.from_numpy(d.copy()).clamp_min(1e-7)
    return F.interpolate(((torch.log2(1.0 / d) / 16.0).clamp(0, 1))[None, None], size=(DH, DW), mode="bilinear", align_corners=False)[0]


def mv_one(fr):
    m = np.fromfile(os.path.join(cap, f"{fr:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < 1000)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m)) * torch.tensor(meta[fr]).view(2, 1, 1) * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    return F.interpolate(m[None], size=(DH, DW), mode="bilinear", align_corners=False)[0], F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0]


def regions(fg):
    nohud = torch.from_numpy(rawu(fg, "backbuffer") == rawu(fg, "hudless")).to(dev)
    d = torch.from_numpy(np.fromfile(os.path.join(cap, f"{fg:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW] > 0.1)
    core = F.interpolate(d.float()[None, None], size=(DH, DW), mode="nearest")[0, 0].to(dev) > 0.5
    band = (F.max_pool2d(core.float()[None, None], 49, 1, 24)[0, 0] > 0.5) & ~core
    mv = np.fromfile(os.path.join(cap, f"{fg:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    fast = torch.from_numpy(np.hypot(mv[..., 0], mv[..., 1]) > 20)
    fast = F.interpolate(fast.float()[None, None], size=(DH, DW), mode="nearest")[0, 0].to(dev) > 0.5
    return {"viewmodel": core & nohud, "vm band": band & nohud, "fast bg": fast & ~core & ~band & nohud,
            "slow bg": ~fast & ~core & ~band & nohud}


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = "fp"
RULES = ("now", "oracle", "head", "near", "far", "OF vote", "OF+far")
REG = ("viewmodel", "vm band", "fast bg", "slow bg")
acc = {r: {k: [0.0, 0.0] for k in RULES} for r in REG}                                      
npx = {r: 0.0 for r in REG}
prev = prev_mask = None
with torch.no_grad():
    for f in range(2, n_fr, 2):
        ca, cb = pad(colour(f - 2))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - 2))[None].to(dev), pad(depth(f))[None].to(dev)
        m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
        mv = pad(chain_backward([m1, m0]))[None].to(dev)
        mvv = pad(v1 * (warp(v0[None], m1[None])[0] > 0.999).float())[None].to(dev)
        pair = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        pm, po, pv = prev if prev is not None else (None, None, None)
        hc = head(torch.tensor([0.5], device=dev), of_q, ca, cb, da, db, mv * mvv, pm, po, mvv, pv,
                  conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
        w = hc["weights"]
        w2 = torch.cat((w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6), torch.zeros_like(w[:, 2:])), 1)
        out = hc["color"]
        if use_rule:
            to_prev = hc["tflows"][0] + 0.5 * warp(pm, hc["tflows"][0]) if (prev_mask is not None and pm is not None) else None
            out, mk = rule_rel(hc, prev=prev_mask if to_prev is not None else None, to_prev=to_prev)
            prev_mask = mk
            w = (1 - mk) * w2 + mk * w
        prev = (mv * mvv, of_q, mvv)
        c = hc["cand"]
        ma, mb = hc["tflows"][0], hc["tflows"][1]
        diff = lambda x, y: F.avg_pool2d((x - y).abs().mean(1, keepdim=True), 3, 1, 1)[0, 0]
        ghost = ((torch.minimum(w[0, 0], w[0, 1]) > 0.25) & (diff(c[:, 0], c[:, 1]) > 10 / 255))[:DH]
        ofb = 0.5 * (c[:, 2] + c[:, 3])                                                                                     
        dA, dB = warp(da, ma)[0, 0], warp(db, mb)[0, 0]                           
        eA, eB = diff(c[:, 0], ofb), diff(c[:, 1], ofb)
        picks = {"head": w[0, 0] >= w[0, 1], "near": dA >= dB, "far": dA < dB, "OF vote": eA <= eB}
        decisive = (torch.maximum(eA, eB) > 2 * torch.minimum(eA, eB))
        picks["OF+far"] = torch.where(decisive, picks["OF vote"], picks["far"])
        gt = colour(f - 1).to(dev)[None]
        lg = luma(gt)[0, 0]
        e_out = (luma(out[..., :DH, :])[0, 0] - lg).abs() * 255
        eAg = (luma(c[:, 0, :, :DH])[0, 0] - lg).abs() * 255
        eBg = (luma(c[:, 1, :, :DH])[0, 0] - lg).abs() * 255
        orc = eAg <= eBg
        regs = regions(f - 1)
        for r in REG:
            s = ghost & regs[r]
            npx[r] += float(s.sum())
            acc[r]["now"][1] += float(e_out[s].sum())
            acc[r]["oracle"][0] += float(s.sum()); acc[r]["oracle"][1] += float(torch.minimum(eAg, eBg)[s].sum())
            for k, p in picks.items():
                pk = p[:DH]
                acc[r][k][0] += float((pk == orc)[s].sum())
                acc[r][k][1] += float(torch.where(pk, eAg, eBg)[s].sum())
print(f"{hk} {'+ rel_t' if use_rule else 'alone'}: MV-pair ghost pixels, hard pick between MV->A and MV->B")
print("  region      |  px share | " + " | ".join(f"{k:>14s}" for k in RULES))
for r in REG:
    n = max(npx[r], 1)
    cells = []
    for k in RULES:
        a = acc[r][k]
        cells.append(f"{a[1] / n:6.2f}" + ("        " if k == "now" else f" ({100 * a[0] / n:4.0f}%)"))
    print(f"  {r:11s} | {npx[r] / 1e6:7.2f}M | " + " | ".join(f"{x:>14s}" for x in cells))
print("  cells: luma err on those pixels (8-bit) and (share agreeing with the oracle side)")
