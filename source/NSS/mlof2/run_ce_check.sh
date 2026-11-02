#!/bin/bash
                                                                                                 
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
H=$R/nfru_head_c2_ce/s2000_snapshot.pt
cp $R/nfru_head_c2_ce/last.pt $H
python dump_sn2_ppm.py $C $Q/k_new_ce2k $OF $H fp 2>&1 | grep -v -i warning
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_new_ce2k_relt $OF $H fp 2>&1 | grep -v -i warning
for f in $Q/k_new_ce2k*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f"; done
M="B_fp=k_new_B_fp B+rel_t=k_new_relt CE_2k=k_new_ce2k CE_2k+rel_t=k_new_ce2k_relt"
for a in self none; do ALIGN=$a python sn2_vs_fsr4.py $C $Q $M | grep -v '^sharp' ; done
python make_sn2_video.py $C $Q/sn2_ce2k_10fps.mp4 10 1 B+rel_t=ppm:$Q/k_new_relt CE_2k=ppm:$Q/k_new_ce2k CE_2k+rel_t=ppm:$Q/k_new_ce2k_relt 2>&1 | grep -v -i warning
b=sn2_ce2k_10fps.mp4; for i in 1 2 3; do cp $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b 2>/dev/null; cmp -s $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b && { echo copied $b; break; }; sleep 2; done
