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

                                                         
#include "ffx_interface.h"

                                             
namespace Fsr31
{
                                                 
   
                          

                                                
   
                            
#define FFX_FSR3UPSCALER_VERSION_MAJOR (3)

                                                
   
                            
#define FFX_FSR3UPSCALER_VERSION_MINOR (1)

                                                
   
                            
#define FFX_FSR3UPSCALER_VERSION_PATCH (2)

                                               
   
                                                                   
   
                            
#define FFX_FSR3UPSCALER_CONTEXT_COUNT 1

                                                      
   
                            
#define FFX_FSR3UPSCALER_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE)

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                             
       
                                                                         
                                                                  
                                                                              
                                                                                        
                                                                             
                                
       
                                                                                      
                                                                                         
                                                                                  
                                                                                     
                                                                                           
                                                                
       
                                
    typedef enum FfxFsr3UpscalerPass
    {
        FFX_FSR3UPSCALER_PASS_PREPARE_INPUTS,                                                        
        FFX_FSR3UPSCALER_PASS_LUMA_PYRAMID,                                                                         
                                                         
        FFX_FSR3UPSCALER_PASS_SHADING_CHANGE_PYRAMID,                                                                
                                                                                       
        FFX_FSR3UPSCALER_PASS_SHADING_CHANGE,                                                                          
        FFX_FSR3UPSCALER_PASS_PREPARE_REACTIVITY,                                                                 
        FFX_FSR3UPSCALER_PASS_LUMA_INSTABILITY,                                                                        
                                                                   
        FFX_FSR3UPSCALER_PASS_ACCUMULATE,                                                  
        FFX_FSR3UPSCALER_PASS_ACCUMULATE_SHARPEN,                                                                  
        FFX_FSR3UPSCALER_PASS_RCAS,                                                         
        FFX_FSR3UPSCALER_PASS_DEBUG_VIEW,                                                                        

        FFX_FSR3UPSCALER_PASS_GENERATE_REACTIVE,                                                   
        FFX_FSR3UPSCALER_PASS_TCR_AUTOGENERATE,                                       
        FFX_FSR3UPSCALER_PASS_COUNT                                                          
    } FfxFsr3UpscalerPass;

                                                                             
                               
       
                                                                        
                                                                              
                                                                        
                                     
       
                                                                                
                                                                                  
                                                                            
                                                                                
       
                                                                                         
                                                                                   
                                                                                  
                                                                                   
                    
       
                                
    typedef enum FfxFsr3UpscalerQualityMode
    {
        FFX_FSR3UPSCALER_QUALITY_MODE_NATIVEAA = 0,                                                                     
        FFX_FSR3UPSCALER_QUALITY_MODE_QUALITY = 1,                                                                      
        FFX_FSR3UPSCALER_QUALITY_MODE_BALANCED = 2,                                                                     
        FFX_FSR3UPSCALER_QUALITY_MODE_PERFORMANCE =
            3,                                                                     
        FFX_FSR3UPSCALER_QUALITY_MODE_ULTRA_PERFORMANCE =
            4                                                                     
    } FfxFsr3UpscalerQualityMode;

                                                        
                                                                                                  
       
                                
    typedef enum FfxFsr3UpscalerInitializationFlagBits
    {

        FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE =
            (1 << 0),                                                                                      
        FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS =
            (1 << 1),                                                                                
        FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION =
            (1 << 2),                                                                                          
        FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED =
            (1 << 3),                                                                                    
        FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE =
            (1 << 4),                                                                                                
        FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE =
            (1 << 5),                                                                                   
        FFX_FSR3UPSCALER_ENABLE_DYNAMIC_RESOLUTION =
            (1 << 6),                                                                            
        FFX_FSR3UPSCALER_ENABLE_TEXTURE1D_USAGE =
            (1 << 7),                                                                                                  
        FFX_FSR3UPSCALER_ENABLE_DEBUG_CHECKING =
            (1 << 8),                                                                                       
    } FfxFsr3UpscalerInitializationFlagBits;

                             
       
                                
       
                                                                   
                                                                        
       
       
                                
    typedef void (*FfxFsr3UpscalerMessage)(FfxMsgType type, const wchar_t* message);

                                                                                  
                                     
       
                                
    typedef struct FfxFsr3UpscalerContextDescription
    {

        uint32_t flags;                                                                                            
        FfxDimensions2D maxRenderSize;                                                              
        FfxDimensions2D maxUpscaleSize;                                                                            
        FfxFsr3UpscalerMessage fpMessage;                                                                         
        FfxInterface backendInterface;                                                                           

    } FfxFsr3UpscalerContextDescription;

    typedef enum FfxFsr3UpscalerDispatchFlags
    {
        FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW =
            (1 << 0),                                                                                                   
                                       
    } FfxFsr3UpscalerDispatchFlags;

    typedef enum FfxFsr3UpscalerConfigureKey
    {
        FFX_FSR3UPSCALER_CONFIGURE_UPSCALE_KEY_FVELOCITYFACTOR =
            0                                                                                                           
                                                                                                                      
                                 
    } FfxFsr3UpscalerConfigureKey;

                                                                                   
                                         
       
                                
    typedef struct FfxFsr3UpscalerDispatchDescription
    {

        FfxCommandList commandList;                                                                              
        FfxResource color;                                                                                              
                                            
        FfxResource depth;                                                                                         
                                                   
        FfxResource
            motionVectors;                                                                                    
                                                                                                                        
                                         
        FfxResource exposure;                                                                           
        FfxResource
            reactive;                                                                                                   
        FfxResource transparencyAndComposition;                                                                    
                                                                                  
        FfxResource dilatedDepth;                                                                         
                                                                                                                   
                                                                                      
        FfxResource dilatedMotionVectors;                                                           
                                                                                                                      
                                                                                                            
        FfxResource reconstructedPrevNearestDepth;                                                           
                                                                                                                       
                                                                                                                        
                                                                          
        FfxResource output;                                                                                          
                                                              
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
    } FfxFsr3UpscalerDispatchDescription;

                                                                                            
       
                                
    typedef struct FfxFsr3UpscalerGenerateReactiveDescription
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
    } FfxFsr3UpscalerGenerateReactiveDescription;

                                                                                                 
       
                                
    typedef struct FfxFsr3UpscalerSharedResourceDescriptions
    {

        FfxCreateResourceDescription
            reconstructedPrevNearestDepth;                                                                       
                                                                                                            
        FfxCreateResourceDescription dilatedDepth;                                                                   
                                                                                                       
        FfxCreateResourceDescription
            dilatedMotionVectors;                                                                       
                                                                                          
    } FfxFsr3UpscalerSharedResourceDescriptions;

                                                                            
       
                                                                              
                                            
       
                                                                                       
                                                                                 
                                                                                 
                                                                              
                     
       
                                
    typedef struct FfxFsr3UpscalerContext
    {
        uint32_t data[FFX_FSR3UPSCALER_CONTEXT_SIZE];                                                                 
                                                                       
    } FfxFsr3UpscalerContext;

                                                                          
                                                                              
       
                                                                               
                                                                                 
                                                                              
                                                                                 
                                                                             
                                                                       
                                                                                 
                                                                                          
                                                                
       
                                                              
                                                                                
                                                                                   
                                                                
                                                                                            
                                                                                
                                                           
       
                                                                                    
                                                                                   
                                                             
                                                                      
       
                                                                                      
                                                                                 
                                                                       
                                                    
       
                                                                                                                       
                                                                                                                      
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                           
               
                                                                                                               
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerContextCreate(FfxFsr3UpscalerContext* pContext,
                                                      const FfxFsr3UpscalerContextDescription* pContextDescription);

                                                                                              
       
                                                                                              
                                                                                                               
                 
       
                
                                                           
                
                                                
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerGetSharedResourceDescriptions(
        FfxFsr3UpscalerContext* context, FfxFsr3UpscalerSharedResourceDescriptions* SharedResources);

                                                                                  
       
                                                                              
                                                                                 
                                                                                     
                                                                     
                                                                                 
                                                                                   
                   
       
                                                                                  
                                                                                           
                                                                                  
                                                                                  
                                                                        
                                                            
                                                                                      
                                                                                   
                                                            
                                                                                 
                                                                        
                                                                                     
                                                     
       
                                                                                                           
                                                                                                                       
       
               
                                                                                 
               
                                                                                                        
                                                                 
               
                                                                                                                     
                                                      
               
                                                                                                          
                           
               
                                                                                                               
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerContextDispatch(FfxFsr3UpscalerContext* pContext,
                                                        const FfxFsr3UpscalerDispatchDescription* pDispatchDescription);

                                                                                                                     
       
                                                                                                           
                                                                                                                    
                 
       
               
                                                                                 
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerContextGenerateReactiveMask(
        FfxFsr3UpscalerContext* pContext, const FfxFsr3UpscalerGenerateReactiveDescription* pParams);

                                                        
       
                                                                                                                      
       
               
                                                                                 
               
                                                                                                         
                           
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerContextDestroy(FfxFsr3UpscalerContext* pContext);

                                                    
       
                                                                          
                                     
       
                                                                            
                                                                             
                                                                            
                                                                            
                                                                            
                                                                            
       
                                                                      
       
                                                                    
       
                
                                                           
                                                               
       
                                
    FFX_API float ffxFsr3UpscalerGetUpscaleRatioFromQualityMode(FfxFsr3UpscalerQualityMode qualityMode);

                                                                             
                                             
       
                                                            
                                                                                      
       
                                                                                                                 
                         
                                                                                                                 
                          
                                                                                
                                                                                 
                                                                                         
       
               
                                                                                 
               
                                                                                                              
                    
               
                                                                                  
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerGetRenderResolutionFromQualityMode(uint32_t* pRenderWidth,
                                                                           uint32_t* pRenderHeight,
                                                                           uint32_t displayWidth,
                                                                           uint32_t displayHeight,
                                                                           FfxFsr3UpscalerQualityMode qualityMode);

                                                                          
                   
       
                                                                               
                                                        
                                                              
       
                                                                        
                                                     
       
                                                                                           
                                                                                               
                                                                                          
                                                                                          
                                                                                          
                                                                                          
                                                                                           
       
                                                                        
                                                                         
       
                
                                                                                                                       
       
                                
    FFX_API int32_t ffxFsr3UpscalerGetJitterPhaseCount(int32_t renderWidth, int32_t displayWidth);

                                                                  
       
                                                                                    
                                                                                  
                                                                                  
                                                                            
                                                                                    
                                                                        
                                                                                            
                                                                                    
                                                                                                
                                                       
                                                                                           
       
                                                                               
                                                                         
                                 
       
                                                                       
                                                                                          
                                                                             
                                                                                 
                                     
       
                                                                                                           
       
                              
                              
                                                                                        
       
                                                                      
                                                                        
                                                                                                                     
                                                                                                
       
                                                                              
                                                                                 
                                                                                        
                                                                                   
                                                                            
                                                                              
                                    
       
                                                                                          
                                                            
                                               
                                                                                         
                                                                                 
       
                                                                                           
                                                                                     
                                                          
       
                                                                                                                      
                            
                                                                                                                      
                            
                                                                                 
                                                                           
                                                         
       
               
                                                                                 
               
                                                                                                            
               
                                                                                                     
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerGetJitterOffset(float* pOutX, float* pOutY, int32_t index, int32_t phaseCount);

                                                   
                                                                
       
                                                                        
       
                
                                                                              
                                                                
                
                                                                          
                                                                
       
                                
    FFX_API bool ffxFsr3UpscalerResourceIsNull(FfxResource resource);

                                                                                
       
                                                                                                           
                                                                                                      
                                                                                                         
                             
       
               
                                                                                 
               
                                                                                                 
               
                                                                            
       
                                
    FFX_API FfxErrorCode ffxFsr3UpscalerSetConstant(FfxFsr3UpscalerContext* context, FfxFsr3UpscalerConfigureKey key,
                                                    void* valuePtr);

#if defined(__cplusplus)
}
#endif                            
}                   