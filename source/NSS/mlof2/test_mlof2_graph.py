"""E1 check: the op-table executor (mlof2_graph) == the model's own OF forward, fp32 and int8 fake quant (quant_ptq).
  python test_mlof2_graph.py <OF ckpt> [qstats json]   (inputs: one NFRU test pair, display look as eval_nfru_mfg)"""
import sys, json, copy
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from data_v2 import TONE_CURVES, srgb_encode, quantize, depth_feature
import mlof2_graph as MG

ck = sys.argv[1]
qs = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else None
dev = "cuda"
s = safe_open("/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors", "pt")
H, W = 1088, 1920
pad = lambda x: F.pad(x, (0, 0, 0, H - 1080), mode="replicate")
lin = lambda i: s.get_slice("rgb_linear")[i:i + 1].float()
def display(x, ref):
    lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
    return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * 0.18 / torch.exp(torch.log(lum(ref)).mean())).clamp(0, 1)), 8)
zn = s.get_tensor("NearPlane").float()
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), zn[i]), size=(1080, 1920), mode="bilinear", align_corners=False)
fa_, fb_ = 18, 20
la = lin(fa_)
col = torch.cat((pad(display(lin(fb_), la)), pad(display(la, la))), 0).to(dev)
dep = torch.cat((pad(dfeat(fb_)), pad(dfeat(fa_))), 0).to(dev)
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
g = MG.build_of_graph(m)
print(g.summary())
macs = sum(o["w"].numel() * (H // g.level(o["out"])) * (W // g.level(o["out"])) * g.tensors[MG._parse(o["out"])[0]]["n"] for o in g.ops if o["kind"] == "conv")
print(f"conv GMAC (both rows) {macs / 1e9:.2f}")
with torch.no_grad():
    ref_full, ref_co = MG.model_reference(m, col, dep)
    out = MG.Executor(g, H, W, dev).run({"col": col, "dep": dep})
    e = lambda a, b: f"max {float((a - b).abs().max()):.2e} mean {float((a - b).abs().mean()):.2e}"
    print("fp32  of_full", e(out["of_full"], ref_full), "| conf_occ", e(out["conf_occ"], ref_co))
    o16 = MG.Executor(g, H, W, dev, fp16_storage=True).run({"col": col, "dep": dep})
    print("fp16 storage  of_full", e(o16["of_full"], ref_full), f"(|flow| mean {float(ref_full.norm(dim=1).mean()):.1f} px)")
    if qs is not None:
        from quant_ptq import quantize as qz
        mq = copy.deepcopy(m)
        for w_ in qz(mq, "int8"):
            w_.stat = qs["of." + w_.name]
        qf, qco = MG.model_reference(mq, col, dep)
        oq = MG.Executor(g, H, W, dev, quant=(qs, "int8")).run({"col": col, "dep": dep})
        print("int8  graph vs QWrap model: of_full", e(oq["of_full"], qf), "| conf_occ", e(oq["conf_occ"], qco))
        print("int8  vs fp32 model: of_full", e(oq["of_full"], ref_full))
