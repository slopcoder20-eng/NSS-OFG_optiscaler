source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
[ -f $R/v2_of_encpre/proj128.pt ] || python -u proj_flow_test.py 2>&1 | grep -v -iE "warning|MIOpen|Consider"
for f in SP_0038/crop_00 SP_0004/crop_00; do
  for c in 64 128; do
    echo "#### $f mencctx block, projected teacher features $c ch"
    PROJ=$R/v2_of_encpre/proj$c.pt python -u diag_rec_ablate.py $V/$f.safetensors $R/v2_of_mencctx/s1500.pt none,teacher,proj 2>&1 | grep -v -iE "warning|MIOpen"
  done
done
echo ALLDONE
