"""Export OFTNet graph, weights, and metadata to engine files (Contract v2 W8A8).
Generates:
  mlof2_oft_graph.h
  mlof2_oft.bin
  mlof2_oft.json
"""
import sys, os, json, struct
import torch
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mlof2_graph as MG
from oft_block import OFTNet
from mlof2_oft_lower import lower_oft, OFT_KINDS

FMT_CODE = {"fp32": 0, "fp16": 1, "int8": 2, "fp8": 3}
ESZ = {0: 4, 1: 2, 2: 1, 3: 1}
ACTS = {"none": 0, "leaky": 1, "relu": 2}

OP_KIND_MAP = {
    "conv": 0, "unshuffle": 1, "resize_area": 2, "resize_bil": 3, "warp": 4, "corr": 5,
    "absdiff": 6, "round_trip": 7, "spread": 8, "axpy": 9, "scale": 10, "zeros": 11,
    "copy": 12, "convex_up": 13, "prop_step": 14,
    "oft_init": 64,
    "oft_prep": 65,
    "oft_out": 66,
    "oft_final": 67,
    "oft_lk": 68,
    "oft_luma": 69,
}
KIND_NAME_MAP = {v: k for k, v in OP_KIND_MAP.items()}

def get_oft_formats(g, qstats):
    """Assign Contract v2 storage formats and scales to all tensors in the OFT graph."""
    store = {}
    QMAX = 127.0
    for name, t in g.tensors.items():
                            
        if name in ("color_a", "color_b") or "color_out" in name:
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        elif "of_ab" in name or "of_ba" in name or name.startswith("f_t") or name.startswith("mask"):
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        elif name.startswith("a_s") or name.startswith("b_s"):
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        elif "fa_" in name or "fb_" in name or "m_" in name or "mask" in name:
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        elif "out80" in name or "luma" in name:
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        else:
                                                                          
            q_key = t.get("q", "")
            stat = float(qstats.get(q_key, 1.0))
            scale = stat / QMAX
            store[name] = (FMT_CODE["int8"], scale, stat)
    return store

def export_oft(g, qstats, out_dir, H=1088, W=1920, prefix="mlof2_oft"):
    os.makedirs(out_dir, exist_ok=True)
    store = get_oft_formats(g, qstats)
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
        out_n, _, out_sl = MG._parse(o["out"])
        oc0, oc1 = out_sl if out_sl is not None else (0, g.tensors[out_n]["c"])
        seg0 = len(segs)
        for r in o["ins"]:
            seg(r)
        
        kind_idx = OP_KIND_MAP.get(k, 64)
        rec = {
            "kind": kind_idx, "out": tid[out_n], "out_coff": oc0, "out_c": oc1 - oc0,
            "seg0": seg0, "nseg": len(o["ins"]), "ip": [0] * 8, "fp": [0.0] * 4,
            "w_off": 0, "scale_off": 0, "bias_off": 0, "kw_words": 0
        }

        if k == "conv":
            w = o["w"].float()
            ocn, _, kh, kw = w.shape
                                     
            ic = w.shape[1]
            pad_ic = (-ic) % 4
            if pad_ic:
                w = torch.cat([w, torch.zeros(ocn, pad_ic, kh, kw)], dim=1)
            ic4 = w.shape[1]

            a = w.abs().flatten(1).amax(1).clamp_min(1e-12)
            wq = torch.clamp(torch.round(w / (a / 127.0).view(-1, 1, 1, 1)), -127, 127).to(torch.int8)

                                                                                   
            in_t_name = MG._parse(o["ins"][0])[0]
            in_fmt, s_act, st = store[in_t_name]

            wq = wq.permute(0, 2, 3, 1).contiguous()
            u = wq.view(torch.uint8).numpy().reshape(ocn, -1, 4)
            packed = (u[..., 0].astype(np.uint32) | (u[..., 1].astype(np.uint32) << 8) |
                      (u[..., 2].astype(np.uint32) << 16) | (u[..., 3].astype(np.uint32) << 24)).reshape(-1)
            rec["kw_words"] = int(packed.size // ocn)
            rec["w_off"] = words(packed.tolist())

            sc = (a / 127.0 * s_act).numpy().astype(np.float32)
            rec["scale_off"] = words(np.frombuffer(sc.tobytes(), np.uint32).tolist())
            rec["bias_off"] = words(np.frombuffer(o["b"].float().numpy().astype(np.float32).tobytes(), np.uint32).tolist())

            res_t, res_c0 = -1, 0
            if o.get("res") is not None:
                rn, _, rsl = MG._parse(o["res"])
                res_t, res_c0 = tid[rn], (rsl[0] if rsl else 0)
            rec["ip"] = [kh, kw, o["stride"], o["pad"], o["dil"], ACTS[o["act"]], res_t,
                         res_c0 if o["res_mode"] == "post" else -1 - res_c0]
            rec["fp"] = [1.0 / s_act, 0.0, 0.0, 0.0]

        elif k in ("resize_area", "resize_bil"):
            rec["ip"][0] = o["s_out"]
            if k == "resize_bil" and "mul" in o:
                mul = o["mul"]
                rec["fp"] = [float(mul[0]), float(mul[1] if len(mul) > 1 else mul[0]), 0.0, 0.0]

        elif k == "oft_init":
            rec["ip"][0] = tid[MG._parse(o["out_b"])[0]]
            rec["ip"][1] = tid[MG._parse(o["out_m"])[0]]

        elif k == "oft_prep":
            rec["ip"][0] = int(o.get("scale_level", 1))
            st = float(qstats.get(o.get("q", ""), 1.0))
            rec["fp"][0] = 1.0 / (st / 127.0)

        elif k == "oft_out":
            rec["ip"][0] = tid[MG._parse(o["out_b"])[0]]
            rec["ip"][1] = tid[MG._parse(o["out_m"])[0]]
            rec["ip"][2] = int(o.get("scale_level", 1))

        elif k == "oft_final":
            pass

        elif k == "oft_lk":
            rec["ip"][0] = tid[MG._parse(o["out_b"])[0]]
            rec["ip"][1] = int(o.get("scale_level", 1))

        elif k == "oft_luma":
            pass

        ops.append(rec)

                           
    blob.extend([0] * (16 * max([r["kw_words"] for r in ops] + [0]) + 16))

                                            
    tens = [(g.tensors[n]["c"], g.tensors[n]["s"], g.tensors[n]["n"]) for n in names]
    tf = [store[n] for n in names]
                                                    
    c_alloc = [((-(-c // 16) * 16 if c >= 8 else -(-c // 4) * 4) if f[0] >= 2 else
                (-(-c // 2) * 2 if f[0] == 1 else c)) for (c, _, _), f in zip(tens, tf)]
    tbytes = [ca * n * 4096 // (sv * sv) * ESZ[f[0]] for ca, (_, sv, n), f in zip(c_alloc, tens, tf)]
    units = [-(-b // 16) for b in tbytes]

                            
    first, last = {}, {}
    for i, o in enumerate(g.ops):
        reads = [MG._parse(r)[0] for r in o["ins"]] + ([MG._parse(o["res"])[0]] if o.get("res") else [])
        for r in reads:
            last[r] = i
        on = MG._parse(o["out"])[0]
        first.setdefault(on, i)
        last[on] = max(last.get(on, i), i)
    for nm in g.inputs + g.outputs:
        first[nm] = -1
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
            o0 = max(o0, b1)
        offs[i] = o0
        placed.append((i, o0, u_aligned))

    arena_units = max([o0 + u for _, o0, u in placed] + [0])
    arena_bytes = arena_units * 16 * (H * W // 4096)
    print(f"Arena units: {arena_units} ({arena_bytes / 1e6:.2f} MB at {H}x{W})")

                            
    h_path = os.path.join(out_dir, f"{prefix}_graph.h")
    p_up = prefix.upper()
    with open(h_path, "w") as f:
        f.write("// Generated by export_oft_engine.py -- DO NOT EDIT\n#pragma once\n#include <stdint.h>\n\n")
        f.write(f"#define {p_up}_NUM_TENSORS {len(names)}\n")
        f.write(f"#define {p_up}_NUM_SEGS {len(segs)}\n")
        f.write(f"#define {p_up}_NUM_OPS {len(ops)}\n")
        f.write(f"#define {p_up}_ARENA_UNITS {arena_units}\n")
        f.write(f"static const uint32_t {p_up}_BLOB_WORDS = {len(blob)}u;\n\n")

                 
        f.write(f"static const Mlof2Tensor g_{prefix}_tensors[] = {{\n")
        for i, (n, (c, s, nb), (fmt, sc, _), ca, off) in enumerate(zip(names, tens, tf, c_alloc, offs)):
            f.write(f"    {{{c}, {s}, {nb}, {off}u, {fmt}, {ca}, {sc:.8e}f}}, // [{i}] {n}\n")
        f.write("};\n\n")

                  
        f.write(f"static const Mlof2Seg g_{prefix}_segs[] = {{\n")
        for i, (tid_, c0, c, sw) in enumerate(segs):
            f.write(f"    {{{tid_}, {c0}, {c}, {sw}}}, // [{i}]\n")
        f.write("};\n\n")

             
        f.write(f"static const Mlof2Op g_{prefix}_ops[] = {{\n")
        for i, o in enumerate(ops):
            ip_str = ", ".join(map(str, o["ip"]))
            fp_str = ", ".join(f"{x:.6e}f" for x in o["fp"])
            f.write(f"    {{{o['kind']}, {o['out']}, {o['out_coff']}, {o['out_c']}, {o['seg0']}, {o['nseg']}, "
                    f"{{{ip_str}}}, {{{fp_str}}}, {o['w_off']}u, {o['kw_words']}u, {o['scale_off']}u, {o['bias_off']}u}}, // [{i}]\n")
        f.write("};\n\n")

            
        io_tids = [tid[n] for n in g.inputs + g.outputs]
        io_names = [f'"{n}"' for n in g.inputs + g.outputs]
        f.write(f"static const int g_{prefix}_io[] = {{{', '.join(map(str, io_tids))}}};\n")
        f.write(f"static const char* const g_{prefix}_io_names[] = {{{', '.join(io_names)}}};\n\n")

               
        f.write(f"static const Mlof2Graph g_{prefix}_graph = {{\n")
        f.write(f"    g_{prefix}_tensors, {len(names)},\n")
        f.write(f"    g_{prefix}_segs, {len(segs)},\n")
        f.write(f"    g_{prefix}_ops, {len(ops)},\n")
        f.write(f"    {len(blob)}u, {arena_units}u, \"{prefix}.bin\",\n")
        f.write(f"    g_{prefix}_io, g_{prefix}_io_names, {len(g.inputs)}, {len(g.outputs)},\n")
        f.write(f"    2\n")
        f.write("};\n")
    print(f"Saved {h_path}")

                        
    bin_path = os.path.join(out_dir, f"{prefix}.bin")
    blob_bytes = struct.pack(f"<{len(blob)}I", *blob)
    with open(bin_path, "wb") as f:
        f.write(blob_bytes)
    print(f"Saved {bin_path} ({len(blob_bytes) / 1e6:.2f} MB)")

                         
    json_path = os.path.join(out_dir, f"{prefix}.json")
    meta = {
        "contract": 2,
        "num_tensors": len(names),
        "num_segs": len(segs),
        "num_ops": len(ops),
        "arena_units": arena_units,
        "arena_bytes_1080p": arena_bytes,
        "tensors": [{"name": n, "c": c, "c_alloc": ca, "s": s, "n": nb, "fmt": fmt, "scale": sc, "off_units": off}
                    for n, (c, s, nb), (fmt, sc, _), ca, off in zip(names, tens, tf, c_alloc, offs)],
        "segs": segs,
        "ops": [{**r, "name": KIND_NAME_MAP.get(r["kind"], str(r["kind"]))} for r in ops]
    }
    with open(json_path, "w") as f:
        json.dump(meta, f, indent=2)
    print(f"Saved {json_path}")

from mlof2_oft_lower import lower_oft_half
import shutil

def main():
    device = "cpu"
    print("Loading OFTNet checkpoint...")
    net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3))
    ckpt = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    net.load_state_dict(torch.load(ckpt, map_location=device))

    qstats_path = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/qstats_oft_int8.json"
    with open(qstats_path) as f:
        qstats = json.load(f)

                                          
    print("\n=== Exporting Full-Res 3-Block + LK ===")
    g_full = lower_oft(net)
    out_dir_full = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8"
    export_oft(g_full, qstats, out_dir_full, prefix="mlof2_oft")

                                                              
    print("\n=== Exporting Half-Res 4-Block + LK (10.2 GMAC) ===")
    g_half = lower_oft_half(net, num_blocks=4)
    out_dir_half = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_half_v2_int8"
    os.makedirs(out_dir_half, exist_ok=True)
    shutil.copyfile(qstats_path, os.path.join(out_dir_half, "qstats_oft_int8.json"))
    export_oft(g_half, qstats, out_dir_half, prefix="mlof2_oft_half")

if __name__ == "__main__":
    main()
