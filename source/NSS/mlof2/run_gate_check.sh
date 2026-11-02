#!/bin/bash
                                                                                                         
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640                                                                        
for ck in "$@"; do
  for g in 1 2; do GAP=$g python diag_sn2_gate.py $ck $C 2>&1 | grep -v -i warning; done
done
