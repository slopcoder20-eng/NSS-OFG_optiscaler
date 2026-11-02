"""Deployed path (variant c, NfruHeadC2): SN2 skip pairs A = f-2, B = f -> generated t = 0.5, scored against the real
skipped frame f-1. Per region: mean |luma(out) - luma(GT)| (8-bit) of the final blend, of each candidate
(MV->A, MV->B, OF->A, OF->B), of the per-pixel best candidate (oracle), and the blend weight on the two MV candidates.
Regions: viewmodel inner / band in / band out (8 px), background by |MV| (chained f -> f-2).
  python diag_sn2_head.py <mlof2 ckpt> <head ckpt> <capture dir>   (env ACCEL=0 to switch the acceleration off)"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import NfruHeadC2, load_head_c2

ck, hk, cap = sys.argv[1], sys.argv[2], sys.argv[3]
ACCEL = os.environ.get("ACCEL", "1") == "1"
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
head = load_head_c2(hk, dev)
head.talign = os.environ.get("TALIGN", "splat")                                                                       
if head.talign == "kpn":                                                                                                
    from talign_kpn import TAlignKPN
    head.talign_net = TAlignKPN().to(dev).eval()
    if os.environ.get("TALIGN_CKPT"):
        head.talign_net.load_state_dict(torch.load(os.environ["TALIGN_CKPT"], map_location=dev))
bins = [0, 8, 32, 64, 128, 256, 1e9]
acc = {}
NAMES = ("final", "MV->A", "MV->B", "OF->A", "OF->B", "best of 4")
prev_mv = prev_of = prev_v = None
with torch.no_grad():
    for f in range(2, 40, 2):
        ca, cb = pad(colour(f - 2))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - 2))[None].to(dev), pad(depth(f))[None].to(dev)
        gt = colour(f - 1).to(dev)
        m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
        mv = pad(chain_backward([m1, m0]))[None].to(dev)
        mvv = pad(v1 * (warp(v0[None], m1[None])[0] > 0.999).float())[None].to(dev)
        fa, fb = m.enc(ca, da), m.enc(cb, db)
        pair = m.pair(fa, fb, mv, mvv, ca, cb)
        acc_on = ACCEL and prev_mv is not None
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        hc = head(torch.tensor([0.5], device=dev), of_q, ca, cb, da, db, mv * mvv,
                  prev_mv if acc_on else None, prev_of if acc_on else None, mvv, prev_v if acc_on else None,
                  conf_q=pair["conf"][:1])
        prev_mv, prev_of, prev_v = mv * mvv, of_q, mvv
        lg = luma(gt)
        errs = [(luma(hc["color"][0, :, :DH]) - lg).abs()] + [(luma(hc["cand"][0, k, :, :DH]) - lg).abs() for k in range(4)]
        errs.append(torch.stack(errs[1:5]).amin(0))
        wmv = (hc["weights"][0, 0] + hc["weights"][0, 1])[:DH]
        vm = torch.from_numpy(rawdepth(f) > 0.1).float()
        vm = (F.interpolate(vm[None, None], size=(DH, DW), mode="nearest")[0, 0] > 0.5).to(dev)
        vmf = vm.float()[None, None]
        grown = F.max_pool2d(vmf, 17, 1, 8)[0, 0] > 0.5
        shrunk = -F.max_pool2d(-vmf, 17, 1, 8)[0, 0] > 0.5
        mm = mv[0, :, :DH].norm(dim=0); valid = mvv[0, 0, :DH] > 0.5
        mg = int(os.environ.get("MARGIN", "0"))                                                                   
        if mg:
            inner = torch.zeros_like(valid); inner[mg:DH - mg, mg:DW - mg] = True; valid = valid & inner
        regions = {"vm inner": vm & shrunk, "vm band in": vm & ~shrunk, "vm band out": grown & ~vm}
        for i in range(len(bins) - 1):
            regions[f"bg |MV| {bins[i]:.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf'}"] = ~grown & valid & (mm >= bins[i]) & (mm < bins[i + 1])
        for rn, rm in regions.items():
            if rm.sum() > 500:
                a = acc.setdefault(rn, {"e": [[] for _ in NAMES], "w": []})
                for k, er in enumerate(errs):
                    a["e"][k].append(float(er[rm].mean()))
                a["w"].append(float(wmv[rm].mean()))
import nfru_head as _nh
if _nh.INVERT_STATS:
    print(f"invert_t: first start unresolved on {100 * sum(_nh.INVERT_STATS) / len(_nh.INVERT_STATS):.1f}% of target pixels "
          f"(rings {os.environ.get('INV_RINGS', '8,24')}, iters {os.environ.get('INV_ITERS', '6')})")
print(f"{ck} + head {hk}  accel {ACCEL} talign {head.talign}: mean |luma - GT| (8-bit) vs the skipped real frame; weight on the MV candidates")
print("  region            frames | " + " | ".join(f"{n:>9s}" for n in NAMES) + " | w(MV)")
for rn, a in acc.items():
    print(f"  {rn:17s} {len(a['w']):5d}  | " + " | ".join(f"{np.mean(v):9.2f}" for v in a["e"]) + f" | {np.mean(a['w']):.2f}")
