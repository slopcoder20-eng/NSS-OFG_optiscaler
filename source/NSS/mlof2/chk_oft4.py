import torch
from oft_block import OFTNet, gmac
n = OFTNet((128, 96, 64, 48), (3, 3, 3, 3))
print(n.SCALES, sum(p.numel() for p in n.parameters()), round(gmac(n), 1))
x = torch.rand(1, 3, 448, 448)
o = n(torch.tensor([0.3]), x, x, torch.zeros(1, 2, 56, 56), torch.zeros(1, 2, 56, 56))
print(o["color"].shape)
