"""Propagate check: warm-started from a checkpoint without it, the 1/4 OF must stay ~equal (gate starts at 0.25%);
backward reaches the new weights; MAC count of Propagate at 1080p (one direction, net + 6 iterations)."""
import sys
import torch
from model_v2 import build_mlof2, MLOF2

ck = sys.argv[1]
dev = "cuda"
sd = torch.load(ck, map_location=dev); sd = sd.get("model", sd)
ref = build_mlof2(sd).to(dev).eval(); ref.load_state_dict(sd)
m = MLOF2(convex_up=True, deep16=True, up_full=ref.pair.up_full, prop4=True).to(dev).eval()
missing, unexpected = m.load_state_dict(sd, strict=False)
print("missing", missing, "unexpected", unexpected)
torch.manual_seed(0)
H, W = 512, 768
ca, cb, da, db = (torch.rand(1, c, H, W, device=dev) for c in (3, 3, 1, 1))
with torch.no_grad():
    o_ref = ref.pair.of_forward(ref.enc(ca, da), ref.enc(cb, db), ca, cb)[4]
    o_new = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]
    d = (o_ref["of"] - o_new["of"]).abs()
    print(f"1/4 OF change at init: max {float(d.max()):.3f} px(1/4), mean {float(d.mean()):.4f}; |flow| max {float(o_ref['of'].abs().max()):.1f}")
m.train()
o = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]
(o["of"] - torch.randn_like(o["of"])).abs().mean().backward()
print("grad on prop.head.weight:", float(m.pair.prop.head.weight.grad.abs().sum()) > 0)
pr = m.pair.prop
cells = (1088 // 4) * (1920 // 4)
net = pr.a.in_channels * 32 + 32 * 32 * 9 * 2 + 32 * pr.head.out_channels
it = len(pr.DIL) * (2 * 9 + 9 + 4)
print(f"Propagate cin {pr.a.in_channels}: net {cells * net / 1e9:.2f} + iterations {cells * it / 1e9:.3f} GMAC per direction at 1920x1088")
