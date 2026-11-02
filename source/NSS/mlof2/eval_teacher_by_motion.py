"""(teacher version: SEA-RAFT flow instead of the checkpoint)
OF accuracy by motion size (per pixel, binned by |game MV| in px): |OF - MV| median/mean and the magnitude ratio
|OF| / |MV| (under- or over-estimation). Regular + strided validation windows, in-screen pixels of both flows.
  python eval_of_by_motion.py <ckpt> [n_batches]"""
import sys
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset

from teacher_searaft import SeaRaftTeacher
ck = "SEA-RAFT teacher"
nb = int(sys.argv[1]) if len(sys.argv) > 1 else 40
dev = "cuda"
T = SeaRaftTeacher(dev)
names = ["forest15", "lyra15", "lyra17"]
sets = {"regular": WindowDataset(names, "validation", crop=448, windows_per_file=8),
        "strided": WindowDataset(names, "validation", crop=448, windows_per_file=8, strides=(1, 2, 3, 4), seed=7)}
edges = [0, 1, 2, 4, 8, 16, 32, 64, 1e9]
with torch.no_grad():
    for name, ds in sets.items():
        dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=2)
        err, mag_of, mag_mv = [], [], []
        for bi, b in enumerate(dl):
            if bi >= nb:
                break
            b = {k: v.to(dev) if torch.is_tensor(v) else v for k, v in b.items()}
            ca, mv = b["color_a"], b["mv_ba"]
            with torch.autocast("cuda", dtype=torch.float16):
                f, _, _ = T.flow_ba(b["color_b"], ca)
            f = f.float()
            ones = torch.ones_like(ca[:, :1])
            mk = ((warp(ones, f) > 0.999) & (warp(ones, mv) > 0.999))[:, 0]
            e = (f - mv).norm(dim=1)[mk]
            mo, mm = f.norm(dim=1)[mk], mv.norm(dim=1)[mk]
            sel = torch.randperm(e.numel(), device=dev)[:200000]                                   
            err.append(e[sel].cpu()); mag_of.append(mo[sel].cpu()); mag_mv.append(mm[sel].cpu())
        e, mo, mm = torch.cat(err), torch.cat(mag_of), torch.cat(mag_mv)
        print(f"[{name}] {ck}  ({e.numel()} sampled pixels)")
        for lo, hi in zip(edges[:-1], edges[1:]):
            s = (mm >= lo) & (mm < hi)
            if s.sum() < 100:
                continue
            ratio = (mo[s].median() / mm[s].median().clamp_min(1e-3)).item()
            print(f"  |MV| {lo:>4}-{hi if hi < 1e8 else 'inf':>4} px: share {100 * s.float().mean():5.1f}% | |OF-MV| median {e[s].median():6.2f} "
                  f"mean {e[s].mean():6.2f} px | |OF|/|MV| (medians) {ratio:5.2f}")
