"""MLOF2 op table -> engine files (docs/NFRU_MLOF2_ENGINE_PLAN_20261023.md, E1).
  python export_mlof2_engine.py <OF ckpt> <qstats_int8.json> <out dir>
writes
  mlof2_of_graph.h   tensor / segment / op tables (C, shared by the VK and DX12 engines)
  mlof2_of.bin       weights: per conv int8 [oc][kh][kw][ic groups of 4] as uint32 words, then fp32 out scale [oc]
                     (= act scale * weight scale) and fp32 bias [oc]; little endian, offsets in uint32 words
  mlof2_of.json      the same tables, readable (debug)
Engine contract (engine 1, correctness first; fp16 storage / fp8 are the optimiser's call):
  tensors fp32, NHWC, rows (n) outermost: element (row, y, x, c) at base + ((row * h + y) * w + x) * c_alloc + c,
  h = H / s, w = W / s for the padded frame H x W (multiples of 64);
  a segment = (tensor, channel offset, channels, swap rows); a conv reads its input segments in order as one
  concatenated input, each segment padded to a multiple of 4 channels with zero weights;
  conv: q = clamp(roundEven(x * in_inv_scale), -127, 127) per input value, int32 acc = sum q * w (dp4a),
  (fp8 blob, argv[4] = fp8: q = e4m3fn(saturate(x * in_inv_scale)), round to nearest even; acc = sum q * w in fp32)
  y = acc * out_scale[oc] + bias[oc]; act; residual (post: res + act(y), pre: act(y + res)); out of range taps = 0
  (zero padding after quantization). Other ops: semantics in mlof2_graph.py.
Engine contract v2 (STORE=v2, 2026-10-23; the network part 8-bit, the math fp16+):
  every tensor has a storage format (fmt 0 fp32, 1 fp16, 2 int8, 3 fp8 e4m3fn), an allocated channel count c_alloc
  (8-bit: multiple of 4, fp16: multiple of 2) and a dequant scale (8-bit only; value = code * scale).
  Byte address of (row, y, x, c) = off_units * 16 * (H * W / 4096) + (((row * h + y) * w + x) * c_alloc + c) * esz
  (esz 4 / 2 / 1 / 1; every tensor 16-byte aligned).
  EVERY op reads through decode(fmt, scale) and writes through encode(fmt, scale) of the tensor table
  (encode 8-bit: int8 clamp(roundEven(v / scale), -127, 127), fp8 e4m3fn(saturate(v / scale)) RNE).
  A writer of an 8-bit tensor also writes zeros into channels c .. c_alloc-1 (fp8 has NaN codes: garbage there would
  reach the WMMA through zero weights).
  Tensors a conv reads are 8-bit, one scale per group of tensors concatenated into the same conv input, and that
  conv's in_inv_scale (fp[0]) is exactly 1 / that scale: the conv feeds the stored codes straight into the WMMA /
  dp4a (no requantization). Everything else (flows, conf, warp / corr results no conv reads, generation math) fp16.
  Graph inputs / outputs fp32, except the encoder -> pair pyramids (f*/q*: 8-bit, the pair graph's scales)."""
import sys, os, json, struct
import torch
import numpy as np
from model_v2 import build_mlof2
import mlof2_graph as MG

from mlof2_gen_lower import GEN_KINDS

KINDS = ["conv", "unshuffle", "resize_area", "resize_bil", "warp", "corr", "absdiff", "round_trip", "spread", "axpy",
         "scale", "zeros", "copy", "convex_up", "prop_step"] + GEN_KINDS                                     
ACTS = {"none": 0, "leaky": 1, "relu": 2}


FMT_CODE = {"fp32": 0, "fp16": 1, "int8": 2, "fp8": 3}
FMT_NAME = {v: k for k, v in FMT_CODE.items()}
ESZ = {0: 4, 1: 2, 2: 1, 3: 1}


def v2_formats(g, qstats, fmt, io_fmt=None):
    qstats = MG.expand_qstats(g, qstats)
    """Contract v2 storage: {tensor: (fmt code, dequant scale, stat)} + the conv input stats (= the stored group
    scales). io_fmt: {tensor: (fmt name, stat)} overrides (the encoder / pair pyramids)."""
    QMAX = 127.0 if fmt == "int8" else 448.0
    plan = MG.storage_plan(g, qstats, "v2_" + fmt)
    out = {}
    for t in g.tensors:
        f = plan.get(t, ("fp16", None))
        if t in g.inputs or t in g.outputs or t.startswith('h_acc') or t.startswith('h_out'):
            f = ("fp32", None)
        if io_fmt and t in io_fmt:
            f = io_fmt[t]
        out[t] = (FMT_CODE[f[0]], f[1] / QMAX if f[1] is not None else 1.0, f[1])
    return out, MG.storage_conv_stats(g, plan, qstats)


def dead_ops_removed(g):
    """A copy of g without the ops whose output tensor nothing reads and is no graph output (e.g. the finest level's
    context copy of the pair graph), repeated until none is left; their tensors go too."""
    import copy
    g = copy.copy(g)
    ops = list(g.ops)
    while True:
        live = set(g.outputs) | {MG._parse(r)[0] for o in ops for r in o["ins"] + ([o["res"]] if o.get("res") else [])}
        keep = [o for o in ops if MG._parse(o["out"])[0] in live]
        if len(keep) == len(ops):
            break
        ops = keep
    used = set(g.inputs) | set(g.outputs) | {MG._parse(o["out"])[0] for o in ops} | live
    g.ops = ops
    g.tensors = {n: t for n, t in g.tensors.items() if n in used}
    return g


def export(g, qstats, out_dir, prefix, H=1088, W=1920, fmt="int8", store=None, keep_inputs=False):
    """store: None (contract v1, fp32 arena) or v2_formats() output {tensor: (fmt code, scale, stat)}."""
    QMAX = 127.0 if fmt == "int8" else 448.0                                                                                 
    g = dead_ops_removed(g)
    names = list(g.tensors)
    tid = {n: i for i, n in enumerate(names)}
    segs, ops, blob = [], [], []

    def seg(ref):
        n, sw, sl = MG._parse(ref)
        c0, c1 = sl if sl is not None else (0, g.tensors[n]["c"])
        segs.append((tid[n], c0, c1 - c0, int(sw)))
        return len(segs) - 1

    def words(a):
        off = len(blob)
        blob.extend(a)
        return off

    for o in g.ops:
        k = o["kind"]
                                                                                                        
                                                                                   
        mode = {"gru": 1, "tanh": 2}.get(k, 0)
        if k == "affine":
            k = "scale"
        elif k in ("gru", "tanh"):
            k = "axpy"
        out_n, _, out_sl = MG._parse(o["out"])
        oc0, oc1 = out_sl if out_sl is not None else (0, g.tensors[out_n]["c"])
        seg0 = len(segs)
        for r in o["ins"]:
            seg(r)
        rec = {"kind": KINDS.index(k), "out": tid[out_n], "out_coff": oc0, "out_c": oc1 - oc0, "seg0": seg0,
               "nseg": len(o["ins"]), "ip": [0] * 8, "fp": [0.0] * 4, "w_off": 0, "scale_off": 0, "bias_off": 0,
               "kw_words": 0}
        if k == "conv":
            w = o["w"].float()
            ocn, _, kh, kw = w.shape
                                     
            cols, c0 = [], 0
            for r in o["ins"]:
                c = g.chans(r)
                part = w[:, c0:c0 + c]
                pad = (-c) % 4
                if pad:
                    part = torch.cat((part, torch.zeros(ocn, pad, kh, kw)), 1)
                cols.append(part)
                c0 += c
            assert c0 == w.shape[1]
            w = torch.cat(cols, 1)                                                              
            a = w.abs().flatten(1).amax(1).clamp_min(1e-12)
            if fmt == "int8":
                wq = torch.clamp(torch.round(w / (a / QMAX).view(-1, 1, 1, 1)), -127, 127).to(torch.int8)
            else:
                wq = (w / (a / QMAX).view(-1, 1, 1, 1)).clamp(-QMAX, QMAX).to(torch.float8_e4m3fn)
            st = max(float(qstats[o["q"]]), 1e-8)                                                           
            if store is not None:                                                                                 
                for r in o["ins"]:
                    tf_ = store[MG._parse(r)[0]]
                    assert tf_[0] == FMT_CODE[fmt] and abs(tf_[2] - st) <= 1e-6 * st, (o["q"], r, tf_, st)
            s_act = st / QMAX
            wq = wq.permute(0, 2, 3, 1).contiguous()                                            
            u = wq.view(torch.uint8).numpy().reshape(ocn, -1, 4)
            packed = (u[..., 0].astype(np.uint32) | (u[..., 1].astype(np.uint32) << 8) |
                      (u[..., 2].astype(np.uint32) << 16) | (u[..., 3].astype(np.uint32) << 24)).reshape(-1)
            rec["kw_words"] = int(packed.size // ocn)
            rec["w_off"] = words(packed.tolist())
            sc = (a / QMAX * s_act).numpy().astype(np.float32)
            rec["scale_off"] = words(np.frombuffer(sc.tobytes(), np.uint32).tolist())
            rec["bias_off"] = words(np.frombuffer(o["b"].float().numpy().astype(np.float32).tobytes(), np.uint32).tolist())
            res_t, res_c0 = -1, 0
            if o["res"] is not None:
                rn, _, rsl = MG._parse(o["res"])
                res_t, res_c0 = tid[rn], (rsl[0] if rsl else 0)
            rec["ip"] = [kh, kw, o["stride"], o["pad"], o["dil"], ACTS[o["act"]], res_t,
                         res_c0 if o["res_mode"] == "post" else -1 - res_c0]                                   
            rec["fp"] = [1.0 / s_act, 0.0, 0.0, 0.0]
        elif k in ("unshuffle", "convex_up"):
            rec["ip"][0] = o["f"]
        elif k in ("resize_area", "resize_bil"):
            rec["ip"][0] = o["s_out"]
            if k == "resize_bil":
                mul = o["mul"]
                rec["fp"] = [float(mul[0]), float(mul[1] if len(mul) > 1 else mul[0]), 0.0, 0.0]
                                                                                                             
                assert len(mul) == 2 or all(abs(x - 1.0) < 1e-9 for x in mul), "per-channel mul: 2 channels or all 1"
        elif k == "corr":
            rec["ip"][0] = o["radius"]
        elif k in ("axpy", "scale"):
            rec["fp"][0] = float(o.get("k", 1.0))
            rec["fp"][1] = float(o.get("c", 0.0)) if k == "scale" else 0.0
            rec["ip"][0] = mode
        elif k == "prop_step":
            rec["ip"][:3] = [o["it"], o["n_it"], o["dil"]]
        elif k == "absdiff":                                                                           
            rec["fp"][:2] = [float(o.get("k", 1.0)), float(o.get("hi", 0.0))]
        elif k == "vig_apply":
            rec["ip"][0] = o["mode"]
        elif k == "invert_t":                                                                                         
            rec["ip"][:2] = [o["t_mode"], o["accel"]]
        elif k == "warp_noise":
            rec["ip"][0] = o["idx"]
        elif k in ("prep_h", "q_prep"):                                                                    
            rec["ip"][0] = int(o.get("point", 0))
        elif k == "q_rule2" and o.get("bf"):                                                                      
            rec["fp"][:3] = [float(o["bf"][0]), float(o["bf"][1]), float(o["bf"][2]) if len(o["bf"]) > 2 else 0.0]
        elif k in ("q_cand", "final4"):                                                                        
            rec["ip"][0] = int(o.get("hw_bil", 0))
            if k == "final4":
                rec["ip"][1] = int(o.get("pick", 0))                                                           
        elif k == "pool":
            rec["ip"][:2] = [o["mode"], o["k"]]
        ops.append(rec)

                                                                                                                    
                                                               
    blob.extend([0] * (16 * max([r["kw_words"] for r in ops] + [0]) + 16))
    tens = [(g.tensors[n]["c"], g.tensors[n]["s"], g.tensors[n]["n"]) for n in names]
    mem = sum(c * n * (H // s) * (W // s) * 4 for c, s, n in tens)
    if store is not None:                                                                        
        tf = [store[n] for n in names]
                                                                                                                  
                                                                                                                       
                                                                        
        if os.environ.get("CALLOC_OLD") == "1":
            c_alloc = [(-(-c // 4) * 4 if f[0] >= 2 else (-(-c // 2) * 2 if f[0] == 1 else c)) for (c, _, _), f in zip(tens, tf)]
        else:
            c_alloc = [((-(-c // 16) * 16 if c >= 8 else -(-c // 4) * 4) if f[0] >= 2 else
                        (-(-c // 2) * 2 if f[0] == 1 else c)) for (c, _, _), f in zip(tens, tf)]
        tbytes = [ca * n * 4096 // (sv * sv) * ESZ[f[0]] for ca, (_, sv, n), f in zip(c_alloc, tens, tf)]
        mem_v2 = sum(b * (H * W // 4096) for b in tbytes)
                                                                                                                      
                                                                                                                      
                                                                                                               
    units = [c * n * 4096 // (sv * sv) for c, sv, n in tens] if store is None else [-(-b // 16) for b in tbytes]
    first, last = {}, {}
    for i, o in enumerate(g.ops):
        reads = [MG._parse(r)[0] for r in o["ins"]] + ([MG._parse(o["res"])[0]] if o.get("res") else [])
        for r in reads:
            last[r] = i
        on = MG._parse(o["out"])[0]
        first.setdefault(on, i); last[on] = max(last.get(on, i), i)
                                                                                                                       
                                                                                                                         
                                                                      
    for i, o in enumerate(g.ops[:-1]):
        nx = g.ops[i + 1]
        if o["kind"] == "conv" and nx["kind"] == "conv" and len(nx["ins"]) == 1 and MG._parse(nx["ins"][0])[0] == MG._parse(o["out"])[0]:
            for r in [MG._parse(r)[0] for r in o["ins"]] + ([MG._parse(o["res"])[0]] if o.get("res") else []):
                last[r] = max(last[r], i + 1)
    for nm in g.inputs:
        first[nm] = -1
        if keep_inputs:
            last[nm] = len(g.ops)
    for nm in g.outputs:
        last[nm] = len(g.ops)
    order = sorted(range(len(names)), key=lambda i: -units[i])
    placed, offs = [], [0] * len(names)
    for i in order:
        nm = names[i]
        a0, a1 = first.get(nm, 0), last.get(nm, 0)
        busy = sorted((o0, o0 + u) for j, o0, u in placed if not (last.get(names[j], 0) < a0 or first.get(names[j], 0) > a1))
        ALIGN_UNITS = 4                                                                        
        u_aligned = ((units[i] + ALIGN_UNITS - 1) // ALIGN_UNITS) * ALIGN_UNITS
        o0 = 0
        for b0, b1 in busy:
            if o0 + u_aligned <= b0:
                break
            o0 = ((max(o0, b1) + ALIGN_UNITS - 1) // ALIGN_UNITS) * ALIGN_UNITS
        offs[i] = o0
        placed.append((i, o0, u_aligned))
    arena_units = max(o0 + u for _, o0, u in placed)
    arena = arena_units * (H * W // 4096) * (4 if store is None else 16)
    up = prefix.upper()
    with open(os.path.join(out_dir, f"{prefix}_graph.h"), "w", newline="\n") as f:
        f.write(f"// generated by mlof2/export_mlof2_engine.py -- do not edit\n#pragma once\n#include <stdint.h>\n")
        f.write(f"// {g.summary()}\n// fp32 tensor memory at {W}x{H}: {mem / 2**20:.1f} MiB without aliasing, arena {arena / 2**20:.1f} MiB\n")
        if store is not None:
            f.write(f"// contract v2 storage: {mem_v2 / 2**20:.1f} MiB without aliasing; tensors 8-bit {sum(x[0] >= 2 for x in tf)}, "
                    f"fp16 {sum(x[0] == 1 for x in tf)}, fp32 {sum(x[0] == 0 for x in tf)}\n")
        f.write('#include "mlof2_graph_types.h"\n')
        f.write(f"// weights: {fmt}, 4 per uint32 word (byte k = input channel 4g+k), per output channel scale\n")
        f.write(f"static const int {up}_WEIGHT_FMT = {FMT_CODE[fmt]};   // tensor fmt codes: 2 int8 symmetric, 3 fp8 e4m3fn\n")
        f.write(f"static const int {up}_NUM_TENSORS = {len(tens)}, {up}_NUM_SEGS = {len(segs)}, {up}_NUM_OPS = {len(ops)};\n")
        f.write(f"static const uint32_t {up}_BLOB_WORDS = {len(blob)}, {up}_ARENA_UNITS = {arena_units};\n")
        for nm in dict.fromkeys(g.inputs + g.outputs):                                                   
            f.write(f"static const int {up}_T_{nm.upper()} = {tid[nm]};\n")
        if store is None:
            f.write(f"static const Mlof2Tensor {prefix}_tensors[] = {{\n" + ",\n".join(f"  {{{c}, {sv}, {n}, {offs[i]}u}}  /* {i} {names[i]} */" for i, (c, sv, n) in enumerate(tens)) + "\n};\n")
        else:
            f.write(f"static const Mlof2Tensor {prefix}_tensors[] = {{\n" + ",\n".join(
                f"  {{{c}, {sv}, {n}, {offs[i]}u, {tf[i][0]}, {c_alloc[i]}, {float(np.float32(tf[i][1]))!r}f}}  /* {i} {names[i]} */"
                for i, (c, sv, n) in enumerate(tens)) + "\n};\n")
        f.write(f"static const Mlof2Seg {prefix}_segs[] = {{\n" + ",\n".join(f"  {{{a}, {b}, {c}, {d}}}" for a, b, c, d in segs) + "\n};\n")
        def fl(x):
            return f"{x!r}f" if "e" in repr(x) or "." in repr(x) else f"{x}.0f"
        f.write(f"static const Mlof2Op {prefix}_ops[] = {{\n" + ",\n".join(
            f"  {{{r['kind']}, {r['out']}, {r['out_coff']}, {r['out_c']}, {r['seg0']}, {r['nseg']}, {{{', '.join(map(str, r['ip']))}}}, "
            f"{{{', '.join(fl(float(np.float32(x))) for x in r['fp'])}}}, {r['w_off']}u, {r['kw_words']}u, {r['scale_off']}u, {r['bias_off']}u}}"
            f"  /* {i} {KINDS[r['kind']]} -> {names[r['out']]} */" for i, r in enumerate(ops)) + "\n};\n")
        f.write(f"static const int {prefix}_io[] = {{{', '.join(str(tid[n]) for n in g.inputs + g.outputs)}}};\n")
        f.write(f"static const char* const {prefix}_io_names[] = {{{', '.join(chr(34) + n + chr(34) for n in g.inputs + g.outputs)}}};\n")
        f.write(f"static const Mlof2Graph {prefix}_graph = {{{prefix}_tensors, {len(tens)}, {prefix}_segs, {len(segs)}, "
                f"{prefix}_ops, {len(ops)}, {len(blob)}u, {arena_units}u, \"{prefix}.bin\", "
                f"{prefix}_io, {prefix}_io_names, {len(g.inputs)}, {len(g.outputs)}, {FMT_CODE[fmt]}}};\n")
    with open(os.path.join(out_dir, "mlof2_graph_types.h"), "w", newline="\n") as f:
        f.write("// generated by mlof2/export_mlof2_engine.py -- do not edit\n"                                               
                "#ifndef MLOF2_GRAPH_TYPES_H\n#define MLOF2_GRAPH_TYPES_H\n#include <stdint.h>\n"
                "enum Mlof2OpKind {" + ", ".join(f"MLOF2_K_{k.upper()} = {i}" for i, k in enumerate(KINDS)) + "};\n"
                + ("// element offset of a tensor = off_units * (H * W / 4096) (H, W multiples of 64)\n"
                   "struct Mlof2Tensor { int32_t c, s, n; uint32_t off_units; };\n" if store is None else
                   "#define MLOF2_CONTRACT 2\n"
                   "// byte offset of a tensor = off_units * 16 * (H * W / 4096); fmt 0 fp32 1 fp16 2 int8 3 fp8 e4m3fn;\n"
                   "// element (row, y, x, c) at + (((row * h + y) * w + x) * c_alloc + c) * esz; value = code * scale (8-bit)\n"
                   "struct Mlof2Tensor { int32_t c, s, n; uint32_t off_units; int32_t fmt, c_alloc; float scale; };\n") +
                "struct Mlof2Seg { int32_t tensor, c_off, c, swap; };\n"
                "struct Mlof2Op { int32_t kind, out, out_coff, out_c, seg0, nseg; int32_t ip[8]; float fp[4];\n"
                "  uint32_t w_off, kw_words, scale_off, bias_off; };\n"
                "struct Mlof2Graph { const Mlof2Tensor* tensors; int num_tensors; const Mlof2Seg* segs; int num_segs;\n"
                "  const Mlof2Op* ops; int num_ops; uint32_t blob_words, arena_units; const char* blob_name;\n"
                "  const int* io; const char* const* io_names; int num_inputs, num_outputs;  // io: inputs then outputs\n"
                "  int32_t weight_fmt; };  // 2 int8, 3 fp8 e4m3fn: the conv kernels must match it (host: refuse otherwise)\n"
                "#endif\n")
    with open(os.path.join(out_dir, f"{prefix}.bin"), "wb") as f:
        f.write(struct.pack(f"<{len(blob)}I", *blob))
    tj = [{"name": n, "c": c, "s": sv, "n": nn, "off_units": offs[i]} for i, (n, (c, sv, nn)) in enumerate(zip(names, tens))]
    if store is not None:
        for i, d in enumerate(tj):
            d.update({"fmt": tf[i][0], "c_alloc": c_alloc[i], "scale": float(np.float32(tf[i][1]))})
    json.dump({"fmt": fmt, "weight_fmt": FMT_CODE[fmt], "contract": 1 if store is None else 2, "tensors": tj, "arena_units": arena_units, "segs": segs,
               "ops": [{**r, "kind": KINDS[r["kind"]]} for r in ops]}, open(os.path.join(out_dir, f"{prefix}.json"), "w"))
    r = {"ops": len(ops), "segs": len(segs), "tensors": len(tens), "blob_MiB": len(blob) * 4 / 2**20, "mem_MiB": mem / 2**20, "arena_MiB": arena / 2**20}
    if store is not None:
        r["mem_v2_MiB"] = mem_v2 / 2**20
    return r


if __name__ == "__main__":
    ck, qs_path, out_dir = sys.argv[1:4]
    fmt = sys.argv[4] if len(sys.argv) > 4 else "int8"                                                    
    os.makedirs(out_dir, exist_ok=True)
    sd = torch.load(ck, map_location="cpu")
    m = build_mlof2(sd).eval(); m.load_state_dict(sd.get("model", sd))
    for _part in [p_ for p_ in os.environ.get("OF_ABLATE", "").split(",") if p_]:                                     
        setattr(m.pair, _part, False)
    qs = json.load(open(qs_path))
    V2 = os.environ.get("STORE") == "v2"                                                                
    sfx = "_" + fmt if V2 else ("" if fmt == "int8" else "_fp8")                                                   

    IO16 = os.environ.get("IO_FP16", "1") != "0"                                                                

    def ex(g_, prefix, io_fmt=None, keep_inputs=False):
        if not V2:
            return export(g_, qs, out_dir, prefix + sfx, fmt=fmt, keep_inputs=keep_inputs)
        st, q2 = v2_formats(g_, qs, fmt, io_fmt)
        return export(g_, q2, out_dir, prefix + sfx, fmt=fmt, store=st, keep_inputs=keep_inputs)
    if os.environ.get("SPLIT") == "1":                                                                              
        gp_ = MG.build_pair_graph(m)
        io_e = io_p = None
        if V2:                                                                                                  
            sp = MG.storage_plan(gp_, qs, "v2_" + fmt)                                                              
            qmax = 127.0 if fmt == "int8" else 448.0
            io_p = {f"q{lv}": sp[f"q{lv}"] if f"q{lv}" in sp else (fmt, float(qs.get(f"of.enc.q{lv}", qs.get(f"enc.q{lv}", 1.0))) / qmax) for lv in MG.ENC_LEVELS}
            io_e = {f"f{lv}": io_p[f"q{lv}"] for lv in MG.ENC_LEVELS}
            if IO16:                                                                                                     
                io_e["col"] = ("fp16", None)
            io_p["c4"] = io_e["c4"] = ("fp16", None)
            if "qm8" in sp:                                                                                       
                io_p["qm8"] = io_e["fm8"] = sp["qm8"]
        print("enc ", ex(MG.build_enc_graph(m), "mlof2_enc", io_e))
        print("pair", ex(gp_, "mlof2_pair", io_p))
    else:
        print("of ", ex(MG.build_of_graph(m), "mlof2_of"))
    if len(sys.argv) > 5:                                                                                           
        from nfru_head import load_head_c2
        from quant_ptq import fold_bn
        from mlof2_gen_lower import build_gen_graph
        head = load_head_c2(sys.argv[5], "cpu")
        fold_bn(head)
        from mlof2_gen_lower import GEN_IO_FP16
        st_ = int(os.environ.get("GEN_STRUCTURE", "4"))
        gg_ = build_gen_graph(head, structure=st_)
                                                                                                          
        io_g = {k: ("fp16", None) for k in GEN_IO_FP16 + ("out",) if k in gg_.tensors} if (V2 and IO16) else None
        print("gen", ex(gg_, "mlof2_gen", io_g))
        if st_ == 4:
            from mlof2_gen_lower import build_gen_prep_graph, build_gen_t_graph
            gp_gen = build_gen_prep_graph(head)
            gt_gen = build_gen_t_graph(head)
            io_gp = {k: ("fp16", None) for k in ("col_a", "col_b", "mvv", "cab", "ph", "qp") if k in gp_gen.tensors} if (V2 and IO16) else None
            io_gt = {k: ("fp16", None) for k in ("cab", "ph", "qp", "co", "pmask", "out") if k in gt_gen.tensors} if (V2 and IO16) else None
            print("gen_prep", ex(gp_gen, "mlof2_gen_prep", io_gp))
            print("gen_t   ", ex(gt_gen, "mlof2_gen_t", io_gt, keep_inputs=True))
