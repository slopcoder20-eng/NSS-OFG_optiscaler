"""MV-pair ghosts on Spring: wrong t position (trajectory) or content that differs between A and B? The MV is Spring's
exact B->A flow (no degradation, no augmentation), so the head's MV candidates are wrong only by the trajectory to t
(linear / clamped quadratic in invert_t) or by occlusion / content change. Reference: the exact G->A flow and the exact
G->B flow (invert_t of the exact B->G flow at t = 0). On the MV-pair ghost pixels (MV->A and MV->B both > 0.25 in the
head's blend, different content), luma error vs the real G (8-bit):
  head        the head output
  MV blend    the head's MV-pair blend (its own A/B split)
  GT traj     same split, candidates resampled with the exact G->A / G->B flows (trajectory fixed, nothing else)
  GT best     the better single side of the exact-trajectory pair (occlusion handled by choosing)
and trajectory error |head t-flow - exact| (px) on those pixels and elsewhere.
  [STRIDES=1,2] [TALIGN=kpn KPN_CKPT=..] python diag_traj_spring.py <OF ckpt> <head ckpt> [n_batches]"""
import os, sys
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset
from train_v2 import to_dev
from nfru_head import load_head_c2, invert_t
from selector import luma

ck, hk = sys.argv[1], sys.argv[2]
nb = int(sys.argv[3]) if len(sys.argv) > 3 else 40
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = os.environ.get("TALIGN", "fp")                                 
if head.talign == "kpn":
    from talign_kpn import TAlignKPN
    if os.environ.get("TALIGN_ARCH") == "net":
        from talign_net import TAlignNet as TAlignKPN
    head.talign_net = TAlignKPN().to(dev).eval()
    head.talign_net.load_state_dict(torch.load(os.environ["KPN_CKPT"], map_location=dev))
    head.talign_net.refine_iters = int(os.environ.get("TNET_REFINE", "0"))                                            
    head.talign_net.refine_hyps = os.environ.get("TNET_HYPS") == "1"                                             
ds = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=tuple(int(x) for x in os.environ.get("STRIDES", "1,2,4,8,12").split(",")), seed=7,
                   tri=True)
dl = torch.utils.data.DataLoader(ds, batch_size=1, shuffle=False, num_workers=2)
ROWS = ("head", "MV blend", "GT traj", "GT best", "GT best 4x4", "GT best 8x8")
acc = {k: 0.0 for k in ROWS}
npx = 0.0
ep = {"ghost A": 0.0, "ghost B": 0.0, "other A": 0.0, "other B": 0.0}
nother = 0.0
nghost_ok = [0.0]
rules = {}
by_t = {}
diff = lambda x, y: F.avg_pool2d((x - y).abs().mean(1, keepdim=True), 3, 1, 1)
with torch.no_grad():
    for bi, b in enumerate(dl):
        if bi >= nb:
            break
        b = to_dev(b, dev)
        if bool(b["cut"].any()):
            continue
        ca, cb, g, t = b["color_a"], b["color_b"], b["color_g"], b["t"]
        fa, fb = m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"])
        pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        hc = head(t, of_q, ca, cb, b["depth_a"], b["depth_b"], b["mv_ba"], b["mv_ap"], None, b["mv_valid"], None,
                  conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
        w, c = hc["weights"], hc["cand"]
        ma, mb = hc["tflows"][0], hc["tflows"][1]
        ga = b["geo_flow_ga"]
        _, gb, gh = invert_t(b["geo_flow_bg"], b["depth_b"], torch.zeros_like(t))                                    
        ghost = ((torch.minimum(w[:, 0:1], w[:, 1:2]) > 0.25) & (diff(c[:, 0], c[:, 1]) > 10 / 255))[:, 0]
        w2 = w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6)
        mvb = w2[:, 0:1] * c[:, 0] + w2[:, 1:2] * c[:, 1]
        ta, tb = warp(ca, ga), warp(cb, gb)
        gtb = w2[:, 0:1] * ta + w2[:, 1:2] * tb
        lg = luma(g)
        e = lambda x: ((luma(x.clamp(0, 1)) - lg).abs() * 255)[:, 0]
        errs = {"head": e(hc["color"]), "MV blend": e(mvb), "GT traj": e(gtb), "GT best": torch.minimum(e(ta), e(tb))}
        for bs_ in (4, 8):                                                                                                     
            ea_, eb_ = e(ta), e(tb)
            pa = F.interpolate((F.avg_pool2d(ea_[:, None], bs_) <= F.avg_pool2d(eb_[:, None], bs_)).float(), scale_factor=bs_, mode="nearest")[:, 0] > 0.5
            errs[f"GT best {bs_}x{bs_}"] = torch.where(pa, ea_, eb_)
        s = ghost
        n = float(s.sum())
        npx += n
        for k in ROWS:
            acc[k] += float(errs[k][s].sum())
        dA, dB = (ma - ga).norm(dim=1), (mb - gb).norm(dim=1)
        okg = gh[:, 0] < 0.5                                                                                               
        sg, og = s & okg, ~s & okg
        ep["ghost A"] += float(dA[sg].sum()); ep["ghost B"] += float(dB[sg].sum())
        ep["other A"] += float(dA[og].sum()); ep["other B"] += float(dB[og].sum())
        nother += float(og.sum()); nghost_ok[0] += float(sg.sum())
        da_, db_ = b["depth_a"], b["depth_b"]
        ofb = 0.5 * (c[:, 2] + c[:, 3])
        eA, eB = e(c[:, 0]), e(c[:, 1])
        for traj, (fa_, fb_, xa, xb) in (("ours", (ma, mb, c[:, 0], c[:, 1])), ("GT", (ga, gb, ta, tb))):
            dA, dB = warp(da_, fa_)[:, 0], warp(db_, fb_)[:, 0]
            ea, eb = e(xa), e(xb)
            orc = ea <= eb
            vA, vB = diff(xa, ofb)[:, 0], diff(xb, ofb)[:, 0]
            for k, pk in (("near", dA >= dB), ("far", dA < dB), ("OF vote", vA <= vB)):
                r = rules.setdefault((traj, k), [0.0, 0.0])
                r[0] += float((pk == orc)[s].sum()); r[1] += float(torch.where(pk, ea, eb)[s].sum())
        tk = round(float(t), 2)
        bt = by_t.setdefault(tk, [0.0, 0.0, 0.0, 0.0])
        bt[0] += n; bt[1] += float(errs["MV blend"][s].sum()); bt[2] += float(errs["GT traj"][s].sum())
        bt[3] += float(s.numel())
print(f"Spring validation, exact MV, {hk}: MV-pair ghost pixels {npx / 1e6:.2f}M")
print("  luma err there: " + " | ".join(f"{k} {acc[k] / max(npx, 1):.2f}" for k in ROWS))
print(f"  t-flow error (px, real G->B defined): ghost A {ep['ghost A'] / max(nghost_ok[0], 1):.2f} B {ep['ghost B'] / max(nghost_ok[0], 1):.2f} | "
      f"other A {ep['other A'] / max(nother, 1):.2f} B {ep['other B'] / max(nother, 1):.2f}")
print("  by t: " + " | ".join(f"t={k}: share {100 * v[0] / v[3]:.1f}% blend {v[1] / max(v[0], 1):.1f} -> GT traj {v[2] / max(v[0], 1):.1f}"
                            for k, v in sorted(by_t.items())))
print("  hard pick on those pixels (err, share agreeing with the better side): " + " | ".join(
    f"{tr}/{k} {v[1] / max(npx, 1):.2f} ({100 * v[0] / max(npx, 1):.0f}%)" for (tr, k), v in rules.items()))
