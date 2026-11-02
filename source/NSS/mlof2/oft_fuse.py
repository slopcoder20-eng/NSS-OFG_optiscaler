"""2-way fusion for the OFT path (2026-11-01 design step 1+2): OF frame (OFTNet 3 blocks + LK) vs the MV candidates.

Candidates at t: OF frame (v * warp(A, f_tA) + (1 - v) * warp(B, f_tB), with an ANALYTIC off-frame rule: a side whose
t-flow leaves the frame gets weight 0 and the other side is renormalised -> no black band on fast turns), MV->A, MV->B
(game MV moved to t by invert_t, nfru_head). FuseNet (small, learned): inputs at 1/2 of the frame = 3 candidate
colours 9, |OF - MVA|, |OF - MVB|, |MVA - MVB| 3, |f_tA - m_A| / 16 1, off-frame flags OF A/B, MV A/B 4, MV hole 1,
OF mask 1, t 1 = 20 ch -> 2 stride-2 convs (internal 1/8), 2 ResC (32 ch), out 3 x 16 -> pixel_shuffle 4 (1/2) ->
bilinear to full -> softmax over the 3 candidates. Last layer zero + bias (OF) -> starts at the OF frame.
The blend itself is a shader operation; the net only decides."""
import torch
from torch import nn
from torch.nn import functional as F
from model_v2 import warp, resize_flow
from oft_block import ResC
import nfru_head


def off_frame(fl):
    n, _, H, W = fl.shape
    yy, xx = torch.meshgrid(torch.arange(H, device=fl.device), torch.arange(W, device=fl.device), indexing="ij")
    qx, qy = xx[None] + fl[:, 0], yy[None] + fl[:, 1]
    return ((qx < -0.5) | (qx > W - 0.5) | (qy < -0.5) | (qy > H - 0.5))[:, None].float()


def of_frame(color_a, color_b, f_ta, f_tb, vis):
    oa, ob = off_frame(f_ta), off_frame(f_tb)
    wa_, wb_ = vis * (1 - oa), (1 - vis) * (1 - ob)
    s = wa_ + wb_
    both = (s < 1e-6).float()
    wa_, wb_ = torch.where(both > 0.5, vis, wa_ / s.clamp_min(1e-6)), torch.where(both > 0.5, 1 - vis, wb_ / s.clamp_min(1e-6))
    return (wa_ * warp(color_a, f_ta) + wb_ * warp(color_b, f_tb)).clamp(0, 1), oa, ob


def mv_candidates(color_a, color_b, depth_b, mv_ba, mv_valid, t):
    ma, mb, hole = nfru_head.invert_t(mv_ba, depth_b, t, None, mv_valid)
    oob_b = nfru_head.LAST_OOB[0]
    return warp(color_a, ma), warp(color_b, mb), ma, mb, hole, off_frame(ma), oob_b


class FuseNet(nn.Module):
    def __init__(self, c=32, n=2, cin=20):
        super().__init__()
                                                                                                                       
                                                                                                                     
                                                                        
        self.CIN = cin
        self.d1 = nn.Conv2d(self.CIN, c // 2, 3, 2, 1)
        self.d2 = nn.Conv2d(c // 2, c, 3, 2, 1)
        self.body = nn.Sequential(*[ResC(c) for _ in range(n)])
        self.out = nn.Conv2d(c, 3 * 16, 3, 1, 1)
        with torch.no_grad():
            self.out.weight.zero_(); self.out.bias.zero_()
            self.out.bias.view(3, 16)[0] += 4.0                                                                         

    def forward(self, t, of_col, mva, mvb, f_ta, ma, oa, ob, offma, offmb, hole, vis, d_of=None):
        n, _, H, W = of_col.shape
        dn = lambda z: F.interpolate(z, size=(H // 2, W // 2), mode="area")
        d = lambda x, y: (x - y).abs().mean(1, keepdim=True) * 4
        x = torch.cat((of_col, mva, mvb, d(of_col, mva), d(of_col, mvb), d(mva, mvb),
                       ((f_ta - ma).norm(dim=1, keepdim=True) / 16).clamp(max=4), oa, ob, offma, offmb, hole, vis,
                       t.view(n, 1, 1, 1).expand(n, 1, H, W)), 1)
        if self.CIN == 21:
            x = torch.cat((x, d_of), 1)
        y = F.leaky_relu(self.d2(F.leaky_relu(self.d1(dn(x)), 0.1)), 0.1)
        y = F.leaky_relu(self.body(y), 0.1)
        lg = F.pixel_shuffle(self.out(y), 4)
        lg = F.interpolate(lg, size=(H, W), mode="bilinear", align_corners=False)
        w = lg.softmax(1)
        cand = torch.stack((of_col, mva, mvb), 1)
        return (w[:, :, None] * cand).sum(1).clamp(0, 1), w, cand
