"""Write a model's SN2 skip-frame outputs (frame f-1 generated at t = 0.5 from f-2 and f) as <prefix>_<f:03d>_1.ppm,
the naming of the replay harness (k_fsr4_..., root_sn2.py), so FSR4 and our models are scored by the same code.
  python dump_sn2_ppm.py <capture dir> <out prefix> <OF ckpt> <head ckpt> <talign splat|fp|kpn> [kpn ckpt]"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import NfruHeadC2, load_head_c2

cap, pre, ck, hk, ta = sys.argv[1:6]
kck = sys.argv[6] if len(sys.argv) > 6 else ""
dev = "cuda"
DW, DH, RW, RH, RP, PH = 1920, 1080, 1129, 636, 1132, 1088
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))


def colour(fr):
    a = np.fromfile(os.path.join(cap, f"{fr:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    return torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0)


def depth(fr):
    d = np.fromfile(os.path.join(cap, f"{fr:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
    d = torch.from_numpy(d.copy()).clamp_min(1e-7)
    return F.interpolate(((torch.log2(1.0 / d) / 16.0).clamp(0, 1))[None, None], size=(DH, DW), mode="bilinear", align_corners=False)[0]


MFIT = {}                                                                                                         
if os.path.exists(os.path.join(cap, "meta_fit.txt")):
    for line in open(os.path.join(cap, "meta_fit.txt")):
        p = line.split()
        if len(p) > 2 and p[2] == "viewProjection":
            MFIT[int(p[1])] = np.array([float(x) for x in p[3:19]]).reshape(4, 4).T                                          


def cam_offset(fa, fb, t, d_raw, fp=None):
    """For every pixel of frame fa (raw reverse-Z depth d_raw, display grid, padded): its offset (display px) at time t
    between fa (t = 0) and fb (t = 1), static content, clip coordinates lerped (diag_traj_camera.py convention).
    fp: the previous real frame (-1): quadratic through fp, fa, fb instead (TRAIL_CAMQ, eval_nfru_mfg TRAIL_A=camq)."""
    Ma = torch.tensor(MFIT[fa], device=d_raw.device, dtype=torch.float64)
    if fp is not None and fp in MFIT:
        Mt = torch.tensor(MFIT[fp] * (t * (t - 1) / 2) + MFIT[fa] * ((1 - t) * (1 + t)) + MFIT[fb] * (t * (t + 1) / 2),
                          device=d_raw.device, dtype=torch.float64)
    else:
        Mt = torch.tensor((1 - t) * MFIT[fa] + t * MFIT[fb], device=d_raw.device, dtype=torch.float64)
    Hh, Ww = d_raw.shape[-2:]
    yy, xx = torch.meshgrid(torch.arange(Hh, device=d_raw.device, dtype=torch.float64), torch.arange(Ww, device=d_raw.device, dtype=torch.float64), indexing="ij")
    nx = (xx + 0.5) / DW * 2 - 1; ny = 1 - (yy + 0.5) / DH * 2
    clip = torch.stack((nx, ny, d_raw[0, 0].double(), torch.ones_like(nx)), 0).view(4, -1)
    c = Mt @ torch.linalg.solve(Ma, clip)
    px = ((c[0] / c[3] + 1) / 2 * DW - 0.5).view(Hh, Ww); py = ((1 - c[1] / c[3]) / 2 * DH - 0.5).view(Hh, Ww)
    return torch.stack((px - xx, py - yy), 0)[None].float()


def mv_one(fr):
    m = np.fromfile(os.path.join(cap, f"{fr:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < 1000)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m)) * torch.tensor(meta[fr]).view(2, 1, 1) * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    up = "nearest" if os.environ.get("MV_POINT") in ("1", "up") else "bilinear"                                                  
    return F.interpolate(m[None], size=(DH, DW), mode=up, **({} if up == "nearest" else {"align_corners": False}))[0], F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0]


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
RULEF = []
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
for _part in [p_ for p_ in os.environ.get("OF_ABLATE", "").split(",") if p_]:                                             
    assert hasattr(m.pair, _part), _part
    setattr(m.pair, _part, False)
head = load_head_c2(hk, dev)
head.hole_b = os.environ.get("HOLE_B") == "1"                                                    
head.talign = ta
if ta == "kpn":
    from talign_kpn import TAlignKPN
    if os.environ.get("TALIGN_ARCH") == "net":
        from talign_net import TAlignNet as TAlignKPN
    head.talign_net = TAlignKPN().to(dev).eval()
    if kck:
        head.talign_net.load_state_dict(torch.load(kck, map_location=dev))
    head.talign_net.refine_iters = int(os.environ.get("TNET_REFINE", "0"))                                            
prev = None
prev_mask = {}
NM = int(os.environ.get("MFG", "2"))                                                            
VIG = None                                                                                                          
VIG_ON = VIG_REF = None                                                                                                    
vlog = []
if os.environ.get("VIGNETTE") == "online":
    from vignette_online import VignetteOnline
    VIG_ON = VignetteOnline(decay=float(os.environ.get("VIG_DECAY", "0.85")), quad4=os.environ.get("VIG_MODEL") in ("quad4", "quad3"),
                           tie_y=os.environ.get("VIG_MODEL") == "quad3",
                           clamp=os.environ.get("VIG_CLAMP", "1") == "1", ridge=float(os.environ.get("VIG_RIDGE", "0")),
                           pw=float(os.environ.get("VIG_PW", "2")))
    if os.environ.get("VIG_REF"):
        VIG_REF = pad(torch.from_numpy(np.load(os.environ["VIG_REF"]))[None]).to(dev)[None]
elif os.environ.get("VIGNETTE"):
    VIG = pad(torch.from_numpy(np.load(os.environ["VIGNETTE"]))[None]).to(dev)[None]

def fit_homog_flow(flow, ring, sc=1000.0):
    """Homography x -> x + flow fitted (IRLS) on the ring pixels; returns the full-grid flow (1,2,H,W) or None."""
    ys, xs = torch.nonzero(ring[0, 0], as_tuple=True)
    if ys.numel() <= 2000:
        return None
    sel = torch.randperm(ys.numel(), device=flow.device)[:20000]
    ys, xs = ys[sel], xs[sel]
    fl = flow[0][:, ys, xs].double()
    X, Y = xs.double() / sc, ys.double() / sc
    U, V = X + fl[0] / sc, Y + fl[1] / sc
    o, z_ = torch.ones_like(X), torch.zeros_like(X)
    Am = torch.cat((torch.stack((X, Y, o, z_, z_, z_, -U * X, -U * Y), 1), torch.stack((z_, z_, z_, X, Y, o, -V * X, -V * Y), 1)), 0)
    bm = torch.cat((U, V)); wts = torch.ones_like(bm)
    for _ in range(4):
        hp = torch.linalg.lstsq(Am * wts[:, None], (bm * wts)[:, None]).solution[:, 0]
        res = (Am @ hp - bm).abs() * sc
        wts = torch.where(res < 3.0, torch.ones_like(res), (3.0 / res).sqrt())
    Hm = torch.cat((hp, torch.ones(1, dtype=hp.dtype, device=hp.device))).view(3, 3)
    H_, W_ = flow.shape[-2:]
    gy, gx = torch.meshgrid(torch.arange(H_, device=flow.device, dtype=torch.float64), torch.arange(W_, device=flow.device, dtype=torch.float64), indexing="ij")
    P = torch.stack((gx / sc, gy / sc, torch.ones_like(gx)), 0).view(3, -1)
    Q_ = Hm @ P; Q_ = Q_[:2] / Q_[2:]
    return (Q_.view(2, H_, W_) * sc - torch.stack((gx, gy), 0)).float()[None]

fracs = []
DIAG_F = int(os.environ["DIAG_F"]) if os.environ.get("DIAG_F") else None
T_REAL = {int(l.split()[0]): float(l.split()[1]) for l in open(os.environ["T_REAL"])} if os.environ.get("T_REAL") else None
n_fr = max(meta) + 1
with torch.no_grad():
    for f in range(NM, n_fr, NM):
        ca, cb = pad(colour(f - NM))[None].to(dev), pad(colour(f))[None].to(dev)
        da, db = pad(depth(f - NM))[None].to(dev), pad(depth(f))[None].to(dev)
        m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
        if NM > 2:                                                                                               
            from data_v2 import _warp_border
            acc, vac = m1[None], v1[None]
            for j in range(1, NM):
                mj, vj = mv_one(f - j)
                vac = vac * (_warp_border(vj[None], acc) > 0.999).float()
                acc = acc + _warp_border(mj[None], acc)
            mv, mvv = pad(acc[0])[None].to(dev), pad(vac[0])[None].to(dev)
        elif os.environ.get("MV_CHAIN", "border") == "border":                                                        
            from data_v2 import chain2_border
            if os.environ.get("MV_POINT") in ("1", "chain"):                                                             
                _, H_, W_ = m1.shape
                yy_, xx_ = torch.meshgrid(torch.arange(H_, dtype=m1.dtype), torch.arange(W_, dtype=m1.dtype), indexing="ij")
                g_ = torch.stack(((xx_ + m1[0] + 0.5) * (2.0 / W_) - 1.0, (yy_ + m1[1] + 0.5) * (2.0 / H_) - 1.0), -1)[None]
                m0w_ = F.grid_sample(m0[None], g_, mode="nearest", padding_mode="border", align_corners=False)[0]
                v0w_ = F.grid_sample(v0[None], g_, mode="nearest", padding_mode="border", align_corners=False)[0]
                mv_, mvv_ = m1 + m0w_, v1 * (v0w_ > 0.5).float()
            else:
                mv_, mvv_ = chain2_border(m1, v1, m0, v0)
            mv, mvv = pad(mv_)[None].to(dev), pad(mvv_)[None].to(dev)
        else:                                                                                                 
            mv = pad(chain_backward([m1, m0]))[None].to(dev)
            mvv = pad(v1 * (warp(v0[None], m1[None])[0] > 0.999).float())[None].to(dev)
        if VIG_ON is not None:                                                                                            
            vm_ = (da < 0.21)                                                                                                      
            nused = VIG_ON.update(ca, cb, mv, mvv, skip=vm_)
            VIG = VIG_ON.map(*ca.shape[-2:])
            if VIG_REF is not None:
                v1, v2 = VIG[0, 0, :DH], VIG_REF[0, 0, :DH]
                vlog.append((f, nused, *([round(float(np.exp(v)), 3) for v in VIG_ON.lv.tolist()] + [tuple(round(float(x)) for x in VIG_ON.info.tolist())] if VIG_ON.quad4 else []), float(v1[:, 0].mean()), float(v1[:, -1].mean()), float((v1 / v1.mean() - v2 / v2.mean()).abs().mean())))
        if VIG is not None:                                                                                              
            ca_h, cb_h = ca / VIG, cb / VIG                                                                       
            if os.environ.get("VIG_OF") == "1":
                ca, cb = ca_h, cb_h
        else:
            ca_h, cb_h = ca, cb
        pair = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        pm, po, pv = prev if prev is not None else (None, None, None)
        for k in range(1, NM):                                                                
            t_ = k / NM
            if T_REAL is not None and NM == 2:                                                                         
                t_ = T_REAL[f]
            tt = torch.tensor([t_], device=dev)
            if os.environ.get("FUSE") == "1":                                                                                        
                from selector import fuse_flow, mv_only
                of_full = of_q if of_q.shape[-2:] == ca.shape[-2:] else                 F.interpolate(of_q, size=ca.shape[-2:], mode="bilinear", align_corners=False) * (ca.shape[-1] / of_q.shape[-1])
                fused, use_of = fuse_flow(ca, cb, mv * mvv, mvv, of_full)
                ones = torch.ones_like(mvv)
                hc = head(tt, of_q, ca_h, cb_h, da, db, fused, pm, po, ones, pv, conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
                prev = (fused, of_q, ones)
                fracs.append(float(use_of[0, 0, :DH].mean()))
                hc["color"] = mv_only(hc)
            else:
                hc = head(tt, of_q, ca_h, cb_h, da, db, mv * mvv, pm, po, mvv, pv, conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
                prev = (mv * mvv, of_q, mvv)
            col = hc["color"]
            if os.environ.get("OFTFUSE"):                                                                                    
                from train_fuse import load_oft3
                from oft_fuse import FuseNet, of_frame, mv_candidates
                from lk_refine import lk_refine
                if "_OFT3" not in globals():
                    globals()["_OFT3"] = load_oft3(os.environ["OFT_CKPT"], dev)
                    fsd = torch.load(os.environ["OFTFUSE"], map_location=dev)
                    fz = FuseNet(cin=fsd["d1.weight"].shape[1]).to(dev).eval()
                    fz.load_state_dict(fsd)
                    globals()["_FZ"] = fz
                o_ = _OFT3(tt, ca, cb, pair["of_ab"], pair["of_ba"])
                fa_, fb_, _ = lk_refine(ca, cb, o_["f_ta"], o_["f_tb"], tt)
                ofc_, oa_, ob_ = of_frame(ca_h, cb_h, fa_, fb_, o_["vis"])
                mva_, mvb_, ma_, mb_, hole_, offa_, offb_ = mv_candidates(ca_h, cb_h, db, mv * mvv, mvv, tt)
                dof_ = (warp(ca_h, fa_) - warp(cb_h, fb_)).abs().mean(1, keepdim=True) * 4
                fused_, w_, cand_ = _FZ(tt, ofc_, mva_, mvb_, fa_, ma_, oa_, ob_, offa_, offb_, hole_, o_["vis"], dof_)
                if os.environ.get("FUSE_RULE"):                                                                             
                    mg_ = float(os.environ["FUSE_RULE"])
                    dd_ = lambda x, y: F.avg_pool2d((x - y).abs().mean(1, keepdim=True), 5, 1, 2)
                    d_of = dd_(warp(ca_h, fa_), warp(cb_h, fb_))
                    d_mv = dd_(mva_, mvb_)
                    use_mv = ((d_of > d_mv + mg_) & (offa_ < 0.5) & (offb_ < 0.5)).float()
                    fused_ = use_mv * 0.5 * (mva_ + mvb_) + (1 - use_mv) * fused_
                    RULEF.append(float(use_mv.mean()))
                if os.environ.get("FUSE_HARD") == "1":                                                      
                    pk_ = F.one_hot(w_.argmax(1), 3).permute(0, 3, 1, 2).float()
                    fused_ = (pk_[:, :, None] * cand_).sum(1).clamp(0, 1)
                col = ofc_ if os.environ.get("OFT_ONLY") == "1" else fused_
            if os.environ.get("HARD") == "1":                                                                                     
                pick = F.one_hot(hc["weights"].argmax(1), 4).permute(0, 3, 1, 2).float()
                col = (pick[:, :, None] * hc["cand"]).sum(1).clamp(0, 1)
            if os.environ.get("MVONLY") == "1":                                                                         
                w2 = hc["weights"][:, :2]
                w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
                col = (w2[:, :, None] * hc["cand"][:, :2]).sum(1).clamp(0, 1)
            if os.environ.get("OVER_THR"):                                                                                        
                thr, dil = float(os.environ["OVER_THR"]), int(os.environ.get("OVER_DIL", "4"))
                w2 = hc["weights"][:, :2]
                w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
                mvonly = (w2[:, :, None] * hc["cand"][:, :2]).sum(1)
                dis = (hc["cand"][:, 0] - hc["cand"][:, 1]).abs().mean(1, keepdim=True)                        
                dis = F.avg_pool2d(dis, 3, 1, 1)                                                                          
                mk = F.max_pool2d((dis > thr).float(), 2 * dil + 1, 1, dil)
                mk = F.avg_pool2d(mk, 5, 1, 2)                                                            
                col = ((1 - mk) * mvonly + mk * hc["color"]).clamp(0, 1)
                fracs.append(float((mk[0, 0, :DH] > 0.5).float().mean()))
            if os.environ.get("RULE") in ("rel", "rel_t"):                                                         
                from selector import rule_rel
                to_prev = None
                if os.environ["RULE"] == "rel_t" and prev_mask.get(k) is not None and pm is not None:
                    ma = hc["tflows"][0]                                                                                 
                    to_prev = ma + (1 - t_) * warp(pm, ma)                                                            
                col, mk = rule_rel(hc, prev=prev_mask[k] if to_prev is not None else None, to_prev=to_prev)
                prev_mask[k] = mk
                fracs.append(float((mk[0, 0, :DH] > 0.5).float().mean()))
            if os.environ.get("GHOST_BLUR"):                                                                       
                k = int(os.environ["GHOST_BLUR"])                                                                        
                w = hc["weights"]
                if os.environ.get("RULE") in ("rel", "rel_t"):                                                   
                    w2 = torch.cat((w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6), torch.zeros_like(w[:, 2:])), 1)
                    w = (1 - mk) * w2 + mk * w
                c = hc["cand"]
                dif = F.avg_pool2d((c[:, 0] - c[:, 1]).abs().mean(1, keepdim=True), 3, 1, 1)
                g = ((torch.minimum(w[:, 0:1], w[:, 1:2]) - 0.1) / 0.15).clamp(0, 1) * ((dif - 5 / 255) / (10 / 255)).clamp(0, 1)
                g = g * float(os.environ.get("GHOST_STRENGTH", "1"))
                gk = torch.tensor([[1, 2, 1]], dtype=col.dtype, device=col.device) if k == 3 else                 torch.tensor([[1, 4, 6, 4, 1]], dtype=col.dtype, device=col.device)
                gk = (gk.T @ gk); gk = (gk / gk.sum()).view(1, 1, k, k).repeat(3, 1, 1, 1)
                blur = F.conv2d(F.pad(col, (k // 2,) * 4, mode="replicate"), gk, groups=3)
                col = (1 - g) * col + g * blur
                fracs.append(float((g[0, 0, :DH] > 0.5).float().mean()))
            if os.environ.get("TRAIL_CAM") in ("1", "2"):
                                                                                                                   
                                                                                                                   
                                                                                                                
                                                                                                              
                from nfru_head import invert_t as _inv
                from mlof2_gen_graph import off_frame as _off
                ia, ib = f - NM, f
                dA_raw = pad(F.interpolate(torch.from_numpy(np.fromfile(os.path.join(cap, f"{ia:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW].copy())[None, None],
                                           size=(DH, DW), mode="nearest")[0]).to(dev)[None]
                camt = cam_offset(ia, ib, t_, dA_raw, fp=ia - NM if os.environ.get("TRAIL_CAMQ") == "1" and ia - NM >= 0 else None)
                _, to_a2, hole2 = _inv(camt, da, torch.zeros(1, device=dev))
                ok2 = (hole2 < 0.5) & (_off(to_a2) < 0.5)
                if os.environ.get("TRAIL_HOMOG"):
                                                                                                                        
                                                                                                                    
                                                                                                                      
                    r = int(os.environ["TRAIL_HOMOG"])
                    ub = (hc["off_mv"][1] > 0.5).float()
                    ring = (F.max_pool2d(ub, 2 * r + 1, 1, r) > 0.5) & (ub < 0.5)
                    ring &= (hc["holes"][0] < 0.5) & (da >= 0.21) & (warp(da, hc["tflows"][0]) >= 0.21)                  
                    ring &= (_off(hc["tflows"][0]) < 0.5)
                    ring[..., DH:, :] = False
                    ys, xs = torch.nonzero(ring[0, 0], as_tuple=True)
                    dis_ = None
                    if os.environ.get("TRAIL_HOMOG_AUTO") and ys.numel() > 500:                                       
                        dis_ = float((to_a2 - hc["tflows"][0]).norm(dim=1)[0][ring[0, 0]].median())
                        print(f"  frame {f - 1}: camera vs MV on the ring {dis_:.1f} px -> " + ("camera" if dis_ <= float(os.environ["TRAIL_HOMOG_AUTO"]) else "homography"))
                    if ys.numel() > 2000 and not (dis_ is not None and dis_ <= float(os.environ["TRAIL_HOMOG_AUTO"])):
                        sel = torch.randperm(ys.numel(), device=dev)[:20000]
                        ys, xs = ys[sel], xs[sel]
                        fl = hc["tflows"][0][0][:, ys, xs]
                        X, Y = xs.double(), ys.double(); U, V = X + fl[0].double(), Y + fl[1].double()
                        sc = 1000.0
                        X, Y, U, V = X / sc, Y / sc, U / sc, V / sc
                        o, z_ = torch.ones_like(X), torch.zeros_like(X)
                        Am = torch.cat((torch.stack((X, Y, o, z_, z_, z_, -U * X, -U * Y), 1), torch.stack((z_, z_, z_, X, Y, o, -V * X, -V * Y), 1)), 0)
                        bm = torch.cat((U, V))
                        wts = torch.ones_like(bm)
                        for _it in range(4):                                                                
                            hp = torch.linalg.lstsq(Am * wts[:, None], (bm * wts)[:, None]).solution[:, 0]
                            res = (Am @ hp - bm).abs() * sc
                            wts = torch.where(res < 3.0, torch.ones_like(res), (3.0 / res).sqrt())
                        Hm = torch.cat((hp, torch.ones(1, dtype=hp.dtype, device=dev))).view(3, 3)
                        gy, gx = torch.meshgrid(torch.arange(ca.shape[-2], device=dev, dtype=torch.float64), torch.arange(ca.shape[-1], device=dev, dtype=torch.float64), indexing="ij")
                        P = torch.stack((gx / sc, gy / sc, torch.ones_like(gx)), 0).view(3, -1)
                        Q_ = Hm @ P; Q_ = Q_[:2] / Q_[2:]
                        to_a2 = (Q_.view(2, *gx.shape) * sc - torch.stack((gx, gy), 0)).float()[None]
                        ok2 = _off(to_a2) < 0.5
                        if os.environ.get("TRAIL_HOMOG_VM", "1") == "1":                                                      
                            ok2 = ok2 & (warp(da, to_a2) >= 0.21)
                        if DIAG_F is None or f == DIAG_F:
                            print(f"  frame {f - 1}: homography fit on {ys.numel()} px, inlier(<3px) {float((res < 3).double().mean()) * 100:.0f}%, median res {float(res.median()):.2f} px")
                use = hc["off_mv"][1] > 0.5
                if os.environ["TRAIL_CAM"] == "2":
                    c_ = hc["cand"]
                    dmv_ = F.avg_pool2d((c_[:, 0] - c_[:, 1]).abs().mean(1, keepdim=True), 3, 1, 1)
                    nearer = warp(da, hc["tflows"][0]) < warp(db, hc["tflows"][1]) - float(os.environ.get("TRAIL_CAM_DZ", "0.02"))
                    front = nearer & (dmv_ > float(os.environ.get("TRAIL_CAM_DIS", "0.03")))
                    if pm is not None and ia - NM >= 0:                                                              
                        cap_ = cam_offset(ia, ia - NM, 1.0, dA_raw)
                        guard = ((cap_ - pm).norm(dim=1, keepdim=True) < 4.0).float()
                        front = front & (warp(guard, to_a2) > 0.5)
                    else:
                        front = front & False
                    use = use | front
                use = use & ok2
                cam_col = warp(ca_h, to_a2)
                if os.environ.get("DIAG_SAVE") and DIAG_F == f:                                                   
                    np.savez(os.environ["DIAG_SAVE"], cam=to_a2[0, :, :DH].cpu().numpy(), mv=hc["tflows"][0][0, :, :DH].cpu().numpy(),
                             of=hc["tflows"][2][0, :, :DH].cpu().numpy(), use=use[0, 0, :DH].cpu().numpy(), ok=ok2[0, 0, :DH].cpu().numpy(),
                             camt=camt[0, :, :DH].cpu().numpy(), mvba=(mv * mvv)[0, :, :DH].cpu().numpy(),
                             wgt=hc["weights"][0, :, :DH].cpu().numpy(), offa=hc["off_mv"][0][0, 0, :DH].cpu().numpy(),
                             offb=hc["off_mv"][1][0, 0, :DH].cpu().numpy(), hmv=hc["holes"][0][0, 0, :DH].cpu().numpy(),
                             hof=hc["holes"][1][0, 0, :DH].cpu().numpy(), mb=hc["tflows"][1][0, :, :DH].cpu().numpy(),
                             ob=hc["tflows"][3][0, :, :DH].cpu().numpy(), mvv=mvv[0, 0, :DH].cpu().numpy(),
                             cand=(hc["cand"][0, :, :, :DH].clamp(0, 1) * 255).byte().cpu().numpy())
                if os.environ.get("TRAIL_FEATHER") or os.environ.get("TRAIL_EXT"):
                                                                                                                     
                                                                                                                    
                                                                                                                         
                    u = use.float()
                    agree = ((to_a2 - hc["tflows"][0]).norm(dim=1, keepdim=True) < float(os.environ.get("TRAIL_EXT_THR", "2"))).float()
                    if DIAG_F is None or f == DIAG_F:
                        ring = (F.max_pool2d(u, 33, 1, 16) - u) * ok2.float()
                        dd = (to_a2 - hc["tflows"][0]).norm(dim=1, keepdim=True)
                        if ring.sum() > 0:
                            q = dd[ring > 0.5]
                            print(f"  frame {f - 1}: band {float(u[0, 0, :DH].mean()) * 100:.1f}% | 16 px ring outside it: |cam t->A - MV t->A| "
                                  f"median {float(q.median()):.2f} px, p90 {float(q.quantile(0.9)):.2f}, agree(<thr) {float(agree[ring > 0.5].mean()) * 100:.0f}%")
                    w = u
                    if os.environ.get("TRAIL_EXT"):
                        r = int(os.environ["TRAIL_EXT"])
                        w = torch.maximum(w, F.max_pool2d(u, 2 * r + 1, 1, r) * agree)
                    if os.environ.get("TRAIL_FEATHER"):
                        r = int(os.environ["TRAIL_FEATHER"])
                        w = F.avg_pool2d(F.max_pool2d(w, 2 * r + 1, 1, r), 2 * r + 1, 1, r)
                        w = torch.where(use, torch.ones_like(w), w * agree if os.environ.get("TRAIL_FEATHER_AGREE") == "1" else w)
                    w = w * ok2.float()
                    col = w * cam_col + (1 - w) * col
                    fracs.append(float((w[0, 0, :DH] > 0.5).float().mean()))
                else:
                    col = torch.where(use, cam_col, col)
                    fracs.append(float(use[0, 0, :DH].float().mean()))
            if os.environ.get("LEAD_HOMOG"):
                                                                                                                       
                                                                                                                      
                from mlof2_gen_graph import off_frame as _off
                r = int(os.environ["LEAD_HOMOG"])
                ua = (hc["off_mv"][0] > 0.5) & (hc["off_mv"][1] < 0.5)
                ringb = (F.max_pool2d(ua.float(), 2 * r + 1, 1, r) > 0.5) & (hc["off_mv"][0] < 0.5) & (hc["off_mv"][1] < 0.5)
                ringb &= (hc["holes"][0] < 0.5) & (warp(db, hc["tflows"][1]) >= 0.21) & (_off(hc["tflows"][1]) < 0.5)
                ringb[..., DH:, :] = False
                to_b = fit_homog_flow(hc["tflows"][1], ringb)
                if to_b is not None:
                    okb = ua & (_off(to_b) < 0.5) & (warp(db, to_b) >= 0.21)
                    col_b = warp(cb_h, to_b)
                    col = torch.where(okb, col_b, col)
                    fracs.append(float(okb[0, 0, :DH].float().mean()))
            if os.environ.get("OFONLY") == "1":                                                                    
                w2 = hc["weights"][:, 2:4]
                w2 = w2 / w2.sum(1, keepdim=True).clamp_min(1e-6)
                col = (w2[:, :, None] * hc["cand"][:, 2:4]).sum(1)
            if VIG is not None:
                col = col * VIG
            if os.environ.get("SAVE_OFF") and "off_mv" in hc:                                                     
                ob = F.max_pool2d(((hc["off_mv"][0] + hc["off_mv"][1]) > 0.5).float(), 33, 1, 16)[0, 0, :DH]
                np.save(f"{os.environ['SAVE_OFF']}_{f:03d}" + (f"_{k}" if NM > 2 else "") + ".npy", (ob > 0.5).cpu().numpy())
            img = (col[0, :, :DH].clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
            with open(f"{pre}_{f:03d}_{k}.ppm", "wb") as fh:
                fh.write(f"P6\n{DW} {DH}\n255\n".encode()); fh.write(img.tobytes())
for v in vlog:
    print(f"  vignette frame {v[0]:3d}: {v[1]:6d} px used, " + (f"edge L/R/(T/B) {v[2:-3]}, " if len(v) > 5 else "") + f"edge L {v[-3]:.3f} R {v[-2]:.3f}, |online - offline fit| {v[-1]:.3f}")
print("wrote", pre, "frames 2..", n_fr - 2, (f"| overwritten area {100 * sum(fracs) / len(fracs):.1f}% of the frame "
      f"(min {100 * min(fracs):.1f}, max {100 * max(fracs):.1f})") if fracs else "")
if RULEF:
    print(f"FUSE_RULE share of pixels on the MV pair: {100 * np.mean(RULEF):.1f} %")
