#!/bin/bash
                                                                               
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
M="start_v2e=k_new_v2e_c2 B_fp=k_new_B_fp B_mvonly=k_new_B_mvonly over_0.08=k_new_over0.08 combo_0.08=k_new_combo0.08 rel=k_new_rel rel_t=k_new_relt FSR4_ref=k_fsr4_s1_t0_h0"
for a in self none; do ALIGN=$a python sn2_vs_fsr4.py $C $Q $M | head -n 12; done
