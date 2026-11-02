"""Gradient-based (Lucas-Kanade) refinement of a pair of t-flows (2026-11-01 experiment, no learning).

Model: the true t-flows are f_tA + dA, f_tB + dB with a shared correction u of the A->B motion (linear in t):
dA = -t u, dB = (1-t) u. With wa = warp(A, f_tA), wb = warp(B, f_tB) (luma) and first-order expansion
    wa - t (grad wa . u) = wb + (1-t) (grad wb . u)   ->   e + g . u = 0,   e = wb - wa,   g = (1-t) grad wb + t grad wa
u per pixel by windowed least squares over a k x k box: u = -(sum g g^T + lam I)^-1 sum g e. Coarse to fine
(scales 2 then 1), a few iterations each, |u| clamped per iteration. Returns refined flows and the confidence
(smallest eigenvalue of the structure tensor, normalised)."""
import torch
from torch.nn import functional as F
from model_v2 import warp, resize_flow

LW = (0.299, 0.587, 0.114)


def luma(x):
    w = torch.tensor(LW, device=x.device, dtype=x.dtype).view(1, 3, 1, 1)
    return (x * w).sum(1, keepdim=True)


def grad(x):
    gx = F.pad(x[..., :, 2:] - x[..., :, :-2], (1, 1, 0, 0), mode="replicate") * 0.5
    gy = F.pad(x[..., 2:, :] - x[..., :-2, :], (0, 0, 1, 1), mode="replicate") * 0.5
    return gx, gy


def lk_step(la, lb, fa, fb, t, k=9, lam=1e-4, umax=2.0):
    wa, wb = warp(la, fa), warp(lb, fb)
    ax, ay = grad(wa)
    bx, by = grad(wb)
    tt = t.view(-1, 1, 1, 1)
    gx, gy = (1 - tt) * bx + tt * ax, (1 - tt) * by + tt * ay
    e = wb - wa
    box = lambda z: F.avg_pool2d(z, k, 1, k // 2, count_include_pad=False)
    sxx, sxy, syy = box(gx * gx) + lam, box(gx * gy), box(gy * gy) + lam
    bxe, bye = box(gx * e), box(gy * e)
    det = sxx * syy - sxy * sxy
    ux = -(syy * bxe - sxy * bye) / det
    uy = -(-sxy * bxe + sxx * bye) / det
    u = torch.cat((ux, uy), 1)
    n = u.norm(dim=1, keepdim=True)
    u = u * (umax / n.clamp_min(umax)).clamp(max=1.0)
    tr = sxx + syy
    lmin = 0.5 * (tr - torch.sqrt((sxx - syy) ** 2 + 4 * sxy * sxy))
    return fa - tt * u, fb + (1 - tt) * u, lmin


def lk_refine(color_a, color_b, f_ta, f_tb, t, scales=(2, 1), iters=3, k=9):
    la, lb = luma(color_a), luma(color_b)
    H, W = la.shape[-2:]
    conf = None
    for s in scales:
        h, w = H // s, W // s
        la_s = la if s == 1 else F.interpolate(la, size=(h, w), mode="area")
        lb_s = lb if s == 1 else F.interpolate(lb, size=(h, w), mode="area")
        fa, fb = (f_ta, f_tb) if s == 1 else (resize_flow(f_ta, h, w), resize_flow(f_tb, h, w))
        for _ in range(iters):
            fa, fb, conf = lk_step(la_s, lb_s, fa, fb, t, k)
        f_ta, f_tb = (fa, fb) if s == 1 else (resize_flow(fa, H, W), resize_flow(fb, H, W))
    return f_ta, f_tb, conf
