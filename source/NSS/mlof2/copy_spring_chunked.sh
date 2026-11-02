#!/bin/bash
                                                                                                                   
                                                                                                     
                                                                       
LOG=/f/Spring/copy_log.txt
: > $LOG
for split in validation train; do
  for d in /f/Spring/mlof/$split/SP_*; do
    s=$(basename $d)
    wsl -d Ubuntu-22.04 -- bash -c "mkdir -p /home/sh/spring_mlof/$split && rsync -a /mnt/f/Spring/mlof/$split/$s /home/sh/spring_mlof/$split/" >> $LOG 2>&1
    wsl -d Ubuntu-22.04 -u root -- sh -c "sync; echo 1 > /proc/sys/vm/drop_caches"
    echo "$split/$s copied $(date +%T)" >> $LOG
  done
done
wsl -d Ubuntu-22.04 -- bash -c "du -sh /home/sh/spring_mlof; ls /home/sh/spring_mlof/train | wc -l" >> $LOG 2>&1
echo "=== baseline v2_e Spring validation EPE (pure OF)" >> $LOG
wsl -d Ubuntu-22.04 -- bash -c "source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2; python eval_spring_epe.py /home/sh/mlof2_runs/v2_e/s16000_best.pt 40 2>&1 | grep -v Warning" >> $LOG 2>&1
echo ALL DONE >> $LOG
