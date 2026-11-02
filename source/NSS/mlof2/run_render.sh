                                                                                                         
source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; D=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets; HD=$R/nfru_head_c2_ce3/s4000.pt
O=$R/render_1031; mkdir -p $O
[ -f $R/v2_of_encpre/fpnfrz_norec.pt ] || python strip_rec.py $R/v2_of_recur8/s1000.pt $R/v2_of_encpre/fpnfrz_norec.pt
[ -f $R/qstats_fpnfrz_int8.json ] || VIGNETTE=online TRAIL_A=1 MFG=2 QUANT=int8 QCALIB_OUT=$R/qstats_fpnfrz_int8.json MAX_PAIRS=12 \
  python eval_nfru_mfg.py $D/val/0000.safetensors $R/v2_of_encpre/fpnfrz_norec.pt $HD 2>&1 | grep -E "wrote|Traceback|Error"
run() {                                    
  echo "## $1"
  SAVE=$O/$1 SAVE_GT=${6:-0} GEN_BOTHFAIL=$4 GEN_BF_PICK=$5 GEN_STRUCTURE=4 GEN_EXEC=v2 GRAPH_QUANT=int8 QSTATS=$R/$3 VIGNETTE=online TRAIL_A=cam MFG=2 \
    python -u eval_nfru_mfg.py $D/test/0000.safetensors $R/$2 $HD 2>&1 | grep "ours   all\|Traceback\|Error"
}
run cut3        v2_of_cut3/s2000.pt            qstats_cut3_int8.json   ""        near 1
run menc        v2_of_menc/s1500.pt            qstats_rec8_int8.json   ""        near
run fpnfrz      v2_of_encpre/fpnfrz_norec.pt   qstats_fpnfrz_int8.json ""        near
run cut3_bfnear v2_of_cut3/s2000.pt            qstats_cut3_int8.json   1.0,0.25  near
run cut3_bfarg  v2_of_cut3/s2000.pt            qstats_cut3_int8.json   1.0,0.25  argmax
run cut3_bfedge v2_of_cut3/s2000.pt            qstats_cut3_int8.json   1.0,0.25  argmax_edge
echo ALLDONE $(date)
