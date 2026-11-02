source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
until grep -q ALLDONE $R/menc_exp/log.txt; do sleep 30; done
ME=$R/v2_of_encpre/mencctx12000.pt
echo "=== MatchEncoder + 1/16 context (frozen cut3) + dilated res (2,4), 12000 steps $(date)"
LR=3e-4 EVAL_EVERY=3000 GAME=0.7 DISTILL=1.0 DIST16=1 python -u probe_enc_match.py $R/v2_of_cut3/s2000.pt matchctx 12000 $ME 2>&1 | grep --line-buffered -v -iE "warning|MIOpen|Consider|run = |meshgrid"
echo ALLDONE $(date)
