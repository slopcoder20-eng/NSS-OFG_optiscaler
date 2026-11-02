// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2023 Advanced Micro Devices, Inc. All rights reserved.
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

#pragma once

#include "ffx_assert.h"
#include "ffx_types.h"
#include "ffx_error.h"

namespace Fsr3
{
#if defined(__cplusplus)
#define FFX_CPU
extern "C"
{
#endif                            

                                   
                                                                   
       
                       

                                           
                                                                     
                                             
       
                         
    FFX_FORWARD_DECLARE(FfxInterface);

                                     
       
                             
#define FFX_SDK_VERSION_MAJOR (1)

                                 
   
                         
#define FFX_SDK_VERSION_MINOR (0)

                                 
   
                         
#define FFX_SDK_VERSION_PATCH (1)

                                                       
   
                         
#define FFX_SDK_MAKE_VERSION(major, minor, patch) ((major << 22) | (minor << 12) | patch)

                                 
       
                                                                              
                                                                            
       
                             
    typedef uint32_t FfxPass;

                                                   
       
                                                                                     
                                                                                       
                                                                                         
       
                                                                                            
       
                
                                                 
       
                             
    typedef FfxUInt32 (*FfxGetSDKVersionFunc)(FfxInterface* backendInterface);

                                                  
       
                                                                        
                                                                                            
       
                                                                                            
                                                                                                                 
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxCreateBackendContextFunc)(FfxInterface* backendInterface, FfxUInt32* effectContextId);

                                                 
       
                                                                                   
                                                                                  
                                                                                 
                                                                                  
                                                                               
                                                                                  
                                                                                        
                                                          
       
                                                                               
                                                                               
                                                    
       
                                                                                           
                                                                                                      
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxGetDeviceCapabilitiesFunc)(FfxInterface* backendInterface,
                                                         FfxDeviceCapabilities* outDeviceCapabilities);

                                                               
       
                                                                                     
       
                                                                                           
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxDestroyBackendContextFunc)(FfxInterface* backendInterface, FfxUInt32 effectContextId);

                          
       
                                                                               
       
                                                                             
                                                                             
                                                                           
                                                                            
                                                                                   
                                                                                   
                                                                                 
                                                                              
                                       
       
                                                                                           
                                                                                                                  
                                                                                                                
                                                                                                        
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxCreateResourceFunc)(FfxInterface* backendInterface,
                                                  const FfxCreateResourceDescription* createResourceDescription,
                                                  FfxUInt32 effectContextId, FfxResourceInternal* outResource);

                                                                 
       
                                                                                
                                                             
                                                                
                                                                       
                                                                       
                                                       
       
                                                                                           
                                                                                                 
                                                                                                                
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxRegisterResourceFunc)(FfxInterface* backendInterface, const FfxResource* inResource,
                                                    FfxUInt32 effectContextId, FfxResourceInternal* outResource);

                                                                
       
                                                                        
                                                                        
                                                                          
                    
       
                                                                                           
                                                                                                                   
                    
       
                
                                                       
       
                             
    typedef FfxResource (*FfxGetResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource);

                                                                      
       
                                                                      
                                  
       
                                                                                           
                                                                                                              
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxUnregisterResourcesFunc)(FfxInterface* backendInterface, FfxCommandList commandList,
                                                       FfxUInt32 effectContextId);

                                                                  
                                            
       
                                                                                           
                                                                                                        
       
                
                                      
       
                             
    typedef FfxResourceDescription (*FfxGetResourceDescriptionFunc)(FfxInterface* backendInterface,
                                                                    FfxResourceInternal resource);

                          
       
                                                                                  
       
                                                                                           
                                                                                                        
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxDestroyResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource,
                                                   FfxUInt32 effectContextId);

                                 
       
                                                                               
                     
       
                                                                                           
                                                                                    
                                                                                                                      
                                   
                                                                                                                
                                                                                                                     
                            
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxCreatePipelineFunc)(FfxInterface* backendInterface, FfxEffect effect, FfxPass pass,
                                                  uint32_t permutationOptions,
                                                  const FfxPipelineDescription* pipelineDescription,
                                                  FfxUInt32 effectContextId, FfxPipelineState* outPipeline);

    typedef FfxErrorCode (*FfxGetPermutationBlobByIndexFunc)(FfxEffect effectId, FfxPass passId, FfxBindStage bindStage,
                                                             uint32_t permutationOptions, FfxShaderBlob* outBlob);

                                  
       
                                                                                           
                                                                                                                
                                                                                                                     
                           
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxDestroyPipelineFunc)(FfxInterface* backendInterface, FfxPipelineState* pipeline,
                                                   FfxUInt32 effectContextId);

                                                                
                                            
       
                                                                            
                           
       
                                                                                           
                                                                                                                    
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxScheduleGpuJobFunc)(FfxInterface* backendInterface, const FfxGpuJobDescription* job);

                                                                               
       
                                                                            
                                                                              
                                                                        
                                                                                 
                                                                             
                              
       
                                                                                   
                                                                                
                                                     
       
                                                                                           
                                                                                                              
       
               
                                                                                             
               
                                                                             
       
                             
    typedef FfxErrorCode (*FfxExecuteGpuJobsFunc)(FfxInterface* backendInterface, FfxCommandList commandList);

    typedef FfxErrorCode (*FfxPresentCallbackFunc)(const FfxPresentCallbackDescription* params);
    typedef FfxErrorCode (*FfxFrameGenerationDispatchFunc)(const FfxFrameGenerationDispatchDescription* params);

    typedef struct FfxFrameGenerationConfig
    {
        FfxSwapchain swapChain;
        FfxPresentCallbackFunc presentCallback;
        FfxFrameGenerationDispatchFunc frameGenerationCallback;
        bool frameGenerationEnabled;
        bool allowAsyncWorkloads;
        FfxResource HUDLessColor;
        FfxUInt32 flags;
        bool onlyPresentInterpolated;
    } FfxFrameGenerationConfig;

    typedef FfxErrorCode (*ffxSwapChainConfigureFrameGenerationFunc)(FfxFrameGenerationConfig const* config);

                                                                                  
                                                                             
       
                                                                                        
                                                                                                
                                                                                
                                                                                   
                                                                         
                                                            
       
                                             
                                                      
                                              
                                               
                                                 
                                            
                                                    
                                                       
                                                
                                               
                                                
                                               
                                               
       
                                                                                  
                                                                            
                                                                                             
                                                                                  
                                                                                 
                                                                               
                                                                                   
                                                                                  
                                                                                      
                                                                  
       
                                                                                  
                                                                              
                                                                    
                                                                              
                                                                 
       
                                                                    
                                                                      
       
                             

    typedef struct FfxInterface
    {

        FfxGetSDKVersionFunc fpGetSDKVersion;                                                   
        FfxCreateBackendContextFunc
            fpCreateBackendContext;                                                                       
        FfxGetDeviceCapabilitiesFunc fpGetDeviceCapabilities;                                                       
        FfxDestroyBackendContextFunc fpDestroyBackendContext;                                                         
                                                                                                     
        FfxCreateResourceFunc fpCreateResource;                                                             
        FfxRegisterResourceFunc fpRegisterResource;                                                                     
        FfxGetResourceFunc
            fpGetResource;                                                                                   
        FfxUnregisterResourcesFunc fpUnregisterResources;                                                          
        FfxGetResourceDescriptionFunc
            fpGetResourceDescription;                                                                         
        FfxDestroyResourceFunc fpDestroyResource;                                                
        FfxCreatePipelineFunc fpCreatePipeline;                                                                   
        FfxGetPermutationBlobByIndexFunc fpGetPermutationBlobByIndex;
        FfxDestroyPipelineFunc fpDestroyPipeline;                                                                  
        FfxScheduleGpuJobFunc fpScheduleGpuJob;                                                     
        FfxExecuteGpuJobsFunc fpExecuteGpuJobs;                                                              
        ffxSwapChainConfigureFrameGenerationFunc
            fpSwapChainConfigureFrameGeneration;                                                                   

        void* scratchBuffer;                                                                               
        size_t scratchBufferSize;                                                                   
        FfxDevice device;                                       

    } FfxInterface;

#if defined(__cplusplus)
}
#endif                            
}                  