// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2022 Advanced Micro Devices, Inc. All rights reserved.
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

#include "ffx_types.h"
#include "ffx_util.h"

namespace Fsr212
{

#ifdef __cplusplus
extern "C"
{
#endif                      

#ifdef _DEBUG
#ifdef _WIN32

#ifdef DISABLE_FFX_DEBUG_BREAK
#define FFX_DEBUG_BREAK                                                                                                \
    {                                                                                                                  \
    }
#else
                                                                       
#define FFX_DEBUG_BREAK __debugbreak();
#endif
#else
#define FFX_DEBUG_BREAK                                                                                                \
    {                                                                                                                  \
    }
#endif
#else
                                             
#define FFX_DEBUG_BREAK
#endif

                                                                
       
                                                                                     
                                                                                        
                                                                                   
                                        
       
                                                                                
       
    typedef void (*FfxAssertCallback)(const char* message);

                                     
       
                                                                             
                                                                              
                                                                                  
                                                                          
       
                
                            
       
    bool ffxAssertReport212(const char* file, int32_t line, const char* condition, const char* msg);

                                                                   
       
                                                                                                    
       
    void ffxAssertSetPrintingCallback212(FfxAssertCallback callback);

#ifdef _DEBUG
                              
#define FFX_ASSERT_212(condition)                                                                                      \
    do                                                                                                                 \
    {                                                                                                                  \
        if (!(condition) && ffxAssertReport212(__FILE__, __LINE__, #condition, NULL))                                  \
            FFX_DEBUG_BREAK                                                                                            \
    } while (0)

                              
#define FFX_ASSERT_MESSAGE_212(condition, msg)                                                                         \
    do                                                                                                                 \
    {                                                                                                                  \
        if (!(condition) && ffxAssertReport212(__FILE__, __LINE__, #condition, msg))                                   \
            FFX_DEBUG_BREAK                                                                                            \
    } while (0)

                                   
#define FFX_ASSERT_FAIL_212(message)                                                                                   \
    do                                                                                                                 \
    {                                                                                                                  \
        ffxAssertReport212(__FILE__, __LINE__, NULL, message);                                                         \
        FFX_DEBUG_BREAK                                                                                                \
    } while (0)
#else
                   
#define FFX_ASSERT_212(condition)                                                                                      \
    do                                                                                                                 \
    {                                                                                                                  \
        FFX_UNUSED(condition);                                                                                         \
    } while (0)

#define FFX_ASSERT_MESSAGE_212(condition, message)                                                                     \
    do                                                                                                                 \
    {                                                                                                                  \
        FFX_UNUSED(condition);                                                                                         \
        FFX_UNUSED(message);                                                                                           \
    } while (0)

#define FFX_ASSERT_FAIL_212(message)                                                                                   \
    do                                                                                                                 \
    {                                                                                                                  \
        FFX_UNUSED(message);                                                                                           \
    } while (0)
#endif              

                         
#define FFX_STATIC_ASSERT(condition) static_assert(condition, #condition)

#ifdef __cplusplus
}
#endif                      
}                    