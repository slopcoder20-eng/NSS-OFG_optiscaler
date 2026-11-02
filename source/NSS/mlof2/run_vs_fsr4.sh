#!/bin/bash
                                                                                                                       
                                                                                                                     
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
python dump_sn2_ppm.py $C $Q/k_new_v2e_c2 $R/v2_e/s16000_best.pt $R/nfru_head_c2/best.pt splat 2>&1 | grep -v -i warning
python dump_sn2_ppm.py $C $Q/k_new_B_fp $OF $R/nfru_head_c2_spring_fp/best.pt fp 2>&1 | grep -v -i warning
python dump_sn2_ppm.py $C $Q/k_new_B_refine $OF $R/nfru_head_c2_spring_fp_refine/best.pt fp 2>&1 | grep -v -i warning
for f in $Q/*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f"; done
python sn2_vs_fsr4.py $C $Q FSR4=k_fsr4_s1_t0_h0 RIFE4.25=k_rife425 start_v2e_c2=k_new_v2e_c2 B_fp=k_new_B_fp B_refine_lpips=k_new_B_refine
