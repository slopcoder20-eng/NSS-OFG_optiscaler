"""(eval_foliage_rifeflow.py: copy of eval_foliage_mfg.py; RIFE_OF=1 replaces the OF B->A by 2 * RIFE 4.25 F_0.5->0)
MFG on a Spring validation sequence (1080p frames, exact flow; grass / fur / foliage): real frames every N-th frame
(A = a, B = a + N), generated t = k/N scored against the frames in between. Same generation path as eval_nfru_mfg.py
(OF pair, head, rule_rel + rel_t carry, ONESIDE) without the camera trailing band (Spring has no camera matrices) and
without the vignette. Colour: Spring's own 8-bit sRGB frames.
Game-like MV for animated foliage: MV_SMOOTH=r,thr replaces the exact flow by its (2r+1)^2 box mean wherever they
differ by more than thr px (local motion the game leaves out of its MV: wind, sway), scored as the "smooth" region.
  [MFG=4] [MV_SMOOTH=32,1.5] [BOTHFAIL=m,w] [SAVE=prefix SAVE_GT=1] python eval_foliage_mfg.py <spring crop safetensors>
      <OF ckpt> <head ckpt>"""
import os, sys
import numpy as np
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp
from data_v2 import depth_feature, chain_backward
from nfru_head import load_head_c2
from selector import rule_rel, luma
import selector

fn, ck, hk = sys.argv[1:4]
NM = int(os.environ.get("MFG", "4"))
dev = "cuda"
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


def mv_ba(a, b):
    return up(chain_backward(nat(x) for x in range(b, a, -1)))


if os.environ.get("RIFE_OF") == "1":
    sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
    from train_log.IFNet_HDv3 import IFNet
    rnet = IFNet().to(dev).eval()
    rsd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
    rnet.load_state_dict({k.replace("module.", ""): v for k, v in rsd.items()}, strict=False)

    def rife_ba(a_, b_):
        """B -> A flow (sample A at x + f) = 2 * RIFE's F_t->0 at t = 0.5 (t = 1 is outside RIFE's range: EPE 31 px;
        2 * F_0.5->0 EPE 1.55 px on SP_0045 c0, diag_rife_flowconv.py), full res px"""
        h_, w_ = a_.shape[-2:]
        ph, pw = (64 - h_ % 64) % 64, (64 - w_ % 64) % 64
        x = torch.cat((F.pad(a_, (0, pw, 0, ph), mode="replicate"), F.pad(b_, (0, pw, 0, ph), mode="replicate")), 1)
        fl, _, _ = rnet(x, 0.5, [16, 8, 4, 2, 1])
        return 2.0 * fl[-1][:, :2, :h_, :w_].float()

sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
from nfru_head_r import load_head_any
head = load_head_any(hk, dev); head.talign = "fp"
SMOOTH = [float(v) for v in os.environ["MV_SMOOTH"].split(",")] if os.environ.get("MV_SMOOTH") else None
SAVE = os.environ.get("SAVE")
OF_CAP = int(os.environ.get("OF_CAP", "1"))                                                                  
epe_r, epe_a = [], []                                                                                  


def save(img, name):
    a = (img[0, :, :H].clamp(0, 1) * 255 + 0.5).byte().permute(1, 2, 0).cpu().numpy()
    with open(name, "wb") as fh:
        fh.write(f"P6\n{W} {H}\n255\n".encode()); fh.write(a.tobytes())


grad_m = lambda l, r: float(((l[:, 2:] - l[:, :-2]).abs()[1:-1, :] + (l[2:, :] - l[:-2, :]).abs()[:, 1:-1])[r[1:-1, 1:-1]].mean())
err, err_r, shp_r, cover = {}, [], [], []
prev, prev_mask = None, {}
with torch.no_grad():
    for a in range(0, T - NM, NM):
        b = a + NM
        ca, cb = pad(col(a)).to(dev), pad(col(b)).to(dev)
        da, db = pad(dfeat(a)).to(dev), pad(dfeat(b)).to(dev)
        mv = pad(mv_ba(a, b)).to(dev); mvv = torch.ones_like(mv[:, :1])
        mv_ex = mv.clone()
        reg = None
        if SMOOTH:
            r, thr = int(SMOOTH[0]), SMOOTH[1]
            sm = F.avg_pool2d(F.pad(mv, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
            drop = ((mv - sm).norm(dim=1, keepdim=True) > thr).float()
            mv = torch.where(drop > 0.5, sm, mv)
            reg = F.max_pool2d(drop, 17, 1, 8)[0, 0, :H] > 0.5
            cover.append(float(drop[..., :H, :].mean()))
        if OF_CAP > 1:
            dn = lambda x: F.avg_pool2d(x, OF_CAP)
            pair = m.pair(m.enc(dn(ca), dn(da)), m.enc(dn(cb), dn(db)), dn(mv) / OF_CAP, dn(mvv), dn(ca), dn(cb))
            for k_ in ("conf", "occ"):
                pair[k_] = F.interpolate(pair[k_], scale_factor=OF_CAP, mode="bilinear", align_corners=False)
            pair["of_ba_full"] = None
        else:
            pair = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        if of_q.shape[-2:] != ca.shape[-2:]:
            from nfru_head import up4
            of_q = up4(of_q, *ca.shape[-2:])
        if os.environ.get("RIFE_OF") == "1":
            of_q = rife_ba(ca, cb)
        ep = (of_q - mv_ex).norm(dim=1)[0, :H]
        epe_a.append(float(ep.mean()))
        if reg is not None and reg.any():
            epe_r.append((float(ep[reg].sum()), float(reg.sum())))
        pm, po, pv = prev if prev is not None else (None, None, None)
        if SAVE:
            save(ca, f"{SAVE}_{a:04d}_0.ppm")
            if os.environ.get("SAVE_GT") == "1":
                save(ca, f"{SAVE}_gt_{a:04d}_0.ppm")
        for k in range(1, NM):
            t_ = k / NM
            hc = head(torch.tensor([t_], device=dev), of_q, ca, cb, da, db, mv * mvv, pm, po, mvv, pv,
                      conf_q=pair["conf"][:1], occ_q=pair["occ"][:1])
            to_prev = None
            if prev_mask.get(k) is not None and pm is not None:
                ma = hc["tflows"][0]
                to_prev = ma + (1 - t_) * warp(pm, ma)
            hc["t"] = t_
            o, mk = rule_rel(hc, prev=prev_mask[k] if to_prev is not None else None, to_prev=to_prev)
            prev_mask[k] = mk
            o = o.clamp(0, 1)
            g = pad(col(a + k)).to(dev)
            lg = luma(g)[0, 0, :H]
            e = (luma(o)[0, 0, :H] - lg).abs() * 255
            err.setdefault(k, []).append(float(e.mean()))
            if reg is not None and reg.any():
                err_r.append((float(e[reg].sum()), float(reg.sum())))
                shp_r.append(grad_m(luma(o)[0, 0, :H], reg) / max(grad_m(lg, reg), 1e-6))
            if SAVE:
                save(o, f"{SAVE}_{a + k:04d}_0.ppm")
                if os.environ.get("SAVE_GT") == "1":
                    save(g, f"{SAVE}_gt_{a + k:04d}_0.ppm")
        prev = (mv * mvv, of_q, mvv)
        print(f"pair B={b:3d}: " + " ".join(f"t={k}/{NM} {err[k][-1]:6.2f}" for k in range(1, NM)), flush=True)
allk = np.mean([np.mean(v) for v in err.values()])
print(f"{os.path.basename(os.path.dirname(fn))}: MFG {NM}x, {len(err[1])} pairs | mean |luma error| (8-bit) all {allk:.2f} | "
      + " ".join(f"t={k}/{NM} {np.mean(v):.2f}" for k, v in sorted(err.items())))
if err_r:
    print(f"  MV_SMOOTH region ({100 * np.mean(cover):.1f}% of px dropped): error {sum(x for x, _ in err_r) / sum(n for _, n in err_r):.2f}"
          f" | sharpness {np.nanmean(shp_r):.3f} (1 = real)")
print(f"  OF (1/{OF_CAP} frame) EPE vs the exact flow: all {np.mean(epe_a):.2f} px"
      + (f" | foliage region {sum(x for x, _ in epe_r) / sum(n for _, n in epe_r):.2f} px" if epe_r else ""))
if selector.BOTHFAIL_LOG:
    print(f"  BOTHFAIL mask mean {100 * np.mean(selector.BOTHFAIL_LOG):.2f}% of px")
