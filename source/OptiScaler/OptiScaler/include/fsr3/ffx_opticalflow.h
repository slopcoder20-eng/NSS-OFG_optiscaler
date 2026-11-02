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

// @defgroup OpticalFlow

#pragma once

                                                                
#include "ffx_interface.h"

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_MAJOR (1)

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_MINOR (0)

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_PATCH (0)

                                         
   
                                                                           
   
                           
#define FFX_OPTICALFLOW_CONTEXT_COUNT (1)

                                                          
   
                           
#define FFX_OPTICALFLOW_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE)

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                                    
       
                               
    typedef enum FfxOpticalflowPass
    {
        FFX_OPTICALFLOW_PASS_PREPARE_LUMA = 0,
        FFX_OPTICALFLOW_PASS_GENERATE_OPTICAL_FLOW_INPUT_PYRAMID,
        FFX_OPTICALFLOW_PASS_GENERATE_SCD_HISTOGRAM,
        FFX_OPTICALFLOW_PASS_COMPUTE_SCD_DIVERGENCE,
        FFX_OPTICALFLOW_PASS_COMPUTE_OPTICAL_FLOW_ADVANCED_V5,
        FFX_OPTICALFLOW_PASS_FILTER_OPTICAL_FLOW_V5,
        FFX_OPTICALFLOW_PASS_SCALE_OPTICAL_FLOW_ADVANCED_V5,

        FFX_OPTICALFLOW_PASS_COUNT
    } FfxOpticalflowPass;

                                                        
                                                                                                 
       
                               
    typedef enum FfxOpticalflowInitializationFlagBits
    {
        FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE = (1 << 0),

    } FfxOpticalflowInitializationFlagBits;

                                                                       
                               
       
                               
    typedef struct FfxOpticalflowContextDescription
    {

        Fsr3::FfxInterface backendInterface;                                                                        
        uint32_t flags;                                                                                        
        Fsr3::FfxDimensions2D resolution;
    } FfxOpticalflowContextDescription;

                                                                                   
                                  
       
                               
    typedef struct FfxOpticalflowDispatchDescription
    {
        Fsr3::FfxCommandList commandList;                                                                            
        Fsr3::FfxResource color;                                                                               
        Fsr3::FfxResource opticalFlowVector;                                                                     
        Fsr3::FfxResource opticalFlowSCD;                                                                                     
        bool reset;                                                                                             
        int backbufferTransferFunction;
        Fsr3::FfxFloatCoords2D minMaxLuminance;
    } FfxOpticalflowDispatchDescription;

    typedef struct FfxOpticalflowSharedResourceDescriptions
    {

        Fsr3::FfxCreateResourceDescription opticalFlowVector;
        Fsr3::FfxCreateResourceDescription opticalFlowSCD;

    } FfxOpticalflowSharedResourceDescriptions;

                                                                     
       
                                                                              
                                                   
       
                                                                                      
                                                                                               
                                                                                        
                                                                                      
                            
       
                               
    typedef struct FfxOpticalflowContext
    {
        uint32_t data[FFX_OPTICALFLOW_CONTEXT_SIZE];                                                                 
                                                                      
    } FfxOpticalflowContext;

                                                                   
                                                                                   
       
                                                                                      
                                                                                 
                                                                                     
                                                                                 
                                                                             
                                                                              
                                                                                 
                                                                                         
                                                                
       
                                                              
                                                                               
                                                                                          
                                                                
                                                                                          
                                                                                
                                                                  
       
                                                                                   
                                                                                  
                                                             
                                                                     
       
                                                                                     
                                                                              
                                                                              
                                                   
       
                                                                                                                     
                                                                                                                    
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                          
               
                                                                                                               
       
                               
    FFX_API Fsr3::FfxErrorCode ffxOpticalflowContextCreate(FfxOpticalflowContext* context,
                                                           FfxOpticalflowContextDescription* contextDescription);

    FFX_API Fsr3::FfxErrorCode
    ffxOpticalflowGetSharedResourceDescriptions(FfxOpticalflowContext* context,
                                                FfxOpticalflowSharedResourceDescriptions* SharedResources);

    FFX_API Fsr3::FfxErrorCode
    ffxOpticalflowContextDispatch(FfxOpticalflowContext* context,
                                  const FfxOpticalflowDispatchDescription* dispatchDescription);

                                                   
       
                                                                                                                    
       
               
                                                                                 
               
                                                                                                         
                           
       
                               
    FFX_API Fsr3::FfxErrorCode ffxOpticalflowContextDestroy(FfxOpticalflowContext* context);

#if defined(__cplusplus)
}
#endif                            
