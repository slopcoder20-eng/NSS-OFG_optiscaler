"""MACs of the deployed path at 1920x1088 (variant c): encoder (one new frame per pair; A is cached), OF network
(both directions stacked, as of_forward always runs them), UpFull (B -> A rows only at inference), NFRU head C2.
Conv MACs counted with forward hooks (out elements x Cin/groups x k^2); the correlation volumes added by formula."""
import torch
import torch.nn as nn
from model_v2 import MLOF2
from nfru_head import NfruHeadC2

H, W = 1088, 1920
m = MLOF2(convex_up=True, deep16=True, up_full=True).eval()
head = NfruHeadC2(arm_init=False).eval()
macs = {}


def hook(name):
    def f(mod, inp, out):
        k = mod.kernel_size[0] * mod.kernel_size[1]
        cin = mod.in_channels // mod.groups
        if isinstance(mod, nn.ConvTranspose2d):
            n = inp[0].numel() * mod.out_channels // mod.groups * k
        else:
            n = out.numel() * cin * k
        top = name.split(".")[0] if not name.startswith("pair.") else ".".join(name.split(".")[:3 if name.startswith("pair.upd") else 2])
        macs[top] = macs.get(top, 0) + n
    return f


for name, mod in list(m.named_modules()) + [("head." + n, md) for n, md in head.named_modules()]:
    if isinstance(mod, (nn.Conv2d, nn.ConvTranspose2d)):
        mod.register_forward_hook(hook(name))
with torch.no_grad():
    ca, cb, da, db = torch.rand(1, 3, H, W), torch.rand(1, 3, H, W), torch.rand(1, 1, H, W), torch.rand(1, 1, H, W)
    fa = m.enc(ca, da)
    enc_one = macs.pop("enc")
    fb = m.enc(cb, db); macs.pop("enc")
    ofs = m.pair.of_forward(fa, fb, ca, cb)
    up_both = macs.pop("pair.upf")
    mv = torch.zeros(1, 2, H, W)
    head(torch.tensor([0.5]), ofs[4]["of_full"][:1], ca, cb, da, db, mv, None, None, torch.ones(1, 1, H, W), None)
corr = 0
for lv in m.pair.LEVELS:
    r = m.pair.radius[lv]
    c = fb[lv].shape[1]
    cells = (H // lv) * (W // lv) * 2
    corr += cells * (2 * r + 1) ** 2 * c
tot_of = sum(v for k, v in macs.items() if k.startswith("pair."))
print(f"encoder (1 frame)        {enc_one / 1e9:7.2f} GMAC")
for k in sorted(k for k in macs if k.startswith("pair.")):
    print(f"  {k:22s} {macs[k] / 1e9:7.2f} GMAC (both directions)")
print(f"  correlation volumes    {corr / 1e9:7.2f} GMAC (both directions)")
print(f"UpFull B->A only         {up_both / 2 / 1e9:7.2f} GMAC (training runs both: {up_both / 1e9:.2f})")
print(f"NFRU head C2             {macs.get('head', 0) / 1e9:7.2f} GMAC")
total = enc_one + tot_of + corr + up_both / 2 + macs.get("head", 0)
print(f"TOTAL per generated frame pair at 1920x1088: {total / 1e9:.2f} GMAC")
