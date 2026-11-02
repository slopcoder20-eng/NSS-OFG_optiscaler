"""(train_nfru_head_r.py: copy for head R = frozen NfruHeadC2 from --init_head + FullSynth, nfru_head_r.py)
Fine-tune the NFRU reconstruction (nfru_head.NfruHead, Arm-initialised autoencoder) on a FROZEN MLOF2
(encoder, OF, gate and TimeHead flows fixed). Same data / augmentation as train_v2 full stage (pan_rotate,
synthetic layers, MV render-scale augmentation); colour losses only (l1, top-k, hole), ground truth = the real G.
  python train_nfru_head.py --mlof2 <ckpt> --out <dir> [--steps 6000] [--lr 5e-4]"""
import argparse
import math
import os
import random
import time
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment, pan_rotate
from losses_v2 import masked_l1, topk_loss, round_trip_occlusion
from train_v2 import to_dev, psnr
from nfru_head import NfruHead, NfruHeadC
VARIANT = "a"
ACCEL = False


def forward(m, head, b, use_prev):
    with torch.no_grad():
        enc = m.enc
        fa, fb = enc(b["color_a"], b["depth_a"]), enc(b["color_b"], b["depth_b"])
        f_prev, of_ap = None, None
        if use_prev:
            fp = enc(b["color_p"], b["depth_p"])
            pp = m.pair(fp, fa, b["mv_ap"], torch.ones_like(b["mv_valid"]), b["color_p"], b["color_a"])
            f_prev, of_ap = pp["f_ba"], pp["of_ba"]                                           
            if pp.get("of_ba_full") is not None:                                                                           
                of_ap = pp["of_ba_full"]
        pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
        frame = m.head(b["t"], pair, fa[8], fb[8], b["color_a"], b["color_b"], f_prev)
    if VARIANT == "c":                                                                                       
        acc = ACCEL and use_prev                                                                                   
        of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
        out = head(b["t"], of_q, b["color_a"], b["color_b"], b["depth_a"], b["depth_b"], b["mv_ba"] * b["mv_valid"],
                   b["mv_ap"] if acc else None, of_ap if acc else None, conf_q=pair["conf"][:b["color_a"].shape[0]],
                   occ_q=pair["occ"][:b["color_a"].shape[0]])
    else:
        out = head(b["t"], pair, frame, b["color_a"], b["color_b"], b["depth_a"], b["depth_b"])
    return out, frame, pair


LPIPS = None


def degrade_spring_mv(b, rng):
    """Spring's 'MV' is the exact flow (better than any game MV): make it game-like per sample so the head does not
    learn 'the MV candidates are always right'. 40% exact (augment() still breaks it on pasted layers), 30% render-res
    MV (area down by 1.5-2x, nearest up), 30% wrong foreground: the nearest ~15% of B (A for mv_ap) takes the
    median background motion (an animating viewmodel / tool whose MV only follows the camera)."""
    n, _, H, W = b["mv_ba"].shape
    p_sm = float(os.environ.get("P_MV_SMOOTH", "0"))
    for i in range(n):
        if rng.random() < p_sm:
                                                                                                                        
                                                                                                       
            r, thr = rng.choice((16, 24, 32)), rng.uniform(1.0, 2.0)
            for key in ("mv_ba", "mv_ap"):
                mv = b[key][i:i + 1]
                sm = F.avg_pool2d(F.pad(mv, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
                b[key][i:i + 1] = torch.where((mv - sm).norm(dim=1, keepdim=True) > thr, sm, mv)
            continue
        u = rng.random()
        if u < 0.4:
            continue
        for key, dkey in (("mv_ba", "depth_b"), ("mv_ap", "depth_a")):
            mv = b[key][i:i + 1]
            if u < 0.7:
                s = rng.uniform(1.5, 2.0)
                lo = F.interpolate(mv, size=(int(H / s), int(W / s)), mode="area")
                b[key][i:i + 1] = F.interpolate(lo, size=(H, W), mode="nearest")
            else:
                d = b[dkey][i, 0]
                fg = d <= torch.quantile(d.flatten()[::97], 0.15)
                if fg.all() or not fg.any():
                    continue
                bgm = mv[0][:, ~fg].median(dim=1).values.view(2, 1, 1)
                b[key][i] = torch.where(fg[None], bgm.expand(2, H, W), mv[0])


def losses(out, pair, b, w_lpips=0.0):
    g = b["color_g"]
    H, W = g.shape[-2:]
    gv = b.get("gt_valid", torch.ones_like(g[:, :1]))
    occ = F.interpolate(round_trip_occlusion(pair["f_ba"], pair["f_ab"]).detach(), size=(H, W), mode="nearest")
    parts = {"l1": masked_l1(out["color"], g, gv), "topk": topk_loss(out["color"] * gv, g * gv),
             "hole": masked_l1(out["color"], g, occ * gv)}
    total = sum(parts.values())
    if w_lpips > 0:                                                                                              
        lp = LPIPS((out["color"] * gv) * 2 - 1, (g * gv) * 2 - 1).mean()
        parts["lpips"] = lp
        total = total + w_lpips * lp
    return total, {k: v.item() for k, v in parts.items()}


def oracle_ce(out, g, gap=1.5, emax=25.0):
    """Cross-entropy of the blend weights against the per-pixel best candidate (|luma - G|, 3x3 mean): teaches the head
    to CHOOSE (L1 alone rewards blending, which smeared backgrounds on SN2). Pixels where the best is clear (gap to
    the second > 1.5/255) and good (< 25/255) only. Returns (loss, share of pixels used)."""
    lw = torch.tensor([.299, .587, .114], device=g.device).view(1, 1, 3, 1, 1)
    e = ((out["cand"] - g[:, None]).mul(lw).sum(2)).abs()                                           
    e = F.avg_pool2d(e, 3, 1, 1)
    srt, idx = e.sort(1)
    w = ((srt[:, 1] - srt[:, 0]) * 255 > gap) & (srt[:, 0] * 255 < emax)
    w = w.float().detach()
    logp = out["weights"].clamp_min(1e-6).log()
    nll = -logp.gather(1, idx[:, :1]).squeeze(1)
    return (nll * w).sum() / w.sum().clamp_min(1.0), float(w.mean())


@torch.no_grad()
def validate(m, head, loader, dev, nb=40):
    head.eval()
    rng = random.Random(1234)
    acc = {"clean": [], "aug": [], "mlof2_clean": [], "mlof2_aug": []}
    for bi, b in enumerate(loader):
        if bi >= nb:
            break
        b = to_dev(b, dev)
        out, frame, _ = forward(m, head, b, True)
        acc["clean"].append(psnr(out["color"], b["color_g"])); acc["mlof2_clean"].append(psnr(frame["color"], b["color_g"]))
        augment(b, rng)
        out, frame, _ = forward(m, head, b, True)
        acc["aug"].append(psnr(out["color"], b["color_g"])); acc["mlof2_aug"].append(psnr(frame["color"], b["color_g"]))
    head.train()
    return {k: sum(v) / len(v) for k, v in acc.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mlof2", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=6000)
    ap.add_argument("--lr", type=float, default=5e-4)
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--val", type=int, default=1000)
    ap.add_argument("--p_pan", type=float, default=0.5)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--variant", default="a", choices=["a", "c"])
    ap.add_argument("--accel", type=int, default=0, help="variant c: quadratic trajectories from the previous frame")
    ap.add_argument("--res", type=int, default=4, help="variant c: autoencoder resolution divisor")
    ap.add_argument("--cues", type=int, default=0, help="variant c: 1 = + 4 MV/OF evidence inputs, 2 = + 7 (zero rows)")
    ap.add_argument("--freeze_mid", type=int, default=0, help="freeze the AE bottleneck (conv2 .. conv5e): train conv1 + decoder")
    ap.add_argument("--ce_gap", type=float, default=1.5, help="CE label: best must beat the 2nd by this (1/255)")
    ap.add_argument("--ce_max", type=float, default=25.0, help="CE label: best error below this (1/255)")
    ap.add_argument("--ce", type=float, default=0.0, help="weight of the oracle-candidate cross-entropy (choose, do not blend)")
    ap.add_argument("--recon", type=float, default=1.0, help="weight of the colour losses (l1 / top-k / hole)")
    ap.add_argument("--of_prior", type=float, default=0.0, help="variant c: fixed bias on the OF candidates' logits (e.g. -2)")
    ap.add_argument("--refine", type=int, default=0, help="variant c: half-res correction of the blend logits")
    ap.add_argument("--arm_init", type=int, default=1, help="0: autoencoder from random init (no Arm weights: release)")
    ap.add_argument("--synth_c", type=int, default=48)
    ap.add_argument("--synth_n", type=int, default=3)
    ap.add_argument("--init_head", default="", help="start from this head checkpoint (missing new modules start at zero)")
    ap.add_argument("--talign", default="splat", choices=["splat", "fp"], help="variant c: how flows are moved to t")
    ap.add_argument("--spring", type=float, default=0.0, help="share of steps on Spring windows (real middle frame G)")
    ap.add_argument("--spring_crop", default="1024,1920")
    ap.add_argument("--spring_batch", type=int, default=2)
    ap.add_argument("--lpips", type=float, default=0.0, help="weight of LPIPS(alex) (Arm NFRU uses 0.157)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    dev = "cuda"
    rng = random.Random(0)
    torch.manual_seed(0)
    names = ["forest15", "lyra15", "lyra17"]
    tl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=448, mv_res=True), batch_size=args.batch,
                                     shuffle=True, num_workers=args.workers, drop_last=True, persistent_workers=True)
    vl = torch.utils.data.DataLoader(WindowDataset(names, "validation", crop=448, windows_per_file=8), batch_size=4,
                                     shuffle=False, num_workers=2)
    sd = torch.load(args.mlof2, map_location=dev)
    m = build_mlof2(sd).to(dev).eval()
    m.load_state_dict(sd.get("model", sd))
    for p in m.parameters():
        p.requires_grad_(False)
    global VARIANT, ACCEL
    VARIANT, ACCEL = args.variant, bool(args.accel)
    from nfru_head_r import NfruHeadR
    from nfru_head import load_head_c2
    base = load_head_c2(args.init_head, dev)
    for p in base.parameters():
        p.requires_grad_(False)
    head = NfruHeadR(base, args.synth_c, args.synth_n).to(dev).train()
    head.base.eval()
    head.talign = args.talign
    if False:
        isd = torch.load(args.init_head, map_location=dev)
        w_own = head.state_dict()["ae.conv1.conv2d.weight"]
        if isd["ae.conv1.conv2d.weight"].shape != w_own.shape:                                          
            w = torch.zeros_like(w_own); w[:, :isd["ae.conv1.conv2d.weight"].shape[1]] = isd["ae.conv1.conv2d.weight"]
            isd["ae.conv1.conv2d.weight"] = w
        miss, unexp = head.load_state_dict(isd, strict=False)
        print("init head", args.init_head, "missing", miss, "unexpected", unexp, flush=True)
    if False:
        head.of_prior.fill_(args.of_prior)                                                          
    sl = None
    if args.spring > 0:                                                                                                 
        sc = tuple(int(x) for x in args.spring_crop.split(","))
        sl = torch.utils.data.DataLoader(WindowDataset(["spring"], "train", crop=sc, strides=(1, 2, 4, 8, 12)),
                                         batch_size=args.spring_batch, shuffle=True, num_workers=2, prefetch_factor=1,
                                         drop_last=True, persistent_workers=True)
        its = iter(sl)
    if args.lpips > 0:
        global LPIPS
        import lpips
        LPIPS = lpips.LPIPS(net="alex", verbose=False).to(dev).eval()
        for p in LPIPS.parameters():
            p.requires_grad_(False)
    if args.freeze_mid:
        for nm, p in head.named_parameters():
            if nm.startswith(("ae.conv2.", "ae.conv3.", "ae.conv5")):
                p.requires_grad_(False)
        print("trainable:", sorted({nm.split(".")[1] for nm, p in head.named_parameters() if p.requires_grad}), flush=True)
    opt = torch.optim.AdamW([p for p in head.parameters() if p.requires_grad], lr=args.lr, weight_decay=1e-4)
    sched = lambda s: 0.5 * (1 + math.cos(math.pi * min(s, args.steps) / args.steps)) * min(1.0, s / 300)
    log = open(os.path.join(args.out, "log.txt"), "a")
    say = lambda s: (print(s, flush=True), log.write(s + "\n"), log.flush())
    say(f"frozen MLOF2 {args.mlof2}; NFRU head params {sum(p.numel() for p in head.parameters())}; talign {args.talign}; "
        f"spring {args.spring}")
    v = validate(m, head, vl, dev)
    say(f"VAL step 0 (Arm init) clean {v['clean']:.2f} aug {v['aug']:.2f} | MLOF2 head clean {v['mlof2_clean']:.2f} aug {v['mlof2_aug']:.2f}")
    best, step, it, t0 = -1e9, 0, iter(tl), time.time()
    run = {}
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
        if use_spring:
            degrade_spring_mv(b, rng)
        if not use_spring and rng.random() < args.p_pan:
            pan_rotate(b, rng, rng.choice([640, 896, 1088]))
        augment(b, rng)
        for g in opt.param_groups:
            g["lr"] = args.lr * sched(step)
        out, _, pair = forward(m, head, b, rng.random() < 0.5)
        loss, parts = losses(out, pair, b, args.lpips)
        loss = args.recon * loss
        if args.ce > 0:
            l_ce, share = oracle_ce(out, b["color_g"], args.ce_gap, args.ce_max)
            loss = loss + args.ce * l_ce
            parts["ce"], parts["ce_px"] = float(l_ce), share
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(head.parameters(), 2.0)
        opt.step()
        step += 1
        for k, x in parts.items():
            run[k] = run.get(k, 0) + x
        if step % 50 == 0:
            w = out["weights"].mean((0, 2, 3)).tolist()
            say(f"step {step} " + " ".join(f"{k} {x / 50:.4f}" for k, x in run.items()) +
                f" | weights mvA {w[0]:.2f} mvB {w[1]:.2f} ofA {w[2]:.2f} ofB {w[3]:.2f} | {(time.time() - t0) / 50:.2f} s/step")
            run, t0 = {}, time.time()
        if step % args.val == 0:
            v = validate(m, head, vl, dev)
            say(f"VAL step {step} clean {v['clean']:.2f} aug {v['aug']:.2f} | MLOF2 head clean {v['mlof2_clean']:.2f} aug {v['mlof2_aug']:.2f}")
            score = 0.5 * (v["clean"] + v["aug"])
            torch.save(head.state_dict(), os.path.join(args.out, "last.pt"))
            if score > best:
                best = score
                torch.save(head.state_dict(), os.path.join(args.out, "best.pt"))
    say("done")


if __name__ == "__main__":
    main()
