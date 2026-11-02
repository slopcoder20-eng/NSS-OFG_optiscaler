"""OF t-block (2026-10-31, future architecture step 1): the OF branch makes its OWN generated frame at time t.

Measured reason (diag_rife_synth.py, 5 Spring foliage crops, MFG 4): our OF B->A + invert_t + 1/4 avg-pooled 4-candidate
head 7.29 / 0.697 (foliage error / sharpness); RIFE's t-flows + our head 6.29 / 0.756; RIFE's t-flows + RIFE's mask with
our own warp 6.02 / 0.915; RIFE 5.93 / 0.910. -> flows at t directly (error) and a full-res learned mask (sharpness).
The old TimeHead (model_v2) had the idea but one 1/8 pass on warped FEATURES, a bilinear x8 mask and the MV-fused flow:
val 18.5 dB vs 26.2 for the candidate head.

OFTNet: no MV input (the OF stays the MV's second opinion). Init: linear t-flows from the PURE pair OF (of_ab / of_ba,
as TimeHead): f_tA = -(1-t) t f_ab + t^2 f_ba, f_tB = (1-t)^2 f_ab - t(1-t) f_ba. Then 3 blocks at 1/4, 1/2, 1 of the
frame (like RIFE's IFBlocks): each re-warps A and B with the current flows at its scale, reads [warped A, warped B,
|wA - wB|, flows / 16, mask logit, t] through two stride-2 convs (internal 1/16, 1/8, 1/4), N residual 3x3, and writes
(d f_tA, d f_tB, d mask) through a learned x4 pixel_shuffle (the last block = full-res mask and flow detail).
Output: v * warp(A, F_tA) + (1 - v) * warp(B, F_tB), v = sigmoid(mask). Zero-init outputs: starts at the linear
init with v = 0.5."""
import torch
from torch import nn
from torch.nn import functional as F
from model_v2 import warp, resize_flow, correlation


class ResC(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.a = nn.Conv2d(c, c, 3, 1, 1)
        self.b = nn.Conv2d(c, c, 3, 1, 1)

    def forward(self, x):
        return x + self.b(F.leaky_relu(self.a(x), 0.1))


class OFTBlk(nn.Module):
    CIN = 3 + 3 + 1 + 4 + 1 + 1

    def __init__(self, c, n, corr_ch=0):
        super().__init__()
        self.inj = nn.Conv2d(corr_ch, c, 1) if corr_ch else None                                         
        self.d1 = nn.Conv2d(self.CIN, c // 2, 3, 2, 1)
        self.d2 = nn.Conv2d(c // 2, c, 3, 2, 1)
        self.body = nn.Sequential(*[ResC(c) for _ in range(n)])
        self.out = nn.Conv2d(c, 5 * 16, 3, 1, 1)
        with torch.no_grad():
            self.out.weight.zero_(); self.out.bias.zero_()

    def forward(self, x, cv=None):
        y = self.d2(F.leaky_relu(self.d1(x), 0.1))
        if self.inj is not None and cv is not None:
            y = y + self.inj(cv)
        y = F.leaky_relu(self.body(F.leaky_relu(y, 0.1)), 0.1)
        return F.pixel_shuffle(self.out(y), 4)


class OFTNet(nn.Module):
    R = 3

    def __init__(self, widths=(96, 64, 48), n=(3, 3, 3), corr=False):
        super().__init__()
                                                                                                                       
                                                                                                                  
                                                                                                                      
                                                        
        self.corr = bool(corr)
        if self.corr:
            self.feat = nn.Sequential(nn.Conv2d(3, 16, 3, 2, 1), nn.LeakyReLU(0.1), nn.Conv2d(16, 32, 3, 2, 1),
                                      nn.LeakyReLU(0.1), nn.Conv2d(32, 32, 3, 1, 1))
                                                                                                                 
                                                                                
        self.SCALES = (8, 4, 2, 1)[-len(widths):]
        cc = (2 * self.R + 1) ** 2
        self.blocks = nn.ModuleList(OFTBlk(c, k, cc if (self.corr and s <= 2) else 0)
                                    for c, k, s in zip(widths, n, self.SCALES))

    def forward(self, t, color_a, color_b, of_ab, of_ba, init=None):
        """t (n,); colours (n,3,H,W), H, W multiples of 16; of_ab / of_ba: pure OF at any resolution (px of that grid).
        Returns color, f_ta, f_tb (full res px), vis (sigmoid mask)."""
        n, _, H, W = color_a.shape
        tt = t.view(n, 1, 1, 1)
        fab, fba = resize_flow(of_ab, H, W), resize_flow(of_ba, H, W)
        f_ta = -(1 - tt) * tt * fab + tt * tt * fba
        f_tb = (1 - tt) ** 2 * fab - tt * (1 - tt) * fba
        if init is not None:                                                                              
            f_ta, f_tb = init
        self.last_init = (f_ta, f_tb)
        mask = torch.zeros(n, 1, H, W, device=color_a.device, dtype=color_a.dtype)
        if self.corr:
            fea, feb = self.feat(color_a), self.feat(color_b)
            h4, w4 = fea.shape[-2:]
        for blk, s in zip(self.blocks, self.SCALES):
            h, w = H // s, W // s
            a_s = color_a if s == 1 else F.interpolate(color_a, size=(h, w), mode="area")
            b_s = color_b if s == 1 else F.interpolate(color_b, size=(h, w), mode="area")
            fa_s = f_ta if s == 1 else resize_flow(f_ta, h, w)
            fb_s = f_tb if s == 1 else resize_flow(f_tb, h, w)
            m_s = mask if s == 1 else F.interpolate(mask, size=(h, w), mode="area")
            wa, wb = warp(a_s, fa_s), warp(b_s, fb_s)
            x = torch.cat((wa, wb, (wa - wb).abs().mean(1, keepdim=True) * 4, fa_s / 16.0, fb_s / 16.0, m_s / 4.0,
                           tt.expand(n, 1, h, w)), 1)
            cv = None
            if blk.inj is not None:
                cv = correlation(warp(fea, resize_flow(f_ta, h4, w4)), warp(feb, resize_flow(f_tb, h4, w4)), self.R)
                if s == 2:
                    cv = F.avg_pool2d(cv, 2)
            d = blk(x, cv)
            if s == 1:
                f_ta, f_tb, mask = f_ta + d[:, 0:2], f_tb + d[:, 2:4], mask + d[:, 4:5]
            else:
                f_ta = f_ta + resize_flow(d[:, 0:2], H, W)
                f_tb = f_tb + resize_flow(d[:, 2:4], H, W)
                mask = mask + F.interpolate(d[:, 4:5], size=(H, W), mode="bilinear", align_corners=False)
        v = torch.sigmoid(mask)
        wa, wb = warp(color_a, f_ta), warp(color_b, f_tb)
        return {"color": (v * wa + (1 - v) * wb).clamp(0, 1), "f_ta": f_ta, "f_tb": f_tb, "vis": v, "wa": wa, "wb": wb}


def gmac(net, H=1088, W=1920):
    tot = 0
    for blk, s in zip(net.blocks, net.SCALES):
        h, w = H // s, W // s
        c = blk.d2.out_channels
        tot += (h // 2) * (w // 2) * blk.CIN * (c // 2) * 9 + (h // 4) * (w // 4) * (c // 2) * c * 9
        tot += (h // 4) * (w // 4) * (len(blk.body) * 2 * c * c * 9 + c * 80 * 9)
        if blk.inj is not None:
            tot += (h // 4) * (w // 4) * blk.inj.in_channels * c
    if getattr(net, "corr", False):
        h4, w4 = H // 4, W // 4
        tot += 2 * (h4 * 2 * w4 * 2 * 3 * 16 * 9 + h4 * w4 * (16 * 32 * 9 + 32 * 32 * 9))                                   
        tot += sum(h4 * w4 * 49 * 32 for b in net.blocks if b.inj is not None)
    return tot / 1e9


def lap_l1(x, y, levels=4):
    """Laplacian pyramid L1 (RIFE's reconstruction loss idea: high frequencies weigh as much as the low ones)."""
    loss = 0.0
    for _ in range(levels):
        xd, yd = F.avg_pool2d(x, 2), F.avg_pool2d(y, 2)
        loss = loss + (x - F.interpolate(xd, scale_factor=2, mode="bilinear", align_corners=False)
                       - (y - F.interpolate(yd, scale_factor=2, mode="bilinear", align_corners=False))).abs().mean()
        x, y = xd, yd
    return loss + (x - y).abs().mean()


if __name__ == "__main__":
    net = OFTNet()
    print("params", sum(p.numel() for p in net.parameters()), "GMAC at 1920x1088 per t", round(gmac(net), 2))
    x = torch.rand(1, 3, 64, 96)
    o = net(torch.tensor([0.5]), x, x, torch.zeros(1, 2, 16, 24), torch.zeros(1, 2, 16, 24))
    print({k: tuple(v.shape) for k, v in o.items()}, float((o["color"] - x).abs().max()))
