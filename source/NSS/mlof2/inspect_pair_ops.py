import json

path = '/mnt/e/nss_VK/NSS/mlof2_engine/generated_cut3_v2_int8/mlof2_pair_int8.json'
m = json.load(open(path))

KIND_MAP = {
    0: "conv", 1: "unshuffle", 2: "resize_area", 3: "resize_bil", 4: "warp", 5: "corr",
    6: "absdiff", 7: "round_trip", 8: "spread", 9: "axpy", 10: "scale", 11: "zeros",
    12: "copy", 13: "convex_up", 14: "prop_step"
}

print(f"Total ops: {len(m['ops'])}")
for i, op in enumerate(m['ops']):
    out_t = m['tensors'][op['out']]
    kname = KIND_MAP.get(op['kind'], str(op['kind']))
    segs = []
    for s_idx in range(op['seg0'], op['seg0'] + op['nseg']):
        s = m['segs'][s_idx]
        tid, c_off, c, swap = s[0], s[1], s[2], s[3]
        t = m['tensors'][tid]
        segs.append(f"{t['name']}[{c_off}:{c_off+c}]" if c < t['c'] else t['name'])
    print(f"[{i:2d}] {kname:12s} segs={segs} -> {out_t['name']} (s={out_t['s']}, c={out_t['c']})")
