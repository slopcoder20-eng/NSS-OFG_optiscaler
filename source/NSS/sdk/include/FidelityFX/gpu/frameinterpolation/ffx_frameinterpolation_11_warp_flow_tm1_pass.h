// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#ifndef GPU_FFX_FRAMEINTERPOLATION_01_WARP_FLOW_TM1_PASS_H
#define GPU_FFX_FRAMEINTERPOLATION_01_WARP_FLOW_TM1_PASS_H

#include "ffx_frameinterpolation_callbacks_glsl.h"
                                                                                          
#include "warp_flow_common.h"
#include "nfru_angular.h"

                                                                                                                   
                                        
float2 NfruFlowTarget(float2 uv, float2 flow, int32_t2 dims)
{
    return (uv + flow * Timestep()) * float2(dims);
}

void warp_flow_tm1(int32_t2 output_pixel)
{
    int32_t2 ofRes     = FlowLaneSize();
    float2   ofInvSize = FlowLaneSizeRcp();
    float    ofInvArea = ofInvSize.x * ofInvSize.y;
    if (any(greaterThanEqual(output_pixel, ofRes)))
        return;

    int32_t output_pixel_cont = output_pixel.x + output_pixel.y * ofRes.x;

    float2 uv = (float2(output_pixel.xy) + 0.5f) * float2(1.0 / ofRes.x, 1.0 / ofRes.y);

                            
    FFX_MIN16_F depth_m1 = FFX_MIN16_F(LoadInputDepthTm1(uv));

                                    
    depth_m1 = FFX_MIN16_F(InvertAndNormalizeDepth(depth_m1, output_pixel_cont, ofInvArea));

                        
    half2 flow_m1_f30_p1 = LoadInputFlowTm1(uv);

                                       
    int32_t2 outCoord;
    uint32_t outData;
                                                                                      
    half2 warpMotion = flow_m1_f30_p1, warpStore = flow_m1_f30_p1;
    if (NfruAngular()) {
        float2 v = NfruVec(uv, uv + float2(flow_m1_f30_p1));
        warpMotion = half2((NfruMove(uv, v, Timestep()) - uv) / max(Timestep(), 1e-4));
        warpStore = half2(v);
    }
    if (WarpStore(output_pixel, warpMotion, warpStore, depth_m1, ofRes, FFX_MIN16_F(Timestep()), FFX_MIN16_F(1.0), outCoord, outData))
        {
        UpdateWarpFlowQDataTm1(FFX_MIN16_I2(outCoord), outData);
                                                                              
                                                                            
        if((cbFI._pad0&0x2000u)!=0u){
            const int32_t2 footprint[3]=int32_t2[3](int32_t2(1,0),int32_t2(0,1),int32_t2(1,1));
                                                                                         
            float2 fractional=fract(float2(warpMotion*half2(ofRes)*half(Timestep())));
            bool fractionalFootprint=(cbFI._pad0&0x4000u)!=0u;
            for(int k=0;k<3;++k){
                if(fractionalFootprint&&((footprint[k].x!=0&&fractional.x<=0.001)||(footprint[k].y!=0&&fractional.y<=0.001)))continue;
                int32_t2 q=outCoord+footprint[k];
                if(all(lessThan(q,ofRes))) UpdateWarpFlowQDataTm1(FFX_MIN16_I2(q),outData);
            }
        }
        if(NfruSplatStretch()){
            float2 uvX=uv+float2(ofInvSize.x,0.0), uvY=uv+float2(0.0,ofInvSize.y);
            float dRaw=LoadInputDepthTm1(uv);
            bool okX=uvX.x<1.0&&NfruSameSurface(dRaw,LoadInputDepthTm1(uvX));
            bool okY=uvY.y<1.0&&NfruSameSurface(dRaw,LoadInputDepthTm1(uvY));
            int32_t2 lo,hi;
            NfruStretchBox(NfruFlowTarget(uv,float2(flow_m1_f30_p1),ofRes),
                           NfruFlowTarget(uvX,float2(LoadInputFlowTm1(uvX)),ofRes),
                           NfruFlowTarget(uvY,float2(LoadInputFlowTm1(uvY)),ofRes),okX,okY,lo,hi);
            for(int32_t oy=lo.y;oy<=hi.y;++oy)
                for(int32_t ox=lo.x;ox<=hi.x;++ox){
                    if(ox==0&&oy==0)continue;
                    int32_t2 q=outCoord+int32_t2(ox,oy);
                    if(all(greaterThanEqual(q,int32_t2(0)))&&all(lessThan(q,ofRes))) UpdateWarpFlowQDataTm1(FFX_MIN16_I2(q),outData);
                }
        }
    }
}

#endif