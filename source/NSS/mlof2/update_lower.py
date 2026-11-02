p = 'E:/nss_VK/NSS/mlof2/mlof2_oft_lower.py'
with open(p, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if 'fa_s1 = g.op("resize_bil", [fa_cur]' in line:
        skip = True
        new_lines.append('    # Progressive 2x upsample fused on-the-fly inside oft_final\n')
        new_lines.append('    col_out = lower.new("color_out", 4, 1)\n')
        new_lines.append('    g.op("oft_final", [col_a, col_b, fa_cur, fb_cur, m_cur], col_out)\n')
        new_lines.append('    g.outputs = [col_out, fa_cur, fb_cur]\n')
        continue
    if skip:
        if 'g.outputs = [col_out, fa_s1, fb_s1]' in line:
            skip = False
        continue
    new_lines.append(line)

with open(p, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Updated successfully")

