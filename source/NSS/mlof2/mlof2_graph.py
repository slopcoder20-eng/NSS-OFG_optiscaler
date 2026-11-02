"""MLOF2 as an engine op table (docs/NFRU_MLOF2_ENGINE_PLAN_20261023.md, E1).

The per-pair OF network (FrameEncoder + PairFlow.of_forward, the variant of the shipped checkpoint: convex_up, deep16,
prop4, up_full; no global match, no PM select) lowered to a flat list of ops that the VK / DX12 engines execute one
dispatch each, plus a torch executor of that list (the reference the engines are diffed against, op by op).
The MV gate (gate8 / gate4) is not lowered: the frame-generation path only uses the OF outputs (of_ba_full, conf, occ).

Tensors: (n, c, H / s, W / s) of the padded frame (H, W multiples of 64), fp16 in the engine. n = 2 for the pair
(row 0 = query B, row 1 = query A, as PairFlow), n = 2 for the encoder too (both frames, row 0 = B).
A tensor reference is "name" or "name[c0:c1]" (channel slice) or "name~" (the batch rows swapped: the reference
frame of each row, r = cat(fa, fb)).

Ops (all semantics = the torch functions in model_v2):
  conv        ins (channel-concatenated), w (oc, sum ic, kh, kw), b, stride, pad, dil, act none|leaky|relu,
              res (tensor) + res_mode post (y = res + act(conv)) | pre (y = act(conv + res)), q = calib key
  unshuffle   pixel_unshuffle by f            resize_area   to level s_out
  resize_bil  bilinear (align_corners False) to level s_out, output channel c scaled by mul[c]
  warp        bilinear sample of src at x + flow (flow in src px), zeros outside
  corr        cosine cost volume radius r (channels (2r+1)^2, dy-major)
  absdiff     mean_c |a - b|                  round_trip   |f + f_other(x + f)|_1 / 4 (rows swapped)
  spread      sqrt(sum_c local 3x3 variance + 1e-4) / 4
  axpy        out = a + k * b                 scale        out = k * a          zeros   out = 0
  convex_up   convex_upsample_rep(flow, mask, f)            prop_step  one iteration of Propagate.forward
  copy        out = a
  affine      out = k * a + c                tanh        out = tanh(a)
  gru         ins h, zq (2 hd ch: z logits | q pre-activations): out = h + sigmoid(z) * (tanh(q) - h)
              (2026-10-31: RecurRefine's ConvGRU update, its gz / gq convs merged into one conv)
Writing into a slice of an existing tensor is allowed ("name[c0:c1]" as out)."""
import json
import re
import torch
import os
from torch.nn import functional as F
import model_v2 as M


def _parse(ref):
    m = re.fullmatch(r"([A-Za-z0-9_]+)(~)?(?:\[(\d+):(\d+)\])?", ref)
    assert m, ref
    name, sw, c0, c1 = m.groups()
    return name, sw is not None, (None if c0 is None else (int(c0), int(c1)))


class Graph:
    def __init__(self):
        self.tensors = {}                                                                   
        self.ops = []
        self.inputs, self.outputs = [], []

    def t(self, name, c, s, n=2):
        assert name not in self.tensors, name
        self.tensors[name] = {"c": c, "s": s, "n": n}
        return name

    def chans(self, ref):
        name, _, sl = _parse(ref)
        return self.tensors[name]["c"] if sl is None else sl[1] - sl[0]

    def level(self, ref):
        return self.tensors[_parse(ref)[0]]["s"]

    def op(self, kind, ins, out, **p):
        self.ops.append({"kind": kind, "ins": list(ins), "out": out, **p})
        return out

    def summary(self):
        kinds = {}
        for o in self.ops:
            kinds[o["kind"]] = kinds.get(o["kind"], 0) + 1
        return f"{len(self.ops)} ops {kinds}, {len(self.tensors)} tensors"


                                                                             
class _OutSlice:
    """output channels a:b of a conv module (weight, bias, geometry): one part of a split head conv"""
    def __init__(self, m, a, b):
        self.weight, self.bias = m.weight[a:b], m.bias[a:b]
        self.stride, self.padding, self.dilation = m.stride, m.padding, m.dilation


class _CatOut:
    """the output channels of several conv modules with the same input and geometry, as one conv"""
    def __init__(self, *ms):
        self.weight = torch.cat([m.weight for m in ms], 0)
        self.bias = torch.cat([m.bias for m in ms], 0)
        self.stride, self.padding, self.dilation = ms[0].stride, ms[0].padding, ms[0].dilation


class _Lower:
    def __init__(self, model, g):
        self.m, self.g = model, g
        self.k = 0
        self.n = 2                                                                                  

    def new(self, base, c, s, n=None):
        self.k += 1
        return self.g.t(f"{base}_{self.k}", c, s, self.n if n is None else n)

    def conv(self, mod, ins, base, act="leaky", res=None, res_mode="post", q="", w_scale=None):
        """ins: tensor refs; zero channels (pad_ch) are simply not listed: the weight columns for them are dropped."""
        g = self.g
        w, b = mod.weight.detach().float(), mod.bias.detach().float()
        cols, c0 = [], 0
        for ref, used in ins:                                                                                            
            slot = used[1]
            cols.append(w[:, c0:c0 + used[0]])
            c0 += slot
        assert c0 == w.shape[1], (base, c0, w.shape)
        w = torch.cat(cols, 1)
        if w_scale is not None:                                                                 
            w, b = w * w_scale.view(-1, 1, 1, 1), b * w_scale
        s_in = g.level(ins[0][0])
        st = mod.stride[0]
        out = self.new(base, w.shape[0], s_in * st)
        return g.op("conv", [r for r, _ in ins], out, w=w, b=b, stride=st, pad=mod.padding[0], dil=mod.dilation[0],
                    act=act, res=res, res_mode=res_mode, q=q)

    def full(self, ref):
        return (ref, (self.g.chans(ref), self.g.chans(ref)))

    def padded(self, ref, slot):
        return (ref, (self.g.chans(ref), slot))

                                                              
    def encoder(self, col, dep):
        g, e = self.g, self.m.enc
        x = g.op("unshuffle", [col, dep], self.new("enc_in", 64, 4), f=4)                                          
        f4 = self.conv(e.e4, [self.full(x)], "f4", q="of.enc.e4")
        if getattr(e, "fpn", False):
            return self.encoder_fpn(col, dep, f4)
        if getattr(e, "deep_fine", False):                                                                 
            f4 = self.conv(e.r4b, [self.full(self.conv(e.r4a, [self.full(f4)], "r4a", q="of.enc.r4a"))], "f4r",
                           act="none", res=f4, res_mode="post", q="of.enc.r4b")
        f8 = self.conv(e.e8b, [self.full(self.conv(e.e8a, [self.full(f4)], "e8a", q="of.enc.e8a"))], "f8", q="of.enc.e8b")
        if getattr(e, "deep_fine", False):
            f8 = self.conv(e.r8b, [self.full(self.conv(e.r8a, [self.full(f8)], "r8a", q="of.enc.r8a"))], "f8r",
                           act="none", res=f8, res_mode="post", q="of.enc.r8b")
        f16 = self.conv(e.e16b, [self.full(self.conv(e.e16a, [self.full(f8)], "e16a", q="of.enc.e16a"))], "f16", q="of.enc.e16b")
        f32 = self.conv(e.e32b, [self.full(self.conv(e.e32a, [self.full(f16)], "e32a", q="of.enc.e32a"))], "f32", q="of.enc.e32b")
        f64 = self.conv(e.e64b, [self.full(self.conv(e.e64a, [self.full(f32)], "e64a", q="of.enc.e64a"))], "f64", q="of.enc.e64b")
        return {4: f4, 8: f8, 16: f16, 32: f32, 64: f64}

    def encoder_fpn(self, col, dep, f4):
        """FrameEncoder fpn (+ deep_fine): plain f8 -> f16 .. f64; f8 += t8(up2 f16) -> r8 block; f4 += t4(up2 f8) -> r4
        block; + the MatchEncoder map m8 when the encoder has one."""
        g, e = self.g, self.m.enc
        f8 = self.conv(e.e8b, [self.full(self.conv(e.e8a, [self.full(f4)], "e8a", q="of.enc.e8a"))], "f8", q="of.enc.e8b")
        f16 = self.conv(e.e16b, [self.full(self.conv(e.e16a, [self.full(f8)], "e16a", q="of.enc.e16a"))], "f16", q="of.enc.e16b")
        f32 = self.conv(e.e32b, [self.full(self.conv(e.e32a, [self.full(f16)], "e32a", q="of.enc.e32a"))], "f32", q="of.enc.e32b")
        f64 = self.conv(e.e64b, [self.full(self.conv(e.e64a, [self.full(f32)], "e64a", q="of.enc.e64a"))], "f64", q="of.enc.e64b")
        u16 = g.op("resize_bil", [f16], self.new("u16", g.chans(f16), 8), s_out=8, mul=[1.0] * g.chans(f16))
        f8 = self.conv(e.t8, [self.full(u16)], "f8t", act="none", res=f8, res_mode="post", q="of.enc.t8")
        if e.deep_fine:
            f8 = self.conv(e.r8b, [self.full(self.conv(e.r8a, [self.full(f8)], "r8a", q="of.enc.r8a"))], "f8r",
                           act="none", res=f8, res_mode="post", q="of.enc.r8b")
        u8 = g.op("resize_bil", [f8], self.new("u8", g.chans(f8), 4), s_out=4, mul=[1.0] * g.chans(f8))
        f4 = self.conv(e.t4, [self.full(u8)], "f4t", act="none", res=f4, res_mode="post", q="of.enc.t4")
        if e.deep_fine:
            f4 = self.conv(e.r4b, [self.full(self.conv(e.r4a, [self.full(f4)], "r4a", q="of.enc.r4a"))], "f4r",
                           act="none", res=f4, res_mode="post", q="of.enc.r4b")
        out = {4: f4, 8: f8, 16: f16, 32: f32, 64: f64}
        if getattr(e, "menc", None) is not None:
            out["m8"] = self.match_encoder(col, dep, f16)
        return out

    def match_encoder(self, col, dep, f16):
        """MatchEncoder: x = cat(2 col - 1, depth) -> s1, s2, s3 (3x3 s2, leaky) [+ up(t16(f16))] -> res block -> out"""
        g, me = self.g, self.m.enc.menc
        cin = self.new("m_in", 4, 1)
        g.op("affine", [col], f"{cin}[0:3]", k=2.0, c=-1.0)
        g.op("copy", [dep], f"{cin}[3:4]")
        x = self.conv(me.s1, [self.full(cin)], "ms1", q="of.enc.menc.s1")
        x = self.conv(me.s2, [self.full(x)], "ms2", q="of.enc.menc.s2")
        x = self.conv(me.s3, [self.full(x)], "ms3", q="of.enc.menc.s3")
        if me.t16 is not None:
            t = self.conv(me.t16, [self.full(f16)], "mt16", act="none", q="of.enc.menc.t16")
            t = g.op("resize_bil", [t], self.new("mt16u", g.chans(t), 8), s_out=8, mul=[1.0] * g.chans(t))
            x = g.op("axpy", [x, t], self.new("ms3c", g.chans(x), 8), k=1.0)
        a = self.conv(me.ra, [self.full(x)], "mra", q="of.enc.menc.ra")
        x = self.conv(me.rb, [self.full(a)], "mrb", act="none", res=x, res_mode="post", q="of.enc.menc.rb")
        return self.conv(me.out, [self.full(x)], "m8", act="none", q="of.enc.menc.out")

    def recur(self, of, q8, ctx, m8):
        """RecurRefine (pair.rec) on the matching features m8 (rows B, A; m8~ = the reference frame of each row)."""
        g, rc = self.g, self.m.pair.rec
        hd = rc.hd
        h = g.op("tanh", [self.conv(_OutSlice(rc.init, 0, hd), [self.full(q8), self.full(ctx)], "rh0", act="none",
                                    q="of.pair.rec.init")], self.new("rh", hd, 8))
        inp = self.conv(_OutSlice(rc.init, hd, 2 * hd), [self.full(q8), self.full(ctx)], "rinp", q="of.pair.rec.init")
        m16 = g.op("resize_area", [m8], self.new("m16", g.chans(m8), 16), s_out=16)
        n8, n16 = (2 * rc.r8 + 1) ** 2, (2 * rc.r16 + 1) ** 2
        gzq = _CatOut(rc.gz, rc.gq)
        for it in range(rc.iters):
            ref8 = g.op("warp", [m8 + "~", of], self.new(f"rr8_{it}", g.chans(m8), 8))
            c8 = g.op("corr", [m8, ref8], self.new(f"rc8_{it}", n8, 8), radius=rc.r8)
            of16 = g.op("resize_bil", [of], self.new(f"rof16_{it}", 2, 16), s_out=16, mul=[0.5, 0.5])
            ref16 = g.op("warp", [m16 + "~", of16], self.new(f"rr16_{it}", g.chans(m16), 16))
            c16 = g.op("corr", [m16, ref16], self.new(f"rc16_{it}", n16, 16), radius=rc.r16)
            c16u = g.op("resize_bil", [c16], self.new(f"rc16u_{it}", n16, 8), s_out=8, mul=[1.0] * n16)
            mo = self.conv(rc.mc, [self.full(c8), self.full(c16u)], f"rmc_{it}", q=f"of.pair.rec.mc@{it}")
            of8 = g.op("scale", [of], self.new(f"rof8_{it}", 2, 8), k=1 / 8.0)
            mf = self.conv(rc.mf, [self.full(of8)], f"rmf_{it}", q=f"of.pair.rec.mf@{it}")
            mm = self.conv(rc.mm, [self.full(mo), self.full(mf)], f"rmm_{it}", q=f"of.pair.rec.mm@{it}")
            ofs = g.op("scale", [of], self.new(f"rofs_{it}", 2, 8), k=1 / 16.0)
            zq = self.conv(gzq, [self.full(h), self.full(mm), self.full(ofs), self.full(inp)], f"rzq_{it}", act="none",
                           q=f"of.pair.rec.gz@{it}")                                                       
            h = g.op("gru", [h, zq], self.new(f"rh_{it}", hd, 8))
            d = self.conv(rc.d1, [self.full(h)], f"rd1_{it}", q=f"of.pair.rec.d1@{it}")
            d = self.conv(rc.d2, [self.full(d)], f"rd2_{it}", act="none", q=f"of.pair.rec.d2@{it}")
            of = g.op("axpy", [of, d], self.new(f"rof_{it}", 2, 8), k=1.0)
        return of

    def explain(self, q, r, qc, rc, f, ref=None, dst=None):
        """4 channels: feature residual, colour residual, round trip, spread (PairFlow.explain). dst: written into
        channels 0:4 of that tensor (the cue the conv reads: no separate explain tensor and copy)."""
        g = self.g
        s = g.level(q)
        out = dst or self.new("explain", 4, s)
        ref = ref or g.op("warp", [r, f], self.new("ref", g.chans(r), s))
        g.op("absdiff", [q, ref], f"{out}[0:1]")
        g.op("absdiff", [qc, g.op("warp", [rc, f], self.new("refc", 3, s))], f"{out}[1:2]")
        g.op("round_trip", [f], f"{out}[2:3]")
        g.op("spread", [f], f"{out}[3:4]")
        return out

    def update(self, upd, parts, lv, ctxc, is_last=False):
        """-> (flow 0:2 | conf_occ 2:4, ctx, upmask or None): the head conv split by its output channels (same weights per
        channel, so the same values), one tensor per consumer: readers of a few channels of the wide head output pulled
        every cache line of it (2026-10-25: pair op85 copy of 2 of 37 channels 56 us); parts nobody reads (the last
        level's ctx, the channel between ctx and the mask) are no conv any more."""
        g = self.g
        q = f"of.pair.upd.{lv}"
        x = self.conv(upd.inp, parts, f"u{lv}_in", q=f"{q}.inp")
        for j, c in enumerate(upd.body):
            x = self.conv(c, [self.full(x)], f"u{lv}_b{j}", res=x, res_mode="post", q=f"{q}.body.{j}")
        n = upd.head.weight.shape[0]
        fc = self.conv(_OutSlice(upd.head, 0, 4), [self.full(x)], f"u{lv}_hf", act="none", q=f"{q}.head")
        cx = None if is_last else self.conv(_OutSlice(upd.head, 4, 4 + ctxc), [self.full(x)], f"u{lv}_hc", act="none", q=f"{q}.head")
        mk = (self.conv(_OutSlice(upd.head, 5 + ctxc, n), [self.full(x)], f"u{lv}_hm", act="none", q=f"{q}.head")
              if n > 5 + ctxc else None)
        return fc, cx, mk

    def pair(self, feats, c4, of4=None):
        """of4: a graph output name -> the 1/4-res flow goes there (px at 1/4) instead of the full-res of_full"""
        g, p = self.g, self.m.pair
        ctxc = p.ctx
        of = conf_occ = ctx = upmask = None
        qcs = {4: c4}
        prev = c4
        for lv in [8, 16, 32, 64]:
            qcs[lv] = prev = g.op("resize_area", [prev], self.new(f"qc{lv}", 3, lv), s_out=lv)
        no_l4 = os.environ.get("MLOF2_OFT_NO_L4") == "1"
        levels = [lv for lv in p.LEVELS if not (no_l4 and lv == 4)]
        for i, lv in enumerate(levels):
            if lv == 4:
                self.n = 1
            q = feats[lv]
            r = q + "~"
            ch = g.chans(q)
            qc = qcs[lv]
            rc = qc + "~"
            cue = self.new(f"cue{lv}", 8, lv)                                                                          
            if of is None:
                of = g.op("zeros", [], self.new(f"of{lv}", 2, lv))
                g.op("zeros", [], f"{cue}[6:8]")
            else:
                of = g.op("convex_up", [of, upmask], self.new(f"of{lv}", 2, lv, n=2 if lv == 4 else self.n), f=2)
                ctx = g.op("resize_bil", [ctx], self.new(f"ctx{lv}", ctxc, lv), s_out=lv, mul=[1.0] * ctxc)
                g.op("resize_bil", [conf_occ], f"{cue}[6:8]", s_out=lv, mul=[1.0, 1.0])
            ref = g.op("warp", [r, of], self.new(f"ref{lv}", ch, lv))
            rad = p.radius[lv]
            nc = (2 * rad + 1) ** 2
            corr = g.op("corr", [q, ref], self.new(f"corr{lv}", nc, lv), radius=rad)
            self.explain(q, r, qc, rc, of, ref=ref, dst=cue)
            g.op("scale", [of], f"{cue}[4:6]", k=1 / 16.0)
            parts = [self.full(q), self.full(ref), self.padded(corr, M.pad_c(nc)), self.padded(cue, p.of_cue)]
            if i:
                parts.append(self.full(ctx))
            fc, ctx, upmask = self.update(p.upd[str(lv)], parts, lv, ctxc, is_last=(lv == 4 and not p.prop4 and not p.up_full))
            of = g.op("axpy", [of, f"{fc}[0:2]"], self.new(f"of{lv}u", 2, lv), k=4.0 if i == 0 else 1.0)
            conf_occ = f"{fc}[2:4]"
            if lv == 8 and getattr(p, "rec", None) is not None:
                assert not p.rec.teacher_feats and "m8" in feats, "recurrent block lowering needs the MatchEncoder"
                of = self.recur(of, q, ctx, feats["m8"])
            if p.deep16 and lv == 16:
                ref2 = g.op("warp", [r, of], self.new("dref", ch, lv))
                rcw = g.op("warp", [rc, of], self.new("drc", 3, lv))
                of16 = g.op("scale", [of], self.new("dof", 2, lv), k=1 / 16.0)
                d = self.deep(p.deep, [self.full(q), self.full(ref2), self.full(qc), self.full(rcw), self.full(of16),
                                       self.full(conf_occ), self.full(ctx)])
                of = g.op("axpy", [of, f"{d}[0:2]"], self.new("of16d", 2, lv), k=1.0)
                conf_occ = g.op("axpy", [conf_occ, f"{d}[2:4]"], self.new("co16d", 2, lv), k=1.0)
        if no_l4:
            of_full = g.op("copy", [of], g.t("of8", 2, 8, n=self.n))
            g.op("copy", [conf_occ], g.t("conf_occ", 2, 8, n=self.n))
            return of_full

                                                                                                         
        q4 = feats[4]
        if p.prop4 or p.up_full:
            unsh = g.op("unshuffle", [col], self.new("col_unsh", 48, 4), f=4)
        if p.prop4:
            qc = g.op("resize_area", [col], self.new("qc4p", 3, 4), s_out=4)
            of16 = g.op("scale", [of], self.new("pof", 2, 4), k=1 / 16.0)
            ex = self.explain(q4, q4 + "~", qc, qc + "~", of)
            pr = p.prop
            x = self.conv(pr.a, [self.full(q4), self.full(unsh), self.full(of16), self.full(conf_occ), self.full(ctx),
                                 self.full(ex)], "pa", q="of.pair.prop.a")
            x = self.conv(pr.b, [self.full(x)], "pb", q="of.pair.prop.b")
            x = self.conv(pr.c, [self.full(x)], "pc", q="of.pair.prop.c")
            o = self.conv(pr.head, [self.full(x)], "phead", act="none", q="of.pair.prop.head")
            kk = len(pr.DIL)
            for j, d in enumerate(pr.DIL):                                                                    
                of = g.op("prop_step", [of, o], self.new(f"of4p{j}", 2, 4), it=j, n_it=kk, dil=d)
        if p.up_full:
            of16 = g.op("scale", [of], self.new("uof", 2, 4), k=1 / 16.0)
            u = p.upf
            x = self.conv(u.a, [self.full(q4), self.full(unsh), self.full(of16), self.full(conf_occ), self.full(ctx)], "ua",
                          q="of.pair.upf.a")
            x = self.conv(u.b, [self.full(x)], "ub", q="of.pair.upf.b")
            mk = self.conv(u.c, [self.full(x)], "uc", act="none", q="of.pair.upf.c")
            of_full = g.op("convex_up", [of, mk], g.t("of_full", 2, 1), f=4)
        elif of4:                                                                                                
            of_full = g.op("copy", [of], g.t(of4, 2, 4, n=self.n))
        else:                                                                             
            of_full = g.op("resize_bil", [of], g.t("of_full", 2, 1, n=self.n), s_out=1, mul=[4.0, 4.0])
        g.op("copy", [conf_occ], g.t("conf_occ", 2, 4, n=self.n))
        return of_full

    def deep(self, dp, parts):
        x = self.conv(dp.inp, parts, "d_in", q="of.pair.deep.inp")
        for j, rc in enumerate(dp.body):
            x = self.conv(rc.conv, [self.full(x)], f"d_b{j}", res=x, res_mode="pre", q=f"of.pair.deep.body.{j}.conv",
                          w_scale=rc.beta.detach().float().flatten())
        return self.conv(dp.head, [self.full(x)], "d_head", act="none", q="of.pair.deep.head")


def _variant_ok(p):
    assert not p.global_match and not p.pm_sel and p.convex_up, "variant"


def build_of_graph(model):
    """The per-pair OF graph of an MLOF2 model (encoder for both frames + pair). Inputs col (2,3,H,W) rows (B, A),
    dep (2,1,H,W). Outputs of_full (2,2,H,W) full-res px (row 0 = B->A), conf_occ (2,2,H/4,W/4) logits.
    prop4 / up_full / deep16 follow the model's flags (cut3: all three off)."""
    _variant_ok(model.pair)
    g = Graph()
    col, dep = g.t("col", 3, 1), g.t("dep", 1, 1)
    g.inputs = [col, dep]
    lo = _Lower(model, g)
    feats = lo.encoder(col, dep)
    lo.pair(feats, col)
    g.outputs = ["of_full", "conf_occ"]
    return g


ENC_LEVELS = (4, 8, 16, 32, 64)


def build_enc_graph(model):
    """The encoder alone, once per REAL frame (n = 1): inputs col (1,3,H,W), dep (1,1,H,W) -> outputs f4 .. f64. The
    host keeps each frame's pyramid: the frame is B of one pair and A of the next (encoder cost 6.2 -> 3.1 GMAC/pair)."""
    g = Graph()
    col, dep = g.t("col", 3, 1, n=1), g.t("dep", 1, 1, n=1)
    g.inputs = [col, dep]
    lo = _Lower(model, g)
    lo.n = 1
    feats = lo.encoder(col, dep)
    for lv in ENC_LEVELS:
        g.op("copy", [feats[lv]], g.t(f"f{lv}", g.chans(feats[lv]), lv, n=1))
    c4 = g.op("resize_area", [col], g.t("c4", 3, 4, n=1), s_out=4)
    g.outputs = [f"f{lv}" for lv in ENC_LEVELS] + ["c4"]
    if "m8" in feats:                                                                           
        g.op("copy", [feats["m8"]], g.t("fm8", g.chans(feats["m8"]), 8, n=1))
        g.outputs.append("fm8")
    return g


def build_pair_graph(model):
    """The pair part on cached pyramids: inputs c4 (2,3,H/4,W/4) rows (B, A) and q4 .. q64 (2,c,H/s,W/s) rows (B's
    pyramid, A's pyramid) -- the host copies the two frames' encoder outputs into the rows. Outputs as build_of_graph,
    except PAIR_OF4 (default 1): the 1/4-res flow "of4" (px at 1/4) instead of the full-res fp32 of_full."""
    of4 = "of4" if os.environ.get("PAIR_OF4", "1") != "0" else None
    _variant_ok(model.pair)
    g = Graph()
    c4 = g.t("c4", 3, 4)
    ch = model.enc.CH
    feats = {lv: g.t(f"q{lv}", ch[lv], lv) for lv in ENC_LEVELS}
    g.inputs = [c4] + [feats[lv] for lv in ENC_LEVELS]
    if getattr(model.enc, "menc", None) is not None:
        feats["m8"] = g.t("qm8", model.enc.menc.out.weight.shape[0], 8)
        g.inputs.append(feats["m8"])
    lo = _Lower(model, g)
    lo.pair(feats, c4, of4=of4)
    if os.environ.get("MLOF2_OFT_NO_L4") == "1":
        g.outputs = ["of8", "conf_occ"]
    else:
        g.outputs = [of4 or "of_full", "conf_occ"]
    return g


                                                                                                   
def expand_qstats(g, qs):
    """qstats with every conv key of the graph present: 'name@k' (one conv module used k times, e.g. the recurrent
    block's iterations: each use has its own stored input scale under contract v2) -> the module's stat."""
    q = dict(qs)
    for o in g.ops:
        k = o.get("q")
        if o["kind"] == "conv" and k and k not in q and "@" in k:
            q[k] = q[k.split("@")[0]]
    return q


def _q_int8(x, s):
    return torch.clamp(torch.round(x / s), -127, 127) * s


def _q_fp8(x, s):                                                                             
    return (x / s).clamp(-448.0, 448.0).to(torch.float8_e4m3fn).to(x.dtype) * s


M8_CHAIN = re.compile(r"m8_\d+|fm8|qm8|m16_\d+|rr8_\d+_\d+|rr16_\d+_\d+")


def storage_plan(g, qstats, mode):
    """Arena storage formats to emulate (engine contract v2 candidates). mode:
      "conv": tensors read ONLY by convs -> int8 at that conv's input scale (stat / 127): bit-identical to the PTQ
              (the conv quantizes its input with the same scale anyway)
      "all" : every tensor a conv reads -> int8 (corr / warp / absdiff / residual readers then see int8 values;
              several conv readers: the largest stat), every other tensor -> fp16
      "fp16": only the non-conv tensors -> fp16 (int8 nowhere)
      "all_fp8": as "all" with e4m3 (stat / 448) instead of int8 (pair with the fp8 qstats / fp8 conv quant)
      "every_fp8": as "all_fp8" and the non-conv tensors (flows, conf, ...) ALSO e4m3, unscaled (saturate +-448)
      "v2_int8" / "v2_fp8": contract v2 (2026-10-23): every tensor a conv reads is 8-bit, ONE scale per group of
              tensors that are concatenated into the same conv input (union over convs, the largest stat): the kernel
              accumulates over K without rescaling; every other tensor fp16. Use with storage_conv_stats() as the
              conv input stats so the conv quantizes exactly as stored.
    Returns {tensor name: ("int8" | "fp8", stat) | ("fp16" | "fp8raw", None)}."""
    qstats = expand_qstats(g, qstats)
    cons = {}
    for o in g.ops:
        for r in o["ins"]:
            cons.setdefault(_parse(r)[0], []).append(o)
        if o.get("res"):
            cons.setdefault(_parse(o["res"])[0], []).append({"kind": "res"})
    plan = {}
    if mode in ("v2_int8", "v2_fp8"):
        par = {}
        find = lambda x: x if par.setdefault(x, x) == x else find(par[x])
        gst = {}
        for o in g.ops:
            if o["kind"] != "conv":
                continue
            ts = [_parse(r)[0] for r in o["ins"]]
            for t_ in ts[1:]:
                par[find(t_)] = find(ts[0])
            find(ts[0])
        for o in g.ops:
            if o["kind"] == "conv":
                r = find(_parse(o["ins"][0])[0])
                gst[r] = max(gst.get(r, 0.0), float(qstats[o["q"]]))
        f8 = "fp8" if mode == "v2_fp8" else "int8"
        for t in cons:
            if t in par:
                plan[t] = (f8, gst[find(t)])
            else:
                plan[t] = ("fp16", None)
        if "of.m8" in qstats:                                                                                         
            for t in g.tensors:                                                                                       
                if M8_CHAIN.fullmatch(t):
                    plan[t] = (f8, float(qstats["of.m8"]))
        return plan
    for t, c in cons.items():
        st = [float(qstats[o["q"]]) for o in c if o["kind"] == "conv"]
        conv_only = all(o["kind"] == "conv" for o in c)
        if st and (mode == "all" or (mode == "conv" and conv_only)):
            plan[t] = ("int8", max(st))
        elif st and mode in ("all_fp8", "every_fp8"):
            plan[t] = ("fp8", max(st))
        elif not st and mode in ("all", "fp16", "all_fp8"):
            plan[t] = ("fp16", None)
        elif not st and mode == "every_fp8":
            plan[t] = ("fp8raw", None)
    return plan


def storage_conv_stats(g, plan, qstats):
    """qstats with every conv's input stat replaced by the stored group scale (contract v2)."""
    q = expand_qstats(g, qstats)
    for o in g.ops:
        if o["kind"] == "conv":
            f = plan.get(_parse(o["ins"][0])[0])
            if f is not None and f[0] in ("int8", "fp8"):
                q[o["q"]] = f[1]
    return q


class Executor:
    """Runs a Graph with torch. quant: None (fp32) or (act stats dict, "int8" | "fp8"): every conv input quantized per
    tensor (stat / QMAX) and the weights per output channel (amax / QMAX), QMAX 127 (int8) or 448 (fp8 e4m3fn), as
    quant_ptq.QWrap."""
    def __init__(self, g, H, W, device="cuda", quant=None, fp16_storage=False, store=None):
        self.g, self.H, self.W, self.dev = g, H, W, device
        self.quant, self.fp16 = quant, fp16_storage
        self.store = store or {}                                                                          
        self.v = {}
        self.wq = {}
        if quant is not None:
            quant = (expand_qstats(g, quant[0]), quant[1]); self.quant = quant
            for i, o in enumerate(g.ops):
                if o["kind"] == "conv":
                    w = o["w"].to(device)
                    a = w.abs().flatten(1).amax(1).clamp_min(1e-12).view(-1, 1, 1, 1)
                    self.wq[i] = self._q(w, a)

    def _q(self, x, amax):
        return _q_fp8(x, amax / 448.0) if self.quant[1] == "fp8" else _q_int8(x, amax / 127)

    def shape(self, name):
        t = self.g.tensors[name]
        return (t["n"], t["c"], self.H // t["s"], self.W // t["s"])

    def get(self, ref):
        name, sw, sl = _parse(ref)
        x = self.v[name]
        if sl is not None:
            x = x[:, sl[0]:sl[1]]
        if sw:
            x = torch.cat((x[1:2], x[0:1]), 0)
        return x

    def put(self, ref, x):
        name, sw, sl = _parse(ref)
        assert not sw
        if self.fp16:
            x = x.half().float()
        x = self._stored(name, x)
        if sl is None:
            self.v[name] = x
        else:
            if name not in self.v:
                self.v[name] = torch.zeros(self.shape(name), device=self.dev)
            self.v[name][:, sl[0]:sl[1]] = x

    def _stored(self, name, x):
        f = self.store.get(name)
        if f is None:
            return x
        if f[0] == "fp16":
            return x.half().float()
        if f[0] == "fp8raw":
            return x.clamp(-448.0, 448.0).to(torch.float8_e4m3fn).float()
        if f[0] == "fp8":
            return _q_fp8(x, max(f[1], 1e-8) / 448.0)
        return _q_int8(x, max(f[1], 1e-8) / 127)

    def run(self, inputs, dump=None):
        for k, x in inputs.items():
            self.v[k] = self._stored(k, x.to(self.dev).float())
        for i, o in enumerate(self.g.ops):
            y = self.op(i, o)
            self.put(o["out"], y)
            if dump is not None:
                dump(i, o, self.get(o["out"]))
        return {k: self.v[k] for k in self.g.outputs}

    def op(self, i, o):
        out_name = _parse(o["out"])[0]
        out_n = self.g.tensors[out_name]["n"]
        k, ins = o["kind"], [self.get(r) for r in o["ins"]]
        lv = lambda: self.g.level(o["out"])
        if out_n == 1:
            if k == "round_trip":
                return M.PairFlow.round_trip(ins[0], 1)[:1]
            ins = [x[:1] if x.shape[0] > 1 else x for x in ins]
        if k == "conv":
            x = torch.cat(ins, 1)
            w = o["w"].to(self.dev)
            if self.quant is not None:
                st = self.quant[0][o["q"]]
                x = self._q(x, max(st, 1e-8))
                w = self.wq[i]
            y = F.conv2d(x, w, o["b"].to(self.dev), o["stride"], o["pad"], o["dil"])
            res = None if o["res"] is None else self.get(o["res"])
            if res is not None and out_n == 1 and res.shape[0] > 1:
                res = res[:1]
            act = {"none": lambda z: z, "leaky": M.leaky, "relu": F.relu}[o["act"]]
            if res is not None and o["res_mode"] == "pre":
                return act(y + res)
            y = act(y)
            return y if res is None else res + y
        if k == "unshuffle":
            return F.pixel_unshuffle(torch.cat(ins, 1), o["f"])
        if k == "resize_area":
            return F.interpolate(ins[0], size=(self.H // o["s_out"], self.W // o["s_out"]), mode="area")
        if k == "resize_bil":
            y = F.interpolate(ins[0], size=(self.H // o["s_out"], self.W // o["s_out"]), mode="bilinear", align_corners=False)
            return y * torch.tensor(o["mul"], device=self.dev).view(1, -1, 1, 1)
        if k == "warp":
            return M.warp(ins[0], ins[1])
        if k == "corr":
            return M.correlation(ins[0], ins[1], o["radius"])
        if k == "absdiff":
            return (ins[0] - ins[1]).abs().mean(1, keepdim=True)
        if k == "round_trip":
            return M.PairFlow.round_trip(ins[0], 1)
        if k == "spread":
            return M.PairFlow.spread(ins[0])
        if k == "axpy":
            return ins[0] + o["k"] * ins[1]
        if k == "scale":
            return o["k"] * ins[0]
        if k == "zeros":                                                       
            nm_, _, sl_ = _parse(o["out"])
            sh_ = list(self.shape(nm_))
            if sl_ is not None:
                sh_[1] = sl_[1] - sl_[0]
            return torch.zeros(sh_, device=self.dev)
        if k == "copy":
            return ins[0]
        if k == "affine":
            return o["k"] * ins[0] + o["c"]
        if k == "tanh":
            return torch.tanh(ins[0])
        if k == "gru":
            h, zq = ins
            hd = h.shape[1]
            return h + torch.sigmoid(zq[:, :hd]) * (torch.tanh(zq[:, hd:]) - h)
        if k == "convex_up":
            return M.convex_upsample_rep(ins[0], ins[1], o["f"])
        if k == "prop_step":                                                                           
            return prop_step(ins[0], ins[1], o["it"], o["n_it"], o["dil"])
        raise ValueError(k)


def prop_step(of, oo, j, kk, d):
    n, _, h, w = of.shape
    wts = oo[:, 9 * j:9 * j + 9].softmax(1)                                                           
    gate = torch.sigmoid(oo[:, 9 * kk + j:9 * kk + j + 1])
    nb = F.unfold(F.pad(of, (d, d, d, d), mode="replicate"), 3, dilation=d).view(n, 2, 9, h, w)
    return of + gate * ((nb * wts[:, None]).sum(2) - of)


def model_reference(model, col, dep):
    """The model's own forward for the same inputs (rows B, A): of_full (2,2,H,W), conf_occ (2,2,H/4,W/4)."""
    fa = model.enc(col[1:2], dep[1:2])
    fb = model.enc(col[0:1], dep[0:1])
    out = model.pair.of_forward(fa, fb, col[1:2], col[0:1])
    o4 = out[4]
    full = o4.get("of_full")
    if full is None:                                                                                    
        full = F.interpolate(o4["of"], size=col.shape[-2:], mode="bilinear", align_corners=False) * (col.shape[-1] / o4["of"].shape[-1])
    return full, torch.cat((o4["conf"], o4["occ"]), 1)
