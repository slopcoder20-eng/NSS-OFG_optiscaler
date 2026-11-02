"""Off-frame trailing band (content only in A): a small net that corrects the camera t->A flow there.
Base: the A-grid camera candidate with the camera at t from a quadratic through P (previous real), A, B (TRAIL_A=camq,
training free). The net adds a residual flow, mainly for moving objects: its key input is the object motion of A
(the game MV A->P minus the camera-only A->P flow), sampled at the camera source. Runs at half resolution on band
tiles only (engine: invert_t's off-frame flag -> tile list -> indirect dispatch). Never sees the OF.
Target: the capture's own MV of the frame at t chained to A (NFRU: every frame is rendered).
Shared by band_data.py (training tiles) and eval_nfru_mfg.py (TRAIL_NET=<ckpt>): one definition of the inputs."""
import torch
from torch import nn
from torch.nn import functional as F
from model_v2 import warp

FLOW_NORM = 32.0                                                 
IN_CH = 13


def quad_vp(vp_p, vp_a, vp_b, t):
    """ViewProj at t (A = 0, B = 1) from P (-1), A, B: Lagrange, element-wise (as the linear clip-lerp)."""
    return vp_p * (t * (t - 1) / 2) + vp_a * ((1 - t) * (1 + t)) + vp_b * (t * (t + 1) / 2)


def cam_offset(depth_raw, vp_a, vp_t):
    """For every A pixel (1080p grid): its offset to the position under ViewProj vp_t (static content).
    depth_raw (H,W) NDC depth of A as the NFRU file stores it (NDC z = 1 - d), vp_* already transposed to column
    vectors (file ViewProj .T), y up. Returns (1,2,H,W) px."""
    H, W = depth_raw.shape
    dev = depth_raw.device
    yy, xx = torch.meshgrid(torch.arange(H, device=dev, dtype=torch.float64), torch.arange(W, device=dev, dtype=torch.float64), indexing="ij")
    d = depth_raw.double()
    nx = (xx + 0.5) / W * 2 - 1; ny = -((yy + 0.5) / H * 2 - 1)
    clip = torch.stack((nx, ny, 1 - d, torch.ones_like(d)), -1)
    c = (clip @ torch.linalg.inv(vp_a.double())) @ vp_t.double()
    p = c[..., :2] / c[..., 3:4]
    px = (p[..., 0] + 1) / 2 * W - 0.5; py = (-p[..., 1] + 1) / 2 * H - 0.5
    return torch.stack((px - xx, py - yy), 0)[None].float()


def band_inputs(col_a, dep_a, to_cam, hole_cam, obj_a, mvap_a, t, trail):
    """Full-res (1,c,H,W) tensors -> the net input at half res (1,13,H/2,W/2).
    col_a: A colour (display), dep_a: A depth feature, to_cam / hole_cam: camq t->A flow at t and its hole,
    obj_a: object motion of A (MV A->P - camera A->P, A grid), mvap_a: MV A->P (A grid), trail: band mask at t."""
    n, _, H, W = col_a.shape
    c = warp(col_a, to_cam)
    d = warp(dep_a, to_cam)
    o = warp(obj_a, to_cam)
    m = warp(mvap_a, to_cam)
    h2 = lambda x: F.avg_pool2d(x, 2)
    yy, xx = torch.meshgrid(torch.linspace(-1, 1, H // 2, device=c.device), torch.linspace(-1, 1, W // 2, device=c.device), indexing="ij")
    pos = torch.stack((xx, yy), 0)[None].expand(n, 2, H // 2, W // 2)
    tt = torch.as_tensor(t, device=c.device, dtype=c.dtype).view(-1, 1, 1, 1).expand(n, 1, H // 2, W // 2)
    return torch.cat((h2(c), h2(d), h2(hole_cam), h2(o) / (2 * FLOW_NORM), h2(m) / (2 * FLOW_NORM), tt, h2(trail.float()), pos), 1)


def _blk(ci, co):
    return nn.Sequential(nn.Conv2d(ci, co, 3, 1, 1), nn.LeakyReLU(0.1), nn.Conv2d(co, co, 3, 1, 1), nn.LeakyReLU(0.1))


class BandNet(nn.Module):
    """3-level U-Net at half res, 16-multiple channels (WMMA tiles). Output: residual flow (half-res px / FLOW_NORM)."""
    def __init__(self, c=(32, 48, 64)):
        super().__init__()
        self.e0 = _blk(IN_CH, c[0])
        self.e1 = _blk(c[0], c[1])
        self.e2 = _blk(c[1], c[2])
        self.d1 = _blk(c[2] + c[1], c[1])
        self.d0 = _blk(c[1] + c[0], c[0])
        self.out = nn.Conv2d(c[0], 2, 3, 1, 1)
        nn.init.zeros_(self.out.weight); nn.init.zeros_(self.out.bias)                            

    def forward(self, x):
        H, W = x.shape[-2:]
        ph, pw = (-H) % 4, (-W) % 4
        if ph or pw:
            x = F.pad(x, (0, pw, 0, ph), mode="replicate")
        a = self.e0(x)
        b = self.e1(F.avg_pool2d(a, 2))
        c = self.e2(F.avg_pool2d(b, 2))
        b = self.d1(torch.cat((F.interpolate(c, scale_factor=2, mode="bilinear", align_corners=False), b), 1))
        a = self.d0(torch.cat((F.interpolate(b, scale_factor=2, mode="bilinear", align_corners=False), a), 1))
        return self.out(a)[..., :H, :W]


def apply_residual(net, x, to_cam):
    """Half-res residual -> full-res corrected t->A flow."""
    r = net(x) * FLOW_NORM * 2                                                                        
    return to_cam + F.interpolate(r, size=to_cam.shape[-2:], mode="bilinear", align_corners=False)
