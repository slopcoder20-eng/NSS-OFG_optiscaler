// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#version 460
#extension GL_EXT_samplerless_texture_functions : require
#extension GL_GOOGLE_include_directive : require
#if NSS_SUPPORT_TENSOR
#extension GL_ARM_tensors : require
#endif

#if FFX_HALF
#extension GL_EXT_shader_8bit_storage : require
#extension GL_EXT_shader_16bit_storage : require
#extension GL_EXT_shader_explicit_arithmetic_types : require
#extension GL_EXT_shader_explicit_arithmetic_types_int8 : require
#extension GL_EXT_shader_explicit_arithmetic_types_float16 : require
#extension GL_EXT_shader_explicit_arithmetic_types_float32 : require
#endif

                                                                               
                      
                                                                               
#define NSS_BIND_SRV_INPUT_COLOR_JITTERED    0                                              
#define NSS_BIND_SRV_INPUT_MOTION_VECTORS    1                                                       
#define NSS_BIND_SRV_HISTORY_UPSCALED_COLOR  2                                                         
#define NSS_BIND_SRV_INPUT_DEPTH             3                                              
#define NSS_BIND_SRV_INPUT_DEPTH_TM1         4                                                                        
#define NSS_BIND_SRV_LUMA_DERIV_TM1          5                                                 
#define NSS_BIND_SRV_NEAREST_DEPTH_COORD     6                                                      
#define NSS_BIND_SRV_FEEDBACK_TENSOR         7                                                                       
#define NSS_BIND_SRV_DISOCCLUSION_MASK_LQ    8                                                       
#define NSS_BIND_SRV_LUMA_DERIV              9                                                                        

                                                                               
                                                       
                                                                               
#define NSS_BIND_PREPROCESS_INPUT_TENSOR     10                                                         

                                                                               
                                     
                                                                               
#define NSS_BIND_UAV_DEBUG_VIEWS             11                                             

#define NSS_BIND_CB_NSS                      12

#include "nss/ffx_nss_debug_view.h"

#ifndef FFX_NSS_NUM_THREADS
#define FFX_NSS_NUM_THREADS layout (local_size_x = FFX_NSS_THREAD_GROUP_WIDTH, local_size_y = FFX_NSS_THREAD_GROUP_HEIGHT, local_size_z = FFX_NSS_THREAD_GROUP_DEPTH) in;
#endif                        

FFX_NSS_NUM_THREADS
void main()
{
    DebugViewCS(int32_t2(gl_GlobalInvocationID.xy));
}
