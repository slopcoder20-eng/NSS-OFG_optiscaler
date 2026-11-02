#!/bin/bash
                                                                                                                       
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/chain_mfg.log
export VIGNETTE=online VIG_MODEL=quad3 RULE=rel_t
echo "start $(date)" > $L
python dump_sn2_ppm.py $C $Q/k_mfg2_reg $OF $H fp 2>&1 | grep -v -i warning | grep -v "vignette frame" >> $L
n=0; for f in $Q/k_ce3_vigq3c_*_1.ppm; do g=${f/k_ce3_vigq3c/k_mfg2_reg}; cmp -s $f $g || n=$((n+1)); done; echo "2x regression vs k_ce3_vigq3c: $n files differ" >> $L
mkdir -p $Q/offmask3 $Q/offmask4
for N in 3 4; do
  MFG=$N SAVE_OFF=$Q/offmask$N/m python dump_sn2_ppm.py $C $Q/k_mfg$N $OF $H fp 2>&1 | grep -v -i warning | grep -v "vignette frame" >> $L
  echo "== ${N}x full frame" >> $L; MFG=$N python sn2_vs_fsr4.py $C $Q ours=k_mfg$N 2>&1 | grep -v -i warning >> $L
  echo "== ${N}x outside the off-frame band" >> $L; MFG=$N EXCL=$Q/offmask$N/m python sn2_vs_fsr4.py $C $Q ours=k_mfg$N 2>&1 | grep -v -i warning >> $L
  MFG=$N python make_sn2_video.py $C $Q/sn2_mfg${N}x_10fps.mp4 10 1 ours_${N}x=ppm:$Q/k_mfg$N 2>&1 | grep -v -i warning >> $L
  b=sn2_mfg${N}x_10fps.mp4; for i in 1 2 3; do cp $Q/$b videos/$b 2>/dev/null; cmp -s $Q/$b videos/$b && { echo copied $b >> $L; break; }; sleep 2; done
done
echo "done $(date)" >> $L
