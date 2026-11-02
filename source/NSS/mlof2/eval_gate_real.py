"""On CLEAN real validation windows (no augmentation): how often the relative gate target says the game MV
is beaten by the OF (real MV failures: shadows, foliage, particles, disocclusion), and what c the model gives
in each target class.  python eval_gate_real.py <ckpt> [n_batches]"""
import sys
import torch
from torch.nn import functional as F
from model_v2 import MLOF2
from losses_v2 import gate_target
from data_v2 import WindowDataset

ck, nb = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 8
dev = "cuda"
m = MLOF2().to(dev).eval()
m.load_state_dict(torch.load(ck, map_location=dev))
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", windows_per_file=8)
dl = torch.utils.data.DataLoader(ds, batch_size=2, num_workers=0, shuffle=True,
                                 generator=torch.Generator().manual_seed(0))
cls = {"MV wins": [0, 0.0], "OF wins": [0, 0.0], "undecided": [0, 0.0]}
spans = {}
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items()}
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
        c = pair["gate"][: b["color_a"].shape[0]]
        tgt, w = gate_target(b["color_a"], b["color_b"], b["mv_ba"], b["mv_valid"], pair["of_ba"], c.shape[-2:])
        dec = w > 0.5
        for name, sel in (("MV wins", dec & (tgt > 0.5)), ("OF wins", dec & (tgt <= 0.5)), ("undecided", ~dec)):
            cls[name][0] += int(sel.sum()); cls[name][1] += float(c[sel].sum())
        for i in range(c.shape[0]):
            k = int(b["span"][i])
            of_share = float((dec[i] & (tgt[i] <= 0.5)).float().mean())
            spans.setdefault(k, []).append(of_share)
tot = sum(v[0] for v in cls.values())
print(f"{ck}: clean real windows, gate cells {tot}")
for k, (n, s) in cls.items():
    print(f"  {k:10s}: {100*n/tot:5.1f}% of cells, model c mean {s/max(n,1):.3f}")
for k in sorted(spans):
    print(f"  span {k}: OF-wins share {100*sum(spans[k])/len(spans[k]):.1f}% (n={len(spans[k])})")
