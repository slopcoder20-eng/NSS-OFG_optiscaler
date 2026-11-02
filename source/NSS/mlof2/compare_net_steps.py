import os, sys, torch
import torch.nn.functional as F
import numpy as np

sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from oft_block import OFTNet
from model_v2 import resize_flow, warp

dev = "cpu"
ckpt_path = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
io_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"

ca = torch.from_numpy(np.fromfile(f"{io_dir}/color_a.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
cb = torch.from_numpy(np.fromfile(f"{io_dir}/color_b.f32", dtype=np.float32).reshape(1, 1088, 1920, 4)).permute(0, 3, 1, 2)[:, :3].to(dev)
of_ab = torch.from_numpy(np.fromfile(f"{io_dir}/of_ab.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
of_ba = torch.from_numpy(np.fromfile(f"{io_dir}/of_ba.f32", dtype=np.float32).reshape(1, 136, 240, 2)).permute(0, 3, 1, 2).to(dev)
t = torch.tensor([0.5], device=dev)
tt = t.view(1, 1, 1, 1)

net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3)).to(dev)
net.load_state_dict(torch.load(ckpt_path, map_location=dev))
net.blocks = net.blocks[:3]
net.SCALES = (8, 4, 2)
net.eval()

with torch.no_grad():
    ref3 = net(t, ca, cb, of_ab, of_ba)

                                       
                           
H, W = 1088, 1920
fab, fba = resize_flow(of_ab, H, W), resize_flow(of_ba, H, W)
f_ta = -(1 - tt) * tt * fab + tt * tt * fba
f_tb = (1 - tt) ** 2 * fab - tt * (1 - tt) * fba
mask = torch.zeros(1, 1, H, W)

for blk, s in zip(net.blocks, net.SCALES):
    h, w = H // s, W // s
    a_s = F.interpolate(ca, size=(h, w), mode="area")
    b_s = F.interpolate(cb, size=(h, w), mode="area")
    fa_s = resize_flow(f_ta, h, w)
    fb_s = resize_flow(f_tb, h, w)
    m_s = F.interpolate(mask, size=(h, w), mode="area")
    wa, wb = warp(a_s, fa_s), warp(b_s, fb_s)
    x = torch.cat((wa, wb, (wa - wb).abs().mean(1, keepdim=True) * 4, fa_s / 16.0, fb_s / 16.0, m_s / 4.0, tt.expand(1, 1, h, w)), 1)
    d = blk(x)
    f_ta = f_ta + resize_flow(d[:, 0:2], H, W)
    f_tb = f_tb + resize_flow(d[:, 2:4], H, W)
    mask = mask + F.interpolate(d[:, 4:5], size=(H, W), mode="bilinear", align_corners=False)

print("Difference between ref3['f_ta'] and step-by-step f_ta:", (ref3["f_ta"] - f_ta).abs().max().item())

                              
                                     
                                    
                                                      
                                           
                                                        
                                                      
                                           
                                                        
                                                      
                                           
                                                        

                                                             
fa_eng = -(1 - tt) * tt * of_ab + tt * tt * of_ba
for blk, s in zip(net.blocks, (8, 4, 2)):
    h, w = H // s, W // s
    a_s = F.interpolate(ca, size=(h, w), mode="area")
    b_s = F.interpolate(cb, size=(h, w), mode="area")
    wa = warp(a_s, fa_eng)
    wb = warp(b_s, fa_eng)                    
         
                                                         

