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

// @defgroup OpticalFlow

#pragma once

                                                                
#include <FidelityFX/host/ffx_interface.h>

                                         
   
                            
#define FSR3_OPTICALFLOW_VERSION_MAJOR (1)

                                         
   
                            
#define FSR3_OPTICALFLOW_VERSION_MINOR (1)

                                         
   
                            
#define FSR3_OPTICALFLOW_VERSION_PATCH (2)

                                         
   
                                                                           
   
                           
#define FSR3_OPTICALFLOW_CONTEXT_COUNT (1)

                                                          
   
                            
#define FSR3_OPTICALFLOW_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE)

#if defined(__cplusplus)
extern "C" {
#endif                            

                                                                                
   
                            
typedef enum Fsr3OpticalflowPass
{
    FSR3_OPTICALFLOW_PASS_PREPARE_LUMA = 0,
    FSR3_OPTICALFLOW_PASS_GENERATE_OPTICAL_FLOW_INPUT_PYRAMID,
    FSR3_OPTICALFLOW_PASS_GENERATE_SCD_HISTOGRAM,
    FSR3_OPTICALFLOW_PASS_COMPUTE_SCD_DIVERGENCE,
    FSR3_OPTICALFLOW_PASS_COMPUTE_OPTICAL_FLOW_ADVANCED_V5,
    FSR3_OPTICALFLOW_PASS_FILTER_OPTICAL_FLOW_V5,
    FSR3_OPTICALFLOW_PASS_SCALE_OPTICAL_FLOW_ADVANCED_V5,

    FSR3_OPTICALFLOW_PASS_CONVERT_FORWARD,
    FSR3_OPTICALFLOW_PASS_COUNT
} Fsr3OpticalflowPass;

                                                    
                                                                                               
   
                            
typedef enum Fsr3OpticalflowInitializationFlagBits
{
    FSR3_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE = (1 << 0),

} Fsr3OpticalflowInitializationFlagBits;

                                                                    
                           
   
                            
typedef struct Fsr3OpticalflowContextDescription {

    FfxInterface                backendInterface;                                                                              
    uint32_t                    flags;                                                                                           
    FfxDimensions2D             resolution;
} Fsr3OpticalflowContextDescription;

                                                                               
                              
   
                            
typedef struct Fsr3OpticalflowDispatchDescription
{
    FfxCommandList   commandList;                                                                               
    FfxResource      color;                                                                                
    FfxResource      opticalFlowVector;                                                                      
    FfxResource      opticalFlowSCD;                                                                                         
    bool             reset;                                                                                                         
    int              backbufferTransferFunction;
    FfxFloatCoords2D minMaxLuminance;
} Fsr3OpticalflowDispatchDescription;

typedef struct Fsr3OpticalflowSharedResourceDescriptions {

    FfxCreateResourceDescription opticalFlowVector;
    FfxCreateResourceDescription opticalFlowSCD;

} Fsr3OpticalflowSharedResourceDescriptions;

                                                                 
   
                                                                          
                                               
   
                                                                                   
                                                                                           
                                                                                    
                                                                                  
                        
   
                            
typedef struct Fsr3OpticalflowContext
{
    uint32_t data[FSR3_OPTICALFLOW_CONTEXT_SIZE];                                                                               
} Fsr3OpticalflowContext;


                                                               
                                                                                
   
                                                                                  
                                                                             
                                                                                 
                                                                             
                                                                         
                                                                          
                                                                             
                                                                                      
                                                            
   
                                                          
                                                                            
                                                                                      
                                                            
                                                                                       
                                                                            
                                                              
   
                                                                                
                                                                               
                                                         
                                                                  
   
                                                                                  
                                                                          
                                                                          
                                                
   
                                                                                                                  
                                                                                                                 
   
           
                                                                             
           
                                                                                                                                                             
           
                                                                                                                                                            
           
                                                                                                           
   
                            
FFX_API FfxErrorCode fsr3OpticalflowContextCreate(Fsr3OpticalflowContext* context, Fsr3OpticalflowContextDescription* contextDescription);

FFX_API FfxErrorCode fsr3OpticalflowContextGetGpuMemoryUsage(Fsr3OpticalflowContext* pContext, FfxEffectMemoryUsage* vramUsage);

FFX_API FfxErrorCode fsr3OpticalflowGetSharedResourceDescriptions(Fsr3OpticalflowContext* context, Fsr3OpticalflowSharedResourceDescriptions* SharedResources);

FFX_API FfxErrorCode fsr3OpticalflowContextDispatch(Fsr3OpticalflowContext* context, const Fsr3OpticalflowDispatchDescription* dispatchDescription);

                                               
   
                                                                                                                 
   
           
                                                                             
           
                                                                                                                         
   
                            
FFX_API FfxErrorCode fsr3OpticalflowContextDestroy(Fsr3OpticalflowContext* context);

                                      
   
            
                                              
   
                            
FFX_API FfxVersionNumber fsr3OpticalflowGetEffectVersion();

#if defined(__cplusplus)
}
#endif                            

FfxErrorCode fsr3OpticalflowConvertForward(Fsr3OpticalflowContext*, FfxCommandList, const FfxResource*, const FfxResource*);
FfxErrorCode fsr3OfGetBlob(uint32_t passId, FfxShaderBlob* out);
