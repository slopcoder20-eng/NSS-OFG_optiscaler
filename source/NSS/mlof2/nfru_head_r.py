"""Head R (2026-10-31 experiment): the deployed NfruHeadC2 + a RIFE-style full-resolution synthesis correction.

Why: on Spring foliage RIFE 4.25 reaches error 5.93 / sharpness 0.91, our head 7.12 / 0.71, and our head fed RIFE's
flows only 6.65 / 0.73 (eval_foliage_rifeflow.py) -> the gap is mostly the synthesis, not the flow. Our head decides at
1/4 from AVERAGE-POOLED candidates (grass blades averaged away) and upsamples the logits bilinearly; RIFE's last block
reads the full-res warped images through strided convs and writes its mask / flow update through a learned 4x upsample.

FullSynth does that on top of the frozen head: full-res cues (4 candidates 12, head logits 4, MV-pair / OF-pair A-B
disagreement 2, OF t-flows / 16 4, t 1 = 23) -> pixel_unshuffle 4 (368 ch at 1/4) -> 1x1 to C -> N ResConv 3x3 ->
1x1 to 16 * 8 -> pixel_shuffle 4 -> per full-res pixel: delta logits 4 + delta OF t-flows (to A, to B) 4 (px, x4 scale).
Last layer zero: starts equal to the plain head. Only MV-free inputs reach the OF flow update (the OF stays a second
opinion: the correction sees the MV candidates' colours, never the MV vectors)."""
import torch
from torch import nn
from torch.nn import functional as F
from model_v2 import warp
from nfru_head import NfruHeadC2, load_head_c2, warp_noise


class ResC(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.a = nn.Conv2d(c, c, 3, 1, 1)
        self.b = nn.Conv2d(c, c, 3, 1, 1)

    def forward(self, x):
        return x + self.b(F.leaky_relu(self.a(x), 0.1))


class FullSynth(nn.Module):
    CIN = 23

    def __init__(self, c=48, n=3):
        super().__init__()
        self.inp = nn.Conv2d(self.CIN * 16, c, 1)
        self.body = nn.Sequential(*[ResC(c) for _ in range(n)])
        self.out = nn.Conv2d(c, 8 * 16, 1)
        with torch.no_grad():
            self.out.weight.zero_(); self.out.bias.zero_()

    def forward(self, x):
        H, W = x.shape[-2:]
        ph, pw = (4 - H % 4) % 4, (4 - W % 4) % 4
        x = F.pad(x, (0, pw, 0, ph), mode="replicate")
        y = self.out(F.leaky_relu(self.body(F.leaky_relu(self.inp(F.pixel_unshuffle(x, 4)), 0.1)), 0.1))
        return F.pixel_shuffle(y, 4)[..., :H, :W]


class NfruHeadR(nn.Module):
    def __init__(self, base, c=48, n=3):
        super().__init__()
        self.base = base
        self.synth = FullSynth(c, n)

    @property
    def talign(self):
        return self.base.talign

    @talign.setter
    def talign(self, v):
        self.base.talign = v

    def train(self, mode=True):                                                                            
        super().train(mode)
        self.base.eval()
        return self

    def forward(self, t, of_ba_q, color_a, color_b, depth_a, depth_b, mv_ba, *args, **kw):
        o = self.base(t, of_ba_q, color_a, color_b, depth_a, depth_b, mv_ba, *args, **kw)
        n, _, H, W = color_a.shape
        cand, (ma, mb, oa, ob) = o["cand"], o["tflows"]
        lg = o["weights"].clamp_min(1e-6).log()                                                                
        x = torch.cat((cand.flatten(1, 2), lg.clamp(min=-8.0) / 4.0,
                       (cand[:, 0] - cand[:, 1]).abs().mean(1, keepdim=True) * 4,
                       (cand[:, 2] - cand[:, 3]).abs().mean(1, keepdim=True) * 4,
                       oa / 16.0, ob / 16.0, t.view(n, 1, 1, 1).expand(n, 1, H, W)), 1)
        d = self.synth(x)
        oa2, ob2 = oa + 4.0 * d[:, 4:6], ob + 4.0 * d[:, 6:8]
        cand2 = torch.stack((cand[:, 0], cand[:, 1], warp_noise(color_a, oa2), warp_noise(color_b, ob2)), 1)
        w = (lg + d[:, :4]).softmax(1)
        if getattr(self.base, "hole_b", False):
            keep = torch.cat((1 - o["off_mv"][0], 1 - o["off_mv"][1], 1 - o["off_of"][0], 1 - o["off_of"][1]), 1)
            w = w * keep
            w = w / w.sum(1, keepdim=True).clamp_min(1e-6)
        o2 = dict(o)
        o2.update(color=(w[:, :, None] * cand2).sum(1).clamp(0, 1), weights=w, cand=cand2, tflows=(ma, mb, oa2, ob2))
        return o2


def load_head_any(path, dev, base_path=None):
    """A plain NfruHeadC2 checkpoint, or an NfruHeadR one (keys 'base.*' / 'synth.*')."""
    sd = torch.load(path, map_location=dev)
    if not any(k.startswith("synth.") for k in sd):
        return load_head_c2(path, dev)
    c = sd["synth.inp.weight"].shape[0]
    n = len({k.split(".")[2] for k in sd if k.startswith("synth.body.")})
    import tempfile, os
    base_sd = {k[5:]: v for k, v in sd.items() if k.startswith("base.")}
    tmp = os.path.join(tempfile.gettempdir(), "head_r_base.pt")
    torch.save(base_sd, tmp)
    head = NfruHeadR(load_head_c2(tmp, dev), c, n).to(dev).eval()
    head.load_state_dict(sd)
    return head
