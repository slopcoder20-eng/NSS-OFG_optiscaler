"""Two checks of the foreground-fattening theory (Spring val + augmentation, same seeds as diag_ring_occ, B rows,
valid GT pixels, by signed distance to the pasted object's edge):
 1) where it is born: EPE of every OF level (bilinear to full res) and of the final full-res OF
 2) can a small-window matching cost pick the right flow? PatchMatch-style oracle, no learning: candidates = the
    1/4 flow of the cell itself and of the cells 1, 2, 4, 6 cells away in 8 directions (33); cost = mean |B - A
    pulled by the candidate| (RGB, full res) over
      'cell 4x4' : the cell's own 16 pixels (candidate constant over the cell, one pick per cell)
      'pixel 3x3': a 3x3 window around each full-res pixel (candidate flows bilinear, one pick per pixel)
    the lowest cost wins. No game MV anywhere.
  python diag_ring_theory.py <ckpt> [n_batches]"""
import sys, random
import numpy as np
import torch
import torch.nn.functional as F
from model_v2 import build_mlof2, warp, resize_flow, full_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 10
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
import os
DISTS = tuple(int(x) for x in os.environ.get("DISTS", "1,2,4,6").split(","))                                     
OFFS = [(0, 0)] + [(dy * d, dx * d) for d in DISTS for dy, dx in
                   ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))]


def shift(f, dy, dx):
    """f(y + dy, x + dx) with replicate borders (the flow of the cell dy, dx away)."""
    p = max(abs(dy), abs(dx))
    if p == 0:
        return f
    g = F.pad(f, (p, p, p, p), mode="replicate")
    h, w = f.shape[-2:]
    return g[..., p + dy:p + dy + h, p + dx:p + dx + w]


prof = {}
COLS = ["1/64", "1/32", "1/16", "1/8", "1/4", "final", "PM cell 4x4", "PM pixel 3x3"]
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        masks = augment(b, random.Random(5000 + bi))
        ca, cb = b["color_a"], b["color_b"]
        fa, fb = m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"])
        n, _, H, W = ca.shape
        ofs = m.pair.of_forward(fa, fb, ca, cb)
        flows = {f"1/{lv}": resize_flow(ofs[lv]["of"][:n], H, W) for lv in (64, 32, 16, 8, 4)}
        flows["final"] = full_flow(ofs[4], H, W)[:n]
        of4 = ofs[4]["of"][:n]
        best_c = best_p = None
        for dy, dx in OFFS:
            cand = shift(of4, dy, dx)
            fc = F.interpolate(cand, scale_factor=4, mode="nearest") * 4.0                                  
            dc = (warp(ca, fc) - cb).abs().mean(1, keepdim=True)
            cost_c = F.interpolate(F.avg_pool2d(dc, 4), scale_factor=4, mode="nearest")
            fp = resize_flow(cand, H, W)
            cost_p = F.avg_pool2d((warp(ca, fp) - cb).abs().mean(1, keepdim=True), 3, 1, 1, count_include_pad=False)
            if best_c is None:
                best_c, flow_c, best_p, flow_p = cost_c, fc, cost_p, fp
            else:
                tc, tp = cost_c < best_c, cost_p < best_p
                best_c = torch.where(tc, cost_c, best_c); flow_c = torch.where(tc, fc, flow_c)
                best_p = torch.where(tp, cost_p, best_p); flow_p = torch.where(tp, fp, flow_p)
        flows["PM cell 4x4"], flows["PM pixel 3x3"] = flow_c, flow_p
        gt = b["geo_flow_ba"]
        ok = (explain_error(ca, cb, gt) <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt) > 0.999)
        ok = ok[:, 0] & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]
        dist = torch.zeros_like(obj[:, 0])
        cur_out, cur_in = obj.clone(), obj.clone()
        for d in range(1, 25):
            nxt = F.max_pool2d(cur_out, 3, 1, 1); dist[(nxt[:, 0] > 0.5) & (cur_out[:, 0] < 0.5)] = d; cur_out = nxt
            nin = -F.max_pool2d(-cur_in, 3, 1, 1); dist[(cur_in[:, 0] > 0.5) & (nin[:, 0] < 0.5)] = -d; cur_in = nin
        groups = {"in 9..24": (dist <= -9), "in 1..8": (dist < 0) & (dist >= -8),
                  "out 1..4": (dist >= 1) & (dist <= 4), "out 5..8": (dist >= 5) & (dist <= 8),
                  "out 9..16": (dist >= 9) & (dist <= 16), "out 17..24": (dist >= 17) & (dist <= 24),
                  "far background": (dist == 0) & (obj[:, 0] < 0.5)}
        for g, sel in groups.items():
            s = sel & ok
            if s.sum() > 200:
                p = prof.setdefault(g, {c: [] for c in COLS})
                for c in COLS:
                    p[c].append(float((flows[c] - gt).norm(dim=1)[s].median()))
print(f"{ck}: {nb} Spring val batches + augmentation; median EPE (px), valid GT pixels, B rows; candidate distances {DISTS} ({len(OFFS)} candidates)")
print("  region         | " + " | ".join(f"{c:>12s}" for c in COLS))
for g, p in prof.items():
    print(f"  {g:14s} | " + " | ".join(f"{np.mean(p[c]):12.2f}" for c in COLS))
