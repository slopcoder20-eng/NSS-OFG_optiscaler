"""Which pixels got the exact-flow supervision in the OF training (of_losses.of_loss: geo / ms only where
explain_error(A, B, GT) <= 0.5, census only on vis_b)? Share of supervised pixels on a Spring sequence, for the foliage
region (as diag_foliage_of.py) and by exact-flow magnitude, real frames N apart.
  python diag_geo_mask.py <spring crop safetensors> [N=1,2,4,8]"""
import sys
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import warp
from data_v2 import chain_backward
from losses_v2 import explain_error

fn = sys.argv[1]
NS = [int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "1,2,4,8").split(",")]
dev = "cuda"
s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))
MAG = [0, 2, 8, 16, 32, 64, 1e9]
with torch.no_grad():
    for N in NS:
        acc = {}
        def add(k, v, m):
            a = acc.setdefault(k, [0.0, 0.0]); a[0] += float(v[m].sum()); a[1] += float(m.sum())
        for a in range(0, T - N, N):
            ca, cb, g = col(a).to(dev), col(a + N).to(dev), mv_ba(a, a + N).to(dev)
            ok = (explain_error(ca, cb, g) <= 0.5).float()[0, 0]
            on = (warp(torch.ones_like(ca[:, :1]), g) > 0.999)[0, 0]
            r = 32
            sm = F.avg_pool2d(F.pad(g, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
            reg = (F.max_pool2d(((g - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5)[0, 0]
            mag = g.norm(dim=1)[0]
            al = torch.ones_like(reg)
            add("all", ok, al); add("foliage", ok, reg); add("non-foliage", ok, ~reg)
            add("on screen (warp in frame)", on.float(), al)
            for i in range(len(MAG) - 1):
                mk = (mag >= MAG[i]) & (mag < MAG[i + 1])
                add(f"|flow| {MAG[i]:g}-{MAG[i + 1]:g}", ok, mk)
                add(f"foliage |flow| {MAG[i]:g}-{MAG[i + 1]:g}", ok, mk & reg)
        print(f"== N = {N}: share of pixels the geo / ms loss supervised (explain_error <= 0.5)")
        for k, (x, n) in acc.items():
            print(f"  {k:30s} {100 * x / max(n, 1):6.1f}%   (n {int(n)})")
