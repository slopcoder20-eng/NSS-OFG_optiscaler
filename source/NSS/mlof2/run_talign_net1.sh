#!/bin/bash
                                                                                                                                                                      
                                                                                                                      
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt
H=$R/nfru_head_c2_ce2/s4000.pt
O=$R/talign_net_v1
L=$R/chain_talign_net1.log
mkdir -p $O
echo "start $(date)" > $L
python distill_talign.py --mlof2 $OF --out $O --steps ${STEPS:-4000} --workers 4 --spring 0.5 --gt 1 --arch net \
  --spring_crop 768,1280 --spring_strides 1,2,4 > $O/stdout.txt 2>&1
for ta in fp kpn; do echo "== $ta" >> $L; STRIDES=1,2 TALIGN_ARCH=net TALIGN=$ta KPN_CKPT=$O/last.pt python diag_traj_spring.py $OF $H 40 2>&1 | grep -v -i warning >> $L; done
echo "done $(date)" >> $L
