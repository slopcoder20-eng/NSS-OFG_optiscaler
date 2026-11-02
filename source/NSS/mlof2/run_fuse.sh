#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
O=$R/${RUN:-fuse1}
mkdir -p $O
P_MV_SMOOTH=${P_MV_SMOOTH:-0.4} python train_fuse.py --mlof2 $R/v2_of_menc/s1500.pt --oft $R/oft5/best.pt --out $O --steps ${STEPS:-2000} ${EXTRA} > $O/stdout.txt 2>&1
