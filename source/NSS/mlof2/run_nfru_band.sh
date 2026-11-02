#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/nfru_band.log
echo "start $(date)" > $L
run() { echo "== $1" >> $L; shift; env "$@" VIGNETTE=online python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep -v '^pair' >> $L; }
run "2x chain" MFG=2
run "2x direct skip MV" MFG=2 MV_DIRECT=1
run "2x chain + trailing A" MFG=2 TRAIL_A=1
run "2x direct + trailing A" MFG=2 MV_DIRECT=1 TRAIL_A=1
run "4x chain" MFG=4
run "4x chain + trailing A" MFG=4 TRAIL_A=1
echo "done $(date)" >> $L
