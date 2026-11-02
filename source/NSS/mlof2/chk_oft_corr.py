import torch
from oft_block import OFTNet, gmac
n = OFTNet((64, 48, 32, 24), (2, 2, 2, 2), corr=True)
print(n.SCALES, [b.inj is not None for b in n.blocks], sum(p.numel() for p in n.parameters()), round(gmac(n), 2))
x = torch.rand(1, 3, 448, 448)
o = n(torch.tensor([0.3]), x, x, torch.zeros(1, 2, 56, 56), torch.zeros(1, 2, 56, 56))
print(o["color"].shape)
