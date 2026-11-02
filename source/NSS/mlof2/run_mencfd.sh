source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; V=/home/sh/spring_mlof/validation; P=$R/v2_of_encpre
echo "=== dense feature distillation onto proj64(teacher) + KL, from mencctx12000, GB 4 SPB 2, lr 2e-4 cosine, 6000 steps $(date)"
FEATD=1.0 PROJ=$P/proj64.pt RESUME_ENC=$P/mencctx12000.pt LR=2e-4 LRDECAY=1 GB=4 SPB=2 EVAL_EVERY=2000 GAME=0.7 DISTILL=1.0 DIST16=1 \
  python -u probe_enc_match.py $R/v2_of_cut3/s2000.pt matchctx 6000 "$P/mencfd{step}.pt" 2>&1 | grep --line-buffered -v -iE "warning|MIOpen|Consider|run = |meshgrid" &
TP=$!
for s in 2000 4000 6000; do
  until [ -f $P/mencfd$s.pt ] || ! kill -0 $TP 2>/dev/null; do sleep 20; done; sleep 10
  python combine_menc.py $R/v2_of_mencctx/s1500.pt $P/mencfd$s.pt $P/mencctx_fd$s.pt > /dev/null
  for f in SP_0038/crop_00 SP_0004/crop_00; do echo "#### s$s $f (mencctx block, distilled features; ref ours 6.07 / 27.45, proj64 5.43 / 26.93)"
    python -u diag_rec_ablate.py $V/$f.safetensors $P/mencctx_fd$s.pt none 2>&1 | grep -v -iE "warning|MIOpen"; done
done
wait $TP; echo ALLDONE $(date)
