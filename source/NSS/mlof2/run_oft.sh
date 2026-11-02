#!/bin/bash
                                                                                                                 
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
O=$R/${RUN:-oft1}
mkdir -p $O
python train_oft.py --mlof2 $R/v2_of_menc/s1500.pt --out $O --steps ${STEPS:-3000} --distill ${DIST:-0.003} --spring ${SPRING:-0.5} ${EXTRA} > $O/stdout.txt 2>&1
V=/home/sh/spring_mlof/validation
for c in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00; do
  OFT_CKPT=$O/best.pt python diag_rife_synth.py $V/$c.safetensors $R/v2_of_menc/s1500.pt $R/nfru_head_c2_ce3/s4000.pt 2>&1 | grep "foliage" >> $O/fol.txt
done
echo ALLDONE >> $O/fol.txt
