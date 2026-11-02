#!/bin/bash
                                                                                                                  
                                                                                   
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
L=$R/chain_heads_new.log
run() {                                    
  mkdir -p $2
  python train_nfru_head.py --mlof2 $1 --out $2 --variant c --accel 1 --steps 6000 > $2/stdout.txt 2>&1
  echo "=== head $2 on $1" >> $L
  python diag_sn2_head.py $1 $2/best.pt $C 2>&1 | grep -v -i warning >> $L
}
echo "start $(date)" > $L
run $R/v2_of_spring_prop4b_gtvis/s3000.pt $R/nfru_head_c2_prop4bgtvis
run $R/pm2_init.pt $R/nfru_head_c2_pm2init
echo "=== baseline: v2_e + nfru_head_c2" >> $L
python diag_sn2_head.py $R/v2_e/s16000_best.pt $R/nfru_head_c2/best.pt $C 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
