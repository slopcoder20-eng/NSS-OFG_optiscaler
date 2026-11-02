#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
Q=/home/sh/sn2_replay
python make_sn2_video.py /home/sh/sn2_cap/nfru_capture_19620640 /mnt/e/nss_VK/NSS/mlof2/videos/sn2_rule_vs_base_8fps.mp4 8 2 \
  base=ppm:$Q/k_n_base fuse2=ppm:$Q/k_n_fuse2 rule=ppm:$Q/k_n_rule0.02 fsr4=ppm:$Q/k_fsr4_s1_t0_h0 2>&1 | grep -v -i warn | tail -2
