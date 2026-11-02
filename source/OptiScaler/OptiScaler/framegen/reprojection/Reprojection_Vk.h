#pragma once

#include "SysUtils.h"
#include <framegen/IFGFeature_Vk.h>
#include <shaders/reproject/Reproject_Vk.h>

                                                                                                                      
class Reprojection_Vk : public virtual IFGFeature_Vk
{
  private:
    std::unique_ptr<Reproject_Vk> _reproject;

    std::vector<VkImage> _swapchainImages;
    std::vector<VkSemaphore> _reprojectedSemaphores;                                                     
    bool _canReproject = false;                                                                           

    ImageCopy _presentCopy;
    ImageCopy _hudlessCopy;
    uint32_t _commandIndex = 0;

    void ReleaseSwapchainResources();

                                                                                                                     
    VkSemaphore ReprojectPresent(VkQueue queue, const VkPresentInfoKHR* pPresentInfo);

  public:
                 
    const char* Name() override final { return "Reprojection"; }
    feature_version Version() override final { return { 0, 0, 1 }; }

    bool Present() override final;
    void Activate() override final;
    void Deactivate() override final;
    void DestroyFGContext() override final;
    bool ReleaseSwapchain(HWND hwnd) override final;
    bool Shutdown() override final;
    bool SetInterpolatedFrameCount(UINT interpolatedFrameCount) override final { return true; }
    std::optional<double> ReadGpuTime(void* commandQueue) override final;

    bool HasReprojection() override final { return true; }
    const Reproject* GetReproject() const override final { return _reproject.get(); }

                    
    bool CreateSwapchain(VkDevice device, const VkSwapchainCreateInfoKHR* pCreateInfo,
                         const VkAllocationCallbacks* pAllocator, VkSwapchainKHR* pSwapchain) override final;
    bool DestroySwapchain(VkDevice device, VkSwapchainKHR swapchain,
                          const VkAllocationCallbacks* pAllocator) override final;
    VkResult GetSwapchainImages(VkDevice device, VkSwapchainKHR swapchain, uint32_t* pSwapchainImageCount,
                                VkImage* pSwapchainImages) override final;
    VkResult AcquireNextImage(VkDevice device, VkSwapchainKHR swapchain, uint64_t timeout, VkSemaphore semaphore,
                              VkFence fence, uint32_t* pImageIndex) override final;
    VkResult QueuePresent(VkQueue queue, const VkPresentInfoKHR* pPresentInfo) override final;
    void SetHdrMetadata(VkDevice device, VkSwapchainKHR swapchain, const VkHdrMetadataEXT* pMetadata) override final;

    void EvaluateState(FG_Constants& fgConstants) override final;

    Reprojection_Vk() : IFGFeature_Vk(), IFGFeature() { _framesToInterpolate = 0; }
    ~Reprojection_Vk() { Shutdown(); }
};
