"""Is MLOF2's OF right on the real game? SN2 skip pairs (A = f-2, B = f), OF = pair['of_ba'] (pure OF, B -> A).
1) Background (no viewmodel, valid MV): |OF - MV| (end-point error vs the game MV) by |MV| bin, and the OF/MV
   magnitude ratio.  2) Photometric: mean |luma(B) - luma(A pulled by flow)| for OF and for the MV, background and
   viewmodel (depth > 0.1, screen-locked; its MV is unreliable when it animates).  3) Flow images for given frames.
  python diag_sn2_of.py <ckpt> <capture dir> <out dir> [viz frames, e.g. 16,20]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward

ck, cap, outd = sys.argv[1], sys.argv[2], sys.argv[3]
viz = [int(v) for v in sys.argv[4].split(",")] if len(sys.argv) > 4 and sys.argv[4] else []
GAP = int(os.environ.get("GAP", "2"))
CROP = int(os.environ.get("CROP", "0"))                                                                                                                                                      
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


def flow_img(f, scale):
    """HSV-like colouring: hue = direction, value = magnitude / scale."""
    mag = np.hypot(f[0], f[1]); ang = (np.arctan2(f[1], f[0]) + np.pi) / (2 * np.pi)
    h = ang * 6; i = np.floor(h).astype(int) % 6; fr = h - np.floor(h); v = np.clip(mag / scale, 0, 1)
    p, q, t = 0 * v, v * (1 - fr), v * fr
    r = np.choose(i, [v, q, p, p, t, v]); g = np.choose(i, [t, v, v, q, p, p]); b = np.choose(i, [p, p, t, v, v, q])
    return (np.stack([r, g, b], -1) * 255).astype(np.uint8)


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
RIFE = ck == "rife"                                                                                              
if RIFE:
    sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
    from train_log.IFNet_HDv3 import IFNet
    rife = IFNet().to(dev).eval()
    rsd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
    rife.load_state_dict({k.replace("module.", ""): v for k, v in rsd.items()}, strict=False)
else:
    sd = torch.load(ck, map_location=dev)
    m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
bins = [0, 8, 32, 64, 128, 256, 1e9]
epe = {i: [] for i in range(len(bins) - 1)}; rat = {i: [] for i in range(len(bins) - 1)}
lvl_of = {}
lvl_epe = {}                                                                                         
epe_t = {i: [] for i in range(len(bins) - 1)}; rat_t = {i: [] for i in range(len(bins) - 1)}
ph = {k: [] for k in ("bg OF", "bg MV", "bg none", "vm OF", "vm MV", "vm none")}
luma = lambda c: (c * torch.tensor([.299, .587, .114], device=c.device).view(3, 1, 1)).sum(0) * 255
with torch.no_grad():
    for f in range(2, 40, 2):
        ca, cb = pad(colour(f - GAP))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - GAP))[None].to(dev), pad(depth(f))[None].to(dev)
        mvs = mvvs = None
        if os.environ.get("SEED") == "1":                                                             
            if GAP == 2:
                m1s, v1s = mv_one(f); m0s, v0s = mv_one(f - 1)
                mvs = chain_backward([m1s, m0s]); mvvs = v1s * (warp(v0s[None], m1s[None])[0] > 0.999).float()
            else:
                mvs, mvvs = mv_one(f)
            mvs, mvvs = pad(mvs)[None].to(dev), pad(mvvs)[None].to(dev)

        def run_of(y0, x0, hh, ww):                                                                   
            sl = lambda t: t[..., y0:y0 + hh, x0:x0 + ww]
            if RIFE:                                                                                                  
                                                                                                                       
                                                                        
                fl, _, _ = rife(torch.cat((sl(ca), sl(cb)), 1), 0.5, [16, 8, 4, 2, 1])
                ba = [x[0, :2] - x[0, 2:4] for x in fl]
                if hh == PH:
                    lvl_of.clear(); lvl_of.update({lv: ba[i][:, :DH] for i, lv in enumerate((64, 32, 16, 8, 4))})
                return ba[-1]
            fa, fb = m.enc(sl(ca), sl(da)), m.enc(sl(cb), sl(db))                
            seed = m.pair.make_seed(sl(mvs), sl(mvvs), *fa[16].shape[-2:]) if mvs is not None else None
            outs = m.pair.of_forward(fa, fb, sl(ca), sl(cb), seed)
            up = lambda lv: (outs[4]["of_full"][0] if lv == 4 and "of_full" in outs[4] else
                             F.interpolate(outs[lv]["of"][:1], size=(hh, ww), mode="bilinear", align_corners=False)[0] * float(lv))
            if hh == PH:
                lvl_of.clear(); lvl_of.update({lv: up(lv)[:, :DH] for lv in (64, 32, 16, 8, 4) if lv in outs})
            return up(4)

        if CROP:                                                                                                  
            acc = torch.zeros(2, PH, DW, device=dev); wsum = torch.zeros(1, PH, DW, device=dev)
            yy = torch.arange(CROP, device=dev, dtype=torch.float32)
            win = (torch.minimum(yy + 1, CROP - yy)[:, None] * torch.minimum(yy + 1, CROP - yy)[None, :])[None]
            for y0 in np.linspace(0, PH - CROP, 4).round().astype(int):
                for x0 in np.linspace(0, DW - CROP, 6).round().astype(int):
                    acc[:, y0:y0 + CROP, x0:x0 + CROP] += run_of(int(y0), int(x0), CROP, CROP) * win
                    wsum[:, y0:y0 + CROP, x0:x0 + CROP] += win
            of = (acc / wsum)[:, :DH]
        else:
            of = run_of(0, 0, PH, DW)[:, :DH]
        m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
        if GAP == 2:
            mv = chain_backward([m1, m0]).to(dev); mvv = (v1 * (warp(v0[None], m1[None])[0] > 0.999).float())[0].to(dev) > 0.5
        else:
            mv = m1.to(dev); mvv = v1[0].to(dev) > 0.5
        vm = torch.from_numpy(rawdepth(f) > 0.1).float()
        vm = (F.interpolate(vm[None, None], size=(DH, DW), mode="nearest")[0, 0] > 0.5).to(dev)
        A, B = ca[0, :, :DH], cb[0, :, :DH]
        ones = torch.ones(1, 1, DH, DW, device=dev)
        inb = lambda fl: warp(ones, fl[None])[0, 0] > 0.999
        bg = mvv & ~vm & inb(mv) & inb(of)
        e = (of - mv).norm(dim=0); mm = mv.norm(dim=0); om = of.norm(dim=0)
        lB = luma(B); gx = F.pad((lB[:, 2:] - lB[:, :-2]).abs(), (1, 1)); gy = F.pad((lB[2:] - lB[:-2]).abs(), (0, 0, 1, 1))
        tex = F.max_pool2d((gx + gy)[None, None], 9, 1, 4)[0, 0] > 12                                         
        for i in range(len(bins) - 1):
            s = bg & (mm >= bins[i]) & (mm < bins[i + 1])
            if s.sum() > 500:
                epe[i].append(float(e[s].median())); rat[i].append(float(om[s].median() / mm[s].median().clamp_min(1e-3)))
            for lv, fl in lvl_of.items():
                if s.sum() > 500:
                    lvl_epe.setdefault((lv, i), []).append(float((fl - mv).norm(dim=0)[s].median()))
            st = s & tex
            if st.sum() > 500:
                epe_t[i].append(float(e[st].median())); rat_t[i].append(float(om[st].median() / mm[st].median().clamp_min(1e-3)))
        vmk_l = vm & mvv & inb(mv)
        vmf = vm.float()[None, None]
        grown = F.max_pool2d(vmf, 17, 1, 8)[0, 0] > 0.5
        shrunk = -F.max_pool2d(-vmf, 17, 1, 8)[0, 0] > 0.5
        regions = {"vm inner": vm & shrunk, "vm band in": vm & ~shrunk, "vm band out": grown & ~vm}
        for rn, rm in regions.items():
            rm = rm & mvv & inb(mv)
            if rm.sum() > 300:
                for lv, fl in lvl_of.items():
                    lvl_epe.setdefault((lv, rn), []).append(float((fl - mv).norm(dim=0)[rm].median()))
                err_of = (luma(B) - luma(warp(A[None], of[None])[0])).abs()
                err_mv = (luma(B) - luma(warp(A[None], mv[None])[0])).abs()
                err_0 = (luma(B) - luma(A)).abs()
                for nm, er in (("OF", err_of), ("MV", err_mv), ("none", err_0)):
                    lvl_epe.setdefault((nm, "ph " + rn), []).append(float(er[rm].mean()))
        if vmk_l.sum() > 500:                                                                                              
            for lv, fl in lvl_of.items():
                lvl_epe.setdefault((lv, "vm"), []).append(float((fl - mv).norm(dim=0)[vmk_l].median()))
                lvl_epe.setdefault((lv, "vm|of|"), []).append(float(fl.norm(dim=0)[vmk_l].median()))
            lvl_epe.setdefault((0, "vm|mv|"), []).append(float(mm[vmk_l].median()))
            lvl_epe.setdefault((0, "bg|mv|"), []).append(float(mm[bg].median()) if bg.any() else 0.0)
        lb = luma(B)
        for name, fl in (("OF", of), ("MV", mv), ("none", torch.zeros_like(of))):
            err = (lb - luma(warp(A[None], fl[None])[0])).abs()
            ph[f"bg {name}"].append(float(err[bg].mean()))
            vmk = vm & inb(of) & inb(mv)
            if vmk.sum() > 500: ph[f"vm {name}"].append(float(err[vmk].mean()))
        if f in viz:
            sc = float(torch.quantile(mm[mvv].flatten()[::50], 0.95)) if mvv.any() else 50.0
            row = [(B.permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8), flow_img(mv.cpu().numpy(), sc),
                   flow_img(of.cpu().numpy(), sc), (np.clip((e / 50).cpu().numpy(), 0, 1)[..., None] * 255).repeat(3, -1).astype(np.uint8)]
            Image.fromarray(np.concatenate([np.asarray(Image.fromarray(x).resize((640, 360))) for x in row], 1)).save(os.path.join(outd, f"of_vs_mv_f{f}.png"))
print("background (valid MV, no viewmodel): OF vs game MV by |MV| (display px, 2-frame pairs)")
for i in range(len(bins) - 1):
    if epe[i]:
        print(f"  |MV| {bins[i]:>4.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf':>4}: frames {len(epe[i]):2d} | median |OF-MV| {np.mean(epe[i]):7.2f} px | |OF|/|MV| {np.mean(rat[i]):5.2f}")
print("  textured pixels only (an edge within 4 px):")
for i in range(len(bins) - 1):
    if epe_t[i]:
        print(f"  |MV| {bins[i]:>4.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf':>4}: frames {len(epe_t[i]):2d} | median |OF-MV| {np.mean(epe_t[i]):7.2f} px | |OF|/|MV| {np.mean(rat_t[i]):5.2f}")
if lvl_epe:
    print("per OF level (each level's flow upsampled to display px): median |OF - MV| by |MV| bin")
    for i in range(len(bins) - 1):
        row = [f"1/{lv}: {np.mean(lvl_epe[(lv, i)]):7.2f}" for lv in (64, 32, 16, 8, 4) if (lv, i) in lvl_epe]
        if row:
            print(f"  |MV| {bins[i]:>4.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf':>4}: " + " | ".join(row))
if (64, "vm") in lvl_epe or (4, "vm") in lvl_epe:
    print(f"viewmodel (median |MV| there {np.mean(lvl_epe[(0, 'vm|mv|')]):.1f} px, background {np.mean(lvl_epe[(0, 'bg|mv|')]):.1f} px):")
    print("  |OF - MV| " + " | ".join(f"1/{lv}: {np.mean(lvl_epe[(lv, 'vm')]):6.2f}" for lv in (64, 32, 16, 8, 4) if (lv, "vm") in lvl_epe))
    print("  |OF|      " + " | ".join(f"1/{lv}: {np.mean(lvl_epe[(lv, 'vm|of|')]):6.2f}" for lv in (64, 32, 16, 8, 4) if (lv, "vm|of|") in lvl_epe))
if (4, "vm inner") in lvl_epe:
    print("viewmodel split (8 px from its edge): |OF - MV| per level | photometric OF / MV / none")
    for rn in ("vm inner", "vm band in", "vm band out"):
        if (4, rn) in lvl_epe:
            print(f"  {rn:11s} " + " | ".join(f"1/{lv}: {np.mean(lvl_epe[(lv, rn)]):6.2f}" for lv in (64, 32, 16, 8, 4)
                                            if (lv, rn) in lvl_epe) +
                  "   ph " + " / ".join(f"{np.mean(lvl_epe[(nm, 'ph ' + rn)]):5.2f}" for nm in ("OF", "MV", "none")))
print("photometric |luma(B) - luma(A pulled by flow)| (8-bit):")
for k, v in ph.items():
    print(f"  {k:8s} {np.mean(v):6.2f}")
