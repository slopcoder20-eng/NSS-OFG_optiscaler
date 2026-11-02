#pragma once
#include <vulkan/vulkan.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
#include <cstdlib>
#include <cstring>

                                                                                                             
                                                                                  
inline bool mlof2_env(const char* name, char* out, size_t size)
{
#ifdef _WIN32
    const DWORD count = GetEnvironmentVariableA(name, out, static_cast<DWORD>(size));
    if (count == 0 || count >= size) { if (size) out[0] = 0; return false; }
    return true;
#else
    const char* value = getenv(name);
    if (!value || strlen(value) >= size) { if (size) out[0] = 0; return false; }
    strcpy(out, value);
    return true;
#endif
}
inline bool mlof2_env_is(const char* name, const char* value)
{
    char buf[32];
    return mlof2_env(name, buf, sizeof(buf)) && strcmp(buf, value) == 0;
}
inline bool mlof2_env_on(const char* name)                     
{
    char buf[32];
    return mlof2_env(name, buf, sizeof(buf)) && strcmp(buf, "0") != 0;
}

#if !defined(VK_EXT_cooperative_matrix_maintenance1)
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_MAINTENANCE_1_FEATURES_EXT ((VkStructureType)1000659000)
typedef struct VkPhysicalDeviceCooperativeMatrixMaintenance1FeaturesEXT {
    VkStructureType    sType;
    void*              pNext;
    VkBool32           cooperativeMatrixProperties2;
    VkBool32           cooperativeMatrixReductions;
    VkBool32           cooperativeMatrixConversions;
    VkBool32           cooperativeMatrixPerElementOperations;
    VkBool32           cooperativeMatrixGetCoordinate;
} VkPhysicalDeviceCooperativeMatrixMaintenance1FeaturesEXT;
#endif
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

struct Mlof2Caps {
    bool has_coopmat = false;
    bool has_maint1 = false;
    bool has_dp4a = false;
    bool has_int8 = false;
    bool has_fp16 = false;
    bool has_subgroup_control = false;
    bool use_coopmat = false;
    std::string backend_name;
    std::string reason;
};

inline Mlof2Caps mlof2_query_caps(VkInstance inst, VkPhysicalDevice pd) {
    Mlof2Caps caps{};

    uint32_t extCount = 0;
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, nullptr);
    std::vector<VkExtensionProperties> availExts(extCount);
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, availExts.data());

    auto hasExt = [&](const char* name) {
        for (const auto& e : availExts) {
            if (strcmp(e.extensionName, name) == 0) return true;
        }
        return false;
    };

    bool ext_coop = hasExt("VK_KHR_cooperative_matrix");
    bool ext_maint1 = hasExt("VK_EXT_cooperative_matrix_maintenance1");

    VkPhysicalDeviceCooperativeMatrixMaintenance1FeaturesEXT fMaint1{};
    fMaint1.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_MAINTENANCE_1_FEATURES_EXT;

    VkPhysicalDeviceCooperativeMatrixFeaturesKHR fCoop{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR};
    if (ext_maint1) fCoop.pNext = &fMaint1;

    VkPhysicalDeviceVulkan12Features f12{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES};
    if (ext_coop) f12.pNext = &fCoop;

    VkPhysicalDeviceVulkan13Features f13{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES};
    f13.pNext = &f12;

    VkPhysicalDeviceFeatures2 feat2{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2};
    feat2.pNext = &f13;

    auto pfnGetFeat2 = inst ? (PFN_vkGetPhysicalDeviceFeatures2)vkGetInstanceProcAddr(inst, "vkGetPhysicalDeviceFeatures2") : nullptr;
    if (pfnGetFeat2) {
        pfnGetFeat2(pd, &feat2);
    } else {
        vkGetPhysicalDeviceFeatures2(pd, &feat2);
    }

    caps.has_int8 = (f12.storageBuffer8BitAccess == VK_TRUE) && (f12.shaderInt8 == VK_TRUE);
    caps.has_fp16 = (f12.shaderFloat16 == VK_TRUE);
    caps.has_subgroup_control = (f13.subgroupSizeControl == VK_TRUE) && (f13.computeFullSubgroups == VK_TRUE);

                 
    if (caps.has_int8 && (f13.shaderIntegerDotProduct == VK_TRUE)) {
        caps.has_dp4a = true;
    }

                               
    if (ext_coop && fCoop.cooperativeMatrix && caps.has_subgroup_control) {
        auto pfnGetCoopProps = (PFN_vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR)
            vkGetInstanceProcAddr(inst, "vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR");
        if (pfnGetCoopProps) {
            uint32_t propCount = 0;
            pfnGetCoopProps(pd, &propCount, nullptr);
            std::vector<VkCooperativeMatrixPropertiesKHR> props(propCount);
            for (auto& p : props) p.sType = VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_KHR;
            pfnGetCoopProps(pd, &propCount, props.data());

            for (const auto& p : props) {
                if (p.MSize == 16 && p.NSize == 16 && p.KSize == 16 &&
                    p.AType == VK_COMPONENT_TYPE_SINT8_KHR &&
                    p.BType == VK_COMPONENT_TYPE_SINT8_KHR &&
                    p.CType == VK_COMPONENT_TYPE_SINT32_KHR &&
                    p.ResultType == VK_COMPONENT_TYPE_SINT32_KHR &&
                    p.scope == VK_SCOPE_SUBGROUP_KHR) {
                    caps.has_coopmat = true;
                    break;
                }
            }
        }
    }

    if (ext_maint1 && fMaint1.cooperativeMatrixProperties2 && fMaint1.cooperativeMatrixReductions &&
        fMaint1.cooperativeMatrixConversions && fMaint1.cooperativeMatrixPerElementOperations &&
        fMaint1.cooperativeMatrixGetCoordinate) {
        caps.has_maint1 = true;
    }

                                             
    if (mlof2_env_on("MLOF2_FAKE_NO_COOPMAT")) {
        caps.has_coopmat = false;
    }
    if (mlof2_env_on("MLOF2_FAKE_NO_MAINT1")) {
        caps.has_maint1 = false;
    }

                        
    char env_use_buf[8];
    const char* env_use = mlof2_env("MLOF2_USE_COOPMAT", env_use_buf, sizeof(env_use_buf)) ? env_use_buf : nullptr;
    if (env_use && strcmp(env_use, "0") == 0) {
        caps.use_coopmat = false;
        caps.backend_name = "DP4a";
        caps.reason = "Forced by MLOF2_USE_COOPMAT=0";
    } else if (env_use && strcmp(env_use, "1") == 0) {
        if (caps.has_coopmat) {
            caps.use_coopmat = true;
            caps.backend_name = "coopmat";
            caps.reason = "Forced by MLOF2_USE_COOPMAT=1 (supported)";
        } else {
            caps.use_coopmat = false;
            caps.backend_name = "DP4a";
            caps.reason = "Forced MLOF2_USE_COOPMAT=1 but unsupported; fallback to DP4a";
        }
    } else {
                        
        if (caps.has_coopmat) {
            caps.use_coopmat = true;
            caps.backend_name = "coopmat";
            caps.reason = caps.has_maint1 ? "Auto-selected coopmat (with maintenance1)" : "Auto-selected coopmat (without maintenance1)";
        } else if (caps.has_dp4a) {
            caps.use_coopmat = false;
            caps.backend_name = "DP4a";
            caps.reason = "Auto-selected DP4a (coopmat unavailable)";
        } else {
            caps.use_coopmat = false;
            caps.backend_name = "None";
            caps.reason = "FATAL: Neither coopmat nor DP4a supported";
        }
    }

    bool m1_props2 = fMaint1.cooperativeMatrixProperties2 != 0;
    bool m1_red = fMaint1.cooperativeMatrixReductions != 0;
    bool m1_conv = fMaint1.cooperativeMatrixConversions != 0;
    bool m1_elem = fMaint1.cooperativeMatrixPerElementOperations != 0;
    bool m1_coord = fMaint1.cooperativeMatrixGetCoordinate != 0;
    printf("[mlof2_caps] Selected backend: %s (reason: %s, coopmat: %d, maint1: %d [ext=%d, p2=%d, red=%d, conv=%d, elem=%d, coord=%d], dp4a: %d)\n",
           caps.backend_name.c_str(), caps.reason.c_str(), (int)caps.has_coopmat, (int)caps.has_maint1,
           (int)ext_maint1, (int)m1_props2, (int)m1_red, (int)m1_conv, (int)m1_elem, (int)m1_coord, (int)caps.has_dp4a);

    return caps;
}

inline bool mlof2_create_device(VkInstance inst, VkPhysicalDevice pd, const Mlof2Caps& caps, uint32_t qf, VkDevice* out_dev, VkQueue* out_q) {
    if (!caps.has_dp4a && !caps.has_coopmat) {
        fprintf(stderr, "[mlof2_caps] Device does not meet minimum requirements for int8/DP4a execution.\n");
        return false;
    }

    float qp = 1.0f;
    VkDeviceQueueCreateInfo qi{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
    qi.queueFamilyIndex = qf; qi.queueCount = 1; qi.pQueuePriorities = &qp;

    std::vector<const char*> dev_exts;
    if (caps.use_coopmat) {
        dev_exts.push_back("VK_KHR_cooperative_matrix");
        if (caps.has_maint1) dev_exts.push_back("VK_EXT_cooperative_matrix_maintenance1");
    }

    uint32_t extCount = 0;
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, nullptr);
    std::vector<VkExtensionProperties> availExts(extCount);
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, availExts.data());
    for (const auto& e : availExts) {
        if (strcmp(e.extensionName, "VK_AMD_shader_info") == 0) dev_exts.push_back("VK_AMD_shader_info");
        if (strcmp(e.extensionName, "VK_KHR_pipeline_executable_properties") == 0) dev_exts.push_back("VK_KHR_pipeline_executable_properties");
    }

    VkPhysicalDeviceCooperativeMatrixMaintenance1FeaturesEXT maint1Feat{};
    maint1Feat.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_MAINTENANCE_1_FEATURES_EXT;
    if (caps.use_coopmat && caps.has_maint1) {
        maint1Feat.cooperativeMatrixProperties2 = VK_TRUE;
        maint1Feat.cooperativeMatrixReductions = VK_TRUE;
        maint1Feat.cooperativeMatrixConversions = VK_TRUE;
        maint1Feat.cooperativeMatrixPerElementOperations = VK_TRUE;
        maint1Feat.cooperativeMatrixGetCoordinate = VK_TRUE;
    }

    VkPhysicalDeviceCooperativeMatrixFeaturesKHR coopFeat{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR};
    if (caps.use_coopmat) {
        coopFeat.cooperativeMatrix = VK_TRUE;
        if (caps.has_maint1) coopFeat.pNext = &maint1Feat;
    }

    VkPhysicalDeviceVulkan12Features f12{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES};
    if (caps.use_coopmat) f12.pNext = &coopFeat;
    f12.storageBuffer8BitAccess = VK_TRUE;
    f12.shaderInt8 = VK_TRUE;
    f12.shaderFloat16 = VK_TRUE;
    f12.vulkanMemoryModel = VK_TRUE;

    VkPhysicalDeviceVulkan13Features f13{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES};
    f13.pNext = &f12;
    f13.shaderIntegerDotProduct = VK_TRUE;
    f13.subgroupSizeControl = VK_TRUE;
    f13.computeFullSubgroups = VK_TRUE;

    VkDeviceCreateInfo di{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO};
    di.pNext = &f13;
    di.queueCreateInfoCount = 1;
    di.pQueueCreateInfos = &qi;
    di.enabledExtensionCount = uint32_t(dev_exts.size());
    di.ppEnabledExtensionNames = dev_exts.data();

    VkResult res = vkCreateDevice(pd, &di, nullptr, out_dev);
    if (res != VK_SUCCESS) {
        fprintf(stderr, "[mlof2_caps] vkCreateDevice failed: %d\n", (int)res);
        return false;
    }
    vkGetDeviceQueue(*out_dev, qf, 0, out_q);
    return true;
}