source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets; HD=$R/nfru_head_c2_ce3/s4000.pt
until grep -q ALLDONE $R/gt_rec8/log.txt; do sleep 30; done
echo "=== hard pick in the both-fail regions (deployed OF cut3 int8), test 0000 $(date)"
for mfg in 2 4; do
  for v in none near argmax argmax_edge; do
    if [ $v = none ]; then BF=""; else BF="1.0,0.25"; fi
    echo "## MFG=$mfg $v"
    GEN_BOTHFAIL=$BF GEN_BF_PICK=$v GEN_STRUCTURE=4 GEN_EXEC=v2 GRAPH_QUANT=int8 QSTATS=$R/qstats_cut3_int8.json VIGNETTE=online TRAIL_A=cam MFG=$mfg \
      python -u eval_nfru_mfg.py $D/test/0000.safetensors $R/v2_of_cut3/s2000.pt $HD 2>&1 | grep "ours   all\|ours   band\|Traceback\|Error"
  done
done
echo ALLDONE $(date)
