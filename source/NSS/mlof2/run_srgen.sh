source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation
diff /home/sh/third_party/SEA-RAFT/config/eval/spring-M.json /home/sh/third_party/SEA-RAFT/config/eval/sintel-M.json
for hf in MemorySlices/Tartan-C-T432x960-M MemorySlices/Tartan-C-T-TSKH432x960-M MemorySlices/Tartan-C-T-TSKH-spring540x960-M; do
 for f in SP_0038/crop_00 SP_0004/crop_00 SP_0045/crop_01; do
  echo "#### $hf $f"
  SEARAFT_HF=$hf CAPS=99,98 python -u diag_foliage_of.py $V/$f.safetensors $R/v2_of_fpndist/s2000.pt 4 2>&1 | grep -v -iE "warning|MIOpen" | grep -E "of(99|98) (all|fol  |dev )|Traceback|rror|404|Repository"
 done
done
echo ALLDONE
