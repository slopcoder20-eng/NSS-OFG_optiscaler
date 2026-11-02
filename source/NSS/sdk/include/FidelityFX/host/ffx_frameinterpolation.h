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
//
// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

// @defgroup ffxFrameGeneration

#pragma once

                                                                       
#include <FidelityFX/host/ffx_interface.h>

                                                
   
                               
#define FFX_FRAMEINTERPOLATION_VERSION_MAJOR (0)

                                                
   
                               
#define FFX_FRAMEINTERPOLATION_VERSION_MINOR (1)

                                                
   
                               
#define FFX_FRAMEINTERPOLATION_VERSION_PATCH (0)

                                                
   
                                                                                  
   
                                  
#define FFX_FRAMEINTERPOLATION_CONTEXT_COUNT (1)

                                                      
   
                               
#define FFX_FRAMEINTERPOLATION_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE)

#if defined(__cplusplus)
extern "C" {
#endif                             

                                                                         
   
                                                                     
                                                              
                                                                  
                                                                            
                                                                         
                            
   
                                                                          
                                                                             
                                                                              
                                                                         
                                                                               
                                                    
   
                               
typedef enum FfxFrameInterpolationPass
{
    FFX_FRAMEINTERPOLATION_PASS_INIT_WARP,                            
    FFX_FRAMEINTERPOLATION_PASS_DOWNSAMPLE_OF_COLOUR,                            
    FFX_FRAMEINTERPOLATION_PASS_WARP_MV_TP1,                          
    FFX_FRAMEINTERPOLATION_PASS_WARP_FLOW_TM1,                            
    FFX_FRAMEINTERPOLATION_PASS_FILL_HOLES_TP1,                        
    FFX_FRAMEINTERPOLATION_PASS_FILL_HOLES_TM1,                            
    FFX_FRAMEINTERPOLATION_PASS_PREPROCESS,                            
    FFX_FRAMEINTERPOLATION_PASS_NFRU_INTERPOLATION,                               
    FFX_FRAMEINTERPOLATION_PASS_POSTPROCESS,                            
    FFX_FRAMEINTERPOLATION_PASS_DEBUG_VIEW,
    FFX_FRAMEINTERPOLATION_PASS_MLOF2,
    FFX_FRAMEINTERPOLATION_PASS_COUNT                                                            
} FfxFrameInterpolationPass;

                       
struct FfxFrameInterpolationContext;

                                                    
                                                                                                          
   
                               
typedef enum FfxFrameInterpolationInitializationFlagBits
{

    FFX_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED = (1 << 0),                                                                                     
    FFX_FG_CONTEXT_FLAG_ENABLE_DEPTH_INFINITE = (1 << 1),                                                                                                 
    FFX_ARM_FRAMEINTERPOLATION_ENABLE_TEXTURE1D_USAGE             = (1 << 2),                                                                
    FFX_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE                 = (1 << 3),                                                                            
    FFX_FG_CONTEXT_FLAG_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS  = (1 << 4),                                                                                 
    FFX_FG_CONTEXT_FLAG_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION = (1 << 5),
    FFX_FG_CONTEXT_FLAG_WARP_FRAGMENT        = (1 << 6),                                                                                         
    FFX_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT  = (1 << 7),                                                                                       
    FFX_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT = (1 << 8),                                                                                              
    FFX_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT = (1 << 9),                                                                                
    FFX_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT  = (1 << 11),                                                                              
    FFX_FG_CONTEXT_FLAG_ALL_STAGES_FRAGMENT  = FFX_FG_CONTEXT_FLAG_WARP_FRAGMENT | FFX_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT |
                                              FFX_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT | FFX_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT |
                                              FFX_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT,                                              
    FFX_FG_CONTEXT_FLAG_ALL_STAGES_COMPUTE    = 0,                                                                                                         
    FFX_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH = (1 << 15),                                                                           
    FFX_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR = (1 << 16),                                                                           
} FfxFrameInterpolationInitializationFlagBits;

                         
   
                            
   
                                                               
                                                                    
   
   
                  
typedef void (*FfxFiMessage)(FfxMsgType type, const char* message);

                                                                   
                                            
   
                               
typedef struct FfxFrameInterpolationContextDescription
{
    uint32_t               flags;                                                                                         
    FfxDimensions2D        maxRenderSize;                                                            
    FfxDimensions2D        displaySize;                                                
    FfxSurfaceFormat       backBufferFormat;
    FfxInterface           backendInterface;                                                                              
    FfxFloat32x4x4         initialViewProjection;                                                                            
    FfxDimensions2D        opticalFlowSize;                                   
    FfxOpticalFlowGridSize opticalFlowGridSize;                                                                                                          
    FfxFiMessage           fpMessage;                                                                                      
} FfxFrameInterpolationContextDescription;

                                                                        
   
                                                                          
                                        
   
                                                                           
                                                                             
                                                                             
                                                                          
                 
   
                               
typedef struct FfxFrameInterpolationContext
{
    uint32_t data[FFX_FRAMEINTERPOLATION_CONTEXT_SIZE];                                                                               
} FfxFrameInterpolationContext;

                                                                      
                                                                  
   
                                                                           
                                                                             
                                                                          
                                                                             
                                                                         
                                                                   
                                                                             
                                                                              
                                                            
   
                                                          
                                                                    
                                                                               
                                                            
                                                                                
                                                                            
                                                       
   
                                                                        
                                                                       
                                                         
                                                          
   
                                                                          
                                                                             
                                                                   
                                        
   
                                                                                                          
                                                                                                         
   
           
                                                                             
           
                                                                                                                                                             
           
                                                                                                                                                    
           
                                                                                                           
   
                               
FFX_API FfxErrorCode ffxFrameInterpolationContextCreate(FfxFrameInterpolationContext* context, FfxFrameInterpolationContextDescription* contextDescription);

FFX_API FfxErrorCode ffxFrameInterpolationContextGetGpuMemoryUsage(FfxFrameInterpolationContext* pContext, FfxEffectMemoryUsage* vramUsage);

typedef struct FfxFrameInterpolationPrepareDescription
{
    FfxCommandList   commandList;                                                                                          
    FfxFloatCoords2D jitterOffset;                                                             
    FfxFloatCoords2D motionVectorScale;                                                   
    float
        mvSimilarityThreshold;                                                                                                                                     
    float
        mvSimilarityNoiseThreshold;                                                                                                                            

    float frameTimeDelta;
    float cameraNear;
    float cameraFar;
    float viewSpaceToMetersFactor;
    float cameraFovAngleVertical;

    FfxResource depth;                                     
    FfxResource motionVectors;                              
    FfxResource depthTm1;                                                                 
    FfxResource depthTm1Next;                                                                                                                     
    FfxResource colorTm1;                                                                                                     
    FfxResource colorTm1Backup;                                                                                                                  
    uint64_t    frameID;

    FfxFloat32x4x4 viewProjection;                                                        
} FfxFrameInterpolationPrepareDescription;

FFX_API FfxErrorCode ffxFrameInterpolationPrepare(FfxFrameInterpolationContext* context, const FfxFrameInterpolationPrepareDescription* params);

typedef enum FfxFrameInterpolationDispatchFlags
{
    FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW =
        (1 << 0),                                                                                                                 
} FfxFrameInterpolationDispatchFlags;

typedef struct FfxFrameInterpolationDispatchDescription
{
    uint32_t       flags;                                                                    
    FfxCommandList commandList;                                                                                          
    FfxResource    currentBackBuffer;                                      
    FfxResource    output;                                                                             

    FfxResource      opticalFlowVector;                                                                                                           
    FfxResource      opticalFlowSceneChangeDetection;                                                   
    FfxDimensions2D  opticalFlowBufferSize;                                                                   
    FfxFloatCoords2D opticalFlowScale;                                                                                                                     

    float cameraNear;                                                                 
    float cameraFar;                                                                                                                       
    float cameraFovAngleVertical;                                                                                        
    float viewSpaceToMetersFactor;                                                          

    float frameTimeDelta;                                                                         
    bool  reset;                                                                                                       

    uint64_t
        frameID;                                                                                                                                                                                                          

    float timestep;                                                    
    bool mfgContinuation;                                            
    bool mfgDeferHistory;                                                        
    bool mfgMvResidual;                                                              
    FfxResource fullColorWithHud;                                                                              
    uint32_t mfg;                                                              
} FfxFrameInterpolationDispatchDescription;

FFX_API FfxErrorCode ffxFrameInterpolationDispatch(FfxFrameInterpolationContext* context, const FfxFrameInterpolationDispatchDescription* params);

                                                                           
                                                                                      
                                                                                                                   
                                                                       
   
                                                                                         
                                                                           
                                                                                  
   
                                                                     
                               
FFX_API FfxErrorCode ffxFrameInterpolationDispatchDownsampleColour(FfxFrameInterpolationContext* context,
                                                                   FfxCommandList                commandList,
                                                                   FfxResource                   currentColour);

                                                                                               
   
                                                                                         
                                                                        
   
                                                                     
                               
FFX_API FfxErrorCode ffxFrameInterpolationGetRequiresColourDownsample(FfxFrameInterpolationContext* context, bool* pRequired);

                                                                    
                                                                                     
                                                                   
   
                                                                                         
                                                                                           
   
                                                                     
                               
FFX_API FfxErrorCode ffxFrameInterpolationGetDownsampledColourP1(FfxFrameInterpolationContext* context, FfxResource* pResource);

                                                                     
                                                                      
                                                                      
                                          
                                                                   
   
                                                                                         
                                                                                                            
   
                                                                     
                               
FFX_API FfxErrorCode ffxFrameInterpolationGetDownsampledColourM1(FfxFrameInterpolationContext* context, FfxResource* pResource);

                                                    
   
                                                                                                         
   
           
                                                                             
           
                                                                                                                         
   
                               
FFX_API FfxErrorCode ffxFrameInterpolationContextDestroy(FfxFrameInterpolationContext* context);

                                                                            
                                                  
   
                                                                            
                                                                           
                                                                        
   
                                                                                                                           
                                                                                                                                 
                                                                                                                                       
                                                                                                                                   
                                                                                                                                   
                                                                                                                                  
   
           
                                                                             
           
                                                                               
   
                               
FFX_API FfxErrorCode ffxFrameInterpolationGetPipelineStageInfo(FfxFrameInterpolationContext* pContext,
                                                               bool*                         pOutWarpUsesFragment,
                                                               bool*                         pOutFillHolesUsesFragment,
                                                               bool*                         pOutPreProcessUsesFragment,
                                                               bool*                         pOutPostprocessUsesFragment,
                                                               bool*                         pOutDebugViewUsesFragment);

                                      
   
            
                                              
   
                               
FFX_API FfxVersionNumber ffxFrameInterpolationGetEffectVersion();

#if defined(__cplusplus)
}
#endif                             
