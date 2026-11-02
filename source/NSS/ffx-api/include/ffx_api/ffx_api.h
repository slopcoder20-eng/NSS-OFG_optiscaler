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

#pragma once

#if defined(__cplusplus)
extern "C" {
#endif                             

#if defined(_MSC_VER)
#define FFX_API_ENTRY __declspec(dllexport)              
#elif defined(__GNUC__)
#define FFX_API_ENTRY __attribute__((visibility("default")))        
#else
#define FFX_API_ENTRY                                                                                 
#pragma warning Unknown dynamic link import / export semantics.
#endif

#include <stdint.h>

enum FfxApiReturnCodes
{
    FFX_API_RETURN_OK    = 0,                                    
    FFX_API_RETURN_ERROR = 1,                                                       
    FFX_API_RETURN_ERROR_UNKNOWN_DESCTYPE =
        2,                                                                                                                                          
    FFX_API_RETURN_ERROR_RUNTIME_ERROR = 3,                                                                                    
    FFX_API_RETURN_NO_PROVIDER         = 4,                                                                                              
    FFX_API_RETURN_ERROR_MEMORY        = 5,                                  
    FFX_API_RETURN_ERROR_PARAMETER     = 6,                                                                                                
};

typedef void*    ffxContext;
typedef uint32_t ffxReturnCode_t;

#define FFX_API_EFFECT_MASK       0xffff0000u
#define FFX_API_EFFECT_ID_GENERAL 0x00000000u

                        
typedef uint64_t ffxStructType_t;
typedef struct ffxApiHeader
{
    ffxStructType_t      type;                                                                                                                               
    struct ffxApiHeader* pNext;                                                                                           
} ffxApiHeader;

typedef ffxApiHeader ffxCreateContextDescHeader;
typedef ffxApiHeader ffxConfigureDescHeader;
typedef ffxApiHeader ffxQueryDescHeader;
typedef ffxApiHeader ffxDispatchDescHeader;

                              
#define FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_SILENCE  0x0000000u
#define FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_ERRORS   0x0000001u
#define FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_WARNINGS 0x0000002u
#define FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_VERBOSE  0xfffffffu

enum FfxApiMsgType
{
    FFX_API_MESSAGE_TYPE_ERROR   = 0,
    FFX_API_MESSAGE_TYPE_WARNING = 1,
    FFX_API_MESSAGE_TYPE_COUNT
};

typedef void (*ffxApiMessage)(uint32_t type, const char* message);

#define FFX_API_CONFIGURE_DESC_TYPE_GLOBALDEBUG1 0x0000001u
struct ffxConfigureDescGlobalDebug1
{
    ffxConfigureDescHeader header;
    ffxApiMessage          fpMessage;
    uint32_t               debugLevel;
};

#define FFX_API_QUERY_DESC_TYPE_GET_VERSIONS 4u
struct ffxQueryDescGetVersions
{
    ffxQueryDescHeader header;
    uint64_t           createDescType;                                                                             
    void*              device;                                                 
    uint64_t*
              outputCount;                                                                                                                                           
    uint64_t* versionIds;                                                                                                               
    const char**
        versionNames;                                                                                                                                                         
};

#define FFX_API_DESC_TYPE_OVERRIDE_VERSION 5u
struct ffxOverrideVersion
{
    ffxApiHeader header;
    uint64_t     versionId;                                                                                                               
};

                                                                                                                     
                                                                                          
typedef void* (*ffxAlloc)(void* pUserData, uint64_t size);

                                                                                    
typedef void (*ffxDealloc)(void* pUserData, void* pMem);

typedef struct ffxAllocationCallbacks
{
    void*      pUserData;
    ffxAlloc   alloc;
    ffxDealloc dealloc;
} ffxAllocationCallbacks;

                                
                                                                                                                                   
                                        
                                                                                             
                                                                                   
FFX_API_ENTRY ffxReturnCode_t ffxCreateContext(ffxContext* context, ffxCreateContextDescHeader* desc, const ffxAllocationCallbacks* memCb);
typedef ffxReturnCode_t (*PfnFfxCreateContext)(ffxContext* context, ffxCreateContextDescHeader* desc, const ffxAllocationCallbacks* memCb);

                                  
                                        
                                                                            
FFX_API_ENTRY ffxReturnCode_t ffxDestroyContext(ffxContext* context, const ffxAllocationCallbacks* memCb);
typedef ffxReturnCode_t (*PfnFfxDestroyContext)(ffxContext* context, const ffxAllocationCallbacks* memCb);

                                              
                                                              
                                        
FFX_API_ENTRY ffxReturnCode_t ffxConfigure(ffxContext* context, const ffxConfigureDescHeader* desc);
typedef ffxReturnCode_t (*PfnFfxConfigure)(ffxContext* context, const ffxConfigureDescHeader* desc);

                                           
                                                          
                                        
FFX_API_ENTRY ffxReturnCode_t ffxQuery(ffxContext* context, ffxQueryDescHeader* desc);
typedef ffxReturnCode_t (*PfnFfxQuery)(ffxContext* context, ffxQueryDescHeader* desc);

                                                                                      
                                        
FFX_API_ENTRY ffxReturnCode_t ffxDispatch(ffxContext* context, const ffxDispatchDescHeader* desc);
typedef ffxReturnCode_t (*PfnFfxDispatch)(ffxContext* context, const ffxDispatchDescHeader* desc);

#if defined(__cplusplus)
}
#endif                             
