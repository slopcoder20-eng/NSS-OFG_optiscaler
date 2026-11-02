#!/bin/bash
                                                                                                                   
S=/mnt/e/nss_VK/NSS/harness/nfru_dx12/replay
D=/home/sh/sn2_replay
mkdir -p $D
n=0
for p in "$@"; do
  for f in $S/${p}_*_1.ppm; do
    b=$(basename $f)
    for try in 1 2 3 4 5; do cmp -s $f $D/$b && break; cp $f $D/$b 2>/dev/null; sleep 1; done
    cmp -s $f $D/$b || { echo "FAIL $b"; n=$((n+1)); }
  done
done
echo "copied to $D, failures $n"
