source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
run() { echo "#### $*"; env "$@" 2>&1 | grep -v -iE "warning|MIOpen" | grep -E "level|net|centre|corr soft T=0.05|corr argmax|iter|oracle|Traceback|rror"; }
for f in SP_0038/crop_00 SP_0004/crop_00; do
  for agg in 0 5; do
    run ITERS=8 AGG=$agg python -u diag_corr_readout.py $V/$f.safetensors $R/v2_of_fpndist/s2000.pt 4
  done
done
run ITERS=8 AGG=0 ENC=searaft python -u diag_corr_readout.py $V/SP_0038/crop_00.safetensors $R/v2_of_fpndist/s2000.pt 4
run ITERS=8 AGG=5 python -u diag_corr_readout.py $V/SP_0038/crop_00.safetensors $R/v2_of_cut3/s2000.pt 4
echo ALLDONE
