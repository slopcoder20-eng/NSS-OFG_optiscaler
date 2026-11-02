"""Drop the recurrent block from a checkpoint (its delta head learned ~nothing): python strip_rec.py <in> <out>"""
import sys, torch
sd = torch.load(sys.argv[1], map_location="cpu"); sd = {k: v for k, v in sd.get("model", sd).items() if not k.startswith("pair.rec.")}
torch.save(sd, sys.argv[2]); print("saved", sys.argv[2], len(sd))
