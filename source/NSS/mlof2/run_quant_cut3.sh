#!/bin/bash
                                                                                                                
                                               
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets
D=$G/test/0000.safetensors; V=$G/val/0000.safetensors
OF=$R/v2_of_cut3/s2000.pt; H=$R/nfru_head_c2_ce3/s4000.pt
E="VIGNETTE=online TRAIL_A=1"
if [ "$1" = calib ]; then
  for Q in int8 fp8; do
    env $E MFG=2 QUANT=$Q QCALIB_OUT=$R/qstats_cut3_$Q.json MAX_PAIRS=12 python eval_nfru_mfg.py $V $OF $H 2>&1 | grep -v -i warning | grep -v '^pair'
  done
else
  [ "$3" = fp32 ] && { env $E MFG=$2 python eval_nfru_mfg.py $D $OF $H 2>&1 | grep -v -i warning | grep -v "^pair"; exit; }
  env $E MFG=$2 QUANT=$3 QSTATS=$R/qstats_cut3_$3.json python eval_nfru_mfg.py $D $OF $H 2>&1 | grep -v -i warning | grep -v '^pair'
fi
