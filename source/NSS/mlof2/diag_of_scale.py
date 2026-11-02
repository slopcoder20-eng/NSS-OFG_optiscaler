"""Input / activation scales of each OF level and gradient norms per part (one window, batch 1).
  python diag_of_scale.py <ckpt>"""
import sys
import torch
import model_v2
from model_v2 import MLOF2
from data_v2 import WindowDataset
from of_losses import of_loss

ck = sys.argv[1]
dev = "cuda"
m = MLOF2().to(dev).train()
m.load_state_dict(torch.load(ck, map_location=dev))
ds = WindowDataset(["forest15", "lyra15"], "validation", windows_per_file=8)
s = ds[1]
b = {k: v[None].to(dev) for k, v in s.items() if torch.is_tensor(v) and v.dim() >= 1}

stats = {}
def hook(name):
    def f(mod, inp, out):
        x = inp[0].detach()
        stats[name] = (x.abs().mean().item(), x.abs().amax().item(), out.detach().abs().mean().item())
    return f
for lv, u in m.pair.upd.items():
    u.inp.register_forward_hook(hook(f"upd{lv}.inp"))
    u.head.register_forward_hook(hook(f"upd{lv}.head"))
fa, fb = m.enc(b["color_a"], b["depth_a"]), m.enc(b["color_b"], b["depth_b"])
for lv in (4, 8, 16, 32, 64):
    print(f"enc f{lv}: mean |x| {fa[lv].abs().mean().item():.3f}  max {fa[lv].abs().amax().item():.1f}")
ofs = m.pair.of_forward(fa, fb, b["color_a"], b["color_b"])
for k, (mi, ma, mo) in stats.items():
    print(f"{k:14s} input mean|x| {mi:8.3f} max {ma:9.1f} | output mean|y| {mo:.4f}")
loss, parts = of_loss(ofs, b)
loss.backward()
groups = {}
for n, p in m.named_parameters():
    if p.grad is None:
        continue
    key = ".".join(n.split(".")[:3])
    groups[key] = groups.get(key, 0.0) + p.grad.pow(2).sum().item()
print("loss parts", {k: round(v, 3) for k, v in parts.items()})
for k, v in sorted(groups.items(), key=lambda kv: -kv[1])[:12]:
    print(f"grad norm {k:22s} {v ** 0.5:.3f}")
