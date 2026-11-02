/*
 * SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: MIT
 */

#include "quant.h"

#ifndef FILL_HOLES_COMMON
#define FILL_HOLES_COMMON

  
                                  
                                                
     
                                                  
     
                                                   
     
                                               
     
                                                                 
     
                    
     
  
FfxFloat32x2 nfruWalkAvgMotion;
void FillHoles(FfxInt32x2 output_pixel, FfxInt32x2 output_dims, FfxFloat32x2 inv_output_dims)
{
    nfruWalkAvgMotion = FfxFloat32x2(1e30, 1e30);
      
                         
                                                                                                                       
                                                                                        
      
    const FfxInt32 iSampleCount = 9;
    FfxUInt32      depth_mvs_packed[iSampleCount];

                                                         
    depth_mvs_packed[0] = LoadPackedQDepth(output_pixel + FfxInt32x2(0, 0));
    depth_mvs_packed[1] = LoadPackedQDepth(output_pixel + FfxInt32x2(1, 0));
    depth_mvs_packed[2] = LoadPackedQDepth(output_pixel + FfxInt32x2(0, 1));
    depth_mvs_packed[3] = LoadPackedQDepth(output_pixel + FfxInt32x2(0, -1));
    depth_mvs_packed[4] = LoadPackedQDepth(output_pixel + FfxInt32x2(-1, 0));
    depth_mvs_packed[5] = LoadPackedQDepth(output_pixel + FfxInt32x2(-1, 1));
    depth_mvs_packed[6] = LoadPackedQDepth(output_pixel + FfxInt32x2(1, 1));
    depth_mvs_packed[7] = LoadPackedQDepth(output_pixel + FfxInt32x2(-1, -1));
    depth_mvs_packed[8] = LoadPackedQDepth(output_pixel + FfxInt32x2(1, -1));

                         
    FfxUInt32 nearest_packed_depth_mv = depth_mvs_packed[0];
#pragma unroll
    for (FfxInt32 iSampleIndex = 1; iSampleIndex < iSampleCount; ++iSampleIndex)
    {
        FfxUInt32 tap = depth_mvs_packed[iSampleIndex];
        if (tap > nearest_packed_depth_mv)
        {
            nearest_packed_depth_mv = tap;
        }
    }

                                                                                                                         
                                                                                                               
                                                                                                                   
                                                                                        
    if (nearest_packed_depth_mv == 0u && (cbFI._pad0 & 0x20000000u) != 0u)
    {
        const FfxInt32x2 dirs[8] = FfxInt32x2[8](FfxInt32x2(1, 0), FfxInt32x2(-1, 0), FfxInt32x2(0, 1), FfxInt32x2(0, -1),
                                                FfxInt32x2(1, 1), FfxInt32x2(-1, 1), FfxInt32x2(1, -1), FfxInt32x2(-1, -1));
                                                                                                                              
                                                                                                                          
                                                                                                                     
        const FfxInt32 radii[12] = FfxInt32[12](2, 4, 7, 11, 16, 24, 36, 54, 80, 120, 180, 384);
        const FfxInt32 nRadii = (cbFI._NfruT2Flags & 1048576u) != 0u ? 12 : 5;
        FfxUInt32 background = 0xffffffffu;
        FfxUInt32 hits[8];
        for (FfxInt32 d = 0; d < 8; ++d)
        {
            hits[d] = 0u;
            for (FfxInt32 r = 0; r < nRadii; ++r)
            {
                FfxInt32x2 q = output_pixel + dirs[d] * radii[r];
                if (any(lessThan(q, FfxInt32x2(0))) || any(greaterThanEqual(q, output_dims))) break;
                FfxUInt32 tap = LoadPackedQDepth(q);
                if (tap != 0u) { background = min(background, tap); hits[d] = tap; break; }
            }
        }
        if (background != 0xffffffffu) { nearest_packed_depth_mv = background; NfruDiagAdd(63u); }
                                                                                                                       
                                                                                                                  
        if (background != 0xffffffffu && (cbFI._NfruT2Flags & 131072u) != 0u)
        {
            const FfxUInt32 band = 2047u * 3u / 110u;                                             
            FfxFloat32x2 sum = FfxFloat32x2(0.0, 0.0);
            FfxFloat32 n = 0.0;
            for (FfxInt32 d = 0; d < 8; ++d)
                if (hits[d] != 0u && ((hits[d] >> 20u) & 2047u) <= ((background >> 20u) & 2047u) + band)
                {
                    sum += dqFloatMv(hits[d]);
                    n += 1.0;
                }
            if (n > 0.0) nfruWalkAvgMotion = sum / n;
        }
    }
#ifdef NFRU_DIAG_FILL
    nfruHoleFlags=0u;
    bool centerEmpty=depth_mvs_packed[0]==0u;
    bool allEmpty=nearest_packed_depth_mv==0u;
    bool border=output_pixel.x==0||output_pixel.y==0||output_pixel.x==output_dims.x-1||output_pixel.y==output_dims.y-1;
    if(centerEmpty){NfruDiagAdd(22u);nfruHoleFlags|=16u;}
    if(allEmpty){NfruDiagAdd(23u);nfruHoleFlags|=32u;if(!border)NfruDiagAdd(24u);}
    if(border)NfruDiagAdd(27u);
    if(centerEmpty&&!allEmpty)NfruDiagAdd(28u);
#endif
#ifdef NFRU_FLOW_VALIDITY
    NfruStoreFlowValidity(output_pixel,nearest_packed_depth_mv!=0u);
#endif
                                 
    FfxFloat32x2 motion = nfruWalkAvgMotion.x < 1e29 ? nfruWalkAvgMotion : dqFloatMv(nearest_packed_depth_mv);
    motion *= FfxFloat32x2(inv_output_dims);

#ifdef NFRU_DIAG_FILL
    if(all(equal(motion,float2(0.0)))){NfruDiagAdd(25u);nfruHoleFlags|=64u;}
    if(length(motion*float2(DisplaySize()))<=0.25)NfruDiagAdd(26u);
#endif
                           
    StoreDilatedVector(output_pixel, FFX_MIN16_F2(motion));
}

#endif                      
