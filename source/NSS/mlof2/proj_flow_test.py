"""1x1 projections 256 -> 64 / 128 of SEA-RAFT's fnet features (trained by the 1/8 cost-volume KL, as
test_distill_limits A) fed to the recurrent block instead of the MatchEncoder: does a 64-ch cosine cost volume of
GOOD features carry the flow gain?  python proj_flow_test.py"""
import os, sys, random, torch
from torch import nn
from torch.nn import functional as F
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import warp, correlation
from data_v2 import WindowDataset
from teacher_searaft import SeaRaftTeacher
dev, TAU, R = "cuda", 0.07, "/home/sh/mlof2_runs"
torch.manual_seed(0)
fnet = SeaRaftTeacher(dev).model.fnet
tl = torch.utils.data.DataLoader(WindowDataset(["forest15", "lyra15", "lyra17"], "train", crop=384, strides=[1, 2, 3, 4, 6, 8]),
                                 batch_size=4, shuffle=True, num_workers=3, drop_last=True)
for cout in (64, 128):
    pj = nn.Conv2d(256, cout, 1).to(dev); opt = torch.optim.AdamW(pj.parameters(), lr=1e-3); it = iter(tl)
    for step in range(1, 1201):
        try: b = next(it)
        except StopIteration: it = iter(tl); b = next(it)
        b = {k: v.to(dev) for k, v in b.items() if torch.is_tensor(v)}
        g = F.avg_pool2d(b["geo_flow_ba"], 8) / 8; g = g + (torch.rand_like(g) * 4 - 2)
        with torch.no_grad():
            ta, tb = fnet(2 * b["color_a"] - 1).float(), fnet(2 * b["color_b"] - 1).float()
            pt = torch.softmax(correlation(tb, warp(ta, g), 3) / TAU, 1)
        ls = torch.log_softmax(correlation(pj(tb), warp(pj(ta), g), 3) / TAU, 1)
        loss = (pt * (torch.log(pt.clamp_min(1e-8)) - ls)).sum(1).mean()
        opt.zero_grad(); loss.backward(); opt.step()
    torch.save(pj.state_dict(), f"{R}/v2_of_encpre/proj{cout}.pt"); print("saved proj", cout, "train KL", float(loss), flush=True)
