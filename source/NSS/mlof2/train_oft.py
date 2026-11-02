"""Train the OF t-block (oft_block.OFTNet) on a FROZEN MLOF2 encoder + pair OF (pure OF, no MV: the pair is not seeded),
OF at half resolution as the DLL (OF_CAP 2). Data as train_nfru_head.py (forest / lyra / Spring windows, augment,
pan_rotate). Loss: Laplacian L1 + L1 against the real middle frame G, plus a small distillation of RIFE 4.25's t-flows
(MIT, training only) where RIFE's own frame is close to G.
  python train_oft.py --mlof2 <ckpt> --out <dir> [--steps 3000]"""
import argparse, math, os, random, sys, time
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment, pan_rotate
from train_v2 import to_dev, psnr
from oft_block import OFTNet, lap_l1, gmac

sys.path.insert(0, "/home/sh/third_party/Practical-RIFE")
from train_log.IFNet_HDv3 import IFNet


def pure_of(m, b):
    """Pure pair OF on the half-res frames (no MV seed): of_ab, of_ba at 1/4 of the half frame."""
    h2, w2 = b["color_a"].shape[-2] // 2, b["color_a"].shape[-1] // 2
    ph, pw = (64 - h2 % 64) % 64, (64 - w2 % 64) % 64                                                              
    dn = lambda x: F.pad(F.avg_pool2d(x, 2), (0, pw, 0, ph), mode="replicate")
    with torch.no_grad():
        fa, fb = m.enc(dn(b["color_a"]), dn(b["depth_a"])), m.enc(dn(b["color_b"]), dn(b["depth_b"]))
        mvv = torch.zeros_like(dn(b["mv_valid"]))
        p = m.pair(fa, fb, dn(b["mv_ba"]) * 0, mvv, dn(b["color_a"]), dn(b["color_b"]))
    return p["of_ab"][..., :h2 // 4, :w2 // 4], p["of_ba"][..., :h2 // 4, :w2 // 4]


def rife(rnet, b):
    with torch.no_grad():
        n = b["color_a"].shape[0]
        fl, mk, merged = rnet(torch.cat((b["color_a"], b["color_b"]), 1), b["t"].view(n, 1, 1, 1).float(), [16, 8, 4, 2, 1])
    run.rife_mask = torch.sigmoid(mk)
    return fl[-1][:, 0:2], fl[-1][:, 2:4], merged[4].clamp(0, 1)


def run(net, m, b):
    of_ab, of_ba = pure_of(m, b)
    return net(b["t"].float(), b["color_a"], b["color_b"], of_ab, of_ba)


def validate(net, m, rnet, loader, dev, nb=30):
    net.eval()
    acc = {"oft": [], "rife": [], "lin": []}
    with torch.no_grad():
        for bi, b in enumerate(loader):
            if bi >= nb:
                break
            b = to_dev(b, dev)
            o = run(net, m, b)
            acc["oft"].append(psnr(o["color"], b["color_g"]))
            acc["rife"].append(psnr(rife(rnet, b)[2], b["color_g"]))
    net.train()
    return {k: sum(v) / len(v) for k, v in acc.items() if v}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mlof2", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=3000)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--batch", type=int, default=2)
    ap.add_argument("--crop", type=int, default=448)
    ap.add_argument("--val", type=int, default=500)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--p_pan", type=float, default=0.5)
    ap.add_argument("--spring", type=float, default=0.5)
    ap.add_argument("--spring_crop", default="1024,1920")
    ap.add_argument("--distill", type=float, default=0.02)
    ap.add_argument("--distill_mask", type=float, default=0.0, help="L1 of the mask to RIFE's (sigmoid), gated as the flows")
    ap.add_argument("--widths", default="96,64,48")
    ap.add_argument("--nres", default="3,3,3")
    ap.add_argument("--corr", type=int, default=0)
    ap.add_argument("--hard", type=float, default=0.0,
                    help="weight of the flow loss on the HARD pixels only (init t-flow error >= max(90th pct, 0.5 px)); "
                         "the plain all-pixel flow loss regresses the correction to 0 (oft5: init EPE ~0.5 px almost everywhere)")
    ap.add_argument("--lm", type=float, default=0.0,
                    help="weight of the flow loss on LEARNABLE local-motion pixels only: exact t-flow differs from its "
                         "65x65 mean by > 1 px (grass / sway) AND the exact warp reproduces G (< 0.04: visible in that "
                         "frame, not occluded) AND it stays inside the frame (oft6 lesson: hard = mostly occlusion)")
    ap.add_argument("--fol_min", type=float, default=0.0,
                    help="Spring: redraw (up to 4x) windows whose local-motion share (|flow - 65x65 mean| > 1.5 px) is below this")
    ap.add_argument("--gtflow", type=float, default=0.0,
                    help="L1 of the t-flows to the EXACT t-flows (geo_flow_ga = G->A; G->B = inverted geo_flow_bg), "
                         "not gated; batches without pan_rotate only (it does not move geo_flow_ga / _bg)")
    ap.add_argument("--init", default="", help="OFTNet checkpoint; with one block more than it, its blocks go to the finer slots")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    dev = "cuda"
    rng = random.Random(0)
    torch.manual_seed(0)
    names = ["forest15", "lyra15", "lyra17"]
    tri = args.gtflow > 0
    tl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=args.crop, mv_res=True, tri=tri), batch_size=args.batch,
                                     shuffle=True, num_workers=args.workers, drop_last=True, persistent_workers=True)
    vl = torch.utils.data.DataLoader(WindowDataset(names, "validation", crop=args.crop, windows_per_file=8), batch_size=2,
                                     shuffle=False, num_workers=1)
    sl = None
    if args.spring > 0:
        sc = tuple(int(x) for x in args.spring_crop.split(","))
        sl = torch.utils.data.DataLoader(WindowDataset(["spring"], "train", crop=sc, strides=(1, 2, 4, 8, 12), tri=tri), batch_size=1,
                                         shuffle=True, num_workers=2, prefetch_factor=1, drop_last=True, persistent_workers=True)
        its = iter(sl)
    sd = torch.load(args.mlof2, map_location=dev)
    m = build_mlof2(sd).to(dev).eval()
    m.load_state_dict(sd.get("model", sd))
    m.pair.seeded = False
    for p in m.parameters():
        p.requires_grad_(False)
    rnet = IFNet().to(dev).eval()
    rsd = torch.load("/home/sh/third_party/Practical-RIFE/train_log/flownet.pkl", map_location=dev)
    rnet.load_state_dict({k.replace("module.", ""): v for k, v in rsd.items()}, strict=False)
    for p in rnet.parameters():
        p.requires_grad_(False)
    net = OFTNet(tuple(int(x) for x in args.widths.split(",")), tuple(int(x) for x in args.nres.split(",")),
                 corr=bool(args.corr)).to(dev).train()
    if args.init:
        isd = torch.load(args.init, map_location=dev)
        nb_i = len({k.split(".")[1] for k in isd})
        off = len(net.blocks) - nb_i
        isd = {f"blocks.{int(k.split('.')[1]) + off}." + k.split(".", 2)[2]: v for k, v in isd.items()}
        miss, unexp = net.load_state_dict(isd, strict=False)
        say_ = print("init", args.init, "offset", off, "missing", len(miss), "unexpected", unexp, flush=True)
    opt = torch.optim.AdamW(net.parameters(), lr=args.lr, weight_decay=1e-4)
    sched = lambda s: 0.5 * (1 + math.cos(math.pi * min(s, args.steps) / args.steps)) * min(1.0, s / 200)
    log = open(os.path.join(args.out, "log.txt"), "a")
    say = lambda s: (print(s, flush=True), log.write(s + "\n"), log.flush())
    say(f"OFT params {sum(p.numel() for p in net.parameters())}, {gmac(net):.1f} GMAC/t at 1080p; frozen {args.mlof2}; "
        f"spring {args.spring}; distill {args.distill}")
    v = validate(net, m, rnet, vl, dev)
    say("VAL step 0 " + " ".join(f"{k} {x:.2f}" for k, x in v.items()))
    best, step, it, t0, run_ = -1e9, 0, iter(tl), time.time(), {}
    while step < args.steps:
        use_spring = sl is not None and rng.random() < args.spring
        try:
            b = next(its) if use_spring else next(it)
        except StopIteration:
            if use_spring:
                its = iter(sl); b = next(its)
            else:
                it = iter(tl); b = next(it)
        b = to_dev(b, dev)
        if use_spring and args.fol_min > 0:
            for _ in range(4):
                f_ = b["geo_flow_ba"]
                sm_ = F.avg_pool2d(F.pad(f_, (32, 32, 32, 32), mode="replicate"), 65, 1)
                if float(((f_ - sm_).norm(dim=1) > 1.5).float().mean()) >= args.fol_min:
                    break
                try:
                    b = to_dev(next(its), dev)
                except StopIteration:
                    its = iter(sl); b = to_dev(next(its), dev)
        panned = not use_spring and rng.random() < args.p_pan
        if panned:
            pan_rotate(b, rng, rng.choice([640, 896, 1088]))
        augment(b, rng)
        for g_ in opt.param_groups:
            g_["lr"] = args.lr * sched(step)
        o = run(net, m, b)
        g = b["color_g"]
        gv = b.get("gt_valid", torch.ones_like(g[:, :1]))
        l_lap = lap_l1(o["color"] * gv, g * gv)
        l_l1 = ((o["color"] - g).abs() * gv).mean()
        loss = l_lap + l_l1
        parts = {"lap": float(l_lap), "l1": float(l_l1)}
        if args.distill > 0:
            ra, rb, rc = rife(rnet, b)
            wq = torch.exp(-(rc - g).abs().mean(1, keepdim=True) * 20.0) * gv
            l_d = (((o["f_ta"] - ra).abs() + (o["f_tb"] - rb).abs()).sum(1, keepdim=True) * wq).mean()
            loss = loss + args.distill * l_d
            parts["dist"] = float(l_d)
            if args.distill_mask > 0:
                l_m = ((o["vis"] - run.rife_mask).abs() * wq).mean()
                loss = loss + args.distill_mask * l_m
                parts["dmask"] = float(l_m)
        if args.gtflow > 0 and not panned:
            from model_v2 import invert_flow
            gt_ta = b["geo_flow_ga"]
            gt_tb, ok_tb = invert_flow(b["geo_flow_bg"])
            l_gf = ((o["f_ta"] - gt_ta).abs().sum(1, keepdim=True) * gv).mean() +                    ((o["f_tb"] - gt_tb).abs().sum(1, keepdim=True) * gv * ok_tb).mean()
            loss = loss + args.gtflow * l_gf
            parts["gtf"] = float(l_gf)
            if args.lm > 0:
                from model_v2 import warp as warp_
                g_ = b["color_g"]
                n_, _, H_, W_ = g_.shape
                yy, xx = torch.meshgrid(torch.arange(H_, device=dev), torch.arange(W_, device=dev), indexing="ij")

                def learnable(gt, src, extra):
                    loc = (gt - F.avg_pool2d(F.pad(gt, (32, 32, 32, 32), mode="replicate"), 65, 1)).norm(dim=1, keepdim=True) > 1.0
                    vis = (warp_(src, gt) - g_).abs().mean(1, keepdim=True) < 0.04
                    qx, qy = xx[None] + gt[:, 0], yy[None] + gt[:, 1]
                    inside = ((qx > 0) & (qx < W_ - 1) & (qy > 0) & (qy < H_ - 1))[:, None]
                    return (loc & vis & inside).float() * gv * extra

                la, lb = learnable(gt_ta, b["color_a"], 1.0), learnable(gt_tb, b["color_b"], ok_tb)
                l_lm = ((o["f_ta"] - gt_ta).abs().sum(1, keepdim=True) * la).sum() / la.sum().clamp_min(1) +                        ((o["f_tb"] - gt_tb).abs().sum(1, keepdim=True) * lb).sum() / lb.sum().clamp_min(1)
                loss = loss + args.lm * l_lm
                parts["lm"] = float(l_lm)
                parts["lm_px"] = float(la.mean())
            if args.hard > 0:
                ia, ib = (x_.detach() for x_ in net.last_init)
                ea_i = (ia - gt_ta).norm(dim=1, keepdim=True) * gv
                eb_i = (ib - gt_tb).norm(dim=1, keepdim=True) * gv * ok_tb
                def hard(e_):
                    thr = torch.quantile(e_.flatten(1)[:, ::7], 0.9, dim=1).clamp_min(0.5).view(-1, 1, 1, 1)
                    return (e_ >= thr).float()
                ha, hb = hard(ea_i), hard(eb_i)
                l_h = ((o["f_ta"] - gt_ta).abs().sum(1, keepdim=True) * ha).sum() / ha.sum().clamp_min(1) +                       ((o["f_tb"] - gt_tb).abs().sum(1, keepdim=True) * hb).sum() / hb.sum().clamp_min(1)
                loss = loss + args.hard * l_h
                parts["hard"] = float(l_h)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(net.parameters(), 1.0)
        opt.step()
        step += 1
        for k, x in parts.items():
            run_[k] = run_.get(k, 0) + x
        if step % 50 == 0:
            say(f"step {step} " + " ".join(f"{k} {x / 50:.4f}" for k, x in run_.items()) +
                f" | vis {float(o['vis'].mean()):.2f} | {(time.time() - t0) / 50:.2f} s/step")
            run_, t0 = {}, time.time()
        if step % args.val == 0 or step == args.steps:
            v = validate(net, m, rnet, vl, dev)
            say(f"VAL step {step} " + " ".join(f"{k} {x:.2f}" for k, x in v.items()))
            torch.save(net.state_dict(), os.path.join(args.out, "last.pt"))
            if v["oft"] > best:
                best = v["oft"]
                torch.save(net.state_dict(), os.path.join(args.out, "best.pt"))
    say("done")


if __name__ == "__main__":
    main()
