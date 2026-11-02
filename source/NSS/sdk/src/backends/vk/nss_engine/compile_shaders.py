import subprocess, os, sys
SDK_BIN = r"C:\VulkanSDK\1.4.357.0\Bin\glslangValidator.exe"
D = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(D, "shaders_src")
OUT_HEADER = os.path.join(D, "shaders_spv.h")
shaders = [
    ("conv2d_fused_coopmat", "g_spv_conv2d_fused_coopmat"),
    ("conv2d_fused_coopmat_s1", "g_spv_conv2d_fused_coopmat_s1"),
    ("conv2d_fused_coopmat_c16", "g_spv_conv2d_fused_coopmat_c16"),
    ("conv2d_fused_coopmat_c32", "g_spv_conv2d_fused_coopmat_c32"),
    ("conv2d_fused_coopmat_c32_pt2", "g_spv_conv2d_fused_coopmat_c32_pt2"),
    ("conv2d_fused_coopmat_2d", "g_spv_conv2d_fused_coopmat_2d"),
    ("conv2d_fused_coopmat_pt2", "g_spv_conv2d_fused_coopmat_pt2"),
    ("conv2d_fused_c4", "g_spv_conv2d_fused_c4"),
    ("conv2d_fused_dp4a_c16", "g_spv_conv2d_fused_dp4a_c16"),
    ("conv2d_fused_dp4a", "g_spv_conv2d_fused_dp4a"),
    ("conv2d_fused_dp4a_1440", "g_spv_conv2d_fused_dp4a_1440"),
    ("conv2d_fused_dp4a_2160", "g_spv_conv2d_fused_dp4a_2160"),
    ("conv2d_fused_dp4a_narrow_tiled", "g_spv_conv2d_fused_dp4a_narrow_tiled"),
    ("conv2d_fused_dp4a_tiled_s1", "g_spv_conv2d_fused_dp4a_tiled_s1"),
    ("conv2d_fused_dp4a_tiled_s2", "g_spv_conv2d_fused_dp4a_tiled_s2"),
    ("conv2d_fused_dp4a_tiled_s1_t16", "g_spv_conv2d_fused_dp4a_tiled_s1_t16"),
    ("resize_nearest_2x", "g_spv_resize_nearest_2x"),
    ("concat_channels", "g_spv_concat_channels"),
    ("nss_preprocess", "g_spv_nss_preprocess"),
    ("nss_preprocess_1440", "g_spv_nss_preprocess_1440"),
    ("nss_preprocess_2160", "g_spv_nss_preprocess_2160"),
    ("nss_postprocess", "g_spv_nss_postprocess"),
    ("nss_postprocess_1440", "g_spv_nss_postprocess_1440"),
    ("nss_postprocess_2160", "g_spv_nss_postprocess_2160"),
    ("nfru_conv", "g_spv_nfru_conv"),
    ("nfru_conv_dp4a_c16_1x1", "g_spv_nfru_conv_dp4a_c16_1x1"),
    ("nfru_concat", "g_spv_nfru_concat"),
    ("nfru_conv_coopmat", "g_spv_nfru_conv_coopmat"),
    ("nfru_conv_narrow_tiled", "g_spv_nfru_conv_narrow_tiled"),
    ("nfru_conv_coopmat_small", "g_spv_nfru_conv_coopmat_small"),
    ("nfru_conv_coopmat_medium", "g_spv_nfru_conv_coopmat_medium"),
    ("nfru_conv_coopmat_5x5s2", "g_spv_nfru_conv_coopmat_5x5s2"),
    ("nfru_of", "g_spv_nfru_of"),
]
out = []
for name, var in shaders:
    src = os.path.join(SRC, name + ".comp"); spv = os.path.join(SRC, name + ".spv")
    r = subprocess.run([SDK_BIN, "-V", "--target-env", "vulkan1.3", "-o", spv, src], capture_output=True, text=True)
    if r.returncode != 0:
        print("ERROR", name, r.stdout, r.stderr); sys.exit(1)
    data = open(spv, "rb").read()
    words = ["0x%08x" % int.from_bytes(data[i:i+4], "little") for i in range(0, len(data), 4)]
    lines = ["static const uint32_t %s[%d] = {" % (var, len(words))]
    for i in range(0, len(words), 8):
        lines.append("    " + ", ".join(words[i:i+8]) + ",")
    lines.append("};\n")
    lines.append("static const size_t %s_size = sizeof(%s);\n" % (var, var))
    out.append("\n".join(lines))
open(OUT_HEADER, "w", encoding="utf-8").write("#pragma once\n#include <stdint.h>\n\n" + "\n".join(out))
print("OK", OUT_HEADER)
