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

#pragma once
#include "ffx_api.h"
#include "ffx_api_types.h"

#ifdef __cplusplus
extern "C" {
#endif

enum FfxApiUpscaleQualityMode
{
    FFX_UPSCALE_QUALITY_MODE_NATIVEAA          = 0,                                                                      
    FFX_UPSCALE_QUALITY_MODE_QUALITY           = 1,                                                                      
    FFX_UPSCALE_QUALITY_MODE_BALANCED          = 2,                                                                      
    FFX_UPSCALE_QUALITY_MODE_PERFORMANCE       = 3,                                                                      
    FFX_UPSCALE_QUALITY_MODE_ULTRA_PERFORMANCE = 4                                                                       
};

enum FfxApiCreateContextUpscaleFlags
{
    FFX_UPSCALE_ENABLE_HIGH_DYNAMIC_RANGE                 = (1 << 0),                                                                                       
    FFX_UPSCALE_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS  = (1 << 1),                                                                                 
    FFX_UPSCALE_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION = (1 << 2),                                                                                           
    FFX_UPSCALE_ENABLE_DEPTH_INVERTED                     = (1 << 3),                                                                                     
    FFX_UPSCALE_ENABLE_DEPTH_INFINITE        = (1 << 4),                                                                                                 
    FFX_UPSCALE_ENABLE_AUTO_EXPOSURE         = (1 << 5),                                                                                    
    FFX_UPSCALE_ENABLE_DYNAMIC_RESOLUTION    = (1 << 6),                                                                             
    FFX_UPSCALE_ENABLE_DEBUG_CHECKING        = (1 << 7),                                                                                        
    FFX_UPSCALE_ENABLE_NON_LINEAR_COLORSPACE = (1 << 8),                                                                                            
};

enum FfxApiDispatchFsrUpscaleFlags
{
    FFX_UPSCALE_FLAG_DRAW_DEBUG_VIEW       = (1 << 0),                                                                                                    
    FFX_UPSCALE_FLAG_NON_LINEAR_COLOR_SRGB = (1 << 1),                                                                                     
    FFX_UPSCALE_FLAG_NON_LINEAR_COLOR_PQ   = (1 << 2),                                                                                   
};

enum FfxApiDispatchUpscaleAutoreactiveFlags
{
    FFX_UPSCALE_AUTOREACTIVEFLAGS_APPLY_TONEMAP        = (1 << 0),
    FFX_UPSCALE_AUTOREACTIVEFLAGS_APPLY_INVERSETONEMAP = (1 << 1),
    FFX_UPSCALE_AUTOREACTIVEFLAGS_APPLY_THRESHOLD      = (1 << 2),
    FFX_UPSCALE_AUTOREACTIVEFLAGS_USE_COMPONENTS_MAX   = (1 << 3),
};

#define FFX_API_EFFECT_ID_UPSCALE 0x00010000u

#define FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE 0x00010000u
struct ffxCreateContextDescUpscale
{
    ffxCreateContextDescHeader header;
    uint32_t                   flags;                                                                                 
    struct FfxApiDimensions2D  maxRenderSize;                                                             
    struct FfxApiDimensions2D  maxUpscaleSize;                                                                                 
    ffxApiMessage              fpMessage;                                                                                            
};

#define FFX_API_DISPATCH_DESC_TYPE_UPSCALE 0x00010001u
struct ffxDispatchDescUpscale
{
    ffxDispatchDescHeader header;
    void*                 commandList;                                                                
    struct FfxApiResource color;                                                                       
    struct FfxApiResource depth;                                                                             
    struct FfxApiResource
                               motionVectors;                                                                                                                                        
    struct FfxApiResource      exposure;                                                                           
    struct FfxApiResource      reactive;                                                                                                   
    struct FfxApiResource      transparencyAndComposition;                                                                                
    struct FfxApiResource      output;                                                                                                  
    struct FfxApiFloatCoords2D jitterOffset;                                                                      
    struct FfxApiFloatCoords2D motionVectorScale;                                                            
    struct FfxApiDimensions2D  renderSize;                                                                                      
    struct FfxApiDimensions2D  upscaleSize;                                                                       
    bool                       enableSharpening;                                                      
    float                      sharpness;                                                                                                                     
    float                      frameTimeDelta;                                                                                  
    float                      preExposure;                                                          
    bool                       reset;                                                                                                                
    float                      cameraNear;                                                                 
    float                      cameraFar;                                                                 
    float                      cameraFovAngleVertical;                                                                                        
    float                      viewSpaceToMetersFactor;                                                             
    uint32_t                   flags;                                                                                            
};

#define FFX_API_QUERY_DESC_TYPE_UPSCALE_GETUPSCALERATIOFROMQUALITYMODE 0x00010002u
struct ffxQueryDescUpscaleGetUpscaleRatioFromQualityMode
{
    ffxQueryDescHeader header;
    uint32_t           qualityMode;                                                       
    float*             pOutUpscaleRatio;                                                                                                   
};

#define FFX_API_QUERY_DESC_TYPE_UPSCALE_GETRENDERRESOLUTIONFROMQUALITYMODE 0x00010003u
struct ffxQueryDescUpscaleGetRenderResolutionFromQualityMode
{
    ffxQueryDescHeader header;
    uint32_t           displayWidth;                                               
    uint32_t           displayHeight;                                               
    uint32_t           qualityMode;                                                       
    uint32_t*          pOutRenderWidth;                                                                                              
    uint32_t*          pOutRenderHeight;                                                                                              
};

#define FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTERPHASECOUNT 0x00010004u
struct ffxQueryDescUpscaleGetJitterPhaseCount
{
    ffxQueryDescHeader header;
    uint32_t           renderWidth;                                    
    uint32_t           displayWidth;                                   
    int32_t*
        pOutPhaseCount;                                                                                                                                                                    
};

#define FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTEROFFSET 0x00010005u
struct ffxQueryDescUpscaleGetJitterOffset
{
    ffxQueryDescHeader header;
    int32_t            index;                                                 
    int32_t            phaseCount;                                                                                        
    float*             pOutX;                                                                                                          
    float*             pOutY;                                                                                                          
};

#define FFX_API_DISPATCH_DESC_TYPE_UPSCALE_GENERATEREACTIVEMASK 0x00010006u
struct ffxDispatchDescUpscaleGenerateReactiveMask
{
    ffxDispatchDescHeader header;
    void*                 commandList;                                                                                     
    struct FfxApiResource
        colorOpaqueOnly;                                                                                                                        
    struct FfxApiResource
                              colorPreUpscale;                                                                                                                               
    struct FfxApiResource     outReactive;                                                                                                 
    struct FfxApiDimensions2D renderSize;                                                                           
    float                     scale;                                            
    float                     cutoffThreshold;                                                           
    float                     binaryValue;                                                      
    uint32_t                  flags;                                                                     
};

#define FFX_API_CONFIGURE_DESC_TYPE_UPSCALE_KEYVALUE 0x00010007u
struct ffxConfigureDescUpscaleKeyValue
{
    ffxConfigureDescHeader header;
    uint64_t               key;                                                                              
    uint64_t               u64;                                          
    void*                  ptr;                                                 
};

enum FfxApiConfigureUpscaleKey
{
    FFX_API_CONFIGURE_UPSCALE_KEY_FVELOCITYFACTOR =
        0                                                                                                                                                                                                                             
};

#define FFX_API_QUERY_DESC_TYPE_UPSCALE_GPU_MEMORY_USAGE 0x00010008u
struct ffxQueryDescUpscaleGetGPUMemoryUsage
{
    ffxQueryDescHeader              header;
    struct FfxApiEffectMemoryUsage* gpuMemoryUsageUpscaler;
};

#ifdef __cplusplus
}
#endif
