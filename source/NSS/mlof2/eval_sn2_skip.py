"""MLOF2 on the Subnautica 2 NFRU capture, same protocol as harness/nfru_dx12/replay/skip_quality.py (REPLAY_SKIP):
real frames f-2 (A) and f (B) -> generated t = 0.5, written as <prefix>_<f:03d>_1.ppm so skip_quality.py scores it
against the skipped real frame f-1 exactly like the NFRU replay output.

  python eval_sn2_skip.py <ckpt> <capture dir> <out prefix> [first=0] [count=40]

Capture (NfruCaptureDx12.h, meta.txt): hudless/backbuffer 1920x1080 packed R10G10B10 (uint32), depth f32 render
1129x636 (row pitch 1132), mv f16 render res (x, y) in render px, depthInv 1 (reverse Z, z = near / d).
The game's MV of frame f covers f -> f-1; the pair (f-2, f) needs the chain f -> f-1 -> f-2 (same as training).
The capture flags hdr=1: the 10-bit colour is the game's output encoding (likely PQ), while the network was trained
on sRGB / gamma 2.2 looks -> a distribution shift worth keeping in mind when reading the numbers.
"""
import os
import sys
import numpy as np
import torch
from torch.nn import functional as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import MLOF2, warp
from data_v2 import chain_backward

ck, cap, pre = sys.argv[1], sys.argv[2], sys.argv[3]
first = int(sys.argv[4]) if len(sys.argv) > 4 else 0
count = int(sys.argv[5]) if len(sys.argv) > 5 else 40
dev = "cuda"
DW, DH, RW, RH, RP = 1920, 1080, 1129, 636, 1132
PH = 1088                                                                     

meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = {"near": float(p[p.index("near") + 1]), "mvs": (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))}


def colour(f):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    c = np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0
    return torch.from_numpy(c)


def depth(f):
    d = np.fromfile(os.path.join(cap, f"{f:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
    d = torch.from_numpy(d.copy()).clamp_min(1e-7)
    feat = (torch.log2(1.0 / d) / 16.0).clamp(0, 1)                                          
    return F.interpolate(feat[None, None], size=(DH, DW), mode="bilinear", align_corners=False)[0]


MV_MAX = 1000.0                                                                                     


def mv_one(f, sign, with_valid=False):
    """game MV of frame f (f -> f-1) as a display-px backward flow (2,DH,DW) (+ validity (1,DH,DW))."""
    m = np.fromfile(os.path.join(cap, f"{f:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < MV_MAX)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m))
    sx, sy = meta[f]["mvs"]
    m = m * torch.tensor([sx, sy]).view(2, 1, 1) * sign
    m = m * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    mode = os.environ.get("MV_UP", "bilinear")                                                       
    if mode.startswith("dilate"):                                                                                                
        d = np.fromfile(os.path.join(cap, f"{f:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
        dp = F.unfold(torch.from_numpy(d.copy())[None, None], 3, padding=1)                           
        idx = dp.argmax(1)                                                                                 
        mp = F.unfold(m[None], 3, padding=1).view(1, 2, 9, -1)
        m = torch.gather(mp, 2, idx.view(1, 1, 1, -1).expand(1, 2, 1, -1)).view(2, RH, RW)
        okp = F.unfold(ok[None].float(), 3, padding=1)
        ok = torch.gather(okp, 1, idx[:, None]).view(1, RH, RW)
    up = F.interpolate(m[None], size=(DH, DW), mode="nearest" if mode == "dilate_nearest" else "bilinear",
                       align_corners=None if mode == "dilate_nearest" else False)[0]
    if not with_valid:
        return up
    return up, (F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0])


def pad(x):
    return F.pad(x, (0, 0, 0, PH - DH), mode="replicate")


def psnr(a, b):
    return -10 * torch.log10(((a - b) ** 2)[..., 16:-16, 16:-16].mean()).item()


                                                             
a, b = colour(first)[None], colour(first + 1)[None]
p_pos = psnr(warp(a, mv_one(first + 1, 1.0)[None]), b)
p_neg = psnr(warp(a, mv_one(first + 1, -1.0)[None]), b)
sign = 1.0 if p_pos > p_neg else -1.0
print(f"MV sign check frame {first}->{first + 1}: +mv {p_pos:.2f} dB, -mv {p_neg:.2f} dB, no warp {psnr(a, b):.2f} dB -> sign {sign:+.0f}")

from model_v2 import PairFlow
sd = torch.load(ck, map_location=dev)
m = MLOF2()
if sd["pair.upd.64.inp.weight"].shape[1] != m.pair.upd["64"].inp.weight.shape[1]:
    m.pair = PairFlow(radius=(4, 3, 3, 2))                                                                    
m = m.to(dev).eval()
m.load_state_dict(sd)
if os.environ.get("FORCE_C"):
    m.pair.force_c = float(os.environ["FORCE_C"])
    print("gate forced to", m.pair.force_c)
f_prev = None
NH, NHC, prev_mv, prev_of, prev_v = None, None, None, None, None
FIX = os.environ.get("NFRU_FIX") == "1"
if os.environ.get("NFRU_HEAD_C"):                                                                                                  
    from nfru_head import NfruHeadC, NfruHeadC2
    NHC = (NfruHeadC2 if FIX else NfruHeadC)(arm_init=False).to(dev).eval()
    NHC.load_state_dict(torch.load(os.environ["NFRU_HEAD_C"], map_location=dev))
    print("NFRU head C", os.environ["NFRU_HEAD_C"], "accel", os.environ.get("ACCEL", "1"))
if os.environ.get("NFRU_HEAD"):
    from nfru_head import NfruHead
    NH = NfruHead(arm_init=False).to(dev).eval()
    NH.load_state_dict(torch.load(os.environ["NFRU_HEAD"], map_location=dev))
    print("NFRU head", os.environ["NFRU_HEAD"])
with torch.no_grad():
    for f in range(first + 2, first + count, 2):
        ca, cb = pad(colour(f - 2))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - 2))[None].to(dev), pad(depth(f))[None].to(dev)
        m1, v1 = mv_one(f, sign, True)
        m0, v0 = mv_one(f - 1, sign, True)
        mv = pad(chain_backward([m1, m0]))[None].to(dev)
        v0w = warp(v0[None], m1[None])[0]                                                                          
        mvv = pad((v1 * (v0w > 0.999).float()))[None].to(dev)
        frames, pair, _ = m(ca, da, cb, db, mv, mvv, [torch.tensor([0.5], device=dev)], f_a_prev=f_prev)
        f_prev = pair["f_ba"]                                                                              
        if NHC is not None:
            acc = os.environ.get("ACCEL", "1") == "1" and prev_mv is not None
            if FIX:
                frames[0]["color"] = NHC(torch.tensor([0.5], device=dev), pair["of_ba"], ca, cb, da, db, mv * mvv,
                                         prev_mv if acc else None, prev_of if acc else None, mvv, prev_v if acc else None)["color"]
            else:
                hc = NHC(torch.tensor([0.5], device=dev), pair["of_ba"], ca, cb, da, db, mv * mvv,
                         prev_mv if acc else None, prev_of if acc else None)
                frames[0]["color"] = hc["color"]
                if os.environ.get("DUMP_CAND"):                                                                    
                    np.save(f"{pre}w_{f:03d}.npy", hc["weights"][0, :, :DH].half().cpu().numpy())
                    for k in range(4):
                        im = (hc["cand"][0, k, :, :DH].clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
                        with open(f"{pre}cand{k}_{f:03d}_1.ppm", "wb") as fh:
                            fh.write(f"P6\n{DW} {DH}\n255\n".encode()); fh.write(im.tobytes())
            prev_mv, prev_of, prev_v = mv * mvv, pair["of_ba"], mvv                                                
        if NH is not None:                                                                                
            frames[0]["color"] = NH(torch.tensor([0.5], device=dev), pair, frames[0], ca, cb, da, db)["color"]
        out = frames[0]["color"][0, :, :DH].clamp(0, 1).cpu()
        img = (out * 255 + 0.5).clamp(0, 255).byte().permute(1, 2, 0).numpy()
        with open(f"{pre}_{f:03d}_1.ppm", "wb") as fh:
            fh.write(f"P6\n{DW} {DH}\n255\n".encode()); fh.write(img.tobytes())
        if os.environ.get("DUMP_FLOW_DIR"):                                                                              
            fl = F.interpolate(pair["f_ba"][:1], size=(PH, DW), mode="bilinear", align_corners=False) * 4.0
            fl = F.interpolate(fl[:, :, :DH], size=(RH, RW), mode="area")[0].cpu()
            sx, sy = meta[f]["mvs"]
            fl = fl * torch.tensor([RW / DW / sx, RH / DH / sy]).view(2, 1, 1) / sign
            od = os.environ["DUMP_FLOW_DIR"]
            fl.permute(1, 2, 0).numpy().astype(np.float16).tofile(os.path.join(od, f"{f:03d}_mv.bin"))
            np.zeros((RH, RW, 2), np.float16).tofile(os.path.join(od, f"{f - 1:03d}_mv.bin"))
        if os.environ.get("DUMP_PARTS"):                                                                                      
            fr = frames[0]
            wa, wb, v = warp(ca, fr["f_ta"])[0, :, :DH], warp(cb, fr["f_tb"])[0, :, :DH], fr["vis"][0, :, :DH]
            parts = {"wa": wa, "wb": wb, "pick": torch.where(v > 0.5, wa, wb), "vis": v.expand(3, -1, -1)}
            for nm, x in parts.items():
                im = (x.clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
                with open(f"{pre}{nm}_{f:03d}_1.ppm", "wb") as fh:
                    fh.write(f"P6\n{DW} {DH}\n255\n".encode()); fh.write(im.tobytes())
        c = pair["gate"][0]
        print(f"frame {f}: MV valid {mvv.mean().item()*100:.1f}%, max |MV| {mv.abs().amax().item():.0f} px, "
              f"c mean {c.mean().item():.3f}, c<0.5 {(c < 0.5).float().mean().item()*100:.1f}%")
