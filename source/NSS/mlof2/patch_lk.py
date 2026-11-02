p = 'E:/nss_VK/NSS/mlof2/mlof2_oft_lower.py'
with open(p, 'rb') as f:
    data = f.read()

                                   
old_part = b'    # LK Refinement at Scale 2 (half-res 544x960, 3 iterations)\r\n    for it in range(3):'
if old_part not in data:
    old_part = b'    # LK Refinement at Scale 2 (half-res 544x960, 3 iterations)\n    for it in range(3):'

new_part = b'    # LK Refinement at Scale 2 (half-res 544x960, default 2 iterations)\r\n    import os\r\n    lk_iters = int(os.environ.get("MLOF2_LK_ITERS", "2"))\r\n    for it in range(lk_iters):'

assert old_part in data, "old_part not found"
data = data.replace(old_part, new_part, 1)

with open(p, 'wb') as f:
    f.write(data)

print("mlof2_oft_lower.py updated successfully!")
