"""Sign check on train windows (with and without pan_rotate / augment): cos(MV, geo), cos(OF_level, geo) per level,
and the census / geo loss of OF vs -OF (which sign do the losses prefer?).
  python diag_sign.py <ckpt> [n]"""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import MLOF2, resize_flow
from data_v2 import WindowDataset
from augment_v2 import augment, pan_rotate
from of_losses import of_loss

ck = sys.argv[1]
nwin = int(sys.argv[2]) if len(sys.argv) > 2 else 4
dev = "cuda"
m = MLOF2().to(dev).eval()
m.load_state_dict(torch.load(ck, map_location=dev))
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "train", crop=448)
rng = random.Random(1)
cosm = lambda a, b, k: F.cosine_similarity(a, b, dim=1)[k].mean().item() if k.any() else float("nan")
with torch.no_grad():
    for mode in ("plain", "pan", "aug"):
        for j in range(nwin):
            s = ds[rng.randrange(len(ds))]
            b = {k: (v[None].to(dev) if torch.is_tensor(v) and v.dim() >= 1 else v) for k, v in s.items()}
            b = {k: (torch.as_tensor(v)[None].to(dev) if not torch.is_tensor(v) else v) for k, v in b.items()}
            if mode == "pan":
                pan_rotate(b, rng, 896)
            if mode == "aug":
                augment(b, rng)
            geo = b["geo_flow_ba"]
            H, W = geo.shape[-2:]
            mv = (geo.norm(dim=1) > 2)
            fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
            ofs = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
            lv = " ".join(f"{l}:{cosm(resize_flow(ofs[l]['of'][:1], H, W), geo, mv):+.2f}" for l in (64, 32, 16, 8, 4))
            l_pos, p_pos = of_loss(ofs, b)
            neg = {l: {**o, "of": -o["of"]} for l, o in ofs.items()}
            l_neg, p_neg = of_loss(neg, b)
            print(f"{mode:5s} span {int(b['span'])} |geo| med {geo.norm(dim=1).median().item():5.1f} "
                  f"cos(MV,geo) {cosm(b['mv_ba'], geo, mv):+.2f} | cos(OF,geo) per level {lv} | "
                  f"census +OF {p_pos['census']:.3f} -OF {p_neg['census']:.3f} | geo +OF {p_pos.get('geo', 0):.2f} -OF {p_neg.get('geo', 0):.2f}")
