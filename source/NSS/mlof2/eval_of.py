"""Check what the OF branch learned on real (clean) validation windows.
  python eval_of.py <checkpoint.pt> [n_batches]
Per span: PSNR of B vs A warped by the game MV and by the network's own OF (in-screen pixels only), and the
OF end-point error vs the engine (geometry) flow, split into textured and flat pixels (flat = local colour
std below a threshold; there any flow explains the colour, so geometry error there is not a failure)."""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import MLOF2, warp, resize_flow
from data_v2 import WindowDataset

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 40
dev = "cuda"
from model_v2 import PairFlow
sd = torch.load(ck, map_location=dev)
m = MLOF2()
if sd["pair.upd.64.inp.weight"].shape[1] != m.pair.upd["64"].inp.weight.shape[1]:
    m.pair = PairFlow(radius=(4, 3, 3, 2))
m = m.to(dev).eval()
m.load_state_dict(sd)
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", windows_per_file=8)
dl = torch.utils.data.DataLoader(ds, batch_size=2, num_workers=2, shuffle=True, generator=torch.Generator().manual_seed(0))
res = {}
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items()}
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
        H, W = b["color_b"].shape[-2:]
        of = resize_flow(pair["of_ba"], H, W)
        fin = resize_flow(pair["f_ba"], H, W)
        ones = torch.ones_like(b["color_b"][:, :1])
        inside = lambda f: (warp(ones, f) > 0.999).float()
        std = F.avg_pool2d(b["color_b"] ** 2, 7, 1, 3) - F.avg_pool2d(b["color_b"], 7, 1, 3) ** 2
        tex = (std.clamp_min(0).sum(1, keepdim=True).sqrt() > 0.03).float()
        for i in range(b["color_b"].shape[0]):
            k = int(b["span"][i])
            msk = inside(b["mv_ba"][i:i+1]) * inside(of[i:i+1])
            def ps(x):
                e = (((x - b["color_b"][i:i+1]) ** 2) * msk).sum() / (3 * msk.sum()).clamp_min(1)
                return -10 * torch.log10(e + 1e-10).item()
            epe = (of[i:i+1] - b["geo_flow_ba"][i:i+1]).norm(dim=1, keepdim=True)
            t, fl = tex[i:i+1] * msk, (1 - tex[i:i+1]) * msk
            r = res.setdefault(k, [])
            r.append((ps(b["color_a"][i:i+1]), ps(warp(b["color_a"][i:i+1], b["mv_ba"][i:i+1])),
                      ps(warp(b["color_a"][i:i+1], of[i:i+1])), ps(warp(b["color_a"][i:i+1], fin[i:i+1])),
                      ((epe * t).sum() / t.sum().clamp_min(1)).item(), ((epe * fl).sum() / fl.sum().clamp_min(1)).item(),
                      t.mean().item(), pair["gate"][i].mean().item()))
print(f"checkpoint {ck}")
for k in sorted(res):
    v = torch.tensor(res[k])
    print(f"span {k} n={len(v):3d} | PSNR B vs: A {v[:,0].mean():.2f}  MV-warp {v[:,1].mean():.2f}  OF-warp {v[:,2].mean():.2f}"
          f"  final-flow {v[:,3].mean():.2f} | OF EPE vs geometry: textured {v[:,4].mean():.1f}px  flat {v[:,5].mean():.1f}px"
          f" (textured {v[:,6].mean()*100:.0f}%) | c mean {v[:,7].mean():.2f}")
