/*
 * SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: MIT
 */

#include "quant.h"

#ifndef WARP_FLOW_COMMON
#define WARP_FLOW_COMMON

                                                                                                                  
                                                                                                              
bool WarpStore(FfxInt32x2                   dtId,
               half2                        motion,
               half2                        store,
               FfxFloat32                   depth,
               FfxInt32x2                   output_dims,
               FFX_MIN16_F                  t,
               FFX_MIN16_F                  s,
               FFX_PARAMETER_OUT FfxInt32x2 outCoord,
               FFX_PARAMETER_OUT FfxUInt32  outData)
{
    outCoord = FfxInt32x2(0);
    outData = 0u;
    FFX_MIN16_F2 vector = FFX_MIN16_F2(motion) * FFX_MIN16_F2(output_dims);
    FFX_MIN16_F2 stored = FFX_MIN16_F2(store) * FFX_MIN16_F2(output_dims);
    if (any(isnan(vector)) || any(isinf(vector)) || any(isnan(stored)) || any(isinf(stored)) || isnan(depth) || isinf(depth))
        return false;
    FFX_MIN16_F2 displacement = vector * t;
    if (any(isnan(displacement)) || any(isinf(displacement))) return false;
    FfxFloat32x2 target = FfxFloat32x2(dtId) + floor(FfxFloat32x2(displacement));
    if (any(lessThan(target, FfxFloat32x2(0.0))) ||
        any(greaterThanEqual(target, FfxFloat32x2(output_dims))))
        return false;
    outCoord = FfxInt32x2(target);
    outData  = qFloat(s * stored, depth);
    return true;
}

                                                                                                                    
                                                                                                                     
                                                                                                                 
bool NfruSplatStretch() { return (cbFI._pad0 & 0x80000000u) != 0u; }
void NfruStretchBox(float2 tgt, float2 tgtX, float2 tgtY, bool okX, bool okY, FFX_PARAMETER_OUT FfxInt32x2 lo, FFX_PARAMETER_OUT FfxInt32x2 hi)
{
    float2 c0 = okX ? tgtX - tgt : float2(1.0, 0.0);
    float2 c1 = okY ? tgtY - tgt : float2(0.0, 1.0);
    if (any(isnan(c0)) || any(isinf(c0))) c0 = float2(1.0, 0.0);
    if (any(isnan(c1)) || any(isinf(c1))) c1 = float2(0.0, 1.0);
    float2 mn = min(float2(0.0), c0) + min(float2(0.0), c1), mx = max(float2(0.0), c0) + max(float2(0.0), c1);
    lo = FfxInt32x2(clamp(floor(mn), float2(-3.0), float2(0.0)));
    hi = FfxInt32x2(clamp(ceil(mx) - 1.0, float2(0.0), float2(3.0)));
}
bool NfruSameSurface(float a, float b) { return abs(a - b) <= 0.05 * max(abs(a), abs(b)) + 1e-7; }

bool Warp(FfxInt32x2                   dtId,
          half2                        motion,
          FfxFloat32                   depth,
          FfxInt32x2                   output_dims,
          FFX_MIN16_F                  t,
          FFX_MIN16_F                  s,
          FFX_PARAMETER_OUT FfxInt32x2 outCoord,
          FFX_PARAMETER_OUT FfxUInt32  outData)
{
    outCoord = FfxInt32x2(0);
    outData = 0u;
                                      

                                                
    FFX_MIN16_F2 vector = FFX_MIN16_F2(motion) * FFX_MIN16_F2(output_dims);

                                                   
                                     
    if (any(isnan(vector)) || any(isinf(vector)) || isnan(depth) || isinf(depth))
        return false;
                                                                                
    FFX_MIN16_F2 displacement = vector * t;
    if (any(isnan(displacement)) || any(isinf(displacement))) return false;
    FfxFloat32x2 target = FfxFloat32x2(dtId) + floor(FfxFloat32x2(displacement));
    if (any(lessThan(target, FfxFloat32x2(0.0))) ||
        any(greaterThanEqual(target, FfxFloat32x2(output_dims))))
        return false;
    FfxInt32x2 coord = FfxInt32x2(target);

                                                             
                                                                           
    FfxUInt32 qdata = qFloat(s * vector, depth);

    outCoord = coord;
    outData  = qdata;
    return true;
}

#endif                     
