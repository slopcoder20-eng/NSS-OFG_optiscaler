#!/bin/bash
                                                                                                       
                                                                                                       
sleep 30
while pgrep -f "^bash .*${1:-run_oft.sh}" > /dev/null; do
  sync; echo 1 > /proc/sys/vm/drop_caches
  sleep 90
done
