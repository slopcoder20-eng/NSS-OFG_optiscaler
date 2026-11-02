#!/bin/bash
                                                                                                                     
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640                                                                        
for ck in "$@"; do
  for g in 1 2; do
    echo "=== $ck GAP $g"
    GAP=$g python diag_sn2_of.py $ck $C /tmp 2>&1 | grep -v -i warning | sed -n '1,8p;/viewmodel split/,$p'
  done
  python diag_sn2_head.py $ck /home/sh/mlof2_runs/nfru_head_c2/best.pt $C 2>&1 | grep -v -i warning
done
