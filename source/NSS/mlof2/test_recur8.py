"""recur8 sanity: zero-init delta head -> same OF as without the block; then gradient reaches the block."""
import sys, torch
from model_v2 import build_mlof2, MLOF2
ck = sys.argv[1]
sd = torch.load(ck, map_location="cpu"); sd = sd.get("model", sd)
a = build_mlof2(sd).eval(); a.load_state_dict(sd); a.pair.seeded = False
b = build_mlof2(sd, recur8=3).eval(); print(b.load_state_dict(sd, strict=False)); b.pair.seeded = False
torch.manual_seed(0)
ca, cb, d = torch.rand(1, 3, 256, 384), torch.rand(1, 3, 256, 384), torch.rand(1, 1, 256, 384)
with torch.no_grad():
    oa = a.pair.of_forward(a.enc(ca, d), a.enc(cb, d), ca, cb)
    ob = b.pair.of_forward(b.enc(ca, d), b.enc(cb, d), ca, cb)
print("max |diff| level 4 of:", (oa[4]["of"] - ob[4]["of"]).abs().max().item())
b.train()
ob = b.pair.of_forward(b.enc(ca, d), b.enc(cb, d), ca, cb)
ob[4]["of"].abs().mean().backward()
print("grad d2:", b.pair.rec.d2.weight.grad.abs().sum().item(), "params rec:", sum(p.numel() for p in b.pair.rec.parameters()))
sd2 = b.state_dict(); c = build_mlof2(sd2); print("rebuilt recur8 =", c.pair.rec.iters if c.pair.rec is not None else None)
