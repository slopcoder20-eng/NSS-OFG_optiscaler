"""Trailing-band fill (content only in A) from a homography t -> A fitted to the head's own MV t -> A on the
background next to the band (2026-10-25, SN2: the fitted camera disagreed 20-80 px with the MV there -> seams;
a camera turn is one homography at any depth, so this fill is continuous with the interior by construction)."""
import torch
from torch.nn import functional as F


def fit_homog_flow(flow, ring, sc=1000.0, max_pts=20000, min_pts=2000, iters=4, huber=3.0):
    """Homography x -> x + flow fitted (IRLS, Huber-like weights at `huber` px) on the ring pixels (n=1).
    Returns the full-grid flow (1,2,H,W), or None with too few ring pixels."""
    ys, xs = torch.nonzero(ring[0, 0], as_tuple=True)
    if ys.numel() <= min_pts:
        return None
    g = torch.Generator(device=flow.device).manual_seed(0)
    sel = torch.randperm(ys.numel(), device=flow.device, generator=g)[:max_pts]
    ys, xs = ys[sel], xs[sel]
    fl = flow[0][:, ys, xs].double()
    X, Y = xs.double() / sc, ys.double() / sc
    U, V = X + fl[0] / sc, Y + fl[1] / sc
    o, z = torch.ones_like(X), torch.zeros_like(X)
    A = torch.cat((torch.stack((X, Y, o, z, z, z, -U * X, -U * Y), 1), torch.stack((z, z, z, X, Y, o, -V * X, -V * Y), 1)), 0)
    b = torch.cat((U, V))
    w = torch.ones_like(b)
    for _ in range(iters):
        hp = torch.linalg.lstsq(A * w[:, None], (b * w)[:, None]).solution[:, 0]
        res = (A @ hp - b).abs() * sc
        w = torch.where(res < huber, torch.ones_like(res), (huber / res).sqrt())
    Hm = torch.cat((hp, torch.ones(1, dtype=hp.dtype, device=hp.device))).view(3, 3)
    H, W = flow.shape[-2:]
    gy, gx = torch.meshgrid(torch.arange(H, device=flow.device, dtype=torch.float64),
                            torch.arange(W, device=flow.device, dtype=torch.float64), indexing="ij")
    P = torch.stack((gx / sc, gy / sc, torch.ones_like(gx)), 0).view(3, -1)
    Q = Hm @ P
    Q = Q[:2] / Q[2:]
    return (Q.view(2, H, W) * sc - torch.stack((gx, gy), 0)).float()[None]


def ring_outside(band, r):
    """(n,1,H,W) bool: pixels within r px outside the band."""
    b = band.float()
    return (F.max_pool2d(b, 2 * r + 1, 1, r) > 0.5) & ~band


def camera_disagreement(cam_to_a, mv_to_a, ring):
    """Median |camera t->A - MV t->A| (px) on the ring pixels, or None if the ring is empty. A camera fill that does
    not continue the interior MV (wrong / fitted matrices, SN2) shows up here as tens of px; a real one as ~1-2 px."""
    m = ring[0, 0]
    if int(m.sum()) < 500:
        return None
    return float((cam_to_a - mv_to_a).norm(dim=1)[0][m].median())
