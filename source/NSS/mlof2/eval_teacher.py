"""Is the SEA-RAFT teacher accurate on our captures? Validation windows (regular and strided), batch 1:
PSNR of B vs A warped by nothing / game MV / teacher flow (in-screen pixels of both), teacher EPE vs the engine
geometry flow where that flow explains the colour, time per pair, peak memory.
  python eval_teacher.py [n_windows] [scale]"""
import sys, time
import torch
from model_v2 import warp
from data_v2 import WindowDataset
from losses_v2 import explain_error
from teacher_searaft import SeaRaftTeacher

n = int(sys.argv[1]) if len(sys.argv) > 1 else 24
scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
dev = "cuda"
T = SeaRaftTeacher(dev)
names = ["forest15", "lyra15", "lyra17"]
sets = {"regular": WindowDataset(names, "validation", crop=448, windows_per_file=8),
        "strided": WindowDataset(names, "validation", crop=448, windows_per_file=8, strides=(1, 2, 3, 4), seed=7)}
ps = lambda x, y, m: -10 * torch.log10((((x - y) ** 2) * m).sum() / (3 * m.sum()).clamp_min(1) + 1e-10).item()
for name, ds in sets.items():
    idx = [int(i * len(ds) / n) for i in range(n)]
    acc, times = {}, []
    for i in idx:
        s = ds[i]
        b = {k: v[None].to(dev) for k, v in s.items() if torch.is_tensor(v) and v.dim() >= 1}
        ca, cb, mv, geo = b["color_a"], b["color_b"], b["mv_ba"], b["geo_flow_ba"]
        torch.cuda.synchronize(); t0 = time.time()
        f, unc, wgt = T.flow_ba(cb, ca, scale)
        torch.cuda.synchronize(); times.append(time.time() - t0)
        ones = torch.ones_like(ca[:, :1])
        m = (warp(ones, mv) > 0.999).float() * (warp(ones, f) > 0.999).float()
        ok = (explain_error(ca, cb, geo) <= 0.5).float() * (warp(ones, geo) > 0.999).float()
        epe = (f - geo).norm(dim=1, keepdim=True)
        k = int(s["span"])
        r = acc.setdefault(k, [])
        r.append((ps(ca, cb, m), ps(warp(ca, mv), cb, m), ps(warp(ca, f), cb, m),
                  ((epe * ok).sum() / ok.sum().clamp_min(1)).item(), epe[ok > 0].median().item() if ok.any() else 0,
                  geo.norm(dim=1).median().item()))
    print(f"[{name}] scale {scale}  teacher {1000 * sum(times[1:]) / max(1, len(times) - 1):.0f} ms/pair (448^2)  "
          f"peak mem {torch.cuda.max_memory_allocated() / 2**30:.2f} GB")
    tot = []
    for k in sorted(acc):
        v = torch.tensor(acc[k]); tot.append(v)
        print(f"  span {k:2d} n={len(v):2d} | none {v[:,0].mean():5.2f}  MV {v[:,1].mean():5.2f}  teacher {v[:,2].mean():5.2f} dB"
              f" | EPE vs geo mean {v[:,3].mean():5.2f} px  median {v[:,4].mean():5.2f} px | |geo| med {v[:,5].mean():5.1f}")
    v = torch.cat(tot)
    print(f"  all: none {v[:,0].mean():.2f}  MV {v[:,1].mean():.2f}  teacher {v[:,2].mean():.2f} dB | EPE mean {v[:,3].mean():.2f} median {v[:,4].mean():.2f}")
