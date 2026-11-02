"""Spring per-level EPE (pure OF, no seed) on the train vs validation split, per |GT| bin; plus each bin's pixel share.
  python diag_spring_levels.py <ckpt> [n_batches]
Same pixels and metric as validate_epe: GT explains B (explain_error <= 0.5), GT stays on screen, median per window."""
import sys
import torch
import torch.nn.functional as F
from model_v2 import build_mlof2, warp
from data_v2 import WindowDataset
from of_losses import resize_flow
from losses_v2 import explain_error

BINS = (0, 8, 32, 64, 128, 256, 1e9)
sd = torch.load(sys.argv[1], map_location="cuda")
m = build_mlof2(sd).cuda(); m.load_state_dict(sd.get("model", sd)); m.pair.seeded = False; m.eval()
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 30
for split, wpf in (("train", 2), ("validation", 16)):
    ds = WindowDataset(["spring"], split, crop=(1024, 1920), windows_per_file=wpf, strides=(1, 2, 4, 8, 12), seed=7)
    dl = torch.utils.data.DataLoader(ds, batch_size=2, shuffle=split == "train", num_workers=2,
                                     generator=torch.Generator().manual_seed(7))
    res, share = {}, {}
    with torch.no_grad():
        for bi, b in enumerate(dl):
            if bi >= nb:
                break
            b = {k: v.cuda() for k, v in b.items() if torch.is_tensor(v)}
            fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
            n, _, H, W = b["color_a"].shape
            gt = b["geo_flow_ba"]; g = gt.norm(dim=1)
            ok = (explain_error(b["color_a"], b["color_b"], gt) <= 0.5).float()
            mk = (ok * (warp(torch.ones_like(ok), gt) > 0.999).float())[:, 0] > 0.5
            ofs = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
            for i in range(len(BINS) - 1):
                share.setdefault(i, []).append(float((mk & (g >= BINS[i]) & (g < BINS[i + 1])).sum() / mk.sum().clamp_min(1)))
            for lv in (64, 32, 16, 8, 4):
                f = resize_flow(ofs[lv]["of"][:n], H, W)
                e = (f - gt).norm(dim=1)
                for i in range(len(BINS) - 1):
                    s_ = mk & (g >= BINS[i]) & (g < BINS[i + 1])
                    if s_.sum() > 2000:
                        res.setdefault((lv, i), []).append((e[s_].median().item(),
                                                            (f.norm(dim=1)[s_].median() / g[s_].median().clamp_min(1e-3)).item()))
    print(f"== {split}  pixel share per bin: " + " | ".join(
        f"{BINS[i]:.0f}-{BINS[i + 1] if BINS[i + 1] < 1e8 else 'inf'} {100 * sum(v) / len(v):.1f}%" for i, v in sorted(share.items())))
    for lv in (64, 32, 16, 8, 4):
        print(f"  1/{lv:<2d} " + " | ".join(
            f"{BINS[i]:.0f}-{BINS[i + 1] if BINS[i + 1] < 1e8 else 'inf'}: {sum(x[0] for x in res[(lv, i)]) / len(res[(lv, i)]):6.2f} "
            f"r{sum(x[1] for x in res[(lv, i)]) / len(res[(lv, i)]):.2f} n{len(res[(lv, i)])}"
            for i in range(len(BINS) - 1) if (lv, i) in res), flush=True)
