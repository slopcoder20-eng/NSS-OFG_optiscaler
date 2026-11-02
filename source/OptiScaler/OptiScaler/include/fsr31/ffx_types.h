// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2023 Advanced Micro Devices, Inc. All rights reserved.
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

#pragma warning(disable : 4005)

namespace Fsr31
{
   
                        
                      
   

                          
                                                 
   
                   

                             
                                                
   
                    

#if defined(FFX_GCC)
                                 
   
                    
#define FFX_API
#else
                                 
   
                    
#define FFX_API __declspec(dllexport)
#endif                         

#define FFX_SDK_DEFAULT_CONTEXT_SIZE (1024 * 128)

                                                          
   
                    
#define FFX_MAX_NUM_SRVS 16

                                                          
   
                    
#define FFX_MAX_NUM_UAVS 16

                                             
   
                    
#define FFX_MAX_NUM_CONST_BUFFERS 3

                                           
#define FFX_MAX_CONST_SIZE 256

                                                   
   
                    
#define FFX_RESOURCE_NAME_SIZE 64

                                                  
   
                    
#define FFX_MAX_QUEUED_FRAMES (4)

                                                  
   
                    
#define FFX_MAX_RESOURCE_COUNT (128)

                                                 
   
                    
#define FFX_MAX_PASS_COUNT (50)

                                                             
   
                    
#define FFX_RING_BUFFER_SIZE (FFX_MAX_QUEUED_FRAMES * FFX_MAX_PASS_COUNT * FFX_MAX_RESOURCE_COUNT)

                                                          
   
                    
#define FFX_BUFFER_SIZE (768)

                                                             
   
                    
#define FFX_RING_BUFFER_MEM_BLOCK_SIZE (FFX_RING_BUFFER_SIZE * FFX_BUFFER_SIZE)

                                        
   
                    
#define FFX_MAX_BARRIERS (16)

                                             
   
                    
#define FFX_MAX_GPU_JOBS (64)

                                        
   
                    
#define FFX_MAX_SAMPLERS (16)

                                              
   
                    
#define UPLOAD_JOB_COUNT (16)

                          
#pragma warning(disable : 4365 4710 4820 5039)

#ifdef __cplusplus
extern "C"
{
#endif                      

                                    
                                                             
       
                        

                                      
       
                         
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

                                                             
       
                         
    typedef uint32_t FfxUInt32x2[2];

                                                             
       
                         
    typedef uint32_t FfxUInt32x3[3];

                                                             
       
                         
    typedef uint32_t FfxUInt32x4[4];

                                    
                                                                        
       
                        

                                          
       
                         
    typedef enum FfxSurfaceFormat
    {

        FFX_SURFACE_FORMAT_UNKNOWN,                                  
        FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS,                                                   
        FFX_SURFACE_FORMAT_R32G32B32A32_UINT,                                                   
        FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT,                                                   
        FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT,                                                   
        FFX_SURFACE_FORMAT_R32G32_FLOAT,                                                         
        FFX_SURFACE_FORMAT_R8_UINT,                                                             
        FFX_SURFACE_FORMAT_R32_UINT,                                                             
        FFX_SURFACE_FORMAT_R10G10B10A2_UNORM,                                                                     
                                                                        
        FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS,                                                    
        FFX_SURFACE_FORMAT_R8G8B8A8_UNORM,                                                                     
        FFX_SURFACE_FORMAT_R8G8B8A8_SNORM,                                                                   
        FFX_SURFACE_FORMAT_R8G8B8A8_SRGB,                                                           
        FFX_SURFACE_FORMAT_R11G11B10_FLOAT,                                         
        FFX_SURFACE_FORMAT_R16G16_FLOAT,                                                         
        FFX_SURFACE_FORMAT_R16G16_UINT,                                                                 
        FFX_SURFACE_FORMAT_R16G16_SINT,                                                               
        FFX_SURFACE_FORMAT_R16_FLOAT,                                                            
        FFX_SURFACE_FORMAT_R16_UINT,                                                                    
        FFX_SURFACE_FORMAT_R16_UNORM,                                                                          
        FFX_SURFACE_FORMAT_R16_SNORM,                                                                        
        FFX_SURFACE_FORMAT_R8_UNORM,                                                                           
        FFX_SURFACE_FORMAT_R8G8_UNORM,                                                                         
        FFX_SURFACE_FORMAT_R8G8_UINT,                                                                       
        FFX_SURFACE_FORMAT_R32_FLOAT                                                             
    } FfxSurfaceFormat;

                                         
       
                         
    typedef enum FfxResourceUsage
    {

        FFX_RESOURCE_USAGE_READ_ONLY = 0,                                                                
        FFX_RESOURCE_USAGE_RENDERTARGET = (1 << 0),                                                         
        FFX_RESOURCE_USAGE_UAV = (1 << 1),                                                        
        FFX_RESOURCE_USAGE_DEPTHTARGET = (1 << 2),                                                         
        FFX_RESOURCE_USAGE_INDIRECT = (1 << 3),                                                                       
        FFX_RESOURCE_USAGE_ARRAYVIEW =
            (1 << 4),                                                                                           
    } FfxResourceUsage;

                                          
       
                         
    typedef enum FfxResourceStates
    {

        FFX_RESOURCE_STATE_COMMON = (1 << 0),
        FFX_RESOURCE_STATE_UNORDERED_ACCESS = (1 << 1),                                                             
        FFX_RESOURCE_STATE_COMPUTE_READ =
            (1 << 2),                                                                         
        FFX_RESOURCE_STATE_PIXEL_READ = (1 << 3),                                                                       
        FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ =
            (FFX_RESOURCE_STATE_PIXEL_READ |
             FFX_RESOURCE_STATE_COMPUTE_READ),                                                                         
                                                            
        FFX_RESOURCE_STATE_COPY_SRC =
            (1 << 4),                                                                                  
        FFX_RESOURCE_STATE_COPY_DEST =
            (1 << 5),                                                                                       
        FFX_RESOURCE_STATE_GENERIC_READ =
            (FFX_RESOURCE_STATE_COPY_SRC |
             FFX_RESOURCE_STATE_COMPUTE_READ),                                                           
        FFX_RESOURCE_STATE_INDIRECT_ARGUMENT =
            (1 << 6),                                                                                     
        FFX_RESOURCE_STATE_PRESENT =
            (1 << 7),                                                                                  
        FFX_RESOURCE_STATE_RENDER_TARGET =
            (1 << 8),                                                                      
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

        FFX_RESOURCE_FLAGS_NONE = 0,               
        FFX_RESOURCE_FLAGS_ALIASABLE =
            (1 << 0),                                                                         
        FFX_RESOURCE_FLAGS_UNDEFINED =
            (1 << 1),                                                                                              
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
        FFX_GPU_JOB_BARRIER = 3,                                              

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

        FFX_BIND_PIXEL_SHADER_STAGE = 1 << 0,
        FFX_BIND_VERTEX_SHADER_STAGE = 1 << 1,
        FFX_BIND_COMPUTE_SHADER_STAGE = 1 << 2,

    } FfxBindStage;

                                        
       
                         
    typedef enum FfxBarrierType
    {
        FFX_BARRIER_TYPE_TRANSITION = 0,
        FFX_BARRIER_TYPE_UAV,
    } FfxBarrierType;

                                                           
       
                         
    typedef enum FfxMsgType
    {
        FFX_MESSAGE_TYPE_ERROR = 0,
        FFX_MESSAGE_TYPE_WARNING = 1,
        FFX_MESSAGE_TYPE_COUNT
    } FfxMsgType;

                                                                              
       
                                                                        
       
                             
    typedef enum FfxEffect
    {

        FFX_EFFECT_FSR2 = 0,                                              
        FFX_EFFECT_FSR1,                                               
        FFX_EFFECT_SPD,                                                       
        FFX_EFFECT_BLUR,                                   
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

    } FfxEffect;

    typedef enum FfxBackbufferTransferFunction
    {
        FFX_BACKBUFFER_TRANSFER_FUNCTION_SRGB,
        FFX_BACKBUFFER_TRANSFER_FUNCTION_PQ,
        FFX_BACKBUFFER_TRANSFER_FUNCTION_SCRGB
    } FfxBackbufferTransferFunction;

                                                   
       
                         
    typedef void* FfxDevice;

    typedef void* FfxCommandQueue;

    typedef void* FfxSwapchain;

                                                                
       
                         
    typedef void* FfxCommandList;

                                       
       
                         
    typedef void* FfxRootSignature;

                                                                      
       
                         
    typedef void* FfxCommandSignature;

                                              
       
                         
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

        FfxResourceType type;                                  
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
        };

        uint32_t mipCount;                                                   
        FfxResourceFlags flags;                                                    
        FfxResourceUsage usage;                           
    } FfxResourceDescription;

                                                         
       
                         
    typedef struct FfxResource
    {
        void* resource;                              
        FfxResourceDescription description;
        FfxResourceStates state;
        wchar_t name[FFX_RESOURCE_NAME_SIZE];                               
    } FfxResource;

                                                                                  
       
                         
    typedef struct FfxResourceInternal
    {
        int32_t internalIndex;                                
    } FfxResourceInternal;

                                                                                          
       
                         
    typedef struct FfxInternalResourceDescription
    {

        uint32_t id;
        const wchar_t* name;
        FfxResourceType type;
        FfxResourceUsage usage;
        FfxSurfaceFormat format;
        uint32_t width;
        uint32_t height;
        uint32_t mipCount;
        FfxResourceFlags flags;
        uint32_t initDataSize;
        void* initData;
    } FfxInternalResourceDescription;

                                               
       
                         
    typedef struct FfxViewDescription
    {
        bool uavView;                                                                 
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
        wchar_t name[64];
    } FfxViewDescription;

    static FfxViewDescription s_FfxViewDescInit = { false, FFX_RESOURCE_VIEW_DIMENSION_TEXTURE_2D, -1, -1, -1, L"" };

                                                  
       
                         
    typedef struct FfxResourceBinding
    {
        uint32_t slotIndex;
        uint32_t resourceIdentifier;
        uint32_t bindCount;
        wchar_t name[64];
    } FfxResourceBinding;

                                                                
       
                         
    typedef struct FfxPipelineState
    {

        FfxRootSignature rootSignature;                                   
        FfxCommandSignature cmdSignature;                                                       
        FfxPipeline pipeline;                                     
        uint32_t uavTextureCount;                                                         
        uint32_t srvTextureCount;                                                         
        uint32_t srvBufferCount;                                                        
        uint32_t uavBufferCount;                                                         
        uint32_t constCount;                                                                  

        FfxResourceBinding uavTextureBindings[FFX_MAX_NUM_UAVS];                                                        
        FfxResourceBinding srvTextureBindings[FFX_MAX_NUM_SRVS];                                                        
        FfxResourceBinding srvBufferBindings[FFX_MAX_NUM_SRVS];                                                        
        FfxResourceBinding uavBufferBindings[FFX_MAX_NUM_UAVS];                                                        
        FfxResourceBinding
            constantBufferBindings[FFX_MAX_NUM_CONST_BUFFERS];                                               
    } FfxPipelineState;

                                                                      
       
                         
    typedef struct FfxCreateResourceDescription
    {

        FfxHeapType heapType;                                                                                        
        FfxResourceDescription resourceDescription;                             
        FfxResourceStates initalState;                                              
        uint32_t initDataSize;                                                       
        void* initData;                                                                              
        const wchar_t* name;                                                  
        uint32_t id;                                                          
    } FfxCreateResourceDescription;

                                                                           
       
                         
    typedef struct FfxSamplerDescription
    {

        FfxFilterType filter;
        FfxAddressMode addressModeU;
        FfxAddressMode addressModeV;
        FfxAddressMode addressModeW;
        FfxBindStage stage;
    } FfxSamplerDescription;

                                                                                        
       
                         
    typedef struct FfxRootConstantDescription
    {
        uint32_t size;
        FfxBindStage stage;
    } FfxRootConstantDescription;

                                                               
                                            
       
                                                                                 
                                                                                             
                                                                                   
                                                       
                                                                              
                                                             
       
                                                                                
                                                                              
                                                                                    
                                                                        
                                                                                       
                                                                                   
                                       
       
                                                                                         
                                                                               
                                                                                 
                                                                             
                                                                           
                                                                                  
                                                                     
           
                         
    typedef struct FfxPipelineDescription
    {

        uint32_t
            contextFlags;                                                                                               
        const FfxSamplerDescription*
            samplers;                                                                                              
        size_t samplerCount;                                                   
        const FfxRootConstantDescription* rootConstants;                                                            
                                                                                                          
        uint32_t rootConstantBufferCount;                                                                               
        wchar_t name[64];                                                                                         
        FfxBindStage stage;                                                                                      
        uint32_t indirectWorkload;                                                                          
        FfxSurfaceFormat backbufferFormat;                                                                            
    } FfxPipelineDescription;

                                                                    
       
                         
    typedef struct FfxBarrierDescription
    {
        FfxResourceInternal resource;
        FfxBarrierType barrierType;
        FfxResourceStates currentState;
        FfxResourceStates newState;
        uint32_t subResourceID;
    } FfxBarrierDescription;

                                                 
       
                         
    typedef struct FfxConstantBuffer
    {

        uint32_t num32BitEntries;                                                                    
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
        FfxResourceInternal cmdArgument;                                                             
        uint32_t cmdArgumentOffset;                                                                                    
        FfxResourceInternal srvTextures[FFX_MAX_NUM_SRVS];                                                           
        wchar_t srvTextureNames[FFX_MAX_NUM_SRVS][64];
        FfxResourceInternal uavTextures[FFX_MAX_NUM_UAVS];                                                           
        uint32_t
            uavTextureMips[FFX_MAX_NUM_UAVS];                                                                        
        wchar_t uavTextureNames[FFX_MAX_NUM_UAVS][64];
        FfxResourceInternal srvBuffers[FFX_MAX_NUM_SRVS];                                                          
        wchar_t srvBufferNames[FFX_MAX_NUM_SRVS][64];
        FfxResourceInternal uavBuffers[FFX_MAX_NUM_UAVS];                                                          
        wchar_t uavBufferNames[FFX_MAX_NUM_UAVS][64];
        FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                      
        wchar_t cbNames[FFX_MAX_NUM_CONST_BUFFERS][64];
    } FfxComputeJobDescription;

    typedef struct FfxRasterJobDescription
    {
        FfxPipelineState pipeline;                                         
        uint32_t numVertices;
        FfxResourceInternal renderTarget;

        FfxResourceInternal srvTextures[FFX_MAX_NUM_SRVS];                                                   
        wchar_t srvTextureNames[FFX_MAX_NUM_SRVS][64];
        FfxResourceInternal uavTextures[FFX_MAX_NUM_UAVS];                                                   
        uint32_t uavTextureMips[FFX_MAX_NUM_UAVS];                                                                
        wchar_t uavTextureNames[FFX_MAX_NUM_UAVS][64];
        FfxConstantBuffer cbs[FFX_MAX_NUM_CONST_BUFFERS];                                                      
        wchar_t cbNames[FFX_MAX_NUM_CONST_BUFFERS][64];
    } FfxRasterJobDescription;

                                                 
       
                         
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
                                                                                                        
            FfxRasterJobDescription rasterJobDescriptor;
            FfxBarrierDescription barrierDescriptor;
        };
    } FfxGpuJobDescription;

#if defined(POPULATE_SHADER_BLOB_FFX)
#undef POPULATE_SHADER_BLOB_FFX
#endif                                         

                                                                                                  
   
                     
#define POPULATE_SHADER_BLOB_FFX(info, index)                                                                          \
    { info[index].blobData,                                                                                            \
      info[index].blobSize,                                                                                            \
      info[index].numConstantBuffers,                                                                                  \
      info[index].numSRVTextures,                                                                                      \
      info[index].numUAVTextures,                                                                                      \
      info[index].numSRVBuffers,                                                                                       \
      info[index].numUAVBuffers,                                                                                       \
      info[index].numSamplers,                                                                                         \
      info[index].numRTAccelerationStructures,                                                                         \
      info[index].constantBufferNames,                                                                                 \
      info[index].constantBufferBindings,                                                                              \
      info[index].constantBufferCounts,                                                                                \
      info[index].srvTextureNames,                                                                                     \
      info[index].srvTextureBindings,                                                                                  \
      info[index].srvTextureCounts,                                                                                    \
      info[index].uavTextureNames,                                                                                     \
      info[index].uavTextureBindings,                                                                                  \
      info[index].uavTextureCounts,                                                                                    \
      info[index].srvBufferNames,                                                                                      \
      info[index].srvBufferBindings,                                                                                   \
      info[index].srvBufferCounts,                                                                                     \
      info[index].uavBufferNames,                                                                                      \
      info[index].uavBufferBindings,                                                                                   \
      info[index].uavBufferCounts,                                                                                     \
      info[index].samplerNames,                                                                                        \
      info[index].samplerBindings,                                                                                     \
      info[index].samplerCounts,                                                                                       \
      info[index].rtAccelerationStructureNames,                                                                        \
      info[index].rtAccelerationStructureBindings,                                                                     \
      info[index].rtAccelerationStructureCounts }

                                                               
       
                         
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

                           
        const char** boundConstantBufferNames;
        const uint32_t* boundConstantBuffers;                                                      
        const uint32_t* boundConstantBufferCounts;                                                               

                       
        const char** boundSRVTextureNames;
        const uint32_t* boundSRVTextures;                                                    
        const uint32_t* boundSRVTextureCounts;                                                    

                       
        const char** boundUAVTextureNames;
        const uint32_t* boundUAVTextures;                                                            
        const uint32_t* boundUAVTextureCounts;                                                            

                      
        const char** boundSRVBufferNames;
        const uint32_t* boundSRVBuffers;                                                           
        const uint32_t* boundSRVBufferCounts;                                                           

                      
        const char** boundUAVBufferNames;
        const uint32_t* boundUAVBuffers;                                                           
        const uint32_t* boundUAVBufferCounts;                                                           

                   
        const char** boundSamplerNames;
        const uint32_t* boundSamplers;                                                        
        const uint32_t* boundSamplerCounts;                                                        

                                     
        const char** boundRTAccelerationStructureNames;
        const uint32_t* boundRTAccelerationStructures;                                                           
        const uint32_t* boundRTAccelerationStructureCounts;                                                           

    } FfxShaderBlob;

    typedef struct FfxPresentCallbackDescription
    {
        FfxDevice device;
        FfxCommandList commandList;
        FfxResource currentBackBuffer;
        FfxResource currentUI;
        FfxResource outputSwapChainBuffer;
        bool isInterpolatedFrame;
    } FfxPresentCallbackDescription;

    typedef struct FfxFrameGenerationDispatchDescription
    {
        FfxCommandList commandList;                                                           
        FfxResource presentColor;                                                                                       
        FfxResource outputs[4];                                                                                       
        uint32_t numInterpolatedFrames;                                                                         
        bool reset;                                                                                             
        FfxBackbufferTransferFunction backBufferTransferFunction;                                          
                                                                                                                     
        float minMaxLuminance[2];                                                                                    
        FfxRect2D interpolationRect;                                                                                   
                                                                                             
        uint64_t frameID;
    } FfxFrameGenerationDispatchDescription;

#ifdef __cplusplus
}
#endif                      
}                   
