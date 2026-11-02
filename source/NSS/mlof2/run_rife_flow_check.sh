#!/bin/bash
                                                                                      
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
GAP=1 python diag_sn2_of.py rife $C /tmp 2>&1 | grep -v Warning
