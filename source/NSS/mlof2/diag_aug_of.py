"""The OF in its real job: where the game MV is wrong. Spring validation windows (exact GT) + the training augmentation
(pasted objects with their own motion, MV wrong / missing on part of them). GT = geo_flow_ba after augment() (the
objects' true motion pasted in). Pure OF (no seed), level 1/4 upsampled. Pixels: GT explains B (explain_error <= 0.5),
on screen, no shadow / glint overlay.
  regions: object inner / band in / band out (8 px from the object edge, B positions), object with MV wrong / ok, rest
  per region: median EPE (px), share of pixels with EPE > 8 px; conf: EPE by conf tercile, AUROC (low conf -> EPE > 8)
  python diag_aug_of.py <ckpt> [n_batches]"""
import sys, random
import torch
import torch.nn.functional as F
from model_v2 import build_mlof2, warp, resize_flow, full_flow
from data_v2 import WindowDataset
from augment_v2 import augment
from losses_v2 import explain_error

ck = sys.argv[1]
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 30
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
acc, confs = {}, []
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        masks = augment(b, random.Random(5000 + bi))
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        n, _, H, W = b["color_a"].shape
        ofs = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
        of = full_flow(ofs[4], H, W)[:n]
        conf = F.interpolate(ofs[4]["conf"][:n], size=(H, W), mode="nearest")[:, 0]
        gt = b["geo_flow_ba"]
        e = (of - gt).norm(dim=1)
        ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5) & (warp(torch.ones_like(gt[:, :1]), gt) > 0.999)
        ok = ok[:, 0] & (masks["shadow"][:, 0] < 0.5) & (masks["glint"][:, 0] < 0.5)
        obj = masks["object"]
        grown = F.max_pool2d(obj, 17, 1, 8)[:, 0] > 0.5
        shrunk = -F.max_pool2d(-obj, 17, 1, 8)[:, 0] > 0.5
        o, w = obj[:, 0] > 0.5, masks["mv_wrong"][:, 0] > 0.5
        regions = {"object inner": o & shrunk, "object band in": o & ~shrunk, "object band out": grown & ~o,
                   "object, MV wrong": o & w, "object, MV ok": o & ~w, "rest": ~grown & ~w}
        for rn, rm in regions.items():
            s = rm & ok
            if s.sum() > 500:
                a = acc.setdefault(rn, {"med": [], "bad": [], "gt": []})
                a["med"].append(float(e[s].median())); a["bad"].append(float((e[s] > 8).float().mean()))
                a["gt"].append(float(gt.norm(dim=1)[s].median()))
        s = (grown | w) & ok                                                                                       
        idx = s.nonzero(as_tuple=True)
        if len(idx[0]) > 0:
            pick = torch.randperm(len(idx[0]), device=dev)[:20000]
            confs.append(torch.stack((conf[idx][pick], e[idx][pick]), 1).cpu())
mean = lambda v: sum(v) / len(v)
print(f"{ck}: {nb} Spring val batches + augmentation (pure OF)")
for rn, a in acc.items():
    med = sorted(a["med"])[len(a["med"]) // 2]                                                                  
    print(f"  {rn:17s}: windows {len(a['med']):3d} | median |GT| {mean(a['gt']):6.1f} px | median EPE {mean(a['med']):6.2f} px "
          f"(median over windows {med:5.2f}) | EPE > 8 px {100 * mean(a['bad']):5.1f}%")
cv = torch.cat(confs)
c, e = cv[:, 0], cv[:, 1]
q1, q2 = torch.quantile(c, 1 / 3), torch.quantile(c, 2 / 3)
print("  conf (objects, bands, MV-wrong): median EPE by conf tercile low / mid / high: " + " / ".join(
    f"{float(e[sel].median()):.2f}" for sel in (c <= q1, (c > q1) & (c <= q2), c > q2)))
bad = e > 8
r = torch.empty_like(c); r[c.argsort()] = torch.arange(len(c), dtype=c.dtype)                        
np_, nn_ = int(bad.sum()), int((~bad).sum())
auc = 1 - (r[bad].sum() - np_ * (np_ - 1) / 2) / max(np_ * nn_, 1)                                                
print(f"  conf AUROC (low conf flags EPE > 8 px): {float(auc):.3f}   (0.5 = no information; bad share {100 * np_ / len(c):.1f}%)")
