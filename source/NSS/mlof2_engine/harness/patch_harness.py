path = 'E:/nss_VK/NSS/mlof2_engine/harness/mlof2_vk_harness.cpp'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

target = """    for (int k = 0; k < g_mlof2_num_kernels; ++k) {
        VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smi.codeSize = sizes[k]; smi.pCode = codes[k]; VkShaderModule sm; CK(vkCreateShaderModule(dev, &smi, nullptr, &sm));
        smod[k] = sm;
        if (k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk) { pipe[k] = VK_NULL_HANDLE; continue; }   // only per-layer specializations"""

replacement = """    bool used_kernel[128] = {false};
    for (const auto& d : plan.dispatches) if (d.kernel < 128) used_kernel[d.kernel] = true;
    for (int k = 0; k < g_mlof2_num_kernels; ++k) {
        VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smi.codeSize = sizes[k]; smi.pCode = codes[k]; VkShaderModule sm; CK(vkCreateShaderModule(dev, &smi, nullptr, &sm));
        smod[k] = sm;
        if (k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk) { pipe[k] = VK_NULL_HANDLE; continue; }   // only per-layer specializations
        if (!used_kernel[k]) { pipe[k] = VK_NULL_HANDLE; continue; }"""

assert target in text, 'target not found'
text = text.replace(target, replacement, 1)
with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text)
print('Successfully patched used_kernel filter in mlof2_vk_harness.cpp')
