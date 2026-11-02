"""MLOF2 engine kernels: GLSL -> SPIR-V (VK) and -> HLSL SM6.6 -> DXIL (DX12, as harness/nfru_dx12/build_engine_dxil.py:
push constants become a cbuffer at b0 space1 = root constants). Writes
  build/<k>.spv, build/<k>.dxil, mlof2_shaders_spv.h (g_spv_<k>), mlof2_shaders_dxil.h (g_dxil_<k>)
and prints the DX12 registers each kernel uses (the DX12 root signature must match)."""
import os, re, shutil, subprocess, sys

D = os.path.dirname(os.path.abspath(__file__))
SRC, OUT = os.path.join(D, "shaders"), os.path.join(D, "build")
                             
BIN = os.environ.get("VULKAN_SDK", "")
if BIN and os.path.isdir(os.path.join(BIN, "Bin")):
    BIN = os.path.join(BIN, "Bin")
elif BIN and os.path.isdir(os.path.join(BIN, "bin")):
    BIN = os.path.join(BIN, "bin")
elif not BIN or not os.path.isfile(os.path.join(BIN, "glslangValidator.exe")):
    which_glslang = shutil.which("glslangValidator.exe")
    if which_glslang:
        BIN = os.path.dirname(which_glslang)
    elif os.path.isdir(r"C:\VulkanSDK\1.4.357.0\Bin"):
        BIN = r"C:\VulkanSDK\1.4.357.0\Bin"
    elif os.path.isdir(r"C:\VulkanSDK"):
        for v in sorted(os.listdir(r"C:\VulkanSDK"), reverse=True):
            cand = os.path.join(r"C:\VulkanSDK", v, "Bin")
            if os.path.isfile(os.path.join(cand, "glslangValidator.exe")):
                BIN = cand
                break
VK_KERNELS = ["mlof2_conv", "mlof2_ops", "mlof2_gen", "mlof2_conv_coop", "mlof2_unshuffle_conv", "mlof2_gen_red"]                           
VARIANTS = {"mlof2_gen_red": ("mlof2_gen", ["-DMLOF2_GEN_RED"])}                              
                                                                                                              
_kd = dict((m[0], int(m[1])) for m in re.findall(r"#define (K_[A-Z0-9_]+) (\d+)", open(os.path.join(SRC, "mlof2_common.glsl")).read()))
GEN_RED_KINDS = {"K_VIG_PART", "K_VIG_SOLVE", "K_MEDIAN", "K_MEDIAN_HIST", "K_MEDIAN_PICK", "K_HOMOG_ACC", "K_HOMOG_SOLVE"}
GEN_SPECIAL = [k for k, v in sorted(_kd.items(), key=lambda kv: kv[1]) if v >= 17 and k not in GEN_RED_KINDS]
for _k in GEN_SPECIAL:
    VK_KERNELS.append("mlof2_gen_" + _k[2:].lower())
    VARIANTS["mlof2_gen_" + _k[2:].lower()] = ("mlof2_gen", [f"-DMLOF2_KIND={_kd[_k]}"])
OPS_SPECIAL = [k for k, v in sorted(_kd.items(), key=lambda kv: kv[1]) if 1 <= v <= 14 and k != "K_CONV"]
for _k in OPS_SPECIAL:
    VK_KERNELS.append("mlof2_ops_" + _k[2:].lower())
    VARIANTS["mlof2_ops_" + _k[2:].lower()] = ("mlof2_ops", [f"-DMLOF2_KIND={_kd[_k]}"])
VK_KERNELS.append("mlof2_conv_w")                                                                 
VK_KERNELS.append("mlof2_conv_blk")                                                            
VK_KERNELS.append("mlof2_dense_dp4a")                                                                                    
VK_KERNELS.append("mlof2_depthwise_dp4a")                                                                               
VK_KERNELS.append("mlof2_oft_init")                                      
VK_KERNELS.append("mlof2_oft_prep")                                                       
VK_KERNELS.append("mlof2_oft_out")                                                         
VK_KERNELS.append("mlof2_oft_final")                                               
VK_KERNELS.append("mlof2_oft_lk")                                                
VK_KERNELS.append("mlof2_oft_luma")                                           
VK_KERNELS.append("mlof2_fuse_prep")                                                        
VK_KERNELS.append("mlof2_fuse_blend")                                    
VK_KERNELS.append("mlof2_cand_mv")                                         
DX_KERNELS = ["mlof2_conv", "mlof2_ops", "mlof2_gen", "mlof2_gen_red"]
DX_DEFINES = [d for d in os.environ.get("MLOF2_DX_DEFINES", "").split(",") if d]                
os.makedirs(OUT, exist_ok=True)


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"FAILED {' '.join(cmd[:3])}:\n{(r.stdout + r.stderr)[-2000:]}")


def arr(kind, name, data, width):
    if kind == "u32":
        w = [f"0x{int.from_bytes(data[i:i + 4], 'little'):08x}" for i in range(0, len(data), 4)]
        rows = [", ".join(w[i:i + 8]) for i in range(0, len(w), 8)]
        return f"static const uint32_t {name}[] = {{\n" + ",\n".join(rows) + f"\n}};\nstatic const size_t {name}_size = sizeof({name});\n"
    rows = [", ".join(f"0x{b:02x}" for b in data[i:i + width]) for i in range(0, len(data), width)]
    return f"static const unsigned char {name}[] = {{\n" + ",\n".join(rows) + f"\n}};\nstatic const size_t {name}_size = sizeof({name});\n"


def spv_nv2ext(path):
    """glslang knows VK_EXT_cooperative_matrix_maintenance1 only by its NV coopmat2 GLSL names: the per-element op,
    reduce and use conversion opcodes and the per-element / reductions capabilities are the same numbers; patch the
    conversions capability (NV 5431 -> EXT 5429) and the extension string (SPV_NV_cooperative_matrix2 ->
    SPV_EXT_cooperative_matrix_maintenance1)."""
    import struct
    raw = open(path, "rb").read()
    w = list(struct.unpack(f"<{len(raw) // 4}I", raw))
    out, i = w[:5], 5
    def sw(t):
        b = t.encode() + b"\0"
        b += b"\0" * (-len(b) % 4)
        return list(struct.unpack(f"<{len(b) // 4}I", b))
    while i < len(w):
        n, op = w[i] >> 16, w[i] & 0xFFFF
        ins = w[i:i + n]
        if op == 17 and ins[1] == 5431:
            ins = [ins[0], 5429]
        elif op == 10 and struct.pack(f"<{n - 1}I", *ins[1:]).split(b"\0")[0] == b"SPV_NV_cooperative_matrix2":
            e = sw("SPV_EXT_cooperative_matrix_maintenance1")
            ins = [((1 + len(e)) << 16) | 10] + e
        out += ins
        i += n
    open(path, "wb").write(struct.pack(f"<{len(out)}I", *out))


spv_h = ["// generated by mlof2_engine/build_mlof2_shaders.py -- do not edit", "#pragma once", "#include <stdint.h>", "#include <stddef.h>", ""]
for k in VK_KERNELS:
    spv = os.path.join(OUT, k + ".spv")
    src, defs = VARIANTS.get(k, (k, []))
    run([os.path.join(BIN, "glslangValidator.exe"), "-V", "--target-env", "vulkan1.3", "-I" + SRC] + defs + ["-o", spv, os.path.join(SRC, src + ".comp")])
    if "GL_NV_cooperative_matrix2" in open(os.path.join(SRC, src + ".comp")).read():
        spv_nv2ext(spv)
    spv_h.append(arr("u32", f"g_spv_{k}", open(spv, "rb").read(), 0))
    print(f"VK {k}: spv {os.path.getsize(spv)} B")
spv_h.append("// kernel table: index = Mlof2Dispatch.kernel; per-kind generation pipelines from index 6")
spv_h.append(f"static const int g_mlof2_num_kernels = {len(VK_KERNELS)};")
spv_h.append("static const char* const g_mlof2_kernel_names[] = {" + ", ".join(f'"{k}"' for k in VK_KERNELS) + "};")
spv_h.append("static const uint32_t* const g_mlof2_kernel_spv[] = {" + ", ".join(f"g_spv_{k}" for k in VK_KERNELS) + "};")
spv_h.append("static const size_t g_mlof2_kernel_spv_size[] = {" + ", ".join(f"g_spv_{k}_size" for k in VK_KERNELS) + "};")
open(os.path.join(D, "mlof2_shaders_spv.h"), "w", newline="\n").write("\n".join(spv_h))
kt = ["// generated by mlof2_engine/build_mlof2_shaders.py -- do not edit", "#pragma once",
      "// op kind -> its per-kind generation pipeline (kernel index), -1: the generic one",
      "static const int g_mlof2_gen_kernel_of_kind[64] = {" + ", ".join(
          str(6 + GEN_SPECIAL.index(k)) if k in GEN_SPECIAL else "-1"
          for k in [next((n for n, v in _kd.items() if v == i), "") for i in range(64)]) + "};"]
kt.append("// op kind -> its per-kind ops pipeline (kernel index), -1: generic mlof2_ops (1)")
kt.append("static const int g_mlof2_ops_kernel_of_kind[64] = {" + ", ".join(
    str(VK_KERNELS.index("mlof2_ops_" + k[2:].lower())) if k in OPS_SPECIAL else "-1"
    for k in [next((n for n, v in _kd.items() if v == i), "") for i in range(64)]) + "};")
kt.append(f"static const int g_mlof2_kernel_conv_w = {VK_KERNELS.index('mlof2_conv_w')};")
kt.append(f"static const int g_mlof2_kernel_conv_blk = {VK_KERNELS.index('mlof2_conv_blk')};")
kt.append(f"static const int g_mlof2_kernel_dense_dp4a = {VK_KERNELS.index('mlof2_dense_dp4a')};")
kt.append(f"static const int g_mlof2_kernel_depthwise_dp4a = {VK_KERNELS.index('mlof2_depthwise_dp4a')};")
kt.append(f"static const int g_mlof2_kernel_oft_init = {VK_KERNELS.index('mlof2_oft_init')};")
kt.append(f"static const int g_mlof2_kernel_oft_prep = {VK_KERNELS.index('mlof2_oft_prep')};")
kt.append(f"static const int g_mlof2_kernel_oft_out = {VK_KERNELS.index('mlof2_oft_out')};")
kt.append(f"static const int g_mlof2_kernel_oft_final = {VK_KERNELS.index('mlof2_oft_final')};")
kt.append(f"static const int g_mlof2_kernel_oft_lk = {VK_KERNELS.index('mlof2_oft_lk')};")
kt.append(f"static const int g_mlof2_kernel_oft_luma = {VK_KERNELS.index('mlof2_oft_luma')};")
kt.append(f"static const int g_mlof2_kernel_fuse_prep = {VK_KERNELS.index('mlof2_fuse_prep')};")
kt.append(f"static const int g_mlof2_kernel_fuse_blend = {VK_KERNELS.index('mlof2_fuse_blend')};")
kt.append(f"static const int g_mlof2_kernel_cand_mv = {VK_KERNELS.index('mlof2_cand_mv')};")
open(os.path.join(D, "mlof2_kernel_table.h"), "w", newline="\n").write("\n".join(kt) + "\n")

dx_h = ["// generated by mlof2_engine/build_mlof2_shaders.py -- do not edit", "#pragma once", "#include <stdint.h>", "#include <stddef.h>", ""]
for k in DX_KERNELS:
    spv = os.path.join(OUT, k + ".spv")
    hl, dx = (os.path.join(OUT, k + e) for e in (".hlsl", ".dxil"))
    spv_dx = os.path.join(OUT, k + "_dx.spv")                                                                   
    if True:
        src, defs = VARIANTS.get(k, (k, []))
        run([os.path.join(BIN, "glslangValidator.exe"), "-V", "--target-env", "vulkan1.3", "-I" + SRC] + defs + ["-DMLOF2_DX"] + [f"-D{d}" for d in DX_DEFINES] +
            ["-o", spv_dx, os.path.join(SRC, src + ".comp")])
    run([os.path.join(BIN, "spirv-cross.exe"), spv_dx, "--hlsl", "--shader-model", "66", "--output", hl])
    s = open(hl, encoding="utf-8").read()
    s, n = re.subn(r"^cbuffer (\w+)\s*$", r"cbuffer \1 : register(b0, space1)", s, flags=re.M)
    open(hl, "w", encoding="utf-8").write(s)
    run([os.path.join(BIN, "dxc.exe"), "-T", "cs_6_6", "-E", "main", "-O3", "-Fo", dx, hl])
    regs = sorted(set(re.findall(r"register\(([tub])(\d+), space0\)", s)), key=lambda x: (x[0], int(x[1])))
    dx_h.append(f"// {k}: push constants {'b0 space1' if n else 'NONE'}, registers " + " ".join(a + b for a, b in regs))
    dx_h.append(arr("u8", f"g_dxil_{k}", open(dx, "rb").read(), 24))
    print(f"DX {k}: dxil {os.path.getsize(dx)} B, DX12 registers {' '.join(a + b for a, b in regs)}")
open(os.path.join(D, "mlof2_shaders_dxil.h"), "w", newline="\n").write("\n".join(dx_h))

print("wrote mlof2_shaders_spv.h, mlof2_shaders_dxil.h")
