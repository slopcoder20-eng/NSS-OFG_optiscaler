"""Multi-frame generation on the SN2 capture: real frames A = f-G and B = f, generated t = k/G (k = 1..G-1) scored
against the real frames f-G+k (G = 2 -> 2x, 3 -> 3x, 4 -> 4x). The OF runs once per pair, the head once per t.
Outputs per t: the head ('head'), its two game-MV candidates only ('mv only'), and the rule 'MV by default, the
full head where |MV->A - MV->B| > thr' ('overwrite'); plus the plain cross-fade ('blend').
Error: mean |luma| (8-bit) vs the real frame, after one integer global alignment of the real frame to each output
(the camera's turn rate changes between real frames; viewmodel compared unshifted), HUD pixels masked; regions as in
sn2_vs_fsr4.py. Temporal: mean |(o_k - o_k-1) - (g_k - g_k-1)| over the sequence real A, generated..., real B.
  python mfg_eval.py <capture dir> <OF ckpt> <head ckpt> <talign> <G> [thr=0.08]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import load_head_c2
from selector import fuse_flow, mv_only as sel_mv_only

cap, ck, hk, ta, G = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
thr = float(sys.argv[6]) if len(sys.argv) > 6 else 0.08
dev = "cuda"
DW, DH, RW, RH, RP, PH = 1920, 1080, 1129, 636, 1132, 1088
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))
n_fr = max(meta) + 1
rawu = lambda f, n: np.fromfile(os.path.join(cap, f"{f:03d}_{n}.bin"), dtype=np.uint32).reshape(1080, 1920)
to8 = lambda a: np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.float32)
upm = lambda m: np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((1920, 1080), Image.NEAREST)) > 0
luma = lambda a: a @ np.float32([.299, .587, .114])


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


def align(out, gt):
    def l(a, k): return (a @ np.float32([.299, .587, .114])).reshape(1080 // k, k, 1920 // k, k).mean((1, 3))
    a, b = l(out, 4), l(gt, 4)
    a = a - a.mean(); b = b - b.mean()
    c = np.fft.irfft2(np.fft.rfft2(a) * np.conj(np.fft.rfft2(b)), a.shape)
    dy, dx = np.unravel_index(np.argmax(c), c.shape)
    dy = dy - a.shape[0] if dy > a.shape[0] // 2 else dy; dx = dx - a.shape[1] if dx > a.shape[1] // 2 else dx
    best = None
    for ry in range(dy * 4 - 3, dy * 4 + 4):
        for rx in range(dx * 4 - 3, dx * 4 + 4):
            e = np.abs(l(out, 8) - l(np.roll(gt, (ry, rx), (0, 1)), 8))[4:-4, 8:-8].mean()
            if best is None or e < best[0]: best = (e, ry, rx)
    return best[1], best[2]


def regions(fg):
    nohud = rawu(fg, "backbuffer") == rawu(fg, "hudless")
    d = np.fromfile(os.path.join(cap, f"{fg:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW] > 0.1
    core = upm(d)
    k = 24; dd = np.pad(core, k).astype(np.uint8); ii = dd.cumsum(0).cumsum(1)
    band = (ii[2 * k:, 2 * k:] - ii[:-2 * k, 2 * k:] - ii[2 * k:, :-2 * k] + ii[:-2 * k, :-2 * k])[:1080, :1920] > 0
    mv = np.fromfile(os.path.join(cap, f"{fg:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    fast = upm(np.hypot(mv[..., 0], mv[..., 1]) > 20)
    return core, band, fast, nohud


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev)
head.talign = ta
REG = ("viewmodel", "vm edge", "fast bg", "slow bg", "all")
NAMES = ("head", "mv only", "overwrite", "fused", "blend")
acc = {(n, k): {r: [] for r in REG} for n in NAMES for k in range(1, G)}
temp = {n: [] for n in NAMES}
area = []
prev = prevf = None
with torch.no_grad():
    for f in range(G, n_fr, G):
        ca, cb = pad(colour(f - G))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - G))[None].to(dev), pad(depth(f))[None].to(dev)
        links = [mv_one(g) for g in range(f, f - G, -1)]                                              
        mv = pad(chain_backward([l[0] for l in links]))[None].to(dev)
        accf, v = links[0][0][None], links[0][1][None]                                                                     
        for mvl, vl in links[1:]:
            v = v * (warp(vl[None], accf) > 0.999).float()
            accf = accf + warp(mvl[None], accf)
        mvv = pad(v[0])[None].to(dev)
        pair = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        pm, po, pv = prev if prev is not None else (None, None, None)
        of_full = of_q if of_q.shape[-2:] == ca.shape[-2:] else             F.interpolate(of_q, size=ca.shape[-2:], mode="bilinear", align_corners=False) * (ca.shape[-1] / of_q.shape[-1])
        fused, _ = fuse_flow(ca, cb, mv * mvv, mvv, of_full)                                                          
        ones = torch.ones_like(mvv)
        fpm = prevf if prevf is not None else None
        seq = {n: [to8(rawu(f - G, "hudless"))] for n in NAMES}
        gts = [to8(rawu(f - G, "hudless"))]
        for k in range(1, G):
            t = torch.tensor([k / G], device=dev)
            hc = head(t, of_q, ca, cb, da, db, mv * mvv, pm, po, mvv, pv, conf_q=pair["conf"][:1])
            w2 = hc["weights"][:, :2]; w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
            mvonly = (w2[:, :, None] * hc["cand"][:, :2]).sum(1)
            dis = F.avg_pool2d((hc["cand"][:, 0] - hc["cand"][:, 1]).abs().mean(1, keepdim=True), 3, 1, 1)
            mk = F.avg_pool2d(F.max_pool2d((dis > thr).float(), 9, 1, 4), 5, 1, 2)
            over = (1 - mk) * mvonly + mk * hc["color"]
            area.append(float((mk[0, 0, :DH] > 0.5).float().mean()))
            hf = head(t, of_q, ca, cb, da, db, fused, fpm, po, ones, pv if fpm is not None else None, conf_q=pair["conf"][:1])
            outs = {"head": hc["color"], "mv only": mvonly, "overwrite": over, "fused": sel_mv_only(hf),
                    "blend": (1 - k / G) * ca + (k / G) * cb}
            fg = f - G + k
            gt0 = to8(rawu(fg, "hudless"))
            gts.append(gt0)
            core, band, fast, nohud = regions(fg)
            for n, o in outs.items():
                o8 = (o[0, :, :DH].clamp(0, 1) * 255 + 0.5).floor().permute(1, 2, 0).cpu().numpy()
                seq[n].append(o8)
                sy, sx = align(o8, gt0)
                valid = np.zeros((1080, 1920), bool); valid[max(sy, 0):1080 + min(sy, 0), max(sx, 0):1920 + min(sx, 0)] = True
                gt = np.where(core[..., None], gt0, np.roll(gt0, (sy, sx), (0, 1)))
                regs = {"viewmodel": core & nohud, "vm edge": band & ~core & nohud & valid,
                        "fast bg": fast & ~band & nohud & valid, "slow bg": ~fast & ~band & nohud & valid}
                regs["all"] = regs["viewmodel"] | regs["vm edge"] | regs["fast bg"] | regs["slow bg"]
                e = np.abs(luma(o8) - luma(gt))
                for r in REG:
                    acc[(n, k)][r].append(float(e[regs[r]].mean()) if regs[r].any() else np.nan)
        gts.append(to8(rawu(f, "hudless")))
        for n in NAMES:
            s = seq[n] + [gts[-1]]
            temp[n].append(float(np.mean([np.abs(luma(s[i] - s[i - 1]) - luma(gts[i] - gts[i - 1])).mean() for i in range(1, len(s))])))
        prev = (mv * mvv, of_q, mvv)
        prevf = fused
print(f"G = {G} ({G}x): real f-{G} and f, generated t = k/{G}; {len(temp['head'])} pairs; overwrite thr {thr}, "
      f"overwritten area {100 * np.mean(area):.1f}%; mean |luma error| (8-bit), output-aligned real frame")
print(f"{'':16s}{'t':>6s}" + "".join(f"{r:>11s}" for r in REG))
for n in NAMES:
    for k in range(1, G):
        print(f"{n:16s}{k}/{G:<4d}" + "".join(f"{np.nanmean(acc[(n, k)][r]):11.2f}" for r in REG))
print("temporal: mean |(o_k - o_k-1) - (g_k - g_k-1)| luma over real A, generated..., real B (lower = steadier)")
for n in NAMES:
    print(f"  {n:16s} {np.mean(temp[n]):7.3f}")
