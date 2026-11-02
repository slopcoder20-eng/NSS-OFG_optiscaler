"""How much of the gap to the per-pixel best candidate is the selection RESOLUTION? Validation windows with a real
middle frame G (forest/lyra 448 crops, Spring 1024x1920 with game-like degraded MV), clean and augmented. For the head's
4 candidates: best candidate per pixel / per 2x2 / 4x4 / 8x8 block (block-mean |luma - G|, one pick per block), against
the heads' own blends (head B, CE head) and the rel rule on top.
  python eval_oracle_res.py <OF ckpt> <head B ckpt> <CE head ckpt> [n_batches]"""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import to_dev
from nfru_head import load_head_c2
from train_nfru_head import degrade_spring_mv
from selector import rule_rel, luma

ck, hb, hc_ = sys.argv[1], sys.argv[2], sys.argv[3]
nb = int(sys.argv[4]) if len(sys.argv) > 4 else 15
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
heads = {"head B": load_head_c2(hb, dev), "CE head": load_head_c2(hc_, dev)}
for h in heads.values():
    h.talign = "fp"
sets = {"forest/lyra": (WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8), 4),
        "spring": (WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7), 2)}
ROWS = ["best/px", "best/2x2", "best/4x4", "best/8x8", "head B", "head B + rel", "CE head", "CE head + rel"]
with torch.no_grad():
    for name, (ds, bs) in sets.items():
        dl = torch.utils.data.DataLoader(ds, batch_size=bs, shuffle=False, num_workers=2)
        for aug in (False, True):
            acc = {r: [0.0, 0] for r in ROWS}
            for bi, b in enumerate(dl):
                if bi >= nb:
                    break
                b = to_dev(b, dev)
                rng = random.Random(9000 + bi)
                if name == "spring":
                    degrade_spring_mv(b, rng)
                if aug:
                    augment(b, rng)
                ca, cb, g = b["color_a"], b["color_b"], b["color_g"]
                n = ca.shape[0]
                fa, fb = m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"])
                pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], ca, cb)
                of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
                outs = {}
                for hn, h in heads.items():
                    o = h(b["t"], of_q, ca, cb, b["depth_a"], b["depth_b"], b["mv_ba"] * b["mv_valid"], None, None,
                          b["mv_valid"], None, conf_q=pair["conf"][:n], occ_q=pair["occ"][:n])
                    outs[hn] = o["color"]; outs[hn + " + rel"] = rule_rel(o)[0]
                    if hn == "head B":
                        cand = o["cand"]
                e = torch.cat([(luma(cand[:, k].clamp(0, 1)) - luma(g)).abs() for k in range(4)], 1) * 255              
                for s, r in ((1, "best/px"), (2, "best/2x2"), (4, "best/4x4"), (8, "best/8x8")):
                    if s == 1:
                        v = e.amin(1)
                    else:
                        H, W = e.shape[-2:]
                        eb = F.avg_pool2d(e[..., :H // s * s, :W // s * s], s)                                            
                        idx = F.interpolate(eb.argmin(1, keepdim=True).float(), scale_factor=s, mode="nearest").long()
                        v = e[..., :H // s * s, :W // s * s].gather(1, idx).squeeze(1)
                    acc[r][0] += float(v.sum()); acc[r][1] += v.numel()
                for hn, o in outs.items():
                    v = (luma(o.clamp(0, 1)) - luma(g)).abs() * 255
                    acc[hn][0] += float(v.sum()); acc[hn][1] += v.numel()
            print(f"{name:12s} {'augmented' if aug else 'clean':9s}: " + " | ".join(f"{r} {a[0] / a[1]:.2f}" for r, a in acc.items()), flush=True)
