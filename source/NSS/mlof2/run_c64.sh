source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
if [ "$1" = smoke ]; then python -u distill_c64.py $R/v2_of_cut3/s2000.pt /tmp/c64_smoke 3 2>&1 | grep -v -iE "warning|MIOpen" | tail -8; exit; fi
until grep -q ALLDONE $R/menc_exp/log.txt; do sleep 30; done
OUT=$R/v2_of_c64
echo "=== narrow 1/64 (c64 128, w64 128, n64 2) distilled from cut3, 4000 steps $(date)"
python -u distill_c64.py $R/v2_of_cut3/s2000.pt $OUT 4000 128 128 2 2>&1 | grep --line-buffered -v -iE "warning|MIOpen|Consider"
for ck in $R/v2_of_cut3/s2000.pt $OUT/s4000.pt; do
  for f in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00; do echo "#### $ck $f"
    CAPS=1 python -u diag_foliage_of.py $V/$f.safetensors $ck 4 2>&1 | grep -v -i warning | grep -E "of1 (all|fol |dev )|Traceback|rror"; done
done
echo ALLDONE $(date)
