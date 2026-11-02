#!/bin/bash
                                                                                                           
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/nfru_mfg.log; mkdir -p /home/sh/nfru_mfg_out
echo "start $(date)" > $L
for N in 2 3 4; do
  MFG=$N VIGNETTE=online SAVE=/home/sh/nfru_mfg_out/m$N python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning >> $L
done
echo "done $(date)" >> $L
