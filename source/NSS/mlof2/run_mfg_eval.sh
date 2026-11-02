#!/bin/bash
                                                                
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
for g in 2 3 4; do python mfg_eval.py $C $OF $R/nfru_head_c2_spring_fp/best.pt fp $g 0.08 2>&1 | grep -v -i warning; done
