#!/bin/bash
ps -eo pid,etimes,rss,args | grep -E 'train_oft|run_oft|drop_cache' | grep -v grep | cut -c1-150
grep -c "VAL step 0" /home/sh/mlof2_runs/oft1/log.txt
grep "VAL" /home/sh/mlof2_runs/oft1/log.txt
