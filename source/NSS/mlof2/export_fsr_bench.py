"""Export the t = 0.5 validation windows (same loader, order and augmentation RNG as train_v2.validate) for a
black-box FSR frame-generation run, and score our model on the same windows.
Per window and version (clean / aug): P, A, B colour as RGBA8 (display-referred, what a game presents), raw depth
d (z = zNear / (1 - d), recovered from the depth feature), MVs A->P and B->A in display pixels as RG16F
(FSR convention: previous position = current + mv), the ground-truth middle frame G, our output, and for aug the
wrong-MV mask. Raw little-endian files: <out>/<idx>_<ver>_<name>.bin, H x W row-major; index.txt lists windows.
  python export_fsr_bench.py <ckpt> <out_dir> [n_batches]"""
import os
import random
import sys
import numpy as np
import torch
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import run, to_dev, psnr

ck, out = sys.argv[1], sys.argv[2]
nb = int(sys.argv[3]) if len(sys.argv) > 3 else 40
zero_mv = len(sys.argv) > 4 and sys.argv[4] == "--zero_mv"                                                   
os.makedirs(out, exist_ok=True)
dev = "cuda"
sd = torch.load(ck, map_location=dev)
model = build_mlof2(sd).to(dev).eval()
model.load_state_dict(sd.get("model", sd))
import data_v2
data_v2.ROOTS.setdefault("ed512", "/mnt/e/NSSData/electric_dreams_5000_20260929/training_ready_512")                            
names = os.environ.get("BENCH_NAMES", "forest15,lyra15,lyra17").split(",")
wpf = int(os.environ.get("BENCH_WPF", "8"))
val = WindowDataset(names, "validation", crop=448, windows_per_file=wpf)
vl = torch.utils.data.DataLoader(val, batch_size=4, shuffle=False, num_workers=0)


def raw_depth(f):                                                                            
    return (1.0 - torch.exp2(-16.0 * f)).clamp(0, 1 - 1e-6)


def save(path, x):
    x.tofile(path)


def rgba8(c):                                                          
    c = (c.clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
    return np.concatenate([c, np.full(c.shape[:2] + (1,), 255, np.uint8)], -1)


def rg16(m):                                                          
    return m.permute(1, 2, 0).cpu().numpy().astype(np.float16)


rng = random.Random(1234)                                                      
idx_lines, scores = [], {"clean": [], "aug": []}
n = 0
with torch.no_grad():
    for bi, b in enumerate(vl):
        if bi >= nb:
            break
        b = to_dev(b, dev)
        sel = [i for i in range(b["t"].shape[0]) if abs(float(b["t"][i]) - 0.5) < 1e-6]
        for ver in ("clean", "aug"):
            masks = augment(b, rng) if ver == "aug" else None
            if zero_mv:
                for key in ("mv_ba", "mv_ap"): b[key] = torch.zeros_like(b[key])
                b["mv_valid"] = torch.zeros_like(b["mv_valid"])
            frame, _ = run(model, b, use_prev=True)
            for i in sel:
                k = n + sel.index(i)
                p = f"{out}/{k:04d}_{ver}_"
                for nm in ("p", "a", "b"):
                    save(p + f"color_{nm}.bin", rgba8(b[f"color_{nm}"][i]))
                    save(p + f"depth_{nm}.bin", raw_depth(b[f"depth_{nm}"][i, 0]).cpu().numpy().astype(np.float32))
                save(p + "mv_ap.bin", rg16(b["mv_ap"][i]))
                save(p + "mv_ba.bin", rg16(b["mv_ba"][i]))
                save(p + "color_g.bin", rgba8(b["color_g"][i]))
                save(p + "ours.bin", rgba8(frame["color"][i]))
                if masks is not None:
                    save(p + "mv_wrong.bin", (masks["mv_wrong"][i, 0] > 0.5).cpu().numpy().astype(np.uint8))
                scores[ver].append(psnr(frame["color"][i:i + 1], b["color_g"][i:i + 1]))
        for i in sel:
            idx_lines.append(f"{n + sel.index(i):04d} span {int(b['span'][i])} batch {bi} item {i}")
        n += len(sel)
open(f"{out}/index.txt", "w").write("H 448 W 448\n" + "\n".join(idx_lines) + "\n")
m = lambda v: sum(v) / max(1, len(v))
print(f"windows {n} | ours PSNR (t=0.5 subset, float output): clean {m(scores['clean']):.2f} aug {m(scores['aug']):.2f}")
