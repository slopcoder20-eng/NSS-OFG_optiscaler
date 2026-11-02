"""MLOF2 training windows from the converted capture crops (prepare_scaled.py output, same files as mlof/data_mlof.py).

One sample = real frames A = i, B = i + k, ground truth G = i + j (t = j / k), and the frame before A,
P = i - k (for the acceleration input). k in SPANS: a span of k capture frames stands for a game running at
capture_fps / k, so large k gives the large motions of low real frame rates.

Crop conventions (same as data_mlof.py, verified there):
  ground_truth_linear (T,3,Hd,Wd) display res, 16 spp, linear HDR -> colour via display_transform (below)
  motion_lr (T,2,h,w) render res game MV, (y,x), current - previous, render px
  motion    (T,2,Hd,Wd) display res engine MV, same convention, display px  (= geometry "GT flow")
  depth     (T,1,h,w) render res, d -> z = zNear / (1 - d)
B->A over k frames is the chain of the k one-frame backward MVs: p <- p + m_s(p) for s = B .. A+1.
Chains through pixels hidden in between give wrong values, like a real game at the lower frame rate would
not (its MV is per frame) -- accepted approximation; the colour losses do not depend on it.

Colour = what the in-game NFRU actually receives: the game's FINAL backbuffer (its own exposure, tone curve,
grading and sRGB encoding already applied; the SDK reads it without conversion). The captures are linear
HDR, so each window gets one random "game look", identical for its four frames:
  auto exposure (log-average luminance of A, random key) -> tone curve (Reinhard / Karis / ACES fit /
  Hable filmic) -> grading (contrast, saturation, white balance) -> sRGB or gamma 2.2 encoding ->
  8- or 10-bit quantization (inputs only; the target G stays unquantized).
All losses and the gate's SMAPE judgement then work in this display-referred space, as in the game.
"""
import glob
import math
import os
import random
import torch
from torch.nn import functional as F
from safetensors import safe_open

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import warp

_BASE = "/home/sh/mlof_data"
ROOTS = {
    "spring": "/home/sh/spring_mlof",
    "lyra15": f"{_BASE}/lyra_x1_5/training_ready_1_5",
    "lyra17": f"{_BASE}/lyra_x1_7/training_ready_1_7",
    "forest15": f"{_BASE}/forest_x1_5/training_ready_1_5",
}
SPANS = (2, 3, 4, 6, 8)
EXPOSURE = math.exp(2.0)                                                                                       


def karis(x):
    x = x.clamp_min(0)
    return x / (1 + x.amax(-3, keepdim=True))


def _aces(x):
    return (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)


def _hable(x):
    A, B, C, D, E, Fh = 0.15, 0.50, 0.10, 0.20, 0.02, 0.30
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * Fh)) - E / Fh


TONE_CURVES = {
    "reinhard": lambda x: x / (1 + x),
    "karis": lambda x: x / (1 + x.amax(-3, keepdim=True)),
    "aces": _aces,
    "hable": lambda x: _hable(2.0 * x) / _hable(torch.tensor(11.2)),
}


def pq_encode(x, peak_nits):
    """SMPTE ST 2084 of a display-referred [0,1] image shown with paper white at peak_nits (HDR10 output)."""
    m1, m2, c1, c2, c3 = 0.1593017578125, 78.84375, 0.8359375, 18.8515625, 18.6875
    y = (x.clamp(0, 1) * peak_nits / 10000.0) ** m1
    return ((c1 + c2 * y) / (1 + c3 * y)) ** m2


def srgb_encode(x):
    return torch.where(x <= 0.0031308, 12.92 * x, 1.055 * x.clamp_min(1e-8) ** (1 / 2.4) - 0.055)


def random_look(rng):
    return {"key": rng.uniform(0.10, 0.30), "curve": rng.choice(list(TONE_CURVES)),
            "contrast": rng.uniform(0.85, 1.20), "saturation": rng.uniform(0.80, 1.25),
            "wb": [rng.uniform(0.94, 1.06), 1.0, rng.uniform(0.94, 1.06)],
            "encode": rng.choices(["srgb", "gamma22", "pq"], weights=[0.70, 0.15, 0.15])[0],
            "pq_nits": rng.uniform(150, 400), "bits": 8 if rng.random() < 0.7 else 10}


def display_transform(lin, look, ref):
    """lin (T,3,H,W) linear HDR -> display-referred [0,1] like a game's backbuffer. ref: the frame whose
    log-average luminance sets the exposure (A), so all frames of a window share one exposure."""
    lum = lambda x: (0.2126 * x[:, 0] + 0.7152 * x[:, 1] + 0.0722 * x[:, 2]).clamp_min(1e-6)
    exposure = look["key"] / torch.exp(torch.log(lum(ref)).mean())
    x = TONE_CURVES[look["curve"]](lin.clamp_min(0) * exposure).clamp(0, 1)
    x = (x * torch.tensor(look["wb"]).view(1, 3, 1, 1)).clamp(0, 1)
    if look["encode"] == "srgb":
        x = srgb_encode(x)
    elif look["encode"] == "pq":
        x = pq_encode(x, look.get("pq_nits", 200.0))
    else:
        x = x.clamp_min(0) ** (1 / 2.2)
                                                                                                         
    y = (0.2126 * x[:, 0:1] + 0.7152 * x[:, 1:2] + 0.0722 * x[:, 2:3])
    x = y + (x - y) * look["saturation"]
    return ((x - 0.5) * look["contrast"] + 0.5).clamp(0, 1)


def quantize(x, bits):
    q = float(2 ** bits - 1)
    return torch.round(x * q) / q


def depth_feature(d, zn):
    d = d.clamp(0.0, 1.0 - 1e-6)
    z = zn / (1.0 - d)
    return (torch.log2(z / zn) / 16.0).clamp(0.0, 1.0)


def chain_backward(m_list):
    """m_list: one-frame backward flows (2,H,W) of frames B, B-1, ..., A+1 (display px, x/y); a list or a lazy
    iterable (only one frame in memory: long Spring chains at 1080p). Returns the B->A flow: follow each pixel
    back frame by frame."""
    acc = None
    border = os.environ.get("CHAIN_BORDER") == "1"                                                                  
    for m in m_list:                                                                                                    
        acc = torch.zeros(1, 2, *m.shape[-2:]) if acc is None else acc
        acc = acc + (_warp_border(m[None], acc) if border else warp(m[None], acc))
    return acc[0]


def _warp_border(t, flow):
    n, _, h, w = t.shape
    y, x = torch.meshgrid(torch.arange(h, dtype=t.dtype), torch.arange(w, dtype=t.dtype), indexing="ij")
    gx = (x + flow[:, 0] + 0.5) * (2.0 / w) - 1.0
    gy = (y + flow[:, 1] + 0.5) * (2.0 / h) - 1.0
    return F.grid_sample(t, torch.stack((gx, gy), -1), mode="bilinear", padding_mode="border", align_corners=False)


def chain2_border(m1, v1, m0, v0):
    """Two-frame chain for the SN2 skip protocol (B = f, A = f-2): B->A = m1 + m0 at the f-1 position, with m0 /
    its validity read with BORDER padding. chain_backward's zero padding gave the pixels whose f-1 position is off
    screen (a 250-350 px band at fast camera yaw) half the motion and then mv_valid = 0 -> zero MV: a static band,
    a seam and doubled content in the MV candidates. The real game MV (one hop B->A) has no such band; off screen the
    camera motion continues, which the border value approximates. m*: (2,H,W), v*: (1,H,W)."""
    _, H, W = m1.shape
    y, x = torch.meshgrid(torch.arange(H, dtype=m1.dtype), torch.arange(W, dtype=m1.dtype), indexing="ij")
    gx = (x + m1[0] + 0.5) * (2.0 / W) - 1.0
    gy = (y + m1[1] + 0.5) * (2.0 / H) - 1.0
    g = torch.stack((gx, gy), -1)[None]
    m0w = F.grid_sample(m0[None], g, mode="bilinear", padding_mode="border", align_corners=False)[0]
    v0w = F.grid_sample(v0[None], g, mode="nearest", padding_mode="border", align_corners=False)[0]
    return m1 + m0w, v1 * (v0w > 0.5).float()


MV_SCALES = (1.0, 0.77, 0.67, 0.58, 0.5, 0.33)


def resample_mv(mv, s, up="bilinear", depth=None):
    """mv (2,Hd,Wd) in display px -> as a game would deliver it at render scale s: point-sampled at s, optional 3x3
    closest-depth dilation (depth (1,h,w), any res; smaller = nearer), back to the display grid. Units unchanged."""
    Hd, Wd = mv.shape[-2:]
    hs, ws = max(8, round(Hd * s)), max(8, round(Wd * s))
    lo = F.interpolate(mv[None], size=(hs, ws), mode="nearest")
    if depth is not None:
        d = F.interpolate(depth[None].float(), size=(hs, ws), mode="nearest")
        pick = F.unfold(F.pad(d, (1, 1, 1, 1), mode="replicate"), 3).argmin(1)                        
        nb = F.unfold(F.pad(lo, (1, 1, 1, 1), mode="replicate"), 3).view(1, 2, 9, -1)
        lo = nb.gather(2, pick[:, None, None, :].expand(1, 2, 1, -1)).view(1, 2, hs, ws)
    if up == "nearest":
        return F.interpolate(lo, size=(Hd, Wd), mode="nearest")[0]
    return F.interpolate(lo, size=(Hd, Wd), mode="bilinear", align_corners=False)[0]


class WindowDataset(torch.utils.data.Dataset):
    def __init__(self, names, split, crop=448, windows_per_file=128, spans=SPANS, seed=0, with_ga=False,
                 strides=None, tri=False, mv_res=False, p_mv_res=0.75, drop=()):
        self.files = []
        for n in names:
            self.files += sorted(glob.glob(f"{ROOTS[n]}/{split}/*/crop_*.safetensors"))
        assert self.files, (names, split)
        self.lengths, self.spring_file = [], []
        for f in self.files:
            with safe_open(f, "pt") as s:
                self.lengths.append(s.get_slice("motion").get_shape()[0])
                self.spring_file.append("ground_truth_srgb8" in s.keys())
        self.crop, self.wpf, self.spans, self.split, self.seed = crop, windows_per_file, spans, split, seed
        self.with_ga = with_ga                                                                                    
        self.strides = strides                                                                                      
        self.tri = tri                                                                                      
        self.mv_res, self.p_mv_res = mv_res, p_mv_res                                                    
        self.drop = set(drop)                                                                                         

    def __len__(self):
        return len(self.files) * self.wpf

    def pick(self, i):
        rng = random.Random(i + self.seed * 1000003) if self.split != "train" else random
        fi = i // self.wpf
        T = self.lengths[fi]
                                                                                                                 
        if self.strides:
            n, st = rng.choice((3, 4, 5)), rng.choice(self.strides)
            k = (n - 1) * st
            if 2 * k > T - 1:                                                                                               
                fits = [x for x in sorted(self.strides) if 2 * 2 * x <= T - 1] or [1]
                n, st = 3, fits[-1]
                k = (n - 1) * st
        else:
            k = rng.choice(self.spans)
        a = rng.randint(k, T - 1 - k)                                                        
        j = st * rng.randint(1, n - 2) if self.strides else rng.randint(1, k - 1)                               
        return fi, k, a, j, rng

    def __getitem__(self, i):
        fi, k, a, j, rng = self.pick(i)
        idx = [a - k, a, a + j, a + k]                              
        with safe_open(self.files[fi], "pt") as s:
            g = lambda key, ix: s.get_slice(key)[ix:ix + 1]
            if "ground_truth_srgb8" in s.keys():                                          
                c8 = torch.cat([g("ground_truth_srgb8", x) for x in idx]).float() / 255.0
                col = torch.where(c8 <= 0.04045, c8 / 12.92, ((c8 + 0.055) / 1.055) ** 2.4)
            else:
                col = torch.cat([g("ground_truth_linear", x) for x in idx]).float()
            dep = torch.cat([g("depth", x) for x in idx]).float()
            zn = torch.cat([g("zNear", x) for x in idx]).float().view(-1, 1, 1, 1)
                                                                                                                
            lo, hi = a - k + 1, a + k + 1                                                                             
            mlr_all = s.get_slice("motion_lr")[lo:hi]                                                          
            mhr_all = s.get_slice("motion")[a + 1:hi]                                                 
            mlr = {x: mlr_all[x - lo] for x in range(lo, hi)}
            mhr = {x: mhr_all[x - a - 1] for x in range(a + 1, hi)}
            cut = s.get_slice("camera_cut")[a - k:a + k + 1].bool().any().item()
        Hd, Wd = col.shape[-2:]
        h, w = dep.shape[-2:]
        look = random_look(rng)
        color = display_transform(col, look, col[1:2])
        bits = look["bits"]
        color = torch.cat((quantize(color[0:2], bits), color[2:3], quantize(color[3:4], bits)))                  
        dfeat = F.interpolate(depth_feature(dep, zn), size=(Hd, Wd), mode="bilinear", align_corners=False)
        game = lambda x: F.interpolate((-mlr[x].float().flip(0) * (Hd / h))[None], size=(Hd, Wd), mode="bilinear",
                                       align_corners=False)[0]                                                    
        eng = lambda x: (-mhr[x].float().flip(0) if mhr[x].shape[-2:] == (Hd, Wd) else                             
                         F.interpolate((-mhr[x].float().flip(0) * (Hd / mhr[x].shape[-2]))[None], size=(Hd, Wd),
                                       mode="bilinear", align_corners=False)[0])                                  
        if self.mv_res and rng.random() < self.p_mv_res:
            s_r, up_r = rng.choice(MV_SCALES), rng.choice(("bilinear", "nearest"))
            dil = rng.random() < 0.3
            src = lambda x: eng(x) if (s_r > 0.5 and x in mhr) else game(x)
            game_b = lambda x: resample_mv(src(x), s_r, up_r, dep[3].reshape(1, h, w) if dil else None)
            game_a = lambda x: resample_mv(game(x), s_r, up_r, dep[1].reshape(1, h, w) if dil else None)
        else:
            game_b = game_a = game
        spring = self.spring_file[fi] and not self.mv_res
        if spring:
                                                                                                                      
                                                                                                   
            hm = mlr[a].shape[-2]
            nat = lambda x: -mlr[x].float().flip(0)
            up = lambda f: F.interpolate(f[None] * (Hd / hm), size=(Hd, Wd), mode="bilinear", align_corners=False)[0]
            geo_ba = up(chain_backward(nat(x) for x in range(a + k, a, -1)))
            mv_ba = geo_ba
            geo_ga = up(chain_backward(nat(x) for x in range(a + j, a, -1))) if (self.with_ga or self.tri) else None
            geo_bg = up(chain_backward(nat(x) for x in range(a + k, a + j, -1))) if self.tri else None
            mv_ap = up(chain_backward(nat(x) for x in range(a, a - k, -1))) if "mv_ap" not in self.drop else None
        else:
            mv_ba = chain_backward(game_b(x) for x in range(a + k, a, -1))
            geo_ba = chain_backward(eng(x) for x in range(a + k, a, -1))
            geo_ga = chain_backward(eng(x) for x in range(a + j, a, -1)) if (self.with_ga or self.tri) else None
            geo_bg = chain_backward(eng(x) for x in range(a + k, a + j, -1)) if self.tri else None
            mv_ap = (chain_backward(game_a(x) for x in range(a, a - k, -1))                                          
                     if "mv_ap" not in self.drop else None)
                                         
        ch, cw = self.crop if isinstance(self.crop, tuple) else (self.crop, self.crop)                      
        oy, ox = rng.randint(0, Hd - ch), rng.randint(0, Wd - cw)
        cr = lambda t: t[..., oy:oy + ch, ox:ox + cw].contiguous()
        out = {
            "color_p": cr(color[0]), "color_a": cr(color[1]), "color_g": cr(color[2]), "color_b": cr(color[3]),
            "depth_a": cr(dfeat[1]), "depth_b": cr(dfeat[3]), "depth_p": cr(dfeat[0]),
            "mv_ba": cr(mv_ba), "mv_valid": torch.ones(1, ch, cw), "geo_flow_ba": cr(geo_ba),
            **({"geo_flow_ga": cr(geo_ga)} if (self.with_ga or self.tri) else {}),
            **({"geo_flow_bg": cr(geo_bg), "depth_g": cr(dfeat[2])} if self.tri else {}),
            "mv_ap": cr(mv_ap) if mv_ap is not None else None, "t": torch.tensor(j / k), "span": torch.tensor(k),
            "cut": torch.tensor(cut),
        }
        return {n: v for n, v in out.items() if n not in self.drop}


if __name__ == "__main__":
                                                                            
    from losses_v2 import explain_error
    ds = WindowDataset(["forest15", "lyra15"], "train", windows_per_file=4, with_ga=True)
    print("files", len(ds.files), "frames per file", ds.lengths[:3])
    random.seed(1)
    stats = {}
    for n in range(60):
        s = ds[random.randrange(len(ds))]
        if s["cut"]:
            continue
        k = int(s["span"])
        ca, cb, cg = s["color_a"][None], s["color_b"][None], s["color_g"][None]
                                                                                                          
        inside = lambda f: (warp(torch.ones_like(ca[:, :1]), f[None]) > 0.999).float()
        m = inside(s["mv_ba"]) * inside(s["geo_flow_ba"])
        mg = inside(s["geo_flow_ga"])
        p = lambda x, y, mm: -10 * torch.log10((((x - y) ** 2) * mm).sum() / (3 * mm.sum()).clamp_min(1) + 1e-10).item()
        r = stats.setdefault(k, [])
        r.append((p(ca, cb, m), p(warp(ca, s["mv_ba"][None]), cb, m), p(warp(ca, s["geo_flow_ba"][None]), cb, m),
                  p(warp(ca, s["geo_flow_ga"][None]), cg, mg), (s["mv_ba"].abs().amax()).item(), m.mean().item()))
    for k in sorted(stats):
        v = torch.tensor(stats[k])
        print(f"span {k}: n={len(v)}  PSNR B vs A {v[:,0].mean():.2f} | warp(A, game MV chain) {v[:,1].mean():.2f}"
              f" | warp(A, engine MV chain) {v[:,2].mean():.2f} | G vs warp(A, G->A) {v[:,3].mean():.2f}"
              f" | max |MV| {v[:,4].mean():.0f}px | inside {v[:,5].mean()*100:.0f}%")
