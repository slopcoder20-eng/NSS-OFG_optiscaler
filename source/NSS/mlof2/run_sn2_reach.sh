#!/bin/bash
                                                                                                    
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/sn2_reach.log
echo "start $(date)" > $L
for RR in x; do for AG in 1 2; do
  TRAIL_CAM=$AG VIGNETTE=online VIG_MODEL=quad3 RULE=rel_t python dump_sn2_ppm.py $C $Q/k_tcam$AG $OF $H fp 2>&1 | grep -v -i warning | grep -v "vignette frame" | tail -1 >> $L
done; done
M="fsr4=k_fsr4_s1_t0_h0 base=k_abl_none trailcam=k_tcam1 frontcam=k_tcam2"
echo "== full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 9 >> $L
echo "== outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 9 >> $L
echo "done $(date)" >> $L
