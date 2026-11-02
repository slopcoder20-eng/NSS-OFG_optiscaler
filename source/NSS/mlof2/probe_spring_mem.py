"""Spring training sample: time / peak RSS, and the half-res chain vs the old 1080p chain (same window)."""
import resource, time, random
import torch
from data_v2 import WindowDataset
ds = WindowDataset(["spring"], "train", crop=(1024, 1920), strides=(1, 2, 4, 8, 12))
for i in range(6):
    idx = random.Random(i).randrange(len(ds))
    random.seed(100 + i); t = time.time(); b = ds[idx]; dt = time.time() - t
    ds.spring_file = [False] * len(ds.files)
    random.seed(100 + i); t = time.time(); b0 = ds[idx]; dt0 = time.time() - t
    ds.spring_file = [True] * len(ds.files)
    d = (b["geo_flow_ba"] - b0["geo_flow_ba"]).norm(dim=0)
    print(f"span {int(b['span']):3d} |flow| med {b0['geo_flow_ba'].norm(dim=0).median():6.1f} px | half-res chain {dt:4.2f} s vs 1080p {dt0:4.2f} s"
          f" | diff median {d.median():.3f} p95 {d.quantile(0.95) if d.numel() < 2**24 else d.flatten()[::4].quantile(0.95):.3f} px"
          f" | peak RSS {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024:5.0f} MB", flush=True)
