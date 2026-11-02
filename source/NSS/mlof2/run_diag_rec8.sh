source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
CK=${1:-/home/sh/mlof2_runs/v2_of_recur8/s1000.pt}
for f in SP_0038/crop_00 SP_0004/crop_00; do echo "#### $f $CK"
  python -u diag_rec8.py /home/sh/spring_mlof/validation/$f.safetensors $CK 4 2>&1 | grep -v -iE "warning|MIOpen"; done
