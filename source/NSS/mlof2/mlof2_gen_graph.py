"""MLOF2 generation stage as an engine op table (docs/NFRU_MLOF2_ENGINE_PLAN_20261023.md, E4).

Per generated frame (t = k / N): t-alignment of the game MV and of the OF (invert_t, one start x 4 iterations),
the four candidates (off-frame samples -> hash noise), the 28 head inputs (CE3 cues), the NFRU autoencoder (CE3
weights, BN folded) at 1/4, softmax blend, rule_rel with ONESIDE and the rel_t carry, the trailing-band A candidate
from the camera, the vignette (quad3 + darken-only clamp, estimated once per pair) divided out before and put back
after. Same pipeline as eval_nfru_mfg.py (VIGNETTE=online TRAIL_A=cam RULE=rel_t) with two engine-friendly changes
(defined here, used by the reference and the engine alike):
  - noise for off-frame candidate samples: lowbias32 hash of (x, y, channel, candidate) instead of torch.rand
  - vignette samples: a fixed 4 x 4 px grid instead of a random 64k subset
Frame constants (meta "fc" block, host-written per frame): t, has_prev (a previous pair exists), pair_first (this is
the pair's first generated frame: vignette update), VP_A / VP_B (row-vector math, as the NFRU file's ViewProj^T).
Graph inputs (n = 1): col_a, col_b (3), dep_a, dep_b (log depth feature), ndc_a (NDC z of A, camera path), mv (B->A
game MV, display px), mvv, mv_ap (previous pair's MV), of (the OF graph's of_full row 0), of_prev (previous pair's),
co (conf/occ 1/4 row 0), state: vig (s 64: 9 ata/atb + 3 coefficients), pmask (the previous output's rule mask at
this k). Output: out (3)."""
import math
import os
import torch
from torch.nn import functional as F
import model_v2 as M
import mlof2_graph as MG
from nfru_head import NFRUAutoEncoder

FC = {"t": 0, "has_prev": 1, "pair_first": 2, "vp_a": 4, "vp_b": 20, "inv_vp_a": 36}                                  
FC_WORDS = 52


def hash_noise(n, c, H, W, idx, device):
    """lowbias32 of (x, y, channel, candidate) -> [0, 1). Same integer ops as mlof2_gen.comp."""
    M32 = 0xFFFFFFFF
    y, x = torch.meshgrid(torch.arange(H, device=device, dtype=torch.int64), torch.arange(W, device=device, dtype=torch.int64), indexing="ij")
    cc = torch.arange(c, device=device, dtype=torch.int64).view(c, 1, 1)
    h = (x[None] * 1973 + y[None] * 9277 + cc * 26699 + idx * 7919 + 12345) & M32
    h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
    h = ((h ^ (h >> 15)) * 0x846ca68b) & M32
    h = h ^ (h >> 16)
    return (h.float() / 4294967296.0)[None].expand(n, c, H, W)


def nearest_border(img, q):
    """grid_sample nearest, border padding, align_corners True, at absolute pixel positions q (n, 2, H, W)."""
    H, W = img.shape[-2:]
    qx = torch.round(q[:, 0]).clamp(0, W - 1).long()                                                              
    qy = torch.round(q[:, 1]).clamp(0, H - 1).long()
    idx = (qy * W + qx).view(q.shape[0], 1, -1).expand(-1, img.shape[1], -1)
    return img.flatten(2).gather(2, idx).view(img.shape[0], img.shape[1], H, W)


def invert_t1(f, depth, t, f_bp=None, valid=None, iters=4, accel_cap=0.5):
    """nfru_head.invert_t with rings=() (one start): (to_A, to_B, hole, oob) -- oob = LAST_OOB."""
    n, _, H, W = f.shape
    tt = t.view(n, 1, 1, 1)
    if f_bp is None:
        disp = (1 - tt) * f
    else:
        a = f_bp - 2 * f
        cap = accel_cap * f.norm(dim=1, keepdim=True)
        a = a * (cap / a.norm(dim=1, keepdim=True).clamp_min(1e-6)).clamp(max=1.0)
        a = torch.where(torch.isfinite(f_bp).all(1, keepdim=True), a, torch.zeros_like(a))
        disp = (1 - tt) * f + 0.5 * a * tt * (tt - 1)
    ok = torch.ones(n, 1, H, W, device=f.device) if valid is None else (valid > 0.5).float()
    yy, xx = torch.meshgrid(torch.arange(H, device=f.device, dtype=f.dtype), torch.arange(W, device=f.device, dtype=f.dtype), indexing="ij")
    grid = torch.stack((xx, yy), 0)[None]
    q = grid - nearest_border(disp, grid)
    for _ in range(iters):
        q = grid - nearest_border(disp, q)
    res = (q + nearest_border(disp, q) - grid).abs().amax(1, keepdim=True)
    inb = (q[:, :1] >= 0) & (q[:, :1] <= W - 1) & (q[:, 1:] >= 0) & (q[:, 1:] <= H - 1)
    good = (res <= 1.0) & inb & (nearest_border(ok, q) > 0.5)
    oob = ((q[:, :1] < -0.5) | (q[:, :1] > W - 0.5) | (q[:, 1:] < -0.5) | (q[:, 1:] > H - 0.5)).float()
    rel = q - grid
    f_x, d_x = M.warp(f, rel), M.warp(disp, rel)
    return f_x - d_x, -d_x, (~good).float(), oob


def off_frame(fl):
    n, _, H, W = fl.shape
    yy, xx = torch.meshgrid(torch.arange(H, device=fl.device), torch.arange(W, device=fl.device), indexing="ij")
    qx, qy = xx[None] + fl[:, 0], yy[None] + fl[:, 1]
    return ((qx < -0.5) | (qx > W - 0.5) | (qy < -0.5) | (qy > H - 0.5))[:, None].float()


def median_hist(x, bins=4096):
    """Per-frame median of x in [0, 1] from a histogram: the centre of the bin holding the lower median."""
    v = x.flatten().clamp(0, 1)
    h = torch.bincount(torch.clamp((v * bins).long(), max=bins - 1), minlength=bins)
    k = (v.numel() - 1) // 2
    b = int(torch.searchsorted(h.cumsum(0), torch.tensor(k + 1, device=x.device)))
    return (b + 0.5) / bins


def contrast(img):
    l = (img * torch.tensor([.299, .587, .114], device=img.device).view(1, 3, 1, 1)).sum(1, keepdim=True)
    gx = F.pad((l[..., :, 2:] - l[..., :, :-2]).abs(), (1, 1, 0, 0))
    gy = F.pad((l[..., 2:, :] - l[..., :-2, :]).abs(), (0, 0, 1, 1))
    return F.avg_pool2d(gx + gy, 5, 1, 2)


def vp_b_for_quadratic(vp_p, vp_a, vp_b, t):
    """The VP_B to put in the fc block so that the kernel's clip lerp (1-t) VP_A + t VP_B equals the camera at t
    from a quadratic through P (previous real frame, -1), A (0), B (1) (TRAIL_A=camq, 2026-10-23: 4x NFRU total -2..5 %,
    no kernel change). The host computes it per generated frame; without P (first pair) pass VP_B itself (linear)."""
    vp_t = vp_p * (t * (t - 1) / 2) + vp_a * ((1 - t) * (1 + t)) + vp_b * (t * (t + 1) / 2)
    return vp_a + (vp_t - vp_a) / t


def cam_flow(ndc, vpa, vpb, inv_vpa, t):
    """A pixel -> its position at t (static content): clip lerp between VP_A and VP_B (eval_nfru_mfg.cam_flow_t)."""
    _, _, H, W = ndc.shape
    yy, xx = torch.meshgrid(torch.arange(H, device=ndc.device, dtype=torch.float32), torch.arange(W, device=ndc.device, dtype=torch.float32), indexing="ij")
    nx = (xx + 0.5) / W * 2 - 1; ny = -((yy + 0.5) / H * 2 - 1)
    clip = torch.stack((nx, ny, ndc[0, 0], torch.ones_like(nx)), -1)
    world = clip @ inv_vpa
    c = world @ ((1 - t) * vpa + t * vpb)
    p = c[..., :2] / c[..., 3:4]
    px = (p[..., 0] + 1) / 2 * W - 0.5; py = (-p[..., 1] + 1) / 2 * H - 0.5
    return torch.stack((px - xx, py - yy), 0)[None]


                                                                                                        
def vig_features(X, Y, W, H):
    dx = (2 * X / (W - 1) - 1).clamp(-1, 1); dy = (2 * Y / (H - 1) - 1).clamp(-1, 1)
    fx, fy = dx * dx, dy * dy
    return torch.stack((fx * (dx < 0), fx * (dx >= 0), fy), 0)


                                                                                                                       
                                                                                                 
GEN_PHASE = int(os.environ.get("GEN_PHASE", "0")) or int(os.environ.get("GEN_LANES", "0"))                         


def vig_sums(ca, cb, mv, mvv, step=4, min_px=30.0):
    """Normal equation sums over the 4 x 4 grid: (sum R R^T (3x3), sum R r (3), count)."""
    _, _, H, W = ca.shape
    p0 = GEN_PHASE                                          
    yy, xx = torch.meshgrid(torch.arange(p0, H, step, device=ca.device, dtype=torch.float32),
                            torch.arange(p0, W, step, device=ca.device, dtype=torch.float32), indexing="ij")
    lum = lambda c: (c * torch.tensor([.299, .587, .114], device=c.device).view(1, 3, 1, 1)).sum(1, keepdim=True)
    lane = mv.shape[-1] != W                                                                                             
    m = mv[0, :, ::2, ::2] if lane else mv[0, :, p0::step, p0::step]
    sx, sy = xx + m[0], yy + m[1]
    g = torch.stack((2 * sx / (W - 1) - 1, 2 * sy / (H - 1) - 1), -1)[None]
    la = F.grid_sample(lum(ca), g, mode="bilinear", align_corners=True)[0, 0]
    lb = lum(cb)[0, 0, p0::step, p0::step]
    ok = ((mvv[0, 0, ::2, ::2] if lane else mvv[0, 0, p0::step, p0::step]) > 0.5) & (sx >= 1) & (sx <= W - 2) & (sy >= 1) & (sy <= H - 2) & (la > 0.03) & (lb > 0.03)
    ok &= torch.hypot(m[0], m[1]) > min_px
    r = torch.log(lb.clamp_min(1e-6)) - torch.log(la.clamp_min(1e-6))
    ok &= r.abs() < 0.5
    R = vig_features(xx, yy, W, H) - vig_features(sx, sy, W, H)                       
    R = R * ok; r = r * ok
    ata = torch.einsum("ihw,jhw->ij", R.double(), R.double())
    atb = torch.einsum("ihw,hw->i", R.double(), r.double())
    return ata, atb, int(ok.sum())


def vig_update(state, sums, decay=0.85):
    """state: dict ata (3,3), atb (3) (float64). Returns the 3 log-edge coefficients (darken-only clamp)."""
    ata, atb, n = sums
    if state.get("ata") is None:
        state["ata"] = torch.zeros(3, 3, dtype=torch.float64, device=ata.device); state["atb"] = torch.zeros(3, dtype=torch.float64, device=ata.device)
    state["ata"] = state["ata"] * decay; state["atb"] = state["atb"] * decay
    if n > 64:
        s = 1e4 / n
        state["ata"] = state["ata"] + s * ata; state["atb"] = state["atb"] + s * atb
    return vig_solve(state["ata"], state["atb"])


def vig_solve(ata, atb):
    P = 3
    r_ = max(1e-6 * float(torch.diagonal(ata).sum()) / P, 1e-9)
    A = ata + r_ * torch.eye(P, dtype=ata.dtype, device=ata.device)
    free = [True] * P
    for _ in range(P):
        lv = torch.zeros(P, dtype=ata.dtype, device=ata.device)
        fi = [i for i in range(P) if free[i]]
        if fi:
            lv[fi] = torch.linalg.solve(A[fi][:, fi], atb[fi])
        if not any(free[i] and float(lv[i]) > 0 for i in range(P)):
            break
        free = [free[i] and not float(lv[i]) > 0 for i in range(P)]
    return lv.float()


def vig_map(lv, H, W, device):
    yy, xx = torch.meshgrid(torch.arange(H, device=device, dtype=torch.float32), torch.arange(W, device=device, dtype=torch.float32), indexing="ij")
    f = vig_features(xx, yy, W, H)
    return torch.exp((f * lv.view(3, 1, 1).to(device)).sum(0))[None, None]


                                                                                                                 
def gen_reference(head, inp, t, has_prev, vig_lv, cam):
    """inp: dict of (1, c, H, W) tensors (see module doc); vig_lv: 3 coefficients; cam: (vpa, vpb, inv_vpa) 4x4.
    Returns (out (1,3,H,W) clamped, rule mask m (the next frame's pmask at this k))."""
    ca, cb, da, db = inp["col_a"], inp["col_b"], inp["dep_a"], inp["dep_b"]
    _, _, H, W = ca.shape
    V = vig_map(vig_lv, H, W, ca.device)
    ca_h, cb_h = ca / V, cb / V
    mv, mvv, of = inp["mv"], inp["mvv"], inp["of"]
    tt = torch.tensor([float(t)], device=ca.device)
    mv_bp = (mv + M.warp(inp["mv_ap"], mv)) if has_prev else None
    of_bp = (of + M.warp(inp["of_prev"], of)) if has_prev else None
    ma, mb, hole_mv, oob_mv = invert_t1(mv * mvv, db, tt, mv_bp, mvv)
    oa, ob, hole_of, oob_of = invert_t1(of, db, tt, of_bp)
    wn = lambda img, fl, i: torch.where(off_frame(fl) > 0.5, hash_noise(1, 3, H, W, i, img.device), M.warp(img, fl))
    cand = torch.stack((wn(ca_h, ma, 0), wn(cb_h, mb, 1), wn(ca_h, oa, 2), wn(cb_h, ob, 3)), 1)
    co = inp["co"]
    up = lambda z: F.interpolate(z, size=(H, W), mode="bilinear", align_corners=False)
    conf = torch.sigmoid(M.warp(up(co[:, 0:1]), ob))
    occ = torch.sigmoid(M.warp(up(co[:, 1:2]), ob))
    da_ma, db_mb = M.warp(da, ma), M.warp(db, mb)
    x = torch.cat((cand.flatten(1, 2), da_ma, db_mb, hole_mv, hole_of, tt.view(1, 1, 1, 1).expand(1, 1, H, W),
                   (cand[:, 0] - cand[:, 1]).abs().mean(1, keepdim=True) * 4, (cand[:, 2] - cand[:, 3]).abs().mean(1, keepdim=True) * 4,
                   ((ma - oa).norm(dim=1, keepdim=True) / 16.0).clamp(max=4.0), conf, occ,
                   ((da_ma - db_mb).abs() * 16).clamp(max=4.0), ((M.warp(da, oa) - M.warp(db, ob)).abs() * 16).clamp(max=4.0),
                   off_frame(ma), oob_mv, off_frame(oa), oob_of), 1)
    lq = head.ae(F.avg_pool2d(x, 4))
    w = F.interpolate(lq, size=(H, W), mode="bilinear", align_corners=False).softmax(1)
    color = (w[:, :, None] * cand).sum(1).clamp(0, 1)
                                           
    c = cand
    w2 = w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6)
    mo = (w2[:, :, None] * c[:, :2]).sum(1)
    oa_, ob_ = off_frame(ma), oob_mv
    mo = torch.where(oa_ > 0.5, c[:, 1], torch.where(ob_ > 0.5, c[:, 0], mo))
    d_mv = F.avg_pool2d((c[:, 0] - c[:, 1]).abs().mean(1, keepdim=True), 3, 1, 1)
    d_of = F.avg_pool2d((c[:, 2] - c[:, 3]).abs().mean(1, keepdim=True), 3, 1, 1)
    one = ((oa_ + ob_) > 0.5).float()
    d_mv = d_mv * (1 - F.max_pool2d(one, 9, 1, 4))
    floor = median_hist(d_mv)
    k = contrast(mo) + floor + 1e-3
    m = torch.sigmoid((d_mv - d_of - 0.5 * k) / (0.25 * k))
    m = F.avg_pool2d(F.max_pool2d(m, 9, 1, 4), 5, 1, 2)
    if has_prev:
        to_prev = ma + (1 - float(t)) * M.warp(inp["mv_ap"], ma)
        m = torch.maximum(m, 0.6 * M.warp(inp["pmask"], to_prev))
    col = (1 - m) * mo + m * color
                                                                                         
    vpa, vpb, ivpa = cam
    dt = cam_flow(inp["ndc_a"], vpa, vpb, ivpa, float(t))
    _, to_a2, hole2, _ = invert_t1(dt, da, torch.zeros(1, device=ca.device))

    trail_homog_r = int(os.environ.get("TRAIL_HOMOG", "48"))
    trail_homog_auto = float(os.environ.get("TRAIL_HOMOG_AUTO", "10"))
    force_homog = os.environ.get("FORCE_HOMOG") == "1"
    if trail_homog_r > 0 or force_homog:
        import homog_fill as HF
        trail = (oob_mv > 0.5)
        ring = HF.ring_outside(trail, trail_homog_r) & (hole_mv < 0.5) & (off_frame(ma) < 0.5)
        dis = HF.camera_disagreement(to_a2, ma, ring)
        if force_homog or (dis is not None and dis > trail_homog_auto):
            th = HF.fit_homog_flow(ma, ring)
            if th is not None:
                to_a2 = th
                hole2 = torch.zeros_like(hole2)

    use = (oob_mv > 0.5) & (hole2 < 0.5) & (off_frame(to_a2) < 0.5)
    col = torch.where(use, M.warp(ca_h, to_a2), col)
    return (col * V).clamp(0, 1), m
