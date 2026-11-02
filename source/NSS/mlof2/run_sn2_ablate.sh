#!/bin/bash
                                                                                                                 
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/sn2_ablate.log
echo "start $1 $(date)" >> $L
for A in none prop4 up_full prop4,up_full deep16 prop4,up_full,deep16; do
  tag=$(echo $A | tr ',' '_')
  AB=""; [ $A != none ] && AB="OF_ABLATE=$A"
  [ "$1" = ofonly ] && AB="$AB OFONLY=1" && tag="of_$tag"
  env $AB VIGNETTE=online VIG_MODEL=quad3 RULE=rel_t python dump_sn2_ppm.py $C $Q/k_abl_$tag $OF $H fp 2>&1 | grep -v -i warning | grep -v "vignette frame" | tail -1 >> $L
done
M="fsr4=k_fsr4_s1_t0_h0"
for A in none prop4 up_full prop4_up_full deep16 prop4_up_full_deep16; do t=$A; [ "$1" = ofonly ] && t="of_$A"; M="$M $t=k_abl_$t"; done
echo "== $1 full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 12 >> $L
echo "== $1 outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning | head -n 12 >> $L
echo "done $(date)" >> $L
