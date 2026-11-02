"""Spring (Mehl et al., CVPR 2023; CC BY 4.0, doi:10.18419/darus-3376) -> MLOF2 training files, read straight from
the downloaded zips (no extraction). Left camera, train split. Per sequence files <out>/<split>/<seq>/crop_NN.safetensors, CHUNK frames each (bounds peak RAM):
  ground_truth_srgb8 (T,3,1080,1920) uint8   the rendered frame (display-referred sRGB; data_v2 decodes to linear)
  depth (T,1,540,960) f32, zNear (T,1)       d = 1 - zNear / z  (data_v2: z = zNear / (1 - d)); z = fx * 0.065 / disparity
  motion (T,2,540,960) f16                    exact backward flow of frame x (x -> x-1) as an engine MV, (y, x) order,
  motion_lr (T,2,540,960) f16                 negated like the Arm NSS captures (data_v2 uses -m.flip(0)); frame 0 = 0
  camera_cut (T,1)
Spring ground truth lives on a 2x grid (3840x2160); [::2, ::2] gives the 1080p grid (spring_utils), [::4, ::4] 540p.
Flow values are 1080p pixels. NaN (invalid) -> 0 flow; depth NaN -> far.
  python convert_spring.py <raw dir with zips> <out dir> [val seqs, e.g. 0045,0046,0047] [only seqs]"""
import io, os, sys, zipfile
import numpy as np
import h5py
from PIL import Image
from safetensors.numpy import save_file                                                                    

raw, out = sys.argv[1], sys.argv[2]
val = set(sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] else set()
only = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
ZN, BASE = 0.05, 0.065
CHUNK = 100
zf = lambda n: zipfile.ZipFile(os.path.join(raw, n))
frames, flows, disps, cams = zf("train_frame_left.zip"), zf("train_flow_BW_left.zip"), zf("train_disp1_left.zip"), zf("train_cam_data.zip")
names = lambda z, key: sorted(n for n in z.namelist() if key in n and not n.endswith("/"))
fr_all = names(frames, "frame_left/")
seqs = sorted({n.split("/")[2] for n in fr_all})
print(f"{len(seqs)} sequences: {seqs}")
for seq in seqs:
    if only and seq not in only:
        continue
    split = "validation" if seq in val else "train"
    od = os.path.join(out, split, f"SP_{seq}")
    if os.path.exists(os.path.join(od, ".done")):                                                         
        print("skip", seq); continue
    fr = [n for n in fr_all if f"/{seq}/" in n]
    T = len(fr)
    intr = np.loadtxt(io.StringIO(cams.read(f"spring/train/{seq}/cam_data/intrinsics.txt").decode())).reshape(-1, 4)
    os.makedirs(od, exist_ok=True)
    for c0 in range(0, T, CHUNK):
        n_c = min(CHUNK, T - c0)
        if n_c < 8 and c0 > 0:                                                                   
            break
        col = np.zeros((n_c, 3, 1080, 1920), np.uint8)
        dep = np.zeros((n_c, 1, 540, 960), np.float32)
        mot = np.zeros((n_c, 2, 540, 960), np.float16)
        for j in range(n_c):
            i = c0 + j; n = fr[i]
            num = int(n[-8:-4])                                                               
            col[j] = np.asarray(Image.open(io.BytesIO(frames.read(n))).convert("RGB")).transpose(2, 0, 1)
            with h5py.File(io.BytesIO(disps.read(f"spring/train/{seq}/disp1_left/disp1_left_{num:04d}.dsp5")), "r") as h:
                d = np.asarray(h["disparity"])[::4, ::4]
            fx = intr[min(i, len(intr) - 1), 0]
            z = np.where(np.isfinite(d) & (d > 1e-6), fx * BASE / np.maximum(d, 1e-6), 1e4)
            dep[j, 0] = 1.0 - ZN / np.maximum(z, ZN)
            if j > 0:                                                                                                     
                with h5py.File(io.BytesIO(flows.read(f"spring/train/{seq}/flow_BW_left/flow_BW_left_{num:04d}.flo5")), "r") as h:
                    f = np.asarray(h["flow"])[::4, ::4] * 0.5                                                   
                f = np.nan_to_num(f, nan=0.0)
                mot[j] = np.stack((-f[..., 1], -f[..., 0]), 0)                                                    
        t = {"ground_truth_srgb8": col, "depth": dep, "zNear": np.full((n_c, 1), ZN, np.float32), "motion": mot,
             "motion_lr": mot.copy(), "camera_cut": np.zeros((n_c, 1), np.float32)}
        save_file(t, os.path.join(od, f"crop_{c0 // CHUNK:02d}.safetensors"))
        del col, dep, mot, t
        print(f"  {seq} frames {c0}-{c0 + n_c - 1} saved", flush=True)
    open(os.path.join(od, ".done"), "w").close()
    print(f"{seq}: {T} frames -> {od}", flush=True)
