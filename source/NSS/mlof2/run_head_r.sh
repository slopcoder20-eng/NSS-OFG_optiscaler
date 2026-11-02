#!/bin/bash
                                                                                                                    
                                                                             
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
OF=$R/v2_of_menc/s1500.pt
O=$R/${RUN:-nfru_head_r1}
mkdir -p $O
CHAIN_BORDER=1 P_MV_SMOOTH=${P_MV_SMOOTH:-0} python train_nfru_head_r.py --mlof2 $OF --out $O --variant c --accel 1 --steps ${STEPS:-2000} --lr 5e-4 --spring 0.5 \
  --talign fp --ce 1.0 --recon 0.5 --ce_gap 0.75 --ce_max 40 --val 500 --workers 2 --spring_batch 1 \
  --init_head $R/nfru_head_c2_ce3/s4000.pt > $O/stdout.txt 2>&1
cp $O/last.pt $O/s${STEPS:-2000}.pt
V=/home/sh/spring_mlof/validation
for c in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00; do
  echo "## headR $c" >> $O/fol.txt
  OF_CAP=2 MV_SMOOTH=32,1.5 MFG=4 python eval_foliage_rifeflow.py $V/$c.safetensors $OF $O/s${STEPS:-2000}.pt 2>&1 | grep -E "MFG|region|EPE|Error" >> $O/fol.txt
done
echo ALLDONE >> $O/fol.txt
