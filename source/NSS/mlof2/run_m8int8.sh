source /home/sh/rocm_env/bin/activate; cd /mnt/e/nss_VK/NSS/mlof2
bash run_export_rec8.sh 2>&1 | grep -E "enc |pair |Traceback|Error|DONE"
python -c "
import json
for g,n in (('enc','fm8'),('pair','qm8'),('pair','rr8_0'),('pair','m16')):
    t=[x for x in json.load(open('/mnt/e/nss_VK/NSS/mlof2_engine/generated_rec8_v2_int8/mlof2_'+g+'_int8.json'))['tensors'] if x['name'].startswith(n)][0]; print(g,t)"
cd /mnt/c/Users/sh/AppData/Local/Temp/claude/C--WINDOWS-system32/551a315c-6ed5-4d1f-9135-4adc600f56de/scratchpad && python make_v2_io.py /mnt/e/nss_VK/NSS/mlof2_engine/generated_rec8_v2_int8 int8 /mnt/c/Users/sh/AppData/Local/Temp/claude/C--WINDOWS-system32/551a315c-6ed5-4d1f-9135-4adc600f56de/scratchpad/vkio_rec8 2>&1 | grep -v -i warn | tail -1
ls -la /mnt/c/Users/sh/AppData/Local/Temp/claude/C--WINDOWS-system32/551a315c-6ed5-4d1f-9135-4adc600f56de/scratchpad/vkio_rec8/pair/in_qm8.bin
