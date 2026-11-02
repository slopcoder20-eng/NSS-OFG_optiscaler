"""SN2 MV-pair ghost at fast yaw: is the screen-linear t-trajectory of the game MV wrong for a camera ROTATION?
For the skip pair (A = f-2, B = f, real frame f-1 at t = 0.5) and static background (MV ~ camera reprojection), each
B pixel x (depth d) is reprojected with the fitted cameras (meta_fit.txt, from camfit.py: clip = VP @ world, VP stored
column-major, reverse-Z) into A and into the REAL frame f-1. Compared at t:
  linear    x + (1 - t) * mv(x)             (what invert_t does without acceleration; mv = 2-hop game MV B->A)
  camera    projection of x with VP(f-1)    (the truth for static content)
  clip-lerp projection with lerp(VP(f-2), VP(f), t)   (what a game could do: the frame at t has no camera)
First a convention check: camera reprojection B -> A vs the game MV (must be ~0 px on background).
  python diag_traj_camera.py <capture dir> [frames f ...]"""
import sys, os, itertools
import numpy as np
import torch
from torch.nn import functional as F

cap = sys.argv[1]
frames = [int(a) for a in sys.argv[2:]] or [8, 16, 22, 26, 30, 32]
RW, RH, RP = 1129, 636, 1132
dev = "cuda"


def meta(fn):
    m = {}
    for line in open(os.path.join(cap, fn)):
        p = line.split()
        if p[0] != "frame":
            continue
        f = int(p[1])
        if p[2] == "viewProjection":
            m.setdefault(f, {})["vp"] = np.array([float(x) for x in p[3:19]])
        elif p[2] == "display":
            kv = dict(zip(p[2::2], p[3::2]))
            m.setdefault(f, {})["mvs"] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))
    return m


MF = meta("meta_fit.txt")
DT = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        DT[int(p[1])] = float(p[p.index("dt") + 1])                                        
mvr = lambda f: torch.from_numpy(np.fromfile(os.path.join(cap, f"{f:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)).permute(2, 0, 1).to(dev) * torch.tensor(MF[f]["mvs"], device=dev).view(2, 1, 1)
dep = lambda f: torch.from_numpy(np.fromfile(os.path.join(cap, f"{f:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW].copy()).to(dev)
yy, xx = torch.meshgrid(torch.arange(RH, device=dev, dtype=torch.float32), torch.arange(RW, device=dev, dtype=torch.float32), indexing="ij")


def sample(img, fx, fy):
    g = torch.stack((2 * (xx + fx) / (RW - 1) - 1, 2 * (yy + fy) / (RH - 1) - 1), -1)[None]
    return F.grid_sample(img[None], g, mode="bilinear", padding_mode="border", align_corners=True)[0]


def reproj(vp_src, vp_dst, d, half, order):
    """pixel of the source frame (depth d) -> its position in the destination frame (render px)."""
    Ms = torch.tensor(vp_src.reshape(4, 4), device=dev, dtype=torch.float64)
    Md = torch.tensor(vp_dst.reshape(4, 4), device=dev, dtype=torch.float64)
    if order == "cm":                                                               
        Ms, Md = Ms.T, Md.T
    nx = (xx.double() + half) / RW * 2 - 1
    ny = 1 - (yy.double() + half) / RH * 2
    clip = torch.stack((nx, ny, d.double(), torch.ones_like(nx)), 0).view(4, -1)
    world = torch.linalg.solve(Ms, clip)
    c = Md @ world
    px = ((c[0] / c[3] + 1) / 2 * RW - half).view(RH, RW)
    py = ((1 - c[1] / c[3]) / 2 * RH - half).view(RH, RW)
    return torch.stack((px - xx.double(), py - yy.double()), 0).float()


best = None
for f in frames:
    a, g_, b = f - 2, f - 1, f
    m1, m0 = mvr(b), mvr(g_)
    mv = m1 + sample(m0, m1[0], m1[1])                                                            
    d = dep(b)
    bg = (d < 0.1) & (d > 0)                                                                                 
    if best is None:                                                                                              
        res = {}
        for half, order in itertools.product((0.0, 0.5), ("cm", "rm")):
            cam = reproj(MF[b]["vp"], MF[a]["vp"], d, half, order)
            e = (cam - mv).norm(dim=0)[bg]
            res[(half, order)] = float(e.median())
        best = min(res, key=res.get)
        print("convention check (median |camera B->A - game MV| px on background):", {k: round(v, 3) for k, v in res.items()}, "-> using", best)
    half, order = best
    camA = reproj(MF[b]["vp"], MF[a]["vp"], d, half, order)
    camT = reproj(MF[b]["vp"], MF[g_]["vp"], d, half, order)                                      
    tt = float(os.environ.get("T_TRUE", "0")) and DT[g_] / (DT[g_] + DT[b]) or 0.5                                     
    vl = (1 - tt) * MF[a]["vp"] + tt * MF[b]["vp"]
    camL = reproj(MF[b]["vp"], vl, d, half, order)                                                
    lin = (1 - tt) * mv                                                                     
    ok = bg & ((camA - mv).norm(dim=0) < 2)                                                                  
    q = lambda v: f"median {float(v.median()):6.1f}  p90 {float(v.flatten()[::7].quantile(.9)):6.1f}  max {float(v.max()):6.1f}"
    print(f"f={f:2d} (A {a}, t-frame {g_}, B {b}): |MV B->A| median {float(mv.norm(dim=0)[ok].median()):6.1f} px (render) | "
          f"camera B->A vs MV {float((camA - mv).norm(dim=0)[bg].median()):.2f}")
    print(f"      linear t-pos vs real camera at t : {q((lin - camT).norm(dim=0)[ok])}")
    print(f"      clip-lerp camera vs real camera  : {q((camL - camT).norm(dim=0)[ok])}")
    print(f"      linear vs clip-lerp              : {q((lin - camL).norm(dim=0)[ok])}   (render px; x1.7 for display px)")
