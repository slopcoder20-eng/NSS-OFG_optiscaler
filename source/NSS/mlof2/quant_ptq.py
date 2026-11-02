"""Post-training quantization (fake quant) of every Conv2d / Linear of the OF network and the NFRU head, int8 or fp8,
to measure what the engine's low-precision path costs in quality before any QAT.
  int8 : weights per output channel, symmetric [-127, 127]; activations (each layer's INPUT) per tensor, symmetric,
         scale from the 99.99th percentile of |x| over the calibration frames (the max is set by rare outliers).
  fp8  : e4m3 (fn), weights per output channel and activations per tensor, scale = amax / 448 (fp8 has the range;
         clipping is worse than the coarse top of the format).
Bias stays fp32 (int32 accumulator in the engine). BatchNorm is folded into the preceding conv first (the head's
ConvBlocks), as the engine would. Everything that is not a Conv2d / Linear stays at full precision (warp, correlation,
softmax, invert_t, the rules): those are shaders, fp16 there.
  w4a8 : int4 weights per output channel, symmetric [-7, 7] (scale amax / 7), int8 activations as int8 (same stats)
  w4   : int4 weights only, activations at full precision (how much of the loss is the weights)
  q = quantize(model, mode); calibrate: with q.calibrating(): run frames; then run normally."""
import contextlib
import torch
from torch import nn
from torch.nn import functional as F

FP8_MAX = 448.0


def fold_bn(model):
    """ConvBlock-style conv -> BN (eval stats) folded into the conv; BN replaced by identity."""
    n_fold = 0
    for mod in model.modules():
        if hasattr(mod, "conv2d") and hasattr(mod, "bn") and isinstance(mod.bn, nn.BatchNorm2d):
            c, bn = mod.conv2d, mod.bn
            s = bn.weight / torch.sqrt(bn.running_var + bn.eps)
            with torch.no_grad():
                c.weight.mul_(s.view(-1, 1, 1, 1))
                b = c.bias if c.bias is not None else torch.zeros_like(bn.running_mean)
                new_b = (b - bn.running_mean) * s + bn.bias
                if c.bias is None:
                    c.bias = nn.Parameter(new_b)
                else:
                    c.bias.copy_(new_b)
            mod.bn = nn.Identity()
            n_fold += 1
    return n_fold


def q_int8(x, scale):
    return torch.clamp(torch.round(x / scale), -127, 127) * scale


def q_fp8(x, scale):
    return (x / scale).clamp(-FP8_MAX, FP8_MAX).to(torch.float8_e4m3fn).to(x.dtype) * scale


class QWrap(nn.Module):
    def __init__(self, inner, mode, name):
        super().__init__()
        self.inner, self.mode, self.name = inner, mode, name
        self.calib = False
        self.stat = None                                                                          
        w = inner.weight.detach()
        amax = w.abs().flatten(1).amax(1).clamp_min(1e-12).view(-1, *([1] * (w.dim() - 1)))
        if mode == "int8":
            self.wq = q_int8(w, amax / 127)
        elif mode in ("w4a8", "w4"):
            self.wq = torch.clamp(torch.round(w / (amax / 7)), -7, 7) * (amax / 7)
        else:
            self.wq = q_fp8(w, amax / FP8_MAX)
        self.wq = self.wq.to(w.dtype)

    def forward(self, x):
        if self.calib:
            a = x.detach().abs().flatten()
            if a.numel() > 4_000_000:
                a = a[torch.randint(0, a.numel(), (4_000_000,), device=a.device)]
            v = float(torch.quantile(a.float(), 0.9999)) if self.mode != "fp8" else float(a.max())
            self.stat = v if self.stat is None else max(self.stat, v)
            return self._run(x, self.inner.weight)
        if self.stat is not None and self.mode != "w4":
            if self.mode in ("int8", "w4a8"):
                x = q_int8(x, max(self.stat, 1e-8) / 127)
            else:
                x = q_fp8(x, max(self.stat, 1e-8) / FP8_MAX)
        return self._run(x, self.wq)

    def _run(self, x, w):
        m = self.inner
        if isinstance(m, nn.Conv2d):
            return F.conv2d(x, w, m.bias, m.stride, m.padding, m.dilation, m.groups)
        return F.linear(x, w, m.bias)


def quantize(model, mode, skip=()):
    """Replace Conv2d / Linear children in place by QWrap. Returns the list of wrappers."""
    assert mode in ("int8", "fp8", "w4a8", "w4")
    wraps = []
    for pname, parent in list(model.named_modules()):
        for cname, child in list(parent.named_children()):
            full = f"{pname}.{cname}" if pname else cname
            if isinstance(child, (nn.Conv2d, nn.Linear)) and not any(s in full for s in skip):
                w = QWrap(child, mode, full)
                setattr(parent, cname, w)
                wraps.append(w)
    return wraps


@contextlib.contextmanager
def calibrating(wraps):
    for w in wraps:
        w.calib = True
    try:
        yield
    finally:
        for w in wraps:
            w.calib = False
