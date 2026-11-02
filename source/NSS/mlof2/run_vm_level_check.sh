#!/bin/bash
                                                             
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
for ck in /home/sh/mlof2_runs/v2_e/s16000_best.pt rife; do
  echo "=== $ck"
  GAP=1 python diag_sn2_of.py $ck $C /tmp 16,24 2>&1 | grep -v Warning | sed -n '/viewmodel (median/,$p'
  mv /tmp/of_vs_mv_f16.png /tmp/vm_$(basename $ck .pt)_f16.png 2>/dev/null; mv /tmp/of_vs_mv_f24.png /tmp/vm_$(basename $ck .pt)_f24.png 2>/dev/null
done
