import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from lk_refine import lk_step

dev = "cpu"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

                                                      
la = torch.from_numpy(np.fromfile(f"{io_dir}/op_002.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2)[:, :1].float()
lb = torch.from_numpy(np.fromfile(f"{io_dir}/op_003.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2)[:, :1].float()

                                             
fa = torch.from_numpy(np.fromfile(f"{io_dir}/op_049.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()

                                                    
                              
                                               
g = json.load(open("/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/mlof2_oft.json"))
t59 = g["tensors"][59]
t60 = g["tensors"][60]
print("Tensor 59 (fa):", t59)
print("Tensor 60 (fb):", t60)

                                           
gpu_fa_it0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_050.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
print("gpu_fa_it0 mean abs:", gpu_fa_it0.abs().mean().item())
print("gpu_fa_in  mean abs:", fa.abs().mean().item())
print("GPU LK update delta mean abs:", (gpu_fa_it0 - fa).abs().mean().item())

