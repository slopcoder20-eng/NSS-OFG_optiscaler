#!/bin/bash
                                                                                    
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640                                                                        
for ck in "$@"; do
  echo "=== $ck"
  GAP=1 python diag_sn2_of.py $ck $C /tmp 2>&1 | grep -v Warning | sed -n '/viewmodel split/,/photometric/p'
done
