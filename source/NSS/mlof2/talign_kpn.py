"""TAlignKPN: moving a B->A flow to the frame at t as MACs (a kernel-prediction formulation of nfru_head.invert_t).
For a target pixel y at t we want the B pixel x with x + disp(x) = y (disp = the B pixel's displacement to t), the
nearest one when several land there. invert_t finds it by data-dependent fixed-point iterations from 17 starts
(~170 dependent gathers per pixel). Here:
  1. one gather: x0(y) = y - disp(y) (the B-grid value at y, no read needed for the position); the packed source
     field [to_A 2, to_B 2, disp 2, depth 1, valid 1] is pulled from x0 (nearest) onto the target grid,
  2. a FIXED window of taps on that pulled field (5x5 at dilation 1, 4 and 12 = 75): tap o of y holds the
     source x = x0(y + o) -- at an edge the neighbours' x0 come from both layers, so both solutions are in the window,
  3. per tap: arrival error |x + disp(x) - y|, depth relative to the window minimum, validity (225 ch) -> 1x1 convs ->
     75 logits = analytic part (-arrival / tau_r - depth / tau_d, invalid -30) + a learned zero-init correction,
  4. softmax over the taps, output = the weighted to_A / to_B (a convex combination of real source values: picks,
     does not regress), plus a hole score (no tap arrives).
Runs at half resolution (flows halved), output bilinear back to full res. Trained by distilling invert_t
(distill_talign.py); no game MV in the OF, no copied design. ~4.5 GMAC per path at 1080p (half res)."""
import math
import torch
import torch.nn as nn
from torch.nn import functional as F

DIRS = [(dy, dx) for dy in range(-2, 3) for dx in range(-2, 3)]
TAPS = [(dy, dx) for dy, dx in DIRS] + [(4 * dy, 4 * dx) for dy, dx in DIRS] +     [(12 * dy, 12 * dx) for dy, dx in DIRS]                                                                          
                                                                                                                        


def _disp(f_ba, t, f_bp=None, accel_cap=0.5):
    """The B pixel's displacement to t (same trajectory as nfru_head.splat_t2 / invert_t)."""
    n = f_ba.shape[0]
    tt = t.view(n, 1, 1, 1)
    if f_bp is None:
        return (1 - tt) * f_ba
    a = f_bp - 2 * f_ba
    cap = accel_cap * f_ba.norm(dim=1, keepdim=True)
    a = a * (cap / a.norm(dim=1, keepdim=True).clamp_min(1e-6)).clamp(max=1.0)
    a = torch.where(torch.isfinite(f_bp).all(1, keepdim=True), a, torch.zeros_like(a))
    return (1 - tt) * f_ba + 0.5 * a * tt * (tt - 1)


def _grid(n, h, w, dev, dt):
    y, x = torch.meshgrid(torch.arange(h, device=dev, dtype=dt), torch.arange(w, device=dev, dtype=dt), indexing="ij")
    return torch.stack((x, y), 0)[None].expand(n, -1, -1, -1)


def _pull_nearest(img, pos):
    """img sampled at absolute pixel positions pos (n, 2, h, w), nearest, border clamp."""
    h, w = img.shape[-2:]
    gx = 2 * pos[:, 0] / max(w - 1, 1) - 1
    gy = 2 * pos[:, 1] / max(h - 1, 1) - 1
    return F.grid_sample(img, torch.stack((gx, gy), -1), mode="nearest", padding_mode="border", align_corners=True)


def _shift(x, dy, dx):
    """x(y + dy, x + dx), replicate borders."""
    if dy == 0 and dx == 0:
        return x
    p = max(abs(dy), abs(dx))
    h, w = x.shape[-2:]
    return F.pad(x, (p, p, p, p), mode="replicate")[..., p + dy:p + dy + h, p + dx:p + dx + w]


class TAlignKPN(nn.Module):
    def __init__(self, scale=2, tau_r=0.5, tau_d=0.004, pre_iters=2):
        super().__init__()
        self.scale = scale
        self.pre_iters = pre_iters                                                                                         
        k = len(TAPS)
        self.net = nn.Sequential(nn.Conv2d(3 * k, 32, 1), nn.LeakyReLU(0.1), nn.Conv2d(32, k + 1, 1))
        with torch.no_grad():
            self.net[2].weight.zero_(); self.net[2].bias.zero_()
            self.net[2].bias[k] = -4.0                                                   
        self.log_tau_r = nn.Parameter(torch.tensor(math.log(tau_r)))
        self.log_tau_d = nn.Parameter(torch.tensor(math.log(tau_d)))

    def forward(self, f_ba, depth_b, t, f_bp=None, valid=None):
        """f_ba: (n,2,H,W) full-res B->A flow, depth_b (n,1,H,W) depth feature (smaller = nearer). Returns (to_A, to_B,
        hole) at full res like invert_t."""
        n, _, H, W = f_ba.shape
        s = self.scale
        h, w = H // s, W // s
        down = lambda z: F.interpolate(z, size=(h, w), mode="nearest")
        disp = down(_disp(f_ba, t, f_bp)) / s                                             
        fb = down(f_ba) / s
        dep = down(depth_b)
        val = torch.ones_like(dep) if valid is None else down((valid > 0.5).float())
        src = torch.cat((fb - disp, -disp, disp, dep, val), 1)                                   
        grid = _grid(n, h, w, f_ba.device, f_ba.dtype)
        x0 = grid - disp                                                                                     
        for _ in range(self.pre_iters):                                                                               
            x0 = grid - _pull_nearest(disp, x0)
        pulled = _pull_nearest(src, x0)
        feats, vals = [], []
        for dy, dx in TAPS:
            p = _shift(pulled, dy, dx)
            xs = _shift(x0, dy, dx)                                                             
            arr = (xs + p[:, 4:6] - grid).norm(dim=1, keepdim=True)                             
            feats.append((arr, p[:, 6:7], p[:, 7:8]))
            vals.append(p[:, 0:4])
        arr = torch.cat([f[0] for f in feats], 1)
        dep_t = torch.cat([f[1] for f in feats], 1)
        val_t = torch.cat([f[2] for f in feats], 1)
        dep_rel = dep_t - torch.where(arr < 1.0, dep_t, torch.full_like(dep_t, 9.0)).amin(1, keepdim=True).clamp(max=1.0)
        x = torch.cat((arr.clamp(max=8.0) / 4.0, dep_rel.clamp(-1, 1) * 16.0, val_t), 1)
        o = self.net(x)
        k = len(TAPS)
        ana = -arr / self.log_tau_r.exp() - dep_rel.clamp(min=0) / self.log_tau_d.exp()
        ana = torch.where(val_t > 0.5, ana, torch.full_like(ana, -30.0))
        wts = (ana + o[:, :k]).softmax(1)                                                  
        v = torch.stack(vals, 2)                                                              
        out = (v * wts[:, None]).sum(2) * s                                               
        hole = torch.sigmoid(o[:, k:k + 1] + 4.0 * ((arr.amin(1, keepdim=True) - 1.0).clamp(min=0) > 0).float())
        up = lambda z: F.interpolate(z, size=(H, W), mode="bilinear", align_corners=False)
        out = up(out)
        return out[:, 0:2], out[:, 2:4], up(hole)
