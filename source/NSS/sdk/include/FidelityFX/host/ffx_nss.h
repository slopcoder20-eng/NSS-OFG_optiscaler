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

                                                        
#include "ffx_interface.h"

                        
                       
   
                          

                      
   
                   
#define FFX_NSS_VERSION_MAJOR (1)

                      
   
                   
#define FFX_NSS_VERSION_MINOR (0)

                      
   
                   
#define FFX_NSS_VERSION_PATCH (0)

                     
   
                                                                  
   
                   
#define FFX_NSS_CONTEXT_COUNT 1

                                                      
   
                   
#define FFX_NSS_CONTEXT_SIZE (24576)

#if defined(__cplusplus)
extern "C" {
#endif                             

                                                                        
   
                                                                    
                                                              
                                                                 
                                                                           
                                                                        
                            
   
                                                                         
                                                                            
                                                                              
                                                                        
                                                                              
                                                   
   
                   
typedef enum FfxNssPass
{
    FFX_NSS_PASS_DEPTH_SCATTER       = 0,                                              
    FFX_NSS_PASS_DISOCCLUSION_MASK   = 1,                                                           
    FFX_NSS_PASS_PREPROCESS          = 2,                                           
    FFX_NSS_PASS_DATA_GRAPH          = 3,                                        
    FFX_NSS_PASS_GENERATE_OFFSET_LUT = 4,                                                              
    FFX_NSS_PASS_POSTPROCESS         = 5,                                            
    FFX_NSS_PASS_DEBUG_VIEW          = 6,                                         
    FFX_NSS_PASS_COUNT                                                                
} FfxNssPass;

                                                             
   
                                                                    
                                                                         
                                                                    
                                 
   
                                                                            
                                                                              
                                                                        
                                                                            
   
                                                                            
                                                                               
                                                                              
                                                                               
                
   
                   
typedef enum FfxNssShaderQualityMode
{
    FFX_NSS_SHADER_QUALITY_MODE_QUALITY     = 0,                                                                
    FFX_NSS_SHADER_QUALITY_MODE_BALANCED    = 1,                                                                
    FFX_NSS_SHADER_QUALITY_MODE_PERFORMANCE = 2,                                                                    
} FfxNssShaderQualityMode;

                                                    
                                                                            
   
                   
typedef enum FfxNssInitializationFlagBits
{
    FFX_NSS_CONTEXT_FLAG_QUANTIZED          = (1 << 0),                                                                         
    FFX_NSS_CONTEXT_FLAG_HIGH_DYNAMIC_RANGE = (1 << 1),                                                                                       
    FFX_NSS_CONTEXT_FLAG_DEPTH_INVERTED     = (1 << 2),                                                                                     
    FFX_NSS_CONTEXT_FLAG_DEPTH_INFINITE     = (1 << 3),                                                                                                 
    FFX_NSS_CONTEXT_FLAG_RESAMPLE_BICUBIC   = (1 << 4),                                                      
    FFX_NSS_CONTEXT_FLAG_ALLOW_16BIT        = (1 << 5),                                                                                 
    FFX_NSS_CONTEXT_FLAG_MANAGE_HISTORY =
        (1
         << 6),                                                                                                                                                 
    FFX_NSS_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT  = (1 << 7),                                                                                                
    FFX_NSS_CONTEXT_FLAG_POST_PROCESS_FRAGMENT = (1 << 8),                                                                                                 
} FfxNssInitializationFlagBits;

                         
   
                            
   
                                                               
                                                                    
   
   
                   
typedef void (*FfxNssMessage)(FfxMsgType type, const char* message);

                                                                        
   
                   
typedef struct FfxNssContextDescription
{
    FfxNssShaderQualityMode qualityMode;                                      
    uint32_t                flags;                                                                        
    FfxDimensions2D         renderSize;                                                                                                
    FfxDimensions2D         upscaleSize;                                                                                                                      
    FfxDimensions2D         displaySize;                                                                                 

    FfxInterface  backendInterface;                                                                         
    FfxNssMessage fpMessage;                                                                                 
} FfxNssContextDescription;

                   
typedef enum FfxNssDispatchFlags
{
    FFX_NSS_DISPATCH_FLAG_ENABLE_DEBUG_CHECKING =
        (1 << 0),                                                                                                                  
    FFX_NSS_DISPATCH_FLAG_DRAW_DEBUG_VIEW =
        (1 << 1),                                                                                                                         
} FfxNssDispatchFlags;

                                                                               
           
   
                   
typedef struct FfxNssDispatchDescription
{
    FfxCommandList commandList;                                                                              
    FfxResource    color;                                                                                                                  
    FfxResource    depth;                                                                                                                    
    FfxResource
                motionVectors;                                                                                                                                                                               
    FfxResource output;                                                                                                                                
    FfxResource
        outputTm1;                                                                                                                                                                                                                                                                                                   

    FfxFloatCoords2D jitterOffset;                                                                  
    FfxDimensions2D  upscaleSize;                                                                                  
    FfxDimensions2D  renderSize;                                                                                  
    float            cameraNear;                                                                
    float            cameraFar;                                                                
    float            cameraFovAngleVertical;                                                                                       

    float            exposure;                                   
    FfxFloatCoords2D motionVectorScale;                                               

    float    frameTimeDelta;                                                                         
    bool     reset;                                                                                                       
    uint32_t flags;                                                                   
    FfxResource
             debugViews;                                                                                                                                                                     
    uint32_t debugViewMode;                                                                                                                
} FfxNssDispatchDescription;

                                                                                        
   
                   
typedef struct FfxNssGenerateReactiveDescription
{
    FfxCommandList commandList;                                                                                  
    FfxResource    colorOpaqueOnly;                                                                                                                        
    FfxResource colorPreUpscale;                                                                                                                               
    FfxResource outReactive;                                                                                                 
    FfxDimensions2D renderSize;                                                                       
    float           scale;                                        
    float           cutoffThreshold;                                                           
    float           binaryValue;                                                      
    uint32_t        flags;                                                                     
} FfxNssGenerateReactiveDescription;

                                              
   
                                                                          
                                       
   
                                                                          
                                                                           
                                                                            
                                                                          
                
   
                   
typedef struct FfxNssContext
{
    uint32_t data[FFX_NSS_CONTEXT_SIZE * 2];                                                                               
} FfxNssContext;

                                            
                                                                 
   
                                                                          
                                                                             
                                                                         
                                                                             
                                                                         
                                                                  
                                                                             
                                                                             
                                                            
   
                                                          
                                                                   
                                                                              
                                                            
                                                                               
                                                                            
                                                      
   
                                                                       
                                                                     
                                                         
                                                         
   
                                                                         
                                                                            
                                                                  
                                       
   
                                                                                                          
                                                                                                         
   
           
                                                                             
           
                                                                                                                                                             
           
                                                                                                                                                   
           
                                                                                                           
   
                   
FFX_API FfxErrorCode ffxNssContextCreate(FfxNssContext* pContext, const FfxNssContextDescription* pContextDescription);

                                                    
   
                                                                         
                                                                             
                                                                        
                                                                 
                                                                    
                                                                               
               
   
                                                                     
                                                                              
                                                                             
                                                                              
                                                                   
                                               
                                                                         
                                                                               
                                                        
                                                                             
                                                                    
                                                                        
                                                
   
                                                                                              
                                                                                                          
   
           
                                                                             
           
                                                                                                                                                              
           
                                                                                                                                                                
           
                                                                                                                          
           
                                                                                                           
   
                   
FFX_API FfxErrorCode ffxNssContextDispatch(FfxNssContext* pContext, const FfxNssDispatchDescription* pDispatchDescription);

                                                                                                                 
   
                                                                                              
                                                                                                                 
   
           
                                                                             
   
                   
FFX_API FfxErrorCode ffxNssContextGenerateReactiveMask(FfxNssContext* pContext, const FfxNssGenerateReactiveDescription* pParams);

                            
   
                                                                                                         
   
           
                                                                             
           
                                                                                                                         
   
                   
FFX_API FfxErrorCode ffxNssContextDestroy(FfxNssContext* pContext);

                                                                      
               
   
                                                                           
                                                    
                                                 
   
                                                                    
                                                 
   
                                                                    
                                                                     
   
            
                                                                                                                   
   
                   
FFX_API int32_t ffxNssGetJitterPhaseCount(int32_t renderWidth, int32_t displayWidth);

                                                              
   
                                                                               
                                                                              
                                                                             
                                                                        
                                                                                
                                                                    
                                                                               
                                                                                
                                                                                   
                                                   
                                                                              
   
                                                                           
                                                                     
                             
   
                                                                   
                                                                             
                                                                         
                                                                             
                                 
   
                                                                                              
   
                          
                          
                                                                           
   
                                                                  
                                                                    
                                                                                                                 
                                                                                            
   
                                                                          
                                                                             
                                                                           
                                                                               
                                                                        
                                                                          
                                
   
                                                                             
                                                        
                                           
                                                                           
                                                                             
   
                                                                              
                                                                                 
                                                      
   
                                                                                                                                       
                                                                                                                                       
                                                                             
                                                                                                                
   
           
                                                                             
           
                                                                                                        
           
                                                                                                 
   
                   
FFX_API FfxErrorCode ffxNssGetJitterOffset(float* pOutX, float* pOutY, int32_t index, int32_t phaseCount);

                                                                        
                                                            
   
                                                                            
                                                                          
                                                                           
   
                                                                                                     
                                                                                                                            
                                                                                                                             
   
           
                                                                             
           
                                                                               
   
                   
FFX_API FfxErrorCode ffxNssGetPipelineStageInfo(FfxNssContext* pContext, bool* pOutPreProcessUsesFragment, bool* pOutPostProcessUsesFragment);

                                               
                                                   
   
                                                                    
   
            
                                                                                                                          
            
                                                                                                                      
   
                   
FFX_API bool ffxNssResourceIsNull(const FfxResource& resource);

#if defined(__cplusplus)
}
#endif                             
