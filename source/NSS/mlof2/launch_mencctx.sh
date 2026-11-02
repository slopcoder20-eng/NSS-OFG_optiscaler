for p in $(pgrep -f run_mencctx.sh); do [ "$p" != "$$" ] && kill $p; done
sleep 1
setsid nohup bash /mnt/e/nss_VK/NSS/mlof2/run_mencctx.sh > /home/sh/mlof2_runs/mencctx_exp/log.txt 2>&1 < /dev/null &
sleep 2
ps -eo args | grep -E '[r]un_(c64|mencctx|menc)\.sh' | cut -c1-60
