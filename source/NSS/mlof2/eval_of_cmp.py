"""Same validation windows for several OF checkpoints: the regular set (spans 2..8) and the strided set
(3/4/5 real frames every 1..4 frames, as train_v2 --strides 1,2,3,4).
  python eval_of_cmp.py <ckpt> [<ckpt> ...]"""
import sys
import torch
from model_v2 import MLOF2, build_mlof2
from data_v2 import WindowDataset
from train_v2 import validate_of

dev = "cuda"
names = ["forest15", "lyra15", "lyra17"]
args = sys.argv[1:]
split = "validation"
if args[0] == "--train":                                                                                      
    split, args = "train", args[1:]
    import random
    random.seed(5)                                                                     
sets = {"regular": WindowDataset(names, split, crop=448, windows_per_file=8),
        "strided": WindowDataset(names, split, crop=448, windows_per_file=8, strides=(1, 2, 3, 4), seed=7)}
if split == "train":                                                                                           
    sets = {k: torch.utils.data.Subset(v, list(range(0, len(v), len(v) // 160))) for k, v in sets.items()}
for ck in args:
    sd = torch.load(ck, map_location=dev)
    m = build_mlof2(sd).to(dev)
    m.load_state_dict(sd.get("model", sd))
    for name, ds in sets.items():
        dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=False, num_workers=2)
        per, gain = validate_of(m, dl, dev, 40)
        print(f"{ck.split('/')[-2]:12s} {name:8s} gain {gain:+.2f} dB | " +
              " | ".join(f"s{k}: none {v[0]:.2f} MV {v[1]:.2f} OF {v[2]:.2f}" for k, v in per.items()), flush=True)
