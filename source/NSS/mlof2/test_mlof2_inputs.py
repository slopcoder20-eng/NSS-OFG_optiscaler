"""One NFRU test-capture pair as engine inputs (rows B, A), padded to 1088x1920; display look as eval_nfru_mfg."""
import torch
from torch.nn import functional as F
from safetensors import safe_open
from data_v2 import TONE_CURVES, srgb_encode, quantize, depth_feature

NFRU_TEST = "/home/sh/neural-graphics-model-gym/tests/usecases/nfru/datasets/test/0000.safetensors"


def nfru_pair(fa=18, fb=20, dev="cuda"):
    s = safe_open(NFRU_TEST, "pt")
    pad = lambda x: F.pad(x, (0, 0, 0, 1088 - 1080), mode="replicate")
    lin = lambda i: s.get_slice("rgb_linear")[i:i + 1].float()
    zn = s.get_tensor("NearPlane").float()
    def display(x, ref):
        lum = lambda y: (0.2126 * y[:, 0] + 0.7152 * y[:, 1] + 0.0722 * y[:, 2]).clamp_min(1e-6)
        return quantize(srgb_encode(TONE_CURVES["aces"](x.clamp_min(0) * 0.18 / torch.exp(torch.log(lum(ref)).mean())).clamp(0, 1)), 8)
    dfeat = lambda i: F.interpolate(depth_feature(s.get_slice("depth")[i:i + 1].float(), zn[i]), size=(1080, 1920), mode="bilinear", align_corners=False)
    la = lin(fa)
    col = torch.cat((pad(display(lin(fb), la)), pad(display(la, la))), 0).to(dev)
    dep = torch.cat((pad(dfeat(fb)), pad(dfeat(fa))), 0).to(dev)
    return col, dep
