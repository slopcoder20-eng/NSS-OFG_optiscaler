"""Why are the MV candidates bad on fast turns? pan_rotate validation (pure rotation: MV exact, motion smooth).
Compare invert_t MV candidates with the plain linear ones (F_tA ~ t * mv_ba(x), F_tB ~ -(1-t) * mv_ba(x), exact up to
the variation of mv over t*|mv| for a rotation) and report how much of the valid region each samples off-frame."""
import random, torch
from data_v2 import WindowDataset
from augment_v2 import pan_rotate
from train_v2 import to_dev, psnr
from model_v2 import warp
from oft_fuse import mv_candidates, off_frame
dev = "cuda"
vl = torch.utils.data.DataLoader(WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8), batch_size=2)
rng = random.Random(7)
acc = {}
with torch.no_grad():
    for bi, b in enumerate(vl):
        if bi >= 15:
            break
        b = to_dev(b, dev)
        pan_rotate(b, rng, 640)
        gv, g, t = b["gt_valid"], b["color_g"], b["t"].float()
        tt = t.view(-1, 1, 1, 1)
        mv = b["mv_ba"] * b["mv_valid"]
        mva, mvb, ma, mb, hole, offa, offb = mv_candidates(b["color_a"], b["color_b"], b["depth_b"], mv, b["mv_valid"], t)
        la, lb = tt * mv, -(1 - tt) * mv
        cands = {"inv A": mva, "inv B": mvb, "lin A": warp(b["color_a"], la), "lin B": warp(b["color_b"], lb)}
        for k, x in cands.items():
            acc.setdefault(k, []).append(psnr(x * gv, g * gv))
        acc.setdefault("off inv B", []).append(float((offb * gv).sum() / gv.sum()))
        acc.setdefault("off lin B", []).append(float((off_frame(lb) * gv).sum() / gv.sum()))
        acc.setdefault("hole", []).append(float((hole * gv).sum() / gv.sum()))
        acc.setdefault("mv_valid", []).append(float(b["mv_valid"].mean()))
        acc.setdefault("|mv|", []).append(float(mv.norm(dim=1).mean()))
print({k: round(sum(v) / len(v), 3) for k, v in acc.items()})
