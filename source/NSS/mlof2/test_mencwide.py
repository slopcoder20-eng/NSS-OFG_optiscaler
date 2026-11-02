import torch
from torch import nn
from model_v2 import build_mlof2, MatchEncoder
R = "/home/sh/mlof2_runs"
sd = torch.load(f"{R}/v2_of_menc/s1500.pt", map_location="cpu"); m = build_mlof2(sd); print("old menc ckpt:", m.load_state_dict(sd))
for c, o in (((24, 48, 96), 64), ((32, 64, 128), 96), ((32, 64, 128), 128), ((48, 96, 160), 128)):
    me = MatchEncoder(c=c, cout=o, ctx16=96, dil=(2, 4)); macs = [0]
    for mod in me.modules():
        mod.register_forward_hook(lambda mod_, i, out: macs.__setitem__(0, macs[0] + (out.numel() * (mod_.in_channels // mod_.groups) * mod_.kernel_size[0] * mod_.kernel_size[1] if isinstance(mod_, nn.Conv2d) else 0)))
    with torch.no_grad(): me(torch.rand(1, 3, 576, 960), torch.rand(1, 1, 576, 960), torch.rand(1, 96, 36, 60))
    print(f"MatchEncoder ctx c={c} out={o}: {macs[0]/1e9:.2f} GMAC at 960x576, {sum(p.numel() for p in me.parameters())/1e3:.0f}k params")
