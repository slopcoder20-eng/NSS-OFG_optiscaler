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

#pragma once

#include "ffx_assert.h"
#include "ffx_types.h"
#include "ffx_error.h"

                                                                                                      
#define FFX_CPU
#include "shaders/ffx_fsr2_resources.h"
#include "shaders/ffx_fsr2_common.h"

namespace Fsr212
{

#if defined(__cplusplus)
extern "C"
{
#endif                            

    FFX_FORWARD_DECLARE(FfxFsr2Interface212);

                                                                             
       
                                                                         
                                                                  
                                                                      
                                                                                
                                                                             
                                
       
                                                                              
                                                                                 
                                                                                  
                                                                             
                                                                                   
                                                        
       
                     
    typedef enum FfxFsr2Pass
    {

        FFX_FSR2_PASS_PREPARE_INPUT_COLOR = 0,                                                            
        FFX_FSR2_PASS_DEPTH_CLIP = 1,                                                    
        FFX_FSR2_PASS_RECONSTRUCT_PREVIOUS_DEPTH =
            2,                                                                                                    
        FFX_FSR2_PASS_LOCK = 3,                                                        
        FFX_FSR2_PASS_ACCUMULATE = 4,                                              
        FFX_FSR2_PASS_ACCUMULATE_SHARPEN = 5,                                                              
        FFX_FSR2_PASS_RCAS = 6,                                                     
        FFX_FSR2_PASS_COMPUTE_LUMINANCE_PYRAMID =
            7,                                                                              
        FFX_FSR2_PASS_GENERATE_REACTIVE = 8,                                                  

        FFX_FSR2_PASS_COUNT                                             
    } FfxFsr2Pass;

                                                  
       
                                                                        
                                                                                            
       
                                                                                           
                                                                                                            
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreateBackendContextFunc)(FfxFsr2Interface212* backendInterface, FfxDevice device);

                                                 
       
                                                                                  
                                                                                  
                                                                              
                                                                                  
                                                                               
                                                                                  
                                                                        
                                                          
       
                                                                               
                                                                               
                                                    
       
                                                                                           
                                                                                                      
                                                                                             
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2GetDeviceCapabilitiesFunc)(FfxFsr2Interface212* backendInterface,
                                                             FfxDeviceCapabilities* outDeviceCapabilities,
                                                             FfxDevice device);

                                                               
       
                                                                                   
       
                                                                                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyBackendContextFunc)(FfxFsr2Interface212* backendInterface);

                          
       
                                                                               
       
                                                                             
                                                                             
                                                                               
                                                                            
                                                                                   
                                                                                   
                                                                                 
                                                                              
                                     
       
                                                                                           
                                                                                                                  
                                                                                                        
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreateResourceFunc)(FfxFsr2Interface212* backendInterface,
                                                      const FfxCreateResourceDescription* createResourceDescription,
                                                      FfxResourceInternal* outResource);

                                                                 
       
                                                                   
                                                                  
                                                                
                                                                       
                                                                       
                                                       
       
                                                                                           
                                                                                                 
                                                                                                                
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2RegisterResourceFunc)(FfxFsr2Interface212* backendInterface,
                                                        const FfxResource* inResource,
                                                        FfxResourceInternal* outResource);

                                                                      
       
                                                                      
                                  
       
                                                                                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2UnregisterResourcesFunc)(FfxFsr2Interface212* backendInterface);

                                                                  
                                            
       
                                                                                           
                                                                                                        
       
                
                                      
       
                     
    typedef FfxResourceDescription (*FfxFsr2GetResourceDescriptionFunc)(FfxFsr2Interface212* backendInterface,
                                                                        FfxResourceInternal resource);

                          
       
                                                                                  
       
                                                                                           
                                                                                                        
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyResourceFunc)(FfxFsr2Interface212* backendInterface,
                                                       FfxResourceInternal resource);

                                 
       
                                                                               
                     
       
                                                                                           
                                                                                    
                                                                                                                      
                                   
                                                                                                                     
                            
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2CreatePipelineFunc)(FfxFsr2Interface212* backendInterface, FfxFsr2Pass pass,
                                                      const FfxPipelineDescription* pipelineDescription,
                                                      FfxPipelineState* outPipeline);

                                  
       
                                                                                           
                                                                                                                     
                           
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2DestroyPipelineFunc)(FfxFsr2Interface212* backendInterface,
                                                       FfxPipelineState* pipeline);

                                                                
                                                
       
                                                                            
                           
       
                                                                                           
                                                                                                                    
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2ScheduleGpuJobFunc)(FfxFsr2Interface212* backendInterface,
                                                      const FfxGpuJobDescription* job);

                                                                               
       
                                                                            
                                                                              
                                                                            
                                                                                 
                                                                             
                              
       
                                                                                       
                                                                                
                                                     
       
                                                                                           
                                                                                                              
       
               
                                                                                             
               
                                                                             
       
                     
    typedef FfxErrorCode (*FfxFsr2ExecuteGpuJobsFunc)(FfxFsr2Interface212* backendInterface,
                                                      FfxCommandList commandList);

                                                                                
                                                                               
       
                                                                                 
                                                                                  
                                                                                   
                                                                                   
                                                                         
                                                            
       
                                                 
                                                          
                                                  
                                                   
                                                           
                                                    
                                                   
                                                    
                                                   
                                                   
       
                                                                                  
                                                                            
                                                                               
                                                                                  
                                                                                 
                                                                               
                                                                                   
                                                                                   
                                                                        
                                                                 
       
                                                                                  
                                                                              
                                                                    
                                                                                  
                                                                 
       
                     
    typedef struct FfxFsr2Interface212
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
}                    