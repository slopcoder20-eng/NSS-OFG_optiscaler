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

// @defgroup FSR3

#pragma once

                                                         
#include "ffx_interface.h"
#include "ffx_fsr3upscaler.h"
#include "ffx_frameinterpolation.h"
#include "ffx_opticalflow.h"

                                                
   
                 
#define FFX_FSR3_VERSION_MAJOR (3)

                                                
   
                 
#define FFX_FSR3_VERSION_MINOR (0)

                                                
   
                 
#define FFX_FSR3_VERSION_PATCH (3)

                                               
   
                                                                                            
   
                    
#define FFX_FSR3_CONTEXT_COUNT                                                                                         \
    (FFX_FSR3UPSCALER_CONTEXT_COUNT + FFX_OPTICALFLOW_CONTEXT_COUNT + FFX_FRAMEINTERPOLATION_CONTEXT_COUNT + 1)

                                                      
   
                 
#define FFX_FSR3_CONTEXT_SIZE (16536)

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                               
         
                                                                           
                                                                    
                                                                        
                                                                                  
                                                                               
                                  
         
                                                                                
                                                                                   
                                                                                    
                                                                               
                                                                                     
                                                          
         
                       
                               
       
                                       
      
                                                                            
                     

                                                                             
                               
       
                                                                        
                                                                              
                                                                        
                                     
       
                                                                                
                                                                                  
                                                                            
                                                                                
       
                                                                                 
                                                                                   
                                                                                  
                                                                                   
                    
       
                     
    typedef enum FfxFsr3QualityMode
    {

        FFX_FSR3_QUALITY_MODE_QUALITY = 1,                                                                              
        FFX_FSR3_QUALITY_MODE_BALANCED = 2,                                                                             
        FFX_FSR3_QUALITY_MODE_PERFORMANCE = 3,                                                                          
        FFX_FSR3_QUALITY_MODE_ULTRA_PERFORMANCE = 4                                                                     
    } FfxFsr3QualityMode;

                                                        
                                                                                  
       
                     
    typedef enum FfxFsr3InitializationFlagBits
    {

        FFX_FSR3_ENABLE_HIGH_DYNAMIC_RANGE =
            (1
             << 0),                                                                                                    
        FFX_FSR3_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS =
            (1 << 1),                                                                                
        FFX_FSR3_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION =
            (1 << 2),                                                                                          
        FFX_FSR3_ENABLE_DEPTH_INVERTED =
            (1 << 3),                                                                                    
        FFX_FSR3_ENABLE_DEPTH_INFINITE =
            (1 << 4),                                                                                                
        FFX_FSR3_ENABLE_AUTO_EXPOSURE =
            (1 << 5),                                                                                   
        FFX_FSR3_ENABLE_DYNAMIC_RESOLUTION =
            (1 << 6),                                                                            
        FFX_FSR3_ENABLE_TEXTURE1D_USAGE = (1 << 7),                                                               
        FFX_FSR3_ENABLE_DEBUG_CHECKING =
            (1 << 8),                                                                                       
        FFX_FSR3_ENABLE_UPSCALING_ONLY =
            (1 << 9),                                                                       
        FFX_FSR3_ENABLE_HDR_UPSCALE_SDR_FINALOUTPUT =
            (1 << 10),                                                                                                 
                                            
        FFX_FSR3_ENABLE_SDR_UPSCALE_HDR_FINALOUTPUT =
            (1 << 11),                                                                                                
                                              
        FFX_FSR3_ENABLE_ASYNC_WORKLOAD_SUPPORT = (1 << 12),
    } FfxFsr3InitializationFlagBits;

    typedef enum FfxFsr3FrameGenerationFlags
    {
        FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES =
            FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES,                                                     
                                                                                                            
        FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW =
            FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW,                                                            
                                                                                                                     
    } FfxFsr3FrameGenerationFlags;

                                                                                  
                                     
       
                     
    typedef struct FfxFsr3ContextDescription
    {
        uint32_t flags;                                                                                       
        Fsr3::FfxDimensions2D maxRenderSize;                                                           
        Fsr3::FfxDimensions2D
            upscaleOutputSize;                                                                                
        Fsr3::FfxDimensions2D
            displaySize;                                                                                          
        Fsr3::FfxInterface
            backendInterfaceSharedResources;                                                                        
        Fsr3::FfxInterface
            backendInterfaceUpscaling;                                                                        
        Fsr3::FfxInterface
            backendInterfaceFrameInterpolation;                                                                        
        Fsr3::FfxFsr3UpscalerMessage fpMessage;                                                                         

        Fsr3::FfxSurfaceFormat backBufferFormat;                                         

    } FfxFsr3ContextDescription;

                                                                                   
                                         
       
                     
    typedef struct FfxFsr3DispatchUpscaleDescription
    {

        Fsr3::FfxCommandList commandList;                                                                              
        Fsr3::FfxResource color;                                                                                       
                                                         
        Fsr3::FfxResource depth;                                                                                     
                                         
                                                         
        Fsr3::FfxResource
            motionVectors;                                                                                    
                                                                                                                
                                         
        Fsr3::FfxResource exposure;                                                                           
        Fsr3::FfxResource
            reactive;                                                                                                   
        Fsr3::FfxResource transparencyAndComposition;                                                                 
                                                             
                                                                                        
        Fsr3::FfxResource upscaleOutput;                                                                                
                                                         
                                                                                     
        Fsr3::FfxFloatCoords2D jitterOffset;                                                       
        Fsr3::FfxFloatCoords2D motionVectorScale;                                                  
        Fsr3::FfxDimensions2D renderSize;                                                                             
        bool enableSharpening;                                                              
        float sharpness;                                                                                              
                                                   
        float frameTimeDelta;                                                                        
        float preExposure;                                                
        bool reset;                                                                                                   
        float cameraNear;                                                   
        float cameraFar;                                                                                         
                                              
        float cameraFovAngleVertical;                                                                             
                                                     
        float viewSpaceToMetersFactor;                                                            
    } FfxFsr3DispatchUpscaleDescription;

    FFX_API Fsr3::FfxErrorCode ffxFsr3DispatchFrameGeneration(const Fsr3::FfxFrameGenerationDispatchDescription* desc);

                                                                                            
       
                     
    typedef struct FfxFsr3GenerateReactiveDescription
    {

        Fsr3::FfxCommandList commandList;                                                                               
        Fsr3::FfxResource colorOpaqueOnly;                                                                             
                                                                                         
        Fsr3::FfxResource colorPreUpscale;                                                                         
                                                          
                                                                                         
        Fsr3::FfxResource
            outReactive;                                                                                            
        Fsr3::FfxDimensions2D renderSize;                                                                     
        float scale;                                                      
        float cutoffThreshold;                                                                     
        float binaryValue;
        uint32_t flags;                                                          
    } FfxFsr3GenerateReactiveDescription;

                                                                            
       
                                                                              
                                            
       
                                                                               
                                                                                 
                                                                                 
                                                                              
                     
       
                     
    typedef struct FfxFsr3Context
    {
        uint32_t data[FFX_FSR3UPSCALER_CONTEXT_SIZE + FFX_OPTICALFLOW_CONTEXT_SIZE +
                      FFX_FRAMEINTERPOLATION_CONTEXT_SIZE +
                      (16536)];                                                                              
    } FfxFsr3Context;

                                                                          
                                                                      
       
                                                                               
                                                                                 
                                                                              
                                                                                 
                                                                             
                                                                       
                                                                                 
                                                                                  
                                                                
       
                                                              
                                                                        
                                                                                   
                                                                
                                                                                    
                                                                                
                                                           
       
                                                                            
                                                                           
                                                             
                                                              
       
                                                                              
                                                                                 
                                                                       
                                            
       
                                                                                                              
                                                                                                             
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                   
               
                                                                                                               
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3ContextCreate(FfxFsr3Context* context,
                                                    FfxFsr3ContextDescription* contextDescription);

                                                                                            
       
                                                                              
                                                                                 
                                                                                    
                                                                     
                                                                         
                                                                                   
                   
       
                                                                          
                                                                       
                                                                                  
                                                                                  
                                                                        
                                                    
                                                                              
                                                                                   
                                                            
                                                                            
                                                                        
                                                                             
                                                     
       
                                                                                                  
                                                                                                                
       
               
                                                                                 
               
                                                                                                        
                                                            
               
                                                                                                                    
                                                  
               
                                                                                                          
                           
               
                                                                                                               
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3ContextDispatchUpscale(FfxFsr3Context* context,
                                                             const FfxFsr3DispatchUpscaleDescription* dispatchParams);

    FFX_API Fsr3::FfxErrorCode ffxFsr3SkipPresent(FfxFsr3Context* context);

                                                                                                                     
       
                                                                                                  
                                                                                                                     
       
               
                                                                                 
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3ContextGenerateReactiveMask(FfxFsr3Context* context,
                                                                  const FfxFsr3GenerateReactiveDescription* params);

    FFX_API Fsr3::FfxErrorCode ffxFsr3ConfigureFrameGeneration(FfxFsr3Context* context,
                                                               const Fsr3::FfxFrameGenerationConfig* config);

                                                        
       
                                                                                                             
       
               
                                                                                 
               
                                                                                                         
                           
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3ContextDestroy(FfxFsr3Context* context);

                                                    
       
                                                                          
                                     
       
                                                                            
                                                                             
                                                                    
                                                                    
                                                                    
                                                                    
                                                                    
       
                                                                      
       
                                                                    
       
                
                                                           
                                                               
       
                     
    FFX_API float ffxFsr3GetUpscaleRatioFromQualityMode(FfxFsr3QualityMode qualityMode);

                                                                             
                                             
       
                                                            
                                                                              
       
                                                                                                                
                         
                                                                                                                
                          
                                                                                
                                                                                 
                                                                                         
       
               
                                                                                 
               
                                                                                                              
                    
               
                                                                                  
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3GetRenderResolutionFromQualityMode(uint32_t* renderWidth, uint32_t* renderHeight,
                                                                         uint32_t displayWidth, uint32_t displayHeight,
                                                                         FfxFsr3QualityMode qualityMode);

                                                                          
                   
       
                                                                               
                                                        
                                                      
       
                                                                        
                                                     
       
                                                                                           
                                                                                               
                                                                                  
                                                                                  
                                                                                  
                                                                                  
                                                                                           
       
                                                                        
                                                                         
       
                
                                                                                                                       
       
                     
    FFX_API int32_t ffxFsr3GetJitterPhaseCount(int32_t renderWidth, int32_t displayWidth);

                                                                  
       
                                                                                    
                                                                                  
                                                                                  
                                                                            
                                                                                    
                                                                        
                                                                                    
                                                                                    
                                                                                        
                                                       
                                                                                   
       
                                                                               
                                                                         
                                 
       
                                                                       
                                                                                  
                                                                             
                                                                                 
                                     
       
                                                                                                   
       
                              
                              
                                                                                
       
                                                                      
                                                                        
                                                                                                                     
                                                                                                
       
                                                                              
                                                                                 
                                                                                
                                                                                   
                                                                            
                                                                              
                                    
       
                                                                                  
                                                            
                                               
                                                                                 
                                                                                 
       
                                                                                   
                                                                                     
                                                          
       
                                                                                                                     
                            
                                                                                                                     
                            
                                                                                 
                                                                                                                     
       
               
                                                                                 
               
                                                                                                            
               
                                                                                                     
       
                     
    FFX_API Fsr3::FfxErrorCode ffxFsr3GetJitterOffset(float* outX, float* outY, int32_t index, int32_t phaseCount);

                                                   
                                                        
       
                                                                        
       
                
                                                                              
                                                        
                
                                                                          
                                                        
       
                     
    FFX_API bool ffxFsr3ResourceIsNull(Fsr3::FfxResource resource);

#if defined(__cplusplus)
}
#endif                            
