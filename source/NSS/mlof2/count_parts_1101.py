"""Per-submodule conv MACs of the deployed menc enc / pair at 960x576 (one frame through enc, pair both directions)."""
import torch
from torch import nn
from model_v2 import build_mlof2
acc = {}


def hook(tag):
    def f(mod, i, o):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        acc[tag] = acc.get(tag, 0) + o.numel() * (mod.in_channels // mod.groups) * k
    return f


sd = torch.load("/home/sh/mlof2_runs/v2_of_menc/s1500.pt", map_location="cpu")
m = build_mlof2(sd).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
for root, mod in (("enc", m.enc), ("pair", m.pair)):
    for name, sub in mod.named_modules():
        if isinstance(sub, (nn.Conv2d, nn.ConvTranspose2d)):
            parts = name.split(".")
            tag = root + "." + ".".join(parts[:2] if parts[0] in ("upd", "menc", "rec") else parts[:1])
            sub.register_forward_hook(hook(tag))
h, w = 576, 960
x, d = torch.rand(1, 3, h, w), torch.rand(1, 1, h, w)
with torch.no_grad():
    fa = m.enc(x, d)
    m.pair(fa, fa, torch.zeros(1, 2, h, w), torch.zeros(1, 1, h, w), x, x)
for k, v in sorted(acc.items(), key=lambda kv: -kv[1]):
    print(f"{k:24s} {v / 1e9:6.2f} GMAC")
