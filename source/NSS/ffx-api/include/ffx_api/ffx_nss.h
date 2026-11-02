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
// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#pragma once
#include "ffx_api.h"
#include "ffx_api_types.h"

#ifdef __cplusplus
extern "C" {
#endif

                   
enum FfxApiNssShaderQualityMode
{
    FFX_API_NSS_SHADER_QUALITY_MODE_QUALITY     = 0,                                                                
    FFX_API_NSS_SHADER_QUALITY_MODE_BALANCED    = 1,                                                                
    FFX_API_NSS_SHADER_QUALITY_MODE_PERFORMANCE = 2,                                                                    
};

                   
enum FfxApiCreateContextNssFlags
{
    FFX_API_NSS_CONTEXT_FLAG_QUANTIZED          = (1 << 0),                                                                         
    FFX_API_NSS_CONTEXT_FLAG_HIGH_DYNAMIC_RANGE = (1 << 1),                                                                                       
    FFX_API_NSS_CONTEXT_FLAG_DEPTH_INVERTED     = (1 << 2),                                                                                     
    FFX_API_NSS_CONTEXT_FLAG_DEPTH_INFINITE     = (1 << 3),                                                                                                 
    FFX_API_NSS_CONTEXT_FLAG_RESAMPLE_BICUBIC   = (1 << 4),                                                      
    FFX_API_NSS_CONTEXT_FLAG_ALLOW_16BIT        = (1 << 5),                                                                                 
    FFX_API_NSS_CONTEXT_FLAG_MANAGE_HISTORY =
        (1 << 6),                                                                                                                                        
    FFX_API_NSS_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT  = (1 << 7),                                                                                                
    FFX_API_NSS_CONTEXT_FLAG_POST_PROCESS_FRAGMENT = (1 << 8),                                                                                                 
};

                   
enum FfxApiDispatchNssFlags
{
    FFX_API_NSS_DISPATCH_FLAG_ENABLE_DEBUG_CHECKING =
        (1 << 0),                                                                                                                  
    FFX_API_NSS_DISPATCH_FLAG_DRAW_DEBUG_VIEW =
        (1 << 1),                                                                                                                         
};

                   
#define FFX_API_EFFECT_ID_NSS 0x000F0000u                                                                                          

#define FFX_API_CREATE_CONTEXT_DESC_TYPE_NSS 0x000F0000u                                                                
                   
struct ffxApiCreateContextDescNss
{
    ffxCreateContextDescHeader header;
    uint32_t                   flags;                                                                                 
    struct FfxApiDimensions2D  maxRenderSize;                                                             
    struct FfxApiDimensions2D  maxUpscaleSize;                                                                                 

    ffxApiMessage              fpMessage;                                                                                         
    FfxApiNssShaderQualityMode qualityMode;                                                          
};

                   
#define FFX_API_DISPATCH_DESC_TYPE_NSS 0x000F0001u                                                           
                   
struct ffxApiDispatchDescNss
{
    ffxDispatchDescHeader header;
    void*                 commandList;                                                                

    struct FfxApiResource color;                                                                                                            
    struct FfxApiResource depth;                                                                                                              
    struct FfxApiResource
                          motionVectors;                                                                                                                                                                               
    struct FfxApiResource output;                                                                                                                         
    struct FfxApiResource
        outputTm1;                                                                                                                                                                                                                                                                                                       

    struct FfxApiFloatCoords2D jitterOffset;                                                                  
    struct FfxApiDimensions2D  upscaleSize;                                                                                  
    struct FfxApiDimensions2D  renderSize;                                                                                  
    float                      cameraNear;                                                                
    float                      cameraFar;                                                                
    float                      cameraFovAngleVertical;                                                                                       

    float                      exposure;                                  
    struct FfxApiFloatCoords2D motionVectorScale;                                               

    float                 frameTimeDelta;                                                                         
    bool                  reset;                                                                                                       
    uint32_t              flags;                                                                      
    struct FfxApiResource debugViews;                                                                                                           
    uint32_t              debugViewMode;                                                                                         
};

                   
#define FFX_API_QUERY_DESC_TYPE_NSS_GETJITTERPHASECOUNT 0x000F0004u                                                                           
                   
struct ffxApiQueryDescNssGetJitterPhaseCount
{
    ffxQueryDescHeader header;
    uint32_t           renderWidth;                                    
    uint32_t           displayWidth;                                   
    int32_t*
        pOutPhaseCount;                                                                                                                                                                    
};

                   
#define FFX_API_QUERY_DESC_TYPE_NSS_GETJITTEROFFSET 0x000F0005u                                                                       
                   
struct ffxApiQueryDescNssGetJitterOffset
{
    ffxQueryDescHeader header;
    int32_t            index;                                                 
    int32_t            phaseCount;                                                                                           
    float*             pOutX;                                                                                                          
    float*             pOutY;                                                                                                          
};

                   
#define FFX_API_QUERY_DESC_TYPE_NSS_GETPIPELINESTAGEINFO 0x000F0006u                                                                            
                   
struct ffxApiQueryDescNssGetPipelineStageInfo
{
    ffxQueryDescHeader header;
    bool* pOutPreProcessUsesFragment;                                                                                                                          
    bool* pOutPostProcessUsesFragment;                                                                                                                          
};

#ifdef __cplusplus
}
#endif
