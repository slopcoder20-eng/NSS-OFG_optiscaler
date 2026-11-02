"""Score the FSR black-box run against ours on the exported t = 0.5 windows (export_fsr_bench.py + fsr_fg_bench.exe).
All outputs compared as RGBA8 -> [0,1] RGB against the ground-truth middle frame G: whole-frame PSNR for clean and aug,
plus PSNR inside the wrong-MV mask (aug) and on the rest. Baselines: 50/50 blend of A and B.
  python score_fsr_bench.py <bench_dir>"""
import sys
import numpy as np

d = sys.argv[1]
lines = open(f"{d}/index.txt").read().split("\n")
H, W = int(lines[0].split()[1]), int(lines[0].split()[3])
ids = [l.split()[0] for l in lines[1:] if l.strip()]
img = lambda p: np.fromfile(p, np.uint8).reshape(H, W, 4)[..., :3].astype(np.float32) / 255


def psnr(x, y, m=None):
    e = (x - y) ** 2
    e = e.mean() if m is None else (e[m].mean() if m.any() else np.nan)
    return -10 * np.log10(max(e, 1e-10))


res = {k: [] for k in ("clean_fsr", "clean_ours", "clean_blend", "aug_fsr", "aug_ours", "aug_blend",
                       "wrong_fsr", "wrong_ours", "wrong_blend", "rest_fsr", "rest_ours")}
for i in ids:
    for ver in ("clean", "aug"):
        p = f"{d}/{i}_{ver}_"
        g, a, b = img(p + "color_g.bin"), img(p + "color_a.bin"), img(p + "color_b.bin")
        fsr, ours, blend = img(p + "fsr.bin"), img(p + "ours.bin"), 0.5 * (a + b)
        import os
        if os.path.exists(p + "rife.bin"):
            rf = img(p + "rife.bin"); res.setdefault(f"{ver}_rife", []).append(psnr(rf, g))
            if ver == "aug": res.setdefault("wrong_rife", []).append(psnr(rf, g, np.fromfile(p + "mv_wrong.bin", np.uint8).reshape(H, W) > 0))
        res[f"{ver}_fsr"].append(psnr(fsr, g)); res[f"{ver}_ours"].append(psnr(ours, g)); res[f"{ver}_blend"].append(psnr(blend, g))
        if ver == "aug":
            m = np.fromfile(p + "mv_wrong.bin", np.uint8).reshape(H, W) > 0
            res["wrong_fsr"].append(psnr(fsr, g, m)); res["wrong_ours"].append(psnr(ours, g, m)); res["wrong_blend"].append(psnr(blend, g, m))
            res["rest_fsr"].append(psnr(fsr, g, ~m)); res["rest_ours"].append(psnr(ours, g, ~m))
mean = lambda v: float(np.nanmean(v))
print(f"windows {len(ids)} (t = 0.5)")
print(f"clean frame PSNR      : FSR {mean(res['clean_fsr']):.2f} | ours {mean(res['clean_ours']):.2f} | blend {mean(res['clean_blend']):.2f}")
print(f"augmented frame PSNR  : FSR {mean(res['aug_fsr']):.2f} | ours {mean(res['aug_ours']):.2f} | blend {mean(res['aug_blend']):.2f}")
print(f"  wrong-MV region     : FSR {mean(res['wrong_fsr']):.2f} | ours {mean(res['wrong_ours']):.2f} | blend {mean(res['wrong_blend']):.2f}")
print(f"  rest of the frame   : FSR {mean(res['rest_fsr']):.2f} | ours {mean(res['rest_ours']):.2f}")
if "clean_rife" in res:
    print(f"RIFE 4.25 (colour only): clean {mean(res['clean_rife']):.2f} | aug {mean(res['aug_rife']):.2f} | wrong-MV {mean(res['wrong_rife']):.2f}")
win = sum(o > f for o, f in zip(res["clean_ours"], res["clean_fsr"]))
print(f"clean windows where ours > FSR: {win}/{len(ids)}")
