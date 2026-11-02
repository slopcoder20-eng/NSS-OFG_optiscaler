"""Our models vs FSR4 frame generation on the SN2 skip protocol, scored like harness/nfru_dx12/replay/root_sn2.py:
mean |luma error| (8-bit) of the generated f-1 vs the real skipped f-1, ONE global alignment per frame (the real frame
shifted to best match the FSR4 output: the camera's turn rate changes between real frames, so every t = 0.5 frame is
globally offset; the screen-locked viewmodel is compared unshifted), HUD pixels masked. Regions: viewmodel core
(depth > 0.1), its 24-px edge band, fast background (|MV| > 20 render px), slow background, all. Also the plain blend.
  python sn2_vs_fsr4.py <capture dir> <replay dir> <name=prefix> [<name=prefix> ...]   (prefix relative to the replay dir)"""
import os, sys
import numpy as np
from PIL import Image

cap, rdir = sys.argv[1], sys.argv[2]
ALIGN = os.environ.get("ALIGN", "self")                                                                              
                                                                                                                          
methods = [a.split("=", 1) for a in sys.argv[3:]]
W, H, DW = 1129, 636, 1132
raw = lambda f, n: np.fromfile(os.path.join(cap, f"{f:03d}_{n}.bin"), dtype=np.uint32).reshape(1080, 1920)
to8 = lambda a: np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.float32)
up = lambda m: np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((1920, 1080), Image.NEAREST)) > 0
luma = lambda a: a @ np.float32([.299, .587, .114])


def align(out, gt):
    """integer global shift of gt that best matches out (same as replay/skip_quality.py)"""
    def l(a, k): return (a @ np.float32([.299, .587, .114])).reshape(1080 // k, k, 1920 // k, k).mean((1, 3))
    a, b = l(out, 4), l(gt, 4)
    a = a - a.mean(); b = b - b.mean()
    c = np.fft.irfft2(np.fft.rfft2(a) * np.conj(np.fft.rfft2(b)), a.shape)
    dy, dx = np.unravel_index(np.argmax(c), c.shape)
    dy = dy - a.shape[0] if dy > a.shape[0] // 2 else dy; dx = dx - a.shape[1] if dx > a.shape[1] // 2 else dx
    best = None
    for ry in range(dy * 4 - 3, dy * 4 + 4):
        for rx in range(dx * 4 - 3, dx * 4 + 4):
            g = np.roll(gt, (ry, rx), (0, 1))
            e = np.abs(l(out, 8) - l(g, 8))[4:-4, 8:-8].mean()
            if best is None or e < best[0]: best = (e, ry, rx)
    return best[1], best[2]


REG = ("viewmodel", "vm edge", "fast bg", "slow bg", "all")
names = [n for n, _ in methods] + ["blend"]
acc = {k: {r: [] for r in REG} for k in names}
shp = {k: {r: [] for r in REG} for k in names}                                                                        


def grad(a):
    l = luma(a)
    gx = np.zeros_like(l); gy = np.zeros_like(l)
    gx[:, 1:-1] = np.abs(l[:, 2:] - l[:, :-2]); gy[1:-1] = np.abs(l[2:] - l[:-2])
    return gx + gy
share = {r: [] for r in REG}
shifts = []
NM = int(os.environ.get("MFG", "2"))                                                                            
byk = {}
for f, kk in [(f, k) for f in range(NM, 40, NM) for k in range(1, NM)]:
    gf = f - NM + kk
    gt0 = to8(raw(gf, "hudless"))
    nohud = np.ones((1080, 1920), bool)
    for g in range(f - NM, f + 1):
        nohud &= raw(g, "backbuffer") == raw(g, "hudless")
    d = np.fromfile(os.path.join(cap, f"{gf:03d}_depth.bin"), dtype=np.float32).reshape(H, DW)[:, :W] > 0.1
    core = up(d)
    k = 24; dd = np.pad(core, k).astype(np.uint8); ii = dd.cumsum(0).cumsum(1)
    band = (ii[2 * k:, 2 * k:] - ii[:-2 * k, 2 * k:] - ii[2 * k:, :-2 * k] + ii[:-2 * k, :-2 * k])[:1080, :1920] > 0
    mv = np.fromfile(os.path.join(cap, f"{gf:03d}_mv.bin"), dtype=np.float16).reshape(H, W, 2).astype(np.float32)
    fast = up(np.hypot(mv[..., 0], mv[..., 1]) > 20)
    outs = {n: np.asarray(Image.open(os.path.join(rdir, f"{p}_{f:03d}_{kk}.ppm")).convert("RGB")).astype(np.float32) for n, p in methods}
    outs["blend"] = to8(raw(f - NM, "hudless")) * (1 - kk / NM) + to8(raw(f, "hudless")) * (kk / NM)
    fixed = None
    if ALIGN == "fsr4":
        fixed = align(np.asarray(Image.open(os.path.join(rdir, f"k_fsr4_s1_t0_h0_{f:03d}_1.ppm"))).astype(np.float32), gt0)
    for n, o in outs.items():
        sy, sx = (0, 0) if ALIGN == "none" else (fixed if fixed is not None else align(o, gt0))
        shifts.append((sy, sx))
        gts = np.roll(gt0, (sy, sx), (0, 1))
        valid = np.zeros((1080, 1920), bool); valid[max(sy, 0):1080 + min(sy, 0), max(sx, 0):1920 + min(sx, 0)] = True
        regs = {"viewmodel": core & nohud, "vm edge": band & ~core & nohud & valid,
                "fast bg": fast & ~band & nohud & valid, "slow bg": ~fast & ~band & nohud & valid}
        if os.environ.get("EXCL"):                                                                                    
            ex = np.load(f"{os.environ['EXCL']}_{f:03d}" + (f"_{kk}" if NM > 2 else "") + ".npy")
            regs = {r: m_ & ~ex for r, m_ in regs.items()}
        regs["all"] = regs["viewmodel"] | regs["vm edge"] | regs["fast bg"] | regs["slow bg"]
        if n == "blend":
            for r in REG:
                share[r].append(regs[r].mean())
        gt = np.where(core[..., None], gt0, gts)
        g_gt = grad(gt)
        e = np.abs(luma(o) - luma(gt))
        g_o = grad(o)
        for r in REG:
            acc[n][r].append(float(e[regs[r]].mean()) if regs[r].any() else np.nan)
            if r == "all":
                byk.setdefault((n, kk), []).append(acc[n][r][-1])
            shp[n][r].append(float(g_o[regs[r]].mean() / max(g_gt[regs[r]].mean(), 1e-6)) if regs[r].any() else np.nan)
print(f"mean |luma error| vs the skipped real frame (8-bit, lower = better), {len(acc[names[0]]['all'])} frames (MFG {NM}x), alignment '{ALIGN}' "
      f"(mean |shift| {np.mean([abs(a) + abs(b) for a, b in shifts]):.1f} px); region share: " +
      ", ".join(f"{r} {100 * np.mean(share[r]):.1f}%" for r in REG[:-1]))
print(f"{'':20s}" + "".join(f"{r:>11s}" for r in REG))
for n in names:
    print(f"{n:20s}" + "".join(f"{np.nanmean(acc[n][r]):11.2f}" for r in REG))
print("sharpness = mean |grad luma| output / real frame (1 = as sharp as real, < 1 = blurred)")
print(f"{'':20s}" + "".join(f"{r:>11s}" for r in REG))
for n in names:
    print(f"{n:20s}" + "".join(f"{np.nanmean(shp[n][r]):11.3f}" for r in REG))
if NM > 2:
    print("all-region error per generated position t = k/N:")
    for n in names:
        print(f"{n:20s}" + "".join(f"   t={kk}/{NM} {np.nanmean(byk[(n, kk)]):6.2f}" for kk in range(1, NM)))
