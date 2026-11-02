#!/bin/bash
                                                                                                                      
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/train; O=/home/sh/mlof2_runs/band_data
mkdir -p $O
for seg in "0000 0:100 tr_a" "0000 100:200 val_b" "0000 200:218 tr_c" "0001 0:26 tr_d" "0001 26:126 tr_e" "0001 126:136 tr_f" "0002 0:34 tr_g" "0002 34:94 tr_h"; do
  set -- $seg
  [ "$SEG" ] && [ "$SEG" != "$3" ] && continue
  FRAMES=$2 python band_data.py $G/$1.safetensors $O/$3 2>&1 | grep -v -i warning | tail -1
done
