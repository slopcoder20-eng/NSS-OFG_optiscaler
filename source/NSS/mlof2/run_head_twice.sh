#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640                                                                        
for k in 1 2; do python diag_sn2_head.py $1 /home/sh/mlof2_runs/nfru_head_c2/best.pt $C 2>&1 | grep -E 'vm |64-128'; nvidia-smi >/dev/null 2>&1; done
