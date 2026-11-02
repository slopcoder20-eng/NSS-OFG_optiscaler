import sys, torch
sd = torch.load(sys.argv[1], map_location="cpu")
print("nan params:", sum(int(torch.isnan(v).any()) for v in sd.values() if v.is_floating_point()), "of", len(sd))
