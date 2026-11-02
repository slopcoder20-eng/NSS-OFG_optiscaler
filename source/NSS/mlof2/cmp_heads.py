import sys, torch
a = torch.load(sys.argv[1], map_location="cpu"); b = torch.load(sys.argv[2], map_location="cpu")
from nfru_head import NFRUAutoEncoder, load_arm
ae = NFRUAutoEncoder(); load_arm(ae); arm = {"ae." + k: v for k, v in ae.state_dict().items()}
for k in list(a)[:4] + [k for k in a if "output_conv" in k]:
    if a[k].dtype.is_floating_point:
        print(f"{k:38s} |a-b| {float((a[k]-b[k]).abs().max()):.2e}  |a-arm| {float((a[k]-arm[k]).abs().max()):.2e}  |a| {float(a[k].abs().max()):.2e}")
