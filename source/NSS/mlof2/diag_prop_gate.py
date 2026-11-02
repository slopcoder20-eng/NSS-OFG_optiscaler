"""Is the Propagate module doing anything at the fattened ring? Spring val + augmentation (same seeds as
diag_ring_occ). Per signed distance to the pasted object's edge (valid GT pixels, B rows): mean gate per iteration
(starts 0.0025), |flow change| by the module (full-res px), EPE of the 1/4 flow before and after the module
(both bilinear to full res).
  python diag_prop_gate.py <ckpt> [n_batches]"""
import sys, random
import numpy as np
import torch
import torch.nn.functional as F
from model_v2 import build_mlof2, warp, resize_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 10
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
assert m.pair.prop4, "checkpoint has no Propagate module"
cap = {}
m.pair.prop.register_forward_hook(lambda mod, inp, out: cap.update(before=inp[0], after=out))
m.pair.prop.head.register_forward_hook(lambda mod, inp, out: cap.update(head=out))
K = len(m.pair.prop.DIL)
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
        m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
        gate = torch.sigmoid(cap["head"][:n, 9 * K:])
        gate = F.interpolate(gate, size=(H, W), mode="nearest")
        f0, f1 = resize_flow(cap["before"][:n], H, W), resize_flow(cap["after"][:n], H, W)
        gt = b["geo_flow_ba"]
        e0, e1 = (f0 - gt).norm(dim=1), (f1 - gt).norm(dim=1)
        dch = (f1 - f0).norm(dim=1)
        ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt) > 0.999)
        ok = ok[:, 0] & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]
        dist = torch.zeros_like(obj[:, 0])
        cur_out, cur_in = obj.clone(), obj.clone()
        for d in range(1, 25):
            nxt = F.max_pool2d(cur_out, 3, 1, 1); dist[(nxt[:, 0] > 0.5) & (cur_out[:, 0] < 0.5)] = d; cur_out = nxt
            nin = -F.max_pool2d(-cur_in, 3, 1, 1); dist[(cur_in[:, 0] > 0.5) & (nin[:, 0] < 0.5)] = -d; cur_in = nin
        groups = {"in 1..24": (dist < 0), "out 1..4": (dist >= 1) & (dist <= 4), "out 5..8": (dist >= 5) & (dist <= 8),
                  "out 9..16": (dist >= 9) & (dist <= 16), "out 17..24": (dist >= 17) & (dist <= 24),
                  "far background": (dist == 0) & (obj[:, 0] < 0.5)}
        for g, sel in groups.items():
            s = sel & ok
            if s.sum() > 200:
                p = prof.setdefault(g, {"gate": [], "chg": [], "e0": [], "e1": []})
                p["gate"].append([float(gate[:, i][s].mean()) for i in range(K)])
                p["chg"].append(float(dch[s].mean())); p["e0"].append(float(e0[s].median())); p["e1"].append(float(e1[s].median()))
print(f"{ck}: {nb} batches. gate per iteration (dilation {m.pair.prop.DIL}), init 0.0025")
print("  region         | gate it1..it6                          | mean |change| px | EPE before | EPE after")
for g, p in prof.items():
    gm = np.mean(np.array(p["gate"]), 0)
    print(f"  {g:14s} | " + " ".join(f"{x:.3f}" for x in gm) + f" | {np.mean(p['chg']):16.2f} | {np.mean(p['e0']):10.2f} | {np.mean(p['e1']):9.2f}")
