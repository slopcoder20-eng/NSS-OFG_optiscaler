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
// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#pragma once
#include "FidelityFX/gpu/nss/ffx_nss_resources.h"

enum NssScalePresetMode
{
    NSS_SCALE_PRESET_NONE = 0,
    NSS_SCALE_PRESET_X2,
    NSS_SCALE_PRESET_COUNT,
};

                                                                                           
                                                                                                                      
static constexpr uint32_t NSS_SHADER_QUALITY_MODE_MASK              = 3;
static constexpr uint32_t NSS_SHADER_PERMUTATION_QUALITY_MODE_SHIFT = 10;

                                                                                   
   
                                                                   
                                                                    
                                                                            
                                       
   
                   
typedef enum NssShaderPermutationOptions : uint32_t
{
    NSS_SHADER_PERMUTATION_QUANTIZED             = (1 << 0),
    NSS_SHADER_PERMUTATION_REVERSE_Z             = (1 << 1),
    NSS_SHADER_PERMUTATION_RESAMPLE_BICUBIC      = (1 << 2),
    NSS_SHADER_PERMUTATION_STATIC                = (1 << 3),
    NSS_SHADER_PERMUTATION_ALLOW_16BIT           = (1 << 4),
    NSS_SHADER_PERMUTATION_SCALE_PRESET_X2       = (1 << 5),
    NSS_SHADER_PERMUTATION_MANAGE_HISTORY        = (1 << 7),
    NSS_SHADER_PERMUTATION_PRE_PROCESS_FRAGMENT  = (1 << 8),
    NSS_SHADER_PERMUTATION_POST_PROCESS_FRAGMENT = (1 << 9),
                                                  
    NSS_SHADER_PERMUTATION_QUALITY_MODE_MASK       = (NSS_SHADER_QUALITY_MODE_MASK << NSS_SHADER_PERMUTATION_QUALITY_MODE_SHIFT),
    NSS_SHADER_PERMUTATION_COMPUTE_SUPPORT_TENSOR  = (1 << 12),
    NSS_SHADER_PERMUTATION_FRAGMENT_SUPPORT_TENSOR = (1 << 13),
} NssShaderPermutationOptions;

                                                         
                                                                                
                                                                                   
                                                                   
typedef enum NssDebugViewMode : uint32_t
{
    NSS_DEBUG_VIEW_MODE_ALL                      = 0,                                        
    NSS_DEBUG_VIEW_MODE_HISTORY                  = 1,                                                             
    NSS_DEBUG_VIEW_MODE_DEPTH                    = 2,                                              
    NSS_DEBUG_VIEW_MODE_RECONSTRUCTED_PREV_DEPTH = 3,                                                       
    NSS_DEBUG_VIEW_MODE_NEAREST_OFFSET           = 4,                                         
    NSS_DEBUG_VIEW_MODE_LOW_RES_COLOR            = 5,                                                            
    NSS_DEBUG_VIEW_MODE_MOTION_VECTOR            = 6,                                                   
    NSS_DEBUG_VIEW_MODE_LUMA_DERIV_TM1           = 7,                                                   
    NSS_DEBUG_VIEW_MODE_TEMPORAL_FEEDBACK        = 8,                                                     
    NSS_DEBUG_VIEW_MODE_LR_WARPED_HISTORY        = 9,                                                                
    NSS_DEBUG_VIEW_MODE_DISOCCLUSION_MASK        = 10,                                     
    NSS_DEBUG_VIEW_MODE_LUMA_DERIV_T             = 11,                                                       
    NSS_DEBUG_VIEW_MODE_DEPTH_DILATED            = 12,                                                                             
    NSS_DEBUG_VIEW_MODE_TENSOR_COLOR             = 13,                                                            
    NSS_DEBUG_VIEW_MODE_TENSOR_MOTION_DETECTOR   = 14,                                                          
    NSS_DEBUG_VIEW_MODE_TENSOR_LUMA_INSTABILITY  = 15,                                                                      
    NSS_DEBUG_VIEW_MODE_TENSOR_WARP_FEEDBACK     = 16,                                                              
} NssDebugViewMode;

                                 
   
                                                                           
                                    
   
                   
typedef struct NssConstants
{
    FfxFloat32x4 _DeviceToViewDepth;
    FfxFloat32x4 _JitterOffset;                                                                 
    FfxFloat32x4 _JitterOffsetTm1;                                                           
    FfxFloat32x4 _ScaleFactor;                                                            

    FfxUInt32x2 _OutputDims;                                                
    FfxUInt32x2 _InputDims;                                                 

    FfxFloat32x2 _InvOutputDims;                                                        
    FfxFloat32x2 _InvInputDims;                                                         

    FfxUInt32x2  _DepthTm1Size;                            
    FfxFloat32x2 _InvDepthTm1Size;                                    

    FfxUInt32x2  _InputTensorSize;                                               
    FfxFloat32x2 _InputTensorSizeRcp;                                    

    FfxUInt32x2  _KpnDimension;                                                 
    FfxFloat32x2 _MotionVectorScale;                                                             

    FfxFloat32x2 _PaddingScale;                                 
    FfxFloat32   _DepthClipRequiredSepScale;
    FfxFloat32   _DepthClipPower;

    FfxFloat32x2 _KpnScale;                                                                               
    FfxUInt32    _DebugViewMode;                                                                                              
    FfxFloat32   _NotHistoryReset;                                                          

    FfxFloat32x2 _Exposure;                                              
    FfxUInt32x2  _IndexModulo;                                                                             

    FfxUInt32x2 _ReducedInputModulo;                                                                                 
    FfxUInt32x2 _LutOffset;                                                                                    
    FfxInt32x2 _ColourTransfer;
    FfxFloat32 _ColourReferenceNits;
    FfxFloat32 _ColourPadding;
} NssConstants;

struct FfxPipelineState;

                         
                                                  
   
                   
typedef struct FfxNssContext_Private
{
    FfxNssContextDescription contextDescription;                                                  
    FfxUInt32                effectContextId;
    NssConstants             constants;                                                                                  
    FfxDevice                device;
    FfxPipelineState         pipelineNssDepthScatter;                                                                                 
    FfxPipelineState         pipelineNssDisocclusionMask;                                                                                 
    FfxPipelineState         pipelineNssPreprocess;                                                                                
    FfxPipelineState         pipelineNssDataGraph;                                                                                 
    FfxPipelineState         pipelineNssGenerateOffsetLut;                                                                                            
    FfxPipelineState         pipelineNssPostprocess;                                                                                
    FfxPipelineState         pipelineNssDebugView;                                                                                 
    FfxConstantBuffer        constantBuffers[FFX_NSS_CONSTANTBUFFER_COUNT];                                                                       
    FfxResourceInternal      srvResources[FFX_NSS_RESOURCE_IDENTIFIER_COUNT];                          
    FfxResourceInternal      uavResources[FFX_NSS_RESOURCE_IDENTIFIER_COUNT];                          
    FfxConstantBuffer        rootConstant;

    bool            firstExecution;
    uint32_t        resourceFrameIndex;
    uint32_t        pipelineFlags;
    FfxDimensions2D depthScatterSize;
    FfxDimensions2D processSize;
    FfxDimensions2D dataGraphSize;
    FfxDimensions2D kpnDimension;
    FfxDimensions2D offsetLutSize;
    FfxDimensions2D reducedFractionLrSize;
    FfxDimensions2D reducedFractionHrSize;
    bool            useDynamicOffsetLut;
    bool            useDisocclusionMaskPass;
} FfxNssContext_Private;
