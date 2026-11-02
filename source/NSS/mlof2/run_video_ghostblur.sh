#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
for fps in 10 30; do
  python make_sn2_video.py $C $Q/sn2_fsr4_vs_ghostblur_${fps}fps.mp4 $fps $([ $fps = 30 ] && echo 3 || echo 1) FSR4=ppm:$Q/k_fsr4_s1_t0_h0 now=ppm:$Q/k_new_ce2_relt_inv1x4 blur3=ppm:$Q/k_gb3_1 blur5=ppm:$Q/k_gb5_1 2>&1 | grep -v -i warning
  b=sn2_fsr4_vs_ghostblur_${fps}fps.mp4; for i in 1 2 3; do cp $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b 2>/dev/null; cmp -s $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b && { echo copied $b; break; }; sleep 2; done
done
