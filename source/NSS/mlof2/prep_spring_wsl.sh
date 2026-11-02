#!/bin/bash
                                                                                                                 
                                                 
set -e
rm -f /home/sh/spring_mlof                                            
mkdir -p /home/sh/spring_mlof
rsync -a --info=progress2 /mnt/f/Spring/mlof/ /home/sh/spring_mlof/
du -sh /home/sh/spring_mlof; ls /home/sh/spring_mlof/train | wc -l; ls /home/sh/spring_mlof/validation
source /home/sh/rocm_env/bin/activate
cd /mnt/e/nss_VK/NSS/mlof2
echo "=== baseline v2_e Spring validation EPE (pure OF)"
python eval_spring_epe.py /home/sh/mlof2_runs/v2_e/s16000_best.pt 40 2>&1 | grep -v Warning
