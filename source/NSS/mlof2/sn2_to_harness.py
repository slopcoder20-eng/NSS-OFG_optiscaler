"""SN2 capture -> FG harness dataset files (timing replay): color_%03d.bin RGBA8 display size (hudless, R10G10B10A2 top
8 bits), depth_%03d.bin fp32 render size (row pitch 1132 -> 1129), mv_2x/mv_4x_%03d.bin fp32 UV (render px / size),
view_proj.bin 56 x 16 fp32 from meta.txt.  python sn2_to_harness.py <capture dir> <out dir>"""
import os, sys, numpy as np
cap, out = sys.argv[1:3]
DW, DH, RW, RH = 1920, 1080, 1129, 636
os.makedirs(out, exist_ok=True)
n = len([f for f in os.listdir(cap) if f.endswith("_hudless.bin")])
for f in range(n):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    rgba = np.stack([((a >> s) & 1023) >> 2 for s in (0, 10, 20)] + [np.full_like(a, 255)], -1).astype(np.uint8)
    rgba.tofile(os.path.join(out, f"color_{f:03d}.bin"))
    d = np.fromfile(os.path.join(cap, f"{f:03d}_depth.bin"), dtype=np.float32)
    pitch = d.size // RH
    d.reshape(RH, pitch)[:, :RW].astype(np.float32).tofile(os.path.join(out, f"depth_{f:03d}.bin"))
    m = np.fromfile(os.path.join(cap, f"{f:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = m / np.array([RW, RH], np.float32)
    for k in ("2x", "4x"):
        m.tofile(os.path.join(out, f"mv_{k}_{f:03d}.bin"))
vp = np.zeros((56, 16), np.float32)
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) == 19 and p[2] == "viewProjection":
        i = int(p[1])
        if i < 56:
            vp[i] = [float(x) for x in p[3:]]
vp[n:] = vp[n - 1]
vp.tofile(os.path.join(out, "view_proj.bin"))
print(f"{n} frames, depth pitch {pitch}, -> {out}")
