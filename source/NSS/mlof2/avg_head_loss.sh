#!/bin/bash
                                                                                                        
for d in "$@"; do
  echo "$d"
  grep '^step' /home/sh/mlof2_runs/$d/log.txt | awk '{s=int(($2-1)/500); l[s]+=$4; n[s]++} END {for (i=0;i<20;i++) if (n[i]) printf "  steps %5d-%5d: mean l1 %.4f (n %d)\n", i*500+1, (i+1)*500, l[i]/n[i], n[i]}'
done
