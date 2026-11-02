source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs
ps aux | grep -E "python .*(train|probe)" | grep -v grep
python -u train_v2.py --out /tmp/fpnof_smoke --batch 4 --workers 2 --log 1 --stage of --seeded 0 --convex_up 1 --deep16 0 --p_pan 0 \
  --strides 1,2,3,4,6,8 --spring 0.5 --spring_batch 2 --lr 5e-5 --steps 2000 --spring_of_w gt_vis=1 --up_full 0 --prop4 0 \
  --enc_deep 1 --enc_fpn 1 --match_w 1.0 --distill_w 1.0 --init $R/v2_of_cut3/s2000.pt --enc_init $R/v2_of_encpre/fpndist12000.pt --smoke 6 2>&1 | grep -v -iE "warning|MIOpen|Consider" | cut -c1-260
