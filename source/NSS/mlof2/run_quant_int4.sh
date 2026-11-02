#!/bin/bash
                                                                                                       
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt; O=/home/sh/nfru_mfg_out
L=$R/quant_int4.log
echo "start $(date)" > $L
for N in 2 4; do
  for Q in w4a8 w4; do
    echo "== ${N}x full $Q" >> $L
    env VIGNETTE=online TRAIL_A=1 MFG=$N QUANT=$Q QSTATS=$R/qstats_int8.json python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep "ours   all" >> $L
    echo "== ${N}x OF only $Q" >> $L
    env VIGNETTE=online OFONLY=1 MFG=$N QUANT=$Q QSTATS=$R/qstats_int8.json SAVE=$O/of${N}_$Q python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep "ours   all" >> $L
  done
done
MFG=4 python make_nfru_video.py $D $O/nfru_ofonly_int4_4x.mp4 10 OF_fp32=$O/of4_fp32 OF_int8=$O/of4_int8 OF_w4a8=$O/of4_w4a8 2>&1 | grep -v -i warning >> $L
b=nfru_ofonly_int4_4x.mp4; for i in 1 2 3; do cp $O/$b videos/$b; cmp -s $O/$b videos/$b && { echo copied $b >> $L; break; }; sleep 2; done
echo "done $(date)" >> $L
