// Copyright  © 2023 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// SPDX-FileCopyrightText: Copyright 2025 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

/// @defgroup VKBackend Vulkan Backend
/// FidelityFX SDK native backend implementation for Vulkan.
///
/// @ingroup Backends

#pragma once

#include <vulkan/vulkan.h>

#include "../../ffx_interface.h"

#if defined(__cplusplus)
extern "C" {
#endif                             

                                                                           
typedef VkResult (*PFN_vkQueueSubmitFFX)(uint32_t submitCount, const VkSubmitInfo* pSubmits, VkFence fence);

typedef struct VkQueueInfoFFX
{
    VkQueue              queue;
    uint32_t             familyIndex;
    PFN_vkQueueSubmitFFX submitFunc;
} VkQueueInfoFFX;

typedef enum VkCompositonModeFFX
{
    VK_COMPOSITION_MODE_NOT_FORCED_FFX,
    VK_COMPOSITION_MODE_GAME_QUEUE_FFX,
    VK_COMPOSITION_MODE_PRESENT_QUEUE_FFX,
} VkCompositonModeFFX;

typedef enum FfxGpuVendorId
{
    UnknownVendor = 0xffffffff,
    NotQueried    = 0,

    Amd         = 0x1002,
    ImgTec      = 0x1010,
    Nvidia      = 0x10DE,
    Arm         = 0x13B5,
    Broadcom    = 0x14E4,
    Qualcomm    = 0x5143,
    Intel       = 0x8086,
    Apple       = 0x106B,
    Vivante     = 0x7a05,
    VeriSilicon = 0x1EB1,
    SamsungAMD  = 0x144D,
    Microsoft   = 0x1414,

    Kazan    = 0x10003,               
    Codeplay = 0x10004,               
    Mesa     = 0x10005,               
} FfxGpuVendorId;

                                                                                                                      
                             
                                                                                                                                                               
                                                                                                                                                                                               
                                                                                       
                                                                                                              
                                                                                                                                                                                                                      
                                                                                                                                                                             
                                                                                                                                                                                                                                                                                 
typedef struct VkFrameInterpolationInfoFFX
{
    VkPhysicalDevice             physicalDevice;
    VkDevice                     device;
    VkQueueInfoFFX               gameQueue;
    VkQueueInfoFFX               asyncComputeQueue;
    VkQueueInfoFFX               presentQueue;
    VkQueueInfoFFX               imageAcquireQueue;
    VkCompositonModeFFX          compositionMode;
    const VkAllocationCallbacks* pAllocator;
} VkFrameInterpolationInfoFFX;

                                                                   
typedef struct VkDeviceContext
{
    VkDevice                  vkDevice;                                    
    VkPhysicalDevice          vkPhysicalDevice;                                     
    PFN_vkGetDeviceProcAddr   vkDeviceProcAddr;                                              
    VkInstance                vkInstance;                                    
    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr;                                           
} VkDeviceContext;

                                                                              
   
                                                                                     
                                                                                                                           
                                                                                                                               
   
            
                                                                                 
   
                      
FFX_API size_t ffxGetScratchMemorySizeVK(VkDeviceContext& deviceContext, size_t maxContexts);

                                                                   
   
                                                                                                            
   
            
                                  
   
                      
FFX_API FfxDevice ffxGetDeviceVK(VkDeviceContext* vkDeviceContext);

                                                           
   
                                                                                                                          
                                                                             
                                                                                                                          
                                                                                                                        
                                                                                                                           
                                                                                                                               
   
           
                                                                                 
           
                                                                                                       
   
                      
FFX_API FfxErrorCode ffxGetInterfaceVK(FfxInterface* backendInterface, FfxDevice device, void* scratchBuffer, size_t scratchBufferSize, size_t maxContexts);

                                                                               
   
                                                                                   
   
            
                                        
   
                      
FFX_API FfxCommandList ffxGetCommandListVK(VkCommandBuffer cmdBuf);

                                                                       
   
                                                                             
   
            
                                    
   
                      
FFX_API FfxPipeline ffxGetPipelineVK(VkPipeline pipeline);

                                                                       
   
                                                                                    
                                                                                                                    
                                                                                                            
                                                                                   
   
            
                                     
   
                      
FFX_API FfxResource ffxGetResourceVK(void*                  vkResource,
                                     FfxResourceDescription ffxResDescription,
                                     const char*            ffxResName,
                                     FfxResourceStates      state = FFX_RESOURCE_STATE_COMPUTE_READ);

                                                           
   
                                                                                              
   
            
                                      
   
                      
FFX_API FfxSurfaceFormat ffxGetSurfaceFormatVK(VkFormat format);

                                                                           
   
                                                                                                               
                                                                        
                                                                                                                     
   
            
                                            
   
                      
FFX_API FfxResourceDescription ffxGetBufferResourceDescriptionVK(const VkBuffer           buffer,
                                                                 const VkBufferCreateInfo createInfo,
                                                                 FfxResourceUsage         additionalUsages = FFX_RESOURCE_USAGE_READ_ONLY);

                                                                          
   
                                                                                                              
                                                                       
                                                                                                                     
   
            
                                            
   
                      
FFX_API FfxResourceDescription ffxGetImageResourceDescriptionVK(const VkImage           image,
                                                                const VkImageCreateInfo createInfo,
                                                                FfxResourceUsage        additionalUsages = FFX_RESOURCE_USAGE_READ_ONLY);

                                                                   
   
                                                                                              
   
            
                                     
   
                      
FFX_API FfxCommandQueue ffxGetCommandQueueVK(VkQueue commandQueue);

                                                                       
   
                                                                                                   
   
            
                                  
   
                      
FFX_API FfxSwapchain ffxGetSwapchainVK(VkSwapchainKHR swapchain);

                                                                       
   
                                                                                                     
   
            
                             
   
                      
FFX_API VkSwapchainKHR ffxGetVKSwapchain(FfxSwapchain ffxSwapchain);

                                                                                
   
                                                                                                         
                                                                                                                                                                                                                                                          
                                                                                                                                                                                               
                                                                                                                                                      
   
           
                                                                             
           
                                                                                                                                                                    
           
                                                                                                                                                          
   
                                 
FFX_API FfxErrorCode ffxReplaceSwapchainForFrameinterpolationVK(FfxCommandQueue                    gameQueue,
                                                                FfxSwapchain&                      gameSwapChain,
                                                                const VkSwapchainCreateInfoKHR*    swapchainCreateInfo,
                                                                const VkFrameInterpolationInfoFFX* frameInterpolationInfo);

                                                                      
   
                                                                                  
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxWaitForPresents(FfxSwapchain gameSwapChain);

                                                                                                     
   
                                                                                                           
                                                                                                   
                                                                                     
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxRegisterFrameinterpolationUiResourceVK(FfxSwapchain gameSwapChain, const FfxResource& uiResource, uint32_t flags);

                                                                               
   
                                                                                                                  
                                                                                                                      
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxGetFrameinterpolationCommandlistVK(FfxSwapchain gameSwapChain, FfxCommandList& gameCommandlist);

                                                                                                         
   
                                                                                                                          
   
            
                                                                  
   
                                 
FFX_API FfxResource ffxGetFrameinterpolationTextureVK(FfxSwapchain gameSwapChain);

                                                                                                               
   
                                                                                          
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxSetFrameGenerationConfigToSwapchainVK(FfxFrameGenerationConfig const* config);

                                                                            
typedef enum FfxFrameInterpolationSwapchainConfigureKey
{
    FFX_FI_SWAPCHAIN_CONFIGURE_KEY_WAITCALLBACK      = 0,
    FFX_FI_SWAPCHAIN_CONFIGURE_KEY_FRAMEPACINGTUNING = 2,
} FfxFrameInterpolationSwapchainConfigureKey;

                                                                                                           
   
                                                                                                    
                                                                                                           
                                                                                                                                   
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxConfigureFrameInterpolationSwapchainVK(FfxSwapchain gameSwapChain, FfxFrameInterpolationSwapchainConfigureKey key, void* valuePtr);

                                                                                                                                                   
   
                                                                                                    
                                                                                                                                       
   
           
                                                                             
           
                                                                                                             
   
                                 
FFX_API FfxErrorCode ffxFrameInterpolationSwapchainGetGpuMemoryUsageVK(FfxSwapchain gameSwapChain, FfxEffectMemoryUsage* vramUsage);

typedef VkResult (*PFN_vkCreateSwapchainFFX)(VkDevice                           device,
                                             const VkSwapchainCreateInfoKHR*    pCreateInfo,
                                             const VkAllocationCallbacks*       pAllocator,
                                             VkSwapchainKHR*                    pSwapchain,
                                             const VkFrameInterpolationInfoFFX* pFrameInterpolationInfo);

                                                                                        
typedef uint64_t (*PFN_getLastPresentCountFFX)(VkSwapchainKHR);

                                                                                       
                                            
                                 
                                                                                                                              
                                                                                                                                                                 
struct FfxSwapchainReplacementFunctions
{
    PFN_vkCreateSwapchainFFX    createSwapchainFFX;
    PFN_vkDestroySwapchainKHR   destroySwapchainKHR;
    PFN_vkGetSwapchainImagesKHR getSwapchainImagesKHR;
    PFN_vkAcquireNextImageKHR   acquireNextImageKHR;
    PFN_vkQueuePresentKHR       queuePresentKHR;
    PFN_vkSetHdrMetadataEXT     setHdrMetadataEXT;
    PFN_getLastPresentCountFFX  getLastPresentCountFFX;
};
FFX_API FfxErrorCode ffxGetSwapchainReplacementFunctionsVK(FfxDevice device, FfxSwapchainReplacementFunctions* functions);
#if defined(__cplusplus)
}
#endif                             
