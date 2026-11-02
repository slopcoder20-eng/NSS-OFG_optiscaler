"""Where are the |MV| >= 64 px pixels and how does the OF fail there? Picks the regular validation windows with the
most such pixels and writes one row per window: frame A | frame B | |MV| (0..128 px) | |OF| (same scale) |
big-motion pixels coloured by |OF-MV| (green < 8 px, yellow < 32, red >= 32), others greyed.
  python viz_big_motion.py <ckpt> <out.png> [n_rows] [n_batches]"""
import sys
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset

ck, outp = sys.argv[1], sys.argv[2]
nrows = int(sys.argv[3]) if len(sys.argv) > 3 else 6
nb = int(sys.argv[4]) if len(sys.argv) > 4 else 40
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval()
m.load_state_dict(sd.get("model", sd))
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8)
dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=2)
cands = []
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) if torch.is_tensor(v) else v for k, v in b.items()}
        ca, cb, mv = b["color_a"], b["color_b"], b["mv_ba"]
        of = m.pair.of_forward(m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"]), ca, cb)[4]["of"]
        n, _, H, W = ca.shape
        f = F.interpolate(of[:n], size=(H, W), mode="bilinear", align_corners=False) * (W / of.shape[-1])
        ones = torch.ones_like(ca[:, :1])
        valid = ((warp(ones, f) > 0.999) & (warp(ones, mv) > 0.999))[:, 0]
        for i in range(n):
            big = (mv[i].norm(dim=0) >= 64) & valid[i]
            cands.append((int(big.sum()), ca[i].cpu(), cb[i].cpu(), mv[i].cpu(), f[i].cpu(), valid[i].cpu(), int(b["span"][i])))
cands.sort(key=lambda c: -c[0])


def img(t):
    return (t.clamp(0, 1).permute(1, 2, 0).numpy() ** (1 / 2.2) * 255).astype(np.uint8)


def mag(v):
    x = (v.norm(dim=0) / 128).clamp(0, 1).numpy()
    return (np.stack([x, x, x], -1) * 255).astype(np.uint8)


rows = []
for cnt, ca, cb, mv, f, valid, span in cands[:nrows]:
    e = (f - mv).norm(dim=0)
    big = (mv.norm(dim=0) >= 64) & valid
    base = (img(ca).astype(np.float32) * 0.35).astype(np.uint8)
    col = np.where((e < 8)[..., None].numpy(), [0, 220, 0], np.where((e < 32)[..., None].numpy(), [230, 220, 0], [230, 0, 0]))
    over = np.where(big[..., None].numpy(), col, base).astype(np.uint8)
    rows.append(np.concatenate([img(ca), img(cb), mag(mv), mag(f), over], 1))
    eb = e[big]
    print(f"span {span}: big-motion px {cnt}, |OF-MV| median {eb.median():.1f}, <8px {100 * (eb < 8).float().mean():.0f}%, "
          f">=32px {100 * (eb >= 32).float().mean():.0f}%, |MV| median {mv.norm(dim=0)[big].median():.1f}, "
          f"|OF| median {f.norm(dim=0)[big].median():.1f}")
Image.fromarray(np.concatenate(rows, 0)).save(outp)
print("wrote", outp)
