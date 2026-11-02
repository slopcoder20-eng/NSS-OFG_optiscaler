#!/bin/bash
                                                                          
                                                                                                                
                                                                                       
                                                                                                            
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O1=$R/nfru_head_free_s1
O2=$R/nfru_head_free_ce2
L=$R/chain_head_free.log
mkdir -p $O1 $O2
echo "start $(date)" > $L
python train_nfru_head.py --mlof2 $OF --out $O1 --variant c --accel 1 --steps 8000 --lr 5e-4 --spring 0.3 --talign fp \
  --cues 2 --arm_init 0 > $O1/stdout.txt 2>&1
cp $O1/last.pt $O1/s8000.pt
echo "stage 1 done $(date)" >> $L
python train_nfru_head.py --mlof2 $OF --out $O2 --variant c --accel 1 --steps 4000 --lr 2e-4 --spring 0.3 --talign fp \
  --cues 2 --ce 1.0 --recon 0.5 --ce_gap 0.75 --ce_max 40 --arm_init 0 --init_head $O1/best.pt > $O2/stdout.txt 2>&1
cp $O2/last.pt $O2/s4000.pt
echo "stage 2 done $(date)" >> $L
for h in "s1:$O1/best.pt" "ce2:$O2/s4000.pt"; do n=${h%%:*}; ck=${h#*:}
  RULE=rel_t python dump_sn2_ppm.py $C $Q/k_free_${n}_relt $OF $ck fp 2>&1 | grep -v -i warning >> $L; done
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_new_ce2_relt_inv1x4d $OF $R/nfru_head_c2_ce2/s4000.pt fp 2>&1 | grep -v -i warning >> $L
for f in $Q/k_free_*_*.ppm $Q/k_new_ce2_relt_inv1x4d_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
python sn2_vs_fsr4.py $C $Q fsr4=k_fsr4_s1_t0_h0 arm_ce2=k_new_ce2_relt_inv1x4d free_s1=k_free_s1_relt free_ce2=k_free_ce2_relt 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
