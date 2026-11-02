import sys, os, torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, warp
from model_v2 import resize_flow

dev = "cpu"
ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
t = torch.tensor([0.5], device=dev)

net_half4 = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
net_half4.load_state_dict(torch.load(ckpt_path, map_location=dev))
net_half4.eval()

H2, W2 = 544, 960
ca_h = F.interpolate(ca, size=(H2, W2), mode="area")
cb_h = F.interpolate(cb, size=(H2, W2), mode="area")

                                
of_ab_s16 = resize_flow(of_ab, 68, 120)
of_ba_s16 = resize_flow(of_ba, 68, 120)
tt = t.view(1, 1, 1, 1)
f_ta_16 = -(1 - tt) * tt * of_ab_s16 + tt * tt * of_ba_s16
f_tb_16 = (1 - tt) ** 2 * of_ab_s16 - tt * (1 - tt) * of_ba_s16

                                                  
fab = resize_flow(of_ab, 544, 960)
fba = resize_flow(of_ba, 544, 960)
f_ta_half = -(1 - tt) * tt * fab + tt * tt * fba
f_ta_pt_16 = resize_flow(f_ta_half, 68, 120)

diff = (f_ta_16 - f_ta_pt_16).abs().max().item()
print("Max diff at level 16 init:", diff)

