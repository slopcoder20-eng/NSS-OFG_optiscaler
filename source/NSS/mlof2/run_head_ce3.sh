#!/bin/bash
                                                                                                                      
                                                                                                             
                                                                                                        
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/nfru_head_c2_ce3
L=$R/chain_head_ce3.log
mkdir -p $O
echo "start $(date)" > $L
CHAIN_BORDER=1 python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps ${STEPS:-4000} --lr 2e-4 --spring 0.3 \
  --talign fp --cues 3 --ce 1.0 --recon 0.5 --ce_gap 0.75 --ce_max 40 --init_head $R/nfru_head_c2_ce2/s4000.pt > $O/stdout.txt 2>&1
cp $O/last.pt $O/s4000.pt
echo "train done $(date)" >> $L
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_ce3_oneside $OF $O/s4000.pt fp 2>&1 | grep -v -i warning >> $L
ONESIDE=0 RULE=rel_t python dump_sn2_ppm.py $C $Q/k_ce3_relt $OF $O/s4000.pt fp 2>&1 | grep -v -i warning >> $L
for f in $Q/k_ce3_*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
M="fsr4=k_fsr4_s1_t0_h0 old_harness=k_new_ce2_relt_inv1x4 ce2_oneside=k_bord_oneside ce3_oneside=k_ce3_oneside ce3_relt=k_ce3_relt"
echo "== full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
echo "== outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
