"""Per-pixel choice between the head's game-MV candidates and its full blend (with the OF), on top of NfruHeadC2's
candidates (hc["cand"]: MV->A, MV->B, OF->A, OF->B; hc["weights"]; hc["color"]).
  mv_only(hc)            the head's own A/B split restricted to the two MV candidates
  rule_abs(hc, thr)      full blend where |MV->A - MV->B| > thr (absolute colour threshold; SN2-tuned 0.08)
  rule_rel(hc, ...)      full blend where the MV pair is clearly less consistent than the OF pair, with margin and
                         width proportional to the local contrast + a per-frame noise floor (median MV-pair
                         disagreement): no absolute threshold to tune per game; optional temporal carry-over.
Every rule: mask dilated by `dil` px and feathered over 5 px; output = (1 - m) * mv_only + m * full blend."""
import os
import torch
from torch.nn import functional as F
from model_v2 import warp

luma = lambda c: (c * torch.tensor([.299, .587, .114], device=c.device).view(1, 3, 1, 1)).sum(1, keepdim=True)


def mv_only(hc):
    w2 = hc["weights"][:, :2]
    w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
    return (w2[:, :, None] * hc["cand"][:, :2]).sum(1)


def _shape(mk, dil):
    return F.avg_pool2d(F.max_pool2d(mk, 2 * dil + 1, 1, dil), 5, 1, 2)


BOTHFAIL_LOG = []                                            


def disagreement(hc):
    c = hc["cand"]
    d_mv = F.avg_pool2d((c[:, 0] - c[:, 1]).abs().mean(1, keepdim=True), 3, 1, 1)
    d_of = F.avg_pool2d((c[:, 2] - c[:, 3]).abs().mean(1, keepdim=True), 3, 1, 1)
    return d_mv, d_of


def contrast(img):
    l = luma(img)
    gx = F.pad((l[..., :, 2:] - l[..., :, :-2]).abs(), (1, 1, 0, 0))
    gy = F.pad((l[..., 2:, :] - l[..., :-2, :]).abs(), (0, 0, 1, 1))
    return F.avg_pool2d(gx + gy, 5, 1, 2)


def rule_abs(hc, thr=0.08, dil=4):
    d_mv, _ = disagreement(hc)
    m = _shape((d_mv > thr).float(), dil)
    return (1 - m) * mv_only(hc) + m * hc["color"], m


def rule_rel(hc, margin=0.5, width=0.25, dil=4, prev=None, to_prev=None, carry=0.6):
    """prev: the previous output's mask, to_prev: flow from this frame's pixels to it (e.g. the t-flow to A),
    carried with weight `carry` (hysteresis against flicker)."""
    d_mv, d_of = disagreement(hc)
    mo = mv_only(hc)
    if os.environ.get("ONESIDE", "1") == "1" and "off_mv" in hc:                                                 
                                                                                                              
                                                                                                     
        oa_, ob_ = hc["off_mv"]
        c = hc["cand"]
        r = int(os.environ.get("ONESIDE_SOFT", "0"))                                                               
        if r > 0:                                                                              
            soft = lambda m_: F.avg_pool2d(F.max_pool2d(m_, 2 * r + 1, 1, r), 2 * r + 1, 1, r, count_include_pad=False)
            sa, sb = soft(oa_), soft(ob_)
            sa, sb = torch.maximum(sa, oa_), torch.maximum(sb, ob_)
            mo = mo + sa * (c[:, 1] - mo)                                                        
            mo = mo + sb * (1 - oa_) * (c[:, 0] - mo)
            d_mv = d_mv * (1 - torch.maximum(sa, sb))
        else:
            mo = torch.where(oa_ > 0.5, c[:, 1], torch.where(ob_ > 0.5, c[:, 0], mo))
            one = ((oa_ + ob_) > 0.5).float()
            d_mv = d_mv * (1 - F.max_pool2d(one, 9, 1, 4))
    floor = d_mv.flatten(1).median(1).values.view(-1, 1, 1, 1)                                               
    k = contrast(mo) + floor + 1e-3
    s = (d_mv - d_of - margin * k) / (width * k)
    m = _shape(torch.sigmoid(s), dil)
    if os.environ.get("OF_REACH"):                                                                                           
        r0, r1 = (float(v) for v in os.environ["OF_REACH"].split(","))                                                   
        ma_, mb_ = hc["tflows"][0], hc["tflows"][1]
        reach = ((ma_ - mb_).norm(dim=1, keepdim=True) - r0) / max(r1 - r0, 1e-6)                                       
        reach = reach.clamp(0, 1)
        if os.environ.get("OF_REACH_AGREE"):                                                                              
            agree = (1 - d_mv / float(os.environ["OF_REACH_AGREE"])).clamp(0, 1)
            reach = reach * agree
        if os.environ.get("OF_REACH_VM") and "dep_mb" in hc:                                                      
            r = int(os.environ["OF_REACH_VM"])
            near = (hc["dep_mb"] < 0.21).float()                                                           
            reach = reach * (1 - F.max_pool2d(near, 2 * r + 1, 1, r))
        m = m * (1 - reach)
    if prev is not None:
        pw = warp(prev, to_prev) if to_prev is not None else prev
        m = torch.maximum(m, carry * pw)
    color = hc["color"]
    if os.environ.get("PICK"):                                                                                        
        t0, t1 = (float(v) for v in os.environ["PICK"].split(","))                                                 
        c, w = hc["cand"], hc["weights"]
        dm, _ = disagreement(hc)
        alpha = ((dm - t0) / max(t1 - t0, 1e-6)).clamp(0, 1)
        pick_mv = torch.where(w[:, 0:1] >= w[:, 1:2], c[:, 0], c[:, 1])                                  
        if "off_mv" in hc:                                                                                     
            oa_, ob_ = hc["off_mv"]
            pick_mv = torch.where(oa_ > 0.5, c[:, 1], torch.where(ob_ > 0.5, c[:, 0], pick_mv))
        mo = mo + alpha * (pick_mv - mo)
        top = F.one_hot(w.argmax(1), 4).permute(0, 3, 1, 2).float()                                         
        color = color + alpha * ((top[:, :, None] * c).sum(1) - color)
    out = (1 - m) * mo + m * color
    if os.environ.get("BOTHFAIL") and "t" in hc:                                                                  
        bm, bw = (float(v) for v in os.environ["BOTHFAIL"].split(","))                                            
        d_mv0, d_of0 = disagreement(hc)                                                                               
        bf = _shape(torch.sigmoid((torch.minimum(d_mv0, d_of0) - bm * k) / (bw * k)), dil)                           
        c = hc["cand"]                                                                                    
        near = c[:, 0] if hc["t"] <= 0.5 else c[:, 1]
        if "off_mv" in hc:
            oa_, ob_ = hc["off_mv"]
            near = torch.where(oa_ > 0.5, c[:, 1], torch.where(ob_ > 0.5, c[:, 0], near))
        out = out + bf * (near - out)
        BOTHFAIL_LOG.append(float(bf.mean()))
    return out, m


def fuse_flow(color_a, color_b, mv, mv_valid, of, margin=0.5, width=0.25):
    """Choose per SOURCE pixel (B grid) between the game MV and the OF, before anything is moved to t: one fused B->A
    flow for every t (no MV/OF position mix at t, the same split for all generated frames, one t-alignment instead of
    two). Evidence: how well each flow explains B (|B - A pulled by it|, 3x3 mean), relative test with margin / width
    proportional to the local contrast of B + a per-frame noise floor (median MV residual), as rule_rel. The flows are
    selected, never averaged. Returns (fused flow, OF mask 0/1)."""
    r_mv = F.avg_pool2d((warp(color_a, mv) - color_b).abs().mean(1, keepdim=True), 3, 1, 1)
    r_of = F.avg_pool2d((warp(color_a, of) - color_b).abs().mean(1, keepdim=True), 3, 1, 1)
    floor = r_mv.flatten(1).median(1).values.view(-1, 1, 1, 1)
    k = contrast(color_b) + floor + 1e-3
    use_of = ((r_mv - r_of - margin * k) / (width * k) > 0).float()
    use_of = torch.maximum(use_of, 1 - (mv_valid > 0.5).float())                                  
    return torch.where(use_of > 0.5, of, mv), use_of
