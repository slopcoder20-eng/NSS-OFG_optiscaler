"""Head R check: is the FullSynth output non-zero, and how big are its logit / flow corrections on one Spring pair?"""
import sys, torch
from nfru_head_r import load_head_any, NfruHeadR
sd = torch.load(sys.argv[1], map_location="cpu")
for k in ("synth.out.weight", "synth.out.bias", "synth.inp.weight"):
    print(k, tuple(sd[k].shape), "abs mean %.3e max %.3e" % (sd[k].abs().mean(), sd[k].abs().max()))
h = load_head_any(sys.argv[1], "cuda")
print("loaded", type(h).__name__)
x = torch.randn(1, 23, 256, 256, device="cuda") * 0.3
d = h.synth(x)
print("d logits abs mean %.4f max %.4f | d flow (x4 px) abs mean %.4f max %.4f" % (
    d[:, :4].abs().mean(), d[:, :4].abs().max(), 4 * d[:, 4:].abs().mean(), 4 * d[:, 4:].abs().max()))
