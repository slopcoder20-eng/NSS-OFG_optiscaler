import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from model_v2 import warp

dev = "cpu"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)

                                                                 
gpu_fa = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_col = torch.from_numpy(np.fromfile(f"{io_dir}/op_059.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].float()

                                                                    
                                          
g = json.load(open("/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/mlof2_oft.json"))
op59 = g["ops"][59]
segs = [g["segs"][op59["seg0"] + i] for i in range(5)]
print("op 59 inputs (color_a, color_b, fa, fb, mask):", [s[0] for s in segs])
for s in segs:
    print(f"  t_{s[0]}: {g['tensors'][s[0]]['name']} c={g['tensors'][s[0]]['c']} s={g['tensors'][s[0]]['s']}")

                                                                                     
                          
                          
                            
                                   
mask_s1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_055.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2)[:, :1].float()
vis = torch.sigmoid(mask_s1)

                                             
pt_wa = warp(ca, gpu_fa)
print("pt_wa shape:", pt_wa.shape, "mean:", pt_wa.mean().item())

                                                                   

