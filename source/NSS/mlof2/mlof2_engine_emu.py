"""Engine emulator: executes ONLY the exported files (mlof2_of.json + mlof2_of.bin) on one flat fp32 arena, NHWC, with
the aliased offsets -- the exact contract the VK / DX12 kernels implement (export_mlof2_engine.py docstring).
Checks the export (packing, scales, segments, slices, aliasing) against mlof2_graph.Executor before any shader exists,
and is the per-op reference the engine harness dumps are compared with.
Contract v2 files (json "contract": 2): a BYTE arena (0xFF = NaN in every float format, -1 in int8, so unwritten
reads show), every tensor in its own format / c_alloc / scale; reads decode, writes encode and zero the channel
padding of 8-bit tensors, conv reads check that padding is 0.
  python mlof2_engine_emu.py <dir with mlof2_of.json/.bin> <OF ckpt> <qstats_int8.json>"""
import sys, os, json
import numpy as np
import torch
from torch.nn import functional as F
import model_v2 as M


class Emu:
    def __init__(self, d, prefix, H, W, device="cuda"):
        self.j = json.load(open(os.path.join(d, f"{prefix}.json")))
        self.blob = np.fromfile(os.path.join(d, f"{prefix}.bin"), dtype=np.uint32)
        self.H, self.W, self.dev = H, W, device
        self.unit = H * W // 4096
        self.T = self.j["tensors"]
        self.v2 = self.j.get("contract", 1) == 2
        if self.v2:
            self.arena = torch.full((self.j["arena_units"] * 16 * self.unit,), 255, dtype=torch.uint8, device=device)
        else:
            self.arena = torch.full((self.j["arena_units"] * self.unit,), float("nan"), device=device)                 
                                                                                                                                
    DT = {0: torch.float32, 1: torch.float16, 2: torch.int8, 3: torch.float8_e4m3fn}
    ESZ = {0: 4, 1: 2, 2: 1, 3: 1}

    def raw(self, t):
        """v2: the typed storage of tensor t, (n, h, w, c_alloc)."""
        d = self.T[t]
        h, w = self.H // d["s"], self.W // d["s"]
        o = d["off_units"] * 16 * self.unit
        nb = d["n"] * h * w * d["c_alloc"] * self.ESZ[d["fmt"]]
        return self.arena[o:o + nb].view(self.DT[d["fmt"]]).view(d["n"], h, w, d["c_alloc"])

    def decode(self, t, r):
        d = self.T[t]
        return r.float() * d["scale"] if d["fmt"] >= 2 else r.float()

    def encode(self, t, x):
        d = self.T[t]
        if d["fmt"] == 2:
            return torch.clamp(torch.round(x / d["scale"]), -127, 127).to(torch.int8)
        if d["fmt"] == 3:
            return (x / d["scale"]).clamp(-448.0, 448.0).to(torch.float8_e4m3fn)
        return x.to(self.DT[d["fmt"]])

    def view(self, t):
        d = self.T[t]
        if self.v2:                                                                                       
            return self.decode(t, self.raw(t)[..., :d["c"]])
        h, w = self.H // d["s"], self.W // d["s"]
        o = d["off_units"] * self.unit
        return self.arena[o:o + d["n"] * h * w * d["c"]].view(d["n"], h, w, d["c"])

    def put(self, t, c0, y):
        """v2: encode y (n, h, w, c) into channels c0.. of tensor t; the writer of the last channels zeroes the padding."""
        d = self.T[t]
        r = self.raw(t)
        r[..., c0:c0 + y.shape[-1]] = self.encode(t, y)
        if c0 + y.shape[-1] == d["c"] and d["c_alloc"] > d["c"]:
            r[..., d["c"]:] = torch.zeros((), dtype=torch.float32, device=r.device).to(r.dtype)

    def read(self, si):
        t, c0, c, sw = self.j["segs"][si]
        if self.v2:
            d = self.T[t]
            if self.j["ops"][self._cur]["kind"] == "conv" and c0 + c == d["c"] and d["c_alloc"] > d["c"]:
                pad_ = self.raw(t)[..., d["c"]:].float()                                                        
                assert bool((pad_ == 0).all()), f"tensor {d['name']}: channel padding not zero"
        x = self.view(t)[..., c0:c0 + c].permute(0, 3, 1, 2)
        return torch.cat((x[1:2], x[0:1]), 0) if sw else x

    def write(self, op, y):
        if self.v2:
            self.put(op["out"], op["out_coff"], y.permute(0, 2, 3, 1)[..., :op["out_c"]])
            return
        v = self.view(op["out"])
        v[..., op["out_coff"]:op["out_coff"] + op["out_c"]] = y.permute(0, 2, 3, 1)

    def tensor_nchw(self, t):
        return self.view(t).permute(0, 3, 1, 2)

    def weights(self, op, cin4):
        oc = self.T[op["out"]]["c"] if op["out_c"] == 0 else op["out_c"]
        kh, kw = op["ip"][0], op["ip"][1]
        wd = self.blob[op["w_off"]:op["w_off"] + oc * op["kw_words"]]
        if self.j.get("fmt", "int8") == "fp8":
            q = torch.from_numpy(wd.view(np.uint8).copy()).view(torch.float8_e4m3fn).float().numpy().reshape(oc, kh, kw, cin4)
        else:
            q = wd.view(np.int8).reshape(oc, kh, kw, cin4).astype(np.float32)
        sc = self.blob[op["scale_off"]:op["scale_off"] + oc].view(np.float32)
        b = self.blob[op["bias_off"]:op["bias_off"] + oc].view(np.float32)
        return (torch.from_numpy(q).permute(0, 3, 1, 2).to(self.dev), torch.from_numpy(sc.copy()).to(self.dev),
                torch.from_numpy(b.copy()).to(self.dev))

    def run(self, inputs):
        for t, x in inputs.items():                                    
            if self.v2:
                self.put(t, 0, x.to(self.dev).float().permute(0, 2, 3, 1))
            else:
                self.view(t)[:] = x.to(self.dev).float().permute(0, 2, 3, 1)
        for i, op in enumerate(self.j["ops"]):
            self._cur = i
            self.write(op, self.op(op))

    fc = None                                                                                                             
    _stub = None

    def gen_op(self, o, ins):
        """The generation ops: the GenExecutor semantics, fed from the arena (one definition, no second copy)."""
        from mlof2_gen_lower import GenExecutor
        import mlof2_graph as MG
        emu = self
        if self._stub is None:
            class Stub(GenExecutor):
                def __init__(s_):
                    s_.H, s_.W, s_.dev, s_.fc, s_.vsums, s_.quant, s_.fp16 = emu.H, emu.W, emu.dev, emu.fc, None, None, False
                    s_.feed = {}
                def get(s_, ref):
                    return s_.feed[ref]
                def shape(s_, name):
                    return s_.feed["__shape"]
            self._stub = Stub()
        st = self._stub
        st.fc = self.fc
        d = self.T[o["out"]]
        st.feed = {f"in{i}": x for i, x in enumerate(ins)}
        st.feed["__shape"] = (d["n"], d["c"], self.H // d["s"], self.W // d["s"])
        st.feed["vig"] = self.tensor_nchw(o["out"]).clone() if o["kind"] == "vig_solve" else None
        ip, fp = o["ip"], o["fp"]
        p = {"kind": o["kind"], "ins": [f"in{i}" for i in range(len(ins))], "out": "__out"}
        p.update({"absdiff": {"k": fp[0], "hi": fp[1]}, "vig_apply": {"mode": ip[0]}, "invert_t": {"t_mode": ip[0], "accel": ip[1]},
                  "warp_noise": {"idx": ip[0]}, "pool": {"mode": ip[0], "k": ip[1]}, "prep_h": {"point": ip[0]},
                  "q_prep": {"point": ip[0]}, "q_cand": {"hw_bil": ip[0]}, "final4": {"hw_bil": ip[0], "pick": ip[1]},
                  "q_rule2": {"bf": (fp[0], fp[1], fp[2], fp[3] if fp[3] > 0 else float(os.environ.get("MLOF2_BF_REACH", "0.75")))} if d["c"] >= 2 else {}}.get(o["kind"], {}))
        MG._parse_orig = getattr(MG, "_parse_orig", MG._parse)
        try:
            MG._parse = lambda ref: ("__shape", False, None) if ref == "__out" else MG._parse_orig(ref)
            return st.op(0, p)
        finally:
            MG._parse = MG._parse_orig

    def op(self, o):
        k = o["kind"]
        out_n = self.T[o["out"]]["n"]
        ins = [self.read(o["seg0"] + i) for i in range(o["nseg"])]
        if out_n == 1:
            if k == "round_trip":
                return M.PairFlow.round_trip(ins[0], 1)[:1]
            ins = [x[:1] if x.shape[0] > 1 else x for x in ins]
        H, W = self.H, self.W
        if k == "absdiff" or k not in ("conv", "unshuffle", "resize_area", "resize_bil", "warp", "corr", "round_trip",
                                       "spread", "axpy", "scale", "zeros", "copy", "convex_up", "prop_step"):
            return self.gen_op(o, ins)
        if k == "conv":
            segs = []
            for x in ins:                                                                                      
                pad = (-x.shape[1]) % 4
                segs.append(F.pad(x, (0, 0, 0, 0, 0, pad)) if pad else x)
            x = torch.cat(segs, 1)
            wq, sc, b = self.weights(o, x.shape[1])
            kh, kw, st, pd, dl, act, rt, rc = o["ip"]
            if self.j.get("fmt", "int8") == "fp8":
                xq = (x * o["fp"][0]).clamp(-448.0, 448.0).to(torch.float8_e4m3fn).float()
            else:
                xq = torch.clamp(torch.round(x * o["fp"][0]), -127, 127)
            y = F.conv2d(xq, wq, None, st, pd, dl) * sc.view(1, -1, 1, 1) + b.view(1, -1, 1, 1)
            fa = {0: lambda z: z, 1: M.leaky, 2: F.relu}[act]
            if rt >= 0:
                c0 = rc if rc >= 0 else -1 - rc
                res = self.tensor_nchw(rt)[:out_n, c0:c0 + y.shape[1]]
                return fa(y + res) if rc < 0 else res + fa(y)
            return fa(y)
        if k == "unshuffle":
            return F.pixel_unshuffle(torch.cat(ins, 1), o["ip"][0])
        if k == "resize_area":
            s = o["ip"][0]
            return F.interpolate(ins[0], size=(H // s, W // s), mode="area")
        if k == "resize_bil":
            s = o["ip"][0]
            y = F.interpolate(ins[0], size=(H // s, W // s), mode="bilinear", align_corners=False)
            mul = torch.full((y.shape[1],), o["fp"][1], device=y.device); mul[0] = o["fp"][0]                                    
            return y * mul.view(1, -1, 1, 1)
        if k == "warp":
            return M.warp(ins[0], ins[1])
        if k == "corr":
            return M.correlation(ins[0], ins[1], o["ip"][0])
        if k == "absdiff":
            return (ins[0] - ins[1]).abs().mean(1, keepdim=True)
        if k == "round_trip":
            return M.PairFlow.round_trip(ins[0], 1)
        if k == "spread":
            return M.PairFlow.spread(ins[0])
        if k == "axpy":                                                                                                  
            if o["ip"][0] == 2:
                return torch.tanh(ins[0].clamp(-15.0, 15.0))
            if o["ip"][0] == 1:
                h, zq = ins
                c = h.shape[1]
                return h + torch.sigmoid(zq[:, :c]) * (torch.tanh(zq[:, c:2 * c].clamp(-15.0, 15.0)) - h)
            return ins[0] + o["fp"][0] * ins[1]
        if k == "scale":
            return o["fp"][0] * ins[0] + o["fp"][1]
        if k == "zeros":
            d = self.T[o["out"]]
            return torch.zeros(d["n"], o["out_c"], H // d["s"], W // d["s"], device=self.dev)
        if k == "copy":
            return ins[0]
        if k == "convex_up":
            return M.convex_upsample_rep(ins[0], ins[1], o["ip"][0])
        if k == "prop_step":
            from mlof2_graph import prop_step
            return prop_step(ins[0], ins[1], o["ip"][0], o["ip"][1], o["ip"][2])
        raise ValueError(k)


if __name__ == "__main__":
    d, ck, qp = sys.argv[1:4]
    import mlof2_graph as MG
    from test_mlof2_inputs import nfru_pair
    from model_v2 import build_mlof2
    col, dep = nfru_pair()
    H, W = col.shape[-2:]
    sd = torch.load(ck, map_location="cuda")
    m = build_mlof2(sd).cuda().eval(); m.load_state_dict(sd.get("model", sd))
    g = MG.build_of_graph(m)
    qs = json.load(open(qp))
    with torch.no_grad():
        ref = MG.Executor(g, H, W, quant=(qs, "int8")).run({"col": col, "dep": dep})
        em = Emu(d, "mlof2_of", H, W)
        em.run({0: col, 1: dep})
        nm = {t["name"]: i for i, t in enumerate(em.T)}
        for k in ("of_full", "conf_occ"):
            a, b = em.tensor_nchw(nm[k]), ref[k]
            print(f"emu vs executor(int8) {k}: max {float((a - b).abs().max()):.3e} mean {float((a - b).abs().mean()):.3e} "
                  f"nan {int(torch.isnan(a).sum())}")
