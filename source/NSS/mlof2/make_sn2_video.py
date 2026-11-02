"""SN2 capture as a video: every odd frame f-1 is generated at t = 0.5 from the real frames f-2 and f (the skip
protocol of diag_sn2_head / eval_sn2_skip), even frames are the real ones. Panels side by side: real | model 1 |
model 2 ..., second row: |generated - real| x4 on the generated frames (black on real ones). Written with ffmpeg
(imageio-ffmpeg binary) at the given fps, the clip looped `loops` times.
  python make_sn2_video.py <capture dir> <out.mp4> <fps> <loops> <label=ckpt,head,talign | label=ppm:prefix> ..."""
import os, sys, subprocess
import numpy as np
import torch
from torch.nn import functional as F
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
from model_v2 import build_mlof2, warp
from data_v2 import chain_backward
from nfru_head import NfruHeadC2, load_head_c2

cap, outp, fps, loops = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
specs = [a.split("=", 1) for a in sys.argv[5:]]
NM = int(os.environ.get("MFG", "2"))                                                                          
dev = "cuda"
DW, DH, RW, RH, RP, PH = 1920, 1080, 1129, 636, 1132, 1088
PW, PHh = 960, 540                                              
meta = {}
for line in open(os.path.join(cap, "meta.txt")):
    p = line.split()
    if len(p) > 2 and p[2] == "display":
        meta[int(p[1])] = (float(p[p.index("mvScale") + 1]), float(p[p.index("mvScale") + 2]))


def colour(fr):
    a = np.fromfile(os.path.join(cap, f"{fr:03d}_hudless.bin"), dtype=np.uint32).reshape(DH, DW)
    return torch.from_numpy(np.stack([((a >> s) & 1023) for s in (0, 10, 20)], 0).astype(np.float32) / 1023.0)


def depth(fr):
    d = np.fromfile(os.path.join(cap, f"{fr:03d}_depth.bin"), dtype=np.float32).reshape(RH, RP)[:, :RW]
    d = torch.from_numpy(d.copy()).clamp_min(1e-7)
    return F.interpolate(((torch.log2(1.0 / d) / 16.0).clamp(0, 1))[None, None], size=(DH, DW), mode="bilinear", align_corners=False)[0]


def mv_one(fr):
    m = np.fromfile(os.path.join(cap, f"{fr:03d}_mv.bin"), dtype=np.float16).reshape(RH, RW, 2).astype(np.float32)
    m = torch.from_numpy(m).permute(2, 0, 1)
    ok = (torch.isfinite(m).all(0, keepdim=True) & (m.abs().amax(0, keepdim=True) < 1000)).float()
    m = torch.where(ok > 0, m, torch.zeros_like(m)) * torch.tensor(meta[fr]).view(2, 1, 1) * torch.tensor([DW / RW, DH / RH]).view(2, 1, 1)
    return F.interpolate(m[None], size=(DH, DW), mode="bilinear", align_corners=False)[0], F.interpolate(ok[None], size=(DH, DW), mode="nearest")[0]


pad = lambda x: F.pad(x, (0, 0, 0, PH - DH), mode="replicate")
frames = sorted(meta)
n_fr = max(frames) + 1
real = {f: colour(f) for f in range(n_fr)}


def generate(ck, hk, talign):
    """{odd f-1: generated frame (3, DH, DW) cpu} for the skip pairs (f-2, f)."""
    sd = torch.load(ck, map_location=dev)
    m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False
    head = load_head_c2(hk, dev)
    head.talign = talign
    out, prev = {}, None
    with torch.no_grad():
        for f in range(2, n_fr, 2):
            ca, cb = pad(real[f - 2])[None].to(dev), pad(real[f])[None].to(dev)
            da, db = pad(depth(f - 2))[None].to(dev), pad(depth(f))[None].to(dev)
            m1, v1 = mv_one(f); m0, v0 = mv_one(f - 1)
            mv = pad(chain_backward([m1, m0]))[None].to(dev)
            mvv = pad(v1 * (warp(v0[None], m1[None])[0] > 0.999).float())[None].to(dev)
            pair = m.pair(m.enc(ca, da), m.enc(cb, db), mv, mvv, ca, cb)
            of_q = pair["of_ba_full"] if pair.get("of_ba_full") is not None else pair["of_ba"]
            pm, po, pv = prev if prev is not None else (None, None, None)
            hc = head(torch.tensor([0.5], device=dev), of_q, ca, cb, da, db, mv * mvv, pm, po, mvv, pv, conf_q=pair["conf"][:1])
            prev = (mv * mvv, of_q, mvv)
            out[f - 1] = hc["color"][0, :, :DH].clamp(0, 1).cpu()
    del m, head
    torch.cuda.empty_cache()
    return out


def load_ppm(prefix):
    """{odd f-1: frame} from replay-format PPMs <prefix>_<f:03d>_1.ppm (e.g. the FSR4 frame-generation outputs)"""
    out = {}
    for f in range(NM, n_fr, NM):
        for k in range(1, NM):
            im = np.asarray(Image.open(f"{prefix}_{f:03d}_{k}.ppm").convert("RGB")).astype(np.float32) / 255.0
            out[f - NM + k] = torch.from_numpy(im).permute(2, 0, 1)
    return out


gens = []
for label, spec in specs:
    print("generating", label, flush=True)
    if spec.startswith("ppm:"):                                           
        gens.append((label, load_ppm(spec[4:])))
        continue
    ck, hk, ta = spec.split(",")
    gens.append((label, generate(ck, hk, ta)))
font = ImageFont.load_default()


def panel(img, text):
    im = Image.fromarray((img.permute(1, 2, 0).numpy() * 255 + 0.5).astype(np.uint8)).resize((PW, PHh), Image.BILINEAR)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 16), fill=(0, 0, 0))
    d.text((4, 2), text, fill=(255, 255, 0), font=font)
    return np.asarray(im)


cols = 1 + len(gens)
W_out, H_out = PW * cols, PHh * 2
ff = imageio_ffmpeg.get_ffmpeg_exe()
proc = subprocess.Popen([ff, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W_out}x{H_out}", "-r", str(fps), "-i", "-",
                         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-preset", "medium", outp],
                        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
seq = list(range(1, n_fr - 1)) if NM == 2 else list(range(0, (n_fr - 1) // NM * NM + 1))
for _ in range(loops):
    for f in seq:
        gen_frame = f % NM != 0
        top = [panel(real[f], f"real {f:03d}")]
        bot = [np.zeros((PHh, PW, 3), np.uint8)]
        for label, g in gens:
            img = g[f] if gen_frame else real[f]
            top.append(panel(img, f"{label} {f:03d}" + (" GENERATED" if gen_frame else " real")))
            if gen_frame:
                e = ((img - real[f]).abs().mean(0, keepdim=True) * 4).clamp(0, 1).expand(3, -1, -1)
                bot.append(panel(e, f"{label} |gen - real| x4  mean {float((img - real[f]).abs().mean()) * 255:.2f}"))
            else:
                bot.append(np.zeros((PHh, PW, 3), np.uint8))
        proc.stdin.write(np.concatenate([np.concatenate(top, 1), np.concatenate(bot, 1)], 0).tobytes())
proc.stdin.close(); proc.wait()
print("wrote", outp, f"{len(seq) * loops} frames at {fps} fps, {W_out}x{H_out}")
