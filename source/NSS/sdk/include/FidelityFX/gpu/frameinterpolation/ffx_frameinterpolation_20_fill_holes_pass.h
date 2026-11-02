// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#ifndef GPU_FRAMEINTERPOLATION_10_FILL_HOLES_PASS_H
#define GPU_FRAMEINTERPOLATION_10_FILL_HOLES_PASS_H

#include "ffx_frameinterpolation_callbacks_glsl.h"
#include "nfru_diagnostic_glsl.h"
#include "nfru_zero_mv_repair.h"
#define NFRU_DIAG_FILL
uint32_t LoadPackedQDepth(int32_t2 coord)
{
    return LoadWarpedMotionQDataTP1(coord);
}

void StoreDilatedVector(int32_t2 coord, FFX_MIN16_F2 value)
{
    float2 uv=(float2(coord)+0.5)*MvDepthLaneSizeRcp();
                                                                          
    int32_t2 flowCoord=clamp(int32_t2(uv*float2(FlowLaneSize())),int32_t2(0),FlowLaneSize()-1);
    FFX_MIN16_F2 forwardFlow=LoadWarpedFilledFlowTM1(flowCoord);
    uint reason;value=NfruRepairZeroMotionDetailed(uv,value,forwardFlow,reason);
    NfruDiagReason(coord,reason);
    StoreWarpFilledMotionTp1(coord, value);
}
#include "fill_holes_common.h"

void fill_holes(int32_t2 output_pixel)
{
    int32_t2 renderSize = MvDepthLaneSize();
    if (any(greaterThanEqual(output_pixel, renderSize)))
        return;

    float2 invRenderSize = MvDepthLaneSizeRcp();
    FillHoles(output_pixel, renderSize, invRenderSize);
}

#endif