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

#include <FidelityFX/host/ffx_interface.h>
#include <FidelityFX/host/ffx_util.h>
#include <FidelityFX/host/ffx_assert.h>
#include <FidelityFX/host/backends/dx12/ffx_dx12.h>
#include <FidelityFX/host/backends/dx12/d3dx12.h>
#include <ffx_shader_blobs.h>
#include <codecvt>                              
#include <memoryapi.h>                    
#include <mutex>
#include <tuple>               
#include <limits>                       
#include <cmath>
#include <stdlib.h>
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include "frameinterpolation/ffx_frameinterpolation_private.h"
#include "nfru_engine_dx12.h"
#include "nfru_dx12_deferred_release.h"

                                                             
                                                                     

#if defined(ENABLE_PIX_CAPTURES)
                                                                                                                                     
                                                              
#ifndef USE_PIX
#define USE_PIX                                                                                      
#endif                             

#ifdef _GAMING_DESKTOP
	#include <pix3.h>
#else
	#include "pix/pix3.h"
#endif                   


#ifdef __clang__
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#endif

static bool s_PIXDLLLoaded = false;

typedef void(WINAPI* BeginEventOnCommandList)(ID3D12GraphicsCommandList* commandList, UINT64 color, _In_ PCSTR formatString);
typedef void(WINAPI* EndEventOnCommandList)(ID3D12GraphicsCommandList* commandList);

BeginEventOnCommandList pixBeginEventOnCommandList;
EndEventOnCommandList   pixEndEventOnCommandList;

#endif                                    

                                                         
FfxVersionNumber GetSDKVersionDX12(FfxInterface* backendInterface);
FfxErrorCode GetEffectGpuMemoryUsageDX12(FfxInterface* backendInterface, FfxUInt32 effectContextId, FfxEffectMemoryUsage* outVramUsage);
FfxErrorCode CreateBackendContextDX12(FfxInterface* backendInterface, FfxEffect effect, FfxEffectBindlessConfig* bindlessConfig, FfxUInt32* effectContextId);
FfxErrorCode GetDeviceCapabilitiesDX12(FfxInterface* backendInterface, FfxDeviceCapabilities* deviceCapabilities);
FfxErrorCode DestroyBackendContextDX12(FfxInterface* backendInterface, FfxUInt32 effectContextId);
FfxErrorCode CreateResourceDX12(FfxInterface* backendInterface, const FfxCreateResourceDescription* desc, FfxUInt32 effectContextId, FfxResourceInternal* outTexture);
FfxErrorCode DestroyResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource, FfxUInt32 effectContextId);
FfxErrorCode MapResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource, void** ptr);
FfxErrorCode UnmapResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode RegisterResourceDX12(FfxInterface* backendInterface, const FfxResource* inResource, FfxUInt32 effectContextId, FfxResourceInternal* outResourceInternal);
FfxResource GetResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode UnregisterResourcesDX12(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);
FfxErrorCode RegisterStaticResourceDX12(FfxInterface* backendInterface, const FfxStaticResourceDescription* desc, FfxUInt32 effectContextId);
FfxResourceDescription GetResourceDescriptorDX12(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode StageConstantBufferDataDX12(FfxInterface* backendInterface, void* data, FfxUInt32 size, FfxConstantBuffer* constantBuffer);
FfxErrorCode CreatePipelineDX12(FfxInterface* backendInterface, FfxEffect effect, FfxPass passId, uint32_t permutationOptions, const FfxPipelineDescription*  desc, FfxUInt32 effectContextId, FfxPipelineState* outPass);
FfxErrorCode DestroyPipelineDX12(FfxInterface* backendInterface, FfxPipelineState* pipeline, FfxUInt32 effectContextId);
FfxErrorCode CreateDataGraphPipelineDX12(FfxInterface* backendInterface, FfxEffect effect, FfxPass passId, uint32_t permutationOptions,
                                         const FfxPipelineDescription* desc, FfxUInt32 effectContextId, FfxUInt32 dataGraphWidth,
                                         FfxUInt32 dataGraphHeight, FfxPipelineState* outPipeline);
FfxErrorCode CreateOpticalFlowPipelineDX12(FfxInterface* backendInterface, const char* name, const FfxOpticalFlowDescription& ofDesc,
                                           FfxUInt32 effectContextId, FfxPipelineState* outPipeline);
static FfxErrorCode CreateGraphicsPipelineDX12(FfxInterface*, FfxEffect, FfxPass, uint32_t, const FfxPipelineDescription*, FfxUInt32, FfxPipelineState*)
{
    return FFX_ERROR_BACKEND_API_ERROR;                                                                                
}
static FfxErrorCode SetupMessageCallbackDX12(FfxInterface* backendInterface, FfxBackendMessage ffxMessageCallback)
{
    backendInterface->fpMessage = ffxMessageCallback;
    return FFX_OK;
}
                                                                                                          
static FfxErrorCode SwapChainConfigureFrameGenerationDX12(FfxFrameGenerationConfig const*)
{
    return FFX_OK;
}
FfxErrorCode ScheduleGpuJobDX12(FfxInterface* backendInterface, const FfxGpuJobDescription* job);
FfxErrorCode ExecuteGpuJobsDX12(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);
void RegisterConstantBufferAllocatorDX12(FfxInterface* backendInterface, FfxConstantBufferAllocator fpConstantAllocator);

#define FFX_MAX_RESOURCE_IDENTIFIER_COUNT   (128)
#define FFX_RING_BUFFER_DESCRIPTOR_COUNT    (FFX_RING_BUFFER_SIZE)
#define FFX_MAX_STATIC_DESCRIPTOR_COUNT   (65536)

                                      
static FfxConstantBufferAllocator s_fpConstantAllocator = nullptr;

typedef struct BackendContext_DX12 {

                                            
    typedef struct Resource
    {
#ifdef _DEBUG
        wchar_t                 resourceName[64] = {};
#endif
        ID3D12Resource*         resourcePtr;
        FfxResourceDescription  resourceDescription;
        FfxResourceStates       initialState;
        FfxResourceStates       currentState;
        uint32_t                srvDescIndex;
        uint32_t                uavDescIndex;
        uint32_t                uavDescCount;
                                                                                                                 
                                                                                                            
        ID3D12Resource*         tensorImage;
        D3D12_RESOURCE_STATES   tensorImageState;
        uint32_t                tensorImageUavIndex;                                                      
    } Resource;

    uint32_t refCount;
    uint32_t maxEffectContexts;

    ID3D12Device*           device = nullptr;

    FfxGpuJobDescription*   pGpuJobs;
    uint32_t                gpuJobCount;

    uint32_t                nextRtvDescriptor;
    ID3D12DescriptorHeap*   descHeapRtvCpu;

    ID3D12DescriptorHeap*   descHeapSrvCpu;
    ID3D12DescriptorHeap*   descHeapUavCpu;
    ID3D12DescriptorHeap*   descHeapUavGpu;

    uint32_t                descRingBufferSize;
    uint32_t                descRingBufferBase;
    ID3D12DescriptorHeap*   descRingBuffer;
    uint32_t                descBindlessBase;

    uint8_t*                pStagingRingBuffer;
    uint32_t                stagingRingBufferBase = 0;

    D3D12_RESOURCE_BARRIER  barriers[FFX_MAX_BARRIERS];
    uint32_t                barrierCount;

    IDXGIFactory*           dxgiFactory = nullptr;

    typedef struct alignas(32) EffectContext {

                                                                                  
        FfxEffect           effectId;

                              
        uint32_t            nextStaticResource;
        uint32_t            nextDynamicResource;

                      
        uint32_t            nextStaticUavDescriptor;
        uint32_t            nextDynamicUavDescriptor;

                        
        uint32_t            bindlessTextureSrvHeapStart;
        uint32_t            bindlessTextureSrvHeapSize;
        uint32_t            bindlessBufferSrvHeapStart;
        uint32_t            bindlessBufferSrvHeapSize;
        uint32_t            bindlessTextureUavHeapStart;
        uint32_t            bindlessTextureUavHeapSize;
        uint32_t            bindlessBufferUavHeapStart;
        uint32_t            bindlessBufferUavHeapSize;

        uint32_t bindlessBufferHeapStart;
        uint32_t bindlessBufferHeapEnd;

                
        bool                active;

                     
        FfxEffectMemoryUsage vramUsage;

    } EffectContext;

                      
    Resource*                   pResources;
    EffectContext*              pEffectContexts;

                          
    FfxConstantAllocation       FallbackConstantAllocator(void* data, FfxUInt64 dataSize);
    void*                       constantBufferMem;
    ID3D12Resource*             constantBufferResource;
    uint32_t                    constantBufferSize;
    uint32_t                    constantBufferOffset;
    std::mutex                  constantBufferMutex;

} BackendContext_DX12;

static uint32_t getFreeBindlessDescriptorBlock(BackendContext_DX12 *context, uint32_t size, uint32_t effectId)
{
    uint32_t base = context->descBindlessBase;

    for (uint32_t i = 0; i < context->maxEffectContexts; ++i) {
        BackendContext_DX12::EffectContext *effectContext = &context->pEffectContexts[i];
        if (i == effectId || !effectContext->active) {
            continue;
        }

        if (!(base >= effectContext->bindlessBufferHeapEnd || base + size <= effectContext->bindlessBufferHeapStart)) {
            base = effectContext->bindlessBufferHeapEnd;
            i = 0;
        }
    }

    FFX_ASSERT(base + size <= context->descBindlessBase + FFX_MAX_STATIC_DESCRIPTOR_COUNT);

    return base;
}

FFX_API size_t ffxGetScratchMemorySizeDX12(size_t maxContexts)
{
    uint32_t resourceArraySize          = FFX_ALIGN_UP(maxContexts * FFX_MAX_RESOURCE_COUNT * sizeof(BackendContext_DX12::Resource), sizeof(uint64_t));
    uint32_t contextArraySize           = FFX_ALIGN_UP(maxContexts * sizeof(BackendContext_DX12::EffectContext), sizeof(uint32_t));
    uint32_t stagingRingBufferArraySize = FFX_ALIGN_UP(maxContexts * FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE, sizeof(uint32_t));
    uint32_t gpuJobDescArraySize        = FFX_ALIGN_UP(maxContexts * FFX_MAX_GPU_JOBS * sizeof(FfxGpuJobDescription), sizeof(uint32_t));

    return FFX_ALIGN_UP(sizeof(BackendContext_DX12) + resourceArraySize + contextArraySize + stagingRingBufferArraySize + gpuJobDescArraySize, sizeof(uint64_t));
}

                                          
FfxDevice ffxGetDeviceDX12(ID3D12Device* dx12Device)
{
    FFX_ASSERT(NULL != dx12Device);
    return reinterpret_cast<FfxDevice>(dx12Device);
}

                                         
FfxErrorCode ffxGetInterfaceDX12(
    FfxInterface* backendInterface,
    FfxDevice device,
    void* scratchBuffer,
    size_t scratchBufferSize,
    size_t maxContexts) {


    FFX_RETURN_ON_ERROR(
        backendInterface,
        FFX_ERROR_INVALID_POINTER);
    FFX_RETURN_ON_ERROR(
        scratchBuffer,
        FFX_ERROR_INVALID_POINTER);
    FFX_RETURN_ON_ERROR(
        scratchBufferSize >= ffxGetScratchMemorySizeDX12(maxContexts),
        FFX_ERROR_INSUFFICIENT_MEMORY);

    backendInterface->fpGetSDKVersion = GetSDKVersionDX12;
    backendInterface->fpGetEffectGpuMemoryUsage = GetEffectGpuMemoryUsageDX12;
    backendInterface->fpCreateBackendContext = CreateBackendContextDX12;
    backendInterface->fpGetDeviceCapabilities = GetDeviceCapabilitiesDX12;
    backendInterface->fpDestroyBackendContext = DestroyBackendContextDX12;
    backendInterface->fpCreateResource = CreateResourceDX12;
    backendInterface->fpDestroyResource = DestroyResourceDX12;
    backendInterface->fpMapResource = MapResourceDX12;
    backendInterface->fpUnmapResource = UnmapResourceDX12;
    backendInterface->fpGetResource = GetResourceDX12;
    backendInterface->fpRegisterResource = RegisterResourceDX12;
    backendInterface->fpUnregisterResources = UnregisterResourcesDX12;
    backendInterface->fpRegisterStaticResource      = RegisterStaticResourceDX12;
    backendInterface->fpGetResourceDescription = GetResourceDescriptorDX12;
    backendInterface->fpStageConstantBufferDataFunc = StageConstantBufferDataDX12;
    backendInterface->fpCreateComputePipeline = CreatePipelineDX12;
    backendInterface->fpCreateGraphicsPipeline = CreateGraphicsPipelineDX12;
    backendInterface->fpCreateDataGraphPipeline = CreateDataGraphPipelineDX12;
    backendInterface->fpCreateOpticalFlowPipeline = CreateOpticalFlowPipelineDX12;
    backendInterface->fpGetPermutationBlobByIndex = ffxGetPermutationBlobByIndex;
    backendInterface->fpDestroyPipeline = DestroyPipelineDX12;
    backendInterface->fpScheduleGpuJob = ScheduleGpuJobDX12;
    backendInterface->fpExecuteGpuJobs = ExecuteGpuJobsDX12;
    backendInterface->fpSwapChainConfigureFrameGeneration = SwapChainConfigureFrameGenerationDX12;
    backendInterface->fpMessage = nullptr;
    backendInterface->fpSetMessageCallback = SetupMessageCallbackDX12;
    backendInterface->devCapInitialized = false;
    backendInterface->fpRegisterConstantBufferAllocator = RegisterConstantBufferAllocatorDX12;

                         
    backendInterface->scratchBuffer = scratchBuffer;
    backendInterface->scratchBufferSize = scratchBufferSize;

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    FFX_RETURN_ON_ERROR(
        !backendContext->refCount,
        FFX_ERROR_BACKEND_API_ERROR);

                           
    memset(backendContext, 0, sizeof(*backendContext));

                     
    backendInterface->device = device;


                                                       
    backendContext->maxEffectContexts = (uint32_t)maxContexts;

    return FFX_OK;
}

FfxCommandList ffxGetCommandListDX12(ID3D12CommandList* cmdList)
{
    FFX_ASSERT(NULL != cmdList);
    return reinterpret_cast<FfxCommandList>(cmdList);
}

FfxPipeline ffxGetPipelineDX12(ID3D12PipelineState* pipelineState)
{
    FFX_ASSERT(NULL != pipelineState);
    return reinterpret_cast<FfxPipeline>(pipelineState);
}

                                          
FfxResource ffxGetResourceDX12(const ID3D12Resource* dx12Resource,
    FfxResourceDescription                     ffxResDescription,
    const wchar_t* ffxResName,
    FfxResourceStates                          state                                     )
{
    FfxResource resource = {};
    resource.resource    = reinterpret_cast<void*>(const_cast<ID3D12Resource*>(dx12Resource));
    resource.state = state;
    resource.description = ffxResDescription;

#ifdef _DEBUG
    if (ffxResName) {
        wcscpy_s(resource.name, ffxResName);
    }
#else
    (void)ffxResName;
#endif

    return resource;
}

FfxErrorCode ffxLoadPixDll(const wchar_t* pixDllPath)
{
#if defined(ENABLE_PIX_CAPTURES)
                        
    if (s_PIXDLLLoaded)
        return FFX_OK;

    HMODULE module = LoadLibrary(pixDllPath);

    if (!module)
    {
        return FFX_ERROR_INVALID_PATH;
    }

                                                   
    pixBeginEventOnCommandList = (BeginEventOnCommandList)GetProcAddress(module, "PIXBeginEventOnCommandList");
    pixEndEventOnCommandList   = (EndEventOnCommandList)GetProcAddress(module, "PIXEndEventOnCommandList");
    if (!pixBeginEventOnCommandList || !pixEndEventOnCommandList)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    s_PIXDLLLoaded = true;
#endif                                    

    return FFX_OK;
}

void TIF(HRESULT result)
{
    if (FAILED(result)) {

        wchar_t errorMessage[256];
        memset(errorMessage, 0, 256);
        FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM, NULL, result, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), errorMessage, 255, NULL);
        char errA[256];
        size_t returnSize;
        wcstombs_s(&returnSize, errA, 255, errorMessage, 255);
#ifdef _DEBUG
        std::ignore = MessageBoxW(NULL, errorMessage, L"Error", MB_OK);
#endif
        throw 1;
    }
}

FfxConstantAllocation BackendContext_DX12::FallbackConstantAllocator(void* data, FfxUInt64 dataSize)
{
    FfxConstantAllocation allocation;
    std::lock_guard<std::mutex> cbLock{ constantBufferMutex };

    if (!constantBufferMem)
    {
                                                          
        constantBufferSize = FFX_ALIGN_UP(FFX_BUFFER_SIZE, 256) * maxEffectContexts * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES;                       

        CD3DX12_RESOURCE_DESC constDesc = CD3DX12_RESOURCE_DESC::Buffer(constantBufferSize);
        CD3DX12_HEAP_PROPERTIES heap(D3D12_HEAP_TYPE_UPLOAD);
        TIF(device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE,
            &constDesc, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&constantBufferResource)));
        constantBufferResource->SetName(L"FFX_DX12_DynamicRingBuffer");

                 
        TIF(constantBufferResource->Map(0, nullptr,
            (void**)&constantBufferMem));
        constantBufferOffset = 0;
    }

    FFX_ASSERT(constantBufferMem);

    uint32_t size = FFX_ALIGN_UP(dataSize, 256);

                      
    if (constantBufferOffset + size >= constantBufferSize)
        constantBufferOffset = 0;

    void* pBuffer = (void*)((uint8_t*)(constantBufferMem)+constantBufferOffset);
    memcpy(pBuffer, data, (size_t)dataSize);

    D3D12_GPU_VIRTUAL_ADDRESS bufferViewDesc = constantBufferResource->GetGPUVirtualAddress() + constantBufferOffset;

                        
    constantBufferOffset += size;

    allocation.resource = FfxResource();                          
    allocation.handle = FfxUInt64(bufferViewDesc);

    return allocation;
}

                                                                 
static DXGI_FORMAT convertFormatUav(DXGI_FORMAT format)
{
    switch (format) 
    {
                       
        case DXGI_FORMAT_R32G8X24_TYPELESS:
        case DXGI_FORMAT_D32_FLOAT_S8X24_UINT:
            return DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS;
        case DXGI_FORMAT_D32_FLOAT:
            return DXGI_FORMAT_R32_FLOAT;
        case DXGI_FORMAT_R24G8_TYPELESS:
        case DXGI_FORMAT_X24_TYPELESS_G8_UINT:
        case DXGI_FORMAT_D24_UNORM_S8_UINT:
            return DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
        case DXGI_FORMAT_D16_UNORM:
            return DXGI_FORMAT_R16_UNORM;

                                                                            
        case DXGI_FORMAT_R32G32B32A32_TYPELESS:
            return DXGI_FORMAT_R32G32B32A32_FLOAT;
        case DXGI_FORMAT_R32G32B32_TYPELESS:
            return DXGI_FORMAT_R32G32B32_FLOAT;
        case DXGI_FORMAT_R16G16B16A16_TYPELESS:
            return DXGI_FORMAT_R16G16B16A16_FLOAT;
        case DXGI_FORMAT_R8G8B8A8_TYPELESS:
        case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
            return DXGI_FORMAT_R8G8B8A8_UNORM;
        case DXGI_FORMAT_R32G32_TYPELESS:
            return DXGI_FORMAT_R32G32_FLOAT;
        case DXGI_FORMAT_R16G16_TYPELESS:
            return DXGI_FORMAT_R16G16_FLOAT;
        case DXGI_FORMAT_R10G10B10A2_TYPELESS:
            return DXGI_FORMAT_R10G10B10A2_UNORM;
        case DXGI_FORMAT_B8G8R8A8_TYPELESS:
        case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
            return DXGI_FORMAT_B8G8R8A8_UNORM;
        case DXGI_FORMAT_B8G8R8X8_TYPELESS:
            return DXGI_FORMAT_B8G8R8X8_UNORM_SRGB;
        case DXGI_FORMAT_R32_TYPELESS:
            return DXGI_FORMAT_R32_FLOAT;
        case DXGI_FORMAT_R8G8_TYPELESS:
            return DXGI_FORMAT_R8G8_UNORM;
        case DXGI_FORMAT_R16_TYPELESS:
            return DXGI_FORMAT_R16_FLOAT;
        case DXGI_FORMAT_R8_TYPELESS:
            return DXGI_FORMAT_R8_UNORM;
        default:
            return format;
    }
}

                                                                 
static DXGI_FORMAT convertFormatSrv(DXGI_FORMAT format)
{
    switch (format) 
    {
                       
        case DXGI_FORMAT_R32G8X24_TYPELESS:
        case DXGI_FORMAT_D32_FLOAT_S8X24_UINT:
            return DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS;
        case DXGI_FORMAT_D32_FLOAT:
            return DXGI_FORMAT_R32_FLOAT;
        case DXGI_FORMAT_R24G8_TYPELESS:
        case DXGI_FORMAT_X24_TYPELESS_G8_UINT:
        case DXGI_FORMAT_D24_UNORM_S8_UINT:
            return DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
        case DXGI_FORMAT_D16_UNORM:
            return DXGI_FORMAT_R16_UNORM;

                                                                            
        case DXGI_FORMAT_R32G32B32A32_TYPELESS:
            return DXGI_FORMAT_R32G32B32A32_FLOAT;
        case DXGI_FORMAT_R32G32B32_TYPELESS:
            return DXGI_FORMAT_R32G32B32_FLOAT;
        case DXGI_FORMAT_R16G16B16A16_TYPELESS:
            return DXGI_FORMAT_R16G16B16A16_FLOAT;
        case DXGI_FORMAT_R8G8B8A8_TYPELESS:
            return DXGI_FORMAT_R8G8B8A8_UNORM;
        case DXGI_FORMAT_R32G32_TYPELESS:
            return DXGI_FORMAT_R32G32_FLOAT;
        case DXGI_FORMAT_R16G16_TYPELESS:
            return DXGI_FORMAT_R16G16_FLOAT;
        case DXGI_FORMAT_R10G10B10A2_TYPELESS:
            return DXGI_FORMAT_R10G10B10A2_UNORM;
        case DXGI_FORMAT_B8G8R8A8_TYPELESS:
            return DXGI_FORMAT_B8G8R8A8_UNORM;
        case DXGI_FORMAT_B8G8R8X8_TYPELESS:
            return DXGI_FORMAT_B8G8R8X8_UNORM_SRGB;
        case DXGI_FORMAT_R32_TYPELESS:
            return DXGI_FORMAT_R32_FLOAT;
        case DXGI_FORMAT_R8G8_TYPELESS:
            return DXGI_FORMAT_R8G8_UNORM;
        case DXGI_FORMAT_R16_TYPELESS:
            return DXGI_FORMAT_R16_FLOAT;
        case DXGI_FORMAT_R8_TYPELESS:
            return DXGI_FORMAT_R8_UNORM;
        default:
            return format;
    }
}

                                                                                                                     
                                                                                                                       
                                                                                                    
D3D12_RESOURCE_STATES ffxGetDX12StateFromResourceState(FfxResourceStates state)
{
    if (state & (FFX_RESOURCE_STATE_COMPUTE_UAV | FFX_RESOURCE_STATE_PIXEL_UAV))
        return D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    if (state == FFX_RESOURCE_STATE_COMMON)
        return D3D12_RESOURCE_STATE_COMMON;
    if (state & FFX_RESOURCE_STATE_PRESENT)
        return D3D12_RESOURCE_STATE_PRESENT;
    if (state & FFX_RESOURCE_STATE_RENDER_TARGET)
        return D3D12_RESOURCE_STATE_RENDER_TARGET;
    if (state & FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT)
        return D3D12_RESOURCE_STATE_DEPTH_WRITE;
    if (state & FFX_RESOURCE_STATE_COPY_DEST)
        return D3D12_RESOURCE_STATE_COPY_DEST;
    D3D12_RESOURCE_STATES out = D3D12_RESOURCE_STATE_COMMON;
    if (state & (FFX_RESOURCE_STATE_COMPUTE_READ | FFX_RESOURCE_STATE_PIXEL_READ | FFX_RESOURCE_STATE_DATA_GRAPH_READ))
        out |= D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
    if (state & FFX_RESOURCE_STATE_COPY_SRC)
        out |= D3D12_RESOURCE_STATE_COPY_SOURCE;
    if (state & FFX_RESOURCE_STATE_INDIRECT_ARGUMENT)
        out |= D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT;
    if (state & FFX_RESOURCE_STATE_DATA_GRAPH_WRITE)
        out = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    return out;
}

DXGI_FORMAT ffxGetDX12FormatFromSurfaceFormat(FfxSurfaceFormat surfaceFormat)
{
    switch (surfaceFormat) 
    {
        case (FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS):
            return DXGI_FORMAT_R32G32B32A32_TYPELESS;
        case (FFX_SURFACE_FORMAT_R32G32B32A32_UINT):
            return DXGI_FORMAT_R32G32B32A32_UINT;
        case (FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT):
            return DXGI_FORMAT_R32G32B32A32_FLOAT;
        case (FFX_SURFACE_FORMAT_R16G16B16A16_TYPELESS):
            return DXGI_FORMAT_R16G16B16A16_TYPELESS;
        case (FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT):
            return DXGI_FORMAT_R16G16B16A16_FLOAT;
        case (FFX_SURFACE_FORMAT_R32G32B32_FLOAT):
            return DXGI_FORMAT_R32G32B32_FLOAT;
        case (FFX_SURFACE_FORMAT_R32G32_TYPELESS):
            return DXGI_FORMAT_R32G32_TYPELESS;
        case (FFX_SURFACE_FORMAT_R32G32_FLOAT):
            return DXGI_FORMAT_R32G32_FLOAT;
        case (FFX_SURFACE_FORMAT_R32_UINT):
            return DXGI_FORMAT_R32_UINT;
        case(FFX_SURFACE_FORMAT_R10G10B10A2_TYPELESS):
            return DXGI_FORMAT_R10G10B10A2_TYPELESS;
        case(FFX_SURFACE_FORMAT_R10G10B10A2_UNORM):
            return DXGI_FORMAT_R10G10B10A2_UNORM;
        case (FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS):
            return DXGI_FORMAT_R8G8B8A8_TYPELESS;
        case (FFX_SURFACE_FORMAT_R8G8B8A8_UNORM):
            return DXGI_FORMAT_R8G8B8A8_UNORM;
        case (FFX_SURFACE_FORMAT_R8G8B8A8_SRGB):
            return DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
        case (FFX_SURFACE_FORMAT_R8G8B8A8_SNORM):
            return DXGI_FORMAT_R8G8B8A8_SNORM;
        case (FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS):
            return DXGI_FORMAT_B8G8R8A8_TYPELESS;
        case (FFX_SURFACE_FORMAT_B8G8R8A8_UNORM):
            return DXGI_FORMAT_B8G8R8A8_UNORM;
        case (FFX_SURFACE_FORMAT_B8G8R8A8_SRGB):
            return DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
        case (FFX_SURFACE_FORMAT_R11G11B10_FLOAT):
            return DXGI_FORMAT_R11G11B10_FLOAT;
        case (FFX_SURFACE_FORMAT_R16G16_TYPELESS):
            return DXGI_FORMAT_R16G16_TYPELESS;
        case (FFX_SURFACE_FORMAT_R16G16_FLOAT):
            return DXGI_FORMAT_R16G16_FLOAT;
        case (FFX_SURFACE_FORMAT_R16G16_UINT):
            return DXGI_FORMAT_R16G16_UINT;
        case (FFX_SURFACE_FORMAT_R16G16_SINT):
            return DXGI_FORMAT_R16G16_SINT;
        case (FFX_SURFACE_FORMAT_R16_TYPELESS):
            return DXGI_FORMAT_R16_TYPELESS;
        case (FFX_SURFACE_FORMAT_R16_FLOAT):
            return DXGI_FORMAT_R16_FLOAT;
        case (FFX_SURFACE_FORMAT_R16_UINT):
            return DXGI_FORMAT_R16_UINT;
        case (FFX_SURFACE_FORMAT_R16_UNORM):
            return DXGI_FORMAT_R16_UNORM;
        case (FFX_SURFACE_FORMAT_R16_SNORM):
            return DXGI_FORMAT_R16_SNORM;
        case (FFX_SURFACE_FORMAT_R8_TYPELESS):
            return DXGI_FORMAT_R8_TYPELESS;
        case (FFX_SURFACE_FORMAT_R8_UNORM):
            return DXGI_FORMAT_R8_UNORM;
        case (FFX_SURFACE_FORMAT_R8_UINT):
            return DXGI_FORMAT_R8_UINT;
        case (FFX_SURFACE_FORMAT_R8G8_UINT):
            return DXGI_FORMAT_R8G8_UINT;
        case (FFX_SURFACE_FORMAT_R8G8_TYPELESS):
            return DXGI_FORMAT_R8G8_TYPELESS;
        case (FFX_SURFACE_FORMAT_R8G8_UNORM):
            return DXGI_FORMAT_R8G8_UNORM;
        case (FFX_SURFACE_FORMAT_R32_TYPELESS):
            return DXGI_FORMAT_R32_TYPELESS;
        case (FFX_SURFACE_FORMAT_R32_FLOAT):
            return DXGI_FORMAT_R32_FLOAT;
        case (FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP):
            return DXGI_FORMAT_R9G9B9E5_SHAREDEXP;
        case (FFX_SURFACE_FORMAT_UNKNOWN):
            return DXGI_FORMAT_UNKNOWN;

        default:
            FFX_ASSERT_MESSAGE(false, "Format not yet supported");
            return DXGI_FORMAT_UNKNOWN;
    }
}

D3D12_RESOURCE_FLAGS ffxGetDX12ResourceFlags(FfxResourceUsage flags)
{
    D3D12_RESOURCE_FLAGS dx12ResourceFlags = D3D12_RESOURCE_FLAG_NONE;
    if (flags & FFX_RESOURCE_USAGE_RENDERTARGET) dx12ResourceFlags |= D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
    if (flags & FFX_RESOURCE_USAGE_UAV) dx12ResourceFlags |= D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    return dx12ResourceFlags;
}

FfxSurfaceFormat ffxGetSurfaceFormatDX12(DXGI_FORMAT format)
{
    switch (format) {

        case DXGI_FORMAT_R32G32B32A32_TYPELESS:
            return FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS;
        case DXGI_FORMAT_R32G32B32A32_FLOAT:
            return FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT;
        case DXGI_FORMAT_R32G32B32_FLOAT:
            return FFX_SURFACE_FORMAT_R32G32B32_FLOAT;
        case DXGI_FORMAT_R32G32B32A32_UINT:
            return FFX_SURFACE_FORMAT_R32G32B32A32_UINT;

        case DXGI_FORMAT_R16G16B16A16_TYPELESS:
        case DXGI_FORMAT_R16G16B16A16_FLOAT:
            return FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT;

        case DXGI_FORMAT_R32G32_TYPELESS:
        case DXGI_FORMAT_R32G32_FLOAT:
            return FFX_SURFACE_FORMAT_R32G32_FLOAT;

        case DXGI_FORMAT_R32G8X24_TYPELESS:
        case DXGI_FORMAT_D32_FLOAT_S8X24_UINT:
        case DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS:
            return FFX_SURFACE_FORMAT_R32_FLOAT;

        case DXGI_FORMAT_R24G8_TYPELESS:
        case DXGI_FORMAT_D24_UNORM_S8_UINT:
        case DXGI_FORMAT_R24_UNORM_X8_TYPELESS:
            return FFX_SURFACE_FORMAT_R32_UINT;

        case DXGI_FORMAT_X32_TYPELESS_G8X24_UINT:
        case DXGI_FORMAT_X24_TYPELESS_G8_UINT:
            return FFX_SURFACE_FORMAT_R8_UINT;

        case DXGI_FORMAT_R10G10B10A2_TYPELESS:
        case DXGI_FORMAT_R10G10B10A2_UNORM:
            return FFX_SURFACE_FORMAT_R10G10B10A2_UNORM;
        
        case DXGI_FORMAT_R11G11B10_FLOAT:
            return FFX_SURFACE_FORMAT_R11G11B10_FLOAT;

        case DXGI_FORMAT_R8G8B8A8_TYPELESS:
            return FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS;
        case DXGI_FORMAT_R8G8B8A8_UNORM:
            return FFX_SURFACE_FORMAT_R8G8B8A8_UNORM;
        case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
            return FFX_SURFACE_FORMAT_R8G8B8A8_SRGB;
        case DXGI_FORMAT_R8G8B8A8_SNORM:
            return FFX_SURFACE_FORMAT_R8G8B8A8_SNORM;

        case DXGI_FORMAT_B8G8R8A8_TYPELESS:
            return FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS;
        case DXGI_FORMAT_B8G8R8A8_UNORM:
            return FFX_SURFACE_FORMAT_B8G8R8A8_UNORM;
        case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
            return FFX_SURFACE_FORMAT_B8G8R8A8_SRGB;

        case DXGI_FORMAT_R16G16_TYPELESS:
        case DXGI_FORMAT_R16G16_FLOAT:
            return FFX_SURFACE_FORMAT_R16G16_FLOAT;
        case DXGI_FORMAT_R16G16_UINT:
            return FFX_SURFACE_FORMAT_R16G16_UINT;
        case DXGI_FORMAT_R16G16_SINT:
            return FFX_SURFACE_FORMAT_R16G16_SINT;
        case DXGI_FORMAT_R32_UINT:
            return FFX_SURFACE_FORMAT_R32_UINT;
        case DXGI_FORMAT_R32_TYPELESS:
        case DXGI_FORMAT_D32_FLOAT:
        case DXGI_FORMAT_R32_FLOAT:
            return FFX_SURFACE_FORMAT_R32_FLOAT;

        case DXGI_FORMAT_R8G8_TYPELESS:
        case DXGI_FORMAT_R8G8_UINT:
            return FFX_SURFACE_FORMAT_R8G8_UINT;
        case DXGI_FORMAT_R8G8_UNORM:
            return FFX_SURFACE_FORMAT_R8G8_UNORM;

        case DXGI_FORMAT_R16_TYPELESS:
        case DXGI_FORMAT_R16_FLOAT:
            return FFX_SURFACE_FORMAT_R16_FLOAT;
        case DXGI_FORMAT_R16_UINT:
            return FFX_SURFACE_FORMAT_R16_UINT;
        case DXGI_FORMAT_D16_UNORM:
        case DXGI_FORMAT_R16_UNORM:
            return FFX_SURFACE_FORMAT_R16_UNORM;
        case DXGI_FORMAT_R16_SNORM:
            return FFX_SURFACE_FORMAT_R16_SNORM;

        case DXGI_FORMAT_R8_TYPELESS:
        case DXGI_FORMAT_R8_UNORM:
        case DXGI_FORMAT_A8_UNORM:
            return FFX_SURFACE_FORMAT_R8_UNORM;
        case DXGI_FORMAT_R8_UINT:
            return FFX_SURFACE_FORMAT_R8_UINT;

        case DXGI_FORMAT_R9G9B9E5_SHAREDEXP:
            return FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP;

        case DXGI_FORMAT_UNKNOWN:
            return FFX_SURFACE_FORMAT_UNKNOWN;
        default:
            FFX_ASSERT_MESSAGE(false, "Format not yet supported");
            return FFX_SURFACE_FORMAT_UNKNOWN;
    }
}

bool IsDepthDX12(DXGI_FORMAT format)
{
    return (format == DXGI_FORMAT_D16_UNORM) || 
           (format == DXGI_FORMAT_D32_FLOAT) || 
           (format == DXGI_FORMAT_D24_UNORM_S8_UINT) ||
           (format == DXGI_FORMAT_D32_FLOAT_S8X24_UINT);
}

bool IsStencilDX12(DXGI_FORMAT format)
{
    return (format == DXGI_FORMAT_D24_UNORM_S8_UINT) || (format == DXGI_FORMAT_D32_FLOAT_S8X24_UINT);
}

FfxResourceDescription ffxGetResourceDescriptionDX12(const ID3D12Resource* pResource, FfxResourceUsage additionalUsages                                  )
{
    FfxResourceDescription resourceDescription = {};

                    
    if (!pResource)
        return resourceDescription;

    if (pResource)
    {
        D3D12_RESOURCE_DESC desc = const_cast<ID3D12Resource*>(pResource)->GetDesc();
        
        if( desc.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER)
        {
            resourceDescription.flags  = FFX_RESOURCE_FLAGS_NONE;
            resourceDescription.usage  = FFX_RESOURCE_USAGE_UAV;
            resourceDescription.size  = (uint32_t)desc.Width;
            resourceDescription.stride = (uint32_t)desc.Height;
            resourceDescription.format = ffxGetSurfaceFormatDX12(desc.Format);

                                                                       
            resourceDescription.depth    = 0;
            resourceDescription.mipCount = 0;

                           
            resourceDescription.type = FFX_RESOURCE_TYPE_BUFFER;
        }
        else
        {
                                                           
            resourceDescription.flags     = FFX_RESOURCE_FLAGS_NONE;
           
                                  
            resourceDescription.usage     = IsDepthDX12(desc.Format) ? FFX_RESOURCE_USAGE_DEPTHTARGET : FFX_RESOURCE_USAGE_READ_ONLY;
            
            if (IsStencilDX12(desc.Format))
                resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_STENCILTARGET);

                                   
            if ((desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) == D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS)
                resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_UAV);

                                                       
            resourceDescription.usage    = (FfxResourceUsage)(resourceDescription.usage | additionalUsages);

            resourceDescription.width    = (uint32_t)desc.Width;
            resourceDescription.height   = (uint32_t)desc.Height;
            resourceDescription.depth    = desc.DepthOrArraySize;
            resourceDescription.mipCount = desc.MipLevels;
            resourceDescription.format   = ffxGetSurfaceFormatDX12(desc.Format);

            switch (desc.Dimension)
            {
            case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
                resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE1D;
                break;
            case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
                if (FFX_CONTAINS_FLAG(additionalUsages, FFX_RESOURCE_USAGE_ARRAYVIEW))
                    resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
                else if (desc.DepthOrArraySize == 1)
                    resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
                else if (desc.DepthOrArraySize == 6)
                    resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE_CUBE;
                else
                    resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
                break;
            case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
                resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE3D;
                break;
            default:
                FFX_ASSERT_MESSAGE(false, "FFXInterface: DX12: Unsupported texture dimension requested. Please implement.");
                break;
            }
        }
    }

    return resourceDescription;
}


ID3D12Resource* getDX12ResourcePtr(BackendContext_DX12* backendContext, int32_t resourceIndex)
{
    FFX_ASSERT(NULL != backendContext);
    return reinterpret_cast<ID3D12Resource*>(backendContext->pResources[resourceIndex].resourcePtr);
}

void beginMarkerDX12(BackendContext_DX12* backendContext, ID3D12GraphicsCommandList* pCmdList, const wchar_t* label)
{
    FFX_ASSERT(nullptr != backendContext);
    FFX_ASSERT(nullptr != pCmdList);

#if defined(ENABLE_PIX_CAPTURES)
    if (s_PIXDLLLoaded)
    {
        char strLabel[FFX_RESOURCE_NAME_SIZE];
        WideCharToMultiByte(CP_UTF8, 0, label, -1, strLabel, int(std::size(strLabel)), nullptr, nullptr);
        pixBeginEventOnCommandList(pCmdList, 0, strLabel);
    }
#endif                                    
}

void endMarkerDX12(BackendContext_DX12* backendContext, ID3D12GraphicsCommandList* pCmdList)
{
    FFX_ASSERT(nullptr != backendContext);
    FFX_ASSERT(nullptr != pCmdList);

#if defined(ENABLE_PIX_CAPTURES)
    if (s_PIXDLLLoaded)
    {
        pixEndEventOnCommandList(pCmdList);
    }
#endif                                    
}

void addBarrier(BackendContext_DX12* backendContext, FfxResourceInternal* resource, FfxResourceStates newState)
{
    FFX_ASSERT(NULL != backendContext);
    FFX_ASSERT(NULL != resource);

    ID3D12Resource* dx12Resource = getDX12ResourcePtr(backendContext, resource->internalIndex);
    D3D12_RESOURCE_BARRIER* barrier = &backendContext->barriers[backendContext->barrierCount];

    FFX_ASSERT(backendContext->barrierCount < FFX_MAX_BARRIERS);

    FfxResourceStates* currentState = &backendContext->pResources[resource->internalIndex].currentState;

    if ((*currentState & newState) != newState) {

        const D3D12_RESOURCE_STATES before = ffxGetDX12StateFromResourceState(*currentState);
        const D3D12_RESOURCE_STATES after  = ffxGetDX12StateFromResourceState(newState);
        *currentState = newState;
        if (before == after)
        {
            if (after == D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
            {
                *barrier = CD3DX12_RESOURCE_BARRIER::UAV(dx12Resource);
                ++backendContext->barrierCount;
            }
            return;
        }
        *barrier = CD3DX12_RESOURCE_BARRIER::Transition(dx12Resource, before, after);
        ++backendContext->barrierCount;

    }
    else if (newState == FFX_RESOURCE_STATE_COMPUTE_UAV) {

        *barrier = CD3DX12_RESOURCE_BARRIER::UAV(dx12Resource);
        ++backendContext->barrierCount;
    }
}

void flushBarriers(BackendContext_DX12* backendContext, ID3D12GraphicsCommandList* dx12CommandList)
{
    FFX_ASSERT(NULL != backendContext);
    FFX_ASSERT(NULL != dx12CommandList);

    if (backendContext->barrierCount > 0) {

        dx12CommandList->ResourceBarrier(backendContext->barrierCount, backendContext->barriers);
        backendContext->barrierCount = 0;
    }
}

                                                                          
                               

FfxUInt32 GetSDKVersionDX12(FfxInterface*)
{
    return FFX_SDK_MAKE_VERSION(FFX_SDK_VERSION_MAJOR, FFX_SDK_VERSION_MINOR, FFX_SDK_VERSION_PATCH);
}

uint64_t GetResourceGpuMemorySizeDX12(ID3D12Resource* resource)
{
    uint64_t      size = 0;
    D3D12_RESOURCE_ALLOCATION_INFO allocInfo = {};
    if (resource)
    {
        D3D12_RESOURCE_DESC desc = resource->GetDesc();
        ID3D12Device4* pDevice4 = nullptr;
        if (SUCCEEDED(resource->GetDevice(IID_PPV_ARGS(&pDevice4))))
        {
            allocInfo = pDevice4->GetResourceAllocationInfo(0, 1, &desc);
            size = allocInfo.SizeInBytes;
            pDevice4->Release();
        }
    }

    return size;
}

FfxErrorCode GetEffectGpuMemoryUsageDX12(FfxInterface* backendInterface, FfxUInt32 effectContextId, FfxEffectMemoryUsage* outVramUsage)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != outVramUsage);

    BackendContext_DX12*                backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;
    BackendContext_DX12::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    *outVramUsage = effectContext.vramUsage;

    return FFX_OK;
}

                              
FfxErrorCode CreateBackendContextDX12(FfxInterface* backendInterface, FfxEffect effect, FfxEffectBindlessConfig* bindlessConfig, FfxUInt32* effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != backendInterface->device);

    HRESULT result = S_OK;
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendInterface->device);

                                                                                             
    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

                                                    
    if (!backendContext->refCount) {

        new (&backendContext->constantBufferMutex) std::mutex();

        if (dx12Device != NULL) {

            dx12Device->AddRef();
            backendContext->device = dx12Device;
        }

                                  
        uint32_t gpuJobDescArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_MAX_GPU_JOBS * sizeof(FfxGpuJobDescription), sizeof(uint32_t));
        uint32_t resourceArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * sizeof(BackendContext_DX12::Resource), sizeof(uint64_t));
        uint32_t stagingRingBufferArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE, sizeof(uint32_t));
        uint32_t contextArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * sizeof(BackendContext_DX12::EffectContext), sizeof(uint32_t));

        uint8_t* pMem = (uint8_t*)((BackendContext_DX12*)(backendContext + 1));

                            
        backendContext->pGpuJobs = (FfxGpuJobDescription*)pMem;
        memset(backendContext->pGpuJobs, 0, gpuJobDescArraySize);
        pMem += gpuJobDescArraySize;

                            
        backendContext->pResources = (BackendContext_DX12::Resource*)(pMem);
        memset(backendContext->pResources, 0, resourceArraySize);
        pMem += resourceArraySize;

                                 
        backendContext->pStagingRingBuffer = (uint8_t*)(pMem);
        memset(backendContext->pStagingRingBuffer, 0, stagingRingBufferArraySize);
        pMem += stagingRingBufferArraySize;

                                  
        backendContext->pEffectContexts = reinterpret_cast<BackendContext_DX12::EffectContext*>(pMem);
        memset(backendContext->pEffectContexts, 0, contextArraySize);

                     
        D3D12_DESCRIPTOR_HEAP_DESC descHeap;
        descHeap.NumDescriptors = FFX_MAX_RESOURCE_COUNT * backendContext->maxEffectContexts;
        descHeap.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        descHeap.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        descHeap.NodeMask = 0;

        result = dx12Device->CreateDescriptorHeap(&descHeap, IID_PPV_ARGS(&backendContext->descHeapSrvCpu));
        result = dx12Device->CreateDescriptorHeap(&descHeap, IID_PPV_ARGS(&backendContext->descHeapUavCpu));

              
        descHeap.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
        result = dx12Device->CreateDescriptorHeap(&descHeap, IID_PPV_ARGS(&backendContext->descHeapUavGpu));

                                 
        descHeap.NumDescriptors            = FFX_RING_BUFFER_DESCRIPTOR_COUNT * backendContext->maxEffectContexts + FFX_MAX_STATIC_DESCRIPTOR_COUNT;
        backendContext->descRingBufferSize = descHeap.NumDescriptors;
        backendContext->descRingBufferBase = 0;
        result = dx12Device->CreateDescriptorHeap(&descHeap, IID_PPV_ARGS(&backendContext->descRingBuffer));

                                             
        descHeap.NumDescriptors = 8;
        descHeap.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        descHeap.NodeMask = 0;
        descHeap.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        dx12Device->CreateDescriptorHeap(&descHeap, IID_PPV_ARGS(&backendContext->descHeapRtvCpu));

                                                                     
        backendContext->descBindlessBase = FFX_RING_BUFFER_DESCRIPTOR_COUNT * backendContext->maxEffectContexts;

                                                      
        result = CreateDXGIFactory2(0, IID_PPV_ARGS(&backendContext->dxgiFactory));

        FFX_UNUSED(result);
    }

                              
    ++backendContext->refCount;

                                  
    for (uint32_t i = 0; i < backendContext->maxEffectContexts; ++i) {
        if (!backendContext->pEffectContexts[i].active) {
            *effectContextId = i;

                                           
            BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[i];
            effectContext.active = true;
            effectContext.effectId = effect;

            effectContext.nextStaticResource = (i * FFX_MAX_RESOURCE_COUNT) + 1;
            effectContext.nextDynamicResource = (i * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT - 1;
            effectContext.nextStaticUavDescriptor = (i * FFX_MAX_RESOURCE_COUNT);
            effectContext.nextDynamicUavDescriptor = (i * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT - 1;

            if (bindlessConfig)
            {
                uint32_t numDescriptors = bindlessConfig->maxTextureSrvs + bindlessConfig->maxBufferSrvs + bindlessConfig->maxTextureUavs + bindlessConfig->maxBufferUavs;

                uint32_t bindlessBase = getFreeBindlessDescriptorBlock(backendContext, numDescriptors, i);

                effectContext.bindlessBufferHeapStart = bindlessBase;
                effectContext.bindlessBufferHeapEnd = bindlessBase + numDescriptors;

                effectContext.bindlessTextureSrvHeapStart = bindlessBase;
                effectContext.bindlessTextureSrvHeapSize  = bindlessConfig->maxTextureSrvs;

                bindlessBase += bindlessConfig->maxTextureSrvs;

                effectContext.bindlessBufferSrvHeapStart = bindlessBase;
                effectContext.bindlessBufferSrvHeapSize  = bindlessConfig->maxBufferSrvs;

                bindlessBase += bindlessConfig->maxBufferSrvs;

                effectContext.bindlessTextureUavHeapStart = bindlessBase;
                effectContext.bindlessTextureUavHeapSize  = bindlessConfig->maxTextureUavs;

                bindlessBase += bindlessConfig->maxTextureUavs;

                effectContext.bindlessBufferUavHeapStart = bindlessBase;
                effectContext.bindlessBufferUavHeapSize  = bindlessConfig->maxBufferUavs;

                bindlessBase += bindlessConfig->maxBufferUavs;
            }
            else
            {
                effectContext.bindlessTextureSrvHeapStart = 0;
                effectContext.bindlessTextureSrvHeapSize  = 0;
                effectContext.bindlessBufferSrvHeapStart  = 0;
                effectContext.bindlessBufferSrvHeapSize   = 0;
                effectContext.bindlessTextureUavHeapStart = 0;
                effectContext.bindlessTextureUavHeapSize  = 0;
                effectContext.bindlessBufferUavHeapStart  = 0;
                effectContext.bindlessBufferUavHeapSize   = 0;
                effectContext.bindlessBufferHeapStart     = 0;
                effectContext.bindlessBufferHeapEnd       = 0;
            }   

            break;
        }
    }

    return FFX_OK;
}

                                                                     
FfxErrorCode GetDeviceCapabilitiesDX12(FfxInterface* backendInterface, FfxDeviceCapabilities* deviceCapabilities)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != backendInterface->device);
    FFX_ASSERT(NULL != deviceCapabilities);
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendInterface->device);

                                        
    D3D12_FEATURE_DATA_SHADER_MODEL shaderModel = { D3D_SHADER_MODEL_6_6 };
    if (SUCCEEDED(dx12Device->CheckFeatureSupport(D3D12_FEATURE_SHADER_MODEL, &shaderModel, sizeof(D3D12_FEATURE_DATA_SHADER_MODEL)))) {

        switch (shaderModel.HighestShaderModel) {

        case D3D_SHADER_MODEL_5_1:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_5_1;
            break;

        case D3D_SHADER_MODEL_6_0:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_0;
            break;

        case D3D_SHADER_MODEL_6_1:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_1;
            break;

        case D3D_SHADER_MODEL_6_2:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_2;
            break;

        case D3D_SHADER_MODEL_6_3:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_3;
            break;

        case D3D_SHADER_MODEL_6_4:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_4;
            break;

        case D3D_SHADER_MODEL_6_5:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_5;
            break;

        case D3D_SHADER_MODEL_6_6:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_6;
            break;

        default:
            deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_6_6;
            break;
        }
    }
    else {

        deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_5_1;
    }

                                         
    D3D12_FEATURE_DATA_D3D12_OPTIONS1 d3d12Options1 = {};
    if (SUCCEEDED(dx12Device->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS1, &d3d12Options1, sizeof(d3d12Options1)))) {

        const uint32_t waveLaneCountMin = d3d12Options1.WaveLaneCountMin;
        const uint32_t waveLaneCountMax = d3d12Options1.WaveLaneCountMax;
        deviceCapabilities->waveLaneCountMin = waveLaneCountMin;
        deviceCapabilities->waveLaneCountMax = waveLaneCountMax;
    }

                                             
    D3D12_FEATURE_DATA_D3D12_OPTIONS d3d12Options = {};
    if (SUCCEEDED(dx12Device->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS, &d3d12Options, sizeof(d3d12Options)))) {

        deviceCapabilities->fp16Supported = bool(d3d12Options.MinPrecisionSupport & D3D12_SHADER_MIN_PRECISION_SUPPORT_16_BIT);
    }
    D3D12_FEATURE_DATA_D3D12_OPTIONS4 d3d12Options4 = {};
    if (SUCCEEDED(dx12Device->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS4, &d3d12Options4, sizeof(d3d12Options4)))) {

        deviceCapabilities->fp16Supported &= bool(d3d12Options4.Native16BitShaderOpsSupported);
    }

                                          
    D3D12_FEATURE_DATA_D3D12_OPTIONS5 d3d12Options5 = {};
    if (SUCCEEDED(dx12Device->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS5, &d3d12Options5, sizeof(d3d12Options5)))) {

        deviceCapabilities->raytracingSupported = (d3d12Options5.RaytracingTier != D3D12_RAYTRACING_TIER_NOT_SUPPORTED);
    }

    deviceCapabilities->deviceCoherentMemorySupported = false;
    deviceCapabilities->dedicatedAllocationSupported = true;                                            
    deviceCapabilities->bufferMarkerSupported = false;
    deviceCapabilities->extendedSynchronizationSupported = false;
    deviceCapabilities->shaderStorageBufferArrayNonUniformIndexing = true;

                                                                                                                    
    deviceCapabilities->fp16Supported = false;
                                                                                                                 
                                                                                                          
    deviceCapabilities->tensorSupported          = true;
    deviceCapabilities->dataGraphSupported       = true;
    deviceCapabilities->computeSupportTensor     = false;
    deviceCapabilities->fragmentSupportTensor    = false;
    deviceCapabilities->dataGraphOFSupported     = true;
    deviceCapabilities->hintSupported            = true;
    deviceCapabilities->costSupported            = false;
    deviceCapabilities->supportedHintGridSizes   = FFX_OPTICAL_FLOW_GRID_SIZE_4X4;
    deviceCapabilities->supportedOutputGridSizes = FFX_OPTICAL_FLOW_GRID_SIZE_4X4;
    deviceCapabilities->dataGraphOFMinWidth      = 32;
    deviceCapabilities->dataGraphOFMinHeight     = 32;
    deviceCapabilities->dataGraphOFMaxWidth      = 8192;
    deviceCapabilities->dataGraphOFMaxHeight     = 8192;

    if (deviceCapabilities != &backendInterface->deviceCapabilities)
        memcpy(&backendInterface->deviceCapabilities, deviceCapabilities, sizeof(FfxDeviceCapabilities));
    backendInterface->devCapInitialized = true;

    return FFX_OK;
}

                                
FfxErrorCode DestroyBackendContextDX12(FfxInterface* backendInterface, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;
    FFX_ASSERT(backendContext->refCount > 0);

                                                     
    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];
    for (uint32_t currentStaticResourceIndex = effectContextId * FFX_MAX_RESOURCE_COUNT; currentStaticResourceIndex < (uint32_t)effectContext.nextStaticResource; ++currentStaticResourceIndex) {
        if (backendContext->pResources[currentStaticResourceIndex].resourcePtr) {
            FFX_ASSERT_MESSAGE(false, "FFXInterface: DX12: SDK Resource was not destroyed prior to destroying the backend context. There is a resource leak.");
            FfxResourceInternal internalResource = { (int32_t)currentStaticResourceIndex };
            DestroyResourceDX12(backendInterface, internalResource, effectContextId);
        }
    }

                                         
    effectContext.nextStaticResource = 0;
    effectContext.active = false;

                          
    --backendContext->refCount;

    if (!backendContext->refCount) {

                                                           
        if (backendContext->constantBufferMem)
        {
            backendContext->constantBufferResource->Unmap(0, nullptr);
            nfruDeferRelease(backendContext->constantBufferResource);
            backendContext->constantBufferMem = nullptr;
            backendContext->constantBufferOffset = 0;
            backendContext->constantBufferSize = 0;
        }

        backendContext->gpuJobCount             = 0;
        backendContext->barrierCount            = 0;

                        
                                                                                                                
        nfruDeferRelease(backendContext->descHeapRtvCpu);
        nfruDeferRelease(backendContext->descHeapSrvCpu);
        nfruDeferRelease(backendContext->descHeapUavCpu);
        nfruDeferRelease(backendContext->descHeapUavGpu);
        nfruDeferRelease(backendContext->descRingBuffer);

        if (backendContext->device != NULL) {
            nfruDeferRelease(backendContext->device);
            backendContext->device = NULL;
        }

        if (backendContext->dxgiFactory != NULL) {
            backendContext->dxgiFactory->Release();
            backendContext->dxgiFactory = NULL;
        }
    }

    return FFX_OK;
}

                                                                                                                   
                                                                                                                    
                                                                                                                        
static FfxErrorCode CreateTensorResourceDX12(BackendContext_DX12* backendContext, FfxUInt32 effectContextId,
                                             const FfxCreateResourceDescription* createResourceDescription, FfxResourceInternal* outTexture)
{
    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];
    ID3D12Device*                       dx12Device    = backendContext->device;
    const FfxResourceDescription&       desc          = createResourceDescription->resourceDescription;
    const UINT                          inc           = dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    uint64_t elementBytes = 1;
    if (desc.format == FFX_SURFACE_FORMAT_R16_FLOAT || desc.format == FFX_SURFACE_FORMAT_R16_UINT) elementBytes = 2;
    else if (desc.format == FFX_SURFACE_FORMAT_R32_FLOAT || desc.format == FFX_SURFACE_FORMAT_R32_UINT) elementBytes = 4;
    const uint64_t batch      = desc.batchSize ? desc.batchSize : 1;
    const uint64_t tensorSize = FFX_ALIGN_UP(batch * desc.height * desc.width * (desc.channel ? desc.channel : 1) * elementBytes, 256);

    FFX_ASSERT(effectContext.nextStaticResource + 1 < effectContext.nextDynamicResource);
    outTexture->internalIndex                      = effectContext.nextStaticResource++;
    BackendContext_DX12::Resource* backendResource = &backendContext->pResources[outTexture->internalIndex];
    backendResource->resourceDescription           = desc;
    backendResource->tensorImage                   = nullptr;
    backendResource->tensorImageUavIndex           = 0;

    D3D12_HEAP_PROPERTIES heap = {};
    heap.Type                  = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC rd     = {};
    rd.Dimension               = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width                   = tensorSize;
    rd.Height                  = 1;
    rd.DepthOrArraySize        = 1;
    rd.MipLevels               = 1;
    rd.SampleDesc.Count        = 1;
    rd.Layout                  = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags                   = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    ID3D12Resource* buffer     = nullptr;
    if (FAILED(dx12Device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COMMON, nullptr, IID_PPV_ARGS(&buffer))))
        return FFX_ERROR_BACKEND_API_ERROR;
    if (createResourceDescription->name) { wchar_t wideName[128]; MultiByteToWideChar(CP_UTF8, 0, createResourceDescription->name, -1, wideName, 128); buffer->SetName(wideName); }
    backendResource->resourcePtr  = buffer;
    backendResource->initialState = FFX_RESOURCE_STATE_COMMON;                                   
    backendResource->currentState = FFX_RESOURCE_STATE_COMMON;
    backendResource->srvDescIndex = outTexture->internalIndex;

    D3D12_CPU_DESCRIPTOR_HANDLE srvHandle = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
    srvHandle.ptr += SIZE_T(outTexture->internalIndex) * inc;

    D3D12_UNORDERED_ACCESS_VIEW_DESC uav = {};
    uav.Format                           = DXGI_FORMAT_R32_TYPELESS;
    uav.ViewDimension                    = D3D12_UAV_DIMENSION_BUFFER;
    uav.Buffer.NumElements               = UINT(tensorSize / 4);
    uav.Buffer.Flags                     = D3D12_BUFFER_UAV_FLAG_RAW;
    FFX_ASSERT(effectContext.nextStaticUavDescriptor + 2 < effectContext.nextDynamicUavDescriptor);
    backendResource->uavDescCount = 1;
    backendResource->uavDescIndex = effectContext.nextStaticUavDescriptor++;
    for (ID3D12DescriptorHeap* uavHeap : {backendContext->descHeapUavGpu, backendContext->descHeapUavCpu})
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = uavHeap->GetCPUDescriptorHandleForHeapStart();
        h.ptr += SIZE_T(backendResource->uavDescIndex) * inc;
        dx12Device->CreateUnorderedAccessView(buffer, nullptr, &uav, h);
    }

    const bool imageAliased = (desc.flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) == FFX_RESOURCE_FLAGS_IMAGE_ALIASED;
    if (!imageAliased)
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC srv = {};
        srv.Format                          = DXGI_FORMAT_R32_TYPELESS;
        srv.ViewDimension                   = D3D12_SRV_DIMENSION_BUFFER;
        srv.Shader4ComponentMapping         = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        srv.Buffer.NumElements              = UINT(tensorSize / 4);
        srv.Buffer.Flags                    = D3D12_BUFFER_SRV_FLAG_RAW;
        dx12Device->CreateShaderResourceView(buffer, &srv, srvHandle);
        return FFX_OK;
    }

                                                                 
    FFX_ASSERT(desc.channel == 4 && elementBytes == 1);
    D3D12_RESOURCE_DESC td = {};
    td.Dimension           = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    td.Format              = DXGI_FORMAT_R8G8B8A8_TYPELESS;
    td.Width               = desc.width;
    td.Height              = desc.height;
    td.DepthOrArraySize    = 1;
    td.MipLevels           = 1;
    td.SampleDesc.Count    = 1;
    td.Flags               = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    if (FAILED(dx12Device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &td, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE, nullptr,
                                                   IID_PPV_ARGS(&backendResource->tensorImage))))
        return FFX_ERROR_BACKEND_API_ERROR;
    backendResource->tensorImageState = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;

    D3D12_SHADER_RESOURCE_VIEW_DESC srv = {};
    srv.Format                          = DXGI_FORMAT_R8G8B8A8_SNORM;
    srv.ViewDimension                   = D3D12_SRV_DIMENSION_TEXTURE2D;
    srv.Shader4ComponentMapping         = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    srv.Texture2D.MipLevels             = 1;
    dx12Device->CreateShaderResourceView(backendResource->tensorImage, &srv, srvHandle);

    D3D12_UNORDERED_ACCESS_VIEW_DESC imageUav = {};
    imageUav.Format                           = DXGI_FORMAT_R8G8B8A8_UINT;
    imageUav.ViewDimension                    = D3D12_UAV_DIMENSION_TEXTURE2D;
    backendResource->tensorImageUavIndex      = effectContext.nextStaticUavDescriptor++;
    for (ID3D12DescriptorHeap* uavHeap : {backendContext->descHeapUavGpu, backendContext->descHeapUavCpu})
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = uavHeap->GetCPUDescriptorHandleForHeapStart();
        h.ptr += SIZE_T(backendResource->tensorImageUavIndex) * inc;
        dx12Device->CreateUnorderedAccessView(backendResource->tensorImage, nullptr, &imageUav, h);
    }
    return FFX_OK;
}

                                                                              
FfxErrorCode CreateResourceDX12(
    FfxInterface* backendInterface,
    const FfxCreateResourceDescription* createResourceDescription,
    FfxUInt32 effectContextId,
    FfxResourceInternal* outTexture
)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != createResourceDescription);
    FFX_ASSERT(NULL != outTexture);
    FFX_ASSERT_MESSAGE(createResourceDescription->initData.type != FFX_RESOURCE_INIT_DATA_TYPE_INVALID,
                       "InitData type cannot be FFX_RESOURCE_INIT_DATA_TYPE_INVALID. Please explicitly specify the resource initialization type.");


    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;
    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];
    ID3D12Device* dx12Device = backendContext->device;

    if (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR)
        return CreateTensorResourceDX12(backendContext, effectContextId, createResourceDescription, outTexture);

    uint64_t resourceSize = 0;
    FFX_ASSERT(NULL != dx12Device);

    D3D12_HEAP_PROPERTIES dx12HeapProperties = {};

    switch (createResourceDescription->heapType)
    {
    case FFX_HEAP_TYPE_DEFAULT:
        dx12HeapProperties.Type = D3D12_HEAP_TYPE_DEFAULT;
        break;
    case FFX_HEAP_TYPE_UPLOAD:
        dx12HeapProperties.Type = D3D12_HEAP_TYPE_UPLOAD;
        break;
    case FFX_HEAP_TYPE_READBACK:
        dx12HeapProperties.Type = D3D12_HEAP_TYPE_READBACK;
        break;
    default:
        dx12HeapProperties.Type = D3D12_HEAP_TYPE_DEFAULT;
        break;
    }

    FFX_ASSERT(effectContext.nextStaticResource + 1 < effectContext.nextDynamicResource);

    outTexture->internalIndex = effectContext.nextStaticResource++;
    BackendContext_DX12::Resource* backendResource = &backendContext->pResources[outTexture->internalIndex];
    backendResource->resourceDescription = createResourceDescription->resourceDescription;
    backendResource->tensorImage = nullptr;

    const auto& initData = createResourceDescription->initData;

    D3D12_RESOURCE_DESC dx12ResourceDescription = {};
    dx12ResourceDescription.Format              = DXGI_FORMAT_UNKNOWN;
    dx12ResourceDescription.Width               = 1;
    dx12ResourceDescription.Height              = 1;
    dx12ResourceDescription.MipLevels           = 1;
    dx12ResourceDescription.DepthOrArraySize    = 1;
    dx12ResourceDescription.SampleDesc.Count    = 1;
    dx12ResourceDescription.Flags               = ffxGetDX12ResourceFlags(backendResource->resourceDescription.usage);

    switch (createResourceDescription->resourceDescription.type) {

    case FFX_RESOURCE_TYPE_BUFFER:
        dx12ResourceDescription.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        dx12ResourceDescription.Width = createResourceDescription->resourceDescription.width;
        dx12ResourceDescription.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        break;

    case FFX_RESOURCE_TYPE_TEXTURE1D:
        dx12ResourceDescription.Format = ffxGetDX12FormatFromSurfaceFormat(createResourceDescription->resourceDescription.format);
        dx12ResourceDescription.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE1D;
        dx12ResourceDescription.Width = createResourceDescription->resourceDescription.width;
        dx12ResourceDescription.DepthOrArraySize = UINT16(createResourceDescription->resourceDescription.depth);
        dx12ResourceDescription.MipLevels = UINT16(createResourceDescription->resourceDescription.mipCount);
        break;

    case FFX_RESOURCE_TYPE_TEXTURE2D:
        dx12ResourceDescription.Format = ffxGetDX12FormatFromSurfaceFormat(createResourceDescription->resourceDescription.format);
        dx12ResourceDescription.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
        dx12ResourceDescription.Width = createResourceDescription->resourceDescription.width;
        dx12ResourceDescription.Height = createResourceDescription->resourceDescription.height;
        dx12ResourceDescription.DepthOrArraySize = UINT16(createResourceDescription->resourceDescription.depth);
        dx12ResourceDescription.MipLevels = UINT16(createResourceDescription->resourceDescription.mipCount);
        break;

    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
        dx12ResourceDescription.Format = ffxGetDX12FormatFromSurfaceFormat(createResourceDescription->resourceDescription.format);
        dx12ResourceDescription.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE3D;
        dx12ResourceDescription.Width = createResourceDescription->resourceDescription.width;
        dx12ResourceDescription.Height = createResourceDescription->resourceDescription.height;
        dx12ResourceDescription.DepthOrArraySize = UINT16(createResourceDescription->resourceDescription.depth);
        dx12ResourceDescription.MipLevels = UINT16(createResourceDescription->resourceDescription.mipCount);
        break;

    default:
        break;
    }

    ID3D12Resource* dx12Resource = nullptr;
    if (createResourceDescription->heapType == FFX_HEAP_TYPE_UPLOAD) {

        D3D12_PLACED_SUBRESOURCE_FOOTPRINT dx12Footprint = {};

        UINT rowCount;
        UINT64 rowSizeInBytes;
        UINT64 totalBytes;

        dx12Device->GetCopyableFootprints(&dx12ResourceDescription, 0, 1, 0, &dx12Footprint, &rowCount, &rowSizeInBytes, &totalBytes);

        D3D12_HEAP_PROPERTIES dx12UploadHeapProperties = {};
        dx12UploadHeapProperties.Type = D3D12_HEAP_TYPE_UPLOAD;

        D3D12_RESOURCE_DESC dx12UploadBufferDescription = {};

        dx12UploadBufferDescription.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        dx12UploadBufferDescription.Width = totalBytes;
        dx12UploadBufferDescription.Height = 1;
        dx12UploadBufferDescription.DepthOrArraySize = 1;
        dx12UploadBufferDescription.MipLevels = 1;
        dx12UploadBufferDescription.Format = DXGI_FORMAT_UNKNOWN;
        dx12UploadBufferDescription.SampleDesc.Count = 1;
        dx12UploadBufferDescription.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;

        TIF(dx12Device->CreateCommittedResource(&dx12HeapProperties, D3D12_HEAP_FLAG_NONE, &dx12UploadBufferDescription, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&dx12Resource)));
        resourceSize = GetResourceGpuMemorySizeDX12(dx12Resource);

        backendResource->initialState = FFX_RESOURCE_STATE_GENERIC_READ;
        backendResource->currentState = FFX_RESOURCE_STATE_GENERIC_READ;

        D3D12_RANGE dx12EmptyRange = {};
        void* uploadBufferData = nullptr;
        TIF(dx12Resource->Map(0, &dx12EmptyRange, &uploadBufferData));

        const uint8_t* src = static_cast<uint8_t*>(initData.buffer);
        uint8_t* dst = static_cast<uint8_t*>(uploadBufferData);
        for (uint32_t currentRowIndex = 0; currentRowIndex < createResourceDescription->resourceDescription.height; ++currentRowIndex) {

            if (initData.type == FFX_RESOURCE_INIT_DATA_TYPE_BUFFER)
            {
                memcpy(dst, src, (size_t)rowSizeInBytes);
                src += rowSizeInBytes;
            }
            else if (initData.type == FFX_RESOURCE_INIT_DATA_TYPE_VALUE)
            {
                memset(dst, initData.value, (size_t)rowSizeInBytes);
            }
            dst += dx12Footprint.Footprint.RowPitch;
        }

        dx12Resource->Unmap(0, nullptr);
        if (createResourceDescription->name) { wchar_t wideName[128]; MultiByteToWideChar(CP_UTF8, 0, createResourceDescription->name, -1, wideName, 128); dx12Resource->SetName(wideName); }
        backendResource->resourcePtr = dx12Resource;

#ifdef _DEBUG
        wcscpy_s(backendResource->resourceName, createResourceDescription->name);
#endif
        return FFX_OK;

    }
    else {

        const FfxResourceStates resourceStates =
            ((initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED) && (createResourceDescription->heapType != FFX_HEAP_TYPE_UPLOAD))
                ? FFX_RESOURCE_STATE_COPY_DEST
                : createResourceDescription->initialState;
                                                                                    
        const D3D12_RESOURCE_STATES dx12ResourceStates = dx12ResourceDescription.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER ? D3D12_RESOURCE_STATE_COMMON : ffxGetDX12StateFromResourceState(resourceStates);

        TIF(dx12Device->CreateCommittedResource(&dx12HeapProperties, D3D12_HEAP_FLAG_NONE, &dx12ResourceDescription, dx12ResourceStates, nullptr, IID_PPV_ARGS(&dx12Resource)));
        resourceSize = GetResourceGpuMemorySizeDX12(dx12Resource);
        const FfxResourceStates trackedState =
            dx12ResourceDescription.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER ? FFX_RESOURCE_STATE_COMMON : resourceStates;
        backendResource->initialState = trackedState;
        backendResource->currentState = trackedState;

        if (createResourceDescription->name) { wchar_t wideName[128]; MultiByteToWideChar(CP_UTF8, 0, createResourceDescription->name, -1, wideName, 128); dx12Resource->SetName(wideName); }
        backendResource->resourcePtr = dx12Resource;

#ifdef _DEBUG
        wcscpy_s(backendResource->resourceName, createResourceDescription->name);
#endif

                               
        {
            D3D12_UNORDERED_ACCESS_VIEW_DESC dx12UavDescription = {};
            D3D12_SHADER_RESOURCE_VIEW_DESC dx12SrvDescription = {};
            D3D12_RESOURCE_DESC dx12Desc = dx12Resource->GetDesc();
            dx12UavDescription.Format = convertFormatUav(dx12Desc.Format);
            dx12SrvDescription.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
            dx12SrvDescription.Format = convertFormatSrv(dx12Desc.Format);

            bool requestArrayView = FFX_CONTAINS_FLAG(createResourceDescription->resourceDescription.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

            switch (dx12Desc.Dimension) {

            case D3D12_RESOURCE_DIMENSION_BUFFER:
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
                dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
                break;

            case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
                if (dx12Desc.DepthOrArraySize > 1 || requestArrayView)
                {
                    dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE1DARRAY;
                    dx12UavDescription.Texture1DArray.ArraySize = dx12Desc.DepthOrArraySize;
                    dx12UavDescription.Texture1DArray.FirstArraySlice = 0;
                    dx12UavDescription.Texture1DArray.MipSlice = 0;

                    dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE1DARRAY;
                    dx12SrvDescription.Texture1DArray.ArraySize = dx12Desc.DepthOrArraySize;
                    dx12SrvDescription.Texture1DArray.FirstArraySlice = 0;
                    dx12SrvDescription.Texture1DArray.MipLevels = dx12Desc.MipLevels;
                    dx12SrvDescription.Texture1DArray.MostDetailedMip = 0;
                }
                else
                {
                    dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE1D;
                    dx12UavDescription.Texture1D.MipSlice = 0;

                    dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE1D;
                    dx12SrvDescription.Texture1D.MipLevels = dx12Desc.MipLevels;
                    dx12SrvDescription.Texture1D.MostDetailedMip = 0;
                }
                break;

            case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
            {
                if (dx12Desc.DepthOrArraySize > 1 || requestArrayView)
                {
                    dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2DARRAY;
                    dx12UavDescription.Texture2DArray.ArraySize = dx12Desc.DepthOrArraySize;
                    dx12UavDescription.Texture2DArray.FirstArraySlice = 0;
                    dx12UavDescription.Texture2DArray.MipSlice = 0;
                    dx12UavDescription.Texture2DArray.PlaneSlice = 0;

                    dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2DARRAY;
                    dx12SrvDescription.Texture2DArray.ArraySize = dx12Desc.DepthOrArraySize;
                    dx12SrvDescription.Texture2DArray.FirstArraySlice = 0;
                    dx12SrvDescription.Texture2DArray.MipLevels = dx12Desc.MipLevels;
                    dx12SrvDescription.Texture2DArray.MostDetailedMip = 0;
                    dx12SrvDescription.Texture2DArray.PlaneSlice = 0;
                }
                else
                {
                    dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
                    dx12UavDescription.Texture2D.MipSlice = 0;
                    dx12UavDescription.Texture2D.PlaneSlice = 0;

                    dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
                    dx12SrvDescription.Texture2D.MipLevels = dx12Desc.MipLevels;
                    dx12SrvDescription.Texture2D.MostDetailedMip = 0;
                    dx12SrvDescription.Texture2D.PlaneSlice = 0;
                }
                break;
            }

            case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE3D;
                dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE3D;
                dx12SrvDescription.Texture3D.MipLevels = dx12Resource->GetDesc().MipLevels;
                dx12SrvDescription.Texture3D.MostDetailedMip = 0;
                break;

            default:
                break;
            }

            if (dx12Desc.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER) {

                                                                                                                            
                dx12SrvDescription.Format                     = DXGI_FORMAT_R32_TYPELESS;
                dx12SrvDescription.Buffer.Flags               = D3D12_BUFFER_SRV_FLAG_RAW;
                dx12SrvDescription.Buffer.FirstElement        = 0;
                dx12SrvDescription.Buffer.StructureByteStride = 0;
                dx12SrvDescription.Buffer.NumElements         = UINT(dx12Desc.Width / 4);
                D3D12_CPU_DESCRIPTOR_HANDLE dx12CpuHandle     = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
                dx12CpuHandle.ptr += outTexture->internalIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, dx12CpuHandle);

                      
                if (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) {

                    FFX_ASSERT(effectContext.nextStaticUavDescriptor + 1 < effectContext.nextDynamicUavDescriptor);
                    backendResource->uavDescCount = 1;
                    backendResource->uavDescIndex = effectContext.nextStaticUavDescriptor++;

                    dx12UavDescription.Format = DXGI_FORMAT_R32_TYPELESS;
                    dx12UavDescription.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
                    dx12UavDescription.Buffer.FirstElement = 0;
                    dx12UavDescription.Buffer.StructureByteStride = 0;
                    dx12UavDescription.Buffer.NumElements = UINT(dx12Desc.Width / 4);
                    dx12UavDescription.Buffer.CounterOffsetInBytes = 0;

                    dx12CpuHandle = backendContext->descHeapUavGpu->GetCPUDescriptorHandleForHeapStart();
                    dx12CpuHandle.ptr += (backendResource->uavDescIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                    dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);

                    dx12CpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                    dx12CpuHandle.ptr += (backendResource->uavDescIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                    dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);

                    effectContext.nextStaticUavDescriptor++;
                }
            }
            else {
                               
                D3D12_CPU_DESCRIPTOR_HANDLE dx12CpuHandle = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
                dx12CpuHandle.ptr += outTexture->internalIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, dx12CpuHandle);

                      
                if (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) {

                    const int32_t uavDescriptorCount = (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) ? dx12Desc.MipLevels : 1;
                    FFX_ASSERT(effectContext.nextStaticUavDescriptor + uavDescriptorCount < effectContext.nextDynamicUavDescriptor);

                    backendResource->uavDescCount = uavDescriptorCount;
                    backendResource->uavDescIndex = effectContext.nextStaticUavDescriptor;

                    for (int32_t currentMipIndex = 0; currentMipIndex < uavDescriptorCount; ++currentMipIndex) {

                        if (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE3D)
                        {
                            dx12UavDescription.Texture3D.MipSlice    = currentMipIndex;
                            dx12UavDescription.Texture3D.FirstWSlice = currentMipIndex;
                            dx12UavDescription.Texture3D.WSize       = createResourceDescription->resourceDescription.depth;
                        }
                        else if (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE2D)
                            dx12UavDescription.Texture2D.MipSlice = currentMipIndex;
                        else if (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE1D)
                            dx12UavDescription.Texture1D.MipSlice = currentMipIndex;

                        dx12CpuHandle = backendContext->descHeapUavGpu->GetCPUDescriptorHandleForHeapStart();
                        dx12CpuHandle.ptr += (backendResource->uavDescIndex + currentMipIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                        dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);

                        dx12CpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                        dx12CpuHandle.ptr += (backendResource->uavDescIndex + currentMipIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                        dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);
                    }

                    effectContext.nextStaticUavDescriptor += uavDescriptorCount;
                }
            }
        }

                                                
        if (initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED) {

            FfxResourceInternal copySrc;
            FfxCreateResourceDescription uploadDescription = { *createResourceDescription };
            uploadDescription.heapType = FFX_HEAP_TYPE_UPLOAD;
            uploadDescription.resourceDescription.usage = FFX_RESOURCE_USAGE_READ_ONLY;
            uploadDescription.initialState = FFX_RESOURCE_STATE_GENERIC_READ;

            backendInterface->fpCreateResource(backendInterface, &uploadDescription, effectContextId, &copySrc);

                                   
            FfxGpuJobDescription copyJob  = { FFX_GPU_JOB_COPY };
            copyJob.copyJobDescriptor.src = copySrc;
            copyJob.copyJobDescriptor.dst = *outTexture;
            copyJob.copyJobDescriptor.srcOffset = 0;
            copyJob.copyJobDescriptor.dstOffset = 0;
            copyJob.copyJobDescriptor.size      = 0;

            backendInterface->fpScheduleGpuJob(backendInterface, &copyJob);
        }
    }
    
    effectContext.vramUsage.totalUsageInBytes += resourceSize;
    if ((createResourceDescription->resourceDescription.flags & FFX_RESOURCE_FLAGS_ALIASABLE) == FFX_RESOURCE_FLAGS_ALIASABLE)
    {
        effectContext.vramUsage.aliasableUsageInBytes += resourceSize;
    }

    return FFX_OK;
}

FfxErrorCode DestroyResourceDX12(
    FfxInterface* backendInterface,
    FfxResourceInternal resource,
	FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;
	BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];
	if ((resource.internalIndex >= int32_t(effectContextId * FFX_MAX_RESOURCE_COUNT)) && (resource.internalIndex < int32_t(effectContext.nextStaticResource))) {
		ID3D12Resource* dx12Resource = getDX12ResourcePtr(backendContext, resource.internalIndex);

		if (dx12Resource) {

            uint64_t resourceSize = GetResourceGpuMemorySizeDX12(dx12Resource);

			nfruDeferRelease(dx12Resource);
            if (backendContext->pResources[resource.internalIndex].tensorImage)
            {
                nfruDeferRelease(backendContext->pResources[resource.internalIndex].tensorImage);
                backendContext->pResources[resource.internalIndex].tensorImage = nullptr;
            }

                                         
            effectContext.vramUsage.totalUsageInBytes -= resourceSize;
            if ((backendContext->pResources[resource.internalIndex].resourceDescription.flags & FFX_RESOURCE_FLAGS_ALIASABLE) == FFX_RESOURCE_FLAGS_ALIASABLE)
            {
                effectContext.vramUsage.aliasableUsageInBytes -= resourceSize;
            }

			backendContext->pResources[resource.internalIndex].resourcePtr = nullptr;
		}
        
        return FFX_OK;
	}

	return FFX_ERROR_OUT_OF_RANGE;
}

DXGI_FORMAT patchDxgiFormatWithFfxUsage(DXGI_FORMAT dxResFmt, FfxSurfaceFormat ffxFmt)
{
    DXGI_FORMAT fromFfx = ffxGetDX12FormatFromSurfaceFormat(ffxFmt);
    DXGI_FORMAT fmt = dxResFmt;

    switch (fmt)
    {
    case DXGI_FORMAT_UNKNOWN:
        return fromFfx;

                                                                
    case DXGI_FORMAT_R8G8B8A8_UNORM:
    case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
        return fromFfx;
    
                                                                                           
    case DXGI_FORMAT_D32_FLOAT:
        return DXGI_FORMAT_R32_FLOAT;

    case DXGI_FORMAT_R32G8X24_TYPELESS:
    case DXGI_FORMAT_D32_FLOAT_S8X24_UINT:
        return DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS;

    case DXGI_FORMAT_R24G8_TYPELESS:
    case DXGI_FORMAT_D24_UNORM_S8_UINT:
        return DXGI_FORMAT_R24_UNORM_X8_TYPELESS;

    case DXGI_FORMAT_D16_UNORM:
        return DXGI_FORMAT_R16_UNORM;

    default:
        break;
    }
    return fmt;
}

FfxErrorCode MapResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource, void** ptr)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    if (FAILED(backendContext->pResources[resource.internalIndex].resourcePtr->Map(0, NULL, ptr)))
        return FFX_ERROR_BACKEND_API_ERROR;

    return FFX_OK;
}

FfxErrorCode UnmapResourceDX12(FfxInterface* backendInterface, FfxResourceInternal resource)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    backendContext->pResources[resource.internalIndex].resourcePtr->Unmap(0, NULL);

    return FFX_OK;
}

FfxErrorCode RegisterResourceDX12(
    FfxInterface* backendInterface,
    const FfxResource* inFfxResource,
    FfxUInt32 effectContextId,
    FfxResourceInternal* outFfxResourceInternal
)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)(backendInterface->scratchBuffer);
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendContext->device);
    ID3D12Resource* dx12Resource = reinterpret_cast<ID3D12Resource*>(inFfxResource->resource);
    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    FfxResourceStates state = inFfxResource->state;

    if (dx12Resource == nullptr) {

        outFfxResourceInternal->internalIndex = 0;                                                          
        return FFX_OK;
    }

    FFX_ASSERT(effectContext.nextDynamicResource > effectContext.nextStaticResource);
    outFfxResourceInternal->internalIndex = effectContext.nextDynamicResource--;

    BackendContext_DX12::Resource* backendResource = &backendContext->pResources[outFfxResourceInternal->internalIndex];
    backendResource->resourcePtr = dx12Resource;
    backendResource->tensorImage = nullptr;
    backendResource->initialState = state;
    backendResource->currentState = state;

#ifdef _DEBUG
    const wchar_t* name = inFfxResource->name;
    if (name) {
        wcscpy_s(backendResource->resourceName, name);
    }
#endif

                            
    if (dx12Resource) {

        D3D12_UNORDERED_ACCESS_VIEW_DESC dx12UavDescription = {};
        D3D12_SHADER_RESOURCE_VIEW_DESC dx12SrvDescription = {};
        D3D12_RESOURCE_DESC dx12Desc = dx12Resource->GetDesc();

                                                                                                         
        DXGI_FORMAT descFormat = patchDxgiFormatWithFfxUsage(dx12Desc.Format, inFfxResource->description.format);

        dx12UavDescription.Format = convertFormatUav(descFormat);
                                                                                           
        dx12SrvDescription.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        dx12SrvDescription.Format = convertFormatSrv(descFormat);

        bool requestArrayView = FFX_CONTAINS_FLAG(inFfxResource->description.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

        switch (dx12Desc.Dimension) {

        case D3D12_RESOURCE_DIMENSION_BUFFER:
            dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
            dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
            backendResource->resourceDescription.type = FFX_RESOURCE_TYPE_BUFFER;
            backendResource->resourceDescription.size = inFfxResource->description.size;
            backendResource->resourceDescription.stride = inFfxResource->description.stride;
            backendResource->resourceDescription.alignment = 0;
            break;

        case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
            if (dx12Desc.DepthOrArraySize > 1 || requestArrayView)
            {
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE1DARRAY;
                dx12UavDescription.Texture1DArray.ArraySize = dx12Desc.DepthOrArraySize;
                dx12UavDescription.Texture1DArray.FirstArraySlice = 0;
                dx12UavDescription.Texture1DArray.MipSlice = 0;

                dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE1DARRAY;
                dx12SrvDescription.Texture1DArray.ArraySize = dx12Desc.DepthOrArraySize;
                dx12SrvDescription.Texture1DArray.FirstArraySlice = 0;
                dx12SrvDescription.Texture1DArray.MipLevels = dx12Desc.MipLevels;
                dx12SrvDescription.Texture1DArray.MostDetailedMip = 0;
            }
            else
            {
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE1D;
                dx12UavDescription.Texture1D.MipSlice = 0;

                dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE1D;
                dx12SrvDescription.Texture1D.MipLevels = dx12Desc.MipLevels;
                dx12SrvDescription.Texture1D.MostDetailedMip = 0;
            }

            backendResource->resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE1D;
            backendResource->resourceDescription.format = inFfxResource->description.format;
            backendResource->resourceDescription.width = inFfxResource->description.width;
            backendResource->resourceDescription.mipCount = inFfxResource->description.mipCount;
            backendResource->resourceDescription.depth = inFfxResource->description.depth;
            break;

        case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
        {
            if (dx12Desc.DepthOrArraySize > 1 || requestArrayView)
            {
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2DARRAY;
                dx12UavDescription.Texture2DArray.ArraySize = dx12Desc.DepthOrArraySize;
                dx12UavDescription.Texture2DArray.FirstArraySlice = 0;
                dx12UavDescription.Texture2DArray.MipSlice = 0;
                dx12UavDescription.Texture2DArray.PlaneSlice = 0;

                dx12SrvDescription.ViewDimension = inFfxResource->description.type == FFX_RESOURCE_TYPE_TEXTURE_CUBE ? D3D12_SRV_DIMENSION_TEXTURECUBE : D3D12_SRV_DIMENSION_TEXTURE2DARRAY;
                dx12SrvDescription.Texture2DArray.ArraySize = dx12Desc.DepthOrArraySize;
                dx12SrvDescription.Texture2DArray.FirstArraySlice = 0;
                dx12SrvDescription.Texture2DArray.MipLevels = dx12Desc.MipLevels;
                dx12SrvDescription.Texture2DArray.MostDetailedMip = 0;
                dx12SrvDescription.Texture2DArray.PlaneSlice = 0;
            }
            else
            {
                dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
                dx12UavDescription.Texture2D.MipSlice = 0;
                dx12UavDescription.Texture2D.PlaneSlice = 0;

                dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
                dx12SrvDescription.Texture2D.MipLevels = dx12Desc.MipLevels;
                dx12SrvDescription.Texture2D.MostDetailedMip = 0;
                dx12SrvDescription.Texture2D.PlaneSlice = 0;
            }

            backendResource->resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
            backendResource->resourceDescription.format = inFfxResource->description.format;
            backendResource->resourceDescription.width = inFfxResource->description.width;
            backendResource->resourceDescription.height = inFfxResource->description.height;
            backendResource->resourceDescription.mipCount = inFfxResource->description.mipCount;
            backendResource->resourceDescription.depth = inFfxResource->description.depth;
            break;
        }

        case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
            dx12UavDescription.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE3D;
            dx12UavDescription.Texture3D.FirstWSlice      = 0;                     
            dx12UavDescription.Texture3D.WSize            = std::numeric_limits<UINT>::max();
            dx12SrvDescription.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE3D;
            dx12SrvDescription.Texture3D.MipLevels = dx12Desc.MipLevels;
            dx12SrvDescription.Texture3D.MostDetailedMip = 0;

            backendResource->resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE3D;
            backendResource->resourceDescription.format = inFfxResource->description.format;
            backendResource->resourceDescription.width = inFfxResource->description.width;
            backendResource->resourceDescription.height = inFfxResource->description.height;
            backendResource->resourceDescription.mipCount = inFfxResource->description.mipCount;
            backendResource->resourceDescription.depth = inFfxResource->description.depth;
            break;

        default:
            break;
        }

        if (dx12Desc.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER) {

                  
            if (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) {

                FFX_ASSERT(effectContext.nextDynamicUavDescriptor > effectContext.nextStaticUavDescriptor);
                backendResource->uavDescCount = 1;
                backendResource->uavDescIndex = effectContext.nextDynamicUavDescriptor--;

                dx12UavDescription.Format = DXGI_FORMAT_R32_TYPELESS;
                dx12UavDescription.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
                dx12UavDescription.Buffer.FirstElement = 0;
                dx12UavDescription.Buffer.StructureByteStride = 0;
                dx12UavDescription.Buffer.NumElements = UINT(dx12Desc.Width / 4);
                dx12UavDescription.Buffer.CounterOffsetInBytes = 0;

                D3D12_CPU_DESCRIPTOR_HANDLE dx12CpuHandle = backendContext->descHeapUavGpu->GetCPUDescriptorHandleForHeapStart();
                dx12CpuHandle.ptr += (backendResource->uavDescIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);

                dx12CpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                dx12CpuHandle.ptr += (backendResource->uavDescIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, dx12CpuHandle);
            }

            {
                dx12SrvDescription.Format = DXGI_FORMAT_R32_TYPELESS;
                dx12SrvDescription.Buffer.Flags               = D3D12_BUFFER_SRV_FLAG_RAW;
                dx12SrvDescription.Buffer.FirstElement        = 0;
                dx12SrvDescription.Buffer.StructureByteStride = 0;
                dx12SrvDescription.Buffer.NumElements         = UINT(dx12Desc.Width / 4);
                D3D12_CPU_DESCRIPTOR_HANDLE dx12CpuHandle     = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
                dx12CpuHandle.ptr += outFfxResourceInternal->internalIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, dx12CpuHandle);
                backendResource->srvDescIndex = outFfxResourceInternal->internalIndex;
            }
        }
        else {

                           
            D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
            cpuHandle.ptr += outFfxResourceInternal->internalIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
            dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, cpuHandle);
            backendResource->srvDescIndex = outFfxResourceInternal->internalIndex;

                  
            if (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) {

                const int32_t uavDescriptorsCount = (dx12Desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS) ? dx12Desc.MipLevels : 1;
                FFX_ASSERT(effectContext.nextDynamicUavDescriptor - uavDescriptorsCount + 1 > effectContext.nextStaticUavDescriptor);

                backendResource->uavDescCount = uavDescriptorsCount;
                backendResource->uavDescIndex = effectContext.nextDynamicUavDescriptor - uavDescriptorsCount + 1;

                for (int32_t currentMipIndex = 0; currentMipIndex < uavDescriptorsCount; ++currentMipIndex) {

                    switch (dx12Desc.Dimension)
                    {
                    case D3D12_RESOURCE_DIMENSION_BUFFER:
                        break;

                    case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
                    case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
                    case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
                                                                       
                        dx12UavDescription.Texture2D.MipSlice = currentMipIndex;
                        break;

                    default:
                        FFX_ASSERT_MESSAGE(false, "Invalid View Dimension");
                        break;
                    }

                    cpuHandle = backendContext->descHeapUavGpu->GetCPUDescriptorHandleForHeapStart();
                    cpuHandle.ptr += (backendResource->uavDescIndex + currentMipIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                    dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, cpuHandle);

                    cpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                    cpuHandle.ptr += (backendResource->uavDescIndex + currentMipIndex) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                    dx12Device->CreateUnorderedAccessView(dx12Resource, 0, &dx12UavDescription, cpuHandle);
                }

                effectContext.nextDynamicUavDescriptor -= uavDescriptorsCount;
            }
        }
    }

    return FFX_OK;
}

FfxResource GetResourceDX12(FfxInterface* backendInterface, FfxResourceInternal inResource)
{
    FFX_ASSERT(nullptr != backendInterface);
    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    FfxResourceDescription ffxResDescription = backendInterface->fpGetResourceDescription(backendInterface, inResource);

    FfxResource resource = {};
    resource.resource = resource.resource = reinterpret_cast<void*>(backendContext->pResources[inResource.internalIndex].resourcePtr);
    resource.state = backendContext->pResources[inResource.internalIndex].currentState;
    resource.description = ffxResDescription;

#ifdef _DEBUG
    if (backendContext->pResources[inResource.internalIndex].resourceName)
    {
        wcscpy_s(resource.name, backendContext->pResources[inResource.internalIndex].resourceName);
    }
#endif

    return resource;
}

                                                                           
FfxErrorCode UnregisterResourcesDX12(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_DX12* backendContext = (BackendContext_DX12*)(backendInterface->scratchBuffer);
    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

                                                                                                
    for (uint32_t resourceIndex = ++effectContext.nextDynamicResource; resourceIndex < (effectContextId * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT; ++resourceIndex)
    {
        FfxResourceInternal internalResource;
        internalResource.internalIndex = resourceIndex;

        BackendContext_DX12::Resource* backendResource = &backendContext->pResources[resourceIndex];
        addBarrier(backendContext, &internalResource, backendResource->initialState);
    }

    FFX_ASSERT(nullptr != commandList);
    ID3D12GraphicsCommandList* pCmdList = reinterpret_cast<ID3D12GraphicsCommandList*>(commandList);

    flushBarriers(backendContext, pCmdList);

    effectContext.nextDynamicResource      = (effectContextId * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT - 1;
    effectContext.nextDynamicUavDescriptor = (effectContextId * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT - 1;

    return FFX_OK;
}

FfxErrorCode registerStaticTextureSrv(BackendContext_DX12* backendContext, const FfxResource* inResource, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_DX12::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    ID3D12Device*                       dx12Device     = reinterpret_cast<ID3D12Device*>(backendContext->device);
    ID3D12Resource*                     dx12Resource   = reinterpret_cast<ID3D12Resource*>(inResource->resource);

    if (effectContext.bindlessTextureSrvHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    if (dx12Resource == nullptr)
        return FFX_OK;

                            
    if (dx12Resource)
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC dx12SrvDescription = {};
        dx12SrvDescription.Shader4ComponentMapping         = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        dx12SrvDescription.Format                          = convertFormatSrv(dx12Resource->GetDesc().Format);

        uint32_t depthArraySize = dx12Resource->GetDesc().DepthOrArraySize;

        switch (dx12Resource->GetDesc().Dimension)
        {
        case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
            if (depthArraySize > 1)
            {
                dx12SrvDescription.ViewDimension            = D3D12_SRV_DIMENSION_TEXTURE1DARRAY;
                dx12SrvDescription.Texture1DArray.MipLevels = dx12Resource->GetDesc().MipLevels;
                dx12SrvDescription.Texture1DArray.ArraySize = std::numeric_limits<UINT>::max();
            }
            else
            {
                dx12SrvDescription.ViewDimension       = D3D12_SRV_DIMENSION_TEXTURE1D;
                dx12SrvDescription.Texture1D.MipLevels = dx12Resource->GetDesc().MipLevels;
            }
            break;

        case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
            if (depthArraySize > 1)
            {
                dx12SrvDescription.ViewDimension            = D3D12_SRV_DIMENSION_TEXTURE2DARRAY;
                dx12SrvDescription.Texture2DArray.MipLevels = dx12Resource->GetDesc().MipLevels;
                dx12SrvDescription.Texture2DArray.ArraySize = depthArraySize;
                dx12SrvDescription.Texture2DArray.ArraySize = std::numeric_limits<UINT>::max();
            }
            else
            {
                dx12SrvDescription.ViewDimension       = D3D12_SRV_DIMENSION_TEXTURE2D;
                dx12SrvDescription.Texture2D.MipLevels = dx12Resource->GetDesc().MipLevels;
            }
            break;

        case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
            dx12SrvDescription.ViewDimension       = D3D12_SRV_DIMENSION_TEXTURE3D;
            dx12SrvDescription.Texture3D.MipLevels = dx12Resource->GetDesc().MipLevels;
            break;

        default:
                                                       
            FFX_ASSERT(false);
            break;
        }

                       
        D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descRingBuffer->GetCPUDescriptorHandleForHeapStart();
        cpuHandle.ptr +=
            (effectContext.bindlessTextureSrvHeapStart + index) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, cpuHandle);
    }

    return FFX_OK;
}

FfxErrorCode registerStaticBufferSrv(BackendContext_DX12* backendContext, const FfxResource* inResource, uint32_t offset, uint32_t size, uint32_t stride, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_DX12::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    ID3D12Device*                       dx12Device     = reinterpret_cast<ID3D12Device*>(backendContext->device);
    ID3D12Resource*                     dx12Resource   = reinterpret_cast<ID3D12Resource*>(inResource->resource);

    if (effectContext.bindlessBufferSrvHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    constexpr uint32_t ShaderComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;

    if (dx12Resource == nullptr)
        return FFX_OK;

                            
    if (dx12Resource)
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC dx12SrvDescription = {};
        dx12SrvDescription.Shader4ComponentMapping         = ShaderComponentMapping;

        switch (dx12Resource->GetDesc().Dimension)
        {
        case D3D12_RESOURCE_DIMENSION_BUFFER:
        {
            FFX_ASSERT(stride > 0);

            const uint32_t actualSize = size > 0 ? size : uint32_t(dx12Resource->GetDesc().Width);

            dx12SrvDescription.Format                     = DXGI_FORMAT_UNKNOWN;
            dx12SrvDescription.ViewDimension              = D3D12_SRV_DIMENSION_BUFFER;
            dx12SrvDescription.Buffer.FirstElement        = offset / stride;
            dx12SrvDescription.Buffer.NumElements         = actualSize / stride;
            dx12SrvDescription.Buffer.StructureByteStride = stride;
            dx12SrvDescription.Buffer.Flags               = D3D12_BUFFER_SRV_FLAG_NONE;
            dx12SrvDescription.Shader4ComponentMapping    = ShaderComponentMapping;
            break;
        }
        default:
                                                      
            FFX_ASSERT(false);
            break;
        }

                       
        D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descRingBuffer->GetCPUDescriptorHandleForHeapStart();
        cpuHandle.ptr +=
            (effectContext.bindlessBufferSrvHeapStart + index) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        dx12Device->CreateShaderResourceView(dx12Resource, &dx12SrvDescription, cpuHandle);
    }

    return FFX_OK;
}

FfxErrorCode registerStaticTextureUav(BackendContext_DX12* backendContext, const FfxResource* inResource, uint32_t mip, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_DX12::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    ID3D12Device*                       dx12Device     = reinterpret_cast<ID3D12Device*>(backendContext->device);
    ID3D12Resource*                     dx12Resource   = reinterpret_cast<ID3D12Resource*>(inResource->resource);

    if (effectContext.bindlessTextureUavHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    if (dx12Resource == nullptr)
        return FFX_OK;

                            
    if (dx12Resource)
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC dx12UavDescription = {};
        dx12UavDescription.Format                           = convertFormatSrv(dx12Resource->GetDesc().Format);

        uint32_t depthArraySize = dx12Resource->GetDesc().DepthOrArraySize;

        switch (dx12Resource->GetDesc().Dimension)
        {
        case D3D12_RESOURCE_DIMENSION_TEXTURE1D:
        {
            if (depthArraySize > 1)
            {
                dx12UavDescription.ViewDimension                  = D3D12_UAV_DIMENSION_TEXTURE1DARRAY;
                dx12UavDescription.Texture1DArray.ArraySize       = depthArraySize;
                dx12UavDescription.Texture1DArray.FirstArraySlice = 0;
                dx12UavDescription.Texture1DArray.MipSlice        = mip;
            }
            else
            {
                dx12UavDescription.ViewDimension      = D3D12_UAV_DIMENSION_TEXTURE1D;
                dx12UavDescription.Texture1D.MipSlice = mip;
            }
            break;
        }
        case D3D12_RESOURCE_DIMENSION_TEXTURE2D:
        {
            if (depthArraySize > 1)
            {
                dx12UavDescription.ViewDimension                  = D3D12_UAV_DIMENSION_TEXTURE2DARRAY;
                dx12UavDescription.Texture2DArray.ArraySize       = depthArraySize;
                dx12UavDescription.Texture2DArray.FirstArraySlice = 0;
                dx12UavDescription.Texture2DArray.MipSlice        = mip;
                dx12UavDescription.Texture2DArray.PlaneSlice      = 0;
            }
            else
            {
                dx12UavDescription.ViewDimension        = D3D12_UAV_DIMENSION_TEXTURE2D;
                dx12UavDescription.Texture2D.MipSlice   = mip;
                dx12UavDescription.Texture2D.PlaneSlice = 0;
            }
            break;
        }
        case D3D12_RESOURCE_DIMENSION_TEXTURE3D:
        {
            dx12UavDescription.ViewDimension         = D3D12_UAV_DIMENSION_TEXTURE3D;
            dx12UavDescription.Texture3D.FirstWSlice = 0;                      
            dx12UavDescription.Texture3D.WSize       = std::numeric_limits<UINT>::max();
            break;
        }
        default:
                                                       
            FFX_ASSERT(false);
            break;
        }

                       
        D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descRingBuffer->GetCPUDescriptorHandleForHeapStart();
        cpuHandle.ptr +=
            (effectContext.bindlessTextureUavHeapStart + index) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        dx12Device->CreateUnorderedAccessView(dx12Resource, nullptr, &dx12UavDescription, cpuHandle);
    }

    return FFX_OK;
}

FfxErrorCode registerStaticBufferUav(BackendContext_DX12* backendContext, const FfxResource* inResource, uint32_t offset, uint32_t size, uint32_t stride, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_DX12::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    ID3D12Device*                       dx12Device     = reinterpret_cast<ID3D12Device*>(backendContext->device);
    ID3D12Resource*                     dx12Resource   = reinterpret_cast<ID3D12Resource*>(inResource->resource);

    if (effectContext.bindlessBufferUavHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    if (dx12Resource == nullptr)
        return FFX_OK;

                            
    if (dx12Resource)
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC dx12UavDescription = {};

        switch (dx12Resource->GetDesc().Dimension)
        {
        case D3D12_RESOURCE_DIMENSION_BUFFER:
        {
            FFX_ASSERT(stride > 0);

            const uint32_t actualSize = size > 0 ? size : uint32_t(dx12Resource->GetDesc().Width);

            dx12UavDescription.Format                      = DXGI_FORMAT_UNKNOWN;
            dx12UavDescription.ViewDimension               = D3D12_UAV_DIMENSION_BUFFER;
            dx12UavDescription.Buffer.FirstElement         = offset / stride;
            dx12UavDescription.Buffer.NumElements          = actualSize / stride;
            dx12UavDescription.Buffer.StructureByteStride  = stride;
            dx12UavDescription.Buffer.CounterOffsetInBytes = 0;
            dx12UavDescription.Buffer.Flags                = D3D12_BUFFER_UAV_FLAG_NONE;
            break;
        }
        default:
                                                      
            FFX_ASSERT(false);
            break;
        }

                       
        D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descRingBuffer->GetCPUDescriptorHandleForHeapStart();
        cpuHandle.ptr +=
            (effectContext.bindlessBufferUavHeapStart + index) * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        dx12Device->CreateUnorderedAccessView(dx12Resource, nullptr, &dx12UavDescription, cpuHandle);
    }

    return FFX_OK;
}

FfxErrorCode RegisterStaticResourceDX12(FfxInterface* backendInterface, const FfxStaticResourceDescription* desc, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != desc);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    switch (desc->descriptorType)
    {
    case FFX_DESCRIPTOR_TEXTURE_SRV:
        return registerStaticTextureSrv(backendContext, desc->resource, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_BUFFER_SRV:
        return registerStaticBufferSrv(backendContext, desc->resource, desc->bufferOffset, desc->bufferSize, desc->bufferStride, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_TEXTURE_UAV:
        return registerStaticTextureUav(backendContext, desc->resource, desc->textureUavMip, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_BUFFER_UAV:
        return registerStaticBufferUav(backendContext, desc->resource, desc->bufferOffset, desc->bufferSize, desc->bufferStride, desc->descriptorIndex, effectContextId);
    default:
        return FFX_ERROR_INVALID_ARGUMENT;
    }
}

FfxResourceDescription GetResourceDescriptorDX12(
    FfxInterface* backendInterface,
    FfxResourceInternal resource)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    FfxResourceDescription resourceDescription = backendContext->pResources[resource.internalIndex].resourceDescription;
    return resourceDescription;
}

FfxErrorCode StageConstantBufferDataDX12(FfxInterface* backendInterface, void* data, FfxUInt32 size, FfxConstantBuffer* constantBuffer)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    if (data && constantBuffer)
    {
        if ((backendContext->stagingRingBufferBase + FFX_ALIGN_UP(size, 256)) >= FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE)
            backendContext->stagingRingBufferBase = 0;

        uint32_t* dstPtr = (uint32_t*)(backendContext->pStagingRingBuffer + backendContext->stagingRingBufferBase);

        memcpy(dstPtr, data, size);

        constantBuffer->data            = dstPtr;
        constantBuffer->num32BitEntries = size / sizeof(uint32_t);

        backendContext->stagingRingBufferBase += FFX_ALIGN_UP(size, 256);

        return FFX_OK;
    }
    else
        return FFX_ERROR_INVALID_POINTER;
}

D3D12_TEXTURE_ADDRESS_MODE FfxGetAddressModeDX12(const FfxAddressMode& addressMode)
{
    switch (addressMode)
    {
    case FFX_ADDRESS_MODE_WRAP:
        return D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    case FFX_ADDRESS_MODE_MIRROR:
        return D3D12_TEXTURE_ADDRESS_MODE_MIRROR;
    case FFX_ADDRESS_MODE_CLAMP:
        return D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    case FFX_ADDRESS_MODE_BORDER:
        return D3D12_TEXTURE_ADDRESS_MODE_BORDER;
    case FFX_ADDRESS_MODE_MIRROR_ONCE:
        return D3D12_TEXTURE_ADDRESS_MODE_MIRROR_ONCE;
    default:
        FFX_ASSERT_MESSAGE(false, "Unsupported addressing mode requested. Please implement");
        return D3D12_TEXTURE_ADDRESS_MODE_WRAP;
        break;
    }
}

FfxErrorCode CreatePipelineDX12(
    FfxInterface* backendInterface,
    FfxEffect effect,
    FfxPass pass,
    uint32_t permutationOptions,
    const FfxPipelineDescription* pipelineDescription,
    FfxUInt32                     effectContextId,
    FfxPipelineState* outPipeline)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != pipelineDescription);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;
    ID3D12Device* dx12Device = backendContext->device;

    FfxShaderBlob shaderBlob = { };
    backendInterface->fpGetPermutationBlobByIndex(effect, pass, permutationOptions, &shaderBlob, nullptr, nullptr);
    FFX_ASSERT(shaderBlob.data && shaderBlob.size);

    int32_t staticTextureSrvCount = 0;
    int32_t staticBufferSrvCount  = 0;
    int32_t staticTextureUavCount = 0;
    int32_t staticBufferUavCount  = 0;

    int32_t staticTextureSrvSpace = -1;
    int32_t staticBufferSrvSpace  = -1;
    int32_t staticTextureUavSpace = -1;
    int32_t staticBufferUavSpace  = -1;

                            
                                                                            
                                                                                               
    {
        FFX_ASSERT(pipelineDescription->samplerCount <= FFX_MAX_SAMPLERS);
        const size_t samplerCount = pipelineDescription->samplerCount;
        D3D12_STATIC_SAMPLER_DESC dx12SamplerDescriptions[FFX_MAX_SAMPLERS];
        for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < samplerCount; ++currentSamplerIndex) {

            D3D12_STATIC_SAMPLER_DESC dx12SamplerDesc = {};

            dx12SamplerDesc.ComparisonFunc = D3D12_COMPARISON_FUNC_NEVER;
            dx12SamplerDesc.MinLOD = 0.f;
            dx12SamplerDesc.MaxLOD = D3D12_FLOAT32_MAX;
            dx12SamplerDesc.MipLODBias = 0.f;
            dx12SamplerDesc.MaxAnisotropy = 16;
            dx12SamplerDesc.BorderColor = D3D12_STATIC_BORDER_COLOR_TRANSPARENT_BLACK;
            dx12SamplerDesc.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
            dx12SamplerDesc.AddressU = FfxGetAddressModeDX12(pipelineDescription->samplers[currentSamplerIndex].addressModeU);
            dx12SamplerDesc.AddressV = FfxGetAddressModeDX12(pipelineDescription->samplers[currentSamplerIndex].addressModeV);
            dx12SamplerDesc.AddressW = FfxGetAddressModeDX12(pipelineDescription->samplers[currentSamplerIndex].addressModeW);

            switch (pipelineDescription->samplers[currentSamplerIndex].filter)
            {
            case FFX_FILTER_TYPE_MINMAGMIP_POINT:
                dx12SamplerDesc.Filter = D3D12_FILTER_MIN_MAG_MIP_POINT;
                break;
            case FFX_FILTER_TYPE_MINMAGMIP_LINEAR:
                dx12SamplerDesc.Filter = D3D12_FILTER_MIN_MAG_MIP_LINEAR;
                break;
            case FFX_FILTER_TYPE_MINMAGLINEARMIP_POINT:
                dx12SamplerDesc.Filter = D3D12_FILTER_MIN_MAG_LINEAR_MIP_POINT;
                break;

            default:
                FFX_ASSERT_MESSAGE(false, "Unsupported filter type requested. Please implement");
                break;
            }

            dx12SamplerDescriptions[currentSamplerIndex] = dx12SamplerDesc;
            dx12SamplerDescriptions[currentSamplerIndex].ShaderRegister = (UINT)currentSamplerIndex + 1000;                                                                                
        }

                                                           
        const int32_t maximumDescriptorRangeSize = 3;
        D3D12_DESCRIPTOR_RANGE dx12Ranges[maximumDescriptorRangeSize] = {};
        int32_t currentDescriptorRangeIndex = 0;

                                                         
        const int32_t maximumRootParameters = 10;
        D3D12_ROOT_PARAMETER dx12RootParameters[maximumRootParameters] = {};
        int32_t currentRootParameterIndex = 0;

        int32_t uavCount              = 0;
        int32_t maxUavSlotIndex       = 0;

        for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; uavIndex++)
        {
                                            
            if (shaderBlob.boundUAVBufferSpaces[uavIndex] != 0)
            {
                if (staticBufferUavCount > 0)
                    FFX_ASSERT(uint32_t(staticBufferUavSpace) != shaderBlob.boundUAVBufferSpaces[uavIndex]);

                staticBufferUavCount += shaderBlob.boundUAVBufferCounts[uavIndex];
                staticBufferUavSpace = shaderBlob.boundUAVBufferSpaces[uavIndex];
                continue;
            }

            uint32_t bindCount = shaderBlob.boundUAVBufferCounts[uavIndex];

            uavCount += bindCount;

            if (shaderBlob.boundUAVBuffers[uavIndex] > uint32_t(maxUavSlotIndex))
                maxUavSlotIndex = shaderBlob.boundUAVBuffers[uavIndex] + (bindCount - 1);
        }

        for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; uavIndex++)
        {
                                            
            if (shaderBlob.boundUAVTextureSpaces[uavIndex] != 0)
            {
                if (staticTextureUavCount > 0)
                    FFX_ASSERT(uint32_t(staticTextureUavSpace) != shaderBlob.boundUAVTextureSpaces[uavIndex]);

                staticTextureUavCount += shaderBlob.boundUAVTextureCounts[uavIndex];
                staticTextureUavSpace = shaderBlob.boundUAVTextureSpaces[uavIndex];
                continue;
            }

            uint32_t bindCount = shaderBlob.boundUAVTextureCounts[uavIndex];

            uavCount += bindCount;

            if (shaderBlob.boundUAVTextures[uavIndex] > uint32_t(maxUavSlotIndex))
                maxUavSlotIndex = shaderBlob.boundUAVTextures[uavIndex] + (bindCount - 1);
        }

        if (uavCount > 0)
            uavCount = (maxUavSlotIndex + 1) > uavCount ? (maxUavSlotIndex + 1) : uavCount;

        int32_t srvCount              = 0;
        int32_t maxSrvSlotIndex       = 0;

        for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvBufferCount; srvIndex++)
        {
                                            
            if (shaderBlob.boundSRVBufferSpaces[srvIndex] != 0)
            {
                if (staticBufferSrvCount > 0)
                    FFX_ASSERT(uint32_t(staticBufferSrvSpace) != shaderBlob.boundSRVBufferSpaces[srvIndex]);

                staticBufferSrvCount += shaderBlob.boundSRVBufferCounts[srvIndex];
                staticBufferSrvSpace = shaderBlob.boundSRVBufferSpaces[srvIndex];
                continue;
            }

            uint32_t bindCount = shaderBlob.boundSRVBufferCounts[srvIndex];

            srvCount += bindCount;

            if (shaderBlob.boundSRVBuffers[srvIndex] > uint32_t(maxSrvSlotIndex))
                maxSrvSlotIndex = shaderBlob.boundSRVBuffers[srvIndex] + (bindCount - 1);
        }

        for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; srvIndex++)
        {
                                            
            if (shaderBlob.boundSRVTextureSpaces[srvIndex] != 0)
            {
                if (staticTextureSrvCount > 0)
                    FFX_ASSERT(uint32_t(staticTextureSrvSpace) != shaderBlob.boundSRVTextureSpaces[srvIndex]);

                staticTextureSrvCount += shaderBlob.boundSRVTextureCounts[srvIndex];
                staticTextureSrvSpace = shaderBlob.boundSRVTextureSpaces[srvIndex];
                continue;
            }

            uint32_t bindCount = shaderBlob.boundSRVTextureCounts[srvIndex];

            srvCount += bindCount;

            if (shaderBlob.boundSRVTextures[srvIndex] > uint32_t(maxSrvSlotIndex))
                maxSrvSlotIndex = shaderBlob.boundSRVTextures[srvIndex] + (bindCount - 1);
        }

        if (srvCount > 0)
            srvCount = (maxSrvSlotIndex + 1) > srvCount ? (maxSrvSlotIndex + 1) : srvCount;

        if (uavCount > 0) {

            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
            dx12DescriptorRange->BaseShaderRegister = 0;
            dx12DescriptorRange->NumDescriptors = uavCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

        if (srvCount > 0) {

            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
            dx12DescriptorRange->BaseShaderRegister = 0;
            dx12DescriptorRange->NumDescriptors = srvCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

        if (staticTextureSrvCount > 0)
        {
            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
            dx12DescriptorRange->BaseShaderRegister                = 0;
            dx12DescriptorRange->RegisterSpace                     = staticTextureSrvSpace;
            dx12DescriptorRange->NumDescriptors                    = staticTextureSrvCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

        if (staticBufferSrvCount > 0)
        {
            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
            dx12DescriptorRange->BaseShaderRegister                = 0;
            dx12DescriptorRange->RegisterSpace                     = staticBufferSrvSpace;
            dx12DescriptorRange->NumDescriptors                    = staticBufferSrvCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

        if (staticTextureUavCount > 0)
        {
            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
            dx12DescriptorRange->BaseShaderRegister                = 0;
            dx12DescriptorRange->RegisterSpace                     = staticTextureUavSpace;
            dx12DescriptorRange->NumDescriptors                    = staticTextureUavCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

        if (staticBufferUavCount > 0)
        {
            FFX_ASSERT(currentDescriptorRangeIndex < maximumDescriptorRangeSize);
            D3D12_DESCRIPTOR_RANGE* dx12DescriptorRange = &dx12Ranges[currentDescriptorRangeIndex];
            memset(dx12DescriptorRange, 0, sizeof(D3D12_DESCRIPTOR_RANGE));
            dx12DescriptorRange->OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
            dx12DescriptorRange->RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
            dx12DescriptorRange->BaseShaderRegister                = 0;
            dx12DescriptorRange->RegisterSpace                     = staticBufferUavSpace;
            dx12DescriptorRange->NumDescriptors                    = staticBufferUavCount;
            currentDescriptorRangeIndex++;

            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* dx12RootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(dx12RootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            dx12RootParameterSlot->ParameterType                       = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            dx12RootParameterSlot->DescriptorTable.NumDescriptorRanges = 1;
            currentRootParameterIndex++;
        }

                                                            
        for (int32_t currentRangeIndex = 0; currentRangeIndex < currentDescriptorRangeIndex; currentRangeIndex++) {

            dx12RootParameters[currentRangeIndex].DescriptorTable.pDescriptorRanges = &dx12Ranges[currentRangeIndex];
        }

        for (int32_t currentRootConstantIndex = 0; currentRootConstantIndex < (int32_t)shaderBlob.cbvCount; currentRootConstantIndex++)
        {
            FFX_ASSERT(currentRootParameterIndex < maximumRootParameters);
            D3D12_ROOT_PARAMETER* rootParameterSlot = &dx12RootParameters[currentRootParameterIndex];
            memset(rootParameterSlot, 0, sizeof(D3D12_ROOT_PARAMETER));
            rootParameterSlot->ParameterType = D3D12_ROOT_PARAMETER_TYPE_CBV;
            rootParameterSlot->Constants.ShaderRegister = shaderBlob.boundConstantBuffers[currentRootConstantIndex];
            currentRootParameterIndex++;
        }

        D3D12_ROOT_SIGNATURE_DESC dx12RootSignatureDescription = {};
        dx12RootSignatureDescription.NumParameters = currentRootParameterIndex;
        dx12RootSignatureDescription.pParameters = dx12RootParameters;
        dx12RootSignatureDescription.NumStaticSamplers = (UINT)samplerCount;
        dx12RootSignatureDescription.pStaticSamplers = dx12SamplerDescriptions;

        ID3DBlob* outBlob = nullptr;
        ID3DBlob* errorBlob = nullptr;

                                                                 
        typedef HRESULT(__stdcall* D3D12SerializeRootSignatureType)(const D3D12_ROOT_SIGNATURE_DESC*, D3D_ROOT_SIGNATURE_VERSION, ID3DBlob**, ID3DBlob**);

                                                                                                               
        HMODULE d3d12ModuleHandle = GetModuleHandleW(L"D3D12.dll");

        if (NULL != d3d12ModuleHandle) {

            D3D12SerializeRootSignatureType dx12SerializeRootSignatureType = (D3D12SerializeRootSignatureType)GetProcAddress(d3d12ModuleHandle, "D3D12SerializeRootSignature");

            if (nullptr != dx12SerializeRootSignatureType) {
                
                HRESULT result = dx12SerializeRootSignatureType(&dx12RootSignatureDescription, D3D_ROOT_SIGNATURE_VERSION_1, &outBlob, &errorBlob);
                if (errorBlob != nullptr) {

                    errorBlob->Release();
                } 
                if (FAILED(result)) {

                    if (outBlob != nullptr) {
                        
                        outBlob->Release();
                    }  
                    return FFX_ERROR_BACKEND_API_ERROR;
                }

                result = dx12Device->CreateRootSignature(0, outBlob->GetBufferPointer(), outBlob->GetBufferSize(), IID_PPV_ARGS(reinterpret_cast<ID3D12RootSignature**>(&outPipeline->rootSignature)));
                if (outBlob != nullptr) {
                    
                    outBlob->Release();
                }  
                if (FAILED(result)) {

                    return FFX_ERROR_BACKEND_API_ERROR;
                }
            } else {
                return FFX_ERROR_BACKEND_API_ERROR;
            }
        } else {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    ID3D12RootSignature* dx12RootSignature = reinterpret_cast<ID3D12RootSignature*>(outPipeline->rootSignature);

                                                                              
    if (pipelineDescription->indirectWorkload)
    {
        D3D12_INDIRECT_ARGUMENT_DESC argumentDescs = { D3D12_INDIRECT_ARGUMENT_TYPE_DISPATCH };
        D3D12_COMMAND_SIGNATURE_DESC commandSignatureDesc = {};
        commandSignatureDesc.pArgumentDescs = &argumentDescs;
        commandSignatureDesc.NumArgumentDescs = 1;
        commandSignatureDesc.ByteStride = sizeof(D3D12_DISPATCH_ARGUMENTS);

        HRESULT result = dx12Device->CreateCommandSignature(&commandSignatureDesc, nullptr, IID_PPV_ARGS(reinterpret_cast<ID3D12CommandSignature**>(&outPipeline->cmdSignature)));
        if (FAILED(result)) {

            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }
    else
    {
        outPipeline->cmdSignature = nullptr;
    }

    uint32_t flattenedSrvTextureCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; ++srvIndex)
    {
        uint32_t slotIndex  = shaderBlob.boundSRVTextures[srvIndex];
        uint32_t spaceIndex = shaderBlob.boundSRVTextureSpaces[srvIndex];
        uint32_t bindCount = shaderBlob.boundSRVTextureCounts[srvIndex];

                                
        if (spaceIndex == uint32_t(staticTextureSrvSpace))
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvTextureCount++;

            outPipeline->srvTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy_s(outPipeline->srvTextureBindings[bindingIndex].name, std::size(outPipeline->srvTextureBindings[bindingIndex].name), shaderBlob.boundSRVTextureNames[srvIndex], _TRUNCATE);
        }
    }

    outPipeline->srvTextureCount = flattenedSrvTextureCount;
    FFX_ASSERT(outPipeline->srvTextureCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavTextureCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; ++uavIndex)
    {
        uint32_t slotIndex  = shaderBlob.boundUAVTextures[uavIndex];
        uint32_t spaceIndex = shaderBlob.boundUAVTextureSpaces[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVTextureCounts[uavIndex];

                                
        if (spaceIndex == uint32_t(staticTextureUavSpace))
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavTextureCount++;

            outPipeline->uavTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy_s(outPipeline->uavTextureBindings[bindingIndex].name, std::size(outPipeline->uavTextureBindings[bindingIndex].name), shaderBlob.boundUAVTextureNames[uavIndex], _TRUNCATE);
        }
    }

    outPipeline->uavTextureCount = flattenedUavTextureCount;
    FFX_ASSERT(outPipeline->uavTextureCount < FFX_MAX_NUM_UAVS);

    uint32_t flattenedSrvBufferCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvBufferCount; ++srvIndex)
    {
        uint32_t slotIndex  = shaderBlob.boundSRVBuffers[srvIndex];
        uint32_t spaceIndex = shaderBlob.boundSRVBufferSpaces[srvIndex];
        uint32_t bindCount  = shaderBlob.boundSRVBufferCounts[srvIndex];

                                
        if (spaceIndex == uint32_t(staticBufferSrvSpace))
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvBufferCount++;

            outPipeline->srvBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy_s(outPipeline->srvBufferBindings[bindingIndex].name, std::size(outPipeline->srvBufferBindings[bindingIndex].name), shaderBlob.boundSRVBufferNames[srvIndex], _TRUNCATE);
        }
    }

    outPipeline->srvBufferCount = flattenedSrvBufferCount;
    FFX_ASSERT(outPipeline->srvBufferCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavBufferCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; ++uavIndex)
    {
        uint32_t slotIndex  = shaderBlob.boundUAVBuffers[uavIndex];
        uint32_t spaceIndex = shaderBlob.boundUAVBufferSpaces[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVBufferCounts[uavIndex];

                                
        if (spaceIndex == uint32_t(staticBufferUavSpace))
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavBufferCount++;

            outPipeline->uavBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy_s(outPipeline->uavBufferBindings[bindingIndex].name, std::size(outPipeline->uavBufferBindings[bindingIndex].name), shaderBlob.boundUAVBufferNames[uavIndex], _TRUNCATE);
        }
    }

    outPipeline->uavBufferCount = flattenedUavBufferCount;
    FFX_ASSERT(outPipeline->uavBufferCount < FFX_MAX_NUM_UAVS);

    for (uint32_t cbIndex = 0; cbIndex < shaderBlob.cbvCount; ++cbIndex)
    {
        outPipeline->constantBufferBindings[cbIndex].slotIndex  = shaderBlob.boundConstantBuffers[cbIndex];
        outPipeline->constantBufferBindings[cbIndex].arrayIndex = 1;
        strncpy_s(outPipeline->constantBufferBindings[cbIndex].name, std::size(outPipeline->constantBufferBindings[cbIndex].name), shaderBlob.boundConstantBufferNames[cbIndex], _TRUNCATE);
    }

    outPipeline->constCount = shaderBlob.cbvCount;
    FFX_ASSERT(outPipeline->constCount < FFX_MAX_NUM_CONST_BUFFERS);

    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    outPipeline->staticTextureSrvCount = staticTextureSrvCount;
    FFX_ASSERT(outPipeline->staticTextureSrvCount <= effectContext.bindlessTextureSrvHeapSize);

    outPipeline->staticBufferSrvCount = staticBufferSrvCount;
    FFX_ASSERT(outPipeline->staticBufferSrvCount <= effectContext.bindlessBufferSrvHeapSize);

    outPipeline->staticTextureUavCount = staticTextureUavCount;
    FFX_ASSERT(outPipeline->staticTextureUavCount <= effectContext.bindlessTextureUavHeapSize);

    outPipeline->staticBufferUavCount = staticBufferUavCount;
    FFX_ASSERT(outPipeline->staticBufferUavCount <= effectContext.bindlessBufferUavHeapSize);

                       
                                                               
                                                                     
        
                     
    D3D12_COMPUTE_PIPELINE_STATE_DESC dx12PipelineStateDescription = {};
    dx12PipelineStateDescription.Flags = D3D12_PIPELINE_STATE_FLAG_NONE;
    dx12PipelineStateDescription.pRootSignature = dx12RootSignature;
    dx12PipelineStateDescription.CS.pShaderBytecode = shaderBlob.data;
    dx12PipelineStateDescription.CS.BytecodeLength = shaderBlob.size;

    if (FAILED(dx12Device->CreateComputePipelineState(&dx12PipelineStateDescription, IID_PPV_ARGS(reinterpret_cast<ID3D12PipelineState**>(&outPipeline->pipeline)))))
        return FFX_ERROR_BACKEND_API_ERROR;

                            
    if (pipelineDescription->name) { wchar_t wideName[128]; MultiByteToWideChar(CP_UTF8, 0, pipelineDescription->name, -1, wideName, 128); reinterpret_cast<ID3D12PipelineState*>(outPipeline->pipeline)->SetName(wideName); }
    strncpy_s(outPipeline->name, pipelineDescription->name ? pipelineDescription->name : "", _TRUNCATE);

    return FFX_OK;
}

                                                                                                                        
                                                                                                                        
                                                                                                                  
struct NfruPipelineDX12
{
    enum Kind : uint32_t { Network = 1, OpticalFlow = 2 } kind;
    NfruEngineDX12*       engine   = nullptr;             
    ID3D12RootSignature*  rootSig  = nullptr;                                                                        
    ID3D12PipelineState*  pso      = nullptr;
};
static constexpr uint32_t kNfruOfSrvCount = 8, kNfruOfUavCount = 7;

static int nfruOfSettingDX12(const char* name, int fallback)
{
    char value[32]{};
    const DWORD count = GetEnvironmentVariableA(name, value, sizeof(value));
    return count && count < sizeof(value) ? atoi(value) : fallback;
}
static float nfruOfSettingDX12f(const char* name, float fallback)
{
    char value[32]{};
    const DWORD count = GetEnvironmentVariableA(name, value, sizeof(value));
    return count && count < sizeof(value) ? (float) atof(value) : fallback;
}

FfxErrorCode CreateDataGraphPipelineDX12(FfxInterface* backendInterface, FfxEffect effect, FfxPass passId, uint32_t permutationOptions,
                                         const FfxPipelineDescription* desc, FfxUInt32, FfxUInt32 dataGraphWidth,
                                         FfxUInt32 dataGraphHeight, FfxPipelineState* outPipeline)
{
    FFX_ASSERT(backendInterface && desc && outPipeline);
    BackendContext_DX12* backendContext = (BackendContext_DX12*) backendInterface->scratchBuffer;
    if (passId != FFX_FRAMEINTERPOLATION_PASS_NFRU_INTERPOLATION)
        return FFX_ERROR_BACKEND_API_ERROR;                                                            

    FfxDataGraphBlob dataGraphBlob = {};
    FFX_VALIDATE(backendInterface->fpGetPermutationBlobByIndex(effect, passId, permutationOptions, nullptr, nullptr, &dataGraphBlob));

    outPipeline->rootSignature = nullptr;
    outPipeline->cmdSignature  = nullptr;
    outPipeline->pipeline      = nullptr;
    outPipeline->uavTensorCount = dataGraphBlob.outputTensorNums;
    FFX_ASSERT(outPipeline->uavTensorCount < FFX_MAX_NUM_TENSORS);
    for (uint32_t i = 0; i < dataGraphBlob.outputTensorNums; ++i)
    {
        outPipeline->uavTensorBindings[i].slotIndex  = dataGraphBlob.outputTensorBindings[i];
        outPipeline->uavTensorBindings[i].arrayIndex = 0;
        strncpy_s(outPipeline->uavTensorBindings[i].name, dataGraphBlob.outputTensorNames[i], FFX_RESOURCE_NAME_SIZE - 1);
    }
    outPipeline->srvTensorCount = dataGraphBlob.inputTensorNums;
    FFX_ASSERT(outPipeline->srvTensorCount < FFX_MAX_NUM_TENSORS);
    for (uint32_t i = 0; i < dataGraphBlob.inputTensorNums; ++i)
    {
        outPipeline->srvTensorBindings[i].slotIndex  = dataGraphBlob.inputTensorBindings[i];
        outPipeline->srvTensorBindings[i].arrayIndex = 0;
        strncpy_s(outPipeline->srvTensorBindings[i].name, dataGraphBlob.inputTensorNames[i], FFX_RESOURCE_NAME_SIZE - 1);
    }

    NfruEngineDX12* engine = new NfruEngineDX12();
    if (!engine->init(backendContext->device, dataGraphWidth, dataGraphHeight))
    {
        engine->destroy();
        delete engine;
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    NfruPipelineDX12* state = new NfruPipelineDX12();
    state->kind             = NfruPipelineDX12::Network;
    state->engine           = engine;
    outPipeline->session    = reinterpret_cast<FfxDataGraphPipelineSession>(state);
    strncpy_s(outPipeline->name, desc->name ? desc->name : "nfru_network", FFX_RESOURCE_NAME_SIZE - 1);
    return FFX_OK;
}

                                                                                                                     
                                                                                                                         
                                                                     
FfxErrorCode CreateOpticalFlowPipelineDX12(FfxInterface* backendInterface, const char* name, const FfxOpticalFlowDescription& ofDesc,
                                           FfxUInt32, FfxPipelineState* outPipeline)
{
    FFX_ASSERT(backendInterface && outPipeline);
    BackendContext_DX12* backendContext = (BackendContext_DX12*) backendInterface->scratchBuffer;
    ID3D12Device*        dx12Device     = backendContext->device;

    D3D12_DESCRIPTOR_RANGE ranges[2] = {};
    ranges[0].RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
    ranges[0].NumDescriptors                    = kNfruOfSrvCount;
    ranges[0].OffsetInDescriptorsFromTableStart = 0;
    ranges[1].RangeType                         = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
    ranges[1].NumDescriptors                    = kNfruOfUavCount;
    ranges[1].OffsetInDescriptorsFromTableStart = kNfruOfSrvCount;
    D3D12_ROOT_PARAMETER params[2] = {};
    params[0].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    params[0].DescriptorTable  = {2, ranges};
    params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    params[1].ParameterType    = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    params[1].Constants        = {0, 1, 28};
    params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    D3D12_ROOT_SIGNATURE_DESC rs = {2, params, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_NONE};
    ID3DBlob* sig = nullptr, *err = nullptr;
    if (FAILED(D3D12SerializeRootSignature(&rs, D3D_ROOT_SIGNATURE_VERSION_1, &sig, &err)))
    {
        if (err) err->Release();
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    NfruPipelineDX12* state = new NfruPipelineDX12();
    state->kind             = NfruPipelineDX12::OpticalFlow;
    HRESULT hr = dx12Device->CreateRootSignature(0, sig->GetBufferPointer(), sig->GetBufferSize(), IID_PPV_ARGS(&state->rootSig));
    sig->Release();
    if (SUCCEEDED(hr))
    {
        D3D12_COMPUTE_PIPELINE_STATE_DESC pd = {};
        pd.pRootSignature                    = state->rootSig;
                                                                                                                         
        const bool adaptive = nfruOfSettingDX12("NFRU_OF_ADAPTIVE", 0) != 0, exitCamera = nfruOfSettingDX12("NFRU_OF_EXIT_CAMERA", 0) != 0;
        static const D3D12_SHADER_BYTECODE variants[4] = {
            {g_dxil_nfru_of_a0e0, g_dxil_nfru_of_a0e0_size}, {g_dxil_nfru_of_a0e1, g_dxil_nfru_of_a0e1_size},
            {g_dxil_nfru_of_a1e0, g_dxil_nfru_of_a1e0_size}, {g_dxil_nfru_of_a1e1, g_dxil_nfru_of_a1e1_size}};
        pd.CS = variants[(adaptive ? 2 : 0) + (exitCamera ? 1 : 0)];
        hr = dx12Device->CreateComputePipelineState(&pd, IID_PPV_ARGS(&state->pso));
    }
    if (FAILED(hr))
    {
        if (state->rootSig) state->rootSig->Release();
        delete state;
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    outPipeline->rootSignature = nullptr;
    outPipeline->cmdSignature  = nullptr;
    outPipeline->pipeline      = nullptr;
    outPipeline->session       = reinterpret_cast<FfxDataGraphPipelineSession>(state);

    uint32_t srvCount = 0, uavCount = 0;
    for (uint32_t i = 0; i < ofDesc.srvTextureCount; ++i)
    {
        FFX_ASSERT(ofDesc.boundSRVTextureCounts[i] == 1 && ofDesc.boundSRVTextures[i] < kNfruOfSrvCount);
        FfxResourceBinding& b = outPipeline->srvTextureBindings[srvCount++];
        b.slotIndex  = ofDesc.boundSRVTextures[i];
        b.arrayIndex = 0;
        b.bindSet    = 0;
        strncpy_s(b.name, ofDesc.boundSRVTextureNames[i], FFX_RESOURCE_NAME_SIZE - 1);
    }
    for (uint32_t i = 0; i < ofDesc.uavTextureCount; ++i)
    {
        FFX_ASSERT(ofDesc.boundUAVTextureCounts[i] == 1 && ofDesc.boundUAVTextures[i] < kNfruOfUavCount);
        FfxResourceBinding& b = outPipeline->uavTextureBindings[uavCount++];
        b.slotIndex  = ofDesc.boundUAVTextures[i];
        b.arrayIndex = 0;
        b.bindSet    = 0;
        strncpy_s(b.name, ofDesc.boundUAVTextureNames[i], FFX_RESOURCE_NAME_SIZE - 1);
    }
    outPipeline->srvTextureCount = srvCount;
    outPipeline->uavTextureCount = uavCount;
    outPipeline->srvTensorCount  = 0;
    outPipeline->uavTensorCount  = 0;
    strncpy_s(outPipeline->name, name ? name : "nfru_optical_flow", FFX_RESOURCE_NAME_SIZE - 1);
    return FFX_OK;
}

FfxErrorCode DestroyPipelineDX12(
    FfxInterface* backendInterface,
    FfxPipelineState* pipeline,
    FfxUInt32)
{
    FFX_ASSERT(backendInterface != nullptr);
    if (!pipeline) {
        return FFX_OK;
    }

    if (NfruPipelineDX12* nfru = reinterpret_cast<NfruPipelineDX12*>(pipeline->session))
    {
        if (nfru->engine) { nfru->engine->destroy(); delete nfru->engine; }
        nfruDeferRelease(nfru->pso);
        nfruDeferRelease(nfru->rootSig);
        delete nfru;
        pipeline->session = nullptr;
    }

                            
    ID3D12RootSignature* dx12RootSignature = reinterpret_cast<ID3D12RootSignature*>(pipeline->rootSignature);
    if (dx12RootSignature) {
        nfruDeferRelease(dx12RootSignature);
    }
    pipeline->rootSignature = nullptr;

                           
    ID3D12CommandSignature* dx12CmdSignature = reinterpret_cast<ID3D12CommandSignature*>(pipeline->cmdSignature);
    if (dx12CmdSignature) {
        nfruDeferRelease(dx12CmdSignature);
    }
    pipeline->cmdSignature = nullptr;

                       
    ID3D12PipelineState* dx12Pipeline = reinterpret_cast<ID3D12PipelineState*>(pipeline->pipeline);
    if (dx12Pipeline) {
        nfruDeferRelease(dx12Pipeline);
    }
    pipeline->pipeline = nullptr;

    return FFX_OK;
}

FfxErrorCode ScheduleGpuJobDX12(
    FfxInterface* backendInterface,
    const FfxGpuJobDescription* job
)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != job);

    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    FFX_ASSERT(backendContext->gpuJobCount < FFX_MAX_GPU_JOBS);

    backendContext->pGpuJobs[backendContext->gpuJobCount] = *job;
    backendContext->gpuJobCount++;

    return FFX_OK;
}

static FfxErrorCode executeGpuJobCompute(BackendContext_DX12*       backendContext,
                                         FfxGpuJobDescription*      job,
                                         ID3D12GraphicsCommandList* dx12CommandList,
                                         FfxUInt32                  effectContextId)
{
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendContext->device);
 
                                      
    ID3D12DescriptorHeap* dx12DescriptorHeap = reinterpret_cast<ID3D12DescriptorHeap*>(backendContext->descRingBuffer);

                         
    ID3D12RootSignature* dx12RootSignature = reinterpret_cast<ID3D12RootSignature*>(job->computeJobDescriptor.pipeline.rootSignature);
    dx12CommandList->SetComputeRootSignature(dx12RootSignature);

                          
    dx12CommandList->SetDescriptorHeaps(1, &dx12DescriptorHeap);

    uint32_t descriptorTableIndex = 0;

                                                                                                                                
    {
                                       
        uint32_t maximumUavIndex = job->computeJobDescriptor.pipeline.uavTextureCount + job->computeJobDescriptor.pipeline.uavBufferCount;

        for (uint32_t uavTextureBinding = 0; uavTextureBinding < job->computeJobDescriptor.pipeline.uavTextureCount; uavTextureBinding++)
        {
            uint32_t slotIndex = job->computeJobDescriptor.pipeline.uavTextureBindings[uavTextureBinding].slotIndex +
                                 job->computeJobDescriptor.pipeline.uavTextureBindings[uavTextureBinding].arrayIndex;

            if (slotIndex > maximumUavIndex)
                maximumUavIndex = slotIndex;
        }

        for (uint32_t uavBufferBinding = 0; uavBufferBinding < job->computeJobDescriptor.pipeline.uavBufferCount; uavBufferBinding++)
        {
            uint32_t slotIndex = job->computeJobDescriptor.pipeline.uavBufferBindings[uavBufferBinding].slotIndex +
                                 job->computeJobDescriptor.pipeline.uavTextureBindings[uavBufferBinding].arrayIndex;

            if (slotIndex > maximumUavIndex)
                maximumUavIndex = slotIndex;
        }

        if (maximumUavIndex)
        {
                                                                          
            if (backendContext->descRingBufferBase + maximumUavIndex + 1 > FFX_RING_BUFFER_DESCRIPTOR_COUNT * backendContext->maxEffectContexts)
                backendContext->descRingBufferBase = 0;

            D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
            gpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                               
            for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->computeJobDescriptor.pipeline.uavTextureCount; ++currentPipelineUavIndex) {

                addBarrier(backendContext, &job->computeJobDescriptor.uavTextures[currentPipelineUavIndex].resource, FFX_RESOURCE_STATE_COMPUTE_UAV);

                const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.uavTextureBindings[currentPipelineUavIndex];

                                                  
                const uint32_t resourceIndex = job->computeJobDescriptor.uavTextures[currentPipelineUavIndex].resource.internalIndex;
                const uint32_t uavIndex = backendContext->pResources[resourceIndex].uavDescIndex + job->computeJobDescriptor.uavTextures[currentPipelineUavIndex].mip;

                                   
                const uint32_t currentUavResourceIndex = binding.slotIndex + binding.arrayIndex;

                D3D12_CPU_DESCRIPTOR_HANDLE srcHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                srcHandle.ptr += uavIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                D3D12_CPU_DESCRIPTOR_HANDLE cpuView = dx12DescriptorHeap->GetCPUDescriptorHandleForHeapStart();
                cpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                cpuView.ptr += currentUavResourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                                  
                dx12Device->CopyDescriptorsSimple(1, cpuView, srcHandle, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
            }

                              
            for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->computeJobDescriptor.pipeline.uavBufferCount; ++currentPipelineUavIndex) {
                
                                                       
                if (job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].resource.internalIndex == 0)
                    continue;

                addBarrier(backendContext, &job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].resource, FFX_RESOURCE_STATE_COMPUTE_UAV);

                const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.uavBufferBindings[currentPipelineUavIndex];

                                   
                const uint32_t currentUavResourceIndex = binding.slotIndex + binding.arrayIndex;

                D3D12_CPU_DESCRIPTOR_HANDLE cpuView = dx12DescriptorHeap->GetCPUDescriptorHandleForHeapStart();
                cpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                cpuView.ptr += currentUavResourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                if (job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].size > 0)
                {
                                                                                               
                    ID3D12Resource* buffer = getDX12ResourcePtr(backendContext, job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].resource.internalIndex);
                    FFX_ASSERT(buffer != NULL);

                    D3D12_UNORDERED_ACCESS_VIEW_DESC dx12UavDescription = {};

                    bool     isStructured = job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].stride > 0;
                    uint32_t stride       = isStructured ? job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].stride : sizeof(uint32_t);

                    dx12UavDescription.Format                      = isStructured ? DXGI_FORMAT_UNKNOWN : DXGI_FORMAT_R32_TYPELESS;
                    dx12UavDescription.ViewDimension               = D3D12_UAV_DIMENSION_BUFFER;
                    dx12UavDescription.Buffer.FirstElement         = job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].offset / stride;
                    dx12UavDescription.Buffer.NumElements          = job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].size / stride;
                    dx12UavDescription.Buffer.StructureByteStride  = isStructured ? stride : 0;
                    dx12UavDescription.Buffer.CounterOffsetInBytes = 0;
                    dx12UavDescription.Buffer.Flags                = isStructured ? D3D12_BUFFER_UAV_FLAG_NONE : D3D12_BUFFER_UAV_FLAG_RAW;

                    dx12Device->CreateUnorderedAccessView(buffer, 0, &dx12UavDescription, cpuView);
                }
                else
                {
                                                                                                     
                    const uint32_t resourceIndex = job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].resource.internalIndex;
          
                    const uint32_t uavIndex  = backendContext->pResources[resourceIndex].uavDescIndex;

                    D3D12_CPU_DESCRIPTOR_HANDLE srcHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
                    srcHandle.ptr += uavIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                                      
                    dx12Device->CopyDescriptorsSimple(1, cpuView, srcHandle, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                }
            }

            backendContext->descRingBufferBase += maximumUavIndex + 1;
            dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
        }
    }

                                 
    {
                                       
        uint32_t maximumSrvIndex = job->computeJobDescriptor.pipeline.srvTextureCount + job->computeJobDescriptor.pipeline.srvBufferCount;

        for (uint32_t srvTextureBinding = 0; srvTextureBinding < job->computeJobDescriptor.pipeline.srvTextureCount; srvTextureBinding++)
        {
            uint32_t slotIndex = job->computeJobDescriptor.pipeline.srvTextureBindings[srvTextureBinding].slotIndex +
                                 job->computeJobDescriptor.pipeline.srvTextureBindings[srvTextureBinding].arrayIndex;

            if (slotIndex > maximumSrvIndex)
                maximumSrvIndex = slotIndex;
        }

        for (uint32_t srvBufferBinding = 0; srvBufferBinding < job->computeJobDescriptor.pipeline.srvBufferCount; srvBufferBinding++)
        {
            uint32_t slotIndex = job->computeJobDescriptor.pipeline.srvBufferBindings[srvBufferBinding].slotIndex +
                                 job->computeJobDescriptor.pipeline.srvTextureBindings[srvBufferBinding].arrayIndex;

            if (slotIndex > maximumSrvIndex)
                maximumSrvIndex = slotIndex;
        }

        if (maximumSrvIndex)
        {
                                                                          
            if (backendContext->descRingBufferBase + maximumSrvIndex + 1 > FFX_RING_BUFFER_DESCRIPTOR_COUNT * backendContext->maxEffectContexts)
            {
                backendContext->descRingBufferBase = 0;
            }

            D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
            gpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

            for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->computeJobDescriptor.pipeline.srvTextureCount; ++currentPipelineSrvIndex)
            {
                if (job->computeJobDescriptor.srvTextures[currentPipelineSrvIndex].resource.internalIndex == 0)
                    break;

                addBarrier(backendContext, &job->computeJobDescriptor.srvTextures[currentPipelineSrvIndex].resource, FFX_RESOURCE_STATE_COMPUTE_READ);

                const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.srvTextureBindings[currentPipelineSrvIndex];

                                                  
                const uint32_t              resourceIndex = job->computeJobDescriptor.srvTextures[currentPipelineSrvIndex].resource.internalIndex;
                D3D12_CPU_DESCRIPTOR_HANDLE srcHandle     = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
                srcHandle.ptr += resourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                                   
                uint32_t currentSrvResourceIndex = binding.slotIndex + binding.arrayIndex;

                D3D12_CPU_DESCRIPTOR_HANDLE cpuView = dx12DescriptorHeap->GetCPUDescriptorHandleForHeapStart();
                cpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                cpuView.ptr += currentSrvResourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                dx12Device->CopyDescriptorsSimple(1, cpuView, srcHandle, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
            }

                              
            for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->computeJobDescriptor.pipeline.srvBufferCount; ++currentPipelineSrvIndex)
            {
                                                       
                if (job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource.internalIndex == 0)
                    continue;

                addBarrier(backendContext, &job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource, FFX_RESOURCE_STATE_COMPUTE_READ);

                const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.srvBufferBindings[currentPipelineSrvIndex];

                                   
                const uint32_t currentSrvResourceIndex = binding.slotIndex + binding.arrayIndex;

                D3D12_CPU_DESCRIPTOR_HANDLE cpuView = dx12DescriptorHeap->GetCPUDescriptorHandleForHeapStart();
                cpuView.ptr += backendContext->descRingBufferBase * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                cpuView.ptr += currentSrvResourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                if (job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].size > 0)
                {
                                                                                               
                    ID3D12Resource* buffer = getDX12ResourcePtr(backendContext, job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource.internalIndex);
                    FFX_ASSERT(buffer != NULL);

                    D3D12_SHADER_RESOURCE_VIEW_DESC dx12SrvDescription = {};

                    bool     isStructured = job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].stride > 0;
                    uint32_t stride       = isStructured ? job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].stride : sizeof(uint32_t);

                    dx12SrvDescription.Format                     = isStructured ? DXGI_FORMAT_UNKNOWN : DXGI_FORMAT_R32_TYPELESS;
                    dx12SrvDescription.ViewDimension              = D3D12_SRV_DIMENSION_BUFFER;
                    dx12SrvDescription.Buffer.FirstElement        = job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].offset / stride;
                    dx12SrvDescription.Buffer.NumElements         = job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].size / stride;
                    dx12SrvDescription.Buffer.StructureByteStride = isStructured ? stride : 0;
                    dx12SrvDescription.Buffer.Flags               = isStructured ? D3D12_BUFFER_SRV_FLAG_NONE : D3D12_BUFFER_SRV_FLAG_RAW;
                    dx12SrvDescription.Shader4ComponentMapping    = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;

                    dx12Device->CreateShaderResourceView(buffer, &dx12SrvDescription, cpuView);
                }
                else
                {
                                                    
                    const uint32_t resourceIndex = job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource.internalIndex;

                    D3D12_CPU_DESCRIPTOR_HANDLE srcHandle = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
                    srcHandle.ptr += resourceIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

                                      
                    dx12Device->CopyDescriptorsSimple(1, cpuView, srcHandle, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
                }
            }

            backendContext->descRingBufferBase += maximumSrvIndex + 1;
            dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
        }
    }

    BackendContext_DX12::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

                                    
    if (job->computeJobDescriptor.pipeline.staticTextureSrvCount > 0)
    {
        D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
        gpuView.ptr += effectContext.bindlessTextureSrvHeapStart * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

        dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
    }

                                   
    if (job->computeJobDescriptor.pipeline.staticBufferSrvCount > 0)
    {
        D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
        gpuView.ptr += effectContext.bindlessBufferSrvHeapStart * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

        dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
    }

                                    
    if (job->computeJobDescriptor.pipeline.staticTextureUavCount > 0)
    {
        D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
        gpuView.ptr += effectContext.bindlessTextureUavHeapStart * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

        dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
    }

                                   
    if (job->computeJobDescriptor.pipeline.staticBufferUavCount > 0)
    {
        D3D12_GPU_DESCRIPTOR_HANDLE gpuView = dx12DescriptorHeap->GetGPUDescriptorHandleForHeapStart();
        gpuView.ptr += effectContext.bindlessBufferUavHeapStart * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

        dx12CommandList->SetComputeRootDescriptorTable(descriptorTableIndex++, gpuView);
    }

                                                                                              
    if (job->computeJobDescriptor.pipeline.cmdSignature)
    {
        addBarrier(backendContext, &job->computeJobDescriptor.cmdArgument, FFX_RESOURCE_STATE_INDIRECT_ARGUMENT);
    }

    flushBarriers(backendContext, dx12CommandList);

                    
    ID3D12PipelineState* dx12PipelineStateObject = reinterpret_cast<ID3D12PipelineState*>(job->computeJobDescriptor.pipeline.pipeline);
    dx12CommandList->SetPipelineState(dx12PipelineStateObject);

                                            
    {
        for (uint32_t currentRootConstantIndex = 0; currentRootConstantIndex < job->computeJobDescriptor.pipeline.constCount; ++currentRootConstantIndex) {

                                                                                                            
            FfxConstantAllocation allocation;
            if (s_fpConstantAllocator)
            {
                allocation = s_fpConstantAllocator(job->computeJobDescriptor.cbs[currentRootConstantIndex].data, job->computeJobDescriptor.cbs[currentRootConstantIndex].num32BitEntries * sizeof(uint32_t));
            }
            else
            {
                allocation = backendContext->FallbackConstantAllocator(job->computeJobDescriptor.cbs[currentRootConstantIndex].data, job->computeJobDescriptor.cbs[currentRootConstantIndex].num32BitEntries * sizeof(uint32_t));
            }

            D3D12_GPU_VIRTUAL_ADDRESS bufferViewDesc = D3D12_GPU_VIRTUAL_ADDRESS(allocation.handle);
            dx12CommandList->SetComputeRootConstantBufferView(descriptorTableIndex + currentRootConstantIndex, bufferViewDesc);
        }
    }

                                      
    if (job->computeJobDescriptor.pipeline.cmdSignature)
    {
        const uint32_t resourceIndex = job->computeJobDescriptor.cmdArgument.internalIndex;
        ID3D12Resource* pResource = backendContext->pResources[resourceIndex].resourcePtr;

        dx12CommandList->ExecuteIndirect(reinterpret_cast<ID3D12CommandSignature*>(job->computeJobDescriptor.pipeline.cmdSignature), 1, pResource, job->computeJobDescriptor.cmdArgumentOffset, nullptr, 0);
    }
    else
    {
        dx12CommandList->Dispatch(job->computeJobDescriptor.dimensions[0], job->computeJobDescriptor.dimensions[1], job->computeJobDescriptor.dimensions[2]);
    }

    return FFX_OK;
}

static FfxErrorCode executeGpuJobCopy(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* dx12CommandList)
{
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendContext->device);

    ID3D12Resource* dx12ResourceSrc = getDX12ResourcePtr(backendContext, job->copyJobDescriptor.src.internalIndex);
    ID3D12Resource* dx12ResourceDst = getDX12ResourcePtr(backendContext, job->copyJobDescriptor.dst.internalIndex);
    D3D12_RESOURCE_DESC dx12ResourceDescriptionDst = dx12ResourceDst->GetDesc();
    D3D12_RESOURCE_DESC dx12ResourceDescriptionSrc = dx12ResourceSrc->GetDesc();

    addBarrier(backendContext, &job->copyJobDescriptor.src, FFX_RESOURCE_STATE_COPY_SRC);
    addBarrier(backendContext, &job->copyJobDescriptor.dst, FFX_RESOURCE_STATE_COPY_DEST);
    flushBarriers(backendContext, dx12CommandList);

    D3D12_PLACED_SUBRESOURCE_FOOTPRINT dx12Footprint = {};
    UINT rowCount;
    UINT64 rowSizeInBytes;
    UINT64 totalBytes;
    dx12Device->GetCopyableFootprints(&dx12ResourceDescriptionDst, 0, 1, 0, &dx12Footprint, &rowCount, &rowSizeInBytes, &totalBytes);

    if (dx12ResourceDescriptionDst.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER)
    {
        dx12CommandList->CopyBufferRegion(dx12ResourceDst,
                                          job->copyJobDescriptor.dstOffset,
                                          dx12ResourceSrc,
                                          job->copyJobDescriptor.srcOffset,
                                          job->copyJobDescriptor.size > 0 ? job->copyJobDescriptor.size : totalBytes);
    }
    else if (dx12ResourceDescriptionSrc.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER)
    {
                                                 
        D3D12_TEXTURE_COPY_LOCATION dx12SourceLocation = {};
        dx12SourceLocation.pResource = dx12ResourceSrc;
        dx12SourceLocation.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
        dx12SourceLocation.PlacedFootprint = dx12Footprint;

        D3D12_TEXTURE_COPY_LOCATION dx12DestinationLocation = {};
        dx12DestinationLocation.pResource = dx12ResourceDst;
        dx12DestinationLocation.SubresourceIndex = 0;
        dx12DestinationLocation.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;

        dx12CommandList->CopyTextureRegion(&dx12DestinationLocation, 0, 0, 0, &dx12SourceLocation, nullptr);
    }
    else
    {
        D3D12_TEXTURE_COPY_LOCATION dx12SourceLocation = {};
        dx12SourceLocation.pResource = dx12ResourceSrc;
        dx12SourceLocation.SubresourceIndex = 0;
        dx12SourceLocation.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;

        D3D12_TEXTURE_COPY_LOCATION dx12DestinationLocation = {};
        dx12DestinationLocation.pResource = dx12ResourceDst;
        dx12DestinationLocation.SubresourceIndex = 0;
        dx12DestinationLocation.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;

        dx12CommandList->CopyTextureRegion(&dx12DestinationLocation, 0, 0, 0, &dx12SourceLocation, nullptr);
    }

    return FFX_OK;
}

static FfxErrorCode executeGpuJobBarrier(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* dx12CommandList)
{
    addBarrier(backendContext, &job->barrierDescriptor.resource, job->barrierDescriptor.newState);
    flushBarriers(backendContext, dx12CommandList);

    return FFX_OK;
}

static FfxErrorCode executeGpuJobTimestamp(BackendContext_DX12*, FfxGpuJobDescription*, ID3D12GraphicsCommandList*)
{
    return FFX_OK;
}

static FfxErrorCode executeGpuJobClearFloat(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* dx12CommandList)
{
    ID3D12Device* dx12Device = reinterpret_cast<ID3D12Device*>(backendContext->device);

    uint32_t idx = job->clearJobDescriptor.target.internalIndex;
    BackendContext_DX12::Resource ffxResource = backendContext->pResources[idx];
    ID3D12Resource* dx12Resource = reinterpret_cast<ID3D12Resource*>(ffxResource.resourcePtr);
    uint32_t uavIndex = ffxResource.uavDescIndex;

    D3D12_CPU_DESCRIPTOR_HANDLE dx12CpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
    dx12CpuHandle.ptr += uavIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    D3D12_GPU_DESCRIPTOR_HANDLE dx12GpuHandle = backendContext->descHeapUavGpu->GetGPUDescriptorHandleForHeapStart();
    dx12GpuHandle.ptr += uavIndex * dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    dx12CommandList->SetDescriptorHeaps(1, &backendContext->descHeapUavGpu);

    addBarrier(backendContext, &job->clearJobDescriptor.target, FFX_RESOURCE_STATE_COMPUTE_UAV);
    flushBarriers(backendContext, dx12CommandList);

    uint32_t clearColorAsUint[4];
    clearColorAsUint[0] = reinterpret_cast<uint32_t&> (job->clearJobDescriptor.color[0]);
    clearColorAsUint[1] = reinterpret_cast<uint32_t&> (job->clearJobDescriptor.color[1]);
    clearColorAsUint[2] = reinterpret_cast<uint32_t&> (job->clearJobDescriptor.color[2]);
    clearColorAsUint[3] = reinterpret_cast<uint32_t&> (job->clearJobDescriptor.color[3]);
    dx12CommandList->ClearUnorderedAccessViewUint(dx12GpuHandle, dx12CpuHandle, dx12Resource, clearColorAsUint, 0, nullptr);

    return FFX_OK;
}

static FfxErrorCode executeGpuJobDiscard(BackendContext_DX12*       backendContext,
                                         FfxGpuJobDescription*      job,
                                         ID3D12GraphicsCommandList* dx12CommandList)
{
    uint32_t                            idx           = job->discardJobDescriptor.target.internalIndex;
    BackendContext_DX12::Resource       ffxResource   = backendContext->pResources[idx];
    ID3D12Resource*                     dx12Resource  = reinterpret_cast<ID3D12Resource*>(ffxResource.resourcePtr);

    addBarrier(backendContext, &job->discardJobDescriptor.target, FFX_RESOURCE_STATE_COMPUTE_UAV);
    flushBarriers(backendContext, dx12CommandList);

    dx12CommandList->DiscardResource(dx12Resource, nullptr);

    return FFX_OK;
}

static void transitionDX12(ID3D12GraphicsCommandList* cl, ID3D12Resource* r, D3D12_RESOURCE_STATES& state, D3D12_RESOURCE_STATES next)
{
    if (state == next) return;
    D3D12_RESOURCE_BARRIER b  = {};
    b.Type                    = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    b.Transition.pResource    = r;
    b.Transition.Subresource  = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    b.Transition.StateBefore  = state;
    b.Transition.StateAfter   = next;
    cl->ResourceBarrier(1, &b);
    state = next;
}

                                                                                                                
static uint32_t reserveRingDescriptors(BackendContext_DX12* backendContext, uint32_t count)
{
    if (backendContext->descRingBufferBase + count > FFX_RING_BUFFER_DESCRIPTOR_COUNT * backendContext->maxEffectContexts)
        backendContext->descRingBufferBase = 0;
    const uint32_t base = backendContext->descRingBufferBase;
    backendContext->descRingBufferBase += count;
    return base;
}

static FfxErrorCode executeNfruOpticalFlowDX12(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* cl,
                                               NfruPipelineDX12* state)
{
    ID3D12Device*           dev      = backendContext->device;
    const UINT              inc      = dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    FfxDataGraphJobDescription& dg   = job->dataGraphJobDescription;
    const FfxPipelineState& pipeline = dg.pipeline;
    ID3D12DescriptorHeap*   ring     = backendContext->descRingBuffer;

    const uint32_t base = reserveRingDescriptors(backendContext, kNfruOfSrvCount + kNfruOfUavCount);
    auto cpuSlot = [&](uint32_t s) { D3D12_CPU_DESCRIPTOR_HANDLE h = ring->GetCPUDescriptorHandleForHeapStart(); h.ptr += SIZE_T(base + s) * inc; return h; };

                                                                     
    for (uint32_t s = 0; s < kNfruOfSrvCount; ++s)
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC d = {};
        d.Format                  = DXGI_FORMAT_R32G32B32A32_FLOAT;
        d.ViewDimension           = D3D12_SRV_DIMENSION_TEXTURE2D;
        d.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        d.Texture2D.MipLevels     = 1;
        dev->CreateShaderResourceView(nullptr, &d, cpuSlot(s));
    }
    for (uint32_t s = 0; s < kNfruOfUavCount; ++s)
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC d = {};
        if (s == 6)                                                                                              
        {
            d.Format             = DXGI_FORMAT_R32_TYPELESS;
            d.ViewDimension      = D3D12_UAV_DIMENSION_BUFFER;
            d.Buffer.NumElements = 1;
            d.Buffer.Flags       = D3D12_BUFFER_UAV_FLAG_RAW;
        }
        else
        {
            d.Format        = DXGI_FORMAT_R16G16_FLOAT;
            d.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
        }
        dev->CreateUnorderedAccessView(nullptr, nullptr, &d, cpuSlot(kNfruOfSrvCount + s));
    }

    auto bindSrv = [&](FfxResourceInternal& res, uint32_t slotIndex) {
        addBarrier(backendContext, &res, FFX_RESOURCE_STATE_COMPUTE_READ);
        D3D12_CPU_DESCRIPTOR_HANDLE src = backendContext->descHeapSrvCpu->GetCPUDescriptorHandleForHeapStart();
        src.ptr += SIZE_T(res.internalIndex) * inc;
        dev->CopyDescriptorsSimple(1, cpuSlot(slotIndex), src, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    };

    uint32_t flowW = 0, flowH = 0;
    for (uint32_t i = 0; i < pipeline.uavTextureCount; ++i)
    {
        FfxTextureUAV& uav = dg.uavTextures[i];
        if (uav.resource.internalIndex == 0)
            continue;
        addBarrier(backendContext, &uav.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);
        const BackendContext_DX12::Resource& r = backendContext->pResources[uav.resource.internalIndex];
        flowW = r.resourceDescription.width;
        flowH = r.resourceDescription.height;
        D3D12_CPU_DESCRIPTOR_HANDLE src = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
        src.ptr += SIZE_T(r.uavDescIndex + uav.mip) * inc;
        dev->CopyDescriptorsSimple(1, cpuSlot(kNfruOfSrvCount + pipeline.uavTextureBindings[i].slotIndex), src, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    }
    for (uint32_t i = 0; i < pipeline.srvTextureCount; ++i)
    {
        FfxTextureSRV& srv = dg.srvTextures[i];
        if (srv.resource.internalIndex == 0)
            continue;
        bindSrv(srv.resource, pipeline.srvTextureBindings[i].slotIndex);
    }

                                                                                        
    FfxResourceInternal mvResource = dg.gameMotionVectors;
    const bool useGameMv = mvResource.internalIndex != 0;
    if (!useGameMv) mvResource = dg.srvTextures[2].resource;
    if (mvResource.internalIndex) bindSrv(mvResource, 4);

    FfxResourceInternal depthResource = dg.gameDepth;
    const bool useDepth = useGameMv && depthResource.internalIndex != 0 && nfruOfSettingDX12("NFRU_OF_DEPTH_AWARE_MV", 1) != 0;
    if (depthResource.internalIndex == 0) depthResource = dg.srvTextures[2].resource;
    if (depthResource.internalIndex) bindSrv(depthResource, 5);

    FfxResourceInternal previousDepthResource = dg.gamePreviousDepth;
    bool useTemporalDepth = useDepth && previousDepthResource.internalIndex != 0 && nfruOfSettingDX12("NFRU_OF_TEMPORAL_DEPTH", 1) != 0;
    for (float value : dg.gamePreviousToCurrentClip)
        if (!std::isfinite(value)) useTemporalDepth = false;
    if (previousDepthResource.internalIndex == 0) previousDepthResource = depthResource;
    if (previousDepthResource.internalIndex) bindSrv(previousDepthResource, 7);

    struct OfPC { int32_t mode, radius; float seedSx, seedSy, flowSx, flowSy, constX, constY; float mvUvX, mvUvY; int32_t useGameMv, pad; float previousToCurrentClip[16]; };
    static_assert(sizeof(OfPC) == 28 * 4, "nfru_of push constants");
    OfPC pc = {nfruOfSettingDX12("NFRU_OF_MODE", 1), nfruOfSettingDX12("NFRU_OF_RADIUS", 2),
               nfruOfSettingDX12f("NFRU_OF_SEED_SX", 1.0f), nfruOfSettingDX12f("NFRU_OF_SEED_SY", 1.0f),
               nfruOfSettingDX12f("NFRU_OF_FLOW_SX", 1.0f), nfruOfSettingDX12f("NFRU_OF_FLOW_SY", 1.0f),
               nfruOfSettingDX12f("NFRU_OF_CONST_X", 0.0f), nfruOfSettingDX12f("NFRU_OF_CONST_Y", 0.0f),
               dg.gameMotionVectorUvScale.x, dg.gameMotionVectorUvScale.y, useGameMv ? 1 : 0, useDepth ? 1 : 0};
    memcpy(pc.previousToCurrentClip, dg.gamePreviousToCurrentClip, sizeof(pc.previousToCurrentClip));
    if (useTemporalDepth) pc.pad |= 2;

    flushBarriers(backendContext, cl);
    cl->SetDescriptorHeaps(1, &ring);
    cl->SetComputeRootSignature(state->rootSig);
    D3D12_GPU_DESCRIPTOR_HANDLE table = ring->GetGPUDescriptorHandleForHeapStart();
    table.ptr += UINT64(base) * inc;
    cl->SetComputeRootDescriptorTable(0, table);
    cl->SetComputeRoot32BitConstants(1, 28, &pc, 0);
    cl->SetPipelineState(state->pso);
    cl->Dispatch((flowW + 7) / 8, (flowH + 7) / 8, 1);
    return FFX_OK;
}

static FfxErrorCode executeNfruNetworkDX12(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* cl,
                                           NfruPipelineDX12* state)
{
    FfxDataGraphJobDescription& dg = job->dataGraphJobDescription;
    if (dg.pipeline.srvTensorCount == 0 || dg.pipeline.uavTensorCount == 0)
        return FFX_ERROR_INVALID_ARGUMENT;
    FfxResourceInternal& inRes  = dg.srvTensors[0].resource;
    FfxResourceInternal& outRes = dg.uavTensors[0].resource;
    BackendContext_DX12::Resource& in  = backendContext->pResources[inRes.internalIndex];
    BackendContext_DX12::Resource& out = backendContext->pResources[outRes.internalIndex];
    if (!in.resourcePtr || !out.resourcePtr)
        return FFX_ERROR_INVALID_ARGUMENT;

                                                                                                   
    addBarrier(backendContext, &inRes, FFX_RESOURCE_STATE_COMPUTE_UAV);
    addBarrier(backendContext, &outRes, FFX_RESOURCE_STATE_COMPUTE_UAV);
    flushBarriers(backendContext, cl);

    NfruEngineDX12* engine = state->engine;
    if (!engine->bindIO(in.resourcePtr, out.resourcePtr, in.resourcePtr->GetDesc().Width, out.resourcePtr->GetDesc().Width))
        return FFX_ERROR_INVALID_ARGUMENT;
    engine->record(cl);

    if (out.tensorImage)
    {
        transitionDX12(cl, out.tensorImage, out.tensorImageState, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        engine->recordToImage(cl, out.tensorImage);
        transitionDX12(cl, out.tensorImage, out.tensorImageState, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
    }
    return FFX_OK;
}

static FfxErrorCode executeGpuJobDataGraph(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* cl)
{
    NfruPipelineDX12* state = reinterpret_cast<NfruPipelineDX12*>(job->dataGraphJobDescription.pipeline.session);
    if (!state)
        return FFX_ERROR_INVALID_ARGUMENT;
    return state->kind == NfruPipelineDX12::OpticalFlow ? executeNfruOpticalFlowDX12(backendContext, job, cl, state)
                                                        : executeNfruNetworkDX12(backendContext, job, cl, state);
}

static FfxErrorCode executeGpuJobClearUint(BackendContext_DX12* backendContext, FfxGpuJobDescription* job, ID3D12GraphicsCommandList* dx12CommandList)
{
    ID3D12Device*                        dx12Device  = backendContext->device;
    const UINT                           inc         = dx12Device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    const BackendContext_DX12::Resource& ffxResource = backendContext->pResources[job->clearUintJobDescriptor.target.internalIndex];

    D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = backendContext->descHeapUavCpu->GetCPUDescriptorHandleForHeapStart();
    D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle = backendContext->descHeapUavGpu->GetGPUDescriptorHandleForHeapStart();
    cpuHandle.ptr += SIZE_T(ffxResource.uavDescIndex) * inc;
    gpuHandle.ptr += UINT64(ffxResource.uavDescIndex) * inc;

    dx12CommandList->SetDescriptorHeaps(1, &backendContext->descHeapUavGpu);
    addBarrier(backendContext, &job->clearUintJobDescriptor.target, FFX_RESOURCE_STATE_COMPUTE_UAV);
    flushBarriers(backendContext, dx12CommandList);

    const UINT value[4] = {job->clearUintJobDescriptor.color[0], job->clearUintJobDescriptor.color[1], job->clearUintJobDescriptor.color[2],
                           job->clearUintJobDescriptor.color[3]};
    dx12CommandList->ClearUnorderedAccessViewUint(gpuHandle, cpuHandle, ffxResource.resourcePtr, value, 0, nullptr);
    return FFX_OK;
}

FfxErrorCode ExecuteGpuJobsDX12(
    FfxInterface* backendInterface,
    FfxCommandList commandList, 
    FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_DX12* backendContext = (BackendContext_DX12*)backendInterface->scratchBuffer;

    FFX_ASSERT(nullptr != commandList);
    ID3D12GraphicsCommandList* dx12CommandList = reinterpret_cast<ID3D12GraphicsCommandList*>(commandList);
    nfruPurgeDeferred(true);

    FfxErrorCode errorCode = FFX_OK;

                          
    for (uint32_t currentGpuJobIndex = 0; currentGpuJobIndex < backendContext->gpuJobCount; ++currentGpuJobIndex) {

        FfxGpuJobDescription* GpuJob = &backendContext->pGpuJobs[currentGpuJobIndex];        

                                                               

        switch (GpuJob->jobType) {

            case FFX_GPU_JOB_CLEAR_FLOAT:
                errorCode = executeGpuJobClearFloat(backendContext, GpuJob, dx12CommandList);
                break;

            case FFX_GPU_JOB_COPY:
                errorCode = executeGpuJobCopy(backendContext, GpuJob, dx12CommandList);
                break;

            case FFX_GPU_JOB_COMPUTE:
                errorCode = executeGpuJobCompute(backendContext, GpuJob, dx12CommandList, effectContextId);
                break;

            case FFX_GPU_JOB_BARRIER:
                errorCode = executeGpuJobBarrier(backendContext, GpuJob, dx12CommandList);
                break;

            case FFX_GPU_JOB_DISCARD:
                errorCode = executeGpuJobDiscard(backendContext, GpuJob, dx12CommandList);
                break;

            case FFX_GPU_JOB_DATA_GRAPH:
                errorCode = executeGpuJobDataGraph(backendContext, GpuJob, dx12CommandList);
                break;

            case FFX_GPU_JOB_CLEAR_UINT:
                errorCode = executeGpuJobClearUint(backendContext, GpuJob, dx12CommandList);
                break;

            default:
                break;
        }

    }

                                                   
    FFX_RETURN_ON_ERROR(
        errorCode == FFX_OK,
        FFX_ERROR_BACKEND_API_ERROR);

    backendContext->gpuJobCount = 0;

    return FFX_OK;
}

                                                                              

void RegisterConstantBufferAllocatorDX12(FfxInterface*, FfxConstantBufferAllocator fpConstantAllocator)
{
    s_fpConstantAllocator = fpConstantAllocator;
}

FfxCommandQueue ffxGetCommandQueueDX12(ID3D12CommandQueue* pCommandQueue)
{
    FFX_ASSERT(nullptr != pCommandQueue);
    return reinterpret_cast<FfxCommandQueue>(pCommandQueue);
}

FfxSwapchain ffxGetSwapchainDX12(IDXGISwapChain4* pSwapchain)
{
    FFX_ASSERT(nullptr != pSwapchain);
    return reinterpret_cast<FfxSwapchain>(pSwapchain);
}

IDXGISwapChain4* ffxGetDX12SwapchainPtr(FfxSwapchain ffxSwapchain)
{
    return reinterpret_cast<IDXGISwapChain4*>(ffxSwapchain);
}
