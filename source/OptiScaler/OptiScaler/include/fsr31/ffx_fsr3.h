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

// @defgroup FSR3

#pragma once

                                                         
#include "ffx_interface.h"
#include "ffx_fsr3upscaler.h"
#include "ffx_frameinterpolation.h"
#include "ffx_opticalflow.h"

namespace Fsr31
{

                                                
   
                 
#define FFX_FSR3_VERSION_MAJOR (3)

                                                
   
                 
#define FFX_FSR3_VERSION_MINOR (1)

                                                
   
                 
#define FFX_FSR3_VERSION_PATCH (2)

                                               
   
                                                                                            
   
                    
#define FFX_FSR3_CONTEXT_COUNT                                                                                         \
    (FFX_FSR3UPSCALER_CONTEXT_COUNT + FFX_OPTICALFLOW_CONTEXT_COUNT + FFX_FRAMEINTERPOLATION_CONTEXT_COUNT + 1)

                                                      
   
                 
#define FFX_FSR3_CONTEXT_SIZE                                                                                          \
    (FFX_FSR3UPSCALER_CONTEXT_SIZE + FFX_OPTICALFLOW_CONTEXT_SIZE + FFX_FRAMEINTERPOLATION_CONTEXT_SIZE +              \
     FFX_SDK_DEFAULT_CONTEXT_SIZE)

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
        FFX_FSR3_ENABLE_TEXTURE1D_USAGE =
            (1 << 7),                                                                                                  
        FFX_FSR3_ENABLE_DEBUG_CHECKING =
            (1 << 8),                                                                                       
        FFX_FSR3_ENABLE_UPSCALING_ONLY =
            (1 << 9),                                                                       
        FFX_FSR3_ENABLE_HDR_UPSCALE_SDR_FINALOUTPUT =
            (1 << 10),                                                                                                 
                                            
        FFX_FSR3_ENABLE_SDR_UPSCALE_HDR_FINALOUTPUT =
            (1 << 11),                                                                                                
                                              
        FFX_FSR3_ENABLE_ASYNC_WORKLOAD_SUPPORT = (1 << 12),
        FFX_FSR3_ENABLE_INTERPOLATION_ONLY = (1 << 13),
    } FfxFsr3InitializationFlagBits;

    typedef enum FfxFsr3FrameGenerationFlags
    {
        FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES =
            FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES,                                                     
                                                                                                            
        FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW =
            FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW,                                                            
                                                                                                                     
    } FfxFsr3FrameGenerationFlags;

    typedef enum FfxFsr3UpscalingFlags
    {
        FFX_FSR3_UPSCALER_FLAG_DRAW_DEBUG_VIEW =
            FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW,                                                             
                                                                                                          
    } FfxFsr3UpscalingFlags;

                                                                                  
                                     
       
                     
    typedef struct FfxFsr3ContextDescription
    {
        uint32_t flags;                                                                                  
        FfxDimensions2D maxRenderSize;                                                            
        FfxDimensions2D maxUpscaleSize;                                                                                
        FfxDimensions2D
            displaySize;                                                                                          
        FfxInterface
            backendInterfaceSharedResources;                                                                           
        FfxInterface backendInterfaceUpscaling;                                                                        
        FfxInterface
            backendInterfaceFrameInterpolation;                                                                        
        FfxFsr3UpscalerMessage fpMessage;                                                                               
        FfxSurfaceFormat backBufferFormat;                                              

    } FfxFsr3ContextDescription;

                                                                                   
                                         
       
                     
    typedef struct FfxFsr3DispatchUpscaleDescription
    {

        FfxCommandList commandList;                                                                              
        FfxResource color;                                                                                              
                                            
        FfxResource depth;                                                                                         
                                                   
        FfxResource motionVectors;                                                                                    
                                                                                                                        
                                                 
        FfxResource exposure;                                                                                
        FfxResource
            reactive;                                                                                                   
        FfxResource transparencyAndComposition;                                                                    
                                                                                  
        FfxResource upscaleOutput;                                                                                    
                                                                           
        FfxFloatCoords2D jitterOffset;                                                            
        FfxFloatCoords2D motionVectorScale;                                                  
        FfxDimensions2D renderSize;                                                                             
        FfxDimensions2D upscaleSize;                                                          
        bool enableSharpening;                                                        
        float sharpness;                                                                                              
                                                   
        float frameTimeDelta;                                                                        
        float preExposure;                                                
        bool reset;                                                                                                   
        float cameraNear;                                                   
        float cameraFar;                                                                                         
                                              
        float cameraFovAngleVertical;                                                                             
                                                     
        float viewSpaceToMetersFactor;                                                            
        uint32_t flags;                                                         
        uint64_t frameID;
    } FfxFsr3DispatchUpscaleDescription;

    typedef struct FfxFsr3DispatchFrameGenerationPrepareDescription
    {
        FfxCommandList commandList;                                                                              
        FfxResource depth;                                                                                         
                                                   
        FfxResource motionVectors;                                                                                    
                                                                                                                        
                                                 
        FfxFloatCoords2D jitterOffset;                                                            
        FfxFloatCoords2D motionVectorScale;                                                  
        FfxDimensions2D renderSize;                                                                             

        float frameTimeDelta;
        float cameraNear;
        float cameraFar;
        float viewSpaceToMetersFactor;
        float cameraFovAngleVertical;

        uint64_t frameID;
    } FfxFsr3DispatchFrameGenerationPrepareDescription;

    FFX_API FfxErrorCode ffxFsr3DispatchFrameGeneration(const FfxFrameGenerationDispatchDescription* desc);

                                                                                            
       
                     
    typedef struct FfxFsr3GenerateReactiveDescription
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
    } FfxFsr3GenerateReactiveDescription;

                                                                            
       
                                                                              
                                            
       
                                                                               
                                                                                 
                                                                                 
                                                                              
                     
       
                     
    typedef struct FfxFsr3Context
    {
        uint32_t
            data[FFX_FSR3_CONTEXT_SIZE];                                                                              
    } FfxFsr3Context;

                                                                          
                                                                      
       
                                                                               
                                                                                 
                                                                              
                                                                                 
                                                                             
                                                                       
                                                                                 
                                                                                  
                                                                
       
                                                              
                                                                        
                                                                                   
                                                                
                                                                                    
                                                                                
                                                           
       
                                                                            
                                                                           
                                                             
                                                              
       
                                                                              
                                                                                 
                                                                       
                                            
       
                                                                                                              
                                                                                                             
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                   
               
                                                                                                               
       
                     
    FFX_API FfxErrorCode ffxFsr3ContextCreate(FfxFsr3Context* context, FfxFsr3ContextDescription* contextDescription);

                                                                                            
       
                                                                              
                                                                                 
                                                                                    
                                                                     
                                                                         
                                                                                   
                   
       
                                                                          
                                                                       
                                                                                  
                                                                                  
                                                                        
                                                    
                                                                              
                                                                                   
                                                            
                                                                            
                                                                        
                                                                             
                                                     
       
                                                                                                  
                                                                                                                
       
               
                                                                                 
               
                                                                                                        
                                                            
               
                                                                                                                    
                                                  
               
                                                                                                          
                           
               
                                                                                                               
       
                     
    FFX_API FfxErrorCode ffxFsr3ContextDispatchUpscale(FfxFsr3Context* context,
                                                       const FfxFsr3DispatchUpscaleDescription* dispatchParams);
    FFX_API FfxErrorCode ffxFsr3ContextDispatchFrameGenerationPrepare(
        FfxFsr3Context* context, const FfxFsr3DispatchFrameGenerationPrepareDescription* dispatchParams);

    FFX_API FfxErrorCode ffxFsr3SkipPresent(FfxFsr3Context* context);

                                                                                                                     
       
                                                                                                  
                                                                                                                     
       
               
                                                                                 
       
                     
    FFX_API FfxErrorCode ffxFsr3ContextGenerateReactiveMask(FfxFsr3Context* context,
                                                            const FfxFsr3GenerateReactiveDescription* params);

    FFX_API FfxErrorCode ffxFsr3ConfigureFrameGeneration(FfxFsr3Context* context,
                                                         const FfxFrameGenerationConfig* config);

                                                        
       
                                                                                                             
       
               
                                                                                 
               
                                                                                                         
                           
       
                     
    FFX_API FfxErrorCode ffxFsr3ContextDestroy(FfxFsr3Context* context);

                                                    
       
                                                                          
                                     
       
                                                                            
                                                                             
                                                                    
                                                                    
                                                                    
                                                                    
                                                                    
       
                                                                      
       
                                                                    
       
                
                                                           
                                                               
       
                     
    FFX_API float ffxFsr3GetUpscaleRatioFromQualityMode(FfxFsr3QualityMode qualityMode);

                                                                             
                                             
       
                                                            
                                                                              
       
                                                                                                                
                         
                                                                                                                
                          
                                                                                
                                                                                 
                                                                                         
       
               
                                                                                 
               
                                                                                                              
                    
               
                                                                                  
       
                     
    FFX_API FfxErrorCode ffxFsr3GetRenderResolutionFromQualityMode(uint32_t* renderWidth, uint32_t* renderHeight,
                                                                   uint32_t displayWidth, uint32_t displayHeight,
                                                                   FfxFsr3QualityMode qualityMode);

                                                                          
                   
       
                                                                               
                                                        
                                                      
       
                                                                        
                                                     
       
                                                                                           
                                                                                               
                                                                                  
                                                                                  
                                                                                  
                                                                                  
                                                                                           
       
                                                                        
                                                                         
       
                
                                                                                                                       
       
                     
    FFX_API int32_t ffxFsr3GetJitterPhaseCount(int32_t renderWidth, int32_t displayWidth);

                                                                  
       
                                                                                    
                                                                                  
                                                                                  
                                                                            
                                                                                    
                                                                        
                                                                                    
                                                                                    
                                                                                        
                                                       
                                                                                   
       
                                                                               
                                                                         
                                 
       
                                                                       
                                                                                  
                                                                             
                                                                                 
                                     
       
                                                                                                   
       
                              
                              
                                                                                
       
                                                                      
                                                                        
                                                                                                                     
                                                                                                
       
                                                                              
                                                                                 
                                                                                
                                                                                   
                                                                            
                                                                              
                                    
       
                                                                                  
                                                            
                                               
                                                                                 
                                                                                 
       
                                                                                   
                                                                                     
                                                          
       
                                                                                                                     
                            
                                                                                                                     
                            
                                                                                 
                                                                                                                     
       
               
                                                                                 
               
                                                                                                            
               
                                                                                                     
       
                     
    FFX_API FfxErrorCode ffxFsr3GetJitterOffset(float* outX, float* outY, int32_t index, int32_t phaseCount);

                                                   
                                                        
       
                                                                        
       
                
                                                                              
                                                        
                
                                                                          
                                                        
       
                     
    FFX_API bool ffxFsr3ResourceIsNull(FfxResource resource);

                                                                                
       
                                                                                                   
                                                                                                      
                                                                                                         
                             
       
               
                                                                                 
               
                                                                                                 
               
                                                                            
       
                                
    FFX_API FfxErrorCode ffxFsr3SetUpscalerConstant(FfxFsr3Context* context, FfxFsr3UpscalerConfigureKey key,
                                                    void* valuePtr);

#if defined(__cplusplus)
}
#endif                            
}                   