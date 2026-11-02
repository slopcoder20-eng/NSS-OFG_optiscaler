// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2022 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// @defgroup VK

#pragma once

#include <vulkan/vulkan.h>
#include "../ffx_fsr2_interface.h"

namespace Fsr212
{

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                                  
       
                
                                                                                     
    size_t ffxFsr2GetScratchMemorySizeVK212(VkPhysicalDevice physicalDevice);

                                                               
       
                                                                                                                        
                 
                                                                
                                                                                                                     
                
                                                                                               
                                    
                                                                                                            
                                                                                                                     
                                   
       
               
                                                                                     
               
                                                                                                           
       
                        
    FfxErrorCode ffxFsr2GetInterfaceVK212(FfxFsr2Interface* outInterface, void* scratchBuffer, size_t scratchBufferSize,
                                          VkPhysicalDevice physicalDevice, PFN_vkGetDeviceProcAddr getDeviceProcAddr);

                                                                           
       
                                                                                       
       
                
                                      
       
                        
    FfxDevice ffxGetDeviceVK212(VkDevice device);

                                                                                   
       
                                                                                       
       
                
                                            
       
                        
    FfxCommandList ffxGetCommandListVK212(VkCommandBuffer cmdBuf);

                                                                        
       
                                                                                                      
                                                                        
                                                                                          
                                                                                
                                                                                 
                                                                                 
                                                                                                                
                                                                                       
       
                
                                         
       
                        
    FfxResource ffxGetTextureResourceVK212(FfxFsr2Context* context, VkImage imgVk, VkImageView imageView,
                                           uint32_t width, uint32_t height, VkFormat imgFormat, wchar_t* name = nullptr,
                                           FfxResourceStates state = FFX_RESOURCE_STATE_COMPUTE_READ);

                                                                         
       
                                                                                                      
                                                                         
                                                                                
                                                                                                                
                                                                                       
       
                
                                         
       
                        
    FfxResource ffxGetBufferResourceVK212(FfxFsr2Context* context, VkBuffer bufVk, uint32_t size,
                                          wchar_t* name = nullptr,
                                          FfxResourceStates state = FFX_RESOURCE_STATE_COMPUTE_READ);

                                                                             
       
                                                                                                      
                                                             
       
                
                                
       
                        
    VkImage ffxGetVkImage212(FfxFsr2Context* context, uint32_t resId);

                                                                                 
       
                                                                                                      
                                                             
       
                
                                
       
                        
    VkImageView ffxGetVkImageView212(FfxFsr2Context* context, uint32_t resId);

                                                                                   
       
                                                                                                      
                                                             
       
                
                                
       
                        
    VkImageLayout ffxGetVkImageLayout212(FfxFsr2Context* context, uint32_t resId);

#if defined(__cplusplus)
}
#endif                            

}                    