"""Light diagnostics for the OF pre-training (runs beside training: batch 1, a few windows).
1) Validation windows in loader order: PSNR B vs A, MV-warp, and the share of pixels whose game MV points off-screen
   (why 'no warp' is ~17 dB here but ~33 dB in eval_of.py's shuffled sample).
2) The OF of a checkpoint vs the geometry flow: magnitudes and direction (is it moving at all? wrong sign? scale?).
  python diag_of_stage.py <ckpt> [n]"""
import sys
import torch
from model_v2 import MLOF2, build_mlof2, warp, resize_flow
from data_v2 import WindowDataset

ck = sys.argv[1]
nwin = int(sys.argv[2]) if len(sys.argv) > 2 else 6
ds = WindowDataset(["forest15", "lyra15", "lyra17"], "validation", windows_per_file=8)
dev = "cuda"
sd = torch.load(ck, map_location=dev)
m = build_mlof2(sd).to(dev).eval()
m.load_state_dict(sd)
ps = lambda x, y, mk: -10 * torch.log10((((x - y) ** 2) * mk).sum() / (3 * mk.sum()).clamp_min(1)).item()
with torch.no_grad():
    for i in list(range(nwin)) + [len(ds) // 2 + j for j in range(nwin)]:
        s = ds[i]
        b = {k: v[None].to(dev) for k, v in s.items() if torch.is_tensor(v) and v.dim() >= 1}
        ca, cb, mv, geo = b["color_a"], b["color_b"], b["mv_ba"], b["geo_flow_ba"]
        ones = torch.ones_like(ca[:, :1])
        ins = (warp(ones, mv) > 0.999).float()
        fa, fb = m.enc(ca, b["depth_a"]), m.enc(cb, b["depth_b"])
        of = m.pair.of_forward(fa, fb, ca, cb)[4]["of"][:1]
        of = resize_flow(of, *ca.shape[-2:])
        cos = torch.nn.functional.cosine_similarity(of, geo, dim=1)
        mag_g, mag_o = geo.norm(dim=1), of.norm(dim=1)
        movers = mag_g > 2
        print(f"win {i:4d} span {int(s['span'])} | B vs A {ps(ca, cb, ins):5.2f}  MV-warp {ps(warp(ca, mv), cb, ins):5.2f}"
              f"  OF-warp {ps(warp(ca, of), cb, ins):5.2f} | off-screen {100*(1-ins.mean().item()):4.1f}% | |geo| med "
              f"{mag_g.median().item():5.1f} |OF| med {mag_o.median().item():5.1f} | cos(OF,geo) where |geo|>2: "
              f"{cos[movers].mean().item() if movers.any() else float('nan'):+.2f}")
