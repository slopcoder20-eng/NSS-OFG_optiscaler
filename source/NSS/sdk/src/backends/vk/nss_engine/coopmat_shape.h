#pragma once
#include <vulkan/vulkan.h>
#include <vector>
#include <cstring>

struct NssCoopShape {
    uint32_t m = 0, n = 0, k = 0;
    bool native16() const { return m == 16 && n == 16 && k == 16; }
};

                                                                                           
inline bool nssQueryCoopShape(VkInstance instance, VkPhysicalDevice pd, NssCoopShape& shape) {
    shape = {};
    if (!instance || !pd) return false;
    uint32_t count = 0;
    if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &count, nullptr) != VK_SUCCESS) return false;
    std::vector<VkExtensionProperties> exts(count);
    if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &count, exts.data()) != VK_SUCCESS) return false;
    bool present = false;
    for (const auto& e : exts) if (!strcmp(e.extensionName, VK_KHR_COOPERATIVE_MATRIX_EXTENSION_NAME)) present = true;
    if (!present) return false;
    VkPhysicalDeviceVulkan12Features f12{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES};
    VkPhysicalDeviceCooperativeMatrixFeaturesKHR cf{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR};
    cf.pNext = &f12;
    VkPhysicalDeviceFeatures2 f{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, &cf};
    vkGetPhysicalDeviceFeatures2(pd, &f);
    if (!cf.cooperativeMatrix || !f12.shaderInt8 || !f12.storageBuffer8BitAccess) return false;
    VkPhysicalDeviceCooperativeMatrixPropertiesKHR cp{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_PROPERTIES_KHR};
    VkPhysicalDeviceSubgroupProperties sg{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES, &cp};
    VkPhysicalDeviceProperties2 limits{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2, &sg};
    vkGetPhysicalDeviceProperties2(pd, &limits);
    if (!(cp.cooperativeMatrixSupportedStages & VK_SHADER_STAGE_COMPUTE_BIT) || !sg.subgroupSize ||
        sg.subgroupSize > limits.properties.limits.maxComputeWorkGroupInvocations ||
        sg.subgroupSize > limits.properties.limits.maxComputeWorkGroupSize[0]) return false;
    auto fn = reinterpret_cast<PFN_vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR>(
        vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR"));
    if (!fn || fn(pd, &count, nullptr) != VK_SUCCESS || !count) return false;
    std::vector<VkCooperativeMatrixPropertiesKHR> props(count, {VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_KHR});
    if (fn(pd, &count, props.data()) != VK_SUCCESS) return false;
    for (const auto& p : props) {
        if (p.AType != VK_COMPONENT_TYPE_SINT8_KHR || p.BType != VK_COMPONENT_TYPE_SINT8_KHR ||
            p.CType != VK_COMPONENT_TYPE_SINT32_KHR || p.ResultType != VK_COMPONENT_TYPE_SINT32_KHR ||
            p.scope != VK_SCOPE_SUBGROUP_KHR || p.saturatingAccumulation || !p.MSize || !p.NSize || !p.KSize) continue;
        const uint64_t lds = uint64_t(p.MSize)*p.KSize + uint64_t(p.KSize)*p.NSize + 4ull*p.MSize*p.NSize + 8ull*p.MSize + 32;
        if (lds > limits.properties.limits.maxComputeSharedMemorySize) continue;
        NssCoopShape candidate{p.MSize, p.NSize, p.KSize};
        if (!shape.m || candidate.native16()) shape = candidate;
        if (candidate.native16()) break;
    }
    return shape.m != 0;
}
