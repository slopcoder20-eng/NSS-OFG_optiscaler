// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#version 450
#extension GL_EXT_shader_8bit_storage : require
#extension GL_EXT_shader_16bit_storage : require
#extension GL_EXT_samplerless_texture_functions : require
#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_shader_explicit_arithmetic_types_int8 : require
#extension GL_EXT_shader_explicit_arithmetic_types_float16 : require
#extension GL_EXT_shader_explicit_arithmetic_types_float32 : require
#extension GL_GOOGLE_include_directive : enable

                                                                               
                      
                                                                               
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_OUT_PARAMS_TENSOR               0
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_FILLED_MOTION_TP1          1
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_FILLED_FLOW_TM1            2
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_FILLED_MOTION_TM1          3
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_PREVIOUS_INTERPOLATION_SOURCE   4
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_CURRENT_INTERPOLATION_SOURCE    5

                                                                               
                      
                                                                               
#define FFX_ARM_FRAMEINTERPOLATION_BIND_UAV_OUTPUT                          6

#define FFX_ARM_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION               7
                                                                                     
#define FFX_ARM_FRAMEINTERPOLATION_BIND_UAV_PREVIOUS_INTERPOLATION_SOURCE   8


#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_PRESENT_BACKBUFFER 9

#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1 11
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TM1 12
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_TP1 13
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_FLOW_TM1 14
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_FLOW_QDATA_TM1 15
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_COLOUR_M2 16
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_DEPTH_M2 17
#define FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1 18
#define NFRU_DIAG_BINDING 10
#define NFRU_SELECT_BINDING 19
#include "frameinterpolation/ffx_frameinterpolation_50_postprocess_pass.h"

                                                                                

              
#ifndef FFX_ARM_FRAMEINTERPOLATION_NUM_THREADS
#define FFX_ARM_FRAMEINTERPOLATION_NUM_THREADS layout (local_size_x = FFX_FRAMEINTERPOLATION_THREAD_GROUP_WIDTH, local_size_y = FFX_FRAMEINTERPOLATION_THREAD_GROUP_HEIGHT, local_size_z = FFX_FRAMEINTERPOLATION_THREAD_GROUP_DEPTH) in;
#endif                                                  

FFX_ARM_FRAMEINTERPOLATION_NUM_THREADS
void main()
{
    postprocess(int32_t2(gl_GlobalInvocationID.xy));
}