for p in $(pgrep -f run_mencfd.sh); do kill $p; done
for p in $(pgrep -f "probe_enc_match.py"); do kill $p; done
for p in $(pgrep -f "diag_rec_ablate.py"); do kill $p; done
sleep 3; ps -eo args | grep -E "[p]robe_enc|[t]rain_v2|[d]iag_" | wc -l
