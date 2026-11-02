#!/bin/bash
                                                                                                                           
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
H=$R/nfru_head_c2_spring_fp/best.pt
for cfg in "8,24 6" "8 6" " 6" " 3"; do
  set -- $cfg
  if [ $# = 1 ]; then r=""; it=$1; else r=$1; it=$2; fi
  echo "##### rings '$r' iters $it"
  INV_RINGS="$r" INV_ITERS=$it TALIGN=fp python diag_sn2_head.py $OF $H $C 2>&1 | grep -v -i warning | grep -E 'invert_t|vm |bg .MV. (64|128|256)'
done
