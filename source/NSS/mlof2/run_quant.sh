#!/bin/bash
                                                                                                            
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets
D=$G/test/0000.safetensors; V=$G/val/0000.safetensors
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
L=$R/quant_ptq.log
echo "start $(date)" > $L
E="VIGNETTE=online TRAIL_A=1"
for Q in int8 fp8; do
  env $E MFG=2 QUANT=$Q QCALIB_OUT=$R/qstats_$Q.json MAX_PAIRS=12 python eval_nfru_mfg.py $V $OF $H 2>&1 | grep --line-buffered -v -i warning | grep -v '^pair' >> $L
done
for N in 2 4; do
  echo "== ${N}x fp32" >> $L; env $E MFG=$N python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep -v '^pair' >> $L
  for Q in int8 fp8; do
    echo "== ${N}x $Q" >> $L; env $E MFG=$N QUANT=$Q QSTATS=$R/qstats_$Q.json python eval_nfru_mfg.py $D $OF $H 2>&1 | grep --line-buffered -v -i warning | grep -v '^pair' >> $L
  done
done
echo "done $(date)" >> $L
