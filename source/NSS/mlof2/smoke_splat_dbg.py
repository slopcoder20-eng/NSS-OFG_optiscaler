import torch
from nfru_head import splat_t
n, H, W = 2, 64, 96
f = torch.zeros(n, 2, H, W); f[:, 0] = 6.0; f[:, 1] = -2.0
d = torch.rand(n, 1, H, W)
for tv in ([0.5, 0.25], [0.0, 1.0]):
    t = torch.tensor(tv)
    _, _, hole = splat_t(f, d, t)
    print(tv, "hole per sample", hole.mean((1, 2, 3)).tolist(), "row0 holes", hole[0, 0, 10].sum().item(), "col holes", hole[0, 0, :, 50].sum().item())
