"""Do the MV/OF choice rules generalise beyond SN2? Validation windows with a real middle frame G:
forest15/lyra15/lyra17 (UE captures, real engine MV, 448 crops) and Spring (exact flow degraded game-like as in
train_nfru_head, 1024x1920), each clean and with the training augmentation (pasted layers whose MV is wrong).
Frozen OF + head (NfruHeadC2, no acceleration); variants: head, mv only, abs rule (thr 0.08), rel rule.
Per set: mean |luma - G| (8-bit) over all pixels and over the augmented pixels (where the MV is wrong / missing),
sharpness (mean |grad luma| output / G).
  python eval_sel.py <OF ckpt> <head ckpt> <talign> [n_batches]"""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import to_dev
from nfru_head import load_head_c2
from train_nfru_head import degrade_spring_mv
from selector import mv_only, rule_abs, rule_rel, luma, contrast

ck, hk, ta = sys.argv[1], sys.argv[2], sys.argv[3]
nb = int(sys.argv[4]) if len(sys.argv) > 4 else 20
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = ta
sets = {"forest/lyra": (WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8), 4),
        "spring": (WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7), 2)}
V = ("head", "mv only", "abs 0.08", "rel")


def grad(x):
    return contrast(x)


with torch.no_grad():
    for name, (ds, bs) in sets.items():
        dl = torch.utils.data.DataLoader(ds, batch_size=bs, shuffle=False, num_workers=2)
        for aug in (False, True):
            acc = {v: [0.0, 0.0, 0.0, 0.0, 0.0] for v in V}                                                  
            nbat = 0
            for bi, b in enumerate(dl):
                if bi >= nb:
                    break
                b = to_dev(b, dev)
                rng = random.Random(9000 + bi)
                if name == "spring":
                    degrade_spring_mv(b, rng)
                g0 = b["color_g"].clone()
                if aug:
                    augment(b, rng)
                augm = ((b["color_g"] - g0).abs().amax(1, keepdim=True) > 0.02).float()
                fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
                pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
                n = b["color_a"].shape[0]
                of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
                hc = head(b["t"], of_q, b["color_a"], b["color_b"], b["depth_a"], b["depth_b"], b["mv_ba"] * b["mv_valid"],
                          None, None, b["mv_valid"], None, conf_q=pair["conf"][:n])
                outs = {"head": hc["color"], "mv only": mv_only(hc), "abs 0.08": rule_abs(hc)[0], "rel": rule_rel(hc)[0]}
                g = b["color_g"]
                gg = grad(g).mean()
                for v, o in outs.items():
                    e = (luma(o.clamp(0, 1)) - luma(g)).abs() * 255
                    a = acc[v]
                    a[0] += float(e.sum()); a[1] += e.numel()
                    a[2] += float((e * augm).sum()); a[3] += float(augm.sum())
                    a[4] += float(grad(o.clamp(0, 1)).mean() / gg.clamp_min(1e-6))
                nbat += 1
            print(f"{name:12s} {'augmented' if aug else 'clean':9s} ({nbat} batches): " + " | ".join(
                f"{v} {a[0] / a[1]:.2f}" + (f" (aug px {a[2] / max(a[3], 1):.2f})" if aug else "") + f" sharp {a[4] / nbat:.3f}"
                for v, a in acc.items()), flush=True)
