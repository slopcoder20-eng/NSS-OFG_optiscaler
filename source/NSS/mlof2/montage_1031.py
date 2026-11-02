"""Side-by-side crops of today's candidates (render_1031 ppm): the 4 frames where the deployed cut3 is worst, each a
480x270 window at its worst region, at 2x zoom -> PNG grid with labels + a full-frame thumbnail with the window.
  python montage_1031.py <render dir> <out dir>"""
import sys, os, glob, numpy as np
from PIL import Image, ImageDraw
rd, od = sys.argv[1:3]; os.makedirs(od, exist_ok=True)
V = [("GT (real frame)", "cut3_gt"), ("cut3 (deployed)", "cut3"), ("menc: new OF (+cost)", "menc"),
     ("fpnfrz: OF same cost", "fpnfrz"), ("BOTHFAIL near (old)", "cut3_bfnear"), ("BOTHFAIL argmax", "cut3_bfarg"),
     ("BOTHFAIL argmax+edge", "cut3_bfedge")]
if os.environ.get("SET") == "bf4":
    V = [("GT (real frame)", "cut3_gt"), ("cut3 (deployed)", "cut3"), ("cut3 + edge (full-res, chosen)", "cut3_bfedge"),
         ("cut3 + edge (engine form 1/4)", "cut3_bfedge4"), ("menc (new OF)", "menc"), ("menc + edge (engine form)", "menc_bfedge4")]
rdp = lambda p: np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
frames = sorted(int(os.path.basename(p).split("_")[2]) for p in glob.glob(f"{rd}/cut3_gt_*_1.ppm"))
lum = lambda x: x @ np.array([0.2126, 0.7152, 0.0722], np.float32)
score = []
for f in frames:
    g = rdp(f"{rd}/cut3_gt_{f:03d}_1.ppm"); c = rdp(f"{rd}/cut3_{f:03d}_1.ppm")
    score.append((float(np.abs(lum(c) - lum(g)).mean()), f))
CW, CH, Z = 480, 270, 2
lines = []
for err, f in sorted(score, reverse=True)[:4]:
    g = rdp(f"{rd}/cut3_gt_{f:03d}_1.ppm"); H, W = g.shape[:2]
    e = np.abs(lum(rdp(f"{rd}/cut3_{f:03d}_1.ppm")) - lum(g))
    ii = e.cumsum(0).cumsum(1); ii = np.pad(ii, ((1, 0), (1, 0)))
    best, by, bx = -1, 0, 0
    for y in range(0, H - CH + 1, 30):
        for x in range(0, W - CW + 1, 30):
            s_ = ii[y + CH, x + CW] - ii[y, x + CW] - ii[y + CH, x] + ii[y, x]
            if s_ > best: best, by, bx = s_, y, x
    tiles = []
    for name, pre in V:
        p = f"{rd}/{pre}_{f:03d}_1.ppm"
        if not os.path.exists(p): continue
        im = Image.fromarray(rdp(p)[by:by + CH, bx:bx + CW].astype(np.uint8)).resize((CW * Z, CH * Z), Image.NEAREST)
        x_ = rdp(p)
        me = float(np.abs(lum(x_) - lum(g)).mean()) if pre != "cut3_gt" else 0.0
        d = ImageDraw.Draw(im); d.rectangle([0, 0, CW * Z, 34], fill=(0, 0, 0))
        d.text((8, 8), f"{name}" + (f"   frame err {me:.2f}" if pre != "cut3_gt" else ""), fill=(255, 255, 0))
        tiles.append(im)
    cols = 4; rows = (len(tiles) + cols - 1) // cols
    grid = Image.new("RGB", (cols * CW * Z, rows * CH * Z), (40, 40, 40))
    for i, t in enumerate(tiles): grid.paste(t, ((i % cols) * CW * Z, (i // cols) * CH * Z))
    th = Image.fromarray(g.astype(np.uint8)).resize((CW * Z, CH * Z)); dd = ImageDraw.Draw(th)
    sx, sy = CW * Z / W, CH * Z / H
    dd.rectangle([bx * sx, by * sy, (bx + CW) * sx, (by + CH) * sy], outline=(255, 0, 0), width=4)
    if len(tiles) < cols * rows: grid.paste(th, ((len(tiles) % cols) * CW * Z, (len(tiles) // cols) * CH * Z))
    out = f"{od}/compare{os.environ.get('SET', '')}_f{f:03d}.png"; grid.save(out); lines.append(f"{out}  (cut3 frame err {err:.2f}, window x{bx} y{by})")
print("\n".join(lines))
