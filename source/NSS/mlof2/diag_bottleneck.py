import json

def analyze():
    json_path = "/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_v2_int8/mlof2_oft.json"
    with open(json_path) as f:
        meta = json.load(f)

    tensors = meta['tensors']
    segs = meta['segs']
    ops = meta['ops']
    H, W = 1088, 1920

    print("==========================================================================================")
    print(f"OFTNet Graph Analysis (Resolution: {H}x{W}, Total Ops: {len(ops)}, Total Tensors: {len(tensors)})")
    print("==========================================================================================")

    op_stats = []
    total_macs = 0
    total_read = 0
    total_write = 0

    for i, op in enumerate(ops):
        name = op.get('name', str(op['kind']))
        out_idx = op['out']
        out_t = tensors[out_idx]
        out_c = op['out_c']
        s = out_t['s']
        h, w = H // s, W // s
        fmt = out_t['fmt']
        esz = 1 if fmt in (2, 3) else (2 if fmt == 1 else 4)
        write_b = h * w * out_c * esz

        read_b = 0
        in_shapes = []
        for si in range(op['seg0'], op['seg0'] + op['nseg']):
            seg = segs[si]
            in_t = tensors[seg[0]]
            in_s = in_t['s']
            ih, iw = H // in_s, W // in_s
            ic = seg[2]
            ifmt = in_t['fmt']
            iesz = 1 if ifmt in (2, 3) else (2 if ifmt == 1 else 4)
            read_b += ih * iw * ic * iesz
            in_shapes.append(f"{in_t['name']}({ic}c@{ih}x{iw})")

        macs = 0
        if name == 'conv':
            kh, kw, stride, pad, dil = op['ip'][:5]
                                    
            in_seg = segs[op['seg0']]
            ic = in_seg[2]
                                                                      
            macs = h * w * out_c * ic * kh * kw
            w_b = out_c * ic * kh * kw
            read_b += w_b

        intensity = macs / (read_b + write_b + 1e-6)
        op_stats.append({
            'idx': i,
            'name': name,
            'out_name': out_t['name'],
            'grid': f"{h}x{w}",
            's': s,
            'c': out_c,
            'macs': macs,
            'read_b': read_b,
            'write_b': write_b,
            'total_b': read_b + write_b,
            'intensity': intensity,
            'ins': in_shapes
        })
        total_macs += macs
        total_read += read_b
        total_write += write_b

                                                       
    print("\n--- TOP 15 OPS BY MEMORY TRAFFIC (VRAM / Cache Transfer) ---")
    by_mem = sorted(op_stats, key=lambda x: x['total_b'], reverse=True)
    print(f"{'Op':<4} {'Name':<12} {'Output Tensor':<24} {'Grid':<10} {'MACs (M)':<10} {'Read(MB)':<10} {'Write(MB)':<10} {'Traffic(MB)':<12} {'Intensity(M/B)':<14}")
    print("-" * 110)
    for o in by_mem[:15]:
        print(f"{o['idx']:<4} {o['name']:<12} {o['out_name']:<24} {o['grid']:<10} {o['macs']/1e6:<10.1f} {o['read_b']/1e6:<10.2f} {o['write_b']/1e6:<10.2f} {o['total_b']/1e6:<12.2f} {o['intensity']:<14.2f}")

                                     
    scale_groups = {'scale_8': [], 'scale_4': [], 'scale_2': [], 'scale_1': [], 'pyramid_prep': [], 'final': []}
    for o in op_stats:
        if o['idx'] < 6:
            scale_groups['pyramid_prep'].append(o)
        elif o['idx'] == 60:
            scale_groups['final'].append(o)
        elif 'b0_s8' in o['out_name']:
            scale_groups['scale_8'].append(o)
        elif 'b1_s4' in o['out_name']:
            scale_groups['scale_4'].append(o)
        elif 'b2_s2' in o['out_name']:
            scale_groups['scale_2'].append(o)
        else:
            scale_groups['scale_1'].append(o)

    print("\n--- BREAKDOWN BY STAGE / SCALE ---")
    print(f"{'Stage':<15} {'Ops':<5} {'MACs (GMAC)':<12} {'Traffic (MB)':<14} {'Arithmetic Intensity (MAC/B)':<30}")
    print("-" * 80)
    for name, grp in scale_groups.items():
        g_macs = sum(x['macs'] for x in grp)
        g_mem = sum(x['total_b'] for x in grp)
        g_int = g_macs / (g_mem + 1e-6)
        print(f"{name:<15} {len(grp):<5} {g_macs/1e9:<12.2f} {g_mem/1e6:<14.1f} {g_int:<30.2f}")

    print("-" * 80)
    print(f"{'TOTAL':<15} {len(op_stats):<5} {total_macs/1e9:<12.2f} {(total_read+total_write)/1e6:<14.1f} {total_macs/(total_read+total_write+1e-6):<30.2f}")

if __name__ == "__main__":
    analyze()

