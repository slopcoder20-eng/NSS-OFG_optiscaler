#!/bin/bash
                                                                                                          
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
H=$R/nfru_head_c2_spring_fp/best.pt
RULE=rel python dump_sn2_ppm.py $C $Q/k_new_rel $OF $H fp 2>&1 | grep -v -i warning
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_new_relt $OF $H fp 2>&1 | grep -v -i warning
for f in $Q/k_new_rel*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f"; done
python sn2_vs_fsr4.py $C $Q FSR4=k_fsr4_s1_t0_h0 B_fp=k_new_B_fp B_mvonly=k_new_B_mvonly over_0.08=k_new_over0.08 rel=k_new_rel rel_temporal=k_new_relt
python eval_sel.py $OF $H fp 20 2>&1 | grep -v -i warning
