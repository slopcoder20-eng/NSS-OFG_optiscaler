#!/bin/bash
                                 
ps -eo pid,etimes,rss,args | grep -E 'train_oft|run_oft|diag_rife|drop_cache' | grep -v grep | cut -c1-110
tail -3 /home/sh/mlof2_runs/$1/stdout.txt | cut -c1-200
grep -E '^step|VAL' /home/sh/mlof2_runs/$1/log.txt 2>/dev/null | tail -3 | cut -c1-150
