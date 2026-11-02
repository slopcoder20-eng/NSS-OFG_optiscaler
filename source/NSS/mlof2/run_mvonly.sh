#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
MVONLY=1 python dump_sn2_ppm.py $C $Q/k_new_B_mvonly $OF $R/nfru_head_c2_spring_fp/best.pt fp 2>&1 | grep -v -i warning
for f in $Q/k_new_B_mvonly_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f"; done
python sn2_vs_fsr4.py $C $Q FSR4=k_fsr4_s1_t0_h0 B_fp=k_new_B_fp B_mvonly=k_new_B_mvonly
python make_sn2_video.py $C $Q/sn2_fsr4_B_mvonly_10fps.mp4 10 1 FSR4=ppm:$Q/k_fsr4_s1_t0_h0 B_fp=ppm:$Q/k_new_B_fp B_mvonly=ppm:$Q/k_new_B_mvonly 2>&1 | grep -v -i warning
b=sn2_fsr4_B_mvonly_10fps.mp4; for i in 1 2 3; do cp $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b 2>/dev/null; cmp -s $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b && { echo copied $b; break; }; sleep 2; done
