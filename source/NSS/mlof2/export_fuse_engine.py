"""Export FuseNet graph, weights, and metadata to engine files (Contract v2 W8A8).
Generates:
  mlof2_fuse_graph.h
  mlof2_fuse.bin
  mlof2_fuse.json
"""
import sys, os, json, struct
import torch
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mlof2_graph as MG
from oft_fuse import FuseNet

FMT_CODE = {"fp32": 0, "fp16": 1, "int8": 2, "fp8": 3}
ESZ = {0: 4, 1: 2, 2: 1, 3: 1}
ACTS = {"none": 0, "leaky": 1, "relu": 2}

OP_KIND_MAP = {
    "conv": 0, "unshuffle": 1, "resize_area": 2, "resize_bil": 3, "warp": 4, "corr": 5,
    "absdiff": 6, "round_trip": 7, "spread": 8, "axpy": 9, "scale": 10, "zeros": 11,
    "copy": 12, "convex_up": 13, "prop_step": 14,
}

class FuseLower:
    def __init__(self, model, g):
        self.m, self.g = model, g
        self.k = 0

    def new(self, base, c, s, n=1, q=""):
        self.k += 1
        name = self.g.t(f"{base}_{self.k}", c, s, n)
        if q:
            self.g.tensors[name]["q"] = q
        return name

    def conv(self, mod, ins, base, act="leaky", res=None, res_mode="post", q=""):
        g = self.g
        w, b = mod.weight.detach().float(), mod.bias.detach().float()
        cols, c0 = [], 0
        for ref, used in ins:
            part = w[:, c0:c0 + used[0]]
            pad = used[1] - used[0]
            if pad > 0:
                part = torch.cat([part, torch.zeros(w.shape[0], pad, *w.shape[2:])], dim=1)
            cols.append(part)
            c0 += used[0]
        assert c0 == w.shape[1], (base, c0, w.shape)
        w = torch.cat(cols, 1)
        s_in = g.level(ins[0][0])
        st = mod.stride[0]
        out = self.new(base, w.shape[0], s_in * st, q=q)
        return g.op("conv", [r for r, _ in ins], out, w=w, b=b, stride=st, pad=mod.padding[0], dil=mod.dilation[0],
                    act=act, res=res, res_mode=res_mode, q=q)

    def full(self, ref):
        return (ref, (self.g.chans(ref), self.g.chans(ref)))


def lower_fuse(net):
    g = MG.Graph()
    lower = FuseLower(net, g)

                                                                     
    cin = getattr(net, "CIN", 21)
    fuse_in = g.t("fuse_in", cin, 2, 1)
    g.tensors[fuse_in]["q"] = "fuse.d1.inp"
    g.inputs = [fuse_in]

                                                                  
    d1_out = lower.conv(net.d1, [lower.full(fuse_in)], "fuse_d1", act="leaky", q="fuse.d2.inp")

                                                                  
    cur = lower.conv(net.d2, [lower.full(d1_out)], "fuse_d2", act="leaky", q="fuse.body.0.a.inp")

                                    
    for ri, resc in enumerate(net.body):
        q_prefix = f"fuse.body.{ri}"
        ya = lower.conv(resc.a, [lower.full(cur)], f"b{ri}_a", act="leaky", q=f"{q_prefix}.b.inp")
        if ri < len(net.body) - 1:
            cur = lower.conv(resc.b, [lower.full(ya)], f"b{ri}_b", act="none", res=cur, res_mode="post",
                             q=f"fuse.body.{ri+1}.a.inp")
        else:
            cur = lower.conv(resc.b, [lower.full(ya)], f"b{ri}_b", act="leaky", res=cur, res_mode="pre",
                             q="fuse.out.inp")

                                                              
    out = lower.conv(net.out, [lower.full(cur)], "fuse_logits_s8", act="none", q="fuse.out.out")
    g.outputs = [out]
    return g


def get_fuse_formats(g, qstats):
    store = {}
    QMAX = 127.0
    for name, t in g.tensors.items():
        if name == "fuse_in":
            stat = float(qstats.get("fuse.d1.inp", 4.0))
            store[name] = (FMT_CODE["int8"], stat / QMAX, stat)
        elif "fuse_logits" in name:
            store[name] = (FMT_CODE["fp16"], 1.0, 1.0)
        else:
            q_key = t.get("q", "")
            stat = float(qstats.get(q_key, 4.0))
            store[name] = (FMT_CODE["int8"], stat / QMAX, stat)
    return store


def export_fuse(g, qstats, out_dir, prefix="mlof2_fuse"):
    os.makedirs(out_dir, exist_ok=True)
    store = get_fuse_formats(g, qstats)
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
        
        kind_idx = OP_KIND_MAP.get(k, 0)
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

        ops.append(rec)

                                                  
    blob_pad = (-len(blob)) % 64
    if blob_pad:
        blob.extend([0] * blob_pad)

                  
    h_lines = [
        f"// Generated by export_fuse_engine.py -- DO NOT EDIT",
        f"#pragma once",
        f"#include <stdint.h>",
        f"",
        f"#define {prefix.upper()}_NUM_TENSORS {len(names)}",
        f"#define {prefix.upper()}_NUM_SEGS {len(segs)}",
        f"#define {prefix.upper()}_NUM_OPS {len(ops)}",
        f"#define {prefix.upper()}_ARENA_UNITS 4096",
        f"static const uint32_t {prefix.upper()}_BLOB_WORDS = {len(blob)}u;",
        f"",
        f"static const Mlof2Tensor g_{prefix}_tensors[] = {{"
    ]

    arena_off = 0
    for i, n in enumerate(names):
        t = g.tensors[n]
        fmt, s_act, st = store[n]
        esz = ESZ[fmt]
        w_pad = int(math.ceil(t["c"] * esz / 16.0) * 16)
        h_lines.append(f"    {{{t['c']}, {t['s']}, {t['n']}, {arena_off}u, {fmt}, {w_pad}, {s_act:.8e}f}}, // [{i}] {n}")
        arena_off += 64

    h_lines.extend([
        f"}};",
        f"",
        f"static const Mlof2Seg g_{prefix}_segs[] = {{"
    ])
    for i, s in enumerate(segs):
        h_lines.append(f"    {{{s[0]}, {s[1]}, {s[2]}, {s[3]}}}, // [{i}]")

    h_lines.extend([
        f"}};",
        f"",
        f"static const Mlof2Op g_{prefix}_ops[] = {{"
    ])
    for i, o in enumerate(ops):
        ip_s = ", ".join(str(x) for x in o["ip"])
        fp_s = ", ".join(f"{x:.6e}f" for x in o["fp"])
        h_lines.append(f"    {{{o['kind']}, {o['out']}, {o['out_coff']}, {o['out_c']}, {o['seg0']}, {o['nseg']}, "
                       f"{{{ip_s}}}, {{{fp_s}}}, {o['w_off']}u, {o['kw_words']}u, {o['scale_off']}u, {o['bias_off']}u}}, // [{i}]")

    h_lines.extend([
        f"}};",
        f"",
        f"static const int g_{prefix}_io[] = {{{tid['fuse_in']}, {tid[names[-1]]}}};",
        f'static const char* const g_{prefix}_io_names[] = {{"fuse_in", "{names[-1]}"}};' ,
        f"",
        f"static const Mlof2Graph g_{prefix}_graph = {{",
        f"    g_{prefix}_tensors, {len(names)},",
        f"    g_{prefix}_segs, {len(segs)},",
        f"    g_{prefix}_ops, {len(ops)},",
        f"    {len(blob)}u, 4096u, \"{prefix}.bin\",",
        f"    g_{prefix}_io, g_{prefix}_io_names, 1, 1,",
        f"    2",
        f"}};"
    ])

    h_path = os.path.join(out_dir, f"{prefix}_graph.h")
    with open(h_path, "w") as f:
        f.write("\n".join(h_lines) + "\n")

    bin_path = os.path.join(out_dir, f"{prefix}.bin")
    np.array(blob, dtype=np.uint32).tofile(bin_path)

    json_path = os.path.join(out_dir, f"{prefix}.json")
    with open(json_path, "w") as f:
        json.dump({"tensors": names, "ops": ops, "blob_words": len(blob)}, f, indent=2)

    print(f"Exported FuseNet to {out_dir}:")
    print(f"  Header: {h_path}")
    print(f"  Binary: {bin_path} ({len(blob)*4/1024:.2f} KB)")
    print(f"  JSON:   {json_path}")


if __name__ == "__main__":
    import math
    ckpt = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/fuse3_best.pt"
    qstats_file = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_half_v2_int8/qstats_fuse_int8.json"
    out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_fuse_v2_int8"

    net = FuseNet(c=32, n=2, cin=21)
    net.load_state_dict(torch.load(ckpt, map_location="cpu"))
    net.eval()

    with open(qstats_file) as f:
        qstats = json.load(f)

    g = lower_fuse(net)
    print(f"FuseNet graph: {len(g.tensors)} tensors, {len(g.ops)} ops")
    export_fuse(g, qstats, out_dir, prefix="mlof2_fuse")

