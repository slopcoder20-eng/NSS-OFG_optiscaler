"""PSNR with the game-MV warp as the reference (not the real frame B): how close is A warped by our OF to A warped by
the game MV? Also the flow difference |OF - MV| (median / mean px). Same validation windows as eval_of_cmp.py.
  python eval_of_vs_mv.py <ckpt> [n_batches]"""
import sys
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 40
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval()
m.load_state_dict(sd.get("model", sd))
names = ["forest15", "lyra15", "lyra17"]
sets = {"regular": WindowDataset(names, "validation", crop=448, windows_per_file=8),
        "strided": WindowDataset(names, "validation", crop=448, windows_per_file=8, strides=(1, 2, 3, 4), seed=7)}
with torch.no_grad():
    for name, ds in sets.items():
        dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=2)
        res = {}
        for bi, b in enumerate(dl):
            if bi >= nb:
                break
            b = {k: v.to(dev) if torch.is_tensor(v) else v for k, v in b.items()}
            ca, mv = b["color_a"], b["mv_ba"]
            fa, fb = m.enc(ca, b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
            of = m.pair.of_forward(fa, fb, ca, b["color_b"])[4]["of"]
            n, _, H, W = ca.shape
            f = F.interpolate(of[:n], size=(H, W), mode="bilinear", align_corners=False) * (W / of.shape[-1])
            ones = torch.ones_like(ca[:, :1])
            for i in range(n):
                mk = (warp(ones[i:i+1], f[i:i+1]) > 0.999).float() * (warp(ones[i:i+1], mv[i:i+1]) > 0.999).float()
                ref = warp(ca[i:i+1], mv[i:i+1])
                e = (((warp(ca[i:i+1], f[i:i+1]) - ref) ** 2) * mk).sum() / (3 * mk.sum()).clamp_min(1)
                d = (f[i:i+1] - mv[i:i+1]).norm(dim=1, keepdim=True)[mk > 0]
                k = int(b["span"][i])
                res.setdefault(k, []).append((-10 * torch.log10(e + 1e-10).item(), d.median().item(), d.mean().item()))
        print(f"[{name}] {ck}")
        allv = []
        for k in sorted(res):
            v = torch.tensor(res[k]); allv.append(v)
            print(f"  span {k:2d} n={len(v):3d} | PSNR(OF-warp vs MV-warp) {v[:,0].mean():5.2f} dB | |OF-MV| median {v[:,1].mean():5.2f} px mean {v[:,2].mean():5.2f} px")
        v = torch.cat(allv)
        print(f"  all: {v[:,0].mean():.2f} dB | |OF-MV| median {v[:,1].mean():.2f} px mean {v[:,2].mean():.2f} px")
