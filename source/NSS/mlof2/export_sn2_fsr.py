"""SN2 capture -> FSR frame-generation inputs for the skip protocol (pairs f-2, f; FSR is fed frames 0, 2, 4, ... in
a row, so the frame it generates at f lies between f-2 and f, like eval_sn2_skip.py / skip_quality.py).
Per fed frame f: <out>/<f:03d>_depth.bin (render RW x RH f32, reverse Z as captured, row pitch removed),
<f:03d>_mv.bin (render RW x RH RG16F: f -> f-2 chained game MV in render px, FSR sign: previous = current + mv),
and a line in frames.txt: f jitter_x jitter_y dt(ms, f-2 -> f) near far fov. Colour is read by the harness straight
from the capture (<f:03d>_hudless.bin, R10G10B10A2).
  python export_sn2_fsr.py <capture dir> <out dir> [first=0] [count=40]"""
import os
import sys
import numpy as np
import torch
from torch.nn import functional as F
from data_v2 import chain_backward
from model_v2 import warp

cap, out = sys.argv[1], sys.argv[2]
first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
count = int(sys.argv[4]) if len(sys.argv) > 4 else 40
os.makedirs(out, exist_ok=True)
DW, DH, RW, RH, RP = 1920, 1080, 1129, 636, 1132
MV_MAX = 1000.0
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        g = lambda k, n=1: [float(x) for x in p[p.index(k) + 1:p.index(k) + 1 + n]]
        meta[int(p[1])] = {"jit": g("jitter", 2), "dt": g("dt")[0], "near": g("near")[0], "far": g("far")[0],
                           "fov": g("fov")[0], "mvs": g("mvScale", 2)}


def mv_raw(f):
    m = np.fromfile(os.path.join(cap, f"{f:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = torch.isfinite(m).all(0) & (m.abs().amax(0) < MV_MAX)
    m = torch.where(ok[None], m, torch.zeros_like(m))
    sx, sy = meta[f]["mvs"]
    return m * torch.tensor([sx, sy]).view(2, 1, 1)


def colour_r(f):                                                     
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    c = torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0)
    return F.interpolate(c[None], size=(RH, RW), mode="area")[0]


                                                                                                      
a, b = colour_r(first)[None], colour_r(first + 1)[None]
ps = lambda x, y: -10 * torch.log10(((x - y) ** 2)[..., 8:-8, 8:-8].mean()).item()
p_pos, p_neg = ps(warp(a, mv_raw(first + 1)[None]), b), ps(warp(a, -mv_raw(first + 1)[None]), b)
sign = 1.0 if p_pos > p_neg else -1.0
print(f"sign check: +mv {p_pos:.2f} dB, -mv {p_neg:.2f} dB -> {sign:+.0f}")
lines = []
for f in range(first, first + count, 2):
    d = np.fromfile(os.path.join(cap, f"{f:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
    np.ascontiguousarray(d).tofile(os.path.join(out, f"{f:03d}_depth.bin"))
    if f >= first + 2:
        mv = chain_backward([sign * mv_raw(f), sign * mv_raw(f - 1)])                                      
    else:
        mv = torch.zeros(2, RH, RW)
    mv.permute(1, 2, 0).numpy().astype(np.float16).tofile(os.path.join(out, f"{f:03d}_mv.bin"))
    m = meta[f]
    dt = m["dt"] + (meta[f - 1]["dt"] if f - 1 in meta else 0.0)
    lines.append(f"{f} {m['jit'][0]} {m['jit'][1]} {dt} {m['near']} {m['far']} {m['fov']}")
open(os.path.join(out, "frames.txt"), "w").write(f"display {DW} {DH} render {RW} {RH}\n" + "\n".join(lines) + "\n")
print(f"wrote {len(lines)} frames to {out}")
