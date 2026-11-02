"""The generation stage (mlof2_gen_graph.gen_reference) lowered to an engine op table + its torch executor.
New op kinds (mlof2_engine/shaders/mlof2_gen.comp; semantics = GenExecutor.op):
  vig_part    pair_first only: 4 x 4 grid normal-equation partial sums (ins col_a, col_b, mv, mvv)
  vig_solve   pair_first only: sum the partials, decay / add into the vig state, darken-only solve -> vig[12:15]
  vig_apply   mode 0: img / V, mode 1: clamp(img * V, 0, 1); V from vig[12:15]
  mul         a * b (b one channel, broadcast)
  invert_t    ins f, depth[, f_bp[, valid]]; t_mode 0 = t from fc, 1 = 0; accel if has_prev and accel=1;
              out 6 = to_A 2, to_B 2, hole, oob
  warp_noise  warp(src, flow), hash noise (candidate idx) where y + flow is off the frame
  off_frame   y + flow off the frame -> 1 / 0          flowdist  min(|a - b|_2 / 16, 4)
  sigmoid     fill_t (t)   up_nearest (x2)
  absdiff     (OF graph op) mean_c |a - b| * k, clamped to hi if hi > 0
  softmax_blend  ins logits 4, cand 12 -> colour 3 (clamp 0..1), weights 4
  rule_prep   ins cand 12, weights 4, off_a, off_b -> mo 3 (ONESIDE), mean|c0 - c1|, mean|c2 - c3|, one
  pool        mode 0 avg (count_include_pad) / 1 max, k (stride 1, pad k // 2)
  luma_grad   |l(x+1) - l(x-1)| + |l(y+1) - l(y-1)| (0 on the border rows / columns)
  mask_mul    a * (1 - b)     median  4096-bin histogram lower median -> the whole out tensor
  rule_score  sigmoid((dmv - dof - 0.5 k) / (0.25 k)), k = contrast + median + 1e-3
  axpy_t      a + (1 - t) b   rule_carry  has_prev ? max(m, 0.6 carried) : m    blend_mask  (1 - m) mo + m colour
  cam_flow    ndc z -> A pixel offset at t (fc VP_A, VP_B, inv VP_A)
  trail_sel   cand_a where oob_mv & !hole2 & !off(to_B2), else col
Fused (fuse=True, 2026-10-24: the 28-channel full-res feature tensor never exists in memory):
  warp_noise4 ins ca_h, cb_h, inv_mv, inv_of -> cand 12 = the four warp_noise candidates (idx 0..3)
  feat4       ins cand, dep_a, dep_b, inv_mv, inv_of, co -> the head input x4 = area / 4 of the 28 features
              (feat28: the unfused ops 15..34, same functions, without the fp16 storage of the full-res tensor)
  median_hist the engine's 4096-bin histogram of ins[0] (uint counts, flat, into a zeroed tensor); here zeros
  median_pick ins hist, x: the lower median of x (= median) -> the whole out tensor (engine: from the histogram)
  prep_c      ins col_a, col_b, vig -> ca_h 3 | 0 | cb_h 3 | 0 (vig_apply mode 0 of both)
  prep_f      ins mv, mvv, mv_ap, of, of_prev -> mv * mvv 2 | mv + warp(mv_ap, mv) 2 | of + warp(of_prev, of) 2
  blend_prep  ins hlog (1/4), cand, off_mv, oob_mv -> softmax_blend(bilinear-up hlog, cand) 7 | rule_prep 6
  carry       ins m1, to_A(mv), mv_ap, pmask -> rule_carry(m1, warp(pmask, ma + (1 - t) warp(mv_ap, ma)))
  cam_inv     ins ndc_a, dep_a -> invert_t(cam_flow(ndc_a), dep_a, t = 0) (cam_flow evaluated where it is read)
  final       ins mo 3, blend colour 3, mask, inv_cam 6, ca_h 3, oob_mv, vig -> vig_apply(trail_sel(blend_mask(...),
              warp(ca_h, inv_cam to_B), inv_cam, oob_mv), mode 1) = out
Structure 3 (fuse=True, 2026-10-24: fewer full-res passes, no stored candidates):
  prep        ins col_a, col_b, vig, mv, mvv, mv_ap, of, of_prev -> pf 12 = prep_c 6 | prep_f 6
  inv3        ins pf, dep_b, mvv, of, ndc_a, dep_a -> inv 18 = invert_t(mv) 6 | invert_t(of) 6 | cam_inv 6
  feat4c      ins pf, inv, dep_a, dep_b, co -> x4 = feat4 of the candidates warp_noise4(pf, inv) (computed, not stored)
  blend9      ins hlog, pf, inv -> bp 9 = blend colour 3 | rule_prep 6 (mo 3, d01, d23, one), candidates computed
  final3      ins bp, mask, inv, pf, vig -> out (final with mo, colour, inv_cam, ca_h, oob_mv from those tensors)
Structure 4 (2026-10-24, the old NFRU lane layout: inversion at 1/2, features / head / rule / camera at 1/4, one
full-res composition pass; NFRU test 2x 5.81 -> 5.95, 4x 9.67 -> 9.53 in the gen_half.py prototype):
  prep_h      ins mv, mvv, mv_ap, of, of_prev -> 1/2: area / 2 of mv * mvv 2 | mv + warp(mv_ap, mv) 2 | of 2 |
              of + warp(of_prev, of) 2 | area(mvv) > 0.5
  (invert_t of both at 1/2)
  q_prep      ins cab, dep_a, dep_b, mv_ap -> 1/4: area of ca_h 3 | 0 | cb_h 3 | 0 | dep_a | dep_b | mv_ap / 4 2
  q_cand      ins qp, inv_mv, inv_of (1/2) -> 1/4: the flows area / 2 (ma mb oa ob), flags area > 0.5 (hole_mv,
              hole_of, oob_mv, oob_of), the four warp_noise candidates of qp: cand 12 | flows 8 | flags 4
  q_feat      ins qc, qp, co -> 1/4: the head's 28 inputs on the 1/4 grid (flow distance in full-res px)
  q_rule1     ins hlog, qc -> 1/4: rule_rel inputs: d_mv (masked by the 3 x 3 max of one), d_of, luma_grad(mo)
  q_rule2     ins r1, med, qc, qp, pmask (1/4) -> mask: max3(rule_score), rel_t carry
  cam_inv_q   ins ndc_a -> 1/4: cam_inv on the 1/4 grid (ndc nearest = pixel 4 y, 4 x)
  final4      ins cab, inv_mv, inv_of, hlog, mask, inv_cam, vig -> out: flows bilinear up x2, logits / mask / camera
              bilinear up, the four candidates, softmax blend, ONESIDE mo, mask mix, trailing band, vignette"""
import os
import torch
from torch.nn import functional as F
import model_v2 as M
import mlof2_graph as MG
from mlof2_gen_graph import (invert_t1, hash_noise, off_frame, median_hist, cam_flow, vig_sums, vig_update, vig_map)

GEN_KINDS = ["vig_part", "vig_solve", "vig_apply", "mul", "invert_t", "warp_noise", "off_frame", "flowdist", "sigmoid",
             "fill_t", "up_nearest", "softmax_blend", "rule_prep", "pool", "luma_grad", "mask_mul", "median",
             "rule_score", "axpy_t", "rule_carry", "blend_mask", "cam_flow", "trail_sel", "warp_noise4", "feat4", "median_hist",
             "median_pick", "prep_c", "prep_f", "blend_prep", "carry", "cam_inv", "final",
             "prep", "inv3", "feat4c", "blend9", "final3",
             "prep_h", "q_prep", "q_cand", "q_feat", "q_rule1", "q_rule2", "cam_inv_q", "final4", "homog_acc", "homog_solve"]
STRUCT4 = ("prep_h", "q_prep", "q_cand", "q_feat", "q_rule1", "q_rule2", "cam_inv_q", "homog_acc", "homog_solve", "final4")
FUSED3 = ("prep", "inv3", "feat4c", "blend9", "final3")
                                                                                                                  
GEN_IO_FP16 = ("col_a", "col_b", "co", "mvv", "pmask")


def feat28(cand, da, db, im, io_, co, t):
    """The head's 28 full-res input features (the unfused graph's x28 tensor)."""
    ma, mb, oa, ob = im[:, 0:2], im[:, 2:4], io_[:, 0:2], io_[:, 2:4]
    ad = lambda a, b, k, hi=0.0: ((a - b).abs().mean(1, keepdim=True) * k).clamp(max=hi) if hi > 0 else (a - b).abs().mean(1, keepdim=True) * k
    x12, x13 = M.warp(da, ma), M.warp(db, mb)
    cof = F.interpolate(co, size=cand.shape[-2:], mode="bilinear", align_corners=False)
    return torch.cat((cand, x12, x13, im[:, 4:5], io_[:, 4:5], torch.full_like(x12, float(t)),
                      ad(cand[:, 0:3], cand[:, 3:6], 4.0), ad(cand[:, 6:9], cand[:, 9:12], 4.0),
                      ((ma - oa).norm(dim=1, keepdim=True) / 16.0).clamp(max=4.0), torch.sigmoid(M.warp(cof, ob)),
                      ad(x12, x13, 16.0, 4.0), ad(M.warp(da, oa), M.warp(db, ob), 16.0, 4.0),
                      off_frame(ma), im[:, 5:6], off_frame(oa), io_[:, 5:6]), 1)


def _name(root, mod):
    for n, mm in root.named_modules():
        if mm is mod:
            return n
    raise KeyError(mod)


def build_gen_graph(head, fuse=True, structure=2, split=False):
    if split:
        return build_gen_prep_graph(head), build_gen_t_graph(head)
    """head: NfruHeadC2 with BN folded (quant_ptq.fold_bn). Inputs / outputs: mlof2_gen_graph docstring.
    fuse: structure 3 (module docstring; same values in fp32), else the op-per-function reference graph."""
    if fuse and structure == 3:
        return _build_fused3(head)
    if fuse and structure == 4:
        return _build_struct4(head)
    g = MG.Graph()
    lo = MG._Lower(None, g)
    new = lambda base, c, s=1: lo.new(base, c, s, n=1)
    for k, c, s in (("col_a", 3, 1), ("col_b", 3, 1), ("dep_a", 1, 1), ("dep_b", 1, 1), ("ndc_a", 1, 1), ("mv", 2, 1),
                    ("mvv", 1, 1), ("mv_ap", 2, 1), ("of", 2, 1), ("of_prev", 2, 1), ("co", 2, 4), ("pmask", 1, 1),
                    ("vig", 16, 64)):
        g.t(k, c, s, n=1)
        g.inputs.append(k)
    op = g.op
    vpart = new("vpart", 16, 4)
    op("vig_part", ["col_a", "col_b", "mv", "mvv"], vpart)
    op("vig_solve", [vpart], "vig")                                                                         
    if fuse:
        cab = op("prep_c", ["col_a", "col_b", "vig"], new("cab", 8))                                                 
        ca_h, cb_h = f"{cab}[0:3]", f"{cab}[4:7]"                                                 
        fl = op("prep_f", ["mv", "mvv", "mv_ap", "of", "of_prev"], new("flows", 6))
        mvm, mvbp, ofbp = f"{fl}[0:2]", f"{fl}[2:4]", f"{fl}[4:6]"
    else:
        ca_h = op("vig_apply", ["col_a", "vig"], new("ca_h", 3), mode=0)
        cb_h = op("vig_apply", ["col_b", "vig"], new("cb_h", 3), mode=0)
        mvm = op("mul", ["mv", "mvv"], new("mvm", 2))
        mvbp = op("axpy", ["mv", op("warp", ["mv_ap", "mv"], new("wap", 2))], new("mvbp", 2), k=1.0)
        ofbp = op("axpy", ["of", op("warp", ["of_prev", "of"], new("wop", 2))], new("ofbp", 2), k=1.0)
    im = op("invert_t", [mvm, "dep_b", mvbp, "mvv"], new("inv_mv", 6), t_mode=0, accel=1)
    io_ = op("invert_t", ["of", "dep_b", ofbp], new("inv_of", 6), t_mode=0, accel=1)
    ma, mb, oa, ob = f"{im}[0:2]", f"{im}[2:4]", f"{io_}[0:2]", f"{io_}[2:4]"
    if fuse:
        cand = op("warp_noise4", [ca_h, cb_h, im, io_], new("cand", 12))
        off_mv, oob_mv = op("off_frame", [ma], new("offmv", 1)), f"{im}[5:6]"
        xq = op("feat4", [cand, "dep_a", "dep_b", im, io_, "co"], new("x4", 28, 4))
    else:
        cand, off_mv, oob_mv, xq = _feat_unfused(op, new, ca_h, cb_h, im, io_, ma, mb, oa, ob)
    return _gen_tail(g, lo, op, new, head, ca_h, ma, cand, off_mv, oob_mv, xq, fuse)


def _feat_unfused(op, new, ca_h, cb_h, im, io_, ma, mb, oa, ob):
    cand = new("cand", 12)
    for i, (src, fl) in enumerate(((ca_h, ma), (cb_h, mb), (ca_h, oa), (cb_h, ob))):
        op("warp_noise", [src, fl], f"{cand}[{3 * i}:{3 * i + 3}]", idx=i)
    x = new("x28", 28)
    op("copy", [cand], f"{x}[0:12]")
    op("warp", ["dep_a", ma], f"{x}[12:13]")
    op("warp", ["dep_b", mb], f"{x}[13:14]")
    op("copy", [f"{im}[4:5]"], f"{x}[14:15]")
    op("copy", [f"{io_}[4:5]"], f"{x}[15:16]")
    op("fill_t", [], f"{x}[16:17]")
    op("absdiff", [f"{cand}[0:3]", f"{cand}[3:6]"], f"{x}[17:18]", k=4.0, hi=0.0)
    op("absdiff", [f"{cand}[6:9]", f"{cand}[9:12]"], f"{x}[18:19]", k=4.0, hi=0.0)
    op("flowdist", [ma, oa], f"{x}[19:20]")
    cof = op("resize_bil", ["co"], new("co_full", 2), s_out=1, mul=[1.0, 1.0])
    cow = op("warp", [cof, ob], new("co_w", 2))
    op("sigmoid", [cow], f"{x}[20:22]")
    op("absdiff", [f"{x}[12:13]", f"{x}[13:14]"], f"{x}[22:23]", k=16.0, hi=4.0)
    dao = op("warp", ["dep_a", oa], new("da_oa", 1))
    dbo = op("warp", ["dep_b", ob], new("db_ob", 1))
    op("absdiff", [dao, dbo], f"{x}[23:24]", k=16.0, hi=4.0)
    op("off_frame", [ma], f"{x}[24:25]")
    op("copy", [f"{im}[5:6]"], f"{x}[25:26]")
    op("off_frame", [oa], f"{x}[26:27]")
    op("copy", [f"{io_}[5:6]"], f"{x}[27:28]")
    xq = op("resize_area", [x], new("x4", 28, 4), s_out=4)
    return cand, f"{x}[24:25]", f"{x}[25:26]", xq


def _gen_tail(g, lo, op, new, head, ca_h, ma, cand, off_mv, oob_mv, xq, fuse):
    ae = head.ae

    def cv(mod, srcs, base, act="relu"):
        y = lo.conv(mod, [lo.full(s) for s in srcs], base, act=act, q=f"head.{_name(head, mod)}")
        g.tensors[y]["n"] = 1
        return y
    h1 = cv(ae.conv1.conv2d, [xq], "h1")
    h2 = cv(ae.conv2.conv2d, [h1], "h2")
    h3 = cv(ae.conv3.conv2d, [h2], "h3")
    sk = cv(ae.skip1_conv.conv2d, [h3], "hsk")
    b = cv(ae.conv5.conv2d, [h3], "h5")
    xa = cv(ae.conv5a.conv2d, [b], "h5a")
    xb = cv(ae.conv5b.conv2d, [b], "h5b")
    xc = cv(ae.conv5c_1.conv2d, [cv(ae.conv5c.conv2d, [b], "h5c")], "h5c1")
    xd = cv(ae.conv5d_2.conv2d, [cv(ae.conv5d_1.conv2d, [cv(ae.conv5d.conv2d, [b], "h5d")], "h5d1")], "h5d2")
    e = cv(ae.conv5e.conv2d, [xa, xb, xc, xd], "h5e")
    u = op("up_nearest", [e], new("hup", 16, g.level(e) // 2))
    h6 = cv(ae.conv6.conv2d, [u], "h6")
    h7 = cv(ae.conv7.conv2d, [h6, sk], "h7")
    lg = cv(ae.output_conv_mv, [h7], "hlog", act="none")
    if fuse:
        bp = op("blend_prep", [lg, cand, off_mv, oob_mv], new("bp", 13))
        sbs = lambda a, b: f"{bp}[{a}:{b}]"
        rps = lambda a, b: f"{bp}[{7 + a}:{7 + b}]"
    else:
        lgf = op("resize_bil", [lg], new("logits", 4), s_out=1, mul=[1.0] * 4)
        sb = op("softmax_blend", [lgf, cand], new("blend", 7))
        rp = op("rule_prep", [cand, f"{sb}[3:7]", off_mv, oob_mv], new("rprep", 6))
        sbs = lambda a, b: f"{sb}[{a}:{b}]"
        rps = lambda a, b: f"{rp}[{a}:{b}]"
    dd = op("pool", [rps(3, 5)], new("dd", 2), mode=0, k=3)
    onep = op("pool", [rps(5, 6)], new("onep", 1), mode=1, k=9)
    dmv = op("mask_mul", [f"{dd}[0:1]", onep], new("dmv", 1))
    if fuse:                                                                                         
        hist = op("zeros", [], new("mhist", 2, 8))                                                                         
                                                                                                          
        op("median_hist", [dmv], hist)
        med = op("median_pick", [hist, dmv], new("med", 1, 64))
    else:
        med = op("median", [dmv], new("med", 1, 64))
    con = op("pool", [op("luma_grad", [rps(0, 3)], new("lgrad", 1))], new("contrast", 1), mode=0, k=5)
    m0 = op("rule_score", [dmv, f"{dd}[1:2]", con, med], new("m0", 1))
    m1 = op("pool", [op("pool", [m0], new("m0mx", 1), mode=1, k=9)], new("m1", 1), mode=0, k=5)
    if fuse:
        m = op("carry", [m1, ma, "mv_ap", "pmask"], new("mask", 1))
        i2 = op("cam_inv", ["ndc_a", "dep_a"], new("inv_cam", 6))
        op("final", [rps(0, 3), sbs(0, 3), m, i2, ca_h, oob_mv, "vig"], g.t("out", 3, 1, n=1))
        op("copy", [m], "pmask")                                                                                 
        g.outputs = ["out", "vig", "pmask"]
        return g
    tp = op("axpy_t", [ma, op("warp", ["mv_ap", ma], new("wapma", 2))], new("to_prev", 2))
    m = op("rule_carry", [m1, op("warp", ["pmask", tp], new("pcarry", 1))], new("mask", 1))
    col = op("blend_mask", [rps(0, 3), sbs(0, 3), m], new("col", 3))
    dt = op("cam_flow", ["ndc_a"], new("camflow", 2))
    i2 = op("invert_t", [dt, "dep_a"], new("inv_cam", 6), t_mode=1, accel=0)
    cav = op("warp", [ca_h, f"{i2}[2:4]"], new("cand_a", 3))
    col2 = op("trail_sel", [col, cav, i2, oob_mv], new("col2", 3))
    op("vig_apply", [col2, "vig"], g.t("out", 3, 1, n=1), mode=1)
    op("copy", [m], "pmask")                                                                                     
    g.outputs = ["out", "vig", "pmask"]
    return g


def _build_fused3(head):
    g = MG.Graph()
    lo = MG._Lower(None, g)
    new = lambda base, c, s=1: lo.new(base, c, s, n=1)
    for k, c, s in (("col_a", 3, 1), ("col_b", 3, 1), ("dep_a", 1, 1), ("dep_b", 1, 1), ("ndc_a", 1, 1), ("mv", 2, 1),
                    ("mvv", 1, 1), ("mv_ap", 2, 1), ("of", 2, 1), ("of_prev", 2, 1), ("co", 2, 4), ("pmask", 1, 1),
                    ("vig", 16, 64)):
        g.t(k, c, s, n=1)
        g.inputs.append(k)
    op = g.op
    vpart = new("vpart", 16, 4)
    op("vig_part", ["col_a", "col_b", "mv", "mvv"], vpart)
    op("vig_solve", [vpart], "vig")                                                                         
    pf = op("prep", ["col_a", "col_b", "vig", "mv", "mvv", "mv_ap", "of", "of_prev"], new("pf", 12))
    inv = op("inv3", [pf, "dep_b", "mvv", "of", "ndc_a", "dep_a"], new("inv", 18))
    xq = op("feat4c", [pf, inv, "dep_a", "dep_b", "co"], new("x4", 28, 4))
    ae = head.ae

    def cv(mod, srcs, base, act="relu"):
        y = lo.conv(mod, [lo.full(s) for s in srcs], base, act=act, q=f"head.{_name(head, mod)}")
        g.tensors[y]["n"] = 1
        return y
    h1 = cv(ae.conv1.conv2d, [xq], "h1")
    h2 = cv(ae.conv2.conv2d, [h1], "h2")
    h3 = cv(ae.conv3.conv2d, [h2], "h3")
    sk = cv(ae.skip1_conv.conv2d, [h3], "hsk")
    b = cv(ae.conv5.conv2d, [h3], "h5")
    xa = cv(ae.conv5a.conv2d, [b], "h5a")
    xb = cv(ae.conv5b.conv2d, [b], "h5b")
    xc = cv(ae.conv5c_1.conv2d, [cv(ae.conv5c.conv2d, [b], "h5c")], "h5c1")
    xd = cv(ae.conv5d_2.conv2d, [cv(ae.conv5d_1.conv2d, [cv(ae.conv5d.conv2d, [b], "h5d")], "h5d1")], "h5d2")
    e = cv(ae.conv5e.conv2d, [xa, xb, xc, xd], "h5e")
    u = op("up_nearest", [e], new("hup", 16, g.level(e) // 2))
    h6 = cv(ae.conv6.conv2d, [u], "h6")
    h7 = cv(ae.conv7.conv2d, [h6, sk], "h7")
    lg = cv(ae.output_conv_mv, [h7], "hlog", act="none")
    bp = op("blend9", [lg, pf, inv], new("bp", 9))
    dd = op("pool", [f"{bp}[6:8]"], new("dd", 2), mode=0, k=3)
    onep = op("pool", [f"{bp}[8:9]"], new("onep", 1), mode=1, k=9)
    dmv = op("mask_mul", [f"{dd}[0:1]", onep], new("dmv", 1))
    hist = op("zeros", [], new("mhist", 2, 8))                                                                   
    op("median_hist", [dmv], hist)
    med = op("median_pick", [hist, dmv], new("med", 1, 64))
    con = op("pool", [op("luma_grad", [f"{bp}[3:6]"], new("lgrad", 1))], new("contrast", 1), mode=0, k=5)
    m0 = op("rule_score", [dmv, f"{dd}[1:2]", con, med], new("m0", 1))
    m1 = op("pool", [op("pool", [m0], new("m0mx", 1), mode=1, k=9)], new("m1", 1), mode=0, k=5)
    m = op("carry", [m1, f"{inv}[0:2]", "mv_ap", "pmask"], new("mask", 1))
    op("final3", [bp, m, inv, pf, "vig"], g.t("out", 3, 1, n=1))
    op("copy", [m], "pmask")                                                                                     
    g.outputs = ["out", "vig", "pmask"]
    return g


def _head_convs(g, lo, op, new, head, xq):
    ae = head.ae

    def cv(mod, srcs, base, act="relu"):
        y = lo.conv(mod, [lo.full(s) for s in srcs], base, act=act, q=f"head.{_name(head, mod)}")
        g.tensors[y]["n"] = 1
        return y
    h1 = cv(ae.conv1.conv2d, [xq], "h1")
    h2 = cv(ae.conv2.conv2d, [h1], "h2")
    h3 = cv(ae.conv3.conv2d, [h2], "h3")
    sk = cv(ae.skip1_conv.conv2d, [h3], "hsk")
    b = cv(ae.conv5.conv2d, [h3], "h5")
    xa = cv(ae.conv5a.conv2d, [b], "h5a")
    xb = cv(ae.conv5b.conv2d, [b], "h5b")
    xc = cv(ae.conv5c_1.conv2d, [cv(ae.conv5c.conv2d, [b], "h5c")], "h5c1")
    xd = cv(ae.conv5d_2.conv2d, [cv(ae.conv5d_1.conv2d, [cv(ae.conv5d.conv2d, [b], "h5d")], "h5d1")], "h5d2")
    e = cv(ae.conv5e.conv2d, [xa, xb, xc, xd], "h5e")
    u = op("up_nearest", [e], new("hup", 16, g.level(e) // 2))
    h6 = cv(ae.conv6.conv2d, [u], "h6")
    h7 = cv(ae.conv7.conv2d, [h6, sk], "h7")
    return cv(ae.output_conv_mv, [h7], "hlog", act="none")


                                                                                                                        
                                                                                                            
                                                                      
GEN_OF_S = 4 if os.environ.get("GEN_OF4", "1") != "0" else 1
                                                                                                                          
if os.environ.get("GEN_OF_S"):
    GEN_OF_S = int(os.environ["GEN_OF_S"])


                                                                                                                
                                                                                                                  
                                                                                                                  
                                                                                                             
GEN_BOTHFAIL = tuple(float(v) for v in os.environ["GEN_BOTHFAIL"].split(",")) if os.environ.get("GEN_BOTHFAIL") else None


GEN_BF_PICK = os.environ.get("GEN_BF_PICK", "near")                                                                           
GEN_BF_EDGE = float(os.environ.get("GEN_BF_EDGE", "2.0"))
                                                                                                                    
                                                                                                         
GEN_BF_PICK4 = int(os.environ.get("GEN_BF_PICK4", "0"))
                                                                                                                   
GEN_BF_REACH = float(os.environ.get("GEN_BF_REACH", "0.75"))


def _rule2(op, new, r1, med, qc, qp):
    if GEN_BOTHFAIL:
        return op("q_rule2", [r1, med, qc, qp, "pmask"], new("mask", 2, 4), bf=GEN_BOTHFAIL)
    return op("q_rule2", [r1, med, qc, qp, "pmask"], new("mask", 1, 4))


def _build_struct4(head):
    g = MG.Graph()
    lo = MG._Lower(None, g)
    new = lambda base, c, s=1: lo.new(base, c, s, n=1)
    for k, c, s in (("col_a", 3, 1), ("col_b", 3, 1), ("dep_a", 1, 1), ("dep_b", 1, 1), ("ndc_a", 1, 1), ("mv", 2, 1),
                    ("mvv", 1, 1), ("mv_ap", 2, 1), ("of", 2, GEN_OF_S), ("of_prev", 2, GEN_OF_S), ("co", 2, 4), ("pmask", 1, 4),
                    ("vig", 16, 64)):
        g.t(k, c, s * _LS(k), n=1)
        g.inputs.append(k)
    op = g.op
    vpart = new("vpart", 16, 4)
    op("vig_part", ["col_a", "col_b", "mv", "mvv"], vpart)
    op("vig_solve", [vpart], "vig")
    cab = op("prep_c", ["col_a", "col_b", "vig"], new("cab", 8))
    ph = op("prep_h", ["mv", "mvv", "mv_ap", "of", "of_prev"], new("ph", 9, 2), point=GEN_POINT & 1)
    qp = op("q_prep", [cab, "dep_a", "dep_b", "mv_ap"], new("qp", 12, 4), point=(GEN_POINT >> 1) & 1)
    im = op("invert_t", [f"{ph}[0:2]", "dep_b", f"{ph}[2:4]", f"{ph}[8:9]"], new("inv_mv", 6, 2), t_mode=0, accel=1)
    io_ = op("invert_t", [f"{ph}[4:6]", "dep_b", f"{ph}[6:8]"], new("inv_of", 6, 2), t_mode=0, accel=1)
    qc = op("q_cand", [qp, im, io_], new("qc", 24, 4), hw_bil=GEN_HWBIL)
    xq = op("q_feat", [qc, qp, "co"], new("x4", 28, 4))
    lg = _head_convs(g, lo, op, new, head, xq)
    r1 = op("q_rule1", [lg, qc], new("r1", 3, 4))
    hist = op("zeros", [], new("mhist", 2, 8))                                                                 
    op("median_hist", [f"{r1}[0:1]"], hist)
    med = op("median_pick", [hist, f"{r1}[0:1]"], new("med", 1, 64))
    m = _rule2(op, new, r1, med, qc, qp)
    ic = op("cam_inv_q", ["ndc_a"], new("inv_cam", 3, 4))
                                                                       
    n_iters = int(os.environ.get("HOMOG_ITERS", "1"))
    h_acc = op("homog_acc", [qc, ic], new("h_acc", 109, 32))
    h_out = op("homog_solve", [h_acc], new("h_out", 16, 64))
    h_final = h_out
    if n_iters >= 2:
        h_acc2 = op("homog_acc", [qc, ic, h_out], new("h_acc2", 109, 32))
        h_out2 = op("homog_solve", [h_acc2], new("h_out2", 16, 64))
        h_final = h_out2
    op("final4", [cab, im, io_, lg, m, ic, "vig", h_final], g.t("out", 3, 1, n=1), hw_bil=GEN_HWBIL, pick=GEN_BF_PICK4)
    op("copy", [f"{m}[0:1]" if GEN_BOTHFAIL else m], "pmask")                                                       
    g.outputs = ["out", "vig", "pmask"]
    return g


def build_gen_prep_graph(head=None):
    """Task 4: T-independent generation ops (0..4), run once per pair in 4x."""
    g = MG.Graph()
    lo = MG._Lower(None, g)
    new = lambda base, c, s=1: lo.new(base, c, s, n=1)
    for k, c, s in (("col_a", 3, 1), ("col_b", 3, 1), ("dep_a", 1, 1), ("dep_b", 1, 1), ("mv", 2, 1),
                    ("mvv", 1, 1), ("mv_ap", 2, 1), ("of", 2, GEN_OF_S), ("of_prev", 2, GEN_OF_S),
                    ("vig", 16, 64)):
        g.t(k, c, s * _LS(k), n=1)
        g.inputs.append(k)
    op = g.op
    vpart = new("vpart", 16, 4)
    op("vig_part", ["col_a", "col_b", "mv", "mvv"], vpart)
    op("vig_solve", [vpart], "vig")
    cab = op("prep_c", ["col_a", "col_b", "vig"], g.t("cab", 8, 1, n=1))
    ph = op("prep_h", ["mv", "mvv", "mv_ap", "of", "of_prev"], g.t("ph", 9, 2, n=1), point=GEN_POINT & 1)
    qp = op("q_prep", [cab, "dep_a", "dep_b", "mv_ap"], g.t("qp", 12, 4, n=1), point=(GEN_POINT >> 1) & 1)
    g.outputs = ["vig", "cab", "ph", "qp"]
    return g


def build_gen_t_graph(head):
    """Task 4: T-dependent generation ops (5..33), run once per sub-frame in 4x."""
    g = MG.Graph()
    lo = MG._Lower(None, g)
    new = lambda base, c, s=1: lo.new(base, c, s, n=1)
    for k, c, s in (("vig", 16, 64), ("cab", 8, 1), ("ph", 9, 2), ("qp", 12, 4),
                    ("dep_b", 1, 1), ("ndc_a", 1, 1), ("co", 2, 4), ("pmask", 1, 4)):
        g.t(k, c, s * _LS(k), n=1)
        g.inputs.append(k)
    op = g.op
    im = op("invert_t", ["ph[0:2]", "dep_b", "ph[2:4]", "ph[8:9]"], new("inv_mv", 6, 2), t_mode=0, accel=1)
    io_ = op("invert_t", ["ph[4:6]", "dep_b", "ph[6:8]"], new("inv_of", 6, 2), t_mode=0, accel=1)
    qc = op("q_cand", ["qp", im, io_], new("qc", 24, 4), hw_bil=GEN_HWBIL)
    xq = op("q_feat", [qc, "qp", "co"], new("x4", 28, 4))
    lg = _head_convs(g, lo, op, new, head, xq)
    r1 = op("q_rule1", [lg, qc], new("r1", 3, 4))
    hist = op("zeros", [], new("mhist", 2, 8))                                                                 
    op("median_hist", [f"{r1}[0:1]"], hist)
    med = op("median_pick", [hist, f"{r1}[0:1]"], new("med", 1, 64))
    m = _rule2(op, new, r1, med, qc, "qp")
    ic = op("cam_inv_q", ["ndc_a"], new("inv_cam", 3, 4))
                                                                       
    n_iters = int(os.environ.get("HOMOG_ITERS", "1"))
    h_acc = op("homog_acc", [qc, ic], new("h_acc", 109, 32))
    h_out = op("homog_solve", [h_acc], new("h_out", 16, 64))
    h_final = h_out
    if n_iters >= 2:
        h_acc2 = op("homog_acc", [qc, ic, h_out], new("h_acc2", 109, 32))
        h_out2 = op("homog_solve", [h_acc2], new("h_out2", 16, 64))
        h_final = h_out2
    op("final4", ["cab", im, io_, lg, m, ic, "vig", h_final], g.t("out", 3, 1, n=1), hw_bil=GEN_HWBIL, pick=GEN_BF_PICK4)
    op("copy", [f"{m}[0:1]" if GEN_BOTHFAIL else m], "pmask")                                                       
    g.outputs = ["out", "pmask"]
    return g


def _area(x, f):
    return x if f == 1 else F.avg_pool2d(x, f)


                                                                                                               
                                                                                                                      
                                                                                                                
                                                                                                                   
                                                                                                 
GEN_POINT = int(os.environ.get("GEN_POINT", "3"))

GEN_HWBIL = int(os.environ.get("GEN_HWBIL", "1"))
GEN_PHASE = int(os.environ.get("GEN_PHASE", "0"))                                                             
                                                                                                                          
                                                                                                                     
                                                                                             
GEN_LANES = int(os.environ.get("GEN_LANES", "0"))
if GEN_LANES:
    GEN_PHASE = 1
_LS = lambda k: ({"dep_a": 4, "dep_b": 4, "ndc_a": 4, "mv": 2, "mvv": 2}.get(k, 1) if GEN_LANES else 1)


def warp_hw(t, flow, bits=8):
    """Sample t at (pixel + flow) with 8-bit quantized bilinear weights, zeros outside."""
    n, c, h, w = t.shape
    x, y = M.base_grid(n, h, w, t.device)
    xf = x + flow[:, 0]
    yf = y + flow[:, 1]
    x0 = torch.floor(xf).long()
    y0 = torch.floor(yf).long()
    x1 = x0 + 1
    y1 = y0 + 1
    fx = xf - x0.float()
    fy = yf - y0.float()
    steps = 1 << bits
    wx = torch.round(fx * steps) / float(steps)
    wy = torch.round(fy * steps) / float(steps)
    w00 = ((1.0 - wx) * (1.0 - wy)).unsqueeze(1)
    w10 = (wx * (1.0 - wy)).unsqueeze(1)
    w01 = ((1.0 - wx) * wy).unsqueeze(1)
    w11 = (wx * wy).unsqueeze(1)

    def sample_zero(xc, yc):
        valid = (xc >= 0) & (xc < w) & (yc >= 0) & (yc < h)
        xc_cl = xc.clamp(0, w - 1)
        yc_cl = yc.clamp(0, h - 1)
        idx = (yc_cl * w + xc_cl).unsqueeze(1).expand(-1, c, -1, -1).reshape(n, c, h * w)
        t_flat = t.reshape(n, c, h * w)
        val = torch.gather(t_flat, 2, idx).reshape(n, c, h, w)
        return torch.where(valid.unsqueeze(1), val, torch.zeros_like(val))

    return w00 * sample_zero(x0, y0) + w10 * sample_zero(x1, y0) + w01 * sample_zero(x0, y1) + w11 * sample_zero(x1, y1)



def _point(x, f):
    return x if f == 1 else x[:, :, f // 2::f, f // 2::f]


def _upb(x, H, W, scale=1.0):
    return F.interpolate(x, size=(H, W), mode="bilinear", align_corners=False) * scale


def _oneside(c, w, offa, oobm):
    w2 = w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6)
    mo = (w2[:, :, None] * c[:, :2]).sum(1)
    return torch.where(offa > 0.5, c[:, 1], torch.where(oobm > 0.5, c[:, 0], mo))


def _luma_grad(img):
    l = (img * torch.tensor([.299, .587, .114], device=img.device).view(1, 3, 1, 1)).sum(1, keepdim=True)
    return F.pad((l[..., :, 2:] - l[..., :, :-2]).abs(), (1, 1, 0, 0)) + F.pad((l[..., 2:, :] - l[..., :-2, :]).abs(), (0, 0, 1, 1))


class GenExecutor(MG.Executor):
    """mlof2_graph.Executor + the generation ops. fc: dict t, has_prev, pair_first, vp_a, vp_b, inv_vp_a."""
    def __init__(self, g, H, W, fc, device="cuda", quant=None, store=None):
        super().__init__(g, H, W, device, quant, store=store)
        self.fc = fc
        self.vsums = None

    def op(self, i, o):
        if o["kind"] in ("prep_c", "prep_f", "blend_prep", "carry", "cam_inv", "final") + FUSED3:
            return self.fused(o, [self.get(r) for r in o["ins"]])
        if o["kind"] in STRUCT4:
            return self.struct4(o, [self.get(r) for r in o["ins"]])
        return self.op1(i, o, [self.get(r) for r in o["ins"]])

    def fused(self, o, ins):
        """The fused kinds = compositions of the single kinds (op1): one definition of the semantics."""
        k, t = o["kind"], float(self.fc["t"])
        one = lambda kind, xs, **kw: self.op1(None, {"kind": kind, **kw}, xs)
        if k == "prep_c":
            ca, cb, vg = ins
            z = torch.zeros_like(ca[:, :1])
            return torch.cat((one("vig_apply", [ca, vg], mode=0), z, one("vig_apply", [cb, vg], mode=0), z), 1)
        if k == "prep_f":
            mv, mvv, mv_ap, of, of_prev = ins
            return torch.cat((mv * mvv, mv + M.warp(mv_ap, mv), of + M.warp(of_prev, of)), 1)
        if k == "blend_prep":
            lg, cand, oa_, ob_ = ins
            lgf = F.interpolate(lg, size=(self.H, self.W), mode="bilinear", align_corners=False)
            sb = one("softmax_blend", [lgf, cand])
            return torch.cat((sb, one("rule_prep", [cand, sb[:, 3:7], oa_, ob_])), 1)
        if k == "carry":
            m1, ma, mv_ap, pm = ins
            return one("rule_carry", [m1, M.warp(pm, ma + (1 - t) * M.warp(mv_ap, ma))])
        if k == "cam_inv":
            ndc, dep = ins
            return one("invert_t", [one("cam_flow", [ndc]), dep], t_mode=1, accel=0)
        if k == "final":
            mo, colb, m, i2, ca, oobm, vg = ins
            col = one("blend_mask", [mo, colb, m])
            return one("vig_apply", [one("trail_sel", [col, M.warp(ca, i2[:, 2:4]), i2, oobm]), vg], mode=1)
        fz = lambda kind, xs: self.fused({"kind": kind}, xs)
        cand = lambda pf, inv: self.op1(None, {"kind": "warp_noise4"}, [pf[:, 0:3], pf[:, 3:6], inv[:, 0:6], inv[:, 6:12]])
        if k == "prep":
            ca, cb, vg, mv, mvv, mv_ap, of, of_prev = ins
            return torch.cat((fz("prep_c", [ca, cb, vg]), fz("prep_f", [mv, mvv, mv_ap, of, of_prev])), 1)
        if k == "inv3":
            pf, dep_b, mvv, of, ndc, dep_a = ins
            return torch.cat((one("invert_t", [pf[:, 6:8], dep_b, pf[:, 8:10], mvv], t_mode=0, accel=1),
                              one("invert_t", [of, dep_b, pf[:, 10:12]], t_mode=0, accel=1), fz("cam_inv", [ndc, dep_a])), 1)
        if k == "feat4c":
            pf, inv, da, db, co = ins
            x = feat28(cand(pf, inv), da, db, inv[:, 0:6], inv[:, 6:12], co, t)
            return F.interpolate(x, size=(self.H // 4, self.W // 4), mode="area")
        if k == "blend9":
            lg, pf, inv = ins
            bp = fz("blend_prep", [lg, cand(pf, inv), off_frame(inv[:, 0:2]), inv[:, 5:6]])
            return torch.cat((bp[:, 0:3], bp[:, 7:13]), 1)
        if k == "final3":
            bp, m, inv, pf, vg = ins
            return fz("final", [bp[:, 3:6], bp[:, 0:3], m, inv[:, 12:18], pf[:, 0:3], inv[:, 5:6], vg])
        raise ValueError(k)

    def struct4(self, o, ins):
        k, t, fc = o["kind"], float(self.fc["t"]), self.fc
        H, W, dev = self.H, self.W, self.dev
        one = lambda kind, xs, **kw: self.op1(None, {"kind": kind, **kw}, xs)
        if k == "prep_h":
            mv, mvv, mv_ap, of, of_prev = ins
            of, of_prev = (_upb(x, H, W, W / x.shape[-1]) if x.shape[-2:] != (H, W) else x for x in (of, of_prev))                
            rm = _point if o.get("point", 0) else _area
            if mv.shape[-1] != W:                                                                                           
                h2, w2 = mv.shape[-2:]
                yy, xx = torch.meshgrid(torch.arange(h2, device=dev, dtype=mv.dtype) * 2 + 1,
                                        torch.arange(w2, device=dev, dtype=mv.dtype) * 2 + 1, indexing="ij")
                gx = (xx + mv[:, 0] + 0.5) * (2.0 / W) - 1.0                                                     
                gy = (yy + mv[:, 1] + 0.5) * (2.0 / H) - 1.0
                ap = F.grid_sample(mv_ap, torch.stack((gx, gy), -1), mode="bilinear", padding_mode="zeros", align_corners=False)
                return torch.cat((mv * mvv / 2, (mv + ap) / 2, _area(of, 2) / 2,
                                  _area(of + M.warp(of_prev, of), 2) / 2, (mvv > 0.5).float()), 1)
            return torch.cat((rm(mv * mvv, 2) / 2, rm(mv + M.warp(mv_ap, mv), 2) / 2, _area(of, 2) / 2,
                              _area(of + M.warp(of_prev, of), 2) / 2, (rm(mvv, 2) > 0.5).float()), 1)
        if k == "q_prep":
            cab, da, db, mv_ap = ins
            rd = _point if o.get("point", 0) else _area
            if o.get("point", 0) and GEN_PHASE:                                                       
                rd = lambda x, f: x[:, :, 1::f, 1::f]
            rdl = lambda x: x if x.shape[-1] != W else rd(x, 4)                                          
            return torch.cat((_area(cab, 4), rdl(da), rdl(db), rd(mv_ap, 4) / 4), 1)
        if k == "q_cand":
            qp, im, io_ = ins
            h, w = qp.shape[-2:]
            fl = [_area(x, 2) / 2 for x in (im[:, 0:2], im[:, 2:4], io_[:, 0:2], io_[:, 2:4])]
            fg = [(_area(x, 2) > 0.5).float() for x in (im[:, 4:5], io_[:, 4:5], im[:, 5:6], io_[:, 5:6])]
            warp_fn = (lambda s, f: warp_hw(s, f, 8)) if o.get("hw_bil", 0) else M.warp
            cs = [torch.where(off_frame(f_) > 0.5, hash_noise(1, 3, h, w, i, dev), warp_fn(src, f_))
                  for i, (src, f_) in enumerate(((qp[:, 0:3], fl[0]), (qp[:, 4:7], fl[1]), (qp[:, 0:3], fl[2]), (qp[:, 4:7], fl[3])))]
            return torch.cat(cs + fl + fg, 1)
        if k == "q_feat":
            qc, qp, co = ins
            c = qc[:, 0:12].view(1, 4, 3, *qc.shape[-2:])
            ma, mb, oa, ob = qc[:, 12:14], qc[:, 14:16], qc[:, 16:18], qc[:, 18:20]
            da, db = qp[:, 8:9], qp[:, 9:10]
            hmv, hof, omv, oof = qc[:, 20:21], qc[:, 21:22], qc[:, 22:23], qc[:, 23:24]
            ad = lambda a, b: (a - b).abs().mean(1, keepdim=True)
            x12, x13 = M.warp(da, ma), M.warp(db, mb)
            return torch.cat((qc[:, 0:12], x12, x13, hmv, hof, torch.full_like(x12, t), ad(c[:, 0], c[:, 1]) * 4, ad(c[:, 2], c[:, 3]) * 4,
                              ((ma - oa).norm(dim=1, keepdim=True) * 4 / 16.0).clamp(max=4.0), torch.sigmoid(M.warp(co, ob)),
                              ((x12 - x13).abs() * 16).clamp(max=4.0), ((M.warp(da, oa) - M.warp(db, ob)).abs() * 16).clamp(max=4.0),
                              off_frame(ma), omv, off_frame(oa), oof), 1)
        if k == "q_rule1":
            lg, qc = ins
            c = qc[:, 0:12].view(1, 4, 3, *qc.shape[-2:])
            ma, omv = qc[:, 12:14], qc[:, 22:23]
            offa = off_frame(ma)
            mo = _oneside(c, lg.softmax(1), offa, omv)
            one_ = ((offa + omv) > 0.5).float()
            dmv = (c[:, 0] - c[:, 1]).abs().mean(1, keepdim=True) * (1 - F.max_pool2d(one_, 3, 1, 1))
            return torch.cat((dmv, (c[:, 2] - c[:, 3]).abs().mean(1, keepdim=True), _luma_grad(mo)), 1)
        if k == "q_rule2":
            r1, med, qc, qp, pm = ins
            kk = r1[:, 2:3] + float(med.flatten()[0]) + 1e-3
            m = F.max_pool2d(torch.sigmoid((r1[:, 0:1] - r1[:, 1:2] - 0.5 * kk) / (0.25 * kk)), 3, 1, 1)
            if fc["has_prev"]:
                ma = qc[:, 12:14]
                m = torch.maximum(m, 0.6 * M.warp(pm, ma + (1 - t) * M.warp(qp[:, 10:12], ma)))
            if o.get("bf"):
                bm, bw = o["bf"][:2]
                bf = F.max_pool2d(torch.sigmoid((torch.minimum(r1[:, 0:1], r1[:, 1:2]) - bm * kk) / (bw * kk)), 3, 1, 1)
                be = o["bf"][2] if len(o["bf"]) > 2 else 0.0
                if be > 0:                                                                                                      
                    ma = qc[:, 12:14]
                    gx = F.pad((ma[..., :, 1:] - ma[..., :, :-1]).norm(dim=1, keepdim=True), (0, 1, 0, 0))
                    gy = F.pad((ma[..., 1:, :] - ma[..., :-1, :]).norm(dim=1, keepdim=True), (0, 0, 0, 1))
                    ex = F.max_pool2d((torch.maximum(gx, gy) > be).float(), 9, 1, 4)
                    reach = o["bf"][3] if len(o["bf"]) > 3 else 0.0
                    if reach > 0:                                                                                                 
                        Hq, Wq = ma.shape[-2:]
                        for r in (2, 3, 4, 6, 8, 12, 16, 24, 32):
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                                sx, sy = dx * r, dy * r
                                if abs(sx) >= Wq or abs(sy) >= Hq:
                                    continue
                                sh_ = torch.full_like(ma, float("nan"))
                                ys, yd = (slice(sy, None), slice(0, Hq - sy)) if sy >= 0 else (slice(0, Hq + sy), slice(-sy, None))
                                xs, xd = (slice(sx, None), slice(0, Wq - sx)) if sx >= 0 else (slice(0, Wq + sx), slice(-sx, None))
                                sh_[..., yd, xd] = ma[..., ys, xs]
                                dd = (sh_ - ma).norm(dim=1, keepdim=True)
                                ex = torch.maximum(ex, (dd > max(be, reach * r)).float())                           
                    bf = torch.where(bf > 0.05, bf * (1 - ex), bf)                                                    
                return torch.cat((m, bf), 1)
            return m
        if k == "cam_inv_q":
            nd = ins[0] if ins[0].shape[-1] != W else ins[0][..., GEN_PHASE::4, GEN_PHASE::4]                               
            full_cam = one("invert_t", [cam_flow(nd, fc["vp_a"], fc["vp_b"], fc["inv_vp_a"], t), nd], t_mode=1, accel=0)
            return full_cam[:, 2:5]
        if k == "homog_acc":
            qc, ic = ins[0], ins[1]
            h_prev = ins[2] if len(ins) >= 3 else None
            _, _, Hq, Wq = qc.shape
            N = Hq * Wq
            N_wg = (N + 63) // 64
            out = torch.zeros((1, 109, Hq // 8, Wq // 8), dtype=torch.float32, device=dev)

            oob_mv = (qc[:, 22:23] > 0.5)
            hole_mv = (qc[:, 20:21] > 0.5)
            mv = qc[:, 12:14] * 4.0
            cam = ic[:, 0:2] * 4.0
            W_full, H_full = float(Wq * 4), float(Hq * 4)

            band = oob_mv.float()
            ring_2d = (F.max_pool2d(band, 25, 1, 12) > 0.5) & ~oob_mv & ~hole_mv & (off_frame(mv) < 0.5)

            diff = (cam - mv).norm(dim=1, keepdim=True)
            gy, gx = torch.meshgrid(torch.arange(Hq, device=dev, dtype=torch.float32),
                                    torch.arange(Wq, device=dev, dtype=torch.float32), indexing="ij")
            X = (gx * 4.0 + 2.0 - 0.5 * W_full) / W_full
            Y = (gy * 4.0 + 2.0 - 0.5 * H_full) / W_full
            U = X + mv[0, 0] / W_full
            V = Y + mv[0, 1] / W_full

            w = torch.ones_like(X)
            if h_prev is not None:
                H_mat = torch.eye(3, dtype=torch.float32, device=dev)
                H_mat[0, 0] = h_prev[0, 0, 0, 0]; H_mat[0, 1] = h_prev[0, 1, 0, 0]; H_mat[0, 2] = h_prev[0, 2, 0, 0]
                H_mat[1, 0] = h_prev[0, 3, 0, 0]; H_mat[1, 1] = h_prev[0, 4, 0, 0]; H_mat[1, 2] = h_prev[0, 5, 0, 0]
                H_mat[2, 0] = h_prev[0, 6, 0, 0]; H_mat[2, 1] = h_prev[0, 7, 0, 0]; H_mat[2, 2] = 1.0
                P = torch.stack((X, Y, torch.ones_like(X)), 0).view(3, -1)
                Q = H_mat @ P
                Q = Q[:2] / Q[2:].clamp_min(1e-7)
                res_px = (Q.view(2, Hq, Wq) - torch.stack((U, V), 0)).norm(dim=0) * W_full
                w = torch.where(res_px < 3.0, torch.ones_like(res_px), (3.0 / res_px).sqrt())

            ring_flat = ring_2d[0, 0].view(-1)
            diff_flat = diff[0, 0].view(-1)
            X_f, Y_f, U_f, V_f, w_f = X.view(-1), Y.view(-1), U.view(-1), V.view(-1), w.view(-1)
            for g in range(N_wg):
                p0 = g * 64
                p1 = min(p0 + 64, N)
                m_g = ring_flat[p0:p1]
                if not m_g.any(): continue
                idx_sel = torch.nonzero(m_g).squeeze(1) + p0
                X_s, Y_s, U_s, V_s, w_s = X_f[idx_sel], Y_f[idx_sel], U_f[idx_sel], V_f[idx_sel], w_f[idx_sel]

                o_s = torch.ones_like(X_s)
                z_s = torch.zeros_like(X_s)
                r1 = torch.stack((X_s, Y_s, o_s, z_s, z_s, z_s, -U_s * X_s, -U_s * Y_s), 1)
                r2 = torch.stack((z_s, z_s, z_s, X_s, Y_s, o_s, -V_s * X_s, -V_s * Y_s), 1)

                gw = Wq // 8
                gy, gx = g // gw, g % gw
                c_idx = 0
                for i in range(8):
                    for j in range(i, 8):
                        term = (w_s * (r1[:, i] * r1[:, j] + r2[:, i] * r2[:, j])).sum()
                        out[0, c_idx, gy, gx] = term
                        c_idx += 1
                for i in range(8):
                    term = (w_s * (r1[:, i] * U_s + r2[:, i] * V_s)).sum()
                    out[0, 36 + i, gy, gx] = term
                out[0, 44, gy, gx] = float(m_g.sum())

                b_s = diff_flat[idx_sel].long().clamp(0, 63)
                for b in b_s:
                    out[0, 45 + b, gy, gx] += 1.0
            return out

        if k == "homog_solve":
            h_acc = ins[0]
            tot = h_acc.sum(dim=(2, 3))[0]
            out = torch.zeros((1, 16, 1, 1), dtype=torch.float32, device=dev)
            n_pts = float(tot[44])
            hist = tot[45:109]

            half_pts = int(n_pts * 0.5)
            cum = 0
            med_diff = 0.0
            for b in range(64):
                cum += int(hist[b].item())
                if cum >= half_pts and half_pts > 0:
                    med_diff = float(b) + 0.5
                    break

            trail_auto = float(fc.get("trail_homog_auto", os.environ.get("TRAIL_HOMOG_AUTO", "10")))
            force_homog = float(fc.get("force_homog", os.environ.get("FORCE_HOMOG", "0"))) > 0.5
            use_homog = (n_pts >= 32.0) and (force_homog or (med_diff > trail_auto))

            M_mat = torch.zeros((8, 8), dtype=torch.float64, device=dev)
            b_vec = tot[36:44].double()
            idx = 0
            trace_A = 0.0
            for i in range(8):
                for j in range(i, 8):
                    val = float(tot[idx])
                    M_mat[i, j] = val
                    M_mat[j, i] = val
                    if i == j: trace_A += val
                    idx += 1
            lambda_reg = max(1e-6 * (trace_A / 8.0), 1e-9)
            M_mat += lambda_reg * torch.eye(8, dtype=torch.float64, device=dev)

            try:
                h_sol = torch.linalg.solve(M_mat, b_vec)
                for i in range(8):
                    out[0, i, 0, 0] = float(h_sol[i])
            except Exception:
                use_homog = False

            out[0, 8, 0, 0] = 1.0
            out[0, 9, 0, 0] = 1.0 if use_homog else 0.0
            out[0, 10, 0, 0] = med_diff
            out[0, 11, 0, 0] = n_pts
            return out

        if k == "final4":
            cab, im, io_, lg, m, ic, vg = ins[:7]
            ho = ins[7] if len(ins) >= 8 else None
            fl = [_upb(x, H, W, 2.0) for x in (im[:, 0:2], im[:, 2:4], io_[:, 0:2], io_[:, 2:4])]
            oobm = (_upb(im[:, 5:6], H, W) > 0.5).float()
            ca, cb = cab[:, 0:3], cab[:, 4:7]
            warp_fn = (lambda s, f: warp_hw(s, f, 8)) if o.get("hw_bil", 0) else M.warp
            cand = torch.stack([torch.where(off_frame(f_) > 0.5, hash_noise(1, 3, H, W, i, dev), warp_fn(src, f_))
                                for i, (src, f_) in enumerate(((ca, fl[0]), (cb, fl[1]), (ca, fl[2]), (cb, fl[3])))], 1)
            w = _upb(lg, H, W).softmax(1)
            colr = (w[:, :, None] * cand).sum(1).clamp(0, 1)
            mm = _upb(m[:, 0:1], H, W)
            col = (1 - mm) * _oneside(cand, w, off_frame(fl[0]), oobm) + mm * colr
            if m.shape[1] > 1:                                                                                        
                bfu = _upb(m[:, 1:2], H, W)
                near = cand[:, 0] if t <= 0.5 else cand[:, 1]
                near = torch.where(off_frame(fl[0]) > 0.5, cand[:, 1], torch.where(oobm > 0.5, cand[:, 0], near))
                if GEN_BF_PICK.startswith("argmax") or o.get("pick", 0) == 1:
                                                                                                                      
                                                                                                         
                    offs = torch.cat([off_frame(f_) for f_ in fl], 1) > 0.5
                    wi = torch.where(offs, torch.full_like(w, -1.0), w)
                    pick = cand.gather(1, wi.argmax(1, keepdim=True)[:, :, None].expand(-1, 1, 3, -1, -1))[:, 0]
                    keep = (off_frame(fl[0]) > 0.5) | (oobm > 0.5) | offs.all(1, keepdim=True)
                    near = torch.where(keep, near, pick)
                if GEN_BF_PICK.endswith("_edge"):
                                                                                                                     
                    f0 = fl[0]
                    gx = F.pad((f0[..., :, 1:] - f0[..., :, :-1]).norm(dim=1, keepdim=True), (0, 1, 0, 0))
                    gy = F.pad((f0[..., 1:, :] - f0[..., :-1, :]).norm(dim=1, keepdim=True), (0, 0, 0, 1))
                    edge = (torch.maximum(gx, gy) > GEN_BF_EDGE).float()
                    bfu = bfu * (1 - F.max_pool2d(edge, 33, 1, 16))
                col = col + bfu * (near - col)

            use_homog = (ho is not None) and (float(ho[0, 9, 0, 0]) > 0.5)
            if use_homog:
                H_mat = torch.eye(3, dtype=torch.float32, device=dev)
                H_mat[0, 0] = ho[0, 0, 0, 0]; H_mat[0, 1] = ho[0, 1, 0, 0]; H_mat[0, 2] = ho[0, 2, 0, 0]
                H_mat[1, 0] = ho[0, 3, 0, 0]; H_mat[1, 1] = ho[0, 4, 0, 0]; H_mat[1, 2] = ho[0, 5, 0, 0]
                H_mat[2, 0] = ho[0, 6, 0, 0]; H_mat[2, 1] = ho[0, 7, 0, 0]; H_mat[2, 2] = 1.0
                gy, gx = torch.meshgrid(torch.arange(H, device=dev, dtype=torch.float32),
                                        torch.arange(W, device=dev, dtype=torch.float32), indexing="ij")
                X = (gx + 0.5 - 0.5 * float(W)) / float(W)
                Y = (gy + 0.5 - 0.5 * float(H)) / float(W)
                P = torch.stack((X, Y, torch.ones_like(X)), 0).view(3, -1)
                Q = H_mat @ P
                Q = Q[:2] / Q[2:].clamp_min(1e-7)
                ox_new = Q[0].view(H, W) * float(W) + 0.5 * float(W)
                oy_new = Q[1].view(H, W) * float(W) + 0.5 * float(H)
                to2 = torch.stack((ox_new - gx, oy_new - gy), 0)[None]
                use = (oobm > 0.5) & (off_frame(to2) < 0.5)
                col = torch.where(use, warp_fn(ca, to2), col)
            else:
                to2, hole2 = _upb(ic[:, 0:2], H, W, 4.0), (_upb(ic[:, 2:3], H, W) > 0.5).float()
                use = (oobm > 0.5) & (hole2 < 0.5) & (off_frame(to2) < 0.5)
                col = torch.where(use, warp_fn(ca, to2), col)
            return one("vig_apply", [col, vg], mode=1)
        raise ValueError(k)

    def op1(self, i, o, ins):
        k = o["kind"]
        fc = self.fc
        H, W = self.H, self.W
        if k == "absdiff":
            y = (ins[0] - ins[1]).abs().mean(1, keepdim=True) * o.get("k", 1.0)
            return y.clamp(max=o["hi"]) if o.get("hi", 0.0) > 0 else y
        if k == "vig_part":
            self.vsums = vig_sums(*ins) if fc["pair_first"] else None
            return torch.zeros(self.shape(MG._parse(o["out"])[0]), device=self.dev)
        if k == "vig_solve":
            st = self.get("vig").clone()
            if fc["pair_first"]:
                state = {"ata": st[0, 0:9, 0, 0].double().view(3, 3).clone(), "atb": st[0, 9:12, 0, 0].double().clone()}
                lv = vig_update(state, self.vsums)
                st[0, 0:9, 0, 0] = state["ata"].flatten().float()                                             
                st[0, 9:12, 0, 0] = state["atb"].float()
                st[0, 12:15, 0, 0] = lv.to(st.device)
            return st
        if k == "vig_apply":
            img, vg = ins
            V = vig_map(vg[0, 12:15, 0, 0], H, W, self.dev)
            return img / V if o["mode"] == 0 else (img * V).clamp(0, 1)
        if k == "mul":
            return ins[0] * ins[1]
        if k == "invert_t":
            f, depth = ins[0], ins[1]
            fbp = ins[2] if len(ins) > 2 and o.get("accel") and fc["has_prev"] else None
            valid = ins[3] if len(ins) > 3 else None
            t = torch.tensor([0.0 if o["t_mode"] else float(fc["t"])], device=self.dev)
            a, b_, h, ob = invert_t1(f, depth, t, fbp, valid)
            return torch.cat((a, b_, h, ob), 1)
        if k == "warp_noise":
            src, fl = ins
            return torch.where(off_frame(fl) > 0.5, hash_noise(1, src.shape[1], H, W, o["idx"], self.dev), M.warp(src, fl))
        if k == "off_frame":
            return off_frame(ins[0])
        if k == "flowdist":
            return ((ins[0] - ins[1]).norm(dim=1, keepdim=True) / 16.0).clamp(max=4.0)
        if k == "sigmoid":
            return torch.sigmoid(ins[0])
        if k == "fill_t":
            return torch.full((1, 1, H, W), float(fc["t"]), device=self.dev)
        if k == "up_nearest":
            return F.interpolate(ins[0], scale_factor=2, mode="nearest")
        if k == "softmax_blend":
            lg, cand = ins
            w = lg.softmax(1)
            col = (w[:, :, None] * cand.view(1, 4, 3, H, W)).sum(1).clamp(0, 1)
            return torch.cat((col, w), 1)
        if k == "rule_prep":
            cand, w, oa_, ob_ = ins
            c = cand.view(1, 4, 3, H, W)
            w2 = w[:, :2] / w[:, :2].sum(1, keepdim=True).clamp_min(1e-6)
            mo = (w2[:, :, None] * c[:, :2]).sum(1)
            mo = torch.where(oa_ > 0.5, c[:, 1], torch.where(ob_ > 0.5, c[:, 0], mo))
            return torch.cat((mo, (c[:, 0] - c[:, 1]).abs().mean(1, keepdim=True), (c[:, 2] - c[:, 3]).abs().mean(1, keepdim=True),
                              ((oa_ + ob_) > 0.5).float()), 1)
        if k == "pool":
            kk = o["k"]
            return F.avg_pool2d(ins[0], kk, 1, kk // 2) if o["mode"] == 0 else F.max_pool2d(ins[0], kk, 1, kk // 2)
        if k == "luma_grad":
            l = (ins[0] * torch.tensor([.299, .587, .114], device=self.dev).view(1, 3, 1, 1)).sum(1, keepdim=True)
            return F.pad((l[..., :, 2:] - l[..., :, :-2]).abs(), (1, 1, 0, 0)) + F.pad((l[..., 2:, :] - l[..., :-2, :]).abs(), (0, 0, 1, 1))
        if k == "mask_mul":
            return ins[0] * (1 - ins[1])
        if k == "median":
            return torch.full(self.shape(MG._parse(o["out"])[0]), median_hist(ins[0]), device=self.dev)
        if k == "median_hist":
            return torch.zeros(self.shape(MG._parse(o["out"])[0]), device=self.dev)
        if k == "median_pick":
            return torch.full(self.shape(MG._parse(o["out"])[0]), median_hist(ins[1]), device=self.dev)
        if k == "rule_score":
            dmv, dof, con, med = ins
            kk = con + float(med.flatten()[0]) + 1e-3
            return torch.sigmoid((dmv - dof - 0.5 * kk) / (0.25 * kk))
        if k == "axpy_t":
            return ins[0] + (1 - float(fc["t"])) * ins[1]
        if k == "rule_carry":
            return torch.maximum(ins[0], 0.6 * ins[1]) if fc["has_prev"] else ins[0]
        if k == "blend_mask":
            mo, col, mm = ins
            return (1 - mm) * mo + mm * col
        if k == "cam_flow":
            return cam_flow(ins[0], fc["vp_a"], fc["vp_b"], fc["inv_vp_a"], float(fc["t"]))
        if k == "warp_noise4":
            ca, cb, im, io_ = ins
            return torch.cat([torch.where(off_frame(fl) > 0.5, hash_noise(1, 3, H, W, i, self.dev), M.warp(src, fl))
                              for i, (src, fl) in enumerate(((ca, im[:, 0:2]), (cb, im[:, 2:4]), (ca, io_[:, 0:2]), (cb, io_[:, 2:4])))], 1)
        if k == "feat4":
            x = feat28(*ins, fc["t"])
            return F.interpolate(x, size=(H // 4, W // 4), mode="area")
        if k == "trail_sel":
            col, cav, i2, oobm = ins
            use = (oobm > 0.5) & (i2[:, 4:5] < 0.5) & (off_frame(i2[:, 2:4]) < 0.5)
            return torch.where(use, cav, col)
        return super().op(i, o)
