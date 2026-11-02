#!/bin/bash
                                                                                             
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
echo "=== v2_e (no seed)"
GAP=1 python diag_sn2_of.py /home/sh/mlof2_runs/v2_e/s16000_best.pt $C /tmp 2>&1 | grep -v Warning | sed -n '/per OF level/,/photometric/p'
echo "=== v2_of_seed best (SEED=1)"
GAP=1 SEED=1 python diag_sn2_of.py /home/sh/mlof2_runs/v2_of_seed/best.pt $C /tmp 2>&1 | grep -v Warning
