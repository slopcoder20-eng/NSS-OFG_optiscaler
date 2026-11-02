source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
ME=$R/v2_of_encpre/menc6000.pt
echo "=== A: MatchEncoder distillation (1/8 + 1/16 KL to SEA-RAFT fnet, + InfoNCE), 6000 steps $(date)"
LR=3e-4 EVAL_EVERY=1500 GAME=0.7 DISTILL=1.0 DIST16=1 python -u probe_enc_match.py $R/v2_of_cut3/s2000.pt match 6000 $ME 2>&1 | grep --line-buffered -v -iE "warning|MIOpen|Consider|run = |meshgrid"
[ -f $ME ] || { echo "NO MENC"; exit 1; }
for f in SP_0038/crop_00 SP_0004/crop_00; do echo "#### readout $f ENC=menc6000 AGG=5"
  ENC=$ME AGG=5 python -u diag_corr_readout.py $V/$f.safetensors $R/v2_of_cut3/s2000.pt 4 2>&1 | grep -v -iE "warning|MIOpen" | grep -E "level|centre|corr soft T=0.05|oracle|Traceback|rror"; done
echo "=== B: zero-shot: rec (trained on SEA-RAFT features) reading the MatchEncoder $(date)"
python combine_menc.py $R/v2_of_rect/s1500.pt $ME $R/v2_of_encpre/rect_menc0.pt
bash run_diag_rec8.sh $R/v2_of_encpre/rect_menc0.pt
OUT=$R/v2_of_menc; mkdir -p $OUT
echo "=== C: rec fine-tune on the MatchEncoder (rec only, seq loss), 1500 steps $(date)"
python -u train_v2.py --out $OUT --batch 4 --workers 4 --log 100 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 \
  --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 --enc_deep 1 --enc_fpn 1 \
  --enc_match 1 --recur8 3 --seq_w 1.0 --train_only pair.rec --lr 2e-4 --warmup 200 --steps 1500 --val 500 --val_batches 20 \
  --init $R/v2_of_encpre/rect_menc0.pt > $OUT/stdout.txt 2>&1 &
TP=$!
for s in 500 1000 1500; do
  until [ -f $OUT/s$s.pt ] || ! kill -0 $TP 2>/dev/null; do sleep 20; done; sleep 15
  echo "=== C s$s $(date)"; grep -h "VAL-OF-BIG step $s\|VAL-SPRING step $s" $OUT/log.txt | cut -c1-200
  bash run_diag_rec8.sh $OUT/s$s.pt
done
wait $TP
echo "=== FINAL 5 crops $(date)"
for f in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00; do echo "#### $OUT/s1500.pt $f"
  CAPS=1 python -u diag_foliage_of.py $V/$f.safetensors $OUT/s1500.pt 4 2>&1 | grep -v -i warning | grep -E "of1 (all|fol |dev )|Traceback|rror"; done
echo ALLDONE $(date)
