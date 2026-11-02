"""Why does the OF spill a pasted object's motion into the background ring around it? Hypothesis: the round-trip
occlusion test (of_losses.of_loss) marks the ring occluded because the OF is wrong there, so the census loss skips
it and only the weak geo term pulls on it. Per signed distance to the object edge (B positions; valid GT pixels):
  share of pixels the census loss counts (same mask as of_loss: half res, vis > 0.99), OF EPE,
  photometric explain error (min-neighbour SMAPE) of the OF flow vs of the GT flow.
  python diag_ring_occ.py <ckpt> [n_batches]"""
import sys, random
import numpy as np
import torch
import torch.nn.functional as F
from model_v2 import build_mlof2, warp, resize_flow, full_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error, round_trip_occlusion

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 10
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
prof = {}
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        masks = augment(b, random.Random(5000 + bi))
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        n, _, H, W = b["color_a"].shape
        out4 = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])[4]
        o4 = out4["of"]
        of = full_flow(out4, H, W)[:n]
        occ_b = round_trip_occlusion(o4[:n], o4[n:])                                                
        vis_b = 1 - F.interpolate(occ_b, size=(H, W), mode="nearest")
        counted = F.interpolate((F.interpolate(vis_b, size=(H // 2, W // 2), mode="area") > 0.99).float(), size=(H, W), mode="nearest")[:, 0] > 0.5
        gt = b["geo_flow_ba"]
        e = (of - gt).norm(dim=1)
        e_bil = (resize_flow(o4[:n], H, W) - gt).norm(dim=1)                                                      
        ex_gt = explain_error(b["color_a"], b["color_b"], gt)[:, 0]
        ex_of = explain_error(b["color_a"], b["color_b"], of)[:, 0]
        ok = (ex_gt <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt)[:, 0] > 0.999)
        ok = ok & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]
        dist = torch.zeros_like(obj[:, 0])
        cur_out, cur_in = obj.clone(), obj.clone()
        for d in range(1, 25):
            nxt = F.max_pool2d(cur_out, 3, 1, 1); dist[(nxt[:, 0] > 0.5) & (cur_out[:, 0] < 0.5)] = d; cur_out = nxt
            nin = -F.max_pool2d(-cur_in, 3, 1, 1); dist[(cur_in[:, 0] > 0.5) & (nin[:, 0] < 0.5)] = -d; cur_in = nin
        far = (dist == 0) & (obj[:, 0] < 0.5)
        groups = {f"in {a}..{b_}": (dist <= -a) & (dist >= -b_) for a, b_ in ((9, 24), (1, 8))}
        groups.update({f"out {a}..{b_}": (dist >= a) & (dist <= b_) for a, b_ in ((1, 4), (5, 8), (9, 16), (17, 24))})
        groups["far background"] = far
        for g, sel in groups.items():
            s = sel & ok
            if s.sum() > 200:
                p = prof.setdefault(g, [[], [], [], [], []])
                p[4].append(float(e_bil[s].median()))
                p[0].append(float(counted[s].float().mean())); p[1].append(float(e[s].median()))
                p[2].append(float(ex_of[s].mean())); p[3].append(float(ex_gt[s].mean()))
print(f"{ck}: {nb} Spring val batches + augmentation, valid GT pixels")
print("  region         | windows | census counts | median EPE | EPE bilinear | explain err OF | explain err GT")
for g, p in prof.items():
    print(f"  {g:14s} | {len(p[0]):7d} | {100 * np.mean(p[0]):12.1f}% | {np.mean(p[1]):10.2f} | {np.mean(p[4]):12.2f} | {np.mean(p[2]):14.3f} | {np.mean(p[3]):14.3f}")
