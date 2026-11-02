"""Check of diag_aug_of's 'object band out' (EPE ~100 px): EPE profile by signed distance to the pasted object's edge
(B positions; negative = inside), counted only on valid pixels, and a sheet per window:
B | object mask (white) + valid band-out pixels (red) | |GT| | |OF| | EPE (0..50 px) | valid mask.
  python viz_aug_band.py <ckpt> <out dir> [n_batches]"""
import os, sys, random
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from model_v2 import build_mlof2, warp, resize_flow, full_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error

ck, outd = sys.argv[1], sys.argv[2]
nb = int(sys.argv[3]) if len(sys.argv) > 3 else 3
os.makedirs(outd, exist_ok=True)
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
prof = {}
gray = lambda x, s: (np.clip(x / s, 0, 1)[..., None] * 255).repeat(3, -1).astype(np.uint8)
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        masks = augment(b, random.Random(5000 + bi))                                     
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        n, _, H, W = b["color_a"].shape
        of = full_flow(m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])[4], H, W)[:n]
        gt = b["geo_flow_ba"]
        e = (of - gt).norm(dim=1)
        ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt) > 0.999)
        ok = ok[:, 0] & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]
                                                                                          
        dist = torch.zeros_like(obj[:, 0])
        cur_out, cur_in = obj.clone(), obj.clone()
        for d in range(1, 17):
            nxt = F.max_pool2d(cur_out, 3, 1, 1); dist[(nxt[:, 0] > 0.5) & (cur_out[:, 0] < 0.5)] = d; cur_out = nxt
            nin = -F.max_pool2d(-cur_in, 3, 1, 1); dist[(cur_in[:, 0] > 0.5) & (nin[:, 0] < 0.5)] = -d; cur_in = nin
        for d in range(-16, 17):
            if d == 0:
                continue
            s = ok & (dist == d)
            if s.sum() > 50:
                p = prof.setdefault(d, [[], [], []])
                p[0].append(float(e[s].median())); p[1].append(float(gt.norm(dim=1)[s].median())); p[2].append(float(of.norm(dim=1)[s].median()))
        for i in range(n):
            if obj[i].sum() < 100:
                continue
            band = (dist[i] > 0) & (dist[i] <= 8)
            mk = np.zeros((H, W, 3), np.uint8); mk[obj[i, 0].cpu().numpy() > 0.5] = 255
            mk[(band & ok[i]).cpu().numpy()] = (255, 0, 0); mk[(band & ~ok[i]).cpu().numpy()] = (90, 0, 0)
            row = [(b["color_b"][i].clamp(0, 1).permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8), mk,
                   gray(gt[i].norm(dim=0).cpu().numpy(), 200), gray(of[i].norm(dim=0).cpu().numpy(), 200),
                   gray(e[i].cpu().numpy(), 50), gray(ok[i].float().cpu().numpy(), 1)]
            row = [np.asarray(Image.fromarray(x).resize((640, 341))) for x in row]
            sheet = np.concatenate([np.concatenate(row[:3], 1), np.concatenate(row[3:], 1)], 0)
            Image.fromarray(sheet).save(os.path.join(outd, f"band_b{bi}_{i}.png"))
print(f"{ck}: EPE by signed distance to the object edge (negative = inside), valid pixels only")
print("  dist | windows | median EPE | median |GT| | median |OF|")
for d in sorted(prof):
    p = prof[d]
    print(f"  {d:4d} | {len(p[0]):7d} | {np.mean(p[0]):10.2f} | {np.mean(p[1]):11.2f} | {np.mean(p[2]):11.2f}")
