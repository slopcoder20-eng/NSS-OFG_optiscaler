#pragma once
#include "IFGNvngx.h"
#include "NfruAsyncVk.h"
#include "NfruRealFramePacer.h"
#include <chrono>
#include <memory>
#include <d3d12.h>
#include <proxies/FfxApi_Proxy.h>

                                                                         
  
                                                                                          
                                                                                                       
                                                                                                            
                                                                                                        
                                                                         
struct Nvngx_NFRU_Handle
{
    unsigned int Id = 0;
    ffxContext ctx = nullptr;
    bool dx12 = false;
    ID3D12Device* d3d12Device = nullptr;
    VkInstance vkInstance = VK_NULL_HANDLE;
    VkPhysicalDevice vkPhysicalDevice = VK_NULL_HANDLE;
    VkDevice vkDevice = VK_NULL_HANDLE;
    PFN_vkGetDeviceProcAddr vkDeviceProcAddr = nullptr;
    PFN_vkGetInstanceProcAddr vkInstanceProcAddr = nullptr;

    uint32_t swapchainWidth = 0;
    uint32_t swapchainHeight = 0;
    uint32_t renderWidth = 0;
    uint32_t renderHeight = 0;
    uint32_t motionVectorWidth = 0;
    uint32_t motionVectorHeight = 0;
    uint32_t backbufferFormat = 0;
    uint64_t lastFrameId = 0;
    bool hdr = false;
    bool hudSeparated = false;
    uint32_t mfgExpectedIndex = 1, mfgCount = 1;
    bool mfgReset = false;
    float mfgFrameTimeDelta = 16.6667f;
    float cameraOrigin[3] = {};
    bool cameraOriginValid = false;
    float mfgViewProjection[16] = {};
    bool mfgCameraValid = false;
    NfruRealFramePacer realFramePacer;
    std::chrono::steady_clock::time_point lastRealEval {};
    std::unique_ptr<NfruAsyncVk::Context> asyncVk;
    bool asyncFallbackReported = false;
    bool resetAfterAsyncFailure = false;

                                                                      
    VkQueryPool profPool = VK_NULL_HANDLE;
    float profPeriodMs = 0.0f;
    double profSumMs = 0.0, profMaxMs = 0.0;
    uint32_t profCount = 0;
    double profCpuSumMs = 0.0, profCpuMaxMs = 0.0, profGapMaxMs = 0.0;
    uint32_t profCpuCount = 0;
    std::chrono::steady_clock::time_point profLastEval {};

    ~Nvngx_NFRU_Handle();
};

class Nvngx_NFRU : public IFGNvngx
{
  private:
    FGNvngxReplacement _type;
    static inline std::atomic_uint32_t lastIdCreated = 0;
    static inline ID3D12Device* initD3D12Device = nullptr;
    static inline VkInstance initVkInstance = VK_NULL_HANDLE;
    static inline VkPhysicalDevice initVkPhysicalDevice = VK_NULL_HANDLE;
    static inline VkDevice initVkDevice = VK_NULL_HANDLE;
    static inline PFN_vkGetDeviceProcAddr initVkDeviceProcAddr = nullptr;
    static inline PFN_vkGetInstanceProcAddr initVkInstanceProcAddr = nullptr;

  public:
    explicit Nvngx_NFRU(FGNvngxReplacement type = FGNvngxReplacement::NFRU) : _type(type) {}
    bool isDx12Available() override final;
    bool isVulkanAvailable() override final;

           
    NVSDK_NGX_Result D3D12_Init(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                ID3D12Device* InDevice, const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo,
                                NVSDK_NGX_Version InSDKVersion) override;
    NVSDK_NGX_Result D3D12_Init_Ext(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                    ID3D12Device* InDevice, NVSDK_NGX_Version InSDKVersion,
                                    const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo) override;
    NVSDK_NGX_Result D3D12_Shutdown() override;
    NVSDK_NGX_Result D3D12_Shutdown1(ID3D12Device* InDevice) override;
    NVSDK_NGX_Result D3D12_GetScratchBufferSize(NVSDK_NGX_Feature InFeatureId, const NVSDK_NGX_Parameter* InParameters,
                                                size_t* OutSizeInBytes) override;
    NVSDK_NGX_Result D3D12_CreateFeature(ID3D12GraphicsCommandList* InCmdList, NVSDK_NGX_Feature InFeatureID,
                                         NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle) override;
    NVSDK_NGX_Result D3D12_ReleaseFeature(NVSDK_NGX_Handle* InHandle) override;
    NVSDK_NGX_Result D3D12_GetFeatureRequirements(IDXGIAdapter* Adapter,
                                                  const NVSDK_NGX_FeatureDiscoveryInfo* FeatureDiscoveryInfo,
                                                  NVSDK_NGX_FeatureRequirement* OutSupported) override;
    NVSDK_NGX_Result D3D12_EvaluateFeature(ID3D12GraphicsCommandList* InCmdList, const NVSDK_NGX_Handle* InFeatureHandle,
                                           NVSDK_NGX_Parameter* InParameters,
                                           PFN_NVSDK_NGX_ProgressCallback InCallback) override;
    NVSDK_NGX_Result D3D12_PopulateParameters_Impl(NVSDK_NGX_Parameter* InParameters) override;

             
    NVSDK_NGX_Result VULKAN_Init(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                 VkInstance InInstance, VkPhysicalDevice InPD, VkDevice InDevice,
                                 PFN_vkGetInstanceProcAddr InGIPA, PFN_vkGetDeviceProcAddr InGDPA,
                                 const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo,
                                 NVSDK_NGX_Version InSDKVersion) override;
    NVSDK_NGX_Result VULKAN_Init_Ext(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                     VkInstance InInstance, VkPhysicalDevice InPD, VkDevice InDevice,
                                     NVSDK_NGX_Version InSDKVersion,
                                     const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo) override;
    NVSDK_NGX_Result VULKAN_Init_Ext2(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                      VkInstance InInstance, VkPhysicalDevice InPD, VkDevice InDevice,
                                      PFN_vkGetInstanceProcAddr InGIPA, PFN_vkGetDeviceProcAddr InGDPA,
                                      NVSDK_NGX_Version InSDKVersion,
                                      const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo) override;
    NVSDK_NGX_Result VULKAN_Shutdown() override;
    NVSDK_NGX_Result VULKAN_Shutdown1(VkDevice InDevice) override;
    NVSDK_NGX_Result VULKAN_GetScratchBufferSize(NVSDK_NGX_Feature InFeatureId, const NVSDK_NGX_Parameter* InParameters,
                                                 size_t* OutSizeInBytes) override;
    NVSDK_NGX_Result VULKAN_CreateFeature(VkCommandBuffer InCmdBuffer, NVSDK_NGX_Feature InFeatureID,
                                          NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle) override;
    NVSDK_NGX_Result VULKAN_CreateFeature1(VkDevice InDevice, VkCommandBuffer InCmdList, NVSDK_NGX_Feature InFeatureID,
                                           NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle) override;
    NVSDK_NGX_Result VULKAN_ReleaseFeature(NVSDK_NGX_Handle* InHandle) override;
    NVSDK_NGX_Result VULKAN_GetFeatureRequirements(const VkInstance Instance, const VkPhysicalDevice PhysicalDevice,
                                                   const NVSDK_NGX_FeatureDiscoveryInfo* FeatureDiscoveryInfo,
                                                   NVSDK_NGX_FeatureRequirement* OutSupported) override;
    NVSDK_NGX_Result VULKAN_EvaluateFeature(VkCommandBuffer InCmdList, const NVSDK_NGX_Handle* InFeatureHandle,
                                            NVSDK_NGX_Parameter* InParameters,
                                            PFN_NVSDK_NGX_ProgressCallback InCallback) override;
    NVSDK_NGX_Result VULKAN_PopulateParameters_Impl(NVSDK_NGX_Parameter* InParameters) override;

    static bool MfgSupported();
    static bool HudSeparationSupported();
    static bool Mlof2Active();                                                            
    static bool OfgActive();                                                                         
    int getMaxFakeFramesCount() override;
    FGNvngxReplacement getType() override { return _type; }
};
