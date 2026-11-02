"""SEA-RAFT (Wang, Lipson, Deng, ECCV 2024; github.com/princeton-vl/SEA-RAFT, BSD-3-Clause,
(c) 2024 Princeton Vision & Learning Lab) as a frozen optical-flow teacher for the MLOF2 OF stage.
Weights: Hugging Face MemorySlices/Tartan-C-T-TSKH-spring540x960-M (bsd-3-clause). The repository is used as is
(not copied into this tree): SEARAFT_ROOT points at a clone.

flow_ba(color_b, color_a) -> (flow B->A in px of the input grid, log-scale uncertainty, mixture weight)
Images: (N,3,H,W) display-referred [0,1] (the SEA-RAFT models take 0..255 RGB)."""
import os
import sys
import json
import argparse
import torch
from torch.nn import functional as F

SEARAFT_ROOT = os.environ.get("SEARAFT_ROOT", "/home/sh/third_party/SEA-RAFT")
HF_ID = os.environ.get("SEARAFT_HF", "MemorySlices/Tartan-C-T-TSKH-spring540x960-M")


class SeaRaftTeacher:
    def __init__(self, dev="cuda", cfg="spring-M", iters=None):
        sys.path.insert(0, os.path.join(SEARAFT_ROOT, "core"))
        from raft import RAFT                                                           
        with open(os.path.join(SEARAFT_ROOT, "config", "eval", f"{cfg}.json")) as f:
            args = argparse.Namespace(**json.load(f))
        if iters:
            args.iters = iters
        self.args = args
        self.model = RAFT.from_pretrained(HF_ID, args=args).to(dev).eval()
        for p in self.model.parameters():
            p.requires_grad_(False)

    @torch.no_grad()
    def flow_ba(self, color_b, color_a, scale=1.0):
        """Flow at B pixels pointing into A (same convention as the engine MV chain geo_flow_ba).
        scale != 1 runs the teacher on a resized pair (SEA-RAFT trained around 540x960)."""
        H, W = color_b.shape[-2:]
        b, a = color_b * 255.0, color_a * 255.0
        if scale != 1.0:
            h, w = int(round(H * scale / 8) * 8), int(round(W * scale / 8) * 8)
            b = F.interpolate(b, size=(h, w), mode="bilinear", align_corners=False)
            a = F.interpolate(a, size=(h, w), mode="bilinear", align_corners=False)
        else:
            h, w = H, W
        out = self.model(b, a, iters=self.args.iters, test_mode=True)
        flow, info = out["flow"][-1].float(), out["info"][-1].float()
        if (h, w) != (H, W):
            flow = F.interpolate(flow, size=(H, W), mode="bilinear", align_corners=False)
            flow = torch.cat((flow[:, :1] * (W / w), flow[:, 1:2] * (H / h)), 1)
            info = F.interpolate(info, size=(H, W), mode="bilinear", align_corners=False)
                                                                                                         
        weight = info[:, :2].softmax(1)
        log_b = torch.stack((info[:, 2].clamp(0, self.args.var_max), info[:, 3].clamp(self.args.var_min, 0)), 1)
        unc = (log_b * weight).sum(1, keepdim=True)
        return flow, unc, weight
