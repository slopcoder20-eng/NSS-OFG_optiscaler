"""NFRU-format capture as an MFG video: real frames every N-th frame, generated frames (ppm sets from eval_nfru_mfg.py
SAVE=<prefix>) in between. Panels: real | set 1 | set 2 ..., second row |gen - real| x4 on generated frames.
Same display look as eval_nfru_mfg.py (exposure from the pair's A).
  MFG=N python make_nfru_video.py <nfru safetensors> <out.mp4> <fps> <label=prefix> ..."""
import os, sys, subprocess
import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFont
from safetensors import safe_open
import imageio_ffmpeg
from data_v2 import TONE_CURVES, srgb_encode, quantize

fn, outp, fps = sys.argv[1], sys.argv[2], float(sys.argv[3])
sets = [a.split("=", 1) for a in sys.argv[4:]]
NM = int(os.environ.get("MFG", "2"))
s = safe_open(fn, "pt")
T = s.get_slice("rgb_linear").get_shape()[0]
OFF = 0
if os.environ.get("FRAMES"):
    OFF, _b = (int(x) for x in os.environ["FRAMES"].split(":")); T = _b - OFF
fd = os.open(fn, os.O_RDONLY)
lin = lambda i: s.get_slice("rgb_linear")[OFF + i:OFF + i + 1].float()


def display(x, ref):
    lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
    e = 0.18 / torch.exp(torch.log(lum(ref)).mean())
    return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * e).clamp(0, 1)), 8)[0]


PW, PHh = 960, 540
font = ImageFont.load_default()


def panel(img, text):
    im = Image.fromarray((img.permute(1, 2, 0).numpy() * 255 + 0.5).astype(np.uint8)).resize((PW, PHh), Image.BILINEAR)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 16), fill=(0, 0, 0))
    d.text((4, 2), text, fill=(255, 255, 0), font=font)
    return np.asarray(im)


last = (T - 1) // NM * NM
cols = 1 + len(sets)
proc = subprocess.Popen([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{PW * cols}x{PHh * 2}",
                         "-r", str(fps), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", outp],
                        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for g in range(0, last + 1):
    k = g % NM
    real = display(lin(g), lin(g - k))
    gen = k != 0 and g >= NM
    top = [panel(real, f"real {g:03d}")]
    bot = [np.zeros((PHh, PW, 3), np.uint8)]
    for label, pre in sets:
        if gen:
            im = torch.from_numpy(np.asarray(Image.open(f"{pre}_{g - k + NM:03d}_{k}.ppm").convert("RGB")).astype(np.float32) / 255).permute(2, 0, 1)
            e = (im - real).abs().mean(0, keepdim=True)
            top.append(panel(im, f"{label} {g:03d} GENERATED t={k}/{NM}"))
            bot.append(panel((e * 4).clamp(0, 1).expand(3, -1, -1), f"{label} |gen - real| x4  mean {float(e.mean()) * 255:.2f}"))
        else:
            top.append(panel(real, f"{label} {g:03d} real")); bot.append(np.zeros((PHh, PW, 3), np.uint8))
    proc.stdin.write(np.concatenate([np.concatenate(top, 1), np.concatenate(bot, 1)], 0).tobytes())
    os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
proc.stdin.close(); proc.wait()
print("wrote", outp, last + 1, "frames")
