"""Where do double images come from? SN2 skip pairs, head (+ rel_t rule). Effective per-pixel weights of the four
candidates in the final output (the rule mixes the MV-only blend and the full head blend). A pixel is a ghost candidate
when two candidates that show DIFFERENT content (|colour diff| > 10/255, 3x3 mean) both carry > 0.25 weight:
  MV pair   MV->A with MV->B   (the two sides put the MV-moved content at different t positions)
  OF pair   OF->A with OF->B
  MV / OF   the MV pair's blend with the OF pair's blend
Per region (viewmodel core, its 24-px band, fast / slow background; no alignment): share of ghost pixels by type, the
output error there and the error had the better single candidate of the mixed pair been used (what choosing would
save). Video: real | output | ghost map (red MV pair, green OF pair, blue MV/OF over the dimmed output).
  python diag_ghost.py <capture dir> <OF ckpt> <head ckpt> <out.mp4> [rel_t 0/1]"""
import os, sys, subprocess
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image
import imageio_ffmpeg
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import load_head_c2
from selector import rule_rel, luma

cap, ck, hk, outp = sys.argv[1:5]
use_rule = len(sys.argv) <= 5 or sys.argv[5] == "1"
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
TYPES = ("MV pair", "OF pair", "MV/OF")
REG = ("viewmodel", "vm band", "fast bg", "slow bg")
acc = {(t_, r): [0.0, 0.0, 0.0, 0.0] for t_ in TYPES for r in REG}                                                          
ff = imageio_ffmpeg.get_ffmpeg_exe()
proc = subprocess.Popen([ff, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{960 * 3}x540", "-r", "5", "-i", "-",
                         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", outp],
                        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
        diff = lambda x, y: F.avg_pool2d((x - y).abs().mean(1, keepdim=True), 3, 1, 1)[0, 0]
        mvb = (c[:, 0] * w[:, 0:1] + c[:, 1] * w[:, 1:2]) / (w[:, 0:1] + w[:, 1:2]).clamp_min(1e-6)
        ofb = (c[:, 2] * w[:, 2:3] + c[:, 3] * w[:, 3:4]) / (w[:, 2:3] + w[:, 3:4]).clamp_min(1e-6)
        w0, w1, w2_, w3 = w[0, 0], w[0, 1], w[0, 2], w[0, 3]
        g = {"MV pair": (torch.minimum(w0, w1) > 0.25) & (diff(c[:, 0], c[:, 1]) > 10 / 255),
             "OF pair": (torch.minimum(w2_, w3) > 0.25) & (diff(c[:, 2], c[:, 3]) > 10 / 255),
             "MV/OF": (torch.minimum(w0 + w1, w2_ + w3) > 0.25) & (diff(mvb, ofb) > 10 / 255)}
        gt = colour(f - 1).to(dev)[None]
        lg = luma(gt)[0, 0]
        e_out = (luma(out[..., :DH, :])[0, 0] - lg).abs() * 255
        e_c = [(luma(c[:, k, :, :DH])[0, 0] - lg).abs() * 255 for k in range(4)]
        e_mvb = (luma(mvb[..., :DH, :])[0, 0] - lg).abs() * 255
        e_ofb = (luma(ofb[..., :DH, :])[0, 0] - lg).abs() * 255
        single = {"MV pair": torch.minimum(e_c[0], e_c[1]), "OF pair": torch.minimum(e_c[2], e_c[3]),
                  "MV/OF": torch.minimum(e_mvb, e_ofb)}
        regs = regions(f - 1)
        for t_ in TYPES:
            gm = g[t_][:DH]
            for r in REG:
                s = gm & regs[r]
                a = acc[(t_, r)]
                a[0] += float(s.sum()); a[1] += float(regs[r].sum())
                a[2] += float(e_out[s].sum()); a[3] += float(single[t_][s].sum())
        o8 = (out[0, :, :DH].clamp(0, 1) * 255).permute(1, 2, 0).cpu().numpy().astype(np.float32)
        ov = o8 * 0.35
        for t_, col in (("MV/OF", (60, 90, 255)), ("OF pair", (60, 255, 60)), ("MV pair", (255, 60, 60))):
            mk_ = g[t_][:DH].cpu().numpy()
            ov[mk_] = np.float32(col)
        row = [(gt[0].clamp(0, 1) * 255).permute(1, 2, 0).cpu().numpy().astype(np.uint8), o8.astype(np.uint8), ov.astype(np.uint8)]
        row = [np.asarray(Image.fromarray(x).resize((960, 540), Image.BILINEAR)) for x in row]
        proc.stdin.write(np.concatenate(row, 1).tobytes())
proc.stdin.close(); proc.wait()
print(f"{hk} {'+ rel_t' if use_rule else 'alone'}: ghost candidates (two DIFFERENT candidates both > 0.25 in the output)")
print("  type      region      | share of region | out err there | single best of the pair | saving")
for t_ in TYPES:
    for r in REG:
        a = acc[(t_, r)]
        if a[0] > 0:
            print(f"  {t_:9s} {r:11s} | {100 * a[0] / max(a[1], 1):14.2f}% | {a[2] / a[0]:13.2f} | {a[3] / a[0]:23.2f} | {(a[2] - a[3]) / a[0]:6.2f}")
print("wrote", outp)
