import torch
from nfru_head import NfruHead, NFRUAutoEncoder, load_arm
ae = NFRUAutoEncoder(); n = load_arm(ae)
print("arm tensors loaded", n, "params", sum(p.numel() for p in ae.parameters()))
x = torch.rand(2, 16, 224, 224); print("ae out", tuple(ae(x).shape))
