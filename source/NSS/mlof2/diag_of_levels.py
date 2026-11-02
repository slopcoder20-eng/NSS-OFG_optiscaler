"""Which OF level resolves local motion? PairFlow.of_forward gives the flow after every level (1/64 .. 1/4); each is
bilinearly upsampled to full res (px scaled) and scored against the exact Spring flow, binned by the pixel's motion
relative to its 65x65 surroundings (|exact - box mean|), real frames N apart. If the error of the high-deviation bins
barely drops from 1/16 to 1/4, the fine levels do not add local motion.
  python diag_of_levels.py <spring crop safetensors> <OF ckpt> [N=4]"""
import sys
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from data_v2 import depth_feature, chain_backward

fn, ck = sys.argv[1:3]
N = int(sys.argv[3]) if len(sys.argv) > 3 else 4
dev = "cuda"
s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)),
                                size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
mv_ba = lambda a, b: up(chain_backward(nat(x) for x in range(b, a, -1)))
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
DEV = [0, 1, 2, 4, 8, 16, 32, 1e9]
acc = {}
with torch.no_grad():
    for a in range(0, T - N, N):
        b = a + N
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        ex = pad(mv_ba(a, b)).to(dev)
        r = 32
        sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        dv = (ex - sm).norm(dim=1)[0, :H]
        ofs = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)
        fl = {lv: o["of"][:1] for lv, o in ofs.items() if isinstance(lv, int)}
        fl["box65 (= surroundings)"] = sm
        for lv, f in fl.items():
            fu = f if f.shape[-2:] == ex.shape[-2:] else F.interpolate(f, size=ex.shape[-2:], mode="bilinear", align_corners=False) * (ex.shape[-1] / f.shape[-1])
            e = (fu - ex).norm(dim=1)[0, :H]
            for i in range(len(DEV) - 1):
                mk = (dv >= DEV[i]) & (dv < DEV[i + 1])
                k = (str(lv), i)
                v = acc.setdefault(k, [0.0, 0.0]); v[0] += float(e[mk].sum()); v[1] += float(mk.sum())
names = [str(lv) for lv in (64, 32, 16, 8, 4) if (str(lv), 0) in acc] + ["box65 (= surroundings)"]
print(f"EPE by |exact - 65x65 box mean| (px), level = flow after that level, bilinear to full res")
print("  dev bin    " + " ".join(f"{('1/' + n if n.isdigit() else 'box65'):>8s}" for n in names))
for i in range(len(DEV) - 1):
    print(f"  {DEV[i]:g}-{DEV[i + 1]:g}".ljust(13) + " ".join(f"{acc[(n, i)][0] / max(acc[(n, i)][1], 1):8.2f}" for n in names))
