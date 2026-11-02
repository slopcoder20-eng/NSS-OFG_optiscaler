import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from lk_refine import lk_step, warp, luma
from model_v2 import resize_flow

dev = "cpu"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
t = torch.tensor([0.5], device=dev)

                                                    
gpu_la_s2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_002.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2)[:, :1].float()
gpu_lb_s2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_003.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2)[:, :1].float()

              
pt_la = luma(ca)
pt_lb = luma(cb)
pt_la_s2 = F.interpolate(pt_la, size=(544, 960), mode="area")
pt_lb_s2 = F.interpolate(pt_lb, size=(544, 960), mode="area")

                                              
fa_s2_in = torch.from_numpy(np.fromfile(f"{io_dir}/op_049.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                  
                                                        
              
gpu_fa_s2_it0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_050.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s2_it1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_051.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s2_it2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_052.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()

gpu_fa_s1_in  = torch.from_numpy(np.fromfile(f"{io_dir}/op_053.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it0 = torch.from_numpy(np.fromfile(f"{io_dir}/op_056.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it1 = torch.from_numpy(np.fromfile(f"{io_dir}/op_057.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()
gpu_fa_s1_it2 = torch.from_numpy(np.fromfile(f"{io_dir}/op_058.bin", dtype=np.float16).reshape(1, 1088, 1920, 2)).permute(0, 3, 1, 2).float()

                     
                                                                 
                                         
                                         
                                                                      
                                                        

