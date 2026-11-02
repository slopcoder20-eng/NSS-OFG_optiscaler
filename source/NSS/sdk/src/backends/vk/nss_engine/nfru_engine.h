                                                                                                           
                                                                                             
#pragma once
#include "../nfru_isa_capture.h"
#include <vulkan/vulkan.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <vector>
#include "nfru_model_data.h"
#include "shaders_spv.h"
#include "coopmat_shape.h"
#include "coopmat_generic_spv.h"
#include "nss_env.h"

struct NfruEngine
{
    struct Buf { VkBuffer buf = VK_NULL_HANDLE; VkDeviceMemory mem = VK_NULL_HANDLE; VkDeviceSize size = 0; };
    struct Dim { uint32_t w = 0, h = 0, c = 0; };

    VkDevice         dev = VK_NULL_HANDLE;
    VkPhysicalDevice pdev = VK_NULL_HANDLE;
    Buf              blob;
    Buf              blobCoop;                                                          
    NssCoopShape coopShape;
    bool genericCoop = false;
    bool             useCoop = false;                                                         
    bool             canRequireWave32 = false;
    uint32_t         coopLocal = 32;                                                                           
    Buf              tensor[NFRU_NUM_OPS + 1];                                                      
    Dim              dim[NFRU_NUM_OPS + 1];
    bool             materialized[NFRU_NUM_OPS + 1] = {};
    int              alias[NFRU_NUM_OPS + 1];                                                             
    VkDescriptorSetLayout dslConv = VK_NULL_HANDLE, dslConcat = VK_NULL_HANDLE;
    VkPipelineLayout      plConv = VK_NULL_HANDLE, plConcat = VK_NULL_HANDLE;
    VkPipeline            pipeConv = VK_NULL_HANDLE, pipeConcat = VK_NULL_HANDLE, pipeConvCoop = VK_NULL_HANDLE;
    VkPipeline            pipeConvNarrowTiled = VK_NULL_HANDLE;                                                         
    VkPipeline            pipeConvCoopSmall = VK_NULL_HANDLE;                                                  
    VkPipeline            pipeConvCoopMedium = VK_NULL_HANDLE;                                                 
    VkPipeline            pipeConvCoop5x5s2 = VK_NULL_HANDLE;                                                  
    VkPipeline            pipeConvDp4aC16_1x1 = VK_NULL_HANDLE;                                                                           
                                                                                                 
    VkQueryPool           qpOpProfile = VK_NULL_HANDLE;
    double                opProfileTsPeriod = 0.0;
    VkDescriptorPool      pool = VK_NULL_HANDLE;
    VkDescriptorSet       sets[NFRU_NUM_OPS] = {};
    uint32_t              width = 0, height = 0;
    bool                  ready = false;

    struct ConvPC
    {
        uint32_t in_w, in_h, out_w, out_h, in_c, out_c;
        int32_t  pad_t, pad_l, stride_y, stride_x;
        uint32_t kh, kw;
        int32_t  out_zp, mult, shift;
        uint32_t upsample;
    };
    struct ConcatPC { uint32_t pixels, count; };

    uint32_t findMem(uint32_t bits, VkMemoryPropertyFlags want) const
    {
        VkPhysicalDeviceMemoryProperties mp;
        vkGetPhysicalDeviceMemoryProperties(pdev, &mp);
        for (uint32_t i = 0; i < mp.memoryTypeCount; ++i)
            if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & want) == want)
                return i;
        return UINT32_MAX;
    }

    bool makeBuf(Buf& b, VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags props)
    {
        VkBufferCreateInfo bi = { VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO };
        bi.size = size;
        bi.usage = usage;
        if (vkCreateBuffer(dev, &bi, nullptr, &b.buf) != VK_SUCCESS) return false;
        VkMemoryRequirements mr;
        vkGetBufferMemoryRequirements(dev, b.buf, &mr);
        uint32_t mt = findMem(mr.memoryTypeBits, props);
        if (mt == UINT32_MAX) return false;
        VkMemoryAllocateInfo ai = { VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO };
        ai.allocationSize = mr.size;
        ai.memoryTypeIndex = mt;
        if (vkAllocateMemory(dev, &ai, nullptr, &b.mem) != VK_SUCCESS) return false;
        vkBindBufferMemory(dev, b.buf, b.mem, 0);
        b.size = size;
        return true;
    }

    VkShaderModule module(const uint32_t* code, size_t bytes) const
    {
        VkShaderModuleCreateInfo si = { VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO };
        si.codeSize = bytes;
        si.pCode = code;
        VkShaderModule m = VK_NULL_HANDLE;
        vkCreateShaderModule(dev, &si, nullptr, &m);
        return m;
    }

                                                                                                                         
                                                                                                        
                                                                                                        
    bool detectCoop(VkInstance inst, uint32_t& subgroup)
    {
        VkPhysicalDeviceVulkan11Properties p11 = { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES };
        VkPhysicalDeviceSubgroupSizeControlProperties sub = { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES };
        p11.pNext = &sub;
        VkPhysicalDeviceProperties2 p2 = { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2, &p11 };
        vkGetPhysicalDeviceProperties2(pdev, &p2);
        subgroup = p11.subgroupSize;
        canRequireWave32 = (sub.minSubgroupSize <= 32 && sub.maxSubgroupSize >= 32 &&
                           (sub.requiredSubgroupSizeStages & VK_SHADER_STAGE_COMPUTE_BIT));
        const bool ok = nssQueryCoopShape(inst, pdev, coopShape);
        genericCoop = ok && (!coopShape.native16() || getenv("NFRU_COOP_GENERIC") != nullptr);
        return ok;
    }

    bool init(VkDevice d, VkPhysicalDevice pd, uint32_t w, uint32_t h, VkInstance inst = VK_NULL_HANDLE)
    {
        dev = d; pdev = pd; width = w; height = h;
        if ((w % 4) || (h % 4)) { fprintf(stderr, "NFRU: size must be a multiple of 4\n"); return false; }
        const VkBufferUsageFlags storage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;

                        
        dim[0] = { w, h, NFRU_INPUT_CHANNELS };
        for (int i = 0; i <= NFRU_NUM_OPS; ++i) alias[i] = -1;
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            Dim in0 = dim[op.in[0]];
            if (op.kind == NFRU_OP_CONV)
                dim[op.out] = { op.stride_x == 1 ? in0.w : in0.w / 2, op.stride_y == 1 ? in0.h : in0.h / 2, (uint32_t) op.out_c };
            else if (op.kind == NFRU_OP_CONCAT)
                dim[op.out] = { in0.w, in0.h, in0.c * (uint32_t) op.in_c };
            else
            {
                dim[op.out] = { in0.w * 2, in0.h * 2, in0.c };
                alias[op.out] = op.in[0];
            }
        }
        for (int t = 0; t <= NFRU_NUM_OPS; ++t)
        {
            if (alias[t] >= 0) continue;
            materialized[t] = true;
            if (t == 0 || t == NFRU_OUTPUT_TENSOR) continue;                         
            if (!makeBuf(tensor[t], (VkDeviceSize) dim[t].w * dim[t].h * dim[t].c + 64, storage, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) return false;
        }
        if (!makeBuf(blob, g_nfru_blob_size + 256, storage,
                     VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) &&
            !makeBuf(blob, g_nfru_blob_size + 256, storage, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
            return false;
        void* p = nullptr;
        if (vkMapMemory(dev, blob.mem, 0, g_nfru_blob_size, 0, &p) != VK_SUCCESS) return false;
        memcpy(p, g_nfru_blob, g_nfru_blob_size);
        vkUnmapMemory(dev, blob.mem);
        nss_trace("nfru: buffers + weight blob ready");

                                                                                                                                     
        {
            uint32_t sg = 32;
            bool coopOk = detectCoop(inst, sg);
            if (const char* f = getenv("NFRU_FORCE_BACKEND"))
            {
                if (!strcmp(f, "dp4a")) coopOk = false;
            }
            useCoop = coopOk;
            bool reqWave32 = canRequireWave32;
            if (const char* envW32 = getenv("NFRU_REQUIRE_WAVE32"))
            {
                reqWave32 = (envW32[0] != '0');
            }
            coopLocal = reqWave32 ? 32u : sg;
            nss_trace("nfru: backend coopmat=%d subgroup=%u (coopLocal=%u reqWave32=%d)", (int) useCoop, (unsigned) sg, (unsigned) coopLocal, (int) reqWave32);
            if (useCoop)
            {
                if (!makeBuf(blobCoop, g_nfru_blob_coop_size + 256, storage,
                             VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) &&
                    !makeBuf(blobCoop, g_nfru_blob_coop_size + 256, storage, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
                    useCoop = false;
                else
                {
                    void* pc = nullptr;
                    vkMapMemory(dev, blobCoop.mem, 0, g_nfru_blob_coop_size, 0, &pc);
                    memcpy(pc, g_nfru_blob_coop, g_nfru_blob_coop_size);
                    vkUnmapMemory(dev, blobCoop.mem);
                }
            }
        }

                              
        VkDescriptorSetLayoutBinding bind[5];
        for (int i = 0; i < 5; ++i) bind[i] = { (uint32_t) i, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr };
        VkDescriptorSetLayoutCreateInfo dli = { VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO };
        dli.bindingCount = 4;
        dli.pBindings = bind;
        vkCreateDescriptorSetLayout(dev, &dli, nullptr, &dslConv);
        dli.bindingCount = 5;
        vkCreateDescriptorSetLayout(dev, &dli, nullptr, &dslConcat);
        VkPushConstantRange pcrConv = { VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(ConvPC) };
        VkPushConstantRange pcrCat = { VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(ConcatPC) };
        VkPipelineLayoutCreateInfo pli = { VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO };
        pli.setLayoutCount = 1;
        pli.pSetLayouts = &dslConv;
        pli.pushConstantRangeCount = 1;
        pli.pPushConstantRanges = &pcrConv;
        vkCreatePipelineLayout(dev, &pli, nullptr, &plConv);
        pli.pSetLayouts = &dslConcat;
        pli.pPushConstantRanges = &pcrCat;
        vkCreatePipelineLayout(dev, &pli, nullptr, &plConcat);

        VkShaderModule mConv = module(g_spv_nfru_conv, g_spv_nfru_conv_size);
        VkShaderModule mCat = module(g_spv_nfru_concat, g_spv_nfru_concat_size);
        VkComputePipelineCreateInfo pi = { VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO };
        pi.flags = nfru_isa::createFlags(dev);                                                                        
        pi.stage = { VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, nullptr, 0, VK_SHADER_STAGE_COMPUTE_BIT, mConv, "main", nullptr };
        pi.layout = plConv;
        if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConv) != VK_SUCCESS) return false;
        nfru_isa::dump(dev, pipeConv, "nfru_net_conv_dp4a");
        {
            VkShaderModule mNarrow = module(g_spv_nfru_conv_narrow_tiled, g_spv_nfru_conv_narrow_tiled_size);
            pi.stage.module = mNarrow;
            pi.layout = plConv;
            if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvNarrowTiled) != VK_SUCCESS)
                pipeConvNarrowTiled = VK_NULL_HANDLE;
            nfru_isa::dump(dev, pipeConvNarrowTiled, "nfru_net_conv_dp4a_narrow_tiled");
            vkDestroyShaderModule(dev, mNarrow, nullptr);
        }
        {
            VkShaderModule mC16_1x1 = module(g_spv_nfru_conv_dp4a_c16_1x1, g_spv_nfru_conv_dp4a_c16_1x1_size);
            pi.stage.module = mC16_1x1;
            pi.layout = plConv;
            if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvDp4aC16_1x1) != VK_SUCCESS)
                pipeConvDp4aC16_1x1 = VK_NULL_HANDLE;
            nfru_isa::dump(dev, pipeConvDp4aC16_1x1, "nfru_net_conv_dp4a_c16_1x1");
            vkDestroyShaderModule(dev, mC16_1x1, nullptr);
        }
        pi.stage.module = mCat;
        pi.layout = plConcat;
        if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConcat) != VK_SUCCESS) return false;
        nfru_isa::dump(dev, pipeConcat, "nfru_net_concat");
        vkDestroyShaderModule(dev, mConv, nullptr);
        vkDestroyShaderModule(dev, mCat, nullptr);
        nss_trace("nfru: conv/concat pipelines ready");
        if (useCoop)
        {
            nss_trace("nfru: INT8 shape %ux%ux%u generic=%d", coopShape.m, coopShape.n, coopShape.k, int(genericCoop));
            VkShaderModule mCoop = genericCoop ? module(g_spv_conv_coop_generic_nfru, g_spv_conv_coop_generic_nfru_size) : module(g_spv_nfru_conv_coopmat, g_spv_nfru_conv_coopmat_size);
            uint32_t specData[4] = {coopLocal, coopShape.m, coopShape.n, coopShape.k};
            VkSpecializationMapEntry me[4] = {{0,0,4},{3,4,4},{4,8,4},{5,12,4}};
            VkSpecializationInfo si = {4, me, sizeof(specData), specData};
            VkPipelineShaderStageRequiredSubgroupSizeCreateInfo reqSubgroup = { VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO };
            reqSubgroup.requiredSubgroupSize = 32;
            void* stageNext = (coopLocal == 32 && canRequireWave32) ? (void*)&reqSubgroup : nullptr;

            pi.stage = { VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, stageNext, 0, VK_SHADER_STAGE_COMPUTE_BIT, mCoop, "main", &si };
            pi.layout = plConv;
            if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvCoop) != VK_SUCCESS) { useCoop = false; pipeConvCoop = VK_NULL_HANDLE; }
            nfru_isa::dump(dev, pipeConvCoop, genericCoop ? "nfru_net_conv_coopmat_generic" : "nfru_net_conv_coopmat");
            vkDestroyShaderModule(dev, mCoop, nullptr);

            if (useCoop && !genericCoop) {
                VkShaderModule mSmall = module(g_spv_nfru_conv_coopmat_small, g_spv_nfru_conv_coopmat_small_size);
                pi.stage.module = mSmall;
                pi.stage.pNext = stageNext;
                if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvCoopSmall) != VK_SUCCESS)
                    pipeConvCoopSmall = VK_NULL_HANDLE;
                nfru_isa::dump(dev, pipeConvCoopSmall, "nfru_net_conv_coopmat_small_lds");
                vkDestroyShaderModule(dev, mSmall, nullptr);
            }
            if (useCoop && !genericCoop) {
                VkShaderModule mMedium = module(g_spv_nfru_conv_coopmat_medium, g_spv_nfru_conv_coopmat_medium_size);
                pi.stage.module = mMedium;
                pi.stage.pNext = stageNext;
                if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvCoopMedium) != VK_SUCCESS)
                    pipeConvCoopMedium = VK_NULL_HANDLE;
                nfru_isa::dump(dev, pipeConvCoopMedium, "nfru_net_conv_coopmat_medium_lds");
                vkDestroyShaderModule(dev, mMedium, nullptr);
            }
            if (useCoop && !genericCoop) {
                VkShaderModule m5x5s2 = module(g_spv_nfru_conv_coopmat_5x5s2, g_spv_nfru_conv_coopmat_5x5s2_size);
                pi.stage.module = m5x5s2;
                pi.stage.pNext = stageNext;
                if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &pi, nullptr, &pipeConvCoop5x5s2) != VK_SUCCESS)
                    pipeConvCoop5x5s2 = VK_NULL_HANDLE;
                nfru_isa::dump(dev, pipeConvCoop5x5s2, "nfru_net_conv_coopmat_5x5s2");
                vkDestroyShaderModule(dev, m5x5s2, nullptr);
            }
        }

                                                     
        VkDescriptorPoolSize ps = { VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NFRU_NUM_OPS * 5 };
        VkDescriptorPoolCreateInfo dpi = { VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO };
        dpi.maxSets = NFRU_NUM_OPS;
        dpi.poolSizeCount = 1;
        dpi.pPoolSizes = &ps;
        vkCreateDescriptorPool(dev, &dpi, nullptr, &pool);
        ready = true;
        return true;
    }

    int srcTensor(int t) const { return alias[t] >= 0 ? alias[t] : t; }

                                                                                                          
                                                                                                      
                                                                                                       
                                                                                                       
                                                                                                
                                                                                                    
                                                                                                  
    bool opUsesCoop(const NfruOp& op) const {
                                                                                                    
                                                                                                 
                                                                                               
                                               
                                                                                                    
                                                                                            
        static const bool skip1x1 = getenv("NFRU_1X1_DP4A") == nullptr || getenv("NFRU_1X1_DP4A")[0] != '0';
                                                                                                       
                                                                                                       
                                                                                                    
                                                                                                       
                                                                                                      
                                                                                                       
                                                                                                        
                                                                                                         
                                                                                                       
                                                                                                   
                                                                                                        
                                                                                                        
                                                                                                      
        static const bool skip1x1_op13 = getenv("NFRU_C16_1X1_OP13") == nullptr || getenv("NFRU_C16_1X1_OP13")[0] != '0';
        if (skip1x1_op13 && op.kind == NFRU_OP_CONV && op.kh == 1 && op.kw == 1 && op.in_c == 64 && op.out_c == 16)
            return false;
        return useCoop && op.kind == NFRU_OP_CONV && op.out_c >= 16 && !(skip1x1 && op.kh == 1 && op.kw == 1 && op.in_c <= 16);
    }

    VkBuffer ioIn = VK_NULL_HANDLE, ioOut = VK_NULL_HANDLE;
    bool     setsAllocated = false;

                                                                                                                       
                                                                                                 
    bool bindIO(VkBuffer in, VkBuffer out)
    {
        if (!ready || in == VK_NULL_HANDLE || out == VK_NULL_HANDLE) return false;
        if (in == ioIn && out == ioOut) return true;
        ioIn = in; ioOut = out;
        tensor[0].buf = in;
        tensor[NFRU_OUTPUT_TENSOR].buf = out;
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            if (op.kind == NFRU_OP_RESIZE) continue;
            if (!setsAllocated)
            {
                VkDescriptorSetAllocateInfo ai = { VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO, nullptr, pool, 1, op.kind == NFRU_OP_CONV ? &dslConv : &dslConcat };
                vkAllocateDescriptorSets(dev, &ai, &sets[i]);
            }
            std::vector<VkDescriptorBufferInfo> infos;
            if (op.kind == NFRU_OP_CONV)
            {
                const int src = srcTensor(op.in[0]);
                const uint32_t ict = op.in_c / 16, oct = (op.out_c + 15) / 16;
                infos.push_back({ tensor[src].buf, 0, VK_WHOLE_SIZE });
                infos.push_back({ tensor[op.out].buf, 0, VK_WHOLE_SIZE });
                if (opUsesCoop(op))
                    infos.push_back({ blobCoop.buf, op.weight_off_coop, (VkDeviceSize) op.kh * op.kw * ict * oct * 256 });
                else
                    infos.push_back({ blob.buf, op.weight_off, (VkDeviceSize) op.kh * op.kw * ict * oct * 256 });
                infos.push_back({ blob.buf, op.bias_off, (VkDeviceSize) ((op.out_c + 3) / 4) * 16 });
            }
            else
            {
                for (int k = 0; k < 4; ++k)
                    infos.push_back({ tensor[srcTensor(op.in[k < op.in_c ? k : 0])].buf, 0, VK_WHOLE_SIZE });
                infos.push_back({ tensor[op.out].buf, 0, VK_WHOLE_SIZE });
            }
            std::vector<VkWriteDescriptorSet> wr(infos.size());
            for (size_t k = 0; k < infos.size(); ++k)
                wr[k] = { VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, sets[i], (uint32_t) k, 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, nullptr, &infos[k], nullptr };
            vkUpdateDescriptorSets(dev, (uint32_t) wr.size(), wr.data(), 0, nullptr);
        }
        setsAllocated = true;
        return true;
    }

    void destroy()
    {
        if (!dev) return;
        vkDeviceWaitIdle(dev);
        if (pool) vkDestroyDescriptorPool(dev, pool, nullptr);
        if (pipeConv) vkDestroyPipeline(dev, pipeConv, nullptr);
        if (pipeConcat) vkDestroyPipeline(dev, pipeConcat, nullptr);
        if (pipeConvCoop) vkDestroyPipeline(dev, pipeConvCoop, nullptr);
        if (pipeConvNarrowTiled) vkDestroyPipeline(dev, pipeConvNarrowTiled, nullptr);
        if (pipeConvDp4aC16_1x1) vkDestroyPipeline(dev, pipeConvDp4aC16_1x1, nullptr);
        if (pipeConvCoopSmall) vkDestroyPipeline(dev, pipeConvCoopSmall, nullptr);
        if (pipeConvCoopMedium) vkDestroyPipeline(dev, pipeConvCoopMedium, nullptr);
        if (pipeConvCoop5x5s2) vkDestroyPipeline(dev, pipeConvCoop5x5s2, nullptr);
        if (qpOpProfile) { vkDestroyQueryPool(dev, qpOpProfile, nullptr); qpOpProfile = VK_NULL_HANDLE; }
        if (plConv) vkDestroyPipelineLayout(dev, plConv, nullptr);
        if (plConcat) vkDestroyPipelineLayout(dev, plConcat, nullptr);
        if (dslConv) vkDestroyDescriptorSetLayout(dev, dslConv, nullptr);
        if (dslConcat) vkDestroyDescriptorSetLayout(dev, dslConcat, nullptr);
        for (int t = 1; t <= NFRU_NUM_OPS; ++t)
            if (tensor[t].buf && t != NFRU_OUTPUT_TENSOR && materialized[t])
            {
                vkDestroyBuffer(dev, tensor[t].buf, nullptr);
                vkFreeMemory(dev, tensor[t].mem, nullptr);
            }
        if (blob.buf) { vkDestroyBuffer(dev, blob.buf, nullptr); vkFreeMemory(dev, blob.mem, nullptr); }
        if (blobCoop.buf) { vkDestroyBuffer(dev, blobCoop.buf, nullptr); vkFreeMemory(dev, blobCoop.mem, nullptr); }
        ready = false;
    }

    static void barrier(VkCommandBuffer cmd)
    {
        VkMemoryBarrier mb = { VK_STRUCTURE_TYPE_MEMORY_BARRIER, nullptr, VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT };
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
    }

                                                                                          
    void record(VkCommandBuffer cmd)
    {
        static const bool opProfile = getenv("NFRU_LAYER_PROFILE") != nullptr;
        if (opProfile && qpOpProfile != VK_NULL_HANDLE) {
                                                                                                        
            uint64_t ts[NFRU_NUM_OPS + 1] = {};
            VkResult qr = vkGetQueryPoolResults(dev, qpOpProfile, 0, NFRU_NUM_OPS + 1, sizeof(ts), ts, sizeof(uint64_t),
                                                 VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT);
            if (qr == VK_SUCCESS) {
                double total = (double)(ts[NFRU_NUM_OPS] - ts[0]) * opProfileTsPeriod / 1e6;
                nss_trace("== NFRU op profile (ms) total=%.4f ==", total);
                for (int i = 0; i < NFRU_NUM_OPS; ++i) {
                    double ms = (double)(ts[i + 1] - ts[i]) * opProfileTsPeriod / 1e6;
                    nss_trace("  op%02d %-6s %.4f ms", i, g_nfru_ops[i].kind == NFRU_OP_RESIZE ? "resize" : (g_nfru_ops[i].kind == NFRU_OP_CONCAT ? "concat" : "conv"), ms);
                }
            }
        }
        VkQueryPool qpOP = VK_NULL_HANDLE;
        if (opProfile) {
            if (qpOpProfile == VK_NULL_HANDLE) {
                VkPhysicalDeviceProperties props{};
                vkGetPhysicalDeviceProperties(pdev, &props);
                opProfileTsPeriod = props.limits.timestampPeriod;
                VkQueryPoolCreateInfo qi = { VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO };
                qi.queryType = VK_QUERY_TYPE_TIMESTAMP;
                qi.queryCount = NFRU_NUM_OPS + 1;
                vkCreateQueryPool(dev, &qi, nullptr, &qpOpProfile);
            }
            qpOP = qpOpProfile;
            vkCmdResetQueryPool(cmd, qpOP, 0, NFRU_NUM_OPS + 1);
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, qpOP, 0);
        }
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            if (op.kind == NFRU_OP_RESIZE) {
                                                                                                  
                                                                                                    
                                                                                                         
                if (qpOP) vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, qpOP, i + 1);
                continue;
            }
            if (op.kind == NFRU_OP_CONV)
            {
                const Dim in = dim[op.in[0]], out = dim[op.out];
                ConvPC pc = { in.w, in.h, out.w, out.h, (uint32_t) op.in_c, (uint32_t) op.out_c, op.pad_t, op.pad_l, op.stride_y, op.stride_x,
                              (uint32_t) op.kh, (uint32_t) op.kw, op.out_zp, op.mult, op.shift, alias[op.in[0]] >= 0 ? 1u : 0u };
                const bool coop = opUsesCoop(op);
                                                                                                   
                                                                                                     
                                                                                                    
                                                                                   
                const bool tryNarrow = getenv("NFRU_NARROW_TILED") == nullptr || getenv("NFRU_NARROW_TILED")[0] != '0';
                const bool narrow = tryNarrow && pipeConvNarrowTiled && !coop && op.kh == 5 && op.kw == 5 &&
                                     op.stride_y == 1 && op.stride_x == 1 && op.pad_t == 2 && op.pad_l == 2 &&
                                     op.in_c == 16 && op.out_c < 16 && pc.upsample == 0u;
                                                                                                     
                                                                                                   
                                                                                                    
                                                                                                     
                                                                                                   
                                                                                                   
                                                                                      
                                                                                              
                const bool smallLds = coop && pipeConvCoopSmall && op.kw == 3 && op.stride_x == 1 &&
                                      (getenv("NFRU_COOP_SMALL_LDS") == nullptr || getenv("NFRU_COOP_SMALL_LDS")[0] != '0');
                                                                                                   
                                                                                                  
                                                                                                
                const bool mediumLds = coop && pipeConvCoopMedium && op.kw == 7 && op.stride_x == 1 &&
                                       (getenv("NFRU_COOP_MEDIUM_LDS") == nullptr || getenv("NFRU_COOP_MEDIUM_LDS")[0] != '0');
                                                                                                   
                                                          
                static const bool try5x5s2 = getenv("NFRU_COOP_5X5S2_LDS") != nullptr;
                const bool lds5x5s2 = try5x5s2 && coop && pipeConvCoop5x5s2 && op.kw == 5 && op.stride_x == 2;
                                                                                                       
                                                                                                     
                                                                                                  
                                                                                                     
                                                                                                     
                                                                                                      
                                                                                                   
                                                                                                 
                static const bool tryC16_1x1 = getenv("NFRU_C16_1X1") == nullptr || getenv("NFRU_C16_1X1")[0] != '0';
                                                                                                  
                                                                                             
                                                                                                          
                                                                                                         
                                                                                                        
                                                                                                
                const bool c16_1x1 = tryC16_1x1 && pipeConvDp4aC16_1x1 && !coop && op.kh == 1 && op.kw == 1 &&
                                      op.stride_y == 1 && op.stride_x == 1 && op.pad_t == 0 && op.pad_l == 0 &&
                                      op.out_c == 16 && pc.upsample == 0u;
                vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, narrow ? pipeConvNarrowTiled : (smallLds ? pipeConvCoopSmall : (mediumLds ? pipeConvCoopMedium : (lds5x5s2 ? pipeConvCoop5x5s2 : (c16_1x1 ? pipeConvDp4aC16_1x1 : (coop ? pipeConvCoop : pipeConv))))));
                vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, plConv, 0, 1, &sets[i], 0, nullptr);
                vkCmdPushConstants(cmd, plConv, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
                if (narrow) {
                    vkCmdDispatch(cmd, (out.w + 7) / 8, (out.h + 7) / 8, 1);
                } else if (c16_1x1) {
                    vkCmdDispatch(cmd, (out.w + 15) / 16, (out.h + 3) / 4, 1);
                } else if (coop && genericCoop) {
                    vkCmdDispatch(cmd, (out.w * out.h + coopShape.m - 1) / coopShape.m,
                                  (uint32_t(op.out_c) + coopShape.n - 1) / coopShape.n, 1);
                } else {
                    const uint32_t groupsX = coop ? ((out.w + 15) / 16) * ((out.h + 3) / 4) : (out.w * out.h + 63) / 64;
                    vkCmdDispatch(cmd, groupsX, (((uint32_t) op.out_c + 15) / 16 + 1) / 2, 1);
                }
            }
            else
            {
                const Dim out = dim[op.out];
                ConcatPC pc = { out.w * out.h, (uint32_t) op.in_c };
                vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipeConcat);
                vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, plConcat, 0, 1, &sets[i], 0, nullptr);
                vkCmdPushConstants(cmd, plConcat, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
                vkCmdDispatch(cmd, (pc.pixels * pc.count + 63) / 64, 1, 1);
            }
            barrier(cmd);
            if (qpOP) vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, qpOP, i + 1);
        }
    }
};
