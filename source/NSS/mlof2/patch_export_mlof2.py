p = 'E:/nss_VK/NSS/mlof2/export_mlof2_engine.py'
with open(p, 'r', encoding='utf-8') as f:
    text = f.read()

target = '''        if V2:                                # the encoder writes its pyramids in the pair graph's 8-bit format
            sp = MG.storage_plan(gp_, qs, "v2_" + fmt)       # the plan itself (v2_formats forces graph inputs fp32)
            io_p = {f"q{lv}": sp[f"q{lv}"] for lv in MG.ENC_LEVELS}'''

replacement = '''        if V2:                                # the encoder writes its pyramids in the pair graph's 8-bit format
            sp = MG.storage_plan(gp_, qs, "v2_" + fmt)       # the plan itself (v2_formats forces graph inputs fp32)
            qmax = 127.0 if fmt == "int8" else 448.0
            io_p = {f"q{lv}": sp[f"q{lv}"] if f"q{lv}" in sp else (fmt, float(qs.get(f"of.enc.q{lv}", qs.get(f"enc.q{lv}", 1.0))) / qmax) for lv in MG.ENC_LEVELS}'''

assert target in text, "Target not found in export_mlof2_engine.py"
text = text.replace(target, replacement, 1)

with open(p, 'w', encoding='utf-8') as f:
    f.write(text)

print("export_mlof2_engine.py updated successfully!")

