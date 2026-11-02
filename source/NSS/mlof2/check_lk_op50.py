import os, sys, math, json
import torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from lk_refine import lk_refine, lk_step, warp

dev = "cpu"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

                     
                                                      
                                                            
import json
g = json.load(open("/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/mlof2_oft.json"))
print("op 49 out:", g["ops"][49]["out"], g["tensors"][g["ops"][49]["out"]]["name"])
print("op 50 kind:", g["ops"][50]["kind"], g["ops"][50]["name"], "inputs:", g["ops"][50]["ip"], "segs:", g["segs"][g["ops"][50]["seg0"]:g["ops"][50]["seg0"]+g["ops"][50]["nseg"]])

                    
fa_in = torch.from_numpy(np.fromfile(f"{io_dir}/op_049.bin", dtype=np.float16).reshape(1, 544, 960, 2)).permute(0, 3, 1, 2).float()
                                         
                           
                                                                                            
                                                       
                                                        
lk_segs = g["segs"][g["ops"][50]["seg0"]:g["ops"][50]["seg0"]+g["ops"][50]["nseg"]]
print("LK segs (tensor_ids):", [s[0] for s in lk_segs])
for s in lk_segs:
    print(f"  tensor {s[0]}: {g['tensors'][s[0]]['name']} c={g['tensors'][s[0]]['c']} s={g['tensors'][s[0]]['s']}")

