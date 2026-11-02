#!/bin/bash
                                                                                                     
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
CAP=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
CK=${1:-/home/sh/mlof2_runs/v2_b/last.pt}
TAG=${2:-b24k}
for C in 1 0; do
  FORCE_C=$C timeout 1500 python eval_sn2_skip.py "$CK" "$CAP" /mnt/e/nss_VK/NSS/harness/nfru_dx12/replay/k_mlof2_${TAG}_c$C 0 40 > /tmp/forcec_$C.log 2>&1
  echo "c=$C exit $? frames $(grep -c '^frame' /tmp/forcec_$C.log)"
done
