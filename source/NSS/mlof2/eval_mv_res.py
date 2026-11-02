"""Robustness to low-resolution game MVs: the validation set (clean, no synthetic layers) with the game MVs (B->A and
A->P) point-sampled at render scale s and brought back to the display grid (data_v2.resample_mv, bilinear or nearest),
as a game rendering at s x display resolution would deliver them. Output PSNR and gate c per setting.
  python eval_mv_res.py <ckpt> [<ckpt> ...]"""
import sys
import torch
from model_v2 import build_mlof2
from data_v2 import WindowDataset, resample_mv
from train_v2 import run, to_dev, psnr

dev = "cuda"
val = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8)
vl = torch.utils.data.DataLoader(val, batch_size=4, shuffle=False, num_workers=0)
settings = [(1.0, "bilinear"), (0.67, "bilinear"), (0.5, "bilinear"), (0.5, "nearest"), (0.33, "bilinear"), (0.33, "nearest")]
for ck in sys.argv[1:]:
    sd = torch.load(ck, map_location=dev)
    m = build_mlof2(sd).to(dev).eval()
    sd = sd.get("model", sd)
    own = m.state_dict()
    for k, v in sd.items():                                                                                          
        if k in own and v.shape != own[k].shape and v.shape[1:] == own[k].shape[1:] and v.shape[0] < own[k].shape[0]:
            pad = own[k].clone().zero_(); pad[: v.shape[0]] = v; sd[k] = pad
    m.load_state_dict(sd)
    res = {s: [[], []] for s in settings}
    with torch.no_grad():
        for bi, b in enumerate(vl):
            if bi >= 40:
                break
            b = to_dev(b, dev)
            orig = {k: b[k].clone() for k in ("mv_ba", "mv_ap")}
            for s, up in settings:
                for k in ("mv_ba", "mv_ap"):
                    b[k] = orig[k] if s == 1.0 else torch.stack([resample_mv(x, s, up) for x in orig[k]])
                frame, pair = run(m, b, use_prev=True)
                res[(s, up)][0].append(psnr(frame["color"], b["color_g"]))
                res[(s, up)][1].append(pair["gate"].mean().item())
    print(ck)
    for (s, up), (p, c) in res.items():
        print(f"  MV at {s:.2f} x display, {up:8s}: PSNR {sum(p) / len(p):.2f} dB, c mean {sum(c) / len(c):.3f}")
