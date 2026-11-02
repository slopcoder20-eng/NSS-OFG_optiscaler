"""Spring validation EPE (pure OF, no seed / with seed) of a checkpoint, same metric as VAL-SPRING in train_v2.
  python eval_spring_epe.py <ckpt> [n_batches] [seed]"""
import sys
import torch
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from train_v2 import validate_epe

sd = torch.load(sys.argv[1], map_location="cuda")
m = build_mlof2(sd).cuda(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = len(sys.argv) > 3 and sys.argv[3] == "seed"                             
sv = WindowDataset(["spring"], "validation", crop=(1024, 1920), windows_per_file=16, strides=(1, 2, 4, 8, 12), seed=7)
dl = torch.utils.data.DataLoader(sv, batch_size=2, shuffle=False, num_workers=2)
ep, bins = validate_epe(m, dl, "cuda", int(sys.argv[2]) if len(sys.argv) > 2 else 40)
for mode, r in ep.items():
    print(f"{mode:4s} | " + " | ".join(f"{bins[i]:.0f}-{bins[i + 1] if bins[i + 1] < 1e8 else 'inf'}: EPE {v[0]:.2f} ratio {v[1]:.2f} (n{v[2]})"
                                     for i, v in r.items()))
