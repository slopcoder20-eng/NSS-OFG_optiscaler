#!/bin/bash
                                                                                   
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
for d in 1,2,4,6,8,12 1,2,4,6,8,12,16,24; do DISTS=$d python diag_ring_theory.py $1 10 2>&1 | grep -v -i warning; done
