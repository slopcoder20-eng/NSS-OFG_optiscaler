"""Pass / fail of an OF run against v2_of_menc/s1500: reads 'of1 fol' of the 5 crops (SP_0038 c0 c1, SP_0045 c0 c1,
SP_0004) after a '#### <ckpt> <crop>' header in a log. PASS = mean foliage ratio <= 0.97 and SP_0004 <= 27.56.
  python of_gate.py <log> <ckpt substring>"""
import sys, re
log, key = sys.argv[1:3]
REF = {"SP_0038/crop_00": 6.131, "SP_0038/crop_01": 8.211, "SP_0045/crop_00": 4.730, "SP_0045/crop_01": 10.844, "SP_0004/crop_00": 27.280}
cur, got = None, {}
for line in open(log):
    m = re.match(r"#### (\S+) (SP_\d+/crop_\d+)", line)
    if m:
        cur = m.group(2) if key in m.group(1) else None
        continue
    m = re.match(r"\s+of1 fol\s+([\d.]+)", line)
    if m and cur:
        got[cur] = float(m.group(1))
r = [got[k] / v for k, v in REF.items() if k in got]
mean = sum(r) / max(len(r), 1)
ok = len(r) == 5 and mean <= 0.97 and got.get("SP_0004/crop_00", 1e9) <= 27.56
print(" ".join(f"{k.split('/')[0][3:]}{k[-1]} {got.get(k, float('nan')):.2f}" for k in REF), f"| mean ratio vs menc {mean:.3f} ->",
      "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
