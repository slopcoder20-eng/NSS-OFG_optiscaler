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

// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

// @defgroup OpticalFlow

#pragma once

                                                                
#include <FidelityFX/host/ffx_interface.h>

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_MAJOR (1)

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_MINOR (0)

                                         
   
                           
#define FFX_OPTICALFLOW_VERSION_PATCH (0)

                                         
   
                                                                           
   
                           
#define FFX_OPTICALFLOW_CONTEXT_COUNT (1)

                                                          
   
                           
#define FFX_OPTICALFLOW_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE * 2)

#if defined(__cplusplus)
extern "C" {
#endif                             

typedef enum FfxOpticalflowPass
{
    FFX_OPTICALFLOW_PASS_COMPUTE_MOTION_FROM_DEPTH = 0,

    FFX_OPTICALFLOW_PASS_COUNT
} FfxOpticalflowPass;

typedef enum FfxOpticalflowInitializationFlagBits
{
    FFX_OPTICALFLOW_ENABLE_DEPTH_INVERTED    = (1 << 0),
    FFX_OPTICALFLOW_ENABLE_MV_HINTS_FRAGMENT = (1 << 1),

} FfxOpticalflowInitializationFlagBits;

typedef enum FfxOpticalFlowSearchRange
{
    FFX_OPTICALFLOW_SEARCH_RANGE_DEFAULT = 0,
    FFX_OPTICALFLOW_SEARCH_RANGE_1       = 1,
    FFX_OPTICALFLOW_SEARCH_RANGE_2       = 2,
    FFX_OPTICALFLOW_SEARCH_RANGE_3       = 3,
} FfxOpticalFlowSearchRange;

                                                                   
                           
   
                           
typedef struct FfxOpticalFlowContextDescription
{
    FfxInterface                   backendInterface;                                                                              
    uint32_t                       flags;                                                                                          
    FfxDimensions2D                resolution;                               
    FfxDimensions2D                maxRenderSize;                                                                    
    FfxFloat32x4x4                 initialViewProjection;                                                                            
    FfxSurfaceFormat               backBufferFormat;
    FfxOpticalFlowGridSize         gridSize;
    FfxOpticalFlowPerformanceLevel performanceLevel;
} FfxOpticalFlowContextDescription;

                                                                               
                              
   
                           
typedef struct FfxOpticalFlowDispatchDescription
{
    FfxCommandList commandList;                                                                                
    FfxResource    color;                                                                                
    FfxResource    depth;                                                                                                       
    FfxFloat32x4x4 viewProjection;                                                          
    FfxResource    opticalFlowVector;                                                                      
    FfxResource
        depthTm1;                                                                                                                                             
    FfxResource
             colorTm1;                                                                                                                                             
    uint32_t meanFlowL1NormHint;                                                                
    FfxResource motionVectors;                                                                   
    FfxFloatCoords2D motionVectorUvScale;                                         
    bool     reset;                                                                                                           
} FfxOpticalFlowDispatchDescription;

typedef struct FfxOpticalFlowSharedResourceDescriptions
{
    FfxCreateResourceDescription opticalFlowVector;
    FfxCreateResourceDescription depthTm1;
    FfxCreateResourceDescription depthTm1Next;
    FfxCreateResourceDescription colorTm1;
} FfxOpticalFlowSharedResourceDescriptions;

                                                                 
   
                                                                          
                                               
   
                                                                                  
                                                                                           
                                                                                    
                                                                                  
                        
   
                           
typedef struct FfxOpticalFlowContext
{
    uint32_t data[FFX_OPTICALFLOW_CONTEXT_SIZE];                                                                               
} FfxOpticalFlowContext;

                                                               
                                                                               
   
                                                                                  
                                                                             
                                                                                 
                                                                             
                                                                         
                                                                          
                                                                             
                                                                                     
                                                            
   
                                                          
                                                                           
                                                                                      
                                                            
                                                                                      
                                                                            
                                                              
   
                                                                               
                                                                              
                                                         
                                                                 
   
                                                                                 
                                                                          
                                                                          
                                               
   
                                                                                                                 
                                                                                                                
   
           
                                                                             
           
                                                                                                                                                             
           
                                                                                                                                                           
           
                                                                                                           
   
                           
FFX_API FfxErrorCode ffxOpticalFlowContextCreate(FfxOpticalFlowContext* context, FfxOpticalFlowContextDescription* contextDescription);

FFX_API FfxErrorCode ffxOpticalFlowGetSharedResourceDescriptions(FfxOpticalFlowContext* context, FfxOpticalFlowSharedResourceDescriptions* SharedResources);

FFX_API FfxErrorCode ffxOpticalFlowContextDispatch(FfxOpticalFlowContext* context, FfxOpticalFlowDispatchDescription* dispatchDescription);

                                                                      
   
                                                                                                      
   
           
                               
   
                           
FFX_API FfxOpticalFlowGridSize ffxGetDefaultDataGraphOpticalFlowGridSize(FfxInterface& backendInterface);

                                                               
   
                                                                                                      
                                                                                    
   
           
                                                                    
   
                           
FFX_API bool ffxOpticalFlowGridSizeSupported(FfxInterface& backendInterface, const FfxOpticalFlowGridSize gridSize);

                                                    
   
                                                                                           
   
           
                               
   
                           
FFX_API FfxOpticalFlowGridSize ffxOpticalFlowGetGridSize(FfxOpticalFlowContext* context);

                                                       
   
                                                                                           
   
           
                                        
   
                           
FFX_API FfxDimensions2D ffxOpticalFlowGetSize(FfxOpticalFlowContext* context);

                                               
   
                                                                                                                
   
           
                                                                             
           
                                                                                                                         
   
                           
FFX_API FfxErrorCode ffxOpticalFlowContextDestroy(FfxOpticalFlowContext* context);

                                      
   
            
                                              
   
                           
FFX_API FfxVersionNumber ffxOpticalFlowGetEffectVersion();

#if defined(__cplusplus)
}
#endif                             
