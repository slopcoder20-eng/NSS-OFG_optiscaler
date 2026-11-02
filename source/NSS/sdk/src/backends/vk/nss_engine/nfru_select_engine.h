#pragma once
#include <vulkan/vulkan.h>
#include <algorithm>
#include <cstring>
#include <vector>
#include "nfru_select_weights.h"
#include "nfru_select_spv.h"

                                                                                                                   
                                                                                                                          
                                                                                                                     
                                                                                                             
struct NfruSelect {
    struct Buf { VkBuffer b{}; VkDeviceMemory mem{}; VkDeviceSize bytes{}; };
    struct PC { uint32_t w, h, iw, ih, c1, c2, iw2, ih2, cout, stride, relu, wofs, fw, fh; };
    VkDevice dev{}; VkPhysicalDevice pd{};
    uint32_t fw{}, fh{}, w4{}, h4{}, w8{}, h8{};
    Buf feat{}, x{}, a{}, h0{}, h1{}, lg{}, weights{};
    VkDescriptorSetLayout nnDSL{}, ioDSL{}; VkPipelineLayout nnPL{}, ioPL{};
    VkPipeline featPipe{}, convPipe[7]{}, blendPipe{}; VkDescriptorPool pool{};
    VkDescriptorSet nnSets[7]{}; std::vector<VkDescriptorSet> ioSets;
    uint64_t calls = 0;
    ~NfruSelect() { destroy(); }

    bool buffer(Buf& b, VkDeviceSize bytes, bool upload = false) {
        b.bytes = bytes; VkBufferCreateInfo ci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; ci.size = bytes; ci.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
        if (vkCreateBuffer(dev, &ci, nullptr, &b.b) != VK_SUCCESS) return false;
        VkMemoryRequirements req; vkGetBufferMemoryRequirements(dev, b.b, &req); VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd, &mp);
        const VkMemoryPropertyFlags flags = upload ? (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) : VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        uint32_t type = UINT32_MAX;
                                                                                                                                      
        if (upload) for (uint32_t i = 0; i < mp.memoryTypeCount && type == UINT32_MAX; i++)
            if ((req.memoryTypeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & (flags | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) == (flags | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) type = i;
        for (uint32_t i = 0; i < mp.memoryTypeCount && type == UINT32_MAX; i++) if ((req.memoryTypeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & flags) == flags) type = i;
        if (type == UINT32_MAX) return false;
        VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; ai.allocationSize = req.size; ai.memoryTypeIndex = type;
        return vkAllocateMemory(dev, &ai, nullptr, &b.mem) == VK_SUCCESS && vkBindBufferMemory(dev, b.b, b.mem, 0) == VK_SUCCESS;
    }
    bool pipeline(VkPipeline& dst, VkPipelineLayout pl, const uint32_t* spv, size_t bytes, const uint32_t* spec = nullptr) {
        VkShaderModuleCreateInfo smc{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smc.codeSize = bytes; smc.pCode = spv; VkShaderModule sm{};
        if (vkCreateShaderModule(dev, &smc, nullptr, &sm) != VK_SUCCESS) return false;
        VkComputePipelineCreateInfo pc{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; pc.layout = pl;
        pc.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; pc.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT; pc.stage.module = sm; pc.stage.pName = "main";
        VkSpecializationMapEntry entries[5]; for (uint32_t i = 0; i < 5; i++) entries[i] = {i, i * 4, 4};
        VkSpecializationInfo si{5, entries, 20, spec}; if (spec) pc.stage.pSpecializationInfo = &si;
        const VkResult r = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pc, nullptr, &dst); vkDestroyShaderModule(dev, sm, nullptr); return r == VK_SUCCESS;
    }
    bool init(VkDevice d, VkPhysicalDevice p, uint32_t displayW, uint32_t displayH, uint32_t ring) {
        dev = d; pd = p; fw = displayW; fh = displayH; w4 = fw / 4; h4 = fh / 4;                       
        if (w4 < 2 || h4 < 2) return false;
        w8 = (w4 - 1) / 2 + 1; h8 = (h4 - 1) / 2 + 1;                                                         
        const VkDeviceSize q = VkDeviceSize(w4) * h4 * 4, e = VkDeviceSize(w8) * h8 * 4;
        if (!buffer(feat, q * 29) || !buffer(x, q * 24) || !buffer(a, q * 24) || !buffer(h0, e * 32) || !buffer(h1, e * 32) || !buffer(lg, q * 6) ||
            !buffer(weights, sizeof(g_nfru_select_weights), true)) return false;
        void* ptr = nullptr; if (vkMapMemory(dev, weights.mem, 0, weights.bytes, 0, &ptr) != VK_SUCCESS) return false;
        memcpy(ptr, g_nfru_select_weights, sizeof(g_nfru_select_weights)); vkUnmapMemory(dev, weights.mem);

        VkDescriptorSetLayoutBinding nb[4]{}; for (uint32_t i = 0; i < 4; i++) nb[i] = {i, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        VkDescriptorSetLayoutCreateInfo dl{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dl.bindingCount = 4; dl.pBindings = nb;
        nb[3].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;                                
        if (vkCreateDescriptorSetLayout(dev, &dl, nullptr, &nnDSL) != VK_SUCCESS) return false;
        nb[3].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        nb[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;                                                            
        if (vkCreateDescriptorSetLayout(dev, &dl, nullptr, &ioDSL) != VK_SUCCESS) return false;
        VkPushConstantRange range{VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PC)};
        VkPipelineLayoutCreateInfo pl{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; pl.setLayoutCount = 1; pl.pSetLayouts = &nnDSL; pl.pushConstantRangeCount = 1; pl.pPushConstantRanges = &range;
        if (vkCreatePipelineLayout(dev, &pl, nullptr, &nnPL) != VK_SUCCESS) return false;
        pl.pSetLayouts = &ioDSL; if (vkCreatePipelineLayout(dev, &pl, nullptr, &ioPL) != VK_SUCCESS) return false;
        for (uint32_t i = 0; i < 7; i++) {                                    
            const NfruSelectLayer& l = g_nfru_select_layers[i];
            const uint32_t spec[5] = {l.cout, i == 5 ? 24u : l.cin, i == 5 ? l.cin - 24u : 0u, l.stride, l.relu};
            if (!pipeline(convPipe[i], nnPL, g_spv_nfru_select_conv, sizeof(g_spv_nfru_select_conv), spec)) return false;
        }
        if (!pipeline(featPipe, ioPL, g_spv_nfru_select_feat, sizeof(g_spv_nfru_select_feat)) ||
            !pipeline(blendPipe, ioPL, g_spv_nfru_select_blend, sizeof(g_spv_nfru_select_blend))) return false;

        VkDescriptorPoolSize sizes[] = {{VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 21 + ring * 3}, {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, ring}, {VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 7}};
        VkDescriptorPoolCreateInfo dp{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dp.maxSets = 7 + ring; dp.poolSizeCount = 3; dp.pPoolSizes = sizes;
        if (vkCreateDescriptorPool(dev, &dp, nullptr, &pool) != VK_SUCCESS) return false;
        std::vector<VkDescriptorSetLayout> ls(7, nnDSL); VkDescriptorSetAllocateInfo da{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        da.descriptorPool = pool; da.descriptorSetCount = 7; da.pSetLayouts = ls.data(); if (vkAllocateDescriptorSets(dev, &da, nnSets) != VK_SUCCESS) return false;
        ioSets.resize(ring); ls.assign(ring, ioDSL); da.descriptorSetCount = ring; da.pSetLayouts = ls.data();
        if (vkAllocateDescriptorSets(dev, &da, ioSets.data()) != VK_SUCCESS) return false;
                                                                                                                    
        const Buf* io[7][3] = {{&feat, &feat, &x}, {&x, &x, &a}, {&a, &a, &h0}, {&h0, &h0, &h1}, {&h1, &h1, &h0}, {&a, &h0, &x}, {&x, &x, &lg}};
        for (uint32_t i = 0; i < 7; i++) {
            const Buf* refs[4] = {io[i][0], io[i][1], io[i][2], &weights}; VkDescriptorBufferInfo infos[4]; VkWriteDescriptorSet wr[4]{};
            for (uint32_t j = 0; j < 4; j++) {
                infos[j] = {refs[j]->b, 0, VK_WHOLE_SIZE}; wr[j] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[j].dstSet = nnSets[i]; wr[j].dstBinding = j;
                wr[j].descriptorType = j == 3 ? VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER : VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
                if (j == 3) {                                                                             
                    const VkDeviceSize start = VkDeviceSize(g_nfru_select_layers[i].offset) * 4;
                    infos[j] = {weights.b, start, std::min<VkDeviceSize>(65536, weights.bytes - start)};
                } wr[j].descriptorCount = 1; wr[j].pBufferInfo = &infos[j];
            }
            vkUpdateDescriptorSets(dev, 4, wr, 0, nullptr);
        }
        nss_trace("NFRU select: initialized %ux%u (logits %ux%u, %u params)", fw, fh, w4, h4, unsigned(sizeof(g_nfru_select_weights) / 4));
        return true;
    }
    static void barrier(VkCommandBuffer cb) {
        VkMemoryBarrier b{VK_STRUCTURE_TYPE_MEMORY_BARRIER}; b.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT; b.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &b, 0, nullptr, 0, nullptr);
    }
                                                                                                                       
    bool record(VkCommandBuffer cb, uint32_t ringIndex, VkBuffer cand, const VkDescriptorImageInfo& output) {
        VkDescriptorSet set = ioSets[ringIndex % ioSets.size()];
        VkDescriptorBufferInfo bufs[3] = {{cand, 0, VK_WHOLE_SIZE}, {feat.b, 0, VK_WHOLE_SIZE}, {lg.b, 0, VK_WHOLE_SIZE}};
        VkWriteDescriptorSet wr[4]{};
        for (uint32_t j = 0; j < 4; j++) { wr[j] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[j].dstSet = set; wr[j].dstBinding = j; wr[j].descriptorCount = 1; }
        wr[0].descriptorType = wr[2].descriptorType = wr[3].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        wr[0].pBufferInfo = &bufs[0]; wr[2].pBufferInfo = &bufs[1]; wr[3].pBufferInfo = &bufs[2];
        wr[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE; wr[1].pImageInfo = &output;
        vkUpdateDescriptorSets(dev, 4, wr, 0, nullptr);

        barrier(cb);                                                     
                                                                                                                
        static const uint32_t stages = getenv("NFRU_SELECT_STAGES") ? uint32_t(strtoul(getenv("NFRU_SELECT_STAGES"), nullptr, 0)) : 0x7fffu;
        PC p{w4, h4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, fw, fh};
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, featPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, ioPL, 0, 1, &set, 0, nullptr);
        vkCmdPushConstants(cb, ioPL, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(p), &p); if (stages & 1) vkCmdDispatch(cb, (w4 + 7) / 8, (h4 + 7) / 8, 1); barrier(cb);

        for (uint32_t i = 0; i < 7; i++) {
            vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, convPipe[i]);
            const NfruSelectLayer& l = g_nfru_select_layers[i];
            const bool half = i >= 2 && i <= 4, concat = i == 5;
            const uint32_t ow = half ? w8 : w4, oh = half ? h8 : h4, iw = (i >= 3 && i <= 4) ? w8 : w4, ih = (i >= 3 && i <= 4) ? h8 : h4;
            p = {ow, oh, iw, ih, concat ? 24u : l.cin, concat ? l.cin - 24u : 0u, w8, h8, l.cout, l.stride, l.relu, l.offset, fw, fh};
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, nnPL, 0, 1, &nnSets[i], 0, nullptr);
            vkCmdPushConstants(cb, nnPL, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(p), &p); if ((stages & 2) && (stages & (0x100u << i))) vkCmdDispatch(cb, (ow + 7) / 8, (oh + 7) / 8, 1); barrier(cb);
        }

        p = {w4, h4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, fw, fh};
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, blendPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, ioPL, 0, 1, &set, 0, nullptr);
        vkCmdPushConstants(cb, ioPL, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(p), &p); if (stages & 4) vkCmdDispatch(cb, (fw + 7) / 8, (fh + 7) / 8, 1); barrier(cb);
        if (calls++ < 4) nss_trace("NFRU select: dispatch #%llu", static_cast<unsigned long long>(calls));
        return true;
    }
    void destroy() {
        if (!dev) return;
        for (auto p : {featPipe, blendPipe}) if (p) vkDestroyPipeline(dev, p, nullptr);
        for (auto p : convPipe) if (p) vkDestroyPipeline(dev, p, nullptr);
        if (pool) vkDestroyDescriptorPool(dev, pool, nullptr);
        for (auto p : {nnPL, ioPL}) if (p) vkDestroyPipelineLayout(dev, p, nullptr);
        for (auto p : {nnDSL, ioDSL}) if (p) vkDestroyDescriptorSetLayout(dev, p, nullptr);
        for (auto b : {feat, x, a, h0, h1, lg, weights}) { if (b.b) vkDestroyBuffer(dev, b.b, nullptr); if (b.mem) vkFreeMemory(dev, b.mem, nullptr); }
        dev = VK_NULL_HANDLE;
    }
};
