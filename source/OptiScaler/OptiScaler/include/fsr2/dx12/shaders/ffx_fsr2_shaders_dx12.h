// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2022-2023 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
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

#pragma once

#include <stdint.h>
#include "../../ffx_fsr2_interface.h"

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                               
    typedef struct Fsr2ShaderBlobDX12
    {

        const uint8_t* data;                         
        uint32_t size;                        
        uint32_t uavCount;                    
        uint32_t srvCount;                    
        uint32_t cbvCount;                    
        const char** boundUAVResourceNames;
        const uint32_t* boundUAVResources;                                               
        const char** boundSRVResourceNames;
        const uint32_t* boundSRVResources;                                               
        const char** boundCBVResourceNames;
        const uint32_t* boundCBVResources;                                                 
    } Fsr2ShaderBlobDX12;

                                                              
    typedef enum Fs2ShaderPermutationOptionsDX12
    {

        FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE =
            (1 << 0),                                                                                 
        FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT = (1 << 1),                                          
        FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS = (1 << 2),                                                 
        FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS = (1 << 3),                                            
        FSR2_SHADER_PERMUTATION_DEPTH_INVERTED = (1 << 4),                                          
        FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING = (1 << 5),                                         
        FSR2_SHADER_PERMUTATION_FORCE_WAVE64 = (1 << 6),                                                              
        FSR2_SHADER_PERMUTATION_ALLOW_FP16 = (1 << 7),                             
    } Fs2ShaderPermutationOptionsDX12;

                                                                           
    Fsr2ShaderBlobDX12 fsr2GetPermutationBlobByIndexDX12(FfxFsr2Pass passId, uint32_t permutationOptions);

#if defined(__cplusplus)
}
#endif                            
