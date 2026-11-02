#!/bin/bash
                                                                                                                      
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/nfru_head_c2_spring_fp_refine
L=$R/chain_head_refine.log
mkdir -p $O
python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps 4000 --lr 2e-4 --spring 0.3 --talign fp \
  --refine 1 --lpips 0.157 --init_head $R/nfru_head_c2_spring_fp/best.pt > $O/stdout.txt 2>&1
echo "=== $O" > $L
TALIGN=fp python diag_sn2_head.py $OF $O/best.pt $C 2>&1 | grep -v -i warning >> $L
python make_sn2_video.py $C /mnt/e/nss_VK/NSS/mlof2/videos/sn2_refine_10fps.mp4 10 1 \
  start_v2e=$R/v2_e/s16000_best.pt,$R/nfru_head_c2/best.pt,splat B_spring_fp=$OF,$R/nfru_head_c2_spring_fp/best.pt,fp \
  B_refine_lpips=$OF,$O/best.pt,fp 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
