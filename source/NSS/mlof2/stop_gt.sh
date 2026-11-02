for p in $(pgrep -f run_bfpick.sh) $(pgrep -f run_gt_rec8.sh) $(pgrep -f eval_nfru_mfg.py); do kill $p; done
sleep 2; pgrep -fc eval_nfru_mfg.py
mkdir -p /home/sh/mlof2_runs/render_1031
setsid nohup bash /mnt/e/nss_VK/NSS/mlof2/run_render.sh > /home/sh/mlof2_runs/render_1031/log.txt 2>&1 < /dev/null &
sleep 2; echo started
