#!/bin/bash
                                                                                                                     
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
H=$R/nfru_head_c2_ofprior/step0_prior.pt
for t in 0.08 0.12; do
  OVER_THR=$t python dump_sn2_ppm.py $C $Q/k_new_combo$t $OF $H fp 2>&1 | grep -v -i warning
done
for f in $Q/k_new_combo*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f"; done
python sn2_vs_fsr4.py $C $Q FSR4=k_fsr4_s1_t0_h0 over_0.08=k_new_over0.08 prior_step0=k_new_ofprior0 combo_0.08=k_new_combo0.08 combo_0.12=k_new_combo0.12
python make_sn2_video.py $C $Q/sn2_fsr4_combo_10fps.mp4 10 1 FSR4=ppm:$Q/k_fsr4_s1_t0_h0 over_0.08=ppm:$Q/k_new_over0.08 combo_0.08=ppm:$Q/k_new_combo0.08 2>&1 | grep -v -i warning
b=sn2_fsr4_combo_10fps.mp4; for i in 1 2 3; do cp $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b 2>/dev/null; cmp -s $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b && { echo copied $b; break; }; sleep 2; done
