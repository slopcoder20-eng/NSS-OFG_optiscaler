#!/bin/bash
                                                                                                              
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/chain_vignette.log
echo "start $(date)" > $L
VIGNETTE=$Q/vignette_V.npy RULE=rel_t python dump_sn2_ppm.py $C $Q/k_ce3_vig $OF $H fp 2>&1 | grep -v -i warning >> $L
VIGNETTE=$Q/vignette_V.npy VIG_OF=1 RULE=rel_t python dump_sn2_ppm.py $C $Q/k_ce3_vigof $OF $H fp 2>&1 | grep -v -i warning >> $L
M="fsr4=k_fsr4_s1_t0_h0 ce3_hard=k_ce3_oneside ce3_vig=k_ce3_vig ce3_vigof=k_ce3_vigof"
echo "== band seam" >> $L; python diag_band_luma.py $C $Q $Q/offmask/m $M 2>&1 | grep -v -i warning | tail -n 4 >> $L
echo "== full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
echo "== outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
python make_sn2_video.py $C $Q/sn2_fsr4_vs_vignette_10fps.mp4 10 1 FSR4=ppm:$Q/k_fsr4_s1_t0_h0 ce3_hard=ppm:$Q/k_ce3_oneside ce3_vig=ppm:$Q/k_ce3_vig ce3_vigof=ppm:$Q/k_ce3_vigof 2>&1 | grep -v -i warning >> $L
b=sn2_fsr4_vs_vignette_10fps.mp4; for i in 1 2 3; do cp $Q/$b videos/$b 2>/dev/null; cmp -s $Q/$b videos/$b && { echo copied $b >> $L; break; }; sleep 2; done
echo "done $(date)" >> $L
