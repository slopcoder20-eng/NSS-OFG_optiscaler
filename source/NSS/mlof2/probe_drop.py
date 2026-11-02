import torch
from data_v2 import WindowDataset
d = ("color_p", "depth_p", "mv_ap", "color_g", "mv_ba")
st = WindowDataset(["spring"], "train", crop=(1024, 1920), strides=(1, 2, 4, 8, 12), drop=d)
x = st[3]; print("spring keys", sorted(x), "MB", round(sum(v.numel() * v.element_size() for v in x.values()) / 1e6, 1))
ot = WindowDataset(["lyra15"], "train", crop=448, strides=(1, 2, 3, 4, 6, 8), drop=d)
x = ot[3]; print("old keys", sorted(x), "MB", round(sum(v.numel() * v.element_size() for v in x.values()) / 1e6, 1))
