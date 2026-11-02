"""Probe: can the OF encoder learn features that match foliage? Trains ONLY the FrameEncoder (from an OF checkpoint)
with a matching loss: at 1/4 and 1/8, InfoNCE over the r=4 cosine cost volume of B against A warped by the exact
Spring flow (the centre is the positive). Variants: 'shallow' = the encoder as is (f4 = one 1x1 on unshuffle(4)),
'deep' = + 2 residual 3x3 convs at 1/4 and at 1/8 (same channel counts). Scored with the diag_feat_match.py
retrieval (top-1 of the true match, foliage / all) on Spring validation crops.
  python probe_enc_match.py <OF ckpt> <shallow|deep> [steps=1000]"""
import sys, glob, random, time, os
import torch
from torch import nn
from torch.nn import functional as F
from safetensors import safe_open
from model_v2 import build_mlof2, warp, correlation, conv, leaky
from data_v2 import depth_feature

ck, variant = sys.argv[1:3]
STEPS = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
                                                                                                                
MW = dict(c=tuple(int(x) for x in os.environ.get("MENC_C", "24,48,96").split(",")), cout=int(os.environ.get("MENC_OUT", "64")))
dev = "cuda"
R, TAU = 4, 0.07
C = (2 * R + 1) ** 2 // 2


class Seq:
    def __init__(self, fn):
        self.fn = fn
        s = self.s
        self.T = s.get_slice("ground_truth_srgb8").get_shape()[0]
        self.H, self.W = s.get_slice("ground_truth_srgb8").get_shape()[-2:]
        self.hm = s.get_slice("motion_lr").get_shape()[-2]

    @property
    def s(self):                                                                                                             
        return safe_open(self.fn, "pt")

    def col(self, i):
        return self.s.get_slice("ground_truth_srgb8")[i:i + 1].to(dev).float() / 255.0

    def dep(self, i):
        s = self.s
        return F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].to(dev).float(), s.get_slice("zNear")[i:i + 1].to(dev).float().view(-1, 1, 1, 1)),
                             size=(self.H, self.W), mode="bilinear", align_corners=False)

    def flow_ba(self, a, b):
        nat = lambda x: -self.s.get_slice("motion_lr")[x].to(dev).float().flip(0)
        f = None                                                                                                   
        for x in range(b, a, -1):
            mm = nat(x)
            f = mm if f is None else f + warp(mm[None], f[None])[0]
        return F.interpolate(f[None] * (self.H / self.hm), size=(self.H, self.W), mode="bilinear", align_corners=False)


class DeepEnc(nn.Module):
    """FrameEncoder + residual 3x3 refinement of the 1/4 and 1/8 maps (last conv of each block starts at zero)."""
    def __init__(self, enc):
        super().__init__()
        self.enc = enc
        c = enc.CH
        self.r4 = nn.ModuleList(conv(c[4], c[4]) for _ in range(2))
        self.r8 = nn.ModuleList(conv(c[8], c[8]) for _ in range(2))
        for b in (self.r4, self.r8):
            nn.init.zeros_(b[-1].weight); nn.init.zeros_(b[-1].bias)

    def forward(self, color, depth):
        f = self.enc(color, depth)
        x4 = f[4] + self.r4[1](leaky(self.r4[0](f[4])))                                                              
        x8 = f[8] + self.r8[1](leaky(self.r8[0](f[8])))
        return {4: x4, 8: x8}


sd = torch.load(ck, map_location=dev); sd = sd.get("model", sd)
WIDE = {4: 64, 8: 128, 16: 96, 32: 128, 64: 256}
if variant == "wide":                                                                                           
    from model_v2 import FrameEncoder
    m = FrameEncoder(deep_fine=True, ch=WIDE).to(dev)
    enc = m
elif variant == "fpn":                                                                                                  
    from model_v2 import FrameEncoder
    m = FrameEncoder(deep_fine=True, fpn=True).to(dev)
    print("load:", m.load_state_dict({k[4:]: v for k, v in sd.items() if k.startswith("enc.")}, strict=False))
    if os.environ.get("RESUME_ENC"):                                                                      
        print("resume:", m.load_state_dict(torch.load(os.environ["RESUME_ENC"], map_location=dev)["enc_wide"]))
    enc = m
elif variant == "match":                                                                                                   
    from model_v2 import MatchEncoder
    m = MatchEncoder(**MW).to(dev)
    if os.environ.get("RESUME_ENC"):
        print("resume:", m.load_state_dict(torch.load(os.environ["RESUME_ENC"], map_location=dev)["menc"]))
    enc = m
elif variant == "matchctx":                                                                                          
    from model_v2 import MatchEncoder
    base = build_mlof2(sd).to(dev).eval(); base.load_state_dict(sd)
    for p_ in base.parameters(): p_.requires_grad_(False)

    class MatchCtx(nn.Module):
        def __init__(self):
            super().__init__()
            self.menc = MatchEncoder(ctx16=base.enc.CH[16], dil=(2, 4), **MW)

        def forward(self, color, depth):
            with torch.no_grad():
                f16 = base.enc(color, depth)[16]
            return self.menc(color, depth, f16)
    m = MatchCtx().to(dev)
    if os.environ.get("RESUME_ENC"):
        print("resume:", m.menc.load_state_dict(torch.load(os.environ["RESUME_ENC"], map_location=dev)["menc"]))
    enc = m
elif variant == "model":                                                                                               
    m = build_mlof2(sd, enc_deep=True).to(dev); print("load:", m.load_state_dict(sd, strict=False))
    enc = m.enc
else:
    m = build_mlof2(sd).to(dev); m.load_state_dict(sd)
    enc = m.enc if variant == "shallow" else DeepEnc(m.enc)
SAVE = sys.argv[4] if len(sys.argv) > 4 else None                                                              
enc = enc.to(dev).train()
fe = lambda c, d: {k: v for k, v in enc(c, d).items() if k in (4, 8)}
if os.environ.get("FREEZE_BASE"):                                                                                      
    for n, p in enc.named_parameters():                                                                                  
        p.requires_grad_(n.split(".")[0] in ("t8", "t4", "r4a", "r4b", "r8a", "r8b"))
    print("trainable:", [n for n, p in enc.named_parameters() if p.requires_grad])
opt = torch.optim.AdamW([p for p in enc.parameters() if p.requires_grad], lr=float(os.environ.get("LR", "2e-4")), weight_decay=1e-4)

train = [Seq(f) for f in sorted(glob.glob("/home/sh/spring_mlof/train/**/*.safetensors", recursive=True))]
val = [Seq(f"/home/sh/spring_mlof/validation/{f}.safetensors") for f in ("SP_0038/crop_00", "SP_0004/crop_00", "SP_0045/crop_01")]


def pair(sq, a, b, crop=None):
    ca, cb, da, db = sq.col(a), sq.col(b), sq.dep(a), sq.dep(b)
    ex = sq.flow_ba(a, b)
    if crop:
        h, w = crop
        y = random.randrange(0, sq.H - h + 1) // 8 * 8; x = random.randrange(0, sq.W - w + 1) // 8 * 8
        ca, cb, da, db, ex = (t[..., y:y + h, x:x + w] for t in (ca, cb, da, db, ex))
    else:
        ph = (sq.H + 63) // 64 * 64
        ca, cb, da, db, ex = (F.pad(t, (0, 0, 0, ph - sq.H), mode="replicate") for t in (ca, cb, da, db, ex))
    return [t.to(dev) for t in (ca, cb, da, db, ex)]


def cost(fa, fb, ex, k):
    g = F.avg_pool2d(ex, k) / k
    return correlation(fb[k], warp(fa[k], g), R)


def evaluate(tag):
    enc.eval(); out = []
    with torch.no_grad():
        for sq in val:
            z = {}
            for a in range(0, sq.T - 4, 16):                                                        
                ca, cb, da, db, ex = pair(sq, a, a + 4)
                r = 32
                sm = F.avg_pool2d(F.pad(ex, (r, r, r, r), mode="replicate"), 2 * r + 1, 1)
                reg = (F.max_pool2d(((ex - sm).norm(dim=1, keepdim=True) > 1.5).float(), 17, 1, 8) > 0.5).float()
                valid = torch.zeros_like(reg); valid[..., :sq.H, :] = 1
                fa, fb = fe(ca, da), fe(cb, db)
                for k in (4, 8):
                    t1 = (cost(fa, fb, ex, k)[0].argmax(0) == C).float()
                    vk = F.avg_pool2d(valid, k)[0, 0] > 0.99
                    for mk, msk in (("all", vk), ("fol", vk & (F.avg_pool2d(reg, k)[0, 0] > 0.5))):
                        v = z.setdefault((k, mk), [0.0, 0.0]); v[0] += float(t1[msk].sum()); v[1] += float(msk.sum())
            out.append(" ".join(f"1/{k} {mk} {100 * v[0] / max(v[1], 1):4.1f}" for (k, mk), v in z.items()))
    enc.train()
    print(f"EVAL {tag} | " + " | ".join(f"{sq_n}: {o}" for sq_n, o in zip(("SP0038c0", "SP0004c0", "SP0045c1"), out)), flush=True)


evaluate("step 0")
t0 = time.time(); run = 0.0
import os
GAME = float(os.environ.get("GAME", "0"))                                                                               
if GAME > 0:
    from data_v2 import WindowDataset
    from teacher_searaft import SeaRaftTeacher
    teacher = SeaRaftTeacher(dev)
    gl = torch.utils.data.DataLoader(WindowDataset(["forest15", "lyra15", "lyra17"], "train", crop=384, strides=[1, 2, 3, 4, 6, 8]),
                                     batch_size=int(os.environ.get("GB", "2")), shuffle=True, num_workers=4, drop_last=True, persistent_workers=True)
    git = iter(gl)
DISTILL = float(os.environ.get("DISTILL", "0"))                                                                     
if DISTILL > 0:
    if GAME <= 0:
        from teacher_searaft import SeaRaftTeacher
        teacher = SeaRaftTeacher(dev)
    tfnet = teacher.model.fnet
FEATD = float(os.environ.get("FEATD", "0"))                                                                              
if FEATD > 0:
    _w = torch.load(os.environ["PROJ"], map_location=dev)
    tproj = nn.Conv2d(_w["weight"].shape[1], _w["weight"].shape[0], 1).to(dev).eval(); tproj.load_state_dict(_w)
    for p_ in tproj.parameters(): p_.requires_grad_(False)
fd_run = 0.0
ngame = 0
kl_run = 0.0
for step in range(1, STEPS + 1):
    if GAME > 0 and random.random() < GAME:
        try:
            gb = next(git)
        except StopIteration:
            git = iter(gl); gb = next(git)
        ca, cb, da, db = (gb[k].to(dev) for k in ("color_a", "color_b", "depth_a", "depth_b"))
        if DISTILL > 0:                                                                                                
            ex = gb["geo_flow_ba"].to(dev); cons = 0.0
        else:
          with torch.no_grad():
            ex = teacher.flow_ba(cb, ca)[0]                             
            fab = teacher.flow_ba(ca, cb)[0]                                                     
            fbk = ex + warp(fab, ex)
            cons = (fbk.norm(dim=1, keepdim=True) < 0.5 + 0.03 * ex.norm(dim=1, keepdim=True)).float()
        ngame += 1
    else:
        sq = random.choice(train)
        n = random.choice((1, 2, 3, 4))
        a = random.randrange(0, sq.T - n)
        ca, cb, da, db, ex = pair(sq, a, a + n, (384, 512))
        for _ in range(int(os.environ.get("SPB", "1")) - 1):
            sq = random.choice(train); n = random.choice((1, 2, 3, 4)); a = random.randrange(0, sq.T - n)
            ca, cb, da, db, ex = (torch.cat((u, v), 0) for u, v in zip((ca, cb, da, db, ex), pair(sq, a, a + n, (384, 512))))
        cons = 1.0
                                                                                                        
    res = (warp(ca, ex) - cb).abs().mean(1, keepdim=True)
    h, w = ex.shape[-2:]
    gy, gx = torch.meshgrid(torch.arange(h, device=dev), torch.arange(w, device=dev), indexing="ij")
    inside = ((gx + ex[:, 0] >= 0) & (gx + ex[:, 0] <= w - 1) & (gy + ex[:, 1] >= 0) & (gy + ex[:, 1] <= h - 1)).float()[:, None]
    ok = (res < 0.06).float() * inside * cons
    fa, fb = fe(ca, da), fe(cb, db)
    loss = 0
    for k in (4, 8):
        lg = cost(fa, fb, ex, k) / TAU
        okk = (F.avg_pool2d(ok, k) > 0.99).float()[:, 0]
        ce = F.cross_entropy(lg, torch.full(lg.shape[:1] + lg.shape[2:], C, device=dev, dtype=torch.long), reduction="none")
        loss = loss + (ce * okk).sum() / okk.sum().clamp_min(1)
    if DISTILL > 0:
                                                                                                                   
                                                                                                             
        g = F.avg_pool2d(ex, 8) / 8
        g = g + (torch.rand_like(g) * 4 - 2)
        with torch.no_grad():
            ta, tb = tfnet(2 * ca - 1).float(), tfnet(2 * cb - 1).float()
            pt = torch.softmax(correlation(tb, warp(ta, g), 3) / TAU, 1)
        ls = torch.log_softmax(correlation(fb[8], warp(fa[8], g), 3) / TAU, 1)
        kl = (pt * (torch.log(pt.clamp_min(1e-8)) - ls)).sum(1).mean()
        if os.environ.get("DIST16"):                                                                                   
            g2 = F.avg_pool2d(g, 2) / 2
            with torch.no_grad():
                pt2 = torch.softmax(correlation(F.avg_pool2d(tb, 2), warp(F.avg_pool2d(ta, 2), g2), 2) / TAU, 1)
            ls2 = torch.log_softmax(correlation(F.avg_pool2d(fb[8], 2), warp(F.avg_pool2d(fa[8], 2), g2), 2) / TAU, 1)
            kl = kl + (pt2 * (torch.log(pt2.clamp_min(1e-8)) - ls2)).sum(1).mean()
        loss = loss + DISTILL * kl
        if FEATD > 0:
            with torch.no_grad():
                pa, pb = tproj(ta), tproj(tb)
            fd = 0.5 * ((1 - F.cosine_similarity(fa[8], pa, dim=1)).mean() + (1 - F.cosine_similarity(fb[8], pb, dim=1)).mean())
            loss = loss + FEATD * fd
            fd_run = 0.98 * fd_run + 0.02 * float(fd) if step > 1 else float(fd)
        kl_run = 0.98 * kl_run + 0.02 * float(kl) if step > 1 else float(kl)
    if os.environ.get("LRDECAY"):
        import math
        for g_ in opt.param_groups:
            g_["lr"] = float(os.environ.get("LR", "2e-4")) * 0.5 * (1 + math.cos(math.pi * step / STEPS))
    opt.zero_grad(); loss.backward(); opt.step()
    run = 0.98 * run + 0.02 * float(loss) if step > 1 else float(loss)
    if step % 100 == 0:
        print(f"step {step} loss {run:.3f} | {(time.time() - t0) / step:.2f} s/step | game steps {ngame} | kl {kl_run:.3f} | featd {fd_run:.3f}", flush=True)
    if step % int(os.environ.get("EVAL_EVERY", "500")) == 0:
        evaluate(f"step {step}")
        if SAVE:
            torch.save({"menc": m.state_dict()} if variant == "match" else {"menc": m.menc.state_dict()} if variant == "matchctx" else
                       {"enc_wide": m.state_dict(), "ch": WIDE} if variant == "wide" else
                       {"enc_wide": m.state_dict(), "ch": dict(m.CH), "fpn": True} if variant == "fpn" else m.state_dict(), SAVE.format(step=step) if "{step}" in SAVE else SAVE)
