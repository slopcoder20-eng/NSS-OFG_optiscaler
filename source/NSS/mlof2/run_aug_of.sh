#!/bin/bash
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
for c in "$@"; do python diag_aug_of.py $c 30 2>&1 | grep -v -i warning; done
