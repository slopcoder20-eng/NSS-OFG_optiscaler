"""cut3 + split check (CPU, small frame, the GPU is training): the cut OF graph == the model with prop4 / up_full /
deep16 switched off; encoder graph (per frame) + pair graph (cached pyramids) == the single OF graph.
  python test_split_graph.py <OF ckpt>"""
import sys
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
import mlof2_graph as MG

ck = sys.argv[1]
dev = "cpu"
torch.manual_seed(0)
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).eval(); m.load_state_dict(sd.get("model", sd))
for p in ("prop4", "up_full", "deep16"):
    setattr(m.pair, p, False)
H, W = 256, 448
from test_mlof2_inputs import nfru_pair
col, dep = nfru_pair(dev="cpu")
col = F.interpolate(col, size=(H, W), mode="area"); dep = F.interpolate(dep, size=(H, W), mode="area")
e = lambda a, b: f"max {float((a - b).abs().max()):.2e} mean {float((a - b).abs().mean()):.2e}"
with torch.no_grad():
    ref_full, ref_co = MG.model_reference(m, col, dep)
    g = MG.build_of_graph(m)
    print("cut3 OF graph:", g.summary())
    macs = sum(o["w"].numel() * (1088 // g.level(o["out"])) * (1920 // g.level(o["out"])) * g.tensors[MG._parse(o["out"])[0]]["n"] for o in g.ops if o["kind"] == "conv")
    out = MG.Executor(g, H, W, dev).run({"col": col, "dep": dep})
    print(f"  conv GMAC at 1920x1088 (both rows) {macs / 1e9:.2f} | vs model: of_full {e(out['of_full'], ref_full)} | conf_occ {e(out['conf_occ'], ref_co)}")
    ge, gp = MG.build_enc_graph(m), MG.build_pair_graph(m)
    fe = [MG.Executor(ge, H, W, dev).run({"col": col[i:i + 1], "dep": dep[i:i + 1]}) for i in (0, 1)]             
    q = {f"q{lv}": torch.cat((fe[0][f"f{lv}"], fe[1][f"f{lv}"]), 0) for lv in MG.ENC_LEVELS}
    po = MG.Executor(gp, H, W, dev).run({"col": col, **q})
    me = sum(o["w"].numel() * (1088 // ge.level(o["out"])) * (1920 // ge.level(o["out"])) for o in ge.ops if o["kind"] == "conv")
    mp = sum(o["w"].numel() * (1088 // gp.level(o["out"])) * (1920 // gp.level(o["out"])) * 2 for o in gp.ops if o["kind"] == "conv")
    print(f"split: enc {ge.summary()} | pair {gp.summary()}")
    print(f"  GMAC at 1920x1088: encoder {me / 1e9:.2f} per frame + pair {mp / 1e9:.2f} = {(me + mp) / 1e9:.2f} per pair | "
          f"vs single graph: of_full {e(po['of_full'], out['of_full'])} | conf_occ {e(po['conf_occ'], out['conf_occ'])}")
