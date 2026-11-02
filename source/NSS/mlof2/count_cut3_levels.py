"""MACs of the deployed cut3 pair network per level at the DLL OF size (half-res frame), + candidate recurrent 1/8 blocks.
  python count_cut3_levels.py <ckpt> [W H]"""
import sys
import torch
from torch import nn
from model_v2 import build_mlof2, FrameEncoder

ck = sys.argv[1]
W, H = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (960, 576)
sd = torch.load(ck, map_location="cpu"); sd = sd.get("model", sd)
m = build_mlof2(sd).eval(); m.load_state_dict(sd); m.pair.seeded = False
macs = {}
names = {mod: n for n, mod in m.named_modules()}
def hook(mod, inp, out):
    if isinstance(mod, nn.Conv2d):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        key = ".".join(names[mod].split(".")[:3])
        macs[key] = macs.get(key, 0) + out.numel() * (mod.in_channels // mod.groups) * k
for mod in m.modules():
    mod.register_forward_hook(hook)
ca, cb = torch.rand(1, 3, H, W), torch.rand(1, 3, H, W)
d = torch.rand(1, 1, H, W)
with torch.no_grad():
    fa, fb = m.enc(ca, d), m.enc(cb, d)
    m.pair.of_forward(fa, fb, ca, cb)
enc = sum(v for k, v in macs.items() if k.startswith("enc")) / 2
print(f"input {W}x{H}: encoder/frame {enc/1e9:.3f} GMAC")
tot = 0
for k, v in sorted(macs.items()):
    if k.startswith("pair"):
        tot += v; print(f"  {k:18s} {v/1e9:7.3f}")
for lv in m.pair.LEVELS:
    r = m.pair.radius[lv]; px = (H // lv) * (W // lv)
    print(f"  corr 1/{lv} r={r} {px * (2*r+1)**2 * FrameEncoder.CH[lv] / 1e9:7.3f}  ({W//lv}x{H//lv})")
print(f"OF convs {tot/1e9:.3f} GMAC (one direction pass as of_forward runs it)")
                                                  
P8 = (H // 8) * (W // 8)
def cand(hd, cin_corr, it, gru="zrq"):
    motion = cin_corr * 64 + 9 * 2 * 16 + 9 * 80 * (hd - 2)                                                                
    xin = hd + hd + hd                                                               
    g = len(gru) * 9 * xin * hd
    head = 9 * hd * 64 + 64 * 2
    per = motion + g + head
    init = 64 * 2 * hd                                                                            
    up = 9 * hd * 64 + 64 * 9 * 4                                                           
    return (per * it + init + up) * P8, per
for hd, it, gru in ((64, 4, "zrq"), (64, 3, "zrq"), (48, 3, "zq"), (64, 2, "zq"), (32, 4, "zq")):
    for corr_c in (49 + 25,):
        t, per = cand(hd, corr_c, it, gru)
        print(f"cand hidden {hd} iters {it} gru {gru}: {per/1e3:.0f}k MAC/px/iter, total {t/1e9:.3f} GMAC at 1/8 ({W//8}x{H//8})")
