"""TAlignNet: moving a B->A flow to the frame at t with convolutions (MACs) and a handful of independent warps, instead
of nfru_head.invert_t's ~170 dependent gathers per pixel. Same interface as invert_t / TAlignKPN:
  (f_ba, depth_b, t, f_bp, valid) -> (to_A, to_B, hole) at full res.
The B pixel x lands at y = x + disp(x) (disp = its displacement to t, same trajectory as invert_t); its values there are
to_B = -disp(x), to_A = f(x) - disp(x). Coarse to fine on the t grid:
  1/32  B-grid features + the zero-gather guess (the values of the B pixel at y itself) -> convs -> residual. At 1/32 a
        large camera motion is a few px, inside the convs' reach, so no warp is needed here.
  1/16, 1/8, 1/4  upsample the estimate, ONE bilinear warp of that level's B-grid features to x = y + to_B, the arrival
        error |x + disp(x) - y| as an input, convs -> residual. The last level has two hypotheses (front / back layer at
        an edge) and a selection logit, so an edge picks one side instead of averaging the two motions.
  full  one nearest read of the exact source values at the arrived x plus the upsampled learned correction (the
        correction keeps what the net learned about the real trajectory, the read keeps edges sharp).
Trained like TAlignKPN (distill_talign.py --arch net): real positions on Spring (--gt 1), invert_t elsewhere. Own
design (coarse-to-fine refinement with warping, standard flow-network practice); no game MV in the OF."""
import torch
import torch.nn as nn
from torch.nn import functional as F
from talign_kpn import _disp, _grid, _pull_nearest
from model_v2 import warp

CH = {32: 48, 16: 40, 8: 32, 4: 32}                                               


def _pull_bilinear(img, pos):
    h, w = img.shape[-2:]
    gx = 2 * pos[:, 0] / max(w - 1, 1) - 1
    gy = 2 * pos[:, 1] / max(h - 1, 1) - 1
    return F.grid_sample(img, torch.stack((gx, gy), -1), mode="bilinear", padding_mode="border", align_corners=True)


def _block(cin, c, cout, n=3):
    layers, ci = [], cin
    for _ in range(n - 1):
        layers += [nn.Conv2d(ci, c, 3, 1, 1), nn.LeakyReLU(0.1)]
        ci = c
    layers.append(nn.Conv2d(ci, cout, 3, 1, 1))
    with torch.no_grad():
        layers[-1].weight.mul_(0.1); layers[-1].bias.zero_()
    return nn.Sequential(*layers)


class TAlignNet(nn.Module):
    SRC = 8                                                                            

    def __init__(self):
        super().__init__()
        enc_in = self.SRC + 1                     
        self.enc = nn.ModuleDict()
        prev = enc_in
        for s in (4, 8, 16, 32):                                                                                     
            st = 1 if s == 4 else 2
            self.enc[str(s)] = nn.Sequential(nn.Conv2d(prev, CH[s], 3, st, 1), nn.LeakyReLU(0.1),
                                             nn.Conv2d(CH[s], CH[s], 3, 1, 1), nn.LeakyReLU(0.1))
            prev = CH[s]
        self.dec = nn.ModuleDict()
        for s in (32, 16, 8, 4):
                                                                                                                  
            cin = CH[s] + 4 + 2 + 1 + (0 if s == 32 else 16)
            cout = (2 * 4 + 1 + 1) if s == 4 else 4 + 16                                                                 
            self.dec[str(s)] = _block(cin, CH[s], cout)
        self.aux = None                                                                                              

    def forward(self, f_ba, depth_b, t, f_bp=None, valid=None):
        n, _, H, W = f_ba.shape
        dev, dt = f_ba.device, f_ba.dtype
        disp = _disp(f_ba, t, f_bp)
        val = torch.ones_like(depth_b) if valid is None else (valid > 0.5).float()
        src_full = torch.cat((f_ba - disp, -disp, disp, depth_b, val), 1)                    
        tt = t.view(n, 1, 1, 1).to(dt)
                                                                                                                    
        srcs, feats = {}, {}
        x = None
        for s in (4, 8, 16, 32):
            h, w = H // s, W // s
            sv = F.interpolate(src_full, size=(h, w), mode="nearest")
            sv = torch.cat((sv[:, :6] / s, sv[:, 6:]), 1)
            srcs[s] = sv
            if s == 4:
                x = torch.cat((sv[:, :6] / 8.0, sv[:, 6:7] * 16.0, sv[:, 7:8], tt.expand(n, 1, h, w)), 1)
            x = self.enc[str(s)](x)
            feats[s] = x
        est = ctx = None
        for s in (32, 16, 8, 4):
            sv, fe = srcs[s], feats[s]
            h, w = sv.shape[-2:]
            grid = _grid(n, h, w, dev, dt)
            if est is None:
                est = sv[:, 0:4]                                                                                  
            else:
                est = F.interpolate(est, size=(h, w), mode="bilinear", align_corners=False) * 2
                ctx = F.interpolate(ctx, size=(h, w), mode="bilinear", align_corners=False)
                pos = grid + est[:, 2:4]                                                   
                wf = _pull_bilinear(fe, pos)
                wdisp = _pull_bilinear(sv[:, 4:6], pos)
            if s == 32:
                wf, wdisp = fe, sv[:, 4:6]
            arr = est[:, 2:4] + wdisp                                                                          
            inp = [wf, est / 8.0, arr.clamp(-8, 8) / 4.0, tt.expand(n, 1, h, w)] + ([] if ctx is None else [ctx])
            o = self.dec[str(s)](torch.cat(inp, 1))
            if s != 4:
                est = est + o[:, :4] * 4.0
                ctx = o[:, 4:]
            else:
                h1, h2 = est + o[:, 0:4] * 4.0, est + o[:, 4:8] * 4.0
                p = torch.sigmoid(o[:, 8:9] * 4.0)
                if self.training:
                    est = p * h1 + (1 - p) * h2
                else:
                    est = torch.where(p >= 0.5, h1, h2)
                hole_q = torch.sigmoid(o[:, 9:10] - 4.0)
                self.aux = (h1 * 4, h2 * 4) if self.training else None                              
                hyps_b = (h1[:, 2:4] * 4, h2[:, 2:4] * 4)                                                        
                                                                                 
        est = est * 4                                                                           
        pos_q = _grid(n, H // 4, W // 4, dev, dt) + est[:, 2:4] / 4
        ana_q = _pull_nearest(torch.cat((srcs[4][:, :4] * 4,), 1), pos_q)
        corr = est - ana_q
        up = lambda z: F.interpolate(z, size=(H, W), mode="bilinear", align_corners=False)
        to_b_up = up(est[:, 2:4])
        gfull = _grid(n, H, W, dev, dt)
        ana = _pull_nearest(src_full[:, :4], gfull + to_b_up)
        out = ana + up(corr)
        if getattr(self, "refine_iters", 0) > 0:                                                                      
            starts = [to_b_up] + ([up(h) for h in hyps_b] if getattr(self, "refine_hyps", False) else [])
                                                                                                                       
                                                                                   
            return self._refine(f_ba, disp, depth_b, val, gfull, starts)
        return out[:, 0:2], out[:, 2:4], up(hole_q)

    def _refine(self, f_ba, disp, depth_b, val, grid, starts):
        """Two starts at full res, x = y + to_B(net) and x = y - disp(y), `refine_iters` fixed-point steps each
        (x <- y - disp(x), nearest reads, as invert_t), converged starts compete by depth (smaller feature wins, as
        invert_t). Values = exact source values at the chosen x (invert_t's trajectory; the learned correction is
        dropped). Hole = neither start converged. Reads per pixel: 2 starts x (iters + 3)."""
        rel = lambda q: q - grid
        nn_ = lambda img, q: _pull_nearest(img, q)
        dd = disp.detach()
        best_q = best_d = first = None
        with torch.no_grad():
            qs = [grid - dd] + [grid + st.detach() for st in starts]                                           
            extra = getattr(self, "extra_starts", "")
            if "zero" in extra:                                                                                 
                qs.append(grid.clone())
            if "ring" in extra:                                                                                       
                n_ = 8 if "ring8" in extra else 4
                dirs = ((0, 8), (0, -8), (8, 0), (-8, 0), (8, 8), (8, -8), (-8, 8), (-8, -8))[:n_]
                for dy, dx in dirs:
                    o = torch.tensor([dx, dy], device=grid.device, dtype=grid.dtype).view(1, 2, 1, 1)
                    qs.append(grid - nn_(dd, grid + o))
            for i, q in enumerate(qs):
                for _ in range(getattr(self, "fallback_iters", 6) if i == 0 else self.refine_iters):
                    q = grid - nn_(dd, q)
                res = (q + nn_(dd, q) - grid).abs().amax(1, keepdim=True)
                H, W = grid.shape[-2:]
                inb = (q[:, :1] >= 0) & (q[:, :1] <= W - 1) & (q[:, 1:] >= 0) & (q[:, 1:] <= H - 1)
                good = (res <= 1.0) & inb & (nn_(val, q) > 0.5)
                dq = torch.where(good, nn_(depth_b.detach(), q), torch.full_like(res, float("inf")))
                if first is None:
                    first, best_q, best_d = q, q, dq
                else:
                    take = dq < best_d
                    best_q, best_d = torch.where(take, q, best_q), torch.where(take, dq, best_d)
            hole = torch.isinf(best_d)
            q = torch.where(hole, first, best_q)
        f_x, d_x = warp(f_ba, q - grid), warp(disp, q - grid)                                                        
        return f_x - d_x, -d_x, hole.float()                                                                     
