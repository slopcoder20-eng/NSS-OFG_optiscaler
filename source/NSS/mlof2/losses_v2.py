"""MLOF2 training losses (design: docs/NFRU_MLOF2_DESIGN_20261015.md, revisions 4-5). Not wired into a trainer yet.

Ideas taken from public papers, implemented here:
  gate target   relative, not absolute: which candidate explains B better, MV-warped A or OF-warped A.
                The per-candidate error is the GFFE (Wu et al., TOG 2024) focus-mask measure: min SMAPE over
                the 3x3 neighbourhood. RGB on purpose: lighting-invariant features would call a moving shadow
                "explained by the MV" (the darkening disappears), which is exactly the case the gate exists for.
                  MV explains B                      -> c = 1 (both explain: prefer the exact geometry)
                  OF explains clearly better than MV -> c = 0 (moving shadow / reflection / MV-less object)
                  neither explains                   -> no target (lighting change, flicker, blending;
                                                        neither flow fixes it, do not force the OF)
  top-k loss    ExtraNet (Guo et al., TOG 2021) shading-augmented loss: extra L1 on the 10 % largest errors.
  hole loss     ExtraNet hole-augmented loss inside occlusions; occlusions from the UnFlow (Meister et al.,
                AAAI 2018) round-trip check with a threshold relative to the motion size. Ramped in.
  OF losses     self-supervised photometric loss of the OF warp alone (always on, no GT needed: the OF
                must learn even while c ~ 1); geometric flow GT only where it explains the colour (the
                captured "GT flow" is the engine MV = geometry, wrong for shadows); appearance-flow GT where
                a synthetic layer provides it.
All images are (N,3,H,W) in the training colour space (Karis tonemapped); masks are (N,1,H,W) in [0,1].
"""
import torch
from torch.nn import functional as F

from model_v2 import warp, resize_flow


def smape(a, b, eps=1e-3):
    """Symmetric mean absolute percentage error |a-b| / ((|a|+|b|)/2) per pixel, channel mean -> [0,2]."""
    return (2.0 * (a - b).abs() / (a.abs() + b.abs() + eps)).mean(1, keepdim=True)


def min_neighbour_smape(pred, gt):
    """min over the 3x3 neighbourhood x' of SMAPE(pred[x], gt[x']). Ignores sub-pixel shifts."""
    n, c, h, w = gt.shape
    g = F.unfold(F.pad(gt, (1, 1, 1, 1), mode="replicate"), 3).view(n, c, 9, h, w)
    e = (2.0 * (pred.unsqueeze(2) - g).abs() / (pred.unsqueeze(2).abs() + g.abs() + 1e-3)).mean(1)
    return e.amin(1, keepdim=True)


def explain_error(color_a, color_b, flow_ba):
    """How badly warping A by a B->A flow reproduces B (full res)."""
    return min_neighbour_smape(warp(color_a, flow_ba), color_b)


def gate_target(color_a, color_b, mv_ba, mv_valid, of_ba, size, exact=0.02, tie=0.03, both_bad=0.5):
    """Relative gate target at the gate's resolution. Returns (target, weight), both (N,1,h,w).
    of_ba: the network's own OF (detached here), any resolution; resized to full res.
    Decided by comparing the two errors, not by an absolute threshold: a 3 px MV error on texture gives
    min-3x3 SMAPE 0.05-0.35 (synthetic test), below GFFE's 0.5 "needs reshading" level, so an absolute
    threshold would keep a wrong MV. Thresholds are first guesses, to be tuned on real captures.
      MV wins : e_mv <= exact, or e_mv <= e_of + tie         (MV as good as the OF -> exact geometry)
      OF wins : e_of + tie < 0.5 * e_mv                      (OF error clearly below half of the MV's)
      none    : in between, or both > both_bad               (lighting change / flicker / blending)"""
    H, W = color_b.shape[-2:]
    e_mv = explain_error(color_a, color_b, mv_ba)
    e_of = explain_error(color_a, color_b, resize_flow(of_ba.detach(), H, W))
    has_mv = (mv_valid > 0.5).float()
    bad = ((e_mv > both_bad) & (e_of > both_bad)).float()
    mv_ok = torch.maximum((e_mv <= exact).float(), (e_mv <= e_of + tie).float()) * has_mv * (1 - bad)
    of_wins = (e_of + tie < 0.5 * e_mv).float() * (1 - mv_ok) * (1 - bad)
    of_wins = torch.maximum(of_wins, 1 - has_mv)                                          
    weight = torch.maximum(mv_ok, of_wins)                                               
    area = lambda x: F.interpolate(x, size=size, mode="area")
    w = area(weight)
    tgt = area(mv_ok) / w.clamp_min(1e-6)                                                                    
    return tgt, w


def gate_loss(c, target, weight):
    bce = F.binary_cross_entropy(c.clamp(1e-4, 1 - 1e-4), target.clamp(0, 1), reduction="none")
    return (bce * weight).sum() / weight.sum().clamp_min(1.0)


def bimodal_loss(c):
    """Pushes c towards 0 or 1 so two disagreeing flows are selected, not averaged. Max at c=0.5."""
    return (c * (1 - c)).mean() * 4.0


def topk_loss(pred, gt, frac=0.10):
    """Extra L1 on the largest frac of per-pixel errors (ExtraNet shading-augmented loss)."""
    e = (pred - gt).abs().mean(1).flatten(1)
    k = max(1, int(e.shape[1] * frac))
    return e.topk(k, dim=1).values.mean()


def topk_mask(pred, gt, frac=0.10):
    """The pixels topk_loss acts on, for dumping as an image (are they shadows, or edges and holes?)."""
    e = (pred - gt).abs().mean(1, keepdim=True)
    k = max(1, int(e[0].numel() * frac))
    th = e.flatten(1).topk(k, dim=1).values[:, -1].view(-1, 1, 1, 1)
    return (e >= th).float()


def masked_l1(pred, gt, mask):
    m = mask.expand_as(pred)
    return ((pred - gt).abs() * m).sum() / m.sum().clamp_min(1.0)


def charbonnier(x, eps=1e-3):
    return (x * x + eps * eps).sqrt()


def round_trip(f_xy, f_yx):
    """f_xy(x) + f_yx(x + f_xy(x)) and the back-sampled flow."""
    back = warp(f_yx, f_xy)
    return f_xy + back, back


def round_trip_occlusion(f_xy, f_yx, a1=0.01, a2=0.5):
    """UnFlow criterion: x is occluded in y when |f_xy + f_yx(x + f_xy)|^2 > a1 (|f_xy|^2 + |f_yx(..)|^2) + a2."""
    d, back = round_trip(f_xy, f_yx)
    lim = a1 * (f_xy.pow(2).sum(1, keepdim=True) + back.pow(2).sum(1, keepdim=True)) + a2
    return (d.pow(2).sum(1, keepdim=True) > lim).float()


def ramp(step, start, length):
    """0 before start, linear to 1 over length steps."""
    return float(min(max((step - start) / max(length, 1), 0.0), 1.0))


DEFAULT_W = {"l1": 1.0, "topk": 1.0, "hole": 1.0, "gate": 0.5, "bimodal": 0.05,
             "of_photo": 0.5, "of_geo": 0.05, "of_app": 0.1, "consist": 0.05}
FLOW_SCALE = 1.0 / 16.0                                                                                             


def total_loss(frame, gt_t, pair, batch, step=0, w=None, hole_ramp=(2000, 8000)):
    """One generated frame. batch: color_a, color_b, mv_ba, mv_valid; optional geo_flow_ba (engine motion,
    full res, B->A) and app_flow_ba + app_valid (appearance flow of synthetic layers). Returns (loss, parts)."""
    w = dict(DEFAULT_W, **(w or {}))
    n = gt_t.shape[0]
    H, W = gt_t.shape[-2:]
    ca, cb = batch["color_a"], batch["color_b"]
                                                                                                         
    gv = batch.get("gt_valid", torch.ones_like(gt_t[:, :1]))
    bv = batch.get("b_valid", torch.ones_like(gt_t[:, :1]))
    parts = {"l1": masked_l1(frame["color"], gt_t, gv), "topk": topk_loss(frame["color"] * gv, gt_t * gv)}
                                                                                          
    f_ba, f_ab = pair["f_ba"], pair["f_ab"]
    occ = round_trip_occlusion(f_ba, f_ab).detach()
    parts["hole"] = masked_l1(frame["color"], gt_t, F.interpolate(occ, size=(H, W), mode="nearest") * gv)
    d, _ = round_trip(f_ba, f_ab)
    parts["consist"] = (charbonnier(d * FLOW_SCALE).sum(1, keepdim=True) * (1 - occ)).sum() / (1 - occ).sum().clamp_min(1.0)
                                     
    c = pair["gate"][:n]
    tgt, tw = gate_target(ca, cb, batch["mv_ba"], batch["mv_valid"], pair["of_ba"], c.shape[-2:])
    tw = tw * F.interpolate(bv, size=c.shape[-2:], mode="area")
    parts["gate"] = gate_loss(c, tgt, tw)
    parts["bimodal"] = bimodal_loss(c)
                                                                                              
    of_full = resize_flow(pair["of_ba"], H, W)
    of_occ = F.interpolate(round_trip_occlusion(pair["of_ba"], pair["of_ab"]).detach(), size=(H, W), mode="nearest")
    ofm = (1 - of_occ) * bv
    parts["of_photo"] = (charbonnier(warp(ca, of_full) - cb).mean(1, keepdim=True) * ofm).sum() / ofm.sum().clamp_min(1.0)
    if "geo_flow_ba" in batch:                                                                             
        geo_ok = (explain_error(ca, cb, batch["geo_flow_ba"]) <= 0.5).float() * bv
        parts["of_geo"] = masked_l1(of_full * FLOW_SCALE, batch["geo_flow_ba"] * FLOW_SCALE, geo_ok)
    if "app_flow_ba" in batch:                                                                             
        parts["of_app"] = masked_l1(of_full * FLOW_SCALE, batch["app_flow_ba"] * FLOW_SCALE, batch["app_valid"])
    w["hole"] *= ramp(step, *hole_ramp)
    loss = sum(w[k] * v for k, v in parts.items())
    return loss, {k: v.detach().item() for k, v in parts.items()}


if __name__ == "__main__":
    torch.manual_seed(0)
    h, w = 64, 96
    a = F.avg_pool2d(torch.rand(1, 3, h + 2, w + 2), 3, 1)                                      
    shift = torch.zeros(1, 2, h, w)
    shift[:, 0] = 3.0                                                                              
    b = warp(a, shift)
    mvv = torch.ones(1, 1, h, w)
    inner = (slice(None), slice(None), slice(4, -4), slice(4, -8))
    zero = torch.zeros_like(shift)

    def decided_mean(t, wt, sl):
        m = wt[sl] > 0.5
        return t[sl][m].mean().item() if m.any() else float("nan")

    t, wt = gate_target(a, b, shift, mvv, zero, (h, w))
    print("MV right:           target %.2f weight %.2f (expect 1, 1)" % (decided_mean(t, wt, inner), wt[inner].mean()))
    t, wt = gate_target(a, b, zero, mvv, shift, (h, w))
    print("MV wrong, OF right: target %.2f weight %.2f (expect 0, high)" % (decided_mean(t, wt, inner), wt[inner].mean()))
                                                                                           
    sh = torch.ones(1, 1, h, w)
    sh[:, :, 20:40, 30:60] = 0.4
    img_a, img_b = a * sh, a * warp(sh, shift)
    of = torch.zeros_like(shift)
    of[:, :, 18:42, 26:64] = 3.0 * torch.tensor([1.0, 0.0]).view(1, 2, 1, 1)
    t, wt = gate_target(img_a, img_b, zero, mvv, of, (h, w))
    for name, xs in (("new shadow band", slice(27, 30)), ("uncovered band", slice(57, 60)), ("shadow interior", slice(35, 50))):
        sl = (slice(None), slice(None), slice(22, 38), xs)
        print("moving shadow, %-16s target %.2f weight %.2f" % (name + ":", decided_mean(t, wt, sl), wt[sl].mean()))
    print("  (expect bands 0 = OF wins; interior 1 = MV still right there)")
                                                                  
    img_b2 = a.clone()
    img_b2[:, :, 10:50, 10:80] *= 2.5
    t, wt = gate_target(a, img_b2, zero, mvv, zero, (h, w))
    print("lighting change:    weight %.2f (expect 0 = no target)" % wt[:, :, 14:46, 14:76].mean())
    print("bimodal c=0.5 %.3f, c=0.98 %.3f" % (bimodal_loss(torch.full((4,), 0.5)), bimodal_loss(torch.full((4,), 0.98))))
    print("ramp 0/5000/9000: %.2f %.2f %.2f" % (ramp(0, 2000, 8000), ramp(5000, 2000, 8000), ramp(9000, 2000, 8000)))
    f2 = torch.zeros(1, 2, 8, 12)
    f2[:, 0], f2[:, 1] = 2.0, 1.0
    r = resize_flow(f2, 16, 36)                                            
    print("anisotropic resize: x %.1f y %.1f (expect 6, 2)" % (r[0, 0, 5, 5], r[0, 1, 5, 5]))
    occ = round_trip_occlusion(shift, -shift)
    print("consistent pair occluded %.3f (expect 0)" % occ[inner].mean())
