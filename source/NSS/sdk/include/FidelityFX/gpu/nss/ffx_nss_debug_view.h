/*
 * SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: MIT
 */

#ifndef GPU_NSS_DEBUG_VIEW_H
#define GPU_NSS_DEBUG_VIEW_H

#include "nss/ffx_nss_common_glsl.h"

                                                                
                                            
                                                                

#if !defined(NSS_BIND_SRV_INPUT_DEPTH) || !defined(NSS_BIND_SRV_INPUT_MOTION_VECTORS) || !defined(NSS_BIND_SRV_HISTORY_UPSCALED_COLOR) || \
    !defined(NSS_BIND_SRV_INPUT_DEPTH_TM1) || !defined(NSS_BIND_SRV_LUMA_DERIV_TM1) || !defined(NSS_BIND_SRV_INPUT_COLOR_JITTERED)
#error "Debug view requires input depth, motion vectors, history color, prev depth, prev luma deriv, and input colour SRVs to be bound."
#endif

#if !defined(NSS_BIND_PREPROCESS_INPUT_TENSOR)
#error "Debug view tensor visualisation requires preprocess input tensor to be bound."
#endif

#if defined(NSS_BIND_SRV_NEAREST_DEPTH_COORD)
layout(set = 0, binding = NSS_BIND_SRV_NEAREST_DEPTH_COORD) uniform highp texture2D r_input_nearest_depth_coord;
#define _NearestDepthCoordTex sampler2D(r_input_nearest_depth_coord, s_LinearClamp)
#endif

                                                                                          
#if defined(NSS_BIND_SRV_LUMA_DERIV)
layout(set = 0, binding = NSS_BIND_SRV_LUMA_DERIV) uniform lowp texture2D r_luma_deriv;
#define _LumaDerivTex sampler2D(r_luma_deriv, s_LinearClamp)
#endif

                                                                          
#include "nss/ffx_nss_preprocess.h"

                                                                
                                                 
                                                                                          
                                                                                             
                                                                                          
                                                                                          
                                                                
#define NSS_DEBUG_VIEW_COLS 4
#define NSS_DEBUG_VIEW_ROWS 4

                                                                              
                         
                                                          
                                                       
                                                             
                                                                 
                                                                              
struct PreprocessTensorInputs
{
    half3 history;
    half3 colour;
    half  motion_detector;
    half4 feedback;
    half  luma_derivative;
};

PreprocessTensorInputs ReadPreprocessTensorInputs(int32_t2 process_coord)
{
    PreprocessTensorInputs inputs;
                                                                                       
    ReadFromTensor(process_coord, inputs.history, inputs.colour, inputs.motion_detector, inputs.feedback, inputs.luma_derivative);
    return inputs;
}

                                                                                        
                                                                                                                 
                                                                                       
                                                       
float3 VisualiseTensorRgb(half3 v)
{
    return float3(v);
}

float3 VisualiseTensorScalar(half v)
{
    return float3(float(v));
}

                                                                   
float3 VisualiseDepth(float d)
{
    float linearized = sqrt(clamp(d, 0.0, 1.0));
    return float3(linearized);
}

                                              
float3 VisualiseRG(float2 rg)
{
    return float3(clamp(rg, float2(0.0), float2(1.0)), 0.0);
}

                                                 
float3 VisualiseSnorm4(float4 v)
{
    return v.rgb * 0.5 + 0.5;
}

                                                                        
float3 VisualiseMotion(float2 mv)
{
    return float3(mv * 0.5 + 0.5, 0.0);
}

                                                                              
                                                                                                         
                                                                             
                                                         
                                                                              
void ComputeDisocclusionMask(int32_t2 process_coord, int32_t2 ref_coord, out float out_depth_dilated, out half disocclusion_mask)
{
    float2 uv          = (float2(ref_coord) + float2(0.5)) * InvInputDims();
    float2 uv_pad      = (float2(process_coord) + float2(0.5)) * InvPaddedDims();
    float2 unjitter_uv = uv - (JitterOffset().xy * InvInputDims());

    float    depth_dilated  = 0.0;
    int32_t2 nearest_offset = int32_t2(0);
    FindNearestDepth_4x4(uv, depth_dilated, nearest_offset);

    int32_t2 nearest_input_coord = clamp(ref_coord + nearest_offset, int32_t2(0), InputDims() - int32_t2(1));
    float2   motion              = LoadMotion(nearest_input_coord);

    float2   reproj_uv      = uv + (motion * InvInputDims());
    int32_t2 depth_coord    = InputCoordToDepthCoord(ref_coord);
    float2   reproj_270p_uv = ((float2(depth_coord) + float2(0.5)) * InvDepthTm1Size()) + (motion * InvInputDims());
    float2   reproj_pad_uv  = uv_pad + MotionToPaddedUvDelta(motion);

#if NSS_PREPROCESS_HALF_RES_INPUT && defined(NSS_BIND_SRV_DISOCCLUSION_MASK_LQ)
    int32_t2 process_dims    = GetProcessDims();
    float2   disocclusion_uv = (float2(process_coord) + float2(0.5)) * rcp(float2(process_dims));
    disocclusion_mask        = half(textureLod(_DisocclusionMaskLQTex, disocclusion_uv, 0.0).r);
#else
    disocclusion_mask = half(ComputeDepthClipInt(reproj_270p_uv, depth_dilated, RenderSize(), DeviceToViewDepth()));
#endif

    out_depth_dilated = depth_dilated;
}

int32_t2 TileUvToTexelPos(float2 tileUV, int32_t2 textureSizeXY)
{
    int32_t2 texelPos = int32_t2(tileUV * float2(textureSizeXY));
    return clamp(texelPos, int32_t2(0), textureSizeXY - int32_t2(1));
}

float4 SampleDebugTile(int32_t tileX, int32_t tileY, float2 tileUV)
{
    int32_t2               debugOutputDims = GetDebugViewDimensions();
    int32_t2               inputPos        = int32_t2(tileUV * float2(InputDims()));
    int32_t2               outputPos       = int32_t2(tileUV * float2(debugOutputDims));
    int32_t2               processCoord    = TileUvToTexelPos(tileUV, GetProcessDims());
    PreprocessTensorInputs tensorInputs    = ReadPreprocessTensorInputs(processCoord);

    inputPos  = clamp(inputPos, int32_t2(0), InputDims() - int32_t2(1));
    outputPos = clamp(outputPos, int32_t2(0), debugOutputDims - int32_t2(1));

    float3 rgb = float3(0.0);

    if (tileY == 0)
    {
        if (tileX == 0)
        {
                                                                                      
            rgb = texelFetch(sampler2D(r_prev_upscaled_color, s_LinearClamp), outputPos, 0).rgb;
        }
        else if (tileX == 1)
        {
                                              
            float d = texelFetch(sampler2D(r_input_depth, s_PointClamp), inputPos, 0).r;
            rgb     = VisualiseDepth(d);
        }
        else if (tileX == 2)
        {
                                                                                  
            int32_t2 depthTm1Pos = TileUvToTexelPos(tileUV, int32_t2(textureSize(r_prev_depth, 0)));
            uint     rawDepth    = texelFetch(_DepthTm1Tex, depthTm1Pos, 0).r;
            float    d           = uintBitsToFloat(rawDepth);
            rgb                  = VisualiseDepth(d);
        }
        else               
        {
                                                                                         
            int32_t2 nearestDepthPos = TileUvToTexelPos(tileUV, int32_t2(textureSize(r_input_nearest_depth_coord, 0)));
            float    v               = texelFetch(_NearestDepthCoordTex, nearestDepthPos, 0).r;
            rgb                      = float3(v);
        }
    }
    else if (tileY == 1)
    {
        if (tileX == 0)
        {
                                                                 
            rgb = texelFetch(sampler2D(r_input_color_jittered, s_LinearClamp), inputPos, 0).rgb;
        }
        else if (tileX == 1)
        {
                                                                        
            float2 mv = texelFetch(sampler2D(r_input_motion_vectors, s_LinearClamp), inputPos, 0).rg;
            rgb       = VisualiseMotion(mv);
        }
        else if (tileX == 2)
        {
                                                                                              
            int32_t2 lumaDerivPos = TileUvToTexelPos(tileUV, int32_t2(textureSize(r_prev_luma_deriv, 0)));
            float4   ld           = texelFetch(_LumaDerivTm1Tex, lumaDerivPos, 0);
            rgb                   = VisualiseSnorm4(ld);
        }
        else               
        {
                                                                                  
            int32_t2 feedbackPos = TileUvToTexelPos(tileUV, int32_t2(textureSize(r_temporal_feedback_tensor, 0)));
            float4   fb          = texelFetch(_FeedbackTensor, feedbackPos, 0);
            rgb                  = VisualiseSnorm4(fb);
        }
    }
    else if (tileY == 2)
    {
                                                                           
        int32_t2 preprocessRefCoord = ProcessCoordToInputCoord(processCoord);

        half  disocclusion_mask;
        float depth_dilated;
        ComputeDisocclusionMask(processCoord, preprocessRefCoord, depth_dilated, disocclusion_mask);

        if (tileX == 0)
        {
                                                                                     
            rgb = VisualiseTensorRgb(tensorInputs.history);
        }
        else if (tileX == 1)
        {
            rgb = float3(disocclusion_mask);
        }
        else if (tileX == 2)
        {
                                                                                                 
                                                                              
#if defined(NSS_BIND_SRV_LUMA_DERIV)
            int32_t2 lumaDerivPos = TileUvToTexelPos(tileUV, int32_t2(textureSize(r_luma_deriv, 0)));
            float4   ld           = texelFetch(_LumaDerivTex, lumaDerivPos, 0);
            rgb                   = VisualiseSnorm4(ld);
#endif
        }
        else               
        {
                                                                                            
            rgb = float3(depth_dilated, 0.0, 0.0);
        }
    }
    else                                                                                        
    {
        if (tileX == 0)
        {
                                                                              
            rgb = VisualiseTensorRgb(tensorInputs.colour);
        }
        else if (tileX == 1)
        {
                                                                                    
            rgb = VisualiseTensorScalar(tensorInputs.motion_detector);
        }
        else if (tileX == 2)
        {
                                                                                       
            rgb = VisualiseTensorScalar(tensorInputs.luma_derivative);
        }
        else               
        {
                                                                                                   
            rgb = VisualiseTensorRgb(tensorInputs.feedback.rgb);
        }
    }

    return float4(rgb, 1.0);
}

                                                                
                                                                              
                                                                
void DebugView(int32_t2 pxPos)
{
    int32_t2 debugDims = GetDebugViewDimensions();

    float4 colour;

    if (DebugViewMode() != NSS_DEBUG_VIEW_MODE_ALL)
    {
                                                                             
        int32_t tileX  = int32_t((DebugViewMode() - 1u) % uint(NSS_DEBUG_VIEW_COLS));
        int32_t tileY  = int32_t((DebugViewMode() - 1u) / uint(NSS_DEBUG_VIEW_COLS));
        float2  tileUV = (float2(pxPos) + float2(0.5)) / float2(debugDims);
        colour         = SampleDebugTile(tileX, tileY, tileUV);
    }
    else
    {
        int32_t tileW = debugDims.x / NSS_DEBUG_VIEW_COLS;
        int32_t tileH = debugDims.y / NSS_DEBUG_VIEW_ROWS;

        int32_t tileX  = pxPos.x / tileW;
        int32_t tileY  = pxPos.y / tileH;
        int32_t localX = pxPos.x - tileX * tileW;
        int32_t localY = pxPos.y - tileY * tileH;

        tileX = clamp(tileX, 0, NSS_DEBUG_VIEW_COLS - 1);
        tileY = clamp(tileY, 0, NSS_DEBUG_VIEW_ROWS - 1);

        float2 tileUV = (float2(localX, localY) + float2(0.5)) / float2(tileW, tileH);
        colour        = SampleDebugTile(tileX, tileY, tileUV);
    }

    StoreDebugView(pxPos, colour);
}

                                                                
                                            
                                                                
void DebugViewCS(int32_t2 outPos)
{
    int32_t2 debugDims = GetDebugViewDimensions();
    if (!IsOnScreen(outPos, debugDims))
        return;
    DebugView(outPos);
}

                                                                
                                             
                                                                
void DebugViewFS(int32_t2 fragPos)
{
    DebugView(fragPos);
}

#endif                         
