#!/bin/bash
                                                                                                                  
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_menc/s1500.pt
H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/sn2_new.txt
: > $L
RULE=rel_t python dump_sn2_ppm.py $C $Q/k_n_base $OF $H fp 2>&1 | grep -iE "error|Traceback" >> $L
OFT_CKPT=$R/oft5/best.pt OFTFUSE=$R/fuse1/best.pt OFT_ONLY=1 python dump_sn2_ppm.py $C $Q/k_n_oft $OF $H fp 2>&1 | grep -iE "error|Traceback" >> $L
OFT_CKPT=$R/oft5/best.pt OFTFUSE=$R/fuse1/best.pt python dump_sn2_ppm.py $C $Q/k_n_fuse $OF $H fp 2>&1 | grep -iE "error|Traceback" >> $L
python sn2_vs_fsr4.py $C $Q fsr4=k_fsr4_s1_t0_h0 base=k_n_base oft=k_n_oft fuse=k_n_fuse 2>&1 | grep -v -i warning >> $L
echo ALLDONE >> $L
