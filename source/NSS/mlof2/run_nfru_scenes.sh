#!/bin/bash
                                                                                                       
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/train
OF=$R/v2_of_spring_prop4b_gtvis/s3000.pt; H=$R/nfru_head_c2_ce3/s4000.pt; O=/home/sh/nfru_mfg_out
L=$R/nfru_scenes.log
echo "start $1 $(date)" >> $L
for sc in "$1"; do
  IFS=: read nm file a b <<< "$sc"
  for N in 2 4; do
    for Q in fp32 int8; do
      QA=""; [ $Q != fp32 ] && QA="QUANT=$Q QSTATS=$R/qstats_$Q.json"
      echo "== $nm ($file $a:$b) ${N}x $Q" >> $L
      env VIGNETTE=online TRAIL_A=1 MFG=$N FRAMES=$a:$b $QA SAVE=$O/${nm}_${N}_$Q python eval_nfru_mfg.py $G/$file.safetensors $OF $H 2>&1 | grep --line-buffered -v -i warning | grep -v "^pair\|blend" >> $L
    done
  done
  FRAMES=$a:$b MFG=4 python make_nfru_video.py $G/$file.safetensors $O/nfru_${nm}_4x.mp4 10 fp32=$O/${nm}_4_fp32 int8=$O/${nm}_4_int8 2>&1 | grep -v -i warning >> $L
  v=nfru_${nm}_4x.mp4; for i in 1 2 3; do cp $O/$v videos/$v; cmp -s $O/$v videos/$v && { echo copied $v >> $L; break; }; sleep 2; done
done
echo "done $(date)" >> $L
