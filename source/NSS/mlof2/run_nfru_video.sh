#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt; O=/home/sh/nfru_mfg_out
for N in 2 4; do
  MFG=$N VIGNETTE=online TRAIL_A=1 SAVE=$O/m${N}a python eval_nfru_mfg.py $D $OF $H 2>&1 | grep -v -i warning | grep "all\|split"
  MFG=$N python make_nfru_video.py $D $O/nfru_mfg${N}x.mp4 10 before=$O/m$N trailing_A=$O/m${N}a 2>&1 | grep -v -i warning
  b=nfru_mfg${N}x.mp4; for i in 1 2 3; do cp $O/$b videos/$b; cmp -s $O/$b videos/$b && { echo copied $b; break; }; sleep 2; done
done
