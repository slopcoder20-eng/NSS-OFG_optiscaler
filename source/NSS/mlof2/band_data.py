"""Training tiles for band_net.BandNet from an NFRU capture (every frame rendered: the true t->A motion is the frame
at t's own MV chained to A). For every pair A = f-N, B = f with P = f-2N in the sequence and every k = 1..N-1:
trailing band at t (MV t-alignment: no B pixel lands there, as the head's off_mv[1]), camq t->A flow, inputs at half
res (band_net.band_inputs), target residual (true - camq) where the true source is in the frame. 96x96 half-res tiles
on a 64 grid wherever the dilated band is. No OF, no head.
  [FRAMES=a:b] [NS=2,3,4] [KEEP=1.0] python band_data.py <nfru safetensors> <out prefix>"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import warp
from data_v2 import TONE_CURVES, srgb_encode, quantize, depth_feature, _warp_border
from nfru_head import invert_t, off_frame
import nfru_head
import band_net as BN

fn, out = sys.argv[1:3]
NS = [int(x) for x in os.environ.get("NS", "2,3,4").split(",")]
KEEP = float(os.environ.get("KEEP", "1.0"))
TILE, STEP, HALO = 96, 64, 16
dev = "cuda"
s = safe_open(fn, "pt")
_fd = os.open(fn, os.O_RDONLY)
T = s.get_slice("rgb_linear").get_shape()[0]
OFF = 0
if os.environ.get("FRAMES"):
    OFF, _b = (int(x) for x in os.environ["FRAMES"].split(":")); T = _b - OFF
H, W = s.get_slice("rgb_linear").get_shape()[-2:]
h, w = s.get_slice("depth").get_shape()[-2:]
PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
zn = s.get_tensor("NearPlane").float()
VPm = s.get_tensor("ViewProj").double()
lin = lambda i: s.get_slice("rgb_linear")[OFF + i:OFF + i + 1].float()
mv1 = lambda i: F.interpolate(s.get_slice("mv_{}_f60_m1")[OFF + i:OFF + i + 1].float().flip(1) * (H / h), size=(H, W), mode="bilinear", align_corners=False)
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[OFF + i:OFF + i + 1].float(), zn[OFF + i]), size=(H, W), mode="bilinear", align_corners=False)
draw = lambda i: F.interpolate(s.get_slice("depth")[OFF + i:OFF + i + 1].float(), size=(H, W), mode="nearest")[0, 0]
vp = lambda i: VPm[OFF + i].T


def display(x, ref):                                              
    lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
    e = 0.18 / torch.exp(torch.log(lum(ref)).mean())
    return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * e).clamp(0, 1)), 8)


def chain(i, n):                                                                           
    acc = mv1(i)
    for j in range(1, n):
        acc = acc + _warp_border(mv1(i - j), acc)
    return acc


rng = np.random.default_rng(0)
X, Y, M = [], [], []
stats = []
with torch.no_grad():
    for N in NS:
        for f in range(2 * N, T, N):
            a, p = f - N, f - 2 * N
            la = lin(a)
            ca = pad(display(la, la)).to(dev)
            da, db = pad(dfeat(a)).to(dev), pad(dfeat(f)).to(dev)
            mv_ba, mv_ap = pad(chain(f, N)).to(dev), pad(chain(a, N)).to(dev)
            mv_bp = mv_ba + warp(mv_ap, mv_ba)
            cam_ap = pad(BN.cam_offset(draw(a), vp(a), vp(p))).to(dev)
            obj_a = mv_ap - cam_ap
            for k in range(1, N):
                t = k / N
                tt = torch.tensor([t], device=dev)
                invert_t(mv_ba, db, tt, mv_bp, torch.ones_like(db))
                trail = nfru_head.LAST_OOB[0] > 0.5
                dt_ = pad(BN.cam_offset(draw(a), vp(a), BN.quad_vp(vp(p), vp(a), vp(f), t))).to(dev)
                _, to_cam, hole = invert_t(dt_, da, torch.zeros(1, device=dev))
                tru = pad(chain(a + k, k)).to(dev)
                ok = trail & (off_frame(tru) < 0.5)
                x = BN.band_inputs(ca, da, to_cam, hole, obj_a, mv_ap, t, trail)
                y = F.avg_pool2d(tru - to_cam, 2) / (2 * BN.FLOW_NORM)
                m = F.avg_pool2d(ok.float(), 2) > 0.5
                e = (tru - to_cam).norm(dim=1, keepdim=True)[ok]
                if e.numel():
                    stats.append((float(e.median()), float(e.quantile(0.9)) if e.numel() < 16_000_000 else float("nan"), float(ok.float().mean())))
                cov = F.max_pool2d(m.float(), 17, 1, 8)[0, 0]
                Hh, Wh = cov.shape
                for y0 in range(0, Hh, STEP):
                    for x0 in range(0, Wh, STEP):
                        if not bool(cov[y0:y0 + STEP, x0:x0 + STEP].any()) or rng.random() > KEEP:
                            continue
                        ty = min(max(y0 - HALO, 0), Hh - TILE); tx = min(max(x0 - HALO, 0), Wh - TILE)
                        X.append(x[0, :, ty:ty + TILE, tx:tx + TILE].half().cpu().numpy())
                        Y.append(y[0, :, ty:ty + TILE, tx:tx + TILE].half().cpu().numpy())
                        M.append(m[0, :, ty:ty + TILE, tx:tx + TILE].cpu().numpy())
            os.posix_fadvise(_fd, 0, 0, os.POSIX_FADV_DONTNEED)
        print(f"N={N}: {len(X)} tiles so far", flush=True)
for nm_, v in (("x", X), ("y", Y), ("m", M)):                                                             
    np.save(f"{out}_{nm_}.npy", np.stack(v).astype(np.uint8 if nm_ == "m" else np.float16))
st = np.array(stats)
print(f"{os.path.basename(fn)}[{OFF}:{OFF + T}] -> {out}: {len(X)} tiles; |true - camq| in the band median {np.nanmedian(st[:, 0]):.2f} "
      f"p90 {np.nanmedian(st[:, 1]):.1f} px, band {100 * st[:, 2].mean():.1f}% of px")
