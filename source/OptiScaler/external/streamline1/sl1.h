/*
* Copyright (c) 2022 NVIDIA CORPORATION. All rights reserved
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

#pragma once

#include "sl1_consts.h"

#undef SL_API
                           
#define SL_API

namespace sl1 {

    using CommandBuffer = void;

                                     
        
                                                  
        
    enum BufferType : uint32_t
    {
                                                                                                                       
        eBufferTypeDepth,
                                                                           
        eBufferTypeMVec,
                                                                                                 
        eBufferTypeHUDLessColor,
                                                                                  
        eBufferTypeScalingInputColor,
                                                                       
        eBufferTypeScalingOutputColor,
                   
        eBufferTypeNormals,
                     
        eBufferTypeRoughness,
                  
        eBufferTypeAlbedo,
                           
        eBufferTypeSpecularAlbedo,
                           
        eBufferTypeIndirectAlbedo,
                         
        eBufferTypeSpecularMVec,
                             
        eBufferTypeDisocclusionMask,
                    
        eBufferTypeEmissive,
                    
        eBufferTypeExposure,
                                                             
        eBufferTypeNormalRoughness,
                                         
        eBufferTypeDiffuseHitNoisy,
                            
        eBufferTypeDiffuseHitDenoised,
                                             
        eBufferTypeSpecularHitNoisy,
                             
        eBufferTypeSpecularHitDenoised,
                        
        eBufferTypeShadowNoisy,
                           
        eBufferTypeShadowDenoised,
                    
        eBufferTypeAmbientOcclusionNoisy,
                       
        eBufferTypeAmbientOcclusionDenoised,

                                                                                                           
        eBufferTypeUIHint,
                                                                                                       
        eBufferTypeShadowHint,
                                                                                                               
        eBufferTypeReflectionHint,
                                                                                                    
        eBufferTypeParticleHint,
                                                                                                                  
        eBufferTypeTransparencyHint,
                                                                                                                           
        eBufferTypeAnimatedTextureHint,
                                                                                                                                    
        eBufferTypeBiasCurrentColorHint,
                                                               
        eBufferTypeRaytracingDistance,
                                                     
        eBufferTypeReflectionMotionVectors,
                                                                    
        eBufferTypePosition,
                                                                                                                                                                                              
        eBufferTypeInvalidDepthMotionHint
    };

                                        
        
                                                      
        
    enum Feature : uint32_t
    {
                                        
        eFeatureDLSS = 0,
                              
        eFeatureNRD = 1,
                                
        eFeatureNIS = 2,
                       
        eFeatureReflex = 3,
                                                            
        eFeatureCommon = UINT_MAX
    };

                                    
    enum LogLevel
    {
                      
        eLogLevelOff,
                           
        eLogLevelDefault,
                           
        eLogLevelVerbose,
                       
        eLogLevelCount
    };

                      
    enum ResourceType : char
    {
        eResourceTypeTex2d,
        eResourceTypeBuffer
    };

                            
    struct ResourceDesc
    {
                                          
        ResourceType type = eResourceTypeTex2d;
                                                                    
        void* desc{};
                                                                           
        uint32_t state = 0;
                                              
        void* heap{};
                                                              
        void* ext{};
    };

                       
    struct Resource
    {
                                          
        ResourceType type = eResourceTypeTex2d;
                                                          
        void* native{};
                                     
        void* memory{};
                                               
        void* view{};
                                                           
            
                                                                                         
            
        uint32_t state{};
                                                              
        void* ext{};
    };

                                                  
       
                                                      
                                                           
       
                                                                                    
       
                                                               
                                               
    using pfunResourceAllocateCallback = Resource(const ResourceDesc* desc, void* device);
    using pfunResourceReleaseCallback = void(Resource* resource, void* device);

                
    enum LogType
    {
                                                                                         
        eLogTypeInfo,
                                               
        eLogTypeWarn,
        eLogTypeError,
                       
        eLogTypeCount
    };

                        
       
                                                                
                                                                
                                                   
    using pfunLogMessageCallback = void(LogType type, const char* msg);

                      
    enum PreferenceFlags : uint64_t
    {
                                                                                                                                                        
        ePreferenceFlagDisableCLStateTracking = 1 << 0,
                                                               
        ePreferenceFlagDisableDebugText = 1 << 1,
    };

    SL_ENUM_OPERATORS_64(PreferenceFlags)

                                
        struct Preferences
    {
                                                                                               
        bool showConsole = false;
                                             
        LogLevel logLevel = eLogLevelDefault;
                                                                                                                             
        const wchar_t** pathsToPlugins = {};
                                                
        uint32_t numPathsToPlugins = 0;
                                                                                           
                                                                           
        const wchar_t* pathToLogsAndData = {};
                                                                           
        pfunResourceAllocateCallback* allocateCallback = {};
                                                                             
        pfunResourceReleaseCallback* releaseCallback = {};
                                                                                          
        pfunLogMessageCallback* logMessageCallback = {};
                                                                       
        PreferenceFlags flags{};
                                                                                                                                        
        const Feature* featuresToLoad = {};
                                                                                            
        uint32_t numFeaturesToLoad = 0;
                                                              
        void* ext = {};
    };

                             
    constexpr int kUniqueApplicationId = 0;

                                
        
    using PFunSlInit = bool(const sl1::Preferences& pref, int applicationId);
    using PFunSlShutdown = bool();
    using PFunSlSetFeatureEnabled = bool(sl1::Feature feature, bool enabled);
    using PFunSlIsFeatureEnabled = bool(sl1::Feature feature);
    using PFunSlIsFeatureSupported = bool(sl1::Feature feature, uint32_t* adapterBitMask);
    using PFunSlSetTag = bool(const sl1::Resource* resource, sl1::BufferType tag, uint32_t id, const sl1::Extent* extent);
    using PFunSlSetConstants = bool(const sl1::Constants& values, uint32_t frameIndex, uint32_t id);
    using PFunSlSetFeatureConstants = bool(sl1::Feature feature, const void* consts, uint32_t frameIndex, uint32_t id);
    using PFunSlGetFeatureSettings = bool(sl1::Feature feature, const void* consts, void* settings);
    using PFunSlEvaluateFeature = bool(sl1::CommandBuffer* cmdBuffer, sl1::Feature feature, uint32_t frameIndex, uint32_t id);
    using PFunSlAllocateResources = bool(sl1::CommandBuffer* cmdBuffer, sl1::Feature feature, uint32_t id);
    using PFunSlFreeResources = bool(sl1::Feature feature, uint32_t id);

                                 
       
                                                        
       
                                                                                         
                                                            
                                                                          
       
                                       
    SL_API bool slInit(const sl1::Preferences& pref, int applicationId = sl1::kUniqueApplicationId);

                                
       
                                                         
       
                                                                      
       
                                       
    SL_API bool slShutdown();

                                                       
       
                                                                                
                                                                                    
       
                                                       
                                                                                                  
                                                                               
       
                                                                                                     
                                                                                                               
       
                                       
    SL_API bool slIsFeatureSupported(sl1::Feature feature, uint32_t* adapterBitMask = nullptr);

                                                      
       
                                                        
                                                                                                   
       
                                                       
                                                                                                                                
       
                                                                                                 
    SL_API bool slIsFeatureEnabled(sl1::Feature feature);

                                                                       
       
                                                                 
                                                                                                   
       
                                                       
                                                                                 
                                                                                                                      
       
                                                                                                       
                                                                    
       
                                                                                                 
    SL_API bool slSetFeatureEnabled(sl1::Feature feature, bool enabled);

                     
       
                                                        
       
                                                                                           
                                                
                                                                   
                                                                                                         
                                                                                                         
       
                                                                                             
    SL_API bool slSetTag(const sl1::Resource* resource, sl1::BufferType tag, uint32_t id = 0, const sl1::Extent* extent = nullptr);

                              
       
                                                                            
       
                                                                                   
                                                    
                                                                   
                                                                                                       
        
                                                                                             
    SL_API bool slSetConstants(const sl1::Constants& values, uint32_t frameIndex, uint32_t id = 0);

                                        
       
                                                     
                                                        
       
                                                  
                                                                                     
                                                    
                                                                   
                                                                                                       
       
                                                                                             
    SL_API bool slSetFeatureConstants(sl1::Feature feature, const void* consts, uint32_t frameIndex, uint32_t id = 0);

                                       
       
                                                                      
       
                                                  
                                                               
                                                                         
                                                                                                              
       
                                                                                                 
    SL_API bool slGetFeatureSettings(sl1::Feature feature, const void* consts, void* settings);

                                                      
       
                                                         
                                                 
        
                                                                                                                                   
                                                  
                                             
                                                                                                             
       
                                                                                                 
    SL_API bool slAllocateResources(sl1::CommandBuffer* cmdBuffer, sl1::Feature feature, uint32_t id);

                                                  
       
                                                     
                                                 
        
                                                  
                                             
                                                                                                         
       
                                                                                                 
    SL_API bool slFreeResources(sl1::Feature feature, uint32_t id);

                         
        
                                                                       
                                                  
       
                                                                                                                                   
                                                  
                                                                      
                                                                   
                                                                                                                                      
        
                                                                                                                
       
                                                                                                 
    SL_API bool slEvaluateFeature(sl1::CommandBuffer* cmdBuffer, sl1::Feature feature, uint32_t frameIndex, uint32_t id = 0);
}