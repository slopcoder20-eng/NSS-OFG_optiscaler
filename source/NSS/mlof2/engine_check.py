"""MLOF2 engine harness I/O and the per-op check (docs/NFRU_MLOF2_ENGINE_PLAN_20261023.md, E3).
  python engine_check.py inputs <io dir>                       write col.f32 / dep.f32 (NHWC, rows B, A; one NFRU pair)
  python engine_check.py check <io dir> <generated dir> [ops]  per-op check of the harness dump (op_NNN.f32): every op
        recomputed by the emulator FROM THE ENGINE'S OWN INPUTS (the dumps of the ops that produced them), so the
        rounding chaos of int8 boundaries does not accumulate and each kernel is judged alone.
  python engine_check.py final <io dir> <generated dir> <OF ckpt> <qstats>   end result vs the torch reference
Contract v2 graphs (json "contract": 2) are detected: the harness dumps every op's output tensor as its RAW storage,
op_NNN.bin = n * h * w * c_alloc elements of the tensor's format (fp32 / fp16 / int8 / fp8 e4m3fn), padding
channels included; graph inputs in_<name>.f32 (fp32, encoded into the tensor's format) or in_<name>.bin (raw, e.g.
the 8-bit pyramids an encoder run dumped). The emulator is fed the engine's own bytes (so its conv-read padding check
also checks the engine zeroed the padding), the reference output is encoded into the same format and compared:
8-bit in codes (int8 code difference, fp8 ulp distance), share of codes off by 1 (rounding boundaries) and > 1.
  python engine_check.py emudump <io dir> <generated dir>   v2: the emulator writes the dumps the harness would (a self
        test of this checker, and reference files for the harness)"""
import sys, os, json, collections
import numpy as np
import torch
from mlof2_engine_emu import Emu

H, W = 1088, 1920


NPDT = {0: np.float32, 1: np.float16, 2: np.int8, 3: np.uint8}
TDT = {0: torch.float32, 1: torch.float16, 2: torch.int8, 3: torch.float8_e4m3fn}


def load_raw(path, d):
    """v2: the raw storage (n, h, w, c_alloc) in the tensor's torch dtype."""
    a = np.fromfile(path, dtype=NPDT[d["fmt"]])
    h, w = H // d["s"], W // d["s"]
    assert a.size == d["n"] * h * w * d["c_alloc"], (path, a.size)
    t = torch.from_numpy(a.copy())
    return (t.view(torch.float8_e4m3fn) if d["fmt"] == 3 else t).view(d["n"], h, w, d["c_alloc"])


def code_dist(a, b, fmt):
    """Distance in codes between two raw 8-bit tensors (int8: |a - b|; fp8: ulps via the ordered integer of the bits)."""
    if fmt == 2:
        return (a.int() - b.int()).abs()
    o = lambda x: (lambda u: torch.where(u >= 128, 128 - u, u))(x.view(torch.uint8).int())                              
    return (o(a) - o(b)).abs()


def check_v2(io, gd, em):
    T, ops = em.T, em.j["ops"]
    pre = os.environ.get("DUMP_PREFIX", "")
    for ti, td in enumerate(T):                                        
        for fn in (f"in_{td['name']}.bin", f"{td['name']}.bin"):
            if os.path.exists(os.path.join(io, fn)):
                em.raw(ti)[:] = load_raw(os.path.join(io, fn), td).to(em.dev)
                break
        else:
            for fn in (f"in_{td['name']}.f32", f"{td['name']}.f32"):
                if os.path.exists(os.path.join(io, fn)):
                    em.put(ti, 0, load_t(os.path.join(io, fn), {**td, "c": td["c"]}).to(em.dev))
                    break
            else:
                for fn in (f"out_{td['name']}.bin",):
                    if os.path.exists(os.path.join(io, fn)):
                        em.raw(ti)[:] = load_raw(os.path.join(io, fn), td).to(em.dev)
                        break
    worst = collections.defaultdict(float)
    bad = 0
    with torch.no_grad():
        for i, o in enumerate(ops):
            em._cur = i
            td = T[o["out"]]
            keep = em.raw(o["out"]).clone()                                                                           
            eng = load_raw(os.path.join(io, f"{pre}op_{i:03d}.bin"), td).to(em.dev)
            try:
                ref = em.op(o)                                                                               
            except AssertionError as ex_:                                                                              
                bad += 1
                print(f"op {i:3d} {o['kind']:10s} -> {td['name']:12s} input: {ex_}")
                em.raw(o["out"])[:] = eng
                continue
            em.raw(o["out"])[:] = keep
            em.write(o, ref)                                                                          
            refr = em.raw(o["out"]).clone()
            em.raw(o["out"])[:] = eng                                                           
            if o["kind"] in ("vig_part", "median_hist"):                                                                    
                continue
            sl = slice(o["out_coff"], o["out_coff"] + o["out_c"])
            if o["kind"] == "vig_solve":
                eng_, ref_ = eng[:, :1, :1, sl], refr[:, :1, :1, sl]
            else:
                eng_, ref_ = eng[..., sl], refr[..., sl]
            if td["fmt"] >= 2:
                cd = code_dist(eng_, ref_, td["fmt"])
                n1, n2 = float((cd == 1).float().mean()), float((cd > 1).float().mean())
                pad_bad = (td["c_alloc"] > td["c"] and o["out_coff"] + o["out_c"] == td["c"]
                           and not bool((eng[..., td["c"]:].float() == 0).all()))
                worst[f"{o['kind']} >1 code"] = max(worst[f"{o['kind']} >1 code"], n2)
                worst[f"{o['kind']} 1 code"] = max(worst[f"{o['kind']} 1 code"], n1)
                tol2 = 1e-3 if o["kind"] in ("conv", "warp", "resize_bil", "corr") else 0.0
                if n2 > tol2 or n1 > 0.02 or pad_bad:
                    bad += 1
                    if bad <= 12:
                        print(f"op {i:3d} {o['kind']:10s} -> {td['name']:12s} 8-bit codes off by 1 {n1:.2e}, by >1 {n2:.2e}"
                              f"{' PADDING NOT ZERO' if pad_bad else ''}")
            else:
                e, r = eng_.float(), ref_.float()
                nan = int(torch.isnan(e).sum())
                if o["kind"] in ("invert_t", "cam_inv", "inv3", "cam_inv_q"):                                                   
                    flips = int(((e[..., 4:6] - r[..., 4:6]).abs() > 0.5).sum())
                    worst[o["kind"] + " flag flips (px)"] = max(worst[o["kind"] + " flag flips (px)"], flips)
                    if flips < 20:
                        fl = ((e[..., 4:6] - r[..., 4:6]).abs() > 0.5).any(-1, keepdim=True)                                     
                        e, r = torch.where(fl, r[..., :4], e[..., :4]), r[..., :4]
                d = (e - r).abs()
                rel = float(d.max()) / max(float(r.abs().max()), 1e-6)
                worst[o["kind"]] = max(worst[o["kind"]], rel)
                tol = (3e-3 if o["kind"] == "final4" else (2e-3 if td["fmt"] == 1 else 1e-3)) if o["kind"] in ("conv", "warp", "warp_noise", "invert_t", "resize_bil",
                                                                       "cam_flow", "vig_solve", "carry", "cam_inv", "inv3", "prep_h", "q_cand", "q_rule2",
                                                                       "cam_inv_q", "final4") else (1e-3 if td["fmt"] == 1 else 1e-4)
                npx = int((d.amax(-1) > tol * max(float(r.abs().max()), 1e-6)).sum())
                if o["kind"] in ("invert_t", "cam_inv", "inv3", "cam_inv_q") and not nan and npx < 20:                                   
                    worst[o["kind"] + " px elsewhere"] = max(worst[o["kind"] + " px elsewhere"], npx)                
                    rel = 0.0                                                                                   
                if nan or rel > tol:
                    bad += 1
                    if bad <= 12:
                        print(f"op {i:3d} {o['kind']:10s} -> {td['name']:12s} rel {rel:.2e} max {float(d.max()):.3e} nan {nan} "
                              f"({npx} px over)")
    print(f"{len(ops)} ops, {bad} over tolerance; worst per kind: " + ", ".join(f"{k} {v:.1e}" for k, v in worst.items()))


def emudump(io, em):
    """v2 self test: run the emulator on the io inputs and write op_NNN.bin like the harness."""
    T = em.T
    for ti, td in enumerate(T):
        for fn in (f"in_{td['name']}.bin",):
            if os.path.exists(os.path.join(io, fn)):
                em.raw(ti)[:] = load_raw(os.path.join(io, fn), td).to(em.dev)
                break
        else:
            for fn in (f"in_{td['name']}.f32", f"{td['name']}.f32"):
                if os.path.exists(os.path.join(io, fn)):
                    em.put(ti, 0, load_t(os.path.join(io, fn), td).to(em.dev))
                    break
    with torch.no_grad():
        for i, o in enumerate(em.j["ops"]):
            em._cur = i
            em.write(o, em.op(o))
            r = em.raw(o["out"])
            (r.view(torch.uint8) if T[o["out"]]["fmt"] == 3 else r).contiguous().cpu().numpy().tofile(
                os.path.join(io, f"{os.environ.get('DUMP_PREFIX', '')}op_{i:03d}.bin"))
    print(f"wrote {len(em.j['ops'])} op dumps to {io}")


def load_t(path, d):
    a = np.fromfile(path, dtype=np.float32)
    h, w = H // d["s"], W // d["s"]
    assert a.size == d["n"] * h * w * d["c"], (path, a.size)
    return torch.from_numpy(a).view(d["n"], h, w, d["c"])


if __name__ == "__main__":
    mode, io = sys.argv[1], sys.argv[2]
    os.makedirs(io, exist_ok=True)
    if mode == "inputs":
        from test_mlof2_inputs import nfru_pair
        col, dep = nfru_pair()
        col.permute(0, 2, 3, 1).contiguous().cpu().numpy().astype(np.float32).tofile(os.path.join(io, "col.f32"))
        dep.permute(0, 2, 3, 1).contiguous().cpu().numpy().astype(np.float32).tofile(os.path.join(io, "dep.f32"))
        print("wrote", io)
    elif mode in ("check", "emudump"):
        gd = sys.argv[3]
        em = Emu(gd, os.environ.get("GRAPH_PREFIX", "mlof2_of"), H, W)                                         
        fc_fn = os.environ.get("FC_FILE")
        if not fc_fn:
            pre_ = os.environ.get("DUMP_PREFIX", "")
            fc_fn = f"{pre_}fc.f32" if os.path.exists(os.path.join(io, f"{pre_}fc.f32")) else "fc.f32"
        if os.path.exists(os.path.join(io, fc_fn)):                                        
            import mlof2_gen_graph as GG
            fv = torch.from_numpy(np.fromfile(os.path.join(io, fc_fn), dtype=np.float32))
            mat = lambda k: fv[GG.FC[k]:GG.FC[k] + 16].view(4, 4).cuda()
            em.fc = {"t": float(fv[GG.FC["t"]]), "has_prev": bool(fv[GG.FC["has_prev"]]), "pair_first": bool(fv[GG.FC["pair_first"]]),
                     "vp_a": mat("vp_a"), "vp_b": mat("vp_b"), "inv_vp_a": mat("inv_vp_a")}
        if em.v2:
            check_v2(io, gd, em) if mode == "check" else emudump(io, em)
            sys.exit(0)
        assert mode == "check", "emudump: contract v2 graphs only"
        T, ops = em.T, em.j["ops"]
        state = {}
        for ti, td in enumerate(T):                                                                 
            for fn in (f"in_{td['name']}.f32", f"{td['name']}.f32"):
                if os.path.exists(os.path.join(io, fn)):
                    state[ti] = load_t(os.path.join(io, fn), td)
                    break
        if os.path.exists(os.path.join(io, "fc.f32")):                                        
            import mlof2_gen_graph as GG
            fv = torch.from_numpy(np.fromfile(os.path.join(io, "fc.f32"), dtype=np.float32))
            mat = lambda k: fv[GG.FC[k]:GG.FC[k] + 16].view(4, 4).cuda()
            em.fc = {"t": float(fv[GG.FC["t"]]), "has_prev": bool(fv[GG.FC["has_prev"]]), "pair_first": bool(fv[GG.FC["pair_first"]]),
                     "vp_a": mat("vp_a"), "vp_b": mat("vp_b"), "inv_vp_a": mat("inv_vp_a")}
        last_writer = {}
        worst = collections.defaultdict(float)
        bad = 0
        with torch.no_grad():
            for i, o in enumerate(ops):
                reads = {em.j["segs"][o["seg0"] + k][0] for k in range(o["nseg"])}
                if o["kind"] == "conv" and o["ip"][6] >= 0:
                    reads.add(o["ip"][6])
                for t in reads:
                    em.view(t)[:] = state[t].cuda()
                if o["out"] in state:                                                                                 
                    em.view(o["out"])[:] = state[o["out"]].cuda()
                ref = em.op(o)
                eng = load_t(os.path.join(io, f"{os.environ.get('DUMP_PREFIX', '')}op_{i:03d}.f32"), T[o["out"]])
                state[o["out"]] = eng
                if o["kind"] == "vig_part":                                                                                
                    continue
                if o["kind"] == "vig_solve":                                                       
                    eng = eng[:, :1, :1]; ref = ref[:, :, :1, :1]
                e = eng.cuda().permute(0, 3, 1, 2)[:, o["out_coff"]:o["out_coff"] + o["out_c"]]
                nan = int(torch.isnan(e).sum())
                d = (e - ref).abs()
                rel = float(d.max()) / max(float(ref.abs().max()), 1e-6)
                worst[o["kind"]] = max(worst[o["kind"]], rel)
                tol = 1e-3 if o["kind"] in ("conv", "warp", "warp_noise", "invert_t", "resize_bil", "cam_flow", "vig_solve") else 1e-4
                if o["kind"] == "invert_t":                                                                              
                    flips = int(((e[:, 4:6] - ref[:, 4:6]).abs() > 0.5).sum())
                    worst["invert_t flag flips (px)"] = max(worst["invert_t flag flips (px)"], flips)
                    d6 = (e[:, :4] - ref[:, :4]).abs()
                    rel = float(d6.max()) / max(float(ref[:, :4].abs().max()), 1e-6) if flips < 20 else rel
                if nan or rel > tol:
                    bad += 1
                    if bad <= 12:
                        print(f"op {i:3d} {o['kind']:10s} -> {T[o['out']]['name']:12s} rel {rel:.2e} max {float(d.max()):.3e} "
                              f"mean {float(d.mean()):.3e} nan {nan}")
        print(f"{len(ops)} ops, {bad} over tolerance; worst rel per kind: " + ", ".join(f"{k} {v:.1e}" for k, v in worst.items()))
