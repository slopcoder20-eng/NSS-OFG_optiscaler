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
// SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#include "FidelityFX/host/backends/vk/ffx_hash.h"
#include <FidelityFX/host/backends/vk/ffx_vk.h>
#include "nss_engine/nss_env.h"
#include <FidelityFX/host/backends/vk/vk_wrapper.h>
#include <FidelityFX/host/ffx_assert.h>
#include <FidelityFX/host/ffx_interface.h>
#include <FidelityFX/host/ffx_util.h>
#include <ffx_shader_blobs.h>

#ifdef _WIN32
#if !defined(__UNREAL__)                                                       
#include <windows.h>

#include <FidelityFX/host/ffx_nss.h>

                                                                            
                                                                        
                                                                       
                                                                            
                                                                        
                                                                            
#include "nss_engine/nss_vk_engine.h"
#include "nss_engine/nfru_engine.h"
#include "../../../../mlof2_engine/mlof2_runtime.h"
#include "nss_engine/mv_residual_engine.h"
#include "nss_engine/nfru_select_engine.h"
#include "nss_engine/nfru_select_i8_engine.h"
                                                           
static bool nfruSelectFp32(){static const bool v=getenv("NFRU_SELECT")&&atoi(getenv("NFRU_SELECT"))==2;return v;}
#include "nss_engine/nfru_gpu_stats.h"
#include "nfru_isa_capture.h"
#include "nss_engine/vkml_of/embedded_optical_flow.h"
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include "../../components/frameinterpolation/ffx_frameinterpolation_private.h"

                                                                                           
                                                                                      
static inline bool loadNssEngine()
{
    static const bool bypass = (getenv("NSS_BYPASS_ENGINE") != nullptr);
    return !bypass;
}

#endif                   
#else
#include <codecvt>                                                        
#endif
#include <vector>
#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <vector>
                            
#include "spirv-tools/libspirv.hpp"
#include "spirv/unified1/spirv.hpp11"

                         
                                                                                                              
                                                                       
                                                                              
                                                                              
                         
#ifdef None
#undef None
#define X11None 0L
#ifdef RevertToNone
#undef RevertToNone
#define RevertToNone (int)X11None
#endif
#endif

#ifdef Success
#undef Success
#endif

namespace
{
                   
    using TensorBinding = std::pair<uint32_t, uint32_t>;                    

    using DescriptorSetBindingToShapeMap = std::map<TensorBinding, std::vector<int64_t>>;

                       
    struct ShapeInferenceResults
    {
        bool                           Success;
        DescriptorSetBindingToShapeMap Shapes;
        std::vector<uint32_t>          NewCode;
    };

                                                                                      
    struct SessionMemoryObjectRequirement
    {
        VkDataGraphPipelineSessionBindPointARM bindPoint;
        uint32_t                               objectIndex;
        VkMemoryRequirements                   memoryRequirements;
        VkDeviceSize                           offset;
    };

                                          
    template <typename T, void (*DeleterFunc)(T*)>
    struct CustomDeleter
    {
        void operator()(T* ptr) const
        {
            if (ptr)
            {
                DeleterFunc(ptr);
            }
        }
    };

    template <typename T, void (*DeleterFunc)(T*)>
    using UniqueSpirvPtr = std::unique_ptr<T, CustomDeleter<T, DeleterFunc>>;

                      
    uint32_t GetSingleWordOperand(const spv_parsed_instruction_t& instr, int operandIdx)
    {
                                                            
        return instr.words[instr.operands[operandIdx].offset];
    }

    DescriptorSetBindingToShapeMap GetInputShapes(const FfxDataGraphBlob& dataGraphBlob, const uint32_t width, const uint32_t height)
    {
        DescriptorSetBindingToShapeMap inputShapes{};
        for (FfxUInt32 i = 0; i < dataGraphBlob.inputTensorNums; ++i)
        {
            const auto           dimSize = dataGraphBlob.inputTensorDimSize[i];
            std::vector<int64_t> currentTensorDimension{};
            currentTensorDimension.push_back(1);                           
            bool is_width = false;
            for (FfxUInt32 j = 1; j < dimSize; ++j)
            {
                                                                     
                auto curSize = dataGraphBlob.inputTensorDims[i][j];

                if (curSize <= 0)
                {
                                                                
                    curSize  = is_width ? width : height;
                    is_width = true;
                }
                currentTensorDimension.push_back(curSize);
            }
            const std::pair<uint32_t, uint32_t> binding{0, dataGraphBlob.inputTensorBindings[i]};                   
            inputShapes.emplace(binding, std::move(currentTensorDimension));
        }
        return inputShapes;
    }

    ShapeInferenceResults RunShapeInference(const uint32_t* code, const uint32_t codeSize, const DescriptorSetBindingToShapeMap& inputShapes)
    {
        UniqueSpirvPtr<spv_optimizer_t, spvOptimizerDestroy> optimizer(spvOptimizerCreate(SPV_ENV_VULKAN_1_3));
        if (!optimizer)
            return {false};

        spvOptimizerSetMessageConsumer(optimizer.get(), [](spv_message_level_t, const char*, const spv_position_t*, const char* message) {});

        UniqueSpirvPtr<spv_optimizer_options_t, spvOptimizerOptionsDestroy> options(spvOptimizerOptionsCreate());
        if (!options)
        {
            return {false};
        }

        std::vector<spv_graph_shape_input> shapeInputs;
        for (const auto& [key, shape] : inputShapes)
        {
            shapeInputs.push_back({key.first, key.second, static_cast<uint32_t>(shape.size()), shape.data()});
        }

        spvOptimizerRegisterGraphShapePass(optimizer.get(), shapeInputs.size(), shapeInputs.data());

        spv_binary_t*                                  rawBinary = nullptr;
        spv_result_t                                   result    = spvOptimizerRun(optimizer.get(), code, codeSize, &rawBinary, options.get());
        UniqueSpirvPtr<spv_binary_t, spvBinaryDestroy> optimizedCode(rawBinary);
        if (result != SPV_SUCCESS)
        {
            return {false};
        }

        UniqueSpirvPtr<spv_context_t, spvContextDestroy> context(spvContextCreate(SPV_ENV_VULKAN_1_3));
        if (!context)
        {
            return {false};
        }

        struct ParsingResultsStruct
        {
            std::vector<spv_parsed_instruction_t>                    ParsedInstructions;
            std::vector<std::vector<spv_parsed_operand_t>>           ParsedOperands;
            std::map<uint32_t, uint32_t>                             IdToInstructionIdx;
            std::map<std::pair<uint32_t, spv::Decoration>, uint32_t> Decorations;
        } parsingResults;

        auto parsingCallback = [](void* userData, const spv_parsed_instruction_t* instr) -> spv_result_t {
            auto& results = *static_cast<ParsingResultsStruct*>(userData);
            results.ParsedInstructions.push_back(*instr);
            results.ParsedOperands.emplace_back(instr->operands, instr->operands + instr->num_operands);
            results.ParsedInstructions.back().operands = results.ParsedOperands.back().data();

            if (instr->result_id)
            {
                results.IdToInstructionIdx[instr->result_id] = static_cast<uint32_t>(results.ParsedInstructions.size()) - 1;
            }

            if (instr->opcode == static_cast<uint16_t>(spv::Op::OpDecorate) && instr->num_operands >= 3)
            {
                auto decoratedId = GetSingleWordOperand(*instr, 0);
                auto kind        = static_cast<spv::Decoration>(GetSingleWordOperand(*instr, 1));
                auto value       = GetSingleWordOperand(*instr, 2);
                if (kind == spv::Decoration::Binding || kind == spv::Decoration::DescriptorSet)
                {
                    results.Decorations[{decoratedId, kind}] = value;
                }
            }
            return SPV_SUCCESS;
        };

        spv_diagnostic_t* rawDiagnostic = nullptr;
        result = spvBinaryParse(context.get(), &parsingResults, optimizedCode->code, optimizedCode->wordCount, nullptr, parsingCallback, &rawDiagnostic);
        UniqueSpirvPtr<spv_diagnostic_t, spvDiagnosticDestroy> diagnostic(rawDiagnostic);
        if (result != SPV_SUCCESS)
        {
                                                                                       
            return {false};
        }

        ShapeInferenceResults inferenceResults;
        for (const auto& instr : parsingResults.ParsedInstructions)
        {
            if (instr.opcode != static_cast<uint32_t>(spv::Op::OpVariable))
            {
                continue;
            }

            uint32_t varId      = instr.result_id;
            auto     varDeclIdx = parsingResults.IdToInstructionIdx[varId];
            auto&    varDecl    = parsingResults.ParsedInstructions[varDeclIdx];

            auto ptrTypeDecl  = parsingResults.ParsedInstructions[parsingResults.IdToInstructionIdx[varDecl.type_id]];
            auto tensorTypeId = GetSingleWordOperand(ptrTypeDecl, 2);
            auto tensorDecl   = parsingResults.ParsedInstructions[parsingResults.IdToInstructionIdx[tensorTypeId]];
            if (tensorDecl.opcode != static_cast<uint32_t>(spv::Op::OpTypeTensorARM))
            {
                continue;
            }

            auto shapeId   = GetSingleWordOperand(tensorDecl, 3);
            auto shapeDecl = parsingResults.ParsedInstructions[parsingResults.IdToInstructionIdx[shapeId]];
            if (shapeDecl.opcode != static_cast<uint32_t>(spv::Op::OpConstantComposite))
            {
                continue;
            }

            std::vector<int64_t> shape;
            for (int i = 0; i < shapeDecl.num_operands - 2; ++i)
            {
                auto dimId   = GetSingleWordOperand(shapeDecl, i + 2);
                auto dimDecl = parsingResults.ParsedInstructions[parsingResults.IdToInstructionIdx[dimId]];
                if (dimDecl.opcode != static_cast<uint32_t>(spv::Op::OpConstant))
                {
                    continue;
                }

                shape.push_back(GetSingleWordOperand(dimDecl, 2));
            }

            auto set                                = parsingResults.Decorations[{varId, spv::Decoration::DescriptorSet}];
            auto binding                            = parsingResults.Decorations[{varId, spv::Decoration::Binding}];
            inferenceResults.Shapes[{set, binding}] = std::move(shape);
        }

        inferenceResults.NewCode.assign(optimizedCode->code, optimizedCode->code + optimizedCode->wordCount);
        inferenceResults.Success = true;
        return inferenceResults;
    }
}              

static void PrintMessage(FfxInterface* backendInterface, uint32_t type, const char* message)
{
    if (backendInterface && backendInterface->fpMessage && message != nullptr)
    {
        backendInterface->fpMessage(type, message);
    }
}

                                            
FfxErrorCode     SetupMessageCallback(FfxInterface* backendInterface, FfxBackendMessage ffxMessageCallback);
FfxVersionNumber GetSDKVersionVK(FfxInterface* backendInterface);
FfxErrorCode     GetEffectGpuMemoryUsageVK(FfxInterface* backendInterface, FfxUInt32 effectContextId, FfxEffectMemoryUsage* outVramUsage);
FfxErrorCode     CreateBackendContextVK(FfxInterface* backendInterface, FfxEffect effect, FfxEffectBindlessConfig* bindlessConfig, FfxUInt32* effectContextId);
FfxErrorCode     GetDeviceCapabilitiesVK(FfxInterface* backendInterface, FfxDeviceCapabilities* deviceCapabilities);
FfxErrorCode     DestroyBackendContextVK(FfxInterface* backendInterface, FfxUInt32 effectContextId);
FfxErrorCode     CreateResourceVK(FfxInterface*                       backendInterface,
                                  const FfxCreateResourceDescription* desc,
                                  FfxUInt32                           effectContextId,
                                  FfxResourceInternal*                outTexture);
FfxErrorCode     DestroyResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource, FfxUInt32 effectContextId);
FfxErrorCode     MapResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource, void** ptr);
FfxErrorCode     UnmapResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode     RegisterResourceVK(FfxInterface*        backendInterface,
                                    const FfxResource*   inResource,
                                    FfxUInt32            effectContextId,
                                    FfxResourceInternal* outResourceInternal);
FfxResource      GetResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode     UnregisterResourcesVK(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);
FfxErrorCode     RegisterStaticResourceVK(FfxInterface* backendInterface, const FfxStaticResourceDescription* desc, FfxUInt32 effectContextId);
FfxResourceDescription GetResourceDescriptionVK(FfxInterface* backendInterface, FfxResourceInternal resource);
FfxErrorCode           StageConstantBufferDataVK(FfxInterface* backendInterface, void* data, FfxUInt32 size, FfxConstantBuffer* constantBuffer);
FfxErrorCode           CreateComputePipelineVK(FfxInterface*                 backendInterface,
                                               FfxEffect                     effect,
                                               FfxPass                       passId,
                                               uint32_t                      permutationOptions,
                                               const FfxPipelineDescription* desc,
                                               FfxUInt32                     effectContextId,
                                               FfxPipelineState*             outPass);
FfxErrorCode           CreateGraphicsPipelineVK(FfxInterface*                 backendInterface,
                                                FfxEffect                     effect,
                                                FfxPass                       passId,
                                                uint32_t                      permutationOptions,
                                                const FfxPipelineDescription* desc,
                                                FfxUInt32                     effectContextId,
                                                FfxPipelineState*             outPass);
FfxErrorCode           CreateDataGraphPipelineVK(FfxInterface*                 backendInterface,
                                                 FfxEffect                     effect,
                                                 FfxPass                       passId,
                                                 uint32_t                      permutationOptions,
                                                 const FfxPipelineDescription* desc,
                                                 FfxUInt32                     effectContextId,
                                                 FfxUInt32                     dataGraphWidth,
                                                 FfxUInt32                     dataGraphHeight,
                                                 FfxPipelineState*             outPass);
FfxErrorCode           CreateOpticalFlowPipelineVK(
              FfxInterface* backendInterface, const char* name, const FfxOpticalFlowDescription& ofDesc, FfxUInt32 effectContextId, FfxPipelineState* outPipeline);

FfxErrorCode DestroyPipelineVK(FfxInterface* backendInterface, FfxPipelineState* pipeline, FfxUInt32 effectContextId);
FfxErrorCode ScheduleGpuJobVK(FfxInterface* backendInterface, const FfxGpuJobDescription* job);
FfxErrorCode ExecuteGpuJobsVK(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId);

static VkDeviceContext sVkDeviceContext = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_NULL_HANDLE};

#define MAX_PIPELINE_USAGE_PER_FRAME (10)                                                                                                                    

#define MAX_DESCRIPTOR_SET_LAYOUTS  (32)
#define MAX_DESCRIPTOR_SETS         (2)
#define MAX_RENDER_PASS_COUNT       (FFX_MAX_QUEUED_FRAMES)
#define MAX_IMAGE_VIEW_COUNT        (FFX_MAX_QUEUED_FRAMES * 4)
#define MAX_FRAME_BUFFER_COUNT      (FFX_MAX_QUEUED_FRAMES)
#define MAX_GRAPHICS_PIPELINE_COUNT (FFX_MAX_QUEUED_FRAMES)

#define FFX_MAX_BINDLESS_DESCRIPTOR_COUNT (65536)

                                      
static FfxConstantBufferAllocator s_fpConstantAllocator = nullptr;

                                                     
constexpr uint32_t SAMPLER_BINDING_SHIFT = 1000;

typedef struct ObjectBase_VK
{
    uint64_t  hash;
    FfxUInt32 visitedFlag;
} ObjectBase_VK;

typedef struct GraphicPipeline_VK : ObjectBase_VK
{
    VkPipeline handle;
} GraphicPipeline_VK;

typedef struct FrameBuffer_VK : ObjectBase_VK
{
    VkFramebuffer handle;
} FrameBuffer_VK;

typedef struct ImageView_VK : ObjectBase_VK
{
    VkImageView handle;
} ImageView_VK;

typedef struct RenderPass_VK : ObjectBase_VK
{
    VkRenderPass handle;
} RenderPass_VK;

typedef struct BackendContext_VK
{
                                            
    typedef struct Resource
    {
#ifdef _DEBUG
        char resourceName[64] = {};
#endif
        union
        {
            struct
            {
                VkImage  imageResource;
                VkBuffer aliasedBufferResource;
            };
            VkBuffer bufferResource;
            struct
            {
                VkTensorARM tensorResource;
                VkImage     aliasedTensorImageResource;                               
                VkBuffer    aliasedTensorBufferResource;                               
            };
        };

        FfxResourceDescription resourceDescription;
        FfxResourceStates      initialState;
        FfxResourceStates      currentState;
        int32_t                srvViewIndex;
        int32_t                uavViewIndex;
        uint32_t               uavViewCount;
        int32_t                tensorViewIndex;

        VkDeviceMemory        deviceMemory;
        VkDeviceSize          allocationSize;
        VkMemoryPropertyFlags memoryProperties;

        bool undefined;
        bool dynamic;
                                                                                  
                                                                              
                                                                      
        bool bridgeTensor;

    } Resource;

    typedef struct PipelineLayout
    {
        VkSampler             samplers[FFX_MAX_SAMPLERS];
        VkDescriptorSetLayout descriptorSetLayout;
        VkDescriptorSet       descriptorSets[FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME];
        uint32_t              descriptorSetIndex;
        VkPipelineLayout      pipelineLayout;
        int32_t               staticTextureSrvSet;
        int32_t               staticBufferSrvSet;
        int32_t               staticTextureUavSet;
        int32_t               staticBufferUavSet;

                                         
        VkShaderModule fragShaderModule;
        VkShaderModule vertShaderModule;

        RenderPass_VK renderPass[MAX_RENDER_PASS_COUNT];
        FfxUInt32     renderPassIndex;

        ImageView_VK imageView[MAX_IMAGE_VIEW_COUNT];
        FfxUInt32    imageViewIndex;

        FrameBuffer_VK frameBuffer[MAX_FRAME_BUFFER_COUNT];
        FfxUInt32      frameBufferIndex;

        GraphicPipeline_VK graphicsPipeline[MAX_GRAPHICS_PIPELINE_COUNT];
        FfxUInt32          graphicsPipelineIndex;

                                                                            
        VkDeviceMemory dataGraphSessionMemory;
        VkDeviceSize   dataGraphSessionMemorySize;
        void*          nssEngineHandle;
        void*          mvResidualEngine;                                        
        void*          selectEngine;                                                                                      
        bool           mvResidualInverted;
        void*          nfruEngine;                                                                
        void*          mlof2Runtime = nullptr;                 
        VkPipeline     ofComputePipeline;                                  
        void*          ofGpuStats = nullptr;
        void*          embeddedOpticalFlow;                                                               

        char      name[64];
        FfxUInt32 effectContextId;
    } PipelineLayout;

    uint32_t refCount;
    uint32_t maxEffectContexts;

    FfxGpuVendorId   gpuVendorId    = FfxGpuVendorId::NotQueried;
    VkInstance       instance       = VK_NULL_HANDLE;
    VkDevice         device         = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    PFN_vkGetInstanceProcAddr getInstanceProcAddr = nullptr;
    PFN_vkGetDeviceProcAddr   getDeviceProcAddr   = nullptr;

    FfxGpuJobDescription* pGpuJobs;
    uint32_t              gpuJobCount = 0;

    typedef struct VkResourceView
    {
        VkImageView     imageView;
        VkTensorViewARM tensorView;
    } VkResourceView;
    VkResourceView* pResourceViews;

    uint8_t* pStagingRingBuffer;
    uint32_t stagingRingBufferBase = 0;

    PipelineLayout* pPipelineLayouts;

    VkDescriptorPool descriptorPool;
    uint32_t         bindlessBase;

    VkImageMemoryBarrier2    imageMemoryBarriers[FFX_MAX_BARRIERS]  = {};
    VkBufferMemoryBarrier2   bufferMemoryBarriers[FFX_MAX_BARRIERS] = {};
    VkTensorMemoryBarrierARM tensorMemoryBarriers[FFX_MAX_BARRIERS] = {};
    uint32_t                 scheduledImageBarrierCount             = 0;
    uint32_t                 scheduledBufferBarrierCount            = 0;
    uint32_t                 scheduledTensorBarrierCount            = 0;

    typedef struct alignas(32) EffectContext
    {
                                                                                  
        FfxEffect effectId;
        void* fiGpuStats;
        VkDescriptorImageInfo mvResidualMotion;                                                            

                              
        uint32_t nextStaticResource;
        uint32_t nextDynamicResource;

                      
        uint32_t nextStaticResourceView;
        uint32_t nextDynamicResourceView[FFX_MAX_QUEUED_FRAMES];

                               
        uint32_t              bindlessTextureSrvHeapStart;
        uint32_t              bindlessTextureSrvHeapSize;
        uint32_t              bindlessBufferSrvHeapSize;
        uint32_t              bindlessTextureUavHeapStart;
        uint32_t              bindlessTextureUavHeapSize;
        uint32_t              bindlessBufferUavHeapSize;
        VkDescriptorPool      bindlessDescriptorPool;
        VkDescriptorSetLayout bindlessTextureSrvDescriptorSetLayout;
        VkDescriptorSetLayout bindlessBufferSrvDescriptorSetLayout;
        VkDescriptorSetLayout bindlessTextureUavDescriptorSetLayout;
        VkDescriptorSetLayout bindlessBufferUavDescriptorSetLayout;
        VkDescriptorSet       bindlessTextureSrvDescriptorSet;
        VkDescriptorSet       bindlessBufferSrvDescriptorSet;
        VkDescriptorSet       bindlessTextureUavDescriptorSet;
        VkDescriptorSet       bindlessBufferUavDescriptorSet;

                          
        uint32_t nextPipelineLayout;

                                          
        uint32_t frameIndex;

                
        bool active;

                     
        FfxEffectMemoryUsage vramUsage;

    } EffectContext;

    Resource*      pResources;
    EffectContext* pEffectContexts;

                          
    FfxConstantAllocation FallbackConstantAllocator(void* data, FfxUInt64 dataSize);
    VkDeviceMemory        uniformBufferMemory = VK_NULL_HANDLE;
    VkMemoryPropertyFlags uniformBufferMemoryProperties;
    VkDeviceSize          uniformBufferAlignment = 0;
    void*                 uniformBufferMem       = nullptr;
    VkBuffer              uniformBuffer          = VK_NULL_HANDLE;
    VkDeviceSize          uniformBufferSize      = 0;
    VkDeviceSize          uniformBufferOffset    = 0;
    std::mutex            uniformBufferMutex;

    uint32_t               numDeviceExtensions = 0;
    VkExtensionProperties* extensionProperties = nullptr;

} BackendContext_VK;

FFX_API size_t ffxGetScratchMemorySizeVK(VkDeviceContext& deviceContext, size_t maxContexts)
{
    uint32_t numExtensions = 0;

    if (deviceContext.vkInstance)
    {
        VulkanWrapper().vkEnumerateDeviceExtensionProperties(deviceContext.vkPhysicalDevice, nullptr, &numExtensions, nullptr);
    }

    uint32_t extensionPropArraySize = sizeof(VkExtensionProperties) * numExtensions;
    uint32_t gpuJobDescArraySize    = FFX_ALIGN_UP(maxContexts * FFX_MAX_GPU_JOBS * sizeof(FfxGpuJobDescription), sizeof(uint32_t));
    uint32_t resourceViewArraySize  = FFX_ALIGN_UP(
        ((maxContexts * FFX_MAX_QUEUED_FRAMES * FFX_MAX_RESOURCE_COUNT * 2) + FFX_MAX_BINDLESS_DESCRIPTOR_COUNT) * sizeof(BackendContext_VK::VkResourceView),
        sizeof(uint32_t));
    uint32_t stagingRingBufferArraySize = FFX_ALIGN_UP(maxContexts * FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE, sizeof(uint32_t));
    uint32_t pipelineArraySize          = FFX_ALIGN_UP(maxContexts * FFX_MAX_PASS_COUNT * sizeof(BackendContext_VK::PipelineLayout), sizeof(uint32_t));
    uint32_t resourceArraySize          = FFX_ALIGN_UP(maxContexts * FFX_MAX_RESOURCE_COUNT * sizeof(BackendContext_VK::Resource), sizeof(uint32_t));
    uint32_t contextArraySize           = FFX_ALIGN_UP(maxContexts * sizeof(BackendContext_VK::EffectContext), sizeof(uint32_t));
                                                                                
    uint32_t effectContextAlignPadding = alignof(BackendContext_VK::EffectContext) - 1;

    return FFX_ALIGN_UP(sizeof(BackendContext_VK) + extensionPropArraySize + gpuJobDescArraySize + resourceViewArraySize + stagingRingBufferArraySize +
                            pipelineArraySize + resourceArraySize + effectContextAlignPadding + contextArraySize,
                        sizeof(uint64_t));
}

                                     
FfxDevice ffxGetDeviceVK(VkDeviceContext* vkDeviceContext)
{
    sVkDeviceContext = *vkDeviceContext;
    return reinterpret_cast<FfxDevice>(&sVkDeviceContext);
}

FfxErrorCode ffxGetInterfaceVK(FfxInterface* backendInterface, FfxDevice device, void* scratchBuffer, size_t scratchBufferSize, size_t maxContexts)
{
    FFX_RETURN_ON_ERROR(backendInterface, FFX_ERROR_INVALID_POINTER);
    FFX_RETURN_ON_ERROR(scratchBuffer, FFX_ERROR_INVALID_POINTER);
    FFX_RETURN_ON_ERROR(scratchBufferSize >= ffxGetScratchMemorySizeVK(*(VkDeviceContext*)device, maxContexts), FFX_ERROR_INSUFFICIENT_MEMORY);

                                                                                             
    backendInterface->fpMessage                     = nullptr;
    backendInterface->fpSetMessageCallback          = SetupMessageCallback;
    backendInterface->fpGetSDKVersion               = GetSDKVersionVK;
    backendInterface->fpGetEffectGpuMemoryUsage     = GetEffectGpuMemoryUsageVK;
    backendInterface->fpCreateBackendContext        = CreateBackendContextVK;
    backendInterface->fpGetDeviceCapabilities       = GetDeviceCapabilitiesVK;
    backendInterface->fpDestroyBackendContext       = DestroyBackendContextVK;
    backendInterface->fpCreateResource              = CreateResourceVK;
    backendInterface->fpDestroyResource             = DestroyResourceVK;
    backendInterface->fpMapResource                 = MapResourceVK;
    backendInterface->fpUnmapResource               = UnmapResourceVK;
    backendInterface->fpRegisterResource            = RegisterResourceVK;
    backendInterface->fpGetResource                 = GetResourceVK;
    backendInterface->fpUnregisterResources         = UnregisterResourcesVK;
    backendInterface->fpRegisterStaticResource      = RegisterStaticResourceVK;
    backendInterface->fpGetResourceDescription      = GetResourceDescriptionVK;
    backendInterface->fpStageConstantBufferDataFunc = StageConstantBufferDataVK;
    backendInterface->fpCreateComputePipeline       = CreateComputePipelineVK;

          
    backendInterface->fpCreateGraphicsPipeline    = CreateGraphicsPipelineVK;
    backendInterface->fpCreateDataGraphPipeline   = CreateDataGraphPipelineVK;
    backendInterface->fpCreateOpticalFlowPipeline = CreateOpticalFlowPipelineVK;
           
    backendInterface->fpDestroyPipeline           = DestroyPipelineVK;
    backendInterface->fpGetPermutationBlobByIndex = ffxGetPermutationBlobByIndex;
    backendInterface->fpScheduleGpuJob            = ScheduleGpuJobVK;
    backendInterface->fpExecuteGpuJobs            = ExecuteGpuJobsVK;
                                                                                                
    backendInterface->fpSwapChainConfigureFrameGeneration = ffxSetFrameGenerationConfigToSwapchainVK;

                         
    backendInterface->scratchBuffer     = scratchBuffer;
    backendInterface->scratchBufferSize = scratchBufferSize;

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    FFX_RETURN_ON_ERROR(!backendContext->refCount, FFX_ERROR_BACKEND_API_ERROR);

                           
    memset(backendContext, 0, sizeof(*backendContext));

                     
    backendInterface->device = device;

                                                       
    backendContext->maxEffectContexts = (uint32_t)maxContexts;

                                                    
    backendInterface->devCapInitialized = false;

    return FFX_OK;
}

FfxCommandList ffxGetCommandListVK(VkCommandBuffer cmdBuf)
{
    FFX_ASSERT(NULL != cmdBuf);
    return reinterpret_cast<FfxCommandList>(cmdBuf);
}

FfxPipeline ffxGetPipelineVK(VkPipeline pipeline)
{
    FFX_ASSERT(NULL != pipeline);
    return reinterpret_cast<FfxPipeline>(pipeline);
}

FfxResource ffxGetResourceVK(void*                  vkResource,
                             FfxResourceDescription ffxResDescription,
                             const char*            ffxResName,
                             FfxResourceStates      state                                     )
{
    FfxResource resource = {};
    resource.resource    = vkResource;
    resource.state       = state;
    resource.description = ffxResDescription;

#ifdef _DEBUG
    if (ffxResName)
    {
        strncpy(resource.name, ffxResName, FFX_RESOURCE_NAME_SIZE - 1);
        resource.name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }
#endif

    return resource;
}

uint32_t findMemoryTypeIndex(BackendContext_VK*     backendContext,
                             VkMemoryRequirements   memRequirements,
                             VkMemoryPropertyFlags  requestedProperties,
                             VkMemoryPropertyFlags& outProperties)
{
    FFX_ASSERT(NULL != backendContext);
    FFX_ASSERT(NULL != backendContext->physicalDevice);

    VkPhysicalDeviceMemoryProperties memProperties;
    VulkanWrapper().vkGetPhysicalDeviceMemoryProperties(backendContext->physicalDevice, &memProperties);

    uint32_t bestCandidate = UINT32_MAX;

                                                                                                                                
    if (requestedProperties == VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    {
        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++)
        {
            const auto propertyFlags    = memProperties.memoryTypes[i].propertyFlags;
            const bool onlyDeviceMemory = (propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) && !(propertyFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
            if ((memRequirements.memoryTypeBits & (1 << i)) && onlyDeviceMemory)
            {
                bestCandidate = i;
                outProperties = propertyFlags;
                break;
            }
        }
    }

                                                                                    
    if (UINT32_MAX == bestCandidate)
    {
        const bool requestHostVisible = requestedProperties & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++)
        {
            const auto propertyFlags = memProperties.memoryTypes[i].propertyFlags;
            if ((memRequirements.memoryTypeBits & (1 << i)) && (propertyFlags & requestedProperties))
            {
                bestCandidate = i;
                outProperties = propertyFlags;

                                                                                                        
                                                                                 
                if (!requestHostVisible || (propertyFlags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
                {
                    break;
                }
            }
        }
    }

    return bestCandidate;
}

VkBufferUsageFlags ffxGetVKBufferUsageFlagsFromResourceUsage(FfxResourceUsage flags)
{
    VkBufferUsageFlags indirectBit = 0;

    if (FFX_CONTAINS_FLAG(flags, FFX_RESOURCE_USAGE_INDIRECT))
        indirectBit = VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT;

    if (FFX_CONTAINS_FLAG(flags, FFX_RESOURCE_USAGE_UAV))
        return indirectBit | VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
    else
        return indirectBit | VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
}

VkImageType ffxGetVKImageTypeFromResourceType(FfxResourceType type)
{
    switch (type)
    {
    case (FFX_RESOURCE_TYPE_TEXTURE1D):
        return VK_IMAGE_TYPE_1D;
    case (FFX_RESOURCE_TYPE_TEXTURE2D):
        return VK_IMAGE_TYPE_2D;
    case (FFX_RESOURCE_TYPE_TEXTURE_CUBE):
    case (FFX_RESOURCE_TYPE_TEXTURE3D):
        return VK_IMAGE_TYPE_3D;
    default:
        return VK_IMAGE_TYPE_MAX_ENUM;
    }
}

bool ffxIsSurfaceFormatSRGB(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SRGB):
    case (FFX_SURFACE_FORMAT_B8G8R8A8_SRGB):
        return true;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS):
    case (FFX_SURFACE_FORMAT_R32G32B32A32_UINT):
    case (FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT):
    case (FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT):
    case (FFX_SURFACE_FORMAT_R32G32B32_FLOAT):
    case (FFX_SURFACE_FORMAT_R32G32_FLOAT):
    case (FFX_SURFACE_FORMAT_R8_UINT):
    case (FFX_SURFACE_FORMAT_R32_UINT):
    case (FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS):
    case (FFX_SURFACE_FORMAT_R8G8B8A8_UNORM):
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SNORM):
    case (FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS):
    case (FFX_SURFACE_FORMAT_B8G8R8A8_UNORM):
    case (FFX_SURFACE_FORMAT_R11G11B10_FLOAT):
    case (FFX_SURFACE_FORMAT_R10G10B10A2_UNORM):
    case (FFX_SURFACE_FORMAT_R16G16_FLOAT):
    case (FFX_SURFACE_FORMAT_R16G16_UINT):
    case (FFX_SURFACE_FORMAT_R16G16_SINT):
    case (FFX_SURFACE_FORMAT_R16_FLOAT):
    case (FFX_SURFACE_FORMAT_R16_UINT):
    case (FFX_SURFACE_FORMAT_R16_UNORM):
    case (FFX_SURFACE_FORMAT_R16_SNORM):
    case (FFX_SURFACE_FORMAT_R8_UNORM):
    case (FFX_SURFACE_FORMAT_R8_SNORM):
    case (FFX_SURFACE_FORMAT_R8_SINT):
    case (FFX_SURFACE_FORMAT_R8G8_UNORM):
    case (FFX_SURFACE_FORMAT_R8G8_UINT):
    case (FFX_SURFACE_FORMAT_R8G8_SINT):
    case (FFX_SURFACE_FORMAT_R32_FLOAT):
    case (FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP):
    case (FFX_SURFACE_FORMAT_UNKNOWN):
        return false;
    default:
        FFX_ASSERT_MESSAGE(false, "Format not yet supported");
        return false;
    }
}

FfxSurfaceFormat ffxGetSurfaceFormatFromGamma(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SRGB):
        return FFX_SURFACE_FORMAT_R8G8B8A8_UNORM;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_SRGB):
        return FFX_SURFACE_FORMAT_B8G8R8A8_UNORM;
    default:
        return fmt;
    }
}

FfxSurfaceFormat ffxGetSurfaceFormatToGamma(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_R8G8B8A8_UNORM):
        return FFX_SURFACE_FORMAT_R8G8B8A8_SRGB;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_UNORM):
        return FFX_SURFACE_FORMAT_B8G8R8A8_SRGB;
    default:
        return fmt;
    }
}

uint8_t ffxGetBytesPerElementFromSurfaceFormat(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_R16G16_FLOAT):
        return 4;
    case (FFX_SURFACE_FORMAT_R16_UINT):
        return 2;
    case (FFX_SURFACE_FORMAT_R8_UNORM):
        return 1;
                                                          
    default:
        return 1;
    }
}

VkFormat ffxGetVkFormatFromSurfaceFormat(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_UNKNOWN):
        return VK_FORMAT_UNDEFINED;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS):
        return VK_FORMAT_R32G32B32A32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_UINT):
        return VK_FORMAT_R32G32B32A32_UINT;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT):
        return VK_FORMAT_R32G32B32A32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT):
        return VK_FORMAT_R16G16B16A16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32B32_FLOAT):
        return VK_FORMAT_R32G32B32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32_FLOAT):
        return VK_FORMAT_R32G32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R8_UINT):
        return VK_FORMAT_R8_UINT;
    case (FFX_SURFACE_FORMAT_R8_SINT):
        return VK_FORMAT_R8_SINT;
    case (FFX_SURFACE_FORMAT_R32_UINT):
        return VK_FORMAT_R32_UINT;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS):
        return VK_FORMAT_R8G8B8A8_UNORM;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_UNORM):
        return VK_FORMAT_R8G8B8A8_UNORM;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SNORM):
        return VK_FORMAT_R8G8B8A8_SNORM;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SRGB):
        return VK_FORMAT_R8G8B8A8_SRGB;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS):
        return VK_FORMAT_B8G8R8A8_UNORM;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_UNORM):
        return VK_FORMAT_B8G8R8A8_UNORM;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_SRGB):
        return VK_FORMAT_B8G8R8A8_SRGB;
    case (FFX_SURFACE_FORMAT_R11G11B10_FLOAT):
        return VK_FORMAT_B10G11R11_UFLOAT_PACK32;
    case (FFX_SURFACE_FORMAT_R10G10B10A2_UNORM):
        return VK_FORMAT_A2B10G10R10_UNORM_PACK32;
    case (FFX_SURFACE_FORMAT_R16G16_FLOAT):
        return VK_FORMAT_R16G16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16G16_UINT):
        return VK_FORMAT_R16G16_UINT;
    case (FFX_SURFACE_FORMAT_R16G16_SINT):
        return VK_FORMAT_R16G16_SINT;
    case (FFX_SURFACE_FORMAT_R16_FLOAT):
        return VK_FORMAT_R16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16_UINT):
        return VK_FORMAT_R16_UINT;
    case (FFX_SURFACE_FORMAT_R16_UNORM):
        return VK_FORMAT_R16_UNORM;
    case (FFX_SURFACE_FORMAT_R16_SNORM):
        return VK_FORMAT_R16_SNORM;
    case (FFX_SURFACE_FORMAT_R8_UNORM):
        return VK_FORMAT_R8_UNORM;
    case (FFX_SURFACE_FORMAT_R8_SNORM):
        return VK_FORMAT_R8_SNORM;
    case (FFX_SURFACE_FORMAT_R8G8_UNORM):
        return VK_FORMAT_R8G8_UNORM;
    case (FFX_SURFACE_FORMAT_R8G8_UINT):
        return VK_FORMAT_R8G8_UINT;
    case (FFX_SURFACE_FORMAT_R8G8_SINT):
        return VK_FORMAT_R8G8_SINT;
    case (FFX_SURFACE_FORMAT_R32_FLOAT):
        return VK_FORMAT_R32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP):
        return VK_FORMAT_E5B9G9R9_UFLOAT_PACK32;

    default:
        FFX_ASSERT_MESSAGE(false, "Format not yet supported");
        return VK_FORMAT_UNDEFINED;
    }
}

VkFormat ffxGetVKUAVFormatFromSurfaceFormat(FfxSurfaceFormat fmt)
{
    switch (fmt)
    {
    case (FFX_SURFACE_FORMAT_UNKNOWN):
        return VK_FORMAT_UNDEFINED;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS):
        return VK_FORMAT_R32G32B32A32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_UINT):
        return VK_FORMAT_R32G32B32A32_UINT;
    case (FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT):
        return VK_FORMAT_R32G32B32A32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT):
        return VK_FORMAT_R16G16B16A16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32B32_FLOAT):
        return VK_FORMAT_R32G32B32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R32G32_FLOAT):
        return VK_FORMAT_R32G32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R8_UINT):
        return VK_FORMAT_R8_UINT;
    case (FFX_SURFACE_FORMAT_R8_SINT):
        return VK_FORMAT_R8_SINT;
    case (FFX_SURFACE_FORMAT_R32_UINT):
        return VK_FORMAT_R32_UINT;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS):
    case (FFX_SURFACE_FORMAT_R8G8B8A8_UNORM):
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SRGB):
        return VK_FORMAT_R8G8B8A8_UNORM;
    case (FFX_SURFACE_FORMAT_R8G8B8A8_SNORM):
        return VK_FORMAT_R8G8B8A8_SNORM;
    case (FFX_SURFACE_FORMAT_B8G8R8A8_TYPELESS):
    case (FFX_SURFACE_FORMAT_B8G8R8A8_UNORM):
    case (FFX_SURFACE_FORMAT_B8G8R8A8_SRGB):
        return VK_FORMAT_B8G8R8A8_UNORM;
    case (FFX_SURFACE_FORMAT_R11G11B10_FLOAT):
        return VK_FORMAT_B10G11R11_UFLOAT_PACK32;
    case (FFX_SURFACE_FORMAT_R10G10B10A2_UNORM):
        return VK_FORMAT_A2B10G10R10_UNORM_PACK32;
    case (FFX_SURFACE_FORMAT_R16G16_FLOAT):
        return VK_FORMAT_R16G16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16G16_UINT):
        return VK_FORMAT_R16G16_UINT;
    case (FFX_SURFACE_FORMAT_R16G16_SINT):
        return VK_FORMAT_R16G16_SINT;
    case (FFX_SURFACE_FORMAT_R16_FLOAT):
        return VK_FORMAT_R16_SFLOAT;
    case (FFX_SURFACE_FORMAT_R16_UINT):
        return VK_FORMAT_R16_UINT;
    case (FFX_SURFACE_FORMAT_R16_UNORM):
        return VK_FORMAT_R16_UNORM;
    case (FFX_SURFACE_FORMAT_R16_SNORM):
        return VK_FORMAT_R16_SNORM;
    case (FFX_SURFACE_FORMAT_R8_UNORM):
        return VK_FORMAT_R8_UNORM;
    case (FFX_SURFACE_FORMAT_R8_SNORM):
        return VK_FORMAT_R8_SNORM;
    case (FFX_SURFACE_FORMAT_R8G8_UNORM):
        return VK_FORMAT_R8G8_UNORM;
    case (FFX_SURFACE_FORMAT_R8G8_UINT):
        return VK_FORMAT_R8G8_UINT;
    case (FFX_SURFACE_FORMAT_R8G8_SINT):
        return VK_FORMAT_R8G8_SINT;
    case (FFX_SURFACE_FORMAT_R32_FLOAT):
        return VK_FORMAT_R32_SFLOAT;
    case (FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP):
        return VK_FORMAT_E5B9G9R9_UFLOAT_PACK32;

    default:
        FFX_ASSERT_MESSAGE(false, "Format not yet supported");
        return VK_FORMAT_UNDEFINED;
    }
}

FfxSurfaceFormat ffxGetSurfaceFormatVK(VkFormat fmt)
{
    switch (fmt)
    {
    case VK_FORMAT_R32G32B32A32_SFLOAT:
        return FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT;
    case VK_FORMAT_R32G32B32A32_UINT:
        return FFX_SURFACE_FORMAT_R32G32B32A32_UINT;
    case VK_FORMAT_R16G16B16A16_SFLOAT:
        return FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT;
    case VK_FORMAT_R32G32_SFLOAT:
        return FFX_SURFACE_FORMAT_R32G32_FLOAT;
    case VK_FORMAT_R32_UINT:
    case VK_FORMAT_D24_UNORM_S8_UINT:
    case VK_FORMAT_X8_D24_UNORM_PACK32:
        return FFX_SURFACE_FORMAT_R32_UINT;
    case VK_FORMAT_R8G8B8A8_UNORM:
        return FFX_SURFACE_FORMAT_R8G8B8A8_UNORM;
    case VK_FORMAT_R8G8B8A8_SNORM:
        return FFX_SURFACE_FORMAT_R8G8B8A8_SNORM;
    case VK_FORMAT_R8G8B8A8_SRGB:
        return FFX_SURFACE_FORMAT_R8G8B8A8_SRGB;
    case VK_FORMAT_B8G8R8A8_UNORM:
        return FFX_SURFACE_FORMAT_B8G8R8A8_UNORM;
    case VK_FORMAT_B8G8R8A8_SRGB:
        return FFX_SURFACE_FORMAT_B8G8R8A8_SRGB;
    case VK_FORMAT_B10G11R11_UFLOAT_PACK32:
        return FFX_SURFACE_FORMAT_R11G11B10_FLOAT;
    case VK_FORMAT_A2B10G10R10_UNORM_PACK32:
        return FFX_SURFACE_FORMAT_R10G10B10A2_UNORM;
    case VK_FORMAT_R16G16_SFLOAT:
        return FFX_SURFACE_FORMAT_R16G16_FLOAT;
    case VK_FORMAT_R16G16_UINT:
        return FFX_SURFACE_FORMAT_R16G16_UINT;
    case VK_FORMAT_R16G16_SINT:
        return FFX_SURFACE_FORMAT_R16G16_SINT;
    case VK_FORMAT_R16_SFLOAT:
        return FFX_SURFACE_FORMAT_R16_FLOAT;
    case VK_FORMAT_R16_UINT:
        return FFX_SURFACE_FORMAT_R16_UINT;
    case VK_FORMAT_R16_UNORM:
    case VK_FORMAT_D16_UNORM:
    case VK_FORMAT_D16_UNORM_S8_UINT:
        return FFX_SURFACE_FORMAT_R16_UNORM;
    case VK_FORMAT_R16_SNORM:
        return FFX_SURFACE_FORMAT_R16_SNORM;
    case VK_FORMAT_R8_UNORM:
        return FFX_SURFACE_FORMAT_R8_UNORM;
    case VK_FORMAT_R8_SNORM:
        return FFX_SURFACE_FORMAT_R8_SNORM;
    case VK_FORMAT_R8_UINT:
    case VK_FORMAT_S8_UINT:
        return FFX_SURFACE_FORMAT_R8_UINT;
    case VK_FORMAT_R8G8_UNORM:
        return FFX_SURFACE_FORMAT_R8G8_UNORM;
    case VK_FORMAT_R8G8_UINT:
        return FFX_SURFACE_FORMAT_R8G8_UINT;
    case VK_FORMAT_R8G8_SINT:
        return FFX_SURFACE_FORMAT_R8G8_SINT;
    case VK_FORMAT_R32_SFLOAT:
    case VK_FORMAT_D32_SFLOAT:
    case VK_FORMAT_D32_SFLOAT_S8_UINT:
        return FFX_SURFACE_FORMAT_R32_FLOAT;
    case VK_FORMAT_E5B9G9R9_UFLOAT_PACK32:
        return FFX_SURFACE_FORMAT_R9G9B9E5_SHAREDEXP;
    case VK_FORMAT_UNDEFINED:
        return FFX_SURFACE_FORMAT_UNKNOWN;

    default:
                                                        
        FFX_ASSERT_MESSAGE(false, "Format not yet supported");
        return FFX_SURFACE_FORMAT_UNKNOWN;
    }
}

bool isDepthFormat(VkFormat format)
{
    switch (format)
    {
    case VK_FORMAT_D16_UNORM:
    case VK_FORMAT_X8_D24_UNORM_PACK32:
    case VK_FORMAT_D32_SFLOAT:
    case VK_FORMAT_D16_UNORM_S8_UINT:
    case VK_FORMAT_D24_UNORM_S8_UINT:
    case VK_FORMAT_D32_SFLOAT_S8_UINT:
        return true;

    default:
        return false;
    }
}

bool isStencilFormat(VkFormat format)
{
    switch (format)
    {
    case VK_FORMAT_S8_UINT:
    case VK_FORMAT_D16_UNORM_S8_UINT:
    case VK_FORMAT_D24_UNORM_S8_UINT:
    case VK_FORMAT_D32_SFLOAT_S8_UINT:
        return true;

    default:
        return false;
    }
}

VkDataGraphPipelineNodeConnectionTypeARM ffxGetVkOpticalFlowConnectionType(const FfxOpticalFlowConnectionType& connectionType)
{
    switch (connectionType)
    {
    case FFX_OPTICAL_FLOW_CONNECTION_INPUT:
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_INPUT_ARM;
    case FFX_OPTICAL_FLOW_CONNECTION_REFERENCE:
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_REFERENCE_ARM;
    case FFX_OPTICAL_FLOW_CONNECTION_HINT:
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_HINT_ARM;
    case FFX_OPTICAL_FLOW_CONNECTION_FLOW_VECTOR:
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_FLOW_VECTOR_ARM;
    case FFX_OPTICAL_FLOW_CONNECTION_COST:
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_COST_ARM;
    case FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_FLOW_VECTOR:
    case FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_COST:
    case FFX_OPTICAL_FLOW_CONNECTION_UNKNOWN:
    default:
        FFX_ASSERT_MESSAGE(false, "Unknown/unsupported optical flow connection type");
        return VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_MAX_ENUM_ARM;
    }
}

VkDataGraphOpticalFlowPerformanceLevelARM ffxGetVkOpticalFlowPerformanceLevel(const FfxOpticalFlowPerformanceLevel& performanceLevel)
{
    switch (performanceLevel)
    {
    case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW:
        return VK_DATA_GRAPH_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW_ARM;
    case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM:
        return VK_DATA_GRAPH_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM_ARM;
    case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST:
        return VK_DATA_GRAPH_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST_ARM;
    case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_UNKNOWN:
    default:
        return VK_DATA_GRAPH_OPTICAL_FLOW_PERFORMANCE_LEVEL_UNKNOWN_ARM;
    }
}

VkDataGraphOpticalFlowGridSizeFlagsARM ffxGetVkOpticalFlowGridSize(const FfxOpticalFlowGridSize& gridSize)
{
    static_assert(static_cast<uint32_t>(FFX_OPTICAL_FLOW_GRID_SIZE_UNKNOWN) == static_cast<uint32_t>(VK_DATA_GRAPH_OPTICAL_FLOW_GRID_SIZE_UNKNOWN_ARM));
    static_assert(static_cast<uint32_t>(FFX_OPTICAL_FLOW_GRID_SIZE_1X1) == static_cast<uint32_t>(VK_DATA_GRAPH_OPTICAL_FLOW_GRID_SIZE_1X1_BIT_ARM));
    static_assert(static_cast<uint32_t>(FFX_OPTICAL_FLOW_GRID_SIZE_2X2) == static_cast<uint32_t>(VK_DATA_GRAPH_OPTICAL_FLOW_GRID_SIZE_2X2_BIT_ARM));
    static_assert(static_cast<uint32_t>(FFX_OPTICAL_FLOW_GRID_SIZE_4X4) == static_cast<uint32_t>(VK_DATA_GRAPH_OPTICAL_FLOW_GRID_SIZE_4X4_BIT_ARM));
    static_assert(static_cast<uint32_t>(FFX_OPTICAL_FLOW_GRID_SIZE_8X8) == static_cast<uint32_t>(VK_DATA_GRAPH_OPTICAL_FLOW_GRID_SIZE_8X8_BIT_ARM));

    return static_cast<VkDataGraphOpticalFlowGridSizeFlagsARM>(gridSize);
}

uint32_t ffxGetVkOpticalFlowExecuteFlags(const uint32_t executeFlags)
{
    uint32_t flags = 0;
    if (executeFlags & FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS)
    {
        flags |= VK_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS_BIT_ARM;
    }
    if (executeFlags & FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_UNCHANGED)
    {
        flags |= VK_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_UNCHANGED_BIT_ARM;
    }
    if (executeFlags & FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_UNCHANGED)
    {
        flags |= VK_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_UNCHANGED_BIT_ARM;
    }
    if (executeFlags & FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_IS_PREVIOUS_REFERENCE)
    {
        flags |= VK_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_INPUT_IS_PREVIOUS_REFERENCE_BIT_ARM;
    }
    if (executeFlags & FFX_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_IS_PREVIOUS_INPUT)
    {
        flags |= VK_DATA_GRAPH_OPTICAL_FLOW_EXECUTE_REFERENCE_IS_PREVIOUS_INPUT_BIT_ARM;
    }
    return flags;
}

                                                                                                                             
                                                                 
VkFormat ffxGetVkFormatForTensorAliasedImage(FfxSurfaceFormat tensorFormat, const uint64_t channel)
{
    VkFormat vkTensorFormat = ffxGetVkFormatFromSurfaceFormat(tensorFormat);

            
                                                                                                                            
                                                                                                                   
                                                                                                                                              

    if (channel == 4)
    {
        switch (vkTensorFormat)
        {
        case VK_FORMAT_R32_SFLOAT:
            return VK_FORMAT_R32G32B32A32_SFLOAT;
        case VK_FORMAT_R8_SINT:
            return VK_FORMAT_R8G8B8A8_SNORM;
        default:
            FFX_ASSERT_MESSAGE(false, "Tensor format not yet supported");
            return VK_FORMAT_UNDEFINED;
        }
    }
    else if (channel == 1)
    {
        switch (vkTensorFormat)
        {
        case VK_FORMAT_R32_SFLOAT:
            return VK_FORMAT_R32_SFLOAT;
        case VK_FORMAT_R8_SINT:
            return VK_FORMAT_R8_SNORM;
        default:
            FFX_ASSERT_MESSAGE(false, "Tensor format not yet supported");
            return VK_FORMAT_UNDEFINED;
        }
    }
    else
    {
        FFX_ASSERT_MESSAGE(false, "Dimensions of tensor not yet supported in image aliasing.");
        return VK_FORMAT_UNDEFINED;
    }
}

VkImageAspectFlags getImageAspect(FfxResourceUsage usage)
{
                                                     
    if (FFX_CONTAINS_FLAG(usage, FFX_RESOURCE_USAGE_DEPTHTARGET))
        return VK_IMAGE_ASPECT_DEPTH_BIT;
    else
        return VK_IMAGE_ASPECT_COLOR_BIT;
}

VkFormat getVkFormatFromSurfaceFormatAndUsage(FfxSurfaceFormat fmt, FfxResourceUsage usage)
{
    VkFormat format     = ffxGetVkFormatFromSurfaceFormat(fmt);
    bool     hasDepth   = FFX_CONTAINS_FLAG(usage, FFX_RESOURCE_USAGE_DEPTHTARGET);
    bool     hasStencil = FFX_CONTAINS_FLAG(usage, FFX_RESOURCE_USAGE_STENCILTARGET);
    if (hasDepth || hasStencil)
    {
        switch (fmt)
        {
        case FFX_SURFACE_FORMAT_R16_UNORM:
        {
            if (hasDepth && hasStencil)
                return VK_FORMAT_D16_UNORM_S8_UINT;
            else if (hasDepth)
                return VK_FORMAT_D16_UNORM;
                                         
            break;
        }
        case FFX_SURFACE_FORMAT_R32_FLOAT:
        {
            if (hasDepth && hasStencil)
                return VK_FORMAT_D32_SFLOAT_S8_UINT;
            else if (hasDepth)
                return VK_FORMAT_D32_SFLOAT;
                                         
            break;
        }
        case FFX_SURFACE_FORMAT_R32_UINT:
        {
            if (hasDepth && hasStencil)
                return VK_FORMAT_D24_UNORM_S8_UINT;
            else if (hasDepth)
                return VK_FORMAT_X8_D24_UNORM_PACK32;
                                         
            break;
        }
        case FFX_SURFACE_FORMAT_R8_UINT:
        {
            if (hasStencil)
                return VK_FORMAT_S8_UINT;
            break;
        }
        default:
            break;
        }
    }

    return format;
}

VkImageUsageFlags getVKImageUsageFlagsFromResourceUsage(FfxResourceUsage flags)
{
    VkImageUsageFlags ret = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    if (FFX_CONTAINS_FLAG(flags, FFX_RESOURCE_USAGE_RENDERTARGET))
        ret |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    if (FFX_CONTAINS_FLAG(flags, FFX_RESOURCE_USAGE_UAV))
        ret |= (VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT);
    return ret;
}

FfxResourceDescription ffxGetBufferResourceDescriptionVK(const VkBuffer           buffer,
                                                         const VkBufferCreateInfo createInfo,
                                                         FfxResourceUsage         additionalUsages                                  )
{
    FfxResourceDescription resourceDescription = {};

                    
    if (buffer == VK_NULL_HANDLE)
        return resourceDescription;

    resourceDescription.flags  = FFX_RESOURCE_FLAGS_NONE;
    resourceDescription.usage  = additionalUsages;
    resourceDescription.size   = (uint32_t)createInfo.size;
    resourceDescription.stride = 0;
    resourceDescription.format = FFX_SURFACE_FORMAT_UNKNOWN;

    if (FFX_CONTAINS_FLAG(createInfo.usage, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT))
        resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_UAV);
    if (FFX_CONTAINS_FLAG(createInfo.usage, VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT))
        resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_INDIRECT);

                                                               
    resourceDescription.depth    = 0;
    resourceDescription.mipCount = 0;

                   
    resourceDescription.type = FFX_RESOURCE_TYPE_BUFFER;

    return resourceDescription;
}

FfxResourceDescription ffxGetImageResourceDescriptionVK(const VkImage           image,
                                                        const VkImageCreateInfo createInfo,
                                                        FfxResourceUsage        additionalUsages                                  )
{
    FfxResourceDescription resourceDescription = {};

                    
    if (image == VK_NULL_HANDLE)
        return resourceDescription;

                                                   
    resourceDescription.flags = FFX_RESOURCE_FLAGS_NONE;
    resourceDescription.usage = FFX_RESOURCE_USAGE_READ_ONLY;

                                      
    if (isDepthFormat(createInfo.format))
        resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_DEPTHTARGET);
    if (isStencilFormat(createInfo.format))
        resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_STENCILTARGET);

                           
    if (FFX_CONTAINS_FLAG(createInfo.usage, VK_IMAGE_USAGE_STORAGE_BIT))
        resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | FFX_RESOURCE_USAGE_UAV);

                                               
    resourceDescription.usage = (FfxResourceUsage)(resourceDescription.usage | additionalUsages);

    resourceDescription.width    = createInfo.extent.width;
    resourceDescription.height   = createInfo.extent.height;
    resourceDescription.mipCount = createInfo.mipLevels;
    resourceDescription.format   = ffxGetSurfaceFormatVK(createInfo.format);

                                                                          
    if (FFX_CONTAINS_FLAG(createInfo.flags, VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT))
        resourceDescription.format = ffxGetSurfaceFormatToGamma(resourceDescription.format);

    switch (createInfo.imageType)
    {
    case VK_IMAGE_TYPE_1D:
        resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE1D;
        break;
    case VK_IMAGE_TYPE_2D:
        resourceDescription.depth = createInfo.arrayLayers;
        if (FFX_CONTAINS_FLAG(additionalUsages, FFX_RESOURCE_USAGE_ARRAYVIEW))
            resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
        else if (FFX_CONTAINS_FLAG(createInfo.flags, VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT))
            resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE_CUBE;
        else
            resourceDescription.type = FFX_RESOURCE_TYPE_TEXTURE2D;
        break;
    case VK_IMAGE_TYPE_3D:
        resourceDescription.depth = createInfo.extent.depth;
        resourceDescription.type  = FFX_RESOURCE_TYPE_TEXTURE3D;
        break;
    default:
        FFX_ASSERT_MESSAGE(false, "FFXInterface: VK: Unsupported texture dimension requested. Please implement.");
        break;
    }

    return resourceDescription;
}

FfxErrorCode allocateDeviceMemory(BackendContext_VK*           backendContext,
                                  VkMemoryRequirements         memRequirements,
                                  VkMemoryPropertyFlags        requiredMemoryProperties,
                                  BackendContext_VK::Resource* backendResource)
{
    VkMemoryAllocateInfo allocInfo{};
    allocInfo.sType           = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize  = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryTypeIndex(backendContext, memRequirements, requiredMemoryProperties, backendResource->memoryProperties);

    if (allocInfo.memoryTypeIndex == UINT32_MAX)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    VkResult result = VulkanWrapper().vkAllocateMemory(backendContext->device, &allocInfo, nullptr, &backendResource->deviceMemory);

    if (result != VK_SUCCESS)
    {
        switch (result)
        {
        case (VK_ERROR_OUT_OF_HOST_MEMORY):
        case (VK_ERROR_OUT_OF_DEVICE_MEMORY):
            return FFX_ERROR_OUT_OF_MEMORY;
        default:
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    return FFX_OK;
}

void setVKObjectName(VkDevice device, VkObjectType objectType, uint64_t object, const char* name)
{
    if (!VulkanWrapper().vkSetDebugUtilsObjectNameEXT)
    {
        return;
    }

    VkDebugUtilsObjectNameInfoEXT s{VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT, nullptr, objectType, object, name};
    VulkanWrapper().vkSetDebugUtilsObjectNameEXT(device, &s);
}

uint32_t getDynamicResourcesStartIndex(uint32_t effectContextId)
{
                                                       
    return (effectContextId * FFX_MAX_RESOURCE_COUNT) + FFX_MAX_RESOURCE_COUNT - 1;
}
uint32_t getDynamicResourceViewsStartIndex(uint32_t effectContextId, uint32_t frameIndex)
{
                                                            
    return (effectContextId * FFX_MAX_QUEUED_FRAMES * FFX_MAX_RESOURCE_COUNT * 2) + (frameIndex * FFX_MAX_RESOURCE_COUNT * 2) + (FFX_MAX_RESOURCE_COUNT * 2) -
           1;
}

void destroyDynamicViews(BackendContext_VK* backendContext, uint32_t effectContextId, uint32_t frameIndex)
{
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

                                                
    const uint32_t dynamicResourceViewIndexStart = getDynamicResourceViewsStartIndex(effectContextId, frameIndex);
    for (uint32_t dynamicViewIndex = effectContext.nextDynamicResourceView[frameIndex] + 1; dynamicViewIndex <= dynamicResourceViewIndexStart;
         ++dynamicViewIndex)
    {
        VulkanWrapper().vkDestroyImageView(backendContext->device, backendContext->pResourceViews[dynamicViewIndex].imageView, VK_NULL_HANDLE);
        backendContext->pResourceViews[dynamicViewIndex].imageView = VK_NULL_HANDLE;
    }
    effectContext.nextDynamicResourceView[frameIndex] = dynamicResourceViewIndexStart;
}

VkAccessFlags2 getVKAccessFlagsFromResourceState(FfxResourceStates state)
{
    switch (state)
    {
    case (FFX_RESOURCE_STATE_COMMON):
        return VK_ACCESS_2_NONE;
    case (FFX_RESOURCE_STATE_GENERIC_READ):
        return VK_ACCESS_2_SHADER_READ_BIT;
    case (FFX_RESOURCE_STATE_GENERIC_UAV):
    case (FFX_RESOURCE_STATE_COMPUTE_UAV):
    case (FFX_RESOURCE_STATE_PIXEL_UAV):
        return VK_ACCESS_2_SHADER_READ_BIT | VK_ACCESS_2_SHADER_WRITE_BIT;
    case (FFX_RESOURCE_STATE_COMPUTE_READ):
    case (FFX_RESOURCE_STATE_PIXEL_READ):
    case (FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ):
        return VK_ACCESS_2_SHADER_READ_BIT;
    case FFX_RESOURCE_STATE_COPY_SRC:
        return VK_ACCESS_2_TRANSFER_READ_BIT;
    case FFX_RESOURCE_STATE_COPY_DEST:
        return VK_ACCESS_2_TRANSFER_WRITE_BIT;
    case FFX_RESOURCE_STATE_INDIRECT_ARGUMENT:
        return VK_ACCESS_2_INDIRECT_COMMAND_READ_BIT;
    case FFX_RESOURCE_STATE_PRESENT:
        return VK_ACCESS_2_NONE;
    case FFX_RESOURCE_STATE_RENDER_TARGET:
        return VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT;
    case FFX_RESOURCE_STATE_DATA_GRAPH_READ:
        return VK_ACCESS_2_DATA_GRAPH_READ_BIT_ARM;
    case FFX_RESOURCE_STATE_DATA_GRAPH_WRITE:
        return VK_ACCESS_2_DATA_GRAPH_WRITE_BIT_ARM;
    case FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT:
        return VK_ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT | VK_ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
    default:
        FFX_ASSERT_MESSAGE(false, "State flag not yet supported");
        return VK_ACCESS_2_SHADER_READ_BIT;
    }
}

VkPipelineStageFlags2 getVKPipelineStageFlagsFromResourceState(FfxResourceStates state)
{
    switch (state)
    {
    case (FFX_RESOURCE_STATE_COMMON):
    case (FFX_RESOURCE_STATE_GENERIC_READ):
    case (FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ):
    case (FFX_RESOURCE_STATE_GENERIC_UAV):
        return VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
    case (FFX_RESOURCE_STATE_PIXEL_UAV):
        return VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
    case (FFX_RESOURCE_STATE_COMPUTE_UAV):
    case (FFX_RESOURCE_STATE_COMPUTE_READ):
        return VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
    case (FFX_RESOURCE_STATE_PIXEL_READ):
        return VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
    case (FFX_RESOURCE_STATE_INDIRECT_ARGUMENT):
        return VK_PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
    case FFX_RESOURCE_STATE_COPY_SRC:
    case FFX_RESOURCE_STATE_COPY_DEST:
        return VK_PIPELINE_STAGE_2_TRANSFER_BIT;
    case FFX_RESOURCE_STATE_PRESENT:
        return VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT;
    case FFX_RESOURCE_STATE_RENDER_TARGET:
        return VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
    case FFX_RESOURCE_STATE_DATA_GRAPH_READ:
    case FFX_RESOURCE_STATE_DATA_GRAPH_WRITE:
        return VK_PIPELINE_STAGE_2_DATA_GRAPH_BIT_ARM;
    case (FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT):
        return VK_PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
    default:
        FFX_ASSERT_MESSAGE(false, "Pipeline stage flag not yet supported");
        return VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
    }
}

VkImageLayout getVKImageLayoutFromResourceState(FfxResourceStates state)
{
    switch (state)
    {
    case (FFX_RESOURCE_STATE_COMMON):
        return VK_IMAGE_LAYOUT_GENERAL;
    case (FFX_RESOURCE_STATE_GENERIC_READ):
        return VK_IMAGE_LAYOUT_GENERAL;
    case (FFX_RESOURCE_STATE_GENERIC_UAV):
    case (FFX_RESOURCE_STATE_COMPUTE_UAV):
    case (FFX_RESOURCE_STATE_PIXEL_UAV):
        return VK_IMAGE_LAYOUT_GENERAL;
    case (FFX_RESOURCE_STATE_COMPUTE_READ):
    case (FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ):
    case (FFX_RESOURCE_STATE_PIXEL_READ):
        return VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    case FFX_RESOURCE_STATE_COPY_SRC:
        return VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    case FFX_RESOURCE_STATE_COPY_DEST:
        return VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    case FFX_RESOURCE_STATE_PRESENT:
        return VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    case FFX_RESOURCE_STATE_RENDER_TARGET:
        return VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    case FFX_RESOURCE_STATE_DATA_GRAPH_READ:
    case FFX_RESOURCE_STATE_DATA_GRAPH_WRITE:
        return VK_IMAGE_LAYOUT_TENSOR_ALIASING_ARM;
    case FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT:
        return VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
    case FFX_RESOURCE_STATE_INDIRECT_ARGUMENT:
                                   
    default:
        FFX_ASSERT_MESSAGE(false, "Image layout flag not yet supported");
        return VK_IMAGE_LAYOUT_GENERAL;
    }
}

void setupImageViewForSRV(VkImageViewCreateInfo&      imageViewCreateInfo,
                          VkImageViewUsageCreateInfo& imageViewUsageCreateInfo,
                          FfxResourceDescription      resourceDescription)
{
    if (ffxIsSurfaceFormatSRGB(resourceDescription.format) && FFX_CONTAINS_FLAG(resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
    {
                                                                     
        imageViewUsageCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO;
        imageViewUsageCreateInfo.pNext = nullptr;
        imageViewUsageCreateInfo.usage = getVKImageUsageFlagsFromResourceUsage(FFX_RESOURCE_USAGE_READ_ONLY);                                     
        imageViewCreateInfo.pNext      = &imageViewUsageCreateInfo;
    }
}

void copyResourceState(BackendContext_VK::Resource* backendResource, const FfxResource* inFfxResource)
{
    FfxResourceStates state = inFfxResource->state;

                          
    backendResource->initialState = state;
    backendResource->currentState = state;
    backendResource->undefined    = false;
    backendResource->dynamic      = true;

                                                                                               
                                                                                                          
    if (backendResource->resourceDescription.flags & FFX_RESOURCE_FLAGS_UNDEFINED)
    {
        backendResource->undefined                 = true;
        backendResource->resourceDescription.flags = (FfxResourceFlags)((int)backendResource->resourceDescription.flags & ~FFX_RESOURCE_FLAGS_UNDEFINED);
    }
}

void beginMarkerVK(BackendContext_VK* backendContext, VkCommandBuffer commandBuffer, const char* label)
{
    if (VulkanWrapper().vkCmdBeginDebugUtilsLabelEXT == nullptr)
    {
                                                               
        return;
    }

    VkDebugUtilsLabelEXT debugLabel = {};
    debugLabel.sType                = VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT;
    debugLabel.pNext                = nullptr;
    debugLabel.pLabelName           = label;

                           
    debugLabel.color[0] = 1.0f;
    debugLabel.color[1] = 0.14f;
    debugLabel.color[2] = 0.14f;
    debugLabel.color[3] = 1.0f;
    VulkanWrapper().vkCmdBeginDebugUtilsLabelEXT(commandBuffer, &debugLabel);
}

void endMarkerVK(BackendContext_VK* backendContext, VkCommandBuffer commandBuffer)
{
    if (VulkanWrapper().vkCmdEndDebugUtilsLabelEXT == nullptr)
    {
                                                               
        return;
    }

    VulkanWrapper().vkCmdEndDebugUtilsLabelEXT(commandBuffer);
}

void addBarrier(BackendContext_VK* backendContext, FfxResourceInternal* resource, FfxResourceStates newState)
{
    FFX_ASSERT(NULL != backendContext);
    FFX_ASSERT(NULL != resource);

    BackendContext_VK::Resource& ffxResource = backendContext->pResources[resource->internalIndex];
    FfxResourceStates&           curState    = backendContext->pResources[resource->internalIndex].currentState;

    auto addBufferBarrier = [&](VkBuffer buffer) {
        VkBufferMemoryBarrier2* barrier = &backendContext->bufferMemoryBarriers[backendContext->scheduledBufferBarrierCount];

        barrier->sType               = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2;
        barrier->pNext               = nullptr;
        barrier->srcStageMask        = getVKPipelineStageFlagsFromResourceState(curState);
        barrier->srcAccessMask       = getVKAccessFlagsFromResourceState(curState);
        barrier->dstStageMask        = getVKPipelineStageFlagsFromResourceState(newState);
        barrier->dstAccessMask       = getVKAccessFlagsFromResourceState(newState);
        barrier->srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier->dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier->buffer              = buffer;
        barrier->offset              = 0;
        barrier->size                = VK_WHOLE_SIZE;

        ++backendContext->scheduledBufferBarrierCount;
    };

    auto addImageBarrier = [&](VkImage image) {
        VkImageMemoryBarrier2* barrier = &backendContext->imageMemoryBarriers[backendContext->scheduledImageBarrierCount];

        VkImageSubresourceRange range;
        range.aspectMask     = getImageAspect(ffxResource.resourceDescription.usage);
        range.baseMipLevel   = 0;
        range.levelCount     = VK_REMAINING_MIP_LEVELS;
        range.baseArrayLayer = 0;
        range.layerCount     = VK_REMAINING_ARRAY_LAYERS;

        barrier->sType               = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;
        barrier->pNext               = nullptr;
        barrier->srcStageMask        = getVKPipelineStageFlagsFromResourceState(curState);
        barrier->srcAccessMask       = getVKAccessFlagsFromResourceState(curState);
        barrier->dstStageMask        = getVKPipelineStageFlagsFromResourceState(newState);
        barrier->dstAccessMask       = getVKAccessFlagsFromResourceState(newState);
        barrier->oldLayout           = ffxResource.undefined ? VK_IMAGE_LAYOUT_UNDEFINED : getVKImageLayoutFromResourceState(curState);
        barrier->newLayout           = getVKImageLayoutFromResourceState(newState);
        barrier->srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier->dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier->image               = image;
        barrier->subresourceRange    = range;

        ++backendContext->scheduledImageBarrierCount;
    };

    if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        addBufferBarrier(ffxResource.bufferResource);
    }
    else if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR)
    {
        if (!ffxResource.bridgeTensor)
        {
                                                                               
                                                                    
            VkTensorARM               vkResource = ffxResource.tensorResource;
            VkTensorMemoryBarrierARM* barrier    = &backendContext->tensorMemoryBarriers[backendContext->scheduledTensorBarrierCount];

            barrier->sType               = VK_STRUCTURE_TYPE_TENSOR_MEMORY_BARRIER_ARM;
            barrier->pNext               = nullptr;
            barrier->srcStageMask        = getVKPipelineStageFlagsFromResourceState(curState);
            barrier->srcAccessMask       = getVKAccessFlagsFromResourceState(curState);
            barrier->dstStageMask        = getVKPipelineStageFlagsFromResourceState(newState);
            barrier->dstAccessMask       = getVKAccessFlagsFromResourceState(newState);
            barrier->srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier->dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier->tensor              = vkResource;

            ++backendContext->scheduledTensorBarrierCount;
        }

        const auto flags         = ffxResource.resourceDescription.flags;
        const bool imageAliased  = (flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) == FFX_RESOURCE_FLAGS_IMAGE_ALIASED;
        const bool bufferAliased = (flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED;

        if (imageAliased && ffxResource.aliasedTensorImageResource != VK_NULL_HANDLE)
        {
            addImageBarrier(ffxResource.aliasedTensorImageResource);
        }

        if ((bufferAliased || ffxResource.bridgeTensor) && ffxResource.aliasedTensorBufferResource != VK_NULL_HANDLE)
        {
            addBufferBarrier(ffxResource.aliasedTensorBufferResource);
        }
    }
    else
    {
        addImageBarrier(ffxResource.imageResource);

        if (ffxResource.aliasedBufferResource != VK_NULL_HANDLE)
        {
            addBufferBarrier(ffxResource.aliasedBufferResource);
        }
    }

    curState = newState;

    if (ffxResource.undefined)
        ffxResource.undefined = false;
}

                                                                                                                                 
                                                                                                                         
static VkPipelineStageFlags stageMask2To1(VkPipelineStageFlags2 s, VkPipelineStageFlags whenNone)
{
    VkPipelineStageFlags o = static_cast<VkPipelineStageFlags>(s & 0xFFFFFFFFull);
    if (s & (0x100000000ull | 0x200000000ull | 0x400000000ull | 0x800000000ull))                                  
        o |= VK_PIPELINE_STAGE_TRANSFER_BIT;
    if (s & (0x1000000000ull | 0x2000000000ull))                                         
        o |= VK_PIPELINE_STAGE_VERTEX_INPUT_BIT;
    if (s & 0x4000000000ull)                              
        o |= VK_PIPELINE_STAGE_VERTEX_SHADER_BIT | VK_PIPELINE_STAGE_TESSELLATION_CONTROL_SHADER_BIT |
             VK_PIPELINE_STAGE_TESSELLATION_EVALUATION_SHADER_BIT | VK_PIPELINE_STAGE_GEOMETRY_SHADER_BIT;
    return o ? o : whenNone;
}

static VkAccessFlags accessMask2To1(VkAccessFlags2 a)
{
    VkAccessFlags o = static_cast<VkAccessFlags>(a & 0xFFFFFFFFull);
    if (a & (0x100000000ull | 0x200000000ull))                                              
        o |= VK_ACCESS_SHADER_READ_BIT;
    if (a & 0x400000000ull)                         
        o |= VK_ACCESS_SHADER_WRITE_BIT;
    return o;
}

static void flushBarriersV1Fallback(BackendContext_VK* backendContext, VkCommandBuffer vkCommandBuffer)
{
    VkImageMemoryBarrier  imageBarriers[FFX_MAX_BARRIERS];
    VkBufferMemoryBarrier bufferBarriers[FFX_MAX_BARRIERS];
    VkPipelineStageFlags  srcStages = 0, dstStages = 0;

    for (uint32_t i = 0; i < backendContext->scheduledImageBarrierCount; ++i)
    {
        const VkImageMemoryBarrier2& b = backendContext->imageMemoryBarriers[i];
        srcStages |= stageMask2To1(b.srcStageMask, 0);
        dstStages |= stageMask2To1(b.dstStageMask, 0);
        imageBarriers[i] = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, accessMask2To1(b.srcAccessMask), accessMask2To1(b.dstAccessMask),
                            b.oldLayout, b.newLayout, b.srcQueueFamilyIndex, b.dstQueueFamilyIndex, b.image, b.subresourceRange};
    }
    for (uint32_t i = 0; i < backendContext->scheduledBufferBarrierCount; ++i)
    {
        const VkBufferMemoryBarrier2& b = backendContext->bufferMemoryBarriers[i];
        srcStages |= stageMask2To1(b.srcStageMask, 0);
        dstStages |= stageMask2To1(b.dstStageMask, 0);
        bufferBarriers[i] = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, nullptr, accessMask2To1(b.srcAccessMask), accessMask2To1(b.dstAccessMask),
                             b.srcQueueFamilyIndex, b.dstQueueFamilyIndex, b.buffer, b.offset, b.size};
    }
    if (srcStages == 0)
        srcStages = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
    if (dstStages == 0)
        dstStages = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

    VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, srcStages, dstStages, VK_DEPENDENCY_BY_REGION_BIT, 0, nullptr,
                                         backendContext->scheduledBufferBarrierCount, bufferBarriers,
                                         backendContext->scheduledImageBarrierCount, imageBarriers);
}

void flushBarriers(BackendContext_VK* backendContext, VkCommandBuffer vkCommandBuffer)
{
    FFX_ASSERT(NULL != backendContext);
    FFX_ASSERT(NULL != vkCommandBuffer);

    uint32_t totalCount =
        backendContext->scheduledImageBarrierCount + backendContext->scheduledBufferBarrierCount + backendContext->scheduledTensorBarrierCount;
    if (totalCount)
    {
        nss_trace("  barriers img=%u buf=%u tensor=%u", (unsigned) backendContext->scheduledImageBarrierCount, (unsigned) backendContext->scheduledBufferBarrierCount,
                  (unsigned) backendContext->scheduledTensorBarrierCount);
        const VkTensorDependencyInfoARM tensorDependencyInfo = {VK_STRUCTURE_TYPE_TENSOR_DEPENDENCY_INFO_ARM,
                                                                nullptr,
                                                                static_cast<uint32_t>(backendContext->scheduledTensorBarrierCount),
                                                                backendContext->tensorMemoryBarriers};

        const VkDependencyInfo dependencyInfo = {VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
                                                 backendContext->scheduledTensorBarrierCount != 0 ? &tensorDependencyInfo : NULL,
                                                 VK_DEPENDENCY_BY_REGION_BIT,                    
                                                 0,                                                 
                                                 nullptr,                                        
                                                 backendContext->scheduledBufferBarrierCount,
                                                 backendContext->bufferMemoryBarriers,
                                                 backendContext->scheduledImageBarrierCount,
                                                 backendContext->imageMemoryBarriers};

        static const bool forceBarrierV1 = (getenv("NSS_FORCE_BARRIER_V1") != nullptr);                                     
        if (!forceBarrierV1 && VulkanWrapper().vkCmdPipelineBarrier2 != nullptr)
            VulkanWrapper().vkCmdPipelineBarrier2(vkCommandBuffer, &dependencyInfo);
        else
            flushBarriersV1Fallback(backendContext, vkCommandBuffer);

        backendContext->scheduledTensorBarrierCount = 0;
        backendContext->scheduledImageBarrierCount  = 0;
        backendContext->scheduledBufferBarrierCount = 0;
    }
}

FfxConstantAllocation BackendContext_VK::FallbackConstantAllocator(void* data, FfxUInt64 dataSize)
{
    FfxConstantAllocation       allocation;
    std::lock_guard<std::mutex> cbLock{uniformBufferMutex};
    memset(&allocation, 0, sizeof(FfxConstantAllocation));

    if (!uniformBufferMem)
    {
                                          

                        
        VkPhysicalDeviceProperties physicalDeviceProperties = {};
        VulkanWrapper().vkGetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties);
        uniformBufferAlignment = physicalDeviceProperties.limits.minUniformBufferOffsetAlignment;

        uniformBufferSize = FFX_ALIGN_UP(FFX_BUFFER_SIZE, uniformBufferAlignment) * maxEffectContexts * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES;

        VkBufferCreateInfo bufferInfo = {};
        bufferInfo.sType              = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size               = static_cast<VkDeviceSize>(uniformBufferSize);
        bufferInfo.usage              = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        bufferInfo.sharingMode        = VK_SHARING_MODE_EXCLUSIVE;

        VkResult res = VulkanWrapper().vkCreateBuffer(device, &bufferInfo, NULL, &uniformBuffer);
        FFX_ASSERT(res == VK_SUCCESS);

        VkMemoryAllocateInfo allocInfo = {};
        if (res == VK_SUCCESS)
        {
                                                            
            VkMemoryRequirements memRequirements = {};
            VulkanWrapper().vkGetBufferMemoryRequirements(device, uniformBuffer, &memRequirements);

                                         
            uniformBufferAlignment = memRequirements.alignment;

            VkMemoryPropertyFlags requiredMemoryProperties = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

            allocInfo.sType           = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
            allocInfo.allocationSize  = uniformBufferSize;
            allocInfo.memoryTypeIndex = findMemoryTypeIndex(this, memRequirements, requiredMemoryProperties, uniformBufferMemoryProperties);

            if (allocInfo.memoryTypeIndex == UINT32_MAX)
            {
                requiredMemoryProperties  = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
                allocInfo.memoryTypeIndex = findMemoryTypeIndex(this, memRequirements, requiredMemoryProperties, uniformBufferMemoryProperties);

                if (allocInfo.memoryTypeIndex == UINT32_MAX)
                    res = VK_ERROR_INITIALIZATION_FAILED;
            }
        }

        if (res == VK_SUCCESS)
            res = VulkanWrapper().vkAllocateMemory(device, &allocInfo, nullptr, &uniformBufferMemory);
        FFX_ASSERT(res == VK_SUCCESS);

        if (res == VK_SUCCESS)
            res = VulkanWrapper().vkBindBufferMemory(device, uniformBuffer, uniformBufferMemory, 0);
        FFX_ASSERT(res == VK_SUCCESS);

                               
        if (res == VK_SUCCESS)
            res = VulkanWrapper().vkMapMemory(device, uniformBufferMemory, 0, uniformBufferSize, 0, &uniformBufferMem);
        FFX_ASSERT(res == VK_SUCCESS);
    }

    FFX_ASSERT(uniformBufferMem);

    allocation.resource.resource = uniformBuffer;
    allocation.handle            = 0;

    if (data && uniformBufferMem)
    {
        if (uniformBufferOffset + dataSize >= uniformBufferSize)
            uniformBufferOffset = 0;

        allocation.handle = static_cast<FfxUInt64>(uniformBufferOffset);

        void* pBuffer = static_cast<void*>(static_cast<uint8_t*>(uniformBufferMem) + uniformBufferOffset);
        memcpy(pBuffer, data, dataSize);

                                                            
        if ((uniformBufferMemoryProperties & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) == 0)
        {
            VkMappedMemoryRange memoryRange;
            memset(&memoryRange, 0, sizeof(memoryRange));

            memoryRange.sType  = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
            memoryRange.memory = uniformBufferMemory;
            memoryRange.offset = uniformBufferOffset;
            memoryRange.size   = dataSize;

            VulkanWrapper().vkFlushMappedMemoryRanges(device, 1, &memoryRange);
        }

        uniformBufferOffset += FFX_ALIGN_UP(dataSize, uniformBufferAlignment);
        if (uniformBufferOffset > uniformBufferSize)
            uniformBufferOffset = 0;
    }

    return allocation;
}

void resetBackendContext(BackendContext_VK* backendContext)
{
                                                                                                    
    uint32_t maxEffectContexts = backendContext->maxEffectContexts;

    memset(backendContext, 0, sizeof(BackendContext_VK));

                                    
    backendContext->maxEffectContexts = maxEffectContexts;
}

                                                                          
                             

FfxErrorCode SetupMessageCallback(FfxInterface* backendInterface, FfxBackendMessage ffxMessageCallback)
{
    FFX_ASSERT(NULL != backendInterface);

    backendInterface->fpMessage = ffxMessageCallback;
    nss_trace_sink() = reinterpret_cast<NssTraceSink>(ffxMessageCallback);                                                    

    return FFX_OK;
}

FfxVersionNumber GetSDKVersionVK(FfxInterface* backendInterface)
{
    return FFX_SDK_MAKE_VERSION(FFX_SDK_VERSION_MAJOR, FFX_SDK_VERSION_MINOR, FFX_SDK_VERSION_PATCH);
}

FfxErrorCode GetEffectGpuMemoryUsageVK(FfxInterface* backendInterface, FfxUInt32 effectContextId, FfxEffectMemoryUsage* outVramUsage)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != outVramUsage);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    *outVramUsage = effectContext.vramUsage;

    return FFX_OK;
}

class VkFuncLoader
{
public:
    explicit VkFuncLoader(VkDeviceContext* vkDeviceContext)
        : getInstanceProcAddrPtr(vkDeviceContext->vkGetInstanceProcAddr)
        , getDeviceProcAddrPtr(vkDeviceContext->vkDeviceProcAddr)
        , device(vkDeviceContext->vkDevice)
        , instance(vkDeviceContext->vkInstance)
    {
        FFX_ASSERT(NULL != getInstanceProcAddrPtr);
        FFX_ASSERT(NULL != getDeviceProcAddrPtr);
        FFX_ASSERT(VK_NULL_HANDLE != device);
        FFX_ASSERT(VK_NULL_HANDLE != instance);
    }

    template <typename T>
    bool getDeviceProc(T& funcPtr, const char* name)
    {
        return getProcInternal(funcPtr, name, getDeviceProcAddrPtr, device);
    }

    template <typename T>
    bool getInstanceProc(T& funcPtr, const char* name)
    {
        return getProcInternal(funcPtr, name, getInstanceProcAddrPtr, instance);
    }

private:
    template <typename T, typename FuncType, typename HandleType>
    bool getProcInternal(T& funcPtr, const char* name, const FuncType& getProcAddrPtr, HandleType handle)
    {
        FFX_ASSERT(NULL != getProcAddrPtr);

        funcPtr = reinterpret_cast<T>(getProcAddrPtr(handle, name));

        if (!funcPtr)
        {
                                                                                    
            char aliasNameKHR[128];
            snprintf(aliasNameKHR, sizeof(aliasNameKHR), "%sKHR", name);
            funcPtr = reinterpret_cast<T>(getProcAddrPtr(handle, aliasNameKHR));
        }

        if (!funcPtr)
        {
                                                                                    
            char aliasNameEXT[128];
            snprintf(aliasNameEXT, sizeof(aliasNameEXT), "%sEXT", name);
            funcPtr = reinterpret_cast<T>(getProcAddrPtr(handle, aliasNameEXT));
        }

        return funcPtr != nullptr;
    }

    PFN_vkGetInstanceProcAddr getInstanceProcAddrPtr;
    PFN_vkGetDeviceProcAddr   getDeviceProcAddrPtr;
    VkInstance                instance = VK_NULL_HANDLE;
    VkDevice                  device   = VK_NULL_HANDLE;
};

FfxErrorCode CreateBackendContextVK(FfxInterface* backendInterface, FfxEffect effect, FfxEffectBindlessConfig* bindlessConfig, FfxUInt32* effectContextId)
{
    nss_trace("backend: CreateBackendContext effect=%d", (int) effect);
    VkDeviceContext* vkDeviceContext = reinterpret_cast<VkDeviceContext*>(backendInterface->device);

    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != vkDeviceContext);
    FFX_ASSERT(VK_NULL_HANDLE != vkDeviceContext->vkDevice);
    FFX_ASSERT(VK_NULL_HANDLE != vkDeviceContext->vkPhysicalDevice);

                                                                                             
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

                                                    
    if (!backendContext->refCount)
    {
        resetBackendContext(backendContext);

        new (&backendContext->uniformBufferMutex) std::mutex();

                                  
        uint32_t gpuJobDescArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_MAX_GPU_JOBS * sizeof(FfxGpuJobDescription), sizeof(uint32_t));
        uint32_t resourceViewArraySize =
            FFX_ALIGN_UP(((backendContext->maxEffectContexts * FFX_MAX_QUEUED_FRAMES * FFX_MAX_RESOURCE_COUNT * 2) + FFX_MAX_BINDLESS_DESCRIPTOR_COUNT) *
                             sizeof(BackendContext_VK::VkResourceView),
                         sizeof(uint32_t));
        uint32_t stagingRingBufferArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_CONSTANT_BUFFER_RING_BUFFER_SIZE, sizeof(uint32_t));
        uint32_t pipelineArraySize =
            FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_MAX_PASS_COUNT * sizeof(BackendContext_VK::PipelineLayout), sizeof(uint32_t));
        uint32_t resourceArraySize =
            FFX_ALIGN_UP(backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * sizeof(BackendContext_VK::Resource), sizeof(uint32_t));
        uint32_t contextArraySize = FFX_ALIGN_UP(backendContext->maxEffectContexts * sizeof(BackendContext_VK::EffectContext), sizeof(uint32_t));
        uint8_t* pMem             = (uint8_t*)((BackendContext_VK*)(backendContext + 1));

                            
        backendContext->pGpuJobs = (FfxGpuJobDescription*)pMem;
        memset(backendContext->pGpuJobs, 0, gpuJobDescArraySize);
        pMem += gpuJobDescArraySize;

                                      
        backendContext->pResourceViews = (BackendContext_VK::VkResourceView*)(pMem);
        memset(backendContext->pResourceViews, 0, resourceViewArraySize);
        pMem += resourceViewArraySize;

                                            
        backendContext->pStagingRingBuffer = (uint8_t*)pMem;
        memset(backendContext->pStagingRingBuffer, 0, stagingRingBufferArraySize);
        pMem += stagingRingBufferArraySize;

                             
        backendContext->pPipelineLayouts = (BackendContext_VK::PipelineLayout*)pMem;
        memset(backendContext->pPipelineLayouts, 0, pipelineArraySize);
        pMem += pipelineArraySize;

                             
        backendContext->pResources = (BackendContext_VK::Resource*)pMem;
        memset(backendContext->pResources, 0, resourceArraySize);
        pMem += resourceArraySize;

                                          
        for (uint32_t i = 0; i < backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT; ++i)
        {
            backendContext->pResources[i].uavViewIndex = backendContext->pResources[i].srvViewIndex = -1;
        }

                                                                                                
        pMem                            = (uint8_t*)FFX_ALIGN_UP((uintptr_t)pMem, alignof(BackendContext_VK::EffectContext));
        backendContext->pEffectContexts = (BackendContext_VK::EffectContext*)pMem;
        memset(backendContext->pEffectContexts, 0, contextArraySize);
        pMem += contextArraySize;

                              
        backendContext->extensionProperties = (VkExtensionProperties*)pMem;

        FFX_ASSERT(vkDeviceContext->vkDeviceProcAddr != NULL);
        backendContext->getInstanceProcAddr = vkDeviceContext->vkGetInstanceProcAddr;
        backendContext->getDeviceProcAddr   = vkDeviceContext->vkDeviceProcAddr;

        if (vkDeviceContext->vkInstance != VK_NULL_HANDLE)
        {
            backendContext->instance = vkDeviceContext->vkInstance;
        }

        if (vkDeviceContext->vkDevice != VK_NULL_HANDLE)
        {
            backendContext->device = vkDeviceContext->vkDevice;
        }

        if (vkDeviceContext->vkPhysicalDevice != VK_NULL_HANDLE)
        {
            backendContext->physicalDevice = vkDeviceContext->vkPhysicalDevice;
        }

                                              
        backendContext->numDeviceExtensions = 0;
        VulkanWrapper().vkEnumerateDeviceExtensionProperties(backendContext->physicalDevice, nullptr, &backendContext->numDeviceExtensions, nullptr);
        VulkanWrapper().vkEnumerateDeviceExtensionProperties(
            backendContext->physicalDevice, nullptr, &backendContext->numDeviceExtensions, backendContext->extensionProperties);

                                             
        GetDeviceCapabilitiesVK(backendInterface, &backendInterface->deviceCapabilities);

                                                                             
        VkDescriptorPoolCreateInfo descriptorPoolCreateInfo = {};
        VkDescriptorPoolSize       poolSizes[]              = {
            {VK_DESCRIPTOR_TYPE_SAMPLER,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_SAMPLER,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
            {VK_DESCRIPTOR_TYPE_TENSOR_ARM,
             backendContext->maxEffectContexts * FFX_MAX_RESOURCE_COUNT * FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME},
        };

        descriptorPoolCreateInfo.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        descriptorPoolCreateInfo.pNext         = nullptr;
        descriptorPoolCreateInfo.flags         = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
        bool nativeTensorExtension = false;
        for (uint32_t i = 0; i < backendContext->numDeviceExtensions; ++i)
            if (!strcmp(backendContext->extensionProperties[i].extensionName, "VK_ARM_tensors")) nativeTensorExtension = true;
                                                                         
        descriptorPoolCreateInfo.poolSizeCount = nativeTensorExtension ? 7 : 6;
        descriptorPoolCreateInfo.pPoolSizes    = poolSizes;
        descriptorPoolCreateInfo.maxSets       = backendContext->maxEffectContexts * FFX_MAX_PASS_COUNT * MAX_PIPELINE_USAGE_PER_FRAME * FFX_MAX_QUEUED_FRAMES;

        if (VulkanWrapper().vkCreateDescriptorPool(backendContext->device, &descriptorPoolCreateInfo, nullptr, &backendContext->descriptorPool) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

                                             
        backendContext->bindlessBase = (backendContext->maxEffectContexts * FFX_MAX_QUEUED_FRAMES * FFX_MAX_RESOURCE_COUNT * 2);

                                          
        {
                            
            VkPhysicalDeviceProperties physicalDeviceProperties = {};
            VulkanWrapper().vkGetPhysicalDeviceProperties(backendContext->physicalDevice, &physicalDeviceProperties);
            backendContext->uniformBufferAlignment = physicalDeviceProperties.limits.minUniformBufferOffsetAlignment;

            backendContext->uniformBufferSize = FFX_ALIGN_UP(FFX_BUFFER_SIZE, backendContext->uniformBufferAlignment) * backendContext->maxEffectContexts *
                                                FFX_MAX_PASS_COUNT * FFX_MAX_QUEUED_FRAMES;

            backendContext->gpuVendorId = static_cast<FfxGpuVendorId>(physicalDeviceProperties.vendorID);

            VkBufferCreateInfo bufferInfo = {};
            bufferInfo.sType              = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
            bufferInfo.size               = static_cast<VkDeviceSize>(backendContext->uniformBufferSize);
            bufferInfo.usage              = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
            bufferInfo.sharingMode        = VK_SHARING_MODE_EXCLUSIVE;

            if (VulkanWrapper().vkCreateBuffer(backendContext->device, &bufferInfo, NULL, &backendContext->uniformBuffer) != VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }

                                                            
            VkMemoryRequirements memRequirements = {};
            VulkanWrapper().vkGetBufferMemoryRequirements(backendContext->device, backendContext->uniformBuffer, &memRequirements);

                                         
            backendContext->uniformBufferAlignment = memRequirements.alignment;

            VkMemoryPropertyFlags requiredMemoryProperties = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

            VkMemoryAllocateInfo allocInfo{};
            allocInfo.sType          = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
            allocInfo.allocationSize = backendContext->uniformBufferSize;
            allocInfo.memoryTypeIndex =
                findMemoryTypeIndex(backendContext, memRequirements, requiredMemoryProperties, backendContext->uniformBufferMemoryProperties);

            if (allocInfo.memoryTypeIndex == UINT32_MAX)
            {
                requiredMemoryProperties = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
                allocInfo.memoryTypeIndex =
                    findMemoryTypeIndex(backendContext, memRequirements, requiredMemoryProperties, backendContext->uniformBufferMemoryProperties);

                if (allocInfo.memoryTypeIndex == UINT32_MAX)
                {
                    return FFX_ERROR_BACKEND_API_ERROR;
                }
            }

            VkResult result = VulkanWrapper().vkAllocateMemory(backendContext->device, &allocInfo, nullptr, &backendContext->uniformBufferMemory);

            if (result != VK_SUCCESS)
            {
                switch (result)
                {
                case (VK_ERROR_OUT_OF_HOST_MEMORY):
                case (VK_ERROR_OUT_OF_DEVICE_MEMORY):
                    return FFX_ERROR_OUT_OF_MEMORY;
                default:
                    return FFX_ERROR_BACKEND_API_ERROR;
                }
            }

                                   
            if (VulkanWrapper().vkMapMemory(
                    backendContext->device, backendContext->uniformBufferMemory, 0, backendContext->uniformBufferSize, 0, &backendContext->uniformBufferMem) !=
                VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }

            if (VulkanWrapper().vkBindBufferMemory(backendContext->device, backendContext->uniformBuffer, backendContext->uniformBufferMemory, 0) != VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }
        }
    }

                              
    ++backendContext->refCount;

                                  
    for (uint32_t i = 0; i < backendContext->maxEffectContexts; ++i)
    {
        if (!backendContext->pEffectContexts[i].active)
        {
            *effectContextId = i;

                                           
            BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[i];
            effectContext.active                            = true;
            effectContext.effectId                          = effect;

            effectContext.nextStaticResource     = (i * FFX_MAX_RESOURCE_COUNT) + 1;
            effectContext.nextDynamicResource    = getDynamicResourcesStartIndex(i);
            effectContext.nextStaticResourceView = (i * FFX_MAX_QUEUED_FRAMES * FFX_MAX_RESOURCE_COUNT * 2);
            for (uint32_t frameIndex = 0; frameIndex < FFX_MAX_QUEUED_FRAMES; ++frameIndex)
            {
                effectContext.nextDynamicResourceView[frameIndex] = getDynamicResourceViewsStartIndex(i, frameIndex);
            }
            effectContext.nextPipelineLayout = (i * FFX_MAX_PASS_COUNT);
            effectContext.frameIndex         = 0;

            if (bindlessConfig)
            {
                effectContext.bindlessTextureSrvHeapStart = backendContext->bindlessBase;
                effectContext.bindlessTextureSrvHeapSize  = bindlessConfig->maxTextureSrvs;

                backendContext->bindlessBase += bindlessConfig->maxTextureSrvs;

                effectContext.bindlessBufferSrvHeapSize = bindlessConfig->maxBufferSrvs;

                effectContext.bindlessTextureUavHeapStart = backendContext->bindlessBase;
                effectContext.bindlessTextureUavHeapSize  = bindlessConfig->maxTextureUavs;

                backendContext->bindlessBase += bindlessConfig->maxTextureUavs;

                effectContext.bindlessBufferUavHeapSize = bindlessConfig->maxBufferUavs;

                                                                                
                VkDescriptorPoolCreateInfo descriptorPoolCreateInfo = {};
                VkDescriptorPoolSize       poolSizes[3];

                uint32_t poolSizeCount = 0;

                if (bindlessConfig->maxTextureSrvs > 0)
                {
                    VkDescriptorPoolSize& poolSize = poolSizes[poolSizeCount++];

                    poolSize.type            = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
                    poolSize.descriptorCount = bindlessConfig->maxTextureSrvs;
                }

                if (bindlessConfig->maxTextureUavs > 0)
                {
                    VkDescriptorPoolSize& poolSize = poolSizes[poolSizeCount++];

                    poolSize.type            = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
                    poolSize.descriptorCount = bindlessConfig->maxTextureUavs;
                }

                if (bindlessConfig->maxBufferSrvs > 0 || bindlessConfig->maxBufferUavs > 0)
                {
                    VkDescriptorPoolSize& poolSize = poolSizes[poolSizeCount++];

                    poolSize.type            = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
                    poolSize.descriptorCount = bindlessConfig->maxBufferSrvs + bindlessConfig->maxBufferUavs;
                }

                descriptorPoolCreateInfo.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
                descriptorPoolCreateInfo.pNext         = nullptr;
                descriptorPoolCreateInfo.flags         = 0;
                descriptorPoolCreateInfo.poolSizeCount = poolSizeCount;
                descriptorPoolCreateInfo.pPoolSizes    = poolSizes;
                descriptorPoolCreateInfo.maxSets       = poolSizeCount;

                if (VulkanWrapper().vkCreateDescriptorPool(backendContext->device, &descriptorPoolCreateInfo, nullptr, &effectContext.bindlessDescriptorPool) !=
                    VK_SUCCESS)
                {
                    return FFX_ERROR_BACKEND_API_ERROR;
                }

                                                                                
                if (bindlessConfig->maxTextureSrvs > 0)
                {
                    VkDescriptorSetLayoutBinding binding = {
                        0, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, bindlessConfig->maxTextureSrvs, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};

                    VkDescriptorBindingFlags bindingFlags[] = {VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT};

                    VkDescriptorSetLayoutBindingFlagsCreateInfo setLayoutBindingFlags = {};

                    setLayoutBindingFlags.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO;
                    setLayoutBindingFlags.bindingCount  = 1;
                    setLayoutBindingFlags.pBindingFlags = bindingFlags;

                    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
                    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
                    layoutInfo.pNext                           = &setLayoutBindingFlags;
                    layoutInfo.bindingCount                    = 1;
                    layoutInfo.pBindings                       = &binding;

                    if (VulkanWrapper().vkCreateDescriptorSetLayout(
                            backendContext->device, &layoutInfo, nullptr, &effectContext.bindlessTextureSrvDescriptorSetLayout) != VK_SUCCESS)
                    {
                        return FFX_ERROR_BACKEND_API_ERROR;
                    }

                                              
                    VkDescriptorSetAllocateInfo setAllocateInfo = {};
                    setAllocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
                    setAllocateInfo.descriptorPool              = effectContext.bindlessDescriptorPool;
                    setAllocateInfo.descriptorSetCount          = 1;
                    setAllocateInfo.pSetLayouts                 = &effectContext.bindlessTextureSrvDescriptorSetLayout;

                    VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &setAllocateInfo, &effectContext.bindlessTextureSrvDescriptorSet);
                }

                                                                               
                if (bindlessConfig->maxBufferSrvs > 0)
                {
                    VkDescriptorSetLayoutBinding binding = {
                        0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, bindlessConfig->maxBufferSrvs, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};

                    VkDescriptorBindingFlags bindingFlags[] = {VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT};

                    VkDescriptorSetLayoutBindingFlagsCreateInfo setLayoutBindingFlags = {};

                    setLayoutBindingFlags.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO;
                    setLayoutBindingFlags.bindingCount  = 1;
                    setLayoutBindingFlags.pBindingFlags = bindingFlags;

                    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
                    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
                    layoutInfo.pNext                           = &setLayoutBindingFlags;
                    layoutInfo.bindingCount                    = 1;
                    layoutInfo.pBindings                       = &binding;

                    if (VulkanWrapper().vkCreateDescriptorSetLayout(
                            backendContext->device, &layoutInfo, nullptr, &effectContext.bindlessBufferSrvDescriptorSetLayout) != VK_SUCCESS)
                    {
                        return FFX_ERROR_BACKEND_API_ERROR;
                    }

                                              
                    VkDescriptorSetAllocateInfo setAllocateInfo = {};
                    setAllocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
                    setAllocateInfo.descriptorPool              = effectContext.bindlessDescriptorPool;
                    setAllocateInfo.descriptorSetCount          = 1;
                    setAllocateInfo.pSetLayouts                 = &effectContext.bindlessBufferSrvDescriptorSetLayout;

                    VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &setAllocateInfo, &effectContext.bindlessBufferSrvDescriptorSet);
                }

                                                                                
                if (bindlessConfig->maxTextureUavs > 0)
                {
                    VkDescriptorSetLayoutBinding binding = {
                        0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, bindlessConfig->maxTextureUavs, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};

                    VkDescriptorBindingFlags bindingFlags[] = {VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT};

                    VkDescriptorSetLayoutBindingFlagsCreateInfo setLayoutBindingFlags = {};

                    setLayoutBindingFlags.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO;
                    setLayoutBindingFlags.bindingCount  = 1;
                    setLayoutBindingFlags.pBindingFlags = bindingFlags;

                    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
                    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
                    layoutInfo.pNext                           = &setLayoutBindingFlags;
                    layoutInfo.bindingCount                    = 1;
                    layoutInfo.pBindings                       = &binding;

                    if (VulkanWrapper().vkCreateDescriptorSetLayout(
                            backendContext->device, &layoutInfo, nullptr, &effectContext.bindlessTextureUavDescriptorSetLayout) != VK_SUCCESS)
                    {
                        return FFX_ERROR_BACKEND_API_ERROR;
                    }

                                              
                    VkDescriptorSetAllocateInfo setAllocateInfo = {};
                    setAllocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
                    setAllocateInfo.descriptorPool              = effectContext.bindlessDescriptorPool;
                    setAllocateInfo.descriptorSetCount          = 1;
                    setAllocateInfo.pSetLayouts                 = &effectContext.bindlessTextureUavDescriptorSetLayout;

                    VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &setAllocateInfo, &effectContext.bindlessTextureUavDescriptorSet);
                }

                                                                               
                if (bindlessConfig->maxBufferUavs > 0)
                {
                    VkDescriptorSetLayoutBinding binding = {
                        0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, bindlessConfig->maxBufferUavs, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};

                    VkDescriptorBindingFlags bindingFlags[] = {VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT};

                    VkDescriptorSetLayoutBindingFlagsCreateInfo setLayoutBindingFlags = {};

                    setLayoutBindingFlags.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO;
                    setLayoutBindingFlags.bindingCount  = 1;
                    setLayoutBindingFlags.pBindingFlags = bindingFlags;

                    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
                    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
                    layoutInfo.pNext                           = &setLayoutBindingFlags;
                    layoutInfo.bindingCount                    = 1;
                    layoutInfo.pBindings                       = &binding;

                    if (VulkanWrapper().vkCreateDescriptorSetLayout(
                            backendContext->device, &layoutInfo, nullptr, &effectContext.bindlessBufferUavDescriptorSetLayout) != VK_SUCCESS)
                    {
                        return FFX_ERROR_BACKEND_API_ERROR;
                    }

                                              
                    VkDescriptorSetAllocateInfo setAllocateInfo = {};
                    setAllocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
                    setAllocateInfo.descriptorPool              = effectContext.bindlessDescriptorPool;
                    setAllocateInfo.descriptorSetCount          = 1;
                    setAllocateInfo.pSetLayouts                 = &effectContext.bindlessBufferUavDescriptorSetLayout;

                    VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &setAllocateInfo, &effectContext.bindlessBufferUavDescriptorSet);
                }
            }
            else
            {
                effectContext.bindlessTextureSrvHeapStart = 0;
                effectContext.bindlessTextureSrvHeapSize  = 0;
                effectContext.bindlessBufferSrvHeapSize   = 0;
                effectContext.bindlessTextureUavHeapStart = 0;
                effectContext.bindlessTextureUavHeapSize  = 0;
                effectContext.bindlessBufferUavHeapSize   = 0;
            }

            break;
        }
    }

    return FFX_OK;
}

FfxErrorCode GetDeviceCapabilitiesVK(FfxInterface* backendInterface, FfxDeviceCapabilities* deviceCapabilities)
{
    nss_trace("backend: GetDeviceCapabilities");
    FFX_ASSERT(backendInterface);
    FFX_ASSERT(deviceCapabilities);

                                   
    if (backendInterface->devCapInitialized)
    {
        if (deviceCapabilities != &backendInterface->deviceCapabilities)
        {
            memcpy(deviceCapabilities, &backendInterface->deviceCapabilities, sizeof(FfxDeviceCapabilities));
        }
        return FFX_OK;
    }

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    FFX_ASSERT(backendContext);
    if (backendContext->physicalDevice == VK_NULL_HANDLE)
    {
                                                                
        return FFX_OK;
    }

    memset(deviceCapabilities, 0, sizeof(FfxDeviceCapabilities));
                                                      
    deviceCapabilities->maximumSupportedShaderModel = FFX_SHADER_MODEL_5_1;
                                                                                                   
    deviceCapabilities->waveLaneCountMin = 16;
    deviceCapabilities->waveLaneCountMax = 16;

                                      

    for (uint32_t i = 0; i < backendContext->numDeviceExtensions; i++)
    {
        const char* extensionName = backendContext->extensionProperties[i].extensionName;

        if (strcmp(extensionName, VK_EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME) == 0)
        {
                                                                        
            VkPhysicalDeviceSubgroupSizeControlProperties subgroupSizeControlProperties = {};
            subgroupSizeControlProperties.sType                                         = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES;

            VkPhysicalDeviceProperties2 deviceProperties2 = {};
            deviceProperties2.sType                       = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
            deviceProperties2.pNext                       = &subgroupSizeControlProperties;
            VulkanWrapper().vkGetPhysicalDeviceProperties2(backendContext->physicalDevice, &deviceProperties2);

            deviceCapabilities->waveLaneCountMin = subgroupSizeControlProperties.minSubgroupSize;
            deviceCapabilities->waveLaneCountMax = subgroupSizeControlProperties.maxSubgroupSize;
        }
        else if (strcmp(extensionName, VK_KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME) == 0)
        {
                                     
            VkPhysicalDeviceShaderFloat16Int8Features shaderFloat16Int8Features = {};
            shaderFloat16Int8Features.sType                                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &shaderFloat16Int8Features;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);

            deviceCapabilities->fp16Supported = (bool)shaderFloat16Int8Features.shaderFloat16;
                                                                                                                         
            if (getenv("NFRU_NO_FP16") && atoi(getenv("NFRU_NO_FP16")) != 0)
                deviceCapabilities->fp16Supported = false;
        }
        else if (strcmp(extensionName, VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME) == 0)
        {
                                            
            VkPhysicalDeviceAccelerationStructureFeaturesKHR accelerationStructureFeatures = {};
            accelerationStructureFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &accelerationStructureFeatures;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);

            deviceCapabilities->raytracingSupported = (bool)accelerationStructureFeatures.accelerationStructure;
        }
        else if (strcmp(extensionName, VK_AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME) == 0)
        {
                                                
            VkPhysicalDeviceCoherentMemoryFeaturesAMD coherentMemoryFeatures = {};
            coherentMemoryFeatures.sType                                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COHERENT_MEMORY_FEATURES_AMD;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &coherentMemoryFeatures;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);

            deviceCapabilities->deviceCoherentMemorySupported = (bool)coherentMemoryFeatures.deviceCoherentMemory;
        }
        else if (strcmp(extensionName, VK_KHR_DEDICATED_ALLOCATION_EXTENSION_NAME) == 0)
        {
                                                                
            deviceCapabilities->dedicatedAllocationSupported = true;
        }
        else if (strcmp(extensionName, VK_AMD_BUFFER_MARKER_EXTENSION_NAME) == 0)
        {
                                                                
            deviceCapabilities->bufferMarkerSupported = true;
        }
        else if (strcmp(extensionName, VK_KHR_SYNCHRONIZATION_2_EXTENSION_NAME) == 0)
        {
                                                         
            VkPhysicalDeviceSynchronization2FeaturesKHR synchronizationFeatures = {};
            synchronizationFeatures.sType                                       = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &synchronizationFeatures;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);

            deviceCapabilities->extendedSynchronizationSupported = (bool)synchronizationFeatures.synchronization2;
        }
        else if (strcmp(extensionName, VK_EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME) == 0)
        {
                                                
            VkPhysicalDeviceDescriptorIndexingFeatures descriptorIndexingFeatures = {};
            descriptorIndexingFeatures.sType                                      = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &descriptorIndexingFeatures;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);

            deviceCapabilities->shaderStorageBufferArrayNonUniformIndexing = (bool)descriptorIndexingFeatures.shaderStorageBufferArrayNonUniformIndexing;
        }
        else if (strcmp(extensionName, VK_ARM_TENSORS_EXTENSION_NAME) == 0)
        {
                                                                
            deviceCapabilities->tensorSupported = true;

            VkPhysicalDeviceTensorPropertiesARM tensorProps = {};
            tensorProps.sType                               = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TENSOR_PROPERTIES_ARM;
            tensorProps.pNext                               = nullptr;

            VkPhysicalDeviceProperties2 deviceProperties2 = {};
            deviceProperties2.sType                       = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
            deviceProperties2.pNext                       = &tensorProps;

            VulkanWrapper().vkGetPhysicalDeviceProperties2(backendContext->physicalDevice, &deviceProperties2);

            deviceCapabilities->computeSupportTensor  = static_cast<bool>(tensorProps.shaderTensorSupportedStages & VK_SHADER_STAGE_COMPUTE_BIT);
            deviceCapabilities->fragmentSupportTensor = static_cast<bool>(tensorProps.shaderTensorSupportedStages & VK_SHADER_STAGE_FRAGMENT_BIT);
        }
        else if (strcmp(extensionName, VK_ARM_DATA_GRAPH_EXTENSION_NAME) == 0)
        {
                                                                
            deviceCapabilities->dataGraphSupported = true;
        }
        else if (strcmp(extensionName, VK_ARM_DATA_GRAPH_OPTICAL_FLOW_EXTENSION_NAME) == 0)
        {
                                                                              
            VkPhysicalDeviceDataGraphOpticalFlowFeaturesARM dataGraphOpticalFlowFeatures = {};
            dataGraphOpticalFlowFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DATA_GRAPH_OPTICAL_FLOW_FEATURES_ARM;

            VkPhysicalDeviceFeatures2 physicalDeviceFeatures2 = {};
            physicalDeviceFeatures2.sType                     = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
            physicalDeviceFeatures2.pNext                     = &dataGraphOpticalFlowFeatures;

            VulkanWrapper().vkGetPhysicalDeviceFeatures2(backendContext->physicalDevice, &physicalDeviceFeatures2);
            deviceCapabilities->dataGraphOFSupported = static_cast<bool>(dataGraphOpticalFlowFeatures.dataGraphOpticalFlow);

                                                                            
            if (deviceCapabilities->dataGraphOFSupported)
            {
                VkQueueFamilyDataGraphOpticalFlowPropertiesARM dataGraphOFProperties = {};
                dataGraphOFProperties.sType                                          = VK_STRUCTURE_TYPE_QUEUE_FAMILY_DATA_GRAPH_OPTICAL_FLOW_PROPERTIES_ARM;

                const auto queryQueueFamilyDataGraphOpProperties = VulkanWrapper().vkGetPhysicalDeviceQueueFamilyDataGraphEngineOperationPropertiesARM;
                if (!queryQueueFamilyDataGraphOpProperties)
                {
                                                                                      
                    deviceCapabilities->dataGraphOFSupported = false;
                    continue;
                }

                uint32_t queueFamilyCount = 0;
                VulkanWrapper().vkGetPhysicalDeviceQueueFamilyProperties(backendContext->physicalDevice, &queueFamilyCount, nullptr);

                for (uint32_t queueFamilyIndex = 0; queueFamilyIndex < queueFamilyCount; ++queueFamilyIndex)
                {
                    VkQueueFamilyDataGraphPropertiesARM queueFamilyDataGraphProperties = {};
                    queueFamilyDataGraphProperties.sType                               = VK_STRUCTURE_TYPE_QUEUE_FAMILY_DATA_GRAPH_PROPERTIES_ARM;
                    queueFamilyDataGraphProperties.engine.type                         = VK_PHYSICAL_DEVICE_DATA_GRAPH_PROCESSING_ENGINE_TYPE_DEFAULT_ARM;
                    queueFamilyDataGraphProperties.engine.isForeign                    = VK_FALSE;
                    queueFamilyDataGraphProperties.operation.operationType             = VK_PHYSICAL_DEVICE_DATA_GRAPH_OPERATION_TYPE_OPTICAL_FLOW_ARM;
                    std::strncpy(
                        queueFamilyDataGraphProperties.operation.name, "OpticalFlow", VK_MAX_PHYSICAL_DEVICE_DATA_GRAPH_OPERATION_SET_NAME_SIZE_ARM - 1);
                    queueFamilyDataGraphProperties.operation.version = 1;

                    const VkResult queryRes = queryQueueFamilyDataGraphOpProperties(backendContext->physicalDevice,
                                                                                    queueFamilyIndex,
                                                                                    &queueFamilyDataGraphProperties,
                                                                                    reinterpret_cast<VkBaseOutStructure*>(&dataGraphOFProperties));

                    if (queryRes == VK_SUCCESS)
                    {
                        deviceCapabilities->costSupported            = static_cast<bool>(dataGraphOFProperties.costSupported);
                        deviceCapabilities->hintSupported            = static_cast<bool>(dataGraphOFProperties.hintSupported);
                        deviceCapabilities->supportedHintGridSizes   = static_cast<uint32_t>(dataGraphOFProperties.supportedHintGridSizes);
                        deviceCapabilities->supportedOutputGridSizes = static_cast<uint32_t>(dataGraphOFProperties.supportedOutputGridSizes);
                        deviceCapabilities->dataGraphOFMinWidth      = dataGraphOFProperties.minWidth;
                        deviceCapabilities->dataGraphOFMinHeight     = dataGraphOFProperties.minHeight;
                        deviceCapabilities->dataGraphOFMaxWidth      = dataGraphOFProperties.maxWidth;
                        deviceCapabilities->dataGraphOFMaxHeight     = dataGraphOFProperties.maxHeight;
                        break;
                    }
                }
            }
        }
    }

    nss_trace("backend: capabilities: extension scan done");
    if (loadNssEngine())
    {
        deviceCapabilities->tensorSupported = true;
        deviceCapabilities->dataGraphSupported = true;
                                                                                                 
                                                                                                    
        deviceCapabilities->computeSupportTensor = false;
        deviceCapabilities->fragmentSupportTensor = false;
        if (!deviceCapabilities->dataGraphOFSupported)
        {
                                                                                                               
            deviceCapabilities->dataGraphOFSupported     = true;
            deviceCapabilities->hintSupported            = true;
            deviceCapabilities->costSupported            = false;
            deviceCapabilities->supportedHintGridSizes   = FFX_OPTICAL_FLOW_GRID_SIZE_4X4;
            deviceCapabilities->supportedOutputGridSizes = FFX_OPTICAL_FLOW_GRID_SIZE_4X4;
            deviceCapabilities->dataGraphOFMinWidth      = 32;
            deviceCapabilities->dataGraphOFMinHeight     = 32;
            deviceCapabilities->dataGraphOFMaxWidth      = 8192;
            deviceCapabilities->dataGraphOFMaxHeight     = 8192;
        }
    }

    backendInterface->devCapInitialized = true;
    if (deviceCapabilities != &backendInterface->deviceCapabilities)
    {
                           
        memcpy(&backendInterface->deviceCapabilities, deviceCapabilities, sizeof(FfxDeviceCapabilities));
        return FFX_OK;
    }

    return FFX_OK;
}

FfxErrorCode DestroyBackendContextVK(FfxInterface* backendInterface, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    FFX_ASSERT(backendContext->refCount > 0);

                                                     
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];
    if(auto* stats=static_cast<NfruGpuStats*>(effectContext.fiGpuStats)){stats->poll("FI");delete stats;effectContext.fiGpuStats=nullptr;}
    for (uint32_t currentStaticResourceIndex = effectContextId * FFX_MAX_RESOURCE_COUNT; currentStaticResourceIndex < effectContext.nextStaticResource;
         ++currentStaticResourceIndex)
    {
        if (backendContext->pResources[currentStaticResourceIndex].imageResource != VK_NULL_HANDLE)
        {
            FFX_ASSERT_MESSAGE(false,
                               "FFXInterface: Vulkan: SDK Resource was not destroyed prior to destroying the backend context. There is a resource leak.");
            FfxResourceInternal internalResource = {static_cast<int32_t>(currentStaticResourceIndex)};
            DestroyResourceVK(backendInterface, internalResource, effectContextId);
        }
    }

    for (uint32_t frameIndex = 0; frameIndex < FFX_MAX_QUEUED_FRAMES; ++frameIndex)
        destroyDynamicViews(backendContext, effectContextId, frameIndex);

                                      
    if (effectContext.bindlessTextureSrvDescriptorSetLayout)
    {
        VulkanWrapper().vkFreeDescriptorSets(backendContext->device, effectContext.bindlessDescriptorPool, 1, &effectContext.bindlessTextureSrvDescriptorSet);
        VulkanWrapper().vkDestroyDescriptorSetLayout(backendContext->device, effectContext.bindlessTextureSrvDescriptorSetLayout, VK_NULL_HANDLE);
        effectContext.bindlessTextureSrvDescriptorSetLayout = VK_NULL_HANDLE;
    }

    if (effectContext.bindlessBufferSrvDescriptorSetLayout)
    {
        VulkanWrapper().vkFreeDescriptorSets(backendContext->device, effectContext.bindlessDescriptorPool, 1, &effectContext.bindlessBufferSrvDescriptorSet);
        VulkanWrapper().vkDestroyDescriptorSetLayout(backendContext->device, effectContext.bindlessBufferSrvDescriptorSetLayout, VK_NULL_HANDLE);
        effectContext.bindlessBufferSrvDescriptorSetLayout = VK_NULL_HANDLE;
    }

    if (effectContext.bindlessTextureUavDescriptorSetLayout)
    {
        VulkanWrapper().vkFreeDescriptorSets(backendContext->device, effectContext.bindlessDescriptorPool, 1, &effectContext.bindlessTextureUavDescriptorSet);
        VulkanWrapper().vkDestroyDescriptorSetLayout(backendContext->device, effectContext.bindlessTextureUavDescriptorSetLayout, VK_NULL_HANDLE);
        effectContext.bindlessTextureUavDescriptorSetLayout = VK_NULL_HANDLE;
    }

    if (effectContext.bindlessBufferUavDescriptorSetLayout)
    {
        VulkanWrapper().vkFreeDescriptorSets(backendContext->device, effectContext.bindlessDescriptorPool, 1, &effectContext.bindlessBufferUavDescriptorSet);
        VulkanWrapper().vkDestroyDescriptorSetLayout(backendContext->device, effectContext.bindlessBufferUavDescriptorSetLayout, VK_NULL_HANDLE);
        effectContext.bindlessBufferUavDescriptorSetLayout = VK_NULL_HANDLE;
    }

    if (effectContext.bindlessDescriptorPool)
    {
        VulkanWrapper().vkDestroyDescriptorPool(backendContext->device, effectContext.bindlessDescriptorPool, VK_NULL_HANDLE);
        effectContext.bindlessTextureSrvDescriptorSetLayout = VK_NULL_HANDLE;
    }

                                         
    effectContext.nextStaticResource = 0;
    effectContext.active             = false;

                          
    --backendContext->refCount;

    if (!backendContext->refCount)
    {
                                   
        VulkanWrapper().vkDestroyDescriptorPool(backendContext->device, backendContext->descriptorPool, VK_NULL_HANDLE);
        backendContext->descriptorPool = VK_NULL_HANDLE;

                                                   
        VulkanWrapper().vkUnmapMemory(backendContext->device, backendContext->uniformBufferMemory);
        VulkanWrapper().vkFreeMemory(backendContext->device, backendContext->uniformBufferMemory, VK_NULL_HANDLE);
        VulkanWrapper().vkDestroyBuffer(backendContext->device, backendContext->uniformBuffer, VK_NULL_HANDLE);

        backendContext->device         = VK_NULL_HANDLE;
        backendContext->physicalDevice = VK_NULL_HANDLE;

        resetBackendContext(backendContext);
    }

    return FFX_OK;
}

static bool validateTensorSurfaceFormat(FfxInterface* backendInterface, FfxSurfaceFormat format)
{
    BackendContext_VK*         backendContext           = (BackendContext_VK*)backendInterface->scratchBuffer;
    VkPhysicalDeviceProperties physicalDeviceProperties = {};
    VulkanWrapper().vkGetPhysicalDeviceProperties(backendContext->physicalDevice, &physicalDeviceProperties);
    bool res = true;

                            
                                                             
                                                                                         
    if (physicalDeviceProperties.vendorID == 0x13B5)                      
    {
        switch (format)
        {
        case FFX_SURFACE_FORMAT_R8_UINT:
        case FFX_SURFACE_FORMAT_R8_SINT:
        case FFX_SURFACE_FORMAT_R16_UINT:
            res = true;
            break;
        default:
            res = false;
            break;
        }
    }

    return res;
}

static VkTensorTilingARM GetTensorTiling(const bool bufferAliased)
{
                                                                                              
                                                                                           
                                                
    return bufferAliased ? VK_TENSOR_TILING_LINEAR_ARM : VK_TENSOR_TILING_OPTIMAL_ARM;
}

FfxErrorCode CreateTensorResourceVK(FfxInterface*                       backendInterface,
                                    const FfxCreateResourceDescription* createResourceDescription,
                                    FfxUInt32                           effectContextId,
                                    FfxResourceInternal*                outResource)
{
    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    VkDevice                          device         = backendContext->device;

    FFX_ASSERT(VK_NULL_HANDLE != device);
    FFX_ASSERT(createResourceDescription);
    FFX_ASSERT(FFX_RESOURCE_TYPE_TENSOR == createResourceDescription->resourceDescription.type);

                                     
    FfxResourceDescription resourceDesc = createResourceDescription->resourceDescription;
    FFX_ASSERT(validateTensorSurfaceFormat(backendInterface, resourceDesc.format));

    outResource->alignedWidth = createResourceDescription->resourceDescription.width;
    FFX_ASSERT(effectContext.nextStaticResource + 1 < effectContext.nextDynamicResource);
    outResource->internalIndex                   = effectContext.nextStaticResource++;
    BackendContext_VK::Resource* backendResource = &backendContext->pResources[outResource->internalIndex];
    backendResource->undefined           = true;                                                                                                          
    backendResource->dynamic             = false;                                                                           
    backendResource->resourceDescription = resourceDesc;
    backendResource->allocationSize      = 0;

    const FfxResourceStates resourceState = ((createResourceDescription->initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED) &&
                                             (createResourceDescription->heapType != FFX_HEAP_TYPE_UPLOAD))
                                                ? FFX_RESOURCE_STATE_COPY_DEST
                                                : createResourceDescription->initialState;
    backendResource->initialState = resourceState;
    backendResource->currentState = resourceState;

#ifdef _DEBUG
    if (createResourceDescription->name)
    {
        strncpy(backendResource->resourceName, createResourceDescription->name, sizeof(backendResource->resourceName) - 1);
        backendResource->resourceName[sizeof(backendResource->resourceName) - 1] = '\0';
    }
#endif

    std::vector<int64_t> dimensions;

    FFX_ASSERT(createResourceDescription->resourceDescription.shapeSize <= 4);
    for (uint32_t i = 0; i < createResourceDescription->resourceDescription.shapeSize; i++)
    {
        switch (i)
        {
        case 0:
            dimensions.push_back(createResourceDescription->resourceDescription.batchSize);
            break;

        case 1:
            dimensions.push_back(createResourceDescription->resourceDescription.height);
            break;

        case 2:
            dimensions.push_back(createResourceDescription->resourceDescription.width);
            break;

        case 3:
            dimensions.push_back(createResourceDescription->resourceDescription.channel);
            break;

        default:
            break;
        }
    }

    if (loadNssEngine() || VulkanWrapper().vkCreateTensorARM == nullptr)
    {
        const bool imageAliased = (createResourceDescription->resourceDescription.flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) == FFX_RESOURCE_FLAGS_IMAGE_ALIASED;
        
                                            
        VkDeviceSize tensorDataSize = 1;
        for (auto d : dimensions) {
            tensorDataSize *= (d > 0 ? static_cast<VkDeviceSize>(d) : 1);
        }
        FfxSurfaceFormat fmt = createResourceDescription->resourceDescription.format;
        if (fmt == FFX_SURFACE_FORMAT_R16_FLOAT || fmt == FFX_SURFACE_FORMAT_R16_UINT) tensorDataSize *= 2;
        else if (fmt == FFX_SURFACE_FORMAT_R32_FLOAT || fmt == FFX_SURFACE_FORMAT_R32_UINT) tensorDataSize *= 4;
        tensorDataSize = (tensorDataSize + 255) & ~((VkDeviceSize)255);

                                                            
        VkBufferCreateInfo bufferInfo = {VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        bufferInfo.size = tensorDataSize;
        bufferInfo.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        if (VulkanWrapper().vkCreateBuffer(device, &bufferInfo, nullptr, &backendResource->aliasedTensorBufferResource) != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;

        VkMemoryRequirements memReqs;
        VulkanWrapper().vkGetBufferMemoryRequirements(device, backendResource->aliasedTensorBufferResource, &memReqs);

        VkMemoryPropertyFlags memProps = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        if (allocateDeviceMemory(backendContext, memReqs, memProps, backendResource))
            return FFX_ERROR_BACKEND_API_ERROR;

        if (VulkanWrapper().vkBindBufferMemory(device, backendResource->aliasedTensorBufferResource, backendResource->deviceMemory, 0) != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;

                                                                                            
        if (imageAliased)
        {
            uint32_t channels = createResourceDescription->resourceDescription.channel;
            VkFormat aliasedFormat = ffxGetVkFormatForTensorAliasedImage(createResourceDescription->resourceDescription.format, channels);
            VkExtent3D imageExtent = {static_cast<uint32_t>(dimensions[2]), static_cast<uint32_t>(dimensions[1]), 1};

            VkImageCreateInfo imgInfo = {VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
            imgInfo.imageType = VK_IMAGE_TYPE_2D;
            imgInfo.format = aliasedFormat;
            imgInfo.extent = imageExtent;
            imgInfo.mipLevels = 1;
            imgInfo.arrayLayers = 1;
            imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
            imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
            imgInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_STORAGE_BIT;
            imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
            imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

            if (VulkanWrapper().vkCreateImage(device, &imgInfo, nullptr, &backendResource->aliasedTensorImageResource) != VK_SUCCESS)
                return FFX_ERROR_BACKEND_API_ERROR;

            VkMemoryRequirements imgMemReqs;
            VulkanWrapper().vkGetImageMemoryRequirements(device, backendResource->aliasedTensorImageResource, &imgMemReqs);

            BackendContext_VK::Resource imgAllocResource{};
            if (allocateDeviceMemory(backendContext, imgMemReqs, memProps, &imgAllocResource))
                return FFX_ERROR_BACKEND_API_ERROR;

            if (VulkanWrapper().vkBindImageMemory(device, backendResource->aliasedTensorImageResource, imgAllocResource.deviceMemory, 0) != VK_SUCCESS)
                return FFX_ERROR_BACKEND_API_ERROR;

            FFX_ASSERT(effectContext.nextStaticResourceView + 1 < effectContext.nextDynamicResourceView[0]);
            backendResource->srvViewIndex = effectContext.nextStaticResourceView++;

            VkImageViewCreateInfo viewInfo = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
            viewInfo.image = backendResource->aliasedTensorImageResource;
            viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
            viewInfo.format = aliasedFormat;
            viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            viewInfo.subresourceRange.baseMipLevel = 0;
            viewInfo.subresourceRange.levelCount = 1;
            viewInfo.subresourceRange.baseArrayLayer = 0;
            viewInfo.subresourceRange.layerCount = 1;

            if (VulkanWrapper().vkCreateImageView(device, &viewInfo, nullptr, &backendContext->pResourceViews[backendResource->srvViewIndex].imageView) != VK_SUCCESS)
                return FFX_ERROR_BACKEND_API_ERROR;
        }

        backendResource->tensorResource = VK_NULL_HANDLE;
        backendResource->tensorViewIndex = -1;
        backendResource->bridgeTensor = true;

        const uint32_t shapeSize = createResourceDescription->resourceDescription.shapeSize;
        outResource->alignedWidth = shapeSize >= 3 ? static_cast<uint32_t>(dimensions[2]) : static_cast<uint32_t>(dimensions.back());

        return FFX_OK;
    }
    const bool imageAliased  = (createResourceDescription->resourceDescription.flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) == FFX_RESOURCE_FLAGS_IMAGE_ALIASED;
    const bool bufferAliased = (createResourceDescription->resourceDescription.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED;
                                                                                                                                             
    FFX_ASSERT_MESSAGE(!imageAliased || !bufferAliased, "Cant alias tensor both as image and buffer!");

    VkTensorUsageFlagsARM tensorUsage = VK_TENSOR_USAGE_DATA_GRAPH_BIT_ARM;
    if (imageAliased)
    {
                                                                              
                                                                  
        tensorUsage |= VK_TENSOR_USAGE_IMAGE_ALIASING_BIT_ARM;
    }

    const VkTensorDescriptionARM tensorDescription = {VK_STRUCTURE_TYPE_TENSOR_DESCRIPTION_ARM,
                                                      nullptr,
                                                      GetTensorTiling(bufferAliased),
                                                      ffxGetVkFormatFromSurfaceFormat(createResourceDescription->resourceDescription.format),
                                                      createResourceDescription->resourceDescription.shapeSize,
                                                      dimensions.data(),
                                                      nullptr,                                        
                                                      tensorUsage};

    const VkTensorCreateInfoARM tensorCreateInfo = {
        VK_STRUCTURE_TYPE_TENSOR_CREATE_INFO_ARM,
        nullptr,
        0,          
        &tensorDescription,
        VK_SHARING_MODE_EXCLUSIVE,
        0,                                
        nullptr,                        
    };

    if (VulkanWrapper().vkCreateTensorARM(device, &tensorCreateInfo, nullptr, &backendResource->tensorResource))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                   
    uint32_t channels = createResourceDescription->resourceDescription.channel;
    VkFormat aliasedFormat =
        imageAliased ? ffxGetVkFormatForTensorAliasedImage(createResourceDescription->resourceDescription.format, channels) : VK_FORMAT_UNDEFINED;
    if (imageAliased)
    {
        VkExtent3D              imageOutExtent     = {static_cast<uint32_t>(dimensions[2]), static_cast<uint32_t>(dimensions[1]), 1};
        const VkImageCreateInfo imageOutCreateInfo = {
            VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            nullptr,
            0,          
            VK_IMAGE_TYPE_2D,
            aliasedFormat,
            imageOutExtent,
            1,                                    
            1,                                      
            VK_SAMPLE_COUNT_1_BIT,              
            VK_IMAGE_TILING_OPTIMAL,                                            
                                                                                                                                                 
            (VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TENSOR_ALIASING_BIT_ARM |                                                     
             VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT),
            VK_SHARING_MODE_EXCLUSIVE,
            0,                                
            nullptr,                        
            VK_IMAGE_LAYOUT_UNDEFINED};

        if (VulkanWrapper().vkCreateImage(device, &imageOutCreateInfo, nullptr, &backendResource->aliasedTensorImageResource))
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

#ifdef _DEBUG
                                                                                                                                                                     
#endif

    const VkTensorMemoryRequirementsInfoARM tensorMemInfo = {VK_STRUCTURE_TYPE_TENSOR_MEMORY_REQUIREMENTS_INFO_ARM, nullptr, backendResource->tensorResource};

    VkMemoryRequirements2 tensorMemreqs;
    tensorMemreqs.sType = VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2;
    tensorMemreqs.pNext = nullptr;
    VulkanWrapper().vkGetTensorMemoryRequirementsARM(device, &tensorMemInfo, &tensorMemreqs);

                                                                                        
    const VkDeviceSize tensorDataSize = tensorMemreqs.memoryRequirements.size;

    VkDeviceSize memoryOffset = 0u;

                                   
    if (imageAliased)
    {
        const VkImageMemoryRequirementsInfo2 imageMemInfo = {
            VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2, nullptr, backendResource->aliasedTensorImageResource};
        VkMemoryRequirements2 imageMemReqs = {VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2, nullptr, {}};
        VulkanWrapper().vkGetImageMemoryRequirements2(device, &imageMemInfo, &imageMemReqs);

        constexpr VkImageSubresource imageOutSubresource = {
            VK_IMAGE_ASPECT_COLOR_BIT,
            0,             
            0                
        };
        VkSubresourceLayout imageOutSubresourceLayout{};
        VulkanWrapper().vkGetImageSubresourceLayout(device, backendResource->aliasedTensorImageResource, &imageOutSubresource, &imageOutSubresourceLayout);

                                                                                                       
        memoryOffset                          = imageOutSubresourceLayout.offset;
        tensorMemreqs.memoryRequirements.size = FFX_MAXIMUM(imageMemReqs.memoryRequirements.size, tensorMemreqs.memoryRequirements.size + memoryOffset);
        tensorMemreqs.memoryRequirements.memoryTypeBits = imageMemReqs.memoryRequirements.memoryTypeBits & tensorMemreqs.memoryRequirements.memoryTypeBits;
    }

    VkMemoryPropertyFlags memoryProperties = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

    if (allocateDeviceMemory(backendContext, tensorMemreqs.memoryRequirements, memoryProperties, backendResource))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    const VkBindTensorMemoryInfoARM tensorBindInfo = {
        VK_STRUCTURE_TYPE_BIND_TENSOR_MEMORY_INFO_ARM, nullptr, backendResource->tensorResource, backendResource->deviceMemory, memoryOffset};

    if (VulkanWrapper().vkBindTensorMemoryARM(device, 1, &tensorBindInfo))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    if (imageAliased)
    {
        const VkBindImageMemoryInfo bindImageMemoryInfo = {
            VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO, nullptr, backendResource->aliasedTensorImageResource, backendResource->deviceMemory, 0};

        if (VulkanWrapper().vkBindImageMemory2(device, 1, &bindImageMemoryInfo))
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    const VkTensorViewCreateInfoARM tensorViewCreateInfo = {VK_STRUCTURE_TYPE_TENSOR_VIEW_CREATE_INFO_ARM,
                                                            nullptr,
                                                            0,          
                                                            backendResource->tensorResource,
                                                            ffxGetVkFormatFromSurfaceFormat(createResourceDescription->resourceDescription.format)};

    FFX_ASSERT_MESSAGE(effectContext.nextStaticResourceView + 1 < effectContext.nextDynamicResourceView[0],
                       "ffxInterface: Vulkan: We've run out of resource views. Please increase the size.");
    backendResource->tensorViewIndex = effectContext.nextStaticResourceView++;

    if (VulkanWrapper().vkCreateTensorViewARM(
            device, &tensorViewCreateInfo, nullptr, &backendContext->pResourceViews[backendResource->tensorViewIndex].tensorView))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    if (imageAliased)
    {
                                                               
        FFX_ASSERT_MESSAGE(effectContext.nextStaticResourceView + 1 < effectContext.nextDynamicResourceView[0],
                           "FFXInterface: Vulkan: We've run out of resource views. Please increase the size.");
        backendResource->srvViewIndex = effectContext.nextStaticResourceView++;

        VkImageViewCreateInfo imageViewCreateInfo = {};
        imageViewCreateInfo.sType                 = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        imageViewCreateInfo.pNext                 = nullptr;

                                                                                                                                             
        imageViewCreateInfo.viewType                        = VK_IMAGE_VIEW_TYPE_2D;
        imageViewCreateInfo.image                           = backendResource->aliasedTensorImageResource;
        imageViewCreateInfo.format                          = aliasedFormat;
        imageViewCreateInfo.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.subresourceRange.aspectMask     = getImageAspect(backendResource->resourceDescription.usage);
        imageViewCreateInfo.subresourceRange.baseMipLevel   = 0;
        imageViewCreateInfo.subresourceRange.levelCount     = backendResource->resourceDescription.mipCount;
        imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
        imageViewCreateInfo.subresourceRange.layerCount     = VK_REMAINING_ARRAY_LAYERS;

        VkImageViewUsageCreateInfo imageViewUsageCreateInfo = {};
        setupImageViewForSRV(imageViewCreateInfo, imageViewUsageCreateInfo, backendResource->resourceDescription);

                                                                           
        if (VulkanWrapper().vkCreateImageView(
                backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->srvViewIndex].imageView) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
#ifdef _DEBUG
        setVKObjectName(backendContext->device,
                        VK_OBJECT_TYPE_IMAGE_VIEW,
                        (uint64_t)backendContext->pResourceViews[backendResource->srvViewIndex].imageView,
                        backendResource->resourceName);
#endif

                                                                       
        if (FFX_CONTAINS_FLAG(backendResource->resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
        {
            const int32_t uavResourceViewCount = backendResource->resourceDescription.mipCount;
            FFX_ASSERT(effectContext.nextStaticResourceView + uavResourceViewCount < effectContext.nextDynamicResourceView[0]);

            backendResource->uavViewIndex = effectContext.nextStaticResourceView;
            backendResource->uavViewCount = uavResourceViewCount;
            imageViewCreateInfo.format    = aliasedFormat;

            for (uint32_t mip = 0; mip < backendResource->resourceDescription.mipCount; ++mip)
            {
                imageViewCreateInfo.subresourceRange.levelCount   = 1;
                imageViewCreateInfo.subresourceRange.baseMipLevel = mip;

                if (VulkanWrapper().vkCreateImageView(
                        backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView) !=
                    VK_SUCCESS)
                {
                    return FFX_ERROR_BACKEND_API_ERROR;
                }
#ifdef _DEBUG
                setVKObjectName(backendContext->device,
                                VK_OBJECT_TYPE_IMAGE_VIEW,
                                (uint64_t)backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView,
                                backendResource->resourceName);
#endif
            }

            effectContext.nextStaticResourceView += uavResourceViewCount;
        }
    }

    if (bufferAliased || backendResource->aliasedTensorBufferResource == VK_NULL_HANDLE)
    {
                                                                    
                                                                                                              
        VkBufferCreateInfo bufferInfo = {};
        bufferInfo.sType              = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size               = tensorDataSize;
        bufferInfo.usage              = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
        bufferInfo.sharingMode        = VK_SHARING_MODE_EXCLUSIVE;

        if (VulkanWrapper().vkCreateBuffer(device, &bufferInfo, nullptr, &backendResource->aliasedTensorBufferResource) != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;

        if (VulkanWrapper().vkBindBufferMemory(device, backendResource->aliasedTensorBufferResource, backendResource->deviceMemory, memoryOffset) != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;

                                                                               
        const uint32_t shapeSize  = createResourceDescription->resourceDescription.shapeSize;
        outResource->alignedWidth = shapeSize >= 3 ? static_cast<uint32_t>(dimensions[2]) : static_cast<uint32_t>(dimensions.back());
    }

#ifdef _DEBUG
                                                                                                                                                                                                                      
#endif

    return FFX_OK;
}

                                                                              
FfxErrorCode CreateResourceVK(FfxInterface*                       backendInterface,
                              const FfxCreateResourceDescription* createResourceDescription,
                              FfxUInt32                           effectContextId,
                              FfxResourceInternal*                outResource)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != createResourceDescription);
    FFX_ASSERT(NULL != outResource);
    FFX_ASSERT_MESSAGE(createResourceDescription->initData.type != FFX_RESOURCE_INIT_DATA_TYPE_INVALID,
                       "InitData type cannot be FFX_RESOURCE_INIT_DATA_TYPE_INVALID. Please explicitly specify the resource initialization type.");

    if (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR)
        return CreateTensorResourceVK(backendInterface, createResourceDescription, effectContextId, outResource);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];
    VkDevice                          vkDevice       = backendContext->device;

    FFX_ASSERT(VK_NULL_HANDLE != vkDevice);

    VkMemoryPropertyFlags requiredMemoryProperties;

    switch (createResourceDescription->heapType)
    {
    case FFX_HEAP_TYPE_DEFAULT:
        requiredMemoryProperties = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        break;
    case FFX_HEAP_TYPE_UPLOAD:
    case FFX_HEAP_TYPE_READBACK:
        requiredMemoryProperties = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
        break;
    default:
        requiredMemoryProperties = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        break;
    }

                                     
    FfxResourceDescription resourceDesc = createResourceDescription->resourceDescription;

    if (resourceDesc.mipCount == 0)
    {
        resourceDesc.mipCount = (uint32_t)(
            1 + floor(log2(FFX_MAXIMUM(FFX_MAXIMUM(createResourceDescription->resourceDescription.width, createResourceDescription->resourceDescription.height),
                                       createResourceDescription->resourceDescription.depth))));
    }

    FFX_ASSERT(effectContext.nextStaticResource + 1 < effectContext.nextDynamicResource);
    outResource->internalIndex                   = effectContext.nextStaticResource++;
    BackendContext_VK::Resource* backendResource = &backendContext->pResources[outResource->internalIndex];
    backendResource->undefined           = true;                                                                                                          
    backendResource->dynamic             = false;                                                                           
    backendResource->resourceDescription = resourceDesc;
    backendResource->allocationSize      = 0;

    const auto& initData = createResourceDescription->initData;

    const FfxResourceStates resourceState =
        ((initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED) && (createResourceDescription->heapType != FFX_HEAP_TYPE_UPLOAD))
            ? FFX_RESOURCE_STATE_COPY_DEST
            : createResourceDescription->initialState;
    backendResource->initialState = resourceState;
    backendResource->currentState = resourceState;

#ifdef _DEBUG
    if (createResourceDescription->name)
    {
        strncpy(backendResource->resourceName, createResourceDescription->name, sizeof(backendResource->resourceName) - 1);
        backendResource->resourceName[sizeof(backendResource->resourceName) - 1] = '\0';
    }
#endif

    VkMemoryRequirements memRequirements = {};

    const bool createAliasedBuffer = (resourceDesc.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED;

    switch (createResourceDescription->resourceDescription.type)
    {
    case FFX_RESOURCE_TYPE_BUFFER:
    {
        VkBufferCreateInfo bufferInfo = {};
        bufferInfo.sType              = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size               = createResourceDescription->resourceDescription.width;
        bufferInfo.usage              = ffxGetVKBufferUsageFlagsFromResourceUsage(resourceDesc.usage);
        if(createResourceDescription->name&&!strcmp(createResourceDescription->name,"ArmFI_Diagnostics")) bufferInfo.usage|=VK_BUFFER_USAGE_TRANSFER_SRC_BIT|VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        bufferInfo.sharingMode        = VK_SHARING_MODE_EXCLUSIVE;

        if (initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED)
            bufferInfo.usage |= VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;

        if (resourceState == FFX_RESOURCE_STATE_COPY_SRC)
            bufferInfo.usage |= VK_BUFFER_USAGE_TRANSFER_SRC_BIT;

        if (resourceState == FFX_RESOURCE_STATE_COPY_DEST)
            bufferInfo.usage |= VK_BUFFER_USAGE_TRANSFER_DST_BIT;

        if (VulkanWrapper().vkCreateBuffer(backendContext->device, &bufferInfo, NULL, &backendResource->bufferResource) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

#ifdef _DEBUG
        setVKObjectName(backendContext->device, VK_OBJECT_TYPE_BUFFER, (uint64_t)backendResource->bufferResource, backendResource->resourceName);
#endif

        VulkanWrapper().vkGetBufferMemoryRequirements(backendContext->device, backendResource->bufferResource, &memRequirements);

                              
        FfxErrorCode errorCode = allocateDeviceMemory(backendContext, memRequirements, requiredMemoryProperties, backendResource);
        if (FFX_OK != errorCode)
            return errorCode;

        if (VulkanWrapper().vkBindBufferMemory(backendContext->device, backendResource->bufferResource, backendResource->deviceMemory, 0) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

                                                                                                        
        if (createResourceDescription->heapType == FFX_HEAP_TYPE_UPLOAD && initData.size > 0)
        {
                                                                                                                                   
            void* data = NULL;

            if (VulkanWrapper().vkMapMemory(backendContext->device, backendResource->deviceMemory, 0, initData.size, 0, &data) != VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }

            if (initData.type == FFX_RESOURCE_INIT_DATA_TYPE_BUFFER)
                memcpy(data, initData.buffer, initData.size);
            else if (initData.type == FFX_RESOURCE_INIT_DATA_TYPE_VALUE)
                memset(data, initData.value, initData.size);

                                                                
            if ((backendResource->memoryProperties & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) == 0)
            {
                VkMappedMemoryRange memoryRange = {};
                memoryRange.sType               = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
                memoryRange.memory              = backendResource->deviceMemory;
                memoryRange.size                = initData.size;

                VulkanWrapper().vkFlushMappedMemoryRanges(backendContext->device, 1, &memoryRange);
            }

            VulkanWrapper().vkUnmapMemory(backendContext->device, backendResource->deviceMemory);
            return FFX_OK;
        }

                                                                                                        
                                                                                                                                                  
                                                                                                                                                                      
        outResource->alignedWidth = createResourceDescription->resourceDescription.stride;

        break;
    }
    case FFX_RESOURCE_TYPE_TEXTURE1D:
    case FFX_RESOURCE_TYPE_TEXTURE2D:
    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
    {
        VkImageCreateInfo imageInfo = {};
        imageInfo.sType             = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        imageInfo.imageType         = ffxGetVKImageTypeFromResourceType(createResourceDescription->resourceDescription.type);
        imageInfo.extent.width      = createResourceDescription->resourceDescription.width;
        imageInfo.extent.height =
            createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE1D ? 1 : createResourceDescription->resourceDescription.height;
        imageInfo.extent.depth = (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE3D ||
                                  createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE_CUBE)
                                     ? createResourceDescription->resourceDescription.depth
                                     : 1;
        imageInfo.mipLevels   = backendResource->resourceDescription.mipCount;
        imageInfo.arrayLayers = (createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE1D ||
                                 createResourceDescription->resourceDescription.type == FFX_RESOURCE_TYPE_TEXTURE2D)
                                    ? createResourceDescription->resourceDescription.depth
                                    : 1;
        imageInfo.format        = getVkFormatFromSurfaceFormatAndUsage(createResourceDescription->resourceDescription.format, resourceDesc.usage);
        imageInfo.tiling        = createAliasedBuffer ? VK_IMAGE_TILING_LINEAR : VK_IMAGE_TILING_OPTIMAL;                                                     
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage         = getVKImageUsageFlagsFromResourceUsage(resourceDesc.usage);
        imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT;
        imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;

        if (FFX_CONTAINS_FLAG(resourceDesc.usage, FFX_RESOURCE_USAGE_UAV) && ffxIsSurfaceFormatSRGB(createResourceDescription->resourceDescription.format))
        {
            imageInfo.flags |= VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT;
            imageInfo.format = ffxGetVkFormatFromSurfaceFormat(ffxGetSurfaceFormatFromGamma(createResourceDescription->resourceDescription.format));
        }

        if (VulkanWrapper().vkCreateImage(backendContext->device, &imageInfo, nullptr, &backendResource->imageResource) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

#ifdef _DEBUG
        setVKObjectName(backendContext->device, VK_OBJECT_TYPE_IMAGE, (uint64_t)backendResource->imageResource, backendResource->resourceName);
#endif

        VulkanWrapper().vkGetImageMemoryRequirements(backendContext->device, backendResource->imageResource, &memRequirements);

                              
        FfxErrorCode errorCode = allocateDeviceMemory(backendContext, memRequirements, requiredMemoryProperties, backendResource);
        if (FFX_OK != errorCode)
            return errorCode;

        if (VulkanWrapper().vkBindImageMemory(backendContext->device, backendResource->imageResource, backendResource->deviceMemory, 0) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
        outResource->alignedWidth = createResourceDescription->resourceDescription.width;

        break;
    }
    default:
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Unsupported resource type creation requested.");
        break;
    }

                           
    switch (createResourceDescription->resourceDescription.type)
    {
    case FFX_RESOURCE_TYPE_BUFFER:
        break;
    case FFX_RESOURCE_TYPE_TEXTURE1D:
    case FFX_RESOURCE_TYPE_TEXTURE2D:
    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
    {
        FFX_ASSERT_MESSAGE(effectContext.nextStaticResourceView + 1 < effectContext.nextDynamicResourceView[0],
                           "FFXInterface: Vulkan: We've run out of resource views. Please increase the size.");
        backendResource->srvViewIndex = effectContext.nextStaticResourceView++;

        FfxResourceType       type                = createResourceDescription->resourceDescription.type;
        VkImageViewCreateInfo imageViewCreateInfo = {};
        imageViewCreateInfo.sType                 = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        imageViewCreateInfo.pNext                 = nullptr;

        bool requestArrayView = FFX_CONTAINS_FLAG(backendResource->resourceDescription.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

        switch (type)
        {
        case FFX_RESOURCE_TYPE_TEXTURE1D:
            imageViewCreateInfo.viewType =
                (backendResource->resourceDescription.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_1D_ARRAY : VK_IMAGE_VIEW_TYPE_1D;
            break;
        default:
        case FFX_RESOURCE_TYPE_TEXTURE2D:
            imageViewCreateInfo.viewType =
                (backendResource->resourceDescription.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_2D_ARRAY : VK_IMAGE_VIEW_TYPE_2D;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE3D:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_3D;
            break;
        }

        imageViewCreateInfo.image = backendResource->imageResource;
        imageViewCreateInfo.format =
            getVkFormatFromSurfaceFormatAndUsage(createResourceDescription->resourceDescription.format, backendResource->resourceDescription.usage);
        imageViewCreateInfo.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.subresourceRange.aspectMask     = getImageAspect(backendResource->resourceDescription.usage);
        imageViewCreateInfo.subresourceRange.baseMipLevel   = 0;
        imageViewCreateInfo.subresourceRange.levelCount     = backendResource->resourceDescription.mipCount;
        imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
        imageViewCreateInfo.subresourceRange.layerCount     = VK_REMAINING_ARRAY_LAYERS;

        VkImageViewUsageCreateInfo imageViewUsageCreateInfo = {};
        setupImageViewForSRV(imageViewCreateInfo, imageViewUsageCreateInfo, backendResource->resourceDescription);

                                                                           
        if (VulkanWrapper().vkCreateImageView(
                backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->srvViewIndex].imageView) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
#ifdef _DEBUG
        setVKObjectName(backendContext->device,
                        VK_OBJECT_TYPE_IMAGE_VIEW,
                        (uint64_t)backendContext->pResourceViews[backendResource->srvViewIndex].imageView,
                        backendResource->resourceName);
#endif

                                                                       
        if (FFX_CONTAINS_FLAG(backendResource->resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
        {
            const int32_t uavResourceViewCount = backendResource->resourceDescription.mipCount;
            FFX_ASSERT(effectContext.nextStaticResourceView + uavResourceViewCount < effectContext.nextDynamicResourceView[0]);

            backendResource->uavViewIndex = effectContext.nextStaticResourceView;
            backendResource->uavViewCount = uavResourceViewCount;

            imageViewCreateInfo.format =
                getVkFormatFromSurfaceFormatAndUsage(createResourceDescription->resourceDescription.format, backendResource->resourceDescription.usage);

            for (uint32_t mip = 0; mip < backendResource->resourceDescription.mipCount; ++mip)
            {
                imageViewCreateInfo.subresourceRange.levelCount   = 1;
                imageViewCreateInfo.subresourceRange.baseMipLevel = mip;

                if (VulkanWrapper().vkCreateImageView(
                        backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView) !=
                    VK_SUCCESS)
                {
                    return FFX_ERROR_BACKEND_API_ERROR;
                }
#ifdef _DEBUG
                setVKObjectName(backendContext->device,
                                VK_OBJECT_TYPE_IMAGE_VIEW,
                                (uint64_t)backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView,
                                backendResource->resourceName);
#endif
            }

            effectContext.nextStaticResourceView += uavResourceViewCount;
        }

        if (createAliasedBuffer)
        {
                                                                          
            VkImageSubresource  subResource{VK_IMAGE_ASPECT_COLOR_BIT, 0, 0};
            VkSubresourceLayout subResourceLayout;
            VulkanWrapper().vkGetImageSubresourceLayout(backendContext->device, backendResource->imageResource, &subResource, &subResourceLayout);
            outResource->alignedWidth =
                subResourceLayout.rowPitch / ffxGetBytesPerElementFromSurfaceFormat(createResourceDescription->resourceDescription.format);

                                                                                 
            VkBufferCreateInfo bufferInfo = {};
            bufferInfo.sType              = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
            bufferInfo.size               = subResourceLayout.size;
            bufferInfo.usage              = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
            bufferInfo.sharingMode        = VK_SHARING_MODE_EXCLUSIVE;

            if (VulkanWrapper().vkCreateBuffer(backendContext->device, &bufferInfo, NULL, &backendResource->aliasedBufferResource) != VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }

            if (VulkanWrapper().vkBindBufferMemory(backendContext->device, backendResource->aliasedBufferResource, backendResource->deviceMemory, 0) !=
                VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }
        }
        break;
    }
    default:
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Unsupported resource view type creation requested.");
        break;
    }

                                                      
    if (initData.type != FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED)
    {
        FfxResourceInternal          copySrc;
        FfxCreateResourceDescription uploadDesc = {*createResourceDescription};
        uploadDesc.heapType                     = FFX_HEAP_TYPE_UPLOAD;
        uploadDesc.resourceDescription.type     = FFX_RESOURCE_TYPE_BUFFER;
        uploadDesc.resourceDescription.width    = static_cast<uint32_t>(initData.size);
        uploadDesc.resourceDescription.usage    = FFX_RESOURCE_USAGE_READ_ONLY;
        uploadDesc.initialState                 = FFX_RESOURCE_STATE_GENERIC_READ;
        uploadDesc.initData                     = createResourceDescription->initData;

        backendInterface->fpCreateResource(backendInterface, &uploadDesc, effectContextId, &copySrc);

                               
        FfxGpuJobDescription copyJob = {FFX_GPU_JOB_COPY};
#ifdef FFX_DEBUG
        strncpy(copyJob.jobLabel, "Resource Initialization Copy", FFX_RESOURCE_NAME_SIZE - 1);
        copyJob.jobLabel[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
#endif
        copyJob.copyJobDescriptor.src       = copySrc;
        copyJob.copyJobDescriptor.dst       = *outResource;
        copyJob.copyJobDescriptor.srcOffset = 0;
        copyJob.copyJobDescriptor.dstOffset = 0;
        copyJob.copyJobDescriptor.size      = 0;

        backendInterface->fpScheduleGpuJob(backendInterface, &copyJob);
    }

    backendResource->allocationSize = memRequirements.size;
    effectContext.vramUsage.totalUsageInBytes += static_cast<uint64_t>(backendResource->allocationSize);
    if ((createResourceDescription->resourceDescription.flags & FFX_RESOURCE_FLAGS_ALIASABLE) == FFX_RESOURCE_FLAGS_ALIASABLE)
    {
        effectContext.vramUsage.aliasableUsageInBytes += static_cast<uint64_t>(backendResource->allocationSize);
    }

    return FFX_OK;
}

FfxErrorCode DestroyResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource, FfxUInt32 effectContextId)
{
    FFX_ASSERT(backendInterface != nullptr);
    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    if ((resource.internalIndex >= int32_t(effectContextId * FFX_MAX_RESOURCE_COUNT)) && (resource.internalIndex < int32_t(effectContext.nextStaticResource)))
    {
        BackendContext_VK::Resource& backgroundResource = backendContext->pResources[resource.internalIndex];

        if (backgroundResource.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER)
        {
                                   
            if (backgroundResource.bufferResource != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyBuffer(backendContext->device, backgroundResource.bufferResource, nullptr);
                backgroundResource.bufferResource = VK_NULL_HANDLE;
            }
        }
        else if (backgroundResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR)
        {
                                  
            if (!backgroundResource.bridgeTensor && backgroundResource.tensorViewIndex >= 0 &&
                backendContext->pResourceViews[backgroundResource.tensorViewIndex].tensorView != VK_NULL_HANDLE)
            {
                if (VulkanWrapper().vkDestroyTensorViewARM)
                {
                    VulkanWrapper().vkDestroyTensorViewARM(
                        backendContext->device, backendContext->pResourceViews[backgroundResource.tensorViewIndex].tensorView, nullptr);
                }
                backendContext->pResourceViews[backgroundResource.tensorViewIndex].tensorView = VK_NULL_HANDLE;
                backgroundResource.tensorViewIndex                                            = -1;
            }
                                 
            if (!backgroundResource.bridgeTensor && backgroundResource.tensorResource != VK_NULL_HANDLE)
            {
                if (VulkanWrapper().vkDestroyTensorARM)
                {
                    VulkanWrapper().vkDestroyTensorARM(backendContext->device, backgroundResource.tensorResource, nullptr);
                }
                backgroundResource.tensorResource = VK_NULL_HANDLE;
            }

            const auto flags         = backgroundResource.resourceDescription.flags;
            const bool imageAliased  = (flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) == FFX_RESOURCE_FLAGS_IMAGE_ALIASED;
            const bool bufferAliased = (flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED;

            if (imageAliased && backgroundResource.aliasedTensorImageResource != VK_NULL_HANDLE)
            {
                              
                if (backgroundResource.srvViewIndex >= 0)
                {
                    VulkanWrapper().vkDestroyImageView(
                        backendContext->device, backendContext->pResourceViews[backgroundResource.srvViewIndex].imageView, nullptr);
                    backendContext->pResourceViews[backgroundResource.srvViewIndex].imageView = VK_NULL_HANDLE;
                    backgroundResource.srvViewIndex                                           = 0;
                }

                           
                if (FFX_CONTAINS_FLAG(backgroundResource.resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
                {
                    for (uint32_t i = 0; i < backgroundResource.uavViewCount; ++i)
                    {
                        if (backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView != VK_NULL_HANDLE)
                        {
                            VulkanWrapper().vkDestroyImageView(
                                backendContext->device, backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView, nullptr);
                            backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView = VK_NULL_HANDLE;
                        }
                    }
                }

                                                  
                backgroundResource.uavViewIndex = backgroundResource.srvViewIndex = -1;
                backgroundResource.uavViewCount                                   = 0;

                VulkanWrapper().vkDestroyImage(backendContext->device, backgroundResource.aliasedTensorImageResource, nullptr);
                backgroundResource.aliasedTensorImageResource = VK_NULL_HANDLE;
            }

                                     
            if ((bufferAliased || backgroundResource.bridgeTensor) && backgroundResource.aliasedTensorBufferResource != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyBuffer(backendContext->device, backgroundResource.aliasedTensorBufferResource, nullptr);
                backgroundResource.aliasedTensorBufferResource = VK_NULL_HANDLE;
            }
        }
        else
        {
                          
            if (backgroundResource.srvViewIndex >= 0)
            {
                VulkanWrapper().vkDestroyImageView(backendContext->device, backendContext->pResourceViews[backgroundResource.srvViewIndex].imageView, nullptr);
                backendContext->pResourceViews[backgroundResource.srvViewIndex].imageView = VK_NULL_HANDLE;
                backgroundResource.srvViewIndex                                           = 0;
            }

                       
            if (FFX_CONTAINS_FLAG(backgroundResource.resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
            {
                for (uint32_t i = 0; i < backgroundResource.uavViewCount; ++i)
                {
                    if (backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView != VK_NULL_HANDLE)
                    {
                        VulkanWrapper().vkDestroyImageView(
                            backendContext->device, backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView, nullptr);
                        backendContext->pResourceViews[backgroundResource.uavViewIndex + i].imageView = VK_NULL_HANDLE;
                    }
                }
            }

                                              
            backgroundResource.uavViewIndex = backgroundResource.srvViewIndex = -1;
            backgroundResource.uavViewCount                                   = 0;

                                   
            if (backgroundResource.imageResource != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyImage(backendContext->device, backgroundResource.imageResource, nullptr);
                backgroundResource.imageResource = VK_NULL_HANDLE;
                                         
                if (backgroundResource.aliasedBufferResource != VK_NULL_HANDLE)
                {
                    VulkanWrapper().vkDestroyBuffer(backendContext->device, backgroundResource.aliasedBufferResource, nullptr);
                    backgroundResource.aliasedBufferResource = VK_NULL_HANDLE;
                }
            }
        }

        if (backgroundResource.deviceMemory)
        {
            VulkanWrapper().vkFreeMemory(backendContext->device, backgroundResource.deviceMemory, nullptr);
            backgroundResource.deviceMemory = VK_NULL_HANDLE;

            effectContext.vramUsage.totalUsageInBytes -= static_cast<uint64_t>(backgroundResource.allocationSize);
            if ((backendContext->pResources[resource.internalIndex].resourceDescription.flags & FFX_RESOURCE_FLAGS_ALIASABLE) == FFX_RESOURCE_FLAGS_ALIASABLE)
            {
                effectContext.vramUsage.aliasableUsageInBytes -= static_cast<uint64_t>(backgroundResource.allocationSize);
            }
            backgroundResource.allocationSize = 0;
        }
    }

    return FFX_OK;
}

FfxErrorCode MapResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource, void** ptr)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    BackendContext_VK::Resource* res = &backendContext->pResources[resource.internalIndex];

    if ((VulkanWrapper().vkMapMemory(backendContext->device, res->deviceMemory, 0, res->resourceDescription.size, 0, ptr) != VK_SUCCESS))
        return FFX_ERROR_BACKEND_API_ERROR;

    return FFX_OK;
}

FfxErrorCode UnmapResourceVK(FfxInterface* backendInterface, FfxResourceInternal resource)
{
    FFX_ASSERT(NULL != backendInterface);

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    BackendContext_VK::Resource* res = &backendContext->pResources[resource.internalIndex];

    VulkanWrapper().vkUnmapMemory(backendContext->device, res->deviceMemory);

    return FFX_OK;
}

FfxErrorCode RegisterResourceVK(FfxInterface*        backendInterface,
                                const FfxResource*   inFfxResource,
                                FfxUInt32            effectContextId,
                                FfxResourceInternal* outFfxResourceInternal)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_VK*                backendContext = (BackendContext_VK*)(backendInterface->scratchBuffer);
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    if (inFfxResource->resource == nullptr)
    {
        outFfxResourceInternal->internalIndex = 0;                                                           
        return FFX_OK;
    }

                                                                                                                                    
                                                                                                                        
                                                                                                                          
                                                      
    FFX_ASSERT(effectContext.nextDynamicResource > effectContext.nextStaticResource);
    outFfxResourceInternal->internalIndex = effectContext.nextDynamicResource--;

                                        
    BackendContext_VK::Resource* backendResource = &backendContext->pResources[outFfxResourceInternal->internalIndex];

                                                                                                            
                                                                                 
     
                                    
     

                                                                                            
                              
     
                                                                      
                                                                                                                                                              
                                                                                                                                                          
                          

                                                                                       
                                                                                                                        
                                     
         
                                                                                                                                 
                                                                                                 

                          
                                                                                                                                                                  
                                                                                                                                                              
             
                                                                   
                               
             

                     
                                                                                           
             
                                            
                      
             

                                                    
         
       

                                                            
    backendResource->resourceDescription = inFfxResource->description;
    if (inFfxResource->description.type == FFX_RESOURCE_TYPE_BUFFER)
        backendResource->bufferResource = reinterpret_cast<VkBuffer>(inFfxResource->resource);
    else
        backendResource->imageResource = reinterpret_cast<VkImage>(inFfxResource->resource);

    copyResourceState(backendResource, inFfxResource);

#ifdef _DEBUG
    if (inFfxResource->name[0])
    {
        strncpy(backendResource->resourceName, inFfxResource->name, sizeof(backendResource->resourceName) - 1);
        backendResource->resourceName[sizeof(backendResource->resourceName) - 1] = '\0';
    }
#endif

                                                                   

                                                                              
                           
    switch (backendResource->resourceDescription.type)
    {
    case FFX_RESOURCE_TYPE_BUFFER:
        break;
    case FFX_RESOURCE_TYPE_TEXTURE1D:
    case FFX_RESOURCE_TYPE_TEXTURE2D:
    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
    {
        FfxResourceType       type                = backendResource->resourceDescription.type;
        VkImageViewCreateInfo imageViewCreateInfo = {};
        imageViewCreateInfo.sType                 = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        imageViewCreateInfo.pNext                 = nullptr;

        bool requestArrayView = FFX_CONTAINS_FLAG(backendResource->resourceDescription.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

        switch (type)
        {
        case FFX_RESOURCE_TYPE_TEXTURE1D:
            imageViewCreateInfo.viewType =
                (backendResource->resourceDescription.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_1D_ARRAY : VK_IMAGE_VIEW_TYPE_1D;
            break;
        default:
        case FFX_RESOURCE_TYPE_TEXTURE2D:
            imageViewCreateInfo.viewType =
                (backendResource->resourceDescription.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_2D_ARRAY : VK_IMAGE_VIEW_TYPE_2D;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE3D:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_3D;
            break;
        }

        imageViewCreateInfo.image = backendResource->imageResource;
        imageViewCreateInfo.format =
            getVkFormatFromSurfaceFormatAndUsage(backendResource->resourceDescription.format, backendResource->resourceDescription.usage);
        imageViewCreateInfo.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.subresourceRange.aspectMask     = getImageAspect(backendResource->resourceDescription.usage);
        imageViewCreateInfo.subresourceRange.baseMipLevel   = 0;
        imageViewCreateInfo.subresourceRange.levelCount     = backendResource->resourceDescription.mipCount;
        imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
        imageViewCreateInfo.subresourceRange.layerCount     = VK_REMAINING_ARRAY_LAYERS;

                                                                           
        FFX_ASSERT(effectContext.nextDynamicResourceView[effectContext.frameIndex] >
                   ((effectContext.frameIndex == 0) ? effectContext.nextStaticResourceView
                                                    : getDynamicResourceViewsStartIndex(effectContextId, effectContext.frameIndex - 1)));
        backendResource->srvViewIndex = effectContext.nextDynamicResourceView[effectContext.frameIndex]--;

        VkImageViewUsageCreateInfo imageViewUsageCreateInfo = {};
        setupImageViewForSRV(imageViewCreateInfo, imageViewUsageCreateInfo, backendResource->resourceDescription);

        if (VulkanWrapper().vkCreateImageView(
                backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->srvViewIndex].imageView) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
#ifdef _DEBUG
        setVKObjectName(backendContext->device,
                        VK_OBJECT_TYPE_IMAGE_VIEW,
                        (uint64_t)backendContext->pResourceViews[backendResource->srvViewIndex].imageView,
                        backendResource->resourceName);
#endif

                                                                       
        if (FFX_CONTAINS_FLAG(backendResource->resourceDescription.usage, FFX_RESOURCE_USAGE_UAV))
        {
            const int32_t uavResourceViewCount = backendResource->resourceDescription.mipCount;
            FFX_ASSERT(effectContext.nextDynamicResourceView[effectContext.frameIndex] - uavResourceViewCount + 1 >
                       ((effectContext.frameIndex == 0) ? effectContext.nextStaticResourceView
                                                        : getDynamicResourceViewsStartIndex(effectContextId, effectContext.frameIndex - 1)));
            backendResource->uavViewIndex = effectContext.nextDynamicResourceView[effectContext.frameIndex] - uavResourceViewCount + 1;
            backendResource->uavViewCount = uavResourceViewCount;

            imageViewCreateInfo.format =
                getVkFormatFromSurfaceFormatAndUsage(backendResource->resourceDescription.format, backendResource->resourceDescription.usage);
            imageViewCreateInfo.pNext = nullptr;

            for (uint32_t mip = 0; mip < backendResource->resourceDescription.mipCount; ++mip)
            {
                imageViewCreateInfo.subresourceRange.levelCount   = 1;
                imageViewCreateInfo.subresourceRange.baseMipLevel = mip;

                if (VulkanWrapper().vkCreateImageView(
                        backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView) !=
                    VK_SUCCESS)
                {
                    return FFX_ERROR_BACKEND_API_ERROR;
                }
#ifdef _DEBUG
                setVKObjectName(backendContext->device,
                                VK_OBJECT_TYPE_IMAGE_VIEW,
                                (uint64_t)backendContext->pResourceViews[backendResource->uavViewIndex + mip].imageView,
                                backendResource->resourceName);
#endif
            }
            effectContext.nextDynamicResourceView[effectContext.frameIndex] -= uavResourceViewCount;
        }
        break;
    }
    default:
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Unsupported resource view type creation requested.");
        break;
    }

    return FFX_OK;
}

FfxResource GetResourceVK(FfxInterface* backendInterface, FfxResourceInternal inResource)
{
    FFX_ASSERT(nullptr != backendInterface);
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    FfxResourceDescription ffxResDescription = backendInterface->fpGetResourceDescription(backendInterface, inResource);

    FfxResource resource = {};
    resource.resource    = reinterpret_cast<void*>(backendContext->pResources[inResource.internalIndex].imageResource);
                                                                                               
                                                                                               
                         
    if (backendContext->pResources[inResource.internalIndex].undefined)
    {
        ffxResDescription.flags = (FfxResourceFlags)((int)ffxResDescription.flags | FFX_RESOURCE_FLAGS_UNDEFINED);
                                                                                      
                    
        backendContext->pResources[inResource.internalIndex].undefined = false;
    }
    resource.state       = backendContext->pResources[inResource.internalIndex].currentState;
    resource.description = ffxResDescription;

#ifdef _DEBUG
    if (backendContext->pResources[inResource.internalIndex].resourceName)
    {
        strncpy(resource.name, backendContext->pResources[inResource.internalIndex].resourceName, FFX_RESOURCE_NAME_SIZE - 1);
        resource.name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }
#endif

    return resource;
}

                                                                           
FfxErrorCode UnregisterResourcesVK(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_VK*                backendContext = (BackendContext_VK*)(backendInterface->scratchBuffer);
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

                                                                                                
    const uint32_t dynamicResourceIndexStart = getDynamicResourcesStartIndex(effectContextId);
    for (uint32_t resourceIndex = ++effectContext.nextDynamicResource; resourceIndex <= dynamicResourceIndexStart; ++resourceIndex)
    {
        FfxResourceInternal internalResource;
        internalResource.internalIndex = resourceIndex;

        BackendContext_VK::Resource* backendResource = &backendContext->pResources[resourceIndex];

                                                                                  
        backendResource->uavViewIndex    = -1;
        backendResource->srvViewIndex    = -1;
        backendResource->tensorViewIndex = -1;

                          
        addBarrier(backendContext, &internalResource, backendResource->initialState);
    }

    FFX_ASSERT(nullptr != commandList);
    VkCommandBuffer pCmdList = reinterpret_cast<VkCommandBuffer>(commandList);

    flushBarriers(backendContext, pCmdList);

                                                                         
                                                                                              
    effectContext.nextDynamicResource = dynamicResourceIndexStart;

                                          
    effectContext.frameIndex = (effectContext.frameIndex + 1) % FFX_MAX_QUEUED_FRAMES;
    destroyDynamicViews(backendContext, effectContextId, effectContext.frameIndex);

    return FFX_OK;
}

FfxErrorCode registerStaticTextureSrv(BackendContext_VK* backendContext, const FfxResource* inResource, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    if (effectContext.bindlessTextureSrvHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    VkImage vkImage = reinterpret_cast<VkImage>(inResource->resource);

                           
    switch (inResource->description.type)
    {
    case FFX_RESOURCE_TYPE_BUFFER:
    {
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Attempting to register a Buffer as a Texture SRV.");
        break;
    }
    case FFX_RESOURCE_TYPE_TEXTURE1D:
    case FFX_RESOURCE_TYPE_TEXTURE2D:
    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
    {
        FfxResourceType       type                = inResource->description.type;
        VkImageViewCreateInfo imageViewCreateInfo = {};
        imageViewCreateInfo.sType                 = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        imageViewCreateInfo.pNext                 = nullptr;

        bool requestArrayView = FFX_CONTAINS_FLAG(inResource->description.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

        switch (type)
        {
        case FFX_RESOURCE_TYPE_TEXTURE1D:
            imageViewCreateInfo.viewType = (inResource->description.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_1D_ARRAY : VK_IMAGE_VIEW_TYPE_1D;
            break;
        default:
        case FFX_RESOURCE_TYPE_TEXTURE2D:
            imageViewCreateInfo.viewType = (inResource->description.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_2D_ARRAY : VK_IMAGE_VIEW_TYPE_2D;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE3D:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_3D;
            break;
        }

        imageViewCreateInfo.image                         = vkImage;
        imageViewCreateInfo.format                        = getVkFormatFromSurfaceFormatAndUsage(inResource->description.format, inResource->description.usage);
        imageViewCreateInfo.components.r                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.g                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.b                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.a                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.subresourceRange.aspectMask   = getImageAspect(inResource->description.usage);
        imageViewCreateInfo.subresourceRange.baseMipLevel = 0;
        imageViewCreateInfo.subresourceRange.levelCount   = inResource->description.mipCount;
        imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
        imageViewCreateInfo.subresourceRange.layerCount     = VK_REMAINING_ARRAY_LAYERS;

        uint32_t imageViewIndex = effectContext.bindlessTextureSrvHeapStart + index;

        if (backendContext->pResourceViews[imageViewIndex].imageView)
            VulkanWrapper().vkDestroyImageView(backendContext->device, backendContext->pResourceViews[imageViewIndex].imageView, nullptr);

        if (VulkanWrapper().vkCreateImageView(backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[imageViewIndex].imageView) !=
            VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

#ifdef _DEBUG
        setVKObjectName(
            backendContext->device, VK_OBJECT_TYPE_IMAGE_VIEW, (uint64_t)backendContext->pResourceViews[imageViewIndex].imageView, inResource->name);
#endif

        VkWriteDescriptorSet  writeDescriptorSet  = {};
        VkDescriptorImageInfo imageDescriptorInfo = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED};

        writeDescriptorSet.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.dstSet          = effectContext.bindlessTextureSrvDescriptorSet;
        writeDescriptorSet.descriptorCount = 1;
        writeDescriptorSet.descriptorType  = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        writeDescriptorSet.pImageInfo      = &imageDescriptorInfo;
        writeDescriptorSet.dstBinding      = 0;
        writeDescriptorSet.dstArrayElement = index;

        imageDescriptorInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        imageDescriptorInfo.imageView   = backendContext->pResourceViews[imageViewIndex].imageView;

        VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, 1, &writeDescriptorSet, 0, nullptr);

        return FFX_OK;

        break;
    }
    default:
        break;
    }

    return FFX_ERROR_INVALID_ARGUMENT;
}

FfxErrorCode registerStaticBufferSrv(BackendContext_VK* backendContext,
                                     const FfxResource* inResource,
                                     uint32_t           offset,
                                     uint32_t           size,
                                     uint32_t           stride,
                                     uint32_t           index,
                                     FfxUInt32          effectContextId)
{
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    if (effectContext.bindlessBufferSrvHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    if (inResource->description.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        VkBuffer buffer = reinterpret_cast<VkBuffer>(inResource->resource);

        VkWriteDescriptorSet   writeDescriptorSet   = {};
        VkDescriptorBufferInfo bufferDescriptorInfo = {VK_NULL_HANDLE, 0, VK_WHOLE_SIZE};

        writeDescriptorSet.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.dstSet          = effectContext.bindlessBufferSrvDescriptorSet;
        writeDescriptorSet.descriptorCount = 1;
        writeDescriptorSet.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSet.pBufferInfo     = &bufferDescriptorInfo;
        writeDescriptorSet.dstBinding      = 0;
        writeDescriptorSet.dstArrayElement = index;

        bufferDescriptorInfo.buffer = buffer;
        bufferDescriptorInfo.offset = offset;
        bufferDescriptorInfo.range  = size > 0 ? size : VK_WHOLE_SIZE;

        VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, 1, &writeDescriptorSet, 0, nullptr);

        return FFX_OK;
    }
    else
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Attempting to register a Texture as a Buffer SRV.");

    return FFX_ERROR_INVALID_ARGUMENT;
}

FfxErrorCode registerStaticTextureUav(BackendContext_VK* backendContext, const FfxResource* inResource, uint32_t mip, uint32_t index, FfxUInt32 effectContextId)
{
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    if (effectContext.bindlessTextureUavHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    VkImage vkImage = reinterpret_cast<VkImage>(inResource->resource);

                           
    switch (inResource->description.type)
    {
    case FFX_RESOURCE_TYPE_BUFFER:
    {
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Attempting to register a Buffer as a Texture UAV.");
        break;
    }
    case FFX_RESOURCE_TYPE_TEXTURE1D:
    case FFX_RESOURCE_TYPE_TEXTURE2D:
    case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
    case FFX_RESOURCE_TYPE_TEXTURE3D:
    {
        FfxResourceType       type                = inResource->description.type;
        VkImageViewCreateInfo imageViewCreateInfo = {};
        imageViewCreateInfo.sType                 = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        imageViewCreateInfo.pNext                 = nullptr;

        bool requestArrayView = FFX_CONTAINS_FLAG(inResource->description.usage, FFX_RESOURCE_USAGE_ARRAYVIEW);

        switch (type)
        {
        case FFX_RESOURCE_TYPE_TEXTURE1D:
            imageViewCreateInfo.viewType = (inResource->description.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_1D_ARRAY : VK_IMAGE_VIEW_TYPE_1D;
            break;
        default:
        case FFX_RESOURCE_TYPE_TEXTURE2D:
            imageViewCreateInfo.viewType = (inResource->description.depth > 1 || requestArrayView) ? VK_IMAGE_VIEW_TYPE_2D_ARRAY : VK_IMAGE_VIEW_TYPE_2D;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE_CUBE:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE;
            break;
        case FFX_RESOURCE_TYPE_TEXTURE3D:
            imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_3D;
            break;
        }

        imageViewCreateInfo.image                         = vkImage;
        imageViewCreateInfo.format                        = getVkFormatFromSurfaceFormatAndUsage(inResource->description.format, inResource->description.usage);
        imageViewCreateInfo.components.r                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.g                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.b                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.components.a                  = VK_COMPONENT_SWIZZLE_IDENTITY;
        imageViewCreateInfo.subresourceRange.aspectMask   = getImageAspect(inResource->description.usage);
        imageViewCreateInfo.subresourceRange.baseMipLevel = 0;
        imageViewCreateInfo.subresourceRange.levelCount   = inResource->description.mipCount;
        imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
        imageViewCreateInfo.subresourceRange.layerCount     = VK_REMAINING_ARRAY_LAYERS;

        uint32_t imageViewIndex = effectContext.bindlessTextureUavHeapStart + index;

        if (backendContext->pResourceViews[imageViewIndex].imageView)
            VulkanWrapper().vkDestroyImageView(backendContext->device, backendContext->pResourceViews[imageViewIndex].imageView, nullptr);

        if (VulkanWrapper().vkCreateImageView(backendContext->device, &imageViewCreateInfo, NULL, &backendContext->pResourceViews[imageViewIndex].imageView) !=
            VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

#ifdef _DEBUG
        setVKObjectName(
            backendContext->device, VK_OBJECT_TYPE_IMAGE_VIEW, (uint64_t)backendContext->pResourceViews[imageViewIndex].imageView, inResource->name);
#endif

        VkWriteDescriptorSet  writeDescriptorSet  = {};
        VkDescriptorImageInfo imageDescriptorInfo = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_UNDEFINED};

        writeDescriptorSet.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.dstSet          = effectContext.bindlessTextureUavDescriptorSet;
        writeDescriptorSet.descriptorCount = 1;
        writeDescriptorSet.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writeDescriptorSet.pImageInfo      = &imageDescriptorInfo;
        writeDescriptorSet.dstBinding      = 0;
        writeDescriptorSet.dstArrayElement = index;

        imageDescriptorInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageDescriptorInfo.imageView   = backendContext->pResourceViews[imageViewIndex].imageView;

        VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, 1, &writeDescriptorSet, 0, nullptr);

        return FFX_OK;

        break;
    }
    default:
        break;
    }

    return FFX_ERROR_INVALID_ARGUMENT;
}

FfxErrorCode registerStaticBufferUav(BackendContext_VK* backendContext,
                                     const FfxResource* inResource,
                                     uint32_t           offset,
                                     uint32_t           size,
                                     uint32_t           stride,
                                     uint32_t           index,
                                     FfxUInt32          effectContextId)
{
    BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

    if (effectContext.bindlessBufferUavHeapSize <= index)
    {
        FFX_ASSERT(false);
        return FFX_ERROR_INSUFFICIENT_MEMORY;
    }

    if (inResource->description.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        VkBuffer buffer = reinterpret_cast<VkBuffer>(inResource->resource);

        VkWriteDescriptorSet   writeDescriptorSet   = {};
        VkDescriptorBufferInfo bufferDescriptorInfo = {VK_NULL_HANDLE, 0, VK_WHOLE_SIZE};

        writeDescriptorSet.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.dstSet          = effectContext.bindlessBufferUavDescriptorSet;
        writeDescriptorSet.descriptorCount = 1;
        writeDescriptorSet.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSet.pBufferInfo     = &bufferDescriptorInfo;
        writeDescriptorSet.dstBinding      = 0;
        writeDescriptorSet.dstArrayElement = index;

        bufferDescriptorInfo.buffer = buffer;
        bufferDescriptorInfo.offset = offset;
        bufferDescriptorInfo.range  = size > 0 ? size : VK_WHOLE_SIZE;

        VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, 1, &writeDescriptorSet, 0, nullptr);

        return FFX_OK;
    }
    else
        FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Attempting to register a Texture as a Buffer UAV.");

    return FFX_ERROR_INVALID_ARGUMENT;
}

FfxErrorCode RegisterStaticResourceVK(FfxInterface* backendInterface, const FfxStaticResourceDescription* desc, FfxUInt32 effectContextId)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != desc);

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    switch (desc->descriptorType)
    {
    case FFX_DESCRIPTOR_TEXTURE_SRV:
        return registerStaticTextureSrv(backendContext, desc->resource, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_BUFFER_SRV:
        return registerStaticBufferSrv(
            backendContext, desc->resource, desc->bufferOffset, desc->bufferSize, desc->bufferStride, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_TEXTURE_UAV:
        return registerStaticTextureUav(backendContext, desc->resource, desc->textureUavMip, desc->descriptorIndex, effectContextId);
    case FFX_DESCRIPTOR_BUFFER_UAV:
        return registerStaticBufferUav(
            backendContext, desc->resource, desc->bufferOffset, desc->bufferSize, desc->bufferStride, desc->descriptorIndex, effectContextId);
    default:
        return FFX_ERROR_INVALID_ARGUMENT;
    }
}

FfxResourceDescription GetResourceDescriptionVK(FfxInterface* backendInterface, FfxResourceInternal resource)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    FfxResourceDescription resourceDescription = backendContext->pResources[resource.internalIndex].resourceDescription;
    return resourceDescription;
}

FfxErrorCode StageConstantBufferDataVK(FfxInterface* backendInterface, void* data, FfxUInt32 size, FfxConstantBuffer* constantBuffer)
{
    FFX_ASSERT(NULL != backendInterface);
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

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

VkSamplerAddressMode FfxGetAddressModeVK(const FfxAddressMode& addressMode)
{
    switch (addressMode)
    {
    case FFX_ADDRESS_MODE_WRAP:
        return VK_SAMPLER_ADDRESS_MODE_REPEAT;
    case FFX_ADDRESS_MODE_MIRROR:
        return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
    case FFX_ADDRESS_MODE_CLAMP:
        return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    case FFX_ADDRESS_MODE_BORDER:
        return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    case FFX_ADDRESS_MODE_MIRROR_ONCE:
        return VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE;
    default:
        FFX_ASSERT_MESSAGE(false, "Unsupported addressing mode requested. Please implement");
        return VK_SAMPLER_ADDRESS_MODE_REPEAT;
        break;
    }
}

FfxErrorCode CreateComputePipelineVK(FfxInterface*                 backendInterface,
                                     FfxEffect                     effect,
                                     FfxPass                       pass,
                                     uint32_t                      permutationOptions,
                                     const FfxPipelineDescription* pipelineDescription,
                                     FfxUInt32                     effectContextId,
                                     FfxPipelineState*             outPipeline)
{
    nss_trace("backend: CreateComputePipeline effect=%d pass=%d name=%s", (int) effect, (int) pass, pipelineDescription ? "" : "?");
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != pipelineDescription);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    if (pass == FFX_FRAMEINTERPOLATION_PASS_MLOF2)
    {
        nss_trace("backend: CreateComputePipeline FFX_FRAMEINTERPOLATION_PASS_MLOF2");
        BackendContext_VK::PipelineLayout* pPipelineLayout = &backendContext->pPipelineLayouts[effectContext.nextPipelineLayout++];
        pPipelineLayout->mvResidualEngine = nullptr;
        pPipelineLayout->selectEngine = nullptr;
        pPipelineLayout->mlof2Runtime = nullptr;
        pPipelineLayout->nfruEngine = nullptr;
        pPipelineLayout->embeddedOpticalFlow = nullptr;
        pPipelineLayout->ofComputePipeline = VK_NULL_HANDLE;

        Mlof2Runtime* rt = new Mlof2Runtime();
        pPipelineLayout->mlof2Runtime = rt;
        outPipeline->pipeline = VK_NULL_HANDLE;
        outPipeline->rootSignature = reinterpret_cast<FfxRootSignature>(pPipelineLayout);
        if (pipelineDescription && pipelineDescription->name) {
            strncpy(outPipeline->name, pipelineDescription->name, FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
        nss_trace("backend: Mlof2Runtime created (lazy initialization on execute)");
        return FFX_OK;
    }

                                        
    FfxShaderBlob shaderBlob = {};
                             
    FFX_VALIDATE(backendInterface->fpGetPermutationBlobByIndex(effect, pass, permutationOptions, &shaderBlob, nullptr, nullptr));
    FFX_ASSERT(shaderBlob.data && shaderBlob.size);

                                                                              
                                                           
    FFX_ASSERT_MESSAGE(effectContext.nextPipelineLayout < (effectContextId * FFX_MAX_PASS_COUNT) + FFX_MAX_PASS_COUNT,
                       "FFXInterface: Vulkan: Ran out of pipeline layouts. Please increase FFX_MAX_PASS_COUNT");
    BackendContext_VK::PipelineLayout* pPipelineLayout = &backendContext->pPipelineLayouts[effectContext.nextPipelineLayout++];
    pPipelineLayout->mvResidualEngine = nullptr;
    pPipelineLayout->selectEngine = nullptr;
    pPipelineLayout->mvResidualInverted = (permutationOptions & (1u << 2)) != 0;

                                 
    FFX_ASSERT(pipelineDescription->samplerCount <= FFX_MAX_SAMPLERS);
    const size_t samplerCount = pipelineDescription->samplerCount;
    for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < samplerCount; ++currentSamplerIndex)
    {
        VkSamplerCreateInfo createInfo = {};

        createInfo.maxLod                  = pipelineDescription->samplers[currentSamplerIndex].unnormalizedCoordinates ? 0.f : VK_LOD_CLAMP_NONE;
        createInfo.unnormalizedCoordinates = pipelineDescription->samplers[currentSamplerIndex].unnormalizedCoordinates ? VK_TRUE : VK_FALSE;

        createInfo.sType  = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        createInfo.pNext  = nullptr;
        createInfo.flags  = 0;
        createInfo.minLod = 0.f;

        createInfo.anisotropyEnable = false;
        createInfo.compareEnable    = false;
        createInfo.compareOp        = VK_COMPARE_OP_NEVER;
        createInfo.borderColor      = VK_BORDER_COLOR_INT_TRANSPARENT_BLACK;

        createInfo.addressModeU = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeU);
        createInfo.addressModeV = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeV);
        createInfo.addressModeW = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeW);

                               
        switch (pipelineDescription->samplers[currentSamplerIndex].filter)
        {
        case FFX_FILTER_TYPE_MINMAGMIP_POINT:
            createInfo.minFilter  = VK_FILTER_NEAREST;
            createInfo.magFilter  = VK_FILTER_NEAREST;
            createInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            break;
        case FFX_FILTER_TYPE_MINMAGMIP_LINEAR:
            createInfo.minFilter  = VK_FILTER_LINEAR;
            createInfo.magFilter  = VK_FILTER_LINEAR;
            createInfo.mipmapMode = createInfo.unnormalizedCoordinates ? VK_SAMPLER_MIPMAP_MODE_NEAREST : VK_SAMPLER_MIPMAP_MODE_LINEAR;
            break;
        case FFX_FILTER_TYPE_MINMAGLINEARMIP_POINT:
            createInfo.minFilter  = VK_FILTER_LINEAR;
            createInfo.magFilter  = VK_FILTER_LINEAR;
            createInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            break;

        default:
            FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Unsupported filter type requested. Please implement");
            break;
        }

        if (VulkanWrapper().vkCreateSampler(backendContext->device, &createInfo, nullptr, &pPipelineLayout->samplers[currentSamplerIndex]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    int32_t staticTextureSrvCount = 0;
    int32_t staticBufferSrvCount  = 0;
    int32_t staticTextureUavCount = 0;
    int32_t staticBufferUavCount  = 0;

    pPipelineLayout->staticTextureSrvSet = -1;
    pPipelineLayout->staticBufferSrvSet  = -1;
    pPipelineLayout->staticTextureUavSet = -1;
    pPipelineLayout->staticBufferUavSet  = -1;

                            
    VkDescriptorSetLayoutBinding layoutBindings[MAX_DESCRIPTOR_SET_LAYOUTS];
    uint32_t                     numLayoutBindings = 0;

                               
    VkShaderStageFlags shaderStageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

                                              
    for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < samplerCount; ++currentSamplerIndex)
        layoutBindings[numLayoutBindings++] = {
            currentSamplerIndex + SAMPLER_BINDING_SHIFT, VK_DESCRIPTOR_TYPE_SAMPLER, 1, shaderStageFlags, &pPipelineLayout->samplers[currentSamplerIndex]};

                   
    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; ++srvIndex)
    {
                                        
        if (shaderBlob.boundSRVTextureSpaces[srvIndex] != 0)
        {
            if (staticTextureSrvCount > 0)
                FFX_ASSERT(pPipelineLayout->staticTextureSrvSet != shaderBlob.boundSRVTextureSpaces[srvIndex]);

            staticTextureSrvCount += shaderBlob.boundSRVTextureCounts[srvIndex];
            pPipelineLayout->staticTextureSrvSet = shaderBlob.boundSRVTextureSpaces[srvIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVTextures[srvIndex], VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, shaderBlob.boundSRVTextureCounts[srvIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvBufferCount; ++srvIndex)
    {
                                        
        if (shaderBlob.boundSRVBufferSpaces[srvIndex] != 0)
        {
            if (staticBufferSrvCount > 0)
                FFX_ASSERT(pPipelineLayout->staticBufferSrvSet != shaderBlob.boundSRVBufferSpaces[srvIndex]);

            staticBufferSrvCount += shaderBlob.boundSRVBufferCounts[srvIndex];
            pPipelineLayout->staticBufferSrvSet = shaderBlob.boundSRVBufferSpaces[srvIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVBuffers[srvIndex], VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shaderBlob.boundSRVBufferCounts[srvIndex], shaderStageFlags, nullptr};
    }

                   
    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; ++uavIndex)
    {
                                        
        if (shaderBlob.boundUAVTextureSpaces[uavIndex] != 0)
        {
            if (staticTextureUavCount > 0)
                FFX_ASSERT(pPipelineLayout->staticTextureUavSet != shaderBlob.boundUAVTextureSpaces[uavIndex]);

            staticTextureUavCount += shaderBlob.boundUAVTextureCounts[uavIndex];
            pPipelineLayout->staticTextureUavSet = shaderBlob.boundUAVTextureSpaces[uavIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVTextures[uavIndex], VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, shaderBlob.boundUAVTextureCounts[uavIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; ++uavIndex)
    {
                                        
        if (shaderBlob.boundUAVBufferSpaces[uavIndex] != 0)
        {
            if (staticBufferUavCount > 0)
                FFX_ASSERT(pPipelineLayout->staticBufferUavSet != shaderBlob.boundUAVBufferSpaces[uavIndex]);

            staticBufferUavCount += shaderBlob.boundUAVBufferCounts[uavIndex];
            pPipelineLayout->staticBufferUavSet = shaderBlob.boundUAVBufferSpaces[uavIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVBuffers[uavIndex], VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shaderBlob.boundUAVBufferCounts[uavIndex], shaderStageFlags, nullptr};
    }

                                  
    for (uint32_t cbIndex = 0; cbIndex < shaderBlob.cbvCount; ++cbIndex)
    {
        layoutBindings[numLayoutBindings++] = {shaderBlob.boundConstantBuffers[cbIndex],
                                               VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                                               shaderBlob.boundConstantBufferCounts[cbIndex],
                                               shaderStageFlags,
                                               nullptr};
    }

                  
    for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.srvTensorCount; ++tensorIndex)
    {
        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVTensors[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, shaderBlob.boundSRVTensorCounts[tensorIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.uavTensorCount; ++tensorIndex)
    {
        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVTensors[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, shaderBlob.boundUAVTensorCounts[tensorIndex], shaderStageFlags, nullptr};
    }

                                   
    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount                    = numLayoutBindings;
    layoutInfo.pBindings                       = layoutBindings;

    if (VulkanWrapper().vkCreateDescriptorSetLayout(backendContext->device, &layoutInfo, nullptr, &pPipelineLayout->descriptorSetLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                               
    pPipelineLayout->descriptorSetIndex = 0;
    for (uint32_t i = 0; i < (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME); i++)
    {
        VkDescriptorSetAllocateInfo allocateInfo = {};
        allocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocateInfo.descriptorPool              = backendContext->descriptorPool;
        allocateInfo.descriptorSetCount          = 1;
        allocateInfo.pSetLayouts                 = &pPipelineLayout->descriptorSetLayout;

        if (VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &allocateInfo, &pPipelineLayout->descriptorSets[i]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    uint32_t setCount = 0;

    VkDescriptorSetLayout layouts[5];

    layouts[setCount++] = pPipelineLayout->descriptorSetLayout;

    if (staticTextureSrvCount > 0)
    {
        layouts[pPipelineLayout->staticTextureSrvSet] = effectContext.bindlessTextureSrvDescriptorSetLayout;
        setCount++;
    }

    if (staticBufferSrvCount > 0)
    {
        layouts[pPipelineLayout->staticBufferSrvSet] = effectContext.bindlessBufferSrvDescriptorSetLayout;
        setCount++;
    }

    if (staticTextureUavCount > 0)
    {
        layouts[pPipelineLayout->staticTextureUavSet] = effectContext.bindlessTextureUavDescriptorSetLayout;
        setCount++;
    }

    if (staticBufferUavCount > 0)
    {
        layouts[pPipelineLayout->staticBufferUavSet] = effectContext.bindlessBufferUavDescriptorSetLayout;
        setCount++;
    }

                                 
    VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
    pipelineLayoutInfo.sType                  = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount         = setCount;
    pipelineLayoutInfo.pSetLayouts            = layouts;
    pipelineLayoutInfo.pushConstantRangeCount = 0;
    pipelineLayoutInfo.pPushConstantRanges    = nullptr;

    if (VulkanWrapper().vkCreatePipelineLayout(backendContext->device, &pipelineLayoutInfo, nullptr, &pPipelineLayout->pipelineLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                         
    outPipeline->rootSignature = reinterpret_cast<FfxRootSignature>(pPipelineLayout);

                                                                              
    if (pipelineDescription->indirectWorkload)
    {
                                                       
        outPipeline->cmdSignature = reinterpret_cast<FfxCommandSignature>(sizeof(VkDispatchIndirectCommand));
    }
    else
    {
        outPipeline->cmdSignature = nullptr;
    }

    uint32_t flattenedSrvTextureCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; ++srvIndex)
    {
        uint32_t slotIndex = shaderBlob.boundSRVTextures[srvIndex];
        uint32_t bindCount = shaderBlob.boundSRVTextureCounts[srvIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvTextureCount++;

            outPipeline->srvTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->srvTextureBindings[bindingIndex].name, shaderBlob.boundSRVTextureNames[srvIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->srvTextureBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->srvTextureCount = flattenedSrvTextureCount;
    FFX_ASSERT(outPipeline->srvTextureCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavTextureCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; ++uavIndex)
    {
        uint32_t slotIndex = shaderBlob.boundUAVTextures[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVTextureCounts[uavIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavTextureCount++;

            outPipeline->uavTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->uavTextureBindings[bindingIndex].name, shaderBlob.boundUAVTextureNames[uavIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->uavTextureBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
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

                                
        if (spaceIndex == 1)
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvBufferCount++;

            outPipeline->srvBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->srvBufferBindings[bindingIndex].name, shaderBlob.boundSRVBufferNames[srvIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->srvBufferBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->srvBufferCount = flattenedSrvBufferCount;
    FFX_ASSERT(outPipeline->srvBufferCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavBufferCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; ++uavIndex)
    {
        uint32_t slotIndex = shaderBlob.boundUAVBuffers[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVBufferCounts[uavIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavBufferCount++;

            outPipeline->uavBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->uavBufferBindings[bindingIndex].name, shaderBlob.boundUAVBufferNames[uavIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->uavBufferBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->uavBufferCount = flattenedUavBufferCount;
    FFX_ASSERT(outPipeline->uavBufferCount < FFX_MAX_NUM_UAVS);

    {
        uint32_t flattenedSrvTensorCount = 0;

        for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.srvTensorCount; ++tensorIndex)
        {
            uint32_t slotIndex = shaderBlob.boundSRVTensors[tensorIndex];
            uint32_t bindCount = shaderBlob.boundSRVTensorCounts[tensorIndex];

            for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
            {
                uint32_t bindingIndex = flattenedSrvTensorCount++;

                outPipeline->srvTensorBindings[bindingIndex].slotIndex  = slotIndex;
                outPipeline->srvTensorBindings[bindingIndex].arrayIndex = arrayIndex;
                strncpy(outPipeline->srvTensorBindings[bindingIndex].name, shaderBlob.boundSRVTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
                outPipeline->srvTensorBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            }
        }

        outPipeline->srvTensorCount = flattenedSrvTensorCount;
        FFX_ASSERT(outPipeline->srvTensorCount < FFX_MAX_NUM_TENSORS);
    }

    {
        uint32_t flattenedUavTensorCount = 0;

        for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.uavTensorCount; ++tensorIndex)
        {
            uint32_t slotIndex = shaderBlob.boundUAVTensors[tensorIndex];
            uint32_t bindCount = shaderBlob.boundUAVTensorCounts[tensorIndex];

            for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
            {
                uint32_t bindingIndex = flattenedUavTensorCount++;

                outPipeline->uavTensorBindings[bindingIndex].slotIndex  = slotIndex;
                outPipeline->uavTensorBindings[bindingIndex].arrayIndex = arrayIndex;
                strncpy(outPipeline->uavTensorBindings[bindingIndex].name, shaderBlob.boundUAVTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
                outPipeline->uavTensorBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            }
        }

        outPipeline->uavTensorCount = flattenedUavTensorCount;
        FFX_ASSERT(outPipeline->uavTensorCount < FFX_MAX_NUM_TENSORS);
    }

    for (uint32_t cbIndex = 0; cbIndex < shaderBlob.cbvCount; ++cbIndex)
    {
        outPipeline->constantBufferBindings[cbIndex].slotIndex  = shaderBlob.boundConstantBuffers[cbIndex];
        outPipeline->constantBufferBindings[cbIndex].arrayIndex = 1;
        strncpy(outPipeline->constantBufferBindings[cbIndex].name, shaderBlob.boundConstantBufferNames[cbIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->constantBufferBindings[cbIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }

    outPipeline->constCount = shaderBlob.cbvCount;
    FFX_ASSERT(outPipeline->constCount < FFX_MAX_NUM_CONST_BUFFERS);

    outPipeline->staticTextureSrvCount = staticTextureSrvCount;
    FFX_ASSERT(outPipeline->staticTextureSrvCount <= effectContext.bindlessTextureSrvHeapSize);

    outPipeline->staticBufferSrvCount = staticBufferSrvCount;
    FFX_ASSERT(outPipeline->staticBufferSrvCount <= effectContext.bindlessBufferSrvHeapSize);

    outPipeline->staticTextureUavCount = staticTextureUavCount;
    FFX_ASSERT(outPipeline->staticTextureUavCount <= effectContext.bindlessTextureUavHeapSize);

    outPipeline->staticBufferUavCount = staticBufferUavCount;
    FFX_ASSERT(outPipeline->staticBufferUavCount <= effectContext.bindlessBufferUavHeapSize);

                       
                                                               
                                                                     

                                                                              
                        
    FfxDeviceCapabilities capabilities;
    FFX_VALIDATE(backendInterface->fpGetDeviceCapabilities(backendInterface, &capabilities));
    FFX_ASSERT(backendInterface->devCapInitialized);

                    
    VkShaderModule           shaderModule           = VK_NULL_HANDLE;
    VkShaderModuleCreateInfo shaderModuleCreateInfo = {};
    shaderModuleCreateInfo.sType                    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    shaderModuleCreateInfo.pCode                    = (uint32_t*)shaderBlob.data;
    shaderModuleCreateInfo.codeSize                 = shaderBlob.size;

    if (VulkanWrapper().vkCreateShaderModule(backendContext->device, &shaderModuleCreateInfo, nullptr, &shaderModule) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                        
    VkPipelineShaderStageCreateInfo shaderStageCreateInfo = {};
    shaderStageCreateInfo.sType                           = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStageCreateInfo.stage                           = VK_SHADER_STAGE_COMPUTE_BIT;
    shaderStageCreateInfo.pName                           = "main";
    shaderStageCreateInfo.module                          = shaderModule;

                                   
    bool isWave64 = false;
    ffxIsWave64(effect, permutationOptions, isWave64);
    VkPipelineShaderStageRequiredSubgroupSizeCreateInfoEXT subgroupSizeCreateInfo = {};
    if (isWave64 && (capabilities.waveLaneCountMin <= 64 && capabilities.waveLaneCountMax >= 64))
    {
        subgroupSizeCreateInfo.sType                = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO_EXT;
        subgroupSizeCreateInfo.requiredSubgroupSize = 64;
        shaderStageCreateInfo.pNext                 = &subgroupSizeCreateInfo;
    }

                                  
    VkComputePipelineCreateInfo pipelineCreateInfo = {};
    pipelineCreateInfo.sType                       = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    pipelineCreateInfo.stage                       = shaderStageCreateInfo;
    pipelineCreateInfo.layout                      = pPipelineLayout->pipelineLayout;
    pipelineCreateInfo.flags                      |= nfru_isa::createFlags(backendContext->device);

    VkPipeline computePipeline = VK_NULL_HANDLE;
    if (VulkanWrapper().vkCreateComputePipelines(backendContext->device, nullptr, 1, &pipelineCreateInfo, nullptr, &computePipeline) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    nfru_isa::dump(backendContext->device, computePipeline, pipelineDescription ? pipelineDescription->name : "ffx_pass");

                                           
    VulkanWrapper().vkDestroyShaderModule(backendContext->device, shaderModule, nullptr);

                       
    outPipeline->pipeline = reinterpret_cast<FfxPipeline>(computePipeline);

                              
    strncpy(outPipeline->name, pipelineDescription->name, FFX_RESOURCE_NAME_SIZE - 1);
    outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

    return FFX_OK;
}

FfxErrorCode CreateGraphicsPipelineVK(FfxInterface*                 backendInterface,
                                      FfxEffect                     effect,
                                      FfxPass                       pass,
                                      uint32_t                      permutationOptions,
                                      const FfxPipelineDescription* pipelineDescription,
                                      FfxUInt32                     effectContextId,
                                      FfxPipelineState*             outPipeline)
{
    nss_trace("backend: CreateGraphicsPipeline effect=%d pass=%d", (int) effect, (int) pass);
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != pipelineDescription);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

                                        
    FfxShaderBlob shaderBlob     = {};
    FfxShaderBlob vertShaderBlob = {};

    FFX_VALIDATE(backendInterface->fpGetPermutationBlobByIndex(effect, pass, permutationOptions, &shaderBlob, &vertShaderBlob, nullptr));
    FFX_ASSERT(shaderBlob.data && shaderBlob.size);
    FFX_ASSERT(vertShaderBlob.data && vertShaderBlob.size);

                                                                              
                                                           
    FFX_ASSERT_MESSAGE(effectContext.nextPipelineLayout < (effectContextId * FFX_MAX_PASS_COUNT) + FFX_MAX_PASS_COUNT,
                       "FFXInterface: Vulkan: Ran out of pipeline layouts. Please increase FFX_MAX_PASS_COUNT");
    BackendContext_VK::PipelineLayout* pPipelineLayout = &backendContext->pPipelineLayouts[effectContext.nextPipelineLayout++];

                                 
    FFX_ASSERT(pipelineDescription->samplerCount <= FFX_MAX_SAMPLERS);
    const size_t samplerCount = pipelineDescription->samplerCount;
    for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < samplerCount; ++currentSamplerIndex)
    {
        VkSamplerCreateInfo createInfo = {};

        createInfo.maxLod                  = pipelineDescription->samplers[currentSamplerIndex].unnormalizedCoordinates ? 0.f : VK_LOD_CLAMP_NONE;
        createInfo.unnormalizedCoordinates = pipelineDescription->samplers[currentSamplerIndex].unnormalizedCoordinates ? VK_TRUE : VK_FALSE;

        createInfo.sType            = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        createInfo.pNext            = nullptr;
        createInfo.flags            = 0;
        createInfo.minLod           = 0.f;
        createInfo.anisotropyEnable = false;
        createInfo.compareEnable    = false;
        createInfo.compareOp        = VK_COMPARE_OP_NEVER;
        createInfo.borderColor      = VK_BORDER_COLOR_INT_TRANSPARENT_BLACK;
        createInfo.addressModeU     = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeU);
        createInfo.addressModeV     = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeV);
        createInfo.addressModeW     = FfxGetAddressModeVK(pipelineDescription->samplers[currentSamplerIndex].addressModeW);

                               
        switch (pipelineDescription->samplers[currentSamplerIndex].filter)
        {
        case FFX_FILTER_TYPE_MINMAGMIP_POINT:
            createInfo.minFilter  = VK_FILTER_NEAREST;
            createInfo.magFilter  = VK_FILTER_NEAREST;
            createInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            break;
        case FFX_FILTER_TYPE_MINMAGMIP_LINEAR:
            createInfo.minFilter  = VK_FILTER_LINEAR;
            createInfo.magFilter  = VK_FILTER_LINEAR;
            createInfo.mipmapMode = createInfo.unnormalizedCoordinates ? VK_SAMPLER_MIPMAP_MODE_NEAREST : VK_SAMPLER_MIPMAP_MODE_LINEAR;
            break;
        case FFX_FILTER_TYPE_MINMAGLINEARMIP_POINT:
            createInfo.minFilter  = VK_FILTER_LINEAR;
            createInfo.magFilter  = VK_FILTER_LINEAR;
            createInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            break;

        default:
            FFX_ASSERT_MESSAGE(false, "FFXInterface: Vulkan: Unsupported filter type requested. Please implement");
            break;
        }

        if (VulkanWrapper().vkCreateSampler(backendContext->device, &createInfo, nullptr, &pPipelineLayout->samplers[currentSamplerIndex]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    int32_t staticTextureSrvCount = 0;
    int32_t staticBufferSrvCount  = 0;
    int32_t staticTextureUavCount = 0;
    int32_t staticBufferUavCount  = 0;

    pPipelineLayout->staticTextureSrvSet = -1;
    pPipelineLayout->staticBufferSrvSet  = -1;
    pPipelineLayout->staticTextureUavSet = -1;
    pPipelineLayout->staticBufferUavSet  = -1;

                            
    VkDescriptorSetLayoutBinding layoutBindings[MAX_DESCRIPTOR_SET_LAYOUTS];
    uint32_t                     numLayoutBindings = 0;

                               
    VkShaderStageFlags shaderStageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

                                              
    for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < samplerCount; ++currentSamplerIndex)
        layoutBindings[numLayoutBindings++] = {
            currentSamplerIndex + SAMPLER_BINDING_SHIFT, VK_DESCRIPTOR_TYPE_SAMPLER, 1, shaderStageFlags, &pPipelineLayout->samplers[currentSamplerIndex]};

                   
    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; ++srvIndex)
    {
                                        
        if (shaderBlob.boundSRVTextureSpaces[srvIndex] != 0)
        {
            if (staticTextureSrvCount > 0)
                FFX_ASSERT(pPipelineLayout->staticTextureSrvSet != shaderBlob.boundSRVTextureSpaces[srvIndex]);

            staticTextureSrvCount += shaderBlob.boundSRVTextureCounts[srvIndex];
            pPipelineLayout->staticTextureSrvSet = shaderBlob.boundSRVTextureSpaces[srvIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVTextures[srvIndex], VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, shaderBlob.boundSRVTextureCounts[srvIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvBufferCount; ++srvIndex)
    {
                                        
        if (shaderBlob.boundSRVBufferSpaces[srvIndex] != 0)
        {
            if (staticBufferSrvCount > 0)
                FFX_ASSERT(pPipelineLayout->staticBufferSrvSet != shaderBlob.boundSRVBufferSpaces[srvIndex]);

            staticBufferSrvCount += shaderBlob.boundSRVBufferCounts[srvIndex];
            pPipelineLayout->staticBufferSrvSet = shaderBlob.boundSRVBufferSpaces[srvIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVBuffers[srvIndex], VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shaderBlob.boundSRVBufferCounts[srvIndex], shaderStageFlags, nullptr};
    }

                   
    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; ++uavIndex)
    {
                                        
        if (shaderBlob.boundUAVTextureSpaces[uavIndex] != 0)
        {
            if (staticTextureUavCount > 0)
                FFX_ASSERT(pPipelineLayout->staticTextureUavSet != shaderBlob.boundUAVTextureSpaces[uavIndex]);

            staticTextureUavCount += shaderBlob.boundUAVTextureCounts[uavIndex];
            pPipelineLayout->staticTextureUavSet = shaderBlob.boundUAVTextureSpaces[uavIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVTextures[uavIndex], VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, shaderBlob.boundUAVTextureCounts[uavIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; ++uavIndex)
    {
                                        
        if (shaderBlob.boundUAVBufferSpaces[uavIndex] != 0)
        {
            if (staticBufferUavCount > 0)
                FFX_ASSERT(pPipelineLayout->staticBufferUavSet != shaderBlob.boundUAVBufferSpaces[uavIndex]);

            staticBufferUavCount += shaderBlob.boundUAVBufferCounts[uavIndex];
            pPipelineLayout->staticBufferUavSet = shaderBlob.boundUAVBufferSpaces[uavIndex];
            continue;
        }

        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVBuffers[uavIndex], VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, shaderBlob.boundUAVBufferCounts[uavIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.srvTensorCount; ++tensorIndex)
    {
        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundSRVTensors[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, shaderBlob.boundSRVTensorCounts[tensorIndex], shaderStageFlags, nullptr};
    }

                  
    for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.uavTensorCount; ++tensorIndex)
    {
        layoutBindings[numLayoutBindings++] = {
            shaderBlob.boundUAVTensors[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, shaderBlob.boundUAVTensorCounts[tensorIndex], shaderStageFlags, nullptr};
    }

                                  
    for (uint32_t cbIndex = 0; cbIndex < shaderBlob.cbvCount; ++cbIndex)
    {
        layoutBindings[numLayoutBindings++] = {shaderBlob.boundConstantBuffers[cbIndex],
                                               VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                                               shaderBlob.boundConstantBufferCounts[cbIndex],
                                               shaderStageFlags,
                                               nullptr};
    }

                                   
    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount                    = numLayoutBindings;
    layoutInfo.pBindings                       = layoutBindings;

    if (VulkanWrapper().vkCreateDescriptorSetLayout(backendContext->device, &layoutInfo, nullptr, &pPipelineLayout->descriptorSetLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                               
    pPipelineLayout->descriptorSetIndex = 0;
    for (uint32_t i = 0; i < (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME); i++)
    {
        VkDescriptorSetAllocateInfo allocateInfo = {};
        allocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocateInfo.descriptorPool              = backendContext->descriptorPool;
        allocateInfo.descriptorSetCount          = 1;
        allocateInfo.pSetLayouts                 = &pPipelineLayout->descriptorSetLayout;

        if (VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &allocateInfo, &pPipelineLayout->descriptorSets[i]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    uint32_t setCount = 0;

    VkDescriptorSetLayout layouts[5];

    layouts[setCount++] = pPipelineLayout->descriptorSetLayout;

    if (staticTextureSrvCount > 0)
    {
        layouts[pPipelineLayout->staticTextureSrvSet] = effectContext.bindlessTextureSrvDescriptorSetLayout;
        setCount++;
    }

    if (staticBufferSrvCount > 0)
    {
        layouts[pPipelineLayout->staticBufferSrvSet] = effectContext.bindlessBufferSrvDescriptorSetLayout;
        setCount++;
    }

    if (staticTextureUavCount > 0)
    {
        layouts[pPipelineLayout->staticTextureUavSet] = effectContext.bindlessTextureUavDescriptorSetLayout;
        setCount++;
    }

    if (staticBufferUavCount > 0)
    {
        layouts[pPipelineLayout->staticBufferUavSet] = effectContext.bindlessBufferUavDescriptorSetLayout;
        setCount++;
    }

                                 
    VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
    pipelineLayoutInfo.sType                  = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount         = setCount;
    pipelineLayoutInfo.pSetLayouts            = layouts;
    pipelineLayoutInfo.pushConstantRangeCount = 0;
    pipelineLayoutInfo.pPushConstantRanges    = nullptr;

    if (VulkanWrapper().vkCreatePipelineLayout(backendContext->device, &pipelineLayoutInfo, nullptr, &pPipelineLayout->pipelineLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                         
    outPipeline->rootSignature = reinterpret_cast<FfxRootSignature>(pPipelineLayout);
                                                                                                                                         
    outPipeline->uavTextureCount = 0;
    outPipeline->srvTextureCount = 0;
    outPipeline->rtCount         = 0;

                                                                              
    if (pipelineDescription->indirectWorkload)
    {
                                                       
        outPipeline->cmdSignature = reinterpret_cast<FfxCommandSignature>(sizeof(VkDispatchIndirectCommand));
    }
    else
    {
        outPipeline->cmdSignature = nullptr;
    }

    uint32_t flattenedSrvTextureCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvTextureCount; ++srvIndex)
    {
        uint32_t slotIndex = shaderBlob.boundSRVTextures[srvIndex];
        uint32_t bindCount = shaderBlob.boundSRVTextureCounts[srvIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvTextureCount++;

            outPipeline->srvTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->srvTextureBindings[bindingIndex].name, shaderBlob.boundSRVTextureNames[srvIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->srvTextureBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->srvTextureCount = flattenedSrvTextureCount;
    FFX_ASSERT(outPipeline->srvTextureCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavTextureCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavTextureCount; ++uavIndex)
    {
        uint32_t slotIndex = shaderBlob.boundUAVTextures[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVTextureCounts[uavIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavTextureCount++;

            outPipeline->uavTextureBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavTextureBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->uavTextureBindings[bindingIndex].name, shaderBlob.boundUAVTextureNames[uavIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->uavTextureBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->uavTextureCount = flattenedUavTextureCount;
    FFX_ASSERT(outPipeline->uavTextureCount < FFX_MAX_NUM_UAVS);

    uint32_t flattenedRtTextureCount = 0;

    for (uint32_t rtIndex = 0; rtIndex < shaderBlob.rtTextureCount; ++rtIndex)
    {
        uint32_t slotIndex = shaderBlob.boundRTTextures[rtIndex];
        uint32_t bindCount = shaderBlob.boundRTTextureCounts[rtIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedRtTextureCount++;

            outPipeline->rtBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->rtBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->rtBindings[bindingIndex].name, shaderBlob.boundRTTextureNames[rtIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->rtBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->rtCount = flattenedRtTextureCount;
    FFX_ASSERT(outPipeline->rtCount < FFX_MAX_NUM_RTS);

    uint32_t flattenedSrvBufferCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < shaderBlob.srvBufferCount; ++srvIndex)
    {
        uint32_t slotIndex  = shaderBlob.boundSRVBuffers[srvIndex];
        uint32_t spaceIndex = shaderBlob.boundSRVBufferSpaces[srvIndex];
        uint32_t bindCount  = shaderBlob.boundSRVBufferCounts[srvIndex];

                                
        if (spaceIndex == 1)
            continue;

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedSrvBufferCount++;

            outPipeline->srvBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->srvBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->srvBufferBindings[bindingIndex].name, shaderBlob.boundSRVBufferNames[srvIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->srvBufferBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->srvBufferCount = flattenedSrvBufferCount;
    FFX_ASSERT(outPipeline->srvBufferCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavBufferCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < shaderBlob.uavBufferCount; ++uavIndex)
    {
        uint32_t slotIndex = shaderBlob.boundUAVBuffers[uavIndex];
        uint32_t bindCount = shaderBlob.boundUAVBufferCounts[uavIndex];

        for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
        {
            uint32_t bindingIndex = flattenedUavBufferCount++;

            outPipeline->uavBufferBindings[bindingIndex].slotIndex  = slotIndex;
            outPipeline->uavBufferBindings[bindingIndex].arrayIndex = arrayIndex;
            strncpy(outPipeline->uavBufferBindings[bindingIndex].name, shaderBlob.boundUAVBufferNames[uavIndex], FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->uavBufferBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        }
    }

    outPipeline->uavBufferCount = flattenedUavBufferCount;
    FFX_ASSERT(outPipeline->uavBufferCount < FFX_MAX_NUM_UAVS);

    {
        uint32_t flattenedSrvTensorCount = 0;

        for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.srvTensorCount; ++tensorIndex)
        {
            uint32_t slotIndex = shaderBlob.boundSRVTensors[tensorIndex];
            uint32_t bindCount = shaderBlob.boundSRVTensorCounts[tensorIndex];

            for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
            {
                uint32_t bindingIndex = flattenedSrvTensorCount++;

                outPipeline->srvTensorBindings[bindingIndex].slotIndex  = slotIndex;
                outPipeline->srvTensorBindings[bindingIndex].arrayIndex = arrayIndex;
                strncpy(outPipeline->srvTensorBindings[bindingIndex].name, shaderBlob.boundSRVTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
                outPipeline->srvTensorBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            }
        }

        outPipeline->srvTensorCount = flattenedSrvTensorCount;
        FFX_ASSERT(outPipeline->srvTensorCount < FFX_MAX_NUM_TENSORS);
    }

    {
        uint32_t flattenedUavTensorCount = 0;

        for (uint32_t tensorIndex = 0; tensorIndex < shaderBlob.uavTensorCount; ++tensorIndex)
        {
            uint32_t slotIndex = shaderBlob.boundUAVTensors[tensorIndex];
            uint32_t bindCount = shaderBlob.boundUAVTensorCounts[tensorIndex];

            for (uint32_t arrayIndex = 0; arrayIndex < bindCount; arrayIndex++)
            {
                uint32_t bindingIndex = flattenedUavTensorCount++;

                outPipeline->uavTensorBindings[bindingIndex].slotIndex  = slotIndex;
                outPipeline->uavTensorBindings[bindingIndex].arrayIndex = arrayIndex;
                strncpy(outPipeline->uavTensorBindings[bindingIndex].name, shaderBlob.boundUAVTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
                outPipeline->uavTensorBindings[bindingIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            }
        }

        outPipeline->uavTensorCount = flattenedUavTensorCount;
        FFX_ASSERT(outPipeline->uavTensorCount < FFX_MAX_NUM_TENSORS);
    }

    for (uint32_t cbIndex = 0; cbIndex < shaderBlob.cbvCount; ++cbIndex)
    {
        outPipeline->constantBufferBindings[cbIndex].slotIndex  = shaderBlob.boundConstantBuffers[cbIndex];
        outPipeline->constantBufferBindings[cbIndex].arrayIndex = 1;
        strncpy(outPipeline->constantBufferBindings[cbIndex].name, shaderBlob.boundConstantBufferNames[cbIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->constantBufferBindings[cbIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }

    outPipeline->constCount = shaderBlob.cbvCount;
    FFX_ASSERT(outPipeline->constCount < FFX_MAX_NUM_CONST_BUFFERS);

    outPipeline->staticTextureSrvCount = staticTextureSrvCount;
    FFX_ASSERT(outPipeline->staticTextureSrvCount <= effectContext.bindlessTextureSrvHeapSize);

    outPipeline->staticBufferSrvCount = staticBufferSrvCount;
    FFX_ASSERT(outPipeline->staticBufferSrvCount <= effectContext.bindlessBufferSrvHeapSize);

    outPipeline->staticTextureUavCount = staticTextureUavCount;
    FFX_ASSERT(outPipeline->staticTextureUavCount <= effectContext.bindlessTextureUavHeapSize);

    outPipeline->staticBufferUavCount = staticBufferUavCount;
    FFX_ASSERT(outPipeline->staticBufferUavCount <= effectContext.bindlessBufferUavHeapSize);

                       
                                                               
                                                                     

                                                                              
                        

                    
    VkShaderModuleCreateInfo shaderModuleCreateInfo = {};
    shaderModuleCreateInfo.sType                    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    shaderModuleCreateInfo.pCode                    = (uint32_t*)shaderBlob.data;
    shaderModuleCreateInfo.codeSize                 = shaderBlob.size;

    if (VulkanWrapper().vkCreateShaderModule(backendContext->device, &shaderModuleCreateInfo, nullptr, &pPipelineLayout->fragShaderModule) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    shaderModuleCreateInfo          = {};
    shaderModuleCreateInfo.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    shaderModuleCreateInfo.pCode    = (uint32_t*)vertShaderBlob.data;
    shaderModuleCreateInfo.codeSize = vertShaderBlob.size;

    if (VulkanWrapper().vkCreateShaderModule(backendContext->device, &shaderModuleCreateInfo, nullptr, &pPipelineLayout->vertShaderModule) != VK_SUCCESS)
    {
        VulkanWrapper().vkDestroyShaderModule(backendContext->device, pPipelineLayout->fragShaderModule, nullptr);
        pPipelineLayout->fragShaderModule = VK_NULL_HANDLE;
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                              
    strncpy(outPipeline->name, pipelineDescription->name, FFX_RESOURCE_NAME_SIZE - 1);
    outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

    return FFX_OK;
}

template <size_t SIZE, typename T>
int8_t findObject(T (&objs)[SIZE], uint64_t hash)
{
    int8_t idx = -1;

    for (int8_t i = 0; i < SIZE; i++)
    {
        objs[i].visitedFlag++;

        if (objs[i].hash == hash)
        {
            objs[i].visitedFlag = 0;
            idx                 = i;
        }
    }

    return idx;
}

template <size_t SIZE, typename T>
uint8_t getLRUIndex(T (&objs)[SIZE])
{
    FfxUInt32 max = 0;
    uint8_t   idx = 0;

    for (uint8_t i = 0; i < SIZE; i++)
    {
        if (objs[i].visitedFlag > max)
        {
            max = objs[i].visitedFlag;
            idx = i;
        }
    }

    objs[idx].visitedFlag = 0;

    return idx;
}

FfxErrorCode getOrCreateFrameBuffer(BackendContext_VK* backendContext, FfxGpuJobDescription* job)
{
    FFX_ASSERT(NULL != backendContext);
    BackendContext_VK::PipelineLayout* pipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->fragmentJobDescriptor.pipeline.rootSignature);
    FfxPipelineState*                  pipeline       = &job->fragmentJobDescriptor.pipeline;

    std::array<VkImageView, FFX_MAX_NUM_RTS> attachments;
    for (FfxUInt32 rtIndex = 0; rtIndex < pipeline->rtCount; ++rtIndex)
    {
        const FfxUInt32       resourceIndex    = job->fragmentJobDescriptor.rtTextures[rtIndex].resource.internalIndex;
        VkImageViewCreateInfo createInfo       = {};
        createInfo.sType                       = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        createInfo.image                       = backendContext->pResources[resourceIndex].imageResource;
        createInfo.viewType                    = VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format                      = getVkFormatFromSurfaceFormatAndUsage(backendContext->pResources[resourceIndex].resourceDescription.format,
                                                                 backendContext->pResources[resourceIndex].resourceDescription.usage);
        createInfo.components.r                = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.g                = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.b                = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.a                = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.subresourceRange.aspectMask = (backendContext->pResources[resourceIndex].resourceDescription.usage & FFX_RESOURCE_USAGE_DEPTHTARGET)
                                                     ? VK_IMAGE_ASPECT_DEPTH_BIT
                                                     : VK_IMAGE_ASPECT_COLOR_BIT;
        createInfo.subresourceRange.baseMipLevel   = 0;
        createInfo.subresourceRange.levelCount     = 1;
        createInfo.subresourceRange.baseArrayLayer = 0;
        createInfo.subresourceRange.layerCount     = 1;

        uint64_t hash = arm::computeHash(&createInfo, sizeof(createInfo));

        int8_t idx = findObject(pipelineLayout->imageView, hash);

                          
        if (idx != -1)
        {
            pipelineLayout->imageViewIndex = idx;
        }
        else
        {
                                                   
            pipelineLayout->imageViewIndex = getLRUIndex(pipelineLayout->imageView);

            if (pipelineLayout->imageView[pipelineLayout->imageViewIndex].handle != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyImageView(backendContext->device, pipelineLayout->imageView[pipelineLayout->imageViewIndex].handle, VK_NULL_HANDLE);
            }

            if (VulkanWrapper().vkCreateImageView(
                    backendContext->device, &createInfo, nullptr, &pipelineLayout->imageView[pipelineLayout->imageViewIndex].handle) != VK_SUCCESS)
            {
                return FFX_ERROR_BACKEND_API_ERROR;
            }

            pipelineLayout->imageView[pipelineLayout->imageViewIndex].hash = hash;
        }

        attachments[rtIndex] = pipelineLayout->imageView[pipelineLayout->imageViewIndex].handle;
    }

    uint64_t hash = arm::computeHash(attachments.data(), pipeline->rtCount * sizeof(attachments[0]));

    VkFramebufferCreateInfo fbufCreateInfo = {};
    fbufCreateInfo.sType                   = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    fbufCreateInfo.renderPass              = pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle;
    fbufCreateInfo.attachmentCount         = pipeline->rtCount;
    fbufCreateInfo.width                   = job->fragmentJobDescriptor.viewport[0];
    fbufCreateInfo.height                  = job->fragmentJobDescriptor.viewport[1];
    fbufCreateInfo.layers                  = 1;

    hash = arm::appendHash(&fbufCreateInfo, sizeof(fbufCreateInfo), hash);

    fbufCreateInfo.pAttachments = attachments.data();

    int8_t idx = findObject(pipelineLayout->frameBuffer, hash);

                        
    if (idx != -1)
    {
        pipelineLayout->frameBufferIndex = idx;
    }
    else
    {
                                               
        pipelineLayout->frameBufferIndex = getLRUIndex(pipelineLayout->frameBuffer);

        if (pipelineLayout->frameBuffer[pipelineLayout->frameBufferIndex].handle != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyFramebuffer(backendContext->device, pipelineLayout->frameBuffer[pipelineLayout->frameBufferIndex].handle, VK_NULL_HANDLE);
        }

        if (VulkanWrapper().vkCreateFramebuffer(
                backendContext->device, &fbufCreateInfo, nullptr, &pipelineLayout->frameBuffer[pipelineLayout->frameBufferIndex].handle) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

        pipelineLayout->frameBuffer[pipelineLayout->frameBufferIndex].hash = hash;
    }

    return FFX_OK;
}

FfxErrorCode getOrCreateRenderPass(BackendContext_VK* backendContext, FfxGpuJobDescription* job)
{
    FFX_ASSERT(NULL != backendContext);
    BackendContext_VK::PipelineLayout* pipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->fragmentJobDescriptor.pipeline.rootSignature);
    FfxPipelineState*                  pipeline       = &job->fragmentJobDescriptor.pipeline;

    std::array<VkAttachmentDescription, FFX_MAX_NUM_RTS> attachmentDescriptions;
    std::array<VkAttachmentReference, FFX_MAX_NUM_RTS>   colorAttachmentReferences;

    for (FfxUInt32 rtIndex = 0; rtIndex < pipeline->rtCount; ++rtIndex)
    {
        const FfxUInt32         resourceIndex         = job->fragmentJobDescriptor.rtTextures[rtIndex].resource.internalIndex;
        VkAttachmentDescription attachmentDescription = {};
        attachmentDescription.format         = getVkFormatFromSurfaceFormatAndUsage(backendContext->pResources[resourceIndex].resourceDescription.format,
                                                                            backendContext->pResources[resourceIndex].resourceDescription.usage);
        attachmentDescription.samples        = VK_SAMPLE_COUNT_1_BIT;
        attachmentDescription.loadOp         = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachmentDescription.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
        attachmentDescription.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachmentDescription.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachmentDescription.initialLayout  = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachmentDescription.finalLayout    = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        attachmentDescriptions[rtIndex] = attachmentDescription;

        VkAttachmentReference colorAttachmentReference = {};
        colorAttachmentReference.attachment            = rtIndex;
        colorAttachmentReference.layout                = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        colorAttachmentReferences[rtIndex] = colorAttachmentReference;
    }

    uint64_t hash = arm::computeHash(attachmentDescriptions.data(), pipeline->rtCount * sizeof(attachmentDescriptions[0]));
    hash          = arm::appendHash(colorAttachmentReferences.data(), pipeline->rtCount * sizeof(colorAttachmentReferences[0]), hash);

                                                                                                          
                                                           
    VkSubpassDescription subPassDescription = {};
    subPassDescription.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subPassDescription.colorAttachmentCount = pipeline->rtCount;
    subPassDescription.pColorAttachments    = colorAttachmentReferences.data();

                             
    VkRenderPassCreateInfo renderPassCreateInfo = {};
    renderPassCreateInfo.sType                  = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderPassCreateInfo.attachmentCount        = pipeline->rtCount;
    renderPassCreateInfo.pAttachments           = attachmentDescriptions.data();
    renderPassCreateInfo.subpassCount           = 1;
    renderPassCreateInfo.pSubpasses             = &subPassDescription;

    int8_t idx = findObject(pipelineLayout->renderPass, hash);

                       
    if (idx != -1)
    {
        pipelineLayout->renderPassIndex = idx;
    }
    else
    {
                                               
        pipelineLayout->renderPassIndex = getLRUIndex(pipelineLayout->renderPass);

        if (pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyRenderPass(backendContext->device, pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle, VK_NULL_HANDLE);
        }

        if (VulkanWrapper().vkCreateRenderPass(
                backendContext->device, &renderPassCreateInfo, nullptr, &pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }

        pipelineLayout->renderPass[pipelineLayout->renderPassIndex].hash = hash;
    }

    return FFX_OK;
}

FfxErrorCode getOrCreateGraphicsPipeline(BackendContext_VK* backendContext, FfxGpuJobDescription* job)
{
    FFX_ASSERT(NULL != backendContext);
    BackendContext_VK::PipelineLayout* pipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->fragmentJobDescriptor.pipeline.rootSignature);
    FfxPipelineState*                  pipeline       = &job->fragmentJobDescriptor.pipeline;

                                                                  
    uint64_t hash = arm::computeHash(&pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle,
                                     sizeof(pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle));

    int8_t idx = findObject(pipelineLayout->graphicsPipeline, hash);

                             
    if (idx != -1)
    {
        pipelineLayout->graphicsPipelineIndex = idx;

                           
        pipeline->pipeline = reinterpret_cast<FfxPipeline>(pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].handle);

        return FFX_OK;
    }

                                        
    VkPipelineShaderStageCreateInfo fragShaderStageCreateInfo = {};
    fragShaderStageCreateInfo.sType                           = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    fragShaderStageCreateInfo.stage                           = VK_SHADER_STAGE_FRAGMENT_BIT;
    fragShaderStageCreateInfo.pName                           = "main";
    fragShaderStageCreateInfo.module                          = pipelineLayout->fragShaderModule;

    VkPipelineShaderStageCreateInfo vertShaderStageCreateInfo = {};
    vertShaderStageCreateInfo.sType                           = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vertShaderStageCreateInfo.stage                           = VK_SHADER_STAGE_VERTEX_BIT;
    vertShaderStageCreateInfo.pName                           = "main";
    vertShaderStageCreateInfo.module                          = pipelineLayout->vertShaderModule;

    VkPipelineShaderStageCreateInfo shaderStages[] = {vertShaderStageCreateInfo, fragShaderStageCreateInfo};

                            
    VkPipelineVertexInputStateCreateInfo vertexInputCreateInfo = {};
    vertexInputCreateInfo.sType                                = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertexInputCreateInfo.vertexBindingDescriptionCount        = 0;
    vertexInputCreateInfo.pVertexBindingDescriptions           = nullptr;
    vertexInputCreateInfo.vertexAttributeDescriptionCount      = 0;
    vertexInputCreateInfo.pVertexAttributeDescriptions         = nullptr;

                              
    VkPipelineInputAssemblyStateCreateInfo inputAssemblyCreateInfo = {};
    inputAssemblyCreateInfo.sType                                  = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssemblyCreateInfo.topology                               = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssemblyCreateInfo.primitiveRestartEnable                 = VK_FALSE;

    VkPipelineViewportStateCreateInfo viewportCreateInfo = {};
    viewportCreateInfo.sType                             = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportCreateInfo.viewportCount                     = 1;
    viewportCreateInfo.scissorCount                      = 1;

    VkDynamicState                   dynamicState[2]        = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
    VkPipelineDynamicStateCreateInfo dynamicStateCreateInfo = {};
    dynamicStateCreateInfo.sType                            = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicStateCreateInfo.dynamicStateCount                = 2;
    dynamicStateCreateInfo.pDynamicStates                   = dynamicState;

    VkPipelineRasterizationStateCreateInfo rasterizationCreateInfo = {};
    rasterizationCreateInfo.sType                                  = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizationCreateInfo.depthClampEnable                       = VK_FALSE;
    rasterizationCreateInfo.rasterizerDiscardEnable                = VK_FALSE;
    rasterizationCreateInfo.polygonMode                            = VK_POLYGON_MODE_FILL;
    rasterizationCreateInfo.cullMode                               = VK_CULL_MODE_BACK_BIT;
    rasterizationCreateInfo.frontFace                              = VK_FRONT_FACE_CLOCKWISE;
    rasterizationCreateInfo.depthBiasEnable                        = VK_FALSE;
    rasterizationCreateInfo.depthBiasConstantFactor                = 0.0f;
    rasterizationCreateInfo.depthBiasClamp                         = 0.0f;
    rasterizationCreateInfo.depthBiasSlopeFactor                   = 0.0f;
    rasterizationCreateInfo.lineWidth                              = 1.0f;

    VkPipelineMultisampleStateCreateInfo multisampleCreateInfo = {};
    multisampleCreateInfo.sType                                = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampleCreateInfo.rasterizationSamples                 = VK_SAMPLE_COUNT_1_BIT;
    multisampleCreateInfo.sampleShadingEnable                  = VK_FALSE;
    multisampleCreateInfo.minSampleShading                     = 1.0f;        
    multisampleCreateInfo.alphaToCoverageEnable                = VK_FALSE;
    multisampleCreateInfo.alphaToOneEnable                     = VK_FALSE;

    std::array<VkPipelineColorBlendAttachmentState, FFX_MAX_NUM_RTS> colorBlendAttachmentStates;
    for (FfxUInt32 rtIndex = 0; rtIndex < pipeline->rtCount; ++rtIndex)
    {
        VkPipelineColorBlendAttachmentState colorBlendAttachmentState = {};
        colorBlendAttachmentState.blendEnable                         = VK_FALSE;
        colorBlendAttachmentState.srcColorBlendFactor                 = VK_BLEND_FACTOR_ONE;
        colorBlendAttachmentState.dstColorBlendFactor                 = VK_BLEND_FACTOR_ZERO;
        colorBlendAttachmentState.colorBlendOp                        = VK_BLEND_OP_ADD;
        colorBlendAttachmentState.srcAlphaBlendFactor                 = VK_BLEND_FACTOR_ONE;
        colorBlendAttachmentState.dstAlphaBlendFactor                 = VK_BLEND_FACTOR_ZERO;
        colorBlendAttachmentState.alphaBlendOp                        = VK_BLEND_OP_ADD;
        colorBlendAttachmentState.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

        colorBlendAttachmentStates[rtIndex] = colorBlendAttachmentState;
    }

    VkPipelineColorBlendStateCreateInfo colorBlendCreateInfo = {};
    colorBlendCreateInfo.sType                               = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlendCreateInfo.logicOpEnable                       = VK_FALSE;
    colorBlendCreateInfo.logicOp                             = VK_LOGIC_OP_COPY;
    colorBlendCreateInfo.attachmentCount                     = pipeline->rtCount;
    colorBlendCreateInfo.pAttachments                        = colorBlendAttachmentStates.data();
    colorBlendCreateInfo.blendConstants[0]                   = 0.0f;
    colorBlendCreateInfo.blendConstants[1]                   = 0.0f;
    colorBlendCreateInfo.blendConstants[2]                   = 0.0f;
    colorBlendCreateInfo.blendConstants[3]                   = 0.0f;

                                   
    VkGraphicsPipelineCreateInfo pipelineCreateInfo = {};
    pipelineCreateInfo.sType                        = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineCreateInfo.stageCount                   = 2;
    pipelineCreateInfo.pStages                      = shaderStages;
    pipelineCreateInfo.pVertexInputState            = &vertexInputCreateInfo;
    pipelineCreateInfo.pInputAssemblyState          = &inputAssemblyCreateInfo;
    pipelineCreateInfo.pViewportState               = &viewportCreateInfo;
    pipelineCreateInfo.pRasterizationState          = &rasterizationCreateInfo;
    pipelineCreateInfo.pMultisampleState            = &multisampleCreateInfo;
    pipelineCreateInfo.pColorBlendState             = &colorBlendCreateInfo;
    pipelineCreateInfo.pDynamicState                = &dynamicStateCreateInfo;
    pipelineCreateInfo.layout                       = pipelineLayout->pipelineLayout;
    pipelineCreateInfo.renderPass                   = pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle;
    pipelineCreateInfo.subpass                      = 0;
    pipelineCreateInfo.basePipelineHandle           = VK_NULL_HANDLE;
    pipelineCreateInfo.basePipelineIndex            = -1;

                                           
    pipelineLayout->graphicsPipelineIndex = getLRUIndex(pipelineLayout->graphicsPipeline);

    if (pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].handle != VK_NULL_HANDLE)
    {
        VulkanWrapper().vkDestroyPipeline(
            backendContext->device, pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].handle, VK_NULL_HANDLE);
    }

    if (VulkanWrapper().vkCreateGraphicsPipelines(backendContext->device,
                                                  VK_NULL_HANDLE,
                                                  1,
                                                  &pipelineCreateInfo,
                                                  nullptr,
                                                  &pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].handle) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].hash = hash;

                       
    pipeline->pipeline = reinterpret_cast<FfxPipeline>(pipelineLayout->graphicsPipeline[pipelineLayout->graphicsPipelineIndex].handle);

    return FFX_OK;
}

FfxErrorCode CreateDataGraphPipelineVK(FfxInterface*                 backendInterface,
                                       FfxEffect                     effect,
                                       FfxPass                       passId,
                                       uint32_t                      permutationOptions,
                                       const FfxPipelineDescription* desc,
                                       FfxUInt32                     effectContextId,
                                       FfxUInt32                     dataGraphWidth,
                                       FfxUInt32                     dataGraphHeight,
                                       FfxPipelineState*             outPipeline)
{
    nss_trace("backend: CreateDataGraphPipeline effect=%d pass=%d size=%ux%u", (int) effect, (int) passId, (unsigned) dataGraphWidth, (unsigned) dataGraphHeight);
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(desc != nullptr);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

                                        
    FfxDataGraphBlob dataGraphBlob = {};
    FFX_VALIDATE(backendInterface->fpGetPermutationBlobByIndex(effect, passId, permutationOptions, nullptr, nullptr, &dataGraphBlob));

                                                                              
                                                           
    FFX_ASSERT_MESSAGE(effectContext.nextPipelineLayout < (effectContextId * FFX_MAX_PASS_COUNT) + FFX_MAX_PASS_COUNT,
                       "FFXInterface: Vulkan: Ran out of pipeline layouts. Please increase FFX_MAX_PASS_COUNT");
    BackendContext_VK::PipelineLayout* pPipelineLayout = &backendContext->pPipelineLayouts[effectContext.nextPipelineLayout++];

                                                                                         
                                                                                           
                                                                                     
                                                                                          
                                                                                       
                                                                                    
                                                                                           
                                    
    const bool useNfruBridge      = (passId == FFX_FRAMEINTERPOLATION_PASS_NFRU_INTERPOLATION) && loadNssEngine();
    const bool useNssEngineBridge = ((passId == FFX_NSS_PASS_DATA_GRAPH) && loadNssEngine()) || useNfruBridge;

    if (!useNssEngineBridge)
    {
                            
    std::vector<VkDescriptorSetLayoutBinding> layoutBindings;

                               
    VkShaderStageFlags shaderStageFlags = VK_SHADER_STAGE_ALL;

                    
    for (uint32_t tensorIndex = 0; tensorIndex < dataGraphBlob.inputTensorNums; ++tensorIndex)
    {
        VkDescriptorSetLayoutBinding binding = {dataGraphBlob.inputTensorBindings[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, 1, shaderStageFlags, nullptr};
        layoutBindings.emplace_back(binding);
    }

                     
    for (uint32_t tensorIndex = 0; tensorIndex < dataGraphBlob.outputTensorNums; ++tensorIndex)
    {
        VkDescriptorSetLayoutBinding binding = {dataGraphBlob.outputTensorBindings[tensorIndex], VK_DESCRIPTOR_TYPE_TENSOR_ARM, 1, shaderStageFlags, nullptr};
        layoutBindings.emplace_back(binding);
    }

    FFX_ASSERT(layoutBindings.size() <= MAX_DESCRIPTOR_SET_LAYOUTS);

                                   
    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount                    = static_cast<uint32_t>(layoutBindings.size());
    layoutInfo.pBindings                       = layoutBindings.data();

    if (VulkanWrapper().vkCreateDescriptorSetLayout(backendContext->device, &layoutInfo, nullptr, &pPipelineLayout->descriptorSetLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                               
    pPipelineLayout->descriptorSetIndex = 0;
    for (uint32_t i = 0; i < (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME); i++)
    {
        VkDescriptorSetAllocateInfo allocateInfo = {};
        allocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocateInfo.descriptorPool              = backendContext->descriptorPool;
        allocateInfo.descriptorSetCount          = 1;
        allocateInfo.pSetLayouts                 = &pPipelineLayout->descriptorSetLayout;

        if (VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &allocateInfo, &pPipelineLayout->descriptorSets[i]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

                                 
    VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
    pipelineLayoutInfo.sType                  = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount         = 1;
    pipelineLayoutInfo.pSetLayouts            = &pPipelineLayout->descriptorSetLayout;
    pipelineLayoutInfo.pushConstantRangeCount = 0;
    pipelineLayoutInfo.pPushConstantRanges    = nullptr;

    if (VulkanWrapper().vkCreatePipelineLayout(backendContext->device, &pipelineLayoutInfo, nullptr, &pPipelineLayout->pipelineLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    }                       

    pPipelineLayout->effectContextId = effectContextId;

                                         
    outPipeline->rootSignature = reinterpret_cast<FfxRootSignature>(pPipelineLayout);

    outPipeline->cmdSignature = nullptr;

    outPipeline->uavTensorCount = dataGraphBlob.outputTensorNums;
    FFX_ASSERT(outPipeline->uavTensorCount < FFX_MAX_NUM_TENSORS);
    for (uint32_t tensorIndex = 0; tensorIndex < dataGraphBlob.outputTensorNums; ++tensorIndex)
    {
        outPipeline->uavTensorBindings[tensorIndex].slotIndex  = dataGraphBlob.outputTensorBindings[tensorIndex];
        outPipeline->uavTensorBindings[tensorIndex].arrayIndex = 0;
        strncpy(outPipeline->uavTensorBindings[tensorIndex].name, dataGraphBlob.outputTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->uavTensorBindings[tensorIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }

    outPipeline->srvTensorCount = dataGraphBlob.inputTensorNums;
    FFX_ASSERT(outPipeline->srvTensorCount < FFX_MAX_NUM_TENSORS);
    for (uint32_t tensorIndex = 0; tensorIndex < dataGraphBlob.inputTensorNums; ++tensorIndex)
    {
        outPipeline->srvTensorBindings[tensorIndex].slotIndex  = dataGraphBlob.inputTensorBindings[tensorIndex];
        outPipeline->srvTensorBindings[tensorIndex].arrayIndex = 0;
        strncpy(outPipeline->srvTensorBindings[tensorIndex].name, dataGraphBlob.inputTensorNames[tensorIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->srvTensorBindings[tensorIndex].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
    }
    pPipelineLayout->nssEngineHandle = nullptr;
    pPipelineLayout->nfruEngine      = nullptr;
    if (useNfruBridge)
    {
        nss_trace("backend: NfruEngine init begin %ux%u", (unsigned) dataGraphWidth, (unsigned) dataGraphHeight);
        NfruEngine* eng = new NfruEngine();
        const bool nfruInitOk = eng->init(backendContext->device, backendContext->physicalDevice, dataGraphWidth, dataGraphHeight, backendContext->instance);
        nss_trace("backend: NfruEngine init end ok=%d", (int) nfruInitOk);
        if (nfruInitOk)
        {
            pPipelineLayout->nfruEngine = eng;
            outPipeline->pipeline       = VK_NULL_HANDLE;
            outPipeline->session        = VK_NULL_HANDLE;
            strncpy(outPipeline->name, desc->name, FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            return FFX_OK;
        }
        delete eng;
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    if (useNssEngineBridge)
    {
        NssEngineConfig engConf = {};
        engConf.instance = backendContext->instance;
        engConf.physicalDevice = backendContext->physicalDevice;
        engConf.device = backendContext->device;
                                                                                                    
                                                                                                         
                                     
        const uint32_t nssQualityMode = (permutationOptions >> 10) & 0x3u;
        engConf.quality = (nssQualityMode == 0) ? NSS_QUALITY_HIGH : NSS_QUALITY_MID_LOW;
        engConf.backend = NSS_BACKEND_AUTO;

        NssEngineHandle engHandle = nullptr;
        if (nss_engine_create(&engConf, &engHandle) == 0)
        {
            nss_engine_setup_resolution(engHandle, dataGraphWidth, dataGraphHeight);
            pPipelineLayout->nssEngineHandle = engHandle;
            outPipeline->pipeline = VK_NULL_HANDLE;
            outPipeline->session = VK_NULL_HANDLE;
            strncpy(outPipeline->name, desc->name, FFX_RESOURCE_NAME_SIZE - 1);
            outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
            return FFX_OK;
        }
                                                                                            
                                                                                              
                                                                            
        return FFX_ERROR_BACKEND_API_ERROR;
    }


    DescriptorSetBindingToShapeMap inputShapes = GetInputShapes(dataGraphBlob, dataGraphWidth, dataGraphHeight);

    ShapeInferenceResults ShapeInferenceResults =
        RunShapeInference(reinterpret_cast<const uint32_t*>(dataGraphBlob.graphData), dataGraphBlob.graphDataSize / 4, inputShapes);

    if (!ShapeInferenceResults.Success)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                    
    VkShaderModule           shaderModule           = VK_NULL_HANDLE;
    VkShaderModuleCreateInfo shaderModuleCreateInfo = {};
    shaderModuleCreateInfo.sType                    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    shaderModuleCreateInfo.pCode                    = ShapeInferenceResults.NewCode.data();
    shaderModuleCreateInfo.codeSize                 = ShapeInferenceResults.NewCode.size() * sizeof(ShapeInferenceResults.NewCode[0]);

    if (VulkanWrapper().vkCreateShaderModule(backendContext->device, &shaderModuleCreateInfo, nullptr, &shaderModule) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    std::vector<VkTensorDescriptionARM>         pipelineTensorConstantDescs;
    std::vector<VkDataGraphPipelineConstantARM> pipelineConstants;

    pipelineTensorConstantDescs.resize(dataGraphBlob.constantNums);

    for (FfxUInt32 constantIndex = 0; constantIndex < dataGraphBlob.constantNums; ++constantIndex)
    {
                                                                                                     
        VkTensorDescriptionARM tensorDescription = {VK_STRUCTURE_TYPE_TENSOR_DESCRIPTION_ARM,
                                                    nullptr,
                                                    VK_TENSOR_TILING_LINEAR_ARM,
                                                    (VkFormat)dataGraphBlob.constantFormats[constantIndex],
                                                    dataGraphBlob.constantShapeSize[constantIndex],
                                                    dataGraphBlob.constantShapes[constantIndex],
                                                    nullptr,             
                                                    VK_TENSOR_USAGE_DATA_GRAPH_BIT_ARM};

        pipelineTensorConstantDescs[constantIndex] = tensorDescription;

        VkDataGraphPipelineConstantARM pipelineConstant = {VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_CONSTANT_ARM,
                                                           &pipelineTensorConstantDescs[constantIndex],
                                                           dataGraphBlob.constantIds[constantIndex],
                                                           dataGraphBlob.constantDatas[constantIndex]};

        pipelineConstants.push_back(pipelineConstant);
    }

    VkDataGraphPipelineShaderModuleCreateInfoARM dataGraphPipelineShaderModuleCreateInfo = {VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SHADER_MODULE_CREATE_INFO_ARM,
                                                                                            nullptr,
                                                                                            shaderModule,
                                                                                            dataGraphBlob.graphEntryPoint,
                                                                                            nullptr,
                                                                                            dataGraphBlob.constantNums,
                                                                                            pipelineConstants.data()};

    std::vector<VkTensorDescriptionARM>             tensorDescs;
    std::vector<VkDataGraphPipelineResourceInfoARM> resourceInfos;

    tensorDescs.resize(dataGraphBlob.inputTensorNums + dataGraphBlob.outputTensorNums);
    const auto isTensorBufferAliased = [&](const char* tensorName) -> bool {
        if (desc->dataGraphTensorInfo == nullptr || desc->dataGraphTensorInfoCount == 0 || tensorName == nullptr)
        {
            return false;
        }

        for (FfxUInt32 tensorInfoIndex = 0; tensorInfoIndex < desc->dataGraphTensorInfoCount; ++tensorInfoIndex)
        {
            const FfxDataGraphTensorInfo& tensorInfo = desc->dataGraphTensorInfo[tensorInfoIndex];
            if (tensorInfo.resourceName != nullptr && 0 == strcmp(tensorInfo.resourceName, tensorName))
            {
                return tensorInfo.bufferAliased;
            }
        }

        return false;
    };

    constexpr uint32_t MESSAGE_BUFFER_SIZE = 256;
    char               message[MESSAGE_BUFFER_SIZE];
    for (FfxUInt32 tensorIndex = 0; tensorIndex < dataGraphBlob.inputTensorNums; ++tensorIndex)
    {
        std::pair<uint32_t, uint32_t> binding{0, dataGraphBlob.inputTensorBindings[tensorIndex]};                   
        const auto&                   tensorShape       = ShapeInferenceResults.Shapes[binding];
        const uint32_t                dimensionCount    = tensorShape.size();
        const bool                    bufferAliased     = isTensorBufferAliased(dataGraphBlob.inputTensorNames[tensorIndex]);
        VkTensorDescriptionARM        tensorDescription = {VK_STRUCTURE_TYPE_TENSOR_DESCRIPTION_ARM,
                                                    nullptr,
                                                    GetTensorTiling(bufferAliased),
                                                    (VkFormat)dataGraphBlob.inputTensorFormats[tensorIndex],
                                                    static_cast<uint32_t>(dimensionCount),
                                                    tensorShape.data(),
                                                    nullptr,             
                                                    VK_TENSOR_USAGE_DATA_GRAPH_BIT_ARM};

        tensorDescs[tensorIndex] = tensorDescription;

        VkDataGraphPipelineResourceInfoARM resourceInfo = {
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_ARM,
            &tensorDescs[tensorIndex],
            binding.first,                   
            binding.second,            
            0                                
        };

        resourceInfos.push_back(resourceInfo);

        snprintf(message,
                 MESSAGE_BUFFER_SIZE,
                 "Input tensor %u: set=%u, binding=%u, rank=%u, buffer_aliased=%u\n",
                 tensorIndex,
                 binding.first,
                 binding.second,
                 dimensionCount,
                 (uint32_t)bufferAliased);
        PrintMessage(backendInterface, FFX_MESSAGE_TYPE_WARNING, message);
        for (uint32_t i = 0; i < dimensionCount; ++i)
        {
            snprintf(message, MESSAGE_BUFFER_SIZE, "\tDimension[%u]: %u\n", i, tensorShape[i]);
            PrintMessage(backendInterface, FFX_MESSAGE_TYPE_WARNING, message);
        }
    }

                           
    for (FfxUInt32 tensorIndex = 0; tensorIndex < dataGraphBlob.outputTensorNums; ++tensorIndex)
    {
        std::pair<uint32_t, uint32_t> binding{0, dataGraphBlob.outputTensorBindings[tensorIndex]};                   
        const auto&                   tensorShape    = ShapeInferenceResults.Shapes[binding];
        const uint32_t                dimensionCount = tensorShape.size();
        const bool                    bufferAliased  = isTensorBufferAliased(dataGraphBlob.outputTensorNames[tensorIndex]);

        VkTensorDescriptionARM tensorDescription = {VK_STRUCTURE_TYPE_TENSOR_DESCRIPTION_ARM,
                                                    nullptr,
                                                    GetTensorTiling(bufferAliased),
                                                    (VkFormat)dataGraphBlob.outputTensorFormats[tensorIndex],
                                                    static_cast<uint32_t>(dimensionCount),
                                                    tensorShape.data(),
                                                    nullptr,             
                                                    VK_TENSOR_USAGE_DATA_GRAPH_BIT_ARM};

        tensorDescs[tensorIndex + dataGraphBlob.inputTensorNums] = tensorDescription;

        VkDataGraphPipelineResourceInfoARM resourceInfo = {
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_ARM,
            &tensorDescs[tensorIndex + dataGraphBlob.inputTensorNums],
            binding.first,                   
            binding.second,            
            0                                
        };

        resourceInfos.push_back(resourceInfo);

        snprintf(message,
                 MESSAGE_BUFFER_SIZE,
                 "Output tensor %u: set=%u, binding=%u, rank=%u, buffer_aliased=%u\n",
                 tensorIndex,
                 binding.first,
                 binding.second,
                 dimensionCount,
                 (uint32_t)bufferAliased);
        PrintMessage(backendInterface, FFX_MESSAGE_TYPE_WARNING, message);
        for (uint32_t i = 0; i < dimensionCount; ++i)
        {
            snprintf(message, MESSAGE_BUFFER_SIZE, "\tDimension[%u]: %lld\n", i, tensorShape[i]);
            PrintMessage(backendInterface, FFX_MESSAGE_TYPE_WARNING, message);
        }
    }

                                     
    VkDataGraphPipelineCreateInfoARM pipelineCreateInfo = {
        VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_CREATE_INFO_ARM,
        &dataGraphPipelineShaderModuleCreateInfo,
        0,                                                    
        pPipelineLayout->pipelineLayout,                       
        static_cast<uint32_t>(resourceInfos.size()),                      
        resourceInfos.data(),                                          
    };

    VkPipeline dataGraphPipeline = VK_NULL_HANDLE;
    if (VulkanWrapper().vkCreateDataGraphPipelinesARM(
            backendContext->device, VK_NULL_HANDLE, VK_NULL_HANDLE, 1, &pipelineCreateInfo, nullptr, &dataGraphPipeline) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                           
    VulkanWrapper().vkDestroyShaderModule(backendContext->device, shaderModule, nullptr);

                       
    outPipeline->pipeline = reinterpret_cast<FfxPipeline>(dataGraphPipeline);

                              
    strncpy(outPipeline->name, desc->name, FFX_RESOURCE_NAME_SIZE - 1);
    outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

    const VkDataGraphPipelineSessionCreateInfoARM sessionCreateInfo = {
        VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_CREATE_INFO_ARM, nullptr, 0, dataGraphPipeline};

    VkDataGraphPipelineSessionARM session;
    if (VulkanWrapper().vkCreateDataGraphPipelineSessionARM(backendContext->device, &sessionCreateInfo, nullptr, &session))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                                                                                    
    outPipeline->session = reinterpret_cast<FfxDataGraphPipelineSession>(session);

                                                                    
    uint32_t                                               numRequiredBindPoints = 0;
    VkDataGraphPipelineSessionBindPointRequirementsInfoARM bindPointReqsInfo     = {
        VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENTS_INFO_ARM, nullptr, session};

    if (VulkanWrapper().vkGetDataGraphPipelineSessionBindPointRequirementsARM(backendContext->device, &bindPointReqsInfo, &numRequiredBindPoints, nullptr))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                                                  
    std::vector<VkDataGraphPipelineSessionBindPointRequirementARM> bindPointRequirements(
        numRequiredBindPoints, VkDataGraphPipelineSessionBindPointRequirementARM{VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENT_ARM});
    if (VulkanWrapper().vkGetDataGraphPipelineSessionBindPointRequirementsARM(
            backendContext->device, &bindPointReqsInfo, &numRequiredBindPoints, bindPointRequirements.data()))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    FFX_ASSERT(numRequiredBindPoints >= 1);                                     

    VkMemoryRequirements2 memreqs = {VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2, nullptr, {}};
    for (uint32_t i = 0; i < numRequiredBindPoints; ++i)
    {
        if (bindPointRequirements[i].bindPoint == VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TRANSIENT_ARM)
        {
            FFX_ASSERT(bindPointRequirements[i].bindPointType == VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TYPE_MEMORY_ARM);

            VkDataGraphPipelineSessionMemoryRequirementsInfoARM info = {
                VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_MEMORY_REQUIREMENTS_INFO_ARM, nullptr, session, bindPointRequirements[i].bindPoint, 0};

            VulkanWrapper().vkGetDataGraphPipelineSessionMemoryRequirementsARM(backendContext->device, &info, &memreqs);
            break;
        }
    }

    BackendContext_VK::Resource sessionMemoryResource = {};
    sessionMemoryResource.memoryProperties            = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

    if (allocateDeviceMemory(backendContext, memreqs.memoryRequirements, sessionMemoryResource.memoryProperties, &sessionMemoryResource))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    pPipelineLayout->dataGraphSessionMemory     = sessionMemoryResource.deviceMemory;
    pPipelineLayout->dataGraphSessionMemorySize = memreqs.memoryRequirements.size;

    const VkBindDataGraphPipelineSessionMemoryInfoARM bindInfo = {
        VK_STRUCTURE_TYPE_BIND_DATA_GRAPH_PIPELINE_SESSION_MEMORY_INFO_ARM,
        nullptr,
        session,
        VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TRANSIENT_ARM,                  
        0,                                                                         
        pPipelineLayout->dataGraphSessionMemory,
        0                 
    };

    if (VulkanWrapper().vkBindDataGraphPipelineSessionMemoryARM(backendContext->device, 1, &bindInfo))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    return FFX_OK;
}

FfxErrorCode CreateOpticalFlowPipelineVK(
    FfxInterface* backendInterface, const char* name, const FfxOpticalFlowDescription& ofDesc, FfxUInt32 effectContextId, FfxPipelineState* outPipeline)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != outPipeline);

    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

                                                                              
                                                           
    FFX_ASSERT_MESSAGE(effectContext.nextPipelineLayout < (effectContextId * FFX_MAX_PASS_COUNT) + FFX_MAX_PASS_COUNT,
                       "FFXInterface: Vulkan: Ran out of pipeline layouts. Please increase FFX_MAX_PASS_COUNT");
    BackendContext_VK::PipelineLayout* pPipelineLayout = &backendContext->pPipelineLayouts[effectContext.nextPipelineLayout++];
    pPipelineLayout->ofComputePipeline   = VK_NULL_HANDLE;
    pPipelineLayout->embeddedOpticalFlow = nullptr;
                                                                                                                    
                                                                                                                     
    const bool useOfHybrid   = loadNssEngine() && getenv("NFRU_OF_HYBRID") && atoi(getenv("NFRU_OF_HYBRID")) != 0;
    const bool useEmbeddedOf = loadNssEngine() && (getenv("NFRU_OF_REAL") != nullptr || useOfHybrid);
    const bool useOfCompute  = loadNssEngine() && (!useEmbeddedOf || useOfHybrid);

                            
    VkDescriptorSetLayoutBinding layoutBindings[MAX_DESCRIPTOR_SET_LAYOUTS];
    uint32_t                     numLayoutBindings = 0;

    VkShaderStageFlags shaderStageFlags = VK_SHADER_STAGE_ALL;

    const uint32_t srvBindingCount = ofDesc.srvTextureCount;
    const uint32_t uavBindingCount = ofDesc.uavTextureCount;

    const char**                  srvNames           = ofDesc.boundSRVTextureNames;
    uint32_t*                     srvBindings        = ofDesc.boundSRVTextures;
    uint32_t*                     srvBindCounts      = ofDesc.boundSRVTextureCounts;
    uint32_t*                     srvSets            = ofDesc.boundSRVTextureSpaces;
    FfxOpticalFlowConnectionType* srvConnectionTypes = ofDesc.boundSRVTextureConnectionType;
    FfxSurfaceFormat*             srvFormats         = ofDesc.boundSRVTextureFormats;

    const char**                  uavNames           = ofDesc.boundUAVTextureNames;
    uint32_t*                     uavBindings        = ofDesc.boundUAVTextures;
    uint32_t*                     uavBindCounts      = ofDesc.boundUAVTextureCounts;
    uint32_t*                     uavSets            = ofDesc.boundUAVTextureSpaces;
    FfxOpticalFlowConnectionType* uavConnectionTypes = ofDesc.boundUAVTextureConnectionType;
    FfxSurfaceFormat*             uavFormats         = ofDesc.boundUAVTextureFormats;

                   
    for (uint32_t srvIndex = 0; srvIndex < srvBindingCount; ++srvIndex)
    {
        layoutBindings[numLayoutBindings++] = {srvBindings[srvIndex], VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, srvBindCounts[srvIndex], shaderStageFlags, nullptr};
    }

                   
    for (uint32_t uavIndex = 0; uavIndex < uavBindingCount; ++uavIndex)
    {
        layoutBindings[numLayoutBindings++] = {uavBindings[uavIndex], VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, uavBindCounts[uavIndex], shaderStageFlags, nullptr};
    }

    if (useOfCompute)
    {
        layoutBindings[numLayoutBindings++] = {4, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, 1, shaderStageFlags, nullptr};
        layoutBindings[numLayoutBindings++] = {5, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, 1, shaderStageFlags, nullptr};
        layoutBindings[numLayoutBindings++] = {6, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        layoutBindings[numLayoutBindings++] = {7, VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, 1, shaderStageFlags, nullptr};
    }

                                   
    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType                           = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount                    = numLayoutBindings;
    layoutInfo.pBindings                       = &layoutBindings[0];

    if (VulkanWrapper().vkCreateDescriptorSetLayout(backendContext->device, &layoutInfo, nullptr, &pPipelineLayout->descriptorSetLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                               
    pPipelineLayout->descriptorSetIndex = 0;
    for (uint32_t i = 0; i < (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME); i++)
    {
        VkDescriptorSetAllocateInfo allocateInfo = {};
        allocateInfo.sType                       = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocateInfo.descriptorPool              = backendContext->descriptorPool;
        allocateInfo.descriptorSetCount          = 1;
        allocateInfo.pSetLayouts                 = &pPipelineLayout->descriptorSetLayout;

                                                                                                              
                                                                                               
        if (VulkanWrapper().vkAllocateDescriptorSets(backendContext->device, &allocateInfo, &pPipelineLayout->descriptorSets[i]) != VK_SUCCESS)
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    VkDescriptorSetLayout layouts[MAX_DESCRIPTOR_SET_LAYOUTS];
    uint32_t              layoutCount = 0;
    layouts[layoutCount++]            = pPipelineLayout->descriptorSetLayout;

                                               

                                 
    VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
    pipelineLayoutInfo.sType                  = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount         = layoutCount;
    pipelineLayoutInfo.pSetLayouts            = layouts;
    const VkPushConstantRange ofPushRange = {VK_SHADER_STAGE_COMPUTE_BIT, 0, 112};
    pipelineLayoutInfo.pushConstantRangeCount = useOfCompute ? 1 : 0;
    pipelineLayoutInfo.pPushConstantRanges    = useOfCompute ? &ofPushRange : nullptr;

    if (VulkanWrapper().vkCreatePipelineLayout(backendContext->device, &pipelineLayoutInfo, nullptr, &pPipelineLayout->pipelineLayout) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                                         
    outPipeline->rootSignature = reinterpret_cast<FfxRootSignature>(pPipelineLayout);
    outPipeline->cmdSignature  = nullptr;

                                               
      
                                                                                           
    std::vector<VkDataGraphPipelineSingleNodeConnectionARM> opticalFlowConnections;
                                                                           
    std::vector<VkDataGraphPipelineResourceInfoARM> resourceInfos;
                                                                                                 
    std::vector<VkDataGraphPipelineResourceInfoImageLayoutARM> resourceImageInfos;

    const uint32_t totalTextures = srvBindingCount + uavBindingCount;
    opticalFlowConnections.reserve(totalTextures);
    resourceInfos.reserve(totalTextures);
    resourceImageInfos.reserve(totalTextures);

    uint32_t flattenedSrvTextureCount = 0;

    for (uint32_t srvIndex = 0; srvIndex < srvBindingCount; ++srvIndex)
    {
        const uint32_t binding   = srvBindings[srvIndex];
        const uint32_t bindCount = srvBindCounts[srvIndex];
        const uint32_t set       = srvSets[srvIndex];

                                                         
        FFX_ASSERT(set == 0);

                                                                                                                        
                                                                                                                
        FFX_ASSERT(bindCount == 1);

                                                                                             

        uint32_t idx                                    = flattenedSrvTextureCount++;
        outPipeline->srvTextureBindings[idx].slotIndex  = binding;
        outPipeline->srvTextureBindings[idx].arrayIndex = 0;
        outPipeline->srvTextureBindings[idx].bindSet    = set;
        strncpy(outPipeline->srvTextureBindings[idx].name, srvNames[srvIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->srvTextureBindings[idx].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

                                                               

        opticalFlowConnections.emplace_back(VkDataGraphPipelineSingleNodeConnectionARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SINGLE_NODE_CONNECTION_ARM,
            nullptr,
            set,
            binding,
            ffxGetVkOpticalFlowConnectionType(srvConnectionTypes[srvIndex]),                    
        });

                                                        

        resourceImageInfos.emplace_back(VkDataGraphPipelineResourceInfoImageLayoutARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_IMAGE_LAYOUT_ARM,
            nullptr,
            VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,        
        });

        resourceInfos.emplace_back(VkDataGraphPipelineResourceInfoARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_ARM,
            nullptr,
            set,
            binding,
            0,                                                                            
        });
    }

    outPipeline->srvTextureCount = flattenedSrvTextureCount;
    FFX_ASSERT(outPipeline->srvTextureCount < FFX_MAX_NUM_SRVS);

    uint32_t flattenedUavTextureCount = 0;

    for (uint32_t uavIndex = 0; uavIndex < uavBindingCount; ++uavIndex)
    {
        const uint32_t binding   = uavBindings[uavIndex];
        const uint32_t bindCount = uavBindCounts[uavIndex];
        const uint32_t set       = uavSets[uavIndex];
                                                         
        FFX_ASSERT(set == 0);

                                                                                                                        
                                                                                                                
        FFX_ASSERT(bindCount == 1);

                                                                                             

        uint32_t idx                                    = flattenedUavTextureCount++;
        outPipeline->uavTextureBindings[idx].slotIndex  = binding;
        outPipeline->uavTextureBindings[idx].arrayIndex = 0;
        outPipeline->uavTextureBindings[idx].bindSet    = set;
        strncpy(outPipeline->uavTextureBindings[idx].name, uavNames[uavIndex], FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->uavTextureBindings[idx].name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

                                                               

        opticalFlowConnections.emplace_back(VkDataGraphPipelineSingleNodeConnectionARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SINGLE_NODE_CONNECTION_ARM,
            nullptr,
            set,
            binding,
            ffxGetVkOpticalFlowConnectionType(uavConnectionTypes[uavIndex]),                    
        });

                                                        

        resourceImageInfos.emplace_back(VkDataGraphPipelineResourceInfoImageLayoutARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_IMAGE_LAYOUT_ARM,
            nullptr,
            VK_IMAGE_LAYOUT_GENERAL,        
        });

        resourceInfos.emplace_back(VkDataGraphPipelineResourceInfoARM{
            VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_ARM,
            nullptr,
            set,
            binding,
            0,                                                                            
        });
    }

                                                                                                                
                                      
                                                                                                              
                                                 
    for (uint32_t srvIndex = 0; srvIndex < srvBindingCount; ++srvIndex)
    {
        resourceInfos[srvIndex].pNext = &resourceImageInfos[srvIndex];
    }

    for (uint32_t uavIndex = 0; uavIndex < uavBindingCount; ++uavIndex)
    {
        resourceInfos[uavIndex + flattenedSrvTextureCount].pNext = &resourceImageInfos[uavIndex + flattenedSrvTextureCount];
    }

    outPipeline->uavTextureCount = flattenedUavTextureCount;
    FFX_ASSERT(outPipeline->uavTextureCount < FFX_MAX_NUM_UAVS);
    outPipeline->srvTensorCount = 0;
    outPipeline->uavTensorCount = 0;

    pPipelineLayout->effectContextId = effectContextId;

    if (useOfCompute)
    {
        VkShaderModuleCreateInfo smi = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        smi.codeSize                 = g_spv_nfru_of_size;
        smi.pCode                    = g_spv_nfru_of;
        VkShaderModule ofModule      = VK_NULL_HANDLE;
        if (VulkanWrapper().vkCreateShaderModule(backendContext->device, &smi, nullptr, &ofModule) != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;
        VkComputePipelineCreateInfo cpi = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpi.stage  = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, nullptr, 0, VK_SHADER_STAGE_COMPUTE_BIT, ofModule, "main", nullptr};
        cpi.layout = pPipelineLayout->pipelineLayout;
                                                                                          
        const char* adaptiveSetting=getenv("NFRU_OF_ADAPTIVE");
        const char* exitSetting=getenv("NFRU_OF_EXIT_CAMERA");
        const VkBool32 ofSpec[2]={VkBool32(adaptiveSetting && atoi(adaptiveSetting)!=0),VkBool32(exitSetting && atoi(exitSetting)!=0)};
        const VkSpecializationMapEntry adaptiveEntries[2]={{0,0,sizeof(VkBool32)},{1,sizeof(VkBool32),sizeof(VkBool32)}};
        const VkSpecializationInfo adaptiveInfo{2,adaptiveEntries,sizeof(ofSpec),ofSpec};
        cpi.stage.pSpecializationInfo=&adaptiveInfo;
        cpi.flags |= nfru_isa::createFlags(backendContext->device);
        const VkResult ofRes = VulkanWrapper().vkCreateComputePipelines(backendContext->device, VK_NULL_HANDLE, 1, &cpi, nullptr, &pPipelineLayout->ofComputePipeline);
        if (ofRes == VK_SUCCESS) nfru_isa::dump(backendContext->device, pPipelineLayout->ofComputePipeline, "nfru_optical_flow");
        VulkanWrapper().vkDestroyShaderModule(backendContext->device, ofModule, nullptr);
        if (ofRes != VK_SUCCESS)
            return FFX_ERROR_BACKEND_API_ERROR;
        outPipeline->pipeline = VK_NULL_HANDLE;
        outPipeline->session  = VK_NULL_HANDLE;
        strncpy(outPipeline->name, name, FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        if (!useOfHybrid)
            return FFX_OK;
    }

    VkDataGraphPipelineSingleNodeCreateInfoARM connectivityMap{};
    connectivityMap.sType           = VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SINGLE_NODE_CREATE_INFO_ARM;
    connectivityMap.pNext           = nullptr;
    connectivityMap.nodeType        = VK_DATA_GRAPH_PIPELINE_NODE_TYPE_OPTICAL_FLOW_ARM;
    connectivityMap.connectionCount = static_cast<uint32_t>(opticalFlowConnections.size());
    connectivityMap.pConnections    = opticalFlowConnections.data();

                                 
    VkDataGraphOpticalFlowCreateFlagsARM ofFlags = 0;
    VkFormat                             image_format{VK_FORMAT_UNDEFINED};
                                                                                       
    VkFormat cost_format{VK_FORMAT_R16_UINT};
    VkFormat flow_format{VK_FORMAT_UNDEFINED};

    for (uint32_t i = 0; i < outPipeline->srvTextureCount; i++)
    {
        switch (srvConnectionTypes[i])
        {
        case FFX_OPTICAL_FLOW_CONNECTION_INPUT:
        {
            image_format = ffxGetVkFormatFromSurfaceFormat(srvFormats[i]);
            break;
        }
        case FFX_OPTICAL_FLOW_CONNECTION_HINT:
            ofFlags |= VK_DATA_GRAPH_OPTICAL_FLOW_CREATE_ENABLE_HINT_BIT_ARM;
            break;
        default:
            break;
        }
    }

    for (uint32_t i = 0; i < outPipeline->uavTextureCount; i++)
    {
        switch (uavConnectionTypes[i])
        {
        case FFX_OPTICAL_FLOW_CONNECTION_COST:
            cost_format = ffxGetVkFormatFromSurfaceFormat(uavFormats[i]);
            ofFlags |= VK_DATA_GRAPH_OPTICAL_FLOW_CREATE_ENABLE_COST_BIT_ARM;
            break;
        case FFX_OPTICAL_FLOW_CONNECTION_FLOW_VECTOR:
            flow_format = ffxGetVkFormatFromSurfaceFormat(uavFormats[i]);
            break;
        case FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_FLOW_VECTOR:
        case FFX_OPTICAL_FLOW_CONNECTION_BACKWARD_COST:
            FFX_ASSERT_MESSAGE(false, "Backward flow/cost are no longer supported by VK_ARM_data_graph_optical_flow");
            break;
        default:
            break;
        }
    }

    VkDataGraphPipelineOpticalFlowCreateInfoARM ofCreateInfo{};
    ofCreateInfo.sType            = VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_OPTICAL_FLOW_CREATE_INFO_ARM;
    ofCreateInfo.pNext            = &connectivityMap;
    ofCreateInfo.width            = ofDesc.dimensions.width;
    ofCreateInfo.height           = ofDesc.dimensions.height;
    ofCreateInfo.imageFormat      = image_format;
    ofCreateInfo.flowVectorFormat = flow_format;
    ofCreateInfo.costFormat       = cost_format;
    ofCreateInfo.outputGridSize   = ffxGetVkOpticalFlowGridSize(ofDesc.gridSize);
    ofCreateInfo.hintGridSize     = ffxGetVkOpticalFlowGridSize(ofDesc.gridSize);
    ofCreateInfo.performanceLevel = ffxGetVkOpticalFlowPerformanceLevel(ofDesc.performanceLevel);
    ofCreateInfo.flags            = ofFlags;

    if (useEmbeddedOf)
    {
        EmbeddedOpticalFlowConfig embeddedConfig{};
        embeddedConfig.width          = ofDesc.dimensions.width;
        embeddedConfig.height         = ofDesc.dimensions.height;
        embeddedConfig.useHint        = (ofFlags & VK_DATA_GRAPH_OPTICAL_FLOW_CREATE_ENABLE_HINT_BIT_ARM) != 0;
        embeddedConfig.outputCost      = (ofFlags & VK_DATA_GRAPH_OPTICAL_FLOW_CREATE_ENABLE_COST_BIT_ARM) != 0;
        embeddedConfig.maxSearchRange = 3;
        embeddedConfig.imageFormat    = image_format;
        embeddedConfig.flowFormat     = flow_format;
        embeddedConfig.costFormat     = cost_format;

        switch (ofDesc.gridSize)
        {
        case FFX_OPTICAL_FLOW_GRID_SIZE_1X1: embeddedConfig.lastEstimationLevel = 0; break;
        case FFX_OPTICAL_FLOW_GRID_SIZE_2X2: embeddedConfig.lastEstimationLevel = 1; break;
        case FFX_OPTICAL_FLOW_GRID_SIZE_4X4: embeddedConfig.lastEstimationLevel = 2; break;
        case FFX_OPTICAL_FLOW_GRID_SIZE_8X8: embeddedConfig.lastEstimationLevel = 3; break;
        default: return FFX_ERROR_INVALID_ARGUMENT;
        }
        switch (ofDesc.performanceLevel)
        {
        case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST: embeddedConfig.performance = EmbeddedOfPerformance::Fast; break;
        case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW: embeddedConfig.performance = EmbeddedOfPerformance::Slow; break;
        case FFX_OPTICAL_FLOW_PERFORMANCE_LEVEL_UNKNOWN: embeddedConfig.performance = EmbeddedOfPerformance::Unknown; break;
        default: embeddedConfig.performance = EmbeddedOfPerformance::Medium; break;
        }

        for (size_t i = 0; i < opticalFlowConnections.size(); ++i)
        {
            const auto& connection = opticalFlowConnections[i];
            const EmbeddedOfBinding binding{connection.set, connection.binding, resourceImageInfos[i].layout};
            switch (connection.connection)
            {
            case VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_REFERENCE_ARM: embeddedConfig.reference = binding; break;
            case VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_INPUT_ARM: embeddedConfig.input = binding; break;
            case VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_HINT_ARM: embeddedConfig.hint = binding; break;
            case VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_FLOW_VECTOR_ARM: embeddedConfig.flow = binding; break;
            case VK_DATA_GRAPH_PIPELINE_NODE_CONNECTION_TYPE_OPTICAL_FLOW_COST_ARM: embeddedConfig.cost = binding; break;
            default: break;
            }
        }

        std::string embeddedError;
        auto embedded = EmbeddedOpticalFlow::create(
            backendContext->instance,
            backendContext->physicalDevice,
            backendContext->device,
            backendContext->getInstanceProcAddr,
            backendContext->getDeviceProcAddr,
            embeddedConfig,
            embeddedError);
        if (!embedded)
        {
            nss_trace("backend: embedded original VKML OF creation failed: %s", embeddedError.c_str());
            return FFX_ERROR_BACKEND_API_ERROR;
        }
        pPipelineLayout->embeddedOpticalFlow = embedded.release();
        outPipeline->pipeline = VK_NULL_HANDLE;
        outPipeline->session  = VK_NULL_HANDLE;
        strncpy(outPipeline->name, name, FFX_RESOURCE_NAME_SIZE - 1);
        outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';
        nss_trace("backend: embedded original VKML OF created (%ux%u, level=%u, hint=%u)",
                  embeddedConfig.width, embeddedConfig.height, embeddedConfig.lastEstimationLevel,
                  embeddedConfig.useHint ? 1u : 0u);
        return FFX_OK;
    }

                                     
    VkDataGraphPipelineCreateInfoARM pipelineCreateInfo = {
        VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_CREATE_INFO_ARM,
        &ofCreateInfo,
        0,                                                    
        pPipelineLayout->pipelineLayout,                       
        static_cast<uint32_t>(resourceInfos.size()),                      
        resourceInfos.data(),                                          
    };

    VkPipeline dataGraphPipeline = VK_NULL_HANDLE;
    if (VulkanWrapper().vkCreateDataGraphPipelinesARM(
            backendContext->device, VK_NULL_HANDLE, VK_NULL_HANDLE, 1, &pipelineCreateInfo, nullptr, &dataGraphPipeline) != VK_SUCCESS)
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

                       
    outPipeline->pipeline = reinterpret_cast<FfxPipeline>(dataGraphPipeline);

                              
    strncpy(outPipeline->name, name, FFX_RESOURCE_NAME_SIZE - 1);
    outPipeline->name[FFX_RESOURCE_NAME_SIZE - 1] = '\0';

    const VkDataGraphPipelineSessionCreateInfoARM sessionCreateInfo = {VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_CREATE_INFO_ARM,
                                                                       nullptr,
                                                                       VK_DATA_GRAPH_PIPELINE_SESSION_CREATE_OPTICAL_FLOW_CACHE_BIT_ARM,
                                                                       dataGraphPipeline};

    VkDataGraphPipelineSessionARM session;
    if (VulkanWrapper().vkCreateDataGraphPipelineSessionARM(backendContext->device, &sessionCreateInfo, nullptr, &session))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    outPipeline->session = reinterpret_cast<FfxDataGraphPipelineSession>(session);

    uint32_t                                               numRequiredBindPoints = 0;
    VkDataGraphPipelineSessionBindPointRequirementsInfoARM bindPointReqsInfo     = {
        VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENTS_INFO_ARM, nullptr, session};

    if (VulkanWrapper().vkGetDataGraphPipelineSessionBindPointRequirementsARM(backendContext->device, &bindPointReqsInfo, &numRequiredBindPoints, nullptr))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    std::vector<VkDataGraphPipelineSessionBindPointRequirementARM> bindPointRequirements(
        numRequiredBindPoints, VkDataGraphPipelineSessionBindPointRequirementARM{VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENT_ARM});
    if (VulkanWrapper().vkGetDataGraphPipelineSessionBindPointRequirementsARM(
            backendContext->device, &bindPointReqsInfo, &numRequiredBindPoints, bindPointRequirements.data()))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    std::vector<SessionMemoryObjectRequirement> memoryObjectRequirements{};
    memoryObjectRequirements.reserve(numRequiredBindPoints);

    VkMemoryRequirements unionMemReq{};
    unionMemReq.size           = 0;
    unionMemReq.alignment      = 1;
    unionMemReq.memoryTypeBits = 0xFFFFFFFFu;
    bool hasMemoryBindPoint    = false;

    for (uint32_t i = 0; i < numRequiredBindPoints; ++i)
    {
        const auto& req = bindPointRequirements[i];

        if (req.bindPointType != VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TYPE_MEMORY_ARM)
            continue;

        for (uint32_t objectIndex = 0; objectIndex < req.numObjects; ++objectIndex)
        {
            VkDataGraphPipelineSessionMemoryRequirementsInfoARM memReqInfo = {
                VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_MEMORY_REQUIREMENTS_INFO_ARM, nullptr, session, req.bindPoint, objectIndex};
            VkMemoryRequirements2 memreqs = {VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2, nullptr, {}};

            VulkanWrapper().vkGetDataGraphPipelineSessionMemoryRequirementsARM(backendContext->device, &memReqInfo, &memreqs);

            hasMemoryBindPoint    = true;
            unionMemReq.size      = (std::max)(unionMemReq.size, memreqs.memoryRequirements.size);
            unionMemReq.alignment = (std::max)(unionMemReq.alignment, memreqs.memoryRequirements.alignment);
            unionMemReq.memoryTypeBits &= memreqs.memoryRequirements.memoryTypeBits;
            memoryObjectRequirements.push_back(SessionMemoryObjectRequirement{req.bindPoint, objectIndex, memreqs.memoryRequirements, 0});
        }
    }

    if (!hasMemoryBindPoint)
    {
        FFX_ASSERT_MESSAGE(false, "Optical flow pipeline session has no memory bind points");
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    if (unionMemReq.memoryTypeBits == 0)
    {
        FFX_ASSERT_MESSAGE(false, "Optical flow pipeline session memory bind points have incompatible memoryTypeBits");
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    auto alignUp = [](VkDeviceSize value, VkDeviceSize alignment) -> VkDeviceSize {
        if (alignment <= 1)
        {
            return value;
        }
        const VkDeviceSize remainder = value % alignment;
        return remainder == 0 ? value : (value + (alignment - remainder));
    };

    VkDeviceSize totalSessionMemorySize = 0;
    VkDeviceSize maxSessionAlignment    = 1;
    for (auto& req : memoryObjectRequirements)
    {
        totalSessionMemorySize = alignUp(totalSessionMemorySize, req.memoryRequirements.alignment);
        req.offset             = totalSessionMemorySize;
        totalSessionMemorySize += req.memoryRequirements.size;
        maxSessionAlignment = maxSessionAlignment > req.memoryRequirements.alignment ? maxSessionAlignment : req.memoryRequirements.alignment;
    }

    unionMemReq.size      = totalSessionMemorySize;
    unionMemReq.alignment = maxSessionAlignment;

    BackendContext_VK::Resource sessionMemoryResource = {};
    sessionMemoryResource.memoryProperties            = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    if (allocateDeviceMemory(backendContext, unionMemReq, sessionMemoryResource.memoryProperties, &sessionMemoryResource))
    {
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    pPipelineLayout->dataGraphSessionMemory     = sessionMemoryResource.deviceMemory;
    pPipelineLayout->dataGraphSessionMemorySize = unionMemReq.size;

    for (const auto& req : memoryObjectRequirements)
    {
        const VkBindDataGraphPipelineSessionMemoryInfoARM bindInfo = {VK_STRUCTURE_TYPE_BIND_DATA_GRAPH_PIPELINE_SESSION_MEMORY_INFO_ARM,
                                                                      nullptr,
                                                                      session,
                                                                      req.bindPoint,
                                                                      req.objectIndex,
                                                                      pPipelineLayout->dataGraphSessionMemory,
                                                                      req.offset};
        if (VulkanWrapper().vkBindDataGraphPipelineSessionMemoryARM(backendContext->device, 1, &bindInfo))
        {
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

    return FFX_OK;
}

FfxErrorCode DestroyPipelineVK(FfxInterface* backendInterface, FfxPipelineState* pipeline, FfxUInt32 effectContextId)
{
    FFX_ASSERT(backendInterface != nullptr);
    BackendContext_VK*                backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;
    BackendContext_VK::EffectContext& effectContext  = backendContext->pEffectContexts[effectContextId];

    if (!pipeline)
        return FFX_OK;

                                                                                                                      
                                
                                                                                  
                                                                                                                     
                                                                                                                   
    if (pipeline->session != VK_NULL_HANDLE)
    {
        VkDataGraphPipelineSessionARM session = reinterpret_cast<VkDataGraphPipelineSessionARM>(pipeline->session);
        VulkanWrapper().vkDestroyDataGraphPipelineSessionARM(backendContext->device, session, nullptr);
        pipeline->session = VK_NULL_HANDLE;
    }

                           
    VkPipeline vkPipeline = reinterpret_cast<VkPipeline>(pipeline->pipeline);
    if (vkPipeline != VK_NULL_HANDLE)
    {
        VulkanWrapper().vkDestroyPipeline(backendContext->device, vkPipeline, VK_NULL_HANDLE);
        pipeline->pipeline = VK_NULL_HANDLE;
    }

                                 
    pipeline->cmdSignature = nullptr;

                                  
    BackendContext_VK::PipelineLayout* pPipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(pipeline->rootSignature);

    if (pPipelineLayout)
    {
        if (pPipelineLayout->nssEngineHandle != nullptr)
        {
            nss_engine_destroy(pPipelineLayout->nssEngineHandle);
            pPipelineLayout->nssEngineHandle = nullptr;
        }
        if (pPipelineLayout->mvResidualEngine != nullptr) {
            delete static_cast<NfruMvResidual*>(pPipelineLayout->mvResidualEngine);
            pPipelineLayout->mvResidualEngine = nullptr;
        }
        if (pPipelineLayout->selectEngine != nullptr) {
            if (nfruSelectFp32()) delete static_cast<NfruSelect*>(pPipelineLayout->selectEngine);
            else delete static_cast<NfruSelectI8*>(pPipelineLayout->selectEngine);
            pPipelineLayout->selectEngine = nullptr;
        }
        if (pPipelineLayout->mlof2Runtime != nullptr)
        {
            Mlof2Runtime* rt = static_cast<Mlof2Runtime*>(pPipelineLayout->mlof2Runtime);
                                                                                                          
            rt->destroy(mlof2_env_on("MLOF2_DESTROY_WAITIDLE"));
            delete rt;
            pPipelineLayout->mlof2Runtime = nullptr;
        }
        if (pPipelineLayout->nfruEngine != nullptr)
        {
            NfruEngine* eng = static_cast<NfruEngine*>(pPipelineLayout->nfruEngine);
            eng->destroy();
            delete eng;
            pPipelineLayout->nfruEngine = nullptr;
        }
        if(auto* stats=static_cast<NfruGpuStats*>(pPipelineLayout->ofGpuStats)){stats->poll("OF");delete stats;pPipelineLayout->ofGpuStats=nullptr;}
        if (pPipelineLayout->embeddedOpticalFlow != nullptr)
        {
            delete static_cast<EmbeddedOpticalFlow*>(pPipelineLayout->embeddedOpticalFlow);
            pPipelineLayout->embeddedOpticalFlow = nullptr;
        }
        if (pPipelineLayout->dataGraphSessionMemory != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkFreeMemory(backendContext->device, pPipelineLayout->dataGraphSessionMemory, nullptr);
            pPipelineLayout->dataGraphSessionMemory     = VK_NULL_HANDLE;
            pPipelineLayout->dataGraphSessionMemorySize = 0;
        }

                                
        if (pPipelineLayout->pipelineLayout != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyPipelineLayout(backendContext->device, pPipelineLayout->pipelineLayout, VK_NULL_HANDLE);
            pPipelineLayout->pipelineLayout = VK_NULL_HANDLE;
        }

                          
        for (uint32_t i = 0; i < FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME; i++)
        {
            VulkanWrapper().vkFreeDescriptorSets(backendContext->device, backendContext->descriptorPool, 1, &pPipelineLayout->descriptorSets[i]);
            pPipelineLayout->descriptorSets[i] = VK_NULL_HANDLE;
        }

                                
        if (pPipelineLayout->descriptorSetLayout != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyDescriptorSetLayout(backendContext->device, pPipelineLayout->descriptorSetLayout, VK_NULL_HANDLE);
            pPipelineLayout->descriptorSetLayout = VK_NULL_HANDLE;
        }

                   
        for (uint32_t currentSamplerIndex = 0; currentSamplerIndex < FFX_MAX_SAMPLERS; ++currentSamplerIndex)
        {
            if (pPipelineLayout->samplers[currentSamplerIndex] != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroySampler(backendContext->device, pPipelineLayout->samplers[currentSamplerIndex], VK_NULL_HANDLE);
                pPipelineLayout->samplers[currentSamplerIndex] = VK_NULL_HANDLE;
            }
        }

        for (FfxUInt32 i = 0; i < MAX_IMAGE_VIEW_COUNT; i++)
        {
            if (pPipelineLayout->imageView[i].handle != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyImageView(backendContext->device, pPipelineLayout->imageView[i].handle, VK_NULL_HANDLE);
            }
        }

        for (FfxUInt32 i = 0; i < MAX_FRAME_BUFFER_COUNT; i++)
        {
            if (pPipelineLayout->frameBuffer[i].handle != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyFramebuffer(backendContext->device, pPipelineLayout->frameBuffer[i].handle, VK_NULL_HANDLE);
            }
        }

        for (FfxUInt32 i = 0; i < MAX_RENDER_PASS_COUNT; i++)
        {
            if (pPipelineLayout->renderPass[i].handle != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyRenderPass(backendContext->device, pPipelineLayout->renderPass[i].handle, VK_NULL_HANDLE);
            }
        }

        for (FfxUInt32 i = 0; i < MAX_GRAPHICS_PIPELINE_COUNT; i++)
        {
            if (pPipelineLayout->graphicsPipeline[i].handle != VK_NULL_HANDLE)
            {
                VulkanWrapper().vkDestroyPipeline(backendContext->device, pPipelineLayout->graphicsPipeline[i].handle, VK_NULL_HANDLE);
            }
        }

        if (pPipelineLayout->fragShaderModule != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyShaderModule(backendContext->device, pPipelineLayout->fragShaderModule, nullptr);
        }

        if (pPipelineLayout->vertShaderModule != VK_NULL_HANDLE)
        {
            VulkanWrapper().vkDestroyShaderModule(backendContext->device, pPipelineLayout->vertShaderModule, nullptr);
        }
    }

    return FFX_OK;
}

FfxErrorCode ScheduleGpuJobVK(FfxInterface* backendInterface, const FfxGpuJobDescription* job)
{
    FFX_ASSERT(NULL != backendInterface);
    FFX_ASSERT(NULL != job);

    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    FFX_ASSERT(backendContext->gpuJobCount < FFX_MAX_GPU_JOBS);

    backendContext->pGpuJobs[backendContext->gpuJobCount] = *job;
    backendContext->gpuJobCount++;

    return FFX_OK;
}

                                                                                                                   
                                                                                                        
static bool validateDescriptorWrites(const VkWriteDescriptorSet* writes, uint32_t count)
{
    bool ok = true;
    for (uint32_t i = 0; i < count; ++i)
    {
        const VkWriteDescriptorSet& w = writes[i];
        void* handle = nullptr;
        switch (w.descriptorType)
        {
        case VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE:
        case VK_DESCRIPTOR_TYPE_STORAGE_IMAGE:
        case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
            handle = w.pImageInfo ? (void*) w.pImageInfo[0].imageView : nullptr;
            break;
        case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:
        case VK_DESCRIPTOR_TYPE_STORAGE_BUFFER:
            handle = w.pBufferInfo ? (void*) w.pBufferInfo[0].buffer : nullptr;
            break;
        default:
            handle = (void*) 1;                               
            break;
        }
        nss_trace("    write[%u] binding=%u type=%d handle=%p set=%p", i, w.dstBinding, (int) w.descriptorType, handle, (void*) w.dstSet);
        if (handle == nullptr || w.dstSet == VK_NULL_HANDLE)
            ok = false;
    }
    return ok;
}

                                                                                                                             
                                                                                                   
static bool updateDescriptorSetsGuarded(VkDevice device, const VkWriteDescriptorSet* writes, uint32_t count)
{
#ifdef _WIN32
    bool faulted = false;
    __try
    {
        VulkanWrapper().vkUpdateDescriptorSets(device, count, writes, 0, nullptr);
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        faulted = true;
    }
    if (!faulted)
        return true;
    nss_trace("  vkUpdateDescriptorSets faulted in the driver: retrying write by write");
    bool allOk = true;
    for (uint32_t i = 0; i < count; ++i)
    {
        bool f = false;
        __try
        {
            VulkanWrapper().vkUpdateDescriptorSets(device, 1, &writes[i], 0, nullptr);
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            f = true;
        }
        if (f)
        {
            nss_trace("    write[%u] binding=%u type=%d FAULTED in the driver", i, writes[i].dstBinding, (int) writes[i].descriptorType);
            allOk = false;
        }
    }
    return allOk;
#else
    VulkanWrapper().vkUpdateDescriptorSets(device, count, writes, 0, nullptr);
    return true;
#endif
}


static FfxErrorCode executeMlof2(BackendContext_VK* backendContext,
                                 FfxGpuJobDescription* job,
                                 VkCommandBuffer vkCommandBuffer,
                                 BackendContext_VK::PipelineLayout* pipelineLayout)
{
    nss_trace("executeMlof2: start");
    Mlof2Runtime* rt = static_cast<Mlof2Runtime*>(pipelineLayout->mlof2Runtime);
    if (!rt) {
        nss_trace("executeMlof2: rt is null!");
        return FFX_ERROR_INVALID_ARGUMENT;
    }

    uint32_t dispW = job->computeJobDescriptor.dimensions[0];
    uint32_t dispH = job->computeJobDescriptor.dimensions[1];
    if (dispW == 0 || dispH == 0) {
        if (job->computeJobDescriptor.pipeline.constCount >= 1 &&
            job->computeJobDescriptor.cbs[0].num32BitEntries * 4 >= sizeof(FrameInterpolationConstants)) {
            const auto* fi = reinterpret_cast<const FrameInterpolationConstants*>(job->computeJobDescriptor.cbs[0].data);
            dispW = fi->_DisplaySize[0];
            dispH = fi->_DisplaySize[1];
        }
    }
    if (dispW > 0 && dispH > 0 && (!rt->started || rt->dispW != dispW || rt->dispH != dispH)) {
        nss_trace("executeMlof2: (re)initializing Mlof2Runtime for %ux%u (previous %ux%u, ready=%d)",
                  dispW, dispH, rt->dispW, rt->dispH, (int)rt->ready.load());
        rt->destroy();
        if (!rt->init(backendContext->device, backendContext->physicalDevice, dispW, dispH, backendContext->instance)) {
            nss_trace("executeMlof2: rt->init failed for %ux%u!", dispW, dispH);
            return FFX_ERROR_BACKEND_API_ERROR;
        }
    }

                                                                                                         
    auto blitImage = [&](const FfxResourceInternal& srcRes, const FfxResourceInternal& dstRes) -> bool {
        if (srcRes.internalIndex <= 0 || dstRes.internalIndex <= 0) return false;
        const auto& src = backendContext->pResources[srcRes.internalIndex];
        const auto& dst = backendContext->pResources[dstRes.internalIndex];
        VkFormatProperties sp{}, dp{};
        vkGetPhysicalDeviceFormatProperties(backendContext->physicalDevice, ffxGetVkFormatFromSurfaceFormat(src.resourceDescription.format), &sp);
        vkGetPhysicalDeviceFormatProperties(backendContext->physicalDevice, ffxGetVkFormatFromSurfaceFormat(dst.resourceDescription.format), &dp);
        if (!(sp.optimalTilingFeatures & VK_FORMAT_FEATURE_BLIT_SRC_BIT) || !(dp.optimalTilingFeatures & VK_FORMAT_FEATURE_BLIT_DST_BIT))
            return false;
        addBarrier(backendContext, const_cast<FfxResourceInternal*>(&srcRes), FFX_RESOURCE_STATE_COPY_SRC);
        addBarrier(backendContext, const_cast<FfxResourceInternal*>(&dstRes), FFX_RESOURCE_STATE_COPY_DEST);
        flushBarriers(backendContext, vkCommandBuffer);
        VkImageBlit blit{};
        blit.srcSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
        blit.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
        blit.srcOffsets[1] = {int32_t(src.resourceDescription.width), int32_t(src.resourceDescription.height), 1};
        blit.dstOffsets[1] = {int32_t(dst.resourceDescription.width), int32_t(dst.resourceDescription.height), 1};
        vkCmdBlitImage(vkCommandBuffer, src.imageResource, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst.imageResource,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit, VK_FILTER_LINEAR);
        return true;
    };
                                                                                                            
                                       
    const FfxResourceInternal historyRes = job->computeJobDescriptor.uavTextures[1].resource;

                                                                                                        
    if (!rt->ready) {
        static bool s_logged = false;
        if (!s_logged || rt->compileFailed) {
            nss_trace("executeMlof2: pipelines %s - repeating the previous frame", rt->compileFailed ? "failed" : "compiling");
            s_logged = true;
        }
        blitImage(job->computeJobDescriptor.srvTextures[1].resource.internalIndex > 0 ? job->computeJobDescriptor.srvTextures[1].resource
                                                                                    : job->computeJobDescriptor.srvTextures[0].resource,
                  job->computeJobDescriptor.uavTextures[0].resource);
        if (historyRes.internalIndex > 0)
            blitImage(job->computeJobDescriptor.srvTextures[0].resource, historyRes);
        return FFX_OK;
    }

    Mlof2JobDesc desc{};

    for (int i = 0; i < 6; ++i) {
        if (job->computeJobDescriptor.srvTextures[i].resource.internalIndex > 0)
            addBarrier(backendContext, &job->computeJobDescriptor.srvTextures[i].resource, FFX_RESOURCE_STATE_COMPUTE_READ);
    }
    if (job->computeJobDescriptor.uavTextures[0].resource.internalIndex > 0) {
        addBarrier(backendContext, &job->computeJobDescriptor.uavTextures[0].resource, FFX_RESOURCE_STATE_COMPUTE_UAV);
    }
    flushBarriers(backendContext, vkCommandBuffer);

    auto getSrvView = [&](const FfxResourceInternal& res, const char* tag) -> VkImageView {
        if (res.internalIndex <= 0) return VK_NULL_HANDLE;
        int32_t vi = backendContext->pResources[res.internalIndex].srvViewIndex;
        if (vi < 0) return VK_NULL_HANDLE;
        return backendContext->pResourceViews[vi].imageView;
    };
    auto getUavView = [&](const FfxResourceInternal& res, const char* tag) -> VkImageView {
        if (res.internalIndex <= 0) return VK_NULL_HANDLE;
        int32_t vi = backendContext->pResources[res.internalIndex].uavViewIndex;
        if (vi < 0) return VK_NULL_HANDLE;
        return backendContext->pResourceViews[vi].imageView;
    };
    auto getImage = [&](const FfxResourceInternal& res, const char* tag) -> VkImage {
        if (res.internalIndex <= 0) return VK_NULL_HANDLE;
        return backendContext->pResources[res.internalIndex].imageResource;
    };

    desc.colCurrView = getSrvView(job->computeJobDescriptor.srvTextures[0].resource, "colCurr");
    desc.colPrevView = getSrvView(job->computeJobDescriptor.srvTextures[1].resource, "colPrev");
    desc.depCurrView = getSrvView(job->computeJobDescriptor.srvTextures[2].resource, "depCurr");
    desc.depPrevView = getSrvView(job->computeJobDescriptor.srvTextures[3].resource, "depPrev");
    desc.mvView      = getSrvView(job->computeJobDescriptor.srvTextures[4].resource, "mv");
    desc.fullColView = getSrvView(job->computeJobDescriptor.srvTextures[5].resource, "fullColor");
                                                                                                              
    if (job->computeJobDescriptor.srvTextures[2].resource.internalIndex > 0) {
        const auto& rd = backendContext->pResources[job->computeJobDescriptor.srvTextures[2].resource.internalIndex].resourceDescription;
        desc.depW = rd.width; desc.depH = rd.height;
    }
    if (job->computeJobDescriptor.srvTextures[4].resource.internalIndex > 0) {
        const auto& rd = backendContext->pResources[job->computeJobDescriptor.srvTextures[4].resource.internalIndex].resourceDescription;
        desc.mvW = rd.width; desc.mvH = rd.height;
    }

    desc.outView     = getUavView(job->computeJobDescriptor.uavTextures[0].resource, "out");
    desc.outImage    = getImage(job->computeJobDescriptor.uavTextures[0].resource, "out");

                                          
    if (!desc.colCurrView || !desc.depCurrView || !desc.outView || !desc.outImage) {
        static bool s_loggedMissing = false;
        if (!s_loggedMissing) {
            nss_trace("executeMlof2: missing required views (colCurr=%p depCurr=%p outView=%p outImg=%p) - skipping record",
                      (void*)desc.colCurrView, (void*)desc.depCurrView, (void*)desc.outView, (void*)desc.outImage);
            s_loggedMissing = true;
        }
        return FFX_OK;
    }

    if (job->computeJobDescriptor.cbs[0].data &&
        job->computeJobDescriptor.cbs[0].num32BitEntries * 4 >= sizeof(FrameInterpolationConstants))
    {
        const auto* fi = reinterpret_cast<const FrameInterpolationConstants*>(job->computeJobDescriptor.cbs[0].data);
        desc.reset = (fi->_Reset != 0);
        desc.t = fi->_Timestep;
        desc.mvScale[0] = fi->_MotionVectorScale[0];
        desc.mvScale[1] = fi->_MotionVectorScale[1];
        desc.jitter[0] = fi->_Jitter[0];
        desc.jitter[1] = fi->_Jitter[1];
        desc.isReverseZ = (fi->_DeviceToViewDepth[3] != 0.0f);
        desc.hudMode = fi->_pad0 & 0xffu;                                               
        nss_trace("executeMlof2: read fi constants: reset=%d t=%.3f mvScale=(%.6f, %.6f) jitter=(%.4f, %.4f) revZ=%d",
                  (int)desc.reset, desc.t, desc.mvScale[0], desc.mvScale[1], desc.jitter[0], desc.jitter[1], (int)desc.isReverseZ);
    }
    else
    {
        nss_trace("executeMlof2: cbs[0] constants NOT read! data=%p num32=%u",
                  job->computeJobDescriptor.cbs[0].data, job->computeJobDescriptor.cbs[0].num32BitEntries);
        desc.t = 0.5f;
    }

                                                  
    if (job->computeJobDescriptor.cbs[1].data &&
        job->computeJobDescriptor.cbs[1].num32BitEntries * 4 >= sizeof(FfxMlof2Constants))
    {
        const auto* mc = reinterpret_cast<const FfxMlof2Constants*>(job->computeJobDescriptor.cbs[1].data);
        desc.frameID = mc->frameID;
        desc.mfg = mc->mfg;
        desc.hasCam = (mc->hasCam != 0);
        desc.hasCamP = (mc->hasCamP != 0);
        desc.isReverseZ = (mc->depthInverted != 0);                                                                  
        memcpy(desc.vp_p, mc->vp_p, sizeof(desc.vp_p));
        memcpy(desc.vp_a, mc->vp_a, sizeof(desc.vp_a));
        memcpy(desc.vp_b, mc->vp_b, sizeof(desc.vp_b));
        memcpy(desc.inv_vp_a, mc->inv_vp_a, sizeof(desc.inv_vp_a));
    }
    else
    {
        static uint64_t s_fallbackFrameID = 1;
        desc.frameID = s_fallbackFrameID++;
        desc.mfg = 2;
    }

    if (getenv("MLOF2_MFG")) desc.mfg = atoi(getenv("MLOF2_MFG"));
    desc.k = (desc.mfg == 4) ? uint32_t(roundf(desc.t * 4.0f)) : 1u;
    if (desc.k < 1) desc.k = 1;
    if (desc.k > 3) desc.k = 3;

    nss_trace("executeMlof2: views: colCurr=%p colPrev=%p depCurr=%p depPrev=%p mv=%p outView=%p outImg=%p",
              (void*)desc.colCurrView, (void*)desc.colPrevView, (void*)desc.depCurrView, (void*)desc.depPrevView,
              (void*)desc.mvView, (void*)desc.outView, (void*)desc.outImage);
    if (rt->ofgPath) {
        nss_trace("OFG (half=%d, lk=%d, margin=%.3f, no_l4=%d)",
                  rt->ofgHalf ? 1 : 0, rt->ofgLkIters, rt->ofgRuleMargin, rt->ofgNoL4 ? 1 : 0);
    }
    rt->recordMlof2Job(vkCommandBuffer, desc);
    if (historyRes.internalIndex > 0)
        blitImage(job->computeJobDescriptor.srvTextures[0].resource, historyRes);
    nss_trace("executeMlof2: done rt->recordMlof2Job");
    return FFX_OK;
}

static FfxErrorCode executeGpuJobCompute(BackendContext_VK*    backendContext,
                                         FfxGpuJobDescription* job,
                                         VkCommandBuffer       vkCommandBuffer,
                                         FfxUInt32             effectContextId)
{
    BackendContext_VK::PipelineLayout* pipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->computeJobDescriptor.pipeline.rootSignature);
    if (pipelineLayout && pipelineLayout->mlof2Runtime != nullptr)
    {
        return executeMlof2(backendContext, job, vkCommandBuffer, pipelineLayout);
    }

                                                                                                                                
    uint32_t             descriptorWriteIndex = 0;
    VkWriteDescriptorSet writeDescriptorSets[FFX_MAX_RESOURCE_COUNT];

                                
    uint32_t              imageDescriptorIndex = 0;
    VkDescriptorImageInfo imageDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        imageDescriptorInfos[i] = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};

                                
    uint32_t               bufferDescriptorIndex = 0;
    VkDescriptorBufferInfo bufferDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        bufferDescriptorInfos[i] = {VK_NULL_HANDLE, 0, VK_WHOLE_SIZE};

                        
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->computeJobDescriptor.pipeline.uavTextureCount; ++currentPipelineUavIndex)
    {
        FfxTextureUAV& textureUAV = job->computeJobDescriptor.uavTextures[currentPipelineUavIndex];

                                               
        if (job->computeJobDescriptor.uavTextures[currentPipelineUavIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureUAV.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.uavTextureBindings[currentPipelineUavIndex];

                           
        const uint32_t currentUavResourceIndex = job->computeJobDescriptor.pipeline.uavTextureBindings[currentPipelineUavIndex].slotIndex;

                                          
        const uint32_t resourceIndex = textureUAV.resource.internalIndex;
        uint32_t       mipOffset     = textureUAV.mip;
        if (textureUAV.mip >= backendContext->pResources[resourceIndex].resourceDescription.mipCount)
            mipOffset = backendContext->pResources[resourceIndex].resourceDescription.mipCount - 1;
        const uint32_t uavViewIndex = backendContext->pResources[resourceIndex].uavViewIndex + mipOffset;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[uavViewIndex].imageView;
        {
            const auto& rd = backendContext->pResources[resourceIndex].resourceDescription;
            nss_trace("    uav tex binding=%u res=%u view=%u fmt=%d %ux%u usage=0x%x flags=0x%x image=%p", binding.slotIndex, resourceIndex, uavViewIndex, (int) rd.format,
                      (unsigned) rd.width, (unsigned) rd.height, (unsigned) rd.usage, (unsigned) rd.flags, (void*) backendContext->pResources[resourceIndex].imageResource);
        }

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->computeJobDescriptor.pipeline.uavBufferCount; ++currentPipelineUavIndex)
    {
        FfxBufferUAV& bufferUAV = job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex];

                                               
        if (job->computeJobDescriptor.uavBuffers[currentPipelineUavIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &bufferUAV.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.uavBufferBindings[currentPipelineUavIndex];

                                        
        const uint32_t resourceIndex = bufferUAV.resource.internalIndex;

                           
        const uint32_t currentUavResourceIndex = job->computeJobDescriptor.pipeline.uavBufferBindings[currentPipelineUavIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        bufferDescriptorInfos[bufferDescriptorIndex] = {};

        const auto& backendResource = backendContext->pResources[resourceIndex];
        const bool  isTensor        = (backendResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR);
        const bool  isBufferAliased = ((backendResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED);
        if (isBufferAliased || backendResource.bridgeTensor)
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer =
                isTensor ? backendResource.aliasedTensorBufferResource : backendResource.aliasedBufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range = VK_WHOLE_SIZE;
        }
        else
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer = backendResource.bufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range  = bufferUAV.size > 0 ? bufferUAV.size : backendResource.resourceDescription.size;
        }
        bufferDescriptorInfos[bufferDescriptorIndex].offset = bufferUAV.offset;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

                        
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->computeJobDescriptor.pipeline.srvTextureCount; ++currentPipelineSrvIndex)
    {
        FfxTextureSRV& textureSRV = job->computeJobDescriptor.srvTextures[currentPipelineSrvIndex];

                                               
        if (job->computeJobDescriptor.srvTextures[currentPipelineSrvIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureSRV.resource, FFX_RESOURCE_STATE_COMPUTE_READ);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.srvTextureBindings[currentPipelineSrvIndex];

                           
        const uint32_t currentSrvResourceIndex = job->computeJobDescriptor.pipeline.srvTextureBindings[currentPipelineSrvIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        const uint32_t resourceIndex = textureSRV.resource.internalIndex;
        const uint32_t srvViewIndex  = backendContext->pResources[resourceIndex].srvViewIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[srvViewIndex].imageView;
        {
            const auto& rd = backendContext->pResources[resourceIndex].resourceDescription;
            nss_trace("    srv tex binding=%u res=%u view=%u fmt=%d %ux%u usage=0x%x flags=0x%x dynamic=%d image=%p", binding.slotIndex, resourceIndex, srvViewIndex, (int) rd.format,
                      (unsigned) rd.width, (unsigned) rd.height, (unsigned) rd.usage, (unsigned) rd.flags, (int) backendContext->pResources[resourceIndex].dynamic,
                      (void*) backendContext->pResources[resourceIndex].imageResource);
        }

        if (!strcmp(binding.name,"r_motion_tp1"))
            backendContext->pEffectContexts[effectContextId].mvResidualMotion = imageDescriptorInfos[imageDescriptorIndex];

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->computeJobDescriptor.pipeline.srvBufferCount; ++currentPipelineSrvIndex)
    {
        FfxBufferSRV& bufferSRV = job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex];

                                               
        if (job->computeJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &bufferSRV.resource, FFX_RESOURCE_STATE_COMPUTE_READ);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.srvBufferBindings[currentPipelineSrvIndex];

                                        
        const uint32_t resourceIndex = bufferSRV.resource.internalIndex;

                           
        const uint32_t currentSrvResourceIndex = job->computeJobDescriptor.pipeline.srvBufferBindings[currentPipelineSrvIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        bufferDescriptorInfos[bufferDescriptorIndex] = {};

        const auto& backendResource = backendContext->pResources[resourceIndex];
        const bool  isTensor        = (backendResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR);
        const bool  isBufferAliased = ((backendResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED);

        if (isBufferAliased || backendResource.bridgeTensor)
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer =
                isTensor ? backendResource.aliasedTensorBufferResource : backendResource.aliasedBufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range = VK_WHOLE_SIZE;
        }
        else
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer = backendResource.bufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range  = bufferSRV.size > 0 ? bufferSRV.size : backendResource.resourceDescription.size;
        }
        bufferDescriptorInfos[bufferDescriptorIndex].offset = bufferSRV.offset;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

    uint32_t                      tensorDescriptorIndex = 0;
    VkWriteDescriptorSetTensorARM tensorDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        tensorDescriptorInfos[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_TENSOR_ARM, nullptr};

                       
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->computeJobDescriptor.pipeline.uavTensorCount; ++currentPipelineUavIndex)
    {
        FfxTensor& tensor = job->computeJobDescriptor.uavTensors[currentPipelineUavIndex];

                                               
        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.uavTensorBindings[currentPipelineUavIndex];

        const uint32_t resourceIndex   = job->computeJobDescriptor.uavTensors[currentPipelineUavIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->computeJobDescriptor.pipeline.srvTensorCount; ++currentPipelineSrvIndex)
    {
        FfxTensor& tensor = job->computeJobDescriptor.srvTensors[currentPipelineSrvIndex];

                                               
        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_COMPUTE_READ);

        const FfxResourceBinding binding = job->computeJobDescriptor.pipeline.srvTensorBindings[currentPipelineSrvIndex];

        const uint32_t resourceIndex   = job->computeJobDescriptor.srvTensors[currentPipelineSrvIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                             
    for (uint32_t currentRootConstantIndex = 0; currentRootConstantIndex < job->computeJobDescriptor.pipeline.constCount; ++currentRootConstantIndex)
    {
        uint32_t dataSize = job->computeJobDescriptor.cbs[currentRootConstantIndex].num32BitEntries * sizeof(uint32_t);

                                                                                                        
        FfxConstantAllocation allocation;
        if (s_fpConstantAllocator)
            allocation = s_fpConstantAllocator(job->computeJobDescriptor.cbs[currentRootConstantIndex].data, dataSize);
        else
            allocation = backendContext->FallbackConstantAllocator(job->computeJobDescriptor.cbs[currentRootConstantIndex].data, dataSize);

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding = job->computeJobDescriptor.pipeline.constantBufferBindings[currentRootConstantIndex].slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = 0;

        bufferDescriptorInfos[bufferDescriptorIndex].buffer = static_cast<VkBuffer>(allocation.resource.resource);
        bufferDescriptorInfos[bufferDescriptorIndex].offset = static_cast<VkDeviceSize>(allocation.handle);
        bufferDescriptorInfos[bufferDescriptorIndex].range  = dataSize;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

                                                                                              
    if (job->computeJobDescriptor.pipeline.cmdSignature)
    {
        addBarrier(backendContext, &job->computeJobDescriptor.cmdArgument, FFX_RESOURCE_STATE_INDIRECT_ARGUMENT);
    }

                              
    flushBarriers(backendContext, vkCommandBuffer);

                               
    nss_trace("  compute update descriptors n=%u", (unsigned) descriptorWriteIndex);
    if (!validateDescriptorWrites(writeDescriptorSets, descriptorWriteIndex))
    {
        nss_trace("  compute job aborted: a descriptor write has a NULL handle");
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    if (!updateDescriptorSetsGuarded(backendContext->device, writeDescriptorSets, descriptorWriteIndex))
    {
        nss_trace("  compute job aborted: descriptor update faulted in the driver");
        return FFX_ERROR_BACKEND_API_ERROR;
    }

    auto& statsContext=backendContext->pEffectContexts[effectContextId];
    auto* fiStats=static_cast<NfruGpuStats*>(statsContext.fiGpuStats);
    const bool statsWarp=!strcmp(job->computeJobDescriptor.pipeline.name,"ARM_NFRU_WARP_MOTION_TP1");
    const bool statsPost=!strcmp(job->computeJobDescriptor.pipeline.name,"ARM_NFRU_POSTPROCESS");
    const FrameInterpolationConstants* statsConstants=nullptr;
    VkBuffer statsBuffer=VK_NULL_HANDLE;
    if((statsWarp||statsPost)&&job->computeJobDescriptor.pipeline.constCount==1&&job->computeJobDescriptor.cbs[0].num32BitEntries*4>=sizeof(FrameInterpolationConstants)){
        statsConstants=reinterpret_cast<const FrameInterpolationConstants*>(job->computeJobDescriptor.cbs[0].data);
        for(uint32_t i=0;i<job->computeJobDescriptor.pipeline.uavBufferCount;i++)
            if(!strcmp(job->computeJobDescriptor.pipeline.uavBufferBindings[i].name,"NfruDiag"))
                statsBuffer=backendContext->pResources[job->computeJobDescriptor.uavBuffers[i].resource.internalIndex].bufferResource;
        if(statsWarp&&statsBuffer&&(statsConstants->_pad0&0x200u)){
            if(!fiStats){fiStats=new NfruGpuStats();if(!fiStats->init(backendContext->device,backendContext->physicalDevice)){delete fiStats;fiStats=nullptr;}statsContext.fiGpuStats=fiStats;}
            if(fiStats)fiStats->clear(vkCommandBuffer,statsBuffer);
        }
        if(statsPost&&fiStats)fiStats->poll("FI");
    }

                                                                                              
    if (!strcmp(job->computeJobDescriptor.pipeline.name, "ARM_NFRU_PREPROCESS") && job->computeJobDescriptor.pipeline.constCount == 1 &&
        job->computeJobDescriptor.cbs[0].num32BitEntries * 4 >= sizeof(FrameInterpolationConstants)) {
        const auto* fi = reinterpret_cast<const FrameInterpolationConstants*>(job->computeJobDescriptor.cbs[0].data);
        const bool enabled = (fi->_pad0 & 0x100u) != 0 && (getenv("NFRU_MV_RESIDUAL") && getenv("NFRU_MV_RESIDUAL")[0] == '1');
        if (enabled && backendContext->pEffectContexts[effectContextId].mvResidualMotion.imageView != VK_NULL_HANDLE) {
            auto* correction = static_cast<NfruMvResidual*>(pipelineLayout->mvResidualEngine);
            if (!correction) {
                correction = new NfruMvResidual();
                if (!correction->init(backendContext->device, backendContext->physicalDevice, backendContext->instance,
                    (fi->_DisplaySize[0]+1)/2, (fi->_DisplaySize[1]+1)/2, pipelineLayout->mvResidualInverted,
                    FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME, pipelineLayout->samplers)) {
                    delete correction;return FFX_ERROR_BACKEND_API_ERROR;
                }
                pipelineLayout->mvResidualEngine = correction;
            }
            if (correction->w != uint32_t((fi->_DisplaySize[0]+1)/2) || correction->h != uint32_t((fi->_DisplaySize[1]+1)/2) ||
                !correction->record(vkCommandBuffer,pipelineLayout->descriptorSetIndex,writeDescriptorSets,descriptorWriteIndex,
                    fi->_InputTensorSize[0],fi->_InputTensorSize[1],backendContext->pEffectContexts[effectContextId].mvResidualMotion)) return FFX_ERROR_BACKEND_API_ERROR;
            pipelineLayout->descriptorSetIndex = (pipelineLayout->descriptorSetIndex+1) % (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME);
            return FFX_OK;
        }
    }

                    
    nss_trace("  compute bind pipeline=%p layout=%p dims=%ux%ux%u", (void*) job->computeJobDescriptor.pipeline.pipeline, (void*) pipelineLayout->pipelineLayout,
              job->computeJobDescriptor.dimensions[0], job->computeJobDescriptor.dimensions[1], job->computeJobDescriptor.dimensions[2]);
    VulkanWrapper().vkCmdBindPipeline(
        vkCommandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, reinterpret_cast<VkPipeline>(job->computeJobDescriptor.pipeline.pipeline));

                           
    {
        VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                                VK_PIPELINE_BIND_POINT_COMPUTE,
                                                pipelineLayout->pipelineLayout,
                                                0,
                                                1,
                                                &pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex],
                                                0,
                                                nullptr);

        BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[effectContextId];

        if (job->computeJobDescriptor.pipeline.staticTextureSrvCount > 0)
            VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                                    VK_PIPELINE_BIND_POINT_COMPUTE,
                                                    pipelineLayout->pipelineLayout,
                                                    pipelineLayout->staticTextureSrvSet,
                                                    1,
                                                    &effectContext.bindlessTextureSrvDescriptorSet,
                                                    0,
                                                    nullptr);

        if (job->computeJobDescriptor.pipeline.staticBufferSrvCount > 0)
            VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                                    VK_PIPELINE_BIND_POINT_COMPUTE,
                                                    pipelineLayout->pipelineLayout,
                                                    pipelineLayout->staticBufferSrvSet,
                                                    1,
                                                    &effectContext.bindlessBufferSrvDescriptorSet,
                                                    0,
                                                    nullptr);

        if (job->computeJobDescriptor.pipeline.staticTextureUavCount > 0)
            VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                                    VK_PIPELINE_BIND_POINT_COMPUTE,
                                                    pipelineLayout->pipelineLayout,
                                                    pipelineLayout->staticTextureUavSet,
                                                    1,
                                                    &effectContext.bindlessTextureUavDescriptorSet,
                                                    0,
                                                    nullptr);

        if (job->computeJobDescriptor.pipeline.staticBufferUavCount > 0)
            VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                                    VK_PIPELINE_BIND_POINT_COMPUTE,
                                                    pipelineLayout->pipelineLayout,
                                                    pipelineLayout->staticBufferUavSet,
                                                    1,
                                                    &effectContext.bindlessBufferUavDescriptorSet,
                                                    0,
                                                    nullptr);
    }

                                      
    if (job->computeJobDescriptor.pipeline.cmdSignature)
    {
        const uint32_t resourceIndex = job->computeJobDescriptor.cmdArgument.internalIndex;
        VkBuffer       buffer        = backendContext->pResources[resourceIndex].bufferResource;
        VulkanWrapper().vkCmdDispatchIndirect(vkCommandBuffer, buffer, job->computeJobDescriptor.cmdArgumentOffset);
    }
    else
    {
        nss_trace("  compute dispatch");
        VulkanWrapper().vkCmdDispatch(
            vkCommandBuffer, job->computeJobDescriptor.dimensions[0], job->computeJobDescriptor.dimensions[1], job->computeJobDescriptor.dimensions[2]);
    }

                                                                                                                 
    if(statsPost&&statsConstants&&(statsConstants->_NfruT2Flags&256u)&&!statsConstants->_Reset){
        VkBuffer cand=VK_NULL_HANDLE;VkDeviceSize candBytes=0;
        for(uint32_t i=0;i<job->computeJobDescriptor.pipeline.uavBufferCount;i++)
            if(!strcmp(job->computeJobDescriptor.pipeline.uavBufferBindings[i].name,"NfruSelectCand")){
                const auto& r=backendContext->pResources[job->computeJobDescriptor.uavBuffers[i].resource.internalIndex];
                cand=r.bufferResource;candBytes=VkDeviceSize(r.resourceDescription.size);
            }
        const VkDescriptorImageInfo* output=nullptr;
        for(uint32_t i=0;i<job->computeJobDescriptor.pipeline.uavTextureCount;i++)
            if(!strcmp(job->computeJobDescriptor.pipeline.uavTextureBindings[i].name,"rw_output"))
                for(uint32_t k=0;k<descriptorWriteIndex;k++)
                    if(writeDescriptorSets[k].dstBinding==job->computeJobDescriptor.pipeline.uavTextureBindings[i].slotIndex&&
                       writeDescriptorSets[k].descriptorType==VK_DESCRIPTOR_TYPE_STORAGE_IMAGE)output=writeDescriptorSets[k].pImageInfo;
        const uint32_t fw=statsConstants->_DisplaySize[0],fh=statsConstants->_DisplaySize[1];
        const uint32_t ring=FFX_MAX_QUEUED_FRAMES*MAX_PIPELINE_USAGE_PER_FRAME;
        if(nfruSelectFp32()){
            auto* select=static_cast<NfruSelect*>(pipelineLayout->selectEngine);
            if(select&&(select->fw!=fw||select->fh!=fh)){delete select;select=nullptr;pipelineLayout->selectEngine=nullptr;}
            if(!select&&cand&&output&&candBytes>=VkDeviceSize(fw)*fh*24){
                select=new NfruSelect();
                if(!select->init(backendContext->device,backendContext->physicalDevice,fw,fh,ring)){nss_trace("NFRU select: init failed, disabled");delete select;select=nullptr;}
                pipelineLayout->selectEngine=select;
            }
            if(select&&cand&&output)select->record(vkCommandBuffer,pipelineLayout->descriptorSetIndex,cand,*output);
        }else{
            auto* select=static_cast<NfruSelectI8*>(pipelineLayout->selectEngine);
            if(select&&(select->fw!=fw||select->fh!=fh)){delete select;select=nullptr;pipelineLayout->selectEngine=nullptr;}
            if(!select&&cand&&output&&candBytes>=VkDeviceSize(fw)*fh*24){
                select=new NfruSelectI8();
                if(!select->init(backendContext->device,backendContext->physicalDevice,backendContext->instance,fw,fh,ring)){nss_trace("NFRU select int8: init failed, disabled");delete select;select=nullptr;}
                pipelineLayout->selectEngine=select;
            }
            if(select&&cand&&output)select->record(vkCommandBuffer,pipelineLayout->descriptorSetIndex,cand,*output);
        }
    }

    if(statsPost&&fiStats&&statsBuffer&&statsConstants&&(statsConstants->_pad0&0x200u)&&!statsConstants->_Reset)
        fiStats->snapshot(vkCommandBuffer,statsBuffer,statsConstants->_MvDepthLaneSize[0],statsConstants->_MvDepthLaneSize[1],statsConstants->_Timestep);

                                                                                                                   
    ++pipelineLayout->descriptorSetIndex;
    if (pipelineLayout->descriptorSetIndex >= (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME))
        pipelineLayout->descriptorSetIndex = 0;

    return FFX_OK;
}

static FfxErrorCode executeGpuJobFragment(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    BackendContext_VK::PipelineLayout* pipelineLayout = reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->fragmentJobDescriptor.pipeline.rootSignature);

                                                                                                                                
    uint32_t             descriptorWriteIndex = 0;
    VkWriteDescriptorSet writeDescriptorSets[FFX_MAX_RESOURCE_COUNT];

                                
    uint32_t              imageDescriptorIndex = 0;
    VkDescriptorImageInfo imageDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        imageDescriptorInfos[i] = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};

                                
    uint32_t               bufferDescriptorIndex = 0;
    VkDescriptorBufferInfo bufferDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        bufferDescriptorInfos[i] = {VK_NULL_HANDLE, 0, VK_WHOLE_SIZE};

    uint32_t                      tensorDescriptorIndex = 0;
    VkWriteDescriptorSetTensorARM tensorDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        tensorDescriptorInfos[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_TENSOR_ARM, nullptr};

                        
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->fragmentJobDescriptor.pipeline.uavTextureCount; ++currentPipelineUavIndex)
    {
        FfxTextureUAV& textureUAV = job->fragmentJobDescriptor.uavTextures[currentPipelineUavIndex];

                                               
        if (job->fragmentJobDescriptor.uavTextures[currentPipelineUavIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureUAV.resource, FFX_RESOURCE_STATE_PIXEL_UAV);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.uavTextureBindings[currentPipelineUavIndex];

                           
        const uint32_t currentUavResourceIndex = job->fragmentJobDescriptor.pipeline.uavTextureBindings[currentPipelineUavIndex].slotIndex;

                                          
        const uint32_t resourceIndex = textureUAV.resource.internalIndex;
        uint32_t       mipOffset     = textureUAV.mip;
        if (textureUAV.mip >= backendContext->pResources[resourceIndex].resourceDescription.mipCount)
            mipOffset = backendContext->pResources[resourceIndex].resourceDescription.mipCount - 1;
        const uint32_t uavViewIndex = backendContext->pResources[resourceIndex].uavViewIndex + mipOffset;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[uavViewIndex].imageView;

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->fragmentJobDescriptor.pipeline.uavBufferCount; ++currentPipelineUavIndex)
    {
        FfxBufferUAV& bufferUAV = job->fragmentJobDescriptor.uavBuffers[currentPipelineUavIndex];

                                               
        if (job->fragmentJobDescriptor.uavBuffers[currentPipelineUavIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &bufferUAV.resource, FFX_RESOURCE_STATE_PIXEL_UAV);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.uavBufferBindings[currentPipelineUavIndex];

                                        
        const uint32_t resourceIndex = bufferUAV.resource.internalIndex;

                           
        const uint32_t currentUavResourceIndex = job->fragmentJobDescriptor.pipeline.uavBufferBindings[currentPipelineUavIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        bufferDescriptorInfos[bufferDescriptorIndex] = {};

        const auto& backendResource = backendContext->pResources[resourceIndex];
        const bool  isTensor        = (backendResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR);
        const bool  isBufferAliased = ((backendResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED);

        if (isBufferAliased || backendResource.bridgeTensor)
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer =
                isTensor ? backendResource.aliasedTensorBufferResource : backendResource.aliasedBufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range = VK_WHOLE_SIZE;
        }
        else
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer = backendResource.bufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range  = bufferUAV.size > 0 ? bufferUAV.size : backendResource.resourceDescription.size;
        }

        bufferDescriptorInfos[bufferDescriptorIndex].offset = bufferUAV.offset;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

                        
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->fragmentJobDescriptor.pipeline.srvTextureCount; ++currentPipelineSrvIndex)
    {
        FfxTextureSRV& textureSRV = job->fragmentJobDescriptor.srvTextures[currentPipelineSrvIndex];

                                               
        if (job->fragmentJobDescriptor.srvTextures[currentPipelineSrvIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureSRV.resource, FFX_RESOURCE_STATE_PIXEL_READ);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.srvTextureBindings[currentPipelineSrvIndex];

                           
        const uint32_t currentSrvResourceIndex = job->fragmentJobDescriptor.pipeline.srvTextureBindings[currentPipelineSrvIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        const uint32_t resourceIndex = textureSRV.resource.internalIndex;
        const uint32_t srvViewIndex  = backendContext->pResources[resourceIndex].srvViewIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[srvViewIndex].imageView;

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->fragmentJobDescriptor.pipeline.srvBufferCount; ++currentPipelineSrvIndex)
    {
        FfxBufferSRV& bufferSRV = job->fragmentJobDescriptor.srvBuffers[currentPipelineSrvIndex];

                                               
        if (job->fragmentJobDescriptor.srvBuffers[currentPipelineSrvIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &bufferSRV.resource, FFX_RESOURCE_STATE_PIXEL_READ);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.srvBufferBindings[currentPipelineSrvIndex];

                                        
        const uint32_t resourceIndex = bufferSRV.resource.internalIndex;

                           
        const uint32_t currentSrvResourceIndex = job->fragmentJobDescriptor.pipeline.srvBufferBindings[currentPipelineSrvIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        bufferDescriptorInfos[bufferDescriptorIndex] = {};

        const auto& backendResource = backendContext->pResources[resourceIndex];
        const bool  isTensor        = (backendResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR);
        const bool  isBufferAliased = ((backendResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_BUFFER_ALIASED) == FFX_RESOURCE_FLAGS_BUFFER_ALIASED);

        if (isBufferAliased || backendResource.bridgeTensor)
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer =
                isTensor ? backendResource.aliasedTensorBufferResource : backendResource.aliasedBufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range = VK_WHOLE_SIZE;
        }
        else
        {
            bufferDescriptorInfos[bufferDescriptorIndex].buffer = backendResource.bufferResource;
            bufferDescriptorInfos[bufferDescriptorIndex].range  = bufferSRV.size > 0 ? bufferSRV.size : backendResource.resourceDescription.size;
        }
        bufferDescriptorInfos[bufferDescriptorIndex].offset = bufferSRV.offset;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->fragmentJobDescriptor.pipeline.uavTensorCount; ++currentPipelineUavIndex)
    {
        FfxTensor& tensor = job->fragmentJobDescriptor.uavTensors[currentPipelineUavIndex];

        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_PIXEL_UAV);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.uavTensorBindings[currentPipelineUavIndex];

        const uint32_t resourceIndex   = job->fragmentJobDescriptor.uavTensors[currentPipelineUavIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->fragmentJobDescriptor.pipeline.srvTensorCount; ++currentPipelineSrvIndex)
    {
        FfxTensor& tensor = job->fragmentJobDescriptor.srvTensors[currentPipelineSrvIndex];

        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_PIXEL_READ);

        const FfxResourceBinding binding = job->fragmentJobDescriptor.pipeline.srvTensorBindings[currentPipelineSrvIndex];

        const uint32_t resourceIndex   = job->fragmentJobDescriptor.srvTensors[currentPipelineSrvIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                             
    for (uint32_t currentRootConstantIndex = 0; currentRootConstantIndex < job->fragmentJobDescriptor.pipeline.constCount; ++currentRootConstantIndex)
    {
        uint32_t dataSize = job->fragmentJobDescriptor.cbs[currentRootConstantIndex].num32BitEntries * sizeof(uint32_t);

                                                                                                        
        FfxConstantAllocation allocation;
        if (s_fpConstantAllocator)
            allocation = s_fpConstantAllocator(job->fragmentJobDescriptor.cbs[currentRootConstantIndex].data, dataSize);
        else
            allocation = backendContext->FallbackConstantAllocator(job->fragmentJobDescriptor.cbs[currentRootConstantIndex].data, dataSize);

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        writeDescriptorSets[descriptorWriteIndex].pBufferInfo     = &bufferDescriptorInfos[bufferDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding = job->fragmentJobDescriptor.pipeline.constantBufferBindings[currentRootConstantIndex].slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = 0;

        bufferDescriptorInfos[bufferDescriptorIndex].buffer = static_cast<VkBuffer>(allocation.resource.resource);
        bufferDescriptorInfos[bufferDescriptorIndex].offset = static_cast<VkDeviceSize>(allocation.handle);
        bufferDescriptorInfos[bufferDescriptorIndex].range  = dataSize;

        bufferDescriptorIndex++;
        descriptorWriteIndex++;
    }

                     
    for (FfxUInt32 rt = 0; rt < job->fragmentJobDescriptor.pipeline.rtCount; ++rt)
    {
        addBarrier(backendContext, &job->fragmentJobDescriptor.rtTextures[rt].resource, FFX_RESOURCE_STATE_RENDER_TARGET);
    }

                              
    flushBarriers(backendContext, vkCommandBuffer);

                               
    VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, descriptorWriteIndex, writeDescriptorSets, 0, nullptr);

    getOrCreateRenderPass(backendContext, job);

    getOrCreateFrameBuffer(backendContext, job);

    getOrCreateGraphicsPipeline(backendContext, job);

    constexpr VkClearValue clearColors[FFX_MAX_NUM_RTS] = {};
    const VkExtent2D       extent                       = {job->fragmentJobDescriptor.viewport[0], job->fragmentJobDescriptor.viewport[1]};

    VkRenderPassBeginInfo renderPassBeginInfo = {};
    renderPassBeginInfo.sType                 = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    renderPassBeginInfo.renderPass            = pipelineLayout->renderPass[pipelineLayout->renderPassIndex].handle;
    renderPassBeginInfo.framebuffer           = pipelineLayout->frameBuffer[pipelineLayout->frameBufferIndex].handle;
    renderPassBeginInfo.renderArea.offset.x   = 0;
    renderPassBeginInfo.renderArea.offset.y   = 0;
    renderPassBeginInfo.renderArea.extent     = extent;
    renderPassBeginInfo.clearValueCount       = job->fragmentJobDescriptor.pipeline.rtCount;
    renderPassBeginInfo.pClearValues          = (job->fragmentJobDescriptor.pipeline.rtCount > 0) ? clearColors : nullptr;

    VulkanWrapper().vkCmdBeginRenderPass(vkCommandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
                    
    VulkanWrapper().vkCmdBindPipeline(
        vkCommandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, reinterpret_cast<VkPipeline>(job->fragmentJobDescriptor.pipeline.pipeline));

                           
    VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                            VK_PIPELINE_BIND_POINT_GRAPHICS,
                                            pipelineLayout->pipelineLayout,
                                            0,
                                            1,
                                            &pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex],
                                            0,
                                            nullptr);

    const VkViewport viewport = {0.0f, 0.0f, static_cast<float>(extent.width), static_cast<float>(extent.height)};
    VulkanWrapper().vkCmdSetViewport(vkCommandBuffer, 0, 1, &viewport);

    const VkRect2D scissor = {{0, 0}, extent};
    VulkanWrapper().vkCmdSetScissor(vkCommandBuffer, 0, 1, &scissor);

    VulkanWrapper().vkCmdDraw(vkCommandBuffer, 3, 1, 0, 0);

    VulkanWrapper().vkCmdEndRenderPass(vkCommandBuffer);

                                                                                                                   
    ++pipelineLayout->descriptorSetIndex;
    if (pipelineLayout->descriptorSetIndex >= (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME))
        pipelineLayout->descriptorSetIndex = 0;

    return FFX_OK;
}

                                                                         
static int nfruOfSetting(const char* name, int fallback)
{
#ifdef _WIN32
    char value[32]{};
    const DWORD count = GetEnvironmentVariableA(name, value, sizeof(value));
    return count && count < sizeof(value) ? atoi(value) : fallback;
#else
    const char* value = getenv(name);
    return value ? atoi(value) : fallback;
#endif
}

                                                                                                         
static FfxErrorCode executeOpticalFlowCompute(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer,
                                              BackendContext_VK::PipelineLayout* pipelineLayout)
{
    uint32_t              writeCount = 0;
    VkWriteDescriptorSet  writes[FFX_MAX_RESOURCE_COUNT];
    uint32_t              infoCount = 0;
    VkDescriptorImageInfo infos[FFX_MAX_RESOURCE_COUNT];
    const VkDescriptorSet set = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];

    uint32_t flowW = 0, flowH = 0;
    const FfxPipelineState& pipeline = job->dataGraphJobDescription.pipeline;

    for (uint32_t i = 0; i < pipeline.uavTextureCount; ++i)
    {
        FfxTextureUAV& uav = job->dataGraphJobDescription.uavTextures[i];
        if (uav.resource.internalIndex == 0)
            continue;
        addBarrier(backendContext, &uav.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);
        const uint32_t resIdx = uav.resource.internalIndex;
        flowW                 = backendContext->pResources[resIdx].resourceDescription.width;
        flowH                 = backendContext->pResources[resIdx].resourceDescription.height;
        const uint32_t view   = backendContext->pResources[resIdx].uavViewIndex;

        infos[infoCount]             = {};
        infos[infoCount].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        infos[infoCount].imageView   = backendContext->pResourceViews[view].imageView;
        writes[writeCount]           = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
        writes[writeCount].dstSet          = set;
        writes[writeCount].dstBinding      = pipeline.uavTextureBindings[i].slotIndex;
        writes[writeCount].dstArrayElement = pipeline.uavTextureBindings[i].arrayIndex;
        writes[writeCount].descriptorCount = 1;
        writes[writeCount].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writes[writeCount].pImageInfo      = &infos[infoCount];
        ++infoCount;
        ++writeCount;
    }

    for (uint32_t i = 0; i < pipeline.srvTextureCount; ++i)
    {
        FfxTextureSRV& srv = job->dataGraphJobDescription.srvTextures[i];
        if (srv.resource.internalIndex == 0)
            continue;
        addBarrier(backendContext, &srv.resource, FFX_RESOURCE_STATE_COMPUTE_READ);
        const uint32_t view = backendContext->pResources[srv.resource.internalIndex].srvViewIndex;

        infos[infoCount]             = {};
        infos[infoCount].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        infos[infoCount].imageView   = backendContext->pResourceViews[view].imageView;
        writes[writeCount]           = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
        writes[writeCount].dstSet          = set;
        writes[writeCount].dstBinding      = pipeline.srvTextureBindings[i].slotIndex;
        writes[writeCount].dstArrayElement = pipeline.srvTextureBindings[i].arrayIndex;
        writes[writeCount].descriptorCount = 1;
        writes[writeCount].descriptorType  = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        writes[writeCount].pImageInfo      = &infos[infoCount];
        ++infoCount;
        ++writeCount;
    }

                                                                                   
    FfxResourceInternal mvResource = job->dataGraphJobDescription.gameMotionVectors;
    const bool useGameMv = mvResource.internalIndex != 0;
    if (!useGameMv) mvResource = job->dataGraphJobDescription.srvTextures[2].resource;
    addBarrier(backendContext, &mvResource, FFX_RESOURCE_STATE_COMPUTE_READ);
    infos[infoCount] = {};
    infos[infoCount].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    infos[infoCount].imageView = backendContext->pResourceViews[backendContext->pResources[mvResource.internalIndex].srvViewIndex].imageView;
    writes[writeCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    writes[writeCount].dstSet = set;
    writes[writeCount].dstBinding = 4;
    writes[writeCount].descriptorCount = 1;
    writes[writeCount].descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
    writes[writeCount].pImageInfo = &infos[infoCount];
    ++infoCount; ++writeCount;

    FfxResourceInternal depthResource = job->dataGraphJobDescription.gameDepth;
    const bool useDepth = useGameMv && depthResource.internalIndex != 0 &&
                          nfruOfSetting("NFRU_OF_DEPTH_AWARE_MV", 1) != 0;
    if (depthResource.internalIndex == 0) depthResource = job->dataGraphJobDescription.srvTextures[2].resource;
    addBarrier(backendContext, &depthResource, FFX_RESOURCE_STATE_COMPUTE_READ);
    infos[infoCount] = {};
    infos[infoCount].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    infos[infoCount].imageView = backendContext->pResourceViews[backendContext->pResources[depthResource.internalIndex].srvViewIndex].imageView;
    writes[writeCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    writes[writeCount].dstSet = set;
    writes[writeCount].dstBinding = 5;
    writes[writeCount].descriptorCount = 1;
    writes[writeCount].descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
    writes[writeCount].pImageInfo = &infos[infoCount];
    ++infoCount; ++writeCount;

    auto* stats=static_cast<NfruGpuStats*>(pipelineLayout->ofGpuStats);
    if(!stats){stats=new NfruGpuStats();if(!stats->init(backendContext->device,backendContext->physicalDevice,true)){delete stats;return FFX_ERROR_BACKEND_API_ERROR;}pipelineLayout->ofGpuStats=stats;}
    FfxResourceInternal previousDepthResource=job->dataGraphJobDescription.gamePreviousDepth;
    bool useTemporalDepth=useDepth && previousDepthResource.internalIndex!=0 && nfruOfSetting("NFRU_OF_TEMPORAL_DEPTH",1)!=0;
    for(float value:job->dataGraphJobDescription.gamePreviousToCurrentClip) if(!std::isfinite(value))useTemporalDepth=false;
    if(previousDepthResource.internalIndex==0)previousDepthResource=depthResource;
    addBarrier(backendContext,&previousDepthResource,FFX_RESOURCE_STATE_COMPUTE_READ);
    infos[infoCount]={};infos[infoCount].imageLayout=VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    infos[infoCount].imageView=backendContext->pResourceViews[backendContext->pResources[previousDepthResource.internalIndex].srvViewIndex].imageView;
    writes[writeCount]={VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};writes[writeCount].dstSet=set;writes[writeCount].dstBinding=7;
    writes[writeCount].descriptorCount=1;writes[writeCount].descriptorType=VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;writes[writeCount].pImageInfo=&infos[infoCount];++writeCount;++infoCount;
    stats->poll("OF");
    const bool sample=nfruStatsEnabled()&&!stats->disabled&&stats->due();
    VkDescriptorBufferInfo statsInfo{stats->own,0,NfruGpuStats::bytes};
    writes[writeCount]={VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};writes[writeCount].dstSet=set;writes[writeCount].dstBinding=6;writes[writeCount].descriptorCount=1;writes[writeCount].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;writes[writeCount].pBufferInfo=&statsInfo;++writeCount;
    flushBarriers(backendContext, vkCommandBuffer);
    if(sample)stats->clear(vkCommandBuffer,stats->own);
    VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, writeCount, writes, 0, nullptr);

    const int   ofMode   = nfruOfSetting("NFRU_OF_MODE", 1);
    const int   ofRadius = nfruOfSetting("NFRU_OF_RADIUS", 2);
    const float seedSx   = getenv("NFRU_OF_SEED_SX") ? (float) atof(getenv("NFRU_OF_SEED_SX")) : 1.0f;
    const float seedSy   = getenv("NFRU_OF_SEED_SY") ? (float) atof(getenv("NFRU_OF_SEED_SY")) : 1.0f;
    const float flowSx   = getenv("NFRU_OF_FLOW_SX") ? (float) atof(getenv("NFRU_OF_FLOW_SX")) : 1.0f;
    const float flowSy   = getenv("NFRU_OF_FLOW_SY") ? (float) atof(getenv("NFRU_OF_FLOW_SY")) : 1.0f;
    const float constX = getenv("NFRU_OF_CONST_X") ? (float) atof(getenv("NFRU_OF_CONST_X")) : 0.0f;
    const float constY = getenv("NFRU_OF_CONST_Y") ? (float) atof(getenv("NFRU_OF_CONST_Y")) : 0.0f;
    struct OfPC { int32_t mode, radius; float seedSx, seedSy, flowSx, flowSy, constX, constY; float mvUvX, mvUvY; int32_t useGameMv, pad; float previousToCurrentClip[16]; };
    const auto mvScale = job->dataGraphJobDescription.gameMotionVectorUvScale;
    OfPC pc = {ofMode, ofRadius, seedSx, seedSy, flowSx, flowSy, constX, constY, mvScale.x, mvScale.y, useGameMv ? 1 : 0, useDepth ? 1 : 0};

    memcpy(pc.previousToCurrentClip,job->dataGraphJobDescription.gamePreviousToCurrentClip,sizeof(pc.previousToCurrentClip));
    if(useTemporalDepth)pc.pad|=2;

    if(sample)pc.pad|=256;
    if(pipelineLayout->embeddedOpticalFlow!=nullptr)pc.pad|=512;                                                                   

    if (getenv("NFRU_OF_DEBUG"))
    {
        static int dbgCount = 0;
        if (dbgCount++ < 6)
            fprintf(stderr, "[NFRU OF] job %d: srv=%u uav=%u flow=%ux%u writes=%u mode=%d radius=%d gameMV=%d\n", dbgCount, pipeline.srvTextureCount,
                    pipeline.uavTextureCount, flowW, flowH, writeCount, ofMode, ofRadius, pc.useGameMv);
    }
    VulkanWrapper().vkCmdBindPipeline(vkCommandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout->ofComputePipeline);
    VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout->pipelineLayout, 0, 1, &set, 0, nullptr);
    VulkanWrapper().vkCmdPushConstants(vkCommandBuffer, pipelineLayout->pipelineLayout, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
    VulkanWrapper().vkCmdDispatch(vkCommandBuffer, (flowW + 7) / 8, (flowH + 7) / 8, 1);

    if(sample)stats->snapshot(vkCommandBuffer,stats->own,flowW,flowH,0.0f);

    ++pipelineLayout->descriptorSetIndex;
    if (pipelineLayout->descriptorSetIndex >= (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME))
        pipelineLayout->descriptorSetIndex = 0;
    return FFX_OK;
}

static FfxErrorCode executeEmbeddedOpticalFlow(BackendContext_VK* backendContext, FfxGpuJobDescription* job,
                                                    VkCommandBuffer vkCommandBuffer,
                                                    BackendContext_VK::PipelineLayout* pipelineLayout)
{
    EmbeddedOfImage images[FFX_MAX_RESOURCE_COUNT]{};
    uint32_t imageCount = 0;
    const FfxPipelineState& pipeline = job->dataGraphJobDescription.pipeline;

    for (uint32_t i = 0; i < pipeline.uavTextureCount; ++i)
    {
        FfxTextureUAV& uav = job->dataGraphJobDescription.uavTextures[i];
        if (uav.resource.internalIndex == 0)
            continue;
        addBarrier(backendContext, &uav.resource, FFX_RESOURCE_STATE_COMPUTE_UAV);
        const uint32_t resourceIndex = uav.resource.internalIndex;
        uint32_t mipOffset = uav.mip;
        if (mipOffset >= backendContext->pResources[resourceIndex].resourceDescription.mipCount)
            mipOffset = backendContext->pResources[resourceIndex].resourceDescription.mipCount - 1;
        const uint32_t view = backendContext->pResources[resourceIndex].uavViewIndex + mipOffset;
        const FfxResourceBinding binding = pipeline.uavTextureBindings[i];
        images[imageCount++] = {binding.bindSet, binding.slotIndex, backendContext->pResourceViews[view].imageView};
    }

    for (uint32_t i = 0; i < pipeline.srvTextureCount; ++i)
    {
        FfxTextureSRV& srv = job->dataGraphJobDescription.srvTextures[i];
        if (srv.resource.internalIndex == 0)
            continue;
        addBarrier(backendContext, &srv.resource, FFX_RESOURCE_STATE_COMPUTE_READ);
        const uint32_t resourceIndex = srv.resource.internalIndex;
        const uint32_t view = backendContext->pResources[resourceIndex].srvViewIndex;
        const FfxResourceBinding binding = pipeline.srvTextureBindings[i];
        images[imageCount++] = {binding.bindSet, binding.slotIndex, backendContext->pResourceViews[view].imageView};
    }

    flushBarriers(backendContext, vkCommandBuffer);
    auto* embedded = static_cast<EmbeddedOpticalFlow*>(pipelineLayout->embeddedOpticalFlow);
    std::string error;
    if (!embedded->dispatch(vkCommandBuffer, images, imageCount,
                            ffxGetVkOpticalFlowExecuteFlags(job->dataGraphJobDescription.opticalFlowExecuteFlags),
                            job->dataGraphJobDescription.meanFlowL1NormHint, error))
    {
        nss_trace("backend: embedded original VKML OF dispatch failed: %s", error.c_str());
        return FFX_ERROR_BACKEND_API_ERROR;
    }
    return FFX_OK;
}

static FfxErrorCode executeGpuJobDataGraph(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    BackendContext_VK::PipelineLayout* pipelineLayout =
        reinterpret_cast<BackendContext_VK::PipelineLayout*>(job->dataGraphJobDescription.pipeline.rootSignature);
    FFX_ASSERT(pipelineLayout->effectContextId < backendContext->maxEffectContexts);

    const BackendContext_VK::EffectContext& effectContext = backendContext->pEffectContexts[pipelineLayout->effectContextId];
    if (pipelineLayout->embeddedOpticalFlow != nullptr && pipelineLayout->ofComputePipeline != VK_NULL_HANDLE)
    {
                                                                                                                
        const FfxErrorCode embeddedResult = executeEmbeddedOpticalFlow(backendContext, job, vkCommandBuffer, pipelineLayout);
        if (embeddedResult != FFX_OK)
            return embeddedResult;
        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                             0, 1, &mb, 0, nullptr, 0, nullptr);
        return executeOpticalFlowCompute(backendContext, job, vkCommandBuffer, pipelineLayout);
    }
    if (pipelineLayout->embeddedOpticalFlow != nullptr)
        return executeEmbeddedOpticalFlow(backendContext, job, vkCommandBuffer, pipelineLayout);
    if (pipelineLayout->ofComputePipeline != VK_NULL_HANDLE)
        return executeOpticalFlowCompute(backendContext, job, vkCommandBuffer, pipelineLayout);

    if (pipelineLayout->nfruEngine != nullptr)
    {
        NfruEngine* eng = static_cast<NfruEngine*>(pipelineLayout->nfruEngine);

        VkBuffer inBuf  = VK_NULL_HANDLE;
        VkBuffer outBuf = VK_NULL_HANDLE;
        uint32_t outIdx = 0xFFFFFFFF;
        if (job->dataGraphJobDescription.pipeline.srvTensorCount > 0)
            inBuf = backendContext->pResources[job->dataGraphJobDescription.srvTensors[0].resource.internalIndex].aliasedTensorBufferResource;
        if (job->dataGraphJobDescription.pipeline.uavTensorCount > 0)
        {
            outIdx = job->dataGraphJobDescription.uavTensors[0].resource.internalIndex;
            outBuf = backendContext->pResources[outIdx].aliasedTensorBufferResource;
        }
        if (inBuf == VK_NULL_HANDLE || outBuf == VK_NULL_HANDLE || !eng->bindIO(inBuf, outBuf))
            return FFX_ERROR_INVALID_ARGUMENT;

                                                     
        VkMemoryBarrier preBarrier = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        preBarrier.srcAccessMask   = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        preBarrier.dstAccessMask   = VK_ACCESS_SHADER_READ_BIT;
        VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &preBarrier, 0, nullptr, 0, nullptr);

        eng->record(vkCommandBuffer);

                                                                                                                         
        const VkImage outImage = backendContext->pResources[outIdx].aliasedTensorImageResource;
        if (outImage != VK_NULL_HANDLE)
        {
            const uint32_t outW = backendContext->pResources[outIdx].resourceDescription.width;
            const uint32_t outH = backendContext->pResources[outIdx].resourceDescription.height;

            VkImageMemoryBarrier imgBarrier = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
            imgBarrier.srcAccessMask       = 0;
            imgBarrier.dstAccessMask       = VK_ACCESS_TRANSFER_WRITE_BIT;
            imgBarrier.oldLayout           = VK_IMAGE_LAYOUT_UNDEFINED;
            imgBarrier.newLayout           = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imgBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imgBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imgBarrier.image               = outImage;
            imgBarrier.subresourceRange    = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

            VkBufferMemoryBarrier bufBarrier = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
            bufBarrier.srcAccessMask       = VK_ACCESS_SHADER_WRITE_BIT;
            bufBarrier.dstAccessMask       = VK_ACCESS_TRANSFER_READ_BIT;
            bufBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bufBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bufBarrier.buffer              = outBuf;
            bufBarrier.offset              = 0;
            bufBarrier.size                = VK_WHOLE_SIZE;
            VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 1, &bufBarrier, 1, &imgBarrier);

            VkBufferImageCopy copyRegion = {};
            copyRegion.imageSubresource  = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
            copyRegion.imageExtent       = {outW, outH, 1};
            VulkanWrapper().vkCmdCopyBufferToImage(vkCommandBuffer, outBuf, outImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

            imgBarrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            imgBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            imgBarrier.oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imgBarrier.newLayout     = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 1, &imgBarrier);
        }

        VkBufferMemoryBarrier outBarrier = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
        outBarrier.srcAccessMask       = VK_ACCESS_SHADER_WRITE_BIT;
        outBarrier.dstAccessMask       = VK_ACCESS_SHADER_READ_BIT;
        outBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        outBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        outBarrier.buffer              = outBuf;
        outBarrier.offset              = 0;
        outBarrier.size                = VK_WHOLE_SIZE;
        VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                             VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, nullptr, 1, &outBarrier, 0, nullptr);
        return FFX_OK;
    }

    if (pipelineLayout->nssEngineHandle != nullptr)
    {
        VkBuffer inBuf = VK_NULL_HANDLE;
        if (job->dataGraphJobDescription.pipeline.srvTensorCount > 0)
        {
            uint32_t rIdx = job->dataGraphJobDescription.srvTensors[0].resource.internalIndex;
            inBuf = backendContext->pResources[rIdx].aliasedTensorBufferResource;
        }

        VkBuffer kpnBuf = VK_NULL_HANDLE;
        VkBuffer fdbkBuf = VK_NULL_HANDLE;
        uint32_t fdbkResIdx = 0xFFFFFFFF;

        for (uint32_t i = 0; i < job->dataGraphJobDescription.pipeline.uavTensorCount; ++i)
        {
            uint32_t rIdx = job->dataGraphJobDescription.uavTensors[i].resource.internalIndex;
            const auto& resDesc = backendContext->pResources[rIdx].resourceDescription;
            if (resDesc.channel == 4)
            {
                fdbkBuf = backendContext->pResources[rIdx].aliasedTensorBufferResource;
                fdbkResIdx = rIdx;
            }
            else
            {
                kpnBuf = backendContext->pResources[rIdx].aliasedTensorBufferResource;
            }
        }

        if (inBuf != VK_NULL_HANDLE && kpnBuf != VK_NULL_HANDLE && fdbkBuf != VK_NULL_HANDLE)
        {
                                                                       
            VkBufferMemoryBarrier inBarrier = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
            inBarrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            inBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            inBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            inBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            inBarrier.buffer = inBuf;
            inBarrier.offset = 0;
            inBarrier.size = VK_WHOLE_SIZE;
            VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer,
                                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                                 0, 0, nullptr, 1, &inBarrier, 0, nullptr);

                                                             
            nss_engine_dispatch(pipelineLayout->nssEngineHandle, vkCommandBuffer,
                                inBuf, 0, kpnBuf, 0, fdbkBuf, 0);

                                                                                              
            if (fdbkResIdx != 0xFFFFFFFF && backendContext->pResources[fdbkResIdx].aliasedTensorImageResource != VK_NULL_HANDLE)
            {
                VkImage fdbkImage = backendContext->pResources[fdbkResIdx].aliasedTensorImageResource;
                uint32_t fdbkW = backendContext->pResources[fdbkResIdx].resourceDescription.width;
                uint32_t fdbkH = backendContext->pResources[fdbkResIdx].resourceDescription.height;

                VkImageMemoryBarrier imgBarrier = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
                imgBarrier.srcAccessMask = 0;
                imgBarrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
                imgBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
                imgBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
                imgBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                imgBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                imgBarrier.image = fdbkImage;
                imgBarrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

                VkBufferMemoryBarrier bufBarrier = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
                bufBarrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
                bufBarrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
                bufBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                bufBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                bufBarrier.buffer = fdbkBuf;
                bufBarrier.offset = 0;
                bufBarrier.size = VK_WHOLE_SIZE;

                VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer,
                                                     VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                                     VK_PIPELINE_STAGE_TRANSFER_BIT,
                                                     0, 0, nullptr, 1, &bufBarrier, 1, &imgBarrier);

                VkBufferImageCopy copyRegion = {};
                copyRegion.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
                copyRegion.imageExtent = {fdbkW, fdbkH, 1};
                VulkanWrapper().vkCmdCopyBufferToImage(vkCommandBuffer, fdbkBuf, fdbkImage,
                                                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

                imgBarrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
                imgBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
                imgBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
                imgBarrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
                VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer,
                                                     VK_PIPELINE_STAGE_TRANSFER_BIT,
                                                     VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                                                     0, 0, nullptr, 0, nullptr, 1, &imgBarrier);
            }

                                                                                               
            VkBufferMemoryBarrier kpnBarrier = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
            kpnBarrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            kpnBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            kpnBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            kpnBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            kpnBarrier.buffer = kpnBuf;
            kpnBarrier.offset = 0;
            kpnBarrier.size = VK_WHOLE_SIZE;
            VulkanWrapper().vkCmdPipelineBarrier(vkCommandBuffer,
                                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                                                 0, 0, nullptr, 1, &kpnBarrier, 0, nullptr);

            return FFX_OK;
        }
    }


    uint32_t             descriptorWriteIndex = 0;
    VkWriteDescriptorSet writeDescriptorSets[FFX_MAX_RESOURCE_COUNT];

    uint32_t                      tensorDescriptorIndex = 0;
    VkWriteDescriptorSetTensorARM tensorDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        tensorDescriptorInfos[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_TENSOR_ARM, nullptr};

                                
    uint32_t              imageDescriptorIndex = 0;
    VkDescriptorImageInfo imageDescriptorInfos[FFX_MAX_RESOURCE_COUNT];
    for (int i = 0; i < FFX_MAX_RESOURCE_COUNT; ++i)
        imageDescriptorInfos[i] = {VK_NULL_HANDLE, VK_NULL_HANDLE, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};

                                                                                                                           
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.srvBufferCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.uavBufferCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.staticTextureSrvCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.staticBufferSrvCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.staticTextureUavCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.staticBufferUavCount == 0);
    FFX_ASSERT(job->dataGraphJobDescription.pipeline.rtCount == 0);

                        
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->dataGraphJobDescription.pipeline.uavTextureCount; ++currentPipelineUavIndex)
    {
        FfxTextureUAV& textureUAV = job->dataGraphJobDescription.uavTextures[currentPipelineUavIndex];

                                               
        if (job->dataGraphJobDescription.uavTextures[currentPipelineUavIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureUAV.resource, FFX_RESOURCE_STATE_DATA_GRAPH_WRITE);

        const FfxResourceBinding binding = job->dataGraphJobDescription.pipeline.uavTextureBindings[currentPipelineUavIndex];

                           
        const uint32_t currentUavResourceIndex = job->dataGraphJobDescription.pipeline.uavTextureBindings[currentPipelineUavIndex].slotIndex;

                                          
        const uint32_t resourceIndex = textureUAV.resource.internalIndex;
        uint32_t       mipOffset     = textureUAV.mip;
        if (textureUAV.mip >= backendContext->pResources[resourceIndex].resourceDescription.mipCount)
            mipOffset = backendContext->pResources[resourceIndex].resourceDescription.mipCount - 1;
        const uint32_t uavViewIndex = backendContext->pResources[resourceIndex].uavViewIndex + mipOffset;

        writeDescriptorSets[descriptorWriteIndex]        = {};
        writeDescriptorSets[descriptorWriteIndex].sType  = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];

        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[uavViewIndex].imageView;

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                        
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->dataGraphJobDescription.pipeline.srvTextureCount; ++currentPipelineSrvIndex)
    {
        FfxTextureSRV& textureSRV = job->dataGraphJobDescription.srvTextures[currentPipelineSrvIndex];

                                               
        if (job->dataGraphJobDescription.srvTextures[currentPipelineSrvIndex].resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &textureSRV.resource, FFX_RESOURCE_STATE_DATA_GRAPH_READ);

        const FfxResourceBinding binding = job->dataGraphJobDescription.pipeline.srvTextureBindings[currentPipelineSrvIndex];

                           
        const uint32_t currentSrvResourceIndex = job->dataGraphJobDescription.pipeline.srvTextureBindings[currentPipelineSrvIndex].slotIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        writeDescriptorSets[descriptorWriteIndex].pImageInfo      = &imageDescriptorInfos[imageDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        const uint32_t resourceIndex = textureSRV.resource.internalIndex;
        const uint32_t srvViewIndex  = backendContext->pResources[resourceIndex].srvViewIndex;

        imageDescriptorInfos[imageDescriptorIndex]             = {};
        imageDescriptorInfos[imageDescriptorIndex].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        imageDescriptorInfos[imageDescriptorIndex].imageView   = backendContext->pResourceViews[srvViewIndex].imageView;

        imageDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineUavIndex = 0; currentPipelineUavIndex < job->dataGraphJobDescription.pipeline.uavTensorCount; ++currentPipelineUavIndex)
    {
        FfxTensor& tensor = job->dataGraphJobDescription.uavTensors[currentPipelineUavIndex];

                                               
        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_DATA_GRAPH_WRITE);

        const FfxResourceBinding binding = job->dataGraphJobDescription.pipeline.uavTensorBindings[currentPipelineUavIndex];

        const uint32_t resourceIndex   = job->dataGraphJobDescription.uavTensors[currentPipelineUavIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                       
    for (uint32_t currentPipelineSrvIndex = 0; currentPipelineSrvIndex < job->dataGraphJobDescription.pipeline.srvTensorCount; ++currentPipelineSrvIndex)
    {
        FfxTensor& tensor = job->dataGraphJobDescription.srvTensors[currentPipelineSrvIndex];

                                               
        if (tensor.resource.internalIndex == 0)
            continue;

        addBarrier(backendContext, &tensor.resource, FFX_RESOURCE_STATE_DATA_GRAPH_READ);

        const FfxResourceBinding binding = job->dataGraphJobDescription.pipeline.srvTensorBindings[currentPipelineSrvIndex];

        const uint32_t resourceIndex   = job->dataGraphJobDescription.srvTensors[currentPipelineSrvIndex].resource.internalIndex;
        const uint32_t tensorViewIndex = backendContext->pResources[resourceIndex].tensorViewIndex;

        writeDescriptorSets[descriptorWriteIndex]                 = {};
        writeDescriptorSets[descriptorWriteIndex].sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSets[descriptorWriteIndex].pNext           = &tensorDescriptorInfos[tensorDescriptorIndex];
        writeDescriptorSets[descriptorWriteIndex].dstSet          = pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex];
        writeDescriptorSets[descriptorWriteIndex].descriptorCount = 1;
        writeDescriptorSets[descriptorWriteIndex].descriptorType  = VK_DESCRIPTOR_TYPE_TENSOR_ARM;
        writeDescriptorSets[descriptorWriteIndex].dstBinding      = binding.slotIndex;
        writeDescriptorSets[descriptorWriteIndex].dstArrayElement = binding.arrayIndex;

        tensorDescriptorInfos[tensorDescriptorIndex].tensorViewCount = 1;
        tensorDescriptorInfos[tensorDescriptorIndex].pTensorViews    = &backendContext->pResourceViews[tensorViewIndex].tensorView;

        tensorDescriptorIndex++;
        descriptorWriteIndex++;
    }

                              
    flushBarriers(backendContext, vkCommandBuffer);

                               
    VulkanWrapper().vkUpdateDescriptorSets(backendContext->device, descriptorWriteIndex, writeDescriptorSets, 0, nullptr);

                    
    VulkanWrapper().vkCmdBindPipeline(
        vkCommandBuffer, VK_PIPELINE_BIND_POINT_DATA_GRAPH_ARM, reinterpret_cast<VkPipeline>(job->dataGraphJobDescription.pipeline.pipeline));

                           
    VulkanWrapper().vkCmdBindDescriptorSets(vkCommandBuffer,
                                            VK_PIPELINE_BIND_POINT_DATA_GRAPH_ARM,
                                            pipelineLayout->pipelineLayout,
                                            0,
                                            1,
                                            &pipelineLayout->descriptorSets[pipelineLayout->descriptorSetIndex],
                                            0,
                                            nullptr);

    VkDataGraphPipelineDispatchInfoARM dispatch_info = {};
    dispatch_info.sType                              = VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_DISPATCH_INFO_ARM;
    dispatch_info.flags                              = 0;

    if (effectContext.effectId == ARM_EFFECT_OPTICALFLOW)
    {
        VkDataGraphPipelineOpticalFlowDispatchInfoARM dispatch_optical_flow_info = {};
        dispatch_optical_flow_info.sType                                         = VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_OPTICAL_FLOW_DISPATCH_INFO_ARM;
        dispatch_optical_flow_info.pNext                                         = nullptr;
        dispatch_optical_flow_info.flags              = ffxGetVkOpticalFlowExecuteFlags(job->dataGraphJobDescription.opticalFlowExecuteFlags);
        dispatch_optical_flow_info.meanFlowL1NormHint = job->dataGraphJobDescription.meanFlowL1NormHint;
        dispatch_info.pNext                           = &dispatch_optical_flow_info;

        VulkanWrapper().vkCmdDispatchDataGraphARM(
            vkCommandBuffer, reinterpret_cast<VkDataGraphPipelineSessionARM>(job->dataGraphJobDescription.pipeline.session), &dispatch_info);
    }
    else
    {
        VulkanWrapper().vkCmdDispatchDataGraphARM(
            vkCommandBuffer, reinterpret_cast<VkDataGraphPipelineSessionARM>(job->dataGraphJobDescription.pipeline.session), &dispatch_info);
    }

                                                                                                                   
    ++pipelineLayout->descriptorSetIndex;
    if (pipelineLayout->descriptorSetIndex >= (FFX_MAX_QUEUED_FRAMES * MAX_PIPELINE_USAGE_PER_FRAME))
        pipelineLayout->descriptorSetIndex = 0;

    return FFX_OK;
}

static FfxErrorCode executeGpuJobCopy(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    BackendContext_VK::Resource ffxResourceSrc = backendContext->pResources[job->copyJobDescriptor.src.internalIndex];
    BackendContext_VK::Resource ffxResourceDst = backendContext->pResources[job->copyJobDescriptor.dst.internalIndex];

    addBarrier(backendContext, &job->copyJobDescriptor.src, FFX_RESOURCE_STATE_COPY_SRC);
    addBarrier(backendContext, &job->copyJobDescriptor.dst, FFX_RESOURCE_STATE_COPY_DEST);
    flushBarriers(backendContext, vkCommandBuffer);

    if (ffxResourceSrc.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER && ffxResourceDst.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        VkBuffer vkResourceSrc = ffxResourceSrc.bufferResource;
        VkBuffer vkResourceDst = ffxResourceDst.bufferResource;

        VkBufferCopy bufferCopy = {};

        bufferCopy.dstOffset = job->copyJobDescriptor.dstOffset;
        bufferCopy.srcOffset = job->copyJobDescriptor.srcOffset;
        bufferCopy.size      = job->copyJobDescriptor.size > 0 ? job->copyJobDescriptor.size : ffxResourceSrc.resourceDescription.width;

        VulkanWrapper().vkCmdCopyBuffer(vkCommandBuffer, vkResourceSrc, vkResourceDst, 1, &bufferCopy);
    }
    else if (ffxResourceSrc.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER && ffxResourceDst.resourceDescription.type != FFX_RESOURCE_TYPE_BUFFER)
    {
        VkBuffer vkResourceSrc = ffxResourceSrc.bufferResource;
        VkImage  vkResourceDst = ffxResourceDst.imageResource;

        VkImageSubresourceLayers subresourceLayers = {};

        subresourceLayers.aspectMask     = getImageAspect(ffxResourceDst.resourceDescription.usage);
        subresourceLayers.baseArrayLayer = 0;
        subresourceLayers.layerCount     = 1;
        subresourceLayers.mipLevel       = 0;

        VkOffset3D offset = {};

        offset.x = 0;
        offset.y = 0;
        offset.z = 0;

        VkExtent3D extent = {};

        extent.width  = ffxResourceDst.resourceDescription.width;
        extent.height = ffxResourceDst.resourceDescription.height;
        extent.depth  = ffxResourceDst.resourceDescription.depth;

                                                 
        VkBufferImageCopy bufferImageCopy = {};

        bufferImageCopy.bufferOffset      = 0;
        bufferImageCopy.bufferRowLength   = 0;
        bufferImageCopy.bufferImageHeight = 0;
        bufferImageCopy.imageSubresource  = subresourceLayers;
        bufferImageCopy.imageOffset       = offset;
        bufferImageCopy.imageExtent       = extent;

        VulkanWrapper().vkCmdCopyBufferToImage(vkCommandBuffer, vkResourceSrc, vkResourceDst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &bufferImageCopy);
    }
    else
    {
#define FFX_MAX_IMAGE_COPY_MIPS 14                               
        VkImageCopy imageCopies[FFX_MAX_IMAGE_COPY_MIPS];
        VkImage     vkResourceSrc = ffxResourceSrc.imageResource;
        VkImage     vkResourceDst = ffxResourceDst.imageResource;

        uint32_t numMipsToCopy = FFX_MINIMUM(ffxResourceSrc.resourceDescription.mipCount, ffxResourceDst.resourceDescription.mipCount);

        for (uint32_t mip = 0; mip < numMipsToCopy; mip++)
        {
            VkImageSubresourceLayers srcSubresourceLayers = {};

            srcSubresourceLayers.aspectMask     = getImageAspect(ffxResourceSrc.resourceDescription.usage);
            srcSubresourceLayers.baseArrayLayer = 0;
            srcSubresourceLayers.layerCount     = 1;
            srcSubresourceLayers.mipLevel       = mip;

            VkImageSubresourceLayers dstSubresourceLayers = {};

            dstSubresourceLayers.aspectMask     = getImageAspect(ffxResourceDst.resourceDescription.usage);
            dstSubresourceLayers.baseArrayLayer = 0;
            dstSubresourceLayers.layerCount     = 1;
            dstSubresourceLayers.mipLevel       = mip;

            VkOffset3D offset = {};

            offset.x = 0;
            offset.y = 0;
            offset.z = 0;

            VkExtent3D extent = {};

            switch (job->copyJobDescriptor.copyMode)
            {
            case FFX_GPU_COPY_SRC_EXTENT:
                extent.width  = ffxResourceSrc.resourceDescription.width / (mip + 1);
                extent.height = ffxResourceSrc.resourceDescription.height / (mip + 1);
                extent.depth  = ffxResourceSrc.resourceDescription.depth / (mip + 1);
                break;
            case FFX_GPU_COPY_DST_EXTENT:
                extent.width  = ffxResourceDst.resourceDescription.width / (mip + 1);
                extent.height = ffxResourceDst.resourceDescription.height / (mip + 1);
                extent.depth  = ffxResourceDst.resourceDescription.depth / (mip + 1);
                break;
            case FFX_GPU_COPY_MIN_EXTENT:
                extent.width  = FFX_MINIMUM(ffxResourceSrc.resourceDescription.width, ffxResourceDst.resourceDescription.width) / (mip + 1);
                extent.height = FFX_MINIMUM(ffxResourceSrc.resourceDescription.height, ffxResourceDst.resourceDescription.height) / (mip + 1);
                extent.depth  = FFX_MINIMUM(ffxResourceSrc.resourceDescription.depth, ffxResourceDst.resourceDescription.depth) / (mip + 1);
                break;
            default:
                FFX_ASSERT_MESSAGE(false, "Unsupported copy mode in vulkan backend of FFX SDK.");
                break;
            }

            VkImageCopy& copyRegion = imageCopies[mip];

            copyRegion.srcSubresource = srcSubresourceLayers;
            copyRegion.srcOffset      = offset;
            copyRegion.dstSubresource = dstSubresourceLayers;
            copyRegion.dstOffset      = offset;
            copyRegion.extent         = extent;
        }

        VulkanWrapper().vkCmdCopyImage(vkCommandBuffer,
                                       vkResourceSrc,
                                       VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                                       vkResourceDst,
                                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                                       numMipsToCopy,
                                       imageCopies);
    }

    return FFX_OK;
}

static FfxErrorCode executeGpuJobBarrier(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    addBarrier(backendContext, &job->barrierDescriptor.resource, job->barrierDescriptor.newState);
    flushBarriers(backendContext, vkCommandBuffer);

    return FFX_OK;
}

static FfxErrorCode executeGpuJobTimestamp(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    return FFX_OK;
}

static FfxErrorCode executeGpuJobClearFloat(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    nss_trace("  clear float target=%u", (unsigned) job->clearJobDescriptor.target.internalIndex);
    uint32_t idx = job->clearJobDescriptor.target.internalIndex;

    BackendContext_VK::Resource ffxResource = backendContext->pResources[idx];

    if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        addBarrier(backendContext, &job->clearJobDescriptor.target, FFX_RESOURCE_STATE_COPY_DEST);
        flushBarriers(backendContext, vkCommandBuffer);

        VkBuffer vkResource = ffxResource.bufferResource;

        VulkanWrapper().vkCmdFillBuffer(vkCommandBuffer, vkResource, 0, VK_WHOLE_SIZE, (uint32_t)job->clearJobDescriptor.color[0]);
    }
    else if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR &&
             (ffxResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) != FFX_RESOURCE_FLAGS_IMAGE_ALIASED)
    {
                                                                                                         
    }
    else
    {
        addBarrier(backendContext, &job->clearJobDescriptor.target, FFX_RESOURCE_STATE_COPY_DEST);
        flushBarriers(backendContext, vkCommandBuffer);

        VkImage vkResource = ffxResource.imageResource;

        VkClearColorValue clearColorValue = {};

        clearColorValue.float32[0] = job->clearJobDescriptor.color[0];
        clearColorValue.float32[1] = job->clearJobDescriptor.color[1];
        clearColorValue.float32[2] = job->clearJobDescriptor.color[2];
        clearColorValue.float32[3] = job->clearJobDescriptor.color[3];

        VkImageSubresourceRange range;
        range.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
        range.baseMipLevel   = 0;
        range.levelCount     = ffxResource.resourceDescription.mipCount;
        range.baseArrayLayer = 0;
        range.layerCount     = VK_REMAINING_ARRAY_LAYERS;

                                                        
        if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR)
        {
            vkResource                            = ffxResource.aliasedTensorImageResource;
            VkClearColorValue clearColorValueSint = {};
            clearColorValueSint.int32[0]          = static_cast<int32_t>(job->clearJobDescriptor.color[0] * 255 - 128);
            clearColorValueSint.int32[1]          = static_cast<int32_t>(job->clearJobDescriptor.color[1] * 255 - 128);
            clearColorValueSint.int32[2]          = static_cast<int32_t>(job->clearJobDescriptor.color[2] * 255 - 128);
            clearColorValueSint.int32[3]          = static_cast<int32_t>(job->clearJobDescriptor.color[3] * 255 - 128);
            clearColorValue                       = clearColorValueSint;
        }
        VulkanWrapper().vkCmdClearColorImage(vkCommandBuffer, vkResource, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColorValue, 1, &range);
    }

    return FFX_OK;
}

static FfxErrorCode executeGpuJobClearUint(BackendContext_VK* backendContext, FfxGpuJobDescription* job, VkCommandBuffer vkCommandBuffer)
{
    nss_trace("  clear uint target=%u", (unsigned) job->clearUintJobDescriptor.target.internalIndex);
    uint32_t idx = job->clearUintJobDescriptor.target.internalIndex;

    BackendContext_VK::Resource ffxResource = backendContext->pResources[idx];

    if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_BUFFER)
    {
        addBarrier(backendContext, &job->clearUintJobDescriptor.target, FFX_RESOURCE_STATE_COPY_DEST);
        flushBarriers(backendContext, vkCommandBuffer);

        VkBuffer vkResource = ffxResource.bufferResource;

        VulkanWrapper().vkCmdFillBuffer(vkCommandBuffer, vkResource, 0, VK_WHOLE_SIZE, job->clearUintJobDescriptor.color[0]);
    }
    else if (ffxResource.resourceDescription.type == FFX_RESOURCE_TYPE_TENSOR &&
             (ffxResource.resourceDescription.flags & FFX_RESOURCE_FLAGS_IMAGE_ALIASED) != FFX_RESOURCE_FLAGS_IMAGE_ALIASED)
    {
                                                                                                         
    }
    else
    {
        addBarrier(backendContext, &job->clearUintJobDescriptor.target, FFX_RESOURCE_STATE_COPY_DEST);
        flushBarriers(backendContext, vkCommandBuffer);

        VkImage vkResource = ffxResource.imageResource;

        VkClearColorValue clearColorValue = {};

        clearColorValue.uint32[0] = job->clearUintJobDescriptor.color[0];
        clearColorValue.uint32[1] = job->clearUintJobDescriptor.color[1];
        clearColorValue.uint32[2] = job->clearUintJobDescriptor.color[2];
        clearColorValue.uint32[3] = job->clearUintJobDescriptor.color[3];

        VkImageSubresourceRange range;
        range.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
        range.baseMipLevel   = 0;
        range.levelCount     = ffxResource.resourceDescription.mipCount;
        range.baseArrayLayer = 0;
        range.layerCount     = VK_REMAINING_ARRAY_LAYERS;
        VulkanWrapper().vkCmdClearColorImage(vkCommandBuffer, vkResource, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColorValue, 1, &range);
    }

    return FFX_OK;
}

                                                                                                                    
                                                                                                           
                                                                                                                        
namespace
{
struct NfruPassProfile
{
    VkQueryPool              pool = VK_NULL_HANDLE;
    uint32_t                 pending = 0;                                                  
    std::vector<std::string> names;                                               
    std::map<std::string, std::pair<double, uint32_t>> sum;
    uint32_t                 submissions = 0;
};
std::map<FfxUInt32, NfruPassProfile> g_nfruPassProfiles;
bool nfruPassProfileEnabled()
{
    static const bool on = getenv("NFRU_PASS_PROFILE") && atoi(getenv("NFRU_PASS_PROFILE")) != 0;
    return on;
}
std::string nfruJobName(const FfxGpuJobDescription* job)
{
    switch (job->jobType)
    {
    case FFX_GPU_JOB_COMPUTE: return job->computeJobDescriptor.pipeline.name[0] ? job->computeJobDescriptor.pipeline.name : "compute";
    case FFX_GPU_JOB_FRAGMENT: return job->fragmentJobDescriptor.pipeline.name[0] ? job->fragmentJobDescriptor.pipeline.name : "fragment";
    case FFX_GPU_JOB_DATA_GRAPH: return "network";
    case FFX_GPU_JOB_COPY: return "copy";
    case FFX_GPU_JOB_CLEAR_FLOAT: return "clear_float";
    case FFX_GPU_JOB_CLEAR_UINT: return "clear_uint";
    case FFX_GPU_JOB_BARRIER: return "barrier";
    default: return "other";
    }
}
void nfruPassProfileCollect(BackendContext_VK* ctx, NfruPassProfile& p, FfxUInt32 effectContextId)
{
    if (!p.pending) return;
    std::vector<uint64_t> ts(p.pending);
    if (vkGetQueryPoolResults(ctx->device, p.pool, 0, p.pending, ts.size() * sizeof(uint64_t), ts.data(), sizeof(uint64_t),
                              VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT) == VK_SUCCESS)
    {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(ctx->physicalDevice, &props);
        for (size_t j = 0; j + 1 < ts.size() && j / 2 < p.names.size(); j += 2)
        {
            auto& s = p.sum[p.names[j / 2]];
            s.first += double(ts[j + 1] - ts[j]) * props.limits.timestampPeriod * 1e-6;
            ++s.second;
        }
    }
    if (++p.submissions % 60 == 0)
        if (FILE* f = fopen("nfru_pass_profile.csv", "a"))
        {
            for (auto& [name, s] : p.sum)
                fprintf(f, "%u,%u,%s,%.5f,%u\n", effectContextId, p.submissions, name.c_str(), s.first / s.second, s.second);
            fclose(f);
            p.sum.clear();
        }
    p.pending = 0;
    p.names.clear();
}
}              

FfxErrorCode ExecuteGpuJobsVK(FfxInterface* backendInterface, FfxCommandList commandList, FfxUInt32 effectContextId)
{
    FFX_ASSERT(nullptr != backendInterface);
    BackendContext_VK* backendContext = (BackendContext_VK*)backendInterface->scratchBuffer;

    FFX_ASSERT(nullptr != commandList);
    VkCommandBuffer vkCommandBuffer = reinterpret_cast<VkCommandBuffer>(commandList);

    FfxErrorCode errorCode = FFX_OK;

    NfruPassProfile* passProfile = nullptr;
    if (nfruPassProfileEnabled())
    {
        passProfile = &g_nfruPassProfiles[effectContextId];
        if (passProfile->pool == VK_NULL_HANDLE)
        {
            VkQueryPoolCreateInfo qi = {VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
            qi.queryType  = VK_QUERY_TYPE_TIMESTAMP;
            qi.queryCount = 512;
            if (vkCreateQueryPool(backendContext->device, &qi, nullptr, &passProfile->pool) != VK_SUCCESS) passProfile = nullptr;
        }
        if (passProfile)
        {
            nfruPassProfileCollect(backendContext, *passProfile, effectContextId);
            const uint32_t used = std::min<uint32_t>(backendContext->gpuJobCount * 2, 512);
            if (used) vkCmdResetQueryPool(vkCommandBuffer, passProfile->pool, 0, used);
        }
    }

                             
    for (uint32_t i = 0; i < backendContext->gpuJobCount; ++i)
    {
        FfxGpuJobDescription* gpuJob = &backendContext->pGpuJobs[i];
        nss_trace("job %u/%u type=%d", i, backendContext->gpuJobCount, (int) gpuJob->jobType);
        const bool timeJob = passProfile && i < 256;
        if (timeJob)
        {
            vkCmdWriteTimestamp(vkCommandBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, passProfile->pool, i * 2);
            passProfile->names.push_back(nfruJobName(gpuJob));
        }

                                                               
#ifdef FFX_DEBUG
        if (gpuJob->jobLabel[0])
        {
            beginMarkerVK(backendContext, vkCommandBuffer, gpuJob->jobLabel);
        }
#endif

        switch (gpuJob->jobType)
        {
        case FFX_GPU_JOB_CLEAR_FLOAT:
        {
            errorCode = executeGpuJobClearFloat(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        case FFX_GPU_JOB_COPY:
        {
            errorCode = executeGpuJobCopy(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        case FFX_GPU_JOB_COMPUTE:
        {
            errorCode = executeGpuJobCompute(backendContext, gpuJob, vkCommandBuffer, effectContextId);
            break;
        }
        case FFX_GPU_JOB_BARRIER:
        {
            errorCode = executeGpuJobBarrier(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        case FFX_GPU_JOB_FRAGMENT:
        {
            errorCode = executeGpuJobFragment(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        case FFX_GPU_JOB_DATA_GRAPH:
        {
            errorCode = executeGpuJobDataGraph(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        case FFX_GPU_JOB_CLEAR_UINT:
        {
            errorCode = executeGpuJobClearUint(backendContext, gpuJob, vkCommandBuffer);
            break;
        }
        default:;
        }

#ifdef FFX_DEBUG
        if (gpuJob->jobLabel[0])
        {
            endMarkerVK(backendContext, vkCommandBuffer);
        }
#endif
        if (timeJob)
        {
            vkCmdWriteTimestamp(vkCommandBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, passProfile->pool, i * 2 + 1);
            passProfile->pending = i * 2 + 2;
        }
    }

                                                   
    FFX_RETURN_ON_ERROR(errorCode == FFX_OK, FFX_ERROR_BACKEND_API_ERROR);

    backendContext->gpuJobCount = 0;

    return FFX_OK;
}

void RegisterConstantBufferAllocatorVK(FfxInterface*, FfxConstantBufferAllocator fpConstantAllocator)
{
    s_fpConstantAllocator = fpConstantAllocator;
}

FfxCommandQueue ffxGetCommandQueueVK(VkQueue commandQueue)
{
    FFX_ASSERT(commandQueue != VK_NULL_HANDLE);
    return reinterpret_cast<FfxCommandQueue>(commandQueue);
}

FfxSwapchain ffxGetSwapchainVK(VkSwapchainKHR swapchain)
{
    FFX_ASSERT(swapchain != VK_NULL_HANDLE);
    return reinterpret_cast<FfxSwapchain>(swapchain);
}

VkSwapchainKHR ffxGetVKSwapchain(FfxSwapchain ffxSwapchain)
{
    return reinterpret_cast<VkSwapchainKHR>(ffxSwapchain);
}
