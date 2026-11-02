for p in $(pgrep -f "v2_of_menc_joint"); do kill $p; done
for p in $(pgrep -f run_ofgate.sh); do kill $p; done
for p in $(pgrep -f "diag_foliage_of.py"); do kill $p; done
for p in $(pgrep -f "run_diag_rec8.sh"); do kill $p; done
for p in $(pgrep -f "diag_rec8.py"); do kill $p; done
sleep 2
ps -eo args | grep -E "[t]rain_v2|[d]iag_|[r]un_ofgate|[t]est_distill" | cut -c1-100
tail -5 /home/sh/mlof2_runs/ofgate_exp/log.txt | cut -c1-150
