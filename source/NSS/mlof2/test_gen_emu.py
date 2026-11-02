"""E4 export check: the generation graph through the engine-contract emulator (exported json/bin only), op by op in
isolation against GenExecutor (int8 head), on the second NFRU test pair of test_gen_graph (has_prev).
Also writes the engine harness inputs for that frame: in_<name>.f32 (NHWC), fc.f32, and ref_out.f32.
  python test_gen_emu.py <OF ckpt> <head ckpt> <qstats_int8> <generated dir> <io dir>"""
import sys, os, json, collections
import numpy as np
import torch
sys.argv, args = sys.argv[:1] + sys.argv[1:3], sys.argv[1:]
import test_gen_graph as TG                                                                                   
import mlof2_graph as MG
import mlof2_gen_lower as GL
import mlof2_gen_graph as GG
from mlof2_engine_emu import Emu

ck, hk, qp, gd, io = args
os.makedirs(io, exist_ok=True)
qs = json.load(open(qp))
H, W, dev = TG.H, TG.W, TG.dev
with torch.no_grad():
    p1, cam1 = TG.pair_inputs(16, 18)
    p2, cam2 = TG.pair_inputs(18, 20)
    vstate = {}
    GG.vig_update(vstate, GG.vig_sums(p1["col_a"], p1["col_b"], p1["mv"], p1["mvv"]))
    vig = torch.zeros(1, 16, H // 64, W // 64, device=dev)
    vig[0, 0:9] = vstate["ata"].flatten().float().view(9, 1, 1); vig[0, 9:12] = vstate["atb"].float().view(3, 1, 1)
    inp = dict(p2); inp["mv_ap"] = p1["mv"] * p1["mvv"]; inp["of_prev"] = p1["of"]
    inp["pmask"] = torch.rand(1, 1, H, W, device=dev) * 0.5; inp["vig"] = vig
    vpa, vpb, ivpa = cam2
    fc = {"t": 0.5, "has_prev": True, "pair_first": True, "vp_a": vpa, "vp_b": vpb, "inv_vp_a": ivpa}
    g = TG.g
    ex = GL.GenExecutor(g, H, W, fc, dev, quant=(qs, "int8"))
    em = Emu(gd, "mlof2_gen", H, W); em.fc = fc
    nm = {t["name"]: i for i, t in enumerate(em.T)}
    for k_, x in inp.items():
        ex.v[k_] = x.float(); em.view(nm[k_])[:] = x.float().permute(0, 2, 3, 1)
    worst = collections.defaultdict(float); bad = 0
    for i, (o, oj) in enumerate(zip(g.ops, em.j["ops"])):
        names_in = {MG._parse(r)[0] for r in o["ins"]} | ({MG._parse(o["res"])[0]} if o.get("res") else set())
        for n_ in names_in | ({MG._parse(o["out"])[0]} if MG._parse(o["out"])[0] in ex.v else set()):
            em.view(nm[n_])[:] = ex.v[n_].permute(0, 2, 3, 1)
        y = ex.op(i, o); ex.put(o["out"], y)
        ye = em.op(oj); em.write(oj, ye)
        a = ex.get(o["out"]); b = em.tensor_nchw(oj["out"])[:, oj["out_coff"]:oj["out_coff"] + oj["out_c"]]
        rel = float((a - b).abs().max()) / max(float(a.abs().max()), 1e-6)
        worst[o["kind"]] = max(worst[o["kind"]], rel)
        if rel > (2e-2 if o["kind"] == "conv" else 1e-4):
            bad += 1
            print(f"op {i} {o['kind']} -> {o['out']} rel {rel:.2e}")
    print(f"{len(g.ops)} ops, {bad} over tolerance; worst: " + ", ".join(f"{k} {v:.1e}" for k, v in worst.items()))
                                   
    for k_, x in inp.items():
        x.permute(0, 2, 3, 1).contiguous().cpu().numpy().astype(np.float32).tofile(os.path.join(io, f"in_{k_}.f32"))
    fcv = np.zeros(GG.FC_WORDS, np.float32)
    fcv[GG.FC["t"]] = 0.5; fcv[GG.FC["has_prev"]] = 1; fcv[GG.FC["pair_first"]] = 1
    fcv[GG.FC["vp_a"]:GG.FC["vp_a"] + 16] = vpa.cpu().numpy().reshape(-1)
    fcv[GG.FC["vp_b"]:GG.FC["vp_b"] + 16] = vpb.cpu().numpy().reshape(-1)
    fcv[GG.FC["inv_vp_a"]:GG.FC["inv_vp_a"] + 16] = ivpa.cpu().numpy().reshape(-1)
    fcv.tofile(os.path.join(io, "fc.f32"))
    print("wrote harness inputs to", io)
