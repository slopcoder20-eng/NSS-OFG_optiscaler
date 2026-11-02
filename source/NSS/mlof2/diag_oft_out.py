"""Are the OFT blocks' flow outputs alive? Per block: |out weight| for the flow channels (pixel_shuffle groups 0-3 =
channels 0..63) vs the mask channel group (64..79); and the actual |d flow| on a random input."""
import sys, torch
from oft_block import OFTNet
sd = torch.load(sys.argv[1], map_location="cpu")
nbl = len({k.split(".")[1] for k in sd if k.startswith("blocks.")})
for i in range(nbl):
    w = sd[f"blocks.{i}.out.weight"]
    print(f"block {i}: |w| flow ch 0-63 {w[:64].abs().mean():.2e}  mask ch 64-79 {w[64:].abs().mean():.2e}  "
          f"bias flow {sd[f'blocks.{i}.out.bias'][:64].abs().mean():.2e}")
nb = [len({k.split(".")[3] for k in sd if k.startswith(f"blocks.{i}.body.")}) for i in range(nbl)]
net = OFTNet(tuple(sd[f"blocks.{i}.d2.weight"].shape[0] for i in range(nbl)), tuple(nb),
             corr=any(k.startswith("feat.") for k in sd)).eval()
net.load_state_dict(sd)
x = torch.rand(1, 3, 256, 256)
y = torch.roll(x, 3, -1)
with torch.no_grad():
    o = net(torch.tensor([0.5]), x, y, torch.zeros(1, 2, 64, 64), torch.zeros(1, 2, 64, 64))
print("final |f_ta| mean", float(o["f_ta"].abs().mean()), "|f_tb|", float(o["f_tb"].abs().mean()), "vis", float(o["vis"].mean()))
