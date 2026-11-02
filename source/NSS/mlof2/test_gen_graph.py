"""E4 check: the generation op table (mlof2_gen_lower) == mlof2_gen_graph.gen_reference, on two consecutive NFRU test
pairs (the second has a previous pair: acceleration, rel_t carry), fp32; then int8 head vs the QWrap head.
  python test_gen_graph.py <OF ckpt> <head ckpt> [qstats]"""
import sys, json, copy
import torch
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2
from nfru_head import load_head_c2
from data_v2 import TONE_CURVES, srgb_encode, quantize, depth_feature, _warp_border
from quant_ptq import fold_bn, quantize as qz
import mlof2_gen_graph as GG
import mlof2_gen_lower as GL

ck, hk = sys.argv[1:3]
qs = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else None
dev = "cuda"
s = safe_open("/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors", "pt")
H, W, h = 1088, 1920, 540
pad = lambda x: F.pad(x, (0, 0, 0, H - 1080), mode="replicate")
lin = lambda i: s.get_slice("rgb_linear")[i:i + 1].float()
zn = s.get_tensor("NearPlane").float()
VP = s.get_tensor("ViewProj").double()
mv1 = lambda i: F.interpolate(s.get_slice("mv_{}_f60_m1")[i:i + 1].float().flip(1) * (1080 / h), size=(1080, 1920), mode="bilinear", align_corners=False)
dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), zn[i]), size=(1080, 1920), mode="bilinear", align_corners=False)
def display(x, ref):
    lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
    return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * 0.18 / torch.exp(torch.log(lum(ref)).mean())).clamp(0, 1)), 8)
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
head = load_head_c2(hk, dev); head.talign = "fp"
fold_bn(head)
g = GL.build_gen_graph(head)
print(g.summary())
N = 2


def pair_inputs(fa, fb):
    la = lin(fa)
    ca, cb = pad(display(la, la)).to(dev), pad(display(lin(fb), la)).to(dev)
    da, db = pad(dfeat(fa)).to(dev), pad(dfeat(fb)).to(dev)
    acc = mv1(fb)
    for j in range(1, fb - fa):
        acc = acc + _warp_border(mv1(fb - j), acc)
    mv = pad(acc).to(dev); mvv = torch.ones_like(mv[:, :1])
    with torch.no_grad():
        pr = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
    dA = F.interpolate(s.get_slice("depth")[fa:fa + 1].float(), size=(1080, 1920), mode="nearest")
    vpa, vpb = VP[fa].T.float().to(dev), VP[fb].T.float().to(dev)
    of = pr.get("of_ba_full")
    if of is None:                                                                                      
        from nfru_head import up4
        of = up4(pr["of_ba"], H, W)
    return {"col_a": ca, "col_b": cb, "dep_a": da, "dep_b": db, "ndc_a": pad(1 - dA).to(dev), "mv": mv, "mvv": mvv,
            "of": of, "of4": pr["of_ba"],                                                                           
            "co": torch.cat((pr["conf"][:1], pr["occ"][:1]), 1)}, (vpa, vpb, torch.linalg.inv(vpa))


e = lambda a, b: f"max {float((a - b).abs().max()):.2e} mean {float((a - b).abs().mean()):.2e}"
with torch.no_grad():
    p1, cam1 = pair_inputs(16, 18)
    p2, cam2 = pair_inputs(18, 20)
    vstate = {}
    vig = torch.zeros(1, 16, H // 64, W // 64, device=dev)
    pm_ref = torch.zeros(1, 1, H, W, device=dev); pm_ex = pm_ref.clone()
    zeros2 = torch.zeros(1, 2, H, W, device=dev)
    for pi, (p, cam, prev) in enumerate(((p1, cam1, None), (p2, cam2, p1))):
        lv = GG.vig_update(vstate, GG.vig_sums(p["col_a"], p["col_b"], p["mv"], p["mvv"]))
        inp = dict(p)
        inp["mv_ap"] = prev["mv"] * prev["mvv"] if prev else zeros2
        inp["of_prev"] = prev["of"] if prev else zeros2
        hp = prev is not None
        ref, mref = GG.gen_reference(head, {**inp, "pmask": pm_ref}, 0.5, hp, lv, cam)
        fc = {"t": 0.5, "has_prev": hp, "pair_first": True, "vp_a": cam[0], "vp_b": cam[1], "inv_vp_a": cam[2]}
        ex = GL.GenExecutor(g, H, W, fc, dev)
        out = ex.run({**inp, "pmask": pm_ex, "vig": vig})
        print(f"pair {pi} (has_prev {hp}): out {e(out['out'], ref)} | mask {e(out['pmask'], mref)} | "
              f"vig lv ref {[round(float(v), 4) for v in lv]} exec {[round(float(v), 4) for v in out['vig'][0, 12:15, 0, 0]]}")
        if qs is not None:                                                                                
            hq = copy.deepcopy(head)
            for w_ in qz(hq, "int8"):
                w_.stat = qs["head." + w_.name]
            refq, _ = GG.gen_reference(hq, {**inp, "pmask": pm_ref}, 0.5, hp, lv, cam)
            exq = GL.GenExecutor(g, H, W, {**fc, "pair_first": False}, dev, quant=(qs, "int8")).run(
                {**inp, "pmask": pm_ex, "vig": out["vig"].clone()})
            print(f"   int8 head: graph vs QWrap {e(exq['out'], refq)} | int8 vs fp32 {e(refq, ref)}")
        vig, pm_ex, pm_ref = out["vig"].clone(), out["pmask"].clone(), mref
