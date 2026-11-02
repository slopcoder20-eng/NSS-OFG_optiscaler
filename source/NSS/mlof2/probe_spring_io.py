import io, sys, time, zipfile
import numpy as np, h5py
from PIL import Image
raw = sys.argv[1]
t = time.time(); fz = zipfile.ZipFile(f"{raw}/train_flow_BW_left.zip"); print(f"open flow zip {time.time() - t:.1f}s, {len(fz.namelist())} entries")
n = [x for x in fz.namelist() if "/0004/" in x][:3]; print(n)
for x in n:
    t = time.time(); b = fz.read(x); t1 = time.time()
    with h5py.File(io.BytesIO(b), "r") as h:
        print(list(h.keys()), h["flow"].shape, h["flow"].dtype); f = np.asarray(h["flow"])
    print(f"  {x}: {len(b) / 1e6:.1f} MB read {t1 - t:.2f}s, decode {time.time() - t1:.2f}s, nan {np.isnan(f).mean():.3f}, |f| median {np.nanmedian(np.hypot(f[..., 0], f[..., 1])):.2f}")
dz = zipfile.ZipFile(f"{raw}/train_disp1_left.zip"); m = [x for x in dz.namelist() if "/0004/" in x][:1]
t = time.time(); b = dz.read(m[0])
with h5py.File(io.BytesIO(b), "r") as h: print(m[0], list(h.keys()), h["disparity"].shape, f"{time.time() - t:.2f}s")
