"""MFG quality on a held-out 60 FPS NFRU-format capture (Arm neural-graphics NFRU test set: 1080p, per-frame game MV
at 540p, every frame rendered = a real frame at every t). Real frames f-N and f, generated f-N+k at t = k/N
(k = 1..N-1), scored against the rendered frame (no alignment needed: same camera, same exposure). Same pipeline as
dump_sn2_ppm.py: OF pair, head, rule_rel (+ rel_t across pairs at the same k), ONESIDE, online vignette (quad3 +
clamp; no vignette -> stays ~1). MV chain over N hops with border padding. Colour: a fixed display look (aces, sRGB,
8-bit, exposure from A as in training). Not used in training (data_v2 ROOTS: spring, lyra, forest).
  [MFG=N] [VIGNETTE=online] [SAVE=<ppm prefix>] python eval_nfru_mfg.py <nfru safetensors> <OF ckpt> <head ckpt>"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import TONE_CURVES, srgb_encode, quantize, depth_feature, _warp_border
from nfru_head import load_head_c2, invert_t, off_frame
from selector import rule_rel, luma

fn, ck, hk = sys.argv[1:4]
NM = int(os.environ.get("MFG", "2"))
MV_DIRECT = os.environ.get("MV_DIRECT") == "1"                                                            
OFONLY = os.environ.get("OFONLY") == "1"                                                            
TRAIL_A = os.environ.get("TRAIL_A") in ("1", "cam", "camq") and not OFONLY
TRAIL_CAM = os.environ.get("TRAIL_A") in ("cam", "camq")                                                                                                           
TRAIL_HOMOG_AUTO = float(os.environ.get("TRAIL_HOMOG_AUTO", "0"))                                                             
homog_log = []
TRAIL_HOMOG = int(os.environ.get("TRAIL_HOMOG", "0"))                                                                                           
TRAIL_CAMQ = os.environ.get("TRAIL_A") == "camq"                                                               
dev = "cuda"
s = safe_open(fn, "pt")
UPSCALE = int(os.environ.get("UPSCALE", "1"))                                                                          
if UPSCALE > 1:                                                                                                          
    class _Up:
        def __init__(self, sl): self.sl = sl
        def get_shape(self): sh = list(self.sl.get_shape()); sh[-2] *= UPSCALE; sh[-1] *= UPSCALE; return sh
        def __getitem__(self, i):
            return F.interpolate(self.sl[i].float(), scale_factor=UPSCALE, mode="bilinear", align_corners=False)
    class _S:
        def __init__(self, s_): self.s_ = s_
        def get_slice(self, k): return _Up(self.s_.get_slice(k)) if k == "rgb_linear" else self.s_.get_slice(k)
        def __getattr__(self, k): return getattr(self.s_, k)
    s = _S(s)
OF_CAP = int(os.environ.get("OF_CAP", "1"))                                                                              
_fd = os.open(fn, os.O_RDONLY)
drop_cache = lambda: os.posix_fadvise(_fd, 0, 0, os.POSIX_FADV_DONTNEED)                                          
                                                                                                                   
T = s.get_slice("rgb_linear").get_shape()[0]
OFF = 0                                                                                                  
if os.environ.get("FRAMES"):
    OFF, _b = (int(x) for x in os.environ["FRAMES"].split(":")); T = _b - OFF
H, W = s.get_slice("rgb_linear").get_shape()[-2:]
h, w = s.get_slice("depth").get_shape()[-2:]
PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
zn = s.get_tensor("NearPlane").float()
lin = lambda i: s.get_slice("rgb_linear")[OFF + i:OFF + i + 1].float()
mv1 = lambda i: F.interpolate(s.get_slice("mv_{}_f60_m1")[OFF + i:OFF + i + 1].float().flip(1) * (H / h), size=(H, W), mode="bilinear", align_corners=False)
VPm = s.get_tensor("ViewProj").double()                                                                                
yy_, xx_ = torch.meshgrid(torch.arange(H, dtype=torch.float64), torch.arange(W, dtype=torch.float64), indexing="ij")


def cam_flow_vp(ia, vp_t):
    """cam_flow_t with an explicit (transposed-file convention) ViewProj at the target time."""
    d = F.interpolate(s.get_slice("depth")[OFF + ia:OFF + ia + 1].float(), size=(H, W), mode="nearest")[0, 0].double()
    nx = (xx_ + 0.5) / W * 2 - 1; ny = -((yy_ + 0.5) / H * 2 - 1)
    clip = torch.stack((nx, ny, 1 - d, torch.ones_like(d)), -1)
    c = (clip @ torch.linalg.inv(VPm[OFF + ia].T)) @ vp_t
    p = c[..., :2] / c[..., 3:4]
    px = (p[..., 0] + 1) / 2 * W - 0.5; py = (-p[..., 1] + 1) / 2 * H - 0.5
    return torch.stack((px - xx_, py - yy_), 0)[None].float()


def cam_flow_t(ia, ib, t_):
    """For every A pixel: its offset at time t (static content), clip coordinates interpolated between A and B (exact
    for a camera whose ViewProj moves linearly; the frame at t is never known in a game). (1,2,H,W) px."""
    d = F.interpolate(s.get_slice("depth")[OFF + ia:OFF + ia + 1].float(), size=(H, W), mode="nearest")[0, 0].double()
    nx = (xx_ + 0.5) / W * 2 - 1; ny = -((yy_ + 0.5) / H * 2 - 1)
    clip = torch.stack((nx, ny, 1 - d, torch.ones_like(d)), -1)
    world = clip @ torch.linalg.inv(VPm[OFF + ia].T)
    c = world @ ((1 - t_) * VPm[OFF + ia].T + t_ * VPm[OFF + ib].T)
    p = c[..., :2] / c[..., 3:4]
    px = (p[..., 0] + 1) / 2 * W - 0.5; py = (-p[..., 1] + 1) / 2 * H - 0.5
    return torch.stack((px - xx_, py - yy_), 0)[None].float()


dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[OFF + i:OFF + i + 1].float(), zn[OFF + i]), size=(H, W), mode="bilinear", align_corners=False)


def display(x, ref):
    lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
    e = 0.18 / torch.exp(torch.log(lum(ref)).mean())
    return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * e).clamp(0, 1)), 8)


sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
for _part in [p for p in os.environ.get("OF_ABLATE", "").split(",") if p]:                                                      
    assert hasattr(m.pair, _part), _part
    setattr(m.pair, _part, False)
    print(f"OF ablation: {_part} off", flush=True)
head = load_head_c2(hk, dev); head.talign = "fp"
QUANT = os.environ.get("QUANT")                                                                               
wraps = []
if QUANT:
    import json
    from quant_ptq import fold_bn, quantize as qz
    nb = fold_bn(head)
    w_of, w_hd = qz(m, QUANT), qz(head, QUANT)
    wraps = w_of + w_hd
    names = [f"of.{w_.name}" for w_ in w_of] + [f"head.{w_.name}" for w_ in w_hd]
    if os.environ.get("QCALIB_OUT"):                                                                            
        for w_ in wraps:
            w_.calib = True
    else:
        st = json.load(open(os.environ["QSTATS"]))
        for n_, w_ in zip(names, wraps):
            w_.stat = st[n_]
    print(f"quant {QUANT}: {len(wraps)} layers wrapped, {nb} BN folded", flush=True)
MAX_PAIRS = int(os.environ.get("MAX_PAIRS", "100000"))
GRAPH_STORE = os.environ.get("GRAPH_STORE")                                                                            
if GRAPH_STORE:                                                                                                       
    import json as _json
    import mlof2_graph as MG
    _qs = _json.load(open(os.environ["QSTATS"]))
    _QF = os.environ.get("GRAPH_QUANT", "int8")                                                                           
    _ge, _gp = MG.build_enc_graph(m), MG.build_pair_graph(m)
    _plan_e = MG.storage_plan(_ge, _qs, GRAPH_STORE) if GRAPH_STORE != "none" else {}
    _plan_p = MG.storage_plan(_gp, _qs, GRAPH_STORE) if GRAPH_STORE != "none" else {}
    if GRAPH_STORE.startswith("v2_"):                                                              
        _qs_e, _qs_p = MG.storage_conv_stats(_ge, _plan_e, _qs), MG.storage_conv_stats(_gp, _plan_p, _qs)
        _grp = sorted({round(v[1], 5) for v in _plan_p.values() if v[1] is not None})
        _chg = sum(abs(_qs_p[o["q"]] - _qs[o["q"]]) > 1e-9 for o in _gp.ops if o["kind"] == "conv")
        print(f"v2: pair {len(_grp)} scale groups, {_chg} convs got a larger input scale", flush=True)
    else:
        _qs_e = _qs_p = _qs
    print(f"graph OF, storage {GRAPH_STORE}: enc {sum(v[0] == 'int8' for v in _plan_e.values())} int8 / "
          f"{sum(v[0] == 'fp16' for v in _plan_e.values())} fp16, pair {sum(v[0] == 'int8' for v in _plan_p.values())} int8 / "
          f"{sum(v[0] == 'fp16' for v in _plan_p.values())} fp16 tensors", flush=True)


def graph_of(ca, da, cb, db):
    Hp, Wp = ca.shape[-2:]
    fe = [MG.Executor(_ge, Hp, Wp, quant=(_qs_e, _QF), store=_plan_e).run({"col": c_, "dep": d_}) for c_, d_ in ((cb, db), (ca, da))]
    q = {f"q{lv}": torch.cat((fe[0][f"f{lv}"], fe[1][f"f{lv}"]), 0) for lv in MG.ENC_LEVELS}
    c4 = torch.cat((fe[0]["c4"], fe[1]["c4"]), 0)
    po = MG.Executor(_gp, Hp, Wp, quant=(_qs_p, _QF), store=_plan_p).run({"c4": c4, **q})
    co = po["conf_occ"]
    of_ = po["of4"] if "of4" in po else po["of_full"]                                               
    return {"of_ba": of_[:1], "conf": co[:, :1], "occ": co[:, 1:2]}
ORACLE = os.environ.get("ORACLE") == "1"                                                                            
orc = {}


def oracle_band(hc, col, cand_a, VIG, ca_h, g, lead, trail, f, k):
    """Band pixels: the current output vs (a) the best existing candidate per pixel / per 8x8 block (what a selection
    net could reach at most), (b) A pulled by the TRUE t->A motion (the capture's own MV of the frame at t, chained to
    A): the content is in A and only the flow is wrong, vs (c) that true source off the frame too (nothing to copy)."""
    sc = (lambda x: x * VIG) if VIG is not None else (lambda x: x)
    acc = mv1(f - NM + k)                                                                                
    for j in range(1, k):
        acc = acc + _warp_border(mv1(f - NM + k - j), acc)
    acc = pad(acc).to(dev)
    gt_a = sc(warp(ca_h, acc))
    gt_off = off_frame(acc)
    cands = [sc(hc["cand"][:, i]) for i in range(4)] + ([sc(cand_a)] if cand_a is not None else [])
    lg = luma(g)[0, 0]
    el = lambda o: (luma(o.clamp(0, 1)[..., :H, :])[0, 0] - lg).abs() * 255
    e_cur, e_gt = el(col), el(gt_a)                                                       
    ia, it, ib = f - NM, f - NM + k, f
    def cam_cand(vp_t):                                                                                                  
        dt_ = pad(cam_flow_vp(ia, vp_t)).to(dev)
        _, to_, _ = invert_t(dt_, da, torch.zeros(1, device=dev))                                                          
        return to_
    to_true = cam_cand(VPm[OFF + it].T)                                                                              
    tt = k / NM
    if ia - NM >= 0:                                                                               
        vq = (VPm[OFF + ia - NM].T * (tt * (tt - 1) / 2) + VPm[OFF + ia].T * ((1 - tt) * (1 + tt)) + VPm[OFF + ib].T * (tt * (tt + 1) / 2))
    else:
        vq = VPm[OFF + ia].T * (1 - tt) + VPm[OFF + ib].T * tt
    to_quad = cam_cand(vq)
    e_ct, e_cq = el(sc(warp(ca_h, to_true))), el(sc(warp(ca_h, to_quad)))
    flow_err = lambda to_: (to_ - acc).norm(dim=1)[0, :H]
    E = torch.stack([el(c) for c in cands], 0)
    e_px = E.min(0).values
    for rn, rm in (("lead", lead[0, 0, :H]), ("trail", trail[0, 0, :H])):
        if not rm.any():
            continue
        mk = rm.float()[None, None]
        pool = lambda x: F.avg_pool2d(x * mk, 8, 8) / F.avg_pool2d(mk, 8, 8).clamp_min(1e-6)
        pick = pool(E[:, None]).argmin(0, keepdim=True)                                            
        pick = F.interpolate(pick.float(), scale_factor=8, mode="nearest")[0, 0].long()
        e_blk = E.gather(0, pick[None])[0]
        n_ = float(rm.sum())
        d = orc.setdefault(rn, {"n": 0.0, "cur": 0.0, "px": 0.0, "blk": 0.0, "gt": 0.0, "gt_in": 0.0, "n_in": 0.0,
                                "gt_or_cur": 0.0, "off": 0.0, "cam_true": 0.0, "cam_quad": 0.0, "fe_true": [], "fe_quad": []})
        d["cam_true"] += float(e_ct[rm].sum()); d["cam_quad"] += float(e_cq[rm].sum())
        d["fe_true"].append(flow_err(to_true)[rm].cpu()); d["fe_quad"].append(flow_err(to_quad)[rm].cpu())
        d["n"] += n_; d["cur"] += float(e_cur[rm].sum()); d["px"] += float(e_px[rm].sum()); d["blk"] += float(e_blk[rm].sum())
        d["gt"] += float(e_gt[rm].sum())
        inn = rm & (gt_off[0, 0, :H] < 0.5)
        d["gt_in"] += float(e_gt[inn].sum()); d["n_in"] += float(inn.sum()); d["off"] += float((rm & ~inn).sum())
        d["gt_or_cur"] += float(torch.where(gt_off[0, 0, :H] < 0.5, e_gt, e_cur)[rm].sum())

VIG_ON = None
if os.environ.get("VIGNETTE") == "online":
    from vignette_online import VignetteOnline
    VIG_ON = VignetteOnline(quad4=True, tie_y=True)
torch.manual_seed(0)
prev, prev_mask = None, {}
err = {"ours": {}, "blend": {}}
err_in = {"ours": {}, "blend": {}}
shp = {"ours": {}, "blend": {}}
vig_log = []
GEN_EXEC = os.environ.get("GEN_EXEC")                                                                                  
GEN_REF = os.environ.get("GEN_REF") == "1" or bool(GEN_EXEC)                                                      
if GEN_EXEC:                                                                                                         
    import copy as _copy, json as _json2
    import mlof2_gen_lower as GL
    from quant_ptq import fold_bn as _fold
    _hf = _copy.deepcopy(head); _fold(_hf)
    _st_num = int(os.environ.get("GEN_STRUCTURE", "2"))
    _gg = GL.build_gen_graph(_hf, structure=_st_num)
    _gqf = os.environ.get("GRAPH_QUANT", "int8")
    _gqs = _json2.load(open(os.environ["QSTATS"]))
    _gstore = None
    if GEN_EXEC == "v2":
        from export_mlof2_engine import v2_formats, FMT_NAME
        _st, _gqs = v2_formats(_gg, _gqs, _gqf)
        _gstore = {t: (FMT_NAME[f_[0]], f_[2]) for t, f_ in _st.items() if f_[0] != 0}
    _use_split = (_st_num == 4) and (NM == 4 or os.environ.get("GEN_SPLIT") == "1")
    if _use_split:
        _gg_prep = GL.build_gen_prep_graph(_hf)
        _gg_t = GL.build_gen_t_graph(_hf)
        _gstore_prep = {t: _gstore[t] for t in _gg_prep.tensors if _gstore and t in _gstore} if _gstore else None
        _gstore_t = {t: _gstore[t] for t in _gg_t.tensors if _gstore and t in _gstore} if _gstore else None
        _gen_prep_out = None
    gen_vig = None
    print(f"generation: lowered graph (split={_use_split}), head {_gqf}, storage {GEN_EXEC}", flush=True)
gen_vstate, gen_pm, gen_lv = {}, {}, None
reg = {"ours": {}, "blend": {}}
fr_use = []
def grad_m(l, rm):                                                                                    
    gx = (l[:, 2:] - l[:, :-2]).abs()[1:-1, :]; gy = (l[2:, :] - l[:-2, :]).abs()[:, 1:-1]
    r = rm[1:-1, 1:-1]
    return float((gx + gy)[r].mean()) if r.any() else float("nan")
dshp = {"ours": [], "blend": []}
grad = lambda l: (l[..., :, 2:] - l[..., :, :-2]).abs()[..., 1:-1, :].mean() + (l[..., 2:, :] - l[..., :-2, :]).abs()[..., :, 1:-1].mean()
with torch.no_grad():
    for f in range(NM, T, NM):
        if f // NM > MAX_PAIRS:
            break
        la = lin(f - NM)
                                                                                                                   
                                                                                  
        SELF_EXPO = os.environ.get("SELF_EXPO") == "1"
        ca, cb = pad(display(la, la)).to(dev), pad(display(lin(f), lin(f) if SELF_EXPO else la)).to(dev)
        da, db = pad(dfeat(f - NM)).to(dev), pad(dfeat(f)).to(dev)
        if MV_DIRECT:                                                                                                
            acc = F.interpolate(s.get_slice("mv_{}_f30_m1")[OFF + f:OFF + f + 1].float().flip(1) * (H / h), size=(H, W), mode="bilinear", align_corners=False)
        else:
            acc = mv1(f)                                                                                       
            for j in range(1, NM):
                acc = acc + _warp_border(mv1(f - j), acc)
        mv = pad(acc).to(dev); mvv = torch.ones_like(mv[:, :1])
        drop = None
        if os.environ.get("MV_DROP"):                                                                          
            cam = pad(cam_flow_vp(f, VPm[OFF + f - NM].T)).to(dev)                                                 
            drop = ((mv - cam).norm(dim=1, keepdim=True) > float(os.environ["MV_DROP"])).float()
            mv = torch.where(drop > 0.5, cam, mv)
            drop_reg = F.max_pool2d(drop, 33, 1, 16)[0, 0, :H] > 0.5                                       
        if VIG_ON is not None:
            VIG_ON.update(ca, cb, mv, mvv)
            VIG = VIG_ON.map(*ca.shape[-2:]); vig_log.append([round(float(np.exp(v)), 3) for v in VIG_ON.lv.tolist()])
            ca_h, cb_h = ca / VIG, cb / VIG
        else:
            VIG, ca_h, cb_h = None, ca, cb
        if OF_CAP > 1 and not GRAPH_STORE:                                                                                   
            dn = lambda x: F.avg_pool2d(x, OF_CAP)
            pair = m.pair(m.enc(dn(ca), dn(da)), m.enc(dn(cb), dn(db)), dn(mv) / OF_CAP, dn(mvv), dn(ca), dn(cb))
            for k_ in ("conf", "occ"):
                pair[k_] = F.interpolate(pair[k_], scale_factor=OF_CAP, mode="bilinear", align_corners=False)
            pair["of_ba_full"] = None
        else:
            pair = graph_of(ca, da, cb, db) if GRAPH_STORE else m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        if of_q.shape[-2:] != ca.shape[-2:]:                                                                  
            from nfru_head import up4
            of_q = up4(of_q, *ca.shape[-2:])
        pm, po, pv = prev if prev is not None else (None, None, None)
        for k in range(1, NM):
            t_ = k / NM
            hc = head(torch.tensor([t_], device=dev), of_q, ca_h, cb_h, da, db, mv * mvv, pm, po, mvv, pv,
                      conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
            to_prev = None
            if prev_mask.get(k) is not None and pm is not None:
                ma = hc["tflows"][0]
                to_prev = ma + (1 - t_) * warp(pm, ma)
            hc["t"] = t_
            col, mk = rule_rel(hc, prev=prev_mask[k] if to_prev is not None else None, to_prev=to_prev)
            prev_mask[k] = mk
            if OFONLY:                                                                                                
                w2 = hc["weights"][:, 2:4]
                w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
                col = (w2[:, :, None] * hc["cand"][:, 2:4]).sum(1)
            lead = (hc["off_mv"][0] > 0.5) & (hc["off_mv"][1] < 0.5)                                            
            trail = hc["off_mv"][1] > 0.5                                                                          
            cand_a = None
            if TRAIL_A and (pm is not None or TRAIL_CAM):
                                                                                                                      
                                                                                                           
                if TRAIL_CAM:                                                                                         
                    if TRAIL_CAMQ and f - 2 * NM >= 0:                                                             
                        vq = (VPm[OFF + f - 2 * NM].T * (t_ * (t_ - 1) / 2) + VPm[OFF + f - NM].T * ((1 - t_) * (1 + t_))
                              + VPm[OFF + f].T * (t_ * (t_ + 1) / 2))
                        dt_ = pad(cam_flow_vp(f - NM, vq)).to(dev)
                    else:
                        dt_ = pad(cam_flow_t(f - NM, f, t_)).to(dev)
                    _, to_a2, hole_a2 = invert_t(dt_, da, torch.zeros(1, device=dev))
                else:
                    _, to_a2, hole_a2 = invert_t(-pm, da, torch.tensor([1 - t_], device=dev))
                ok2 = (hole_a2 < 0.5) & (off_frame(to_a2) < 0.5)
                if TRAIL_HOMOG:                                                                                      
                    import homog_fill as HF
                    ring = HF.ring_outside(trail, TRAIL_HOMOG) & (hc["holes"][0] < 0.5) & (off_frame(hc["tflows"][0]) < 0.5)
                    if os.environ.get("TRAIL_HOMOG_VM") == "1":
                        ring &= (da >= 0.21) & (warp(da, hc["tflows"][0]) >= 0.21)
                    ring[..., H:, :] = False
                    th = HF.fit_homog_flow(hc["tflows"][0], ring)
                    if th is not None and TRAIL_HOMOG_AUTO > 0:                                                
                        dis = HF.camera_disagreement(to_a2, hc["tflows"][0], ring)
                        homog_log.append(dis)
                        if dis is not None and dis <= TRAIL_HOMOG_AUTO:
                            th = None
                    if th is not None:
                        to_a2 = th
                        ok2 = off_frame(to_a2) < 0.5
                        if os.environ.get("TRAIL_HOMOG_VM") == "1":
                            ok2 &= warp(da, to_a2) >= 0.21
                cand_a = warp(ca_h, to_a2)
                use = trail & ok2
                col = torch.where(use, cand_a, col)
                fr_use.append(float(use[0, 0, :H].float().mean()))
            if GEN_REF:                                                                                         
                import mlof2_gen_graph as GG
                if k == 1:
                    gen_lv = GG.vig_update(gen_vstate, GG.vig_sums(ca, cb, mv, mvv))
                dA = F.interpolate(s.get_slice("depth")[OFF + f - NM:OFF + f - NM + 1].float(), size=(H, W), mode="nearest")
                vpa = VPm[OFF + f - NM].T.float().to(dev); vpb = VPm[OFF + f].T.float().to(dev)
                if TRAIL_CAMQ and f - 2 * NM >= 0:                                                                      
                    vpb = GG.vp_b_for_quadratic(VPm[OFF + f - 2 * NM].T, VPm[OFF + f - NM].T, VPm[OFF + f].T, t_).float().to(dev)
                inp = {"col_a": ca, "col_b": cb, "dep_a": da, "dep_b": db, "ndc_a": pad(1 - dA).to(dev), "mv": mv, "mvv": mvv,
                       "mv_ap": pm, "of": of_q, "of_prev": po, "co": torch.cat((pair["conf"][:1], pair["occ"][:1]), 1),
                       "pmask": gen_pm.get(k)}
                if GEN_EXEC:
                    hp_ = pm is not None and gen_pm.get(k) is not None
                    z2 = torch.zeros_like(mv)
                    fcd = {"t": t_, "has_prev": hp_, "pair_first": k == 1, "vp_a": vpa, "vp_b": vpb, "inv_vp_a": torch.linalg.inv(vpa)}
                    gi = {**inp, "mv_ap": pm if pm is not None else z2, "of_prev": po if po is not None else z2,
                          "pmask": gen_pm[k] if hp_ else torch.zeros(1, 1, ca.shape[-2] // _gg.tensors["pmask"]["s"], ca.shape[-1] // _gg.tensors["pmask"]["s"], device=dev),
                          "vig": gen_vig if gen_vig is not None else torch.zeros(1, 16, ca.shape[-2] // 64, ca.shape[-1] // 64, device=dev)}
                    if GL.GEN_LANES:                                                                                       
                        gi.update({n_: gi[n_][..., 1::4, 1::4] for n_ in ("dep_a", "dep_b", "ndc_a")})
                        gi.update({n_: gi[n_][..., 1::2, 1::2] for n_ in ("mv", "mvv")})
                    if _use_split:
                        if k == 1:
                            _gen_prep_out = GL.GenExecutor(_gg_prep, *ca.shape[-2:], fcd, dev, quant=(_gqs, _gqf), store=_gstore_prep).run(gi)
                            gen_vig = _gen_prep_out["vig"].clone()
                        gi_t = {**gi, **_gen_prep_out, "vig": gen_vig}
                        go = GL.GenExecutor(_gg_t, *ca.shape[-2:], fcd, dev, quant=(_gqs, _gqf), store=_gstore_t).run(gi_t)
                        col, gen_pm[k] = go["out"], go["pmask"].clone()
                    else:
                        go = GL.GenExecutor(_gg, *ca.shape[-2:], fcd, dev, quant=(_gqs, _gqf), store=_gstore).run(gi)
                        col, gen_pm[k], gen_vig = go["out"], go["pmask"].clone(), go["vig"].clone()
                elif os.environ.get("GEN_HALF") is not None:                                           
                    import gen_half as GH
                    col, gen_pm[k] = GH.gen_half(head, inp, t_, pm is not None and gen_pm.get(k) is not None, gen_lv,
                                                 (vpa, vpb, torch.linalg.inv(vpa)), set(os.environ["GEN_HALF"].split(",")) - {""})
                else:
                    col, gen_pm[k] = GG.gen_reference(head, inp, t_, pm is not None and gen_pm.get(k) is not None, gen_lv,
                                                      (vpa, vpb, torch.linalg.inv(vpa)))
            elif VIG is not None:
                col = col * VIG
            g = display(lin(f - NM + k), lin(f - NM + k) if SELF_EXPO else la).to(dev)
            if ORACLE:
                oracle_band(hc, col, cand_a, VIG, ca_h, g, lead, trail, f, k)
            band = (F.max_pool2d(((hc["off_mv"][0] + hc["off_mv"][1]) > 0.5).float(), 33, 1, 16)[0, 0, :H] > 0.5)
            lg = luma(g)[0, 0]
            for nm, o in (("ours", col[..., :H, :].clamp(0, 1)), ("blend", ca[..., :H, :] * (1 - t_) + cb[..., :H, :] * t_)):
                e = (luma(o)[0, 0] - lg).abs() * 255
                err[nm].setdefault(k, []).append(float(e.mean()))
                err_in[nm].setdefault(k, []).append(float(e[~band].mean()) if (~band).any() else np.nan)
                regs = [("lead", lead[0, 0, :H]), ("trail", trail[0, 0, :H])]
                if drop is not None:
                    regs.append(("drop", drop_reg))
                    dshp[nm].append(
                        float(grad_m(luma(o)[0, 0], drop_reg) / max(grad_m(lg, drop_reg), 1e-6)))
                for rn, rm in regs:
                    reg[nm].setdefault(rn, []).append((float(e[rm].sum()), float(rm.sum())))
                shp[nm].setdefault(k, []).append(float(grad(luma(o)[0, 0]) / grad(lg)))
            if os.environ.get("SAVE"):
                img = (col[0, :, :H].clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
                with open(f"{os.environ['SAVE']}_{f:03d}_{k}.ppm", "wb") as fh:
                    fh.write(f"P6\n{W} {H}\n255\n".encode()); fh.write(img.tobytes())
                if os.environ.get("SAVE_GT") == "1":                                                      
                    gi = (g[0, :, :H].clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
                    with open(f"{os.environ['SAVE']}_gt_{f:03d}_{k}.ppm", "wb") as fh:
                        fh.write(f"P6\n{W} {H}\n255\n".encode()); fh.write(gi.tobytes())
        prev = (mv * mvv, of_q, mvv)
        drop_cache()
        print(f"pair B={f:3d}: " + " ".join(f"t={k}/{NM} ours {err['ours'][k][-1]:6.2f} blend {err['blend'][k][-1]:6.2f}" for k in range(1, NM)), flush=True)
if QUANT and os.environ.get("QCALIB_OUT"):
    json.dump({n_: w_.stat for n_, w_ in zip(names, wraps)}, open(os.environ["QCALIB_OUT"], "w"), indent=0)
    print("wrote", os.environ["QCALIB_OUT"]); sys.exit(0)
mvmag = []
for f in range(NM, min(T, (MAX_PAIRS + 1) * NM), NM):
    acc = mv1(f)
    for j in range(1, NM):
        acc = acc + _warp_border(mv1(f - j), acc)
    mvmag.append(float(acc.norm(dim=1).median()))
print(f"{os.path.basename(fn)}[{OFF}:{OFF + T}]: MFG {NM}x, {len(err['ours'][1])} pairs, {T} frames at 60 FPS (base {60 / NM:.0f} FPS), "
      f"median |MV B->A| {np.median(mvmag):.1f} px (1080p)" + (f", vignette L/R/(T/B) last {vig_log[-1]}" if vig_log else ""))
print("mean |luma error| vs the rendered frame (8-bit) | outside the off-frame band | sharpness (1 = real)")
if dshp["ours"]:
    print("  MV_DROP region sharpness (1 = real): " + " | ".join(f"{n_} {np.nanmean(v_):.3f}" for n_, v_ in dshp.items()))
import selector as _sel
if _sel.BOTHFAIL_LOG:
    print(f"  BOTHFAIL mask mean {100 * np.mean(_sel.BOTHFAIL_LOG):.2f}% of px")
for nm in ("ours", "blend"):
    cells = " | ".join(f"t={k}/{NM} {np.mean(err[nm][k]):6.2f} {np.nanmean(err_in[nm][k]):6.2f} {np.mean(shp[nm][k]):5.3f}" for k in sorted(err[nm]))
    allk = np.mean([x for k in err[nm] for x in err[nm][k]]); alli = np.nanmean([x for k in err_in[nm] for x in err_in[nm][k]])
    print(f"  {nm:6s} all {allk:6.2f} {alli:6.2f} | {cells}")
for nm in ("ours", "blend"):
    print(f"  {nm:6s} band split: " + " | ".join(f"{rn} {sum(a for a, _ in v) / max(sum(b for _, b in v), 1):6.2f} ({100 * sum(b for _, b in v) / (len(v) * H * W):4.1f}% of px)" for rn, v in reg[nm].items()))
if homog_log:
    _hv = [v for v in homog_log if v is not None]
    print(f"  camera vs MV on the band ring: median {np.median(_hv):.2f} px, max {max(_hv):.2f}, homography used on {sum(v > TRAIL_HOMOG_AUTO for v in _hv)}/{len(_hv)} frames")
if fr_use:
    print(f"  trailing A-grid candidate used on {100 * np.mean(fr_use):.1f}% of px")
for rn, d in orc.items():
    n_ = max(d["n"], 1)
    print(f"  ORACLE {rn:5s} ({100 * d['n'] / (len(err['ours'][1]) * (NM - 1) * H * W):4.1f}% px): now {d['cur'] / n_:6.2f} | best candidate per px "
          f"{d['px'] / n_:6.2f} per 8x8 {d['blk'] / n_:6.2f} | A by TRUE t->A motion {d['gt'] / n_:6.2f} "
          f"(source in A: {d['gt_in'] / max(d['n_in'], 1):6.2f} on {100 * d['n_in'] / n_:4.1f}% | true source off-frame "
          f"{100 * d['off'] / n_:4.1f}%) | true A where it exists, else now {d['gt_or_cur'] / n_:6.2f}")
    fq = lambda v: (lambda x: x[::max(1, x.numel() // 4000000)].quantile(torch.tensor([0.5, 0.9])).tolist())(torch.cat(v).float()) if v else [float('nan')] * 2
    print(f"         camera at t TRUE {d['cam_true'] / n_:6.2f} (|flow - true| p50/p90 {fq(d['fe_true'])[0]:5.1f}/{fq(d['fe_true'])[1]:5.1f} px) | "
          f"quadratic P,A,B {d['cam_quad'] / n_:6.2f} ({fq(d['fe_quad'])[0]:5.1f}/{fq(d['fe_quad'])[1]:5.1f} px)")
