// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#ifndef GPU_FFX_FRAMEINTERPOLATION_00_WARP_FLOW_PASS_H
#define GPU_FFX_FRAMEINTERPOLATION_00_WARP_FLOW_PASS_H

#include "ffx_frameinterpolation_callbacks_glsl.h"
#include "nfru_diagnostic_glsl.h"
                                                                                          
#include "warp_flow_common.h"
#include "nfru_angular.h"

                                                                                                            
                                                                               
                                                                            
void NfruWarpVectors(float2 uv, float2 uvSpace, float2 full, float k, out half2 motion, out half2 store)
{
    if (!NfruAngular()) { motion = half2(full); store = half2(full); return; }
    float2 v = NfruToAngle(uv + full) - uvSpace;
    motion = half2((NfruFromAngle(uvSpace + v * k) - uv) / max(k, 1e-4));
    store = half2(v);
}
                                                                                                                 
                                                                                                                
float2 NfruScatterTarget(float2 uv, float2 full, float k, int32_t2 dims)
{
    return (uv + full * k) * float2(dims);
}
void NfruScatterBox(int32_t2 outCoord, uint32_t outData, int32_t2 lo, int32_t2 hi, int32_t2 dims)
{
    for (int32_t oy = lo.y; oy <= hi.y; ++oy)
        for (int32_t ox = lo.x; ox <= hi.x; ++ox)
        {
            if (ox == 0 && oy == 0) continue;
            int32_t2 q = outCoord + int32_t2(ox, oy);
            if (all(greaterThanEqual(q, int32_t2(0))) && all(lessThan(q, dims))) UpdateWarpMotionQDataTp1(FFX_MIN16_I2(q), outData);
        }
}

                                                                                                           
half2 CalculateCameraMotion(float2 uv, float depth, mat4 MotionMat, FFX_PARAMETER_OUT half mask)
{
    float2 uvT    = float2(uv.x, 1.0f - uv.y);
    float4 clip   = float4(2.0f * uvT - 1.0f, depth, 1.0f);
    float4 reproj = MotionMat * clip;
    mask          = half(reproj.w < 0);
    float2 uvProj = ((reproj.xy / reproj.w) + 1.0f) * 0.5f;

    float2 velocity = uvT - uvProj;

    float basically_0_motion = 1e-5f;
    velocity                 = all(lessThan(abs(velocity), float2(basically_0_motion))) ? float2(0.0f) : velocity;
    velocity                 = any(isnan(velocity)) ? float2(0.0f) : velocity;
    velocity                 = any(isinf(velocity)) ? float2(0.0f) : velocity;

    return half2(-velocity.x, velocity.y);
}

FFX_MIN16_F2 sym_ceil(FFX_MIN16_F2 x)
{
    return sign(x) * ceil(abs(x));
}

FFX_MIN16_F2 quantise(FFX_MIN16_F2 x)
{
    const int32_t full_bits = _BITS_X + _BITS_Y;
    const int32_t max_int   = (1 << full_bits) - 1;
    FFX_MIN16_F   c         = FFX_MIN16_F(max_int) / FFX_MIN16_F(_MAX_VAL);
    int32_t2      q         = int32_t2(clamp(sym_ceil(x * c), FFX_MIN16_F(-_MAX_VAL), FFX_MIN16_F(_MAX_VAL)));
    return FFX_MIN16_F2(q) / c;
}

FFX_MIN16_F dynamic_mask_v5(FFX_MIN16_F2 a, FFX_MIN16_F2 b, FFX_MIN16_F eps, FFX_MIN16_F tau)
{
    a                   = quantise(a);
    b                   = quantise(b);
    FFX_MIN16_F diff    = length(a - b);
    FFX_MIN16_F max_len = max(max(length(a), length(b)), tau);
    return max_len < tau ? FFX_MIN16_F(0.0) : FFX_MIN16_F(diff >= eps);
}

FFX_MIN16_F dynamic_mask_v4(FFX_MIN16_F2 a, FFX_MIN16_F2 b, FFX_MIN16_F eps, FFX_MIN16_F tau)
{
    FFX_MIN16_F diff  = length(a - b);
    FFX_MIN16_F denom = max(max(length(a), length(b)), tau);
    return FFX_MIN16_F((diff / denom) >= eps);
}

void warp_flow(int32_t2 output_pixel)
{
    int32_t2 renderSize = MvDepthLaneSize();
    if (any(greaterThanEqual(output_pixel, renderSize)))
        return;

    int32_t output_pixel_cont = output_pixel.x + output_pixel.y * renderSize.x;

    float  renderSizeAreaRcp = 1.0 / float(renderSize.x * renderSize.y);
    float2 uv                = (float2(output_pixel.xy) + 0.5f) * MvDepthLaneSizeRcp();
    const float2 uvSpace     = NfruSpace(uv);

                            
                                                                
    FFX_MIN16_F depth_p1 = FFX_MIN16_F(LoadInputDepthTp1(uv));
    const float depthRaw_p1 = LoadInputDepthTp1(uv);
                                                                                      
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_DEPTH
    StoreDepthTm1Next(output_pixel, FfxFloat32(depth_p1));
#endif
                                                                
    half  cm_p1_f30_m1_mask;
    half2 cm_p1_f30_m1 = CalculateCameraMotion(uv, depth_p1, GetMotionTP1ToTM1(), cm_p1_f30_m1_mask);
    depth_p1           = FFX_MIN16_F(InvertAndNormalizeDepth(depth_p1, output_pixel_cont, renderSizeAreaRcp));

                            
    half2 mv_p1_f30_m1 = LoadInputMotionTp1(uv);
    NfruDiagAdd(0u);

                                       
    int32_t2 outCoord;
    uint32_t outData;
    half2 warpMotion, warpStore;
    NfruWarpVectors(uv, uvSpace, float2(mv_p1_f30_m1), 1.0 - Timestep(), warpMotion, warpStore);
                                                                                                                     
                                                                                                                     
                                          
    bool nfruLocked=false;
    if((cbFI._NfruT2Flags&262144u)!=0u){
        const float cmLen=length(float2(cm_p1_f30_m1)*float2(renderSize)), mvLen=length(float2(mv_p1_f30_m1)*float2(renderSize));
        nfruLocked=cm_p1_f30_m1_mask==half(0.0)&&cmLen>8.0&&mvLen<0.2*cmLen;
    }
    if (!nfruLocked && WarpStore(output_pixel, warpMotion, warpStore, depth_p1, renderSize, FFX_MIN16_F(1.0) - FFX_MIN16_F(Timestep()), FFX_MIN16_F(1.0), outCoord, outData)) {
        NfruDiagAdd(3u);
        {
        UpdateWarpMotionQDataTp1(FFX_MIN16_I2(outCoord), outData);
                                                                              
                                                                            
        if((cbFI._pad0&0x1000u)!=0u){
            const int32_t2 footprint[3]=int32_t2[3](int32_t2(1,0),int32_t2(0,1),int32_t2(1,1));
            for(int k=0;k<3;++k){
                int32_t2 q=outCoord+footprint[k];
                if(all(lessThan(q,renderSize))) UpdateWarpMotionQDataTp1(FFX_MIN16_I2(q),outData);
            }
        }
        if(NfruSplatStretch()){
            float2 h=MvDepthLaneSizeRcp(), uvX=uv+float2(h.x,0.0), uvY=uv+float2(0.0,h.y);
            float k=1.0-Timestep();
            bool okX=uvX.x<1.0&&NfruSameSurface(depthRaw_p1,LoadInputDepthTp1(uvX));
            bool okY=uvY.y<1.0&&NfruSameSurface(depthRaw_p1,LoadInputDepthTp1(uvY));
            int32_t2 lo,hi;
            NfruStretchBox(NfruScatterTarget(uv,float2(mv_p1_f30_m1),k,renderSize),
                           NfruScatterTarget(uvX,float2(LoadInputMotionTp1(uvX)),k,renderSize),
                           NfruScatterTarget(uvY,float2(LoadInputMotionTp1(uvY)),k,renderSize),okX,okY,lo,hi);
            NfruScatterBox(outCoord,outData,lo,hi,renderSize);
        }
    }
    } else NfruDiagAdd(4u);

                                  
                                  
                                  

    const int32_t  iSampleCount = 9;
    FFX_MIN16_F    offset_depth[iSampleCount];
    const int32_t2 offsets[9] = {int32_t2(+0, +0),
                                 int32_t2(+1, +0),
                                 int32_t2(+0, +1),
                                 int32_t2(+0, -1),
                                 int32_t2(-1, +0),
                                 int32_t2(-1, +1),
                                 int32_t2(+1, +1),
                                 int32_t2(-1, -1),
                                 int32_t2(+1, -1)};

                                                         
    offset_depth[0] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[0]).r);
    offset_depth[1] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[1]).r);
    offset_depth[2] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[2]).r);
    offset_depth[3] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[3]).r);
    offset_depth[4] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[4]).r);
    offset_depth[5] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[5]).r);
    offset_depth[6] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[6]).r);
    offset_depth[7] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[7]).r);
    offset_depth[8] = FFX_MIN16_F(LoadInputDepthTp1WithOffset(uv, offsets[8]).r);

                         
    int32_t     nearest_offset_index = 0;
    FFX_MIN16_F nearest_depth        = offset_depth[nearest_offset_index];
#pragma unroll
    for (int32_t iSampleIndex = 1; iSampleIndex < iSampleCount; ++iSampleIndex)
    {
        FFX_MIN16_F tap = offset_depth[iSampleIndex];
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
        if (tap > nearest_depth)
        {
#else
        if (tap < nearest_depth)
        {
#endif
            nearest_depth        = tap;
            nearest_offset_index = iSampleIndex;
        }
    }

    FFX_MIN16_F2 nearest_motion = LoadInputMotionTP1WithOffset(uv, offsets[nearest_offset_index]);
    {
        half2 holeMotion, holeStore;
        NfruWarpVectors(uv, uvSpace, float2(nearest_motion), 1.0 - Timestep(), holeMotion, holeStore);
        StoreHolesTp1(output_pixel, holeMotion);
    }
    StoreHolesTm1(output_pixel, nearest_motion);

                                      
                                      
                                      

                                                                                        
    FFX_MIN16_F depth_m1 = FFX_MIN16_F(LoadInputDepthTm1(uv));

                                                               
    half         cm_m1_f30_p1_mask;
    FFX_MIN16_F2 cm_m1_f30_p1 = CalculateCameraMotion(uv, depth_m1, GetMotionTM1ToTP1(), cm_m1_f30_p1_mask);

                                                                      
                          
                                   
    uint8_t dynamic_mask_m1 = uint8_t(LoadDynamicMaskTm1(output_pixel));
    uint8_t dynamic_mask_p1 = uint8_t(
#if NEW_DYNAMIC_MASK
        dynamic_mask_v5(
            cm_p1_f30_m1 * FFX_MIN16_F2(renderSize), mv_p1_f30_m1 * FFX_MIN16_F2(renderSize), MvSimilarityThreshold(), MvSimilarityNoiseThreshold()) >
        FFX_MIN16_F(0.0)
#else
        dynamic_mask_v4(cm_p1_f30_m1, mv_p1_f30_m1, MvSimilarityThreshold(), MvSimilarityNoiseThreshold()) > FFX_MIN16_F(0.0)
#endif
    );

                                                           
    {
                                                                                                                       
                                                                          
        float2 cmPx=float2(cm_p1_f30_m1)*float2(renderSize), mvPx=float2(mv_p1_f30_m1)*float2(renderSize);
        float cmLen=length(cmPx), mvLen=length(mvPx);
        if(mvLen>4.0)NfruDiagAdd(18u);
        if((cbFI._pad0&0x800u)!=0u&&dynamic_mask_p1!=uint8_t(0)&&length(cmPx-mvPx)<0.08*max(cmLen,mvLen))
            dynamic_mask_p1=uint8_t(0);
                                                                                                                         
                                                                                                              
                                                                                                  
        if((cbFI._NfruT2Flags&2048u)!=0u&&length(cmPx-mvPx)>2.0)
            dynamic_mask_p1=uint8_t(1);
        if((cbFI._NfruT2Flags&4096u)!=0u)dynamic_mask_p1=uint8_t(1);                                    
    }
    StoreDynamicMaskTp1(output_pixel, dynamic_mask_p1 + uint8_t(cm_p1_f30_m1_mask));
                                                                                                    
    if(dynamic_mask_p1!=uint8_t(0))NfruDiagAdd(15u);
    if(cm_p1_f30_m1_mask>half(0.0))NfruDiagAdd(16u);

                                                                                       
    if ((cbFI._NfruT2Flags & 512u) != 0u) return;
                                                                                                    
    if ((cbFI._NfruT2Flags & 1024u) != 0u && NormalizeDepth(float(depth_m1)) < 0.3) return;
                               
    if (dynamic_mask_m1 + uint8_t(cm_m1_f30_p1_mask) > 0)
    {
        NfruDiagAdd(17u);
        return;
    }

                                        
    depth_m1 = FFX_MIN16_F(InvertAndNormalizeDepth(depth_m1, output_pixel_cont, renderSizeAreaRcp));

                                       
    NfruWarpVectors(uv, uvSpace, float2(cm_m1_f30_p1), Timestep(), warpMotion, warpStore);
    if (WarpStore(output_pixel, warpMotion, warpStore, depth_m1, renderSize, FFX_MIN16_F(Timestep()), FFX_MIN16_F(-1.0f), outCoord, outData))
        {
        UpdateWarpMotionQDataTp1(FFX_MIN16_I2(outCoord), outData);
                                                                              
                                                                            
        if((cbFI._pad0&0x1000u)!=0u){
            const int32_t2 footprint[3]=int32_t2[3](int32_t2(1,0),int32_t2(0,1),int32_t2(1,1));
            for(int k=0;k<3;++k){
                int32_t2 q=outCoord+footprint[k];
                if(all(lessThan(q,renderSize))) UpdateWarpMotionQDataTp1(FFX_MIN16_I2(q),outData);
            }
        }
        if(NfruSplatStretch()){
            float2 h=MvDepthLaneSizeRcp(), uvX=uv+float2(h.x,0.0), uvY=uv+float2(0.0,h.y);
            float dRaw=LoadInputDepthTm1(uv), dX=LoadInputDepthTm1(uvX), dY=LoadInputDepthTm1(uvY);
            half maskX, maskY;
            float2 cmX=float2(CalculateCameraMotion(uvX, dX, GetMotionTM1ToTP1(), maskX));
            float2 cmY=float2(CalculateCameraMotion(uvY, dY, GetMotionTM1ToTP1(), maskY));
            bool okX=uvX.x<1.0&&maskX==half(0.0)&&NfruSameSurface(dRaw,dX);
            bool okY=uvY.y<1.0&&maskY==half(0.0)&&NfruSameSurface(dRaw,dY);
            int32_t2 lo,hi;
            NfruStretchBox(NfruScatterTarget(uv,float2(cm_m1_f30_p1),Timestep(),renderSize),
                           NfruScatterTarget(uvX,cmX,Timestep(),renderSize),
                           NfruScatterTarget(uvY,cmY,Timestep(),renderSize),okX,okY,lo,hi);
            NfruScatterBox(outCoord,outData,lo,hi,renderSize);
        }
    }
}

#endif