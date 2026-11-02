source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
for f in SP_0038/crop_00 SP_0038/crop_01 SP_0045/crop_00 SP_0045/crop_01 SP_0004/crop_00; do
  echo "#### $f menc"; python -u diag_rec_ablate.py $V/$f.safetensors $R/v2_of_menc/s1500.pt none,c16,skip4,skip4c16 2>&1 | grep -v -iE "warning|MIOpen"
  echo "#### $f cut3"; python -u diag_rec_ablate.py $V/$f.safetensors $R/v2_of_cut3/s2000.pt none,skip4 2>&1 | grep -v -iE "warning|MIOpen"
done
echo ALLDONE
