import json

g = json.load(open("/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/mlof2_oft.json"))
print(f"Num ops: {len(g['ops'])}")
for i, op in enumerate(g["ops"]):
    t = g["tensors"][op["out"]]
    print(f"op_{i:03d}: {op.get('name'):15s} out_t={op['out']:2d} ({t['name']:20s} c={t['c']:2d} s={t['s']:2d} fmt={t['fmt']})")

