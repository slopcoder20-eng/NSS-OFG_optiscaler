#!/bin/bash
                                                                                                                            
                                                                                                                   
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/nfru_head_c2_ce
L=$R/chain_head_ce.log
mkdir -p $O
echo "start $(date)" > $L
python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps 4000 --lr 3e-4 --spring 0.3 --talign fp \
  --cues 1 --freeze_mid 1 --ce 1.0 --recon 0.5 --init_head $R/nfru_head_c2_spring_fp/best.pt > $O/stdout.txt 2>&1
python dump_sn2_ppm.py $C $Q/k_new_ce $OF $O/best.pt fp 2>&1 | grep -v -i warning >> $L
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_new_ce_relt $OF $O/best.pt fp 2>&1 | grep -v -i warning >> $L
for f in $Q/k_new_ce*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
M="B_fp=k_new_B_fp rel_t=k_new_relt ce_head=k_new_ce ce_head+rel_t=k_new_ce_relt"
for a in self none; do ALIGN=$a python sn2_vs_fsr4.py $C $Q $M | head -n 8 >> $L; done
echo "=== validation sets, head B" >> $L
python eval_sel.py $OF $R/nfru_head_c2_spring_fp/best.pt fp 20 2>&1 | grep -v -i warning >> $L
echo "=== validation sets, CE head" >> $L
python eval_sel.py $OF $O/best.pt fp 20 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
