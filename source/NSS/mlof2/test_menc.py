import torch
from model_v2 import MLOF2, MatchEncoder, build_mlof2
from torch import nn
m = MLOF2(enc_deep=True, enc_fpn=True, recur8=3, enc_match=True).eval()
macs = [0]
def hk(mod, i, o):
    if isinstance(mod, nn.Conv2d): macs[0] += o.numel() * (mod.in_channels // mod.groups) * mod.kernel_size[0] * mod.kernel_size[1]
for mod in m.enc.menc.modules(): mod.register_forward_hook(hk)
c, d = torch.rand(1, 3, 576, 960), torch.rand(1, 1, 576, 960)
with torch.no_grad():
    f = m.enc(c, d); print({k: tuple(v.shape) for k, v in f.items()})
    print(f"menc {macs[0]/1e9:.2f} GMAC at 960x576, params {sum(p.numel() for p in m.enc.menc.parameters())/1e3:.0f}k")
    o = m.pair.of_forward(f, f, c, c); print("of4", tuple(o[4]["of"].shape))
print("rebuilt enc_match:", build_mlof2(m.state_dict()).enc.menc is not None)
