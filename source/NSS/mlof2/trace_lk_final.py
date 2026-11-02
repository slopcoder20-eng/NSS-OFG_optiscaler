import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from lk_refine import lk_step, warp, luma
from model_v2 import resize_flow

dev = "cpu"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
t = torch.tensor([0.5], device=dev)

la = luma(ca)
lb = luma(cb)
la_s2 = F.interpolate(la, size=(544, 960), mode="area")
lb_s2 = F.interpolate(lb, size=(544, 960), mode="area")

                                                    
fa_s2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_049.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                                             
                                                                                                      
                  
                        
gpu_fa_s2_it0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_050.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s2_it1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_051.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s2_it2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_052.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()

gpu_fa_s1_in  = torch.from_numpy(np.fromfile(f"{io_dir}/op_053.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_056.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_057.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()

                                                                                   
pt_fa_s1_bil = resize_flow(gpu_fa_s2_it2, 1088, 1920)
print(f"resize_bil op_053 vs PyTorch resize_flow: max={(gpu_fa_s1_in - pt_fa_s1_bil).abs().max().item():.5f}, mean={(gpu_fa_s1_in - pt_fa_s1_bil).abs().mean().item():.5f}")

                    
                     
gpu_col = torch.from_numpy(np.fromfile(f"{io_dir}/op_059.bin", dtype=np.float16).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].float()
                                              
gpu_m1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_055.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2)[:, :1].float()
v = torch.sigmoid(gpu_m1)

                                                             
                                                               
                                                                  
wa_pt = warp(ca, gpu_fa_s1_it2)
print("PyTorch wa min/max:", wa_pt.min().item(), wa_pt.max().item())

