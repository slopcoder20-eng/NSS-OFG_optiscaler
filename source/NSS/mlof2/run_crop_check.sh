#!/bin/bash
                                                                             
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
for cr in 0 448; do
  echo "=== v2_e GAP=1 CROP=$cr"
  GAP=1 CROP=$cr python diag_sn2_of.py /home/sh/mlof2_runs/v2_e/s16000_best.pt $C /tmp 2>&1 | grep -v Warning
done
