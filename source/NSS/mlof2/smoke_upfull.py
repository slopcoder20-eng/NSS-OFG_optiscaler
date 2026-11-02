"""UpFull check: warm-started from a checkpoint without it, the convex x4 output must equal bilinear (resize_flow) to
float precision; backward reaches the new weights; MAC count of UpFull at 1080p (one direction)."""
import sys
import torch
from model_v2 import build_mlof2, MLOF2, resize_flow, full_flow

ck = sys.argv[1]
dev = "cuda"
sd = torch.load(ck, map_location=dev); sd = sd.get("model", sd)
ref = build_mlof2(sd).to(dev).eval(); ref.load_state_dict(sd)
m = MLOF2(convex_up=True, deep16=True, up_full=True).to(dev).eval()
missing, unexpected = m.load_state_dict(sd, strict=False)
print("missing", missing, "unexpected", unexpected)
torch.manual_seed(0)
H, W = 512, 768
ca, cb, da, db = (torch.rand(1, c, H, W, device=dev) for c in (3, 3, 1, 1))
with torch.no_grad():
    o_ref = ref.pair.of_forward(ref.enc(ca, da), ref.enc(cb, db), ca, cb)[4]
    o_new = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]
    bil = resize_flow(o_ref["of"], H, W)
    print("1/4 OF identical:", float((o_ref["of"] - o_new["of"]).abs().max()))
    d = (o_new["of_full"] - bil).abs()
    print(f"convex x4 vs bilinear: max {float(d.max()):.2e} px, interior max {float(d[..., 8:-8, 8:-8].max()):.2e} px, |flow| max {float(bil.abs().max()):.1f}")
m.train()
o = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]
(o["of_full"] - torch.randn_like(o["of_full"])).abs().mean().backward()
print("grad on upf.c.weight:", float(m.pair.upf.c.weight.grad.abs().sum()) > 0)
h4, w4 = 1088 // 4, 1920 // 4
cin = m.pair.upf.a.in_channels
mac = h4 * w4 * (cin * 48 + 48 * 32 * 9 + 32 * 144)
print(f"UpFull cin {cin}: {mac / 1e9:.2f} GMAC per direction at 1920x1088")
