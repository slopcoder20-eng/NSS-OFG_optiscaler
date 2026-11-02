import os, sys, json, torch
from torch.nn import functional as F

sys.path.insert(0, '/mnt/e/nss_VK/NSS/mlof2')
from model_v2 import build_mlof2
from oft_fuse import FuseNet, of_frame, mv_candidates
from train_fuse import load_oft3
from lk_refine import lk_refine
from train_oft import pure_of
from data_v2 import WindowDataset
from train_v2 import to_dev

dev = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f'Using device: {dev}')

                
sd_of = torch.load('/home/sh/mlof2_runs/v2_of_menc/s1500.pt', map_location=dev)
m = build_mlof2(sd_of).to(dev).eval(); m.load_state_dict(sd_of.get('model', sd_of)); m.pair.seeded = False
oft = load_oft3('/home/sh/mlof2_runs/oft5/best.pt', dev)

fuse = FuseNet(c=32, n=2, cin=21).to(dev).eval()
sd_fuse = torch.load('/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/fuse3_best.pt', map_location=dev)
fuse.load_state_dict(sd_fuse)

                                           
stats = {}
def make_hook(name):
    def hook(module, inp, out):
        x = inp[0].detach()
        amax = x.abs().max().item()
        if name not in stats:
            stats[name] = amax
        else:
            stats[name] = max(stats[name], amax)
    return hook

fuse.d1.register_forward_hook(make_hook('fuse.d1.inp'))
fuse.d2.register_forward_hook(make_hook('fuse.d2.inp'))
fuse.body[0].a.register_forward_hook(make_hook('fuse.body.0.a.inp'))
fuse.body[0].b.register_forward_hook(make_hook('fuse.body.0.b.inp'))
fuse.body[1].a.register_forward_hook(make_hook('fuse.body.1.a.inp'))
fuse.body[1].b.register_forward_hook(make_hook('fuse.body.1.b.inp'))
fuse.out.register_forward_hook(make_hook('fuse.out.inp'))

                                             
ds = WindowDataset(['forest15', 'lyra15', 'lyra17'], 'validation', crop=448, windows_per_file=8)
loader = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=False)

print('Running calibration...')
with torch.no_grad():
    for bi, b in enumerate(loader):
        if bi >= 15:
            break
        b = to_dev(b, dev)
        t = b['t'].float()
        of_ab, of_ba = pure_of(m, b)
        o = oft(t, b['color_a'], b['color_b'], of_ab, of_ba)
        fa, fb, _ = lk_refine(b['color_a'], b['color_b'], o['f_ta'], o['f_tb'], t)
        ofc, oa, ob = of_frame(b['color_a'], b['color_b'], fa, fb, o['vis'])
        mva, mvb, ma, mb, hole, offma, offmb = mv_candidates(b['color_a'], b['color_b'], b['depth_b'],
                                                            b['mv_ba'] * b['mv_valid'], b['mv_valid'], t)
        from model_v2 import warp as warp_
        d_of = (warp_(b['color_a'], fa) - warp_(b['color_b'], fb)).abs().mean(1, keepdim=True) * 4
        out, w, cand = fuse(t, ofc, mva, mvb, fa, ma, oa, ob, offma, offmb, hole, o['vis'], d_of)

print('Calibration complete! Qstats:')
for k, v in stats.items():
    print(f'  {k:20s}: {v:.6f}')

out_json = '/mnt/e/nss_VK/NSS/mlof2_engine/generated_oft_half_v2_int8/qstats_fuse_int8.json'
with open(out_json, 'w') as f:
    json.dump(stats, f, indent=2)
print(f'Saved to {out_json}')
