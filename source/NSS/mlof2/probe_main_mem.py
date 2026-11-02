"""Host RSS of the training main process, stage by stage (no DataLoader workers)."""
import os, sys, torch
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def rss(tag):
    d = {l.split(":")[0]: l.split()[1] for l in open("/proc/self/status") if l.startswith(("VmRSS", "RssAnon", "RssShmem"))}
    print(f"{tag:34s} RSS {int(d['VmRSS'])/1e6:5.2f} GB  anon {int(d['RssAnon'])/1e6:5.2f}  shmem {int(d['RssShmem'])/1e6:5.2f}", flush=True)


rss("python + torch import")
torch.zeros(1, device="cuda"); rss("cuda init")
from model_v2 import MLOF2
from data_v2 import WindowDataset
m = MLOF2(convex_up=True, deep16=True).cuda(); rss("model on gpu")
opt = torch.optim.AdamW(m.parameters(), lr=1e-4)
for h, w, b in ((448, 448, 4), (1024, 1920, 2)):
    ca, cb = torch.rand(b, 3, h, w, device="cuda"), torch.rand(b, 3, h, w, device="cuda")
    da, db = torch.rand(b, 1, h, w, device="cuda"), torch.rand(b, 1, h, w, device="cuda")
    of = m.pair.of_forward(m.enc(ca, da), m.enc(cb, db), ca, cb)[4]["of"]
    of.float().abs().mean().backward(); opt.step(); opt.zero_grad()
    torch.cuda.synchronize(); rss(f"fwd+bwd {h}x{w} b{b}")
st = WindowDataset(["spring"], "train", crop=(1024, 1920), strides=(1, 2, 4, 8, 12)); rss("spring dataset object")
x = st[0]; rss("one spring sample in main")
p = {k: v.pin_memory() for k, v in x.items() if torch.is_tensor(v)}; rss("pinned copy of one sample")
print("sample MB", sum(v.numel() * v.element_size() for v in x.values() if torch.is_tensor(v)) / 1e6)

for k, v in x.items():
    if torch.is_tensor(v): print(k, tuple(v.shape), v.dtype, round(v.numel() * v.element_size() / 1e6, 1))
