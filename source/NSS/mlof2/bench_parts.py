"""Relative cost of the deployed parts at 1920x1088, one generated frame, PyTorch on this GPU (NOT kernel-level
numbers: eager PyTorch launches, no fusion -- use for ratios / where the time goes, then hand off to the kernel side).
OF network (fp32 / fp16 autocast), t-alignment per path (splat_t2, invert_t, TAlignKPN), NFRU head AE (+HalfRefine).
Median of 10 after 3 warm-ups.
  python bench_parts.py <OF ckpt> <head ckpt>"""
import sys, time
import torch
from model_v2 import build_mlof2
from nfru_head import NfruHeadC2, splat_t2, invert_t
from talign_kpn import TAlignKPN

ck, hk = sys.argv[1], sys.argv[2]
dev = "cuda"
H, W = 1088, 1920
torch.manual_seed(0)
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
hsd = torch.load(hk, map_location=dev)
head = NfruHeadC2(arm_init=False, refine=any(k.startswith("ref.") for k in hsd)).to(dev).eval(); head.load_state_dict(hsd)
kpn = TAlignKPN().to(dev).eval()
ca, cb = torch.rand(1, 3, H, W, device=dev), torch.rand(1, 3, H, W, device=dev)
da, db = torch.rand(1, 1, H, W, device=dev) * 0.3, torch.rand(1, 1, H, W, device=dev) * 0.3
                                                                                               
y, x = torch.meshgrid(torch.arange(H, device=dev), torch.arange(W, device=dev), indexing="ij")
f = torch.stack((40 + 0.02 * (x - W / 2), 5 + 0.01 * (y - H / 2)), 0)[None].float()
sq = ((x > 700) & (x < 1100) & (y > 300) & (y < 700))[None, None]
f = torch.where(sq, torch.tensor([-120.0, 30.0], device=dev).view(1, 2, 1, 1), f)
t = torch.tensor([0.5], device=dev)
valid = torch.ones(1, 1, H, W, device=dev)


def bench(name, fn, n=10):
    for _ in range(3):
        fn()
    torch.cuda.synchronize()
    ts = []
    for _ in range(n):
        t0 = time.perf_counter(); fn(); torch.cuda.synchronize(); ts.append(time.perf_counter() - t0)
    ts.sort()
    print(f"  {name:40s} {1000 * ts[len(ts) // 2]:8.2f} ms", flush=True)


with torch.no_grad():
    print("OF network (both directions, as deployed)")
    fa, fb = m.enc(ca, da), m.enc(cb, db)
    bench("encoder, 1 frame (fp32)", lambda: m.enc(cb, db))
    bench("of_forward (fp32)", lambda: m.pair.of_forward(fa, fb, ca, cb))
    with torch.autocast("cuda", dtype=torch.float16):
        bench("encoder, 1 frame (fp16 autocast)", lambda: m.enc(cb, db))
        bench("of_forward (fp16 autocast)", lambda: m.pair.of_forward(fa, fb, ca, cb))
    print("t-alignment, ONE path (MV or OF); the head runs two")
    bench("splat_t2 (forward splat + 8 fill passes)", lambda: splat_t2(f, db, t, None, valid))
    bench("invert_t (17 starts x 6 iterations)", lambda: invert_t(f, db, t, None, valid))
    bench("invert_t, 1 start only", lambda: invert_t(f, db, t, None, valid, rings=()))
    bench("invert_t, 1 start, 3 iterations", lambda: invert_t(f, db, t, None, valid, iters=3, rings=()))
    bench("TAlignKPN (half res, 75 taps, fp32)", lambda: kpn(f, db, t, None, valid))
    with torch.autocast("cuda", dtype=torch.float16):
        bench("TAlignKPN (fp16 autocast)", lambda: kpn(f, db, t, None, valid))
    print("NFRU head (candidates + AE (+HalfRefine)), talign fp, including its two invert_t calls")
    of = f
    head.talign = "fp"
    bench("head C2 total, talign fp", lambda: head(t, of, ca, cb, da, db, f, None, None, valid, None, conf_q=None))
    head.talign = "splat"
    bench("head C2 total, talign splat", lambda: head(t, of, ca, cb, da, db, f, None, None, valid, None, conf_q=None))
    head.talign, head.talign_net = "kpn", kpn
    bench("head C2 total, talign kpn", lambda: head(t, of, ca, cb, da, db, f, None, None, valid, None, conf_q=None))
