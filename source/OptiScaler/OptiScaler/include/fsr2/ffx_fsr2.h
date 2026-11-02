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

// @defgroup FSR2

#pragma once

                                                         
#include "ffx_fsr2_interface.h"

                                                
   
                 
#define FFX_FSR2_VERSION_MAJOR (2)

                                                
   
                 
#define FFX_FSR2_VERSION_MINOR (2)

                                                
   
                 
#define FFX_FSR2_VERSION_PATCH (1)

                                                      
   
                 
#define FFX_FSR2_CONTEXT_SIZE (16536)

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                             
                               
       
                                                                        
                                                                              
                                                                        
                                     
       
                                                                                
                                                                                  
                                                                            
                                                                                
       
                                                                                 
                                                                                   
                                                                                  
                                                                                   
                    
       
                     
    typedef enum FfxFsr2QualityMode
    {

        FFX_FSR2_QUALITY_MODE_QUALITY = 1,                                                                              
        FFX_FSR2_QUALITY_MODE_BALANCED = 2,                                                                             
        FFX_FSR2_QUALITY_MODE_PERFORMANCE = 3,                                                                          
        FFX_FSR2_QUALITY_MODE_ULTRA_PERFORMANCE = 4                                                                     
    } FfxFsr2QualityMode;

                                                        
                                                                                  
       
                     
    typedef enum FfxFsr2InitializationFlagBits
    {

        FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE =
            (1 << 0),                                                                                      
        FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS =
            (1 << 1),                                                                                
        FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION =
            (1 << 2),                                                                                          
        FFX_FSR2_ENABLE_DEPTH_INVERTED =
            (1 << 3),                                                                                    
        FFX_FSR2_ENABLE_DEPTH_INFINITE =
            (1 << 4),                                                                                                
        FFX_FSR2_ENABLE_AUTO_EXPOSURE =
            (1 << 5),                                                                                   
        FFX_FSR2_ENABLE_DYNAMIC_RESOLUTION =
            (1 << 6),                                                                            
        FFX_FSR2_ENABLE_TEXTURE1D_USAGE = (1 << 7),                                                               
        FFX_FSR2_ENABLE_DEBUG_CHECKING =
            (1 << 8),                                                                                       
    } FfxFsr2InitializationFlagBits;

                                                                                  
                                     
       
                     
    typedef struct FfxFsr2ContextDescription
    {

        uint32_t flags;                                                                                 
        FfxDimensions2D maxRenderSize;                                                           
        FfxDimensions2D displaySize;                                                                                  
        FfxFsr2Interface callbacks;                                                                     
        FfxDevice device;                                                                                    

        FfxFsr2Message fpMessage;                                                                         
    } FfxFsr2ContextDescription;

                                                                                   
                                         
       
                     
    typedef struct FfxFsr2DispatchDescription
    {

        FfxCommandList commandList;                                                                              
        FfxResource color;                                                                                              
                                            
        FfxResource depth;                                                                                         
                                                   
        FfxResource motionVectors;                                                                                    
                                                                                                                        
                                                 
        FfxResource exposure;                                                                                
        FfxResource
            reactive;                                                                                                   
        FfxResource transparencyAndComposition;                                                                    
                                                                                  
        FfxResource output;                                                                                          
                                                              
        FfxFloatCoords2D jitterOffset;                                                            
        FfxFloatCoords2D motionVectorScale;                                                  
        FfxDimensions2D renderSize;                                                                             
        bool enableSharpening;                                                        
        float sharpness;                                                                                              
                                                   
        float frameTimeDelta;                                                                        
        float preExposure;                                                
        bool reset;                                                                                                   
        float cameraNear;                                                   
        float cameraFar;                                                   
        float cameraFovAngleVertical;                                                                             
                                                     
        float viewSpaceToMetersFactor;                                                            

                                                           
        bool enableAutoReactive;                                                                                     
        FfxResource colorOpaqueOnly;                                                                                 
                                                                               
        float autoTcThreshold;                               
        float autoTcScale;                                                                      
        float autoReactiveScale;                                            
        float autoReactiveMax;                                              

    } FfxFsr2DispatchDescription;

                                                                                            
       
                     
    typedef struct FfxFsr2GenerateReactiveDescription
    {

        FfxCommandList commandList;                                                                               
        FfxResource colorOpaqueOnly;                                                                                 
                                                                               
        FfxResource colorPreUpscale;                                                                                    
                                                                                   
        FfxResource
            outReactive;                                                                                            
        FfxDimensions2D renderSize;                                                                     
        float scale;                                                
        float cutoffThreshold;                                                               
        float binaryValue;                                                          
        uint32_t flags;                                                                      
    } FfxFsr2GenerateReactiveDescription;

                                                                            
       
                                                                              
                                            
       
                                                                               
                                                                                 
                                                                                 
                                                                              
                     
       
                     
    typedef struct FfxFsr2Context
    {

        uint32_t
            data[FFX_FSR2_CONTEXT_SIZE];                                                                              
    } FfxFsr2Context;

                                                                          
                                                                      
       
                                                                               
                                                                                 
                                                                              
                                                                                 
                                                                             
                                                                       
                                                                                 
                                                                                  
                                                                
       
                                                              
                                                                        
                                                                                   
                                                                
                                                                                    
                                                                                
                                                           
       
                                                                            
                                                                           
                                                             
                                                              
       
                                                                              
                                                                                 
                                                                       
                                            
       
                                                                                                              
                                                                                                             
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                   
               
                                                                                                               
       
                     
    FfxErrorCode ffxFsr2ContextCreate(FfxFsr2Context* context, const FfxFsr2ContextDescription* contextDescription);

                                                                                  
       
                                                                              
                                                                                 
                                                                             
                                                                     
                                                                         
                                                                                   
                   
       
                                                                          
                                                                                   
                                                                                  
                                                                                  
                                                                        
                                                    
                                                                              
                                                                                   
                                                            
                                                                                 
                                                                        
                                                                             
                                                     
       
                                                                                                  
                                                                                                              
       
               
                                                                                 
               
                                                                                                        
                                                                 
               
                                                                                                                     
                                                      
               
                                                                                                          
                           
               
                                                                                                               
       
                     
    FfxErrorCode ffxFsr2ContextDispatch(FfxFsr2Context* context, const FfxFsr2DispatchDescription* dispatchDescription);

                                                                                                                     
       
                                                                                                  
                                                                                                                     
       
               
                                                                                 
       
                     
    FfxErrorCode ffxFsr2ContextGenerateReactiveMask(FfxFsr2Context* context,
                                                    const FfxFsr2GenerateReactiveDescription* params);

                                                        
       
                                                                                                             
       
               
                                                                                 
               
                                                                                                         
                           
       
                     
    FfxErrorCode ffxFsr2ContextDestroy(FfxFsr2Context* context);

                                                    
       
                                                                          
                                     
       
                                                                            
                                                                             
                                                                    
                                                                    
                                                                    
                                                                    
       
                                                                      
       
                                                                    
       
                
                                                           
                                                               
       
                     
    float ffxFsr2GetUpscaleRatioFromQualityMode(FfxFsr2QualityMode qualityMode);

                                                                             
                                             
       
                                                            
                                                                              
       
                                                                                                                
                         
                                                                                                                
                          
                                                                                
                                                                                 
                                                                                         
       
               
                                                                                 
               
                                                                                                              
                    
               
                                                                                  
       
                     
    FfxErrorCode ffxFsr2GetRenderResolutionFromQualityMode(uint32_t* renderWidth, uint32_t* renderHeight,
                                                           uint32_t displayWidth, uint32_t displayHeight,
                                                           FfxFsr2QualityMode qualityMode);

                                                                          
                   
       
                                                                               
                                                        
                                                      
       
                                                                        
                                                     
       
                                                                                           
                                                                                               
                                                                                  
                                                                                  
                                                                                  
                                                                                  
                                                                                           
       
                                                                        
                                                                         
       
                
                                                                                                                       
       
                     
    int32_t ffxFsr2GetJitterPhaseCount(int32_t renderWidth, int32_t displayWidth);

                                                                  
       
                                                                                    
                                                                                  
                                                                                  
                                                                            
                                                                                    
                                                                        
                                                                                    
                                                                                    
                                                                                        
                                                       
                                                                                   
       
                                                                               
                                                                         
                                 
       
                                                                       
                                                                                  
                                                                             
                                                                                 
                                     
       
                                                                                                   
       
                              
                              
                                                                                
       
                                                                      
                                                                        
                                                                                                                     
                                                                                                
       
                                                                              
                                                                                 
                                                                                
                                                                                   
                                                                            
                                                                              
                                    
       
                                                                                  
                                                            
                                               
                                                                                 
                                                                                 
       
                                                                                   
                                                                                     
                                                          
       
                                                                                                                     
                            
                                                                                                                     
                            
                                                                                 
                                                                                                                     
       
               
                                                                                 
               
                                                                                                            
               
                                                                                                     
       
                     
    FfxErrorCode ffxFsr2GetJitterOffset(float* outX, float* outY, int32_t index, int32_t phaseCount);

                                                   
                                                        
       
                                                                        
       
                
                                                                              
                                                        
                
                                                                          
                                                        
       
                     
    bool ffxFsr2ResourceIsNull(FfxResource resource);

#if defined(__cplusplus)
}
#endif                            
