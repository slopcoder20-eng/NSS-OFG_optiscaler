"""Does the Update fail to read the cost volume (decoding), or is the cost volume itself not good enough (features)?
At the 1/8 and 1/4 levels: the network's input flow there (the coarser level's flow, bilinear x2) is the centre; the
level's own cosine cost volume (model_v2.correlation, the level's radius) around it is read out WITHOUT the Update:
hard argmax and soft-argmax (softmax(corr / T)) displacement. Compared with the network's flow after that level, all
at full res against the exact Spring flow, by deviation bins and foliage. 'window oracle' = the candidate nearest to
the truth (what the window can reach at best).
  python diag_corr_readout.py <spring crop safetensors> <OF ckpt> [N=4]"""
import sys
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp, correlation
from data_v2 import depth_feature, chain_backward

fn, ck = sys.argv[1:3]
N = int(sys.argv[3]) if len(sys.argv) > 3 else 4
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
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
import os
enc = m.enc                                                                                                           
AGG = int(os.environ.get("AGG", "0"))                                                                                    
ITERS = int(os.environ.get("ITERS", "1"))                                                              
SR = None
if os.environ.get("ENC") == "searaft":                                                                         
    from teacher_searaft import SeaRaftTeacher
    SR = SeaRaftTeacher(dev).model
    enc = lambda c, d: {8: SR.fnet(2 * c - 1).float()}
elif os.environ.get("ENC"):
    from model_v2 import FrameEncoder
    e_sd = torch.load(os.environ["ENC"], map_location=dev)
    if "menc" in e_sd:
        from model_v2 import MatchEncoder
        enc = MatchEncoder().to(dev).eval(); enc.load_state_dict(e_sd["menc"])
    elif "enc_wide" in e_sd:
        enc = FrameEncoder(deep_fine=True, ch=e_sd["ch"], fpn=e_sd.get("fpn", False)).to(dev).eval(); enc.load_state_dict(e_sd["enc_wide"])
    else:
        e_sd = e_sd.get("model", e_sd); enc = build_mlof2(e_sd).to(dev).eval().enc; enc.load_state_dict({k[4:]: v for k, v in e_sd.items() if k.startswith("enc.")})
DEV = [0, 1, 2, 4, 8, 16, 1e9]
acc = {}


def full(f, shape):
    return F.interpolate(f, size=shape, mode="bilinear", align_corners=False) * (shape[-1] / f.shape[-1])


with torch.no_grad():
    for a in range(0, T - N, N):
        b = a + N
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        ex = pad(mv_ba(a, b)).to(dev)
        r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        dv = (ex - sm).norm(dim=1)[0, :H]
        reg = (F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5)[0, 0, :H]
        fa, fb = m.enc(ca, da), m.enc(cb, db)
        ofs = m.pair.of_forward(fa, fb, ca, cb)
        ga = (enc(ca, da), enc(cb, db)) if enc is not m.enc else None
        lvls = ((8, 16),) if SR is not None else ((8, 16), (4, 8))
        masks = {"all": torch.ones_like(reg), "fol": reg}
        for i in range(len(DEV) - 1):
            masks[f"dev {DEV[i]:g}-{DEV[i + 1]:g}"] = (dv >= DEV[i]) & (dv < DEV[i + 1])
        for lv, coarse in lvls:
            rad = m.pair.radius[lv]
            q, rr = (fb[lv], fa[lv]) if enc is m.enc else (ga[1][lv], ga[0][lv])
            init = full(ofs[coarse]["of"][:1], q.shape[-2:])                                                    
            cv = correlation(q, warp(rr, init), rad)[0]                             
            if AGG > 1:
                cv = F.avg_pool2d(F.pad(cv[None], (AGG // 2,) * 4, mode="replicate"), AGG, 1)[0]
            yy, xx = torch.meshgrid(torch.arange(-rad, rad + 1, device=dev), torch.arange(-rad, rad + 1, device=dev), indexing="ij")
            offs = torch.stack((xx.flatten(), yy.flatten()), 0).float()                      
            cands = {"net": ofs[lv]["of"][:1], "centre (coarse x2)": init}
            hard = offs[:, cv.argmax(0)]                                             
            cands["corr argmax"] = init + hard[None]
            for tmp in (0.02, 0.05):
                p = torch.softmax(cv / tmp, 0)
                cands[f"corr soft T={tmp}"] = init + torch.einsum("ck,khw->chw", offs, p)[None]
                                                                                                                 
            for mode in ("soft", "hard"):
                cur = init
                for it in range(2, ITERS + 1):
                    if it == 2:
                        cur = cands["corr soft T=0.05"] if mode == "soft" else cands["corr argmax"]
                    c2 = correlation(q, warp(rr, cur), rad)[0]
                    if AGG > 1:
                        c2 = F.avg_pool2d(F.pad(c2[None], (AGG // 2,) * 4, mode="replicate"), AGG, 1)[0]
                    d2 = torch.einsum("ck,khw->chw", offs, torch.softmax(c2 / 0.05, 0)) if mode == "soft" else offs[:, c2.argmax(0)]
                    cur = cur + d2[None]
                    if it in (2, 3, 5, 8, ITERS):
                        cands[f"iter{it} {mode}"] = cur
            gt = F.avg_pool2d(ex, lv) / lv                                                                       
            d = gt[0] - init[0]                                                                
            k_or = ((offs[:, :, None, None] - d[:, None]) ** 2).sum(0).argmin(0)
            cands["window oracle"] = init + offs[:, k_or][None]
            for name, f in cands.items():
                e = (full(f, ex.shape[-2:]) - ex).norm(dim=1)[0, :H]
                for mk, msk in masks.items():
                    v = acc.setdefault((lv, name, mk), [0.0, 0.0]); v[0] += float(e[msk].sum()); v[1] += float(msk.sum())
mks = ["all", "fol"] + [f"dev {DEV[i]:g}-{DEV[i + 1]:g}" for i in range(len(DEV) - 1)]
for lv in sorted({k[0] for k in acc}, reverse=True):
    print(f"level 1/{lv} (radius {m.pair.radius[lv]}): full-res EPE vs exact, frames {N} apart")
    print(f"  {'':22s}" + "".join(f"{k:>10s}" for k in mks))
    names = [k[1] for k in acc if k[0] == lv and k[2] == "all"]
    for n in names:
        print(f"  {n:22s}" + "".join(f"{acc[(lv, n, k)][0] / max(acc[(lv, n, k)][1], 1):10.2f}" for k in mks))
