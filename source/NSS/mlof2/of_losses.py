"""Losses for pre-training the pure OF network alone (train_v2 --stage of).

Standard unsupervised optical-flow practice (public: UnFlow, Meister et al. AAAI 2018; ARFlow, Liu et al. CVPR 2020),
implemented here:
  census   ternary census transform (7x7) of the warped vs the target frame: robust to brightness / exposure
           change, so the OF matches structure, not raw colour. Both directions, occlusions masked out.
  smooth   edge-aware first-order smoothness: flow may change where the image has an edge, elsewhere it should not.
  occlusion: UnFlow round-trip check with a threshold relative to the motion size (detached).
Supervision where the motion is known exactly: geometry flow (engine MV chain, also exact for the synthetic camera
turns of augment_v2.pan_rotate) only where it explains the colour, and the appearance flow of synthetic objects.
"""
import torch
from torch.nn import functional as F

from model_v2 import warp, resize_flow, full_flow
from losses_v2 import round_trip_occlusion, explain_error, masked_l1, FLOW_SCALE


def _gray(x):
    return (0.299 * x[:, 0:1] + 0.587 * x[:, 1:2] + 0.114 * x[:, 2:3]) * 255.0


def census_transform(img, k=7):
    g = _gray(img)
    p = F.unfold(F.pad(g, (k // 2,) * 4, mode="replicate"), k).view(g.shape[0], k * k, *g.shape[-2:])
    d = p - g
    return d / torch.sqrt(0.81 + d * d)


def census_loss(warped, target, mask, k=7):
    """Per-pixel census distance, robust power, mean over the mask."""
    d = (census_transform(warped, k) - census_transform(target, k)) ** 2
    dist = (d / (0.1 + d)).sum(1, keepdim=True) / (k * k)
    e = (dist.abs() + 0.01) ** 0.4
    m = mask.clone()
    m[..., : k // 2, :] = 0; m[..., -(k // 2):, :] = 0; m[..., :, : k // 2] = 0; m[..., :, -(k // 2):] = 0
    return (e * m).sum() / m.sum().clamp_min(1.0)


def smooth_loss(flow, img, alpha=10.0):
    """Edge-aware first-order smoothness of flow (any grid) against img resized to that grid."""
    im = F.interpolate(img, size=flow.shape[-2:], mode="area")
    f = flow * FLOW_SCALE
    gx_f, gy_f = (f[..., :, 1:] - f[..., :, :-1]).abs(), (f[..., 1:, :] - f[..., :-1, :]).abs()
    gx_i = (im[..., :, 1:] - im[..., :, :-1]).abs().mean(1, keepdim=True)
    gy_i = (im[..., 1:, :] - im[..., :-1, :]).abs().mean(1, keepdim=True)
    return (gx_f * torch.exp(-alpha * gx_i)).mean() + (gy_f * torch.exp(-alpha * gy_i)).mean()


OF_W = {"census": 1.0, "smooth": 0.1, "geo": 0.2, "app": 0.5, "ms": 0.2, "chain": 0.2, "teach": 0.0, "tms": 0.0, "tmask": 0, "tmask_off": 0.0,
                                                                                                                         
                                                                                                                        
        "mag": 0.0, "mag_max": 8.0, "ms_decay": 0.5,
                                                                                                                       
                                                                                                                   
                                                                                                                   
                                                                   
        "gt_vis": 0, "edge": 0.0}


def mol_loss(pred, conf, beta, gt, w, beta_max=10.0):
    """Mixture-of-Laplace NLL per axis (SEA-RAFT): component 1 scale 1 px (= L1), component 2 scale e^beta,
    beta in [0, beta_max]; mixture weight alpha = sigmoid(conf). pred/gt full-res px; conf/beta any res."""
    H, W = gt.shape[-2:]
    up = lambda x: F.interpolate(x, size=(H, W), mode="bilinear", align_corners=False)
    a = torch.sigmoid(up(conf)).clamp(1e-4, 1 - 1e-4)
    b = up(beta).clamp(0.0, beta_max)
    d = (pred - gt).abs()                                                      
    l1 = torch.log(a) - d - 0.6931                                                     
    l2 = torch.log(1 - a) - d * torch.exp(-b) - b - 0.6931
    nll = -torch.logsumexp(torch.stack((l1, l2)), 0)
    return (nll * w).sum() / (2 * w.sum()).clamp_min(1.0)


def of_loss(ofs, batch, w=None):
    """ofs: PairFlow.of_forward output ({level: {of, ...}}, rows 0..n-1 from B, n..2n-1 from A)."""
    w = dict(OF_W, **(w or {}))
    ca, cb = batch["color_a"], batch["color_b"]
    n, _, H, W = ca.shape
    of = ofs[4]["of"]
    ff = full_flow(ofs[4], H, W)                                                                         
    f_ba, f_ab = ff[:n], ff[n:]
    occ_b = round_trip_occlusion(of[:n], of[n:]).detach()                                     
    occ_a = round_trip_occlusion(of[n:], of[:n]).detach()
    up = lambda m: F.interpolate(m, size=(H, W), mode="nearest")
    bv = batch.get("b_valid", torch.ones_like(ca[:, :1]))
    vis_b = (1 - up(occ_b)) * bv
    if w["gt_vis"] and "geo_flow_ba" in batch:
        g = batch["geo_flow_ba"]
        on = (warp(torch.ones_like(ca[:, :1]), g) > 0.999).float()
        vis_b = (explain_error(ca, cb, g) <= 0.5).float() * on * bv
    vis_a = (1 - up(occ_a))
                                                                                              
    h2, w2 = H // 2, W // 2
    d2 = lambda x: F.interpolate(x, size=(h2, w2), mode="area")
    ca2, cb2 = d2(ca), d2(cb)
    fb2, fa2 = resize_flow(f_ba, h2, w2), resize_flow(f_ab, h2, w2)
    vb2, va2 = (d2(vis_b) > 0.99).float(), (d2(vis_a) > 0.99).float()
    parts = {"census": 0.5 * (census_loss(warp(ca2, fb2), cb2, vb2) + census_loss(warp(cb2, fa2), ca2, va2)),
             "smooth": 0.5 * (smooth_loss(of[:n], cb) + smooth_loss(of[n:], ca))}
    if "geo_flow_ba" in batch:
        geo_ok = (explain_error(ca, cb, batch["geo_flow_ba"]) <= 0.5).float() * bv
        if w["edge"] > 0:
            g = batch["geo_flow_ba"]
            rng = (F.max_pool2d(g, 17, 1, 8) + F.max_pool2d(-g, 17, 1, 8)).amax(1, keepdim=True)
            geo_ok = geo_ok * (1 + w["edge"] * (rng > 8).float())
        if w["mag"] > 0:
            geo_ok = geo_ok * (1 + (batch["geo_flow_ba"].norm(dim=1, keepdim=True) / w["mag"]).clamp(max=w["mag_max"]))
        parts["geo"] = masked_l1(f_ba * FLOW_SCALE, batch["geo_flow_ba"] * FLOW_SCALE, geo_ok)
    if "app_flow_ba" in batch:
        parts["app"] = masked_l1(f_ba * FLOW_SCALE, batch["app_flow_ba"] * FLOW_SCALE, batch["app_valid"])
                                                                                                           
                                                                                                             
    ms = 0.0
    for i, lv in enumerate((8, 16, 32, 64 if 64 in ofs else "gm")):
        if lv not in ofs:
            continue
        fl = ofs[lv]["of"][:n]
        h, w_ = fl.shape[-2:]
        dn = lambda m: F.interpolate(m, size=(h, w_), mode="area")
        up_f = resize_flow(fl, H, W)
        if "geo_flow_ba" in batch:
            ms = ms + w["ms_decay"] ** (i + 1) * masked_l1(up_f * FLOW_SCALE, batch["geo_flow_ba"] * FLOW_SCALE, geo_ok)
        if "app_flow_ba" in batch:
            ms = ms + w["ms_decay"] ** (i + 1) * masked_l1(up_f * FLOW_SCALE, batch["app_flow_ba"] * FLOW_SCALE, batch["app_valid"])
    if torch.is_tensor(ms):
        parts["ms"] = ms
    if "teach_ba" in batch:                                                                                      
        tw = torch.exp(-batch["teach_unc"]).clamp(0, 1) * bv
        if w.get("tmask", 0) and "geo_flow_ba" in batch:
                                                                                                                       
                                                                                                                    
            gt = batch["geo_flow_ba"]
            tol = torch.clamp(0.1 * gt.norm(dim=1, keepdim=True), min=3.0)
            bad = ((batch["teach_ba"] - gt).norm(dim=1, keepdim=True) > tol).float() * geo_ok
            tw = tw * (1 - bad)
            parts["tmask_off"] = bad.mean().detach()
        o4 = ofs[4]
        parts["teach"] = FLOW_SCALE * mol_loss(f_ba, o4["conf"][:n], o4["beta"][:n], batch["teach_ba"], tw)
        tms = 0.0
        for i, lv in enumerate((8, 16, 32, "gm")):
            if lv in ofs:
                tms = tms + 0.5 ** (i + 1) * masked_l1(resize_flow(ofs[lv]["of"][:n], H, W) * FLOW_SCALE,
                                                       batch["teach_ba"] * FLOW_SCALE, tw)
        parts["tms"] = tms
    loss = sum(w[k] * v for k, v in parts.items())
    return loss, {k: v.detach().item() for k, v in parts.items()}


def tri_inputs(fa, fb, fg, batch):
    """Encoder pyramids / colours for one OF call on the pairs (A,B), (A,G), (G,B) (pair = batch block)."""
    cat = lambda *x: torch.cat(x, 0)
    f1 = {lv: cat(fa[lv], fa[lv], fg[lv]) for lv in fa}
    f2 = {lv: cat(fb[lv], fg[lv], fb[lv]) for lv in fb}
    ca, cb, cg = batch["color_a"], batch["color_b"], batch["color_g"]
    return f1, f2, cat(ca, ca, cg), cat(cb, cg, cb)


def _pair(ofs, p, n):
    """Pair p of a tri OF call in the layout of_loss expects (rows 0..n-1 from the 2nd frame, n..2n-1 from the 1st)."""
    out = {}
    for lv, o in ofs.items():
        out[lv] = {k: torch.cat((v[p * n:(p + 1) * n], v[3 * n + p * n:3 * n + (p + 1) * n]), 0)
                   for k, v in o.items() if torch.is_tensor(v)}
    return out


def chain_loss(ofs, n, H):
    """Long-span flow vs the composition of the two short ones (detached teacher), at 1/4, both directions."""
    of = ofs[4]["of"]
    f_ba, f_ga, f_bg = of[:n], of[n:2 * n], of[2 * n:3 * n]
    f_ab, f_ag, f_gb = of[3 * n:4 * n], of[4 * n:5 * n], of[5 * n:]
    unit = H / of.shape[-2] * FLOW_SCALE                                                     
    ones = torch.ones_like(f_ba[:, :1])
    loss = 0.0
    with torch.no_grad():
        jobs = []
        for long_, s1, s1r, s2, s2r in ((f_ba, f_bg, f_gb, f_ga, f_ag), (f_ab, f_ag, f_ga, f_gb, f_bg)):
            tgt = s1 + warp(s2, s1)
            ok = (1 - round_trip_occlusion(s1, s1r)) * (1 - warp(round_trip_occlusion(s2, s2r), s1))
            ok = ok * (warp(ones, s1) > 0.999).float()
            jobs.append((tgt, (ok > 0.5).float()))
    for long_, (tgt, ok) in zip((f_ba, f_ab), jobs):
        loss = loss + 0.5 * masked_l1(long_ * unit, tgt * unit, ok)
    return loss


def of_loss_tri(ofs, batch, w=None):
    """ofs: PairFlow.of_forward on tri_inputs. Per pair of_loss (census / smooth / geo / app / ms), mean over the
    three pairs, + chain consistency."""
    w = dict(OF_W, **(w or {}))
    n = batch["color_a"].shape[0]
    ca, cb, cg = batch["color_a"], batch["color_b"], batch["color_g"]
    subs = [
        {"color_a": ca, "color_b": cb, "geo_flow_ba": batch["geo_flow_ba"],
         **({"app_flow_ba": batch["app_flow_ba"], "app_valid": batch["app_valid"]} if "app_flow_ba" in batch else {})},
        {"color_a": ca, "color_b": cg, "geo_flow_ba": batch["geo_flow_ga"],
         **({"app_flow_ba": batch["app_flow_ga"], "app_valid": batch["app_valid_g"]} if "app_flow_ga" in batch else {})},
        {"color_a": cg, "color_b": cb, "geo_flow_ba": batch["geo_flow_bg"],
         **({"app_flow_ba": batch["app_flow_bg"], "app_valid": batch["app_valid"]} if "app_flow_bg" in batch else {})},
    ]
    if "teach_ba" in batch:                                                                             
        for p, sb in enumerate(subs):
            sb["teach_ba"] = batch["teach_ba"][p * n:(p + 1) * n]
            sb["teach_unc"] = batch["teach_unc"][p * n:(p + 1) * n]
    loss, parts = 0.0, {}
    for p, sb in enumerate(subs):
        l, pp = of_loss(_pair(ofs, p, n), sb, w)
        loss = loss + l / 3.0
        for k, v in pp.items():
            parts[k] = parts.get(k, 0.0) + v / 3.0
    ch = chain_loss(ofs, n, ca.shape[-2])
    loss = loss + w.get("chain", 0.2) * ch
    parts["chain"] = ch.detach().item()
    return loss, parts
