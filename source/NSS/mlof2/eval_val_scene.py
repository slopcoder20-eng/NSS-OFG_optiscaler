"""train_v2.validate() (clean + synthetic-layer augmented PSNR, gate c) on any dataset names, incl. the unseen
Electric Dreams scene ("ed512", validation crops only).  python eval_val_scene.py <ckpt> <names,comma> [windows_per_file]"""
import sys
import torch
import data_v2
from data_v2 import WindowDataset
from model_v2 import build_mlof2
from train_v2 import validate

data_v2.ROOTS.setdefault("ed512", "/mnt/e/NSSData/electric_dreams_5000_20260929/training_ready_512")
ck, names = sys.argv[1], sys.argv[2].split(",")
wpf = int(sys.argv[3]) if len(sys.argv) > 3 else 8
sd = torch.load(ck, map_location="cuda")
m = build_mlof2(sd).to("cuda")
m.load_state_dict(sd.get("model", sd))
ds = WindowDataset(names, "validation", crop=448, windows_per_file=wpf)
dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=0)
v = validate(m, dl, "cuda", 10 ** 9)
print(f"{names} windows {len(ds)} | clean PSNR out {v['clean']:.2f} blend {v['clean_blend']:.2f} | augmented out {v['out']:.2f} "
      f"blend {v['blend']:.2f} mvwarp {v['mvwarp']:.2f} | c wrongMV {v['c_wrong']:.3f} okMV {v['c_ok']:.3f}")
