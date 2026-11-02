"""Inside the variant-c NFRU head on one SN2 skip frame: candidates, blend weights, splat holes, MV validity and
the acceleration term, with acceleration on and off. Writes a labelled sheet for a box and prints box statistics.
  python diag_sn2_c.py <mlof2 ckpt> <head ckpt> <capture dir> <frame f (even)> <y0,y1,x0,x1> <out.png>"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image, ImageDraw
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import NfruHeadC, splat_t, up4

ck, hk, cap, f, box, outp = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], sys.argv[6]
y0, y1, x0, x1 = (int(v) for v in box.split(","))
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


def pad(x):
    return F.pad(x, (0, 0, 0, PH - DH), mode="replicate")


def pair_inputs(fr):
    m1, v1 = mv_one(fr); m0, v0 = mv_one(fr - 1)
    mv = chain_backward([m1, m0]); mvv = v1 * (warp(v0[None], m1[None])[0] > 0.999).float()
    return pad(mv)[None].to(dev), pad(mvv)[None].to(dev)


sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
H = NfruHeadC(arm_init=False).to(dev).eval(); H.load_state_dict(torch.load(hk, map_location=dev))
with torch.no_grad():
    ld = lambda fr: (pad(colour(fr))[None].to(dev), pad(depth(fr))[None].to(dev))
    cp, dp = ld(f - 4); ca, da = ld(f - 2); cb, db = ld(f)
    fp_, fa, fb = m.enc(cp, dp), m.enc(ca, da), m.enc(cb, db)
    mv_prev, mvv_prev = pair_inputs(f - 2)
    pp = m.pair(fp_, fa, mv_prev, mvv_prev, cp, ca)
    mv, mvv = pair_inputs(f)
    pair = m.pair(fa, fb, mv, mvv, ca, cb)
    t = torch.tensor([0.5], device=dev)
    rows, stats = [], {}
    for acc in (False, True):
        mv_ap, of_ap = (mv_prev * mvv_prev, pp["of_ba"]) if acc else (None, None)
        out = H(t, pair["of_ba"], ca, cb, da, db, mv * mvv, mv_ap, of_ap)
        of = up4(pair["of_ba"], *ca.shape[-2:])
        mv_bp = None if mv_ap is None else mv * mvv + warp(mv_ap, mv * mvv)
        _, _, hole_mv = splat_t(mv * mvv, db, t, mv_bp)
        _, _, hole_of = splat_t(of, db, t, None if of_ap is None else of + warp(up4(of_ap, *ca.shape[-2:]), of))
        w = out["weights"][0]
        tag = "accel" if acc else "linear"
        sl = (slice(y0, y1), slice(x0, x1))
        stats[tag] = {"weights mvA/mvB/ofA/ofB": [round(float(w[k][sl].mean()), 3) for k in range(4)],
                      "hole_mv": round(float(hole_mv[0, 0][sl].mean()), 3), "hole_of": round(float(hole_of[0, 0][sl].mean()), 3)}
        if acc:
            accel = (mv_bp - 2 * mv * mvv)[0].norm(dim=0)
            stats[tag]["|accel| px median/p90"] = [round(float(accel[sl].median()), 1), round(float(accel[sl].flatten().quantile(0.9)), 1)]
            stats[tag]["MV valid (pair / prev)"] = [round(float(mvv[0, 0][sl].mean()), 3), round(float(mvv_prev[0, 0][sl].mean()), 3)]
            stats[tag]["|MV| px median"] = round(float((mv * mvv)[0].norm(dim=0)[sl].median()), 1)
        gt = pad(colour(f - 1))[None].to(dev)
        tiles = [("GT f-1", gt[0]), ("out " + tag, out["color"][0])] + [(n, out["cand"][0, k]) for k, n in enumerate(("cand mvA", "cand mvB", "cand ofA", "cand ofB"))]
        wv = w[[0, 1, 2]] * 0 + torch.stack((w[0] + w[1], w[2] + w[3], hole_mv[0, 0]), 0)                                                     
        tiles += [("R=MV G=OF B=hole_mv", wv), ("hole_of", hole_of[0].expand(3, -1, -1))]
        ims = []
        for name, x in tiles:
            im = Image.fromarray((x[:, y0:y1, x0:x1].clamp(0, 1) * 255).byte().permute(1, 2, 0).cpu().numpy()).resize((320, int(320 * (y1 - y0) / (x1 - x0))))
            ImageDraw.Draw(im).rectangle((0, 0, 7 * len(name) + 8, 12), fill=(0, 0, 0)); ImageDraw.Draw(im).text((2, 0), name, fill=(255, 255, 0))
            ims.append(np.asarray(im))
        rows.append(np.concatenate(ims, 1))
    Image.fromarray(np.concatenate(rows, 0)).save(outp)
    for k, v in stats.items():
        print(f"f{f} box {box} {k}: {v}")
