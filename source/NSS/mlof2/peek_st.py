import sys, glob
from safetensors import safe_open
for pat in sys.argv[1:]:
    for p in sorted(glob.glob(pat))[:1]:
        s = safe_open(p, "pt"); print(p.split("/")[-3:])
        for k in s.keys(): print("  ", k, s.get_slice(k).get_shape())
