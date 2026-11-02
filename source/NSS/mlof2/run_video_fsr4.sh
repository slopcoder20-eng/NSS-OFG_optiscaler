#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
for fps in 10 30; do
  python make_sn2_video.py $C $Q/sn2_fsr4_vs_B_${fps}fps.mp4 $fps $([ $fps = 30 ] && echo 3 || echo 1) FSR4=ppm:$Q/k_fsr4_s1_t0_h0 B_spring_fp=ppm:$Q/k_new_B_fp start_v2e=ppm:$Q/k_new_v2e_c2 2>&1 | grep -v -i warning
done
