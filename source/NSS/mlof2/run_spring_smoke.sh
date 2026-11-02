#!/bin/bash
                                                                                                 
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
[ -e /home/sh/spring_mlof ] || ln -s /mnt/f/Spring/mlof /home/sh/spring_mlof
python train_v2.py --out /tmp/spring_smoke --smoke 20 --batch 4 --workers 6 --stage of --seeded 1 --p_pan 0 \
  --strides 1,2,3,4,6,8 --spring 1.0 --init /home/sh/mlof2_runs/v2_of_seed/best.pt 2>&1 | grep -v Warning
