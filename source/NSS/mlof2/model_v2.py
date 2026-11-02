"""NFRU ML optical flow v2: t-conditioned frame interpolation network (structure only, not trained).

Design: docs/NFRU_MLOF2_DESIGN_20261015.md. Own model; general NN practice only.

Three parts, split by how often they run:
  FrameEncoder  once per REAL frame (cached; each real frame is shared by two pairs)
  PairFlow      once per real frame PAIR (A = previous real frame, t=0; B = current, t=1)
  TimeHead      once per GENERATED frame, takes t in (0,1): 2x -> t=1/2, 3x -> 1/3,2/3, 4x -> 1/4,1/2,3/4

Tensor conventions
  color_*  (N,3,H,W)  display res, Karis tonemapped [0,1]
  depth_*  (N,1,H,W)  display res, log depth feature [0,1]
  mv_ba    (N,2,H,W)  game MV, backward B -> A (where a pixel of B was in A), display px, x/y
  mv_valid (N,1,H,W)  1 = game MV present
  H, W multiples of 64. Flows are in pixels of the grid they live on unless noted.
Flow naming: f_xy = for each pixel of x, offset to its position in y (backward-warp field for sampling y).

Out-of-graph ops (warp, correlation, flow inversion, convex upsampling) are plain functions so they can become
shaders later. Channel counts are multiples of 16; activations are leaky ReLU (int8/fp16 engine friendly).
"""
import math
import torch
from torch import nn
from torch.nn import functional as F


def leaky(x):
    return F.leaky_relu(x, 0.1)


def conv(cin, cout, k=3, s=1, d=1):
    return nn.Conv2d(cin, cout, k, stride=s, padding=d * (k // 2), dilation=d)


class LWGConv(nn.Module):
    """Lightweight gated convolution (ExtraNet, after Yi et al. 2020): features times a ONE-channel sigmoid
    mask, so regions without a valid correspondence (holes) can be suppressed at almost no extra cost."""
    def __init__(self, cin, cout, k=3):
        super().__init__()
        self.f = conv(cin, cout, k)
        self.m = conv(cin, 1, k)

    def forward(self, x):
        return torch.sigmoid(self.m(x)) * leaky(self.f(x))


                                                                                     
def base_grid(n, h, w, device, dtype=torch.float32):
    y, x = torch.meshgrid(torch.arange(h, device=device, dtype=dtype),
                          torch.arange(w, device=device, dtype=dtype), indexing="ij")
    return x[None].expand(n, -1, -1), y[None].expand(n, -1, -1)


def warp(t, flow):
    """Sample t at (pixel + flow), bilinear, zeros outside. flow in pixels of t's grid."""
    n, _, h, w = t.shape
    x, y = base_grid(n, h, w, t.device)
    gx = (x + flow[:, 0] + 0.5) * (2.0 / w) - 1.0
    gy = (y + flow[:, 1] + 0.5) * (2.0 / h) - 1.0
    return F.grid_sample(t, torch.stack((gx, gy), -1).to(t.dtype), mode="bilinear",
                         padding_mode="zeros", align_corners=False)


def correlation(q, r, radius):
    """Local cost volume: cosine similarity of q and r(+dy,+dx) for (dy,dx) in [-radius, radius]^2.
    (Raw <q,r>/C was ~4e-4 with the ~0.02 encoder features: the OF net saw no matching signal and collapsed.)"""
    q, r = F.normalize(q, dim=1, eps=1e-6), F.normalize(r, dim=1, eps=1e-6)
    _, c, h, w = q.shape
    rp = F.pad(r, (radius,) * 4)
    vols = [(q * rp[:, :, radius + dy:radius + dy + h, radius + dx:radius + dx + w]).sum(1, keepdim=True)
            for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1)]
    return torch.cat(vols, 1)


def pad_ch(x, c):
    return F.pad(x, (0, 0, 0, 0, 0, c - x.shape[1])) if x.shape[1] < c else x


def pad_c(c):
    return (c + 15) // 16 * 16


def resize_flow(flow, h, w):
    """Resample a flow field to (h,w) and rescale its units to the new grid (x and y separately)."""
    sx, sy = w / flow.shape[-1], h / flow.shape[-2]
    out = F.interpolate(flow, size=(h, w), mode="bilinear", align_corners=False)
    return torch.cat((out[:, :1] * sx, out[:, 1:2] * sy), 1)


def invert_flow(f_ba, iters=6):
    """f_ab from f_ba by fixed point (q + f_ba(q) = p). Same scheme as the current nfru_of inverse."""
    n, _, h, w = f_ba.shape
    x, y = base_grid(n, h, w, f_ba.device, f_ba.dtype)
    p = torch.stack((x, y), 1)
    q = p.clone()
    for _ in range(iters):
        q = p - warp(f_ba, q - p)
    res = (q + warp(f_ba, q - p) - p).abs().amax(1, keepdim=True)
    valid = (res <= 0.5).to(f_ba.dtype)
    return (q - p) * valid, valid


def convex_upsample(flow, mask, factor):
    """Learned convex upsampling (each fine pixel = softmax-weighted 3x3 coarse neighbours), units x factor."""
    n, _, h, w = flow.shape
    mask = mask.view(n, 1, 9, factor, factor, h, w).softmax(2)
    up = F.unfold(flow * factor, 3, padding=1).view(n, 2, 9, 1, 1, h, w)
    up = (mask * up).sum(2).permute(0, 1, 4, 2, 5, 3)
    return up.reshape(n, 2, h * factor, w * factor)


def convex_upsample_rep(flow, mask, factor=2):
    """convex_upsample with replicate borders (a level-to-level flow upsampling that can start equal to bilinear)."""
    n, _, h, w = flow.shape
    mask = mask.view(n, 1, 9, factor, factor, h, w).softmax(2)
    up = F.unfold(F.pad(flow * factor, (1, 1, 1, 1), mode="replicate"), 3).view(n, 2, 9, 1, 1, h, w)
    up = (mask * up).sum(2).permute(0, 1, 4, 2, 5, 3)
    return up.reshape(n, 2, h * factor, w * factor)


def bilinear_mask_bias(factor=2):
    """9 * factor^2 logits for convex_upsample_rep that reproduce bilinear x factor (align_corners=False) exactly:
    per axis, fine sub-pixel s sits at d = (s + 0.5) / factor - 0.5 coarse cells from its cell centre and takes
    |d| of the neighbour on that side and 1 - |d| of its own cell (factor 2: 0.25 / 0.75)."""
    taps = []
    for s in range(factor):
        d = (s + 0.5) / factor - 0.5
        taps.append((max(-d, 0.0), 1 - abs(d), max(d, 0.0)))
    b = torch.empty(9, factor, factor)
    for ky in range(3):
        for kx in range(3):
            for a in range(factor):
                for c in range(factor):
                    wgt = taps[a][ky] * taps[c][kx]
                    b[ky * 3 + kx, a, c] = math.log(wgt) if wgt > 0 else -30.0
    return b.flatten()


class UpFull(nn.Module):
    """Learned convex x4 upsampling of the final 1/4 OF to full res (replaces bilinear). Inputs per 1/4 cell: the
    query frame's 1/4 features, its full-res colour unshuffled into the cell (48 = 3 x 4 x 4: where an edge runs inside
    the cell), the flow / 16, conf, occ, context. 1x1 48 -> 3x3 32 -> 1x1 144 logits; the last layer starts at zero
    weight with the bilinear-x4 bias, so the module starts exactly equal to bilinear. ~24k MAC per 1/4 cell
    (1080p one direction ~3.1 GMAC)."""
    def __init__(self, cin):
        super().__init__()
        self.a = nn.Conv2d(cin, 48, 1)
        self.b = nn.Conv2d(48, 32, 3, 1, 1)
        self.c = nn.Conv2d(32, 144, 1)
        with torch.no_grad():
            self.c.weight.zero_(); self.c.bias.copy_(bilinear_mask_bias(4))

    def forward(self, x):
        return self.c(leaky(self.b(leaky(self.a(x)))))


class Propagate(nn.Module):
    """Edge-aware spatial propagation of the final 1/4 OF (CSPN-like). Foreground fattening: the background ring
    next to a moving object (4-24 px, 1-6 cells at 1/4) carries the object's motion, so a 3x3 convex upsampling
    cannot fix it (all its neighbours are wrong too; measured 2026-10-19). A small net, run once, gives per cell and
    per iteration a 3x3 softmax over neighbours and a gate; the iterations use dilations (1, 2, 4, 1, 2, 4) and reach
    14 cells (56 px): f <- f + g * (sum_k w_k f(x + d k) - f). Inputs: query features, full-res colour unshuffled into
    the cell, flow / 16, conf, occ, context, explain cues (feature / colour residual, round trip, spread).
    Starts ~identity through the neighbour weights, not a closed gate: centre logit 5.55 (softmax 0.97 on the cell
    itself), gate bias -2 (0.12), zero last weights -> change per iteration ~0.4% of (neighbour mean - f). A gate
    starting at sigmoid(-6) scaled every gradient by 0.0025 and the dilation-2/4 iterations never opened (measured
    2026-10-19, diag_prop_gate.py). ~24k MAC per 1/4 cell (1080p ~3.1 GMAC/direction)."""
    DIL = (1, 2, 4, 1, 2, 4)

    def __init__(self, cin):
        super().__init__()
        k = len(self.DIL)
        self.a = nn.Conv2d(cin, 32, 1)
        self.b = nn.Conv2d(32, 32, 3, 1, 1)
        self.c = nn.Conv2d(32, 32, 3, 1, 2, dilation=2)
        self.head = nn.Conv2d(32, k * 10, 1)                                                                    
        with torch.no_grad():
            self.head.weight.zero_(); self.head.bias.zero_()
            self.head.bias[:9 * k].view(k, 9)[:, 4] = 5.55
            self.head.bias[9 * k:] = -2.0

    def forward(self, of, x):
        n, _, h, w = of.shape
        k = len(self.DIL)
        o = self.head(leaky(self.c(leaky(self.b(leaky(self.a(x)))))))
        wts = o[:, :9 * k].view(n, k, 9, h, w).softmax(2)
        gate = torch.sigmoid(o[:, 9 * k:])
        for i, d in enumerate(self.DIL):
            nb = F.unfold(F.pad(of, (d, d, d, d), mode="replicate"), 3, dilation=d).view(n, 2, 9, h, w)
            prop = (nb * wts[:, i:i + 1]).sum(2)
            of = of + gate[:, i:i + 1] * (prop - of)
        return of


class PMSelect(nn.Module):
    """PatchMatch-style candidate selection of the final OF at full res (foreground fattening fix, no game MV).
    Candidates: the bilinear full-res flow U of the cell itself and of the 1/4 cells 1, 2, 4, 8, 12, 16, 24 away in 8
    directions (57) = U shifted by 4 * offset px. Evidence per candidate and pixel: small-window matching cost = 3x3
    mean of |query - other frame pulled by the candidate| (RGB) -- a small window does not see the occluding contour
    that drags the background ring along with the foreground -- plus the 7x7 cost. The search runs without gradient.
    The set is the pixel's OWN candidate + the 3 cheapest others (v1 kept the 4 cheapest overall: when the own flow
    was not among them nothing could bring it back, and object pixels next to their edge took background candidates,
    band-in EPE > 8 px 5.6% -> 13.7%, 2026-10-19). Their flows are gathered with gradient (to U, hence to the 1/4 OF)
    and blended by softmax(-cost3 / tau + net(costs 3x3 / 7x7, cost - own cost, |candidate - own| flow, offset size,
    colour, conf)). Starts at the argmin of the 3x3 cost (tau 0.005, net last layer zero; without learning: ring
    out 1..4 px 124 -> 36 px). Inference (one direction, 1080p): 57 warps + window means ~3.5 G ops, net ~0.8 GMAC."""
    DISTS = (1, 2, 4, 8, 12, 16, 24)
    K = 4                                                                   

    def __init__(self):
        super().__init__()
        dirs = ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))
        offs = [(0, 0)] + [(dy * d, dx * d) for d in self.DISTS for dy, dx in dirs]
        self.register_buffer("off", torch.tensor(offs, dtype=torch.long) * 4, persistent=False)                
        self.net = nn.Sequential(nn.Conv2d(5 * self.K + 4, 24, 1), nn.LeakyReLU(0.1), nn.Conv2d(24, self.K, 1))
        with torch.no_grad():
            self.net[2].weight.zero_(); self.net[2].bias.zero_()
        self.log_tau = nn.Parameter(torch.tensor(math.log(0.005)))

    @staticmethod
    def _shift(f, dy, dx):
        if dy == 0 and dx == 0:
            return f
        p = max(abs(dy), abs(dx))
        h, w = f.shape[-2:]
        return F.pad(f, (p, p, p, p), mode="replicate")[..., p + dy:p + dy + h, p + dx:p + dx + w]

    def forward(self, U, query, ref, conf):
        r, _, H, W = U.shape
        K = self.K
        with torch.no_grad(), torch.autocast("cuda", dtype=torch.float16):
            Ud, rf, qy = U.detach(), ref.detach(), query.detach()

            def costs(i):
                d = (warp(rf, self._shift(Ud, int(self.off[i, 0]), int(self.off[i, 1]))) - qy).abs().mean(1, keepdim=True)
                return (F.avg_pool2d(d, 3, 1, 1, count_include_pad=False).float(),
                        F.avg_pool2d(d, 7, 1, 3, count_include_pad=False).float())

            own3, own7 = costs(0)
            b3 = b7 = bi = None
            N, CH = self.off.shape[0], 8                                                                            
            for s0 in range(1, N, CH):
                ids = range(s0, min(s0 + CH, N))
                c3, c7 = zip(*(costs(i) for i in ids))
                c3, c7 = torch.cat(c3, 1), torch.cat(c7, 1)
                ci = torch.tensor(list(ids), device=U.device).view(1, -1, 1, 1).expand(r, -1, H, W)
                if b3 is not None:
                    c3, c7, ci = torch.cat((b3, c3), 1), torch.cat((b7, c7), 1), torch.cat((bi, ci), 1)
                b3, idx = c3.topk(K - 1, dim=1, largest=False)
                b7, bi = c7.gather(1, idx), ci.gather(1, idx)
            c3 = torch.cat((own3, b3), 1).to(U.dtype)
            c7 = torch.cat((own7, b7), 1).to(U.dtype)
            best_i = torch.cat((torch.zeros_like(bi[:, :1]), bi), 1)
        oy, ox = self.off[best_i, 0], self.off[best_i, 1]                                     
        yy = (torch.arange(H, device=U.device).view(1, 1, H, 1) + oy).clamp(0, H - 1)
        xx = (torch.arange(W, device=U.device).view(1, 1, 1, W) + ox).clamp(0, W - 1)
        flat = (yy * W + xx).view(r, 1, K * H * W).expand(r, 2, K * H * W)
        cand = U.flatten(2).gather(2, flat).view(r, 2, K, H, W)                                                    
        size = oy.abs().maximum(ox.abs()).float() / 96.0                                                   
        dflow = (cand.detach() - U.detach()[:, :, None]).norm(dim=1) / 16.0                                          
        x = torch.cat((c3 * 10.0, c7 * 10.0, (c3 - c3[:, :1]) * 10.0, dflow, size, query, conf), 1)
        logits = -c3 / self.log_tau.exp() + self.net(x)
        w = logits.softmax(1)
        return (cand * w[:, None]).sum(2)


def full_flow(o4, H, W):
    """The level-4 OF output at full res in full-res px: the learned convex x4 result when the model has one
    (UpFull, of_full), else bilinear."""
    f = o4.get("of_full")
    if f is not None and f.shape[-2:] == (H, W):
        return f
    return resize_flow(o4["of"], H, W)


class ResConv(nn.Module):
    """3x3 residual conv with a learnable per-channel branch scale (as in RIFE's IFBlock, MIT)."""
    def __init__(self, c, d=1):
        super().__init__()
        self.conv = nn.Conv2d(c, c, 3, 1, d, dilation=d)
        self.beta = nn.Parameter(torch.ones(1, c, 1, 1))

    def forward(self, x):
        return leaky(self.conv(x) * self.beta + x)


class DeepRefine(nn.Module):
    """Wide-context residual flow refinement for one level (no cost-volume search radius: the correction is bounded
    by the receptive field, not by +-r cells). Sees both frames' colour and features, the frame pulled by the
    current flow, the flow, conf/occ and the context. Head starts at zero (= keep the input flow)."""
    def __init__(self, cin, c=64, dil=(1, 2, 4, 8, 2, 1)):
        super().__init__()
        self.inp = conv(cin, c, 1)
        self.body = nn.Sequential(*[ResConv(c, d) for d in dil])
        self.head = conv(c, 4, 1)                                                                  
        nn.init.zeros_(self.head.weight)
        nn.init.zeros_(self.head.bias)

    def forward(self, x):
        return self.head(self.body(leaky(self.inp(x))))


                                                                                      
class MatchEncoder(nn.Module):
    """Matching features for the recurrent 1/8 block (2026-10-31). The FrameEncoder's entry (one 1x1 on
    pixel_unshuffle(4)) loses the detail foliage matching needs: with SEA-RAFT's features the recurrent block cuts
    SP_0038 foliage 6.67 -> 5.26, with ours it learns nothing. This branch starts from the pixels with 3x3 stride-2 convs
    (1/2 24 ch, 1/4 48, 1/8 96 + one residual block, 1x1 -> 64), trained by cost-volume distillation from SEA-RAFT.
    ~1.6 GMAC per frame on the 960x576 OF grid. Returns {4: 48 ch, 8: 64 ch}."""
    def __init__(self, c=(24, 48, 96), cout=64, ctx16=0, dil=(1, 1)):
        super().__init__()
        self.s1, self.s2, self.s3 = conv(4, c[0], 3, 2), conv(c[0], c[1], 3, 2), conv(c[1], c[2], 3, 2)
                                                                                                                    
                                                                                                                   
                                                                                                          
        self.t16 = conv(ctx16, c[2], 1) if ctx16 else None
        self.ra, self.rb = conv(c[2], c[2], d=dil[0]), conv(c[2], c[2], d=dil[1])
        self.out = conv(c[2], cout, 1)
        self.register_buffer("cfg_buf", torch.tensor([ctx16, dil[0], dil[1]]), persistent=False)                                          

    def forward(self, color, depth, f16=None):
        x = torch.cat((2 * color - 1, depth), 1)
        f4 = leaky(self.s2(leaky(self.s1(x))))
        x = leaky(self.s3(f4))
        if self.t16 is not None:
            x = x + F.interpolate(self.t16(f16), size=x.shape[-2:], mode="bilinear", align_corners=False)
        x = x + self.rb(leaky(self.ra(x)))
        return {4: f4, 8: self.out(x)}


class FrameEncoder(nn.Module):
    """RGB + depth -> pyramid 1/4 (32), 1/8 (64), 1/16 (96), 1/32 (128), 1/64 (256). Cached per real frame."""
    CH = {4: 32, 8: 64, 16: 96, 32: 128, 64: 256}

    def __init__(self, deep_fine=False, ch=None, fpn=False, match=False, match_ctx=False, match_c=None, match_out=64):
        super().__init__()
                                                                                                                
                                                                               
        mc = dict(c=tuple(match_c or (24, 48, 96)), cout=int(match_out))
        self.menc = (MatchEncoder(ctx16=self.CH[16] if ch is None else ch[16], dil=(2, 4), **mc) if match_ctx else MatchEncoder(**mc)) \
            if match else None
        if ch is not None:                                                                                           
            self.CH = dict(ch)
        c = self.CH
                                                                                                                      
                                                                                                                      
                                                                                                               
                                                                               
        self.deep_fine = deep_fine
        if deep_fine:
            self.r4a, self.r4b = conv(c[4], c[4]), conv(c[4], c[4])
            self.r8a, self.r8b = conv(c[8], c[8]), conv(c[8], c[8])
            for t in (self.r4b, self.r8b):
                nn.init.zeros_(t.weight); nn.init.zeros_(t.bias)
        self.e4 = conv(64, c[4], 1)                                                             
                                                                                                                     
                                                                                                                   
        self.fpn = fpn
        if fpn:
            self.t8, self.t4 = conv(c[16], c[8]), conv(c[8], c[4])
            for t in (self.t8, self.t4):
                nn.init.zeros_(t.weight); nn.init.zeros_(t.bias)
        self.e8a, self.e8b = conv(c[4], c[8], 3, 2), conv(c[8], c[8], 1)
        self.e16a, self.e16b = conv(c[8], c[16], 3, 2), conv(c[16], c[16])
        self.e32a, self.e32b = conv(c[16], c[32], 3, 2), conv(c[32], c[32])
        self.e64a, self.e64b = conv(c[32], c[64], 3, 2), conv(c[64], c[64])

    def forward(self, color, depth):
        f4 = leaky(self.e4(F.pixel_unshuffle(torch.cat((color, depth), 1), 4)))
        if getattr(self, "fpn", False):
            f8 = leaky(self.e8b(leaky(self.e8a(f4))))
            f16 = leaky(self.e16b(leaky(self.e16a(f8))))
            up2 = lambda x: F.interpolate(x, scale_factor=2, mode="bilinear", align_corners=False)
            f8 = f8 + self.t8(up2(f16))
            if self.deep_fine:
                f8 = f8 + self.r8b(leaky(self.r8a(f8)))
            f4 = f4 + self.t4(up2(f8))
            if self.deep_fine:
                f4 = f4 + self.r4b(leaky(self.r4a(f4)))
        else:
            if self.deep_fine:
                f4 = f4 + self.r4b(leaky(self.r4a(f4)))
            f8 = leaky(self.e8b(leaky(self.e8a(f4))))
            if self.deep_fine:
                f8 = f8 + self.r8b(leaky(self.r8a(f8)))
            f16 = leaky(self.e16b(leaky(self.e16a(f8))))
        f32 = leaky(self.e32b(leaky(self.e32a(f16))))
        f64 = leaky(self.e64b(leaky(self.e64a(f32))))
        out = {4: f4, 8: f8, 16: f16, 32: f32, 64: f64}
        if getattr(self, "menc", None) is not None:
            out["m8"] = self.menc(color, depth, f16)[8]
        return out


                                                                                           
class Update(nn.Module):
    """One coarse-to-fine level: 1x1 in -> n x 3x3 (residual) -> 1x1 head. Head starts at zero (= keep input flow)."""
    def __init__(self, cin, width, n_conv, n_out, dilations=None):
        super().__init__()
        self.inp = conv(cin, width, 1)
        dil = dilations or [1] * n_conv
        self.body = nn.ModuleList(conv(width, width, 3, d=d) for d in dil)
        self.head = conv(width, n_out, 1)
        nn.init.zeros_(self.head.weight)
        nn.init.zeros_(self.head.bias)

    def forward(self, x):
        x = leaky(self.inp(x))
        for c in self.body:
            x = x + leaky(c(x))
        return self.head(x), x


class GlobalMatch(nn.Module):
    """1/32 global matching (GMFlow-style softmax correspondence over the whole frame) -> initial flow + the
    conf/occ/ctx/beta maps the 1/32 refinement level expects from a coarser level."""
    def __init__(self, ch, ctx):
        super().__init__()
        self.proj = conv(ch, ch, 1)
        self.log_temp = nn.Parameter(torch.tensor(math.log(10.0)))                                           
        self.ctx = ctx
        self.net = Update(ch + 4, 64, 2, 5 + ctx)                                                       

    def forward(self, q, r):
        n, c, h, w = q.shape
        fq = F.normalize(self.proj(q), dim=1).flatten(2)                         
        fr = F.normalize(self.proj(r), dim=1).flatten(2)
        sim = torch.einsum("nci,ncj->nij", fq.float(), fr.float()) * self.log_temp.exp()
        p = sim.softmax(-1)                                                           
        x, y = base_grid(1, h, w, q.device, torch.float32)
        coords = torch.stack((x.flatten(), y.flatten()), -1)                  
        target = p @ coords                                                                  
        flow = (target - coords).transpose(1, 2).reshape(n, 2, h, w).to(q.dtype)
        peak = p.amax(-1).view(n, 1, h, w).to(q.dtype)
        ent = (-(p * (p + 1e-9).log()).sum(-1) / math.log(h * w)).view(n, 1, h, w).to(q.dtype)
        o, _ = self.net(torch.cat((q, flow / 16.0, peak, ent), 1))
        flow = flow + o[:, 0:2]
        return {"of": flow, "conf": o[:, 2:3], "occ": o[:, 3:4], "ctx": o[:, 4:4 + self.ctx],
                "beta": o[:, 4 + self.ctx:]}


class RecurRefine(nn.Module):
    """RAFT-style recurrent refinement of the 1/8 flow (2026-10-31). Diagnosis: the single-pass fine Update cannot pick
    the right candidate where the local cost is ambiguous (foliage); a non-Spring SEA-RAFT (1/8 corr pyramid + ConvGRU,
    4 iters) gets foliage 2.8 vs our 5.9 on SP_0038, while one readout of its own cost volume only reaches 5.9.
    Per iteration: 1/8 corr r=3 + 1/16 corr r=2 around the current flow -> motion features -> ConvGRU (z/q gates, hidden
    hd) -> flow delta. Hidden state and input context from the 1/8 query features + the level's ctx (once).
    The delta head starts at zero: with the block added the network computes exactly what it did before."""
    def __init__(self, c8, c16, ctx, hd=48, iters=3, r8=3, r16=2, teacher_feats=False):
        super().__init__()
        self.iters, self.r8, self.r16, self.hd = iters, r8, r16, hd
                                                                                                                       
                                                                                                                 
        self.teacher_feats = teacher_feats
        if teacher_feats:
            self.register_buffer("tfeat_buf", torch.tensor([1]))
        self.seq = []
        self.init = conv(c8 + ctx, 2 * hd, 1)
        self.mc = conv((2 * r8 + 1) ** 2 + (2 * r16 + 1) ** 2, 64, 1)
        self.mf = conv(2, 16)
        self.mm = conv(80, hd - 2)
        self.gz = conv(3 * hd, hd)
        self.gq = conv(3 * hd, hd)
        self.d1 = conv(hd, 64)
        self.d2 = conv(64, 2, 1)
        nn.init.zeros_(self.d2.weight); nn.init.zeros_(self.d2.bias)
        self.register_buffer("iters_buf", torch.tensor([iters]))

    def forward(self, of, q8, r8, q16, r16, ctx, corr_feats=None):
        """corr_feats: optional (q8, r8, q16, r16) used for the correlations only (teacher_feats experiment)."""
        h8, w8 = q8.shape[-2:]
        hi = self.init(torch.cat((q8, ctx), 1))
        h, inp = torch.tanh(hi[:, :self.hd]), leaky(hi[:, self.hd:])
        if corr_feats is not None:
            q8, r8, q16, r16 = corr_feats
        h16, w16 = q16.shape[-2:]
        self.seq = []
        for _ in range(self.iters):
            c8 = correlation(q8, warp(r8, of), self.r8)
            of16 = resize_flow(of, h16, w16)
            c16 = F.interpolate(correlation(q16, warp(r16, of16), self.r16), size=(h8, w8), mode="bilinear", align_corners=False)
            ab = getattr(self, "ablate", ())                                                       
            if getattr(self, "no16", False) or "c16" in ab:                                                      
                c16 = torch.zeros_like(c16)
            if "c8" in ab:
                c8 = torch.zeros_like(c8)
            if "c16" in ab:
                c16 = torch.zeros_like(c16)
            m = leaky(self.mc(torch.cat((c8, c16), 1)))
            m = torch.cat((leaky(self.mm(torch.cat((m, leaky(self.mf(of / 8.0))), 1))), of / 16.0), 1)
            x = torch.cat((h, m, inp), 1)
            z = torch.sigmoid(self.gz(x))
            h = (1 - z) * h + z * torch.tanh(self.gq(x))
            of = of + self.d2(leaky(self.d1(h)))
            self.seq.append(of)
        return of


_TEACHER_FNET = []


@torch.no_grad()
def _teacher_corr_feats(color_a, color_b, hw8):
    """SEA-RAFT fnet features (1/8, + 2x2 mean for 1/16), stacked like PairFlow's q / r (rows B first). Loaded once,
    kept out of the module tree (no weights in our checkpoints)."""
    if not _TEACHER_FNET:
        from teacher_searaft import SeaRaftTeacher
        _TEACHER_FNET.append(SeaRaftTeacher(color_a.device).model.fnet)
    fnet = _TEACHER_FNET[0]
    ta, tb = fnet(2 * color_a - 1).float(), fnet(2 * color_b - 1).float()
    if ta.shape[-2:] != tuple(hw8):
        ta = F.interpolate(ta, size=hw8, mode="bilinear", align_corners=False)
        tb = F.interpolate(tb, size=hw8, mode="bilinear", align_corners=False)
    q8, r8 = torch.cat((tb, ta), 0), torch.cat((ta, tb), 0)
    return q8, r8, F.avg_pool2d(q8, 2), F.avg_pool2d(r8, 2)


class PairFlow(nn.Module):
    """Bidirectional flow A<->B for one pair; both directions run as one batch (direction = batch axis).

    Two separate networks (user decision 2026-10-16: the OF network must not see the game MV at all):
      OF network   : pure optical flow from the two frames' features, coarse-to-fine 1/64 -> 1/4. No MV input,
                     no MV evidence. 1/64 starts at zero motion with r=8 (+-512 px); every finer level searches
                     around its own upsampled flow. It can be pre-trained on its own (train_v2 --stage of).
      gate network : small; compares how well the projected game MV and the OF explain the frames
                     (feature / colour residual, round-trip error, local spread, 3x3 similarity at the MV match)
                     and outputs the MV confidence c at 1/8, refined at 1/4.
    The game MV itself gets no network: it is only projected (resized; A->B by fixed-point inversion).
      flow = c * MV + (1 - c) * OF   at 1/4 (training pushes c towards 0/1: select, do not average).
    """
    LEVELS = (64, 32, 16, 8, 4)

    def __init__(self, widths=(256, 128, 96, 48, 32), n_conv=(3, 2, 2, 2, 1), radius=(8, 3, 3, 3, 2),
                 dilations=((1, 2, 1), (1, 2), (1, 2), (1, 2), None), ctx=32, gate_bias=4.0, gate_width=32,
                 global_match=False, convex_up=False, deep16=False, up_full=False, prop4=False, pm_sel=False,
                 fine_iters=1, recur8=0, recur8_teacher=False, enc_ch=None):
        super().__init__()
        self.rec = RecurRefine(FrameEncoder.CH[8], FrameEncoder.CH[16], ctx, iters=recur8,
                               teacher_feats=recur8_teacher) if recur8 else None
                                                                                                                       
                                                                                                                   
                                                                                                                 
        self.fine_iters = int(fine_iters)
        if self.fine_iters > 1:                                                                            
            self.register_buffer("fine_iters_buf", torch.tensor([self.fine_iters]))
        self.convex_up = convex_up                                                                             
        self.up_full = up_full                                                                                           
        self.prop4 = prop4                                                                                 
        self.pm_sel = pm_sel                                                                                         
        self.deep16 = deep16                                                                                        
        ch = {**FrameEncoder.CH, **(enc_ch or {})}                                                       
        self.global_match = global_match
        self.radius = dict(zip(self.LEVELS, radius))
        self.ctx = ctx
        self.gate_bias = gate_bias                                                                           
        self.of_cue = 16                                                                                     
        self.upd = nn.ModuleDict()
        if global_match:                                                                           
            self.gm = GlobalMatch(ch[32], ctx)
        for i, (lv, wd, nc, dl) in enumerate(zip(self.LEVELS, widths, n_conv, dilations)):
            if global_match and lv == 64:
                continue
            corr = (2 * self.radius[lv] + 1) ** 2
            cin = 2 * ch[lv] + pad_c(corr) + self.of_cue + (0 if i == 0 else ctx)
            n_up = 36 if (convex_up and lv != 4) else 0                                                            
            self.upd[str(lv)] = Update(cin, wd, nc, 5 + ctx + n_up, dl)                                                
            if n_up:
                with torch.no_grad():
                    self.upd[str(lv)].head.bias[5 + ctx:] = bilinear_mask_bias()
        if deep16:
            self.deep = DeepRefine(2 * ch[16] + 6 + 4 + ctx)                                                                  
        if up_full:
            self.upf = UpFull(ch[4] + 48 + 2 + 2 + ctx)
        if prop4:
            self.prop = Propagate(ch[4] + 48 + 2 + 2 + ctx + 4)
        if pm_sel:
            self.pms = PMSelect()
                                                                                                                 
        self.gate_cue = 32
        self.gate8 = Update(self.gate_cue + ctx, gate_width, 2, 1)
        self.gate4 = Update(self.gate_cue + ctx + 16, gate_width // 2, 1, 1)                                    

    @staticmethod
    def residual(q, ref):
        return (q - ref).abs().mean(1, keepdim=True)

    @staticmethod
    def round_trip(f, n):
        """|f(x) + f_other(x + f(x))| with the two directions stacked on the batch axis."""
        other = torch.cat((f[n:], f[:n]), 0)
        return (f + warp(other, f)).abs().sum(1, keepdim=True) / 4.0

    @staticmethod
    def spread(f):
        m = F.avg_pool2d(f, 3, 1, 1, count_include_pad=False)
        v = F.avg_pool2d(f * f, 3, 1, 1, count_include_pad=False) - m * m
        return (v.clamp_min(0).sum(1, keepdim=True) + 1e-4).sqrt() / 4.0                                      

    def explain(self, q, r, qc, rc, f, n):
        """How well flow f explains the pair: feature residual, colour residual, round-trip error, spread."""
        return torch.cat((self.residual(q, warp(r, f)), self.residual(qc, warp(rc, f)),
                          self.round_trip(f, n), self.spread(f)), 1)

    @staticmethod
    def colours(color_a, color_b, h, w):
        ca = F.interpolate(color_a, size=(h, w), mode="area")
        cb = F.interpolate(color_b, size=(h, w), mode="area")
        return torch.cat((cb, ca), 0), torch.cat((ca, cb), 0)

    @staticmethod
    def make_seed(mv_ba, mv_valid, h, w):
        """Game-MV seed for the seeded 1/64 level: B->A (invalid MV -> 0) and its inverse A->B, stacked like q/r."""
        sb = resize_flow(mv_ba * mv_valid, h, w)
        sa, ok = invert_flow(sb)
        return torch.cat((sb, sa * ok), 0)

    def of_forward(self, fa, fb, color_a, color_b, seed=None):
        """The OF network alone. Returns {level: {of, conf, occ, ctx}}; batch rows 0..n-1 = from B.
        seed (optional, (2n,2,h,w) px at that res, from make_seed): the coarsest level is evaluated twice with the
        same weights, around zero motion and around the seed (large camera motion is out of the zero search
        range); the two hypotheses are blended per pixel by softmax of their conf logits (out['seed_w'])."""
        n = color_a.shape[0]
        q = {lv: torch.cat((fb[lv], fa[lv]), 0) for lv in self.LEVELS}
        r = {lv: torch.cat((fa[lv], fb[lv]), 0) for lv in self.LEVELS}
        of = conf = occ = ctx = upmask = None
        out = {}
        if self.global_match:                                                                                       
            g = self.gm(q[32], r[32])
            of, conf, occ, ctx = g["of"], g["conf"], g["occ"], g["ctx"]
            out["gm"] = g
        for i, lv in enumerate(self.LEVELS):
            if self.global_match and lv == 64:
                continue
            if lv == 4 and getattr(self, "skip4", False):                                                       
                h, w = q[4].shape[-2:]
                of = convex_upsample_rep(of, upmask, 2) if upmask is not None else resize_flow(of, h, w)
                up = lambda x: F.interpolate(x, size=(h, w), mode="bilinear", align_corners=False)
                out[4] = {"of": of, "conf": up(conf), "occ": up(occ), "ctx": up(ctx), "beta": up(beta)}
                continue
            h, w = q[lv].shape[-2:]
            qc, rc = self.colours(color_a, color_b, h, w)
            if of is None and seed is not None:                                                                 
                hyp = []
                for init in (torch.zeros(2 * n, 2, h, w, device=q[lv].device, dtype=q[lv].dtype), resize_flow(seed, h, w)):
                    ref = warp(r[lv], init)
                    corr = correlation(q[lv], ref, self.radius[lv])
                    cue = torch.cat((self.explain(q[lv], r[lv], qc, rc, init, n), init / 16.0, torch.zeros_like(init)), 1)
                    o, _ = self.upd[str(lv)](torch.cat([q[lv], ref, pad_ch(corr, pad_c(corr.shape[1])), pad_ch(cue, self.of_cue)], 1))
                    hyp.append((init + o[:, 0:2] * 4.0, o))
                wsel = torch.softmax(torch.cat((hyp[0][1][:, 2:3], hyp[1][1][:, 2:3]), 1), 1)
                of = wsel[:, :1] * hyp[0][0] + wsel[:, 1:] * hyp[1][0]
                o = wsel[:, :1] * hyp[0][1] + wsel[:, 1:] * hyp[1][1]
                conf, occ, ctx, beta = o[:, 2:3], o[:, 3:4], o[:, 4:4 + self.ctx], o[:, 4 + self.ctx:5 + self.ctx]
                upmask = o[:, 5 + self.ctx:] if o.shape[1] > 5 + self.ctx else None
                out[lv] = {"of": of, "conf": conf, "occ": occ, "ctx": ctx, "beta": beta}
                out["seed_w"] = wsel[:, 1:]
                continue
            if of is None:
                of = torch.zeros(2 * n, 2, h, w, device=q[lv].device, dtype=q[lv].dtype)
                extra = torch.zeros_like(of)
            else:
                if upmask is not None and of.shape[-2] * 2 == h and of.shape[-1] * 2 == w:
                    of = convex_upsample_rep(of, upmask, 2)
                else:
                    of = resize_flow(of, h, w)
                up = lambda x: F.interpolate(x, size=(h, w), mode="bilinear", align_corners=False)
                ctx, extra = up(ctx), up(torch.cat((conf, occ), 1))
            ref = warp(r[lv], of)
            corr = correlation(q[lv], ref, self.radius[lv])
            cue = torch.cat((self.explain(q[lv], r[lv], qc, rc, of, n), of / 16.0, extra), 1)
            parts = [q[lv], ref, pad_ch(corr, pad_c(corr.shape[1])), pad_ch(cue, self.of_cue)]
            if i:
                parts.append(ctx)
            o, _ = self.upd[str(lv)](torch.cat(parts, 1))
            of = of + o[:, 0:2] * (4.0 if i == 0 else 1.0)
            conf, occ, ctx, beta = o[:, 2:3], o[:, 3:4], o[:, 4:4 + self.ctx], o[:, 4 + self.ctx:5 + self.ctx]
            upmask = o[:, 5 + self.ctx:] if o.shape[1] > 5 + self.ctx else None
            for _ in range(self.fine_iters - 1 if lv in (8, 4) and i else 0):
                ref = warp(r[lv], of)
                corr = correlation(q[lv], ref, self.radius[lv])
                cue = torch.cat((self.explain(q[lv], r[lv], qc, rc, of, n), of / 16.0, torch.cat((conf, occ), 1)), 1)
                o, _ = self.upd[str(lv)](torch.cat([q[lv], ref, pad_ch(corr, pad_c(corr.shape[1])), pad_ch(cue, self.of_cue), ctx], 1))
                of = of + o[:, 0:2]
                conf, occ, ctx, beta = o[:, 2:3], o[:, 3:4], o[:, 4:4 + self.ctx], o[:, 4 + self.ctx:5 + self.ctx]
                upmask = o[:, 5 + self.ctx:] if o.shape[1] > 5 + self.ctx else None
            if lv == 8 and getattr(self, "rec", None) is not None:
                cf = None
                if self.rec.teacher_feats:
                    cf = _teacher_corr_feats(color_a, color_b, q[8].shape[-2:])
                elif "m8" in fa:
                    qm, rm = torch.cat((fb["m8"], fa["m8"]), 0), torch.cat((fa["m8"], fb["m8"]), 0)
                    ab = getattr(self.rec, "ablate", ())                                            
                    if "teacher" in ab or "proj" in ab:
                        qm, rm = _teacher_corr_feats(color_a, color_b, q[8].shape[-2:])[:2]
                        if "proj" in ab:                                                                           
                            qm, rm = self.rec.proj(qm), self.rec.proj(rm)
                    if "shuffle" in ab:
                        g_ = torch.Generator(device=qm.device).manual_seed(0)
                        pm = torch.randperm(qm.shape[-1] * qm.shape[-2], generator=g_, device=qm.device)
                        qm = qm.flatten(2)[..., pm].view_as(qm); rm = rm.flatten(2)[..., pm].view_as(rm)
                    cf = (qm, rm, F.avg_pool2d(qm, 2), F.avg_pool2d(rm, 2))
                of = self.rec(of, q[8], r[8], q[16], r[16], ctx, cf)
            if self.deep16 and lv == 16:
                ref = warp(r[lv], of)
                d = self.deep(torch.cat((q[lv], ref, qc, warp(rc, of), of / 16.0, conf, occ, ctx), 1))
                of, conf, occ = of + d[:, 0:2], conf + d[:, 2:3], occ + d[:, 3:4]
                                                                                                                  
            out[lv] = {"of": of, "conf": conf, "occ": occ, "ctx": ctx, "beta": beta}
        if self.prop4:
            h, w = q[4].shape[-2:]
            qc, rc = self.colours(color_a, color_b, h, w)
            col = torch.cat((color_b, color_a), 0)
            x = torch.cat((q[4], F.pixel_unshuffle(col, 4), of / 16.0, conf, occ, ctx,
                           self.explain(q[4], r[4], qc, rc, of, n)), 1)
            of = self.prop(of, x)
            out[4]["of"] = of
        if self.up_full:
            col = torch.cat((color_b, color_a), 0)                                                       
            x = torch.cat((q[4], F.pixel_unshuffle(col, 4), of / 16.0, conf, occ, ctx), 1)
            out[4]["of_full"] = convex_upsample_rep(of, self.upf(x), 4)
        if self.pm_sel:                                                                                               
            H, W = color_a.shape[-2:]
            U = out[4]["of_full"] if "of_full" in out[4] else resize_flow(of, H, W)
            cf = F.interpolate(conf[:n], size=(H, W), mode="nearest")
            out[4]["of_full"] = torch.cat((self.pms(U[:n], color_b, color_a, cf), U[n:]), 0)
        return out

    def forward(self, fa, fb, mv_ba, mv_valid, color_a, color_b):
        """fa, fb: encoder pyramids. Returns 1/4 flows; batch rows 0..n-1 = from B, n..2n-1 = from A."""
        n = mv_ba.shape[0]
        seed = None
        if getattr(self, "seeded", False):
            h16, w16 = fa[16].shape[-2:]
            seed = self.make_seed(mv_ba, mv_valid, h16, w16)
        ofs = self.of_forward(fa, fb, color_a, color_b, seed)
        logit = None
        for lv in (8, 4):
            q = torch.cat((fb[lv], fa[lv]), 0)
            r = torch.cat((fa[lv], fb[lv]), 0)
            h, w = q.shape[-2:]
            qc, rc = self.colours(color_a, color_b, h, w)
            p_ba = resize_flow(mv_ba, h, w)                                               
            p_ab, inv_ok = invert_flow(p_ba)
            mvv = F.interpolate(mv_valid, size=(h, w), mode="area")
            usable = torch.cat((torch.ones_like(inv_ok), inv_ok), 0) * torch.cat((mvv, mvv), 0)
            prior = torch.cat((p_ba, p_ab), 0)
            o = ofs[lv]
            of = o["of"]
            cue = torch.cat((correlation(q, warp(r, prior), 1), self.explain(q, r, qc, rc, prior, n),
                             self.explain(q, r, qc, rc, of, n), usable,
                             (of - prior).norm(dim=1, keepdim=True) / 16.0, o["conf"], o["occ"]), 1)
            x = torch.cat((pad_ch(cue, self.gate_cue), o["ctx"]), 1)
            if logit is None:
                g, _ = self.gate8(x)
                logit = self.gate_bias + g
            else:
                prev = F.interpolate(logit, size=(h, w), mode="bilinear", align_corners=False)
                g, _ = self.gate4(torch.cat((x, pad_ch(prev / 4.0, 16)), 1))
                logit = prev + g
        c = torch.sigmoid(logit) * usable                                              
        if getattr(self, "force_c", None) is not None:                                                               
            c = torch.full_like(c, float(self.force_c)) * usable
        o4 = ofs[4]
        flow = c * prior + (1 - c) * o4["of"]
        full = o4.get("of_full")
        return {"f_ba": flow[:n], "f_ab": flow[n:], "of_ba": o4["of"][:n], "of_ab": o4["of"][n:],
                "of_ba_full": None if full is None else full[:n],
                "mv_ba": prior[:n], "mv_ab": prior[n:], "conf": o4["conf"], "occ": o4["occ"], "ctx": o4["ctx"],
                "gate": c, "of_levels": ofs}


                                                                                           
class TimeEmbed(nn.Module):
    """t -> per-channel FiLM (scale, shift). Tiny MLP on [t, 1-t, t(1-t), sin/cos(pi t)]."""
    def __init__(self, width):
        super().__init__()
        self.l1, self.l2 = nn.Linear(5, 64), nn.Linear(64, 2 * width)
        nn.init.zeros_(self.l2.weight)
        nn.init.zeros_(self.l2.bias)

    def forward(self, t):
        e = torch.stack((t, 1 - t, t * (1 - t), torch.sin(math.pi * t), torch.cos(math.pi * t)), -1)
        s, b = self.l2(F.silu(self.l1(e))).chunk(2, -1)
        return (1 + s)[..., None, None], b[..., None, None]


class TimeHead(nn.Module):
    """Generated frame at time t (option B: the network outputs the final colour).

    Initial t-flows at 1/4 from the 1/4 pair flows (linear motion; the net learns the rest):
      f_tA ~ -(1-t) t f_ab + t^2 f_ba       f_tB ~ (1-t)^2 f_ab - t(1-t) f_ba
    1/8 body (FiLM by t at the input, so t reshapes the trajectory correction itself): flow corrections and
    a visibility logit, added back at 1/4. Convex x4 upsample mask from the body upsampled to 1/4.
    full res: warp A and B with the upsampled flows, blend by visibility.
    1/4: colour residual on pixel_unshuffle(4) of [warped A, warped B, blend, vis].
    The 3x3 layers are lightweight gated convs (holes / disocclusions get suppressed by a 1-channel mask).
    Acceleration (QVI, Xu et al. 2019): with the previous pair's flow f_a,prev (A -> previous real frame,
    cached from the last pair), the quadratic term q = (f_ab + f_a,prev) / 2 is an input, so the
    trajectory at t = 1/3, 2/3 can bend. Without a previous pair q = 0 and the flag is 0.
    """
    def __init__(self, width=48, n_conv=2, ctx=32, c_ref=16):
        super().__init__()
        c8 = FrameEncoder.CH[8]
        cin = 2 * c8 + 4 + 2 + 2 + 2 * ctx + 3                                                                 
                                                                                
        self.cin = pad_c(cin)
        self.film = TimeEmbed(width)
        self.inp = conv(self.cin, width, 1)
        self.body = nn.ModuleList(LWGConv(width, width) for _ in range(n_conv))
        self.head = conv(width, 5, 1)                                                        
        self.up = conv(width, 9 * 16, 1)                                                         
        nn.init.zeros_(self.head.weight)
        nn.init.zeros_(self.head.bias)
        self.r_in = conv(160, c_ref, 1)                                           
        self.r_body = LWGConv(c_ref, c_ref)
        self.r_out = conv(c_ref, 48, 1)                                              
        nn.init.zeros_(self.r_out.weight)
        nn.init.zeros_(self.r_out.bias)

    def forward(self, t, pair, f8a, f8b, color_a, color_b, f_a_prev=None):
        n = color_a.shape[0]
        h8, w8 = f8a.shape[-2:]
        f_ab, f_ba = pair["f_ab"], pair["f_ba"]                          
        h4, w4 = f_ab.shape[-2:]
        tt = t.view(n, 1, 1, 1)
        f_ta = -(1 - tt) * tt * f_ab + tt * tt * f_ba
        f_tb = (1 - tt) ** 2 * f_ab - tt * (1 - tt) * f_ba
        f_ta8, f_tb8 = resize_flow(f_ta, h8, w8), resize_flow(f_tb, h8, w8)
        d8 = lambda x: F.interpolate(x, size=(h8, w8), mode="area")                             
        ctx = d8(torch.cat((pair["ctx"][:n], pair["ctx"][n:]), 1))
        if f_a_prev is None:
            accel = torch.zeros(n, 3, h8, w8, device=f8a.device, dtype=f8a.dtype)
        else:
            q = resize_flow(0.5 * (f_ab + resize_flow(f_a_prev, h4, w4)), h8, w8)
            accel = torch.cat((q / 16.0, torch.ones_like(q[:, :1])), 1)
        x = torch.cat((warp(f8a, f_ta8), warp(f8b, f_tb8), f_ta8 / 16.0, f_tb8 / 16.0,
                       d8(pair["conf"][:n]), d8(pair["occ"][:n]), d8(pair["gate"][:n]), tt.expand(n, 1, h8, w8), ctx,
                       accel), 1)
        x = pad_ch(x, self.cin)
        s, b = self.film(t)
        x = leaky(self.inp(x) * s + b)
        for c in self.body:
            x = x + c(x)
        o = self.head(x)
        f_ta = f_ta + resize_flow(o[:, 0:2], h4, w4)
        f_tb = f_tb + resize_flow(o[:, 2:4], h4, w4)
        m = self.up(F.interpolate(x, size=(h4, w4), mode="bilinear", align_corners=False))
        F_ta, F_tb = convex_upsample(f_ta, m, 4), convex_upsample(f_tb, m, 4)
        wa, wb = warp(color_a, F_ta), warp(color_b, F_tb)
        v = torch.sigmoid(F.interpolate(o[:, 4:5], scale_factor=8, mode="bilinear", align_corners=False))
        blend = v * wa + (1 - v) * wb
        r = F.pixel_unshuffle(torch.cat((wa, wb, blend, v), 1), 4)
        r = leaky(self.r_in(r))
        r = r + self.r_body(r)
        out = blend + F.pixel_shuffle(self.r_out(r), 4)
        return {"color": out.clamp(0, 1), "f_ta": F_ta, "f_tb": F_tb, "vis": v}


def build_mlof2(state_dict=None, **kw):
    """MLOF2 matching a checkpoint (global-match variant if its keys say so)."""
    if state_dict is not None:
        sd = state_dict.get("model", state_dict)
        kw.setdefault("global_match", any(k.startswith("pair.gm.") for k in sd))
        kw.setdefault("deep16", any(k.startswith("pair.deep.") for k in sd))
        hw = sd.get("pair.upd.32.head.weight")
        kw.setdefault("convex_up", hw is not None and hw.shape[0] > 5 + 32)
        kw.setdefault("up_full", any(k.startswith("pair.upf.") for k in sd))
        kw.setdefault("prop4", any(k.startswith("pair.prop.") for k in sd))
        kw.setdefault("pm_sel", any(k.startswith("pair.pms.") for k in sd))
        if "pair.fine_iters_buf" in sd:
            kw.setdefault("fine_iters", int(sd["pair.fine_iters_buf"].flatten()[0]))
        wd = [sd[f"pair.upd.{lv}.inp.weight"].shape[0] if f"pair.upd.{lv}.inp.weight" in sd else d
              for lv, d in zip(PairFlow.LEVELS, (256, 128, 96, 48, 32))]
        if wd != [256, 128, 96, 48, 32]:
            kw.setdefault("of_widths", wd)
        kw.setdefault("enc_deep", "enc.r4a.weight" in sd)
        kw.setdefault("enc_fpn", "enc.t8.weight" in sd)
        if "pair.rec.iters_buf" in sd:
            kw.setdefault("recur8", int(sd["pair.rec.iters_buf"].flatten()[0]))
            kw.setdefault("recur8_teacher", "pair.rec.tfeat_buf" in sd)
        kw.setdefault("enc_match", "enc.menc.out.weight" in sd)
        kw.setdefault("enc_match_ctx", "enc.menc.t16.weight" in sd)
        if "enc.menc.out.weight" in sd:
            kw.setdefault("match_c", tuple(int(sd[f"enc.menc.{k}.weight"].shape[0]) for k in ("s1", "s2", "s3")))
            kw.setdefault("match_out", int(sd["enc.menc.out.weight"].shape[0]))
        if "enc.e64b.weight" in sd and sd["enc.e64b.weight"].shape[0] != 256:
            kw.setdefault("c64", int(sd["enc.e64b.weight"].shape[0]))
        nb = len({k.split(".")[4] for k in sd if k.startswith("pair.upd.64.body.")})
        if nb and nb != 3:
            kw.setdefault("n64", nb)
    return MLOF2(**kw)


class MLOF2(nn.Module):
    def __init__(self, global_match=False, convex_up=False, deep16=False, up_full=False, prop4=False, pm_sel=False,
                 fine_iters=1, of_widths=None, enc_deep=False, enc_fpn=False, recur8=0, recur8_teacher=False,
                 enc_match=False, c64=None, n64=None, enc_match_ctx=False, match_c=None, match_out=64):
        super().__init__()
                                                                                                                      
                                                                                                                    
        ech = None if c64 is None else {**FrameEncoder.CH, 64: int(c64)}
        self.enc = FrameEncoder(deep_fine=enc_deep, fpn=enc_fpn, match=enc_match, ch=ech, match_ctx=enc_match_ctx,
                                match_c=match_c, match_out=match_out)
        wkw = {} if of_widths is None else {"widths": tuple(of_widths)}                             
        if c64 is not None:
            wkw["enc_ch"] = {64: int(c64)}
        if n64 is not None:
            n64 = int(n64)
            wkw["n_conv"] = (n64, 2, 2, 2, 1)
            wkw["dilations"] = ((1, 2, 1, 2)[:n64], (1, 2), (1, 2), (1, 2), None)
        self.pair = PairFlow(global_match=global_match, convex_up=convex_up, deep16=deep16, up_full=up_full, prop4=prop4,
                             pm_sel=pm_sel, fine_iters=fine_iters, recur8=recur8, recur8_teacher=recur8_teacher, **wkw)
        self.head = TimeHead()

    def forward(self, color_a, depth_a, color_b, depth_b, mv_ba, mv_valid, ts, feats_a=None, f_a_prev=None):
        """feats_a: cached encoder output of A. f_a_prev: the previous pair's f_ba (A -> previous real frame).
        Return pair["f_ba"] as the next call's f_a_prev (it is B -> A, i.e. the new A -> its previous)."""
        fa = feats_a or self.enc(color_a, depth_a)
        fb = self.enc(color_b, depth_b)
        pair = self.pair(fa, fb, mv_ba, mv_valid, color_a, color_b)
        frames = [self.head(t, pair, fa[8], fb[8], color_a, color_b, f_a_prev) for t in ts]
        return frames, pair, fb
