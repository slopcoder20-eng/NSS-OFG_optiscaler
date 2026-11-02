"""Can the OF network fit ONE fixed batch with the geometry flow as the only target? (bug vs capacity check)
  python overfit_of.py <init ckpt or ''> [steps] [lr]"""
import sys, random
import torch
from model_v2 import MLOF2, resize_flow
from data_v2 import WindowDataset
from losses_v2 import masked_l1, FLOW_SCALE

init = sys.argv[1]
steps = int(sys.argv[2]) if len(sys.argv) > 2 else 400
lr = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-3
dev = "cuda"
torch.manual_seed(0)
m = MLOF2().to(dev).train()
if init:
    sd = torch.load(init, map_location=dev); sd = sd.get("model", sd)
    own = m.state_dict()
    m.load_state_dict({k: v for k, v in sd.items() if k in own and own[k].shape == v.shape}, strict=False)
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "train", crop=448)
rng = random.Random(3)
ss = []
while len(ss) < 2:                                                                                      
    s = ds[rng.randrange(len(ds))]
    if s["geo_flow_ba"].norm(dim=0).median() > 8 and not s["cut"]:
        ss.append(s)
b = {k: torch.stack([s[k] for s in ss]).to(dev) for k in ("color_a", "color_b", "depth_a", "depth_b", "geo_flow_ba")}
geo = b["geo_flow_ba"]
H, W = geo.shape[-2:]
print("spans", [int(s["span"]) for s in ss], "|geo| median", geo.norm(dim=1).median().item(),
      "max", geo.norm(dim=1).amax().item())
params = list(m.pair.upd.parameters()) + list(m.enc.parameters())
opt = torch.optim.Adam(params, lr=lr)
ones = torch.ones_like(geo[:, :1])
for it in range(steps + 1):
    fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
    ofs = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
    loss, per = 0.0, {}
    for lv in (64, 32, 16, 8, 4):
        f = resize_flow(ofs[lv]["of"][:2], H, W)
        l = masked_l1(f, geo, ones)              
        per[lv] = l.item()
        loss = loss + l * FLOW_SCALE
    opt.zero_grad(); loss.backward()
    gn = torch.nn.utils.clip_grad_norm_(params, 1e9).item()
    opt.step()
    if it % 25 == 0:
        f4 = resize_flow(ofs[4]["of"][:2], H, W)
        print(f"it {it:4d} L1 px per level " + " ".join(f"{k}:{v:6.2f}" for k, v in per.items()) +
              f" | |OF4| med {f4.norm(dim=1).median().item():5.2f} | gnorm {gn:.2f}", flush=True)
