#!/bin/bash
                                                                                                                    
                                                                              
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
OUT=/home/sh/mlof2_runs/v2_of_cut3
mkdir -p $OUT
setsid nohup python train_v2.py --out $OUT --batch 4 --workers 6 --log 50 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 \
  --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --lr 5e-5 --steps 2000 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 --val 500 --val_batches 40 \
  --init /home/sh/mlof2_runs/v2_of_spring_prop4b_gtvis/s3000.pt > $OUT/stdout.txt 2>&1 &
sleep 5; echo started
