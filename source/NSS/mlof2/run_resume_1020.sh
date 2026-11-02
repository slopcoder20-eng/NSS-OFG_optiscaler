#!/bin/bash
                                                                                                                  
                                                    
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
L=$R/chain_resume_1020.log
echo "start $(date)" > $L
echo "=== (1) refine head" >> $L
TALIGN=fp python diag_sn2_head.py $OF $R/nfru_head_c2_spring_fp_refine/best.pt $C 2>&1 | grep -v -i warning >> $L
python make_sn2_video.py $C /mnt/e/nss_VK/NSS/mlof2/videos/sn2_refine_10fps.mp4 10 1 \
  start_v2e=$R/v2_e/s16000_best.pt,$R/nfru_head_c2/best.pt,splat B_spring_fp=$OF,$R/nfru_head_c2_spring_fp/best.pt,fp \
  B_refine_lpips=$OF,$R/nfru_head_c2_spring_fp_refine/best.pt,fp 2>&1 | grep -v -i warning >> $L
echo "video1 done $(date)" >> $L
mkdir -p $R/talign_kpn_v1
python distill_talign.py --mlof2 $OF --out $R/talign_kpn_v1 --steps 4000 > $R/talign_kpn_v1/stdout.txt 2>&1
echo "=== (3) SN2 candidates fp vs kpn (distilled), head B" >> $L
TALIGN_CKPT=$R/talign_kpn_v1/last.pt bash run_talign_cmp.sh $OF $R/nfru_head_c2_spring_fp/best.pt "fp kpn" >> $L 2>&1
echo "done $(date)" >> $L
