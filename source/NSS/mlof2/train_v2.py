"""MLOF2 trainer. Design: docs/NFRU_MLOF2_DESIGN_20261015.md.

  python train_v2.py --out runs/v2_a [--steps 60000] [--batch 4] [--smoke 20]

Per step: augment (augment_v2) -> encoder for P, A, B -> previous pair (P, A) without grad for the
acceleration input on half the steps -> pair (A, B) -> head at the sample's t -> losses (losses_v2).
Logged every --log steps (the checks the reviews asked for):
  loss parts; c mean and histogram; c where the MV is known wrong (augmentation) vs elsewhere;
  share of c in (0.3, 0.7) (undecided cells); gradient norm of the pair network (OF + gate trunk).
Validation every --val steps on fixed windows: PSNR of the output, of the A/B average and of A warped by
the game MV, plus c in wrong-MV regions. progress.pt (resume), best.pt, last.pt.
"""
import argparse
import math
import os
import random
import sys
import time
import torch
from torch.nn import functional as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import full_flow, MLOF2, warp, correlation
from losses_v2 import total_loss
from data_v2 import WindowDataset
from augment_v2 import augment, pan_rotate
from of_losses import of_loss, of_loss_tri, tri_inputs, explain_error


def match_loss(fa, fb, b, R=4, tau=0.07):
    """InfoNCE: in B's r=R cosine cost volume against A's features warped by the exact flow, the centre is the true
    match (probe_enc_match.py). Only where the exact flow explains the colours and lands on the frame."""
    g = b["geo_flow_ba"]
    ok = (explain_error(b["color_a"], b["color_b"], g) <= 0.5).float() * \
        (warp(torch.ones_like(g[:, :1]), g) > 0.999).float() * b.get("b_valid", torch.ones_like(g[:, :1]))
    c = (2 * R + 1) ** 2 // 2
    tot = 0.0
    for k in (4, 8):
        lg = correlation(fb[k], warp(fa[k], F.avg_pool2d(g, k) / k), R) / tau
        okk = (F.avg_pool2d(ok, k) > 0.99).float()[:, 0]
        ce = F.cross_entropy(lg, torch.full(lg.shape[:1] + lg.shape[2:], c, device=lg.device, dtype=torch.long), reduction="none")
        tot = tot + (ce * okk).sum() / okk.sum().clamp_min(1)
    return tot / 2


def distill_loss(tfnet, fa, fb, b, R=3, tau=0.07, key=8):
    """Cost-volume distillation (probe_enc_match DISTILL): around geo_flow_ba at 1/8 with +-2 cell jitter, the softmax
    of our r=R cosine cost volume follows the one of SEA-RAFT's matching features (fnet). No flow labels needed."""
    g = F.avg_pool2d(b["geo_flow_ba"], 8) / 8
    g = g + (torch.rand_like(g) * 4 - 2)
    with torch.no_grad():
        ta, tb = tfnet(2 * b["color_a"] - 1).float(), tfnet(2 * b["color_b"] - 1).float()
        pt = torch.softmax(correlation(tb, warp(ta, g), R) / tau, 1)
    ls = torch.log_softmax(correlation(fb[key], warp(fa[key], g), R) / tau, 1)
    return (pt * (torch.log(pt.clamp_min(1e-8)) - ls)).sum(1).mean()


def psnr(x, y):
    return -10 * torch.log10(((x - y) ** 2).mean().clamp_min(1e-10)).item()


def to_dev(b, dev):
    return {k: v.to(dev, non_blocking=True) if torch.is_tensor(v) else v for k, v in b.items()}


def run(model, b, use_prev):
    enc = model.enc
    fa, fb = enc(b["color_a"], b["depth_a"]), enc(b["color_b"], b["depth_b"])
    f_prev = None
    if use_prev:
        with torch.no_grad():
            fp = enc(b["color_p"], b["depth_p"])
            pp = model.pair(fp, fa, b["mv_ap"], torch.ones_like(b["mv_valid"]), b["color_p"], b["color_a"])
            f_prev = pp["f_ba"]                                           
    pair = model.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
    frame = model.head(b["t"], pair, fa[8], fb[8], b["color_a"], b["color_b"], f_prev)
    return frame, pair


def gate_stats(c, wrong):
    """c at 1/8 vs the full-res known-wrong-MV mask."""
    wr = F.interpolate(wrong, size=c.shape[-2:], mode="area") > 0.5
    ok = F.interpolate(wrong, size=c.shape[-2:], mode="area") < 0.01
    hist = torch.histc(c.float(), bins=10, min=0, max=1)
    hist = (hist / hist.sum().clamp_min(1)).tolist()
    mid = ((c > 0.3) & (c < 0.7)).float().mean().item()
    return {"c_mean": c.mean().item(), "c_wrong": c[wr].mean().item() if wr.any() else float("nan"),
            "c_ok": c[ok].mean().item() if ok.any() else float("nan"), "c_mid": mid, "c_hist": hist}


@torch.no_grad()
def of_seed(model, fa, b, drop=0.0, rng=None):
    """Game-MV seed for a seeded OF (model.pair.seeded), else None. drop: chance per call to give a zero seed."""
    if not getattr(model.pair, "seeded", False):
        return None
    v = b["mv_valid"]
    if rng is not None and rng.random() < drop:
        v = torch.zeros_like(v)
    return model.pair.make_seed(b["mv_ba"], v, *fa[16].shape[-2:])


def validate_of(model, loader, dev, n_batches):
    """Clean real windows: PSNR of B vs A, vs A warped by the game MV, vs A warped by the network's own OF
    (in-screen pixels of both flows), per span. The OF stage is done when OF-warp is clearly above no-warp and
    within ~1-2 dB of MV-warp."""
    model.eval()
    res = {}
    for bi, b in enumerate(loader):
        if bi >= n_batches:
            break
        b = to_dev(b, dev)
        fa, fb = model.enc(b["color_a"], b["depth_a"]), model.enc(b["color_b"], b["depth_b"])
        of = full_flow(model.pair.of_forward(fa, fb, b["color_a"], b["color_b"], of_seed(model, fa, b))[4],
                       *b["color_a"].shape[-2:])
        n, _, H, W = b["color_a"].shape
        f = torch.nn.functional.interpolate(of[:n], size=(H, W), mode="bilinear", align_corners=False) * (W / of.shape[-1])
        ones = torch.ones_like(b["color_a"][:, :1])
        for i in range(n):
            m = (warp(ones[i:i+1], f[i:i+1]) > 0.999).float() * (warp(ones[i:i+1], b["mv_ba"][i:i+1]) > 0.999).float()
            def ps(x):
                e = (((x - b["color_b"][i:i+1]) ** 2) * m).sum() / (3 * m.sum()).clamp_min(1)
                return -10 * torch.log10(e + 1e-10).item()
            k = int(b["span"][i])
            res.setdefault(k, []).append((ps(b["color_a"][i:i+1]), ps(warp(b["color_a"][i:i+1], b["mv_ba"][i:i+1])),
                                          ps(warp(b["color_a"][i:i+1], f[i:i+1]))))
    model.train()
    out = {k: [sum(x[j] for x in v) / len(v) for j in range(3)] for k, v in sorted(res.items())}
    gain = sum(v[2] - v[0] for v in out.values()) / max(1, len(out))                                              
    return out, gain


@torch.no_grad()
def validate_epe(model, loader, dev, n_batches, bins=(0, 8, 32, 64, 128, 256, 1e9)):
    """Exact-GT windows (Spring): median end-point error of the network's OF vs geo_flow_ba (display px) per |GT| bin,
    with no seed (pure OF; the score) and with the game-MV seed (on Spring the seed IS the GT, so only a sanity line).
    Pixels: GT explains B (explain_error <= 0.5) and both flows stay on screen."""
    from losses_v2 import explain_error
    model.eval()
    res = {"none": {}, "seed": {}}
    for bi, b in enumerate(loader):
        if bi >= n_batches:
            break
        b = to_dev(b, dev)
        fa, fb = model.enc(b["color_a"], b["depth_a"]), model.enc(b["color_b"], b["depth_b"])
        n, _, H, W = b["color_a"].shape
        gt = b["geo_flow_ba"]
        ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5).float()
        ones = torch.ones_like(b["color_a"][:, :1])
        for mode in ("none", "seed"):
            seed = None
            if getattr(model.pair, "seeded", False):
                v = b["mv_valid"] if mode == "seed" else torch.zeros_like(b["mv_valid"])
                seed = model.pair.make_seed(b["mv_ba"], v, *fa[16].shape[-2:])
            elif mode == "seed":
                continue
            of = full_flow(model.pair.of_forward(fa, fb, b["color_a"], b["color_b"], seed)[4], H, W)[:n]
            f = F.interpolate(of, size=(H, W), mode="bilinear", align_corners=False) * (W / of.shape[-1])
            e = (f - gt).norm(dim=1); g = gt.norm(dim=1)
            m = (ok * (warp(ones, gt) > 0.999).float())[:, 0] > 0.5
            for i in range(len(bins) - 1):
                s_ = m & (g >= bins[i]) & (g < bins[i + 1])
                if s_.sum() > 2000:
                    res[mode].setdefault(i, []).append((e[s_].median().item(), (f.norm(dim=1)[s_].median() / g[s_].median().clamp_min(1e-3)).item()))
    model.train()
    out = {mode: {i: (sum(x[0] for x in v) / len(v), sum(x[1] for x in v) / len(v), len(v)) for i, v in sorted(r.items())}
           for mode, r in res.items()}
    return out, bins


@torch.no_grad()
def validate(model, loader, dev, n_batches):
    model.eval()
    acc = {"clean": [], "clean_blend": [], "out": [], "blend": [], "mvwarp": [], "c_wrong": [], "c_ok": []}
    rng = random.Random(1234)
    for bi, b in enumerate(loader):
        if bi >= n_batches:
            break
        b = to_dev(b, dev)
        frame, _ = run(model, b, use_prev=True)                                         
        acc["clean"].append(psnr(frame["color"], b["color_g"]))
        acc["clean_blend"].append(psnr(0.5 * (b["color_a"] + b["color_b"]), b["color_g"]))
        masks = augment(b, rng)                                                                          
        frame, pair = run(model, b, use_prev=True)
        g = b["color_g"]
        acc["out"].append(psnr(frame["color"], g))
        acc["blend"].append(psnr(0.5 * (b["color_a"] + b["color_b"]), g))
        t = b["t"].view(-1, 1, 1, 1)
        acc["mvwarp"].append(psnr(warp(b["color_a"], b["mv_ba"] * t), g))                              
        s = gate_stats(pair["gate"][: g.shape[0]], masks["mv_wrong"])
        acc["c_wrong"].append(s["c_wrong"])
        acc["c_ok"].append(s["c_ok"])
    model.train()
    m = lambda v: sum(x for x in v if x == x) / max(1, sum(1 for x in v if x == x))
    return {k: m(v) for k, v in acc.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=60000)
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--crop", type=int, default=448)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--workers", type=int, default=10)
    ap.add_argument("--log", type=int, default=50)
    ap.add_argument("--val", type=int, default=2000)
    ap.add_argument("--val_batches", type=int, default=40)
    ap.add_argument("--smoke", type=int, default=0, help="run N steps, print timing/memory, no checkpoints")
    ap.add_argument("--init", default="", help="warm start: model weights; tensors whose shape changed stay new")
    ap.add_argument("--p_pan", type=float, default=0.5, help="share of steps with a large fast camera turn")
    ap.add_argument("--pan_sizes", default="640,896,1088")
    ap.add_argument("--strides", default="", help="OF stage: windows of 3/4/5 real frames every s-th frame, e.g. 1,2,3,4")
    ap.add_argument("--tri", type=int, default=0, help="OF stage on (A,B), (A,G), (G,B) + chain loss (needs --strides)")
    ap.add_argument("--clip", type=float, default=2.0, help="global grad-norm clip")
    ap.add_argument("--mv_res", type=int, default=0, help="game-MV render-scale augmentation (data_v2.resample_mv)")
    ap.add_argument("--seeded", type=int, default=0, help="OF coarsest level with zero + game-MV seed hypotheses")
    ap.add_argument("--seed_drop", type=float, default=0.15, help="seeded OF stage: share of steps with no MV seed")
    ap.add_argument("--gm", type=int, default=0, help="1/32 global matching instead of the 1/64 OF level")
    ap.add_argument("--teacher", type=int, default=0, help="OF stage: SEA-RAFT teacher flows as targets (teach/tms weights)")
    ap.add_argument("--spring_of_w", default="", help="OF-stage loss weights on Spring batches only (exact GT), over --of_w")
    ap.add_argument("--of_w", default="", help="OF-stage loss weights, e.g. census=0,smooth=0 (of_losses.OF_W)")
    ap.add_argument("--spring", type=float, default=0.0, help="OF stage: share of steps on a Spring batch (exact GT flow, 1080p)")
    ap.add_argument("--spring_crop", default="1024,1920", help="Spring crop h,w (multiples of 64)")
    ap.add_argument("--spring_batch", type=int, default=2)
    ap.add_argument("--spring_strides", default="1,2,4,8,12")
    ap.add_argument("--spring_seed_drop", type=float, default=0.5, help="Spring MV seed = exact GT: drop it more often")
    ap.add_argument("--convex_up", type=int, default=0, help="OF: learned convex level-to-level upsampling (starts = bilinear)")
    ap.add_argument("--pm_sel", type=int, default=0, help="OF: PatchMatch-style candidate selection at full res")
    ap.add_argument("--prop4", type=int, default=0, help="OF: edge-aware propagation of the final 1/4 flow (starts ~identity)")
    ap.add_argument("--up_full", type=int, default=0, help="OF: learned convex x4 1/4 -> full res (starts = bilinear)")
    ap.add_argument("--deep16", type=int, default=0, help="OF: wide-context DeepRefine block after the 1/16 level")
    ap.add_argument("--enc_deep", type=int, default=0, help="OF encoder: residual block after the 1/4 and 1/8 maps")
    ap.add_argument("--match_w", type=float, default=0.0,
                    help="Spring batches: InfoNCE on the r=4 cosine cost volume at the exact match, 1/4 and 1/8")
    ap.add_argument("--enc_fpn", type=int, default=0, help="OF encoder: top-down 1/16 -> 1/8 -> 1/4 context (FrameEncoder fpn)")
    ap.add_argument("--enc_init", default="", help="encoder weights from probe_enc_match ({'enc_wide': ...}), after --init")
    ap.add_argument("--distill_w", type=float, default=0.0,
                    help="OF stage: KL of the 1/8 r=3 cost-volume softmax to SEA-RAFT fnet's around geo_flow_ba +-2 (all batches)")
    ap.add_argument("--recur8", type=int, default=0, help="OF: RAFT-style recurrent refinement after the 1/8 level, N iters")
    ap.add_argument("--recur8_teacher", type=int, default=0, help="EXPERIMENT: recur8 correlations on SEA-RAFT features")
    ap.add_argument("--seq_w", type=float, default=0.0,
                    help="recur8: per-iteration L1 to the exact flow at 1/8 on Spring batches, weights 0.8^(K-1-i)")
    ap.add_argument("--warmup", type=int, default=1000, help="lr warm-up steps")
    ap.add_argument("--enc_match", type=int, default=0, help="OF encoder: MatchEncoder branch for the recurrent 1/8 block")
    ap.add_argument("--enc_match_ctx", type=int, default=0, help="MatchEncoder with 1/16 context + dilated residual")
    ap.add_argument("--menc_init", default="", help="MatchEncoder weights from probe_enc_match match ({'menc': ...})")
    ap.add_argument("--distill_key", default="8", help="distillation on the 1/8 map '8' or the MatchEncoder map 'm8'")
    ap.add_argument("--train_only", default="", help="comma list of parameter-name prefixes to train (others frozen)")
    ap.add_argument("--of_widths", default="", help="OF Update widths 1/64,1/32,1/16,1/8,1/4 (default 256,128,96,48,32)")
    ap.add_argument("--fine_iters", type=int, default=1, help="OF: 1/8 and 1/4 levels run their Update this many times")
    ap.add_argument("--stage", default="full", choices=["full", "of"], help="of = pre-train the pure OF network only")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    dev = "cuda"
    torch.manual_seed(0)
    rng = random.Random(0)
    names = ["forest15", "lyra15", "lyra17"]
    strides = tuple(int(x) for x in args.strides.split(",") if x) or None
    assert not args.tri or (strides and args.p_pan == 0), "--tri needs --strides and --p_pan 0"
                                                                                                                        
    of_drop = (("color_p", "depth_p", "mv_ap", "color_g") + (() if args.seeded else ("mv_ba",))
               if args.stage == "of" and not args.tri else ())
    train = WindowDataset(names, "train", crop=args.crop, strides=strides, tri=bool(args.tri), mv_res=bool(args.mv_res))
    val = WindowDataset(names, "validation", crop=args.crop, windows_per_file=8)
    tl = torch.utils.data.DataLoader(train, batch_size=args.batch, shuffle=True, num_workers=args.workers,
                                     drop_last=True, persistent_workers=True, pin_memory=True)
    vl = torch.utils.data.DataLoader(val, batch_size=args.batch, shuffle=False, num_workers=2)
    vl_big = None
    if strides:                                                                       
        vb = WindowDataset(names, "validation", crop=args.crop, windows_per_file=8, strides=strides, seed=7)
        vl_big = torch.utils.data.DataLoader(vb, batch_size=args.batch, shuffle=False, num_workers=2)
    sl = sl_val = None
    if args.spring > 0:
        assert args.stage == "of" and not args.tri, "--spring is wired for the plain OF stage"
        sc = tuple(int(x) for x in args.spring_crop.split(","))
        ss = tuple(int(x) for x in args.spring_strides.split(","))
        st = WindowDataset(["spring"], "train", crop=sc, strides=ss, mv_res=bool(args.mv_res), drop=of_drop)
        sl = torch.utils.data.DataLoader(st, batch_size=args.spring_batch, shuffle=True, num_workers=3, prefetch_factor=2,
                                         drop_last=True, persistent_workers=True, pin_memory=True)
        sv = WindowDataset(["spring"], "validation", crop=sc, windows_per_file=16, strides=ss, seed=7)
        sl_val = torch.utils.data.DataLoader(sv, batch_size=args.spring_batch, shuffle=False, num_workers=2)
        print(f"spring: train windows {len(st)} ({len(st.files)} files), val windows {len(sv)}", flush=True)
    model = MLOF2(enc_deep=bool(args.enc_deep), enc_fpn=bool(args.enc_fpn), recur8=args.recur8,
                  recur8_teacher=bool(args.recur8_teacher), enc_match=bool(args.enc_match),
                  enc_match_ctx=bool(args.enc_match_ctx), of_widths=[int(x) for x in args.of_widths.split(",")] if args.of_widths else None,
                  fine_iters=args.fine_iters, global_match=bool(args.gm), convex_up=bool(args.convex_up), deep16=bool(args.deep16),
                  up_full=bool(args.up_full), prop4=bool(args.prop4), pm_sel=bool(args.pm_sel)).to(dev)
    model.pair.seeded = bool(args.seeded)
    if args.train_only:
        pre = tuple(x for x in args.train_only.split(",") if x)
        for nm, p in model.named_parameters():
            p.requires_grad_(nm.startswith(pre))
        print("trainable:", sum(p.numel() for p in model.parameters() if p.requires_grad), "params in",
              sorted({".".join(nm.split(".")[:3]) for nm, p in model.named_parameters() if p.requires_grad}), flush=True)
    opt = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=args.lr, weight_decay=1e-4)
    sched = lambda s: 0.5 * (1 + math.cos(math.pi * min(s, args.steps) / args.steps)) * min(1.0, s / args.warmup)
    step, best = 0, -1e9
    prog = os.path.join(args.out, "progress.pt")
    if os.path.exists(prog) and not args.smoke:
        ck = torch.load(prog, map_location=dev)
        model.load_state_dict(ck["model"]); opt.load_state_dict(ck["opt"])
        step, best = ck["step"], ck["best"]
                                                                                                              
                                                                                            
        torch.manual_seed(step); rng = random.Random(step)
    elif args.init:
        sd = torch.load(args.init, map_location=dev)
        sd = sd.get("model", sd)
        own = model.state_dict()
        keep = {k: v for k, v in sd.items() if k in own and own[k].shape == v.shape}
        for k, v in sd.items():                                                                                    
            if k in own and k not in keep and own[k].dim() == v.dim() and own[k].shape[1:] == v.shape[1:] \
                    and own[k].shape[0] > v.shape[0]:
                t = own[k].clone(); t[: v.shape[0]] = v; keep[k] = t
            elif k in own and k not in keep and own[k].dim() == v.dim() == 4 and own[k].shape[2:] == v.shape[2:] \
                    and own[k].shape[0] >= v.shape[0] and own[k].shape[1] >= v.shape[1]:
                                                                                                                   
                                                                                                             
                t = own[k].clone(); t[: v.shape[0]] = 0; t[: v.shape[0], : v.shape[1]] = v; keep[k] = t
        for k, v in sd.items():                                   
            if k in own and k not in keep and own[k].dim() == v.dim() == 1 and own[k].shape[0] > v.shape[0]:
                t = own[k].clone(); t[: v.shape[0]] = v; keep[k] = t
        skipped = [k for k in own if k not in keep]
        model.load_state_dict(keep, strict=False)
        print(f"warm start from {args.init}: {len(keep)} tensors loaded, new: {skipped}", flush=True)
        if args.enc_init:
            e = torch.load(args.enc_init, map_location=dev)
            e = e.get("enc_wide", e)
            model.enc.load_state_dict(e)
            print(f"encoder from {args.enc_init}: {len(e)} tensors", flush=True)
        if args.menc_init:
            model.enc.menc.load_state_dict(torch.load(args.menc_init, map_location=dev)["menc"])
            print(f"match encoder from {args.menc_init}", flush=True)
    teacher = None
    if args.teacher:
        from teacher_searaft import SeaRaftTeacher
        teacher = SeaRaftTeacher(dev)
        assert args.tri, "--teacher is wired for --tri"
    tfnet = None
    if args.distill_w > 0:
        from teacher_searaft import SeaRaftTeacher
        tfnet = (teacher or SeaRaftTeacher(dev)).model.fnet
    pan_sizes = [int(x) for x in args.pan_sizes.split(",")]
    ofw = {k: float(v) for k, v in (kv.split("=") for kv in args.of_w.split(",") if kv)}
    ofw_s = dict(ofw, **{k: float(v) for k, v in (kv.split("=") for kv in args.spring_of_w.split(",") if kv)})
    log = open(os.path.join(args.out, "log.txt"), "a")

    def say(s):
        print(s, flush=True)
        log.write(s + "\n"); log.flush()

    say(f"start step {step} params {sum(p.numel() for p in model.parameters())/1e6:.2f}M "
        f"train windows {len(train)} val windows {len(val)}")
    t0, tdata, acc = time.time(), 0.0, {}
    it = iter(tl)
    its = iter(sl) if sl is not None else None
    while step < (args.smoke or args.steps):
        td = time.time()
        use_spring = sl is not None and rng.random() < args.spring
        try:
            b = next(its) if use_spring else next(it)
        except StopIteration:
            if use_spring:
                its = iter(sl); b = next(its)
            else:
                it = iter(tl); b = next(it)
        b = to_dev(b, dev)
        if use_spring and of_drop:                                                                                                  
                                                            
            for k, src in (("color_p", "color_a"), ("color_g", "color_a"), ("depth_p", "depth_a"), ("mv_ba", "geo_flow_ba")):
                if k not in b:
                    b[k] = b[src].clone()
            if "mv_ap" not in b:
                b["mv_ap"] = torch.zeros_like(b["geo_flow_ba"])
        tdata += time.time() - td
        if rng.random() < args.p_pan:
            pan_rotate(b, rng, rng.choice(pan_sizes))
        masks = augment(b, rng)
        for g in opt.param_groups:
            g["lr"] = args.lr * sched(step)
        if args.stage == "of":
            fa, fb = model.enc(b["color_a"], b["depth_a"]), model.enc(b["color_b"], b["depth_b"])
            if args.tri:
                if teacher is not None:
                    with torch.no_grad(), torch.autocast("cuda", dtype=torch.float16):
                        tb = torch.cat((b["color_b"], b["color_g"], b["color_b"]), 0)
                        ta = torch.cat((b["color_a"], b["color_a"], b["color_g"]), 0)
                        b["teach_ba"], b["teach_unc"], _ = teacher.flow_ba(tb, ta)
                fg = model.enc(b["color_g"], b["depth_g"])
                ofs = model.pair.of_forward(*tri_inputs(fa, fb, fg, b))
                loss, parts = of_loss_tri(ofs, b, ofw)
            else:
                ofs = model.pair.of_forward(fa, fb, b["color_a"], b["color_b"], of_seed(model, fa, b, args.spring_seed_drop if use_spring else args.seed_drop, rng))
                loss, parts = of_loss(ofs, b, ofw_s if use_spring else ofw)
                if args.match_w > 0 and use_spring:
                    ml = match_loss(fa, fb, b)
                    loss = loss + args.match_w * ml
                    parts["match"] = float(ml)
                if args.seq_w > 0 and use_spring and model.pair.rec is not None and model.pair.rec.seq:
                    n = b["color_a"].shape[0]
                    gt = F.avg_pool2d(b["geo_flow_ba"], 8) / 8
                    K = len(model.pair.rec.seq)
                    sl = sum(0.8 ** (K - 1 - i) * (f[:n] - gt).abs().sum(1).mean() for i, f in enumerate(model.pair.rec.seq))
                    loss = loss + args.seq_w * sl
                    parts["seq"] = float(sl)
                if tfnet is not None:
                    kl = distill_loss(tfnet, fa, fb, b, key=args.distill_key if args.distill_key == "m8" else 8)
                    loss = loss + args.distill_w * kl
                    parts["distill"] = float(kl)
            pair = None
        else:
            frame, pair = run(model, b, use_prev=rng.random() < 0.5)
            loss, parts = total_loss(frame, b["color_g"], pair, b, step=step)
        opt.zero_grad(set_to_none=True)
        if not torch.isfinite(loss):
            say(f"step {step} non-finite loss, skipped: " + " ".join(f"{k} {v:.4g}" for k, v in parts.items()))
            step += 1
            continue
        loss.backward()
        gnorm_pair = torch.nn.utils.clip_grad_norm_(model.pair.parameters(), 1e9).item()
        gnorm = torch.nn.utils.clip_grad_norm_(model.parameters(), args.clip)
        if not torch.isfinite(gnorm):
            bad = [n for n, p in model.named_parameters() if p.grad is not None and not torch.isfinite(p.grad).all()]
            say(f"step {step} non-finite grad, skipped; first params: {bad[:4]}")
            step += 1
            continue
        opt.step()
        step += 1
        for k, v in parts.items():
            acc.setdefault(k, []).append(v)
        acc.setdefault("gnorm_pair", []).append(gnorm_pair)
        if (step % args.log == 0 or args.smoke) and pair is None:
            el = time.time() - t0
            mean = {k: sum(v) / len(v) for k, v in acc.items()}
            say(f"step {step} OF loss {sum(mean[k] for k in parts):.4f} " + " ".join(f"{k} {v:.4f}" for k, v in mean.items()) +
                f" | {el / max(1, len(acc['census'])):.2f} s/step (data {tdata / max(1, len(acc['census'])):.2f})"
                f" mem {torch.cuda.max_memory_allocated() / 2**30:.1f} GB")
            t0, tdata, acc = time.time(), 0.0, {}
        elif step % args.log == 0 or args.smoke:
            gs = gate_stats(pair["gate"][: b["color_g"].shape[0]].detach(), masks["mv_wrong"])
            el = time.time() - t0
            mean = {k: sum(v) / len(v) for k, v in acc.items()}
            say(f"step {step} loss {sum(mean[k] for k in parts):.4f} " +
                " ".join(f"{k} {v:.4f}" for k, v in mean.items()) +
                f" | c mean {gs['c_mean']:.3f} wrongMV {gs['c_wrong']:.3f} okMV {gs['c_ok']:.3f} mid {gs['c_mid']:.3f}"
                f" hist {' '.join(f'{h:.2f}' for h in gs['c_hist'])}"
                f" | {el / max(1, len(acc['l1'])):.2f} s/step (data {tdata / max(1, len(acc['l1'])):.2f})"
                f" mem {torch.cuda.max_memory_allocated() / 2**30:.1f} GB")
            t0, tdata, acc = time.time(), 0.0, {}
        if not args.smoke and step % args.val == 0 and args.stage == "of":
            per, gain = validate_of(model, vl, dev, args.val_batches)
            say(f"VAL-OF step {step} OF-warp gain over no-warp {gain:+.2f} dB | " +
                " | ".join(f"span {k}: none {v[0]:.2f} MV {v[1]:.2f} OF {v[2]:.2f}" for k, v in per.items()))
            if vl_big is not None:
                per_b, gain_b = validate_of(model, vl_big, dev, args.val_batches)
                say(f"VAL-OF-BIG step {step} OF-warp gain over no-warp {gain_b:+.2f} dB | " +
                    " | ".join(f"span {k}: none {v[0]:.2f} MV {v[1]:.2f} OF {v[2]:.2f}" for k, v in per_b.items()))
            if sl_val is not None:
                ep, bins = validate_epe(model, sl_val, dev, args.val_batches)
                for mode, r in ep.items():
                    if r:
                        say(f"VAL-SPRING step {step} {mode:4s} | " + " | ".join(
                            f"{bins[i]:.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf'}: EPE {v[0]:.2f} ratio {v[1]:.2f} (n{v[2]})"
                            for i, v in r.items()))
                torch.save(model.state_dict(), os.path.join(args.out, f"s{step}.pt"))
            ck = {"model": model.state_dict(), "opt": opt.state_dict(), "step": step, "best": best}
            if gain > best:
                best = gain; ck["best"] = best
                torch.save(model.state_dict(), os.path.join(args.out, "best.pt"))
            torch.save(ck, prog)
            torch.save(model.state_dict(), os.path.join(args.out, "last.pt"))
        elif not args.smoke and step % args.val == 0:
            v = validate(model, vl, dev, args.val_batches)
            say(f"VAL step {step} clean PSNR out {v['clean']:.2f} blend {v['clean_blend']:.2f} | augmented PSNR out "
                f"{v['out']:.2f} blend {v['blend']:.2f} mvwarp {v['mvwarp']:.2f} | c wrongMV {v['c_wrong']:.3f} "
                f"okMV {v['c_ok']:.3f}")
            ck = {"model": model.state_dict(), "opt": opt.state_dict(), "step": step, "best": best}
            score = 0.5 * (v["clean"] + v["out"])
            if score > best:
                best = score; ck["best"] = best
                torch.save(model.state_dict(), os.path.join(args.out, "best.pt"))
            torch.save(ck, prog)
            torch.save(model.state_dict(), os.path.join(args.out, "last.pt"))
    say("done")


if __name__ == "__main__":
    main()
