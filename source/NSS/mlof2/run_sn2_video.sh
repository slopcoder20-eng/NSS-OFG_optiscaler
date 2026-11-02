#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
O=/mnt/e/nss_VK/NSS/mlof2/videos
mkdir -p $O
M="start_v2e=$R/v2_e/s16000_best.pt,$R/nfru_head_c2/best.pt,splat A_spring_splat=$R/v2_of_spring_prop4b_gtvis/s3000.pt,$R/nfru_head_c2_spring_splat/best.pt,splat B_spring_fp=$R/v2_of_spring_prop4b_gtvis/s3000.pt,$R/nfru_head_c2_spring_fp/best.pt,fp"
python make_sn2_video.py $C $O/sn2_compare_30fps.mp4 30 3 $M 2>&1 | grep -v -i warning
python make_sn2_video.py $C $O/sn2_compare_10fps.mp4 10 1 $M 2>&1 | grep -v -i warning
