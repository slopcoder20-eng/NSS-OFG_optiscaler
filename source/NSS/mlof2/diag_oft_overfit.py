"""Can the OFT net fit the exact t-flows on ONE batch (only the flow loss)? If not -> a bug, not capacity.
Also checks the target: EPE of the linear init vs the exact t-flow, and of a constant zero / mean correction.
  python diag_oft_overfit.py <game|spring> [ckpt]"""
import sys, random
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, invert_flow
from data_v2 import WindowDataset
from train_v2 import to_dev
from train_oft import pure_of
from oft_block import OFTNet

dev = "cuda"
torch.manual_seed(0)
which = sys.argv[1]
if which == "game":
    ds = WindowDataset(["forest15", "lyra15", "lyra17"], "train", crop=448, mv_res=True, tri=True)
    bs = 2
else:
    ds = WindowDataset(["spring"], "train", crop=(1024, 1920), strides=(1, 2, 4, 8, 12), tri=True)
    bs = 1
b = to_dev(next(iter(torch.utils.data.DataLoader(ds, batch_size=bs, shuffle=True))), dev)
sd = torch.load("/home/sh/mlof2_runs/v2_of_menc/s1500.pt", map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
of_ab, of_ba = pure_of(m, b)
gt_ta = b["geo_flow_ga"]
gt_tb, ok_tb = invert_flow(b["geo_flow_bg"])
print("t", b["t"].tolist(), "| |gt_ta| mean %.2f px, |gt_tb| %.2f px, inv ok %.2f" % (
    gt_ta.norm(dim=1).mean(), gt_tb.norm(dim=1).mean(), ok_tb.mean()))
net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
if len(sys.argv) > 2:
    net.load_state_dict(torch.load(sys.argv[2], map_location=dev))
opt = torch.optim.Adam(net.parameters(), lr=1e-3)
for step in range(301):
    o = net(b["t"].float(), b["color_a"], b["color_b"], of_ab, of_ba)
    ea = (o["f_ta"] - gt_ta).norm(dim=1).mean()
    eb = ((o["f_tb"] - gt_tb).norm(dim=1) * ok_tb[:, 0]).sum() / ok_tb.sum().clamp_min(1)
    if step == 0:
        ia, ib = net.last_init
        print("init EPE t->A %.2f  t->B %.2f" % ((ia - gt_ta).norm(dim=1).mean(), ((ib - gt_tb).norm(dim=1) * ok_tb[:, 0]).sum() / ok_tb.sum()))
                                                                       
        print("  init*(-1) EPE t->A %.2f | init*0.5 %.2f | zero flow %.2f" % (
            (-ia - gt_ta).norm(dim=1).mean(), (0.5 * ia - gt_ta).norm(dim=1).mean(), gt_ta.norm(dim=1).mean()))
    loss = ((o["f_ta"] - gt_ta).abs().sum(1)).mean() + ((o["f_tb"] - gt_tb).abs().sum(1, keepdim=True) * ok_tb).mean()
    opt.zero_grad(); loss.backward(); opt.step()
    if step % 50 == 0:
        print(f"step {step:3d} EPE t->A {float(ea):6.2f} t->B {float(eb):6.2f} | |d| mean {float((o['f_ta'] - net.last_init[0]).norm(dim=1).mean()):.3f}", flush=True)
