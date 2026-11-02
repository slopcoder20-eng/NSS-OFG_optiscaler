"""MACs / params of SEA-RAFT's matching encoder (fnet) at the DLL OF size, CPU."""
import torch
from torch import nn
import teacher_searaft as ts
t = ts.SeaRaftTeacher("cpu")
f = t.model.fnet
macs = [0]
def hook(m, i, o):
    if isinstance(m, nn.Conv2d):
        macs[0] += o.numel() * (m.in_channels // m.groups) * m.kernel_size[0] * m.kernel_size[1]
for m in f.modules(): m.register_forward_hook(hook)
with torch.no_grad():
    out = f(torch.rand(1, 3, 576, 960))
print(f"fnet out {tuple(out.shape)}, params {sum(p.numel() for p in f.parameters())/1e6:.2f} M, {macs[0]/1e9:.2f} GMAC per frame at 960x576")
print(type(f).__name__, [type(c).__name__ for c in f.children()][:12])
