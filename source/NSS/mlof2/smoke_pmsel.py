"""PMSelect check: build convex_up + deep16 + pm_sel (no Propagate / UpFull) from a checkpoint, save it as an init
checkpoint (so the diag scripts can measure the untrained selection), check backward, time and peak GPU memory
of one training-size forward+backward (2 x 1024x1920).
  python smoke_pmsel.py <ckpt> <out init ckpt>"""
import sys, time
import torch
from model_v2 import MLOF2, full_flow

ck, outp = sys.argv[1], sys.argv[2]
dev = "cuda"
sd = torch.load(ck, map_location=dev); sd = sd.get("model", sd)
m = MLOF2(convex_up=True, deep16=True, pm_sel=True).to(dev)
own = m.state_dict()
keep = {k: v for k, v in sd.items() if k in own and own[k].shape == v.shape}
print("loaded", len(keep), "of", len(own), "| new:", [k for k in own if k not in keep], "| dropped:", sorted({k.split('.')[1] for k in sd if k not in own}))
m.load_state_dict(keep, strict=False)
torch.save({"model": m.state_dict()}, outp)
H, W = 1024, 1920
ca, cb, da, db = (torch.rand(2, c, H, W, device=dev) for c in (3, 3, 1, 1))
for it in range(3):                                                                             
    torch.cuda.reset_peak_memory_stats(); torch.cuda.synchronize(); t0 = time.time()
    m.zero_grad()
    o = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]
    f = full_flow(o, H, W)
    f.abs().mean().backward()
    torch.cuda.synchronize(); t1 = time.time()
    m.pair.pm_sel = False
    with torch.no_grad():
        m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)
    torch.cuda.synchronize(); t2 = time.time()
    m.pair.pm_sel = True
    with torch.no_grad():
        m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)
    torch.cuda.synchronize(); t3 = time.time()
    print(f"iter {it}: fwd+bwd 2x{H}x{W} {t1 - t0:.2f} s, peak {torch.cuda.max_memory_allocated() / 1e9:.2f} GB | "
          f"no-grad fwd without PM {t2 - t1:.3f} s, with PM {t3 - t2:.3f} s (4 rows: both directions x 2)")
print("grad: net", float(m.pair.pms.net[2].weight.grad.abs().sum()) > 0, "| tau", m.pair.pms.log_tau.grad is not None,
      "| 1/4 level", float(m.pair.upd["4"].head.weight.grad.abs().sum()) > 0)
