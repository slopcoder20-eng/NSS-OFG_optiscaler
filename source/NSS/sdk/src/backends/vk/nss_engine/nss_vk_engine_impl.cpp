#include "nss_vk_engine.h"
#include "shaders_spv.h"
#include "coopmat_shape.h"
#include "coopmat_generic_spv.h"
#include "nss_model_high_data.h"
#include "nss_model_high_v2_data.h"
#include "nss_model_mid_low_data.h"
#include "nss_env.h"

#include <vector>
#include <string>
#include <cstring>
#include <cstdio>
#include <cstdlib>

struct PushConstantConv2D {
    uint32_t in_width;
    uint32_t in_height;
    uint32_t out_width;
    uint32_t out_height;
    uint32_t in_channels;
    uint32_t out_channels;
    int32_t  pad_y;
    int32_t  pad_x;
    int32_t  stride_y;
    int32_t  stride_x;
    int32_t  out_zp;
    int32_t  has_table;
    uint32_t in1_channels;
    uint32_t upsample;
};

struct PushConstantResize {
    uint32_t in_width;
    uint32_t in_height;
    uint32_t out_width;
    uint32_t out_height;
    uint32_t channels;
};

struct PushConstantConcat {
    uint32_t total_pixels;
    uint32_t c1;
    uint32_t c2;
};

struct PushConstantPreprocess {
    uint32_t render_width;
    uint32_t render_height;
    uint32_t display_width;
    uint32_t display_height;
    float    jitter_x;
    float    jitter_y;
    float    pre_exposure;
    int32_t  reset_history;
};

struct PushConstantPostprocess {
    uint32_t render_width;
    uint32_t render_height;
    uint32_t display_width;
    uint32_t display_height;
    float    jitter_x;
    float    jitter_y;
    float    pre_exposure;
    int32_t  reset_history;
};

struct AllocatedBuffer {
    VkBuffer       buffer = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    VkDeviceSize   size   = 0;
};

class NssEngine {
public:
    VkInstance       instance = VK_NULL_HANDLE;
    VkPhysicalDevice physDev  = VK_NULL_HANDLE;
    VkDevice         device   = VK_NULL_HANDLE;
    NssModelQuality  quality  = NSS_QUALITY_HIGH;
    NssBackendType   backend  = NSS_BACKEND_COOPMAT;

                
    VkPipelineLayout layoutConv2D          = VK_NULL_HANDLE;
    VkPipeline       pipeConv2D            = VK_NULL_HANDLE;
    VkPipeline       pipeConv2D_DP4a       = VK_NULL_HANDLE;
    VkPipeline       pipeConv2D_DP4a_1440  = VK_NULL_HANDLE;
    VkPipeline       pipeConv2D_DP4a_2160  = VK_NULL_HANDLE;
    VkPipeline       pipeConv2D_DP4a_NarrowTiled = VK_NULL_HANDLE;                                                     
    VkPipeline       pipeConv2D_DP4a_TiledS1 = VK_NULL_HANDLE;                                                                                    
    VkPipeline       pipeConv2D_DP4a_TiledS2 = VK_NULL_HANDLE;                                                                         
    VkPipeline       pipeConv2D_DP4a_TiledS1_T16 = VK_NULL_HANDLE;                                                           
    VkPipeline       pipeConv2D_Coop_S1 = VK_NULL_HANDLE;                                                               
    VkPipeline       pipeConv2D_Coop2D = VK_NULL_HANDLE;                                                                                              
    VkPipeline       pipeConv2D_CoopPT2 = VK_NULL_HANDLE;                                                                                   
    VkPipeline       pipeConv2D_Coop_C16 = VK_NULL_HANDLE;                                                                                   
    VkPipeline       pipeConv2D_Coop_C32 = VK_NULL_HANDLE;                                                                                             
    VkPipeline       pipeConv2D_Coop_C32_PT2 = VK_NULL_HANDLE;                                                                                        
    VkPipeline       pipeConv2D_C4 = VK_NULL_HANDLE;                                                              
    VkPipeline       pipeConv2D_DP4a_C16 = VK_NULL_HANDLE;                                                                              
    VkDescriptorSetLayout dslConv2D        = VK_NULL_HANDLE;

                                                                  
    VkQueryPool qpLayerProfile        = VK_NULL_HANDLE;
    double      layerProfileTsPeriod  = 0.0;

    VkPipelineLayout layoutResize = VK_NULL_HANDLE;
    VkPipeline       pipeResize   = VK_NULL_HANDLE;
    VkDescriptorSetLayout dslResize = VK_NULL_HANDLE;

    VkPipelineLayout layoutConcat = VK_NULL_HANDLE;
    VkPipeline       pipeConcat   = VK_NULL_HANDLE;
    VkDescriptorSetLayout dslConcat = VK_NULL_HANDLE;

                                               
    VkDescriptorSetLayout dslPreprocess        = VK_NULL_HANDLE;
    VkPipelineLayout       layoutPreprocess     = VK_NULL_HANDLE;
    VkPipeline             pipePreprocess       = VK_NULL_HANDLE;
    VkPipeline             pipePreprocess_1440  = VK_NULL_HANDLE;
    VkPipeline             pipePreprocess_2160  = VK_NULL_HANDLE;

    VkDescriptorSetLayout dslPostprocess       = VK_NULL_HANDLE;
    VkPipelineLayout       layoutPostprocess    = VK_NULL_HANDLE;
    VkPipeline             pipePostprocess      = VK_NULL_HANDLE;
    VkPipeline             pipePostprocess_1440 = VK_NULL_HANDLE;
    VkPipeline             pipePostprocess_2160 = VK_NULL_HANDLE;

    VkSampler linearSampler = VK_NULL_HANDLE;

                                           
    AllocatedBuffer t_frame_in_tensor;
    AllocatedBuffer t_frame_kpn_tensor;
    AllocatedBuffer t_frame_feedback;

    VkImage        historyImage  = VK_NULL_HANDLE;
    VkDeviceMemory historyMemory = VK_NULL_HANDLE;
    VkImageView    historyView   = VK_NULL_HANDLE;
    uint32_t       curDisplayW   = 0;
    uint32_t       curDisplayH   = 0;

    VkDescriptorPool descPool = VK_NULL_HANDLE;

                                              
    AllocatedBuffer modelBuffer;
    AllocatedBuffer modelBuffer_DP4a;
                                 
    const NssLayerParam* layers = nullptr;

                                                                                                  
                                                                                                      
                                                                                                      
                                                                                                    
                                                                                                      
                                                                                                    
    bool useV2Model = false;
    static constexpr int kMaxConv = 14;
    int numConv = 14;

                         
    uint32_t curInW = 0;
    uint32_t curInH = 0;

                           
                            
                
                    
                    
                    
    AllocatedBuffer t_l1;                        
    AllocatedBuffer t_l2_skip;                            
    AllocatedBuffer t_l3;                        
    AllocatedBuffer t_l4_skip;                            
    AllocatedBuffer t_l5;                        
    AllocatedBuffer t_l6;                        
    AllocatedBuffer t_l7;                        
    AllocatedBuffer t_up1;                       
    AllocatedBuffer t_d1;                        
    AllocatedBuffer t_cat1;                      
    AllocatedBuffer t_d2;                        
    AllocatedBuffer t_up2;                       
    AllocatedBuffer t_d3;                        
    AllocatedBuffer t_cat2;                      
    AllocatedBuffer t_d4;                        
    AllocatedBuffer t_d5;                        
    AllocatedBuffer t_up3;                   

                                                                                                  
                                                                                                   
                                      

                                                          
    bool dsInitialized = false;
    VkBuffer lastInBuf = VK_NULL_HANDLE;
    VkBuffer lastKpnBuf = VK_NULL_HANDLE;
    VkBuffer lastFeedbackBuf = VK_NULL_HANDLE;
    VkDescriptorSet dsConv[kMaxConv];
    VkDescriptorSet dsConv_DP4a[kMaxConv];
    VkDescriptorSet dsResize[3];

                                                                                                              
    VkQueryPool profPool = VK_NULL_HANDLE;
    uint32_t profIdx = 0;
    int profFrames = 0;
    double profPeriodNs = 1.0;
    std::vector<std::string> profNames;
    std::vector<double> profSum;

    void profBegin(VkCommandBuffer cmd) {
        static const bool on = getenv("NSS_PROFILE") != nullptr;
        if (!on) return;
        if (profPool == VK_NULL_HANDLE) {
            VkQueryPoolCreateInfo qi = {VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
            qi.queryType = VK_QUERY_TYPE_TIMESTAMP;
            qi.queryCount = 64;
            vkCreateQueryPool(device, &qi, nullptr, &profPool);
            VkPhysicalDeviceProperties pr;
            vkGetPhysicalDeviceProperties(physDev, &pr);
            profPeriodNs = pr.limits.timestampPeriod;
        }
        profCollect();
        vkCmdResetQueryPool(cmd, profPool, 0, 64);
        profIdx = 0;
        vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, profPool, profIdx++);
    }
    void profMark(VkCommandBuffer cmd, const char* name) {
        if (profPool == VK_NULL_HANDLE || profIdx >= 64) return;
        if (profNames.size() < profIdx) profNames.push_back(name);
        vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, profPool, profIdx++);
    }
    void profCollect() {
        if (profPool == VK_NULL_HANDLE || profIdx < 2) return;
        std::vector<uint64_t> ts(profIdx);
        if (vkGetQueryPoolResults(device, profPool, 0, profIdx, ts.size() * 8, ts.data(), 8,
                                  VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT) != VK_SUCCESS) return;
        if (profSum.size() < profIdx - 1) profSum.resize(profIdx - 1, 0.0);
        for (uint32_t i = 1; i < profIdx; ++i)
            profSum[i - 1] += (double)(ts[i] - ts[i - 1]) * profPeriodNs * 1e-6;
        profFrames++;
    }
    void profWrite() {
        if (profPool == VK_NULL_HANDLE) return;
        profCollect();
        FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
        if (lf && profFrames > 0) {
            double total = 0;
            fprintf(lf, "[NSS Profile] backend=%s, %d frames, avg ms per pass:\n", backend == NSS_BACKEND_COOPMAT ? "COOPMAT" : "DP4A", profFrames);
            for (size_t i = 0; i < profSum.size() && i < profNames.size(); ++i) {
                fprintf(lf, "[NSS Profile]   %-10s %.4f\n", profNames[i].c_str(), profSum[i] / profFrames);
                total += profSum[i] / profFrames;
            }
            fprintf(lf, "[NSS Profile]   TOTAL U-Net %.4f ms\n", total);
        }
        if (lf) fclose(lf);
        vkDestroyQueryPool(device, profPool, nullptr);
        profPool = VK_NULL_HANDLE;
    }

                                                                                                       
                                                                                             
    struct DumpEntry { std::string name; AllocatedBuffer stage; void* mapped = nullptr; VkDeviceSize size = 0; };
    std::vector<DumpEntry> dumpEntries;

    void dumpRecord(VkCommandBuffer cmd, const char* name, VkBuffer src, VkDeviceSize srcOff, VkDeviceSize size) {
        if (src == VK_NULL_HANDLE || size == 0) return;
        DumpEntry* e = nullptr;
        for (auto& d : dumpEntries) if (d.name == name) { e = &d; break; }
        if (!e) {
            dumpEntries.push_back({});
            e = &dumpEntries.back();
            e->name = name;
            e->size = size;
            if (!createBuffer(size, VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                              VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, e->stage)) {
                dumpEntries.pop_back();
                return;
            }
            vkMapMemory(device, e->stage.memory, 0, size, 0, &e->mapped);
        }
        VkBufferCopy c = {srcOff, 0, size};
        vkCmdCopyBuffer(cmd, src, e->stage.buffer, 1, &c);
    }

                                                                                                    
                                                                                                   
                                                                                                     
                                                                                                    
                                                                                                  
                                                                                                        
    static constexpr int kCapRing = 4;
    static constexpr uint64_t kCapDelay = 8;
    struct CapSlot { AllocatedBuffer stage; void* mapped = nullptr; uint64_t frame = 0; bool pending = false; uint32_t w = 0, h = 0; };
    CapSlot capSlots[kCapRing];
    uint64_t capFrame = 0;
    uint32_t capCount = 0;

    void capWriteSlot(CapSlot& s, const char* dir) {
        if (!s.pending || !s.mapped) return;
        char path[600];
        snprintf(path, sizeof(path), "%s/in_%ux%u_%llu.bin", dir, s.w, s.h, (unsigned long long)s.frame);
        if (FILE* f = fopen(path, "wb")) {
            fwrite(s.mapped, 1, (size_t)s.w * s.h * 12, f);
            fclose(f);
        }
        s.pending = false;
    }

    void captureInput(VkCommandBuffer cmd, VkBuffer in_buf, VkDeviceSize in_off) {
        static const char* dir = getenv("NSS_CAPTURE_IN");
        if (!dir || !dir[0]) return;
        static const uint64_t every = getenv("NSS_CAPTURE_EVERY") ? (uint64_t)atoll(getenv("NSS_CAPTURE_EVERY")) : 15;
        static const uint32_t maxCap = getenv("NSS_CAPTURE_MAX") ? (uint32_t)atoi(getenv("NSS_CAPTURE_MAX")) : 200;
        ++capFrame;
        for (auto& s : capSlots) if (s.pending && capFrame - s.frame >= kCapDelay) capWriteSlot(s, dir);
        if (every == 0 || capFrame % every != 0 || capCount >= maxCap) return;
        const VkDeviceSize sz = (VkDeviceSize)curInW * curInH * 12;
        CapSlot* slot = nullptr;
        for (auto& s : capSlots) if (!s.pending) { slot = &s; break; }
        if (!slot) return;
        if (slot->stage.buffer == VK_NULL_HANDLE || slot->stage.size < sz) {
            if (slot->mapped) { vkUnmapMemory(device, slot->stage.memory); slot->mapped = nullptr; }
            destroyBuffer(slot->stage);
            if (!createBuffer(sz, VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                              VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, slot->stage)) return;
            vkMapMemory(device, slot->stage.memory, 0, sz, 0, &slot->mapped);
        }
        VkMemoryBarrier mb = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
        VkBufferCopy c = {in_off, 0, sz};
        vkCmdCopyBuffer(cmd, in_buf, slot->stage.buffer, 1, &c);
        VkMemoryBarrier mb2 = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb2.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb2.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_HOST_BIT, 0, 1, &mb2, 0, nullptr, 0, nullptr);
        slot->frame = capFrame; slot->w = curInW; slot->h = curInH; slot->pending = true;
        ++capCount;
    }

    void captureFlush() {
        const char* dir = getenv("NSS_CAPTURE_IN");
        if (dir && dir[0]) for (auto& s : capSlots) capWriteSlot(s, dir);
        for (auto& s : capSlots) {
            if (s.mapped) { vkUnmapMemory(device, s.stage.memory); s.mapped = nullptr; }
            destroyBuffer(s.stage);
        }
    }

    void dumpRecordAll(VkCommandBuffer cmd, VkBuffer in_buf, VkDeviceSize in_off, VkBuffer out_kpn, VkDeviceSize kpn_off,
                       VkBuffer out_feedback, VkDeviceSize fb_off) {
        VkMemoryBarrier mb = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0,
                             nullptr, 0, nullptr);
        const uint64_t w = curInW, h = curInH, w2 = w / 2, h2 = h / 2, w4 = w / 4, h4 = h / 4, w8 = w / 8, h8 = h / 8;
        const uint64_t kpn_c = (quality == NSS_QUALITY_HIGH) ? 36 : 16;
        dumpRecord(cmd, "in", in_buf, in_off, w * h * 12);
        dumpRecord(cmd, "l1", t_l1.buffer, 0, w2 * h2 * 32);
        dumpRecord(cmd, "l2_skip", t_l2_skip.buffer, 0, w2 * h2 * 32);
        dumpRecord(cmd, "l3", t_l3.buffer, 0, w4 * h4 * 32);
        dumpRecord(cmd, "l4_skip", t_l4_skip.buffer, 0, w4 * h4 * 32);
        dumpRecord(cmd, "l5", t_l5.buffer, 0, w8 * h8 * 64);
        dumpRecord(cmd, "l6", t_l6.buffer, 0, w8 * h8 * 64);
        dumpRecord(cmd, "l7", t_l7.buffer, 0, w8 * h8 * 32);
        if (!useV2Model) dumpRecord(cmd, "d1", t_d1.buffer, 0, w4 * h4 * 16);
        dumpRecord(cmd, "d2", t_d2.buffer, 0, w4 * h4 * 32);
        dumpRecord(cmd, "kpn", out_kpn, kpn_off, w4 * h4 * kpn_c);
        if (!useV2Model) dumpRecord(cmd, "d3", t_d3.buffer, 0, w2 * h2 * 16);
        dumpRecord(cmd, "d4", t_d4.buffer, 0, w2 * h2 * 16);
        dumpRecord(cmd, "d5", t_d5.buffer, 0, w2 * h2 * 16);
        dumpRecord(cmd, "fdbk", out_feedback, fb_off, w * h * 4);
    }

    void dumpWriteAll() {
        const char* dir = getenv("NSS_DUMP_LAYERS");
        if (!dir) return;
        for (auto& d : dumpEntries) {
            if (!d.mapped) continue;
            std::string path = std::string(dir) + "/" + d.name + ".bin";
            FILE* f = fopen(path.c_str(), "wb");
            if (f) { fwrite(d.mapped, 1, (size_t)d.size, f); fclose(f); }
            vkUnmapMemory(device, d.stage.memory);
            d.mapped = nullptr;
            destroyBuffer(d.stage);
        }
        dumpEntries.clear();
    }

    uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties) {
        VkPhysicalDeviceMemoryProperties memProperties;
        vkGetPhysicalDeviceMemoryProperties(physDev, &memProperties);

                                                               
        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
            if ((typeFilter & (1 << i)) && ((memProperties.memoryTypes[i].propertyFlags & properties) == properties)) {
                if (memProperties.memoryHeaps[memProperties.memoryTypes[i].heapIndex].flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) {
                    return i;
                }
            }
        }

                                           
        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
            if ((typeFilter & (1 << i)) && ((memProperties.memoryTypes[i].propertyFlags & properties) == properties)) {
                return i;
            }
        }
        return 0;
    }

    bool createBuffer(VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties, AllocatedBuffer& outBuf) {
        VkBufferCreateInfo bufferInfo = {VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        bufferInfo.size = size;
        bufferInfo.usage = usage | (getenv("NSS_DUMP_LAYERS") ? VK_BUFFER_USAGE_TRANSFER_SRC_BIT : 0);
        bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

        if (vkCreateBuffer(device, &bufferInfo, nullptr, &outBuf.buffer) != VK_SUCCESS) {
            return false;
        }

        VkMemoryRequirements memRequirements;
        vkGetBufferMemoryRequirements(device, outBuf.buffer, &memRequirements);

        VkMemoryAllocateInfo allocInfo = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, properties);

        if (vkAllocateMemory(device, &allocInfo, nullptr, &outBuf.memory) != VK_SUCCESS) {
            return false;
        }

        vkBindBufferMemory(device, outBuf.buffer, outBuf.memory, 0);
        outBuf.size = size;
        return true;
    }

    void destroyBuffer(AllocatedBuffer& b) {
        if (b.buffer != VK_NULL_HANDLE) {
            vkDestroyBuffer(device, b.buffer, nullptr);
            b.buffer = VK_NULL_HANDLE;
        }
        if (b.memory != VK_NULL_HANDLE) {
            vkFreeMemory(device, b.memory, nullptr);
            b.memory = VK_NULL_HANDLE;
        }
        b.size = 0;
    }

    VkShaderModule createShaderModule(const uint32_t* spvCode, size_t size) {
        VkShaderModuleCreateInfo createInfo = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        createInfo.codeSize = size;
        createInfo.pCode = spvCode;
        VkShaderModule module;
        if (vkCreateShaderModule(device, &createInfo, nullptr, &module) != VK_SUCCESS) {
            return VK_NULL_HANDLE;
        }
        return module;
    }

                                                                                     
    static void engineLog(const char* fmt, uint32_t a, uint32_t b, const char* c) {
        FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
        if (lf) {
            fprintf(lf, fmt, a, b, c);
            fclose(lf);
        }
    }

    NssCoopShape coopShape;
    bool genericCoop = false;
    bool coopMatInt8Supported() {
        const bool ok = nssQueryCoopShape(instance, physDev, coopShape);
        genericCoop = ok && (!coopShape.native16() || getenv("NSS_COOP_GENERIC") != nullptr);
        return ok;
    }

    const bool fuseResize = (getenv("NSS_NO_FUSE") == nullptr);                                            
    uint32_t coopLocalSize = 32;                                                                         

    void resolveBackend(NssBackendType requested) {
                                                                                                      
                                                                                 
        VkPhysicalDeviceSubgroupSizeControlProperties sc = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES};
        VkPhysicalDeviceSubgroupProperties sg = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES};
        sg.pNext = &sc;
        VkPhysicalDeviceProperties2 props2 = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2};
        props2.pNext = &sg;
        vkGetPhysicalDeviceProperties2(physDev, &props2);

        const bool coopOk = coopMatInt8Supported();
                                                                                       
                                                                                          
        NssBackendType chosen = NSS_BACKEND_DP4A;
        if (requested != NSS_BACKEND_DP4A && coopOk)
            chosen = NSS_BACKEND_COOPMAT;

                                                        
        if (const char* f = getenv("NSS_FORCE_BACKEND")) {
            if (strcmp(f, "coopmat") == 0) chosen = NSS_BACKEND_COOPMAT;
            else if (strcmp(f, "dp4a") == 0) chosen = NSS_BACKEND_DP4A;
        }
        if (chosen == NSS_BACKEND_COOPMAT && !coopOk) chosen = NSS_BACKEND_DP4A;                                                    
        backend = chosen;
        if (FILE* log = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
            fprintf(log, "[NSS Engine] INT8 shape %ux%ux%u generic=%d\n", coopShape.m, coopShape.n, coopShape.k, int(genericCoop));
            fclose(log);
        }
        coopLocalSize = (getenv("NSS_REQUIRE_WAVE32") != nullptr) ? 32u : sg.subgroupSize;

        FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
        if (lf) {
            fprintf(lf, "[NSS Engine] subgroup default=%u min=%u max=%u coopmat_int8=%d -> backend=%s\n",
                    sg.subgroupSize, sc.minSubgroupSize, sc.maxSubgroupSize, coopOk ? 1 : 0,
                    chosen == NSS_BACKEND_COOPMAT ? "COOPMAT" : "DP4A");
            fclose(lf);
        }
    }

    bool init(const NssEngineConfig* config) {
        instance = config->instance;
        physDev  = config->physicalDevice;
        device   = config->device;
        quality  = config->quality;

        useV2Model = (quality == NSS_QUALITY_HIGH) && getenv("NSS_V2_MODEL") != nullptr &&
                     getenv("NSS_V2_MODEL")[0] != '0';
        if (quality == NSS_QUALITY_HIGH) {
            layers = useV2Model ? g_nss_high_v2_layers : g_nss_high_layers;
        } else {
            layers = g_nss_mid_low_layers;
        }

        resolveBackend(config->backend);

                                                                                                                 
        VkDescriptorSetLayoutBinding bindingsConv2D[8];
        for (uint32_t i = 0; i < 8; ++i) {
            bindingsConv2D[i].binding = i;
            bindingsConv2D[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            bindingsConv2D[i].descriptorCount = 1;
            bindingsConv2D[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindingsConv2D[i].pImmutableSamplers = nullptr;
        }
        VkDescriptorSetLayoutCreateInfo dslInfoConv2D = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dslInfoConv2D.bindingCount = 8;
        dslInfoConv2D.pBindings = bindingsConv2D;
        vkCreateDescriptorSetLayout(device, &dslInfoConv2D, nullptr, &dslConv2D);

        VkPushConstantRange pcrConv2D = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PushConstantConv2D)};
        VkPipelineLayoutCreateInfo plInfoConv2D = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plInfoConv2D.setLayoutCount = 1;
        plInfoConv2D.pSetLayouts = &dslConv2D;
        plInfoConv2D.pushConstantRangeCount = 1;
        plInfoConv2D.pPushConstantRanges = &pcrConv2D;
        vkCreatePipelineLayout(device, &plInfoConv2D, nullptr, &layoutConv2D);

                                                                           
        VkDescriptorSetLayoutBinding bindingsResize[2];
        for (uint32_t i = 0; i < 2; ++i) {
            bindingsResize[i].binding = i;
            bindingsResize[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            bindingsResize[i].descriptorCount = 1;
            bindingsResize[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindingsResize[i].pImmutableSamplers = nullptr;
        }
        VkDescriptorSetLayoutCreateInfo dslInfoResize = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dslInfoResize.bindingCount = 2;
        dslInfoResize.pBindings = bindingsResize;
        vkCreateDescriptorSetLayout(device, &dslInfoResize, nullptr, &dslResize);

        VkPushConstantRange pcrResize = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PushConstantResize)};
        VkPipelineLayoutCreateInfo plInfoResize = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plInfoResize.setLayoutCount = 1;
        plInfoResize.pSetLayouts = &dslResize;
        plInfoResize.pushConstantRangeCount = 1;
        plInfoResize.pPushConstantRanges = &pcrResize;
        vkCreatePipelineLayout(device, &plInfoResize, nullptr, &layoutResize);

                                                                                 
        VkDescriptorSetLayoutBinding bindingsConcat[3];
        for (uint32_t i = 0; i < 3; ++i) {
            bindingsConcat[i].binding = i;
            bindingsConcat[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            bindingsConcat[i].descriptorCount = 1;
            bindingsConcat[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindingsConcat[i].pImmutableSamplers = nullptr;
        }
        VkDescriptorSetLayoutCreateInfo dslInfoConcat = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dslInfoConcat.bindingCount = 3;
        dslInfoConcat.pBindings = bindingsConcat;
        vkCreateDescriptorSetLayout(device, &dslInfoConcat, nullptr, &dslConcat);

        VkPushConstantRange pcrConcat = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PushConstantConcat)};
        VkPipelineLayoutCreateInfo plInfoConcat = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plInfoConcat.setLayoutCount = 1;
        plInfoConcat.pSetLayouts = &dslConcat;
        plInfoConcat.pushConstantRangeCount = 1;
        plInfoConcat.pPushConstantRanges = &pcrConcat;
        vkCreatePipelineLayout(device, &plInfoConcat, nullptr, &layoutConcat);

                                      
                                                                                                                    
                                                                                            
                                                                       
        const bool wantCoop = (backend == NSS_BACKEND_COOPMAT);
        const bool wantFastCoop = wantCoop && !genericCoop;
        VkShaderModule modConv2D           = wantCoop ? (genericCoop ? createShaderModule(g_spv_conv_coop_generic_nss, g_spv_conv_coop_generic_nss_size) : createShaderModule(g_spv_conv2d_fused_coopmat, g_spv_conv2d_fused_coopmat_size)) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_Coop_S1   = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_s1, g_spv_conv2d_fused_coopmat_s1_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_Coop2D    = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_2d, g_spv_conv2d_fused_coopmat_2d_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_CoopPT2   = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_pt2, g_spv_conv2d_fused_coopmat_pt2_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_Coop_C16 = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_c16, g_spv_conv2d_fused_coopmat_c16_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_Coop_C32 = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_c32, g_spv_conv2d_fused_coopmat_c32_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_Coop_C32_PT2 = wantFastCoop ? createShaderModule(g_spv_conv2d_fused_coopmat_c32_pt2, g_spv_conv2d_fused_coopmat_c32_pt2_size) : VK_NULL_HANDLE;
        VkShaderModule modConv2D_C4        = createShaderModule(g_spv_conv2d_fused_c4, g_spv_conv2d_fused_c4_size);
        VkShaderModule modConv2D_DP4a_C16  = createShaderModule(g_spv_conv2d_fused_dp4a_c16, g_spv_conv2d_fused_dp4a_c16_size);
        VkShaderModule modConv2D_DP4a      = createShaderModule(g_spv_conv2d_fused_dp4a, g_spv_conv2d_fused_dp4a_size);
        VkShaderModule modConv2D_DP4a_1440 = createShaderModule(g_spv_conv2d_fused_dp4a_1440, g_spv_conv2d_fused_dp4a_1440_size);
        VkShaderModule modConv2D_DP4a_2160 = createShaderModule(g_spv_conv2d_fused_dp4a_2160, g_spv_conv2d_fused_dp4a_2160_size);
        VkShaderModule modConv2D_DP4a_NarrowTiled = createShaderModule(g_spv_conv2d_fused_dp4a_narrow_tiled, g_spv_conv2d_fused_dp4a_narrow_tiled_size);
        VkShaderModule modConv2D_DP4a_TiledS1 = createShaderModule(g_spv_conv2d_fused_dp4a_tiled_s1, g_spv_conv2d_fused_dp4a_tiled_s1_size);
        VkShaderModule modConv2D_DP4a_TiledS2 = createShaderModule(g_spv_conv2d_fused_dp4a_tiled_s2, g_spv_conv2d_fused_dp4a_tiled_s2_size);
        VkShaderModule modConv2D_DP4a_TiledS1_T16 = createShaderModule(g_spv_conv2d_fused_dp4a_tiled_s1_t16, g_spv_conv2d_fused_dp4a_tiled_s1_t16_size);
        VkShaderModule modResize           = createShaderModule(g_spv_resize_nearest_2x, g_spv_resize_nearest_2x_size);
        VkShaderModule modConcat           = createShaderModule(g_spv_concat_channels, g_spv_concat_channels_size);
        VkShaderModule modPreprocess       = createShaderModule(g_spv_nss_preprocess, g_spv_nss_preprocess_size);
        VkShaderModule modPreprocess_1440  = createShaderModule(g_spv_nss_preprocess_1440, g_spv_nss_preprocess_1440_size);
        VkShaderModule modPreprocess_2160  = createShaderModule(g_spv_nss_preprocess_2160, g_spv_nss_preprocess_2160_size);
        VkShaderModule modPostprocess      = createShaderModule(g_spv_nss_postprocess, g_spv_nss_postprocess_size);
        VkShaderModule modPostprocess_1440 = createShaderModule(g_spv_nss_postprocess_1440, g_spv_nss_postprocess_1440_size);
        VkShaderModule modPostprocess_2160 = createShaderModule(g_spv_nss_postprocess_2160, g_spv_nss_postprocess_2160_size);

        VkComputePipelineCreateInfo pipeInfo = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        pipeInfo.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        pipeInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
        pipeInfo.stage.pName = "main";

                                                                                                                             
        int pipeFailures = 0;
        auto mkPipe = [&](VkPipeline* out, const char* name) {
                                                                                                                         
            VkResult r;
            const char* failList = getenv("NSS_TEST_FAIL_PIPE");
            if (failList && strstr(failList, name)) r = VK_ERROR_INITIALIZATION_FAILED;
            else r = vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipeInfo, nullptr, out);
            if (r != VK_SUCCESS) {
                *out = VK_NULL_HANDLE;
                ++pipeFailures;
                if (FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
                    fprintf(lf, "[NSS Engine] ERROR: vkCreateComputePipelines(%s) failed: VkResult=%d\n", name, (int)r);
                    fclose(lf);
                }
            }
        };

                                                                                                          
                                                   
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo reqSubgroup = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        reqSubgroup.requiredSubgroupSize = 32;
        if (getenv("NSS_REQUIRE_WAVE32")) {
            pipeInfo.stage.pNext = &reqSubgroup;
            pipeInfo.stage.flags = 0;
        }

                                                                         
        uint32_t coopSpecData[6] = {coopLocalSize, (getenv("NSS_NO_SLIDE") != nullptr) ? 0u : 1u,
            getenv("NSS_ABLATE") ? (uint32_t)atoi(getenv("NSS_ABLATE")) : 0u, coopShape.m, coopShape.n, coopShape.k};
        VkSpecializationMapEntry specEntries[6] = {};
        for (uint32_t i = 0; i < 6; ++i) specEntries[i] = {i, i * 4u, sizeof(uint32_t)};
        VkSpecializationInfo specInfo = {6, specEntries, sizeof(coopSpecData), coopSpecData};
        pipeInfo.stage.pSpecializationInfo = &specInfo;
        if (wantCoop) {
            pipeInfo.stage.module = modConv2D;
            pipeInfo.layout = layoutConv2D;
            mkPipe(&pipeConv2D, "pipeConv2D");
            if (modConv2D_Coop_S1 != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_Coop_S1;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_Coop_S1, "pipeConv2D_Coop_S1");
            }
            if (modConv2D_Coop2D != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_Coop2D;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_Coop2D, "pipeConv2D_Coop2D");
            }
            if (modConv2D_CoopPT2 != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_CoopPT2;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_CoopPT2, "pipeConv2D_CoopPT2");
            }
            if (modConv2D_Coop_C16 != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_Coop_C16;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_Coop_C16, "pipeConv2D_Coop_C16");
            }
            if (modConv2D_Coop_C32 != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_Coop_C32;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_Coop_C32, "pipeConv2D_Coop_C32");
            }
            if (modConv2D_Coop_C32_PT2 != VK_NULL_HANDLE) {
                pipeInfo.stage.module = modConv2D_Coop_C32_PT2;
                pipeInfo.layout = layoutConv2D;
                mkPipe(&pipeConv2D_Coop_C32_PT2, "pipeConv2D_Coop_C32_PT2");
            }
        }
        if (modConv2D_C4 != VK_NULL_HANDLE) {
            pipeInfo.stage.pSpecializationInfo = nullptr;
            pipeInfo.stage.module = modConv2D_C4;
            pipeInfo.layout = layoutConv2D;
            mkPipe(&pipeConv2D_C4, "pipeConv2D_C4");
        }
        if (modConv2D_DP4a_C16 != VK_NULL_HANDLE) {
            pipeInfo.stage.pSpecializationInfo = nullptr;
            pipeInfo.stage.module = modConv2D_DP4a_C16;
            pipeInfo.layout = layoutConv2D;
            mkPipe(&pipeConv2D_DP4a_C16, "pipeConv2D_DP4a_C16");
        }
        pipeInfo.stage.pSpecializationInfo = nullptr;

                                            
        {
        pipeInfo.stage.module = modConv2D_DP4a;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a, "pipeConv2D_DP4a");

        pipeInfo.stage.module = modConv2D_DP4a_1440;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_1440, "pipeConv2D_DP4a_1440");

        pipeInfo.stage.module = modConv2D_DP4a_2160;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_2160, "pipeConv2D_DP4a_2160");

        pipeInfo.stage.module = modConv2D_DP4a_NarrowTiled;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_NarrowTiled, "pipeConv2D_DP4a_NarrowTiled");

        pipeInfo.stage.module = modConv2D_DP4a_TiledS1;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_TiledS1, "pipeConv2D_DP4a_TiledS1");

        pipeInfo.stage.module = modConv2D_DP4a_TiledS2;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_TiledS2, "pipeConv2D_DP4a_TiledS2");

        pipeInfo.stage.module = modConv2D_DP4a_TiledS1_T16;
        pipeInfo.layout = layoutConv2D;
        mkPipe(&pipeConv2D_DP4a_TiledS1_T16, "pipeConv2D_DP4a_TiledS1_T16");
        }

        pipeInfo.stage.module = modResize;
        pipeInfo.layout = layoutResize;
        mkPipe(&pipeResize, "pipeResize");

        pipeInfo.stage.module = modConcat;
        pipeInfo.layout = layoutConcat;
        mkPipe(&pipeConcat, "pipeConcat");

                                           
        VkDescriptorSetLayoutBinding bindingsPre[5];
        for (int i = 0; i < 4; ++i) {
            bindingsPre[i].binding = i;
            bindingsPre[i].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            bindingsPre[i].descriptorCount = 1;
            bindingsPre[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindingsPre[i].pImmutableSamplers = nullptr;
        }
        bindingsPre[4].binding = 4;
        bindingsPre[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        bindingsPre[4].descriptorCount = 1;
        bindingsPre[4].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindingsPre[4].pImmutableSamplers = nullptr;

        VkDescriptorSetLayoutCreateInfo dslInfoPre = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dslInfoPre.bindingCount = 5;
        dslInfoPre.pBindings = bindingsPre;
        vkCreateDescriptorSetLayout(device, &dslInfoPre, nullptr, &dslPreprocess);

        VkPushConstantRange pcrPre = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PushConstantPreprocess)};
        VkPipelineLayoutCreateInfo plInfoPre = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plInfoPre.setLayoutCount = 1;
        plInfoPre.pSetLayouts = &dslPreprocess;
        plInfoPre.pushConstantRangeCount = 1;
        plInfoPre.pPushConstantRanges = &pcrPre;
        vkCreatePipelineLayout(device, &plInfoPre, nullptr, &layoutPreprocess);

        pipeInfo.stage.module = modPreprocess;
        pipeInfo.layout = layoutPreprocess;
        mkPipe(&pipePreprocess, "pipePreprocess");

        pipeInfo.stage.module = modPreprocess_1440;
        pipeInfo.layout = layoutPreprocess;
        mkPipe(&pipePreprocess_1440, "pipePreprocess_1440");

        pipeInfo.stage.module = modPreprocess_2160;
        pipeInfo.layout = layoutPreprocess;
        mkPipe(&pipePreprocess_2160, "pipePreprocess_2160");

                                            
        VkDescriptorSetLayoutBinding bindingsPost[7];
        for (int i = 0; i < 3; ++i) {
            bindingsPost[i].binding = i;
            bindingsPost[i].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            bindingsPost[i].descriptorCount = 1;
            bindingsPost[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            bindingsPost[i].pImmutableSamplers = nullptr;
        }
        bindingsPost[3].binding = 3;
        bindingsPost[3].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        bindingsPost[3].descriptorCount = 1;
        bindingsPost[3].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindingsPost[3].pImmutableSamplers = nullptr;

        bindingsPost[4].binding = 4;
        bindingsPost[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        bindingsPost[4].descriptorCount = 1;
        bindingsPost[4].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindingsPost[4].pImmutableSamplers = nullptr;

        bindingsPost[5].binding = 5;
        bindingsPost[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        bindingsPost[5].descriptorCount = 1;
        bindingsPost[5].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindingsPost[5].pImmutableSamplers = nullptr;

        bindingsPost[6].binding = 6;
        bindingsPost[6].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        bindingsPost[6].descriptorCount = 1;
        bindingsPost[6].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindingsPost[6].pImmutableSamplers = nullptr;

        VkDescriptorSetLayoutCreateInfo dslInfoPost = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dslInfoPost.bindingCount = 7;
        dslInfoPost.pBindings = bindingsPost;
        vkCreateDescriptorSetLayout(device, &dslInfoPost, nullptr, &dslPostprocess);

        VkPushConstantRange pcrPost = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(PushConstantPostprocess)};
        VkPipelineLayoutCreateInfo plInfoPost = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plInfoPost.setLayoutCount = 1;
        plInfoPost.pSetLayouts = &dslPostprocess;
        plInfoPost.pushConstantRangeCount = 1;
        plInfoPost.pPushConstantRanges = &pcrPost;
        vkCreatePipelineLayout(device, &plInfoPost, nullptr, &layoutPostprocess);

        pipeInfo.stage.module = modPostprocess;
        pipeInfo.layout = layoutPostprocess;
        mkPipe(&pipePostprocess, "pipePostprocess");

        pipeInfo.stage.module = modPostprocess_1440;
        pipeInfo.layout = layoutPostprocess;
        mkPipe(&pipePostprocess_1440, "pipePostprocess_1440");

        pipeInfo.stage.module = modPostprocess_2160;
        pipeInfo.layout = layoutPostprocess;
        mkPipe(&pipePostprocess_2160, "pipePostprocess_2160");

                  
        VkSamplerCreateInfo sampInfo = {VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
        sampInfo.magFilter = VK_FILTER_LINEAR;
        sampInfo.minFilter = VK_FILTER_LINEAR;
        sampInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        vkCreateSampler(device, &sampInfo, nullptr, &linearSampler);

        vkDestroyShaderModule(device, modConv2D, nullptr);
        if (modConv2D_Coop_S1 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_Coop_S1, nullptr);
        if (modConv2D_Coop2D != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_Coop2D, nullptr);
        if (modConv2D_CoopPT2 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_CoopPT2, nullptr);
        if (modConv2D_Coop_C16 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_Coop_C16, nullptr);
        if (modConv2D_Coop_C32 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_Coop_C32, nullptr);
        if (modConv2D_Coop_C32_PT2 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_Coop_C32_PT2, nullptr);
        if (modConv2D_C4 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_C4, nullptr);
        if (modConv2D_DP4a_C16 != VK_NULL_HANDLE) vkDestroyShaderModule(device, modConv2D_DP4a_C16, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_TiledS1_T16, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_TiledS2, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_TiledS1, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_NarrowTiled, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_1440, nullptr);
        vkDestroyShaderModule(device, modConv2D_DP4a_2160, nullptr);
        vkDestroyShaderModule(device, modResize, nullptr);
        vkDestroyShaderModule(device, modConcat, nullptr);
        vkDestroyShaderModule(device, modPreprocess, nullptr);
        vkDestroyShaderModule(device, modPreprocess_1440, nullptr);
        vkDestroyShaderModule(device, modPreprocess_2160, nullptr);
        vkDestroyShaderModule(device, modPostprocess, nullptr);
        vkDestroyShaderModule(device, modPostprocess_1440, nullptr);
        vkDestroyShaderModule(device, modPostprocess_2160, nullptr);

        {
            const bool haveDp4a = pipeConv2D_DP4a || pipeConv2D_DP4a_1440 || pipeConv2D_DP4a_2160;
            if (wantCoop && !pipeConv2D && haveDp4a) {
                backend = NSS_BACKEND_DP4A;                                                                          
                if (FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
                    fprintf(lf, "[NSS Engine] coopmat pipeline unavailable -> falling back to DP4A\n");
                    fclose(lf);
                }
            }
            const bool convOk = (backend == NSS_BACKEND_DP4A) ? haveDp4a : (pipeConv2D != VK_NULL_HANDLE);
            if (!convOk || !pipeResize || !pipeConcat) {
                if (FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
                    fprintf(lf, "[NSS Engine] ERROR: required compute pipelines missing (failures=%d) -> engine init fails\n", pipeFailures);
                    fclose(lf);
                }
                return false;
            }
        }

                                                                     
        const void* blob_src = (quality == NSS_QUALITY_HIGH)
            ? (useV2Model ? (const void*)g_nss_high_v2_blob : (const void*)g_nss_high_blob)
            : (const void*)g_nss_mid_low_blob;
        size_t      blob_sz  = (quality == NSS_QUALITY_HIGH)
            ? (useV2Model ? g_nss_high_v2_blob_size : g_nss_high_blob_size)
            : g_nss_mid_low_blob_size;

        std::vector<uint8_t> blob_fixed((const uint8_t*)blob_src, (const uint8_t*)blob_src + blob_sz);
        if (!useV2Model) {
                                                                                                 
                                                                                                    
                                                                                                   
                                                                                                  
                                                                                               
                                                                                            
            for (int l = 0; l < 14; ++l) {
                const uint32_t oc = layers[l].out_channels;
                const uint32_t ic = layers[l].in_channels;
                const uint32_t ic_tiles = (ic + 15) / 16, oc_tiles = (oc + 15) / 16;
                const int8_t* wt = (const int8_t*)blob_fixed.data() + layers[l].weight_tiled_offset;
                int32_t* bias = (int32_t*)(blob_fixed.data() + layers[l].bias_offset);
                for (uint32_t n = 0; n < oc; ++n) {
                    int64_t sum = 0;
                    const uint32_t oct = n / 16, nn = n % 16;
                    for (uint32_t ky = 0; ky < 3; ++ky)
                        for (uint32_t kx = 0; kx < 3; ++kx)
                            for (uint32_t ict = 0; ict < ic_tiles; ++ict)
                                for (uint32_t k = 0; k < 16; ++k)
                                    sum += wt[((((ky * 3 + kx) * ic_tiles + ict) * oc_tiles + oct) * 16 + k) * 16 + nn];
                    bias[n] += (int32_t)(128 * sum);
                }
            }
        }
        const void* blob_ptr = blob_fixed.data();

        AllocatedBuffer staging;
        createBuffer(blob_sz, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                     VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, staging);

        void* mapped = nullptr;
        vkMapMemory(device, staging.memory, 0, blob_sz, 0, &mapped);
        memcpy(mapped, blob_ptr, blob_sz);
        vkUnmapMemory(device, staging.memory);

        createBuffer(blob_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                     VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, modelBuffer);

                                                                              
                                                                                                      
                                                                                                                   
                               
                                                                                                                            
        destroyBuffer(staging);
        destroyBuffer(modelBuffer);

                                                                                                   
                                                                                                                 
        if (!createBuffer(blob_sz + 1024, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                          VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, modelBuffer)) {
            createBuffer(blob_sz + 1024, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, modelBuffer);
        }
        vkMapMemory(device, modelBuffer.memory, 0, blob_sz, 0, &mapped);
        if (mapped) {
            memcpy(mapped, blob_ptr, blob_sz);
            vkUnmapMemory(device, modelBuffer.memory);
        }

                                                                                 
        std::vector<uint8_t> dp4a_blob((const uint8_t*)blob_ptr, (const uint8_t*)blob_ptr + blob_sz);
        for (int l = 0; l < numConv; ++l) {
            size_t off = layers[l].weight_tiled_offset;
            size_t sz  = layers[l].weight_tiled_size;
            for (size_t t = 0; t < sz; t += 256) {
                const int8_t* src_tile = (const int8_t*)blob_ptr + off + t;
                uint32_t* dst_tile = (uint32_t*)(dp4a_blob.data() + off + t);
                for (int ic_sub = 0; ic_sub < 4; ++ic_sub) {
                    for (int oc = 0; oc < 16; ++oc) {
                        uint8_t b0 = (uint8_t)src_tile[(ic_sub * 4 + 0) * 16 + oc];
                        uint8_t b1 = (uint8_t)src_tile[(ic_sub * 4 + 1) * 16 + oc];
                        uint8_t b2 = (uint8_t)src_tile[(ic_sub * 4 + 2) * 16 + oc];
                        uint8_t b3 = (uint8_t)src_tile[(ic_sub * 4 + 3) * 16 + oc];
                        dst_tile[ic_sub * 16 + oc] = (uint32_t)b0 | ((uint32_t)b1 << 8) | ((uint32_t)b2 << 16) | ((uint32_t)b3 << 24);
                    }
                }
            }
        }

        destroyBuffer(modelBuffer_DP4a);
        if (!createBuffer(blob_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                          VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, modelBuffer_DP4a)) {
            createBuffer(blob_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, modelBuffer_DP4a);
        }
        mapped = nullptr;
        vkMapMemory(device, modelBuffer_DP4a.memory, 0, blob_sz, 0, &mapped);
        if (mapped) {
            memcpy(mapped, dp4a_blob.data(), blob_sz);
            vkUnmapMemory(device, modelBuffer_DP4a.memory);
        }

                                                                            
        VkDescriptorPoolSize poolSizes[3] = {
            {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 320},
            {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 50},
            {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 50}
        };
        VkDescriptorPoolCreateInfo poolInfo = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
        poolInfo.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
        poolInfo.maxSets = 120;
        poolInfo.poolSizeCount = 3;
        poolInfo.pPoolSizes = poolSizes;
        vkCreateDescriptorPool(device, &poolInfo, nullptr, &descPool);

        return true;
    }

    void freeIntermediateBuffers() {
        destroyBuffer(t_l1);
        destroyBuffer(t_l2_skip);
        destroyBuffer(t_l3);
        destroyBuffer(t_l4_skip);
        destroyBuffer(t_l5);
        destroyBuffer(t_l6);
        destroyBuffer(t_l7);
        destroyBuffer(t_up1);
        destroyBuffer(t_d1);
        destroyBuffer(t_cat1);
        destroyBuffer(t_d2);
        destroyBuffer(t_up2);
        destroyBuffer(t_d3);
        destroyBuffer(t_cat2);
        destroyBuffer(t_d4);
        destroyBuffer(t_d5);
        destroyBuffer(t_up3);
        dsInitialized = false;
    }

    bool setupResolution(uint32_t w, uint32_t h) {
        if (w == curInW && h == curInH && t_l1.buffer != VK_NULL_HANDLE) {
            return true;
        }

        freeIntermediateBuffers();

        curInW = w;
        curInH = h;

        uint32_t w2 = w / 2,  h2 = h / 2;
        uint32_t w4 = w / 4,  h4 = h / 4;
        uint32_t w8 = w / 8,  h8 = h / 8;

        VkBufferUsageFlags usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
        VkMemoryPropertyFlags props = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

        createBuffer(w2 * h2 * 32, usage, props, t_l1);
        createBuffer(w2 * h2 * 32, usage, props, t_l2_skip);
        createBuffer(w4 * h4 * 32, usage, props, t_l3);
        createBuffer(w4 * h4 * 32, usage, props, t_l4_skip);
        createBuffer(w8 * h8 * 64, usage, props, t_l5);
        createBuffer(w8 * h8 * 64, usage, props, t_l6);
        createBuffer(w8 * h8 * 32, usage, props, t_l7);
        if (!fuseResize && !useV2Model) createBuffer(w4 * h4 * 32, usage, props, t_up1);
        if (!useV2Model) createBuffer(w4 * h4 * 16, usage, props, t_d1);
        createBuffer(w4 * h4 * 32, usage, props, t_d2);
        if (!fuseResize && !useV2Model) createBuffer(w2 * h2 * 32, usage, props, t_up2);
        if (!useV2Model) createBuffer(w2 * h2 * 16, usage, props, t_d3);
        createBuffer(w2 * h2 * 16, usage, props, t_d4);
        createBuffer(w2 * h2 * 16, usage, props, t_d5);
        if (!fuseResize) createBuffer(w * h * 16,   usage, props, t_up3);

        return true;
    }

    void bufferBarrier(VkCommandBuffer cmd, VkBuffer buffer, VkDeviceSize size = VK_WHOLE_SIZE) {
        VkBufferMemoryBarrier bmb = {VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
        bmb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        bmb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        bmb.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        bmb.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        bmb.buffer = buffer;
        bmb.offset = 0;
        bmb.size = size;
        vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                             0, 0, nullptr, 1, &bmb, 0, nullptr);
    }

    void bakeDescriptorSetConv2D(VkDescriptorSet ds,
                                 const NssLayerParam& lp,
                                 VkBuffer in_buf, VkDeviceSize in_off,
                                 VkBuffer out_buf, VkDeviceSize out_off,
                                 VkBuffer in_buf2 = VK_NULL_HANDLE, VkDeviceSize in2_off = 0,
                                 VkBuffer weight_buf = VK_NULL_HANDLE)
    {
        VkBuffer actual_wbuf = (weight_buf != VK_NULL_HANDLE) ? weight_buf : modelBuffer.buffer;
        VkDescriptorBufferInfo bufInfos[8];
        bufInfos[0] = {in_buf, in_off, VK_WHOLE_SIZE};
        bufInfos[1] = {out_buf, out_off, VK_WHOLE_SIZE};
        bufInfos[2] = {actual_wbuf, lp.weight_tiled_offset, lp.weight_tiled_size};
        bufInfos[3] = {modelBuffer.buffer, lp.bias_offset, (VkDeviceSize)lp.out_channels * 4};
        bufInfos[4] = {modelBuffer.buffer, lp.mul_offset, (VkDeviceSize)lp.out_channels * 4};
        bufInfos[5] = {modelBuffer.buffer, lp.shift_offset, (VkDeviceSize)lp.out_channels * 4};
        bufInfos[6] = {modelBuffer.buffer, lp.has_table ? lp.table_offset : 0, 256};
        bufInfos[7] = {in_buf2 != VK_NULL_HANDLE ? in_buf2 : in_buf, in_buf2 != VK_NULL_HANDLE ? in2_off : in_off, VK_WHOLE_SIZE};

        VkWriteDescriptorSet writes[8];
        for (int i = 0; i < 8; ++i) {
            writes[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
            writes[i].dstSet = ds;
            writes[i].dstBinding = i;
            writes[i].descriptorCount = 1;
            writes[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            writes[i].pBufferInfo = &bufInfos[i];
        }
        vkUpdateDescriptorSets(device, 8, writes, 0, nullptr);
    }

    void bakeDescriptorSetResize(VkDescriptorSet ds, VkBuffer in_buf, VkBuffer out_buf) {
        VkDescriptorBufferInfo bufInfos[2];
        bufInfos[0] = {in_buf, 0, VK_WHOLE_SIZE};
        bufInfos[1] = {out_buf, 0, VK_WHOLE_SIZE};

        VkWriteDescriptorSet writes[2];
        for (int i = 0; i < 2; ++i) {
            writes[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
            writes[i].dstSet = ds;
            writes[i].dstBinding = i;
            writes[i].descriptorCount = 1;
            writes[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            writes[i].pBufferInfo = &bufInfos[i];
        }
        vkUpdateDescriptorSets(device, 2, writes, 0, nullptr);
    }

    void dispatchConv2D(VkCommandBuffer cmd,
                        VkDescriptorSet ds,
                        const NssLayerParam& lp,
                        uint32_t in_w, uint32_t in_h,
                        uint32_t out_w, uint32_t out_h,
                        uint32_t in1_channels = 0,
                        bool upsample = false,
                        bool forceDp4a = false,
                        int layerIdx = -1)
    {
        const bool useDp4a = (backend == NSS_BACKEND_DP4A) || forceDp4a;
                                                                                                 
                                                           
        static const bool tryNarrowTiled = getenv("NSS_OUT2_TILED") == nullptr || getenv("NSS_OUT2_TILED")[0] != '0';
                                                                                           
                                                                                           
                                                                                        
                                                    
                                                                                            
                                                                                             
                                                                                           
                                                                                           
                                                                                              
                                                                                         
        const bool narrowTiled = tryNarrowTiled && pipeConv2D_DP4a_NarrowTiled != VK_NULL_HANDLE && layerIdx >= 0 &&
                                  lp.stride_y == 1 && lp.stride_x == 1 && lp.pad_y == 1 && lp.pad_x == 1 &&
                                  lp.in_channels <= 16 && lp.out_channels < 16 && in1_channels == 0;
                                                                                              
                                                                                         
                                                                                             
                                                                                               
                                                                                                
                                                                                                  
                                                                                    
                                                                                                  
                                                                                                  
                                           
        static const bool tryTiledS1 = getenv("NSS_TILED_S1") == nullptr || getenv("NSS_TILED_S1")[0] != '0';
        const bool tiledS1 = tryTiledS1 && useDp4a && pipeConv2D_DP4a_TiledS1 != VK_NULL_HANDLE && layerIdx >= 0 &&
                              lp.stride_y == 1 && lp.stride_x == 1 && lp.pad_y == 1 && lp.pad_x == 1;
                                                                                                  
                                                                                               
        static const bool tryTile16 = getenv("NSS_TILE16") != nullptr;
        const bool tiledS1_t16 = tiledS1 && tryTile16 && pipeConv2D_DP4a_TiledS1_T16 != VK_NULL_HANDLE;
                                                                                                
                                                                                                
                                                                                                
                                                                                             
                                                                                         
        static const bool tryTiledS2 = getenv("NSS_TILED_S2") != nullptr;
        const bool tiledS2 = tryTiledS2 && useDp4a && pipeConv2D_DP4a_TiledS2 != VK_NULL_HANDLE && layerIdx >= 0 &&
                              lp.stride_y == 2 && lp.stride_x == 2 && lp.pad_y == 1 && lp.pad_x == 1;
                                                                                     
                                                                                           
                                                                                              
                                                                                
        if (narrowTiled || tiledS1 || tiledS2) ds = dsConv_DP4a[layerIdx];
                                                                                           
                                                                                               
                                                                                                    
                                                                                                    
                                                                                                 
                                                                                                  
                                                                                                     
                                                                                                     
                                                                                                      
                                                                                                  
                                                                                                      
                                                                                               
                                               
        static const bool tryC4 = getenv("NSS_C4") == nullptr || getenv("NSS_C4")[0] != '0';
        static const bool tryC16 = getenv("NSS_C16") == nullptr || getenv("NSS_C16")[0] != '0';
        VkPipeline activePipe = pipeConv2D;
        if (tryC4 && layerIdx == 13 && lp.out_channels == 4 && pipeConv2D_C4 != VK_NULL_HANDLE) {
            activePipe = pipeConv2D_C4;
            ds = dsConv_DP4a[13];
        } else if (tryC16 && useDp4a && lp.out_channels == 16 && in1_channels == 0 && pipeConv2D_DP4a_C16 != VK_NULL_HANDLE) {
            activePipe = pipeConv2D_DP4a_C16;
            ds = dsConv_DP4a[layerIdx];
        } else if (tiledS1_t16) {
            activePipe = pipeConv2D_DP4a_TiledS1_T16;
        } else if (tiledS1) {
            activePipe = pipeConv2D_DP4a_TiledS1;
        } else if (tiledS2) {
            activePipe = pipeConv2D_DP4a_TiledS2;
        } else if (narrowTiled || activePipe == pipeConv2D_C4) {
            activePipe = pipeConv2D_DP4a_NarrowTiled;
        } else if (useDp4a) {
            if (curInW >= 1920 || curInH >= 1080) {
                activePipe = pipeConv2D_DP4a_2160;
            } else if (curInW >= 1280 || curInH >= 720) {
                activePipe = pipeConv2D_DP4a_1440;
            } else {
                activePipe = pipeConv2D_DP4a;
            }
        } else if ((getenv("NSS_COOP_C16") == nullptr || getenv("NSS_COOP_C16")[0] != '0') &&
                   !useDp4a && lp.stride_y == 1 && lp.stride_x == 1 && lp.out_channels == 16 &&
                   pipeConv2D_Coop_C16 != VK_NULL_HANDLE) {
                                                                                                       
                                                                                                       
                                                                                                       
                                                                                                    
                                                                                                       
                                                                                                     
                                                                                                           
                                                                                                       
                                                                                                  
                                                                                                        
                                                                                                         
                                                                                                  
                                                                                                       
                                                                                                    
                                                                                                     
                                                                                                      
                                                                                                    
                                                                                                        
                                                                                                        
                                                                                                      
                                                                                                        
                                                                                                   
                                                                                                     
                                                                                                       
                                                                                                       
                                                                                                          
                            
            activePipe = pipeConv2D_Coop_C16;
        } else if (getenv("NSS_COOP_C32_PT2") != nullptr && !useDp4a && lp.out_channels == 32 &&
                   pipeConv2D_Coop_C32_PT2 != VK_NULL_HANDLE) {
                                                                                                 
                                                                                                  
                                                                                                  
                                                                                                  
                                                                                                    
                                                                                                    
                                                                                                   
                                                
                                                                                                 
                                                                                                 
                                                                                                   
                                                                                                 
                                                                                                
                                                                                               
                                                                                                 
                                                                                               
                                                                                                   
                                                                                                  
                                                                                                   
                                                                                                 
                                                                                                    
                                                                                                 
            activePipe = pipeConv2D_Coop_C32_PT2;
        } else if (getenv("NSS_COOP_C32") != nullptr && !useDp4a && lp.out_channels == 32 &&
                   pipeConv2D_Coop_C32 != VK_NULL_HANDLE) {
                                                                                                   
                                                                                                     
                                                                                                      
                                                                                                 
                                                                                                    
                                                                                                   
                                                                                                        
                                                                                                        
                                                                                                 
                                                                                                     
                                                                                                        
                                                                                                         
                                                                                          
                                     
                                                                                               
                                                                                                  
                                                                                                 
                                                                                                
                                                                                                    
                                                                                                
                                                                                                 
                                                                                                   
                                                                 
                                                                                                 
                                                                                                 
                                                                                                 
                                                                                                 
                                                                                                  
                                                                                                   
                                                                               
            activePipe = pipeConv2D_Coop_C32;
        } else if (getenv("NSS_COOP_S1") != nullptr && !useDp4a && lp.stride_y == 1 && lp.stride_x == 1 && pipeConv2D_Coop_S1 != VK_NULL_HANDLE) {
                                                                                                     
                                                                                                       
                                                                                                        
                                                                                                        
                                                                                                        
                                                                                                      
                                                                                                        
                                                                                                         
                                                                                                      
                                                                                                 
                                                               
                                                                                                    
                                                                                                      
                                                                                                      
                                                                                                          
                                                                                                       
                                                                                                         
                                      
            activePipe = pipeConv2D_Coop_S1;
        } else if (getenv("NSS_COOP_2D") != nullptr && !useDp4a && pipeConv2D_Coop2D != VK_NULL_HANDLE) {
                                                                                                    
                                                                                                     
                                                                                               
                                                    
                                                                                                 
                                                                                                
                                                                                                    
                                                                                                      
                                                                                                   
                                                                                                 
                                                                                                      
                                                                                                       
                                                                                                    
                                                                                                      
                                                                                                      
                                                                                                    
                                                                                                    
                                                                                  
            activePipe = pipeConv2D_Coop2D;
        } else if (getenv("NSS_COOP_PT2") != nullptr && !useDp4a && pipeConv2D_CoopPT2 != VK_NULL_HANDLE) {
                                                                                                    
                                                                                                     
                                                                                                   
                                                                                                      
                                                                                                         
                                                                                                         
                                                                              
                                                                                                        
                                                                                                        
                                                                                                      
                                                                                                      
                                                                                                     
                                                                                                      
                                                                                                   
                                                                                                       
                                                                                                        
                                                                                                        
                                                                                                        
                                                                                                    
                                                                                                     
                                    
            activePipe = pipeConv2D_CoopPT2;
        }
        if (activePipe == VK_NULL_HANDLE && useDp4a && !narrowTiled && !tiledS1 && !tiledS2) {                                                                                       
            activePipe = pipeConv2D_DP4a ? pipeConv2D_DP4a : (pipeConv2D_DP4a_1440 ? pipeConv2D_DP4a_1440 : pipeConv2D_DP4a_2160);
        }
                                                                                                          
                                                                                                        
                                                                                                         
                                                                                                     
                                                                                                
        const char* pipeName =
            activePipe == pipeConv2D ? "coopmat_default" :
            activePipe == pipeConv2D_Coop_C16 ? "coopmat_C16" :
            activePipe == pipeConv2D_Coop_C32 ? "coopmat_C32" :
            activePipe == pipeConv2D_Coop_C32_PT2 ? "coopmat_C32_PT2" :
                         activePipe == pipeConv2D_Coop_S1 ? "coopmat_S1" :
            activePipe == pipeConv2D_Coop2D ? "coopmat_2D" :
            activePipe == pipeConv2D_CoopPT2 ? "coopmat_PT2" :
            activePipe == pipeConv2D_C4 ? "dp4a_C4" :
            activePipe == pipeConv2D_DP4a_C16 ? "dp4a_C16" :
            activePipe == pipeConv2D_DP4a_NarrowTiled ? "dp4a_narrowTiled" :
            activePipe == pipeConv2D_DP4a_TiledS1 ? "dp4a_tiledS1" :
            activePipe == pipeConv2D_DP4a_TiledS1_T16 ? "dp4a_tiledS1_t16" :
            activePipe == pipeConv2D_DP4a_TiledS2 ? "dp4a_tiledS2" :
            activePipe == pipeConv2D_DP4a ? "dp4a_default" :
            activePipe == pipeConv2D_DP4a_1440 ? "dp4a_1440" :
            activePipe == pipeConv2D_DP4a_2160 ? "dp4a_2160" :
            activePipe == VK_NULL_HANDLE ? "NULL!!" : "UNKNOWN!!";
        nss_trace("  engine conv %s pipe=%s(%p) ds=%p in=%ux%u out=%ux%u", lp.name, pipeName, (void*) activePipe, (void*) ds, in_w, in_h, out_w, out_h);
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, activePipe);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, layoutConv2D, 0, 1, &ds, 0, nullptr);

        PushConstantConv2D pc;
        pc.in_width      = in_w;
        pc.in_height     = in_h;
        pc.out_width     = out_w;
        pc.out_height    = out_h;
        pc.in_channels   = lp.in_channels;
        pc.out_channels  = lp.out_channels;
        pc.pad_y         = lp.pad_y;
        pc.pad_x         = lp.pad_x;
        pc.stride_y      = lp.stride_y;
        pc.stride_x      = lp.stride_x;
        pc.out_zp        = (lp.out_zp == 128) ? -128 : lp.out_zp;                                   
        pc.has_table     = lp.has_table;
        pc.in1_channels  = in1_channels;
        pc.upsample      = upsample ? 1u : 0u;

        vkCmdPushConstants(cmd, layoutConv2D, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);

        uint32_t groupX, groupY, groupZ = 1;
                                                                                              
                                                                                                    
                                                                                                   
                                                                                                    
                                                                                                   
                                                                                                    
                                                                                                
                                                                                               
                                                                                               
                                                                                                   
                                      
        if (genericCoop && activePipe == pipeConv2D) {
            groupX = (out_w * out_h + coopShape.m - 1) / coopShape.m;
            groupY = (lp.out_channels + coopShape.n - 1) / coopShape.n;
        } else if (activePipe == pipeConv2D_C4 || activePipe == pipeConv2D_DP4a_NarrowTiled) {
                                                                                                   
            groupX = (out_w + 7u) / 8u;
            groupY = (out_h + 7u) / 8u;
        } else if (activePipe == pipeConv2D_DP4a_C16) {
            groupX = (out_w + 15u) / 16u;
            groupY = (out_h + 3u) / 4u;
        } else if (tiledS1_t16) {
            groupX = (out_w + 15u) / 16u;
            groupY = (out_h + 15u) / 16u;
            const uint32_t ocTilesPerGroup = 2u;
            groupZ = (((lp.out_channels + 15) / 16) + ocTilesPerGroup - 1) / ocTilesPerGroup;
        } else if (activePipe == pipeConv2D_Coop2D) {
                                                                                                        
            groupX = (out_w + 15u) / 16u;
            groupY = (out_h + 3u) / 4u;
            const uint32_t ocTilesPerGroup = 2u;
            groupZ = (((lp.out_channels + 15) / 16) + ocTilesPerGroup - 1) / ocTilesPerGroup;
        } else if (activePipe == pipeConv2D_CoopPT2 || activePipe == pipeConv2D_Coop_C32_PT2) {
                                                                                                     
                                                                                                      
                                                                                                
                                                                                                  
                                                                                            
            groupX = ((out_w + 15u) / 16u) * ((out_h + 1u) / 2u);
            const uint32_t ocTilesPerGroup = 2u;
            groupY = (((lp.out_channels + 15) / 16) + ocTilesPerGroup - 1) / ocTilesPerGroup;
        } else if (tiledS1 || tiledS2) {
                                                                                                
                                        
            groupX = (out_w + 7u) / 8u;
            groupY = (out_h + 7u) / 8u;
            const uint32_t ocTilesPerGroup = 2u;
            groupZ = (((lp.out_channels + 15) / 16) + ocTilesPerGroup - 1) / ocTilesPerGroup;
        } else {
                                                                                             
            const uint32_t pixPerGroup = 64u;                                            
            groupX = (out_w * out_h + pixPerGroup - 1) / pixPerGroup;
            if (!useDp4a)                                                             
                groupX = ((out_w + 15u) / 16u) * ((out_h + 3u) / 4u);
                                                                                            
            const uint32_t ocTilesPerGroup = 2u;                                                         
            groupY = (((lp.out_channels + 15) / 16) + ocTilesPerGroup - 1) / ocTilesPerGroup;
        }
        vkCmdDispatch(cmd, groupX, groupY, groupZ);
        profMark(cmd, lp.name);
    }

    void dispatchResize(VkCommandBuffer cmd, VkDescriptorSet ds,
                        uint32_t in_w, uint32_t in_h, uint32_t c)
    {
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipeResize);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, layoutResize, 0, 1, &ds, 0, nullptr);

        uint32_t out_w = in_w * 2;
        uint32_t out_h = in_h * 2;

        PushConstantResize pc;
        pc.in_width   = in_w;
        pc.in_height  = in_h;
        pc.out_width  = out_w;
        pc.out_height = out_h;
        pc.channels   = c;
        vkCmdPushConstants(cmd, layoutResize, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);

        uint32_t total_out_pixels = out_w * out_h;
        vkCmdDispatch(cmd, (total_out_pixels + 63) / 64, 1, 1);
        profMark(cmd, "resize");
    }

    void dispatchInference(VkCommandBuffer cmd,
                           VkBuffer in_buf, VkDeviceSize in_off,
                           VkBuffer out_kpn, VkDeviceSize kpn_off,
                           VkBuffer out_feedback, VkDeviceSize feedback_off)
    {
        static const bool layerProfile = getenv("NSS_LAYER_PROFILE") != nullptr;
        if (layerProfile && qpLayerProfile != VK_NULL_HANDLE) {
                                                                                                    
            uint64_t ts[15] = {};
            VkResult qr = vkGetQueryPoolResults(device, qpLayerProfile, 0, 15, sizeof(ts), ts, sizeof(uint64_t),
                                                 VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT);
            if (qr == VK_SUCCESS) {
                static const char* names[14] = {"L1","L2","L3","L4","L5","L6","L7","D1","D2","KPN","D3","D4","D5","Out2"};
                double total = (double)(ts[14] - ts[0]) * layerProfileTsPeriod / 1e6;
                nss_trace("== NSS layer profile (ms) total=%.4f ==", total);
                for (int i = 0; i < 14; ++i) {
                    double ms = (double)(ts[i + 1] - ts[i]) * layerProfileTsPeriod / 1e6;
                    nss_trace("  %-5s %.4f ms", names[i], ms);
                }
            }
        }

        profBegin(cmd);
        captureInput(cmd, in_buf, in_off);
        if (!dsInitialized || lastInBuf != in_buf || lastKpnBuf != out_kpn || lastFeedbackBuf != out_feedback) {
            vkResetDescriptorPool(device, descPool, 0);

                                                                                                    
            VkDescriptorSetLayout layoutsConv[kMaxConv];
            for (int i = 0; i < kMaxConv; ++i) layoutsConv[i] = dslConv2D;
            VkDescriptorSetAllocateInfo allocConv = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
            allocConv.descriptorPool = descPool;
            allocConv.descriptorSetCount = numConv;
            allocConv.pSetLayouts = layoutsConv;
            vkAllocateDescriptorSets(device, &allocConv, dsConv);

                                              
            vkAllocateDescriptorSets(device, &allocConv, dsConv_DP4a);

                                         
            VkDescriptorSetLayout layoutsResize[3] = {dslResize, dslResize, dslResize};
            VkDescriptorSetAllocateInfo allocResize = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
            allocResize.descriptorPool = descPool;
            allocResize.descriptorSetCount = 3;
            allocResize.pSetLayouts = layoutsResize;
            vkAllocateDescriptorSets(device, &allocResize, dsResize);

                                                   
            auto bakeBoth = [&](int idx, const NssLayerParam& lp, VkBuffer in_b, VkDeviceSize in_o, VkBuffer out_b, VkDeviceSize out_o, VkBuffer in_b2 = VK_NULL_HANDLE, VkDeviceSize in2_o = 0) {
                bakeDescriptorSetConv2D(dsConv[idx], lp, in_b, in_o, out_b, out_o, in_b2, in2_o, modelBuffer.buffer);
                bakeDescriptorSetConv2D(dsConv_DP4a[idx], lp, in_b, in_o, out_b, out_o, in_b2, in2_o, modelBuffer_DP4a.buffer);
            };

            bakeBoth(0, layers[0], in_buf, in_off, t_l1.buffer, 0);
            if (useV2Model) {
                                                                                      
                bakeBoth(1, layers[1], t_l1.buffer, 0, t_l2_skip.buffer, 0);
                bakeBoth(2, layers[2], t_l2_skip.buffer, 0, t_l3.buffer, 0);
                bakeBoth(3, layers[3], t_l3.buffer, 0, t_l4_skip.buffer, 0);
                bakeBoth(4, layers[4], t_l4_skip.buffer, 0, t_l5.buffer, 0);
                bakeBoth(5, layers[5], t_l5.buffer, 0, t_l6.buffer, 0);
                bakeBoth(6, layers[6], t_l6.buffer, 0, t_l7.buffer, 0);
                                                                                              
                bakeBoth(8, layers[8], t_l7.buffer, 0, t_d2.buffer, 0, t_l4_skip.buffer, 0);
                bakeBoth(9, layers[9], t_d2.buffer, 0, out_kpn, kpn_off);
                                                                                                 
                bakeBoth(11, layers[11], t_d2.buffer, 0, t_d4.buffer, 0, t_l2_skip.buffer, 0);
                                          
                bakeBoth(12, layers[12], t_d4.buffer, 0, t_d5.buffer, 0);
            } else {
                bakeBoth(1, layers[1], t_l1.buffer, 0, t_l2_skip.buffer, 0);
                bakeBoth(2, layers[2], t_l2_skip.buffer, 0, t_l3.buffer, 0);
                bakeBoth(3, layers[3], t_l3.buffer, 0, t_l4_skip.buffer, 0);
                bakeBoth(4, layers[4], t_l4_skip.buffer, 0, t_l5.buffer, 0);
                bakeBoth(5, layers[5], t_l5.buffer, 0, t_l6.buffer, 0);
                bakeBoth(6, layers[6], t_l6.buffer, 0, t_l7.buffer, 0);
                if (!fuseResize) bakeDescriptorSetResize(dsResize[0], t_l7.buffer, t_up1.buffer);
                bakeBoth(7, layers[7], fuseResize ? t_l7.buffer : t_up1.buffer, 0, t_d1.buffer, 0);
                bakeBoth(8, layers[8], t_d1.buffer, 0, t_d2.buffer, 0, t_l4_skip.buffer, 0);
                bakeBoth(9, layers[9], t_d2.buffer, 0, out_kpn, kpn_off);
                if (!fuseResize) bakeDescriptorSetResize(dsResize[1], t_d2.buffer, t_up2.buffer);
                bakeBoth(10, layers[10], fuseResize ? t_d2.buffer : t_up2.buffer, 0, t_d3.buffer, 0);
                bakeBoth(11, layers[11], t_d3.buffer, 0, t_d4.buffer, 0, t_l2_skip.buffer, 0);
                bakeBoth(12, layers[12], t_d4.buffer, 0, t_d5.buffer, 0);
            }

            if (!fuseResize) bakeDescriptorSetResize(dsResize[2], t_d5.buffer, t_up3.buffer);
            bakeBoth(13, layers[13], fuseResize ? t_d5.buffer : t_up3.buffer, 0, out_feedback, feedback_off);

            lastInBuf = in_buf;
            lastKpnBuf = out_kpn;
            lastFeedbackBuf = out_feedback;
            dsInitialized = true;
        }

        auto getConvDs = [&](int idx) {
            return (backend == NSS_BACKEND_DP4A) ? dsConv_DP4a[idx] : dsConv[idx];
        };

        uint32_t w = curInW,  h = curInH;
        uint32_t w2 = w / 2,  h2 = h / 2;
        uint32_t w4 = w / 4,  h4 = h / 4;
        uint32_t w8 = w / 8,  h8 = h / 8;

        VkQueryPool qpLP = VK_NULL_HANDLE;
        if (layerProfile) {
            if (qpLayerProfile == VK_NULL_HANDLE) {
                VkPhysicalDeviceProperties props{};
                vkGetPhysicalDeviceProperties(physDev, &props);
                layerProfileTsPeriod = props.limits.timestampPeriod;
                VkQueryPoolCreateInfo qi = { VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO };
                qi.queryType = VK_QUERY_TYPE_TIMESTAMP;
                qi.queryCount = 15;
                vkCreateQueryPool(device, &qi, nullptr, &qpLayerProfile);
            }
            qpLP = qpLayerProfile;
            vkCmdResetQueryPool(cmd, qpLP, 0, 15);
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, qpLP, 0);
        }
        auto markLayer = [&](int i) { if (qpLP) vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, qpLP, i + 1); };

                                                           
        dispatchConv2D(cmd, getConvDs(0), layers[0], w, h, w2, h2, 0, false, false, 0);
        bufferBarrier(cmd, t_l1.buffer);
        markLayer(0);

                                                                  
        dispatchConv2D(cmd, getConvDs(1), layers[1], w2, h2, w2, h2, 0, false, false, 1);
        bufferBarrier(cmd, t_l2_skip.buffer);
        markLayer(1);

                                                                  
        dispatchConv2D(cmd, getConvDs(2), layers[2], w2, h2, w4, h4, 0, false, false, 2);
        bufferBarrier(cmd, t_l3.buffer);
        markLayer(2);

                                                                  
        dispatchConv2D(cmd, getConvDs(3), layers[3], w4, h4, w4, h4, 0, false, false, 3);
        bufferBarrier(cmd, t_l4_skip.buffer);
        markLayer(3);

                                                                  
        dispatchConv2D(cmd, getConvDs(4), layers[4], w4, h4, w8, h8, 0, false, false, 4);
        bufferBarrier(cmd, t_l5.buffer);
        markLayer(4);

                                                             
        dispatchConv2D(cmd, getConvDs(5), layers[5], w8, h8, w8, h8, 0, false, false, 5);
        bufferBarrier(cmd, t_l6.buffer);
        markLayer(5);

                                                             
        dispatchConv2D(cmd, getConvDs(6), layers[6], w8, h8, w8, h8, 0, false, false, 6);
        bufferBarrier(cmd, t_l7.buffer);
        markLayer(6);

                                                                                                              
                                                                                                    
        if (!useV2Model) {
            if (!fuseResize) { dispatchResize(cmd, dsResize[0], w8, h8, 32); bufferBarrier(cmd, t_up1.buffer); }
            dispatchConv2D(cmd, getConvDs(7), layers[7], w4, h4, w4, h4, 0, fuseResize, false, 7);
            bufferBarrier(cmd, t_d1.buffer);
        }
        markLayer(7);

                                                                                
                                                                                                                          
        dispatchConv2D(cmd, getConvDs(8), layers[8], w4, h4, w4, h4, useV2Model ? 32 : 16, useV2Model, false, 8);
        bufferBarrier(cmd, t_d2.buffer);
        markLayer(8);

                                                    
                                                                           
        dispatchConv2D(cmd, getConvDs(9), layers[9], w4, h4, w4, h4, 0, false, false, 9);
        markLayer(9);

                                          
                                                                               
        if (!fuseResize && !useV2Model) { dispatchResize(cmd, dsResize[1], w4, h4, 32); bufferBarrier(cmd, t_up2.buffer); }
        if (!useV2Model) {
                                                                                               
            dispatchConv2D(cmd, getConvDs(10), layers[10], w2, h2, w2, h2, 0, fuseResize, false, 10);
            bufferBarrier(cmd, t_d3.buffer);
        }
        markLayer(10);                                                   

                                                                                                   
                                                                                                     
        dispatchConv2D(cmd, getConvDs(11), layers[11], w2, h2, w2, h2, useV2Model ? 32 : 16, useV2Model, false, 11);
        bufferBarrier(cmd, t_d4.buffer);
        markLayer(11);

                                              
        dispatchConv2D(cmd, getConvDs(12), layers[12], w2, h2, w2, h2, 0, false, false, 12);
        bufferBarrier(cmd, t_d5.buffer);
        markLayer(12);

                                              
                                                                                                                    
        if (!fuseResize) { dispatchResize(cmd, dsResize[2], w2, h2, 16); bufferBarrier(cmd, t_up3.buffer); }
                                                                                                       
        static const bool out2Coop = getenv("NSS_OUT2_COOP") != nullptr;
        const bool out2Dp4a = (backend == NSS_BACKEND_COOPMAT) && !out2Coop;
        dispatchConv2D(cmd, out2Dp4a ? dsConv_DP4a[13] : getConvDs(13), layers[13], w, h, w, h, 0, fuseResize, out2Dp4a, 13);
        markLayer(13);

        if (getenv("NSS_DUMP_LAYERS"))
            dumpRecordAll(cmd, in_buf, in_off, out_kpn, kpn_off, out_feedback, feedback_off);
    }

    bool setupFramePipeline(uint32_t in_w, uint32_t in_h, uint32_t disp_w, uint32_t disp_h) {
        if (in_w == curInW && in_h == curInH && disp_w == curDisplayW && disp_h == curDisplayH && historyImage != VK_NULL_HANDLE) {
            return true;
        }

                                                      
        if (!setupResolution(in_w, in_h)) {
            return false;
        }

                                       
                                                  
        VkDeviceSize in_tensor_sz = (VkDeviceSize)in_w * in_h * 12;
        destroyBuffer(t_frame_in_tensor);
        createBuffer(in_tensor_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, t_frame_in_tensor);

                                                                                                
        uint32_t kpn_c = (quality == NSS_QUALITY_HIGH) ? 36 : 16;
        VkDeviceSize kpn_sz = (VkDeviceSize)((in_w + 3)/4) * ((in_h + 3)/4) * kpn_c;
        destroyBuffer(t_frame_kpn_tensor);
        createBuffer(kpn_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, t_frame_kpn_tensor);

                                                       
        VkDeviceSize fdbk_sz = (VkDeviceSize)in_w * in_h * 4;
        destroyBuffer(t_frame_feedback);
        createBuffer(fdbk_sz, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, t_frame_feedback);

                                                             
        if (historyView != VK_NULL_HANDLE) {
            vkDestroyImageView(device, historyView, nullptr);
            historyView = VK_NULL_HANDLE;
        }
        if (historyImage != VK_NULL_HANDLE) {
            vkDestroyImage(device, historyImage, nullptr);
            historyImage = VK_NULL_HANDLE;
        }
        if (historyMemory != VK_NULL_HANDLE) {
            vkFreeMemory(device, historyMemory, nullptr);
            historyMemory = VK_NULL_HANDLE;
        }

        VkImageCreateInfo imgInfo = {VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
        imgInfo.imageType = VK_IMAGE_TYPE_2D;
        imgInfo.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        imgInfo.extent.width = disp_w;
        imgInfo.extent.height = disp_h;
        imgInfo.extent.depth = 1;
        imgInfo.mipLevels = 1;
        imgInfo.arrayLayers = 1;
        imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
        imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
        imgInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_STORAGE_BIT;
        imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        vkCreateImage(device, &imgInfo, nullptr, &historyImage);

        VkMemoryRequirements memReq;
        vkGetImageMemoryRequirements(device, historyImage, &memReq);
        VkMemoryAllocateInfo allocInfo = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
        allocInfo.allocationSize = memReq.size;
        allocInfo.memoryTypeIndex = findMemoryType(memReq.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        vkAllocateMemory(device, &allocInfo, nullptr, &historyMemory);
        vkBindImageMemory(device, historyImage, historyMemory, 0);

        VkImageViewCreateInfo viewInfo = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        viewInfo.image = historyImage;
        viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        viewInfo.subresourceRange.baseMipLevel = 0;
        viewInfo.subresourceRange.levelCount = 1;
        viewInfo.subresourceRange.baseArrayLayer = 0;
        viewInfo.subresourceRange.layerCount = 1;
        vkCreateImageView(device, &viewInfo, nullptr, &historyView);

        curDisplayW = disp_w;
        curDisplayH = disp_h;
        return true;
    }

    void dispatchFrame(VkCommandBuffer cmd, const NssFrameParameters* params) {
        setupFramePipeline(params->render_width, params->render_height,
                           params->display_width, params->display_height);

                                                         
        VkDescriptorSetAllocateInfo allocPre = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        allocPre.descriptorPool = descPool;
        allocPre.descriptorSetCount = 1;
        allocPre.pSetLayouts = &dslPreprocess;
        VkDescriptorSet dsPre;
        vkAllocateDescriptorSets(device, &allocPre, &dsPre);

        VkDescriptorImageInfo imgInColor = {linearSampler, params->in_color_jittered, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
        VkDescriptorImageInfo imgInDepth = {linearSampler, params->in_depth, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
        VkDescriptorImageInfo imgInMvec  = {linearSampler, params->in_motion_vectors, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
        VkDescriptorImageInfo imgHistory = {linearSampler, historyView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
        VkDescriptorBufferInfo bufOutTen = {t_frame_in_tensor.buffer, 0, VK_WHOLE_SIZE};

        VkWriteDescriptorSet writesPre[5] = {};
        writesPre[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPre[0].dstSet = dsPre;
        writesPre[0].dstBinding = 0;
        writesPre[0].descriptorCount = 1;
        writesPre[0].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPre[0].pImageInfo = &imgInColor;

        writesPre[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPre[1].dstSet = dsPre;
        writesPre[1].dstBinding = 1;
        writesPre[1].descriptorCount = 1;
        writesPre[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPre[1].pImageInfo = &imgInDepth;

        writesPre[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPre[2].dstSet = dsPre;
        writesPre[2].dstBinding = 2;
        writesPre[2].descriptorCount = 1;
        writesPre[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPre[2].pImageInfo = &imgInMvec;

        writesPre[3].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPre[3].dstSet = dsPre;
        writesPre[3].dstBinding = 3;
        writesPre[3].descriptorCount = 1;
        writesPre[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPre[3].pImageInfo = &imgHistory;

        writesPre[4].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPre[4].dstSet = dsPre;
        writesPre[4].dstBinding = 4;
        writesPre[4].descriptorCount = 1;
        writesPre[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writesPre[4].pBufferInfo = &bufOutTen;

        vkUpdateDescriptorSets(device, 5, writesPre, 0, nullptr);

                              
        VkPipeline prePipe = pipePreprocess;
        if (params->render_width >= 1920 || params->render_height >= 1080) {
            prePipe = pipePreprocess_2160;
        } else if (params->render_width >= 1280 || params->render_height >= 720) {
            prePipe = pipePreprocess_1440;
        }
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, prePipe);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, layoutPreprocess, 0, 1, &dsPre, 0, nullptr);

        PushConstantPreprocess pcPre;
        pcPre.render_width  = params->render_width;
        pcPre.render_height = params->render_height;
        pcPre.display_width = params->display_width;
        pcPre.display_height = params->display_height;
        pcPre.jitter_x      = params->jitter_offset_x;
        pcPre.jitter_y      = params->jitter_offset_y;
        pcPre.pre_exposure  = (params->pre_exposure > 0.0f) ? params->pre_exposure : 1.0f;
        pcPre.reset_history = params->reset_history;
        vkCmdPushConstants(cmd, layoutPreprocess, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pcPre), &pcPre);

        vkCmdDispatch(cmd, (params->render_width + 7) / 8, (params->render_height + 7) / 8, 1);

                                                  
        bufferBarrier(cmd, t_frame_in_tensor.buffer);

                                                             
        dispatchInference(cmd, t_frame_in_tensor.buffer, 0,
                          t_frame_kpn_tensor.buffer, 0,
                          t_frame_feedback.buffer, 0);

                                                           
        bufferBarrier(cmd, t_frame_kpn_tensor.buffer);
        bufferBarrier(cmd, t_frame_feedback.buffer);

                                  
        VkDescriptorSetAllocateInfo allocPost = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        allocPost.descriptorPool = descPool;
        allocPost.descriptorSetCount = 1;
        allocPost.pSetLayouts = &dslPostprocess;
        VkDescriptorSet dsPost;
        vkAllocateDescriptorSets(device, &allocPost, &dsPost);

        VkDescriptorBufferInfo bufKpn = {t_frame_kpn_tensor.buffer, 0, VK_WHOLE_SIZE};
        VkDescriptorBufferInfo bufFdbk = {t_frame_feedback.buffer, 0, VK_WHOLE_SIZE};
        VkDescriptorImageInfo imgOutCol = {VK_NULL_HANDLE, params->out_upscaled_color, VK_IMAGE_LAYOUT_GENERAL};
        VkDescriptorImageInfo imgOutHist = {VK_NULL_HANDLE, historyView, VK_IMAGE_LAYOUT_GENERAL};

        VkWriteDescriptorSet writesPost[7] = {};
        writesPost[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[0].dstSet = dsPost;
        writesPost[0].dstBinding = 0;
        writesPost[0].descriptorCount = 1;
        writesPost[0].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPost[0].pImageInfo = &imgInColor;

        writesPost[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[1].dstSet = dsPost;
        writesPost[1].dstBinding = 1;
        writesPost[1].descriptorCount = 1;
        writesPost[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPost[1].pImageInfo = &imgInMvec;

        writesPost[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[2].dstSet = dsPost;
        writesPost[2].dstBinding = 2;
        writesPost[2].descriptorCount = 1;
        writesPost[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        writesPost[2].pImageInfo = &imgHistory;

        writesPost[3].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[3].dstSet = dsPost;
        writesPost[3].dstBinding = 3;
        writesPost[3].descriptorCount = 1;
        writesPost[3].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writesPost[3].pBufferInfo = &bufKpn;

        writesPost[4].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[4].dstSet = dsPost;
        writesPost[4].dstBinding = 4;
        writesPost[4].descriptorCount = 1;
        writesPost[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        writesPost[4].pBufferInfo = &bufFdbk;

        writesPost[5].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[5].dstSet = dsPost;
        writesPost[5].dstBinding = 5;
        writesPost[5].descriptorCount = 1;
        writesPost[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writesPost[5].pImageInfo = &imgOutCol;

        writesPost[6].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writesPost[6].dstSet = dsPost;
        writesPost[6].dstBinding = 6;
        writesPost[6].descriptorCount = 1;
        writesPost[6].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        writesPost[6].pImageInfo = &imgOutHist;

        vkUpdateDescriptorSets(device, 7, writesPost, 0, nullptr);

        VkPipeline postPipe = pipePostprocess;
        if (params->display_width >= 3840 || params->display_height >= 2160) {
            postPipe = pipePostprocess_2160;
        } else if (params->display_width >= 2560 || params->display_height >= 1440) {
            postPipe = pipePostprocess_1440;
        }
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, postPipe);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, layoutPostprocess, 0, 1, &dsPost, 0, nullptr);

        PushConstantPostprocess pcPost;
        pcPost.render_width  = params->render_width;
        pcPost.render_height = params->render_height;
        pcPost.display_width = params->display_width;
        pcPost.display_height = params->display_height;
        pcPost.jitter_x      = params->jitter_offset_x;
        pcPost.jitter_y      = params->jitter_offset_y;
        pcPost.pre_exposure  = pcPre.pre_exposure;
        pcPost.reset_history = params->reset_history;
        vkCmdPushConstants(cmd, layoutPostprocess, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pcPost), &pcPost);

        if (params->display_width >= 3840 || params->display_height >= 2160) {
            vkCmdDispatch(cmd, (params->display_width + 15) / 16, (params->display_height + 15) / 16, 1);
        } else {
            vkCmdDispatch(cmd, (params->display_width + 7) / 8, (params->display_height + 7) / 8, 1);
        }
    }

    void cleanup() {
        profWrite();
        dumpWriteAll();
        captureFlush();
        freeIntermediateBuffers();
        destroyBuffer(modelBuffer);
        destroyBuffer(modelBuffer_DP4a);
        destroyBuffer(t_frame_in_tensor);
        destroyBuffer(t_frame_kpn_tensor);
        destroyBuffer(t_frame_feedback);

        if (historyView != VK_NULL_HANDLE) {
            vkDestroyImageView(device, historyView, nullptr);
            historyView = VK_NULL_HANDLE;
        }
        if (historyImage != VK_NULL_HANDLE) {
            vkDestroyImage(device, historyImage, nullptr);
            historyImage = VK_NULL_HANDLE;
        }
        if (historyMemory != VK_NULL_HANDLE) {
            vkFreeMemory(device, historyMemory, nullptr);
            historyMemory = VK_NULL_HANDLE;
        }

        if (linearSampler != VK_NULL_HANDLE) {
            vkDestroySampler(device, linearSampler, nullptr);
            linearSampler = VK_NULL_HANDLE;
        }

        if (descPool != VK_NULL_HANDLE) {
            vkDestroyDescriptorPool(device, descPool, nullptr);
            descPool = VK_NULL_HANDLE;
        }

        if (qpLayerProfile != VK_NULL_HANDLE) {
            vkDestroyQueryPool(device, qpLayerProfile, nullptr);
            qpLayerProfile = VK_NULL_HANDLE;
        }

        if (pipeConv2D != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D, nullptr);
            pipeConv2D = VK_NULL_HANDLE;
        }
        if (pipeConv2D_Coop_S1 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_Coop_S1, nullptr);
            pipeConv2D_Coop_S1 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_Coop_C16 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_Coop_C16, nullptr);
            pipeConv2D_Coop_C16 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_Coop_C32 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_Coop_C32, nullptr);
            pipeConv2D_Coop_C32 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_Coop_C32_PT2 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_Coop_C32_PT2, nullptr);
            pipeConv2D_Coop_C32_PT2 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_Coop2D != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_Coop2D, nullptr);
            pipeConv2D_Coop2D = VK_NULL_HANDLE;
        }
        if (pipeConv2D_CoopPT2 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_CoopPT2, nullptr);
            pipeConv2D_CoopPT2 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_C4 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_C4, nullptr);
            pipeConv2D_C4 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_C16 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_C16, nullptr);
            pipeConv2D_DP4a_C16 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a, nullptr);
            pipeConv2D_DP4a = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_1440 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_1440, nullptr);
            pipeConv2D_DP4a_1440 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_NarrowTiled != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_NarrowTiled, nullptr);
            pipeConv2D_DP4a_NarrowTiled = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_TiledS1 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_TiledS1, nullptr);
            pipeConv2D_DP4a_TiledS1 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_TiledS2 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_TiledS2, nullptr);
            pipeConv2D_DP4a_TiledS2 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_TiledS1_T16 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_TiledS1_T16, nullptr);
            pipeConv2D_DP4a_TiledS1_T16 = VK_NULL_HANDLE;
        }
        if (pipeConv2D_DP4a_2160 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConv2D_DP4a_2160, nullptr);
            pipeConv2D_DP4a_2160 = VK_NULL_HANDLE;
        }
        if (pipeResize != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeResize, nullptr);
            pipeResize = VK_NULL_HANDLE;
        }
        if (pipeConcat != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConcat, nullptr);
            pipeConcat = VK_NULL_HANDLE;
        }
        if (pipePreprocess != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePreprocess, nullptr);
            pipePreprocess = VK_NULL_HANDLE;
        }
        if (pipePreprocess_1440 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePreprocess_1440, nullptr);
            pipePreprocess_1440 = VK_NULL_HANDLE;
        }
        if (pipePreprocess_2160 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePreprocess_2160, nullptr);
            pipePreprocess_2160 = VK_NULL_HANDLE;
        }
        if (pipePostprocess != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePostprocess, nullptr);
            pipePostprocess = VK_NULL_HANDLE;
        }
        if (pipePostprocess_1440 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePostprocess_1440, nullptr);
            pipePostprocess_1440 = VK_NULL_HANDLE;
        }
        if (pipePostprocess_2160 != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePostprocess_2160, nullptr);
            pipePostprocess_2160 = VK_NULL_HANDLE;
        }
        if (pipeResize != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeResize, nullptr);
            pipeResize = VK_NULL_HANDLE;
        }
        if (pipeConcat != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipeConcat, nullptr);
            pipeConcat = VK_NULL_HANDLE;
        }
        if (pipePreprocess != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePreprocess, nullptr);
            pipePreprocess = VK_NULL_HANDLE;
        }
        if (pipePostprocess != VK_NULL_HANDLE) {
            vkDestroyPipeline(device, pipePostprocess, nullptr);
            pipePostprocess = VK_NULL_HANDLE;
        }

        if (layoutConv2D != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, layoutConv2D, nullptr);
            layoutConv2D = VK_NULL_HANDLE;
        }
        if (layoutResize != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, layoutResize, nullptr);
            layoutResize = VK_NULL_HANDLE;
        }
        if (layoutConcat != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, layoutConcat, nullptr);
            layoutConcat = VK_NULL_HANDLE;
        }
        if (layoutPreprocess != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, layoutPreprocess, nullptr);
            layoutPreprocess = VK_NULL_HANDLE;
        }
        if (layoutPostprocess != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(device, layoutPostprocess, nullptr);
            layoutPostprocess = VK_NULL_HANDLE;
        }

        if (dslConv2D != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, dslConv2D, nullptr);
            dslConv2D = VK_NULL_HANDLE;
        }
        if (dslResize != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, dslResize, nullptr);
            dslResize = VK_NULL_HANDLE;
        }
        if (dslConcat != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, dslConcat, nullptr);
            dslConcat = VK_NULL_HANDLE;
        }
        if (dslPreprocess != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, dslPreprocess, nullptr);
            dslPreprocess = VK_NULL_HANDLE;
        }
        if (dslPostprocess != VK_NULL_HANDLE) {
            vkDestroyDescriptorSetLayout(device, dslPostprocess, nullptr);
            dslPostprocess = VK_NULL_HANDLE;
        }
    }
};

extern "C" {

NSS_API int nss_engine_create(const NssEngineConfig* config, NssEngineHandle* out_handle) {
    if (!config || !out_handle) return -1;
    FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
    if (lf) {
        fprintf(lf, "[NSS Cooperative Matrix Engine] Initializing engine (quality=%d, device=%p)...\n", (int)config->quality, (void*)config->device);
        fclose(lf);
    }
    auto* engine = new NssEngine();
    if (!engine->init(config)) {
        if (lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
            fprintf(lf, "[NSS Cooperative Matrix Engine] ERROR: Failed to initialize engine!\n");
            fclose(lf);
        }
        delete engine;
        return -2;
    }
    if (lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr)) {
        fprintf(lf, "[NSS Cooperative Matrix Engine] Engine successfully created and loaded!\n");
        fclose(lf);
    }
    *out_handle = (NssEngineHandle)engine;
    return 0;
}

NSS_API int nss_engine_setup_resolution(NssEngineHandle handle, uint32_t input_width, uint32_t input_height) {
    if (!handle) return -1;
    auto* engine = (NssEngine*)handle;
    bool ok = engine->setupResolution(input_width, input_height);
    FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
    if (lf) {
        fprintf(lf, "[NSS Cooperative Matrix Engine] Resolution configured: %ux%u (result=%s)\n",
                input_width, input_height, ok ? "OK" : "FAILED");
        fclose(lf);
    }
    return ok ? 0 : -2;
}

NSS_API int nss_engine_set_backend(NssEngineHandle handle, NssBackendType backend) {
    if (!handle) return -1;
    auto* engine = (NssEngine*)handle;
    engine->backend = backend;
    FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
    if (lf) {
        fprintf(lf, "[NSS Cooperative Matrix Engine] Backend switched to: %s\n",
                (backend == NSS_BACKEND_DP4A) ? "DP4A" : "COOPMAT");
        fclose(lf);
    }
    return 0;
}

NSS_API NssBackendType nss_engine_get_backend(NssEngineHandle handle) {
    if (!handle) return NSS_BACKEND_COOPMAT;
    auto* engine = (NssEngine*)handle;
    return engine->backend;
}

NSS_API int nss_engine_dispatch_frame(
    NssEngineHandle handle,
    VkCommandBuffer cmd_buffer,
    const NssFrameParameters* params)
{
    if (!handle || !params) return -1;
    auto* engine = (NssEngine*)handle;
    engine->dispatchFrame(cmd_buffer, params);
    return 0;
}

NSS_API int nss_engine_dispatch(
    NssEngineHandle handle,
    VkCommandBuffer cmd_buffer,
    VkBuffer input_buf,          VkDeviceSize input_offset,
    VkBuffer out_kpn_buf,        VkDeviceSize kpn_offset,
    VkBuffer out_feedback_buf,   VkDeviceSize feedback_offset)
{
    if (!handle) return -1;
    static uint64_t s_dispatch_count = 0;
    s_dispatch_count++;
    if (s_dispatch_count <= 10 || (s_dispatch_count % 60 == 0)) {
        FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
        if (lf) {
            fprintf(lf, "[NSS Cooperative Matrix Engine] Dispatch #%llu: inBuf=%p, kpnBuf=%p, fdbkBuf=%p\n",
                    s_dispatch_count, (void*)input_buf, (void*)out_kpn_buf, (void*)out_feedback_buf);
            fclose(lf);
        }
    }
    auto* engine = (NssEngine*)handle;
    engine->dispatchInference(cmd_buffer, input_buf, input_offset, out_kpn_buf, kpn_offset, out_feedback_buf, feedback_offset);
    return 0;
}

NSS_API void nss_engine_destroy(NssEngineHandle handle) {
    if (!handle) return;
    FILE* lf = (nss_file_logging_enabled() ? fopen("nss_coopmat_engine.log", "a") : nullptr);
    if (lf) {
        fprintf(lf, "[NSS Cooperative Matrix Engine] Engine destroyed.\n");
        fclose(lf);
    }
    auto* engine = (NssEngine*)handle;
    engine->cleanup();
    delete engine;
}

}
