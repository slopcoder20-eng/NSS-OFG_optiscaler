import torch
from nfru_head import splat_t, splat_t2
n, H, W = 1, 96, 128
y, x = torch.meshgrid(torch.arange(H).float(), torch.arange(W).float(), indexing="ij")
f = torch.stack((0.15 * x, 0.1 * y), 0)[None]                                                                       
d = torch.rand(n, 1, H, W); t = torch.tensor([0.5])
_, _, h1 = splat_t(f, d, t); _, _, h2 = splat_t2(f, d, t)
print("crack-prone flow: holes 1px-splat", float(h1.mean()), "| 2x2 + fill", float(h2.mean()))
v = torch.ones(n, 1, H, W); v[:, :, 30:60, 40:80] = 0                      
_, _, h3 = splat_t2(torch.zeros(n, 2, H, W), d, t, None, v)
print("invalid block (30x40) holes after fill:", float(h3.sum()), "(block area 1200, filled from neighbours up to 8 px)")
