#pragma once
#include "SysUtils.h"

class VulkanHooks
{
    inline static std::atomic<VkSwapchainKHR> lowLatencySwapchain = VK_NULL_HANDLE;

  public:
    static PFN_vkCreateSemaphore o_vkCreateSemaphore;
    static PFN_vkAntiLagUpdateAMD o_vkAntiLagUpdateAMD;

                                                                                                              
                                                                
    static VkResult SignalSemaphore(VkDevice device, const VkSemaphoreSignalInfo* pSignalInfo);

                                      
    inline static PFN_vkSetLatencySleepModeNV o_vkSetLatencySleepModeNV = nullptr;
    inline static PFN_vkLatencySleepNV o_vkLatencySleepNV = nullptr;
    inline static PFN_vkSetLatencyMarkerNV o_vkSetLatencyMarkerNV = nullptr;
    inline static PFN_vkGetLatencyTimingsNV o_vkGetLatencyTimingsNV = nullptr;
    inline static PFN_vkQueueNotifyOutOfBandNV o_vkQueueNotifyOutOfBandNV = nullptr;

                                                                                      
    static VkSwapchainKHR LowLatencySwapchain() { return lowLatencySwapchain; }
    static void SetLowLatencySwapchain(VkSwapchainKHR swapchain);
    static void ForgetLowLatencySwapchain(VkSwapchainKHR swapchain)
    {
        lowLatencySwapchain.compare_exchange_strong(swapchain, VK_NULL_HANDLE);
    }

                                                                                                                     
                                    
    inline static thread_local VkSurfaceKHR existingSurface = VK_NULL_HANDLE;

                                           
    static HWND SurfaceWindow(VkSurfaceKHR surface);

                                                     
    static PFN_vkVoidFunction GetDeviceProcAddr(VkDevice device, const char* pName);

                                                       
    static PFN_vkVoidFunction GetInstanceProcAddr(VkInstance instance, const char* pName);

                                                                                                             
                                                                                                      
    static PFN_vkVoidFunction OriginalSwapchainFunction(const char* pName);

    static void Hook(HMODULE vulkan1);
    static void Unhook();
};
