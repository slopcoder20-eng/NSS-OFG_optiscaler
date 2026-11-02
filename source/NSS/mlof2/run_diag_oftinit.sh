#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
V=/home/sh/spring_mlof/validation
OUT=$R/oft2/fol_init.txt
: > $OUT
for c in SP_0045/crop_00 SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_01 SP_0004/crop_00; do
  OFT_CKPT=$R/oft2/best.pt python diag_rife_synth.py $V/$c.safetensors $R/v2_of_menc/s1500.pt $R/nfru_head_c2_ce3/s4000.pt 2>&1 | grep -E "foliage|Error|error:" >> $OUT
done
echo ALLDONE >> $OUT
