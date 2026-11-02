p = 'E:/nss_VK/NSS/mlof2/mlof2_graph.py'
with open(p, 'r', encoding='utf-8') as f:
    text = f.read()

                     
old_loop = """        for i, lv in enumerate(p.LEVELS):
            if lv == 4:
                self.n = 1"""

new_loop = """        no_l4 = os.environ.get("MLOF2_OFT_NO_L4") == "1"
        levels = [lv for lv in p.LEVELS if not (no_l4 and lv == 4)]
        for i, lv in enumerate(levels):
            if lv == 4:
                self.n = 1"""

assert old_loop in text, "old_loop not found"
text = text.replace(old_loop, new_loop, 1)

                     
old_post = """        # level 4: propagation, then learned x4 to full res (both optional: the cut3 variant has neither)
        q4 = feats[4]"""

new_post = """        if no_l4:
            of_full = g.op("copy", [of], g.t("of8", 2, 8, n=self.n))
            g.op("copy", [conf_occ], g.t("conf_occ", 2, 8, n=self.n))
            return of_full

        # level 4: propagation, then learned x4 to full res (both optional: the cut3 variant has neither)
        q4 = feats[4]"""

assert old_post in text, "old_post not found"
text = text.replace(old_post, new_post, 1)

                                    
old_out = """    lo = _Lower(model, g)
    lo.pair(feats, c4, of4=of4)
    g.outputs = [of4 or "of_full", "conf_occ"]
    return g"""

new_out = """    lo = _Lower(model, g)
    lo.pair(feats, c4, of4=of4)
    if os.environ.get("MLOF2_OFT_NO_L4") == "1":
        g.outputs = ["of8", "conf_occ"]
    else:
        g.outputs = [of4 or "of_full", "conf_occ"]
    return g"""

assert old_out in text, "old_out not found"
text = text.replace(old_out, new_out, 1)

with open(p, 'w', encoding='utf-8') as f:
    f.write(text)

print("mlof2_graph.py updated successfully!")

