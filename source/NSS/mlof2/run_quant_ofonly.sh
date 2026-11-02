#!/bin/bash
                                                                                                
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt; O=/home/sh/nfru_mfg_out
L=$R/quant_ofonly.log
echo "start $(date)" > $L
for N in 2 4; do
  for Q in fp32 int8 fp8; do
    QA=""; [ $Q != fp32 ] && QA="QUANT=$Q QSTATS=$R/qstats_$Q.json"
    echo "== ${N}x OF only $Q" >> $L
    env VIGNETTE=online OFONLY=1 MFG=$N $QA SAVE=$O/of${N}_$Q python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep "ours   all" >> $L
  done
  MFG=$N python make_nfru_video.py $D $O/nfru_ofonly_quant_${N}x.mp4 10 OF_fp32=$O/of${N}_fp32 OF_int8=$O/of${N}_int8 OF_fp8=$O/of${N}_fp8 2>&1 | grep -v -i warning >> $L
  b=nfru_ofonly_quant_${N}x.mp4; for i in 1 2 3; do cp $O/$b videos/$b; cmp -s $O/$b videos/$b && { echo copied $b >> $L; break; }; sleep 2; done
done
echo "done $(date)" >> $L
