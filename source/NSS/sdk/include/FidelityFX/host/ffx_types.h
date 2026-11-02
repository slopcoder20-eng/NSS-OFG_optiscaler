// Copyright  © 2023 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <stdint.h>
#include <cwchar>                                            
#include <cstring>

   
                        
                      
   

                          
                                                 
   
                   

                             
                                                
   
                    

                                                      
                                                  
                                                      
                                                      
                                                          
  
                                                                           
                                                                                     
#ifndef FFX_MUTEX
#if __cplusplus >= 201703L
#include <shared_mutex>
                             
   
                     
#define FFX_MUTEX std::shared_mutex
#define FFX_MUTEX_IMPL_SHARED
#else
#include <mutex>
                             
   
                     
#define FFX_MUTEX std::mutex
#define FFX_MUTEX_IMPL_STANDARD
#endif                               
#endif                      

#if defined(FFX_GCC) || !defined(FFX_BUILD_AS_DLL)
                                 
   
                    
#define FFX_API
#else
                                 
   
                    
#if defined(_WIN32)
#define FFX_API __declspec(dllexport)
#else
#define FFX_API __attribute__((visibility("default")))
#endif
#endif                          

#define FFX_SDK_DEFAULT_CONTEXT_SIZE (1024 * 256)

                                                          
   
                    
#define FFX_MAX_NUM_SRVS 16

                                                          
   
                    
#define FFX_MAX_NUM_UAVS 16

                                                                   
   
                    
#define FFX_MAX_NUM_RTS 8

                                                             
   
                    
#define FFX_MAX_NUM_TENSORS 8

                                             
   
                    
#define FFX_MAX_NUM_CONST_BUFFERS 3

                                           
#define FFX_MAX_CONST_SIZE 256

                                                   
   
                    
#define FFX_RESOURCE_NAME_SIZE 64

                                                  
   
                    
#define FFX_MAX_QUEUED_FRAMES (4)

                                                  
   
                    
#define FFX_MAX_RESOURCE_COUNT (64)

                                                 
   
                    
#define FFX_MAX_PASS_COUNT (50)

                                                             
   
                    
#define FFX_RING_BUFFER_SIZE (FFX_MAX_QUEUED_FRAMES * FFX_MAX_PASS_COUNT * FFX_MAX_RESOURCE_COUNT)

                                                          
   
                    
#define FFX_BUFFER_SIZE (768)

                                                             
   
                    
#define FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE (FFX_MAX_QUEUED_FRAMES * FFX_MAX_PASS_COUNT * FFX_BUFFER_SIZE)

                                        
   
                    
#define FFX_MAX_BARRIERS (16)

                                             
   
                    
#define FFX_MAX_GPU_JOBS (64)

                                        
   
                    
#define FFX_MAX_SAMPLERS (16)

                                              
   
                    
#define UPLOAD_JOB_COUNT (16)

                          
#pragma warning(disable : 4365 4710 4820 5039)

#ifdef __cplusplus
extern "C" {
#endif                       

                                
                                                         
   
                    

                                                                                
   
                     
typedef uint32_t FfxVersionNumber;

                                  
   
                     
typedef bool FfxBoolean;

                                          
   
                     
typedef uint8_t FfxUInt8;

                                           
   
                     
typedef uint16_t FfxUInt16;

                                           
   
                     
typedef uint32_t FfxUInt32;

                                           
   
                     
typedef uint64_t FfxUInt64;

                                        
   
                     
typedef int8_t FfxInt8;

                                         
   
                     
typedef int16_t FfxInt16;

                                         
   
                     
typedef int32_t FfxInt32;

                                         
   
                     
typedef int64_t FfxInt64;

                                         
   
                     
typedef float FfxFloat32;

                                                       
   
                     
typedef float FfxFloat32x2[2];

                                                       
   
                     
typedef float FfxFloat32x3[3];

                                                       
   
                     
typedef float FfxFloat32x4[4];

                                              
   
                     
typedef float FfxFloat32x4x4[16];

                                                         
   
                     
typedef uint32_t FfxUInt32x2[2];

                                                         
   
                     
typedef uint32_t FfxUInt32x3[3];

                                                         
   
                     
typedef uint32_t FfxUInt32x4[4];

                                                       
   
                     
typedef int32_t FfxInt32x2[2];

                                                       
   
                     
typedef int32_t FfxInt32x3[3];

                                                       
   
                     
typedef int32_t FfxInt32x4[4];

                                
                                                                    
   
                    

                                                                              
   
                     
typedef enum FfxSurfaceFormat
{

    FFX_SURFACE_FORMAT_UNKNOWN,                                   
    FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS,                                                    
    FFX_SURFACE_FORMAT_R32G32B32A32_UINT,                                                    
    FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT,                                                    
    FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT,                                                    
    FFX_SURFACE_FORMAT_R32G32B32_FLOAT,                                                       
    FFX_SURFACE_FORMAT_R32G32_FLOAT,                                                          
    FFX_SURFACE_FORMAT_R8_UINT,                                                              
    FFX_SURFACE_FORMAT_R8_SINT,                                                              
    FFX_SURFACE_FORMAT_R32_UINT,                                                              
    FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS,                                                        
    FFX_SURFACE_FORMAT_R8G8B8A8_UNORM,                                                                      
    FFX_SURFACE_FORMAT_R8G8B8A8_SNORM,                                                                    
    FFX_SURFACE_FORMAT_R8G8B8A8_SRGB,                                                            
    FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS,                                                        
    FFX_SURFACE_FORMAT_B8G8R8A8_UNORM,                                                                      
    FFX_SURFACE_FORMAT_B8G8R8A8_SRGB,                                                            
    FFX_SURFACE_FORMAT_R11G11B10_FLOAT,                                          
    FFX_SURFACE_FORMAT_R10G10B10A2_UNORM,                                                                      
    FFX_SURFACE_FORMAT_R16G16_FLOAT,                                                          
    FFX_SURFACE_FORMAT_R16G16_UINT,                                                                  
    FFX_SURFACE_FORMAT_R16G16_SINT,                                                                
    FFX_SURFACE_FORMAT_R16_FLOAT,                                                             
    FFX_SURFACE_FORMAT_R16_UINT,                                                                     
    FFX_SURFACE_FORMAT_R16_UNORM,                                                                           
    FFX_SURFACE_FORMAT_R16_SNORM,                                                                         
    FFX_SURFACE_FORMAT_R8_UNORM,                                                                            
    FFX_SURFACE_FORMAT_R8_SNORM,                                                                          
    FFX_SURFACE_FORMAT_R8G8_UNORM,                                                                          
    FFX_SURFACE_FORMAT_R8G8_UINT,                                                                        
    FFX_SURFACE_FORMAT_R8G8_SINT,                                                                      
    FFX_SURFACE_FORMAT_R32_FLOAT,                                                             
    FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP,                                                   

    FFX_SURFACE_FORMAT_R16G16B16A16_TYPELESS,                                                    
    FFX_SURFACE_FORMAT_R32G32_TYPELESS,                                                          
    FFX_SURFACE_FORMAT_R10G10B10A2_TYPELESS,                                                                 
    FFX_SURFACE_FORMAT_R16G16_TYPELESS,                                                          
    FFX_SURFACE_FORMAT_R16_TYPELESS,                                                             
    FFX_SURFACE_FORMAT_R8_TYPELESS,                                                              
    FFX_SURFACE_FORMAT_R8G8_TYPELESS,                                                            
    FFX_SURFACE_FORMAT_R32_TYPELESS,                                                             
} FfxSurfaceFormat;

typedef enum FfxIndexFormat
{
    FFX_INDEX_TYPE_UINT32,
    FFX_INDEX_TYPE_UINT16
} FfxIndexFormat;

                                     
   
                     
typedef enum FfxResourceUsage
{

    FFX_RESOURCE_USAGE_READ_ONLY        = 0,                                                               
    FFX_RESOURCE_USAGE_RENDERTARGET     = (1 << 0),                                                           
    FFX_RESOURCE_USAGE_UAV              = (1 << 1),                                                 
    FFX_RESOURCE_USAGE_DEPTHTARGET      = (1 << 2),                                                          
    FFX_RESOURCE_USAGE_INDIRECT         = (1 << 3),                                                                     
    FFX_RESOURCE_USAGE_ARRAYVIEW        = (1 << 4),                                                                                             
    FFX_RESOURCE_USAGE_STENCILTARGET    = (1 << 5),                                                            
    FFX_RESOURCE_USAGE_DCC_RENDERTARGET = (1 << 15),                                                                                                           
} FfxResourceUsage;

                                                                                             
   
                     
typedef enum FfxResourceStates
{

    FFX_RESOURCE_STATE_COMMON       = (1 << 0),
    FFX_RESOURCE_STATE_COMPUTE_UAV  = (1 << 1),                                                                                 
    FFX_RESOURCE_STATE_PIXEL_UAV    = (1 << 2),                                                                               
    FFX_RESOURCE_STATE_GENERIC_UAV  = (FFX_RESOURCE_STATE_COMPUTE_UAV |
                                      FFX_RESOURCE_STATE_PIXEL_UAV),                                                                                          
    FFX_RESOURCE_STATE_COMPUTE_READ = (1 << 3),                                                                                                
    FFX_RESOURCE_STATE_PIXEL_READ   = (1 << 4),                                                                                              
    FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ =
        (FFX_RESOURCE_STATE_PIXEL_READ | FFX_RESOURCE_STATE_COMPUTE_READ),                                                                                   
    FFX_RESOURCE_STATE_COPY_SRC  = (1 << 5),                                                                                                                 
    FFX_RESOURCE_STATE_COPY_DEST = (1 << 6),                                                                                        
    FFX_RESOURCE_STATE_GENERIC_READ =
        (FFX_RESOURCE_STATE_COPY_SRC | FFX_RESOURCE_STATE_COMPUTE_READ),                                                            
    FFX_RESOURCE_STATE_INDIRECT_ARGUMENT = (1 << 7),                                                                                                          
    FFX_RESOURCE_STATE_PRESENT           = (1 << 8),                                                                                                       
    FFX_RESOURCE_STATE_RENDER_TARGET     = (1 << 9),                                                                                           
    FFX_RESOURCE_STATE_DATA_GRAPH_READ   = (1 << 10),                                                                                       
    FFX_RESOURCE_STATE_DATA_GRAPH_WRITE  = (1 << 11),                                                                                          
                                          
    FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT = (1 << 12),                                                                          

} FfxResourceStates;

                                         
   
                     
typedef enum FfxResourceDimension
{

    FFX_RESOURCE_DIMENSION_TEXTURE_1D,                                          
    FFX_RESOURCE_DIMENSION_TEXTURE_2D,                                      
} FfxResourceDimension;

                                               
   
                     
typedef enum FfxResourceViewDimension
{
    FFX_RESOURCE_VIEW_DIMENSION_BUFFER,                                             
    FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_1D,                                                   
    FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_1D_ARRAY,                                                     
    FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_2D,                                               
    FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_2D_ARRAY,                                                
    FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_3D,                                                 
} FfxResourceViewDimension;

                                         
   
                     
typedef enum FfxResourceFlags
{

    FFX_RESOURCE_FLAGS_NONE           = 0,                       
    FFX_RESOURCE_FLAGS_ALIASABLE      = (1 << 0),                                                                          
    FFX_RESOURCE_FLAGS_IMAGE_ALIASED  = (1 << 1),                                                                                          
    FFX_RESOURCE_FLAGS_BUFFER_ALIASED = (1 << 2),                                                            
    FFX_RESOURCE_FLAGS_UNDEFINED      = (1 << 3),                                                                                               
} FfxResourceFlags;

                                              
   
                     
typedef enum FfxResourceViewType
{

    FFX_RESOURCE_VIEW_UNORDERED_ACCESS,                                                           
    FFX_RESOURCE_VIEW_SHADER_READ,                                                              
} FfxResourceViewType;

                                                            
   
                     
typedef enum FfxFilterType
{

    FFX_FILTER_TYPE_MINMAGMIP_POINT,                            
    FFX_FILTER_TYPE_MINMAGMIP_LINEAR,                                        
    FFX_FILTER_TYPE_MINMAGLINEARMIP_POINT,                                                                                                              
} FfxFilterType;

                                                 
   
                     
typedef enum FfxAddressMode
{

    FFX_ADDRESS_MODE_WRAP,                                        
    FFX_ADDRESS_MODE_MIRROR,                                        
    FFX_ADDRESS_MODE_CLAMP,                                        
    FFX_ADDRESS_MODE_BORDER,                                              
    FFX_ADDRESS_MODE_MIRROR_ONCE,                                        
} FfxAddressMode;

                                                  
   
                     
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
    FFX_RESOURCE_TYPE_TEXTURE_CUBE,                                  
    FFX_RESOURCE_TYPE_TEXTURE3D,                                                  
    FFX_RESOURCE_TYPE_TENSOR,                                      
} FfxResourceType;

                                                                     
                                                             
   
                     
typedef enum FfxOpticalFlowConnectionType
{
    FFX_OPTICAL_FLOW_CONNECTION_UNKNOWN,
    FFX_OPTICAL_FLOW_CONNECTION_INPUT,
    FFX_OPTICAL_FLOW_CONNECTION_REFERENCE,
    FFX_OPTICAL_FLOW_CONNECTION_HINT,
    FFX_OPTICAL_FLOW_CONNECTION_FLOW_VECTOR,
    FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_FLOW_VECTOR,
    FFX_OPTICAL_FLOW_CONNECTION_COST,
    FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_COST,
} FfxOpticalFlowConnectionType;

                                                       
   
                     
typedef enum FfxOpticalFlowGridSize
{
    FFX_OPTICAL_FLOW_GRID_SIZE_UNKNOWN = 0,
    FFX_OPTICAL_FLOW_GRID_SIZE_1X1     = 1,
    FFX_OPTICAL_FLOW_GRID_SIZE_2X2     = 2,
    FFX_OPTICAL_FLOW_GRID_SIZE_4X4     = 4,
    FFX_OPTICAL_FLOW_GRID_SIZE_8X8     = 8,
} FfxOpticalFlowGridSize;

                                                       
   
                     
typedef enum FfxOpticalFlowPerformanceLevel
{
    FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_UNKNOWN,
    FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW,
    FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM,
    FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST
} FfxOpticalFlowPerformanceLevel;

typedef enum FfxDataGraphOpticalFlowExecuteFlagBits
{
    FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS      = (1 << 0),
    FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_UNCHANGED             = (1 << 1),
    FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_UNCHANGED         = (1 << 2),
    FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_IS_PREVIOUS_REFERENCE = (1 << 3),
    FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_IS_PREVIOUS_INPUT = (1 << 4),
} FfxDataGraphOpticalFlowExecuteFlagBits;

                                           
   
                     
typedef enum FfxHeapType
{

    FFX_HEAP_TYPE_DEFAULT = 0,                    
    FFX_HEAP_TYPE_UPLOAD,                                              
    FFX_HEAP_TYPE_READBACK                                                
} FfxHeapType;

                                                 
   
                     
typedef enum FfxGpuJobType
{

    FFX_GPU_JOB_CLEAR_FLOAT = 0,                                                        
    FFX_GPU_JOB_COPY        = 1,                                        
    FFX_GPU_JOB_COMPUTE     = 2,                                                    
    FFX_GPU_JOB_BARRIER     = 3,                                           
    FFX_GPU_JOB_DISCARD     = 4,                                                        
    FFX_GPU_JOB_FRAGMENT    = 5,                                                 
    FFX_GPU_JOB_DATA_GRAPH  = 6,                                                   
    FFX_GPU_JOB_CLEAR_UINT  = 7                                                            
} FfxGpuJobType;

                                               
   
                     
typedef enum FfxDescriptorType
{

                                                                              
                                                                
    FFX_DESCRIPTOR_TEXTURE_SRV = 0,
    FFX_DESCRIPTOR_BUFFER_SRV,
    FFX_DESCRIPTOR_TEXTURE_UAV,
    FFX_DESCRIPTOR_BUFFER_UAV,
} FfxDescriptiorType;

                                          
   
                     
typedef enum FfxBindStage
{

    FFX_BIND_PIXEL_SHADER_STAGE   = 1 << 0,
    FFX_BIND_VERTEX_SHADER_STAGE  = 1 << 1,
    FFX_BIND_COMPUTE_SHADER_STAGE = 1 << 2,

} FfxBindStage;

                                    
   
                     
typedef enum FfxBarrierType
{
    FFX_BARRIER_TYPE_TRANSITION = 0,
    FFX_BARRIER_TYPE_UAV,
} FfxBarrierType;

                                                       
   
                     
typedef enum FfxMsgType
{
    FFX_MESSAGE_TYPE_ERROR   = 0,
    FFX_MESSAGE_TYPE_WARNING = 1,
    FFX_MESSAGE_TYPE_COUNT
} FfxMsgType;

                                                                          
   
                                                                    
   
                     
typedef enum FfxEffect
{

    FFX_EFFECT_FSR2 = 0,                                               
    FFX_EFFECT_FSR1,                                                
    FFX_EFFECT_SPD,                                                        
    FFX_EFFECT_BLUR,                                    
    FFX_EFFECT_BRIXELIZER,                                    
    FFX_EFFECT_BRIXELIZER_GI,                                    
    FFX_EFFECT_CACAO,                                                                          
    FFX_EFFECT_CAS,                                                             
    FFX_EFFECT_DENOISER,                                    
    FFX_EFFECT_LENS,                                    
    FFX_EFFECT_PARALLEL_SORT,                                    
    FFX_EFFECT_SSSR,                                                                   
    FFX_EFFECT_VARIABLE_SHADING,                                    
    FFX_EFFECT_LPM,                                                       
    FFX_EFFECT_DOF,                                               
    FFX_EFFECT_CLASSIFIER,                                    
    FFX_EFFECT_FSR3UPSCALER,                                           
    FFX_EFFECT_FRAMEINTERPOLATION,                                                                             
    FFX_EFFECT_OPTICALFLOW,                                                                             
    FFX_EFFECT_NSSPLACEHOLDER,
    FFX_EFFECT_NFRUPLACEHOLDER,
    FFX_EFFECT_ASR,
    FFX_EFFECT_NSS,
    ARM_EFFECT_FRAMEINTERPOLATION,                              
    FFX_EFFECT_CT_OPTICALFLOW,                           
    ARM_EFFECT_OPTICALFLOW,                                           

    FFX_EFFECT_SHAREDRESOURCES  = 127,                                            
    FFX_EFFECT_SHAREDAPIBACKEND = 128                                                           
} FfxEffect;

                                               
   
                     
typedef void* FfxDevice;

typedef void* FfxCommandQueue;

typedef void* FfxSwapchain;

                                                            
   
                     
typedef void* FfxCommandList;

                                   
   
                     
typedef void* FfxRootSignature;

                                                                  
   
                     
typedef void* FfxCommandSignature;

                                          
   
                     
typedef void* FfxPipeline;

                             
   
                                                                 
                                   
   
                                                                        
   
           
                                                         
           
                                                                         
   
                     
typedef void* (*FfxAllocFunc)(size_t size);

                               
   
                                                                                   
                        
                                                              
                                                      
   
                                                                          
                                                                        
   
           
                                                         
           
                                                                         
   
                     
typedef void* (*FfxReallocFunc)(void* ptr, size_t size);

                         
   
                                                               
                                                   
   
                                                                 
   
                     
typedef void (*FfxFreeFunc)(void* ptr);

                                                            
   
                     
typedef struct FfxAllocationCallbacks
{
    FfxAllocFunc   fpAlloc;                                                       
    FfxReallocFunc fpRealloc;                                                       
    FfxFreeFunc    fpFree;                                                               
} FfxAllocationCallbacks;

                                                                                 
   
                     
typedef struct FfxEffectBindlessConfig
{
    uint32_t maxTextureSrvs;                                                                   
    uint32_t maxBufferSrvs;                                                                   
    uint32_t maxTextureUavs;                                                                   
    uint32_t maxBufferUavs;                                                                   
} FfxEffectBindlessConfig;

                                                                                 
   
                     
typedef void* FfxDataGraphPipelineSession;

                                                                  
   
                     
typedef struct FfxDeviceCapabilities
{
    FfxShaderModel maximumSupportedShaderModel;                                                                       
    uint32_t       waveLaneCountMin;                                                                       
    uint32_t       waveLaneCountMax;                                                                       
    bool           fp16Supported;                                                                         
    bool           raytracingSupported;                                                              
    bool           deviceCoherentMemorySupported;                                                            
    bool           dedicatedAllocationSupported;                                                                             
    bool           bufferMarkerSupported;                                                                   
    bool           extendedSynchronizationSupported;                                                                        
    bool           shaderStorageBufferArrayNonUniformIndexing;                                                                            
    bool           tensorSupported;                                                              
    bool           computeSupportTensor;                                                                          
    bool           fragmentSupportTensor;                                                                          
    bool           dataGraphSupported;                                                               
    bool           dataGraphOFSupported;                                                                         
    bool           costSupported;                                                                                                           
    bool           hintSupported;                                                                                                            
    uint32_t       supportedOutputGridSizes;                                                                                                  
    uint32_t       supportedHintGridSizes;                                                                                                  
    uint32_t       dataGraphOFMinWidth;                                                                            
    uint32_t       dataGraphOFMinHeight;                                                                            
    uint32_t       dataGraphOFMaxWidth;                                                                                
    uint32_t       dataGraphOFMaxHeight;                                                                                
} FfxDeviceCapabilities;

                                                                                   
   
                     
typedef struct FfxDimensions2D
{
    uint32_t width;                                           
    uint32_t height;                                           
} FfxDimensions2D;

                                       
   
                     
struct FfxTensorInfo
{
    uint32_t width;                                              
    uint32_t height;                                              
    uint32_t channels;                                   
    uint32_t shapeSize;                                           
};

                                                    
   
                     
typedef struct FfxIntCoords2D
{
    int32_t x;                                                 
    int32_t y;                                                 
} FfxIntCoords2D;

                                                   
   
                     
typedef struct FfxRect2D
{
    int32_t left;                             
    int32_t top;                             
    int32_t width;                  
    int32_t height;                  
} FfxRect2D;

                                                                                
   
                     
typedef struct FfxFloatCoords2D
{
    float x;                                                 
    float y;                                                 
} FfxFloatCoords2D;

                                      
   
                     
typedef struct FfxResourceDescription
{
    FfxResourceType  type;                                  
    FfxSurfaceFormat format;                          
    union
    {
        uint32_t width;                                         
        uint32_t size;                                        
    };

    union
    {
        uint32_t height;                                                 
        uint32_t stride;                                         
    };

    union
    {
        uint32_t depth;                                                    
        uint32_t alignment;                                            
        uint32_t channel;                                        
    };

    uint32_t         mipCount;                                               
    FfxResourceFlags flags;                                                        
    FfxResourceUsage usage;                               

    uint32_t batchSize;                                    
    uint32_t shapeSize;                                    

} FfxResourceDescription;

                                                     
   
                     
typedef struct FfxResource
{
    void*                  resource;                               
    FfxResourceDescription description;
    FfxResourceStates      state;
    char                   name[FFX_RESOURCE_NAME_SIZE];                                
} FfxResource;

                                             
   
                     
typedef struct FfxStaticResourceDescription
{
    const FfxResource* resource;                                       
    FfxDescriptorType  descriptorType;                                         
    uint32_t           descriptorIndex;                                                                       

    union
    {
        uint32_t bufferOffset;                                   
        uint32_t textureUavMip;                                                           
    };

    uint32_t bufferSize;                                  
    uint32_t bufferStride;                                  
} FfxStaticResourceDescription;

                                                        
   
                     
typedef struct FfxConstantAllocation
{
    FfxResource resource;                                                              
    FfxUInt64   handle;                                                   

} FfxRootConstantAllocation;

                                                                   
   
                                                                      
   
                                                                    
                                                                                
   
   
                     
typedef FfxConstantAllocation (*FfxConstantBufferAllocator)(void* data, const FfxUInt64 dataSize);

                                                                              
   
                     
typedef struct FfxResourceInternal
{
    int32_t  internalIndex = 0;                                 
    uint32_t alignedWidth =
        0;                                                                                                                                                    
} FfxResourceInternal;

                                                                  
   
                     
typedef enum FfxResourceInitDataType
{
    FFX_RESOURCE_INIT_DATA_TYPE_INVALID = 0,
    FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED,
    FFX_RESOURCE_INIT_DATA_TYPE_BUFFER,
    FFX_RESOURCE_INIT_DATA_TYPE_VALUE,
} FfxResourceInitDataType;

                                                                       
   
                     
typedef struct FfxResourceInitData
{
    FfxResourceInitDataType type;                                                                                                       
    size_t                  size;                                                                      
    union
    {
        void*         buffer;                                                  
        unsigned char value;                                                                      
    };

    static FfxResourceInitData FfxResourceInitValue(size_t dataSize, uint8_t initVal)
    {
        FfxResourceInitData initData = {FFX_RESOURCE_INIT_DATA_TYPE_VALUE};
        initData.size                = dataSize;
        initData.value               = initVal;
        return initData;
    }

    static FfxResourceInitData FfxResourceInitBuffer(size_t dataSize, void* pInitData)
    {
        FfxResourceInitData initData = {FFX_RESOURCE_INIT_DATA_TYPE_BUFFER};
        initData.size                = dataSize;
        initData.buffer              = pInitData;
        return initData;
    }

} FfxResourceInitData;

                                                                                      
   
                     
typedef struct FfxInternalResourceDescription
{
    uint32_t            id;
    const char*         name;
    FfxResourceType     type;
    FfxResourceUsage    usage;
    FfxSurfaceFormat    format;
    uint32_t            width;
    uint32_t            height;
    uint32_t            mipCount;
    FfxResourceFlags    flags;
    FfxResourceInitData initData;
    uint32_t            batchSize;
    uint32_t            channel;
    uint32_t            shapeSize;
} FfxInternalResourceDescription;

                                                                   
   
                     
typedef struct FfxDataGraphTensorInfo
{
    const char* resourceName;                                                               
    bool        bufferAliased;                                                                               
} FfxDataGraphTensorInfo;

                                           
   
                     
typedef struct FfxViewDescription
{
    bool                     uavView;                                              
    FfxResourceViewDimension viewDimension;                                
    union
    {
        int32_t mipLevel;                                                      
        int32_t firstElement;                                                           
    };

    union
    {
        int32_t arraySize;                                                                    
        int32_t elementCount;                                                                              
    };

    int32_t firstSlice;                                                              
    char    name[FFX_RESOURCE_NAME_SIZE];
} FfxViewDescription;

static FfxViewDescription s_FfxViewDescInit = {false, FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_2D, -1, -1, -1, ""};

                                              
   
                     
typedef struct FfxResourceBinding
{
    uint32_t slotIndex;                                                                  
    uint32_t arrayIndex;                                                                 
    uint32_t resourceIdentifier;                                                                                     
    char     name[FFX_RESOURCE_NAME_SIZE];                                                      
    uint32_t bindCount;
    uint32_t bindSet;
} FfxResourceBinding;

                                                            
   
                     
typedef struct FfxPipelineState
{
    FfxRootSignature            rootSignature;                                          
    uint32_t                    passId;                                                                            
    FfxCommandSignature         cmdSignature;                                                                 
    FfxPipeline                 pipeline;                                       
    FfxDataGraphPipelineSession session;                                        
    uint32_t                    uavTextureCount;                                                        
    uint32_t                    srvTextureCount;                                                        
    uint32_t                    srvBufferCount;                                                       
    uint32_t                    uavBufferCount;                                                        
    uint32_t                    staticTextureSrvCount;                                                         
    uint32_t                    staticBufferSrvCount;                                                         
    uint32_t                    staticTextureUavCount;                                                         
    uint32_t                    staticBufferUavCount;                                                         
    uint32_t                    constCount;                                                                 
    uint32_t                    rtCount;
    uint32_t                    uavTensorCount;
    uint32_t                    srvTensorCount;

    FfxResourceBinding uavTextureBindings[FFX_MAX_NUM_UAVS];                                                                      
    FfxResourceBinding srvTextureBindings[FFX_MAX_NUM_SRVS];                                                                      
    FfxResourceBinding srvBufferBindings[FFX_MAX_NUM_SRVS];                                                                      
    FfxResourceBinding uavBufferBindings[FFX_MAX_NUM_UAVS];                                                                      
    FfxResourceBinding constantBufferBindings[FFX_MAX_NUM_CONST_BUFFERS];                                                
    FfxResourceBinding rtBindings[FFX_MAX_NUM_RTS];                                                                                

                                                                                       
                                                                                                          
    FfxResourceBinding srvTensorBindings[FFX_MAX_NUM_TENSORS];                                                        
    FfxResourceBinding uavTensorBindings[FFX_MAX_NUM_TENSORS];                                                        

    char name[FFX_RESOURCE_NAME_SIZE];                                                     
} FfxPipelineState;

                                                                  
   
                     
typedef struct FfxCreateResourceDescription
{
    FfxHeapType            heapType;                                                                                                    
    FfxResourceDescription resourceDescription;                              
    FfxResourceStates      initialState;                                         
    const char*            name;                                           
    uint32_t               id;                                             
    FfxResourceInitData    initData;                                                              
} FfxCreateResourceDescription;

                                                                       
   
                     
typedef struct FfxSamplerDescription
{
    FfxFilterType  filter;
    FfxAddressMode addressModeU;
    FfxAddressMode addressModeV;
    FfxAddressMode addressModeW;
    FfxBindStage   stage;
    FfxBoolean     unnormalizedCoordinates;
} FfxSamplerDescription;

                                                                                    
   
                     
typedef struct FfxRootConstantDescription
{
    uint32_t     size;
    FfxBindStage stage;
} FfxRootConstantDescription;

                                                           
                                        
   
                                                                             
                                                                                         
                                                                               
                                                   
                                                                          
                                                         
   
                                                                            
                                                                          
                                                                                
                                                                    
                                                                                   
                                                                               
                                   
   
                                                                                     
                                                                           
                                                                             
                                                                         
                                                                       
                                                                              
                                                                 
       
                     
typedef struct FfxPipelineDescription
{
    uint32_t                          contextFlags;                                                                                                 
    const FfxSamplerDescription*      samplers;                                                                                             
    size_t                            samplerCount;                                                     
    const FfxRootConstantDescription* rootConstants;                                                                                                          
    uint32_t                          rootConstantBufferCount;                                                                      
    char                              name[FFX_RESOURCE_NAME_SIZE];                                                           
    FfxBindStage                      stage;                                                                                 
    uint32_t                          indirectWorkload;                                                                 
    FfxSurfaceFormat                  backbufferFormat;                                                                           
    const FfxDataGraphTensorInfo*     dataGraphTensorInfo;                                                                              
    uint32_t                          dataGraphTensorInfoCount;                                                                   
} FfxPipelineDescription;

                                                                
   
                     
typedef struct FfxBarrierDescription
{
    FfxResourceInternal resource;                                       
    FfxBarrierType      barrierType;                                       
    FfxResourceStates   currentState;                                         
    FfxResourceStates   newState;                                                       
    uint32_t            subResourceID;                                                       
} FfxBarrierDescription;

                                             
   
                     
typedef struct FfxConstantBuffer
{
    uint32_t  num32BitEntries;                                                            
    uint32_t* data;                                                 
} FfxConstantBuffer;

                                                  
typedef struct FfxTextureSRV
{
    FfxResourceInternal resource;                                                          
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxTextureSRV;

typedef struct FfxTensor
{
    FfxResourceInternal resource;                                            
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxTensor;

                                                  
typedef struct FfxBufferSRV
{
    uint32_t            offset;                                             
    uint32_t            size;                                             
    uint32_t            stride;                                           
    FfxResourceInternal resource;                                                          
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxBufferSRV;

                                                   
typedef struct FfxTextureUAV
{
    uint32_t            mip;                                          
    FfxResourceInternal resource;                                                           
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxTextureUAV;

                                                        
typedef struct FfxTextureRT
{
    FfxResourceInternal resource;                                                        
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxTextureRT;

                                                   
typedef struct FfxBufferUAV
{
    uint32_t            offset;                                             
    uint32_t            size;                                             
    uint32_t            stride;                                           
    FfxResourceInternal resource;                                                           
#ifdef FFX_DEBUG
    char name[FFX_RESOURCE_NAME_SIZE];
#endif
} FfxBufferUAV;

                                              
   
                     
typedef struct FfxClearFloatJobDescription
{
    float               color[4];                                       
    FfxResourceInternal target;                                    
} FfxClearFloatJobDescription;

                                                
   
                     
typedef struct FfxComputeJobDescription
{
    FfxPipelineState    pipeline;                                                                  
    uint32_t            dimensions[3];                                             
    FfxResourceInternal cmdArgument;                                                                
    uint32_t            cmdArgumentOffset;                                                                            
    FfxTextureSRV       srvTextures[FFX_MAX_NUM_SRVS];                                                              
    FfxBufferSRV        srvBuffers[FFX_MAX_NUM_SRVS];                                                              
    FfxTextureUAV       uavTextures[FFX_MAX_NUM_UAVS];                                                              
    FfxBufferUAV        uavBuffers[FFX_MAX_NUM_UAVS];                                                              
    FfxTensor           srvTensors[FFX_MAX_NUM_TENSORS];                                                           
    FfxTensor           uavTensors[FFX_MAX_NUM_TENSORS];                                                           

    FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                       
#ifdef FFX_DEBUG
    char cbNames[FFX_MAX_NUM_CONST_BUFFERS][FFX_RESOURCE_NAME_SIZE];

    char srvTextureNames[FFX_MAX_NUM_SRVS][64];
    char uavTextureNames[FFX_MAX_NUM_UAVS][64];
    char srvBufferNames[FFX_MAX_NUM_SRVS][64];
    char uavBufferNames[FFX_MAX_NUM_UAVS][64];
    char sampledTextureNames[FFX_MAX_NUM_SRVS][64];
    char tensorNames[FFX_MAX_NUM_TENSORS][64];
#endif
    uint32_t uavTextureMips[FFX_MAX_NUM_UAVS];                                                                         
} FfxComputeJobDescription;

                                                 
   
                     
typedef struct FfxFragmentJobDescription
{
    FfxPipelineState  pipeline;                                                                   
    uint32_t          viewport[2];                                               
    FfxTextureSRV     srvTextures[FFX_MAX_NUM_SRVS];                                                               
    FfxBufferSRV      srvBuffers[FFX_MAX_NUM_SRVS];                                                               
    FfxTextureUAV     uavTextures[FFX_MAX_NUM_UAVS];                                                               
    FfxTextureRT      rtTextures[FFX_MAX_NUM_RTS];                                                                
    FfxBufferUAV      uavBuffers[FFX_MAX_NUM_UAVS];                                                               
    FfxTensor         srvTensors[FFX_MAX_NUM_TENSORS];                                                            
    FfxTensor         uavTensors[FFX_MAX_NUM_TENSORS];                                                            
    FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                         
#ifdef FFX_DEBUG
    char cbNames[FFX_MAX_NUM_CONST_BUFFERS][FFX_RESOURCE_NAME_SIZE];
#endif
} FfxFragmentJobDescription;

                                                                                                
                                       
   
                     
typedef struct FfxRasterJobDescription
{
                                                                                                   
    FfxPipelineState    pipeline;                                          
    uint32_t            numVertices;
    FfxResourceInternal renderTarget;
    FfxTextureSRV       srvTextures[FFX_MAX_NUM_SRVS];                                                            
    FfxTextureUAV       uavTextures[FFX_MAX_NUM_UAVS];                                                            

    FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                       
#ifdef FFX_DEBUG
    char cbNames[FFX_MAX_NUM_CONST_BUFFERS][FFX_RESOURCE_NAME_SIZE];
#endif
} FfxRasterJobDescription;

                                            
   
                     
typedef struct FfxDataGraphJobDescription
{
    FfxPipelineState pipeline;                                                                     
    FfxTensor        srvTensors[FFX_MAX_NUM_TENSORS];                                                           
    FfxTensor        uavTensors[FFX_MAX_NUM_TENSORS];                                                           
    FfxTextureSRV    srvTextures[FFX_MAX_NUM_SRVS];                                                                 
    FfxTextureUAV    uavTextures[FFX_MAX_NUM_UAVS];                                                                 
    uint32_t         opticalFlowExecuteFlags;                                                   
    FfxResourceInternal gameMotionVectors;                                                                                
    FfxResourceInternal gameDepth;                                                                                       
    FfxResourceInternal gamePreviousDepth;                                                                              
    FfxFloat32x4x4 gamePreviousToCurrentClip;                                                
    FfxFloatCoords2D gameMotionVectorUvScale;                                                           
    uint32_t         meanFlowL1NormHint;                                                                             
} FfxDataGraphJobDescription;

                                                           
   
                     
typedef enum FfxCopyJobMode
{

    FFX_GPU_COPY_SRC_EXTENT = 0,                                                                     
    FFX_GPU_COPY_DST_EXTENT = 1,                                                                          
    FFX_GPU_COPY_MIN_EXTENT = 2,                                                                                              
} FfxCopyJobMode;

                                             
   
                     
typedef struct FfxCopyJobDescription
{
    FfxResourceInternal src;                                          
    uint32_t            srcOffset;                                              
    FfxResourceInternal dst;                                               
    uint32_t            dstOffset;                                                   
    uint32_t            size;                                                                     
    FfxCopyJobMode      copyMode;                                                  
} FfxCopyJobDescription;

typedef struct FfxDiscardJobDescription
{
    FfxResourceInternal target;                                    
} FfxDiscardJobDescription;

                                              
   
                     
typedef struct FfxClearUintJobDescription
{
    uint32_t            color[4];                                       
    FfxResourceInternal target;                                    
} FfxClearUintJobDescription;

                                               
   
                     
typedef struct FfxGpuJobDescription
{
    FfxGpuJobType jobType;                       
#ifdef FFX_DEBUG
    char jobLabel[FFX_RESOURCE_NAME_SIZE];                            
#endif

    union
    {
        FfxClearFloatJobDescription
                                  clearJobDescriptor;                                                                                                          
        FfxCopyJobDescription     copyJobDescriptor;                                                                                                   
        FfxComputeJobDescription  computeJobDescriptor;                                                                                                         
        FfxFragmentJobDescription fragmentJobDescriptor;                                                                                                       
        FfxRasterJobDescription   rasterJobDescriptor;
        FfxBarrierDescription     barrierDescriptor;
        FfxDiscardJobDescription  discardJobDescriptor;
        FfxDataGraphJobDescription
            dataGraphJobDescription;                                                                                                           
        FfxClearUintJobDescription
            clearUintJobDescriptor;                                                                                                         
    };
} FfxGpuJobDescription;

#if defined(POPULATE_SHADER_BLOB_FFX)
#undef POPULATE_SHADER_BLOB_FFX
#endif                                          

                                                                                                  
#define POPULATE_SHADER_BLOB_FFX(info, index)                                                                                                                  \
    {                                                                                                                                                          \
        info[index].blobData, info[index].blobSize, info[index].numConstantBuffers, info[index].numSRVTextures, info[index].numUAVTextures,                    \
            info[index].numSRVBuffers, info[index].numUAVBuffers, info[index].numSamplers, info[index].numRTAccelerationStructures, info[index].numRTTextures, \
            info[index].numSRVTensors, info[index].numUAVTensors, info[index].constantBufferNames, info[index].constantBufferBindings,                         \
            info[index].constantBufferCounts, info[index].constantBufferSpaces, info[index].srvTextureNames, info[index].srvTextureBindings,                   \
            info[index].srvTextureCounts, info[index].srvTextureSpaces, info[index].uavTextureNames, info[index].uavTextureBindings,                           \
            info[index].uavTextureCounts, info[index].uavTextureSpaces, info[index].srvBufferNames, info[index].srvBufferBindings,                             \
            info[index].srvBufferCounts, info[index].srvBufferSpaces, info[index].uavBufferNames, info[index].uavBufferBindings, info[index].uavBufferCounts,  \
            info[index].uavBufferSpaces, info[index].samplerNames, info[index].samplerBindings, info[index].samplerCounts, info[index].samplerSpaces,          \
            info[index].rtAccelerationStructureNames, info[index].rtAccelerationStructureBindings, info[index].rtAccelerationStructureCounts,                  \
            info[index].rtAccelerationStructureSpaces, info[index].rtTextureNames, info[index].rtTextureBindings, info[index].rtTextureCounts,                 \
            info[index].rtTextureSpaces, info[index].srvTensorNames, info[index].srvTensorBindings, info[index].srvTensorCounts, info[index].srvTensorSpaces,  \
            info[index].uavTensorNames, info[index].uavTensorBindings, info[index].uavTensorCounts, info[index].uavTensorSpaces                                \
    }

                                                           
   
                     
typedef struct FfxShaderBlob
{
    const uint8_t* data;                          
    const uint32_t size;                   

    const uint32_t cbvCount;                             
    const uint32_t srvTextureCount;                               
    const uint32_t uavTextureCount;                               
    const uint32_t srvBufferCount;                               
    const uint32_t uavBufferCount;                               
    const uint32_t samplerCount;                              
    const uint32_t rtAccelStructCount;                                          
    const uint32_t rtTextureCount;                                         
    const uint32_t srvTensorCount;                           
    const uint32_t uavTensorCount;                           

                       
    const char**    boundConstantBufferNames;
    const uint32_t* boundConstantBuffers;                                                       
    const uint32_t* boundConstantBufferCounts;                                                                
    const uint32_t* boundConstantBufferSpaces;                                                                         

                   
    const char**    boundSRVTextureNames;
    const uint32_t* boundSRVTextures;                                                     
    const uint32_t* boundSRVTextureCounts;                                                     
    const uint32_t* boundSRVTextureSpaces;                                                              

                   
    const char**    boundUAVTextureNames;
    const uint32_t* boundUAVTextures;                                                             
    const uint32_t* boundUAVTextureCounts;                                                             
    const uint32_t* boundUAVTextureSpaces;                                                                      

                  
    const char**    boundSRVBufferNames;
    const uint32_t* boundSRVBuffers;                                                            
    const uint32_t* boundSRVBufferCounts;                                                            
    const uint32_t* boundSRVBufferSpaces;                                                                     

                  
    const char**    boundUAVBufferNames;
    const uint32_t* boundUAVBuffers;                                                            
    const uint32_t* boundUAVBufferCounts;                                                            
    const uint32_t* boundUAVBufferSpaces;                                                                     

               
    const char**    boundSamplerNames;
    const uint32_t* boundSamplers;                                                         
    const uint32_t* boundSamplerCounts;                                                         
    const uint32_t* boundSamplerSpaces;                                                                  

                                 
    const char**    boundRTAccelerationStructureNames;
    const uint32_t* boundRTAccelerationStructures;                                                            
    const uint32_t* boundRTAccelerationStructureCounts;                                                            
    const uint32_t* boundRTAccelerationStructureSpaces;                                                                     

                  
    const char**    boundRTTextureNames;
    const uint32_t* boundRTTextures;                                                            
    const uint32_t* boundRTTextureCounts;                                                            
    const uint32_t* boundRTTextureSpaces;                                                                     

              
    const char**    boundSRVTensorNames;
    const uint32_t* boundSRVTensors;                                                        
    const uint32_t* boundSRVTensorCounts;                                                        
    const uint32_t* boundSRVTensorSpaces;                                                                 

              
    const char**    boundUAVTensorNames;
    const uint32_t* boundUAVTensors;                                                        
    const uint32_t* boundUAVTensorCounts;                                                        
    const uint32_t* boundUAVTensorSpaces;                                                                 

} FfxShaderBlob;

typedef struct FfxDataGraphBlob
{
    const uint32_t        constantNums;
    const uint32_t*       constantIds;
    const uint32_t*       constantFormats;
    const uint32_t*       constantShapeSize;
    const int64_t**       constantShapes;
    const int64_t*        constantSparsityDimensions;
    const uint32_t*       constantDataSize;
    const unsigned char** constantDatas;

    const char*          graphEntryPoint;
    const uint32_t       graphDataSize;
    const unsigned char* graphData;

    const uint32_t  inputTensorNums;
    const char**    inputTensorNames;
    const uint32_t* inputTensorSets;
    const uint32_t* inputTensorBindings;
    const uint32_t* inputTensorFormats;
    const uint32_t* inputTensorDimSize;
    const int64_t** inputTensorDims;

    const uint32_t  outputTensorNums;
    const char**    outputTensorNames;
    const uint32_t* outputTensorSets;
    const uint32_t* outputTensorBindings;
    const uint32_t* outputTensorFormats;
    const uint32_t* outputTensorDimSize;
    const int64_t** outputTensorDims;
} FfxDataGraphBlob;

                                                           
   
                     
typedef struct FfxOpticalFlowDescription
{
    uint32_t srvTextureCount;                            
    uint32_t uavTextureCount;                            
    uint32_t srvTensorCount;                            
    uint32_t uavTensorCount;                            

                   
    const char**                  boundSRVTextureNames;
    uint32_t*                     boundSRVTextures;                                                             
    uint32_t*                     boundSRVTextureCounts;                                                             
    uint32_t*                     boundSRVTextureSpaces;                                                                      
    FfxOpticalFlowConnectionType* boundSRVTextureConnectionType;                                                               
    FfxSurfaceFormat*             boundSRVTextureFormats;

                   
    const char**                  boundUAVTextureNames;
    uint32_t*                     boundUAVTextures;                                                                     
    uint32_t*                     boundUAVTextureCounts;                                                                     
    uint32_t*                     boundUAVTextureSpaces;                                                                              
    FfxOpticalFlowConnectionType* boundUAVTextureConnectionType;                                                               
    FfxSurfaceFormat*             boundUAVTextureFormats;

                  
    const char**                  boundSRVTensorNames;
    uint32_t*                     boundSRVTensors;                                                                    
    uint32_t*                     boundSRVTensorCounts;                                                                    
    uint32_t*                     boundSRVTensorSpaces;                                                                             
    FfxOpticalFlowConnectionType* boundSRVTensorConnectionType;                                                             
    FfxSurfaceFormat*             boundSRVTensorFormats;

                  
    const char**                  boundUAVTensorNames;
    uint32_t*                     boundUAVTensors;                                                                    
    uint32_t*                     boundUAVTensorCounts;                                                                    
    uint32_t*                     boundUAVTensorSpaces;                                                                             
    FfxOpticalFlowConnectionType* boundUAVTensorConnectionType;                                                             
    FfxSurfaceFormat*             boundUAVTensorFormats;

                  
    FfxDimensions2D                dimensions;
    FfxOpticalFlowGridSize         gridSize;
    FfxOpticalFlowPerformanceLevel performanceLevel;

} FfxOpticalFlowDescription;

                                                         
                                                                
   
                     
typedef struct FfxPresentCallbackDescription
{
    FfxDevice      device;                                       
    FfxCommandList commandList;                                                                      
    FfxResource    currentBackBuffer;                                                         
    FfxResource    currentUI;                                                                         
    FfxResource    outputSwapChainBuffer;                                                               
    bool           isInterpolatedFrame;                                                      
    bool           usePremulAlpha;                                                                         
    uint64_t       frameID;
} FfxPresentCallbackDescription;

                                                                             
   
                     
typedef struct FfxFrameGenerationDispatchDescription
{
    FfxCommandList commandList;                                                                      
    FfxResource    presentColor;                                                                                               
    FfxResource    outputs[4];                                                                                               
    uint32_t       numInterpolatedFrames;                                                                          
    bool           reset;                                                                                                              
    uint64_t       frameID;
} FfxFrameGenerationDispatchDescription;

                                                   
typedef struct FfxEffectMemoryUsage
{
    uint64_t totalUsageInBytes;
    uint64_t aliasableUsageInBytes;
} FfxEffectMemoryUsage;

                                                            
typedef struct FfxSwapchainFramePacingTuning
{
    float safetyMarginInMs;                   
    float varianceFactor;                            
    bool  allowHybridSpin;                                     
    uint32_t
         hybridSpinTime;                                                                                                                                                       
    bool allowWaitForSingleObjectOnFence;                                                                             
} FfxSwapchainFramePacingTuning;

#ifdef __cplusplus
}
#endif                       
