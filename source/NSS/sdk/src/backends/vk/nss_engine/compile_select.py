                                                                                                                         
import subprocess, os, sys
SDK_BIN = r"C:\VulkanSDK\1.4.357.0\Bin\glslangValidator.exe"
D = os.path.dirname(os.path.abspath(__file__)); SRC = os.path.join(D, "shaders_src")
out = []
for name in ("nfru_select_feat", "nfru_select_conv", "nfru_select_blend", "nfru_select_feat_i8", "nfru_select_concat_i8", "nfru_select_blend_i8", "nfru_select_logits_f32", "nfru_select_blend_f"):
    src = os.path.join(SRC, name + ".comp"); spv = os.path.join(SRC, name + ".spv")
    r = subprocess.run([SDK_BIN, "-V", "--target-env", "vulkan1.3", "-o", spv, src], capture_output=True, text=True)
    if r.returncode != 0:
        print("ERROR", name, r.stdout, r.stderr); sys.exit(1)
    data = open(spv, "rb").read(); var = "g_spv_" + name
    words = ["0x%08x" % int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
    lines = ["static const uint32_t %s[%d] = {" % (var, len(words))]
    lines += ["    " + ", ".join(words[i:i + 8]) + "," for i in range(0, len(words), 8)]
    lines.append("};\n")
    out.append("\n".join(lines))
open(os.path.join(D, "nfru_select_spv.h"), "w", encoding="utf-8").write("#pragma once\n#include <stdint.h>\n\n" + "\n".join(out))
print("OK")
