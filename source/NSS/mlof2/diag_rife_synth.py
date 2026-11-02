"""Where does our pipeline lose the sharpness RIFE keeps on foliage? Spring crop, MFG 4, foliage region (as
eval_foliage_mfg.py MV_SMOOTH=32,1.5, which also makes the MV game-like there). Variants per generated frame:
  A ours      : our OF (OF_CAP 2) + our head (no rule / no previous frame)
  B rflow+head: RIFE's own t-flows (F_t->0, F_t->1 at this t, no inversion) as the OF candidates + our head
  C rflow+rmask: RIFE t-flows + RIFE's mask, warped with OUR warp (model_v2.warp)
  D rflow+avg : RIFE t-flows, 0.5 / 0.5 average
  E rife      : RIFE's own output
  python diag_rife_synth.py <spring crop safetensors> <OF ckpt> <head ckpt>"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import depth_feature, chain_backward
import nfru_head
from nfru_head import load_head_c2, up4
from selector import luma

sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
from train_log.IFNet_HDv3 import IFNet

fn, ck, hk = sys.argv[1:4]
NM, dev = 4, "cuda"
rnet = IFNet().to(dev).eval()
rsd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
rnet.load_state_dict({k.replace("module.", ""): v for k, v in rsd.items()}, strict=False)
s = safe_open(fn, "pt")
T = s.get_slice("ground_truth_srgb8").get_shape()[0]
H, W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
hm = s.get_slice("motion_lr").get_shape()[-2]
PH = (H + 63) // 64 * 64
pad = lambda x: F.pad(x, (0, 0, 0, PH - H), mode="replicate")
col = lambda i: s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)),
                                size=(H, W), mode="bilinear", align_corners=False)
nat = lambda x: -s.get_slice("motion_lr")[x].float().flip(0)
up = lambda f: F.interpolate(f[None] * (H / hm), size=(H, W), mode="bilinear", align_corners=False)
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = "fp"
OFT = None
if os.environ.get("OFT_CKPT"):                                                                                         
    from oft_block import OFTNet
    osd = torch.load(os.environ["OFT_CKPT"], map_location=dev)
    nbl = len({k.split(".")[1] for k in osd if k.startswith("blocks.")})
    nb = [len({k.split(".")[3] for k in osd if k.startswith(f"blocks.{i}.body.")}) for i in range(nbl)]
    OFT = OFTNet(tuple(osd[f"blocks.{i}.d2.weight"].shape[0] for i in range(nbl)), tuple(nb),
                 corr=any(k.startswith("feat.") for k in osd)).to(dev).eval()
    OFT.load_state_dict(osd)

                                                                                          
_inv = nfru_head.invert_t
OVR = {"on": False, "fa": None, "fb": None, "n": 0}


def inv_patch(f_ba, depth_b, t, *a, **k):
    OVR["n"] += 1
    if OVR["on"] and OVR["n"] % 2 == 0:
        fa, fb = OVR["fa"], OVR["fb"]
        nfru_head.LAST_OOB[0] = nfru_head.off_frame(fb)
        return fa, fb, torch.zeros_like(fa[:, :1])
    return _inv(f_ba, depth_b, t, *a, **k)


nfru_head.invert_t = inv_patch
EPE = {}
LKF = {}
QD = {}
QNET = None


def OFT_init_ta(pair, t_, ca):
    from model_v2 import resize_flow
    H_, W_ = ca.shape[-2:]
    fab, fba = resize_flow(pair["of_ab"], H_, W_), resize_flow(pair["of_ba"], H_, W_)
    return -(1 - t_) * t_ * fab + t_ * t_ * fba


grad_m = lambda l, r: float(((l[:, 2:] - l[:, :-2]).abs()[1:-1, :] + (l[2:, :] - l[:-2, :]).abs()[:, 1:-1])[r[1:-1, 1:-1]].mean())
acc = {}
with torch.no_grad():
    for a in range(0, T - NM, NM):
        b = a + NM
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        mv = pad(up(chain_backward(nat(x) for x in range(b, a, -1)))).to(dev); mvv = torch.ones_like(mv[:, :1])
        r = 32
        sm = F.avg_pool2d(F.pad(mv, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
        drop = ((mv - sm).norm(dim=1, keepdim=True) > 1.5).float()
        mv = torch.where(drop > 0.5, sm, mv)
        reg = F.max_pool2d(drop, 17, 1, 8)[0, 0, :H] > 0.5
        if not reg.any():
            continue
        dn = lambda x: F.avg_pool2d(x, 2)
        pair = m.pair(m.enc(dn(ca), dn(da)), m.enc(dn(cb), dn(db)), dn(mv) / 2, dn(mvv), dn(ca), dn(cb))
        for k_ in ("conf", "occ"):
            pair[k_] = F.interpolate(pair[k_], scale_factor=2, mode="bilinear", align_corners=False)
        of_q = up4(pair["of_ba"], *ca.shape[-2:])
        x = torch.cat((ca, cb), 1)
        ph_, pw_ = (64 - x.shape[-2] % 64) % 64, (64 - x.shape[-1] % 64) % 64
        x = F.pad(x, (0, pw_, 0, ph_), mode="replicate")
        for k in range(1, NM):
            t_ = k / NM
            fl, mk, merged = rnet(x, t_, [16, 8, 4, 2, 1])
            fa, fb = fl[-1][:, :2, :ca.shape[-2], :ca.shape[-1]].float(), fl[-1][:, 2:4, :ca.shape[-2], :ca.shape[-1]].float()
            msk = torch.sigmoid(mk[..., :ca.shape[-2], :ca.shape[-1]]).float()
            hargs = (torch.tensor([t_], device=dev), of_q, ca, cb, da, db, mv * mvv, None, None, mvv, None)
            hkw = dict(conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
            OVR["on"] = False
            outs = {"A ours": head(*hargs, **hkw)["color"]}
            OVR.update(on=True, fa=fa, fb=fb, n=0)
            outs["B rflow+head"] = head(*hargs, **hkw)["color"]
            OVR["on"] = False
            wa, wb = warp(ca, fa), warp(cb, fb)
            outs["C rflow+rmask"] = wa * msk + wb * (1 - msk)
            outs["D rflow+avg"] = 0.5 * (wa + wb)
            outs["E rife"] = merged[4][..., :ca.shape[-2], :ca.shape[-1]].float()
            if OFT is not None:
                tq = torch.tensor([t_], device=dev)
                of_ = OFT(tq, ca, cb, pair["of_ab"], pair["of_ba"])
                outs["F oft"] = of_["color"]
                og = OFT(tq, ca, cb, pair["of_ab"], pair["of_ba"], init=(fa, fb))
                if os.environ.get("LK"):                                                                            
                    from lk_refine import lk_refine
                    it_ = int(os.environ.get("LK_IT", "3")); kk = int(os.environ.get("LK_K", "9"))
                    i_a, i_b = OFT.last_init if False else (OFT_init_ta(pair, t_, ca), None)
                    lin_b = None
                                                                
                    from model_v2 import resize_flow as rf_
                    fab_, fba_ = rf_(pair["of_ab"], *ca.shape[-2:]), rf_(pair["of_ba"], *ca.shape[-2:])
                    i_a = -(1 - t_) * t_ * fab_ + t_ * t_ * fba_
                    i_b = (1 - t_) ** 2 * fab_ - t_ * (1 - t_) * fba_
                    la_, lb_, _ = lk_refine(ca, cb, i_a, i_b, tq, iters=it_, k=kk)
                    ol = OFT(tq, ca, cb, pair["of_ab"], pair["of_ba"], init=(la_, lb_))
                    outs["I lk->oft"] = ol["color"]
                    ra_, rb_, _ = lk_refine(ca, cb, of_["f_ta"], of_["f_tb"], tq, iters=it_, k=kk)
                    v_ = of_["vis"]
                    outs["H oft->lk"] = (v_ * warp(ca, ra_) + (1 - v_) * warp(cb, rb_)).clamp(0, 1)
                                                                                                                  
                    from model_v2 import resize_flow as rf2
                    H2, W2 = ca.shape[-2] // 2, ca.shape[-1] // 2
                    ch_, cbh_ = F.interpolate(ca, size=(H2, W2), mode="area"), F.interpolate(cb, size=(H2, W2), mode="area")
                    oh_ = OFT(tq, ch_, cbh_, pair["of_ab"], pair["of_ba"])
                    rh_a, rh_b, _ = lk_refine(ch_, cbh_, oh_["f_ta"], oh_["f_tb"], tq, scales=(1,), iters=it_, k=kk)
                    vh_ = F.interpolate(oh_["vis"], size=ca.shape[-2:], mode="bilinear", align_corners=False)
                    fa_h, fb_h = rf2(rh_a, *ca.shape[-2:]), rf2(rh_b, *ca.shape[-2:])
                    outs["J half oft->lk"] = (vh_ * warp(ca, fa_h) + (1 - vh_) * warp(cb, fb_h)).clamp(0, 1)
                                                                                                                    
                    blk_all, sc_all = OFT.blocks, OFT.SCALES
                    OFT.blocks, OFT.SCALES = blk_all[:-1], sc_all[:-1]
                    try:
                        ok_ = OFT(tq, ca, cb, pair["of_ab"], pair["of_ba"])
                    finally:
                        OFT.blocks, OFT.SCALES = blk_all, sc_all
                    rk_a, rk_b, _ = lk_refine(ca, cb, ok_["f_ta"], ok_["f_tb"], tq, iters=it_, k=kk)
                    outs["K no-finest->lk"] = (ok_["vis"] * warp(ca, rk_a) + (1 - ok_["vis"]) * warp(cb, rk_b)).clamp(0, 1)
                    if os.environ.get("NO_L4"):                                                                           
                        o8 = pair["of_levels"][8]["of"]
                        om_ = OFT.__class__.forward(OFT, tq, ca, cb, o8[1:2], o8[0:1]) if False else None
                        blk_all, sc_all = OFT.blocks, OFT.SCALES
                        OFT.blocks, OFT.SCALES = blk_all[:-1], sc_all[:-1]
                        try:
                            om_ = OFT(tq, ca, cb, o8[1:2], o8[0:1])
                        finally:
                            OFT.blocks, OFT.SCALES = blk_all, sc_all
                        rm_a, rm_b, _ = lk_refine(ca, cb, om_["f_ta"], om_["f_tb"], tq, iters=it_, k=kk)
                        outs["M no-L4 3blk->lk"] = (om_["vis"] * warp(ca, rm_a) + (1 - om_["vis"]) * warp(cb, rm_b)).clamp(0, 1)
                    if os.environ.get("OFT_Q"):                                                                                 
                        import copy
                        from oft_quant import quantize_oft, freeze
                        if QNET is None:
                            QNET = quantize_oft(copy.deepcopy(OFT))
                            QNET.blocks, QNET.SCALES = QNET.blocks[:-1], QNET.SCALES[:-1]
                            for t2 in (0.25, 0.5, 0.75):
                                QNET(torch.tensor([t2], device=dev), ca, cb, pair["of_ab"], pair["of_ba"])
                            freeze(QNET)
                        oq_ = QNET(tq, ca, cb, pair["of_ab"], pair["of_ba"])
                        rq_a, rq_b, _ = lk_refine(ca, cb, oq_["f_ta"], oq_["f_tb"], tq, iters=it_, k=kk)
                        outs["L int8 3blk->lk"] = (oq_["vis"] * warp(ca, rq_a) + (1 - oq_["vis"]) * warp(cb, rq_b)).clamp(0, 1)
                        QD.setdefault("flow", []).append(float((rq_a - rk_a).norm(dim=1).median()))
                        QD.setdefault("psnr", []).append(float(-10 * torch.log10(((outs["L int8 3blk->lk"] - outs["K no-finest->lk"]) ** 2).mean())))
                    if os.environ.get("SAVE_PNG") and a == int(os.environ.get("SAVE_A", "24")) and k == 2:
                        from PIL import Image
                        y0, x0, hh, ww = [int(v) for v in os.environ.get("CROP", "300,700,360,640").split(",")]
                        tiles = [("gt", pad(col(a + k)).to(dev)), ("deployed", outs["A ours"]), ("fp32", outs["K no-finest->lk"])]
                        if "L int8 3blk->lk" in outs:
                            tiles.append(("int8", outs["L int8 3blk->lk"]))
                        tiles.append(("rife", outs["E rife"]))
                        row = torch.cat([tl[0, :, y0:y0 + hh, x0:x0 + ww] for _, tl in tiles], 2).clamp(0, 1)
                        Image.fromarray((row.permute(1, 2, 0).cpu().numpy() * 255 + 0.5).astype("uint8")).save(os.environ["SAVE_PNG"])
                        print("saved", os.environ["SAVE_PNG"], [n for n, _ in tiles], flush=True)
                    ka_, kb_, _ = lk_refine(ca, cb, fa, fb, tq, iters=it_, k=kk)
                    LKF.update(init_lk=la_, oft_lk=ra_, rife_lk=ka_, lkoft=ol["f_ta"])
                outs["G oft+rife init"] = og["color"]
                                                                                                                     
                ex_ta = pad(up(chain_backward(nat(x2) for x2 in range(a + k, a, -1)))).to(dev)
                ep = lambda f: float((f - ex_ta).norm(dim=1)[0, :H][reg].mean())
                lst = [("F init", ep(of_["f_ta"] * 0 + OFT_init_ta(pair, t_, ca))), ("F out", ep(of_["f_ta"])),
                       ("G out", ep(og["f_ta"])), ("rife", ep(fa))]
                if LKF:
                    lst += [("init+LK", ep(LKF["init_lk"])), ("LK->oft", ep(LKF["lkoft"])), ("oft+LK", ep(LKF["oft_lk"])),
                            ("rife+LK", ep(LKF["rife_lk"]))]
                for nm, v_ in lst:
                    EPE.setdefault(nm, []).append(v_)
            lg = luma(pad(col(a + k)).to(dev))[0, 0, :H]
            for name, o in outs.items():
                lo = luma(o.clamp(0, 1))[0, 0, :H]
                e = (lo - lg).abs() * 255
                v = acc.setdefault(name, [0.0, 0.0, [], []])
                v[0] += float(e[reg].sum()); v[1] += float(reg.sum()); v[2].append(grad_m(lo, reg) / max(grad_m(lg, reg), 1e-6))
                v[3].append(float(e.mean()))
name = "/".join(fn.split("/")[-2:])
for k, v in acc.items():
    print(f"{name} {k:14s} foliage error {v[0] / v[1]:6.2f} sharpness {np.nanmean(v[2]):.3f} | all {np.mean(v[3]):.2f}", flush=True)
for k, v in EPE.items():
    print(f"{name} EPE t->A foliage {k:8s} {np.mean(v):6.2f} px", flush=True)
if QD:
    print(f"{name} int8 vs fp32 (3 blocks + LK): flow diff median {np.mean(QD['flow']):.3f} px, colour PSNR {np.mean(QD['psnr']):.2f} dB", flush=True)
