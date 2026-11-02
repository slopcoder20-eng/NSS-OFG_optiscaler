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

#include <FidelityFX/gpu/frameinterpolation/ffx_frameinterpolation_resources.h>
#include <FidelityFX/host/ffx_types.h>

                                                                                    
   
                                                                    
                                                                    
                                                                            
                                       
   
                               
typedef enum FfxFrameInterpolationShaderPermutationOptions
{
    FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS  = (1 << 0),
    FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS   = (1 << 1),
    FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED          = (1 << 2),                                                                    
    FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64            = (1 << 3),                                                        
    FRAMEINTERPOLATION_SHADER_PERMUTATION_ALLOW_FP16              = (1 << 4),                                                     
    FRAMEINTERPOLATION_SHADER_PERMUTATION_ENABLE_DATA_GRAPH_FI    = (1 << 5),                                                                             
    FRAMEINTERPOLATION_SHADER_PERMUTATION_WARP_FRAGMENT           = (1 << 6),                                                               
    FRAMEINTERPOLATION_SHADER_PERMUTATION_FILL_HOLES_FRAGMENT     = (1 << 7),                                                             
    FRAMEINTERPOLATION_SHADER_PERMUTATION_PRE_PROCESS_FRAGMENT    = (1 << 8),                                                        
    FRAMEINTERPOLATION_SHADER_PERMUTATION_POSTPROCESS_FRAGMENT    = (1 << 9),                                          
    FRAMEINTERPOLATION_SHADER_PERMUTATION_DEBUG_VIEW_FRAGMENT     = (1 << 11),                                        
    FRAMEINTERPOLATION_SHADER_PERMUTATION_COMPUTE_SUPPORT_TENSOR  = (1 << 12),                                                                
    FRAMEINTERPOLATION_SHADER_PERMUTATION_FRAGMENT_SUPPORT_TENSOR = (1 << 13),                                                                 
    FRAMEINTERPOLATION_SHADER_PERMUTATION_MANAGE_PREVIOUS_DEPTH   = (1 << 14),                                                              
    FRAMEINTERPOLATION_SHADER_PERMUTATION_MANAGE_PREVIOUS_COLOR   = (1 << 15),                                                              
} FfxInterpolationShaderPermutationOptions;

struct FfxPipelineState;
struct FfxResource;

typedef struct FfxMlof2Constants
{
    uint64_t frameID;
    uint32_t mfg;
    uint32_t hasCam;
    uint32_t hasCamP;
    uint32_t depthInverted;                                                                                         
    float vp_p[16];
    float vp_a[16];
    float vp_b[16];
    float inv_vp_a[16];
} FfxMlof2Constants;

typedef struct FrameInterpolationConstants
{
    FfxFloat32x4x4 _MotionTM1ToTP1;
    FfxFloat32x4x4 _MotionTP1ToTM1;

    FfxFloat32x4 _QuantParamsSINT;                                                                                     
    FfxFloat32x4 _QuantParamsSNORM;                                                                                     

    float _DeviceToViewDepth[4];

    int32_t _RenderSize[2];
    int32_t _DisplaySize[2];
    int32_t _OfSize[2];

    float _RenderSizeRcp[2];
    float _DisplaySizeRcp[2];
    float _OfSizeRcp[2];

    float _Jitter[2];
    float _MotionVectorScale[2];
    float _MvSimilarityThresholds[2];                                                            

    int32_t  _InputTensorSize[2];
    float    _InputTensorSizeRcp[2];
    int      _Reset;
    float    _Timestep;
    uint32_t _RandomSeed;
    uint32_t _pad0;                                       

    int32_t _MvDepthLaneSize[2];
    float   _MvDepthLaneSizeRcp[2];
    int32_t _FlowLaneSize[2];
    float   _FlowLaneSizeRcp[2];
    float   _OfGridSizeRcp;                                                                             
    float   _padT2;                                                                               
    FfxFloat32x4x4 _MotionTM1ToTM2;                                                        
    uint32_t _NfruT2Flags;                                                         
    uint32_t _padT2b[3];
} FrameInterpolationConstants;

typedef struct FrameInterpolationRenderDescription
{
    FfxDimensions2D renderSize;
    FfxDimensions2D upscaleSize;

    float cameraNear;
    float cameraFar;
    float cameraFovAngleVertical;
    float viewSpaceToMetersFactor;

    FfxFloatCoords2D motionVectorScale;                                                   
} FrameInterpolationRenderDescription;

                         
                                                  
typedef struct FfxArmFrameInterpolationContext_Private
{
    FfxFrameInterpolationContextDescription contextDescription;
    FfxUInt32                               effectContextId;
    FrameInterpolationRenderDescription     renderDescription;
    FrameInterpolationConstants             constants;
    FfxDevice                               device;

                                                                        
    FfxDimensions2D ofInputColour;                                                                 
    FfxDimensions2D mvDepthLane;                                                                  
    FfxDimensions2D flowLane;                                                              
    FfxDimensions2D tensorLane;                                                                     
    bool            requiresColourDownsample;                                        

                                   
    FfxPipelineState pipelineDebugView;
    FfxPipelineState pipelineMlof2;
    bool             isMlof2;                                                    
    bool             mlof2ConvertHistory;                                                                  

                           
    FfxPipelineState pipelineDownsampleOfColour;                                                                           
    FfxPipelineState pipelineInitWarp;
    FfxPipelineState pipelineWarpFlow;
    FfxPipelineState pipelineWarpFlowTM1;
    FfxPipelineState pipelineFillHoles;
    FfxPipelineState pipelineFillHolesTM1;
    FfxPipelineState pipelinePreprocess;
    FfxPipelineState pipelineNFRUInterpolation;
    FfxPipelineState pipelinePostprocess;

    FfxConstantBuffer constantBuffers[FFX_FRAMEINTERPOLATION_CONSTANTBUFFER_COUNT];

                                                                                                                                                  
    FfxResourceInternal srvResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT];
    FfxResourceInternal uavResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT];

    uint64_t lastStatsSampleMs;
    bool firstExecution;
    bool refreshPipelineStates;

    FfxDataGraphTensorInfo dataGraphTensorInfo[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT];
    uint32_t               dataGraphTensorInfoCount;

    uint32_t pipelineFlags;
    uint32_t dataGraphWidth;
    uint32_t dataGraphHeight;

    uint64_t       previousFrameID;
    uint64_t       dispatchCount;
    FfxFloat32x4x4 lastFrameViewProjection;
    uint64_t lastPreparedFrameID;
    bool motionMatricesPrepared;

                      
    FfxFloat32x4x4 secondLastFrameViewProjection;
    bool     secondLastViewProjectionValid;
    uint32_t t2Frames;                                     
    bool     t2ColourCopyable;                                                                 
    bool     t2DepthCopyable;

                  
    uint32_t          mfg;
    bool              mlof2_has_cam;
    bool              mlof2_has_cam_p;
    FfxFloat32x4x4    mlof2_vp_p;
    FfxFloat32x4x4    mlof2_vp_a;
    FfxFloat32x4x4    mlof2_vp_b;
    FfxFloat32x4x4    mlof2_inv_vp_a;
    FfxMlof2Constants mlof2Constants;

    bool enableDataGraphFI = true;
} FfxArmFrameInterpolationContext_Private;
