"""NFRU-style reconstruction on top of a frozen MLOF2 (OF + gate + TimeHead flows).

Four candidates for the frame at time t, as in Arm NFRU v1 (postprocess: softmax-weighted blend, no new colour):
  A pulled by the game-MV t-flow, B pulled by the game-MV t-flow, A pulled by MLOF2's F_tA, B pulled by MLOF2's F_tB.
The blend weights come from NFRU's autoencoder (architecture and initial weights: Arm neural-graphics-model-gym,
src/ng_model_gym/usecases/nfru/model/nfru_v1_nn.py, nfru_v1_fp32.pt, Copyright 2025-2026 Arm Limited, Apache-2.0),
run at half resolution on 16 channels: candidate colours 12, depth pulled by the MV t-flows 2, disocclusion 2.
Differences from NFRU: the flow candidates are MLOF2's (gate-fused MV / learned OF, t-conditioned), the depth is the
MLOF2 depth feature (log2(z / zNear) / 16) instead of NFRU's normalised device depth, and the two disocclusion
channels are MLOF2's TimeHead visibility (1 - v for A, v for B) instead of NFRU's depth reprojection test."""
import os
import torch
from torch import nn
from torch.nn import functional as F
from model_v2 import warp

ARM_WEIGHTS = "/home/sh/neural-graphics-model-gym/tests/usecases/nfru/weights/nfru_v1_fp32.pt"


class ConvBlock(nn.Module):
    """conv -> BatchNorm -> ReLU, same parameter names as ng_model_gym ConvBlock (conv2d, bn)."""
    def __init__(self, cin, cout, k, padding=(1, 1), stride=(1, 1)):
        super().__init__()
        self.conv2d = nn.Conv2d(cin, cout, k, stride=stride, padding=padding)
        self.bn = nn.BatchNorm2d(cout, momentum=0.1)
        self.act = nn.ReLU()

    def forward(self, x):
        return self.act(self.bn(self.conv2d(x)))


class NFRUAutoEncoder(nn.Module):
    """Arm NFRU v1 autoencoder (16 -> 4), layer for layer as nfru_v1_nn.NFRUAutoEncoder (Apache-2.0, Arm)."""
    def __init__(self, in_ch=16, hid=32, br=16, cat=64, out=4):
        super().__init__()
        self.conv1 = ConvBlock(in_ch, hid, 3, (1, 1))
        self.conv2 = ConvBlock(hid, br, 5, (2, 2))
        self.skip1_conv = ConvBlock(br, br, 3)
        self.conv3 = ConvBlock(br, br, 3)
        self.conv5 = ConvBlock(br, br, 5, (2, 2), (2, 2))
        self.conv5a = ConvBlock(br, br, 1, 0)
        self.conv5b = ConvBlock(br, br, 3)
        self.conv5c = ConvBlock(br, br, 7, (3, 3))
        self.conv5c_1 = ConvBlock(br, br, 7, (3, 3))
        self.conv5d = ConvBlock(br, br, 7, (3, 3))
        self.conv5d_1 = ConvBlock(br, br, 7, (3, 3))
        self.conv5d_2 = ConvBlock(br, br, 7, (3, 3))
        self.conv5e = ConvBlock(cat, br, 1, 0)
        self.upsample1 = nn.Upsample(mode="nearest", scale_factor=2)
        self.conv6 = ConvBlock(br, br, 3, (1, 1))
        self.conv7 = ConvBlock(hid, br, 3)
        self.output_conv_mv = nn.Conv2d(br, out, 5, padding=(2, 2))

    def forward(self, x):
        x = self.conv2(self.conv1(x))
        x = self.conv3(x)
        skip1 = self.skip1_conv(x)
        b = self.conv5(x)
        xa, xb = self.conv5a(b), self.conv5b(b)
        xc = self.conv5c_1(self.conv5c(b))
        xd = self.conv5d_2(self.conv5d_1(self.conv5d(b)))
        x = self.conv5e(torch.cat([xa, xb, xc, xd], 1))
        x = self.conv6(self.upsample1(x))
        x = x[..., :skip1.shape[-2], :skip1.shape[-1]]
        x = self.conv7(torch.cat([x, skip1], 1))
        return self.output_conv_mv(x)


def load_arm(ae, path=ARM_WEIGHTS):
    sd = torch.load(path, map_location="cpu", weights_only=False)["model_state_dict"]
    sd = {k[len("network.auto_encoder."):]: v for k, v in sd.items() if k.startswith("network.auto_encoder.")}
    missing, unexpected = ae.load_state_dict(sd, strict=True), None
    return len(sd)


def up4(f, H, W):
    """1/4-res flow (px at 1/4) -> full-res flow in full-res px (a flow already at full res passes through)."""
    if f.shape[-2:] == (H, W):
        return f
    return F.interpolate(f, size=(H, W), mode="bilinear", align_corners=False) * (W / f.shape[-1])


class NfruHead(nn.Module):
    def __init__(self, arm_init=True):
        super().__init__()
        self.ae = NFRUAutoEncoder()
        if arm_init:
            load_arm(self.ae)

    def forward(self, t, pair, frame, color_a, color_b, depth_a, depth_b):
        """frame: the frozen MLOF2 TimeHead output (f_ta, f_tb, vis). Returns colour, weights, candidates."""
        n, _, H, W = color_a.shape
        tt = t.view(n, 1, 1, 1)
        mv_ab, mv_ba = pair["mv_ab"], pair["mv_ba"]
        ma = -(1 - tt) * tt * mv_ab + tt * tt * mv_ba                                                                
        mb = (1 - tt) ** 2 * mv_ab - tt * (1 - tt) * mv_ba
        ma, mb = up4(ma, H, W), up4(mb, H, W)
        cand = torch.stack((warp(color_a, ma), warp(color_b, mb), warp(color_a, frame["f_ta"]), warp(color_b, frame["f_tb"])), 1)
        v = frame["vis"]
        x = torch.cat((cand.flatten(1, 2), warp(depth_a, ma), warp(depth_b, mb), 1 - v, v), 1)       
        logits = self.ae(F.avg_pool2d(x, 2))
        logits = F.interpolate(logits, size=(H, W), mode="bilinear", align_corners=False)
        wgt = logits.softmax(1)
        return {"color": (wgt[:, :, None] * cand).sum(1).clamp(0, 1), "weights": wgt, "cand": cand}


                                                                                                             
def splat_t(f_ba, depth_b, t, f_bp=None):
    """Forward-splat a B->A flow (full res, px; A at t=0, B at t=1) to the time-t grid, nearest depth wins.
    A B pixel x sits at x + (1-t) f(x) at time t; there f_tA = t f(x), f_tB = -(1-t) f(x).
    Holes (no source) keep the flow at the pixel itself and are returned as a mask (the disocclusion cue).
    depth_b: MLOF2 depth feature (larger = farther).
    f_bp (optional, B -> previous frame P): quadratic trajectory through P (-1), A (0), B (1) (QVI, Xu et al. 2019):
      p(t) = x + f_ba - (f_bp / 2) t + (f_bp / 2 - f_ba) t^2   (= the linear case when f_bp = 2 f_ba)."""
    n, _, H, W = f_ba.shape
    dev = f_ba.device
    tt = t.view(n, 1, 1, 1)
    y, x = torch.meshgrid(torch.arange(H, device=dev), torch.arange(W, device=dev), indexing="ij")
    if f_bp is None:
        disp = (1 - tt) * f_ba                                                
    else:
        disp = f_ba - 0.5 * f_bp * tt + (0.5 * f_bp - f_ba) * tt * tt
    px = torch.floor(x[None] + disp[:, 0] + 0.5).long()                                                  
    py = torch.floor(y[None] + disp[:, 1] + 0.5).long()
    ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
    hw = H * W
    tgt = (torch.arange(n, device=dev).view(n, 1, 1) * hw + py.clamp(0, H - 1) * W + px.clamp(0, W - 1))[ok]
    src = (y * W + x)[None].expand(n, H, W)[ok]
    dq = (depth_b[:, 0].clamp(0, 1) * 65535).long()[ok]
    key = dq * hw + src                                                                                    
    big = torch.iinfo(torch.long).max
    best = torch.full((n * hw,), big, dtype=torch.long, device=dev).scatter_reduce(0, tgt, key, "amin")
    hole = best == big
    srci = torch.where(hole, torch.zeros_like(best), best % hw)
    to_a, to_b = f_ba - disp, -disp                                                          
    vec = torch.cat((to_a, to_b), 1).permute(0, 2, 3, 1).reshape(n, hw, 4)
    picked = torch.gather(vec, 1, srci.view(n, hw, 1).expand(-1, -1, 4))
    picked = torch.where(hole.view(n, hw, 1), vec, picked).view(n, H, W, 4).permute(0, 3, 1, 2)
    return picked[:, :2], picked[:, 2:], hole.view(n, 1, H, W).float()


class HalfRefine(nn.Module):
    """Half-res correction of the 1/4-res blend logits: the 1/4 AE + bilinear upsampling blends two candidates over
    4-8 px at every edge (smeared background edges on SN2). Inputs at 1/2: the upsampled logits 4, candidate colours
    12, A/B agreement of the MV pair and of the OF pair 2, |MV t-flow - OF t-flow| / 16 1, OF conf at the B source 1,
    holes 2 = 22. 3x3 22->16, 3x3 16->16, 1x1 16->4 (last zero: starts equal to the plain head). ~2.9 GMAC at 1080p."""
    def __init__(self):
        super().__init__()
        self.a = nn.Conv2d(22, 16, 3, 1, 1)
        self.b = nn.Conv2d(16, 16, 3, 1, 1)
        self.c = nn.Conv2d(16, 4, 1)
        with torch.no_grad():
            self.c.weight.zero_(); self.c.bias.zero_()

    def forward(self, x):
        return self.c(F.leaky_relu(self.b(F.leaky_relu(self.a(x), 0.1)), 0.1))


def load_head_c2(path, dev):
    """NfruHeadC2 from a checkpoint (HalfRefine detected from its keys; older checkpoints have no of_prior = 0)."""
    hsd = torch.load(path, map_location=dev)
    hsd.setdefault("of_prior", torch.tensor(0.0))
    head = NfruHeadC2(arm_init=False, refine=any(k.startswith("ref.") for k in hsd),
                      cues={17: 0, 21: 1, 24: 2, 28: 3}[hsd["ae.conv1.conv2d.weight"].shape[1]]).to(dev).eval()
    head.load_state_dict(hsd)
    return head


def off_frame(fl):
    """(n,1,H,W): y + fl off the frame."""
    n, _, H, W = fl.shape
    yy, xx = torch.meshgrid(torch.arange(H, device=fl.device), torch.arange(W, device=fl.device), indexing="ij")
    qx, qy = xx[None] + fl[:, 0], yy[None] + fl[:, 1]
    return ((qx < -0.5) | (qx > W - 0.5) | (qy < -0.5) | (qy > H - 0.5))[:, None].float()


def head_cues(cand, ma, oa, ob, conf_q, H, W, level=1, occ_q=None, depth_a=None, depth_b=None, mb=None, offs=None):
    """Evidence for the MV / OF choice at t: A-B disagreement of the MV pair and of the OF pair (a right flow pulls the
    same colour from both sides), distance between the MV and OF t-flows / 16, OF conf (sigmoid) at the B source."""
    n = cand.shape[0]
    conf = torch.zeros(n, 1, H, W, device=cand.device) if conf_q is None else \
        torch.sigmoid(warp(F.interpolate(conf_q, size=(H, W), mode="bilinear", align_corners=False), ob))
    c = [(cand[:, 0] - cand[:, 1]).abs().mean(1, keepdim=True) * 4,
         (cand[:, 2] - cand[:, 3]).abs().mean(1, keepdim=True) * 4,
         ((ma - oa).norm(dim=1, keepdim=True) / 16.0).clamp(max=4.0), conf]
    if level >= 2:
        occ = torch.zeros(n, 1, H, W, device=cand.device) if occ_q is None else \
            torch.sigmoid(warp(F.interpolate(occ_q, size=(H, W), mode="bilinear", align_corners=False), ob))
        d_mv = (warp(depth_a, ma) - warp(depth_b, mb)).abs() * 16                                       
        d_of = (warp(depth_a, oa) - warp(depth_b, ob)).abs() * 16
        c += [occ, d_mv.clamp(max=4.0), d_of.clamp(max=4.0)]
    if level >= 3:                                                                                                       
        c += list(offs) if offs is not None else [off_frame(ma), off_frame(mb), off_frame(oa), off_frame(ob)]
    return torch.cat(c, 1)


def head_logits(head, x, cand, ma, oa, ob, conf_q, hole_mv, hole_of):
    """Blend logits at full res: the 1/4 AE, plus the HalfRefine correction at 1/2 when the head has one."""
    n, _, H, W = x.shape
    lq = head.ae(F.avg_pool2d(x, head.res))
    pr = getattr(head, "of_prior", None)                                                                            
    if pr is not None and float(pr) != 0.0:
        lq = torch.cat((lq[:, :2], lq[:, 2:] + pr), 1)
    if getattr(head, "ref", None) is None:
        return F.interpolate(lq, size=(H, W), mode="bilinear", align_corners=False)
    h2, w2 = H // 2, W // 2
    down = lambda z: F.interpolate(z, size=(h2, w2), mode="area")
    conf = torch.zeros(n, 1, H, W, device=x.device) if conf_q is None else \
        warp(F.interpolate(conf_q, size=(H, W), mode="bilinear", align_corners=False), ob)                           
    cues = torch.cat((F.interpolate(lq, size=(h2, w2), mode="bilinear", align_corners=False),
                      down(cand.flatten(1, 2)),
                      down((cand[:, 0] - cand[:, 1]).abs().mean(1, keepdim=True)),
                      down((cand[:, 2] - cand[:, 3]).abs().mean(1, keepdim=True)),
                      down((ma - oa).norm(dim=1, keepdim=True) / 16.0), down(torch.sigmoid(conf)),
                      down(hole_mv), down(hole_of)), 1)
    l2 = cues[:, :4] + head.ref(cues)
    return F.interpolate(l2, size=(H, W), mode="bilinear", align_corners=False)


class NfruHeadC(nn.Module):
    """NFRU candidates from the RAW game MV and the RAW MLOF2 OF (no gate, no TimeHead), both splatted to t;
    autoencoder at 1/4 resolution (as the deployed NFRU), 17 inputs = colours 12 + MV-pulled depth 2 +
    splat holes (MV, OF) 2 + t 1. Arm init for everything but the extra t input row (zero)."""
    def __init__(self, arm_init=True, res=4, refine=False, cues=False):
        super().__init__()
        self.res = res
        self.cues = int(cues)                                                                                                  
                                                                                                                            
        self.ae = NFRUAutoEncoder(in_ch=17 + {0: 0, 1: 4, 2: 7, 3: 11}[self.cues])                           
        self.ref = HalfRefine() if refine else None
                                                                                                                      
                                                                                                                      
                                                                                                                        
        self.register_buffer("of_prior", torch.tensor(0.0))
        if arm_init:
            ref = NFRUAutoEncoder()
            load_arm(ref)
            sd = ref.state_dict()
            w = torch.zeros_like(self.ae.conv1.conv2d.weight)
            w[:, :16] = sd["conv1.conv2d.weight"]
            sd["conv1.conv2d.weight"] = w
            self.ae.load_state_dict(sd)

    def forward(self, t, of_ba_q, color_a, color_b, depth_a, depth_b, mv_ba, mv_ap=None, of_ap_q=None, conf_q=None,
                occ_q=None):
        """of_ba_q: MLOF2 pure OF B->A at 1/4 (pair['of_ba']); mv_ba: game MV B->A at full res.
        Optional acceleration: mv_ap (game MV A->P, full res) and of_ap_q (pure OF A->P at 1/4, previous pair):
        B->P = B->A + (A->P at the A position), then the quadratic trajectory in splat_t."""
        n, _, H, W = color_a.shape
        of = up4(of_ba_q, H, W)
        mv_bp = None if mv_ap is None else mv_ba + warp(mv_ap, mv_ba)
        of_bp = None if of_ap_q is None else of + warp(up4(of_ap_q, H, W), of)
        if getattr(self, "talign", "splat") == "kpn":                                                                
            ma, mb, hole_mv = self.talign_net(mv_ba, depth_b, t, mv_bp)
            oa, ob, hole_of = self.talign_net(of, depth_b, t, of_bp)
        elif getattr(self, "talign", "splat") == "fp":                                                      
            ma, mb, hole_mv = invert_t(mv_ba, depth_b, t, mv_bp)
            ob_mv = LAST_OOB[0]
            oa, ob, hole_of = invert_t(of, depth_b, t, of_bp)
            ob_of = LAST_OOB[0]
        else:
            ma, mb, hole_mv = splat_t(mv_ba, depth_b, t, mv_bp)
            oa, ob, hole_of = splat_t(of, depth_b, t, of_bp)
        cand = torch.stack((warp(color_a, ma), warp(color_b, mb), warp(color_a, oa), warp(color_b, ob)), 1)
        x = torch.cat((cand.flatten(1, 2), warp(depth_a, ma), warp(depth_b, mb), hole_mv, hole_of,
                       t.view(n, 1, 1, 1).expand(n, 1, H, W)), 1)                             
        fp_ = getattr(self, "talign", "splat") == "fp"
        offs = (off_frame(ma), ob_mv if fp_ else off_frame(mb), off_frame(oa), ob_of if fp_ else off_frame(ob))
        if self.cues:
            x = torch.cat((x, head_cues(cand, ma, oa, ob, conf_q, H, W, self.cues, occ_q, depth_a, depth_b, mb, offs)), 1)
        logits = head_logits(self, x, cand, ma, oa, ob, conf_q, hole_mv, hole_of)
        wgt = logits.softmax(1)
        return {"color": (wgt[:, :, None] * cand).sum(1).clamp(0, 1), "weights": wgt, "cand": cand}


                                                                                                                
def splat_t2(f_ba, depth_b, t, f_bp=None, valid=None, fill_passes=8, accel_cap=0.5):
    """splat_t with the SN2 fixes: 2x2 footprint per source (no 1-px cracks where the flow varies smoothly),
    invalid sources are not splatted, holes filled from the farthest valid 3x3 neighbour (disocclusions show
    background) for `fill_passes` passes, acceleration clamped to accel_cap * |f_ba| and off where the
    previous flow is invalid (valid: (n,1,H,W) source validity; f_bp given = quadratic trajectory).
    Returns (to_A, to_B, hole) with hole = no source even after the fill."""
    n, _, H, W = f_ba.shape
    dev = f_ba.device
    tt = t.view(n, 1, 1, 1)
    ok_src = torch.ones(n, 1, H, W, device=dev, dtype=torch.bool) if valid is None else valid > 0.5
    if f_bp is None:
        disp = (1 - tt) * f_ba
    else:
        a = f_bp - 2 * f_ba                                                                     
        cap = accel_cap * f_ba.norm(dim=1, keepdim=True)
        a = a * (cap / a.norm(dim=1, keepdim=True).clamp_min(1e-6)).clamp(max=1.0)
        a = torch.where(torch.isfinite(f_bp).all(1, keepdim=True), a, torch.zeros_like(a))
        disp = (1 - tt) * f_ba + 0.5 * a * tt * (tt - 1)                                                          
    y, x = torch.meshgrid(torch.arange(H, device=dev), torch.arange(W, device=dev), indexing="ij")
    qx, qy = x[None] + disp[:, 0], y[None] + disp[:, 1]
    x0, y0 = torch.floor(qx).long(), torch.floor(qy).long()
    hw = H * W
    dq = (depth_b[:, 0].clamp(0, 1) * 65535).long()
    src = (y * W + x)[None].expand(n, H, W)
    key_all, tgt_all = [], []
    for dy in (0, 1):
        for dx in (0, 1):
            px, py = x0 + dx, y0 + dy
            ok = (px >= 0) & (px < W) & (py >= 0) & (py < H) & ok_src[:, 0]
            tgt_all.append((torch.arange(n, device=dev).view(n, 1, 1) * hw + py.clamp(0, H - 1) * W + px.clamp(0, W - 1))[ok])
            key_all.append((dq * hw + src)[ok])
    big = torch.iinfo(torch.long).max
    best = torch.full((n * hw,), big, dtype=torch.long, device=dev).scatter_reduce(0, torch.cat(tgt_all), torch.cat(key_all), "amin")
    hole = (best == big).view(n, 1, H, W)
    srci = torch.where(best == big, torch.zeros_like(best), best % hw)
    to_a, to_b = f_ba - disp, -disp
    vec = torch.cat((to_a, to_b, depth_b), 1).permute(0, 2, 3, 1).reshape(n, hw, 5)
    picked = torch.gather(vec, 1, srci.view(n, hw, 1).expand(-1, -1, 5)).view(n, H, W, 5).permute(0, 3, 1, 2)
    for _ in range(fill_passes):                                                                                
        if not hole.any():
            break
        nb = F.unfold(picked, 3, padding=1).view(n, 5, 9, H, W)
        nv = F.unfold((~hole).float(), 3, padding=1).view(n, 1, 9, H, W)
        score = torch.where(nv > 0.5, nb[:, 4:5], torch.full_like(nv, -1.0))
        sel = score.argmax(2, keepdim=True)
        cand = torch.gather(nb, 2, sel.expand(-1, 5, -1, -1, -1))[:, :, 0]
        has = torch.gather(nv, 2, sel)[:, :, 0] > 0.5
        upd = hole & has
        picked = torch.where(upd, cand, picked)
        hole = hole & ~has
    vec_self = torch.cat((to_a, to_b, depth_b), 1)
    picked = torch.where(hole, vec_self, picked)
    return picked[:, :2], picked[:, 2:4], hole.float()


INVERT_STATS = []                                                                                   


LAST_OOB = [None]                                                                                                      


def invert_t(f_ba, depth_b, t, f_bp=None, valid=None, iters=4, rings=(), accel_cap=0.5):
    """Backward alternative to splat_t2: for every pixel y of the frame at t, find the B pixel x that lands on it,
    x + disp(x) = y, by fixed-point iteration x <- y - disp(x) (bilinear samples of disp), from 1 + 8 * len(rings)
    starts (y - disp(y) and y - disp(y + o) for o on rings of the given radii: a pixel next to a moving edge has a
    background and a foreground solution). Converged starts (|x + disp(x) - y| <= 1 px with nearest samples of disp, source valid) compete
    by depth (smallest depth feature wins, the same rule as splat_t2). No holes or cracks by construction; hole =
    no start converged (disocclusion: then the y - disp(y) start is used). The search runs without gradient; the
    flow values at the chosen x are sampled with gradient. Same trajectory (linear / clamped quadratic) as splat_t2.
    Default since 2026-10-22: ONE start x 4 iterations (rings=()): SN2 12.55 vs 12.53 for 17 x 6, Spring t-flow
    slightly better, ~10 reads/px, 0.12-0.17 ms per path as a Vulkan compute shader at 1080p. (8, 24) x 6 = old.
    Returns (to_A, to_B, hole)."""
    n, _, H, W = f_ba.shape
    dev = f_ba.device
    if os.environ.get("INV_RINGS") is not None:                                                                       
        rings = tuple(int(r) for r in os.environ["INV_RINGS"].split(",") if r)
    if os.environ.get("INV_ITERS"):
        iters = int(os.environ["INV_ITERS"])
    tt = t.view(n, 1, 1, 1)
    if f_bp is None:
        disp = (1 - tt) * f_ba
    else:
        a = f_bp - 2 * f_ba
        cap = accel_cap * f_ba.norm(dim=1, keepdim=True)
        a = a * (cap / a.norm(dim=1, keepdim=True).clamp_min(1e-6)).clamp(max=1.0)
        a = torch.where(torch.isfinite(f_bp).all(1, keepdim=True), a, torch.zeros_like(a))
        disp = (1 - tt) * f_ba + 0.5 * a * tt * (tt - 1)
    ok_src = torch.ones(n, 1, H, W, device=dev) if valid is None else (valid > 0.5).float()
    y, x = torch.meshgrid(torch.arange(H, device=dev, dtype=f_ba.dtype), torch.arange(W, device=dev, dtype=f_ba.dtype), indexing="ij")
    grid = torch.stack((x, y), 0)[None]                                                   
    def nn(img, rel):                                                                                      
        gx = 2 * (grid[:, 0] + rel[:, 0]) / max(W - 1, 1) - 1
        gy = 2 * (grid[:, 1] + rel[:, 1]) / max(H - 1, 1) - 1
        return F.grid_sample(img, torch.stack((gx, gy), -1), mode="nearest", padding_mode="border", align_corners=True)

    starts = [(0, 0)] + [(dy * r, dx * r) for r in rings for dy, dx in
                         ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))]
    with torch.no_grad():
        dd = disp.detach()
        best_q = best_d = None
        first = None
        for dy, dx in starts:
            o = torch.tensor([dx, dy], device=dev, dtype=dd.dtype).view(1, 2, 1, 1)
            q = grid - nn(dd, o.expand(n, 2, H, W))                                                     
            for _ in range(iters):
                q = grid - nn(dd, q - grid)
            res = (q + nn(dd, q - grid) - grid).abs().amax(1, keepdim=True)
            inb = (q[:, :1] >= 0) & (q[:, :1] <= W - 1) & (q[:, 1:] >= 0) & (q[:, 1:] <= H - 1)
            good = (res <= 1.0) & inb & (nn(ok_src, q - grid) > 0.5)
            dq = torch.where(good, nn(depth_b.detach(), q - grid), torch.full_like(res, float("inf")))
            if first is None:
                first = q
                best_q, best_d = q, dq
                INVERT_STATS.append(float((~good).float().mean()))                                           
            else:
                take = dq < best_d
                best_q, best_d = torch.where(take, q, best_q), torch.where(take, dq, best_d)
        hole = torch.isinf(best_d)
        q = torch.where(hole, first, best_q)
        LAST_OOB[0] = ((q[:, :1] < -0.5) | (q[:, :1] > W - 0.5) | (q[:, 1:] < -0.5) | (q[:, 1:] > H - 0.5)).float()
    rel = q - grid                                                                                                 
    f_x, d_x = warp(f_ba, rel), warp(disp, rel)
    return f_x - d_x, -d_x, hole.float()


def warp_noise(img, flow):
    """warp() with out-of-frame samples replaced by noise (NFRU does the same so the blend learns to avoid them)."""
    n, _, H, W = img.shape
    y, x = torch.meshgrid(torch.arange(H, device=img.device), torch.arange(W, device=img.device), indexing="ij")
    qx, qy = x[None] + flow[:, 0], y[None] + flow[:, 1]
    oob = ((qx < -0.5) | (qx > W - 0.5) | (qy < -0.5) | (qy > H - 0.5))[:, None]
    g = torch.Generator(device=img.device).manual_seed(1234)
    noise = torch.rand(img.shape, generator=g, device=img.device, dtype=img.dtype)
    return torch.where(oob, noise, warp(img, flow))


class NfruHeadC2(NfruHeadC):
    """NfruHeadC with the SN2 fixes in the candidate construction (same weights / inputs)."""
    def forward(self, t, of_ba_q, color_a, color_b, depth_a, depth_b, mv_ba, mv_ap=None, of_ap_q=None,
                mv_valid=None, mv_ap_valid=None, conf_q=None, occ_q=None):
        n, _, H, W = color_a.shape
        of = up4(of_ba_q, H, W)
        mv_bp = None
        if mv_ap is not None:
            mv_bp = mv_ba + warp(mv_ap, mv_ba)
            if mv_ap_valid is not None:                                                                               
                pv = warp(mv_ap_valid, mv_ba) > 0.999
                mv_bp = torch.where(pv, mv_bp, 2 * mv_ba)
        of_bp = None if of_ap_q is None else of + warp(up4(of_ap_q, H, W), of)
        if getattr(self, "talign", "splat") == "kpn":                                                                
            ma, mb, hole_mv = self.talign_net(mv_ba, depth_b, t, mv_bp, mv_valid)
            oa, ob, hole_of = self.talign_net(of, depth_b, t, of_bp)
        elif getattr(self, "talign", "splat") == "fp":                                                      
            ma, mb, hole_mv = invert_t(mv_ba, depth_b, t, mv_bp, mv_valid)
            oob_mv = LAST_OOB[0]
            oa, ob, hole_of = invert_t(of, depth_b, t, of_bp)
            oob_of = LAST_OOB[0]
        else:
            ma, mb, hole_mv = splat_t2(mv_ba, depth_b, t, mv_bp, mv_valid)
            oa, ob, hole_of = splat_t2(of, depth_b, t, of_bp)
        cand = torch.stack((warp_noise(color_a, ma), warp_noise(color_b, mb), warp_noise(color_a, oa), warp_noise(color_b, ob)), 1)
        x = torch.cat((cand.flatten(1, 2), warp(depth_a, ma), warp(depth_b, mb), hole_mv, hole_of,
                       t.view(n, 1, 1, 1).expand(n, 1, H, W)), 1)
        def off(fl):                                                                                    
            yy, xx = torch.meshgrid(torch.arange(H, device=fl.device), torch.arange(W, device=fl.device), indexing="ij")
            qx, qy = xx[None] + fl[:, 0], yy[None] + fl[:, 1]
            return ((qx < -0.5) | (qx > W - 0.5) | (qy < -0.5) | (qy > H - 0.5))[:, None].float()
        fp_ = getattr(self, "talign", "") == "fp"
                                                                                                                    
        off_mv = (off(ma), oob_mv if fp_ else off(mb))
        off_of = (off(oa), oob_of if fp_ else off(ob))
        if self.cues:
            x = torch.cat((x, head_cues(cand, ma, oa, ob, conf_q, H, W, self.cues, occ_q, depth_a, depth_b, mb,
                                        off_mv + off_of)), 1)
        logits = head_logits(self, x, cand, ma, oa, ob, conf_q, hole_mv, hole_of)
        wgt = logits.softmax(1)
        if getattr(self, "hole_b", False):
            keep = torch.cat((1 - off_mv[0], 1 - off_mv[1], 1 - off_of[0], 1 - off_of[1]), 1)
            wgt = wgt * keep                                                                                   
            wgt = wgt / wgt.sum(1, keepdim=True).clamp_min(1e-6)
        return {"color": (wgt[:, :, None] * cand).sum(1).clamp(0, 1), "weights": wgt, "cand": cand,
                "tflows": (ma, mb, oa, ob), "holes": (hole_mv, hole_of), "off_mv": off_mv, "off_of": off_of,
                "dep_mb": x[:, 13:14]}                                                                                    
