"""Upper bounds of the two ways to combine the game MV and the OF, on Spring validation windows (exact GT flow and the
real middle frame G; game-like degraded MV as in train_nfru_head), clean and with the augmentation (pasted layers with
wrong MV; their true motion is in geo_flow_ba).
  source-grid ('fused'): one B->A flow chosen per B pixel, moved to t once, the head's A/B blend of the two candidates
    'GT flow'          the exact flow itself (ceiling of any single-flow method)
    'fused oracle'     per pixel the one of MV / OF closer to the GT flow
    'fused rule'       selector.fuse_flow (relative photometric test)
  t-grid: the head's 4 candidates (MV->A, MV->B, OF->A, OF->B)
    'best of 4 (t)'    per pixel the candidate closest to G
    'head', 'mv only', 'abs 0.08', 'rel'
Mean |luma - G| (8-bit) over all pixels / over the augmented pixels.
  python eval_oracle_fused.py <OF ckpt> <head ckpt> [n_batches]"""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import to_dev
from nfru_head import load_head_c2
from train_nfru_head import degrade_spring_mv
from selector import mv_only, rule_abs, rule_rel, luma, fuse_flow

ck, hk = sys.argv[1], sys.argv[2]
nb = int(sys.argv[3]) if len(sys.argv) > 3 else 20
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = "fp"
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False, num_workers=2)
V = ("GT flow", "fused oracle", "fused rule", "best of 4 (t)", "head", "mv only", "abs 0.08", "rel")
with torch.no_grad():
    for aug in (False, True):
        acc = {v: [0.0, 0.0, 0.0, 0.0] for v in V}
        share = []
        for bi, b in enumerate(dl):
            if bi >= nb:
                break
            b = to_dev(b, dev)
            rng = random.Random(9000 + bi)
            degrade_spring_mv(b, rng)
            g0 = b["color_g"].clone()
            if aug:
                augment(b, rng)
            augm = ((b["color_g"] - g0).abs().amax(1, keepdim=True) > 0.02).float()
            ca, cb, g = b["color_a"], b["color_b"], b["color_g"]
            n, _, H, W = ca.shape
            fa, fb = m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"])
            pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], ca, cb)
            of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
            of = of_q if of_q.shape[-2:] == (H, W) else F.interpolate(of_q, size=(H, W), mode="bilinear", align_corners=False) * (W / of_q.shape[-1])
            mv = b["mv_ba"] * b["mv_valid"]
            gt = b["geo_flow_ba"]
            pick_of = ((of - gt).norm(dim=1, keepdim=True) < (mv - gt).norm(dim=1, keepdim=True)).float()
            share.append(float(pick_of.mean()))
            ones = torch.ones_like(b["mv_valid"])
            conf = pair["conf"][:n]
            run = lambda flow, val: head(b["t"], of_q, ca, cb, b["depth_a"], b["depth_b"], flow, None, None, val, None, conf_q=conf)
            outs = {"GT flow": mv_only(run(gt, ones)),
                    "fused oracle": mv_only(run(torch.where(pick_of > 0.5, of, mv), ones)),
                    "fused rule": mv_only(run(fuse_flow(ca, cb, mv, b["mv_valid"], of)[0], ones))}
            hc = run(mv, b["mv_valid"])
            errs = torch.stack([(luma(hc["cand"][:, k].clamp(0, 1)) - luma(g)).abs() for k in range(4)])
            outs.update({"head": hc["color"], "mv only": mv_only(hc), "abs 0.08": rule_abs(hc)[0], "rel": rule_rel(hc)[0]})
            for v, o in outs.items():
                e = (luma(o.clamp(0, 1)) - luma(g)).abs() * 255
                a = acc[v]; a[0] += float(e.sum()); a[1] += e.numel(); a[2] += float((e * augm).sum()); a[3] += float(augm.sum())
            e = errs.amin(0) * 255                                                                                     
            a = acc["best of 4 (t)"]; a[0] += float(e.sum()); a[1] += e.numel(); a[2] += float((e * augm).sum()); a[3] += float(augm.sum())
        print(f"Spring val {'augmented' if aug else 'clean':9s} ({nb} batches, MV degraded game-like; OF closer to GT on "
              f"{100 * sum(share) / len(share):.1f}% of pixels): mean |luma - G| (8-bit) all" + (" / augmented px" if aug else ""))
        for v in V:
            a = acc[v]
            print(f"  {v:14s} {a[0] / a[1]:7.2f}" + (f" / {a[2] / max(a[3], 1):7.2f}" if aug else ""), flush=True)
