source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets; HD=$R/nfru_head_c2_ce3/s4000.pt; O=$R/render_1031
for ofq in cut3:v2_of_cut3/s2000.pt:qstats_cut3_int8.json menc:v2_of_menc/s1500.pt:qstats_rec8_int8.json; do
  IFS=: read nm ck q <<< "$ofq"
  echo "## ${nm}_bfedge4 (engine form: 1/4-grid edge 2.0, argmax pick)"
  SAVE=$O/${nm}_bfedge4 GEN_BOTHFAIL=1.0,0.25,2.0 GEN_BF_PICK4=1 GEN_STRUCTURE=4 GEN_EXEC=v2 GRAPH_QUANT=int8 QSTATS=$R/$q VIGNETTE=online TRAIL_A=cam MFG=2 \
    python -u eval_nfru_mfg.py $D/test/0000.safetensors $R/$ck $HD 2>&1 | grep "ours   all\|Traceback\|Error"
done
echo ALLDONE $(date)
