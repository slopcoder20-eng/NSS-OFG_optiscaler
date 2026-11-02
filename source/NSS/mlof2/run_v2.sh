#!/bin/bash
                                                                              
                                                                                                                 
                             
OUT=${1:-/home/sh/mlof2_runs/v2_a}
shift
mkdir -p "$OUT"
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
setsid nohup python train_v2.py --out "$OUT" --steps 60000 --batch 4 --workers 10 --log 50 --val 2000 "$@" \
    > "$OUT/stdout.txt" 2>&1 < /dev/null &
echo "started pid $! -> $OUT/log.txt"
