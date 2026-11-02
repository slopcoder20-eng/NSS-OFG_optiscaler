#pragma once

#include "FSR4DriverProvider.h"

#include <proxies/FfxModule.h>

#include <vulkan/vulkan.h>

                                                                                   

                                                                                                            
                                                                                                                 
#define FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_VK_V2 0x01000003u

                                                                                                 
#define FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE_VERSION_V2 0x0001000Bu
#define FFX_UPSCALER_VERSION_V2 ((4u << 22) | (1u << 12) | 2u)

struct ffxCreateContextDescUpscaleVersionV2
{
    ffxCreateContextDescHeader header;
    uint32_t version;
};

                                                                                                             
#define FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION_VERSION_V2 0x0002000Eu
#define FFX_FRAMEGENERATION_VERSION_V2 ((4u << 22) | 2u)

struct ffxCreateContextDescFrameGenerationVersionV2
{
    ffxCreateContextDescHeader header;
    uint32_t version;
};

                                                                
#define FFX_API_CREATE_CONTEXT_DESC_TYPE_FGSWAPCHAIN_VERSION_VK_V2 0x0004000Au
#define FFX_FGSWAPCHAIN_VERSION_VK_V2 (4u << 22)

struct ffxCreateContextDescFrameGenerationSwapChainVersionVKV2
{
    ffxCreateContextDescHeader header;
    uint32_t version;
};

                                                                                                   
                                                                                                                        
class FSR4DriverProviderVk
{
  public:
    static bool Init();
    static bool IsAvailable() { return _module.CreateContext != nullptr; }

    static FfxModule* Module() { return &_module; }
    static uint64_t VersionId() { return _upscaler.functions.versionId; }
    static const char* VersionName() { return _upscaler.versionName.c_str(); }

    static bool IsSupported(VkDevice device, VkPhysicalDevice physicalDevice, PFN_vkGetDeviceProcAddr gdpa);

                                                                                                  
    static void AddToVersionList(std::vector<uint64_t>& ids, std::vector<const char*>& names, DriverListing listing);

                                                                                                   
    static bool InitFg();
    static bool IsFgAvailable()
    {
        return _fgModule.CreateContext != nullptr && _fgSwapchainModule.CreateContext != nullptr;
    }

    static FfxModule* FgModule() { return &_fgModule; }
    static FfxModule* FgSwapchainModule() { return &_fgSwapchainModule; }
    static uint64_t FgVersionId() { return _fg.functions.versionId; }
    static const char* FgVersionName() { return _fg.versionName.c_str(); }

    static bool IsFgSupported(VkDevice device, VkPhysicalDevice physicalDevice, PFN_vkGetDeviceProcAddr gdpa);

                                                                       
    static void AddFgToVersionList(std::vector<uint64_t>& ids, std::vector<const char*>& names);

  private:
    inline static DriverProvider _upscaler {};
    inline static FfxModule _module {};

    inline static DriverProvider _fg {};
    inline static FfxModule _fgModule {};
    inline static FfxModule _fgSwapchainModule {};
};
