"""Where do the pair-flow MACs go? Conv MACs per PairFlow module + cost-volume MACs per OF level, 1920x1088.
  python count_levels.py [W H]"""
import sys
import torch
from torch import nn
from model_v2 import MLOF2, FrameEncoder

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (1920, 1088)
dev = "cuda"
m = MLOF2().to(dev).eval().half()
macs = {}
names = {mod: n for n, mod in m.named_modules()}


def hook(mod, inp, out):
    if isinstance(mod, nn.Conv2d):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        key = ".".join(names[mod].split(".")[:3])
        macs[key] = macs.get(key, 0) + out.numel() * (mod.in_channels // mod.groups) * k


for mod in m.modules():
    mod.register_forward_hook(hook)
ca, cb = torch.rand(1, 3, H, W, device=dev).half(), torch.rand(1, 3, H, W, device=dev).half()
d = torch.rand(1, 1, H, W, device=dev).half()
with torch.no_grad():
    fa, fb = m.enc(ca, d), m.enc(cb, d)
    macs_enc = sum(v for k, v in macs.items() if k.startswith("enc")) / 2                                 
    m.pair(fa, fb, torch.zeros(1, 2, H, W, device=dev).half(), torch.ones(1, 1, H, W, device=dev).half(), ca, cb)
tot = 0
print(f"encoder per frame {macs_enc / 1e9:.2f} GMAC")
for k, v in sorted(macs.items()):
    if k.startswith("pair"):
        tot += v
        print(f"  {k:18s} {v / 1e9:6.2f} GMAC")
ch = FrameEncoder.CH
corr = 0
for lv in m.pair.LEVELS:
    r = m.pair.radius[lv]
    px = 2 * (H // lv) * (W // lv)                                      
    c = px * (2 * r + 1) ** 2 * ch[lv]
    corr += c
    print(f"  cost volume 1/{lv:<3d} r={r}  {(2 * r + 1) ** 2:4d} taps x {ch[lv]:3d} ch  {c / 1e9:6.3f} GMAC")
print(f"pair convs {tot / 1e9:.2f} + cost volumes {corr / 1e9:.2f} GMAC (both directions)")
