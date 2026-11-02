// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
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

/// @defgroup DX12Backend DX12 Backend
/// FidelityFX SDK native backend implementation for DirectX 12.
/// 
/// @ingroup Backends

/// @defgroup DX12FrameInterpolation DX12 FrameInterpolation
/// FidelityFX SDK native frame interpolation implementation for DirectX 12 backend.
/// 
/// @ingroup DX12Backend

#pragma once

#include <d3d12.h>
#include <dxgi1_6.h>
#include <FidelityFX/host/ffx_interface.h>

#if defined(__cplusplus)
extern "C" {
#endif                            

                                                                                  
    
                                                                                                                           
                                                                                                                               
   
            
                                                                                   
                        
FFX_API size_t ffxGetScratchMemorySizeDX12(size_t maxContexts);

                                                                       
   
                                                                              
   
            
                                  
   
                        
FFX_API FfxDevice ffxGetDeviceDX12(ID3D12Device* device);

                                                             
   
                                                                                                                          
                                                                              
                                                                                                                          
                                                                                                                        
                                                                                                                           
                                                                                                                               
   
           
                                                                                 
           
                                                                                                       
   
                        
FFX_API FfxErrorCode ffxGetInterfaceDX12(
    FfxInterface* backendInterface,
    FfxDevice device,
    void* scratchBuffer,
    size_t scratchBufferSize, 
    size_t maxContexts);

                                                                                 
   
                                                                                    
   
            
                                        
   
                        
FFX_API FfxCommandList ffxGetCommandListDX12(ID3D12CommandList* cmdList);

                                                                                
   
                                                                                      
   
            
                                    
   
                        
FFX_API FfxPipeline ffxGetPipelineDX12(ID3D12PipelineState* pipelineState);

                                                                       
   
                                                                           
                                                                                                                    
                                                                                                            
                                                                                   
   
            
                                     
   
                        
FFX_API FfxResource ffxGetResourceDX12(const ID3D12Resource*  dx12Resource,
                                       FfxResourceDescription ffxResDescription,
                                       const wchar_t*         ffxResName,
                                       FfxResourceStates      state = FFX_RESOURCE_STATE_COMPUTE_READ);

                                                                         
   
                                                                        
   
           
                                                                                 
           
                                                                                           
           
                                                                                                             
   
                        
FFX_API FfxErrorCode ffxLoadPixDll(const wchar_t*  pixDllPath);

                                                              
   
                                                                                                 
   
            
                                      
   
                        
FFX_API FfxSurfaceFormat ffxGetSurfaceFormatDX12(DXGI_FORMAT format);

                                                              
   
                                                                                                 
   
            
                   
   
                        
FFX_API DXGI_FORMAT ffxGetDX12FormatFromSurfaceFormat(FfxSurfaceFormat surfaceFormat);

                                                                                 
   
                                                                                                                     
                                                                                                                     
   
            
                                            
   
                        
FFX_API FfxResourceDescription ffxGetResourceDescriptionDX12(const ID3D12Resource* pResource, FfxResourceUsage additionalUsages = FFX_RESOURCE_USAGE_READ_ONLY);

                                                                              
   
                                                                                                          
   
            
                                     
   
                        
FFX_API FfxCommandQueue ffxGetCommandQueueDX12(ID3D12CommandQueue* pCommandQueue);

                                                                        
   
                                                                                                    
   
            
                                  
   
                        
FFX_API FfxSwapchain ffxGetSwapchainDX12(IDXGISwapChain4* pSwapchain);

                                                                        
   
                                                                                                      
   
            
                              
   
                        
FFX_API IDXGISwapChain4* ffxGetDX12SwapchainPtr(FfxSwapchain ffxSwapchain);

                                                                                
   
                                                                                                     
                                                                                                                   
   
           
                                                                             
           
                                                                         
   
                                   
FFX_API FfxErrorCode ffxReplaceSwapchainForFrameinterpolationDX12(FfxCommandQueue gameQueue, FfxSwapchain& gameSwapChain);

                                                                   
   
                                                                                                                                           
                                                                                                           
                                                                                            
                                                                               
   
           
                                                                             
           
                                                                         
                                                                                                                                     
   
                                   
FFX_API FfxErrorCode ffxCreateFrameinterpolationSwapchainDX12(const DXGI_SWAP_CHAIN_DESC* desc,
                                                      ID3D12CommandQueue* queue,
                                                      IDXGIFactory* dxgiFactory,
                                                      FfxSwapchain& outGameSwapChain);

                                                                   
   
                                                                                    
                                                                                                                                            
                                                                                                                                                                  
                                                                                                           
                                                                                            
                                                                               
   
           
                                                                             
           
                                                                         
                                                                                                                                     
   
                                   
FFX_API FfxErrorCode ffxCreateFrameinterpolationSwapchainForHwndDX12(HWND hWnd,
                                                             const DXGI_SWAP_CHAIN_DESC1* desc1,
                                                             const DXGI_SWAP_CHAIN_FULLSCREEN_DESC* fullscreenDesc,
                                                             ID3D12CommandQueue* queue,
                                                             IDXGIFactory* dxgiFactory,
                                                             FfxSwapchain& outGameSwapChain);

                                                                      
   
                                                                                  
   
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxWaitForPresents(FfxSwapchain gameSwapChain);

                                                                                                     
   
                                                                                                           
                                                                                                   
                                                                                     
    
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxRegisterFrameinterpolationUiResourceDX12(FfxSwapchain gameSwapChain, FfxResource uiResource, uint32_t flags);

                                                                               
   
                                                                                                                  
                                                                                                                      
   
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxGetFrameinterpolationCommandlistDX12(FfxSwapchain gameSwapChain, FfxCommandList& gameCommandlist);

                                                                                                         
   
                                                                                                                          
   
            
                                                                  
   
                                   
FFX_API FfxResource ffxGetFrameinterpolationTextureDX12(FfxSwapchain gameSwapChain);

                                                                                                               
   
                                                                                          
   
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxSetFrameGenerationConfigToSwapchainDX12(FfxFrameGenerationConfig const* config);

                                                                        
typedef enum FfxFrameInterpolationSwapchainConfigureKey
{
    FFX_FI_SWAPCHAIN_CONFIGURE_KEY_WAITCALLBACK = 0,
    FFX_FI_SWAPCHAIN_CONFIGURE_KEY_FRAMEPACINGTUNING = 2,
} FfxFrameInterpolationSwapchainConfigureKey;

                                                                                                           
   
                                                                                                    
                                                                                                           
                                                                                                                                   
    
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxConfigureFrameInterpolationSwapchainDX12(FfxSwapchain gameSwapChain, FfxFrameInterpolationSwapchainConfigureKey key, void* valuePtr);

                                                                                                                                                       
   
                                                                                                    
                                                                                                                                       
    
           
                                                                             
           
                                                                                                             
   
                                   
FFX_API FfxErrorCode ffxFrameInterpolationSwapchainGetGpuMemoryUsageDX12(FfxSwapchain gameSwapChain, FfxEffectMemoryUsage* vramUsage);

struct FfxFrameInterpolationContext;
typedef FfxErrorCode (*FfxCreateFiSwapchain)(FfxFrameInterpolationContext* fiContext, FfxDevice device, FfxCommandQueue gameQueue, FfxSwapchain& swapchain);
typedef FfxErrorCode (*FfxReleaseFiSwapchain)(FfxFrameInterpolationContext* fiContext, FfxSwapchain* outRealSwapchain);

#if defined(__cplusplus)
}
#endif                            
