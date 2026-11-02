#include "../../sdk/src/backends/vk/fsr3_of/fsr3_opticalflow.h"
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
// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#include "ffx_provider_framegeneration.h"
#include "backends.h"
#include <ffx_api/ffx_framegeneration.hpp>
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include <FidelityFX/host/ffx_opticalflow.h>
#include <FidelityFX/gpu/frameinterpolation/ffx_frameinterpolation_resources.h>
#include <stdlib.h>
#include <cmath>
#include <algorithm>

                                                                                
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
static bool nfruGameMvEnabled()
{
#ifdef _WIN32
    char value[8]{};
    const DWORD count = GetEnvironmentVariableA("NFRU_GAME_MV", value, sizeof(value));
    return count == 1 && value[0] == '1';
#else
    const char* value = getenv("NFRU_GAME_MV");
    return value && strcmp(value, "1") == 0;
#endif
}
static bool nfruEngineMlof2()                                                                                        
{
#ifdef _WIN32
    char value[16]{};
    const DWORD count = GetEnvironmentVariableA("NFRU_ENGINE", value, sizeof(value));
    return count == 5 && strcmp(value, "mlof2") == 0;
#else
    const char* value = getenv("NFRU_ENGINE");
    return value && strcmp(value, "mlof2") == 0;
#endif
}

static uint32_t ConvertContextFlagsFI(const uint32_t apiFlags)
{
    uint32_t outFlags = 0;
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INFINITE)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_ENABLE_DEPTH_INFINITE;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_WARP_FRAGMENT)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_WARP_FRAGMENT;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_FILL_HOLES_FRAGMENT;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_PRE_PROCESS_FRAGMENT;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_DEBUG_VIEW_FRAGMENT;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH;
    }
    if (apiFlags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR)
    {
        outFlags |= FFX_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR;
    }
    return outFlags;
}

                                                                                      
static bool IsBackBufferFormatSupportedByOpticalFlow(uint32_t apiFormat)
{
    switch (apiFormat)
    {
    case FFX_API_SURFACE_FORMAT_R8G8B8A8_UNORM:
    case FFX_API_SURFACE_FORMAT_R8G8B8A8_TYPELESS:
    case FFX_API_SURFACE_FORMAT_B8G8R8A8_UNORM:
    case FFX_API_SURFACE_FORMAT_B8G8R8A8_TYPELESS:
    case FFX_API_SURFACE_FORMAT_R11G11B10_FLOAT:
    case FFX_API_SURFACE_FORMAT_R8_UNORM:
        return true;
#ifdef FFX_BACKEND_DX12
                                                                                                                        
    case FFX_API_SURFACE_FORMAT_R10G10B10A2_UNORM:
    case FFX_API_SURFACE_FORMAT_R16G16B16A16_FLOAT:
        return true;
#endif
    default:
        return false;
    }
}

bool ffxProvider_FrameGeneration::CanProvide(uint64_t type) const
{
    return (type & FFX_API_EFFECT_MASK) == FFX_API_EFFECT_ID_FRAMEGENERATION;
}

const uint32_t MAX_QUEUED_FRAMES = 2;

constexpr uint64_t NFRU_MFG_DESC = 0x4E46525500000001ull;
struct NfruMfgDesc { ffxDispatchDescHeader header; uint32_t index, count; };
constexpr uint64_t NFRU_HUD_DESC = 0x4E46525500000002ull;
struct NfruHudDesc { ffxDispatchDescHeader header; FfxApiResource fullColor; };

static bool nfruFsr3OfEnabled(){
#ifdef FFX_BACKEND_DX12
 return false;                                                                                       
#endif
 char value[32]{};
#ifdef _WIN32
 GetEnvironmentVariableA("NFRU_OF_BACKEND",value,sizeof(value));
#else
 if(const char* v=getenv("NFRU_OF_BACKEND"))snprintf(value,sizeof(value),"%s",v);
#endif
 return strcmp(value,"fsr3")==0;
}

struct InternalFgContext
{
    InternalContextHeader header;
    uint64_t mfgFrameId = 0;
    uint32_t mfgExpected = 1, mfgCount = 1;
    bool interpolationInputsRegistered = false;

    FfxInterface                 backendInterfaceFi;
    FfxInterface                 backendInterfaceShared;
    FfxOpticalFlowContext        armOFContext;
    Fsr3OpticalflowContext fsr3OFContext;
    FfxResourceInternal fsr3RawFlow{},fsr3Scd{};
    bool fsr3Enabled=false;
    FfxFrameInterpolationContext armFiContext;
    FfxResourceInternal          sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT];
    FfxResourceStates historyInitialStates[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT]{};
    bool historyInitialized = false;
    uint32_t                     effectContextIdShared, effectContextIdFi;
    FfxDimensions2D renderSize, displaySize;
    uint32_t                     flags;
    float                        deltaTime;

    bool                                     frameGenEnabled;
    uint32_t                                 frameGenFlags;
    ffxApiDispatchDescFrameGenerationPrepare prepareDescriptions[MAX_QUEUED_FRAMES];

    struct Callbacks
    {
        FfxApiCallbackFrameGenerationPresentFunc presentCallback;
        void*                                    presentCallbackUserContext;
        FfxApiDispatchFrameGenerationFunc        frameGenerationCallback;
        void*                                    frameGenerationCallbackUserContext;
    } callbacks[MAX_QUEUED_FRAMES];

    uint64_t lastConfigureFrameID;

    bool          dumpGeneratedFrame;
    const char*   dumpGeneratedFramePath;
    ffxApiMessage fpMessage;

    FfxDimensions2D ofInputColourLaneSize;                                                                        
    bool            requiresColourDownsample;                                                              
};

#define STRINGIFY_(X)                            #X
#define STRINGIFY(X)                             STRINGIFY_(X)
#define MAKE_VERSION_STRING(major, minor, patch) STRINGIFY major "." STRINGIFY minor "." STRINGIFY patch

uint64_t ffxProvider_FrameGeneration::GetId() const
{
                              
    return 0xF600'0000ull << 32u |
           (FFX_SDK_MAKE_VERSION(FFX_FRAMEINTERPOLATION_VERSION_MAJOR, FFX_FRAMEINTERPOLATION_VERSION_MINOR, FFX_FRAMEINTERPOLATION_VERSION_PATCH) &
            0xFFFF'FFFF);
}

const char* ffxProvider_FrameGeneration::GetVersionName() const
{
    return MAKE_VERSION_STRING(FFX_FRAMEINTERPOLATION_VERSION_MAJOR, FFX_FRAMEINTERPOLATION_VERSION_MINOR, FFX_FRAMEINTERPOLATION_VERSION_PATCH);
}

                                                                                  
static FfxApiReturnCodes CreateOpticalFlow(InternalFgContext* internal_context, const FfxCreateResourceDescription* createResourceDesc)
{
    TRY2(internal_context->backendInterfaceShared.fpCreateResource(
        &internal_context->backendInterfaceShared,
        createResourceDesc,
        internal_context->effectContextIdShared,
        &internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR]));
    return FFX_API_RETURN_OK;
};

                                                                               
static FfxApiReturnCodes CreateDepthTm1(InternalFgContext*                  internal_context,
                                        const FfxCreateResourceDescription* depthTm1Desc,
                                        const FfxCreateResourceDescription* depthTm1NextDesc)
{
    TRY2(internal_context->backendInterfaceShared.fpCreateResource(&internal_context->backendInterfaceShared,
                                                                   depthTm1Desc,
                                                                   internal_context->effectContextIdShared,
                                                                   &internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1]));
    TRY2(internal_context->backendInterfaceShared.fpCreateResource(
        &internal_context->backendInterfaceShared,
        depthTm1NextDesc,
        internal_context->effectContextIdShared,
        &internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1_NEXT]));
    internal_context->historyInitialStates[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1] = depthTm1Desc->initialState;
    internal_context->historyInitialStates[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1_NEXT] = depthTm1NextDesc->initialState;
    return FFX_API_RETURN_OK;
};

                                                                                  
static FfxApiReturnCodes CreateColorTm1(InternalFgContext* internal_context, const FfxCreateResourceDescription* createResourceDesc)
{
    TRY2(internal_context->backendInterfaceShared.fpCreateResource(
        &internal_context->backendInterfaceShared,
        createResourceDesc,
        internal_context->effectContextIdShared,
        &internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE]));
    TRY2(internal_context->backendInterfaceShared.fpCreateResource(
        &internal_context->backendInterfaceShared,
        createResourceDesc,
        internal_context->effectContextIdShared,
        &internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP]));
    internal_context->historyInitialStates[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE] = createResourceDesc->initialState;
    internal_context->historyInitialStates[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP] = createResourceDesc->initialState;
    return FFX_API_RETURN_OK;
};

                                                                                                                          
                                                                                       
                                                                                                                      
                                                                                               
                                                                                               
                                                                              
static FfxApiReturnCodes CreateColorTm1Resources(InternalFgContext*                  internal_context,
                                                 const FfxCreateResourceDescription* ofColorTm1Desc,
                                                 uint32_t                            displayWidth,
                                                 uint32_t                            displayHeight,
                                                 bool                                bindAsRenderTarget)
{
    if (internal_context->requiresColourDownsample)
    {
                                                     
        FfxCreateResourceDescription fullResDesc = *ofColorTm1Desc;
        fullResDesc.resourceDescription.width    = displayWidth;
        fullResDesc.resourceDescription.height   = displayHeight;
        fullResDesc.name                         = "ARM_ColorTm1_FullRes";
        if (bindAsRenderTarget)
        {
            fullResDesc.resourceDescription.usage = FfxResourceUsage(FFX_RESOURCE_USAGE_RENDERTARGET);
        }
        TRY2(CreateColorTm1(internal_context, &fullResDesc));

                                                                              
                                                                                 
                                                             
    }
    else
    {
        FfxCreateResourceDescription desc = *ofColorTm1Desc;
        if (bindAsRenderTarget)
        {
            desc.resourceDescription.usage = FfxResourceUsage(FFX_RESOURCE_USAGE_RENDERTARGET);
        }
        TRY2(CreateColorTm1(internal_context, &desc));
    }
    return FFX_API_RETURN_OK;
}

ffxReturnCode_t ffxProvider_FrameGeneration::CreateContext(ffxContext* context, ffxCreateContextDescHeader* header, Allocator& alloc) const
{
    if (auto desc = ffx::DynamicCast<ffxApiCreateContextDescFrameGeneration>(header))
    {
                                                                                                
                                                           
        if (!IsBackBufferFormatSupportedByOpticalFlow(desc->backBufferFormat))
        {
            if (desc->fpMessage)
            {
                desc->fpMessage(FFX_API_MESSAGE_TYPE_ERROR,
                                "Unsupported backbuffer format for optical flow. Supported formats are "
                                "R8G8B8A8_UNORM, B8G8R8A8_UNORM, R11G11B10_FLOAT and R8_UNORM.");
            }
            return FFX_API_RETURN_ERROR_PARAMETER;
        }

        InternalFgContext* internal_context = alloc.construct<InternalFgContext>();
        VERIFY(internal_context, FFX_API_RETURN_ERROR_MEMORY);
        internal_context->header.provider = this;

        TRY(MustCreateBackend(header, &internal_context->backendInterfaceShared, 1, alloc));
        internal_context->fsr3Enabled=nfruFsr3OfEnabled();
        TRY(MustCreateBackend(header, &internal_context->backendInterfaceFi, internal_context->fsr3Enabled?3:2, alloc));

        {
            TRY2(internal_context->backendInterfaceShared.fpCreateBackendContext(
                &internal_context->backendInterfaceShared, FFX_EFFECT_SHAREDAPIBACKEND, nullptr, &internal_context->effectContextIdShared));

            FfxErrorCode           result          = FFX_OK;
            FfxDimensions2D        opticalFlowSize = {0, 0};
            FfxOpticalFlowGridSize ofGridSize      = FFX_OPTICAL_FLOW_GRID_SIZE_UNKNOWN;
            internal_context->flags                = desc->flags;
            internal_context->renderSize = {desc->renderSize.width, desc->renderSize.height};
            internal_context->displaySize = {desc->displaySize.width, desc->displaySize.height};
            internal_context->fpMessage            = desc->fpMessage;

                                                                                                            
            if (desc->displaySize.height <= FFX_FRAMEINTERPOLATION_OF_INPUT_COLOUR_MAX_HEIGHT)
            {
                internal_context->ofInputColourLaneSize    = {desc->displaySize.width, desc->displaySize.height};
                internal_context->requiresColourDownsample = false;
            }
            else
            {
                const float A                                  = static_cast<float>(desc->displaySize.width) / static_cast<float>(desc->displaySize.height);
                internal_context->ofInputColourLaneSize.width  = static_cast<uint32_t>(floorf(FFX_FRAMEINTERPOLATION_OF_INPUT_COLOUR_MAX_HEIGHT * A));
                internal_context->ofInputColourLaneSize.height = FFX_FRAMEINTERPOLATION_OF_INPUT_COLOUR_MAX_HEIGHT;
                internal_context->requiresColourDownsample     = true;
            }

            if (desc->fpMessage)
            {
                desc->fpMessage(FFX_MESSAGE_TYPE_WARNING, "Request to use data graph optical flow.");
            }

            ofGridSize = ffxGetDefaultDataGraphOpticalFlowGridSize(internal_context->backendInterfaceShared);

            FfxOpticalFlowContextDescription ofDescription = {};
            ofDescription.backendInterface                 = internal_context->backendInterfaceFi;
            ofDescription.resolution                       = internal_context->ofInputColourLaneSize;
            ofDescription.maxRenderSize.width              = desc->renderSize.width;
            ofDescription.maxRenderSize.height             = desc->renderSize.height;
            memcpy(ofDescription.initialViewProjection, desc->initialViewProjection, sizeof(ofDescription.initialViewProjection));
            ofDescription.gridSize         = ofGridSize;
            ofDescription.performanceLevel = FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM;
            ofDescription.backBufferFormat = ConvertEnum<FfxSurfaceFormat>(desc->backBufferFormat);

            if (desc->flags & FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED)
            {
                ofDescription.flags |= FFX_OPTICALFLOW_ENABLE_DEPTH_INVERTED;
            }

            if (desc->flags & FFX_API_FG_CONTEXT_FLAG_MV_HINTS_FRAGMENT)
            {
                ofDescription.flags |= FFX_OPTICALFLOW_ENABLE_MV_HINTS_FRAGMENT;
            }

                                 
            result          = ffxOpticalFlowContextCreate(&internal_context->armOFContext, &ofDescription);
            opticalFlowSize = ffxOpticalFlowGetSize(&internal_context->armOFContext);

            FfxOpticalFlowSharedResourceDescriptions ofResourceDescs = {};
            TRY2(ffxOpticalFlowGetSharedResourceDescriptions(&internal_context->armOFContext, &ofResourceDescs));
            TRY2(CreateOpticalFlow(internal_context, &ofResourceDescs.opticalFlowVector));
            if(internal_context->fsr3Enabled){
                Fsr3OpticalflowContextDescription f3{};
                f3.backendInterface=internal_context->backendInterfaceFi;
                f3.resolution=internal_context->ofInputColourLaneSize;
                TRY2(fsr3OpticalflowContextCreate(&internal_context->fsr3OFContext,&f3));
                Fsr3OpticalflowSharedResourceDescriptions resources{};
                TRY2(fsr3OpticalflowGetSharedResourceDescriptions(&internal_context->fsr3OFContext,&resources));
                TRY2(internal_context->backendInterfaceShared.fpCreateResource(&internal_context->backendInterfaceShared,&resources.opticalFlowVector,internal_context->effectContextIdShared,&internal_context->fsr3RawFlow));
                TRY2(internal_context->backendInterfaceShared.fpCreateResource(&internal_context->backendInterfaceShared,&resources.opticalFlowSCD,internal_context->effectContextIdShared,&internal_context->fsr3Scd));
                if(desc->fpMessage)desc->fpMessage(FFX_MESSAGE_TYPE_WARNING,"NFRU OF backend: AMD FSR3 reference; matching pair reversed for previous-anchored forward flow");
            }


            const bool sdkManagesPrevDepth = (desc->flags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH) != 0;
            const bool sdkManagesPrevColor = (desc->flags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR) != 0;

                                                                                              
                                                                                                         
                                                                                                                      
                                                                             
            {
                const bool     full  = nfruEngineMlof2();
                const float    A     = static_cast<float>(desc->displaySize.width) / static_cast<float>(desc->displaySize.height);
                const uint32_t laneH = (full || desc->renderSize.height <= FFX_FRAMEINTERPOLATION_MV_DEPTH_LANE_MAX_HEIGHT)
                                           ? desc->renderSize.height
                                           : FFX_FRAMEINTERPOLATION_MV_DEPTH_LANE_MAX_HEIGHT;
                const uint32_t laneW = (full || desc->renderSize.height <= FFX_FRAMEINTERPOLATION_MV_DEPTH_LANE_MAX_HEIGHT)
                                           ? desc->renderSize.width
                                           : static_cast<uint32_t>(floorf(FFX_FRAMEINTERPOLATION_MV_DEPTH_LANE_MAX_HEIGHT * A));
                const FfxResourceUsage depthUsage = (desc->flags & FFX_API_FG_CONTEXT_FLAG_WARP_FRAGMENT) ? FfxResourceUsage(FFX_RESOURCE_USAGE_RENDERTARGET)
                                                                                                          : FfxResourceUsage(FFX_RESOURCE_USAGE_UAV);
                ofResourceDescs.depthTm1.resourceDescription.width      = laneW;
                ofResourceDescs.depthTm1.resourceDescription.height     = laneH;
                ofResourceDescs.depthTm1.resourceDescription.usage      = depthUsage;
                ofResourceDescs.depthTm1Next.resourceDescription.width  = laneW;
                ofResourceDescs.depthTm1Next.resourceDescription.height = laneH;
                ofResourceDescs.depthTm1Next.resourceDescription.usage  = depthUsage;
            }

                                                                                                                                
            if (sdkManagesPrevDepth || internal_context->requiresColourDownsample)
            {
                TRY2(CreateDepthTm1(internal_context, &ofResourceDescs.depthTm1, &ofResourceDescs.depthTm1Next));
            }

                                                                                                          
            if (sdkManagesPrevColor)
            {
                                                                                          
                                                                                            
                const bool bindColorTm1AsRenderTarget = (desc->flags & FFX_API_FG_CONTEXT_FLAG_POSTPROCESS_FRAGMENT) != 0;
                TRY2(CreateColorTm1Resources(
                    internal_context, &ofResourceDescs.colorTm1, desc->displaySize.width, desc->displaySize.height, bindColorTm1AsRenderTarget));
            }

                                 
            {
                FfxFrameInterpolationContextDescription fiDescription = {};
                fiDescription.backendInterface                        = internal_context->backendInterfaceFi;
                fiDescription.flags                                   = ConvertContextFlagsFI(desc->flags);
                fiDescription.maxRenderSize.width                     = desc->renderSize.width;
                fiDescription.maxRenderSize.height                    = desc->renderSize.height;
                fiDescription.displaySize.width                       = desc->displaySize.width;
                fiDescription.displaySize.height                      = desc->displaySize.height;
                fiDescription.backBufferFormat                        = ConvertEnum<FfxSurfaceFormat>(desc->backBufferFormat);
                fiDescription.opticalFlowSize                         = opticalFlowSize;
                fiDescription.opticalFlowGridSize                     = ofGridSize;
                fiDescription.fpMessage                               = reinterpret_cast<FfxFiMessage>(desc->fpMessage);

                memcpy(fiDescription.initialViewProjection, desc->initialViewProjection, sizeof(fiDescription.initialViewProjection));
                                            
                TRY2(ffxFrameInterpolationContextCreate(&internal_context->armFiContext, &fiDescription));
            }
        }

        *context = internal_context;
        return FFX_API_RETURN_OK;
    }
    else
    {
        return FFX_API_RETURN_ERROR_UNKNOWN_DESCTYPE;
    }
}

ffxReturnCode_t ffxProvider_FrameGeneration::DestroyContext(ffxContext* context, Allocator& alloc) const
{
    VERIFY(context, FFX_API_RETURN_ERROR_PARAMETER);
    VERIFY(*context, FFX_API_RETURN_ERROR_PARAMETER);

    InternalFgContext* internal_context = reinterpret_cast<InternalFgContext*>(*context);

    {                                                   
        for (FfxUInt32 i = 0; i < FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT; i++)
        {
            TRY2(internal_context->backendInterfaceShared.fpDestroyResource(
                &internal_context->backendInterfaceShared, internal_context->sharedResources[i], internal_context->effectContextIdShared));
        }

        TRY2(ffxFrameInterpolationContextDestroy(&internal_context->armFiContext));

        TRY2(ffxOpticalFlowContextDestroy(&internal_context->armOFContext));
        if(internal_context->fsr3Enabled){
            TRY2(fsr3OpticalflowContextDestroy(&internal_context->fsr3OFContext));
            TRY2(internal_context->backendInterfaceShared.fpDestroyResource(&internal_context->backendInterfaceShared,internal_context->fsr3RawFlow,internal_context->effectContextIdShared));
            TRY2(internal_context->backendInterfaceShared.fpDestroyResource(&internal_context->backendInterfaceShared,internal_context->fsr3Scd,internal_context->effectContextIdShared));
        }


        TRY2(internal_context->backendInterfaceShared.fpDestroyBackendContext(&internal_context->backendInterfaceShared,
                                                                              internal_context->effectContextIdShared));
    }

    alloc.dealloc(internal_context->backendInterfaceFi.scratchBuffer);
    alloc.dealloc(internal_context->backendInterfaceShared.scratchBuffer);
    alloc.dealloc(internal_context);

    return FFX_API_RETURN_OK;
}

ffxReturnCode_t ffxProvider_FrameGeneration::Configure(ffxContext* context, const ffxConfigureDescHeader* header) const
{
    VERIFY(context, FFX_API_RETURN_ERROR_PARAMETER);
    VERIFY(*context, FFX_API_RETURN_ERROR_PARAMETER);
    VERIFY(header, FFX_API_RETURN_ERROR_PARAMETER);

    InternalFgContext* internal_context = reinterpret_cast<InternalFgContext*>(*context);
    if (auto desc = ffx::DynamicCast<ffxApiConfigureDescFrameGeneration>(header))
    {
        FfxFrameGenerationConfig config{};
        config.allowAsyncWorkloads = desc->allowAsyncWorkloads;
        config.flags               = desc->flags;

        size_t callbacksIndex = desc->frameID % MAX_QUEUED_FRAMES;

        bool const bPresentCallbackChanged =
            (internal_context->callbacks[callbacksIndex].presentCallback != desc->presentCallback) ||
            (desc->presentCallback && (internal_context->callbacks[callbacksIndex].presentCallbackUserContext != desc->presentCallbackUserContext));
        bool const bFrameGenerationCallback =
            (internal_context->callbacks[callbacksIndex].frameGenerationCallback != desc->frameGenerationCallback) ||
            (desc->frameGenerationCallback &&
             (internal_context->callbacks[callbacksIndex].frameGenerationCallbackUserContext != desc->frameGenerationCallbackUserContext));
        internal_context->callbacks[callbacksIndex].presentCallback                    = desc->presentCallback;
        internal_context->callbacks[callbacksIndex].frameGenerationCallback            = desc->frameGenerationCallback;
        internal_context->callbacks[callbacksIndex].presentCallbackUserContext         = desc->presentCallbackUserContext;
        internal_context->callbacks[callbacksIndex].frameGenerationCallbackUserContext = desc->frameGenerationCallbackUserContext;

        config.frameGenerationCallback        = nullptr;
        config.frameGenerationCallbackContext = nullptr;
        if (desc->frameGenerationCallback != nullptr)
        {
            config.frameGenerationCallback = [](const FfxFrameGenerationDispatchDescription* desc, void* ctx) -> FfxErrorCode {
                size_t             callbacksIndex   = desc->frameID % MAX_QUEUED_FRAMES;
                InternalFgContext* internal_context = reinterpret_cast<InternalFgContext*>(ctx);
                auto               callbacks        = &internal_context->callbacks[callbacksIndex];
                VERIFY(callbacks->frameGenerationCallback, FFX_ERROR_BACKEND_API_ERROR);

                ffx::DispatchDescFrameGeneration dispatchDesc{};

                dispatchDesc.commandList        = desc->commandList;
                dispatchDesc.numGeneratedFrames = desc->numInterpolatedFrames;
                dispatchDesc.outputs[0]         = Convert(desc->outputs[0]);
                dispatchDesc.outputs[1]         = Convert(desc->outputs[1]);
                dispatchDesc.outputs[2]         = Convert(desc->outputs[2]);
                dispatchDesc.outputs[3]         = Convert(desc->outputs[3]);
                dispatchDesc.presentColor       = Convert(desc->presentColor);
                dispatchDesc.reset              = desc->reset;
                dispatchDesc.frameID            = desc->frameID;

                if (FFX_API_RETURN_OK != callbacks->frameGenerationCallback(&dispatchDesc, callbacks->frameGenerationCallbackUserContext))
                    return FFX_ERROR_BACKEND_API_ERROR;
                return FFX_OK;
            };
            config.frameGenerationCallbackContext = internal_context;
        }

        config.presentCallback        = nullptr;
        config.presentCallbackContext = nullptr;
        if (desc->presentCallback != nullptr)
        {
            config.presentCallback = [](const FfxPresentCallbackDescription* params, void* ctx) -> FfxErrorCode {
                size_t             callbacksIndex   = params->frameID % MAX_QUEUED_FRAMES;
                InternalFgContext* internal_context = reinterpret_cast<InternalFgContext*>(ctx);
                auto               callbacks        = &internal_context->callbacks[callbacksIndex];
                VERIFY(callbacks->presentCallback, FFX_ERROR_BACKEND_API_ERROR);

                ffxApiCallbackDescFrameGenerationPresent cbDesc{};
                cbDesc.header.pNext = nullptr;
                cbDesc.header.type  = FFX_API_CALLBACK_DESC_TYPE_FRAMEGENERATION_PRESENT;

                cbDesc.commandList           = params->commandList;
                cbDesc.currentBackBuffer     = Convert(params->currentBackBuffer);
                cbDesc.currentUI             = Convert(params->currentUI);
                cbDesc.device                = params->device;
                cbDesc.isGeneratedFrame      = params->isInterpolatedFrame;
                cbDesc.outputSwapChainBuffer = Convert(params->outputSwapChainBuffer);
                cbDesc.frameID               = params->frameID;

                if (FFX_API_RETURN_OK != callbacks->presentCallback(&cbDesc, callbacks->presentCallbackUserContext))
                    return FFX_ERROR_BACKEND_API_ERROR;
                return FFX_OK;
            };
            config.presentCallbackContext = internal_context;
        }

        config.frameGenerationEnabled  = desc->frameGenerationEnabled;
        config.onlyPresentInterpolated = desc->onlyPresentGenerated;
        config.swapChain               = desc->swapChain;

        config.frameID = desc->frameID;

        {
            internal_context->frameGenFlags = config.flags;

            if (config.flags & FFX_API_FG_DISPATCH_FLAG_DRAW_DEBUG_VIEW)
            {
                config.onlyPresentInterpolated = true;
            }

            if (config.flags & FFX_API_FG_DISPATCH_FLAG_DUMP_GENERATED_FRAME)
            {
                config.dumpGeneratedFrame                = true;
                config.dumpGeneratedFramePath            = desc->dumpGeneratedFramePath;
                internal_context->dumpGeneratedFrame     = true;
                internal_context->dumpGeneratedFramePath = desc->dumpGeneratedFramePath;
            }

            internal_context->frameGenEnabled = config.frameGenerationEnabled;

            if (!(config.flags & FFX_API_FG_DISPATCH_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY))
            {
                                                                                                                                                 
                if (((internal_context->lastConfigureFrameID + 1) != desc->frameID) && (bPresentCallbackChanged || bFrameGenerationCallback))
                {
                    FfxFrameGenerationConfig resetConfig       = config;
                    resetConfig.frameGenerationCallback        = nullptr;
                    resetConfig.frameGenerationCallbackContext = nullptr;
                    resetConfig.presentCallback                = nullptr;
                    resetConfig.presentCallbackContext         = nullptr;

                    TRY2(internal_context->backendInterfaceShared.fpSwapChainConfigureFrameGeneration(&resetConfig));
                }

                TRY2(internal_context->backendInterfaceShared.fpSwapChainConfigureFrameGeneration(&config));

                internal_context->lastConfigureFrameID = desc->frameID;
            }
        }

        return FFX_API_RETURN_OK;
    }
    else
    {
        return FFX_API_RETURN_ERROR_PARAMETER;
    }
}

ffxReturnCode_t ffxProvider_FrameGeneration::Query(ffxContext* context, ffxQueryDescHeader* header) const
{
    switch (header->type)
    {
    case FFX_API_QUERY_DESC_TYPE_FG_GETPIPELINESTAGEINFO:
    {
        VERIFY(context, FFX_API_RETURN_ERROR_PARAMETER);
        VERIFY(*context, FFX_API_RETURN_ERROR_PARAMETER);
        InternalFgContext* internal_context = reinterpret_cast<InternalFgContext*>(*context);
        auto               desc             = reinterpret_cast<ffxApiQueryDescFgGetPipelineStageInfo*>(header);
        TRY2(ffxFrameInterpolationGetPipelineStageInfo(&internal_context->armFiContext,
                                                       desc->pOutWarpUsesFragment,
                                                       desc->pOutFillHolesUsesFragment,
                                                       desc->pOutPreProcessUsesFragment,
                                                       desc->pOutPostprocessUsesFragment,
                                                       desc->pOutDebugViewUsesFragment));
        break;
    }
    default:
        return FFX_API_RETURN_ERROR_UNKNOWN_DESCTYPE;
    }
    return FFX_API_RETURN_OK;
}

static uint64_t getTM1Index(const uint64_t framIndex)
{
    return 2 * framIndex - 2;
}

ffxReturnCode_t ffxProvider_FrameGeneration::Dispatch(ffxContext* context, const ffxDispatchDescHeader* header) const
{
    VERIFY(context, FFX_API_RETURN_ERROR_PARAMETER);
    VERIFY(*context, FFX_API_RETURN_ERROR_PARAMETER);

    InternalFgContext* internal_context    = reinterpret_cast<InternalFgContext*>(*context);
    const bool         sdkManagesPrevDepth = (internal_context->flags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH) != 0;
    const bool         sdkManagesPrevColor = (internal_context->flags & FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR) != 0;
    if (auto desc = ffx::DynamicCast<ffxApiDispatchDescFrameGeneration>(header))
    {
        const NfruMfgDesc* mfg = nullptr;
        const NfruHudDesc* hud = nullptr;
        for (auto next = header->pNext; next; next = next->pNext) {
            if (next->type == NFRU_MFG_DESC) mfg = reinterpret_cast<const NfruMfgDesc*>(next);
            if (next->type == NFRU_HUD_DESC) hud = reinterpret_cast<const NfruHudDesc*>(next);
        }
        if (hud) {
            VERIFY(hud->fullColor.resource && hud->fullColor.resource != desc->outputs[0].resource &&
                   hud->fullColor.description.width == desc->presentColor.description.width &&
                   hud->fullColor.description.height == desc->presentColor.description.height &&
                   (hud->fullColor.description.format == desc->presentColor.description.format ||
                    (desc->presentColor.description.format == FFX_API_SURFACE_FORMAT_R11G11B10_FLOAT &&
                     (hud->fullColor.description.format == FFX_API_SURFACE_FORMAT_B8G8R8A8_UNORM ||
                      hud->fullColor.description.format == FFX_API_SURFACE_FORMAT_R8G8B8A8_UNORM))),
                   FFX_API_RETURN_ERROR_PARAMETER);
        }
        const uint32_t index = mfg ? mfg->index : 1, count = mfg ? mfg->count : 1;
        VERIFY(count >= 1 && count <= 3 && index >= 1 && index <= count, FFX_API_RETURN_ERROR_PARAMETER);
        VERIFY(desc->numGeneratedFrames == 1 && desc->outputs[0].resource, FFX_API_RETURN_ERROR_PARAMETER);
        if (index == 1) { internal_context->mfgFrameId = desc->frameID; internal_context->mfgCount = count; internal_context->mfgExpected = 1; }
        VERIFY(internal_context->mfgFrameId == desc->frameID && internal_context->mfgCount == count && internal_context->mfgExpected == index, FFX_API_RETURN_ERROR_PARAMETER);
        const bool first = index == 1, last = index == count;
        const ffxApiDispatchDescFrameGenerationPrepare* prepDesc = &internal_context->prepareDescriptions[desc->frameID % MAX_QUEUED_FRAMES];

                                                                                  
                                                                               
                                                                                   
                                                                                   
        if (!first && !internal_context->interpolationInputsRegistered) {
            auto continuationPrepare = *prepDesc;
            continuationPrepare.commandList = desc->commandList;
            TRY(Dispatch(context, &continuationPrepare.header));
        }


                       

                                                                                            
        if (first && internal_context->requiresColourDownsample)
        {
            TRY2(ffxFrameInterpolationDispatchDownsampleColour(&internal_context->armFiContext, desc->commandList, Convert(desc->presentColor)));
        }

        {
            if (first) {
            FfxOpticalFlowDispatchDescription ofDispatchDesc{};
            ofDispatchDesc.commandList = desc->commandList;

                                                                                    
            if (internal_context->requiresColourDownsample)
            {
                ffxFrameInterpolationGetDownsampledColourP1(&internal_context->armFiContext, &ofDispatchDesc.color);
                ffxFrameInterpolationGetDownsampledColourM1(&internal_context->armFiContext, &ofDispatchDesc.colorTm1);
            }
            else if (!sdkManagesPrevColor)
            {
                ofDispatchDesc.color                   = Convert(desc->presentColor);
                ofDispatchDesc.color.description.usage = FfxResourceUsage(ofDispatchDesc.color.description.usage);
                ofDispatchDesc.colorTm1                = Convert(prepDesc->colorTm1);
            }
            else
            {
                ofDispatchDesc.color                   = Convert(desc->presentColor);
                ofDispatchDesc.color.description.usage = FfxResourceUsage(ofDispatchDesc.color.description.usage);
                                                                                             
                                                                                            
                const uint32_t colorTm1Identifier = (desc->frameID % 2 == 0) ? FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE
                                                                             : FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP;
                ofDispatchDesc.colorTm1 = internal_context->backendInterfaceShared.fpGetResource(&internal_context->backendInterfaceShared,
                                                                                                 internal_context->sharedResources[colorTm1Identifier]);
            }

                                                                                         
            if (nfruGameMvEnabled() &&
                !(internal_context->flags & FFX_API_FG_CONTEXT_FLAG_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION))
            {
                ofDispatchDesc.motionVectors = Convert(prepDesc->motionVectors);
                const bool displayMv = (internal_context->flags & FFX_API_FG_CONTEXT_FLAG_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS) != 0;
                const float w = float(displayMv ? internal_context->displaySize.width : internal_context->renderSize.width);
                const float h = float(displayMv ? internal_context->displaySize.height : internal_context->renderSize.height);
                ofDispatchDesc.motionVectorUvScale = {prepDesc->motionVectorScale.x / w, prepDesc->motionVectorScale.y / h};
            }
            ofDispatchDesc.depth = Convert(prepDesc->depth);
            memcpy(ofDispatchDesc.viewProjection, prepDesc->viewProjection, sizeof(ofDispatchDesc.viewProjection));
            ofDispatchDesc.reset = desc->reset;
                                                                            
            ofDispatchDesc.opticalFlowVector = internal_context->backendInterfaceShared.fpGetResource(
                &internal_context->backendInterfaceShared, internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR]);

                                                                                                                                                            
            if (!sdkManagesPrevDepth && !internal_context->requiresColourDownsample)
            {
                ofDispatchDesc.depthTm1 = Convert(prepDesc->depthTm1);
            }
            else
            {
                ofDispatchDesc.depthTm1 = internal_context->backendInterfaceShared.fpGetResource(
                    &internal_context->backendInterfaceShared, internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1]);
            }

            TRY2(ffxOpticalFlowContextDispatch(&internal_context->armOFContext, &ofDispatchDesc));
            if(internal_context->fsr3Enabled){
                Fsr3OpticalflowDispatchDescription f3{};
                f3.commandList=ofDispatchDesc.commandList;
                f3.color=ofDispatchDesc.color;
                f3.reset=ofDispatchDesc.reset;
                f3.backbufferTransferFunction=0;                                              
                f3.minMaxLuminance={0.0f,1000.0f};
                f3.opticalFlowVector=internal_context->backendInterfaceShared.fpGetResource(&internal_context->backendInterfaceShared,internal_context->fsr3RawFlow);
                f3.opticalFlowSCD=internal_context->backendInterfaceShared.fpGetResource(&internal_context->backendInterfaceShared,internal_context->fsr3Scd);
                TRY2(fsr3OpticalflowContextDispatch(&internal_context->fsr3OFContext,&f3));
                TRY2(fsr3OpticalflowConvertForward(&internal_context->fsr3OFContext,f3.commandList,&f3.opticalFlowVector,&ofDispatchDesc.opticalFlowVector));
            }

            }
        }

                              
        {
            FfxFrameInterpolationDispatchDescription fiDispatchDesc{};

                                                                                                            
            fiDispatchDesc.commandList       = desc->commandList;
            fiDispatchDesc.currentBackBuffer = Convert(desc->presentColor);
            if (hud) fiDispatchDesc.fullColorWithHud = Convert(hud->fullColor);
            fiDispatchDesc.reset             = desc->reset;

            fiDispatchDesc.output            = Convert(desc->outputs[0]);
            fiDispatchDesc.opticalFlowVector = internal_context->backendInterfaceShared.fpGetResource(
                &internal_context->backendInterfaceShared, internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR]);

            fiDispatchDesc.opticalFlowScale = {1.f / fiDispatchDesc.opticalFlowVector.description.width,
                                               1.f / fiDispatchDesc.opticalFlowVector.description.height};

            fiDispatchDesc.frameTimeDelta          = prepDesc->frameTimeDelta;
            fiDispatchDesc.cameraNear              = prepDesc->cameraNear;
            fiDispatchDesc.cameraFar               = prepDesc->cameraFar;
            fiDispatchDesc.viewSpaceToMetersFactor = prepDesc->viewSpaceToMetersFactor;
            fiDispatchDesc.cameraFovAngleVertical  = prepDesc->cameraFovAngleVertical;

            if (internal_context->frameGenFlags & FFX_API_FG_DISPATCH_FLAG_DRAW_DEBUG_VIEW)
            {
                fiDispatchDesc.flags |= FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW;
            }

            fiDispatchDesc.frameID = desc->frameID;
            fiDispatchDesc.timestep = float(index) / float(count + 1);
            fiDispatchDesc.mfgContinuation = !first;
            fiDispatchDesc.mfgDeferHistory = !last;
            fiDispatchDesc.mfgMvResidual = count > 1 && !(internal_context->flags & FFX_API_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE);
            fiDispatchDesc.mfg           = count + 1;

            TRY2(ffxFrameInterpolationDispatch(&internal_context->armFiContext, &fiDispatchDesc));
            internal_context->interpolationInputsRegistered = false;

                                                                                             
                                                                                                                                          
            if (last && (sdkManagesPrevDepth || internal_context->requiresColourDownsample))
            {
                std::swap(internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1],
                          internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1_NEXT]);
            }
        }
        internal_context->mfgExpected = last ? 1 : index + 1;
        return FFX_API_RETURN_OK;
    }
    else if (auto desc = ffx::DynamicCast<ffxApiDispatchDescFrameGenerationPrepare>(header))
    {
                                                                                        
                                                                                       
        if (!internal_context->historyInitialized) {
            for (uint32_t id : {uint32_t(FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE),
                                uint32_t(FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP),
                                uint32_t(FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1),
                                uint32_t(FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1_NEXT)}) {
                const auto resource = internal_context->sharedResources[id];
                if (!resource.internalIndex) continue;
                FfxGpuJobDescription clear{};
                clear.jobType = FFX_GPU_JOB_CLEAR_FLOAT;
                clear.clearJobDescriptor.target = resource;
                TRY2(internal_context->backendInterfaceShared.fpScheduleGpuJob(&internal_context->backendInterfaceShared, &clear));
                FfxGpuJobDescription barrier{};
                barrier.jobType = FFX_GPU_JOB_BARRIER;
                barrier.barrierDescriptor.resource = resource;
                barrier.barrierDescriptor.barrierType = FFX_BARRIER_TYPE_TRANSITION;
                barrier.barrierDescriptor.newState = internal_context->historyInitialStates[id];
                TRY2(internal_context->backendInterfaceShared.fpScheduleGpuJob(&internal_context->backendInterfaceShared, &barrier));
            }
            TRY2(internal_context->backendInterfaceShared.fpExecuteGpuJobs(&internal_context->backendInterfaceShared, desc->commandList, internal_context->effectContextIdShared));
            internal_context->historyInitialized = true;
        }
        internal_context->prepareDescriptions[desc->frameID % MAX_QUEUED_FRAMES] = *desc;

        FfxFrameInterpolationPrepareDescription dispatchDesc{};
        dispatchDesc.commandList                = desc->commandList;
        dispatchDesc.jitterOffset.x             = desc->jitterOffset.x;
        dispatchDesc.jitterOffset.y             = desc->jitterOffset.y;
        dispatchDesc.motionVectorScale.x        = desc->motionVectorScale.x;
        dispatchDesc.motionVectorScale.y        = desc->motionVectorScale.y;
        dispatchDesc.mvSimilarityThreshold      = desc->mvSimilarityThreshold;
        dispatchDesc.mvSimilarityNoiseThreshold = desc->mvSimilarityNoiseThreshold;
        dispatchDesc.frameTimeDelta             = desc->frameTimeDelta;
        dispatchDesc.cameraNear                 = desc->cameraNear;
        dispatchDesc.cameraFar                  = desc->cameraFar;
        dispatchDesc.viewSpaceToMetersFactor    = desc->viewSpaceToMetersFactor;
        dispatchDesc.cameraFovAngleVertical     = desc->cameraFovAngleVertical;
        dispatchDesc.depth                      = Convert(desc->depth);
        dispatchDesc.motionVectors              = Convert(desc->motionVectors);
        dispatchDesc.frameID                    = desc->frameID;

        if (!sdkManagesPrevDepth && !internal_context->requiresColourDownsample && desc->depthTm1.resource == nullptr)
        {
            internal_context->fpMessage(FFX_MESSAGE_TYPE_ERROR, "No valid history provided when FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH is not set.");
            return FFX_API_RETURN_ERROR_PARAMETER;
        }

        if (!sdkManagesPrevColor && desc->colorTm1.resource == nullptr)
        {
            internal_context->fpMessage(FFX_MESSAGE_TYPE_ERROR, "No valid history provided when FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR is not set.");
            return FFX_API_RETURN_ERROR_PARAMETER;
        }
        if (!sdkManagesPrevDepth && !internal_context->requiresColourDownsample)
        {
                                                                                              
                                                                              
            dispatchDesc.depthTm1     = Convert(desc->depthTm1);
            dispatchDesc.depthTm1Next = {};                                                             
        }
        else
        {
                                                        
            dispatchDesc.depthTm1 = internal_context->backendInterfaceShared.fpGetResource(
                &internal_context->backendInterfaceShared, internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1]);
            dispatchDesc.depthTm1Next = internal_context->backendInterfaceShared.fpGetResource(
                &internal_context->backendInterfaceShared, internal_context->sharedResources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH_TM1_NEXT]);
        }
        if (!sdkManagesPrevColor)
        {
            dispatchDesc.colorTm1 = Convert(desc->colorTm1);
        }
        else
        {
                                                                                           
                                                                                          
            const bool     useBackupAsSource     = (desc->frameID % 2 != 0);
            const uint32_t colorTm1SrvIdentifier = useBackupAsSource ? FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP
                                                                     : FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE;
            const uint32_t colorTm1UavIdentifier = useBackupAsSource ? FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE
                                                                     : FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE_BACKUP;
            dispatchDesc.colorTm1       = internal_context->backendInterfaceShared.fpGetResource(&internal_context->backendInterfaceShared,
                                                                                           internal_context->sharedResources[colorTm1SrvIdentifier]);
            dispatchDesc.colorTm1Backup = internal_context->backendInterfaceShared.fpGetResource(&internal_context->backendInterfaceShared,
                                                                                                 internal_context->sharedResources[colorTm1UavIdentifier]);
        }
                               
        memcpy(dispatchDesc.viewProjection, desc->viewProjection, sizeof(desc->viewProjection));
        TRY2(ffxFrameInterpolationPrepare(&internal_context->armFiContext, &dispatchDesc));
        internal_context->interpolationInputsRegistered = true;

        return FFX_API_RETURN_OK;
    }
    else
    {
        return FFX_API_RETURN_ERROR_PARAMETER;
    }
}

ffxProvider_FrameGeneration ffxProvider_FrameGeneration::Instance;
