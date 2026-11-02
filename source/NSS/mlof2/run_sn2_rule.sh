#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
L=$R/sn2_rule.txt
: > $L
for mg in 0.02 0.05; do
  FUSE_RULE=$mg OFT_CKPT=$R/oft5/best.pt OFTFUSE=$R/fuse2/best.pt python dump_sn2_ppm.py $C $Q/k_n_rule$mg $R/v2_of_menc/s1500.pt $R/nfru_head_c2_ce3/s4000.pt fp 2>&1 | grep -iE "error|Traceback|FUSE_RULE" >> $L
done
python sn2_vs_fsr4.py $C $Q fsr4=k_fsr4_s1_t0_h0 base=k_n_base fuse2=k_n_fuse2 rule02=k_n_rule0.02 rule05=k_n_rule0.05 2>&1 | grep -v -i warning >> $L
echo ALLDONE >> $L
