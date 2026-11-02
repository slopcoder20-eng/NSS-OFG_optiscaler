"""SN2 comparison sheet: one row per (frame, box), columns = GT (skipped real frame f-1) + the given replay prefixes,
each tile labelled. Boxes are y0,y1,x0,x1 in 1080p pixels; "full" = whole frame downscaled.
  python montage_sn2.py <capture dir> <replay dir> <out.png> <frames, e.g. 16,20> <box;box;...> <name=prefix> ..."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

cap, rep, out = sys.argv[1], sys.argv[2], sys.argv[3]
frames = [int(x) for x in sys.argv[4].split(",")]
boxes = sys.argv[5].split(";")
cols = [a.split("=", 1) for a in sys.argv[6:]]
TW = 480                                                                 


def gt(f):
    a = np.fromfile(os.path.join(cap, f"{f:03d}_hudless.bin"), dtype=np.uint32).reshape(1080, 1920)
    return Image.fromarray(np.stack([(((a >> s) & 1023) * 255 + 511) // 1023 for s in (0, 10, 20)], -1).astype(np.uint8))


rows = []
for f in frames:
    ims = [("GT f-1", gt(f - 1))] + [(n, Image.open(os.path.join(rep, f"{p}_{f:03d}_1.ppm")).convert("RGB")) for n, p in cols]
    for bx in boxes:
        tiles = []
        for name, im in ims:
            if bx != "full":
                y0, y1, x0, x1 = (int(v) for v in bx.split(","))
                im = im.crop((x0, y0, x1, y1))
            im = im.resize((TW, int(TW * im.height / im.width)), Image.LANCZOS if bx == "full" else Image.NEAREST)
            d = ImageDraw.Draw(im)
            d.rectangle((0, 0, 8 * len(name) + 70, 14), fill=(0, 0, 0))
            d.text((3, 1), f"{name}  f{f}", fill=(255, 255, 0))
            tiles.append(np.asarray(im))
        rows.append(np.concatenate(tiles, 1))
w = max(r.shape[1] for r in rows)
Image.fromarray(np.concatenate([np.pad(r, ((0, 4), (0, w - r.shape[1]), (0, 0))) for r in rows], 0)).save(out)
print("wrote", out)
