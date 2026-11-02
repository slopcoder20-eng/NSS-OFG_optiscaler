#pragma once
#include <vulkan/vulkan.h>
#include <State.h>
#include <cstring>
#include <vector>

                                                                                                                       
                                                                                         
                                                                                                        
inline bool VkCoopMatInt8Supported()
{
    static VkPhysicalDevice cachedDevice = VK_NULL_HANDLE;
    static bool cachedResult = false;

    const VkPhysicalDevice pd = State::Instance().VulkanPhysicalDevice;
    const VkInstance inst = State::Instance().VulkanInstance;
    if (pd == VK_NULL_HANDLE || inst == VK_NULL_HANDLE)
        return false;                                                     

    if (pd == cachedDevice)
        return cachedResult;

    cachedDevice = pd;
    cachedResult = false;

    uint32_t extensionCount = 0;
    if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &extensionCount, nullptr) != VK_SUCCESS || extensionCount == 0)
        return false;
    std::vector<VkExtensionProperties> extensions(extensionCount);
    if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &extensionCount, extensions.data()) != VK_SUCCESS)
        return false;
    bool hasExtension = false;
    for (const auto& extension : extensions)
    {
        if (strcmp(extension.extensionName, VK_KHR_COOPERATIVE_MATRIX_EXTENSION_NAME) == 0)
        {
            hasExtension = true;
            break;
        }
    }
    if (!hasExtension)
        return false;

    VkPhysicalDeviceCooperativeMatrixFeaturesKHR cooperativeFeatures {
        VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR
    };
    VkPhysicalDeviceFeatures2 features { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };
    features.pNext = &cooperativeFeatures;
    vkGetPhysicalDeviceFeatures2(pd, &features);
    if (!cooperativeFeatures.cooperativeMatrix)
        return false;

    auto fn = (PFN_vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR) vkGetInstanceProcAddr(
        inst, "vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR");
    if (!fn)
        return false;

    uint32_t count = 0;
    if (fn(pd, &count, nullptr) != VK_SUCCESS || count == 0)
        return false;

    std::vector<VkCooperativeMatrixPropertiesKHR> props(count, { VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_KHR });
    if (fn(pd, &count, props.data()) != VK_SUCCESS)
        return false;

    VkPhysicalDeviceCooperativeMatrixPropertiesKHR cp { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_PROPERTIES_KHR };
    VkPhysicalDeviceSubgroupProperties sg { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES, &cp };
    VkPhysicalDeviceProperties2 limits { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2, &sg };
    vkGetPhysicalDeviceProperties2(pd, &limits);
    if (!(cp.cooperativeMatrixSupportedStages & VK_SHADER_STAGE_COMPUTE_BIT) || !sg.subgroupSize ||
        sg.subgroupSize > limits.properties.limits.maxComputeWorkGroupInvocations ||
        sg.subgroupSize > limits.properties.limits.maxComputeWorkGroupSize[0]) return false;
    VkPhysicalDeviceVulkan12Features f12 { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES };
    VkPhysicalDeviceFeatures2 f { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, &f12 };
    vkGetPhysicalDeviceFeatures2(pd, &f);
    if (!f12.shaderInt8 || !f12.storageBuffer8BitAccess) return false;
    for (const auto& p : props)
    {
        if (p.AType == VK_COMPONENT_TYPE_SINT8_KHR && p.BType == VK_COMPONENT_TYPE_SINT8_KHR &&
            p.CType == VK_COMPONENT_TYPE_SINT32_KHR && p.ResultType == VK_COMPONENT_TYPE_SINT32_KHR &&
            p.scope == VK_SCOPE_SUBGROUP_KHR && !p.saturatingAccumulation && p.MSize && p.NSize && p.KSize &&
            uint64_t(p.MSize)*p.KSize + uint64_t(p.KSize)*p.NSize + 4ull*p.MSize*p.NSize + 8ull*p.MSize + 32 <= limits.properties.limits.maxComputeSharedMemorySize)
        {
            cachedResult = true;
            break;
        }
    }
    return cachedResult;
}
