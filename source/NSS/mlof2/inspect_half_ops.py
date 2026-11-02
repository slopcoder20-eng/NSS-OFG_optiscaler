import json

with open('/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_half_v2_int8/mlof2_oft_half.json') as f:
    meta = json.load(f)

print(f"Total ops: {len(meta['ops'])}")
for i, op in enumerate(meta['ops']):
    t = meta['tensors'][op['out']]
    out_t = t['name']
    fmt = "fp32" if t['fmt'] == 0 else ("fp16" if t['fmt'] == 1 else "int8")
    print(f"[{i:2d}] {op['name']:12s} -> {out_t:25s} (c={t['c']:2d}, s={t['s']:2d}, fmt={fmt})")

