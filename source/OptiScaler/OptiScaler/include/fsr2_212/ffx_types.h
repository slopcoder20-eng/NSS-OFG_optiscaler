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

#include <stdint.h>

namespace Fsr212
{

#if defined(FFX_GCC)
                                 
#define FFX_API
#else
                                 
#define FFX_API __declspec(dllexport)
#endif                         

                                                          
#define FFX_MAX_NUM_SRVS 16

                                                          
#define FFX_MAX_NUM_UAVS 8

                                             
#define FFX_MAX_NUM_CONST_BUFFERS 2

                                           
#define FFX_MAX_CONST_SIZE 64

                           
#pragma warning(disable : 4365 4710 4820 5039)

#ifdef __cplusplus
extern "C"
{
#endif                      

                                          
    typedef enum FfxSurfaceFormat
    {

        FFX_SURFACE_FORMAT_UNKNOWN,                                  
        FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS,                                                   
        FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT,                                                   
        FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT,                                                   
        FFX_SURFACE_FORMAT_R16G16B16A16_UNORM,                                                                 
        FFX_SURFACE_FORMAT_R32G32_FLOAT,                                                         
        FFX_SURFACE_FORMAT_R32_UINT,                                                             
        FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS,                                                    
        FFX_SURFACE_FORMAT_R8G8B8A8_UNORM,                                                                     
        FFX_SURFACE_FORMAT_R11G11B10_FLOAT,                                         
        FFX_SURFACE_FORMAT_R16G16_FLOAT,                                                         
        FFX_SURFACE_FORMAT_R16G16_UINT,                                                                 
        FFX_SURFACE_FORMAT_R16_FLOAT,                                                            
        FFX_SURFACE_FORMAT_R16_UINT,                                                                    
        FFX_SURFACE_FORMAT_R16_UNORM,                                                                          
        FFX_SURFACE_FORMAT_R16_SNORM,                                                                        
        FFX_SURFACE_FORMAT_R8_UNORM,                                                                           
        FFX_SURFACE_FORMAT_R8G8_UNORM,                                                                         
        FFX_SURFACE_FORMAT_R32_FLOAT                                                             
    } FfxSurfaceFormat;

                                         
    typedef enum FfxResourceUsage
    {

        FFX_RESOURCE_USAGE_READ_ONLY = 0,                                                                
        FFX_RESOURCE_USAGE_RENDERTARGET = (1 << 0),                                                         
        FFX_RESOURCE_USAGE_UAV = (1 << 1),                                                        
    } FfxResourceUsage;

                                          
    typedef enum FfxResourceStates
    {

        FFX_RESOURCE_STATE_UNORDERED_ACCESS = (1 << 0),                                                             
        FFX_RESOURCE_STATE_COMPUTE_READ =
            (1 << 1),                                                                         
        FFX_RESOURCE_STATE_COPY_SRC =
            (1 << 2),                                                                                  
        FFX_RESOURCE_STATE_COPY_DEST =
            (1 << 3),                                                                                       
        FFX_RESOURCE_STATE_GENERIC_READ =
            (FFX_RESOURCE_STATE_COPY_SRC |
             FFX_RESOURCE_STATE_COMPUTE_READ),                                                           
    } FfxResourceStates;

                                             
    typedef enum FfxResourceDimension
    {

        FFX_RESOURCE_DIMENSION_TEXTURE_1D,                                         
        FFX_RESOURCE_DIMENSION_TEXTURE_2D,                                     
    } FfxResourceDimension;

                                             
    typedef enum FfxResourceFlags
    {

        FFX_RESOURCE_FLAGS_NONE = 0,               
        FFX_RESOURCE_FLAGS_ALIASABLE =
            (1 << 0),                                                                         
    } FfxResourceFlags;

                                                  
    typedef enum FfxResourceViewType
    {

        FFX_RESOURCE_VIEW_UNORDERED_ACCESS,                                                          
        FFX_RESOURCE_VIEW_SHADER_READ,                                                             
    } FfxResourceViewType;

                                                                
    typedef enum FfxFilterType
    {

        FFX_FILTER_TYPE_POINT,                     
        FFX_FILTER_TYPE_LINEAR                                  
    } FfxFilterType;

                                                      
    typedef enum FfxShaderModel
    {

        FFX_SHADER_MODEL_5_1,                       
        FFX_SHADER_MODEL_6_0,                       
        FFX_SHADER_MODEL_6_1,                       
        FFX_SHADER_MODEL_6_2,                       
        FFX_SHADER_MODEL_6_3,                       
        FFX_SHADER_MODEL_6_4,                       
        FFX_SHADER_MODEL_6_5,                       
        FFX_SHADER_MODEL_6_6,                       
        FFX_SHADER_MODEL_6_7,                       
    } FfxShaderModel;

                                                  
    typedef enum FfxResourceType
    {

        FFX_RESOURCE_TYPE_BUFFER,                                  
        FFX_RESOURCE_TYPE_TEXTURE1D,                                              
        FFX_RESOURCE_TYPE_TEXTURE2D,                                              
        FFX_RESOURCE_TYPE_TEXTURE3D,                                              
    } FfxResourceType;

                                               
    typedef enum FfxHeapType
    {

        FFX_HEAP_TYPE_DEFAULT = 0,                   
        FFX_HEAP_TYPE_UPLOAD                                              
    } FfxHeapType;

                                                      
    typedef enum FfxGpuJobType
    {

        FFX_GPU_JOB_CLEAR_FLOAT = 0,                                                       
        FFX_GPU_JOB_COPY = 1,                                              
        FFX_GPU_JOB_COMPUTE = 2,                                                       
    } FfxGpuJobType;

                                                   
    typedef void* FfxDevice;

                                                                
    typedef void* FfxCommandList;

                                       
    typedef void* FfxRootSignature;

                                              
    typedef void* FfxPipeline;

                                                                       
    typedef struct FfxDeviceCapabilities
    {

        FfxShaderModel minimumSupportedShaderModel;                                                       
        uint32_t waveLaneCountMin;                                                             
        uint32_t waveLaneCountMax;                                                             
        bool fp16Supported;                                                                   
        bool raytracingSupported;                                                       
    } FfxDeviceCapabilities;

                                                                                       
    typedef struct FfxDimensions2D
    {

        uint32_t width;                                          
        uint32_t height;                                          
    } FfxDimensions2D;

                                                        
    typedef struct FfxIntCoords2D
    {

        int32_t x;                                                
        int32_t y;                                                
    } FfxIntCoords2D;

                                                                                    
    typedef struct FfxFloatCoords2D
    {

        float x;                                                
        float y;                                                
    } FfxFloatCoords2D;

                                          
    typedef struct FfxResourceDescription
    {

        FfxResourceType type;                                  
        FfxSurfaceFormat format;                         
        uint32_t width;                                         
        uint32_t height;                                         
        uint32_t depth;                                         
        uint32_t mipCount;                                                    
        FfxResourceFlags flags;                                                     
    } FfxResourceDescription;

                                                         
    typedef struct FfxResource
    {
        void* resource;                              
        wchar_t name[64];
        FfxResourceDescription description;
        FfxResourceStates state;
        bool isDepth;
        uint64_t descriptorData;
    } FfxResource;

                                                                                  
    typedef struct FfxResourceInternal
    {
        int32_t internalIndex;                                
    } FfxResourceInternal;

                                                  
    typedef struct FfxResourceBinding
    {
        uint32_t slotIndex;
        uint32_t resourceIdentifier;
        wchar_t name[64];
    } FfxResourceBinding;

                                                                
    typedef struct FfxPipelineState
    {

        FfxRootSignature rootSignature;                                 
        FfxPipeline pipeline;                                   
        uint32_t uavCount;                                                      
        uint32_t srvCount;                                                      
        uint32_t constCount;                                                                

        FfxResourceBinding uavResourceBindings[FFX_MAX_NUM_UAVS];                                                
        FfxResourceBinding srvResourceBindings[FFX_MAX_NUM_SRVS];                                                
        FfxResourceBinding cbResourceBindings[FFX_MAX_NUM_CONST_BUFFERS];                                               
    } FfxPipelineState;

                                                                      
    typedef struct FfxCreateResourceDescription
    {

        FfxHeapType heapType;                                                                                        
        FfxResourceDescription resourceDescription;                             
        FfxResourceStates initalState;                                              
        uint32_t initDataSize;                                                       
        void* initData;                                                                              
        const wchar_t* name;                                                  
        FfxResourceUsage usage;                                               
        uint32_t id;                                                          
    } FfxCreateResourceDescription;

                                                               
                                            
       
                                                                                 
                                                                               
                                                                                   
                                                       
                                                                              
                                                             
       
                                                                                
                                                                                  
                                                                                
                                                                        
                                                                                   
                                                                                   
                                       
       
                                                                               
                                                                              
                                                                                 
                                                                            
                                                                           
                                                                                  
                                                       
       
                     
    typedef struct FfxPipelineDescription
    {

        uint32_t contextFlags;                                                                                          
                                            
        FfxFilterType* samplers;                                               
        size_t samplerCount;                                                                                        
        const uint32_t* rootConstantBufferSizes;                                                                       
                                                                       
        uint32_t rootConstantBufferCount;                                                          
                                                                                            
    } FfxPipelineDescription;

                                                 
    typedef struct FfxConstantBuffer
    {

        uint32_t uint32Size;                                                                     
        uint32_t data[FFX_MAX_CONST_SIZE];                          
    } FfxConstantBuffer;

                                                  
    typedef struct FfxClearFloatJobDescription
    {

        float color[4];                                                  
        FfxResourceInternal target;                                 
    } FfxClearFloatJobDescription;

                                                    
    typedef struct FfxComputeJobDescription
    {

        FfxPipelineState pipeline;                                                           
        uint32_t dimensions[3];                                              
        FfxResourceInternal srvs[FFX_MAX_NUM_SRVS];                                                   
        wchar_t srvNames[FFX_MAX_NUM_SRVS][64];
        FfxResourceInternal uavs[FFX_MAX_NUM_UAVS];                                                   
        uint32_t uavMip[FFX_MAX_NUM_UAVS];                                                                         
        wchar_t uavNames[FFX_MAX_NUM_UAVS][64];
        FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                      
        wchar_t cbNames[FFX_MAX_NUM_CONST_BUFFERS][64];
    } FfxComputeJobDescription;

                                                 
    typedef struct FfxCopyJobDescription
    {
        FfxResourceInternal src;                                   
        FfxResourceInternal dst;                                        
    } FfxCopyJobDescription;

                                                   
    typedef struct FfxGpuJobDescription
    {

        FfxGpuJobType jobType;                      

        union
        {
            FfxClearFloatJobDescription clearJobDescriptor;                                                            
                                                                                                             
            FfxCopyJobDescription copyJobDescriptor;                                                                    
                                                                                                  
            FfxComputeJobDescription computeJobDescriptor;                                                              
                                                                                                        
        };
    } FfxGpuJobDescription;

#ifdef __cplusplus
}
#endif                      

}                    