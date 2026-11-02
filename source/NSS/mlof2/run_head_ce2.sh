#!/bin/bash
                                                                                                                          
                                                                                                                      
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/nfru_head_c2_ce2
L=$R/chain_head_ce2.log
mkdir -p $O
echo "start $(date)" > $L
python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps 4000 --lr 2e-4 --spring 0.3 --talign fp \
  --cues 2 --ce 1.0 --recon 0.5 --ce_gap 0.75 --ce_max 40 --init_head $R/nfru_head_c2_spring_fp/best.pt > $O/stdout.txt 2>&1
cp $O/last.pt $O/s4000.pt
python eval_oracle_res.py $OF $R/nfru_head_c2_spring_fp/best.pt $O/s4000.pt 15 2>&1 | grep -v -i warning >> $L
python dump_sn2_ppm.py $C $Q/k_new_ce2 $OF $O/s4000.pt fp 2>&1 | grep -v -i warning >> $L
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_new_ce2_relt $OF $O/s4000.pt fp 2>&1 | grep -v -i warning >> $L
for f in $Q/k_new_ce2*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
M="B+rel_t=k_new_relt CE_2k+rel_t=k_new_ce2k_relt CE2=k_new_ce2 CE2+rel_t=k_new_ce2_relt FSR4_ref=k_fsr4_s1_t0_h0"
for a in self none; do ALIGN=$a python sn2_vs_fsr4.py $C $Q $M | grep -v '^sharp' >> $L; done
echo "done $(date)" >> $L
