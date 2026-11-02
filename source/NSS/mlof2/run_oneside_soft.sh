#!/bin/bash
                                                                                                              
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; C=/home/sh/sn2_cap/nfru_capture_19620640; Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
L=$R/chain_oneside_soft.log
while pgrep -f run_head_ce3.sh > /dev/null; do sleep 60; done
echo "start $(date)" > $L
for h in "ce2:$R/nfru_head_c2_ce2/s4000.pt" "ce3:$R/nfru_head_c2_ce3/s4000.pt"; do n=${h%%:*}; ck=${h#*:}
  for r in 8 16; do ONESIDE_SOFT=$r RULE=rel_t python dump_sn2_ppm.py $C $Q/k_${n}_soft$r $OF $ck fp 2>&1 | grep -v -i warning >> $L; done; done
for f in $Q/k_ce*_soft*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
M="fsr4=k_fsr4_s1_t0_h0 ce2_hard=k_bord_oneside ce2_soft8=k_ce2_soft8 ce2_soft16=k_ce2_soft16 ce3_hard=k_ce3_oneside ce3_soft8=k_ce3_soft8 ce3_soft16=k_ce3_soft16"
echo "== full frame" >> $L; python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
echo "== outside the off-frame band" >> $L; EXCL=$Q/offmask/m python sn2_vs_fsr4.py $C $Q $M 2>&1 | grep -v -i warning >> $L
echo "done $(date)" >> $L
