import torch
from nfru_head import NfruHeadC, splat_t
from model_v2 import warp
torch.manual_seed(0)
n, H, W = 2, 64, 96
                                                                                     
f = torch.zeros(n, 2, H, W); f[:, 0] = 6.0; f[:, 1] = -2.0
d = torch.rand(n, 1, H, W)
t = torch.tensor([0.5, 0.25])
ta, tb, hole = splat_t(f, d, t)
print("f_tA mean", ta.mean((0, 2, 3)).tolist(), "expected", [float((t * 6).mean()), float((t * -2).mean())], "hole frac", float(hole.mean()))
                                                                                 
a = torch.rand(n, 3, H, W); b = warp(a, -f)                                                                                         
h = NfruHeadC(arm_init=True)
out = h(t, torch.zeros(n, 2, H // 4, W // 4), a, b, d, d, f)
print("out", tuple(out["color"].shape), "weights", [round(x, 3) for x in out["weights"].mean((0, 2, 3)).tolist()])
