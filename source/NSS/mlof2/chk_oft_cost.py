from oft_block import OFTNet, gmac
for w, n in (((128, 96, 64, 48), (3, 3, 3, 3)), ((64, 48, 32, 24), (3, 3, 3, 3)), ((64, 48, 32, 24), (2, 2, 2, 2)),
             ((48, 32, 24), (2, 2, 2))):
    o = OFTNet(w, n)
    print(w, n, "params", sum(p.numel() for p in o.parameters()), "GMAC/t", round(gmac(o), 2))
H4, W4 = 1088 // 4, 1920 // 4
enc = (H4 * 2 * W4 * 2 * 3 * 16 * 9 + H4 * W4 * 16 * 32 * 9 + H4 * W4 * 32 * 32 * 9) / 1e9
corr = 2 * H4 * W4 * 49 * 32 / 1e9
inj = H4 * W4 * 98 * 24 / 1e9
print("feature encoder per real frame", round(enc, 2), "| corr both sides per t", round(corr, 2), "| corr 1x1 into the block", round(inj, 2))
