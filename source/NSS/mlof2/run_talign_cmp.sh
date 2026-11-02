#!/bin/bash
                                                                                                                        
                                                                                                           
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
C=/home/sh/sn2_cap/nfru_capture_19620640
for a in ${3:-splat fp}; do TALIGN=$a python diag_sn2_head.py $1 $2 $C 2>&1 | grep -v -i warning; done
