for i in $(seq 60); do grep -q ALLDONE /home/sh/mlof2_runs/render_1031/log_bf4.txt && break; sleep 10; done
cat /home/sh/mlof2_runs/render_1031/log_bf4.txt
source /home/sh/rocm_env/bin/activate
SET=bf4 python /mnt/e/nss_VK/NSS/mlof2/montage_1031.py /home/sh/mlof2_runs/render_1031 /mnt/e/nss_VK/NSS/mlof2_engine/docs/compare_1031
