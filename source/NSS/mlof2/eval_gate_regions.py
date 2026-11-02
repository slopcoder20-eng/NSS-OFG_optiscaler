"""Does the gate do 'follow the MV, let the OF take over where the MV is wrong'?
Validation windows + the training augmentation (seeded): MV-less / wrong-MV objects, shadows, glints, locked layers.
Region 'aug' = pixels of G changed by the augmentation (mostly content the MV does not describe), 'clean' = the
rest. PSNR of the generated frame per region for the learned gate, c forced to 1 (MV wherever usable) and c forced
to 0 (OF only); gate c on known-wrong vs known-ok MV.
  python eval_gate_regions.py <ckpt> [n_batches]"""
import sys, random
import torch
from model_v2 import MLOF2, build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import run, gate_stats, to_dev

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 30
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval()
m.load_state_dict(sd.get("model", sd))
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8)
dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=2)
ps = lambda x, y, mk: ((((x - y) ** 2) * mk).sum().item(), (3 * mk.sum()).item())
acc = {}
cw, co = [], []
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = to_dev(b, dev)
        g0 = b["color_g"].clone()
        masks = augment(b, random.Random(1000 + bi))
        aug = ((b["color_g"] - g0).abs().amax(1, keepdim=True) > 0.02).float()
        regions = {"aug": aug, "clean": 1 - aug}
        for mode in ("gate", "MV", "OF"):
            m.pair.force_c = {"gate": None, "MV": 1.0, "OF": 0.0}[mode]
            frame, pair = run(m, b, use_prev=False)
            if mode == "gate":
                s = gate_stats(pair["gate"][: b["color_g"].shape[0]], masks["mv_wrong"])
                cw.append(s["c_wrong"]); co.append(s["c_ok"])
            for r, mk in regions.items():
                e, n = ps(frame["color"], b["color_g"], mk)
                a = acc.setdefault((mode, r), [0.0, 0.0]); a[0] += e; a[1] += n
m.pair.force_c = None
import math
print(f"{ck}: {nb} batches")
for r in ("aug", "clean"):
    print(f"  region {r:5s}: " + "  ".join(
        f"{mode} {-10 * math.log10(acc[(mode, r)][0] / max(acc[(mode, r)][1], 1)):6.2f} dB" for mode in ("gate", "MV", "OF")))
cw = [x for x in cw if x == x]; co = [x for x in co if x == x]
print(f"  gate c: known-wrong MV {sum(cw) / max(len(cw), 1):.3f}   known-ok MV {sum(co) / max(len(co), 1):.3f}")
