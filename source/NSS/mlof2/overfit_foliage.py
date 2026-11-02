"""Capacity probe: can the OF network fit the exact flow of ONE Spring sequence? Start from an OF checkpoint, train on
that sequence only with the exact-flow L1 (full res after up4, every on-screen pixel; no census / smooth), random
pairs N in {2, 4} frames apart and random 512 x 1024 crops, then score it with diag_foliage_of.py on the same
sequence. Fits well -> the architecture can represent foliage motion (the training mix / weights are the limit);
stays near the start -> the architecture is the limit.
  python overfit_foliage.py <spring crop safetensors> <OF ckpt> <out ckpt> [steps=600] [lr=1e-4]"""
import random, sys, time
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import depth_feature, chain_backward
from nfru_head import up4

fn, ck, out = sys.argv[1:4]
steps = int(sys.argv[4]) if len(sys.argv) > 4 else 600
lr = float(sys.argv[5]) if len(sys.argv) > 5 else 1e-4
dev = "cuda"
s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)),
                                size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))

sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
m.train()
opt = torch.optim.AdamW(m.parameters(), lr=lr, weight_decay=1e-4)
cache = {}
def pair(a, b):
    if (a, b) not in cache:
        cache[(a, b)] = tuple(x.to(dev) for x in (col(a), col(b), dfeat(a), dfeat(b), mv_ba(a, b)))
    return cache[(a, b)]

rng = random.Random(0)
CH, CW = 512, 1024
t0 = time.time()
for st in range(1, steps + 1):
    N = rng.choice((2, 4))
    a = rng.randrange(0, T - N)
    ca, cb, da, db, ex = pair(a, a + N)
    y, x = rng.randrange(0, H - CH + 1), rng.randrange(0, W - CW + 1)
    c = lambda t: t[..., y:y + CH, x:x + CW]
    ca_, cb_, da_, db_, ex_ = c(ca), c(cb), c(da), c(db), c(ex)
    pr = m.pair(m.enc(ca_, da_), m.enc(cb_, db_), ex_, torch.ones_like(ex_[:, :1]), ca_, cb_)
    of = pr["of_ba_full"] if pr.get("of_ba_full") is not None else pr["of_ba"]
    of = up4(of, CH, CW)
    on = (warp(torch.ones_like(ca_[:, :1]), ex_) > 0.999).float()
    loss = ((of - ex_).abs().sum(1, keepdim=True) * on).sum() / on.sum().clamp_min(1)
    opt.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(m.parameters(), 2.0)
    opt.step()
    if st % 50 == 0:
        print(f"step {st} L1 {loss.item():.3f} | {(time.time() - t0) / st:.2f} s/step", flush=True)
torch.save({"model": m.state_dict()}, out)
print("saved", out)
