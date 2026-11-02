#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
OF=\/v2_of_cut3/s2000.pt
H=\/nfru_head_c2_ce3/s4000.pt
QS=\/qstats_cut3_int8.json
OUT=/mnt/e/nss_VK/NSS/mlof2_engine/generated_cut3_v2_int8
export STORE=v2
export SPLIT=1
export GEN_STRUCTURE=4
python export_mlof2_engine.py \ \ \ int8 