"""Checks for --convex_up / --deep16: (1) the convex level upsampling at init equals bilinear resize_flow exactly,
(2) v2_e weights warm-started into the new model give the same OF as the old model, (3) params / added GMAC."""
import torch
from model_v2 import MLOF2, convex_upsample_rep, bilinear_mask_bias, resize_flow

torch.manual_seed(0)
f = torch.randn(2, 2, 17, 30) * 20
m = bilinear_mask_bias().view(1, 36, 1, 1).expand(2, 36, 17, 30)
d = (convex_upsample_rep(f, m, 2) - resize_flow(f, 34, 60)).abs().max().item()
print(f"(1) convex init vs bilinear: max |diff| {d:.2e} px")

dev = "cuda"
sd = torch.load("/home/sh/mlof2_runs/v2_e/s16000_best.pt", map_location=dev)
sd = sd.get("model", sd)
old = MLOF2().to(dev).eval(); old.load_state_dict(sd)
new = MLOF2(convex_up=True, deep16=True).to(dev).eval()
own = new.state_dict()
keep = {k: v for k, v in sd.items() if k in own and own[k].shape == v.shape}
for k, v in sd.items():                                                                                    
    if k in own and k not in keep and own[k].shape[1:] == v.shape[1:] and own[k].shape[0] > v.shape[0]:
        t = own[k].clone(); t[: v.shape[0]] = v; keep[k] = t
new.load_state_dict(keep, strict=False)
print("    new tensors:", [k for k in own if k not in keep][:12])
c = torch.rand(1, 3, 448, 448, device=dev); c2 = torch.roll(c, (5, -9), (2, 3)); dp = torch.rand(1, 1, 448, 448, device=dev)
with torch.no_grad():
    fa, fb = old.enc(c, dp), old.enc(c2, dp)
    o1 = old.pair.of_forward(fa, fb, c, c2)
    o2 = new.pair.of_forward(fa, fb, c, c2)
for lv in (64, 32, 16, 8, 4):
    print(f"(2) level 1/{lv}: max |OF old - OF new| {(o1[lv]['of'] - o2[lv]['of']).abs().max().item():.2e}")
po = sum(p.numel() for p in old.pair.parameters()); pn = sum(p.numel() for p in new.pair.parameters())
dp_ = sum(p.numel() for p in new.pair.deep.parameters())
print(f"(3) pair params {po/1e6:.3f}M -> {pn/1e6:.3f}M (deep16 {dp_/1e6:.3f}M); deep16 GMAC at 1088x1920 per direction: "
      f"{dp_ * (1088 // 16) * (1920 // 16) / 1e9:.2f} (x2 directions)")
