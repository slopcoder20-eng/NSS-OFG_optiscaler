"""Why does the MatchEncoder distillation stall? (2026-10-31)
A  representation: a 1x1 conv 256 -> 64 on SEA-RAFT's own fnet features, trained with the same 1/8 r=3 cost-volume KL
   -> the KL a 64-channel cosine CAN reach (if low: 64 ch is enough, the student backbone is the limit)
B  optimisation: a fresh MatchEncoder overfit on ONE fixed batch (if the KL does not drop: architecture problem)
Reference: held-out 1/8 KL of menc6000 (plain MatchEncoder) and of the fpndist12000 encoder's f8, on fixed game
validation batches.  python test_distill_limits.py"""
import os, sys, random, torch
from torch import nn
from torch.nn import functional as F
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import MatchEncoder, FrameEncoder, build_mlof2, warp, correlation
from data_v2 import WindowDataset
from teacher_searaft import SeaRaftTeacher
dev, TAU, R = "cuda", 0.07, "/home/sh/mlof2_runs"
torch.manual_seed(0); random.seed(0)
fnet = SeaRaftTeacher(dev).model.fnet
names, strides = ["forest15", "lyra15", "lyra17"], [1, 2, 3, 4, 6, 8]
tl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=384, strides=strides), batch_size=4, shuffle=True,
                                 num_workers=3, drop_last=True)
vl = torch.utils.data.DataLoader(WindowDataset(names, "validation", crop=384, windows_per_file=8, strides=strides, seed=7),
                                 batch_size=4, num_workers=2)
vb = [b for _, b in zip(range(12), vl)]


def kl_of(sa, sb, b, g, ta=None, tb=None):
    with torch.no_grad():
        if ta is None:
            ta, tb = fnet(2 * b["color_a"] - 1).float(), fnet(2 * b["color_b"] - 1).float()
        pt = torch.softmax(correlation(tb, warp(ta, g), 3) / TAU, 1)
    ls = torch.log_softmax(correlation(sb, warp(sa, g), 3) / TAU, 1)
    return (pt * (torch.log(pt.clamp_min(1e-8)) - ls)).sum(1).mean()


def jit(b, seed):
    g = F.avg_pool2d(b["geo_flow_ba"].to(dev), 8) / 8
    gen = torch.Generator(device=dev).manual_seed(seed)
    return g + (torch.rand(g.shape, generator=gen, device=dev) * 4 - 2)


def heldout(feat):                          
    s = 0.0
    with torch.no_grad():
        for i, b in enumerate(vb):
            b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
            fa, fb = feat(b)
            s += float(kl_of(fa, fb, b, jit(b, i)))
    return s / len(vb)


tf = lambda b: (fnet(2 * b["color_a"] - 1).float(), fnet(2 * b["color_b"] - 1).float())
            
me = MatchEncoder().to(dev).eval(); me.load_state_dict(torch.load(f"{R}/v2_of_encpre/menc6000.pt", map_location=dev)["menc"])
print(f"held-out 1/8 KL  menc6000 (plain MatchEncoder): {heldout(lambda b: (me(b['color_a'], b['depth_a'])[8], me(b['color_b'], b['depth_b'])[8])):.3f}", flush=True)
e = torch.load(f"{R}/v2_of_encpre/fpndist12000.pt", map_location=dev)
fe = FrameEncoder(deep_fine=True, ch=e["ch"], fpn=True).to(dev).eval(); fe.load_state_dict(e["enc_wide"])
print(f"held-out 1/8 KL  fpndist12000 encoder f8:       {heldout(lambda b: (fe(b['color_a'], b['depth_a'])[8], fe(b['color_b'], b['depth_b'])[8])):.3f}", flush=True)
print(f"held-out 1/8 KL  teacher itself:                {heldout(tf):.3f}", flush=True)

                                         
for cout in (64, 128):
    pj = nn.Conv2d(256, cout, 1).to(dev)
    opt = torch.optim.AdamW(pj.parameters(), lr=1e-3)
    it = iter(tl)
    for step in range(1, 1201):
        try: b = next(it)
        except StopIteration: it = iter(tl); b = next(it)
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        with torch.no_grad(): ta, tb = tf(b)
        loss = kl_of(pj(ta), pj(tb), b, jit(b, step + 10_000), ta, tb)
        opt.zero_grad(); loss.backward(); opt.step()
    print(f"A  1x1 256->{cout} on teacher features: held-out KL {heldout(lambda b: tuple(pj(x) for x in tf(b))):.3f}", flush=True)

                                            
st = MatchEncoder().to(dev)
opt = torch.optim.AdamW(st.parameters(), lr=1e-3)
b = {k: v.to(dev) for k, v in next(iter(tl)).items() if torch.is_tensor(v)}
g = jit(b, 1)
for step in range(1, 801):
    loss = kl_of(st(b["color_a"], b["depth_a"])[8], st(b["color_b"], b["depth_b"])[8], b, g)
    opt.zero_grad(); loss.backward(); opt.step()
    if step in (1, 100, 200, 400, 800):
        print(f"B  overfit one batch step {step}: KL {float(loss):.3f}", flush=True)
print("DONE")
