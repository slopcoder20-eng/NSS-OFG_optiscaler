#!/bin/bash
                                                                                                
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets
env ${FR:+FRAMES=$FR} VIGNETTE=online TRAIL_A=${TRAIL:-1} ORACLE=1 MFG=$1 python eval_nfru_mfg.py $G/${FILE:-test/0000}.safetensors $R/v2_of_cut3/s2000.pt $R/nfru_head_c2_ce3/s4000.pt 2>&1 | grep -v -i warning | grep -v '^pair'
