// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
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
//
// SPDX-FileCopyrightText: Copyright 2025 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#pragma once

#include "ffx_types.h"
#if !defined(_WIN32)
#include <wchar.h>
#include <stdexcept>
#include <algorithm>
#endif

                             
                                             
   
                    

                    
   
                  
#define FFX_COUNTOF(ARRAY) (sizeof(ARRAY) / sizeof(ARRAY[0]))

#if !defined(_WIN32)
                              
template <size_t N>
int wcscpy_s(wchar_t (&dest)[N], const wchar_t* src)
{
    if (!src || !dest)
        return EINVAL;
    size_t i = 0;
    for (; i < N - 1 && src[i] != L'\0'; ++i)
    {
        dest[i] = src[i];
    }
    dest[i] = L'\0';
                                       
    if (src[i] != L'\0')
        return ERANGE;
    return 0;
}

inline int wcstombs_s(size_t* pRetval, char* dst, size_t dst_size, const wchar_t* src, size_t             )
{
    size_t result = wcstombs(dst, src, dst_size - 1);
    if (pRetval)
        *pRetval = result;
    dst[dst_size - 1] = '\0';                            
    return 0;                                            
}
#endif

                    
   
                  
const float FFX_PI = 3.141592653589793f;

                                                
   
                  
const float FFX_EPSILON = 1e-06f;

                                              
   
                  
#define FFX_MAKE_VERSION(major, minor, patch) ((major << 22) | (minor << 12) | patch)

                                    
   
                  
#define FFX_UNSPECIFIED_VERSION 0xFFFFAD00

                                                          
   
                  
#define FFX_UNUSED(x) ((void)(x))

                                                                         
   
                  
#define FFX_ALIGN_UP(x, y) (((x) + ((y)-1)) & ~((y)-1))

                                                
   
                  
#define FFX_IS_ALIGNED(x) (((x) != 0) && ((x) & ((x)-1)))

                                                                                    
   
                  
#define FFX_DIVIDE_ROUNDING_UP(x, y) ((x + y - 1) / y)

                                                                                    
   
                  
#define FFX_DIV_ALIGN(n, a) (((n) + ((a)-1)) / (a))

                                                              
   
                  
#define FFX_ALIGN(n, a) (FFX_DIV_ALIGN(n, a) * (a))

                                      
   
                  
#define FFX_STR(s)  FFX_XSTR(s)
#define FFX_XSTR(s) #s

                                                
   
                  
#define FFX_FORWARD_DECLARE(x) typedef struct x x

                                                     
   
                  
#define FFX_MAXIMUM(x, y) (((x) > (y)) ? (x) : (y))

                                                     
   
                  
#define FFX_MINIMUM(x, y) (((x) < (y)) ? (x) : (y))

                                              
   
                  
#define FFX_SAFE_FREE(x, freeFunc) \
    do                             \
    {                              \
        if (x)                     \
        {                          \
            freeFunc(x);           \
            x = nullptr;           \
        }                          \
    } while (false)

                                                       
   
                  
#define FFX_ABSOLUTE(x) (((x) < 0) ? (-(x)) : (x))

                                           
   
                  
#define FFX_SIGN(x) (((x) < 0) ? -1 : 1)

                                                                
   
                  
#define FFX_ARRAY_ELEMENTS(x) (int32_t)((sizeof(x) / sizeof(0 [x])) / ((size_t)(!(sizeof(x) % sizeof(0 [x])))))

                                                                             
   
                  
#define FFX_MAXIMUM_PATH (260)

                                                                    
   
                  
#define FFX_CONTAINS_FLAG(options, key) (((options)&key) == key)

#if defined(FFX_MUTEX_IMPL_SHARED)
                           
   
                  
#define FFX_MUTEX_LOCK(x) x.lock()
                                 
   
                  
#define FFX_MUTEX_LOCK_SHARED(x) x.lock_shared()
                                
   
                  
#define FFX_MUTEX_UNLOCK(x) x.unlock()
                             
   
                  
#define FFX_MUTEX_UNLOCK_SHARED(x) x.unlock_shared()
#elif defined(FFX_MUTEX_IMPL_STANDARD)
                           
   
                  
#define FFX_MUTEX_LOCK(x)          x.lock()
                                 
   
                  
#define FFX_MUTEX_LOCK_SHARED(x)   FFX_MUTEX_LOCK(x)
                                
   
                  
#define FFX_MUTEX_UNLOCK(x)        x.unlock()
                             
   
                  
#define FFX_MUTEX_UNLOCK_SHARED(x) FFX_MUTEX_UNLOCK(x)
#elif !defined(FFX_MUTEX_LOCK) || !defined(FFX_MUTEX_LOCK_SHARED) || !defined(FFX_MUTEX_UNLOCK) || !defined(FFX_MUTEX_UNLOCK_SHARED)
#error When using custom mutex you have to provide all following operations too: FFX_MUTEX_LOCK, FFX_MUTEX_LOCK_SHARED, FFX_MUTEX_UNLOCK, FFX_MUTEX_UNLOCK_SHARED!
#endif                                       

                                                      
   
                                 
   
                                                    
   
                  
inline uint8_t ffxCountBitsSet(uint32_t val) noexcept
{
#if defined(_MSVC_LANG)
    return static_cast<uint8_t>(__popcnt(val));
#elif defined(__GNUC__) || defined(__clang__)
    return static_cast<uint8_t>(__builtin_popcount(val));
#else
    uint32_t c = val - ((val >> 1) & 0x55555555);
    c          = ((c >> 2) & 0x33333333) + (c & 0x33333333);
    c          = ((c >> 4) + c) & 0x0F0F0F0F;
    c          = ((c >> 8) + c) & 0x00FF00FF;
    return static_cast<uint8_t>(((c >> 16) + c) & 0x0000FFFF);
#endif
}

                                             
   
                                                      
                                                                 
   
           
                                  
   
                  
FFX_API FfxDimensions2D GetOpticalFlowTextureSizeFromBlockSize(const FfxDimensions2D& displaySize, const uint32_t opticalFlowBlockSize);

                                           
   
                                                             
   
           
                                
   
                  
FFX_API uint32_t GetOpticalFlowBlockSize(const FfxOpticalFlowGridSize gridSize);

                               
   
                                                  
                                                      
   
                  
FFX_API void MatrixInvert4x4(const FfxFloat32x4x4 m, FfxFloat32x4x4 out);

                                     
   
                                                        
                                                         
                                                       
   
                  
FFX_API void MatrixMul4x4(const FfxFloat32x4x4 a, const FfxFloat32x4x4 b, FfxFloat32x4x4 out);