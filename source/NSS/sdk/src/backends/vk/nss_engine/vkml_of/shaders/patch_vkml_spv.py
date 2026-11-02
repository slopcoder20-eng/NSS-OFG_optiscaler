"""Compile the AMD-tuned optical-flow shaders in this folder and replace their arrays in ../vkml_of_shaders_spv.hpp.
usage: python patch_vkml_spv.py [name ...]   (default: every *.comp here; name = file stem = array name)
The untouched arrays keep the original VKML SPIR-V. A backup of the header is kept as vkml_of_shaders_spv.hpp.orig."""
import os, re, shutil, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HDR = os.path.join(HERE, "..", "vkml_of_shaders_spv.hpp")
GLSLANG = r"C:\VulkanSDK\1.4.357.0\Bin\glslangValidator.exe"

names = sys.argv[1:] or sorted(f[:-5] for f in os.listdir(HERE) if f.endswith(".comp"))
if not os.path.exists(HDR + ".orig"):
    shutil.copyfile(HDR, HDR + ".orig")
s = open(HDR, encoding="utf-8").read()
for name in names:
    out = os.path.join(tempfile.gettempdir(), name + ".spv")
    subprocess.run([GLSLANG, "-V", "--target-env", "vulkan1.2", "-o", out, os.path.join(HERE, name + ".comp")], check=True)
    data = open(out, "rb").read()
    words = struct.unpack(f"<{len(data) // 4}I", data)
    body = ",\n".join(", ".join(f"0x{w:08x}u" for w in words[i:i + 8]) for i in range(0, len(words), 8))
    pat = re.compile(r"(inline constexpr uint32_t " + re.escape(name) + r"\[\] = \{)(.*?)(\};)", re.S)
    assert len(pat.findall(s)) == 1, f"array {name} not found exactly once"
    s = pat.sub(lambda m: m.group(1) + "\n" + body + "\n" + m.group(3), s)
    print(f"{name}: {len(words)} words")
open(HDR, "w", encoding="utf-8", newline="\n").write(s)
