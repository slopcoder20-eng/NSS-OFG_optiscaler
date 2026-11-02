#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
for c in /home/sh/mlof2_runs/v2_e/s16000_best.pt /home/sh/mlof2_runs/v2_of_spring_hand/s4000.pt; do
  echo "##### $c"; python diag_spring_levels.py $c 30 2>&1 | grep -v -i warning
done
