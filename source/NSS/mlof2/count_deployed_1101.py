"""Conv MACs of the DEPLOYED path (2026-11-01): menc OF (v2_of_menc/s1500) on the half-res frame 960x576 (one new frame
per pair through the encoder, pair both directions), head c2_ce3 (cues 3) at 1920x1088 per generated frame; plus the
OF t-block (oft3) per generated frame. Forward hooks on Conv2d / ConvTranspose (out elements x Cin/groups x k^2)."""
import torch
from torch import nn
from model_v2 import build_mlof2
from nfru_head import load_head_c2
from oft_block import OFTNet, gmac

dev = "cpu"
acc = {}


def hook(tag):
    def f(mod, i, o):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        acc[tag] = acc.get(tag, 0) + o.numel() * (mod.in_channels // mod.groups) * k
    return f


def count(module, tag):
    hs = [m.register_forward_hook(hook(tag)) for m in module.modules() if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d))]
    return hs


sd = torch.load("/home/sh/mlof2_runs/v2_of_menc/s1500.pt", map_location=dev)
m = build_mlof2(sd).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
h, w = 576, 960
x, d = torch.rand(1, 3, h, w), torch.rand(1, 1, h, w)
hs = count(m.enc, "enc (per real frame)")
with torch.no_grad():
    fa = m.enc(x, d)
for k in hs: k.remove()
fb = fa
hs = count(m.pair, "pair (per real frame pair)")
with torch.no_grad():
    p = m.pair(fa, fb, torch.zeros(1, 2, h, w), torch.zeros(1, 1, h, w), x, x)
for k in hs: k.remove()
head = load_head_c2("/home/sh/mlof2_runs/nfru_head_c2_ce3/s4000.pt", dev); head.talign = "fp"
H, W = 1088, 1920
hs = count(head, "head (per generated frame)")
X, D = torch.rand(1, 3, H, W), torch.rand(1, 1, H, W)
with torch.no_grad():
    head(torch.tensor([0.5]), torch.zeros(1, 2, H // 4, W // 4), X, X, D, D, torch.zeros(1, 2, H, W),
         conf_q=torch.zeros(1, 1, H // 4, W // 4), occ_q=torch.zeros(1, 1, H // 4, W // 4))
for k in hs: k.remove()
for k, v in acc.items():
    print(f"{k:32s} {v / 1e9:7.2f} GMAC")
o = OFTNet((128, 96, 64, 48), (3, 3, 3, 3))
print(f"{'OF t-block oft3 (per gen. frame)':32s} {gmac(o):7.2f} GMAC")
