"""MLOF2 structure check: shapes, parameter count, conv MACs per part at a given resolution, fp16 GPU timing.

  python count_v2.py [W H]      default 1920 1088 (1080p padded to a multiple of 32)
"""
import sys
import time
import torch
from torch import nn
from model_v2 import MLOF2

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (1920, 1088)
dev = "cuda" if torch.cuda.is_available() else "cpu"
torch.manual_seed(0)
m = MLOF2().to(dev).eval()

macs = {"enc": 0, "pair": 0, "head": 0}
owner = {}
for part in macs:
    for mod in getattr(m, part).modules():
        owner[mod] = part


def hook(mod, inp, out):
    if isinstance(mod, nn.Conv2d):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        macs[owner[mod]] += out.numel() * (mod.in_channels // mod.groups) * k
    elif isinstance(mod, nn.Linear):
        macs[owner[mod]] += out.numel() * mod.in_features


for mod in m.modules():
    if isinstance(mod, (nn.Conv2d, nn.Linear)):
        mod.register_forward_hook(hook)

params = {p: sum(x.numel() for x in getattr(m, p).parameters()) for p in macs}
print(f"resolution {W}x{H}  device {dev}")
print("params: " + ", ".join(f"{k} {v/1e6:.2f}M" for k, v in params.items()) + f", total {sum(params.values())/1e6:.2f}M")


def inputs(dtype):
    r = lambda c: torch.rand(1, c, H, W, device=dev, dtype=dtype)
    mv = (torch.randn(1, 2, H, W, device=dev) * 20).to(dtype)
    return r(3), r(1), r(3), r(1), mv, torch.ones(1, 1, H, W, device=dev, dtype=dtype)


                                                                                           
with torch.no_grad():
    ca, da, cb, db, mv, mvv = inputs(torch.float32)
    fa = m.enc(ca, da)
    for k in macs:
        macs[k] = 0
    frames, pair, _ = m(ca, da, cb, db, mv, mvv, [torch.tensor([0.5], device=dev)], feats_a=fa)
print("shapes: f_ba", tuple(pair["f_ba"].shape), "color", tuple(frames[0]["color"].shape),
      "flow t->A", tuple(frames[0]["f_ta"].shape))
G = {k: v / 1e9 for k, v in macs.items()}
print("GMAC per call: " + ", ".join(f"{k} {v:.2f}" for k, v in G.items()))
for mult in (2, 3, 4):
    gen = mult - 1
    per_pair = G["enc"] + G["pair"] + gen * G["head"]
    print(f"  {mult}x: {gen} generated/pair, {per_pair:.2f} GMAC per pair, {per_pair/gen:.2f} GMAC per generated frame")

                                                                          
if dev == "cuda":
    m16 = m.half()
    ca, da, cb, db, mv, mvv = inputs(torch.float16)
    t = torch.tensor([0.5], device=dev, dtype=torch.float16)

    def bench(fn, n=20):
        with torch.no_grad():
            for _ in range(3):
                fn()
            torch.cuda.synchronize()
            s = time.perf_counter()
            for _ in range(n):
                fn()
            torch.cuda.synchronize()
        return (time.perf_counter() - s) / n * 1000

    with torch.no_grad():
        fa = m16.enc(ca, da)
        fb = m16.enc(cb, db)
        pr = m16.pair(fa, fb, mv, mvv, ca, cb)
    te = bench(lambda: m16.enc(cb, db))
    tp = bench(lambda: m16.pair(fa, fb, mv, mvv, ca, cb))
    th = bench(lambda: m16.head(t, pr, fa[8], fb[8], ca, cb))
    print(f"fp16 PyTorch ms: enc {te:.2f}, pair {tp:.2f}, head {th:.2f}")
    for mult in (2, 3, 4):
        gen = mult - 1
        print(f"  {mult}x: {(te + tp + gen * th) / gen:.2f} ms per generated frame")

                                   
m = MLOF2().to(dev).train().float()
h, w = 128, 192
r = lambda c: torch.rand(2, c, h, w, device=dev)
frames, pair, _ = m(r(3), r(1), r(3), r(1), torch.randn(2, 2, h, w, device=dev) * 5, torch.ones(2, 1, h, w, device=dev),
                    [torch.rand(2, device=dev)])
loss = frames[0]["color"].mean() + pair["f_ba"].abs().mean()
loss.backward()
nograd = [n for n, p in m.named_parameters() if p.grad is None]
print("backward ok, params without grad:", nograd or "none")
