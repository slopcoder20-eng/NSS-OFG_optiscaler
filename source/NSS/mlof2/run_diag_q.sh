#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
V=/home/sh/spring_mlof/validation
OUT=$R/oft5/fol_q.txt
: > $OUT
for c in SP_0038/crop_00 SP_0045/crop_00 SP_0038/crop_01 SP_0045/crop_01 SP_0004/crop_00; do
  png=""; [ "$c" = "SP_0038/crop_00" ] && png="/mnt/e/nss_VK/NSS/mlof2/docs_oft_compare_SP0038.png"
  SAVE_PNG=$png LK=1 OFT_Q=1 OFT_CKPT=$R/oft5/best.pt python diag_rife_synth.py $V/$c.safetensors $R/v2_of_menc/s1500.pt $R/nfru_head_c2_ce3/s4000.pt 2>&1 | grep -E "A ours|K no|L int8|E rife|int8 vs|saved|Error|error:" >> $OUT
done
echo ALLDONE >> $OUT
