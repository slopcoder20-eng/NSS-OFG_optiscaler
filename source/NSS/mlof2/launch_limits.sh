for p in $(pgrep -f "python -u test_distill_limits.py"); do kill $p; done
sleep 2
mkdir -p /home/sh/mlof2_runs/limits
cd /mnt/e/nss_VK/NSS/mlof2
setsid nohup bash -c 'source /home/sh/rocm_env/bin/activate; python -u test_distill_limits.py > /home/sh/mlof2_runs/limits/log.txt 2>&1' < /dev/null > /dev/null 2>&1 &
sleep 5
pgrep -fc "python -u test_distill_limits.py"
grep -E '^===' /home/sh/mlof2_runs/ofgate_exp/log.txt | tail -2
