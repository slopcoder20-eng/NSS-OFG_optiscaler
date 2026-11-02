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

#pragma once

#include "ffx_assert.h"
#include "ffx_error.h"
#include "ffx_types.h"

#if defined(__cplusplus)
#define FFX_CPU
extern "C" {
#endif                             

                               
                                                               
   
                   

                                       
                                                                 
                                         
   
                     
FFX_FORWARD_DECLARE(FfxInterface);

                                 
   
                         
#define FFX_SDK_VERSION_MAJOR (1)

                                 
   
                         
#define FFX_SDK_VERSION_MINOR (1)

                                 
   
                         
#define FFX_SDK_VERSION_PATCH (2)

                                                       
   
                         
#define FFX_SDK_MAKE_VERSION(major, minor, patch) ((major << 22) | (minor << 12) | patch)

                             
   
                                                                         
                                                                        
   
                         
typedef uint32_t FfxPass;

                                               
   
                                                                                        
   
            
                                             
   
                         
typedef FfxVersionNumber (*FfxGetSDKVersionFunc)(FfxInterface* backendInterface);

                          
   
                                                                                 
                                                                                   
                                                                                     
   
                                                                                        
                                                                                                             
                                                                                                   
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxGetEffectGpuMemoryUsageFunc)(FfxInterface* backendInterface, FfxUInt32 effectContextId, FfxEffectMemoryUsage* outVramUsage);

                                              
   
                                                                    
                                                                                        
   
                                                                                        
                                                                                                
                                                                                                                        
                                                                                                             
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxCreateBackendContextFunc)(FfxInterface*            backendInterface,
                                                    FfxEffect                effect,
                                                    FfxEffectBindlessConfig* bindlessConfig,
                                                    FfxUInt32*               effectContextId);

                                             
   
                                                                               
                                                                              
                                                                             
                                                                              
                                                                           
                                                                              
                                                                                    
                                                      
   
                                                                           
                                                                           
                                                
   
                                                                                       
                                                                                                  
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxGetDeviceCapabilitiesFunc)(FfxInterface* backendInterface, FfxDeviceCapabilities* outDeviceCapabilities);

                                                           
   
                                                                                 
   
                                                                                       
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxDestroyBackendContextFunc)(FfxInterface* backendInterface, FfxUInt32 effectContextId);

                      
   
                                                                           
   
                                                                         
                                                                         
                                                                       
                                                                        
                                                                               
                                                                               
                                                                             
                                                                          
                                   
   
                                                                                       
                                                                                                              
                                                                                                            
                                                                                                    
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxCreateResourceFunc)(FfxInterface*                       backendInterface,
                                              const FfxCreateResourceDescription* createResourceDescription,
                                              FfxUInt32                           effectContextId,
                                              FfxResourceInternal*                outResource);

                                                             
   
                                                                            
                                                         
                                                            
                                                                   
                                                                   
                                                   
   
                                                                                       
                                                                                             
                                                                                                            
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxRegisterResourceFunc)(FfxInterface*        backendInterface,
                                                const FfxResource*   inResource,
                                                FfxUInt32            effectContextId,
                                                FfxResourceInternal* outResource);

                                                            
   
                                                                    
                                                                    
                                                                      
                
   
                                                                                       
                                                                                                                            
   
            
                                                   
   
                         
typedef FfxResource (*FfxGetResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource);

                                                                  
   
                                                                  
                              
   
                                                                                       
                                                                                                          
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxUnregisterResourcesFunc)(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);

                                                                    
   
                                                                                 
                                                          
                                                                                          
                                               
   
                                                                                       
                                                                                                               
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxRegisterStaticResourceFunc)(FfxInterface* backendInterface, const FfxStaticResourceDescription* desc, FfxUInt32 effectContextId);

                                                              
                                        
   
                                                                                       
                                                                                                    
   
            
                                  
   
                         
typedef FfxResourceDescription (*FfxGetResourceDescriptionFunc)(FfxInterface* backendInterface, FfxResourceInternal resource);

                      
   
                                                                              
   
                                                                                       
                                                                                                    
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxDestroyResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource, FfxUInt32 effectContextId);

                       
   
                                                                
   
                                                                                       
                                                                                                    
                                                                                   
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxMapResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource, void** ptr);

                         
   
                                                  
   
                                                                                       
                                                                                                    
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxUnmapResourceFunc)(FfxInterface* backendInterface, FfxResourceInternal resource);

                      
   
                                                                              
   
                                                                                       
                                                                                                    
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxStageConstantBufferDataFunc)(FfxInterface* backendInterface, void* data, FfxUInt32 size, FfxConstantBuffer* constantBuffer);

                             
   
                                                                           
                 
   
                                                                                       
                                                                                
                                                                                                                       
                                                                                                 
                                                                                                                                              
                                                                                                            
                                                                                                                                      
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxCreatePipelineFunc)(FfxInterface*                 backendInterface,
                                              FfxEffect                     effect,
                                              FfxPass                       pass,
                                              uint32_t                      permutationOptions,
                                              const FfxPipelineDescription* pipelineDescription,
                                              FfxUInt32                     effectContextId,
                                              FfxPipelineState*             outPipeline);

                                 
   
                                                                            
                 
   
                                                                                       
                                                                                  
                                                                                
                                                                                                 
                                                                                                                                              
                                                                                                            
                                                                     
                                                                      
                                                                                                                                      
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxCreateDataGraphPipelineFunc)(FfxInterface*                 backendInterface,
                                                       FfxEffect                     effect,
                                                       FfxPass                       pass,
                                                       uint32_t                      permutationOptions,
                                                       const FfxPipelineDescription* pipelineDescription,
                                                       FfxUInt32                     effectContextId,
                                                       FfxUInt32                     render_width,
                                                       FfxUInt32                     render_height,
                                                       FfxPipelineState*             outPipeline);
                                                                                                               
typedef FfxErrorCode (*FfxCreateOpticalFlowPipelineFunc)(
    FfxInterface* backendInterface, const char* name, const FfxOpticalFlowDescription& ofDesc, FfxUInt32 effectContextId, FfxPipelineState* outPipeline);

typedef FfxErrorCode (*FfxGetPermutationBlobByIndexFunc)(
    FfxEffect effectId, FfxPass passId, uint32_t permutationOptions, FfxShaderBlob* outBlob, FfxShaderBlob* outVertBlob, FfxDataGraphBlob* outDataGraphBlob);

                              
   
                                                                                       
                                                                                                            
                                                                                                                                     
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxDestroyPipelineFunc)(FfxInterface* backendInterface, FfxPipelineState* pipeline, FfxUInt32 effectContextId);

                                                            
                                        
   
                                                                        
                       
   
                                                                                       
                                                                                                                
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxScheduleGpuJobFunc)(FfxInterface* backendInterface, const FfxGpuJobDescription* job);

                                                                           
   
                                                                        
                                                                          
                                                                    
                                                                             
                                                                         
                          
   
                                                                               
                                                                            
                                                 
   
                                                                                       
                                                                                                          
                                                                                                            
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxExecuteGpuJobsFunc)(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);

typedef enum FfxUiCompositionFlags
{
    FFX_UI_COMPOSITION_FLAG_USE_PREMUL_ALPHA                    = (1 << 0),                                                                          
    FFX_UI_COMPOSITION_FLAG_ENABLE_INTERNAL_UI_DOUBLE_BUFFERING = (1 << 1),                                                                              
} FfxUiCompositionFlags;

typedef FfxErrorCode (*FfxPresentCallbackFunc)(const FfxPresentCallbackDescription* params, void*);
typedef FfxErrorCode (*FfxFrameGenerationDispatchFunc)(const FfxFrameGenerationDispatchDescription* params, void*);
typedef FfxErrorCode (*FfxWaitCallbackFunc)(const char* fenceName, uint64_t fenceValueToWaitFor);

                                                                                             
   
                         
typedef struct FfxFrameGenerationConfig
{
    FfxSwapchain                   swapChain;                                                                                          
    FfxPresentCallbackFunc         presentCallback;                                                                                       
    void*                          presentCallbackContext;                                                                    
    FfxFrameGenerationDispatchFunc frameGenerationCallback;                                                                                     
    void*                          frameGenerationCallbackContext;                                                              
    bool                           frameGenerationEnabled;                                                                                           
    bool                           allowAsyncWorkloads;                                                                                                       
    FfxUInt32                      flags;                              
    bool                           onlyPresentInterpolated;                                                     
    uint64_t                       frameID;                                                                                         
    bool                           drawDebugPacingLines;                                                                                  
    bool                           dumpGeneratedFrame;                                                                                            
    const char*                    dumpGeneratedFramePath;                                                                                       
} FfxFrameGenerationConfig;

typedef FfxErrorCode (*FfxSwapChainConfigureFrameGenerationFunc)(FfxFrameGenerationConfig const* config);

                                                                                      
   
                                                                                       
                                                                                                                                   
   
                         
typedef void (*FfxRegisterConstantBufferAllocatorFunc)(FfxInterface* backendInterface, FfxConstantBufferAllocator constantAllocator);

                                                   
   
                                                                                            
                                                                                
   
                                                                                                   
                                                                                                     
   
                         
typedef void (*FfxBackendMessage)(uint32_t type, const char* message);

                                                          
   
                                                                                         
                                                                                       
                                                                                                   
   
                                                                                       
                                                                                                                    
   
           
                                                                                         
           
                                                                         
   
                         
typedef FfxErrorCode (*FfxSetMessageCallback)(FfxInterface* backendInterface, FfxBackendMessage ffxMessageCallback);

                                                                              
                                                                         
   
                                                                                    
                                                                                            
                                                                            
                                                                               
                                                                     
                                                        
   
                                         
                                                  
                                          
                                           
                                             
                                        
                                                
                                                   
                                            
                                           
                                            
                                           
                                           
   
                                                                              
                                                                        
                                                                                         
                                                                              
                                                                             
                                                                                 
                                                                               
                                                                              
                                                                                  
                                                              
   
                                                                              
                                                                          
                                                            
                                                                         
                                                             
   
                                                                
                                                                  
   
                         
typedef struct FfxInterface
{
    FfxSetMessageCallback fpSetMessageCallback;                                                          
                                          
    FfxGetSDKVersionFunc             fpGetSDKVersion;                                                                  
    FfxGetEffectGpuMemoryUsageFunc   fpGetEffectGpuMemoryUsage;                                                               
    FfxCreateBackendContextFunc      fpCreateBackendContext;                                                                               
    FfxGetDeviceCapabilitiesFunc     fpGetDeviceCapabilities;                                                             
    FfxDestroyBackendContextFunc     fpDestroyBackendContext;                                                                                                  
    FfxCreateResourceFunc            fpCreateResource;                                                             
    FfxRegisterResourceFunc          fpRegisterResource;                                                                       
    FfxGetResourceFunc               fpGetResource;                                                                                                    
    FfxUnregisterResourcesFunc       fpUnregisterResources;                                                                   
    FfxRegisterStaticResourceFunc    fpRegisterStaticResource;                                                              
    FfxGetResourceDescriptionFunc    fpGetResourceDescription;                                                                   
    FfxDestroyResourceFunc           fpDestroyResource;                                                             
    FfxMapResourceFunc               fpMapResource;                                                             
    FfxUnmapResourceFunc             fpUnmapResource;                                                             
    FfxStageConstantBufferDataFunc   fpStageConstantBufferDataFunc;                                                                            
    FfxCreatePipelineFunc            fpCreateComputePipeline;                                                              
    FfxCreatePipelineFunc            fpCreateGraphicsPipeline;                                                            
    FfxCreateDataGraphPipelineFunc   fpCreateDataGraphPipeline;                                                               
    FfxCreateOpticalFlowPipelineFunc fpCreateOpticalFlowPipeline;                                                                              
    FfxDestroyPipelineFunc           fpDestroyPipeline;                                                                               
    FfxScheduleGpuJobFunc            fpScheduleGpuJob;                                                                 
    FfxExecuteGpuJobsFunc            fpExecuteGpuJobs;                                                                          

                                          
    FfxGetPermutationBlobByIndexFunc         fpGetPermutationBlobByIndex;
    FfxSwapChainConfigureFrameGenerationFunc fpSwapChainConfigureFrameGeneration;                                                                    

    FfxRegisterConstantBufferAllocatorFunc
        fpRegisterConstantBufferAllocator;                                                                                             

    FfxBackendMessage fpMessage;                                                              

    void*     scratchBuffer;                                                                               
    size_t    scratchBufferSize;                                                                    
    FfxDevice device;                                           

    bool                  devCapInitialized;
    FfxDeviceCapabilities deviceCapabilities;
} FfxInterface;

#if defined(__cplusplus)
}
#endif                             
