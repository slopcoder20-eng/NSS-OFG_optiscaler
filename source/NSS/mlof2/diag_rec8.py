"""What does the recurrent 1/8 block (pair.rec) do? 1/8 flow before vs after it, and the final 1/4 flow, full-res EPE
vs the exact Spring flow by deviation bins (as diag_corr_readout).  python diag_rec8.py <crop> <ckpt> [N=4]"""
import sys, torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from data_v2 import depth_feature, chain_backward
fn, ck = sys.argv[1:3]; N = int(sys.argv[3]) if len(sys.argv) > 3 else 4
dev = "cuda"; s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]; H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]; PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)), size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))
sd = torch.load(ck, map_location=dev); m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
rec = m.pair.rec; cap = {}
orig = rec.forward
def hooked(of, *a):
    cap["before"] = of.detach(); out = orig(of, *a); cap["after"] = out.detach(); return out
rec.forward = hooked
DEV = [0, 1, 2, 4, 8, 16, 1e9]; acc = {}
full = lambda f, shape: F.interpolate(f, size=shape, mode="bilinear", align_corners=False) * (shape[-1] / f.shape[-1])
with torch.no_grad():
    for a in range(0, T - N, N):
        b = a + N
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev); da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        ex = pad(mv_ba(a, b)).to(dev); r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        dv = (ex - sm).norm(dim=1)[0, :H]
        reg = (F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5)[0, 0, :H]
        ofs = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)
        masks = {"all": torch.ones_like(reg), "fol": reg}
        for i in range(len(DEV) - 1):
            masks[f"dev {DEV[i]:g}-{DEV[i+1]:g}"] = (dv >= DEV[i]) & (dv < DEV[i + 1])
        cands = {"1/8 before rec": cap["before"][:1], "1/8 after rec": cap["after"][:1], "1/4 final": ofs[4]["of"][:1]}
        d = (cap["after"][:1] - cap["before"][:1]).norm(dim=1)
        acc.setdefault("delta", [0, 0]); acc["delta"][0] += float(d.sum()); acc["delta"][1] += d.numel()
        for name, f in cands.items():
            e = (full(f, ex.shape[-2:]) - ex).norm(dim=1)[0, :H]
            for mk, msk in masks.items():
                v = acc.setdefault((name, mk), [0.0, 0.0]); v[0] += float(e[msk].sum()); v[1] += float(msk.sum())
mks = ["all", "fol"] + [f"dev {DEV[i]:g}-{DEV[i+1]:g}" for i in range(len(DEV) - 1)]
print(f"mean |rec delta| at 1/8: {acc['delta'][0] / acc['delta'][1]:.3f} px (1/8 px)")
print(f"  {'':16s}" + "".join(f"{k:>10s}" for k in mks))
for n in ("1/8 before rec", "1/8 after rec", "1/4 final"):
    print(f"  {n:16s}" + "".join(f"{acc[(n, k)][0] / max(acc[(n, k)][1], 1):10.2f}" for k in mks))
