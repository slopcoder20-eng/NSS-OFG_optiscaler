import torch, collections, glob, os
from model_v2 import build_mlof2, MLOF2
def show(name, sd):
    g = collections.OrderedDict()
    for k, v in sd.items():
        if not torch.is_floating_point(v) or k.endswith(("running_mean", "running_var")): continue
        top = ".".join(k.split(".")[:2])
        g[top] = g.get(top, 0) + v.numel()
    tot = sum(g.values())
    print(f"== {name}: {tot/1e6:.3f} M")
    agg = collections.OrderedDict()
    for k, n in g.items():
        a = k.split(".")[0] + "." + (k.split(".")[1] if k.startswith("pair") or k.startswith("enc") else "")
        agg[a] = agg.get(a, 0) + n
    for k, n in agg.items(): print(f"   {k:16s} {n/1e3:8.1f} k")
R = "/home/sh/mlof2_runs"
sd = torch.load(f"{R}/v2_of_cut3/s2000.pt", map_location="cpu"); show("deployed OF cut3 (ckpt incl. unused head)", sd.get("model", sd))
m = MLOF2(enc_deep=True, enc_fpn=True, recur8=3, enc_match=True); show("new OF (fpn+deep enc, MatchEncoder, recur8)", m.state_dict())
for p in sorted(glob.glob(f"{R}/nfru_head_c2_ce3/*.pt"))[-1:]:
    h = torch.load(p, map_location="cpu"); h = h.get("model", h); show(f"gen head {os.path.basename(p)}", h)
g = collections.Counter()
for k, v in sd.get("model", sd).items():
    if k.startswith("pair.upd."): g[k.split(".")[2]] += v.numel()
print("pair.upd per level (k):", {k: round(v / 1e3, 1) for k, v in g.items()})
