#pragma once
#include "SysUtils.h"
#include <framegen/IFGFeature_Vk.h>
#include <framegen/dlssg/DLSSG_Common.h>

                                                                              
#pragma warning(push)
#pragma warning(disable : 4250)

                                                                                                                 
class DLSSG_Vk : public virtual IFGFeature_Vk, public DLSSG_Common
{
  private:
    struct
    {
        PFN_vkCreateSwapchainKHR createSwapchain = nullptr;
        PFN_vkDestroySwapchainKHR destroySwapchain = nullptr;
        PFN_vkGetSwapchainImagesKHR getSwapchainImages = nullptr;
        PFN_vkAcquireNextImageKHR acquireNextImage = nullptr;
        PFN_vkQueuePresentKHR queuePresent = nullptr;
        PFN_vkSetHdrMetadataEXT setHdrMetadata = nullptr;
    } _sl;

                                                                        
    VkDevice _slDevice = VK_NULL_HANDLE;

                                                                                                                
    uint32_t _graphicsQueueCount = 0;
    uint32_t _computeQueueCount = 0;
    std::vector<std::string> _requiredExtensions;
    std::vector<std::string> _requiredFeatures12;
    std::vector<std::string> _requiredFeatures13;
    std::vector<const char*> _deviceExtensions;

    bool SetupStreamline(VkDevice device);
    void ShowSurface(VkSurfaceKHR surface);
    void AddExtensions(VkPhysicalDevice physicalDevice, VkDeviceCreateInfo& createInfo);
    void EnableFeatures(VkPhysicalDevice physicalDevice, VkDeviceCreateInfo& createInfo);

    bool Dispatch();
    bool TagResources(int fIndex);

  public:
                 
    bool Present() override final;
    void DestroyFGContext() override final;
    bool ReleaseSwapchain(HWND hwnd) override final;
    bool Shutdown() override final;

                    
    void PrepareDevice(VkPhysicalDevice physicalDevice, VkDeviceCreateInfo& createInfo) override final;

                                                       
    bool HasDriverSwapchain() const override final { return true; }

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

                                                                              
    DLSSG_Vk();
    ~DLSSG_Vk();
};

#pragma warning(pop)
