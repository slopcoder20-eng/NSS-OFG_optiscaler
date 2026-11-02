#!/bin/bash
                                                                                                                       
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/talign_kpn_v1
L=$R/chain_talign_kpn.log
until grep -q '^done' $R/chain_head_refine.log 2>/dev/null; do sleep 60; done
mkdir -p $O
echo "start $(date)" > $L
python distill_talign.py --mlof2 $OF --out $O --steps 4000 > $O/stdout.txt 2>&1
echo "=== SN2 candidates: fp vs kpn (distilled $O/last.pt), head B" >> $L
TALIGN_CKPT=$O/last.pt bash run_talign_cmp.sh $OF $R/nfru_head_c2_spring_fp/best.pt "fp kpn" >> $L 2>&1
echo "done $(date)" >> $L
