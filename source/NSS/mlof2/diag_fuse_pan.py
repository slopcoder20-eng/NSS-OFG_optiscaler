"""Per-candidate PSNR on the pan_rotate validation (why does the fusion not gain on fast turns?)."""
import random, torch
from data_v2 import WindowDataset
from augment_v2 import pan_rotate
from train_v2 import to_dev, psnr
from model_v2 import build_mlof2
from oft_fuse import FuseNet
from train_fuse import load_oft3, run
dev = "cuda"
vl = torch.utils.data.DataLoader(WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8), batch_size=2)
sd = torch.load("/home/sh/mlof2_runs/v2_of_menc/s1500.pt", map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
oft = load_oft3("/home/sh/mlof2_runs/oft5/best.pt", dev)
fuse = FuseNet().to(dev).eval(); fuse.load_state_dict(torch.load("/home/sh/mlof2_runs/fuse1/best.pt", map_location=dev))
rng = random.Random(7)
acc = {}
with torch.no_grad():
    for bi, b in enumerate(vl):
        if bi >= 15:
            break
        b = to_dev(b, dev)
        pan_rotate(b, rng, 640)
        gv = b["gt_valid"]
        out, w, cand, ofc = run(m, oft, fuse, b)
        g = b["color_g"]
        for k, x in (("fused", out), ("of", cand[:, 0]), ("mvA", cand[:, 1]), ("mvB", cand[:, 2])):
            acc.setdefault(k, []).append(psnr(x * gv, g * gv))
        acc.setdefault("gv", []).append(float(gv.mean()))
        acc.setdefault("w_of", []).append(float(w[:, 0].mean()))
print({k: round(sum(v) / len(v), 3) for k, v in acc.items()})
