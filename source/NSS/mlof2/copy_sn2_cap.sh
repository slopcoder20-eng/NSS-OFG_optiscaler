#!/bin/bash
                                                                                                                
S=/mnt/f/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/nfru_capture_19620640
D=/home/sh/sn2_cap/nfru_capture_19620640
mkdir -p $D
cd $S
for f in *; do
  cmp -s "$f" "$D/$f" || cp "$f" "$D/$f" || echo "FAIL $f"
done
n=0; for f in *; do cmp -s "$f" "$D/$f" || { echo "DIFF $f"; n=$((n+1)); }; done
echo "files src $(ls | wc -l) dst $(ls $D | wc -l), mismatches $n"
