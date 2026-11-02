"""Graph lowering check for the fpn / MatchEncoder / recurrent-block model: Executor (fp32) of the OF graph and of the
enc + pair graphs vs the model's own forward, on a Spring pair (CPU).  python test_graph_rec.py <ckpt> [H W]"""
import sys, torch
from torch.nn import functional as F
from safetensors import safe_open
import mlof2_graph as G
from model_v2 import build_mlof2
from data_v2 import depth_feature
ck = sys.argv[1]
H, W = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (512, 768)
if ck == "random_ctx":                                                                                       
    from model_v2 import MLOF2
    torch.manual_seed(0)
    m = MLOF2(enc_deep=True, enc_fpn=True, recur8=3, enc_match=True, enc_match_ctx=True, convex_up=True).eval()
    for n_, p_ in m.named_parameters():                                                                              
        if p_.abs().sum() == 0: p_.data.normal_(0, 0.02)
else:
    sd = torch.load(ck, map_location="cpu"); sd = sd.get("model", sd)
    m = build_mlof2(sd).eval(); m.load_state_dict(sd)
m.pair.seeded = False
s = safe_open("/home/sh/spring_mlof/validation/SP_0038/crop_00.safetensors", "pt")
Hs, Ws = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
def fr(i):
    c = s.get_slice("ground_truth_srgb8")[i:i + 1].float() / 255.0
    d = F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), s.get_slice("zNear")[i:i + 1].float().view(-1, 1, 1, 1)), size=(Hs, Ws), mode="bilinear", align_corners=False)
    return c[..., 200:200 + H, 400:400 + W], d[..., 200:200 + H, 400:400 + W]
ca, da = fr(0); cb, db = fr(4)
col, dep = torch.cat((cb, ca), 0), torch.cat((db, da), 0)                             
with torch.no_grad():
    ref_full, ref_co = G.model_reference(m, col, dep)
                                                                                                               
    ge, gp = G.build_enc_graph(m), G.build_pair_graph(m)
    print("enc graph:", ge.summary()); print("pair graph:", gp.summary(), "inputs", gp.inputs, "outputs", gp.outputs)
    ex = [G.Executor(ge, H, W, device="cpu").run({"col": col[i:i + 1], "dep": dep[i:i + 1]}) for i in (0, 1)]
    inp = {"c4": torch.cat((ex[0]["c4"], ex[1]["c4"]), 0)}
    for lv in G.ENC_LEVELS:
        inp[f"q{lv}"] = torch.cat((ex[0][f"f{lv}"], ex[1][f"f{lv}"]), 0)
    if "qm8" in gp.inputs:
        inp["qm8"] = torch.cat((ex[0]["fm8"], ex[1]["fm8"]), 0)
    op = G.Executor(gp, H, W, device="cpu").run(inp)
    of4_ref = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]["of"][:1]
    print(f"enc+pair graphs vs model: of4 max {(op['of4'] - of4_ref).abs().max():.2e} mean {(op['of4'] - of4_ref).abs().mean():.2e}"
          f" | conf_occ max {(op['conf_occ'][:1] - ref_co[:1]).abs().max():.2e}")
    nk = {}
    for x in gp.ops: nk[x["kind"]] = nk.get(x["kind"], 0) + 1
    print("pair op kinds:", nk)
