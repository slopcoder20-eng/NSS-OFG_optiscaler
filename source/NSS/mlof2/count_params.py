"""Parameter count per module of the current MLOF2 (convex_up + deep16 + up_full) and the NFRU head C2."""
from model_v2 import MLOF2
from nfru_head import NfruHeadC2

m = MLOF2(convex_up=True, deep16=True, up_full=True)
c = lambda mod: sum(p.numel() for p in mod.parameters())
p = m.pair
print(f"total MLOF2 {c(m):,}")
print(f"  encoder {c(m.enc):,}")
for k, v in p.upd.items():
    print(f"  OF level 1/{k}: {c(v):,}")
print(f"  DeepRefine {c(p.deep):,}   UpFull {c(p.upf):,}")
print(f"  OF network total (encoder + levels + DeepRefine + UpFull) {c(m.enc) + c(p.upd) + c(p.deep) + c(p.upf):,}")
print(f"  gate {c(p.gate8) + c(p.gate4):,}   TimeHead {c(m.head):,}")
print(f"NFRU head C2 {c(NfruHeadC2(arm_init=False)):,}")
