source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
for f in SP_0038/crop_00 SP_0004/crop_00; do
  echo "#### $f  rect (block trained on SEA-RAFT features)"
  python -u diag_rec_ablate.py $V/$f.safetensors $R/v2_of_rect/s1500.pt none,c8,c16,norec 2>&1 | grep -v -iE "warning|MIOpen"
  echo "#### $f  mencctx (block trained on our context MatchEncoder)"
  python -u diag_rec_ablate.py $V/$f.safetensors $R/v2_of_mencctx/s1500.pt none,c8,c16,teacher,shuffle,norec 2>&1 | grep -v -iE "warning|MIOpen"
done
echo ALLDONE
