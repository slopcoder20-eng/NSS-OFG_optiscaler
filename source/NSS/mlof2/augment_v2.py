"""MLOF2 synthetic augmentation on a GPU batch from data_v2 (in place). Every layer is drawn consistently in all
four frames P (t=-1), A (0), G (t), B (1), assuming constant velocity, so the interpolation target stays right.

  objects  : textured ellipses moving with their own velocity, closer than the scene. The game MV inside
             them is one of: background MV (wrong), zero (wrong), correct, missing. Their true flow is known
             -> app_flow_ba / app_valid (appearance-flow GT for the OF) and geo_flow_ba.
  shadows  : soft multiplicative darkening that moves, game MV untouched (the ground's). No flow GT: one flow
             cannot describe ground texture and shadow at once; the colour losses and the relative gate target
             handle it.
  glints   : soft additive layer (reflection / highlight) that moves, game MV untouched. No flow GT.
  MV damage: holes (missing MV), MV copied from elsewhere (valid but wrong), global scale error + noise.
Returns masks for logging: mv_wrong (MV known to be wrong or missing), shadow, glint, object.
"""
import math
import os
import sys
import torch
from torch.nn import functional as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import warp


def ellipse(s, device, soft=0.0):
    yy, xx = torch.meshgrid(torch.arange(s, device=device), torch.arange(s, device=device), indexing="ij")
    r = (((yy - s / 2 + 0.5) / (s / 2)) ** 2 + ((xx - s / 2 + 0.5) / (s / 2)) ** 2).sqrt()
    if soft <= 0:
        return (r <= 1).float()
    return ((1 - r) / soft).clamp(0, 1)


def place(dst, patch, mask, y, x, mode):
    """Composite patch (C,s,s) with mask (1,s,s) at integer (y,x) into dst (C,H,W), clipped to the image."""
    C, H, W = dst.shape
    s = mask.shape[-1]
    y0, x0, y1, x1 = max(y, 0), max(x, 0), min(y + s, H), min(x + s, W)
    if y0 >= y1 or x0 >= x1:
        return
    py, px = y0 - y, x0 - x
    m = mask[:, py:py + y1 - y0, px:px + x1 - x0]
    reg = dst[:, y0:y1, x0:x1]
    if mode == "over":
        p = patch[:, py:py + y1 - y0, px:px + x1 - x0]
        dst[:, y0:y1, x0:x1] = m * p + (1 - m) * reg
    elif mode == "mul":
        dst[:, y0:y1, x0:x1] = reg * (1 - m * (1 - patch))                                          
    elif mode == "add":
        p = patch[:, py:py + y1 - y0, px:px + x1 - x0]
        dst[:, y0:y1, x0:x1] = (reg + m * p).clamp(0, 1)
    elif mode == "set":
        p = patch[:, py:py + y1 - y0, px:px + x1 - x0] if patch.dim() == 3 and patch.shape[-1] == s else patch
        dst[:, y0:y1, x0:x1] = torch.where(m > 0.5, p.expand_as(reg), reg)


FRAMES = (("color_p", -1.0), ("color_a", 0.0), ("color_g", None), ("color_b", 1.0))


def positions(y, x, dy, dx, t):
    """Top-left per frame for a layer at (y, x) in A moving (dy, dx) per span."""
    out = {}
    for key, tt in FRAMES:
        tt = t if tt is None else tt
        out[key] = (int(round(y + tt * dy)), int(round(x + tt * dx)))
    return out


def _rot(yaw, pitch, dev):
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    ry = torch.tensor([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], device=dev)
    rx = torch.tensor([[1, 0, 0], [0, cp, -sp], [0, sp, cp]], device=dev)
    return ry @ rx


def _apply_h(h, S, dev):
    """Homography h (3x3) on the pixel-centre grid -> (2,S,S) mapped positions and (1,S,S) inside mask."""
    y, x = torch.meshgrid(torch.arange(S, device=dev, dtype=torch.float32),
                          torch.arange(S, device=dev, dtype=torch.float32), indexing="ij")
    p = torch.stack((x, y, torch.ones_like(x)), 0).view(3, -1)
    q = h @ p
    q = (q[:2] / q[2:].clamp_min(1e-6)).view(2, S, S)
    inside = ((q[0] >= -0.5) & (q[0] <= S - 0.5) & (q[1] >= -0.5) & (q[1] <= S - 0.5)).float()[None]
    return q, inside


def pan_rotate(batch, rng, size, max_frac=0.45):
    """Large, fast camera turns (in place, resizes the batch to size x size).

    The real window is upscaled to the canvas, then every frame tau (P=-1, A=0, G=t, B=1) is re-rendered as seen by
    a camera rotated by R(tau) (yaw/pitch at a constant rate, slight acceleration): I'(x) = I(K R^T K^-1 x). A pure
    rotation has no parallax, so the rotated view is exact, and so are the new flows:
      B'->A' : u = M_B(x);  flow = u + f_ba(u) - x            (A' = A, R_A = identity)
      A'->P' : u = x + f_ap(x);  flow = M_P^-1(u) - x
    Content that rotates in from outside the window does not exist: it is black in B', G', P', the MV there is
    marked missing, and batch["gt_valid"] / batch["b_valid"] remove it from the losses.
    Motion per pair at the canvas centre: up to max_frac * size px (0.45 * 1088 = 490 px)."""
    dev = batch["color_a"].device
    N, _, H0, W0 = batch["color_a"].shape
    S, sc = size, size / W0
    up = lambda x, mode="bilinear": F.interpolate(x, size=(S, S), mode=mode, align_corners=False if mode == "bilinear" else None)
    for k in ("color_p", "color_a", "color_g", "color_b", "depth_p", "depth_a", "depth_b"):
        batch[k] = up(batch[k])
    for k in ("mv_ba", "geo_flow_ba", "mv_ap"):
        batch[k] = up(batch[k]) * sc
    batch["mv_valid"] = up(batch["mv_valid"], "nearest")
    gt_valid, b_valid = torch.ones(N, 1, S, S, device=dev), torch.ones(N, 1, S, S, device=dev)
    c = (S - 1) / 2.0
    for i in range(N):
        fov = math.radians(rng.uniform(70, 100))
        f = (S / 2) / math.tan(fov / 2)
        K = torch.tensor([[f, 0, c], [0, f, c], [0, 0, 1.0]], device=dev)
        Ki = torch.linalg.inv(K)
        d = rng.uniform(0.05, max_frac) * S                                            
        ang = rng.uniform(0, 2 * math.pi)
        yaw_r, pitch_r = math.atan(d * math.cos(ang) / f), 0.5 * math.atan(d * math.sin(ang) / f)
        acc = rng.uniform(-0.3, 0.3)
        R = lambda tau: _rot(yaw_r * tau * (1 + acc * tau), pitch_r * tau * (1 + acc * tau), dev)
        t = float(batch["t"][i])
        grid = None
        new = {}
        for key, dkey, tau in (("color_b", "depth_b", 1.0), ("color_g", None, t), ("color_p", "depth_p", -1.0)):
            q, inside = _apply_h(K @ R(tau).T @ Ki, S, dev)
            if grid is None:
                y, x = torch.meshgrid(torch.arange(S, device=dev, dtype=torch.float32),
                                      torch.arange(S, device=dev, dtype=torch.float32), indexing="ij")
                grid = torch.stack((x, y), 0)
            off = (q - grid)[None]
            new[key] = warp(batch[key][i:i + 1], off)[0] * inside
            if dkey:
                new[dkey] = warp(batch[dkey][i:i + 1], off)[0] * inside + (1 - inside)
            if key == "color_b":
                for fk in ("mv_ba", "geo_flow_ba"):
                    fb = warp(batch[fk][i:i + 1], off)[0]
                    new[fk] = (q + fb - grid) * inside
                mv_ok = (warp(batch["mv_valid"][i:i + 1], off)[0] > 0.999).float() * inside
                new["mv_valid"] = mv_ok
                new["mv_ba"] = new["mv_ba"] * mv_ok
                b_valid[i] = inside
            if key == "color_g":
                gt_valid[i] = inside
            if key == "color_p":
                                                                                    
                u = grid + batch["mv_ap"][i]
                h_inv = K @ R(-1.0) @ Ki
                pu = (h_inv @ torch.cat((u, torch.ones_like(u[:1])), 0).view(3, -1)).view(3, S, S)
                new["mv_ap"] = pu[:2] / pu[2:].clamp_min(1e-6) - grid
        for k, v in new.items():
            batch[k][i] = v
    batch["gt_valid"], batch["b_valid"] = gt_valid, b_valid


def augment(batch, rng, p_obj=0.6, p_shadow=0.5, p_glint=0.3, p_damage=0.5, max_move=96, p_locked=0.3):
    cb = batch["color_b"]
    N, _, H, W = cb.shape
    dev = cb.device
    max_move = int(max_move * H / 448)                                                                   
    batch["app_flow_ba"] = torch.zeros(N, 2, H, W, device=dev)
    batch["app_valid"] = torch.zeros(N, 1, H, W, device=dev)
    tri = "depth_g" in batch                                                                  
    if tri:
        for k in ("app_flow_ga", "app_flow_bg"):
            batch[k] = torch.zeros(N, 2, H, W, device=dev)
        batch["app_valid_g"] = torch.zeros(N, 1, H, W, device=dev)
    masks = {k: torch.zeros(N, 1, H, W, device=dev) for k in ("mv_wrong", "shadow", "glint", "object")}
    for i in range(N):
        t = float(batch["t"][i])
                            
        for _ in range(rng.randint(1, 2) if rng.random() < p_obj else 0):
            s = rng.randint(H // 8, H // 3)
            m = ellipse(s, dev)[None]
            j = (i + 1 + rng.randrange(max(N - 1, 1))) % N
            sy, sx = rng.randint(0, H - s), rng.randint(0, W - s)
            tex = batch["color_a"][j, :, sy:sy + s, sx:sx + s].clone()
            dy, dx = rng.randint(-max_move, max_move), rng.randint(-max_move, max_move)
            y, x = rng.randint(-s // 4, H - s + s // 4), rng.randint(-s // 4, W - s + s // 4)
            pos = positions(y, x, dy, dx, t)
            for key, _ in FRAMES:
                place(batch[key][i], tex, m, *pos[key], "over")
            near = torch.tensor([0.02], device=dev).view(1, 1, 1)
            for key, pk in (("depth_p", "color_p"), ("depth_a", "color_a"), ("depth_b", "color_b"),
                            ("depth_g", "color_g")):
                if key in batch:
                    place(batch[key][i], near, m, *pos[pk], "set")
            if tri:                                                                                                 
                (ya, xa), (yg, xg) = pos["color_a"], pos["color_g"]
                yb_, xb_ = pos["color_b"]
                f_ga = torch.tensor([xa - xg, ya - yg], device=dev, dtype=cb.dtype).view(2, 1, 1).expand(2, s, s)
                f_bg = torch.tensor([xg - xb_, yg - yb_], device=dev, dtype=cb.dtype).view(2, 1, 1).expand(2, s, s)
                place(batch["app_flow_ga"][i], f_ga, m, yg, xg, "set")
                place(batch["app_valid_g"][i], torch.ones(1, s, s, device=dev), m, yg, xg, "set")
                place(batch["geo_flow_ga"][i], f_ga, m, yg, xg, "set")
                place(batch["app_flow_bg"][i], f_bg, m, yb_, xb_, "set")
                place(batch["geo_flow_bg"][i], f_bg, m, yb_, xb_, "set")
            yb, xb = pos["color_b"]
            true = torch.tensor([-dx, -dy], device=dev, dtype=cb.dtype).view(2, 1, 1)           
            place(batch["app_flow_ba"][i], true.expand(2, s, s), m, yb, xb, "set")
            place(batch["app_valid"][i], torch.ones(1, s, s, device=dev), m, yb, xb, "set")
            place(batch["geo_flow_ba"][i], true.expand(2, s, s), m, yb, xb, "set")
            place(masks["object"][i], torch.ones(1, s, s, device=dev), m, yb, xb, "set")
            u = rng.random()
            if u < 0.40:
                choice = None                                                                      
            elif u < 0.60:
                choice = torch.zeros(2, s, s, device=dev)                              
            elif u < 0.85:
                choice = true.expand(2, s, s)                                      
            else:
                choice = "missing"
            if isinstance(choice, str):
                place(batch["mv_valid"][i], torch.zeros(1, s, s, device=dev), m, yb, xb, "set")
                place(batch["mv_ba"][i], torch.zeros(2, s, s, device=dev), m, yb, xb, "set")
            elif choice is not None:
                place(batch["mv_ba"][i], choice, m, yb, xb, "set")
            if choice is None or isinstance(choice, str) or u < 0.60:
                place(masks["mv_wrong"][i], torch.ones(1, s, s, device=dev), m, yb, xb, "set")
                                                                                                                   
                                                                                               
        if rng.random() < p_locked:
            s = rng.randint(H // 5, H // 2)
            m = ellipse(s, dev, soft=0.15)[None]
            j = rng.randrange(N)
            sy, sx = rng.randint(0, H - s), rng.randint(0, W - s)
            tex = batch["color_a"][j, :, sy:sy + s, sx:sx + s].clone()
            y, x = rng.randint(H - s - s // 4, H - s // 2), rng.randint(-s // 3, W - s + s // 3)               
            for key, _ in FRAMES:
                place(batch[key][i], tex, m, y, x, "over")
            mm = (m > 0.5).float()
            near = torch.tensor([0.01], device=dev).view(1, 1, 1)
            for key in ("depth_p", "depth_a", "depth_b", "depth_g"):
                if key in batch:
                    place(batch[key][i], near, mm, y, x, "set")
            zero2 = torch.zeros(2, s, s, device=dev)
            if tri:
                for k in ("app_flow_ga", "app_flow_bg", "geo_flow_ga", "geo_flow_bg"):
                    place(batch[k][i], zero2, mm, y, x, "set")
                place(batch["app_valid_g"][i], torch.ones(1, s, s, device=dev), mm, y, x, "set")
            place(batch["app_flow_ba"][i], zero2, mm, y, x, "set")
            place(batch["app_valid"][i], torch.ones(1, s, s, device=dev), mm, y, x, "set")
            place(batch["geo_flow_ba"][i], zero2, mm, y, x, "set")
            place(masks["object"][i], torch.ones(1, s, s, device=dev), mm, y, x, "set")
            if rng.random() < 0.5:
                place(batch["mv_ba"][i], zero2, mm, y, x, "set")                          
            else:
                place(masks["mv_wrong"][i], torch.ones(1, s, s, device=dev), mm, y, x, "set")                   
                                           
        for _ in range(rng.randint(1, 3) if rng.random() < p_shadow else 0):
            s = rng.randint(H // 6, H // 2)
            m = ellipse(s, dev, soft=rng.uniform(0.1, 0.5))[None]
            f = torch.full((1, 1, 1), rng.uniform(0.3, 0.7), device=dev)
            dy, dx = rng.randint(-max_move // 2, max_move // 2), rng.randint(-max_move // 2, max_move // 2)
            pos = positions(rng.randint(-s // 3, H - s), rng.randint(-s // 3, W - s), dy, dx, t)
            for key, _ in FRAMES:
                place(batch[key][i], f, m, *pos[key], "mul")
            place(masks["shadow"][i], torch.ones(1, s, s, device=dev), (m > 0.05).float(), *pos["color_b"], "set")
                                                        
        if rng.random() < p_glint:
            s = rng.randint(H // 8, H // 3)
            m = ellipse(s, dev, soft=0.6)[None] * rng.uniform(0.15, 0.4)
            j = rng.randrange(N)
            sy, sx = rng.randint(0, H - s), rng.randint(0, W - s)
            tex = batch["color_a"][j, :, sy:sy + s, sx:sx + s].clone()
            dy, dx = rng.randint(-max_move, max_move), rng.randint(-max_move, max_move)
            pos = positions(rng.randint(0, H - s), rng.randint(0, W - s), dy, dx, t)
            for key, _ in FRAMES:
                place(batch[key][i], tex, m, *pos[key], "add")
            place(masks["glint"][i], torch.ones(1, s, s, device=dev), (m > 0.02).float(), *pos["color_b"], "set")
                       
        if rng.random() < p_damage:
            mv, val = batch["mv_ba"][i], batch["mv_valid"][i]
            for _ in range(rng.randint(0, 2)):                                 
                hh, ww = rng.randint(H // 16, H // 3), rng.randint(W // 16, W // 3)
                y, x = rng.randint(0, H - hh), rng.randint(0, W - ww)
                mv[:, y:y + hh, x:x + ww] = 0
                val[:, y:y + hh, x:x + ww] = 0
                masks["mv_wrong"][i, :, y:y + hh, x:x + ww] = 1
            for _ in range(rng.randint(0, 2)):                                                                  
                hh, ww = rng.randint(H // 16, H // 4), rng.randint(W // 16, W // 4)
                y, x = rng.randint(0, H - hh), rng.randint(0, W - ww)
                y2, x2 = rng.randint(0, H - hh), rng.randint(0, W - ww)
                mv[:, y:y + hh, x:x + ww] = mv[:, y2:y2 + hh, x2:x2 + ww].clone()
                masks["mv_wrong"][i, :, y:y + hh, x:x + ww] = 1
            if rng.random() < 0.15:
                mv.mul_(rng.uniform(0.9, 1.1)).add_(torch.randn_like(mv) * 0.3)
    return masks
