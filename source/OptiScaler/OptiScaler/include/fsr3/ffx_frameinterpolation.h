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

// @defgroup FRAMEINTERPOLATION

#pragma once

                                                                       
#include "ffx_interface.h"

                                                
   
                                                 
#define FFX_FRAMEINTERPOLATION_VERSION_MAJOR (1)

                                                
   
                                                 
#define FFX_FRAMEINTERPOLATION_VERSION_MINOR (0)

                                                
   
                                                 
#define FFX_FRAMEINTERPOLATION_VERSION_PATCH (0)

                                                
   
                                                                                  
   
                                  
#define FFX_FRAMEINTERPOLATION_CONTEXT_COUNT (1)

                                                      
   
                                                 
#define FFX_FRAMEINTERPOLATION_CONTEXT_SIZE (FFX_SDK_DEFAULT_CONTEXT_SIZE)

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                             
       
                                                                         
                                                                  
                                                                      
                                                                                
                                                                             
                                
       
                                                                              
                                                                                 
                                                                                  
                                                                             
                                                                                   
                                                        
       
                                                     
    typedef enum FfxFrameInterpolationPass
    {
        FFX_FRAMEINTERPOLATION_PASS_SETUP,
        FFX_FRAMEINTERPOLATION_PASS_RECONSTRUCT_PREV_DEPTH,
        FFX_FRAMEINTERPOLATION_PASS_GAME_MOTION_VECTOR_FIELD,
        FFX_FRAMEINTERPOLATION_PASS_OPTICAL_FLOW_VECTOR_FIELD,
        FFX_FRAMEINTERPOLATION_PASS_DISOCCLUSION_MASK,
        FFX_FRAMEINTERPOLATION_PASS_INTERPOLATION,
        FFX_FRAMEINTERPOLATION_PASS_INPAINTING_PYRAMID,
        FFX_FRAMEINTERPOLATION_PASS_INPAINTING,
        FFX_FRAMEINTERPOLATION_PASS_GAME_VECTOR_FIELD_INPAINTING_PYRAMID,
        FFX_FRAMEINTERPOLATION_PASS_DEBUG_VIEW,
        FFX_FRAMEINTERPOLATION_PASS_COUNT                                                           
    } FfxFrameInterpolationPass;

                           
    struct FfxFrameInterpolationContext;

                                                        
                                                                                                              
       
                                                     
    typedef enum FfxFrameInterpolationInitializationFlagBits
    {

        FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED =
            (1 << 0),                                                                                    
        FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE =
            (1 << 1),                                                                                                
        FFX_FRAMEINTERPOLATION_ENABLE_TEXTURE1D_USAGE =
            (1 << 2),                                                               
        FFX_FRAMEINTERPOLATION_ENABLE_HDR_COLOR_INPUT =
            (1 << 3)                                                                           
    } FfxFrameInterpolationInitializationFlagBits;

                                                                       
                                                
       
                                   
    typedef struct FfxFrameInterpolationContextDescription
    {

        Fsr3::FfxInterface backendInterface;                                                                        

        uint32_t flags;                                                                                
        Fsr3::FfxDimensions2D maxRenderSize;                                                           
        Fsr3::FfxDimensions2D displaySize;                                               
        Fsr3::FfxSurfaceFormat backBufferFormat;
    } FfxFrameInterpolationContextDescription;

                                                                            
       
                                                                              
                                            
       
                                                                               
                                                                                 
                                                                                 
                                                                              
                     
       
                                   
    typedef struct FfxFrameInterpolationContext
    {
        uint32_t data[FFX_FRAMEINTERPOLATION_CONTEXT_SIZE];                                                             
                                                                                 
    } FfxFrameInterpolationContext;

                                                                          
                                                                      
       
                                                                               
                                                                                 
                                                                              
                                                                                 
                                                                             
                                                                       
                                                                                 
                                                                                  
                                                                
       
                                                              
                                                                        
                                                                                   
                                                                
                                                                                    
                                                                                
                                                           
       
                                                                            
                                                                           
                                                             
                                                              
       
                                                                              
                                                                                 
                                                                       
                                            
       
                                                                                                              
                                                                                                             
       
               
                                                                                 
               
                                                                                                        
                                                                
               
                                                                            
                                                                                   
               
                                                                                                               
       
                                   
    FFX_API Fsr3::FfxErrorCode
    ffxFrameInterpolationContextCreate(FfxFrameInterpolationContext* context,
                                       FfxFrameInterpolationContextDescription* contextDescription);

    typedef enum FfxFrameInterpolationDispatchFlags
    {
        FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES =
            (1 << 0),                                                                                          
        FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW =
            (1 << 1),                                                                                                   
                                       
    } FfxFrameInterpolationDispatchFlags;

    typedef struct FfxFrameInterpolationDispatchDescription
    {

        uint32_t flags;                                                       
        Fsr3::FfxCommandList
            commandList;                                                                                   
        Fsr3::FfxDimensions2D displaySize;                                         
        Fsr3::FfxDimensions2D renderSize;                                                                  
                                                                                                      
        Fsr3::FfxResource currentBackBuffer;                                                                         
                                                       
                                                                                                 
        Fsr3::FfxResource currentBackBuffer_HUDLess;                                                                  
                                                                 
                                                                                               
        Fsr3::FfxResource output;                                                                                    
        Fsr3::FfxResource
            dilatedDepth;                                                                                           
        Fsr3::FfxResource dilatedMotionVectors;                                                                        
                                                                                
        Fsr3::FfxResource reconstructPrevNearDepth;                                                            
                                                                       
                                                                                    

        Fsr3::FfxRect2D interpolationRect;                                                                              
                                                    
                                                                                                   

        Fsr3::FfxResource opticalFlowVector;                                                                     
                                                                        
        Fsr3::FfxResource opticalFlowSceneChangeDetection;                                                  
        Fsr3::FfxDimensions2D opticalFlowBufferSize;                                                              
        Fsr3::FfxFloatCoords2D opticalFlowScale;                                                                        
                                                                                  
        int opticalFlowBlockSize;                                                          

        float cameraNear;                                                   
        float cameraFar;                                                                                         
                                              
        float cameraFovAngleVertical;                                                                             
                                                     
        float viewSpaceToMetersFactor;                                                         

        float frameTimeDelta;                                                                        
        bool reset;                                                                                             

        Fsr3::FfxBackbufferTransferFunction
            backBufferTransferFunction;                                          
                                                                                           
        float minMaxLuminance[2];                                                                                       

    } FfxFrameInterpolationDispatchDescription;

    FFX_API Fsr3::FfxErrorCode ffxFrameInterpolationDispatch(FfxFrameInterpolationContext* context,
                                                             const FfxFrameInterpolationDispatchDescription* params);

                                                        
       
                                                                                                             
       
               
                                                                                 
               
                                                                                                         
                           
       
                                   
    FFX_API Fsr3::FfxErrorCode ffxFrameInterpolationContextDestroy(FfxFrameInterpolationContext* context);

#if defined(__cplusplus)
}
#endif                            
