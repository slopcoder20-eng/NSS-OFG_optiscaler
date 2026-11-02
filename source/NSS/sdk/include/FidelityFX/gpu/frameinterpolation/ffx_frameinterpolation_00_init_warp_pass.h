// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#include "ffx_frameinterpolation_callbacks_glsl.h"
#include "ffx_frameinterpolation_common.h"
#include "nfru_diagnostic_glsl.h"
#include "nfru_camera_fit.h"

                                                                                     
                                                                                          
void init_warp(int32_t2 output_pixel)
{
    int32_t2 mv_depth_size = MvDepthLaneSize();
    if (all(lessThan(output_pixel, mv_depth_size)))
    {
        InitWarpClearQDataTp1(output_pixel);
        InitWarpClearHolesTp1(output_pixel);
        InitWarpClearHolesTm1(output_pixel);
    }

    int32_t2 flow_size = FlowLaneSize();
    if (all(lessThan(output_pixel, flow_size)))
    {
        InitWarpClearQDataTm1(output_pixel);
    }
}
