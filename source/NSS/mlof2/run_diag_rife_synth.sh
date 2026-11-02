#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
V=/home/sh/spring_mlof/validation
OUT=/home/sh/mlof2_runs/diag_rife_synth.txt
: > $OUT
for c in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_01 SP_0004/crop_00; do
  python diag_rife_synth.py $V/$c.safetensors /home/sh/mlof2_runs/v2_of_menc/s1500.pt /home/sh/mlof2_runs/nfru_head_c2_ce3/s4000.pt 2>&1 | grep "foliage error" >> $OUT
done
echo ALLDONE >> $OUT
