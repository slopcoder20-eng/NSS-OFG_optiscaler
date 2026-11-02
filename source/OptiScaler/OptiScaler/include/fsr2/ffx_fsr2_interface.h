// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2022-2023 Advanced Micro Devices, Inc. All rights reserved.
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

                                                                                                      
#define FFX_CPU
#include "shaders/ffx_fsr2_resources.h"
#include "shaders/ffx_fsr2_common.h"

#if defined(__cplusplus)
extern "C"
{
#endif                            

    FFX_FORWARD_DECLARE(FfxFsr2Interface);

                                                                             
       
                                                                         
                                                                  
                                                                      
                                                                                
                                                                             
                                
       
                                                                              
                                                                                 
                                                                                  
                                                                             
                                                                                   
                                                        
       
                     
    typedef enum FfxFsr2Pass
    {

        FFX_FSR2_PASS_DEPTH_CLIP = 0,                                           
        FFX_FSR2_PASS_RECONSTRUCT_PREVIOUS_DEPTH =
            1,                                                                                                    
        FFX_FSR2_PASS_LOCK = 2,                                                        
        FFX_FSR2_PASS_ACCUMULATE = 3,                                              
        FFX_FSR2_PASS_ACCUMULATE_SHARPEN = 4,                                                              
        FFX_FSR2_PASS_RCAS = 5,                                                     
        FFX_FSR2_PASS_COMPUTE_LUMINANCE_PYRAMID =
            6,                                                                              
        FFX_FSR2_PASS_GENERATE_REACTIVE = 7,                                                  
        FFX_FSR2_PASS_TCR_AUTOGENERATE =
            8,                                                                               

        FFX_FSR2_PASS_COUNT                                             
    } FfxFsr2Pass;

    typedef enum FfxFsr2MsgType
    {
        FFX_FSR2_MESSAGE_TYPE_ERROR = 0,
        FFX_FSR2_MESSAGE_TYPE_WARNING = 1,
        FFX_FSR2_MESSAGE_TYPE_COUNT
    } FfxFsr2MsgType;

                                                  
       
                                                                        
                                                                                            
       
                                                                                           
                                                                                                            
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreateBackendContextFunc)(FfxFsr2Interface* backendInterface, FfxDevice device);

                                                 
       
                                                                                  
                                                                                  
                                                                              
                                                                                  
                                                                               
                                                                                  
                                                                        
                                                          
       
                                                                               
                                                                               
                                                    
       
                                                                                           
                                                                                                      
                                                                                             
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2GetDeviceCapabilitiesFunc)(FfxFsr2Interface* backendInterface,
                                                             FfxDeviceCapabilities* outDeviceCapabilities,
                                                             FfxDevice device);

                                                               
       
                                                                                   
       
                                                                                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyBackendContextFunc)(FfxFsr2Interface* backendInterface);

                          
       
                                                                               
       
                                                                             
                                                                             
                                                                               
                                                                            
                                                                                   
                                                                                   
                                                                                 
                                                                              
                                     
       
                                                                                           
                                                                                                                  
                                                                                                        
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreateResourceFunc)(FfxFsr2Interface* backendInterface,
                                                      const FfxCreateResourceDescription* createResourceDescription,
                                                      FfxResourceInternal* outResource);

                                                                 
       
                                                                   
                                                                  
                                                                
                                                                       
                                                                       
                                                       
       
                                                                                           
                                                                                                 
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2RegisterResourceFunc)(FfxFsr2Interface* backendInterface,
                                                        const FfxResource* inResource,
                                                        FfxResourceInternal* outResource);

                                                                      
       
                                                                      
                                  
       
                                                                                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2UnregisterResourcesFunc)(FfxFsr2Interface* backendInterface);

                                                                  
                                            
       
                                                                                           
                                                                                                        
       
                
                                      
       
                     
    typedef FfxResourceDescription (*FfxFsr2GetResourceDescriptionFunc)(FfxFsr2Interface* backendInterface,
                                                                        FfxResourceInternal resource);

                          
       
                                                                                  
       
                                                                                           
                                                                                                        
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyResourceFunc)(FfxFsr2Interface* backendInterface,
                                                       FfxResourceInternal resource);

                                 
       
                                                                               
                     
       
                                                                                           
                                                                                    
                                                                                                                      
                                   
                                                                                                                     
                            
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreatePipelineFunc)(FfxFsr2Interface* backendInterface, FfxFsr2Pass pass,
                                                      const FfxPipelineDescription* pipelineDescription,
                                                      FfxPipelineState* outPipeline);

                                  
       
                                                                                           
                                                                                                                     
                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyPipelineFunc)(FfxFsr2Interface* backendInterface, FfxPipelineState* pipeline);

                                                                
                                                
       
                                                                            
                           
       
                                                                                           
                                                                                                                    
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2ScheduleGpuJobFunc)(FfxFsr2Interface* backendInterface,
                                                      const FfxGpuJobDescription* job);

                                                                               
       
                                                                            
                                                                              
                                                                            
                                                                                 
                                                                             
                              
       
                                                                                       
                                                                                
                                                     
       
                                                                                           
                                                                                                              
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2ExecuteGpuJobsFunc)(FfxFsr2Interface* backendInterface, FfxCommandList commandList);

                             
       
                                
       
                                                                   
                                                                        
       
       
                     
    typedef void (*FfxFsr2Message)(FfxFsr2MsgType type, const wchar_t* message);

                                                                                
                                                                               
       
                                                                                 
                                                                                  
                                                                                   
                                                                                   
                                                                         
                                                            
       
                                                 
                                                          
                                                  
                                                   
                                                           
                                                    
                                                   
                                                    
                                                   
                                                   
       
                                                                                  
                                                                            
                                                                               
                                                                                  
                                                                                 
                                                                               
                                                                                   
                                                                                   
                                                                        
                                                                 
       
                                                                                  
                                                                              
                                                                    
                                                                                  
                                                                 
       
                     
    typedef struct FfxFsr2Interface
    {

        FfxFsr2CreateBackendContextFunc
            fpCreateBackendContext;                                                                       
        FfxFsr2GetDeviceCapabilitiesFunc fpGetDeviceCapabilities;                                                      
        FfxFsr2DestroyBackendContextFunc
            fpDestroyBackendContext;                                                                                   
                                                 
        FfxFsr2CreateResourceFunc fpCreateResource;                                                         
        FfxFsr2RegisterResourceFunc fpRegisterResource;                                                                 
        FfxFsr2UnregisterResourcesFunc fpUnregisterResources;                                                          
        FfxFsr2GetResourceDescriptionFunc
            fpGetResourceDescription;                                                                             
        FfxFsr2DestroyResourceFunc fpDestroyResource;                                                
        FfxFsr2CreatePipelineFunc fpCreatePipeline;                                                                   
        FfxFsr2DestroyPipelineFunc fpDestroyPipeline;                                                                  
        FfxFsr2ScheduleGpuJobFunc fpScheduleGpuJob;                                                     
        FfxFsr2ExecuteGpuJobsFunc fpExecuteGpuJobs;                                                              

        void* scratchBuffer;                                                                               
        size_t scratchBufferSize;                                                                   
    } FfxFsr2Interface;

#if defined(__cplusplus)
}
#endif                            
