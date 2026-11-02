#!/bin/bash
                                                                                                             
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/chain_vig_online.log
echo "start $(date)" > $L
VIGNETTE=online VIG_REF=$Q/vignette_V.npy RULE=rel_t python dump_sn2_ppm.py $C $Q/k_ce3_vigon $OF $H fp 2>&1 | grep -v -i warning >> $L
M="fsr4=k_fsr4_s1_t0_h0 ce3_hard=k_ce3_oneside ce3_vig_offline=k_ce3_vig ce3_vig_online=k_ce3_vigon"
echo "== band seam" >> $L; python diag_band_luma.py $C $Q $Q/offmask/m $M 2>&1 | grep -v -i warning | tail -n 4 >> $L
echo "== full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 9 >> $L
echo "== outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 9 >> $L
echo "done $(date)" >> $L
