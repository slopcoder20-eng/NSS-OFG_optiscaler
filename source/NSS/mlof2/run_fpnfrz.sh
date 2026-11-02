source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
echo "=== fpn distillation, base frozen at cut3, 6000 steps, eval/save every 1500 $(date)"
FREEZE_BASE=1 EVAL_EVERY=1500 GAME=0.7 DISTILL=1.0 python -u probe_enc_match.py $R/v2_of_cut3/s2000.pt fpn 6000 $R/v2_of_encpre/fpnfrz6000.pt 2>&1 | grep --line-buffered -v -iE "warning|MIOpen|Consider|run = |meshgrid"
echo "=== readout $(date)"
for f in SP_0038/crop_00 SP_0004/crop_00; do
  echo "#### $f ENC=fpnfrz6000 AGG=5"
  ENC=$R/v2_of_encpre/fpnfrz6000.pt AGG=5 python -u diag_corr_readout.py $V/$f.safetensors $R/v2_of_cut3/s2000.pt 4 2>&1 | grep -v -iE "warning|MIOpen" | grep -E "level|centre|corr soft T=0.05|oracle|Traceback|rror"
done
echo ALLDONE $(date)
