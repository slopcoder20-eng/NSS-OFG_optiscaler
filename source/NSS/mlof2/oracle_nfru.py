"""Ceiling of the 4-candidate NFRU blend on the validation set (clean + augmented, same RNG as validate()):
per pixel best candidate (closest to G, L1 over RGB) vs the trained head vs the MLOF2 TimeHead.
  python oracle_nfru.py <mlof2 ckpt> <head ckpt> [n_batches]"""
import sys, random
import torch
from model_v2 import build_mlof2
from data_v2 import WindowDataset
from augment_v2 import augment
from train_v2 import to_dev, psnr
from nfru_head import NfruHead
from train_nfru_head import forward

dev = "cuda"
sd = torch.load(sys.argv[1], map_location=dev)
m = build_mlof2(sd).to(dev).eval(); m.load_state_dict(sd.get("model", sd))
head = NfruHead(arm_init=False).to(dev).eval(); head.load_state_dict(torch.load(sys.argv[2], map_location=dev))
nb = int(sys.argv[3]) if len(sys.argv) > 3 else 40
vl = torch.utils.data.DataLoader(WindowDataset(["forest15", "lyra15", "lyra17"], "validation", crop=448, windows_per_file=8),
                                 batch_size=4, shuffle=False, num_workers=0)
rng = random.Random(1234)
acc = {f"{v}_{k}": [] for v in ("clean", "aug") for k in ("head", "mlof2", "oracle", "oracle_flow", "c1", "c2", "c3", "c4")}
with torch.no_grad():
    for bi, b in enumerate(vl):
        if bi >= nb: break
        b = to_dev(b, dev)
        for ver in ("clean", "aug"):
            if ver == "aug": augment(b, rng)
            out, frame, _ = forward(m, head, b, True)
            g, c = b["color_g"], out["cand"]                                    
            err = (c - g[:, None]).abs().sum(2)                                
            best = err.argmin(1, keepdim=True)
            orc = torch.gather(c, 1, best[:, :, None].expand(-1, 1, 3, -1, -1))[:, 0]
            bf = err[:, 2:].argmin(1, keepdim=True) + 2                                          
            orf = torch.gather(c, 1, bf[:, :, None].expand(-1, 1, 3, -1, -1))[:, 0]
            acc[f"{ver}_head"].append(psnr(out["color"], g)); acc[f"{ver}_mlof2"].append(psnr(frame["color"], g))
            acc[f"{ver}_oracle"].append(psnr(orc, g)); acc[f"{ver}_oracle_flow"].append(psnr(orf, g))
            for j in range(4): acc[f"{ver}_c{j + 1}"].append(psnr(c[:, j], g))
mean = lambda v: sum(v) / len(v)
for ver in ("clean", "aug"):
    print(f"{ver}: head {mean(acc[ver + '_head']):.2f} | MLOF2 TimeHead {mean(acc[ver + '_mlof2']):.2f} | ORACLE best-of-4 {mean(acc[ver + '_oracle']):.2f} "
          f"| oracle flow-only (3,4) {mean(acc[ver + '_oracle_flow']):.2f} | single cand mvA {mean(acc[ver + '_c1']):.2f} mvB {mean(acc[ver + '_c2']):.2f} "
          f"flowA {mean(acc[ver + '_c3']):.2f} flowB {mean(acc[ver + '_c4']):.2f}")
