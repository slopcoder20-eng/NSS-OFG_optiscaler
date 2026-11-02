#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
OF=/home/sh/mlof2_runs/v2_of_menc/s1500.pt
H=/home/sh/mlof2_runs/nfru_head_c2_ce3/s4000.pt
QS=/home/sh/mlof2_runs/qstats_rec8_int8.json
OUTD=/mnt/e/nss_VK/NSS/mlof2_engine/generated_rec8_nol4_v2_int8
mkdir -p "$OUTD"
export MLOF2_OFT_NO_L4=1
export GEN_STRUCTURE=4
export GEN_BOTHFAIL=1.0,0.25
export STORE=v2
export SPLIT=1
python export_mlof2_engine.py "$OF" "$QS" "$OUTD" int8 "$H"
