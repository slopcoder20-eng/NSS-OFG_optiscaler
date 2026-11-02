source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
COMMON="--batch 4 --workers 4 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 --enc_deep 1 --enc_fpn 1 --recur8 3 --recur8_teacher 1 --seq_w 1.0 --train_only pair.rec --lr 3e-4 --warmup 200 --init $R/v2_of_recur8/s1000.pt"
if [ "$1" = smoke ]; then
  python -u train_v2.py --out /tmp/rect_smoke --log 1 --steps 1500 --smoke 6 $COMMON 2>&1 | grep -v -iE "warning|MIOpen|Consider" | cut -c1-260
  exit
fi
OUT=$R/v2_of_rect; mkdir -p $OUT
echo "=== recur8 block only, correlations on SEA-RAFT features (experiment), seq loss, lr 3e-4, 1500 steps $(date)"
python -u train_v2.py --out $OUT --log 100 --steps 1500 --val 500 --val_batches 20 $COMMON > $OUT/stdout.txt 2>&1 &
TP=$!
for s in 500 1000 1500; do
  until [ -f $OUT/s$s.pt ] || ! kill -0 $TP 2>/dev/null; do sleep 20; done; sleep 15
  echo "=== s$s $(date)"; grep -h "VAL-OF-BIG step $s\|VAL-SPRING step $s" $OUT/log.txt | cut -c1-200
  bash run_diag_rec8.sh $OUT/s$s.pt
done
wait $TP; echo ALLDONE $(date)
