/*
 * SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: Apache-2.0
 *
 */

/*******************************************************************************
 * Includes
 *******************************************************************************/

#include "compute_pipeline_common.hpp"

#include <stdexcept>
#include <string>

namespace mlsdk::el::compute::common {

std::vector<VkSpecializationMapEntry> makeSpecializationMapEntries(const uint32_t entryCount) {
    std::vector<VkSpecializationMapEntry> entries;
    entries.reserve(entryCount);

    for (uint32_t i = 0; i < entryCount; ++i) {
        entries.push_back({
            i,                                                        
            static_cast<uint32_t>(i * sizeof(uint32_t)),          
            sizeof(uint32_t),                                   
        });
    }

    return entries;
}

VkShaderModule createShaderModule(const std::shared_ptr<VULKAN_HPP_NAMESPACE::detail::DispatchLoaderDynamic> &loader,
                                  const VkDevice device, const SpirvBinary &code,
                                  const VkAllocationCallbacks *allocator) {
    const VkShaderModuleCreateInfo shaderModuleCreateInfo = {
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,                  
        nullptr,                                                      
        0,                                                             
        static_cast<uint32_t>(code.size() * sizeof(uint32_t)),             
        code.data(),                                                  
    };

    VkShaderModule shaderModule;
    if (loader->vkCreateShaderModule(device, &shaderModuleCreateInfo, allocator, &shaderModule) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create shader module");
    }

    return shaderModule;
}

namespace {

VkPipeline createComputePipelineWithSpecializationInfo(
    const std::shared_ptr<VULKAN_HPP_NAMESPACE::detail::DispatchLoaderDynamic> &loader, const VkDevice device,
    const VkPipelineCache pipelineCache, const VkShaderModule shaderModule, const VkPipelineLayout pipelineLayout,
    const VkSpecializationInfo *specializationInfo, const VkAllocationCallbacks *allocator) {
    const VkPipelineShaderStageCreateInfo pipelineShaderCreateInfo = {
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,        
        nullptr,                                                    
        0,                                                           
        VK_SHADER_STAGE_COMPUTE_BIT,                                           
        shaderModule,                                                        
        "main",                                                     
        specializationInfo,                                                        
    };

    const VkComputePipelineCreateInfo computePipelineCreateInfo = {
        VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,        
        nullptr,                                               
        0,                                                      
        pipelineShaderCreateInfo,                                     
        pipelineLayout,                                                   
        nullptr,                                                               
        0,                                                                    
    };

    VkPipeline pipeline;
    if (loader->vkCreateComputePipelines(device, pipelineCache, 1, &computePipelineCreateInfo, allocator, &pipeline) !=
        VK_SUCCESS) {
        throw std::runtime_error("Failed to create compute pipelines");
    }

    return pipeline;
}

}             

VkPipeline createComputePipeline(const std::shared_ptr<VULKAN_HPP_NAMESPACE::detail::DispatchLoaderDynamic> &loader,
                                 const VkDevice device, const VkPipelineCache pipelineCache,
                                 const VkShaderModule shaderModule, const VkPipelineLayout pipelineLayout,
                                 const SpecializationConstantsView *specializationConstants,
                                 const VkAllocationCallbacks *allocator) {
    if (specializationConstants == nullptr || specializationConstants->entryCount == 0) {
        return createComputePipelineWithSpecializationInfo(loader, device, pipelineCache, shaderModule, pipelineLayout,
                                                           nullptr, allocator);
    }

    const auto specEntries = makeSpecializationMapEntries(specializationConstants->entryCount);
    const VkSpecializationInfo specializationInfo = {
        static_cast<uint32_t>(specEntries.size()),                 
        specEntries.data(),                                      
        specializationConstants->sizeBytes,                   
        specializationConstants->data,                     
    };
    return createComputePipelineWithSpecializationInfo(loader, device, pipelineCache, shaderModule, pipelineLayout,
                                                       &specializationInfo, allocator);
}

}                                        
