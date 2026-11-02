"""Does exact-flow-only training (no census / smooth / app) generalise? Like overfit_foliage.py but every step draws a
random Spring TRAIN sequence (crop file), a random pair N in {2, 4} frames apart and a random 512 x 1024 crop: no
single scene to memorise. Score with diag_foliage_of.py on the validation sequences (never seen).
  python probe_gt_multi.py <spring train dir> <OF ckpt> <out ckpt> [steps=2000] [lr=1e-4]"""
import glob, os, random, sys, time
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import depth_feature, chain_backward
from nfru_head import up4

root, ck, out = sys.argv[1:4]
steps = int(sys.argv[4]) if len(sys.argv) > 4 else 2000
lr = float(sys.argv[5]) if len(sys.argv) > 5 else 1e-4
dev = "cuda"
files = sorted(glob.glob(os.path.join(root, "*", "*.safetensors")))
print(f"{len(files)} train crops", flush=True)


_open = {}


def sample(fn, rng, CH=512, CW=1024):
    if fn not in _open:                                                                                       
        _open.clear()
        _open[fn] = safe_open(fn, "pt")
    s = _open[fn]
    T = s.get_slice("ground_truth_srgb8").get_shape()[0]
    H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
    hm = s.get_slice("motion_lr").get_shape()[-2]
    N = rng.choice((2, 4))
    a = rng.randrange(0, T - N)
    b = a + N
    col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
    dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)),
                                    size=(H, W), mode="bilinear", align_corners=False)
    nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
    ex = F.interpolate(chain_backward(nat(x) for x in range(b, a, -1))[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
    y, x = rng.randrange(0, H - CH + 1), rng.randrange(0, W - CW + 1)
    c = lambda t: t[..., y:y + CH, x:x + CW].to(dev)
    return c(col(a)), c(col(b)), c(dfeat(a)), c(dfeat(b)), c(ex)


sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
m.train()
opt = torch.optim.AdamW(m.parameters(), lr=lr, weight_decay=1e-4)
rng = random.Random(0)
GROUP = int(os.environ.get("GROUP", "25"))
cur = None
t0, run = time.time(), []
for st in range(1, steps + 1):
    if (st - 1) % GROUP == 0:
        cur = rng.choice(files)                                                                                
    ca, cb, da, db, ex = sample(cur, rng)
    pr = m.pair(m.enc(ca, da), m.enc(cb, db), ex, torch.ones_like(ex[:, :1]), ca, cb)
    of = pr["of_ba_full"] if pr.get("of_ba_full") is not None else pr["of_ba"]
    of = up4(of, *ca.shape[-2:])
    on = (warp(torch.ones_like(ca[:, :1]), ex) > 0.999).float()
    loss = ((of - ex).abs().sum(1, keepdim=True) * on).sum() / on.sum().clamp_min(1)
    opt.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(m.parameters(), 2.0)
    opt.step()
    run.append(loss.item())
    if st % 100 == 0:
        print(f"step {st} L1 (mean of 100) {sum(run[-100:]) / 100:.3f} | {(time.time() - t0) / st:.2f} s/step", flush=True)
torch.save({"model": m.state_dict()}, out)
print("saved", out)
