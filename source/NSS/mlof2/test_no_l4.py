import os, sys, torch
sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
from model_v2 import build_mlof2
import mlof2_graph as MG

ck = "/home/sh/mlof2_runs/v2_of_cut3/s2000.pt"
sd = torch.load(ck, map_location="cpu")
m = build_mlof2(sd).eval()
m.load_state_dict(sd.get("model", sd))

for p in ("prop4", "up_full", "deep16"):
    setattr(m.pair, p, False)

                                   
g_def = MG.build_pair_graph(m)
print("Default pair graph:")
print(f"  Ops: {len(g_def.ops)}")
print(f"  Inputs: {g_def.inputs}")
print(f"  Outputs: {g_def.outputs}")

                       
                                                      
os.environ["MLOF2_OFT_NO_L4"] = "1"
                   
class CustomPairLower(MG._Lower):
    def pair_nol4(self, feats, c4):
        g, p = self.g, self.m.pair
        ctxc = p.ctx
        of = conf_occ = ctx = upmask = None
        qcs = {4: c4}
        prev = c4
        for lv in [8, 16, 32, 64]:
            qcs[lv] = prev = g.op("resize_area", [prev], self.new(f"qc{lv}", 3, lv), s_out=lv)
        
        levels = [64, 32, 16, 8]                   
        for i, lv in enumerate(levels):
            q = feats[lv]
            r = q + "~"
            ch = g.chans(q)
            qc = qcs[lv]
            rc = qc + "~"
            cue = self.new(f"cue{lv}", 8, lv)
            if of is None:
                of = g.op("zeros", [], self.new(f"of{lv}", 2, lv))
                g.op("zeros", [], f"{cue}[6:8]")
            else:
                of = g.op("convex_up", [of, upmask], self.new(f"of{lv}", 2, lv, n=self.n), f=2)
                ctx = g.op("resize_bil", [ctx], self.new(f"ctx{lv}", ctxc, lv), s_out=lv, mul=[1.0] * ctxc)
                g.op("resize_bil", [conf_occ], f"{cue}[6:8]", s_out=lv, mul=[1.0, 1.0])
            ref = g.op("warp", [r, of], self.new(f"ref{lv}", ch, lv))
            rad = p.radius[lv]
            nc = (2 * rad + 1) ** 2
            corr = g.op("corr", [q, ref], self.new(f"corr{lv}", nc, lv), radius=rad)
            self.explain(q, r, qc, rc, of, ref=ref, dst=cue)
            g.op("scale", [of], f"{cue}[4:6]", k=1 / 16.0)
            parts = [self.full(q), self.full(ref), self.padded(corr, MG.M.pad_c(nc)), self.padded(cue, p.of_cue)]
            if i:
                parts.append(self.full(ctx))
            fc, ctx, upmask = self.update(p.upd[str(lv)], parts, lv, ctxc, is_last=True)
            of = g.op("axpy", [of, f"{fc}[0:2]"], self.new(f"of{lv}u", 2, lv), k=4.0 if i == 0 else 1.0)
            conf_occ = f"{fc}[2:4]"
        
        of_out = g.op("copy", [of], g.t("of8", 2, 8, n=self.n))
        g.op("copy", [conf_occ], g.t("conf_occ", 2, 8, n=self.n))
        return of_out

g_nol4 = MG.Graph()
c4 = g_nol4.t("c4", 3, 4)
ch = m.enc.CH
feats = {lv: g_nol4.t(f"q{lv}", ch[lv], lv) for lv in MG.ENC_LEVELS}
g_nol4.inputs = [c4] + [feats[lv] for lv in MG.ENC_LEVELS]
lo = CustomPairLower(m, g_nol4)
lo.pair_nol4(feats, c4)
g_nol4.outputs = ["of8", "conf_occ"]

print("\nNo-L4 pair graph:")
print(f"  Ops: {len(g_nol4.ops)} (vs {len(g_def.ops)}, -{len(g_def.ops) - len(g_nol4.ops)} ops!)")
print(f"  Inputs: {g_nol4.inputs}")
print(f"  Outputs: {g_nol4.outputs}")

