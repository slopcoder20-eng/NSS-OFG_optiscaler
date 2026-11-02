"""pan_rotate check: after the turn, the new B'->A' game MV must still move A' onto B' (in-screen, valid pixels),
and the A'->P' flow must move A' to P'. Also saves an image of P', A', G', B' for one sample."""
import random, torch
from torch.nn import functional as F
from torchvision.utils import save_image
from data_v2 import WindowDataset
from augment_v2 import pan_rotate
from model_v2 import warp
ds = WindowDataset(["forest15", "lyra15"], "validation", windows_per_file=4)
dl = torch.utils.data.DataLoader(ds, batch_size=4, shuffle=True, generator=torch.Generator().manual_seed(1))
b = next(iter(dl))
b = {k: v.cuda() for k, v in b.items()}
def ps(x, y, m):
    return -10 * torch.log10((((x - y) ** 2) * m).sum() / (3 * m.sum()).clamp_min(1)).item()
ones = torch.ones_like(b["color_a"][:, :1])
inside = lambda f: (warp(ones, f) > 0.999).float()
m0 = inside(b["mv_ba"])
before = ps(warp(b["color_a"], b["mv_ba"]), b["color_b"], m0)
before_none = ps(b["color_a"], b["color_b"], m0)
pan_rotate(b, random.Random(3), 896)
ones = torch.ones_like(b["color_a"][:, :1])
inside = lambda f: (warp(ones, f) > 0.999).float()
m = inside(b["mv_ba"]) * b["mv_valid"] * b["b_valid"]
after = ps(warp(b["color_a"], b["mv_ba"]), b["color_b"], m)
after_none = ps(b["color_a"], b["color_b"], m)
mp = inside(b["mv_ap"])
p_fit = ps(warp(b["color_p"], b["mv_ap"]), b["color_a"], mp)
mag = b["mv_ba"].norm(dim=1)[b["mv_valid"][:, 0] > 0]
print(f"before turn: MV warp {before:.2f} dB (no warp {before_none:.2f}) | after turn 896px: MV warp {after:.2f} dB "
      f"(no warp {after_none:.2f}), valid {m.mean().item()*100:.0f}% | A'->P' flow: P' warped onto A' {p_fit:.2f} dB")
print(f"MV size after turn: median {mag.median():.0f} px, p90 {mag.quantile(0.9):.0f} px, max {mag.max():.0f} px; gt_valid {b['gt_valid'].mean().item()*100:.0f}%")
save_image(torch.cat([b[k][:2] for k in ("color_p", "color_a", "color_g", "color_b")], 0), "/tmp/pan_check.png", nrow=2)
