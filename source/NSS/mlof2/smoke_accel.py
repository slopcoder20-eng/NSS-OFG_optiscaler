import torch
from nfru_head import splat_t
n, H, W = 2, 48, 64
fba = torch.zeros(n, 2, H, W); fba[:, 0] = 8.0
d = torch.rand(n, 1, H, W); t = torch.tensor([0.5, 0.25])
la, lb, _ = splat_t(fba, d, t)
qa, qb, _ = splat_t(fba, d, t, 2 * fba)                                                             
print("linear == quadratic(const vel):", torch.allclose(la, qa), torch.allclose(lb, qb))
                                                                                            
qa, qb, _ = splat_t(fba, d, t, 12 * torch.ones_like(fba) * torch.tensor([1., 0.]).view(1, 2, 1, 1))
for i, tv in enumerate(t.tolist()):
    disp = 8 - 6 * tv - 2 * tv * tv
    print(f"t={tv}: toA x mean {qa[i,0,10:-10,20:-20].mean():.3f} expected {8 - disp:.3f} | toB {qb[i,0,10:-10,20:-20].mean():.3f} expected {-disp:.3f}")
