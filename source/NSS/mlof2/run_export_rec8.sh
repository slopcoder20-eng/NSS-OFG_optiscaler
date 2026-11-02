source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
R=/home/sh/mlof2_runs; G=/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets
V=$G/val/0000.safetensors; D=$G/test/0000.safetensors
OF=${1:-$R/v2_of_menc/s1500.pt}; H=$R/nfru_head_c2_ce3/s4000.pt; QS=$R/qstats_rec8_int8.json
OUTD=/mnt/e/nss_VK/NSS/mlof2_engine/generated_rec8_v2_int8
E="VIGNETTE=online TRAIL_A=1"
echo "=== calib $OF $(date)"
[ -f $QS ] || env $E MFG=2 QUANT=int8 QCALIB_OUT=$QS MAX_PAIRS=12 python eval_nfru_mfg.py $V $OF $H 2>&1 | grep -v -i warning | grep -v '^pair' | tail -3
echo "=== export -> $OUTD $(date)"
mkdir -p $OUTD
GEN_STRUCTURE=4 GEN_BOTHFAIL=1.0,0.25 STORE=v2 SPLIT=1 python export_mlof2_engine.py $OF $QS $OUTD int8 $H 2>&1 | grep -v -i warning | tail -15
ls $OUTD
echo DONE $(date)
