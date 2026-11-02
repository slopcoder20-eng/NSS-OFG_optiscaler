"""Which RIFE output matches our B->A convention (warp(A, f) ~ B)? One Spring pair, photometric error + EPE vs exact."""
import sys
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import warp
from data_v2 import chain_backward
sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
from train_log.IFNet_HDv3 import IFNet
dev = "cuda"
net = IFNet().to(dev).eval()
sd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
net.load_state_dict({k.replace("module.", ""): v for k, v in sd.items()}, strict=False)
s = safe_open(sys.argv[1], "pt")
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
col = lambda i: (s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0).to(dev)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
a, b = 24, 28
ex = F.interpolate(chain_backward(nat(x) for x in range(b, a, -1))[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False).to(dev)
ca, cb = col(a), col(b)
ph, pw = (64 - H % 64) % 64, (64 - W % 64) % 64
x = torch.cat((F.pad(ca, (0, pw, 0, ph), mode="replicate"), F.pad(cb, (0, pw, 0, ph), mode="replicate")), 1)
with torch.no_grad():
    res = {}
    for t in (1.0, 0.0, 0.5):
        fl, _, _ = net(x, t, [16, 8, 4, 2, 1])
        res[t] = fl[-1][..., :H, :W].float()
pe = lambda f: float((warp(ca, f) - cb).abs().mean() * 255)
print(f"H W {H} {W} | exact |f| mean {float(ex.norm(dim=1).mean()):.2f} | photometric: none {float((ca - cb).abs().mean() * 255):.2f} exact {pe(ex):.2f}")
cands = {"t1 F_t0": res[1.0][:, :2], "t0 F_t1": res[0.0][:, 2:4], "-t0 F_t1": -res[0.0][:, 2:4], "2*t.5 F_t0": 2 * res[0.5][:, :2],
         "t1 F_t0 xy": res[1.0][:, :2].flip(1), "t1 F_t1": res[1.0][:, 2:4]}
for k, f in cands.items():
    print(f"{k:12s} |f| {float(f.norm(dim=1).mean()):7.2f} EPE {float((f - ex).norm(dim=1).mean()):7.2f} photometric {pe(f):6.2f}")
