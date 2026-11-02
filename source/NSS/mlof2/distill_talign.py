"""Distil nfru_head.invert_t (exact backward fixed-point inversion to t) into talign_kpn.TAlignKPN (MAC form).
Flows: the frozen MLOF2 OF (B->A, full res) and the game MV of the window (Spring: exact flow, degraded game-like as
in train_nfru_head), with the quadratic trajectory from the previous pair on half of the MV samples. Teacher =
invert_t at full res (no gradient). Loss: L1 of to_A / to_B (px / 16) on teacher-arrived pixels + BCE of the hole.
--gt 1: Spring samples are supervised by the REAL position instead (exact G->A flow, exact G->B = invert_t of the exact
B->G flow at t = 0): the MV is Spring's exact flow (not degraded, no synthetic motion), MV and OF paths both target the
real t->A / t->B (per-pixel error capped at 4 px: the OF's own error is not the module's to fix), hole target = G
pixels no B pixel reaches. invert_t (with --gt the teacher only for forest/lyra) has ~3 px error at moving edges.
  python distill_talign.py --mlof2 <ckpt> --out <dir> [--steps 4000] [--spring 0.3] [--gt 1]"""
import argparse, math, os, random, time
import torch
from torch.nn import functional as F
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import to_dev
from nfru_head import invert_t
from talign_kpn import TAlignKPN
from train_nfru_head import degrade_spring_mv

ap = argparse.ArgumentParser()
ap.add_argument("--mlof2", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--steps", type=int, default=4000)
ap.add_argument("--lr", type=float, default=1e-3)
ap.add_argument("--spring", type=float, default=0.3)
ap.add_argument("--workers", type=int, default=6)
ap.add_argument("--arch", default="kpn", help="kpn = TAlignKPN (picks), net = TAlignNet (talign_net.py, regresses)")
ap.add_argument("--gt", type=int, default=0, help="1: Spring targets = real t->A / t->B (see the docstring)")
ap.add_argument("--spring_crop", type=str, default="1024,1920")
ap.add_argument("--spring_strides", type=str, default="1,2,4,8,12")
args = ap.parse_args()
os.makedirs(args.out, exist_ok=True)
dev = "cuda"
rng = random.Random(0); torch.manual_seed(0)
names = ["forest15", "lyra15", "lyra17"]
tl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=448, mv_res=True), batch_size=4, shuffle=True,
                                 num_workers=args.workers, drop_last=True, persistent_workers=True)
sl = torch.utils.data.DataLoader(WindowDataset(["spring"], "train", crop=tuple(int(x) for x in args.spring_crop.split(",")),
                                              strides=tuple(int(x) for x in args.spring_strides.split(",")), tri=bool(args.gt)),
                                 batch_size=2, shuffle=True, num_workers=3, prefetch_factor=2, drop_last=True,
                                 persistent_workers=True)
sd = torch.load(args.mlof2, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
for p in m.parameters():
    p.requires_grad_(False)
if args.arch == "net":
    from talign_net import TAlignNet
    net = TAlignNet().to(dev).train()
else:
    net = TAlignKPN().to(dev).train()
opt = torch.optim.AdamW(net.parameters(), lr=args.lr, weight_decay=1e-4)
sched = lambda s: 0.5 * (1 + math.cos(math.pi * min(s, args.steps) / args.steps)) * min(1.0, s / 200)
log = open(os.path.join(args.out, "log.txt"), "a")
say = lambda s: (print(s, flush=True), log.write(s + "\n"), log.flush())
say(f"distil invert_t -> TAlignKPN ({sum(p.numel() for p in net.parameters())} params) on {args.mlof2}")
it, its, step, t0, acc = iter(tl), iter(sl), 0, time.time(), {}


def wta(ta, tb, ok):
    """TAlignNet's two edge hypotheses at 1/4: the better one of each pixel takes an L1 (winner-take-all), so they
    specialise on the two layers instead of both regressing the average."""
    if getattr(net, "aux", None) is None:
        return 0.0
    h1, h2 = net.aux
    sz = h1.shape[-2:]
    d = lambda z: F.interpolate(z, size=sz, mode="nearest")
    tq, okq = torch.cat((d(ta), d(tb)), 1), d(ok)
    e1 = (h1 - tq).abs().clamp(max=8.0).sum(1, keepdim=True)
    e2 = (h2 - tq).abs().clamp(max=8.0).sum(1, keepdim=True)
    return (torch.minimum(e1, e2) * okq).sum() / okq.sum().clamp_min(1) / 16.0


def loss_of(f, dep, t, fbp, val):
    with torch.no_grad():
        ta, tb, th = invert_t(f, dep, t, fbp, val)
    sa, sb, sh = net(f, dep, t, fbp, val)
    ok = 1 - th
    l1 = (((sa - ta).abs() + (sb - tb).abs()).sum(1, keepdim=True) * ok).sum() / ok.sum().clamp_min(1) / 16.0
    l1 = l1 + 0.5 * wta(ta, tb, ok)
    bce = F.binary_cross_entropy(sh.clamp(1e-4, 1 - 1e-4), th)
    return l1, bce, float(((sa - ta).norm(dim=1, keepdim=True) * ok).sum() / ok.sum().clamp_min(1))


def loss_gt(f, dep, t, fbp, ga, gb, ghole):
    """Real-position targets (Spring --gt): L1 capped at 4 px per component, on G pixels some B pixel reaches."""
    sa, sb, sh = net(f, dep, t, fbp, None)
    ok = 1 - ghole
    e = ((sa - ga).abs().clamp(max=4.0) + (sb - gb).abs().clamp(max=4.0)).sum(1, keepdim=True)
    l1 = (e * ok).sum() / ok.sum().clamp_min(1) / 16.0 + 0.5 * wta(ga, gb, ok)
    bce = F.binary_cross_entropy(sh.clamp(1e-4, 1 - 1e-4), ghole)
    return l1, bce, float(((sa - ga).norm(dim=1, keepdim=True) * ok).sum() / ok.sum().clamp_min(1))


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
    gt = use_spring and args.gt
    if use_spring and not gt:
        degrade_spring_mv(b, rng)
    if not gt:                                                                                                      
        augment(b, rng)
    for g in opt.param_groups:
        g["lr"] = args.lr * sched(step)
    with torch.no_grad():
        fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
        pair = m.pair(fa, fb, b["mv_ba"], b["mv_valid"], b["color_a"], b["color_b"])
        H, W = b["color_a"].shape[-2:]
        of = pair["of_ba_full"] if pair.get("of_ba_full") is not None else \
            F.interpolate(pair["of_ba"], size=(H, W), mode="bilinear", align_corners=False) * (W / pair["of_ba"].shape[-1])
    t = b["t"]
    mv = b["mv_ba"] * b["mv_valid"]
    if gt:
        with torch.no_grad():
            _, gb, gh = invert_t(b["geo_flow_bg"], b["depth_b"], torch.zeros_like(t))                 
        ga = b["geo_flow_ga"]
        mbp = mv + warp(b["mv_ap"], mv) if rng.random() < 0.5 else None
        l_mv, b_mv, e_mv = loss_gt(mv, b["depth_b"], t, mbp, ga, gb, gh)
        l_of, b_of, e_of = loss_gt(of, b["depth_b"], t, None, ga, gb, gh)
    elif rng.random() < 0.5:                                                                                             
        s_ = rng.uniform(1.0, 3.0)
        off = torch.tensor([rng.uniform(-150, 150), rng.uniform(-80, 80)], device=dev).view(1, 2, 1, 1)
        mv, of = mv * s_ + off, of * s_ + off
        b["mv_ap"] = b["mv_ap"] * s_ + off
    if not gt:
        mbp = mv + warp(b["mv_ap"], mv) if rng.random() < 0.5 else None                                        
        l_mv, b_mv, e_mv = loss_of(mv, b["depth_b"], t, mbp, b["mv_valid"])
        l_of, b_of, e_of = loss_of(of, b["depth_b"], t, None, None)
    loss = l_mv + l_of + 0.1 * (b_mv + b_of)
    opt.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(net.parameters(), 2.0)
    opt.step()
    step += 1
    for k, v in (("l1", float(l_mv + l_of)), ("bce", float(b_mv + b_of)), ("epe_mv" + ("_gt" if gt else ""), e_mv),
                 ("epe_of" + ("_gt" if gt else ""), e_of)):
        acc.setdefault(k, []).append(v)
    if step % 50 == 0:
        say(f"step {step} " + " ".join(f"{k} {sum(v) / len(v):.4f}" for k, v in acc.items()) +
            (f" | tau_r {net.log_tau_r.exp().item():.3f} tau_d {net.log_tau_d.exp().item():.4f}" if hasattr(net, "log_tau_r") else "") +
            f" | {(time.time() - t0) / 50:.2f} s/step")
        acc, t0 = {}, time.time()
    if step % 1000 == 0 or step == args.steps:
        torch.save(net.state_dict(), os.path.join(args.out, f"s{step}.pt"))
        torch.save(net.state_dict(), os.path.join(args.out, "last.pt"))
say("done")
