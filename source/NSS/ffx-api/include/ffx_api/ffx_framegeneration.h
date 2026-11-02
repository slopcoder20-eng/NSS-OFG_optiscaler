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

#pragma once

#include "ffx_api.h"
#include "ffx_api_types.h"

                               
#define FFX_API_EFFECT_ID_FRAMEGENERATION 0x00020000u

#if defined(__cplusplus)
extern "C" {
#endif

                               
enum FfxApiCreateContextFramegenerationFlags
{
    FFX_API_FG_CONTEXT_FLAG_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS =
        (1 << 0),                                                                                 
    FFX_API_FG_CONTEXT_FLAG_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION =
        (1 << 1),                                                                                                                                       
    FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED = (1 << 2),                                                                                     
    FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INFINITE = (1 << 3),                                                                                                 
    FFX_API_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE =
        (1 << 4),                                                                                                     
    FFX_API_FG_CONTEXT_FLAG_WARP_FRAGMENT        = (1 << 5),                                                                                        
    FFX_API_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT  = (1 << 6),                                                                                      
    FFX_API_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT = (1 << 7),                                                                                            
    FFX_API_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT = (1 << 8),                                                                                            
    FFX_API_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT  = (1 << 9),                                                                                           
    FFX_API_FG_CONTEXT_FLAG_ALL_STAGES_FRAGMENT  = FFX_API_FG_CONTEXT_FLAG_WARP_FRAGMENT | FFX_API_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT |
                                                  FFX_API_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT | FFX_API_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT |
                                                  FFX_API_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT,                                                     
    FFX_API_FG_CONTEXT_FLAG_ALL_STAGES_COMPUTE = 0,                                                                                                       
    FFX_API_FG_CONTEXT_FLAG_MV_HINTS_FRAGMENT  = (1 << 11),                                                                                       

    FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH = (1 << 17),                                                                           
    FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR = (1 << 18),                                                                           
};

                               
enum FfxApiDispatchFramegenerationFlags
{
    FFX_API_FG_DISPATCH_FLAG_DRAW_DEBUG_VIEW =
        (1 << 0),                                                                                                              
    FFX_API_FG_DISPATCH_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY =
        (1 << 1),                                                                                                          
    FFX_API_FG_DISPATCH_FLAG_DUMP_GENERATED_FRAME = (1 << 2),                                                                        
};

                               
#define FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION 0x00020001u

                               
struct ffxApiCreateContextDescFrameGeneration
{
    ffxCreateContextDescHeader header;
    uint32_t                   flags;                                                                                                         
    struct FfxApiDimensions2D  displaySize;                                                                                              
    struct FfxApiDimensions2D  renderSize;                                                   
    FfxApiFloat32x4x4          initialViewProjection;                                                                            
    uint32_t                   backBufferFormat;                                                                                              
    ffxApiMessage              fpMessage;                                                                                                   
};

                               
#define FFX_API_CALLBACK_DESC_TYPE_FRAMEGENERATION_PRESENT 0x00020005u

                               
struct ffxApiCallbackDescFrameGenerationPresent
{
    ffxDispatchDescHeader header;
    void*                 device;                                                                                                
    void*                 commandList;                                                                          
    struct FfxApiResource currentBackBuffer;                                                         
    struct FfxApiResource currentUI;                                                                       
    struct FfxApiResource outputSwapChainBuffer;                                           
    bool                  isGeneratedFrame;                                                               
    uint64_t
        frameID;                                                                                                                                                                                                          
};

                               
#define FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION 0x00020003u

                               
struct ffxApiDispatchDescFrameGeneration
{
    ffxDispatchDescHeader header;
    void*                 commandList;                                                                    
    struct FfxApiResource presentColor;                                                                              
    struct FfxApiResource outputs[4];                                                                            
    uint32_t              numGeneratedFrames;                                                                        
    bool                  reset;                                                                                                           
    uint64_t
        frameID;                                                                                                                                                                                                          
};

typedef ffxReturnCode_t (*FfxApiCallbackFrameGenerationPresentFunc)(ffxApiCallbackDescFrameGenerationPresent* params, void* pUserCtx);
typedef ffxReturnCode_t (*FfxApiDispatchFrameGenerationFunc)(ffxApiDispatchDescFrameGeneration* params, void* pUserCtx);

                               
#define FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION 0x00020002u

                               
struct ffxApiConfigureDescFrameGeneration
{
    ffxConfigureDescHeader                   header;
    void*                                    swapChain;                                                                           
    FfxApiCallbackFrameGenerationPresentFunc presentCallback;                                                                                            
    void*                                    presentCallbackUserContext;                                                                     
    FfxApiDispatchFrameGenerationFunc        frameGenerationCallback;                                                                           
    void*                                    frameGenerationCallbackUserContext;                                                               
    bool                                     frameGenerationEnabled;                                                                                    
    bool     allowAsyncWorkloads;                                                                                                  
    uint32_t flags;                                                                                           
    bool     onlyPresentGenerated;                                                    
    uint64_t
                frameID;                                                                                                                                                                                                          
    const char* dumpGeneratedFramePath;                                                                      
};

                               
#define FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION_PREPARE 0x00020004u

                               
struct ffxApiDispatchDescFrameGenerationPrepare
{
    ffxDispatchDescHeader header;
    uint64_t
                               frameID;                                                                                                                                                                                                          
    void*                      commandList;                                                                     
    struct FfxApiFloatCoords2D jitterOffset;                                                             
    struct FfxApiFloatCoords2D motionVectorScale;                                                   
    float
        mvSimilarityThreshold;                                                                                                                                     
    float
        mvSimilarityNoiseThreshold;                                                                                                                            

    float                 frameTimeDelta;                                                                  
    float                 cameraNear;                                                                 
    float                 cameraFar;                                                                                                                       
    float                 cameraFovAngleVertical;                                                                                        
    float                 viewSpaceToMetersFactor;                                                             
    struct FfxApiResource depth;                                              
    struct FfxApiResource motionVectors;                                       
    struct FfxApiResource
        depthTm1;                                                                                                                                                
    struct FfxApiResource
        colorTm1;                                                                                                                                              

    FfxApiFloat32x4x4 viewProjection;                                                        
};

                               
#define FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION_KEYVALUE 0x00020006u

                               
struct ffxApiConfigureDescFrameGenerationKeyValue
{
    ffxConfigureDescHeader header;
    uint64_t               key;                                                                                      
    uint64_t               u64;                                          
    void*                  ptr;                                                 
};

                               
#define FFX_API_QUERY_DESC_TYPE_FG_GETPIPELINESTAGEINFO 0x00020007u                                                                           
                               
struct ffxApiQueryDescFgGetPipelineStageInfo
{
    ffxQueryDescHeader header;
    bool*              pOutWarpUsesFragment;                                                                                                             
    bool* pOutFillHolesUsesFragment;                                                                                                                           
    bool* pOutPreProcessUsesFragment;                                                                                                                          
    bool* pOutPostprocessUsesFragment;                                                                                                                         
    bool* pOutDebugViewUsesFragment;                                                                                                                          
};

#if defined(__cplusplus)
}               
#endif
