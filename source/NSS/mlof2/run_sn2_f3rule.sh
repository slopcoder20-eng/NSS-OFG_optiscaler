#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
L=$R/sn2_f3rule.txt
: > $L
FUSE_RULE=0.02 OFT_CKPT=$R/oft5/best.pt OFTFUSE=$R/fuse3/best.pt python dump_sn2_ppm.py $C $Q/k_n_f3rule $R/v2_of_menc/s1500.pt $R/nfru_head_c2_ce3/s4000.pt fp 2>&1 | grep -iE "error|Traceback|FUSE_RULE" >> $L
python sn2_vs_fsr4.py $C $Q fsr4=k_fsr4_s1_t0_h0 base=k_n_base rule=k_n_rule0.02 fuse3=k_n_fuse3 f3rule=k_n_f3rule 2>&1 | grep -v -i warning >> $L
python make_sn2_video.py $C /mnt/e/nss_VK/NSS/mlof2/videos/sn2_fuse3_8fps.mp4 8 2 base=ppm:$Q/k_n_base rule=ppm:$Q/k_n_rule0.02 fuse3=ppm:$Q/k_n_fuse3 fsr4=ppm:$Q/k_fsr4_s1_t0_h0 2>&1 | tail -1 >> $L
bash compress_video.sh /mnt/e/nss_VK/NSS/mlof2/videos/sn2_fuse3_8fps.mp4 /mnt/e/nss_VK/NSS/mlof2/videos/sn2_fuse3_8fps_small.mp4
echo ALLDONE >> $L
