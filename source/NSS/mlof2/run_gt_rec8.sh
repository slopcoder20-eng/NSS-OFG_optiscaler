source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets; HD=$R/nfru_head_c2_ce3/s4000.pt
echo "=== FG GT test 0000, python engine emulation (gen v2 graphs), OF fp32 vs int8 graph $(date)"
for mfg in 2 4; do
  for of in v2_of_cut3/s2000.pt:qstats_cut3_int8.json v2_of_menc/s1500.pt:qstats_rec8_int8.json; do
    ck=${of%%:*}; q=${of##*:}
    echo "## MFG=$mfg $ck int8"
    GEN_STRUCTURE=4 GEN_EXEC=v2 GRAPH_QUANT=int8 QSTATS=$R/$q VIGNETTE=online TRAIL_A=cam MFG=$mfg python -u eval_nfru_mfg.py $D/test/0000.safetensors $R/$ck $HD 2>&1 | grep "ours   all\|Traceback\|Error"
  done
  echo "## MFG=$mfg v2_of_menc/s1500.pt fp32 OF"
  GEN_STRUCTURE=4 GEN_EXEC=v2 VIGNETTE=online TRAIL_A=cam MFG=$mfg python -u eval_nfru_mfg.py $D/test/0000.safetensors $R/v2_of_menc/s1500.pt $HD 2>&1 | grep "ours   all\|Traceback\|Error"
done
echo ALLDONE $(date)
