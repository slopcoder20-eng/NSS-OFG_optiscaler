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

#include <stdint.h>

typedef float FfxApiFloat32x4x4[16];

                                                                           
enum FfxApiSurfaceFormat
{
    FFX_API_SURFACE_FORMAT_UNKNOWN,                                   
    FFX_API_SURFACE_FORMAT_R32G32B32A32_TYPELESS,                                                    
    FFX_API_SURFACE_FORMAT_R32G32B32A32_UINT,                                                    
    FFX_API_SURFACE_FORMAT_R32G32B32A32_FLOAT,                                                    
    FFX_API_SURFACE_FORMAT_R16G16B16A16_FLOAT,                                                    
    FFX_API_SURFACE_FORMAT_R32G32B32_FLOAT,                                                       
    FFX_API_SURFACE_FORMAT_R32G32_FLOAT,                                                          
    FFX_API_SURFACE_FORMAT_R8_UINT,                                                              
    FFX_API_SURFACE_FORMAT_R8_SINT,                                                              
    FFX_API_SURFACE_FORMAT_R32_UINT,                                                              
    FFX_API_SURFACE_FORMAT_R8G8B8A8_TYPELESS,                                                        
    FFX_API_SURFACE_FORMAT_R8G8B8A8_UNORM,                                                                      
    FFX_API_SURFACE_FORMAT_R8G8B8A8_SNORM,                                                                    
    FFX_API_SURFACE_FORMAT_R8G8B8A8_SRGB,                                                            
    FFX_API_SURFACE_FORMAT_B8G8R8A8_TYPELESS,                                                        
    FFX_API_SURFACE_FORMAT_B8G8R8A8_UNORM,                                                                      
    FFX_API_SURFACE_FORMAT_B8G8R8A8_SRGB,                                                            
    FFX_API_SURFACE_FORMAT_R11G11B10_FLOAT,                                          
    FFX_API_SURFACE_FORMAT_R10G10B10A2_UNORM,                                                                      
    FFX_API_SURFACE_FORMAT_R16G16_FLOAT,                                                          
    FFX_API_SURFACE_FORMAT_R16G16_UINT,                                                                  
    FFX_API_SURFACE_FORMAT_R16G16_SINT,                                                                
    FFX_API_SURFACE_FORMAT_R16_FLOAT,                                                             
    FFX_API_SURFACE_FORMAT_R16_UINT,                                                                     
    FFX_API_SURFACE_FORMAT_R16_UNORM,                                                                           
    FFX_API_SURFACE_FORMAT_R16_SNORM,                                                                         
    FFX_API_SURFACE_FORMAT_R8_UNORM,                                                                            
    FFX_API_SURFACE_FORMAT_R8_SNORM,                                                                          
    FFX_API_SURFACE_FORMAT_R8G8_UNORM,                                                                          
    FFX_API_SURFACE_FORMAT_R8G8_UINT,                                                                        
    FFX_API_SURFACE_FORMAT_R8G8_SINT,                                                                      
    FFX_API_SURFACE_FORMAT_R32_FLOAT,                                                             
    FFX_API_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP,                                                   

    FFX_API_SURFACE_FORMAT_R16G16B16A16_TYPELESS,                                                    
    FFX_API_SURFACE_FORMAT_R32G32_TYPELESS,                                                          
    FFX_API_SURFACE_FORMAT_R10G10B10A2_TYPELESS,                                                                 
    FFX_API_SURFACE_FORMAT_R16G16_TYPELESS,                                                         
    FFX_API_SURFACE_FORMAT_R16_TYPELESS,                                                             
    FFX_API_SURFACE_FORMAT_R8_TYPELESS,                                                              
    FFX_API_SURFACE_FORMAT_R8G8_TYPELESS,                                                            
    FFX_API_SURFACE_FORMAT_R32_TYPELESS,                                                             
};

                                     
enum FfxApiResourceUsage
{
    FFX_API_RESOURCE_USAGE_READ_ONLY     = 0,                                                              
    FFX_API_RESOURCE_USAGE_RENDERTARGET  = (1 << 0),                                                          
    FFX_API_RESOURCE_USAGE_UAV           = (1 << 1),                                                
    FFX_API_RESOURCE_USAGE_DEPTHTARGET   = (1 << 2),                                                         
    FFX_API_RESOURCE_USAGE_INDIRECT      = (1 << 3),                                                                    
    FFX_API_RESOURCE_USAGE_ARRAYVIEW     = (1 << 4),                                                                                            
    FFX_API_RESOURCE_USAGE_STENCILTARGET = (1 << 5),                                                           
    FFX_API_RESOURCE_USAGE_DATA_GRAPH    = (1 << 6),                                                                
};
typedef FfxApiResourceUsage FfxApiResorceUsage;                                                   

                                      
enum FfxApiResourceState
{
                                                                   
                                                                    
    FFX_API_RESOURCE_STATE_COMMON      = (1 << 0),
    FFX_API_RESOURCE_STATE_COMPUTE_UAV = (1 << 1),                                                                                 
    FFX_API_RESOURCE_STATE_PIXEL_UAV   = (1 << 2),                                                                               
    FFX_API_RESOURCE_STATE_UNORDERED_ACCESS =
        (FFX_API_RESOURCE_STATE_COMPUTE_UAV |
         FFX_API_RESOURCE_STATE_PIXEL_UAV),                                                                                                  
    FFX_API_RESOURCE_STATE_COMPUTE_READ = (1 << 3),                                                                          
    FFX_API_RESOURCE_STATE_PIXEL_READ   = (1 << 4),                                                                        
    FFX_API_RESOURCE_STATE_PIXEL_COMPUTE_READ =
        (FFX_API_RESOURCE_STATE_PIXEL_READ |
         FFX_API_RESOURCE_STATE_COMPUTE_READ),                                                                                     
    FFX_API_RESOURCE_STATE_COPY_SRC  = (1 << 5),                                                                                   
    FFX_API_RESOURCE_STATE_COPY_DEST = (1 << 6),                                                                                        
    FFX_API_RESOURCE_STATE_GENERIC_READ =
        (FFX_API_RESOURCE_STATE_COPY_SRC | FFX_API_RESOURCE_STATE_COMPUTE_READ),                                                            
    FFX_API_RESOURCE_STATE_INDIRECT_ARGUMENT  = (1 << 7),                                                                                       
    FFX_API_RESOURCE_STATE_PRESENT            = (1 << 8),                                                                                    
    FFX_API_RESOURCE_STATE_RENDER_TARGET      = (1 << 9),                                                                        
    FFX_API_RESOURCE_STATE_DATA_GRAPH_READ    = (1 << 10),                                                                    
    FFX_API_RESOURCE_STATE_DATA_GRAPH_WRITE   = (1 << 11),                                                                       
    FFX_API_RESOURCE_STATE_DEPTH_STENCIL_READ = (1 << 12),                                                                 
};

                                         
enum FfxApiResourceDimension
{
    FFX_API_RESOURCE_DIMENSION_TEXTURE_1D,                                          
    FFX_API_RESOURCE_DIMENSION_TEXTURE_2D,                                      
};

                                     
enum FfxApiResourceFlags
{
    FFX_API_RESOURCE_FLAGS_NONE      = 0,                       
    FFX_API_RESOURCE_FLAGS_ALIASABLE = (1 << 0),                                                                          
    FFX_API_RESOURCE_FLAGS_UNDEFINED = (1 << 1),                                                                                               
};

                                              
enum FfxApiResourceType
{
    FFX_API_RESOURCE_TYPE_BUFFER,                                      
    FFX_API_RESOURCE_TYPE_TEXTURE1D,                                                  
    FFX_API_RESOURCE_TYPE_TEXTURE2D,                                                  
    FFX_API_RESOURCE_TYPE_TEXTURE_CUBE,                                  
    FFX_API_RESOURCE_TYPE_TEXTURE3D,                                                  
    FFX_API_RESOURCE_TYPE_TENSOR,                                      
};

                                                                                   
struct FfxApiDimensions2D
{
    uint32_t width;                                           
    uint32_t height;                                           
};

struct FfxApiTensorInfo
{
    uint32_t width;                                              
    uint32_t height;                                              
    uint32_t channels;                                   
    uint32_t shapeSize;                                           
};

                                                                                
struct FfxApiFloatCoords2D
{
    float x;                                                 
    float y;                                                 
};

                                                   
struct FfxApiRect2D
{
    int32_t left;
    int32_t top;
    int32_t width;
    int32_t height;
};

                                      
   
                     
struct FfxApiResourceDescription
{
    uint32_t type;                                  
    uint32_t format;                          
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

    uint32_t mipCount;                                               
    uint32_t flags;                                  
    uint32_t usage;                               

                                        
    uint32_t batchSize = 0;                                    
    uint32_t shapeSize = 0;                                    
};

struct FfxApiResource
{
    void*                            resource;
    struct FfxApiResourceDescription description;
    uint32_t                         state;
};

                                                
typedef struct FfxApiEffectMemoryUsage
{
    uint64_t totalUsageInBytes;
    uint64_t aliasableUsageInBytes;
} FfxApiEffectMemoryUsage;

  
                                                
                                                               
                                                                                           

                                                                    
                                                                        
                                                                       

                                                                                                                                                                                                                       
                           
                                                                                                                                      
                                                                                                                                                           

                                                                                                            

                                                                                                                
                                                                                                                           
                                                                                                                               
                                                                                                                               

                                                                                                              
                                                                                                              
                                                                                                              
                                                                                                              
                                                                                                              
                                                                                                              

                                
                        
                                                                                                                                                 
                                                                                                                                                             

     
                                                                                                                                                                                                                                                    

  

                                                         
typedef struct FfxApiSwapchainFramePacingTuning
{
    float safetyMarginInMs;                                     
    float varianceFactor;                                            
    bool  allowHybridSpin;                                                       
    uint32_t
         hybridSpinTime;                                                                                                                                                                     
    bool allowWaitForSingleObjectOnFence;                                                                                     
} FfxApiSwapchainFramePacingTuning;
