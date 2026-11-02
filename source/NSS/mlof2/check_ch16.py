"""List every conv / linear and whether its in/out channels are multiples of 16."""
import torch
from torch import nn
from model_v2 import MLOF2
m = MLOF2()
bad = []
for name, mod in m.named_modules():
    if isinstance(mod, nn.Conv2d):
        ci, co = mod.in_channels, mod.out_channels
        ok = ci % 16 == 0 and co % 16 == 0
        print(f"{'ok ' if ok else 'BAD'} {name:28s} {ci:4d} -> {co:4d}  k{mod.kernel_size[0]}")
        if not ok:
            bad.append((name, ci, co))
    elif isinstance(mod, nn.Linear):
        print(f"lin {name:28s} {mod.in_features:4d} -> {mod.out_features:4d}  (tiny MLP for t, CPU/scalar)")
print("not multiples of 16:", len(bad))
