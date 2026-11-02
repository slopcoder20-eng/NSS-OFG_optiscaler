source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
OUT=$R/v2_of_fpndist; mkdir -p $OUT
( while true; do echo "MEM $(date +%H:%M) $(free -m | awk '/Mem/{print "used",$3,"avail",$7}')"; sleep 300; done ) &
MP=$!
echo "=== OF train: fpn encoder (fpndist12000) + match_w 1.0 + distill_w 1.0, 2000 steps $(date)"
python -u train_v2.py --out $OUT --batch 4 --workers 4 --log 100 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 \
  --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --lr 5e-5 --steps 2000 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 \
  --val 1000 --val_batches 20 --enc_deep 1 --enc_fpn 1 --match_w 1.0 --distill_w 1.0 \
  --init $R/v2_of_cut3/s2000.pt --enc_init $R/v2_of_encpre/fpndist12000.pt > $OUT/stdout.txt 2>&1 &
TP=$!
diagall() {                       
  ck=$1; shift
  for f in "$@"; do
    echo "#### $ck $f"
    CAPS=1 python -u diag_foliage_of.py $V/$f.safetensors $ck 4 2>&1 | grep -v -i warning | grep -E "of1 (all|fol|dev )|Traceback|rror"
  done
}
until [ -f $OUT/s1000.pt ] || ! kill -0 $TP 2>/dev/null; do sleep 20; done; sleep 15
echo "=== MID $(date)"
grep -h "VAL-OF-BIG step 1000\|VAL-SPRING step 1000" $OUT/log.txt | cut -c1-220
diagall $OUT/s1000.pt SP_0038/crop_00 SP_0004/crop_00
echo MIDDONE $(date)
wait $TP
grep -h "VAL-OF-BIG step 2000\|VAL-SPRING step 2000" $OUT/log.txt | cut -c1-220
echo "=== FINAL 5 crops $(date)"
diagall $OUT/s2000.pt SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00
kill $MP; echo ALLDONE $(date)
