"""Online screen-space vignette estimate from the frame-generation inputs only (the two real frames and the game MV).
A world point seen at x in B and at x + mv in A: log B(x) - log A(x + mv) = lv(x) - lv(x + mv) for a separable
log-vignette lv(x, y) = lx(col) + ly(row) on a coarse grid. Each frame adds the normal equations of a random sample of
matched pixels (valid MV, both ends on screen, not the viewmodel, not dark, small photometric outliers dropped) to a
decayed accumulator; a small smoothness prior keeps it stable while few pixels have moved (a static camera gives no
information: then the estimate just stays where it was). The overall scale is free (it cancels: colours are divided by V
before interpolation and the output is multiplied by it), so the centre is anchored at 1."""
import torch
from torch.nn import functional as F


class VignetteOnline:
    def __init__(self, nx=24, ny=12, decay=0.85, smooth=200.0, prior=20.0, n_samp=65536, min_px=30.0, quad4=False, pw=2.0, tie_y=False, clamp=True, ridge=0.0):
        self.clamp, self.ridge = clamp, ridge
        self.quad4, self.pw, self.tie_y = quad4, pw, tie_y                                                                 
                                                                                                                        
        self.nx, self.ny, self.decay, self.smooth, self.prior, self.n_samp, self.min_px = nx, ny, decay, smooth, prior, n_samp, min_px
        self.ata = self.atb = None
        self.lv = None

    def _onehot(self, x, n, size):
        return F.one_hot((x * n / size).long().clamp(0, n - 1), n).float()

    @torch.no_grad()
    def update(self, a, b, mv, valid, skip=None):
        """a, b (1,3,H,W) colours in [0,1]; mv (1,2,H,W) B->A in px; valid (1,1,H,W); skip (1,1,H,W) bool to leave out."""
        dev = a.device
        H, W = a.shape[-2:]
        P = (3 if self.tie_y else 4) if self.quad4 else self.nx + self.ny
        if self.ata is None:
            self.ata = torch.zeros(P, P, device=dev, dtype=torch.float64); self.atb = torch.zeros(P, device=dev, dtype=torch.float64)
        yy, xx = torch.meshgrid(torch.arange(H, device=dev, dtype=torch.float32), torch.arange(W, device=dev, dtype=torch.float32), indexing="ij")
        sx, sy = xx + mv[0, 0], yy + mv[0, 1]
        g = torch.stack((2 * sx / (W - 1) - 1, 2 * sy / (H - 1) - 1), -1)[None]
        lum = lambda c: (c * torch.tensor([.299, .587, .114], device=dev).view(1, 3, 1, 1)).sum(1, keepdim=True)
        la = F.grid_sample(lum(a), g, mode="bilinear", align_corners=True)[0, 0]
        lb = lum(b)[0, 0]
        ok = (valid[0, 0] > 0.5) & (sx >= 1) & (sx <= W - 2) & (sy >= 1) & (sy <= H - 2) & (la > 0.03) & (lb > 0.03)
        ok &= torch.hypot(mv[0, 0], mv[0, 1]) > self.min_px
        if skip is not None:
            ok &= ~skip[0, 0]
        idx = ok.flatten().nonzero()[:, 0]
        self.ata *= self.decay; self.atb *= self.decay
        if idx.numel() > 64:
            idx = idx[torch.randperm(idx.numel(), device=dev)[:self.n_samp]]
            r = (torch.log(lb.flatten()[idx]) - torch.log(la.flatten()[idx]))
            keep = r.abs() < 0.5
            idx, r = idx[keep], r[keep]
            X, Y, SX, SY = (t.flatten()[idx] for t in (xx, yy, sx, sy))
            if self.quad4:
                R = (self._quad(X, Y, W, H) - self._quad(SX, SY, W, H)).double()
            else:
                R = torch.cat((self._onehot(X, self.nx, W) - self._onehot(SX, self.nx, W),
                               self._onehot(Y, self.ny, H) - self._onehot(SY, self.ny, H)), 1).double()
            s = 1e4 / max(idx.numel(), 1)                                                                               
            self.ata += s * (R.T @ R); self.atb += s * (R.T @ r.double())
        if self.quad4:
                                                                                                                   
                                                                                                                     
                                                                                                                 
                                                                                                                     
                                                                                                                      
            r_ = max(self.ridge, 1e-6 * float(torch.diagonal(self.ata).sum()) / P, 1e-9)
            A_ = self.ata + r_ * torch.eye(P, device=dev, dtype=torch.float64)
            free = torch.ones(P, dtype=torch.bool, device=dev)
            for _ in range(P):
                lv = torch.zeros(P, device=dev, dtype=torch.float64)
                fi = free.nonzero()[:, 0]
                if fi.numel():
                    lv[fi] = torch.linalg.solve(A_[fi][:, fi], self.atb[fi])
                if not self.clamp or not bool((lv[free] > 0).any()):
                    break
                free &= ~(lv > 0)
            self.lv = lv.float()
            self.info = torch.diagonal(self.ata).float()
            return int(idx.numel()) if idx.numel() > 64 else 0
                                                                                         
        D = lambda n: torch.diff(torch.eye(n, device=dev, dtype=torch.float64), 2, 0)
        reg = torch.zeros(P, P, device=dev, dtype=torch.float64)
        reg[:self.nx, :self.nx] += self.smooth * D(self.nx).T @ D(self.nx)
        reg[self.nx:, self.nx:] += self.smooth * D(self.ny).T @ D(self.ny)
        reg += self.prior * 1e-3 * torch.eye(P, device=dev, dtype=torch.float64)
        c = torch.zeros(P, device=dev, dtype=torch.float64)
        c[self.nx // 2 - 1:self.nx // 2 + 1] = 1; reg += 1e3 * torch.outer(c, c)
        c = torch.zeros(P, device=dev, dtype=torch.float64)
        c[self.nx + self.ny // 2 - 1:self.nx + self.ny // 2 + 1] = 1; reg += 1e3 * torch.outer(c, c)
        self.lv = torch.linalg.solve(self.ata + reg, self.atb).float()
        return int(idx.numel())

    def _quad(self, X, Y, W, H):
        dx = (2 * X / (W - 1) - 1).clamp(-1, 1); dy = (2 * Y / (H - 1) - 1).clamp(-1, 1)
        fx, fy = dx.abs() ** self.pw, dy.abs() ** self.pw
        if self.tie_y:
            return torch.stack((fx * (dx < 0), fx * (dx >= 0), fy), 1).float()
        return torch.stack((fx * (dx < 0), fx * (dx >= 0), fy * (dy < 0), fy * (dy >= 0)), 1).float()

    def map(self, H, W):
        dev = self.lv.device
        if self.quad4:
            yy, xx = torch.meshgrid(torch.arange(H, device=dev, dtype=torch.float32), torch.arange(W, device=dev, dtype=torch.float32), indexing="ij")
            V = torch.exp((self._quad(xx.flatten(), yy.flatten(), W, H) @ self.lv).view(H, W))
            return (V / V.max())[None, None]
        lx = F.interpolate(self.lv[None, None, :self.nx], size=W, mode="linear", align_corners=False)[0, 0]
        ly = F.interpolate(self.lv[None, None, self.nx:], size=H, mode="linear", align_corners=False)[0, 0]
        V = torch.exp(ly[:, None] + lx[None, :])
        return (V / V.max())[None, None]
