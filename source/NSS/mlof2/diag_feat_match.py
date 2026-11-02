"""Do the OF features tell foliage apart? For every feature-grid pixel of B, the cosine cost volume (model_v2.correlation,
radius R) around its exact match in A (A's features warped by the exact flow, area-reduced to that grid): the centre
is the true match. Scored: top-1 (argmax = centre), top-3x3 (argmax within +-1), and the margin centre - best offset
>= 2 away. Feature sets: raw pixels (pixel_unshuffle of RGB+depth, as the encoder's input), the OF encoder's 1/4 and
1/8 maps, SEA-RAFT's matching features (1/8). Regions: all, foliage (as diag_foliage_of.py), deviation bins.
  python diag_feat_match.py <spring crop safetensors> <OF ckpt> [N=4] [R=4]"""
import sys
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp, correlation
from data_v2 import depth_feature, chain_backward

fn, ck = sys.argv[1:3]
N = int(sys.argv[3]) if len(sys.argv) > 3 else 4
R = int(sys.argv[4]) if len(sys.argv) > 4 else 4
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
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
from teacher_searaft import SeaRaftTeacher
sr = SeaRaftTeacher(dev).model


def feats(c, d):
    x = torch.cat((c, d), 1)
    f = m.enc(c, d)
    u4, u8 = F.pixel_unshuffle(x, 4), F.pixel_unshuffle(x, 8)
    return {"raw 1/4": (4, u4), "raw-mean 1/4": (4, u4 - u4.mean((2, 3), keepdim=True)),
            "enc 1/4": (4, f[4]), "raw-mean 1/8": (8, u8 - u8.mean((2, 3), keepdim=True)),
            "enc 1/8": (8, f[8]), "searaft 1/8": (8, sr.fnet(2 * c - 1).float())}


DEV = [0, 1, 2, 4, 8, 16, 1e9]
acc = {}
C = (2 * R + 1) ** 2 // 2
yy, xx = torch.meshgrid(torch.arange(-R, R + 1), torch.arange(-R, R + 1), indexing="ij")
far = ((yy.abs() >= 2) | (xx.abs() >= 2)).flatten().to(dev)
near = ((yy.abs() <= 1) & (xx.abs() <= 1)).flatten().to(dev)
with torch.no_grad():
    for a in range(0, T - N, N):
        b = a + N
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        ex = pad(mv_ba(a, b)).to(dev)
        r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        reg = (F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5).float()
        dv = (ex - sm).norm(dim=1, keepdim=True)
        valid = torch.zeros_like(reg); valid[..., :H, :] = 1
        fa, fb = feats(ca, da), feats(cb, db)
        for name in fa:
            k, qa = fa[name]; qb = fb[name][1]
            g = F.avg_pool2d(ex, k) / k
            cv = correlation(qb, warp(qa, g), R)[0]                                                        
            am = cv.argmax(0)
            top1 = (am == C).float(); top3 = near[am].float()
            margin = cv[C] - cv[far].max(0).values
            vk = F.avg_pool2d(valid, k)[0, 0] > 0.99
            masks = {"all": vk, "fol": vk & (F.avg_pool2d(reg, k)[0, 0] > 0.5)}
            dk = F.avg_pool2d(dv, k)[0, 0]
            for i in range(len(DEV) - 1):
                masks[f"dev {DEV[i]:g}-{DEV[i + 1]:g}"] = vk & (dk >= DEV[i]) & (dk < DEV[i + 1])
            for mk, msk in masks.items():
                for met, v in (("top1", top1), ("top3x3", top3), ("margin", margin)):
                    z = acc.setdefault((name, mk, met), [0.0, 0.0]); z[0] += float(v[msk].sum()); z[1] += float(msk.sum())
names = list(fa)
print(f"exact-match retrieval, cosine cost volume r={R}, frames {N} apart (top1/top3x3 in %, margin)")
for mk in ["all", "fol"] + [f"dev {DEV[i]:g}-{DEV[i + 1]:g}" for i in range(len(DEV) - 1)]:
    print(f"  {mk:10s}" + "".join(f" | {n}: {100 * acc[(n, mk, 'top1')][0] / max(acc[(n, mk, 'top1')][1], 1):4.0f}"
                                   f"/{100 * acc[(n, mk, 'top3x3')][0] / max(acc[(n, mk, 'top3x3')][1], 1):3.0f}"
                                   f" {acc[(n, mk, 'margin')][0] / max(acc[(n, mk, 'margin')][1], 1):+.2f}" for n in names))
