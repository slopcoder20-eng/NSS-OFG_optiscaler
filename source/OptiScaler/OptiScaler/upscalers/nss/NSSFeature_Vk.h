#pragma once
#include <upscalers/IFeature_Vk.h>

#include "vk/ffx_api_vk.h"
#include "ffx_nss.h"
#include <proxies/FfxApi_Proxy.h>

                                                                                     
                                                                              
                                                                                       
                                                                                       
                 
struct NssCreateBackendVKDesc
{
    ffxCreateContextDescHeader header;
    VkDevice                   vkDevice;
    VkPhysicalDevice           vkPhysicalDevice;
    VkInstance                 vkInstance;
    PFN_vkGetDeviceProcAddr    vkDeviceProcAddr;
    PFN_vkGetInstanceProcAddr  vkGetInstanceProcAddr;
};

                                                                     
                                                                                
                                                                            
                                                                            
                                                                               
                                                             
                                              
class NSSFeatureVk : public IFeature_Vk
{
  private:
    ffxContext _context = nullptr;
    ffxApiCreateContextDescNss _contextDesc = {};

                                                                                                                    
    VkImage _dbgImage = VK_NULL_HANDLE;
    VkDeviceMemory _dbgMem = VK_NULL_HANDLE;
    uint32_t _dbgW = 0, _dbgH = 0;
    bool EnsureDebugImage(VkFormat fmt, uint32_t w, uint32_t h);

  protected:
                                                                                                
    bool InitNSS(const NVSDK_NGX_Parameter* InParameters, uint32_t rw = 0, uint32_t rh = 0, uint32_t uw = 0, uint32_t uh = 0);
    uint32_t _ctxRenderW = 0, _ctxRenderH = 0, _ctxUpscaleW = 0, _ctxUpscaleH = 0;

                       
    bool InitInternal(VkCommandBuffer InCmdList, NVSDK_NGX_Parameter* InParameters) override;
    bool EvaluateInternal(VkCommandBuffer InCmdBuffer, NVSDK_NGX_Parameter* InParameters) override;

  public:
    NSSFeatureVk(unsigned int InHandleId, NVSDK_NGX_Parameter* InParameters);

    feature_version Version() override { return feature_version { 1, 0, 0 }; }
    Upscaler GetUpscalerType() const final { return Upscaler::NSS; }
    API Api() const override { return IFeature_Vk::Api(); }

    bool IsWithDx12() final { return false; }

    ~NSSFeatureVk()
    {
        if (State::Instance().isShuttingDown)
            return;

        if (_context != nullptr)
            FfxApiProxy::VULKAN_NSS_DestroyContext()(&_context, NULL);
    }
};
