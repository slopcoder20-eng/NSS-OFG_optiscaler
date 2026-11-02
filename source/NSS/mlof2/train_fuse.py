"""Train FuseNet (oft_fuse.py) on frozen MLOF2 pair (pure OF) + OFTNet 3 blocks + LK. MV-wrong cases: augment()
(pasted layers whose MV is missing / locked), Spring MV degrade incl. the foliage MV_SMOOTH case (P_MV_SMOOTH env,
train_nfru_head_r.degrade_spring_mv), pan_rotate (fast turns: content enters from off-frame).
Loss: Laplacian L1 + L1 to G, + ce * oracle cross-entropy (choose the clearly best candidate, do not blend).
  python train_fuse.py --mlof2 <ckpt> --oft <oft ckpt> --out <dir> [--steps 2000]"""
import argparse, math, os, random, time
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment, pan_rotate
from train_v2 import to_dev, psnr
from oft_block import OFTNet, lap_l1
from oft_fuse import FuseNet, of_frame, mv_candidates
from lk_refine import lk_refine
from train_oft import pure_of
from train_nfru_head_r import degrade_spring_mv


def load_oft3(path, dev):
    sd = torch.load(path, map_location=dev)
    nbl = len({k.split(".")[1] for k in sd if k.startswith("blocks.")})
    nb = [len({k.split(".")[3] for k in sd if k.startswith(f"blocks.{i}.body.")}) for i in range(nbl)]
    net = OFTNet(tuple(sd[f"blocks.{i}.d2.weight"].shape[0] for i in range(nbl)), tuple(nb)).to(dev).eval()
    net.load_state_dict(sd)
    net.blocks, net.SCALES = net.blocks[:-1], net.SCALES[:-1]                                         
    for p in net.parameters():
        p.requires_grad_(False)
    return net


def run(m, oft, fuse, b):
    t = b["t"].float()
    with torch.no_grad():
        of_ab, of_ba = pure_of(m, b)
        o = oft(t, b["color_a"], b["color_b"], of_ab, of_ba)
        fa, fb, _ = lk_refine(b["color_a"], b["color_b"], o["f_ta"], o["f_tb"], t)
        ofc, oa, ob = of_frame(b["color_a"], b["color_b"], fa, fb, o["vis"])
        mva, mvb, ma, mb, hole, offma, offmb = mv_candidates(b["color_a"], b["color_b"], b["depth_b"],
                                                            b["mv_ba"] * b["mv_valid"], b["mv_valid"], t)
    from model_v2 import warp as warp_
    d_of = (warp_(b["color_a"], fa) - warp_(b["color_b"], fb)).abs().mean(1, keepdim=True) * 4
    out, w, cand = fuse(t, ofc, mva, mvb, fa, ma, oa, ob, offma, offmb, hole, o["vis"], d_of)
    run.mb = mb
    return out, w, cand, ofc


def oracle_ce(w, cand, g, gap=0.03, emax=0.15, mask=None):
    lw = torch.tensor([.299, .587, .114], device=g.device).view(1, 1, 3, 1, 1)
    e = F.avg_pool2d(((cand - g[:, None]) * lw).sum(2).abs(), 3, 1, 1)
    s, idx = e.sort(1)
    ok = ((s[:, 1] - s[:, 0]) > gap) & (s[:, 0] < emax)
    if mask is not None:
        ok = ok & (mask[:, 0] > 0.5)
    nll = -torch.log(w.gather(1, idx[:, :1]).clamp_min(1e-6))[:, 0]
    return (nll * ok).sum() / ok.sum().clamp_min(1), float(ok.float().mean())


def validate(m, oft, fuse, vl, dev, nb=30):
    fuse.eval()
    rng = random.Random(7)
    acc = {"fused": [], "of": [], "fused_pan": [], "of_pan": []}
    with torch.no_grad():
        for bi, b in enumerate(vl):
            if bi >= nb:
                break
            b = to_dev(b, dev)
            out, _, _, ofc = run(m, oft, fuse, b)
            acc["fused"].append(psnr(out, b["color_g"])); acc["of"].append(psnr(ofc, b["color_g"]))
            pan_rotate(b, rng, 640)
            gv = b["gt_valid"]
            out, _, _, ofc = run(m, oft, fuse, b)
            acc["fused_pan"].append(psnr(out * gv, b["color_g"] * gv)); acc["of_pan"].append(psnr(ofc * gv, b["color_g"] * gv))
    fuse.train()
    return {k: sum(v) / len(v) for k, v in acc.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mlof2", required=True)
    ap.add_argument("--oft", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=2000)
    ap.add_argument("--lr", type=float, default=5e-4)
    ap.add_argument("--ce", type=float, default=0.3)
    ap.add_argument("--spring", type=float, default=0.4)
    ap.add_argument("--p_pan", type=float, default=0.5)
    ap.add_argument("--val", type=int, default=500)
    ap.add_argument("--cin", type=int, default=21)
    ap.add_argument("--init", default="")
    ap.add_argument("--spring_crop", default="512,960", help="Spring crop (h,w); 1024,1920 was killed by memory pressure")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    dev = "cuda"
    rng = random.Random(0)
    torch.manual_seed(0)
    names = ["forest15", "lyra15", "lyra17"]
    tl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=448, mv_res=True), batch_size=2, shuffle=True,
                                     num_workers=2, drop_last=True, persistent_workers=True)
    vl = torch.utils.data.DataLoader(WindowDataset(names, "validation", crop=448, windows_per_file=8), batch_size=2,
                                     shuffle=False, num_workers=1)
    sl = torch.utils.data.DataLoader(WindowDataset(["spring"], "train", crop=tuple(int(x) for x in args.spring_crop.split(",")), strides=(1, 2, 4, 8, 12)),
                                     batch_size=1, shuffle=True, num_workers=2, prefetch_factor=1, drop_last=True,
                                     persistent_workers=True)
    its, it = iter(sl), iter(tl)
    sd = torch.load(args.mlof2, map_location=dev)
    m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
    for p in m.parameters():
        p.requires_grad_(False)
    oft = load_oft3(args.oft, dev)
    fuse = FuseNet(cin=args.cin).to(dev).train()
    if args.init:                                                                                      
        isd = torch.load(args.init, map_location=dev)
        w_ = fuse.state_dict()["d1.weight"].clone(); w_.zero_()
        w_[:, :isd["d1.weight"].shape[1]] = isd["d1.weight"]
        isd["d1.weight"] = w_
        fuse.load_state_dict(isd)
    opt = torch.optim.AdamW(fuse.parameters(), lr=args.lr, weight_decay=1e-4)
    sched = lambda s: 0.5 * (1 + math.cos(math.pi * min(s, args.steps) / args.steps)) * min(1.0, s / 100)
    log = open(os.path.join(args.out, "log.txt"), "a")
    say = lambda s: (print(s, flush=True), log.write(s + "\n"), log.flush())
    say(f"FuseNet params {sum(p.numel() for p in fuse.parameters())}; oft {args.oft}; ce {args.ce}")
    v = validate(m, oft, fuse, vl, dev)
    say("VAL step 0 " + " ".join(f"{k} {x:.2f}" for k, x in v.items()))
    best, step, t0, run_ = -1e9, 0, time.time(), {}
    while step < args.steps:
        use_spring = rng.random() < args.spring
        try:
            b = next(its) if use_spring else next(it)
        except StopIteration:
            if use_spring:
                its = iter(sl); b = next(its)
            else:
                it = iter(tl); b = next(it)
        b = to_dev(b, dev)
        if use_spring:
            degrade_spring_mv(b, rng)
        elif rng.random() < args.p_pan:
            pan_rotate(b, rng, rng.choice([640, 896]))
        augment(b, rng)
        for g_ in opt.param_groups:
            g_["lr"] = args.lr * sched(step)
        out, w, cand, _ = run(m, oft, fuse, b)
        g = b["color_g"]
        gv = b.get("gt_valid", torch.ones_like(g[:, :1]))
        if "b_valid" in b:                                                                                          
            from model_v2 import warp as warp_                                                                               
            gv = gv * (warp_(b["b_valid"], run.mb) > 0.999).float()
        loss = lap_l1(out * gv, g * gv) + ((out - g).abs() * gv).mean()
        parts = {"rec": float(loss)}
        if args.ce > 0:
            l_ce, share = oracle_ce(w, cand, g, mask=gv)
            loss = loss + args.ce * l_ce
            parts["ce"], parts["ce_px"] = float(l_ce), share
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(fuse.parameters(), 1.0)
        opt.step()
        step += 1
        for k, x in parts.items():
            run_[k] = run_.get(k, 0) + x
        if step % 50 == 0:
            wm = w.mean((0, 2, 3)).tolist()
            say(f"step {step} " + " ".join(f"{k} {x / 50:.4f}" for k, x in run_.items()) +
                f" | w of {wm[0]:.2f} mvA {wm[1]:.2f} mvB {wm[2]:.2f} | {(time.time() - t0) / 50:.2f} s/step")
            run_, t0 = {}, time.time()
        if step % args.val == 0 or step == args.steps:
            v = validate(m, oft, fuse, vl, dev)
            say(f"VAL step {step} " + " ".join(f"{k} {x:.2f}" for k, x in v.items()))
            torch.save(fuse.state_dict(), os.path.join(args.out, "last.pt"))
            sc = v["fused"] + v["fused_pan"]
            if sc > best:
                best = sc
                torch.save(fuse.state_dict(), os.path.join(args.out, "best.pt"))
    say("done")


if __name__ == "__main__":
    main()
