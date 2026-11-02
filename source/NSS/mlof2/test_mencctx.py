import torch
from torch import nn
from model_v2 import MLOF2, build_mlof2
R = "/home/sh/mlof2_runs"
m = build_mlof2(torch.load(f"{R}/v2_of_encpre/rect_menc0.pt", map_location="cpu")); print("old menc ckpt loads:", m.load_state_dict(torch.load(f"{R}/v2_of_encpre/rect_menc0.pt", map_location="cpu")))
m2 = MLOF2(enc_deep=True, enc_fpn=True, recur8=3, enc_match=True, enc_match_ctx=True).eval()
macs = [0]
def hk(mod, i, o):
    if isinstance(mod, nn.Conv2d): macs[0] += o.numel() * (mod.in_channels // mod.groups) * mod.kernel_size[0] * mod.kernel_size[1]
for mod in m2.enc.menc.modules(): mod.register_forward_hook(hk)
c, d = torch.rand(1, 3, 576, 960), torch.rand(1, 1, 576, 960)
with torch.no_grad(): f = m2.enc(c, d)
print("m8", tuple(f["m8"].shape), f"menc ctx {macs[0]/1e9:.2f} GMAC", "rebuilt ctx:", build_mlof2(m2.state_dict()).enc.menc.t16 is not None)
