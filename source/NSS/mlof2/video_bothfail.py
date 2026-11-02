"""2x2 comparison video of eval_nfru_mfg.py SAVE dumps (generated frames at t, same pair order):
  python video_bothfail.py <out.mp4> <fps> <label=prefix> x4   (prefix as given to SAVE; label "GT" uses <prefix>_gt_*)"""
import glob, re, subprocess, sys
import numpy as np
import cv2
import os
import imageio_ffmpeg

CROP = [int(v) for v in os.environ['CROP'].split(',')] if os.environ.get('CROP') else None                 

out, fps = sys.argv[1], sys.argv[2]
panels = [a.split("=", 1) for a in sys.argv[3:7]]


def frames(prefix, gt):
    pat = f"{prefix}_gt_*.ppm" if gt else f"{prefix}_[0-9]*.ppm"
    fs = sorted(glob.glob(pat), key=lambda p: [int(x) for x in re.findall(r"_(\d+)_(\d+)\.ppm$", p)[0]])
    return fs


lists = [frames(p, lb == "GT") for lb, p in panels]
n = min(len(l) for l in lists)
print("frames per panel", [len(l) for l in lists], "->", n)
W, H = 960, 540
cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{2 * W}x{2 * H}", "-r", fps,
       "-i", "-", "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p", out]
pr = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
for i in range(n):
    tiles = []
    for (lb, _), l in zip(panels, lists):
        im = cv2.imread(l[i])
        if CROP:                                                                                        
            x0, y0, cw, ch = CROP
            im = im[y0:y0 + ch, x0:x0 + cw]
        im = cv2.resize(im, (W, H), interpolation=cv2.INTER_AREA)
        cv2.rectangle(im, (0, 0), (12 + 15 * len(lb), 34), (0, 0, 0), -1)
        cv2.putText(im, lb, (6, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (255, 255, 255), 2, cv2.LINE_AA)
        tiles.append(im)
    pr.stdin.write(np.vstack((np.hstack(tiles[:2]), np.hstack(tiles[2:]))).tobytes())
pr.stdin.close(); pr.wait()
print("wrote", out)
