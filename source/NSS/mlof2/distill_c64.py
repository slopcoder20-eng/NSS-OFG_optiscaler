"""Narrow 1/64 level by distillation (2026-10-31). Student = teacher OF checkpoint with a narrower 1/64 encoder map
(c64) and 1/64 Update (width w64, n64 body convs); everything else copied from the teacher and FROZEN. Loss: the
student's 1/64 outputs (flow L1, conf/occ/ctx MSE) and the 1/32 and final 1/4 flows (L1, these carry the convex
upsampling mask) follow the teacher's. Game windows + Spring crops, no labels.
  python distill_c64.py <teacher ckpt> <out dir> [steps=4000] [c64=128] [w64=128] [n64=2]"""
import sys, os, math, random, time, copy, torch
from torch.nn import functional as F
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import validate_of, validate_epe, to_dev

tck, out = sys.argv[1:3]
STEPS = int(sys.argv[3]) if len(sys.argv) > 3 else 4000
c64, w64, n64 = (int(x) for x in (sys.argv[4:7] if len(sys.argv) > 6 else (128, 128, 2)))
dev = "cuda"; os.makedirs(out, exist_ok=True)
torch.manual_seed(0); rng = random.Random(0)
sd = torch.load(tck, map_location=dev); sd = sd.get("model", sd)
T = build_mlof2(sd).to(dev).eval(); T.load_state_dict(sd); T.pair.seeded = False
for p in T.parameters(): p.requires_grad_(False)
wd = [T.pair.upd[str(lv)].inp.weight.shape[0] for lv in T.pair.LEVELS]
S = build_mlof2(sd, c64=c64, n64=n64, of_widths=[w64] + wd[1:]).to(dev); S.pair.seeded = False
own = S.state_dict()
keep = {k: v for k, v in sd.items() if k in own and own[k].shape == v.shape and not k.startswith(("enc.e64", "pair.upd.64."))}
print("copied", len(keep), "tensors; new:", sorted({k.rsplit(".", 1)[0] for k in own if k not in keep}), flush=True)
S.load_state_dict(keep, strict=False)
train_p = [p for n, p in S.named_parameters() if n.startswith(("enc.e64", "pair.upd.64."))]
for n, p in S.named_parameters(): p.requires_grad_(n.startswith(("enc.e64", "pair.upd.64.")))
cnt = lambda m, pre: sum(v.numel() for k, v in m.state_dict().items() if k.startswith(pre))
print(f"1/64 params teacher {(cnt(T, 'enc.e64') + cnt(T, 'pair.upd.64.')) / 1e6:.3f} M -> student "
      f"{(cnt(S, 'enc.e64') + cnt(S, 'pair.upd.64.')) / 1e6:.3f} M", flush=True)
opt = torch.optim.AdamW(train_p, lr=5e-4, weight_decay=1e-4)
names, strides = ["forest15", "lyra15", "lyra17"], (1, 2, 3, 4, 6, 8)
drop = ("color_p", "depth_p", "mv_ap", "color_g", "mv_ba")
gl = torch.utils.data.DataLoader(WindowDataset(names, "train", crop=448, strides=strides, drop=drop), batch_size=4,
                                 shuffle=True, num_workers=3, drop_last=True, persistent_workers=True, pin_memory=True)
sl = torch.utils.data.DataLoader(WindowDataset(["spring"], "train", crop=(1024, 1920), strides=(1, 2, 4, 8, 12), drop=drop),
                                 batch_size=2, shuffle=True, num_workers=3, drop_last=True, persistent_workers=True, pin_memory=True)
vb = torch.utils.data.DataLoader(WindowDataset(names, "validation", crop=448, windows_per_file=8, strides=strides, seed=7), batch_size=4, num_workers=2)
sv = torch.utils.data.DataLoader(WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7),
                                 batch_size=2, num_workers=2)
gi, si = iter(gl), iter(sl)


def nxt(it, ld):
    try:
        return next(it), it
    except StopIteration:
        it = iter(ld); return next(it), it


def val(tag):
    S.eval()
    with torch.no_grad():
        for nm, m in (("teacher", T), ("student", S)) if tag == "start" else (("student", S),):
            _, gain = validate_of(m, vb, dev, 20)
            ep, bins = validate_epe(m, sv, dev, 20)
            r = ep.get("none") or next(iter(ep.values()))
            print(f"VAL {tag} {nm}: VAL-OF-BIG {gain:+.2f} dB | Spring " + " | ".join(
                f"{bins[i]:.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf'} {v[0]:.2f}" for i, v in r.items()), flush=True)
    S.train()


if STEPS >= 100:
    val("start")
t0, run = time.time(), {}
for step in range(1, STEPS + 1):
    spring = rng.random() < 0.5
    if spring:
        b, si = nxt(si, sl)
    else:
        b, gi = nxt(gi, gl)
    b = to_dev(b, dev)
    if True:                                                                                                      
        for k, src in (("color_p", "color_a"), ("color_g", "color_a"), ("depth_p", "depth_a"), ("mv_ba", "geo_flow_ba")):
            if k not in b: b[k] = b[src].clone()
        if "mv_ap" not in b: b["mv_ap"] = torch.zeros_like(b["geo_flow_ba"])
    augment(b, rng)
    for g in opt.param_groups:
        g["lr"] = 5e-4 * 0.5 * (1 + math.cos(math.pi * step / STEPS)) * min(1.0, step / 200)
    ca, cb, da, db = b["color_a"], b["color_b"], b["depth_a"], b["depth_b"]
    with torch.no_grad():
        to = T.pair.of_forward(T.enc(ca, da), T.enc(cb, db), ca, cb)
    so = S.pair.of_forward(S.enc(ca, da), S.enc(cb, db), ca, cb)
    l64 = (so[64]["of"] - to[64]["of"]).abs().mean()
    lx = sum(F.mse_loss(so[64][k], to[64][k]) for k in ("conf", "occ", "ctx"))
    l32 = (so[32]["of"] - to[32]["of"]).abs().mean()
    l4 = (so[4]["of"] - to[4]["of"]).abs().mean()
    loss = l64 + 0.5 * lx + l32 + 0.25 * l4
    opt.zero_grad(set_to_none=True); loss.backward()
    torch.nn.utils.clip_grad_norm_(train_p, 2.0); opt.step()
    for k, v in (("loss", loss), ("of64", l64), ("aux64", lx), ("of32", l32), ("of4", l4)):
        run[k] = 0.98 * run.get(k, float(v)) + 0.02 * float(v)
    if step % 100 == 0:
        print(f"step {step} " + " ".join(f"{k} {v:.4f}" for k, v in run.items()) + f" | {(time.time() - t0) / step:.2f} s/step", flush=True)
    if step % 1000 == 0 or step == STEPS:
        torch.save(S.state_dict(), os.path.join(out, f"s{step}.pt"))
        if STEPS >= 100 and (step % 2000 == 0 or step == STEPS):
            val(f"step {step}")
