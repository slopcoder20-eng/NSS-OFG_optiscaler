"""Parameters and MACs of the current OF (convex_up + deep16 + pm_sel, no Propagate / UpFull) at 1920x1088."""
import torch
import torch.nn as nn
from model_v2 import MLOF2
from nfru_head import NfruHeadC2

H, W = 1088, 1920
m = MLOF2(convex_up=True, deep16=True, pm_sel=True).eval()
c = lambda mod: sum(p.numel() for p in mod.parameters())
p = m.pair
print(f"params: encoder {c(m.enc):,} | levels " + ", ".join(f"1/{k} {c(v):,}" for k, v in p.upd.items()) +
      f" | DeepRefine {c(p.deep):,} | PMSelect {c(p.pms):,} | OF total {c(m.enc) + c(p.upd) + c(p.deep) + c(p.pms):,}"
      f" | head C2 {c(NfruHeadC2(arm_init=False)):,}")
macs = {}


def hook(name):
    def f(mod, inp, out):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        n = out.numel() * (mod.in_channels // mod.groups) * k
        key = ".".join(name.split(".")[:3]) if name.startswith("pair.upd") else ("enc" if name.startswith("enc") else ".".join(name.split(".")[:2]))
        macs[key] = macs.get(key, 0) + n
    return f


for name, mod in m.named_modules():
    if isinstance(mod, nn.Conv2d):
        mod.register_forward_hook(hook(name))
with torch.no_grad():
    x = [torch.rand(1, ch, H, W) for ch in (3, 1, 3, 1)]
    fa = m.enc(x[0], x[1]); enc = macs.pop("enc"); fb = m.enc(x[2], x[3]); macs.pop("enc")
    m.pair.of_forward(fa, fb, x[0], x[2])
corr = sum((H // lv) * (W // lv) * 2 * (2 * p.radius[lv] + 1) ** 2 * fb[lv].shape[1] for lv in p.LEVELS)
n_c = p.pms.off.shape[0]
search = H * W * n_c * (12 + 3 + 9 + 49)                                                                                
print(f"encoder (1 frame) {enc / 1e9:.2f} GMAC")
for k in sorted(macs):
    print(f"  {k:14s} {macs[k] / 1e9:6.2f} GMAC")
print(f"  correlation  {corr / 1e9:6.2f} GMAC")
print(f"  PMSelect search (no MAC, ~ops) {search / 1e9:.2f} G ops for {n_c} candidates, B->A only")
tot = enc + sum(macs.values()) + corr
print(f"OF MAC total {tot / 1e9:.2f} GMAC (+ head C2 6.40 = {tot / 1e9 + 6.40:.2f}) + PMSelect search {search / 1e9:.2f} G ops")
