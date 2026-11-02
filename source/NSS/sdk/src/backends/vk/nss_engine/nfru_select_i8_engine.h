#pragma once
#include <vulkan/vulkan.h>
#include <cstring>
#include <vector>
#include "nfru_select_int8.h"
#include "nfru_select_spv.h"
#include "shaders_spv.h"
#include "coopmat_shape.h"
#ifndef NFRU_SELECT_FLOAT_LOGITS
#define NFRU_SELECT_FLOAT_LOGITS 0
#endif

                                                                                                                          
                                                                                                                 
                                                                                                                         
                                                                                                                          
                                                                                   
struct NfruSelectI8 {
    struct Buf { VkBuffer b{}; VkDeviceMemory mem{}; VkDeviceSize bytes{}; };
    struct ConvPC { uint32_t in_w, in_h, out_w, out_h, in_c, out_c; int32_t pad_t, pad_l, stride_y, stride_x; uint32_t kh, kw; int32_t out_zp, mult, shift; uint32_t upsample; };
    struct IoPC { uint32_t w, h, iw, ih, c1, c2, iw2, ih2, cout, stride, relu, wofs, fw, fh; };
    VkDevice dev{}; VkPhysicalDevice pd{};
    uint32_t fw{}, fh{}, lw4{}, lh4{}, w4{}, h4{}, w8{}, h8{};                                                                    
                                                                      
    Buf t[9]{}, blob{}, blobCoop{}, logitW{};                                                         
    bool coop = false; uint32_t coopLocal = 32; NssCoopShape shape{};
    VkDescriptorSetLayout nnDSL{}, ioDSL{}; VkPipelineLayout pl{}, ioPL{};
    VkPipeline dp4a{}, coopSmall{}, coopGeneric{}, featPipe{}, concatPipe{}, blendPipe{}, logitPipe{}; VkDescriptorPool pool{};
    VkDescriptorSet nnSets[8]{}; std::vector<VkDescriptorSet> ioSets;
    std::vector<VkBuffer> lastCand;
    std::vector<VkImageView> lastOutput;
    uint64_t calls = 0;
    VkQueryPool qpool[4]{}; bool qactive[4]{};
    ~NfruSelectI8() { destroy(); }

    bool buffer(Buf& b, VkDeviceSize bytes, bool upload = false) {
        b.bytes = bytes; VkBufferCreateInfo ci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; ci.size = bytes; ci.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
        if (vkCreateBuffer(dev, &ci, nullptr, &b.b) != VK_SUCCESS) return false;
        VkMemoryRequirements req; vkGetBufferMemoryRequirements(dev, b.b, &req); VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd, &mp);
        const VkMemoryPropertyFlags host = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
        uint32_t type = UINT32_MAX;
                                                                                                      
        for (VkMemoryPropertyFlags want : {upload ? (host | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) : VkMemoryPropertyFlags(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT), upload ? host : VkMemoryPropertyFlags(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)})
            for (uint32_t i = 0; i < mp.memoryTypeCount && type == UINT32_MAX; i++)
                if ((req.memoryTypeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & want) == want) type = i;
        if (type == UINT32_MAX) return false;
        VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; ai.allocationSize = req.size; ai.memoryTypeIndex = type;
        return vkAllocateMemory(dev, &ai, nullptr, &b.mem) == VK_SUCCESS && vkBindBufferMemory(dev, b.b, b.mem, 0) == VK_SUCCESS;
    }
    bool upload(Buf& b, const uint8_t* data, size_t bytes) {
        if (!buffer(b, bytes + 256, true)) return false;
        void* p = nullptr; if (vkMapMemory(dev, b.mem, 0, bytes, 0, &p) != VK_SUCCESS) return false;
        memcpy(p, data, bytes); vkUnmapMemory(dev, b.mem); return true;
    }
    bool pipeline(VkPipeline& dst, VkPipelineLayout layout, const uint32_t* spv, size_t bytes, const VkSpecializationInfo* spec = nullptr) {
        VkShaderModuleCreateInfo smc{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smc.codeSize = bytes; smc.pCode = spv; VkShaderModule sm{};
        if (vkCreateShaderModule(dev, &smc, nullptr, &sm) != VK_SUCCESS) return false;
        VkComputePipelineCreateInfo pc{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; pc.layout = layout;
        pc.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; pc.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT; pc.stage.module = sm; pc.stage.pName = "main";
        pc.stage.pSpecializationInfo = spec;
        const VkResult r = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pc, nullptr, &dst); vkDestroyShaderModule(dev, sm, nullptr); return r == VK_SUCCESS;
    }
    bool init(VkDevice d, VkPhysicalDevice p, VkInstance inst, uint32_t displayW, uint32_t displayH, uint32_t ring) {
        dev = d; pd = p; fw = displayW; fh = displayH; lw4 = fw / 4; lh4 = fh / 4;
        if (lw4 < 2 || lh4 < 2) return false;
                                                                                                                          
                                                                                             
        w4 = lw4 + (lw4 & 1); h4 = lh4 + (lh4 & 1); w8 = w4 / 2; h8 = h4 / 2;
        const VkDeviceSize q = VkDeviceSize(w4) * h4, e = VkDeviceSize(w8) * h8;
                                                                             
        const VkDeviceSize bytes[9] = {q * 32, q * 32, q * 32, e * 32, e * 32, e * 32, q * 64, q * 32, NFRU_SELECT_FLOAT_LOGITS ? q * 24 : q * 8};
        for (int i = 0; i < 9; i++) if (!buffer(t[i], bytes[i] + 64)) return false;
        if (!upload(blob, g_nfru_select_blob, g_nfru_select_blob_size)) return false;
#if NFRU_SELECT_FLOAT_LOGITS
        if (!upload(logitW, reinterpret_cast<const uint8_t*>(g_nfru_select_logit_wf), sizeof(g_nfru_select_logit_wf))) return false;
#endif

        VkPhysicalDeviceVulkan11Properties p11{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES};
        VkPhysicalDeviceProperties2 p2{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2, &p11}; vkGetPhysicalDeviceProperties2(pd, &p2);
        coop = nssQueryCoopShape(inst, pd, shape) && shape.native16();
        if (const char* f = getenv("NFRU_FORCE_BACKEND")) if (!strcmp(f, "dp4a")) coop = false;
        coopLocal = getenv("NFRU_REQUIRE_WAVE32") ? 32u : p11.subgroupSize;
        if (coop && !upload(blobCoop, g_nfru_select_blob_coop, g_nfru_select_blob_coop_size)) coop = false;

        VkDescriptorSetLayoutBinding nb[4]{}; for (uint32_t i = 0; i < 4; i++) nb[i] = {i, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        VkDescriptorSetLayoutCreateInfo dl{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dl.bindingCount = 4; dl.pBindings = nb;
        if (vkCreateDescriptorSetLayout(dev, &dl, nullptr, &nnDSL) != VK_SUCCESS) return false;
        nb[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;                                                            
        if (vkCreateDescriptorSetLayout(dev, &dl, nullptr, &ioDSL) != VK_SUCCESS) return false;
        VkPushConstantRange range{VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(ConvPC)};
        VkPipelineLayoutCreateInfo pli{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; pli.setLayoutCount = 1; pli.pSetLayouts = &nnDSL; pli.pushConstantRangeCount = 1; pli.pPushConstantRanges = &range;
        if (vkCreatePipelineLayout(dev, &pli, nullptr, &pl) != VK_SUCCESS) return false;
        pli.pSetLayouts = &ioDSL; if (vkCreatePipelineLayout(dev, &pli, nullptr, &ioPL) != VK_SUCCESS) return false;
        if (!pipeline(dp4a, pl, g_spv_nfru_conv, g_spv_nfru_conv_size) ||
            !pipeline(concatPipe, pl, g_spv_nfru_select_concat_i8, sizeof(g_spv_nfru_select_concat_i8)) ||
            !pipeline(featPipe, ioPL, g_spv_nfru_select_feat_i8, sizeof(g_spv_nfru_select_feat_i8)) ||
#if NFRU_SELECT_FLOAT_LOGITS
            !pipeline(logitPipe, pl, g_spv_nfru_select_logits_f32, sizeof(g_spv_nfru_select_logits_f32)) ||
            !pipeline(blendPipe, ioPL, g_spv_nfru_select_blend_f, sizeof(g_spv_nfru_select_blend_f))) return false;
#else
            !pipeline(blendPipe, ioPL, g_spv_nfru_select_blend_i8, sizeof(g_spv_nfru_select_blend_i8))) return false;
#endif
        if (coop) {                                                                                    
            const uint32_t spec[4] = {coopLocal, shape.m, shape.n, shape.k};
            const VkSpecializationMapEntry me[4] = {{0, 0, 4}, {3, 4, 4}, {4, 8, 4}, {5, 12, 4}};
            const VkSpecializationInfo si{4, me, sizeof(spec), spec};
            if (!pipeline(coopSmall, pl, g_spv_nfru_conv_coopmat_small, g_spv_nfru_conv_coopmat_small_size, &si) ||
                !pipeline(coopGeneric, pl, g_spv_nfru_conv_coopmat, g_spv_nfru_conv_coopmat_size, &si)) coop = false;
        }

        VkDescriptorPoolSize sizes[] = {{VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 32 + ring * 3}, {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, ring}};
        VkDescriptorPoolCreateInfo dp{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dp.maxSets = 8 + ring; dp.poolSizeCount = 2; dp.pPoolSizes = sizes;
        if (vkCreateDescriptorPool(dev, &dp, nullptr, &pool) != VK_SUCCESS) return false;
        std::vector<VkDescriptorSetLayout> ls(8, nnDSL); VkDescriptorSetAllocateInfo da{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        da.descriptorPool = pool; da.descriptorSetCount = 8; da.pSetLayouts = ls.data(); if (vkAllocateDescriptorSets(dev, &da, nnSets) != VK_SUCCESS) return false;
        ioSets.resize(ring); lastCand.assign(ring, VK_NULL_HANDLE); lastOutput.assign(ring, VK_NULL_HANDLE); ls.assign(ring, ioDSL); da.descriptorSetCount = ring; da.pSetLayouts = ls.data();
        if (vkAllocateDescriptorSets(dev, &da, ioSets.data()) != VK_SUCCESS) return false;
                                                                               
        const int in[7] = {0, 1, 2, 3, 4, 6, 7}, out[7] = {1, 2, 3, 4, 5, 7, 8};
        for (uint32_t i = 0; i < 8; i++) {
            VkDescriptorBufferInfo infos[4]; uint32_t n = 4;
            if (NFRU_SELECT_FLOAT_LOGITS && i == 6) {                                                                
                infos[0] = {t[7].b, 0, VK_WHOLE_SIZE}; infos[1] = {t[8].b, 0, VK_WHOLE_SIZE};
                infos[2] = {logitW.b ? logitW.b : t[8].b, 0, VK_WHOLE_SIZE}; infos[3] = infos[2];
            } else if (i < 7) {
                const NfruSelectOp& op = g_nfru_select_ops[i];
                const bool c = useCoop(i);
                const VkDeviceSize wbytes = VkDeviceSize(9) * (op.in_c / 16) * ((op.out_c + 15) / 16) * 256;
                infos[0] = {t[in[i]].b, 0, VK_WHOLE_SIZE}; infos[1] = {t[out[i]].b, 0, VK_WHOLE_SIZE};
                infos[2] = {c ? blobCoop.b : blob.b, c ? op.weight_off_coop : op.weight_off, wbytes};
                infos[3] = {blob.b, op.bias_off, VkDeviceSize((op.out_c + 3) / 4) * 16};
            } else {
                infos[0] = {t[2].b, 0, VK_WHOLE_SIZE}; infos[1] = {t[6].b, 0, VK_WHOLE_SIZE}; infos[2] = {t[5].b, 0, VK_WHOLE_SIZE}; infos[3] = {t[5].b, 0, VK_WHOLE_SIZE};
            }
            VkWriteDescriptorSet wr[4]{};
            for (uint32_t j = 0; j < n; j++) {
                wr[j] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[j].dstSet = nnSets[i]; wr[j].dstBinding = j;
                wr[j].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[j].descriptorCount = 1; wr[j].pBufferInfo = &infos[j];
            }
            vkUpdateDescriptorSets(dev, n, wr, 0, nullptr);
        }
        for (int r = 0; r < 4; r++) {
            VkQueryPoolCreateInfo qci{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
            qci.queryType = VK_QUERY_TYPE_TIMESTAMP; qci.queryCount = 16;
            if (vkCreateQueryPool(dev, &qci, nullptr, &qpool[r]) != VK_SUCCESS) qpool[r] = VK_NULL_HANDLE;
            qactive[r] = false;
        }
        nss_trace("NFRU select int8: initialized %ux%u (logits %ux%u) backend=%s subgroup=%u", fw, fh, w4, h4, coop ? "coopmat+dp4a" : "dp4a", coopLocal);
        return true;
    }
                                                                                                             
    bool useCoop(uint32_t i) const { return coop && g_nfru_select_ops[i].out_c >= 16; }
    static void barrier(VkCommandBuffer cb) {
        VkMemoryBarrier b{VK_STRUCTURE_TYPE_MEMORY_BARRIER}; b.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT; b.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &b, 0, nullptr, 0, nullptr);
    }
    void bufBarrier(VkCommandBuffer cb, VkBuffer b) {
        VkBufferMemoryBarrier mb{VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT; mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        mb.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED; mb.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        mb.buffer = b; mb.offset = 0; mb.size = VK_WHOLE_SIZE;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 1, &mb, 0, nullptr);
    }
    void conv(VkCommandBuffer cb, uint32_t i) {
        const NfruSelectOp& op = g_nfru_select_ops[i];
        const bool half = i >= 2 && i <= 4, halfIn = i >= 3 && i <= 4;
        const uint32_t iw = halfIn ? w8 : w4, ih = halfIn ? h8 : h4, ow = half ? w8 : w4, oh = half ? h8 : h4;
        ConvPC pc{iw, ih, ow, oh, op.in_c, op.out_c, 1, 1, int32_t(op.stride), int32_t(op.stride), 3, 3, op.out_zp, op.mult, op.shift, 0};
        const bool c = useCoop(i);
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, c ? (op.stride == 1 ? coopSmall : coopGeneric) : dp4a);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &nnSets[i], 0, nullptr);
        vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
                                                                        
        const uint32_t groupsX = c ? ((ow + 15) / 16) * ((oh + 3) / 4) : (ow * oh + 63) / 64;
        const int out[7] = {1, 2, 3, 4, 5, 7, 8};
        vkCmdDispatch(cb, groupsX, ((op.out_c + 15) / 16 + 1) / 2, 1);
        bufBarrier(cb, t[out[i]].b);
    }
    bool record(VkCommandBuffer cb, uint32_t ringIndex, VkBuffer cand, const VkDescriptorImageInfo& output) {
        uint32_t qidx = ringIndex % 4;
        if (qpool[qidx] && qactive[qidx]) {
            uint64_t ts[16]{};
            if (vkGetQueryPoolResults(dev, qpool[qidx], 0, 12, sizeof(ts), ts, sizeof(uint64_t), VK_QUERY_RESULT_64_BIT) == VK_SUCCESS) {
                static uint64_t reportCount = 0;
                if (++reportCount % 4 == 0) {
                    double ns2ms = 1e-5;
                    double t_post_barrier = (ts[1] - ts[0]) * ns2ms;
                    double t_feat = (ts[2] - ts[1]) * ns2ms;
                    double t_conv0_4 = (ts[7] - ts[2]) * ns2ms;
                    double t_concat = (ts[8] - ts[7]) * ns2ms;
                    double t_conv5_6 = (ts[10] - ts[8]) * ns2ms;
                    double t_blend = (ts[11] - ts[10]) * ns2ms;
                    double t_total = (ts[11] - ts[0]) * ns2ms;
                    nss_trace("[PROFILE_SELECT] total: %6.3f ms | post_barr: %5.3f | feat: %5.3f | c0-4: %5.3f | cat: %5.3f | c5-6: %5.3f | blend: %5.3f ms\n",
                        t_total, t_post_barrier, t_feat, t_conv0_4, t_concat, t_conv5_6, t_blend);
                }
            }
        }
        if (qpool[qidx]) {
            vkCmdResetQueryPool(cb, qpool[qidx], 0, 16);
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qpool[qidx], 0);
        }

        const uint32_t setIdx = ringIndex % ioSets.size();
        VkDescriptorSet set = ioSets[setIdx];
        VkWriteDescriptorSet wr[4]{}; uint32_t wrCount = 0;
        VkDescriptorBufferInfo bufs[3] = {{cand, 0, VK_WHOLE_SIZE}, {t[0].b, 0, VK_WHOLE_SIZE}, {t[8].b, 0, VK_WHOLE_SIZE}};
        if (cand != lastCand[setIdx]) {
            wr[wrCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[wrCount].dstSet = set; wr[wrCount].dstBinding = 0; wr[wrCount].descriptorCount = 1;
            wr[wrCount].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[wrCount].pBufferInfo = &bufs[0]; wrCount++;
            wr[wrCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[wrCount].dstSet = set; wr[wrCount].dstBinding = 2; wr[wrCount].descriptorCount = 1;
            wr[wrCount].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[wrCount].pBufferInfo = &bufs[1]; wrCount++;
            wr[wrCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[wrCount].dstSet = set; wr[wrCount].dstBinding = 3; wr[wrCount].descriptorCount = 1;
            wr[wrCount].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[wrCount].pBufferInfo = &bufs[2]; wrCount++;
            lastCand[setIdx] = cand;
        }
        if (output.imageView != lastOutput[setIdx]) {
            wr[wrCount] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET}; wr[wrCount].dstSet = set; wr[wrCount].dstBinding = 1; wr[wrCount].descriptorCount = 1;
            wr[wrCount].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE; wr[wrCount].pImageInfo = &output; wrCount++;
            lastOutput[setIdx] = output.imageView;
        }
        if (wrCount > 0) vkUpdateDescriptorSets(dev, wrCount, wr, 0, nullptr);

        barrier(cb);                                                     
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 1);
        IoPC p{w4, h4, lw4, lh4, 0, 0, 0, 0, 0, 0, 0, 0, fw, fh};
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, featPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, ioPL, 0, 1, &set, 0, nullptr);
        vkCmdPushConstants(cb, ioPL, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(p), &p); vkCmdDispatch(cb, (w4 + 7) / 8, (h4 + 7) / 8, 1);
        bufBarrier(cb, t[0].b);
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 2);
        for (uint32_t i = 0; i < 5; i++) {
            conv(cb, i);
            if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 3 + i);
        }
        const uint32_t cpc[7] = {w4, h4, w8, h8, NFRU_SELECT_UP_BILINEAR, lw4, lh4};
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, concatPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &nnSets[7], 0, nullptr);
        vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(cpc), cpc); vkCmdDispatch(cb, (w4 * h4 * 16 + 63) / 64, 1, 1);
        bufBarrier(cb, t[6].b);
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 8);
        conv(cb, 5);
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 9);
#if NFRU_SELECT_FLOAT_LOGITS
        {
            const uint32_t lpc[3] = {w4, h4, g_nfru_select_logit_cin};
            vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, logitPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &nnSets[6], 0, nullptr);
            vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(lpc), lpc); vkCmdDispatch(cb, (w4 + 7) / 8, (h4 + 7) / 8, 1);
            bufBarrier(cb, t[8].b);
        }
#else
        conv(cb, 6);
#endif
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 10);
        uint32_t scaleBits; memcpy(&scaleBits, &g_nfru_select_logit_scale, 4);
        p = {lw4, lh4, w4, h4, 0, 0, 0, 0, 0, 0, 0, scaleBits, fw, fh};
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, blendPipe); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, ioPL, 0, 1, &set, 0, nullptr);
        vkCmdPushConstants(cb, ioPL, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(p), &p); vkCmdDispatch(cb, (fw + 7) / 8, (fh + 7) / 8, 1); barrier(cb);
        if (qpool[qidx]) vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qpool[qidx], 11);
        qactive[qidx] = true;
        if (calls++ < 4) nss_trace("NFRU select int8: dispatch #%llu", static_cast<unsigned long long>(calls));
        return true;
    }
    void destroy() {
        if (!dev) return;
        for (auto p : {dp4a, coopSmall, coopGeneric, featPipe, concatPipe, blendPipe, logitPipe}) if (p) vkDestroyPipeline(dev, p, nullptr);
        if (pool) vkDestroyDescriptorPool(dev, pool, nullptr);
        for (auto p : {pl, ioPL}) if (p) vkDestroyPipelineLayout(dev, p, nullptr);
        for (auto p : {nnDSL, ioDSL}) if (p) vkDestroyDescriptorSetLayout(dev, p, nullptr);
        for (auto& b : t) { if (b.b) vkDestroyBuffer(dev, b.b, nullptr); if (b.mem) vkFreeMemory(dev, b.mem, nullptr); }
        for (auto b : {blob, blobCoop, logitW}) { if (b.b) vkDestroyBuffer(dev, b.b, nullptr); if (b.mem) vkFreeMemory(dev, b.mem, nullptr); }
        for (int r = 0; r < 4; r++) { if (qpool[r]) { vkDestroyQueryPool(dev, qpool[r], nullptr); qpool[r] = VK_NULL_HANDLE; } }
        dev = VK_NULL_HANDLE;
    }
};
