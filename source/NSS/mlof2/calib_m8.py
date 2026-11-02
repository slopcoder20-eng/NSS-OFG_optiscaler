"""int8 storage scale of the MatchEncoder map (m8 chain: fm8 / qm8 / warped / 1/16 mean): 99.99th pct |m8| over NFRU
val + test capture frames at the DLL OF size (half res), written into the qstats json as 'of.m8'.
  python calib_m8.py <OF ckpt> <qstats json>"""
import sys, json, torch
from torch.nn import functional as F
import test_mlof2_inputs as TI
from model_v2 import build_mlof2
ck, qs = sys.argv[1:3]
dev = "cuda"
sd = torch.load(ck, map_location=dev); m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
vals = []
with torch.no_grad():
    for path in (TI.NFRU_TEST.replace("/test/", "/val/"), TI.NFRU_TEST):
        TI.NFRU_TEST = path
        for fa in range(2, 50, 6):
            col, dep = TI.nfru_pair(fa, fa + 2)
            col = F.interpolate(col, scale_factor=0.5, mode="area"); dep = F.interpolate(dep, scale_factor=0.5, mode="area")
            col = F.pad(col, (0, 0, 0, (64 - col.shape[-2] % 64) % 64), mode="replicate"); dep = F.pad(dep, (0, 0, 0, (64 - dep.shape[-2] % 64) % 64), mode="replicate")
            vals.append(m.enc(col, dep)["m8"].abs().flatten().float().cpu())
v = torch.cat(vals)
st = float(torch.quantile(v[torch.randperm(v.numel())[:4_000_000]], 0.9999))
print(f"m8 |x| max {float(v.max()):.4f}  p99.99 {st:.4f}  mean {float(v.mean()):.4f}")
q = json.load(open(qs)); q["of.m8"] = st; json.dump(q, open(qs, "w"), indent=0); print("wrote of.m8 into", qs)
