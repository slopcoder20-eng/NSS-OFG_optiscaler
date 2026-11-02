#!/bin/bash
                                                                                                                   
                                                                                                                    
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
C=/home/sh/sn2_cap/nfru_capture_19620640
Q=/home/sh/sn2_replay
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
O=$R/nfru_head_c2_ofprior
L=$R/chain_head_ofprior.log
mkdir -p $O
echo "start $(date)" > $L
python - <<PY
import torch
sd = torch.load("$R/nfru_head_c2_spring_fp/best.pt", map_location="cpu")
sd["of_prior"] = torch.tensor(-2.0)
torch.save(sd, "$O/step0_prior.pt")
PY
python dump_sn2_ppm.py $C $Q/k_new_ofprior0 $OF $O/step0_prior.pt fp 2>&1 | grep -v -i warning >> $L
python train_nfru_head.py --mlof2 $OF --out $O --variant c --accel 1 --steps 4000 --lr 2e-4 --spring 0.3 --talign fp \
  --refine 1 --of_prior -2 --init_head $R/nfru_head_c2_spring_fp/best.pt > $O/stdout.txt 2>&1
python dump_sn2_ppm.py $C $Q/k_new_ofprior $OF $O/best.pt fp 2>&1 | grep -v -i warning >> $L
for f in $Q/k_new_ofprior*_*.ppm; do s=$(stat -c %s $f); [ "$s" != 6220817 ] && echo "BAD SIZE $s $f" >> $L; done
python sn2_vs_fsr4.py $C $Q FSR4=k_fsr4_s1_t0_h0 B_fp=k_new_B_fp B_mvonly=k_new_B_mvonly ofprior_step0=k_new_ofprior0 ofprior_trained=k_new_ofprior >> $L 2>&1
python make_sn2_video.py $C $Q/sn2_fsr4_ofprior_10fps.mp4 10 1 FSR4=ppm:$Q/k_fsr4_s1_t0_h0 B_fp=ppm:$Q/k_new_B_fp ofprior_trained=ppm:$Q/k_new_ofprior 2>&1 | grep -v -i warning >> $L
b=sn2_fsr4_ofprior_10fps.mp4; for i in 1 2 3; do cp $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b 2>/dev/null; cmp -s $Q/$b /mnt/e/nss_VK/NSS/mlof2/videos/$b && { echo "copied $b" >> $L; break; }; sleep 2; done
echo "done $(date)" >> $L
