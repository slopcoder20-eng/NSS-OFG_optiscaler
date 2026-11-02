source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation; L=$R/ofgate_exp/log.txt
CROPS="SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00"
COMMON="--batch 4 --workers 4 --log 100 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 --enc_deep 1 --enc_fpn 1 --enc_match 1 --recur8 3 --seq_w 1.0 --warmup 200 --val 500 --val_batches 20"
crops() { for f in $CROPS; do echo "#### $1 $f"; CAPS=1 python -u diag_foliage_of.py $V/$f.safetensors $1 4 2>&1 | grep -v -i warning | grep -E "of1 (all|fol |dev )|Traceback|rror"; done; }
trainrun() {                           
  OUT=$1; ST=$2; shift 2; mkdir -p $OUT
  python -u train_v2.py --out $OUT --steps $ST $COMMON "$@" > $OUT/stdout.txt 2>&1 &
  TP=$!
  for s in $(seq 500 500 $ST); do
    until [ -f $OUT/s$s.pt ] || ! kill -0 $TP 2>/dev/null; do sleep 20; done; sleep 15
    echo "=== $(basename $OUT) s$s $(date)"; grep -h "VAL-OF-BIG step $s \|VAL-SPRING step $s " $OUT/log.txt | cut -c1-160
    bash run_diag_rec8.sh $OUT/s$s.pt | grep -E "####|delta|after rec"
  done
  wait $TP
}
until grep -q ALLDONE $R/mencctx_exp/log.txt; do sleep 30; done
echo "=== OF test 1: context MatchEncoder (mencctx12000) + rec fine-tune $(date)"
python combine_menc.py $R/v2_of_rect/s1500.pt $R/v2_of_encpre/mencctx12000.pt $R/v2_of_encpre/rect_mencctx0.pt
trainrun $R/v2_of_mencctx 1500 --enc_match_ctx 1 --train_only pair.rec --lr 2e-4 --init $R/v2_of_encpre/rect_mencctx0.pt
crops $R/v2_of_mencctx/s1500.pt
if python of_gate.py $L v2_of_mencctx/s1500; then echo "GATE PASS -> stop"; echo ALLDONE $(date); exit 0; fi
echo "=== GATE FAIL -> next: joint fine-tune MatchEncoder + rec (seq loss + m8 distillation), from v2_of_menc/s1500 $(date)"
trainrun $R/v2_of_menc_joint 2000 --train_only pair.rec,enc.menc --lr 1e-4 --distill_w 0.5 --distill_key m8 --init $R/v2_of_menc/s1500.pt
crops $R/v2_of_menc_joint/s2000.pt
python of_gate.py $L v2_of_menc_joint/s2000 && echo "GATE PASS (joint)" || echo "GATE FAIL (joint)"
echo ALLDONE $(date)
