"""Fake int8 PTQ of OFTNet (task doc rule 3): conv weights int8 per output channel (symmetric), conv INPUTS int8 per
tensor (symmetric, scale = calibrated max |x|); flow / mask accumulation, warps and LK stay float.
Usage: qnet = quantize_oft(copy.deepcopy(net)); calibrate(qnet, fn) runs fn() with recording on; then freeze(qnet)."""
import torch
from torch import nn


def _q(x, s):
    return torch.clamp(torch.round(x / s), -127, 127) * s


def quantize_oft(net):
    for m in net.modules():
        if isinstance(m, nn.Conv2d):
            with torch.no_grad():
                w = m.weight
                s = w.abs().amax(dim=(1, 2, 3), keepdim=True).clamp_min(1e-8) / 127.0
                m.weight.copy_(_q(w, s))
            m.register_buffer("amax", torch.zeros((), device=m.weight.device))
            m.calib = True

            def pre(mod, inp):
                x = inp[0]
                if mod.calib:
                    mod.amax = torch.maximum(mod.amax, x.detach().abs().amax())
                    return None
                return (_q(x, mod.amax.clamp_min(1e-8) / 127.0),)
            m.register_forward_pre_hook(pre)
    return net


def freeze(net):
    for m in net.modules():
        if isinstance(m, nn.Conv2d) and hasattr(m, "calib"):
            m.calib = False
    return net
