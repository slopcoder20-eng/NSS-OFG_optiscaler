#!/bin/bash
                                                                                                                   
                                                                                                                          
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
L=$R/chain_heads_spring.log
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
until grep -q '^done' $R/chain_heads_new.log 2>/dev/null; do sleep 60; done
echo "start $(date)" > $L
for a in splat fp; do
  O=$R/nfru_head_c2_spring_$a
  mkdir -p $O
  python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps 6000 --spring 0.3 --talign $a > $O/stdout.txt 2>&1
  echo "=== head $O (talign $a)" >> $L
  TALIGN=$a python diag_sn2_head.py $OF $O/best.pt $C 2>&1 | grep -v -i warning >> $L
done
echo "done $(date)" >> $L
