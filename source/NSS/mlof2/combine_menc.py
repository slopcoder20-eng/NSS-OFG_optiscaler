"""OF checkpoint + probe MatchEncoder -> one checkpoint whose recurrent block reads the MatchEncoder (teacher flag off).
  python combine_menc.py <OF ckpt> <menc ckpt> <out>"""
import sys, torch
a, mc, out = sys.argv[1:4]
sd = torch.load(a, map_location="cpu"); sd = dict(sd.get("model", sd))
sd.pop("pair.rec.tfeat_buf", None)
for k, v in torch.load(mc, map_location="cpu")["menc"].items():
    sd["enc.menc." + k] = v
torch.save(sd, out); print("saved", out, len(sd))
