"""Is splat_t2 deterministic on this GPU? Same SN2 MV / depth input, 5 runs, max difference of the outputs;
the same for scatter_reduce('amin') on int64 alone, and for the candidate colour warp."""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from nfru_head import splat_t2, warp_noise
from data_v2 import chain_backward
from model_v2 import warp

cap = sys.argv[1]
dev = "cuda"
DW, DH, RW, RH, RP = 1920, 1080, 1129, 636, 1132
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))


def mv_one(fr):
    m = np.fromfile(os.path.join(cap, f"{fr:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < 1000)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m)) * torch.tensor(meta[fr]).view(2, 1, 1) * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    return F.interpolate(m[None], size=(DH, DW), mode="bilinear", align_corners=False)[0], F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0]


d = np.fromfile(os.path.join(cap, "010_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
dep = F.interpolate(((torch.log2(1.0 / torch.from_numpy(d.copy()).clamp_min(1e-7)) / 16.0).clamp(0, 1))[None, None], size=(DH, DW), mode="bilinear")
m1, v1 = mv_one(10); m0, v0 = mv_one(9)
mv = chain_backward([m1, m0])[None].to(dev); vv = v1[None].to(dev); dep = dep.to(dev)
t = torch.tensor([0.5], device=dev)
outs = [splat_t2(mv, dep, t, None, vv) for _ in range(5)]
for k in range(1, 5):
    print("splat_t2 run", k, "max |diff| to run 0:", [float((a - b).abs().max()) for a, b in zip(outs[k], outs[0])])
g = torch.Generator(device=dev).manual_seed(0)
tgt = torch.randint(0, 1000, (2_000_000,), device=dev, generator=g)
key = torch.randint(0, 2 ** 40, (2_000_000,), device=dev, generator=g)
big = torch.iinfo(torch.long).max
r = [torch.full((1000,), big, dtype=torch.long, device=dev).scatter_reduce(0, tgt, key, "amin") for _ in range(5)]
ref = torch.full((1000,), big, dtype=torch.long).scatter_reduce(0, tgt.cpu(), key.cpu(), "amin")
print("scatter_reduce amin int64: GPU runs identical:", all(bool((x == r[0]).all()) for x in r), "| equal to CPU:", bool((r[0].cpu() == ref).all()),
      "| mismatching slots vs CPU:", int((r[0].cpu() != ref).sum()))
