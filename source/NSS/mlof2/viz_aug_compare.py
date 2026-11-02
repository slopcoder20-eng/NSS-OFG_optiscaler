"""Two checkpoints on the same Spring val + augmentation windows as diag_aug_of (same seeds): per window the median
EPE on pasted-object pixels (inner + band in) and on the outer band, then a sheet for the windows where checkpoint 2
got worst on the objects:  B (object edge red) | |GT| | EPE ck1 (0..50 px)  /  |OF| ck1 | |OF| ck2 | EPE ck2.
  python viz_aug_compare.py <ck1> <ck2> <out dir> [n_batches] [n_sheets]"""
import os, sys, random
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from model_v2 import build_mlof2, warp, resize_flow, full_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error

ck1, ck2, outd = sys.argv[1], sys.argv[2], sys.argv[3]
nb = int(sys.argv[4]) if len(sys.argv) > 4 else 30
ns = int(sys.argv[5]) if len(sys.argv) > 5 else 4
os.makedirs(outd, exist_ok=True)
dev = "cuda"


def load(ck):
    sd = torch.load(ck, map_location=dev)
    m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
    return m


models = [load(ck1), load(ck2)]
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
gray = lambda x, s: (np.clip(x / s, 0, 1)[..., None] * 255).repeat(3, -1).astype(np.uint8)
rows, keep = [], {}
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        masks = augment(b, random.Random(5000 + bi))
        n, _, H, W = b["color_a"].shape
        gt = b["geo_flow_ba"]
        ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt) > 0.999)
        ok = ok[:, 0] & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]; o = obj[:, 0] > 0.5
        ring = (F.max_pool2d(obj, 17, 1, 8)[:, 0] > 0.5) & ~o
        ofs = []
        for m in models:
            fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
            ofs.append(full_flow(m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])[4], H, W)[:n])
        es = [(f - gt).norm(dim=1) for f in ofs]
        for i in range(n):
            so, sr = o[i] & ok[i], ring[i] & ok[i]
            if so.sum() < 500:
                continue
            r = (bi, i, int(b["span"][i]), float(gt[i].norm(dim=0)[so].median()),
                 *[float(e[i][so].median()) for e in es], *[float(e[i][sr].median()) if sr.sum() > 200 else float("nan") for e in es])
            rows.append(r)
            edge = (F.max_pool2d(obj[i:i + 1], 3, 1, 1)[0, 0] > 0.5) & ~o[i]
            bimg = (b["color_b"][i].clamp(0, 1).permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8)
            bimg[edge.cpu().numpy()] = (255, 0, 0)
            sc = max(float(torch.quantile(gt[i].norm(dim=0).flatten()[::97], 0.98)), 20.0)
            keep[(bi, i)] = [bimg, gray(gt[i].norm(dim=0).cpu().numpy(), sc), gray(es[0][i].cpu().numpy(), 50),
                             gray(ofs[0][i].norm(dim=0).cpu().numpy(), sc), gray(ofs[1][i].norm(dim=0).cpu().numpy(), sc),
                             gray(es[1][i].cpu().numpy(), 50)]
print(f"ck1 {ck1}\nck2 {ck2}")
print(" batch win span | |GT| obj | obj EPE ck1 | ck2 | ring EPE ck1 | ck2")
for r in rows:
    print(f"  {r[0]:3d} {r[1]:3d} {r[2]:4d} | {r[3]:8.1f} | {r[4]:11.2f} | {r[5]:6.2f} | {r[6]:12.2f} | {r[7]:6.2f}")
worst = sorted(rows, key=lambda r: r[5] - r[4], reverse=True)[:ns]
for r in worst:
    row = [np.asarray(Image.fromarray(x).resize((640, 341))) for x in keep[(r[0], r[1])]]
    sheet = np.concatenate([np.concatenate(row[:3], 1), np.concatenate(row[3:], 1)], 0)
    Image.fromarray(sheet).save(os.path.join(outd, f"cmp_b{r[0]}_{r[1]}_span{r[2]}.png"))
    print("sheet", r[0], r[1], f"obj EPE {r[4]:.2f} -> {r[5]:.2f}")
