#pragma once
#include <vulkan/vulkan.h>
#include <vector>
#include <string>
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <atomic>
#include <thread>
#include <map>

#include "mlof2_engine_host.h"
#include "../../sdk/src/backends/vk/nfru_isa_capture.h"
#include "harness/mlof2_caps.h"
#include "mlof2_blobs.h"
#include "mlof2_shaders_spv.h"
#include "mlof2_input_prep_spv.h"
#include "mlof2_output_prep_spv.h"
#include "mlof2_glue_spv.h"

                                                                                                                     
                                                                                                       
#include "mlof2_of_select.h"
#ifndef MLOF2_OF_GEN_DIR
#define MLOF2_OF_GEN_DIR generated_cut3_v2_int8
#endif
#define MLOF2_STR2_(x) #x
#define MLOF2_STR_(x) MLOF2_STR2_(x)
#include MLOF2_STR_(MLOF2_OF_GEN_DIR/mlof2_enc_int8_graph.h)
#include MLOF2_STR_(MLOF2_OF_GEN_DIR/mlof2_pair_int8_graph.h)
#include "generated_cut3_v2_int8/mlof2_gen_int8_graph.h"
#include "generated_cut3_v2_int8/mlof2_gen_prep_int8_graph.h"
#include "generated_cut3_v2_int8/mlof2_gen_t_int8_graph.h"
#include "generated_dp4a_light_v2/mlof2_light_graph.h"                                                                     
#include "generated_oft_half_v2_int8/mlof2_oft_half_graph.h"
#include "generated_oft_v2_int8/mlof2_oft_graph.h"
#include "generated_fuse_v2_int8/mlof2_fuse_graph.h"
namespace mlof2_rec8_nol4 {
#include "generated_rec8_nol4_v2_int8/mlof2_pair_int8_graph.h"
}

struct Mlof2FrameInputs {
    VkImageView colView = VK_NULL_HANDLE;
    VkImageView depView = VK_NULL_HANDLE;
    VkImageView depTm1View = VK_NULL_HANDLE;
    VkImageView mvView = VK_NULL_HANDLE;
    float mvScale[2] = {1.0f, 1.0f};
    float jitter[2] = {0.0f, 0.0f};
    float viewProj[16] = {};
    float invViewProj[16] = {};
    float nearPlane = 0.1f, farPlane = 1000.0f;
    bool reset = false;
    uint64_t frameID = 0;
};

struct Mlof2JobDesc {
    VkImageView colCurrView = VK_NULL_HANDLE;
    VkImageView colPrevView = VK_NULL_HANDLE;
    VkImageView depCurrView = VK_NULL_HANDLE;
    VkImageView depPrevView = VK_NULL_HANDLE;
    VkImageView mvView      = VK_NULL_HANDLE;
    VkImageView fullColView = VK_NULL_HANDLE;                                                               
    uint32_t hudMode        = 0;                                                                               
    uint32_t depW = 0, depH = 0;                                                                 
    uint32_t mvW = 0, mvH = 0;                                                                           
    VkImage     outImage    = VK_NULL_HANDLE;
    VkImageView outView     = VK_NULL_HANDLE;
    float mvScale[2]        = {1.0f, 1.0f};
    float jitter[2]         = {0.0f, 0.0f};
    float viewProj[16]      = {};
    float invViewProj[16]   = {};
    float nearPlane         = 0.1f;
    float farPlane          = 1000.0f;
    bool  reset             = false;
    bool  isReverseZ        = false;
    uint64_t frameID        = 0;
    float t                 = 0.5f;
    uint32_t k              = 1;
    uint32_t mfg            = 2;            
    bool  hasCam            = false;
    bool  hasCamP           = false;
    float vp_p[16]          = {};
    float vp_a[16]          = {};
    float vp_b[16]          = {};
    float inv_vp_a[16]      = {};
};

class Mlof2Runtime {
public:
    struct Buf {
        VkBuffer b = VK_NULL_HANDLE;
        VkDeviceMemory m = VK_NULL_HANDLE;
        VkDeviceSize sz = 0;
    };

    struct Img {
        VkImage image = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        VkImageView view = VK_NULL_HANDLE;
        uint32_t width = 0, height = 0;
    };

    VkDevice dev = VK_NULL_HANDLE;
    VkPhysicalDevice pd = VK_NULL_HANDLE;
    Mlof2Caps caps;

    uint32_t dispW = 0, dispH = 0;
    uint32_t padW = 0, padH = 0;
                                                                                                                         
                                                                                                   
    bool ofHalf = false;
    uint32_t ofW = 0, ofH = 0;

    Mlof2Plan plan_enc, plan_pair, plan_gen, plan_prep, plan_t;
                                                                                                                  
                                                                                                                  
                                                            
    bool lightPath = false;
    bool camq = false;                                                                
    bool ofgPath = false;
    bool ofgMemoryPrune = false;
    bool ofgHalf = true;
    int ofgLkIters = 2;
    float ofgRuleMargin = 0.0f;
    bool ofgNoL4 = false;
    int ofgDebugView = 0;
    uint64_t m_off_ca = 0, m_off_cb = 0;

    Mlof2Plan plan_oft;
    uint32_t oftPrefixOps = 0;
    bool oftPrefixReady = false;
    Mlof2Plan plan_fuse;

    Buf bArena_oft, bBlob_oft, bMeta_oft;
    Buf bArena_fuse, bBlob_fuse, bMeta_fuse;

    struct StagingItem {
        Buf* dst = nullptr;
        VkDeviceSize srcOffset = 0;
        VkDeviceSize size = 0;
    };
    Buf bStagingWeights;
    std::vector<StagingItem> stagingWeightsItems;
    bool weightsUploaded = false;

    void prepareStagingUpload(const std::vector<std::pair<Buf*, std::pair<const void*, size_t>>>& uploads) {
        VkDeviceSize totalSize = 0;
        for (const auto& u : uploads) {
            if (u.first && u.second.first && u.second.second > 0) {
                totalSize = (totalSize + 255u) & ~255u;
                totalSize += u.second.second;
            }
        }
        if (totalSize == 0) return;
        bStagingWeights = mk(totalSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
        void* ptr = nullptr;
        if (vkMapMemory(dev, bStagingWeights.m, 0, totalSize, 0, &ptr) == VK_SUCCESS) {
            VkDeviceSize curOff = 0;
            for (const auto& u : uploads) {
                if (u.first && u.second.first && u.second.second > 0) {
                    curOff = (curOff + 255u) & ~255u;
                    memcpy((uint8_t*)ptr + curOff, u.second.first, u.second.second);
                    stagingWeightsItems.push_back({u.first, curOff, u.second.second});
                    curOff += u.second.second;
                }
            }
            vkUnmapMemory(dev, bStagingWeights.m);
        }
        weightsUploaded = false;
    }

    void cmdUploadStagedWeights(VkCommandBuffer cb) {
        if (weightsUploaded || stagingWeightsItems.empty()) return;
        for (const auto& item : stagingWeightsItems) {
            if (item.dst && item.dst->b && item.size > 0) {
                VkBufferCopy copyRegion{item.srcOffset, 0, item.size};
                vkCmdCopyBuffer(cb, bStagingWeights.b, item.dst->b, 1, &copyRegion);
            }
        }
        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
        weightsUploaded = true;
    }
    VkDescriptorSet ds_oft = VK_NULL_HANDLE;
    VkDescriptorSet ds_fuse = VK_NULL_HANDLE;

    std::vector<VkPipeline> dpipe_oft;
    std::vector<VkPipeline> dpipe_fuse;
    uint64_t off_cand_warpa = 0, off_cand_warpb = 0;
    uint64_t off_cand_mva = 0, off_cand_mvb = 0;
    uint64_t off_cand_inv_mv = 0, oft_fuse_off = 0, oft_total_arena = 0;
    uint32_t extra_tb = 0, extra_sb = 0, extra_ob = 0, extra_fc = 0;
                                                                                                             
    VkDescriptorSetLayout dsl_glue = VK_NULL_HANDLE;
    VkPipelineLayout pl_glue = VK_NULL_HANDLE;
    VkPipeline pipe_glue = VK_NULL_HANDLE;
    VkDescriptorSet ds_glue_gen = VK_NULL_HANDLE, ds_glue_t = VK_NULL_HANDLE;
    std::vector<uint32_t> meta_t[3];

    Buf bArena_enc, bArena_pair, bArena_gen, bArena_prep, bArena_t;
    Buf bBlob_enc, bBlob_pair, bBlob_gen, bBlob_prep, bBlob_t;
    Buf bMeta_enc, bMeta_pair, bMeta_gen, bMeta_prep, bMeta_t[3];
    Buf bPmask[3];
                                                                                                                    
                                                                                                                      
    bool pmaskInArena = false;
    uint64_t pmask_slot_off = 0, pmask_slot_sz = 0;

    Buf bEnc_curr, bEnc_prev;
    Buf bMv_prev, bOf_prev;
    uint64_t enc_off[8]{};                                                                                          
    uint64_t enc_cnt[8]{};
    uint64_t prep_extra_ndc_off = 0;
                                                                                                                      
                                                                                                           
    bool tAliasesPrep = false;
    uint64_t t_region_off = 0;                                                  
                                                                                                                        
                                                                                                    
    uint64_t sz_mvfull = 0, prep_extra_mvfull_off = 0, gen_extra_mvfull_off = 0;
    bool lanesActive = false;
                                                                                                                                     
                                                                                                                           
                                                                                       
    bool extMvap = true, snapValid = false, lanesNext = false;                                                 
    uint32_t snapW = 0;
    bool snapWritten = false;
    bool tRedirect[6] = {};
    uint64_t sz_ndc = 0;
    size_t enc_features_sz = 0;

    Img imgCabA, imgCabB, imgQpA, imgQpB;
    Img* all_imgs[4] = {&imgCabA, &imgCabB, &imgQpA, &imgQpB};
    VkSampler samplerLinear = VK_NULL_HANDLE;

    VkDescriptorSetLayout dsl = VK_NULL_HANDLE;
                                                                                                                         
                                                                                                              
    VkDescriptorSetLayout dsl_ext = VK_NULL_HANDLE;
    VkDescriptorSet ds_ext_ring[16] = {};
    VkDescriptorSet ds_ext = VK_NULL_HANDLE;
    bool extInOn = true;
    bool extOutJob = false;                                                                         
    uint32_t extHudJob = 0;
    VkPipelineLayout pl = VK_NULL_HANDLE;
    VkDescriptorPool dp = VK_NULL_HANDLE;

    VkDescriptorSet ds_enc = VK_NULL_HANDLE;
    VkDescriptorSet ds_pair = VK_NULL_HANDLE;
    VkDescriptorSet ds_gen = VK_NULL_HANDLE;
    VkDescriptorSet ds_prep = VK_NULL_HANDLE;
    VkDescriptorSet ds_t[3] = {};

    VkDescriptorSetLayout dsl_prep = VK_NULL_HANDLE;
    VkPipelineLayout pl_prep = VK_NULL_HANDLE;
    VkPipeline pipe_prep = VK_NULL_HANDLE;
    VkDescriptorSet ds_prep_io = VK_NULL_HANDLE;                                                          
                                                                                                                  
                                                                           
    static const uint32_t kDsRing = 16;
    VkDescriptorSet ds_prep_ring[kDsRing] = {};
    VkDescriptorSet ds_out_ring[kDsRing] = {};
    uint32_t ringIdx = 0;
    VkDescriptorSetLayout dsl_out = VK_NULL_HANDLE;
    VkPipelineLayout pl_out = VK_NULL_HANDLE;
    VkPipeline pipe_out = VK_NULL_HANDLE;
    VkDescriptorSet ds_out = VK_NULL_HANDLE;

    std::vector<VkShaderModule> smod;
    std::vector<VkPipeline> pipe_def;
    struct SpecKey { uint32_t kernel, fmts; int32_t ip0, ip1; uint32_t rt, sw, ksp, pf; int32_t redKind; };
    std::vector<std::pair<SpecKey, VkPipeline>> spec_pipes;

    std::vector<VkPipeline> dpipe_enc, dpipe_pair, dpipe_gen, dpipe_prep, dpipe_t;

    uint64_t lastPairFrameID = UINT64_MAX;
    bool has_prev = false;
    bool pair_first = true;                                                
    bool prev_pair_valid = false;                                                                                        
    std::atomic<bool> ready{false};                                                  
    bool started = false;                                                                            
    std::thread compileThread;                                                                                       
    std::atomic<bool> compileAbort{false};
    std::atomic<bool> compileFailed{false};
                                                                                                           
                                                                               
    struct Prof {
        bool on = false;
        int coarse = 0;                                                                                           
        static constexpr uint32_t kRing = 4, kQ = 2048;
        VkQueryPool qp[kRing] = {};
        std::vector<std::pair<uint32_t, uint32_t>> tags[kRing];                                                    
        bool pending[kRing] = {};
        uint32_t slot = 0, jobs = 0, every = 0;                                                     
        double period_ms = 1e-6, total = 0;
        std::map<uint32_t, std::pair<double, uint32_t>> op;                          
        std::map<uint32_t, double> kern, stage;
    } prof;
    enum : uint32_t { PS_ENC = 1, PS_PAIR, PS_GEN, PS_PREP, PS_T, PS_LIGHT, PS_MISC, PS_OFT, PS_FUSE, PS_CAND, PS_BLEND };
    uint32_t planStage(const Mlof2Plan& p) const {
        return &p == &plan_enc ? PS_ENC : &p == &plan_pair ? PS_PAIR : &p == &plan_gen ? PS_GEN : &p == &plan_prep ? PS_PREP
             : &p == &plan_t ? PS_T : &p == &plan_oft ? PS_OFT : &p == &plan_fuse ? PS_FUSE : PS_MISC;
    }
    bool isStageEdge(uint32_t tag, bool edge) const {
        if (edge) return true;
        if (prof.coarse != 2) return false;
        const uint32_t st = tag >> 16, op = tag & 0xFFFFu;
        if (st == PS_ENC) return !plan_enc.dispatches.empty() && op == plan_enc.dispatches.back().op;
        if (st == PS_PAIR) return !plan_pair.dispatches.empty() && op == plan_pair.dispatches.back().op;
        if (st == PS_PREP) return !plan_prep.dispatches.empty() && op == plan_prep.dispatches.back().op;
        if (st == PS_GEN) return op == 4u || op == 6u || op == 8u || op == 25u || op == 30u || op == 33u || op == 35u;
        if (st == PS_T) return op == 1u || op == 3u || op == 20u || op == 25u || op == 28u || op == 30u;
        if (st == PS_MISC) return op == 0u || op == 2u || op == 261u || op == 266u || op == 271u || op == 272u;
        if (st == PS_OFT) return !plan_oft.dispatches.empty() && op == plan_oft.dispatches.back().op;
        if (st == PS_FUSE) return !plan_fuse.dispatches.empty() && op == plan_fuse.dispatches.back().op;
        if (st == PS_CAND || st == PS_BLEND) return true;
        return false;
    }
    void profMark(VkCommandBuffer cb, uint32_t tag, uint32_t kernel, bool edge = false) {
        if (!prof.on || (prof.coarse && !isStageEdge(tag, edge))) return;
        auto& tg = prof.tags[prof.slot];
        if (tg.size() >= Prof::kQ) return;
        vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, prof.qp[prof.slot], uint32_t(tg.size()));
        tg.push_back({tag, kernel});
    }
    void profCollect(uint32_t sl, bool wait) {
        if (!prof.pending[sl] || prof.tags[sl].size() < 2) { prof.pending[sl] = false; return; }
        const auto& tg = prof.tags[sl];
        std::vector<uint64_t> ts(tg.size());
        if (vkGetQueryPoolResults(dev, prof.qp[sl], 0, uint32_t(tg.size()), ts.size() * 8, ts.data(), 8,
                                  VK_QUERY_RESULT_64_BIT | (wait ? VK_QUERY_RESULT_WAIT_BIT : 0)) != VK_SUCCESS) return;
        prof.pending[sl] = false;
        for (size_t i = 1; i < tg.size(); ++i) {
            const double ms = double(ts[i] - ts[i - 1]) * prof.period_ms;
            auto& o = prof.op[tg[i].first]; o.first += ms; o.second = tg[i].second;
            prof.kern[tg[i].second] += ms;
            prof.stage[tg[i].first >> 16] += ms;
        }
        prof.total += double(ts.back() - ts.front()) * prof.period_ms;
        ++prof.jobs;
        if (prof.every && prof.jobs >= prof.every) {                                                       
            profPrint();
            prof.jobs = 0; prof.total = 0; prof.op.clear(); prof.kern.clear(); prof.stage.clear();
        }
    }
    void profBegin(VkCommandBuffer cb) {
        if (!prof.on) return;
        profCollect(prof.slot, false);
        vkCmdResetQueryPool(cb, prof.qp[prof.slot], 0, Prof::kQ);
        prof.tags[prof.slot].clear();
        prof.pending[prof.slot] = true;
        profMark(cb, 0u, 0xFFFFu, true);
    }
    void profEnd(VkCommandBuffer cb) {
        if (!prof.on) return;
                                                                       
        profMark(cb, (PS_MISC << 16) | 0xFFu, 0xFFFFu, true);
        prof.slot = (prof.slot + 1) % Prof::kRing;
    }
    void profReport() {
        if (!prof.on) return;
        prof.every = 0;
        for (uint32_t i = 0; i < Prof::kRing; ++i) profCollect(i, true);
        profPrint();
    }
    void profPrint() {
        if (!prof.jobs) return;
        static const char* sn[] = {"-", "enc", "pair", "gen", "gen_prep", "gen_t", "light", "misc", "oft", "fuse", "cand", "blend"};
        const double J = prof.jobs;
        char line[256];
        auto out = [&](const char* l) { printf("%s\n", l); fflush(stdout); nss_trace("%s", l); };
        snprintf(line, sizeof line, "[mlof2 profile] %s%s %ux%u: %u jobs, %.3f ms per job (GPU, timestamps after every dispatch)",
                 caps.backend_name.c_str(), lightPath ? " light" : "", dispW, dispH, prof.jobs, prof.total / J); out(line);
        for (auto& st : prof.stage) { snprintf(line, sizeof line, "  stage %-8s %7.3f ms/job", sn[st.first < 12 ? st.first : 7], st.second / J); out(line); }
        std::vector<std::pair<double, uint32_t>> kv;
        for (auto& k : prof.kern) kv.push_back({k.second, k.first});
        std::sort(kv.rbegin(), kv.rend());
        for (size_t i = 0; i < kv.size() && i < 12; ++i) { snprintf(line, sizeof line, "  kernel %5u %7.3f ms/job", kv[i].second, kv[i].first / J); out(line); }
        std::vector<std::pair<double, uint32_t>> ov;
        for (auto& o : prof.op) ov.push_back({o.second.first, o.first});
        std::sort(ov.rbegin(), ov.rend());
        char tv[16]; const size_t top = mlof2_env("MLOF2_PROFILE_TOP", tv, sizeof tv) ? size_t(atoi(tv)) : 25;
        for (size_t i = 0; i < ov.size() && i < top; ++i) {
            const uint32_t tg = ov[i].second;
            snprintf(line, sizeof line, "  op %-8s #%-4u kernel %5u %7.3f ms/job", sn[(tg >> 16) < 12 ? (tg >> 16) : 7], tg & 0xFFFFu,
                     prof.op[tg].second, ov[i].first / J); out(line);
        }
    }
    bool imgBarriers = false;                                                                               
    VkPipeline boundPipe = VK_NULL_HANDLE;                                                                  
    bool blkZeroed = false;                                                                                   
    std::vector<VkPipeline> activeDumpedPipelines;
    std::vector<uint64_t> activeTracedOps;
    void traceActive(VkPipeline pipeline, uint32_t stage, uint32_t op, uint32_t kernel, uint32_t gx, uint32_t gy) {
        static const bool enabled = mlof2_env_on("MLOF2_TRACE_ACTIVE");
        if (!enabled || !pipeline) return;
        const uint64_t key = (uint64_t(stage) << 48) | (uint64_t(kernel) << 32) | op;
        if (std::find(activeTracedOps.begin(), activeTracedOps.end(), key) == activeTracedOps.end()) {
            activeTracedOps.push_back(key);
            printf("ACTIVE stage=%u op=%u kernel=%u name=%s groups=%ux%u\n", stage, op, kernel, g_mlof2_kernel_names[kernel], gx, gy);
            fflush(stdout);
        }
        if (nfru_isa::dumpDir() && std::find(activeDumpedPipelines.begin(), activeDumpedPipelines.end(), pipeline) == activeDumpedPipelines.end()) {
            activeDumpedPipelines.push_back(pipeline);
            char name[200];
            snprintf(name, sizeof name, "s%u_op%u_%s", stage, op, g_mlof2_kernel_names[kernel]);
            nfru_isa::dump(dev, pipeline, name);
        }
    }

    Mlof2Runtime() = default;
    ~Mlof2Runtime() { destroy(); }

    uint32_t findMem(uint32_t bits, VkMemoryPropertyFlags want) const {
        VkPhysicalDeviceMemoryProperties mp;
        vkGetPhysicalDeviceMemoryProperties(pd, &mp);
                                                                                           
                                                                                               
        if (ofgPath && (want & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
            const VkMemoryPropertyFlags localWant = want | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
            for (uint32_t i = 0; i < mp.memoryTypeCount; ++i)
                if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & localWant) == localWant)
                    return i;
        }
        for (uint32_t i = 0; i < mp.memoryTypeCount; ++i) {
            if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & want) == want)
                return i;
        }
        return 0;
    }

    Buf mk(VkDeviceSize sz, VkBufferUsageFlags usage, VkMemoryPropertyFlags props) {
        Buf buf; buf.sz = sz;
        VkBufferCreateInfo ci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        ci.size = sz; ci.usage = usage;
        if (vkCreateBuffer(dev, &ci, nullptr, &buf.b) != VK_SUCCESS) return {};
        VkMemoryRequirements mr; vkGetBufferMemoryRequirements(dev, buf.b, &mr);
        VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
        ai.allocationSize = mr.size; ai.memoryTypeIndex = findMem(mr.memoryTypeBits, props);
        if (vkAllocateMemory(dev, &ai, nullptr, &buf.m) != VK_SUCCESS) return {};
        vkBindBufferMemory(dev, buf.b, buf.m, 0);
        return buf;
    }

                                                                                                                              
    static void shiftPlan(Mlof2Plan& p, uint64_t off) {
        for (size_t t = 0; t < p.tensor_base.size(); ++t) {
            p.tensor_base[t] = uint32_t(uint64_t(p.tensor_base[t]) + off);
            p.meta[p.tb + 8u * uint32_t(t)] = p.tensor_base[t];
        }
        p.blk_lo += off; p.blk_hi += off;
    }
    const Mlof2Graph& encGraph() const { return lightPath ? mlof2_light_enc_graph : mlof2_enc_int8_graph; }
    const Mlof2Graph& pairGraph() const { return lightPath ? mlof2_light_pair_graph : mlof2_pair_int8_graph; }
                                                                                                          
    int pairOut(const char* name) const {
        const Mlof2Graph& g = pairGraph();
        for (int i = 0; i < g.num_outputs; ++i)
            if (strcmp(g.io_names[g.num_inputs + i], name) == 0) return g.io[g.num_inputs + i];
        assert(false && "pair graph output missing");
        return -1;
    }
    static void pointTensor(Mlof2Plan& p, int t, uint64_t addr) {
        p.tensor_base[t] = uint32_t(addr);
        p.meta[p.tb + 8u * uint32_t(t)] = uint32_t(addr);
    }
    static bool sameLayout(const Mlof2Graph& ga, const Mlof2Plan& pa, int ta, const Mlof2Graph& gb, const Mlof2Plan& pb, int tb) {
        const Mlof2Tensor& a = ga.tensors[ta]; const Mlof2Tensor& b = gb.tensors[tb];
        const bool ba = ta < int(pa.blk.size()) && pa.blk[ta].on, bb = tb < int(pb.blk.size()) && pb.blk[tb].on;
        return a.c == b.c && a.c_alloc == b.c_alloc && a.s == b.s && a.n == b.n && a.fmt == b.fmt && !ba && !bb;
    }

    void freeBuf(Buf& buf) {
        if (buf.b) { vkDestroyBuffer(dev, buf.b, nullptr); buf.b = VK_NULL_HANDLE; }
        if (buf.m) { vkFreeMemory(dev, buf.m, nullptr); buf.m = VK_NULL_HANDLE; }
        buf.sz = 0;
    }

                                                                                                                   
                                                                                                 
    void setExtFc(float* f, const Mlof2JobDesc& desc, uint64_t extraBase) {
        f[55] = float(dispW); f[56] = float(dispH);
        f[57] = float(desc.mvW ? desc.mvW : dispW); f[58] = float(desc.mvH ? desc.mvH : dispH);
        f[59] = float(desc.depW ? desc.depW : dispW); f[60] = float(desc.depH ? desc.depH : dispH);
        f[61] = desc.isReverseZ ? 1.0f : 0.0f;
        const bool use = extMvap && lanesNext && snapValid && prev_pair_valid;
        f[62] = use ? 1.0f : 0.0f;
        const uint32_t w = uint32_t((extraBase + uint64_t(snapW ^ 1u) * sz_mvfull) / 4u);                              
        memcpy(&f[63], &w, 4);
        f[53] = extIn() ? 1.0f : 0.0f;
        const uint32_t ws = uint32_t((extraBase + uint64_t(snapW) * sz_mvfull) / 4u);                                              
        memcpy(&f[54], &ws, 4);
        f[64] = desc.mvScale[0] * float(dispW); f[65] = desc.mvScale[1] * float(dispH);
        f[67] = extOutJob ? 1.0f : 0.0f; f[68] = float(extHudJob);
    }
                                                                                                                      
                                                                                                                      
    bool extOfOk = true;
                                                                                                                   
                                                                                                                    
                                                                                            
    float trailHomog = 10.0f;
    bool extOf() const { return extInOn && ofHalf && extOfOk; }                                                                  
                                                                                                            
    void cmdOfFc(VkCommandBuffer cb, Mlof2Plan& plan, const Buf& meta, const Mlof2JobDesc& desc) {
        float* f = (float*)&plan.meta[plan.fc];
        f[55] = float(dispW); f[56] = float(dispH);
        f[59] = float(desc.depW ? desc.depW : dispW); f[60] = float(desc.depH ? desc.depH : dispH);
        f[61] = desc.isReverseZ ? 1.0f : 0.0f;
        f[66] = extOf() ? 1.0f : 0.0f;
        cmdUpdateFc(cb, meta, plan.fc, &plan.meta[plan.fc]);
    }
    bool extIn() const { return extInOn && lanesNext; }                                                                 

                                                                                                                   
                                                                                                               
                                                                                               
    void cmdUpdateFc(VkCommandBuffer cb, const Buf& meta, uint32_t fcWord, const uint32_t* src) {
        VkMemoryBarrier b0{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        b0.srcAccessMask = VK_ACCESS_SHADER_READ_BIT;                                                        
        b0.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &b0, 0, nullptr, 0, nullptr);
        vkCmdUpdateBuffer(cb, meta.b, VkDeviceSize(fcWord) * 4u, VkDeviceSize(MLOF2_FC_WORDS) * 4u, src);
        VkMemoryBarrier b1{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        b1.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        b1.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &b1, 0, nullptr, 0, nullptr);
    }

    void uploadHostBuf(Buf& buf, const void* data, size_t sz) {
        void* ptr = nullptr;
        if (vkMapMemory(dev, buf.m, 0, sz, 0, &ptr) == VK_SUCCESS) {
            memcpy(ptr, data, sz);
            vkUnmapMemory(dev, buf.m);
        }
    }

    Img mkimg(uint32_t w, uint32_t h) {
        Img img; img.width = w; img.height = h;
        VkImageCreateInfo ici{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
        ici.imageType = VK_IMAGE_TYPE_2D;
        ici.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        ici.extent = {w, h, 1};
        ici.mipLevels = 1; ici.arrayLayers = 1;
        ici.samples = VK_SAMPLE_COUNT_1_BIT; ici.tiling = VK_IMAGE_TILING_OPTIMAL;
        ici.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        ici.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        ici.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        if (vkCreateImage(dev, &ici, nullptr, &img.image) != VK_SUCCESS) return {};
        VkMemoryRequirements mr; vkGetImageMemoryRequirements(dev, img.image, &mr);
        VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, nullptr, mr.size, findMem(mr.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)};
        if (vkAllocateMemory(dev, &mai, nullptr, &img.memory) != VK_SUCCESS) return {};
        vkBindImageMemory(dev, img.image, img.memory, 0);
        VkImageViewCreateInfo ivci{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        ivci.image = img.image; ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        ivci.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        ivci.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        if (vkCreateImageView(dev, &ivci, nullptr, &img.view) != VK_SUCCESS) return {};
        return img;
    }

    void freeImg(Img& img) {
        if (img.view) { vkDestroyImageView(dev, img.view, nullptr); img.view = VK_NULL_HANDLE; }
        if (img.image) { vkDestroyImage(dev, img.image, nullptr); img.image = VK_NULL_HANDLE; }
        if (img.memory) { vkFreeMemory(dev, img.memory, nullptr); img.memory = VK_NULL_HANDLE; }
    }

    void writeDescriptorSet(VkDescriptorSet s, Buf bArena, Buf bBlob, Buf bMeta) {
        VkDescriptorBufferInfo dbi[3] = {
            {bArena.b, 0, VK_WHOLE_SIZE},
            {bBlob.b, 0, VK_WHOLE_SIZE},
            {bMeta.b, 0, VK_WHOLE_SIZE}
        };
        VkDescriptorImageInfo dii_storage[4];
        VkDescriptorImageInfo dii_sampler[4];
        for (int i = 0; i < 4; ++i) dii_storage[i] = {VK_NULL_HANDLE, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL};
        for (int i = 0; i < 4; ++i) dii_sampler[i] = {samplerLinear, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL};

        VkWriteDescriptorSet wr[11];
        for (int i = 0; i < 3; ++i) wr[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, s, uint32_t(i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, nullptr, &dbi[i], nullptr};
        for (int i = 0; i < 4; ++i) wr[3 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, s, uint32_t(3 + i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &dii_storage[i], nullptr, nullptr};
        for (int i = 0; i < 4; ++i) wr[7 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, s, uint32_t(7 + i), 0, 1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, &dii_sampler[i], nullptr, nullptr};
        vkUpdateDescriptorSets(dev, 11, wr, 0, nullptr);
    }

    bool initPipelines() {
        nss_trace("initPipelines: creating shader modules (count=%d)", g_mlof2_num_kernels);
        VkPipelineCreateFlags p_flags = nfru_isa::createFlags(dev);
        smod.resize(g_mlof2_num_kernels);
        for (int k = 0; k < g_mlof2_num_kernels; ++k) {
            VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
            smi.codeSize = g_mlof2_kernel_spv_size[k];
            smi.pCode = g_mlof2_kernel_spv[k];
            if (vkCreateShaderModule(dev, &smi, nullptr, &smod[k]) != VK_SUCCESS) return false;
        }

        auto mkpipe = [&](int k, uint32_t fmts, int32_t ip0, int32_t ip1, uint32_t rt, uint32_t sw, uint32_t ksp, uint32_t pf, int32_t redKind) -> VkPipeline {
            const uint32_t mvOnly = ofgMemoryPrune && k == g_mlof2_gen_kernel_of_kind[MLOF2_K_PREP_H] ? 1u : 0u;
            uint32_t sd[9] = {fmts, uint32_t(ip0), uint32_t(ip1), rt, sw, ksp, pf, uint32_t(redKind), mvOnly};
            VkSpecializationMapEntry me[9] = {{0u, 0u, 4u}, {1u, 4u, 4u}, {2u, 8u, 4u}, {3u, 12u, 4u}, {4u, 16u, 4u}, {5u, 20u, 4u}, {6u, 24u, 4u}, {7u, 28u, 4u}, {8u, 32u, 4u}};
            VkSpecializationInfo spi{9u, me, 36u, sd};
            VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpi.flags = p_flags;
            VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
            const bool is_coop = caps.use_coopmat;
            const bool wave32 = is_coop || (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);
            const bool wave64 = !is_coop && (k == 0 || k == 1 || k == g_mlof2_kernel_dense_dp4a || k == g_mlof2_kernel_depthwise_dp4a) && !getenv("MLOF2_DP4A_WAVE32");
            rss.requiredSubgroupSize = wave32 ? 32u : 64u;
            const bool useRss = caps.has_subgroup_control;
            cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (useRss && (wave32 || wave64)) ? &rss : nullptr,
                         (useRss && wave32) ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                         VK_SHADER_STAGE_COMPUTE_BIT, smod[k], "main", &spi};
            cpi.layout = pl;
            VkPipeline pp = VK_NULL_HANDLE;
            VkResult res = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp);
            if (res != VK_SUCCESS) {
                nss_trace("mkpipe error: k=%d res=%d", k, (int)res);
            }
            return pp;
        };

        auto mkpipe_w = [&](const Mlof2Dispatch& d) -> VkPipeline {
            uint32_t sd[31] = {d.fmts, uint32_t(d.ip01[0]), uint32_t(d.ip01[1])};
            VkSpecializationMapEntry me[31];
            for (uint32_t j = 0; j < 3; ++j) me[j] = {j, 4u * j, 4u};
            for (uint32_t j = 0; j < 28; ++j) { sd[3 + j] = d.wsc[j]; me[3 + j] = {10u + j, 4u * (3u + j), 4u}; }
            VkSpecializationInfo spi{31u, me, sizeof sd, sd};
            VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
            rss.requiredSubgroupSize = 32u;
            VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpi.flags = p_flags;
            const bool useRss = caps.has_subgroup_control;
            cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, useRss ? &rss : nullptr,
                         useRss ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                         VK_SHADER_STAGE_COMPUTE_BIT, smod[d.kernel], "main", &spi};
            cpi.layout = pl;
            VkPipeline pp = VK_NULL_HANDLE;
            VkResult res = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp);
            if (res != VK_SUCCESS) {
                nss_trace("mkpipe_w error: kernel=%d res=%d", d.kernel, (int)res);
            }
            return pp;
        };

                                                                                                       
        auto isDefaultSpec = [](const Mlof2Dispatch& d) {
            return !d.wk && d.kernel != 5u && d.fmts == 0xFFFFFFFFu && d.ip01[0] == 0 && d.ip01[1] == 0 && d.coop_rt == 1u && d.coop_sw == 8u && d.coop_fuse == 0u && d.coop_pf == 24u;
        };
        std::vector<char> needDef(g_mlof2_num_kernels, 0);
        const Mlof2Plan* plans[7] = {&plan_enc, &plan_pair, &plan_gen, &plan_prep, &plan_t, &plan_oft, &plan_fuse};
        for (const Mlof2Plan* p : plans)
            if (p && !(ofgPath && (p == &plan_prep || p == &plan_t)))
                for (size_t i = 0; i < p->dispatches.size(); ++i) {
                    if (ofgPath && p == &plan_gen && i >= 6u) break;
                    const auto& d = p->dispatches[i];
                    if (isDefaultSpec(d) && d.kernel < uint32_t(g_mlof2_num_kernels)) needDef[d.kernel] = 1;
                }
        if (ofgPath) {
            needDef[g_mlof2_kernel_fuse_prep] = 1;
            needDef[g_mlof2_kernel_fuse_blend] = 1;
            needDef[g_mlof2_kernel_cand_mv] = 1;
        }
        nss_trace("initPipelines: shader modules created, creating pipe_def");
        pipe_def.resize(g_mlof2_num_kernels, VK_NULL_HANDLE);
        for (int k = 0; k < g_mlof2_num_kernels; ++k) {
            if (compileAbort) return false;
            if (k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk || !needDef[k]) continue;
            nss_trace("pipe_def: k=%d start (size=%llu)", k, (unsigned long long)g_mlof2_kernel_spv_size[k]);
            VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpi.flags = p_flags;
            VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
            const bool is_coop = caps.use_coopmat;
            const bool wave32 = is_coop || (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);
            const bool wave64 = !is_coop && (k == 0 || k == 1 || k == g_mlof2_kernel_dense_dp4a || k == g_mlof2_kernel_depthwise_dp4a) && !getenv("MLOF2_DP4A_WAVE32");
            rss.requiredSubgroupSize = wave32 ? 32u : 64u;
            const bool useRss = caps.has_subgroup_control;
            cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (useRss && (wave32 || wave64)) ? &rss : nullptr,
                         (useRss && wave32) ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                         VK_SHADER_STAGE_COMPUTE_BIT, smod[k], "main", nullptr};
            cpi.layout = pl;
            VkResult res = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pipe_def[k]);
            nss_trace("pipe_def: k=%d done res=%d", k, (int)res);
            if (res != VK_SUCCESS) {
                nss_trace("pipe_def error: k=%d res=%d", k, (int)res);
            }
        }

        auto getDispatchPipelines = [&](const Mlof2Plan& plan) -> std::vector<VkPipeline> {
            std::vector<VkPipeline> dpipe(plan.dispatches.size(), VK_NULL_HANDLE);
            if (ofgPath && (&plan == &plan_prep || &plan == &plan_t)) return dpipe;
            for (size_t i = 0; i < plan.dispatches.size(); ++i) {
                if (ofgPath && &plan == &plan_gen && i >= 6u) break;
                const Mlof2Dispatch& d = plan.dispatches[i];
                if (compileAbort) break;
                if (d.wk) { dpipe[i] = mkpipe_w(d); continue; }
                if (isDefaultSpec(d)) {
                    dpipe[i] = pipe_def[d.kernel];
                    continue;
                }
                const uint32_t kind = plan.meta[plan.ob + d.op * 24u];
                const int32_t redKind = ofgPath && d.kernel == 5u && (kind == MLOF2_K_VIG_PART || kind == MLOF2_K_VIG_SOLVE) ? int32_t(kind) : -1;
                const SpecKey key = {d.kernel, uint32_t(d.fmts), int32_t(d.ip01[0]), int32_t(d.ip01[1]), uint32_t(d.coop_rt), uint32_t(d.coop_sw), uint32_t(d.coop_fuse), uint32_t(d.coop_pf), redKind};
                auto it = std::find_if(spec_pipes.begin(), spec_pipes.end(), [&](const std::pair<SpecKey, VkPipeline>& e) {
                    return e.first.kernel == key.kernel && e.first.fmts == key.fmts && e.first.ip0 == key.ip0 && e.first.ip1 == key.ip1 &&
                           e.first.rt == key.rt && e.first.sw == key.sw && e.first.ksp == key.ksp && e.first.pf == key.pf && e.first.redKind == key.redKind; });
                if (it == spec_pipes.end()) {
                    spec_pipes.push_back({key, mkpipe(int(d.kernel), key.fmts, key.ip0, key.ip1, key.rt, key.sw, key.ksp, key.pf, key.redKind)});
                    it = spec_pipes.end() - 1;
                }
                dpipe[i] = it->second;
            }
            return dpipe;
        };

        nss_trace("initPipelines: pipe_def created, creating dispatch pipelines");
        dpipe_enc  = getDispatchPipelines(plan_enc);
        dpipe_pair = getDispatchPipelines(plan_pair);
        dpipe_gen  = getDispatchPipelines(plan_gen);
        dpipe_prep = getDispatchPipelines(plan_prep);
        dpipe_t    = getDispatchPipelines(plan_t);
        if (ofgPath) {
            dpipe_oft  = getDispatchPipelines(plan_oft);
            dpipe_fuse = getDispatchPipelines(plan_fuse);
        }

        return !compileAbort;
    }

    bool initGlue() {
        VkDescriptorSetLayoutBinding gb[2]{};
        for (uint32_t i = 0; i < 2; ++i) gb[i] = {i, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        VkDescriptorSetLayoutCreateInfo gl{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        gl.bindingCount = 2; gl.pBindings = gb;
        if (vkCreateDescriptorSetLayout(dev, &gl, nullptr, &dsl_glue) != VK_SUCCESS) return false;
        VkPushConstantRange gpr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 28};
        VkPipelineLayoutCreateInfo gpl{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        gpl.setLayoutCount = 1; gpl.pSetLayouts = &dsl_glue; gpl.pushConstantRangeCount = 1; gpl.pPushConstantRanges = &gpr;
        if (vkCreatePipelineLayout(dev, &gpl, nullptr, &pl_glue) != VK_SUCCESS) return false;
        VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        smi.codeSize = g_mlof2_glue_spv_size; smi.pCode = g_mlof2_glue_spv;
        VkShaderModule sm = VK_NULL_HANDLE;
        if (vkCreateShaderModule(dev, &smi, nullptr, &sm) != VK_SUCCESS) return false;
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, nullptr, 0, VK_SHADER_STAGE_COMPUTE_BIT, sm, "main", nullptr};
        cpi.layout = pl_glue;
        const VkResult pr = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pipe_glue);
        vkDestroyShaderModule(dev, sm, nullptr);
        if (pr != VK_SUCCESS) return false;
        VkDescriptorSetLayout gls[2] = {dsl_glue, dsl_glue};
        VkDescriptorSet gs[2];
        VkDescriptorSetAllocateInfo gai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        gai.descriptorPool = dp; gai.descriptorSetCount = 2; gai.pSetLayouts = gls;
        if (vkAllocateDescriptorSets(dev, &gai, gs) != VK_SUCCESS) return false;
        ds_glue_gen = gs[0]; ds_glue_t = gs[1];
        const VkBuffer dsts[2] = {bArena_gen.b, bArena_t.b};
        for (int i = 0; i < 2; ++i) {
            VkDescriptorBufferInfo bi[2] = {{bArena_pair.b, 0, VK_WHOLE_SIZE}, {dsts[i], 0, VK_WHOLE_SIZE}};
            VkWriteDescriptorSet w[2]{};
            for (uint32_t j = 0; j < 2; ++j) {
                w[j] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
                w[j].dstSet = gs[i]; w[j].dstBinding = j; w[j].descriptorCount = 1;
                w[j].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; w[j].pBufferInfo = &bi[j];
            }
            vkUpdateDescriptorSets(dev, 2, w, 0, nullptr);
        }
        return true;
    }

                                                                                                                    
                                                                                
    void glueCo(VkCommandBuffer cb, VkDescriptorSet ds, uint64_t src_off, uint64_t dst_off) {
        VkMemoryBarrier b0{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        b0.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        b0.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                             0, 1, &b0, 0, nullptr, 0, nullptr);
        struct { uint32_t src_off_w, dst_off_w, n, mode, dstW, dstH, srcStride; } gpc{uint32_t(src_off / 4u), uint32_t(dst_off / 4u),
            (padW / 4u) * (padH / 4u), ofHalf ? 1u : 0u, padW / 4u, padH / 4u, ofW / 4u};                                       
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_glue); boundPipe = VK_NULL_HANDLE;
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl_glue, 0, 1, &ds, 0, nullptr);
        vkCmdPushConstants(cb, pl_glue, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(gpc), &gpc);
        vkCmdDispatch(cb, (gpc.n + 255u) / 256u, 1, 1);
        profMark(cb, (PS_MISC << 16) | 1u, 0xFF01u);
        VkMemoryBarrier b1{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        b1.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        b1.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                             0, 1, &b1, 0, nullptr, 0, nullptr);
    }

    bool initInputPrep() {
        VkDescriptorSetLayoutBinding b[7];
        for (int i = 0; i < 5; ++i) {
            b[i].binding = uint32_t(i);
            b[i].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            b[i].descriptorCount = 1;
            b[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            b[i].pImmutableSamplers = &samplerLinear;
        }
        b[5].binding = 5; b[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[5].descriptorCount = 1; b[5].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT; b[5].pImmutableSamplers = nullptr;
        b[6].binding = 6; b[6].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        b[6].descriptorCount = 1; b[6].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT; b[6].pImmutableSamplers = nullptr;

        VkDescriptorSetLayoutCreateInfo dlci{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dlci.bindingCount = 7; dlci.pBindings = b;
        if (vkCreateDescriptorSetLayout(dev, &dlci, nullptr, &dsl_prep) != VK_SUCCESS) return false;

        VkPushConstantRange pcr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 96};                           
        VkPipelineLayoutCreateInfo plci{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plci.setLayoutCount = 1; plci.pSetLayouts = &dsl_prep;
        plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
        if (vkCreatePipelineLayout(dev, &plci, nullptr, &pl_prep) != VK_SUCCESS) return false;

        VkShaderModuleCreateInfo smci{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        smci.codeSize = g_mlof2_input_prep_spv_size;
        smci.pCode = g_mlof2_input_prep_spv;
        VkShaderModule sm_prep = VK_NULL_HANDLE;
        if (vkCreateShaderModule(dev, &smci, nullptr, &sm_prep) != VK_SUCCESS) return false;

        VkComputePipelineCreateInfo cpci{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpci.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, nullptr, 0, VK_SHADER_STAGE_COMPUTE_BIT, sm_prep, "main", nullptr};
        cpci.layout = pl_prep;
        if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpci, nullptr, &pipe_prep) != VK_SUCCESS) {
            vkDestroyShaderModule(dev, sm_prep, nullptr);
            return false;
        }
        vkDestroyShaderModule(dev, sm_prep, nullptr);

        VkDescriptorSetAllocateInfo dsai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        VkDescriptorSetLayout prepLayouts[kDsRing];
        for (uint32_t i = 0; i < kDsRing; ++i) prepLayouts[i] = dsl_prep;
        dsai.descriptorPool = dp; dsai.descriptorSetCount = kDsRing; dsai.pSetLayouts = prepLayouts;
        if (vkAllocateDescriptorSets(dev, &dsai, ds_prep_ring) != VK_SUCCESS) return false;
        ds_prep_io = ds_prep_ring[0];

                                      
        VkDescriptorSetLayoutBinding ob[4]{};
        ob[0].binding = 0; ob[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        ob[0].descriptorCount = 1; ob[0].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        ob[1].binding = 1; ob[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        ob[1].descriptorCount = 1; ob[1].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        for (uint32_t i = 2; i < 4; ++i)
            ob[i] = {i, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, &samplerLinear};

        VkDescriptorSetLayoutCreateInfo odlci{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        odlci.bindingCount = 4; odlci.pBindings = ob;
        if (vkCreateDescriptorSetLayout(dev, &odlci, nullptr, &dsl_out) != VK_SUCCESS) return false;

        VkPushConstantRange opcr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 24};
        VkPipelineLayoutCreateInfo oplci{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        oplci.setLayoutCount = 1; oplci.pSetLayouts = &dsl_out;
        oplci.pushConstantRangeCount = 1; oplci.pPushConstantRanges = &opcr;
        if (vkCreatePipelineLayout(dev, &oplci, nullptr, &pl_out) != VK_SUCCESS) return false;

        VkShaderModuleCreateInfo osmci{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        osmci.codeSize = g_mlof2_output_prep_spv_size;
        osmci.pCode = g_mlof2_output_prep_spv;
        VkShaderModule sm_out = VK_NULL_HANDLE;
        if (vkCreateShaderModule(dev, &osmci, nullptr, &sm_out) != VK_SUCCESS) return false;

        VkComputePipelineCreateInfo ocpci{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        ocpci.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, nullptr, 0, VK_SHADER_STAGE_COMPUTE_BIT, sm_out, "main", nullptr};
        ocpci.layout = pl_out;
        if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &ocpci, nullptr, &pipe_out) != VK_SUCCESS) {
            vkDestroyShaderModule(dev, sm_out, nullptr);
            return false;
        }
        vkDestroyShaderModule(dev, sm_out, nullptr);

        VkDescriptorSetAllocateInfo odsai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        VkDescriptorSetLayout outLayouts[kDsRing];
        for (uint32_t i = 0; i < kDsRing; ++i) outLayouts[i] = dsl_out;
        odsai.descriptorPool = dp; odsai.descriptorSetCount = kDsRing; odsai.pSetLayouts = outLayouts;
        if (vkAllocateDescriptorSets(dev, &odsai, ds_out_ring) != VK_SUCCESS) return false;
        ds_out = ds_out_ring[0];

        return true;
    }

    bool init(VkDevice in_dev, VkPhysicalDevice in_pd, uint32_t width, uint32_t height, VkInstance inst = VK_NULL_HANDLE) {
        nss_trace("Mlof2Runtime::init: begin %ux%u", width, height);
        dev = in_dev; pd = in_pd;
        caps = mlof2_query_caps(inst, pd);
        nss_trace("Mlof2Runtime::init: caps queried backend=%s use_coop=%d (reason: %s)", caps.backend_name.c_str(), (int)caps.use_coopmat, caps.reason.c_str());
        dev = in_dev; pd = in_pd;
        caps = mlof2_query_caps(inst, pd);

        dispW = width; dispH = height;
        padW = (width + 63) & ~63;
        padH = (height + 63) & ~63;

                                                                                                                 
                                                                                                           
        lightPath = caps.use_coopmat ? mlof2_env_on("MLOF2_LIGHT_COOP") : !mlof2_env_is("MLOF2_DP4A_LIGHT", "0");
        camq = mlof2_env_is("MLOF2_CAMQ", "1");
        {
            char eng_buf[32] = {};
            ofgPath = (mlof2_env("NFRU_ENGINE", eng_buf, sizeof(eng_buf)) && strcmp(eng_buf, "ofg") == 0) || mlof2_env_on("OFG_ENABLE");
            ofgMemoryPrune = ofgPath && !mlof2_env_is("OFG_MEM_PRUNE", "0");
        if (ofgPath) {
                ofgHalf = !mlof2_env_is("OFG_HALF", "0");
                char lk_buf[16] = {};
                ofgLkIters = mlof2_env("OFG_LK_ITERS", lk_buf, sizeof(lk_buf)) ? atoi(lk_buf) : 2;
                char rm_buf[32] = {};
                ofgRuleMargin = mlof2_env("OFG_RULE_MARGIN", rm_buf, sizeof(rm_buf)) ? float(atof(rm_buf)) : 0.0f;
                ofgNoL4 = mlof2_env_on("OFG_NO_L4");
                char dbg_buf[32] = {};
                if (mlof2_env("OFG_DEBUG_VIEW", dbg_buf, sizeof(dbg_buf))) ofgDebugView = atoi(dbg_buf);
                else if (mlof2_env("OFG_DEBUG", dbg_buf, sizeof(dbg_buf))) ofgDebugView = atoi(dbg_buf);
                nss_trace("Mlof2Runtime::init: OFG path active (half=%d, lk=%d, margin=%.3f, no_l4=%d)",
                          (int)ofgHalf, ofgLkIters, ofgRuleMargin, (int)ofgNoL4);
            }
        }
        const Mlof2Graph& g_enc = encGraph();
        const Mlof2Graph& g_pair = (ofgPath && ofgNoL4) ? mlof2_rec8_nol4::mlof2_pair_int8_graph : pairGraph();

        std::vector<uint8_t> blob_enc = lightPath ? std::vector<uint8_t>(mlof2_light_enc_blob, mlof2_light_enc_blob + mlof2_light_enc_blob_size)
                                                  : std::vector<uint8_t>(mlof2_enc_blob, mlof2_enc_blob + mlof2_enc_blob_size);
        std::vector<uint8_t> blob_pair = (ofgPath && ofgNoL4) ? std::vector<uint8_t>(mlof2_rec8_nol4_pair_blob, mlof2_rec8_nol4_pair_blob + mlof2_rec8_nol4_pair_blob_size)
                                       : lightPath ? std::vector<uint8_t>(mlof2_light_pair_blob, mlof2_light_pair_blob + mlof2_light_pair_blob_size)
                                       : std::vector<uint8_t>(mlof2_pair_blob, mlof2_pair_blob + mlof2_pair_blob_size);
        std::vector<uint8_t> blob_gen(mlof2_gen_blob, mlof2_gen_blob + mlof2_gen_blob_size);
        std::vector<uint8_t> blob_prep(mlof2_gen_prep_blob, mlof2_gen_prep_blob + mlof2_gen_prep_blob_size);
        std::vector<uint8_t> blob_t(mlof2_gen_t_blob, mlof2_gen_t_blob + mlof2_gen_t_blob_size);
                                                                                  
        std::vector<uint8_t> blob_oft, blob_fuse;

        {
            int of_s = 4;
            for (int i = 0; i < mlof2_gen_prep_int8_graph.num_inputs; ++i)
                if (std::string(mlof2_gen_prep_int8_graph.io_names[i]) == "of") of_s = mlof2_gen_prep_int8_graph.tensors[mlof2_gen_prep_int8_graph.io[i]].s;
            ofHalf = of_s == 8 && !mlof2_env_on("MLOF2_OF_FULL");
            ofW = ofHalf ? ((padW / 2u + 63u) & ~63u) : padW;
            ofH = ofHalf ? ((padH / 2u + 63u) & ~63u) : padH;
            nss_trace("Mlof2Runtime::init: OF grid %ux%u (%s)", ofW, ofH, ofHalf ? "half-res frame" : "full res");
        }
        {
            char v[32] = {};
            trailHomog = 10.0f;
            if (mlof2_env("MLOF2_TRAIL_HOMOG", v, sizeof(v))) {
                const float f = float(atof(v));
                trailHomog = (strcmp(v, "off") == 0 || f <= 0.0f) ? 1e30f : f;
            }
            nss_trace("Mlof2Runtime::init: trailing band homography threshold %g px", trailHomog);
        }
        extOfOk = true;
        for (int i = 0; i < g_enc.num_ops && !lightPath; ++i) {
            const Mlof2Op& o = g_enc.ops[i];
            for (int si = 0; si < o.nseg; ++si) {
                const int tin = g_enc.segs[o.seg0 + si].tensor;
                if (tin != g_enc.io[0] && tin != g_enc.io[1]) continue;
                const bool ok = (o.kind == MLOF2_K_UNSHUFFLE && o.ip[0] == 4 && o.nseg == 2 && o.out_c == 64) ||
                                (o.kind == MLOF2_K_RESIZE_AREA && o.out_c == 3);
                if (!ok) extOfOk = false;
            }
        }
        if (!extOfOk) nss_trace("Mlof2Runtime::init: encoder reads col / dep in other ops -> OF input via the input shader");
        mlof2_ext_of_ops() = ofHalf && extOfOk && !mlof2_env_on("MLOF2_NO_EXT_IN");                    
        const bool ok_enc = lightPath ? mlof2_plan_dp4a_light(g_enc, ofH, ofW, plan_enc, caps.use_coopmat)
                                      : mlof2_plan(g_enc, ofH, ofW, plan_enc, caps.use_coopmat);
        mlof2_ext_of_ops() = false;
        if (!ok_enc) return false;
        const bool ok_pair = lightPath ? mlof2_plan_dp4a_light(g_pair, ofH, ofW, plan_pair, caps.use_coopmat)
                                       : mlof2_plan(g_pair, ofH, ofW, plan_pair, caps.use_coopmat);
        if (!ok_pair) return false;
        if (!mlof2_plan(mlof2_gen_int8_graph, padH, padW, plan_gen, caps.use_coopmat)) return false;
        if (!mlof2_plan(mlof2_gen_prep_int8_graph, padH, padW, plan_prep, caps.use_coopmat)) return false;
        if (!mlof2_plan(mlof2_gen_t_int8_graph, padH, padW, plan_t, caps.use_coopmat)) return false;
        if (ofgPath) {
            const Mlof2Graph& g_oft = ofgHalf ? g_mlof2_oft_half_graph : g_mlof2_oft_graph;
            blob_oft = ofgHalf ? std::vector<uint8_t>(mlof2_oft_half_blob, mlof2_oft_half_blob + mlof2_oft_half_blob_size)
                                                    : std::vector<uint8_t>(mlof2_oft_blob, mlof2_oft_blob + mlof2_oft_blob_size);
            if (!mlof2_plan(g_oft, padH, padW, plan_oft, caps.use_coopmat)) return false;
            mlof2_convw_weights(g_oft, plan_oft, blob_oft);

                                                                            
                                                                          
                                                                             
                                                                
            oftPrefixOps = 0;
            oftPrefixReady = false;
            if (!mlof2_env_is("OFG_CACHE_PREFIX", "0")) {
                uint32_t prefix = 0;
                while (prefix < uint32_t(g_oft.num_ops)) {
                    const uint32_t kind = uint32_t(g_oft.ops[prefix].kind);
                    if (kind != MLOF2_K_RESIZE_AREA && kind != MLOF2_K_RESIZE_BIL && kind != 69u) break;
                    ++prefix;
                }
                std::vector<bool> made(g_oft.num_tensors, false), crossing(g_oft.num_tensors, false);
                for (uint32_t i = 0; i < prefix; ++i) made[g_oft.ops[i].out] = true;
                for (uint32_t i = prefix; i < uint32_t(g_oft.num_ops); ++i)
                    for (int si = 0; si < g_oft.ops[i].nseg; ++si) {
                        const int ti = g_oft.segs[g_oft.ops[i].seg0 + si].tensor;
                        if (made[ti]) crossing[ti] = true;
                    }
                bool supported = true;
                for (int ti = 0; ti < g_oft.num_tensors; ++ti)
                    if (crossing[ti] && plan_oft.blk[ti].on) supported = false;
                if (supported && prefix) {
                    const uint64_t before = plan_oft.arena_bytes;
                    for (int ti = 0; ti < g_oft.num_tensors; ++ti) if (crossing[ti]) {
                        uint64_t oldOffset, bytes;
                        mlof2_tensor_span(g_oft, plan_oft, ti, oldOffset, bytes);
                        const uint64_t at = (plan_oft.arena_bytes + 255u) & ~uint64_t(255u);
                        pointTensor(plan_oft, ti, uint32_t(at));
                        plan_oft.arena_bytes = at + bytes;
                    }
                    oftPrefixOps = prefix;
                    nss_trace("OFG prefix cache: %u ops, %llu extra bytes", prefix, (unsigned long long)(plan_oft.arena_bytes - before));
                }
            }

            const Mlof2Graph& g_fuse = g_mlof2_fuse_graph;
            blob_fuse.assign(mlof2_fuse_blob, mlof2_fuse_blob + mlof2_fuse_blob_size);
            if (!mlof2_plan(g_fuse, padH, padW, plan_fuse, caps.use_coopmat)) return false;
            mlof2_convw_weights(g_fuse, plan_fuse, blob_fuse);

                                                                       
            uint64_t sz_rgba_s1 = uint64_t(padW) * uint64_t(padH) * 8u;                        
            sz_rgba_s1 = (sz_rgba_s1 + 65535u) & ~65535u;
            uint64_t sz_inv_mv = uint64_t(padW / 2u) * uint64_t(padH / 2u) * 12u;                       
            sz_inv_mv = (sz_inv_mv + 65535u) & ~65535u;

            off_cand_warpa  = (plan_oft.arena_bytes + 65535u) & ~65535u;
            off_cand_warpb  = off_cand_warpa + sz_rgba_s1;
            off_cand_mva    = off_cand_warpb + sz_rgba_s1;
            off_cand_mvb    = off_cand_mva + sz_rgba_s1;
            off_cand_inv_mv = off_cand_mvb + sz_rgba_s1;
            oft_fuse_off    = off_cand_inv_mv + sz_inv_mv;
            oft_total_arena = oft_fuse_off + ((plan_fuse.arena_bytes + 65535u) & ~65535u);

                                              
            for (size_t t = 0; t < plan_fuse.tensor_base.size(); ++t) {
                plan_fuse.tensor_base[t] += uint32_t(oft_fuse_off);
                plan_fuse.meta[plan_fuse.tb + 8u * t] += uint32_t(oft_fuse_off);
            }
            if (plan_fuse.blk_lo != plan_fuse.blk_hi) {
                plan_fuse.blk_lo += oft_fuse_off;
                plan_fuse.blk_hi += oft_fuse_off;
            }

                                                    
                                              
                                                
                                                 
            while (plan_fuse.meta.size() % 16 != 0) plan_fuse.meta.push_back(0u);
            extra_tb = uint32_t(plan_fuse.meta.size());

            auto addTensor = [&](uint32_t base, uint32_t c, uint32_t w, uint32_t h, uint32_t s, uint32_t c_alloc, uint32_t fmt, float scale) {
                uint32_t u_scale; memcpy(&u_scale, &scale, 4);
                plan_fuse.meta.push_back(base);
                plan_fuse.meta.push_back(c);
                plan_fuse.meta.push_back(w);
                plan_fuse.meta.push_back(h);
                plan_fuse.meta.push_back(1u);     
                plan_fuse.meta.push_back(s);
                plan_fuse.meta.push_back((fmt & 0xFFu) | ((c_alloc & 0xFFFFu) << 8));
                plan_fuse.meta.push_back(u_scale);
            };
                               
            addTensor(plan_oft.tensor_base[g_oft.io[4]], 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                            
            addTensor(uint32_t(off_cand_mva), 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                            
            addTensor(uint32_t(off_cand_mvb), 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                              
            addTensor(uint32_t(off_cand_warpa), 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                              
            addTensor(uint32_t(off_cand_warpb), 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                             
            addTensor(plan_oft.tensor_base[g_oft.io[5]], 2u, padW / 2u, padH / 2u, 2u, 2u, 1u, 1.0f);
                             
            addTensor(plan_oft.tensor_base[g_oft.io[6]], 2u, padW / 2u, padH / 2u, 2u, 2u, 1u, 1.0f);
                               
            addTensor(uint32_t(off_cand_inv_mv), 6u, padW / 2u, padH / 2u, 2u, 6u, 1u, 1.0f);
                                                                           
            uint32_t vis_t = ofgHalf ? 79u : 70u;
            addTensor(plan_oft.tensor_base[vis_t], 1u, padW / (ofgHalf ? 2u : 1u), padH / (ofgHalf ? 2u : 1u), ofgHalf ? 2u : 1u, 2u, 1u, 1.0f);
                                
            addTensor(plan_fuse.tensor_base[0], 21u, padW / 2u, padH / 2u, 2u, g_mlof2_fuse_tensors[0].c_alloc, 2u, g_mlof2_fuse_tensors[0].scale);
                                     
            addTensor(plan_fuse.tensor_base[7], 48u, padW / 8u, padH / 8u, 8u, g_mlof2_fuse_tensors[7].c_alloc, 1u, 1.0f);
                                 
            addTensor(plan_oft.tensor_base[0], 4u, padW, padH, 1u, 4u, 1u, 1.0f);
                                 
            addTensor(plan_oft.tensor_base[1], 4u, padW, padH, 1u, 4u, 1u, 1.0f);

            extra_sb = uint32_t(plan_fuse.meta.size());
            auto addSeg = [&](uint32_t tensor, uint32_t c_off, uint32_t c, uint32_t swap) {
                plan_fuse.meta.push_back(tensor);
                plan_fuse.meta.push_back(c_off);
                plan_fuse.meta.push_back(c);
                plan_fuse.meta.push_back(swap);
            };
                                                                             
            addSeg(11u, 0u, 4u, 0u);
            addSeg(12u, 0u, 4u, 0u);
            addSeg(5u,  0u, 2u, 0u);
            addSeg(6u,  0u, 2u, 0u);
            addSeg(7u,  0u, 6u, 0u);
            addSeg(2u,  0u, 4u, 0u);
            addSeg(3u,  0u, 4u, 0u);
            addSeg(4u,  0u, 4u, 0u);

                                                                                                                     
            addSeg(0u, 0u, 4u, 0u);
            addSeg(1u, 0u, 4u, 0u);
            addSeg(2u, 0u, 4u, 0u);
            addSeg(3u, 0u, 4u, 0u);
            addSeg(4u, 0u, 4u, 0u);
            addSeg(5u, 0u, 2u, 0u);
            addSeg(6u, 0u, 2u, 0u);
            addSeg(7u, 0u, 2u, 0u);
            addSeg(7u, 2u, 2u, 0u);
            addSeg(7u, 4u, 1u, 0u);
            addSeg(8u, 0u, 1u, 0u);

                                                                                                                      
            addSeg(0u,  0u, 4u, 0u);
            addSeg(1u,  0u, 4u, 0u);
            addSeg(2u,  0u, 4u, 0u);
            addSeg(10u, 0u, 48u, 0u);
            addSeg(3u,  0u, 4u, 0u);
            addSeg(4u,  0u, 4u, 0u);
            addSeg(7u,  0u, 6u, 0u);
            addSeg(8u,  0u, 1u, 0u);

            extra_ob = uint32_t(plan_fuse.meta.size());
            auto addOp = [&](uint32_t kind, uint32_t out_t, uint32_t seg0, uint32_t nseg, float fp0) {
                uint32_t op_words[24] = {};
                op_words[0] = kind;
                op_words[1] = out_t;          
                op_words[4] = seg0;            
                op_words[5] = nseg;            
                memcpy(&op_words[14], &fp0, 4);         
                for (int w = 0; w < 24; ++w) plan_fuse.meta.push_back(op_words[w]);
            };
            addOp(82u, 1u, 0u, 8u, 0.0f);                           
            addOp(70u, 9u, 8u, 11u, 0.0f);                            
            addOp(71u, 0u, 19u, 8u, ofgRuleMargin);                    

            extra_fc = uint32_t(plan_fuse.meta.size());
            for (int w = 0; w < MLOF2_FC_WORDS; ++w) plan_fuse.meta.push_back(0u);

            const VkBufferUsageFlags ofg_SB = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
            const VkMemoryPropertyFlags ofg_DL = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
            const VkMemoryPropertyFlags ofg_HV = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;

            bArena_oft  = mk(oft_total_arena, ofg_SB, ofg_DL);
            bBlob_oft   = mk(std::max<size_t>(blob_oft.size(), 256), ofg_SB, ofg_DL);
            bMeta_oft   = mk(plan_oft.meta.size() * 4, ofg_SB, ofg_DL);

            bArena_fuse = bArena_oft;                       
            bBlob_fuse  = mk(std::max<size_t>(blob_fuse.size(), 256), ofg_SB, ofg_DL);
            bMeta_fuse  = mk(plan_fuse.meta.size() * 4, ofg_SB, ofg_DL);
        }
        nss_trace("Mlof2Runtime::init: plans created successfully pad=%ux%u%s", padW, padH, lightPath ? " (light enc+pair)" : "");

        mlof2_convw_weights(g_enc, plan_enc, blob_enc);
        mlof2_convw_weights(g_pair, plan_pair, blob_pair);
        mlof2_convw_weights(mlof2_gen_int8_graph, plan_gen, blob_gen);
        mlof2_convw_weights(mlof2_gen_prep_int8_graph, plan_prep, blob_prep);
        mlof2_convw_weights(mlof2_gen_t_int8_graph, plan_t, blob_t);
        {                                                                                                                  
                                                                                                                           
                                                                                                      
            char v[64] = {};
            const bool set = mlof2_env("MLOF2_BOTHFAIL", v, sizeof(v)) && strcmp(v, "0") != 0;
            float bm = 1e30f, bw = 1.0f;
            const bool keep = set && strcmp(v, "1") == 0;
            if (set && !keep) sscanf(v, "%f,%f", &bm, &bw);
            auto patch = [&](const Mlof2Graph& g, Mlof2Plan& p) {
                for (int i = 0; i < g.num_ops; ++i)
                    if (g.ops[i].kind == MLOF2_K_Q_RULE2 && g.ops[i].out_c >= 2) {
                        if (!keep) {
                            memcpy(&p.meta[p.ob + 24u * uint32_t(i) + 14u], &bm, 4);
                            memcpy(&p.meta[p.ob + 24u * uint32_t(i) + 15u], &bw, 4);
                        }
                        char e[32] = {};                                                                                        
                        if (mlof2_env("MLOF2_BF_EDGE", e, sizeof(e))) {
                            float be = float(atof(e));
                            memcpy(&p.meta[p.ob + 24u * uint32_t(i) + 16u], &be, 4);
                        }
                                                                                                                        
                                                                                                                      
                        float reach = 0.75f;
                        if (mlof2_env("MLOF2_BF_REACH", e, sizeof(e))) reach = float(atof(e));
                        memcpy(&p.meta[p.ob + 24u * uint32_t(i) + 17u], &reach, 4);
                    }
            };
            patch(mlof2_gen_t_int8_graph, plan_t);
            patch(mlof2_gen_int8_graph, plan_gen);
            nss_trace("Mlof2Runtime::init: BOTHFAIL %s (%g, %g)", keep ? "export values" : (set ? "on" : "off"), bm, bw);
        }

        sz_ndc = (uint64_t)padW * padH * sizeof(float);
        prep_extra_ndc_off = plan_prep.arena_bytes;
        sz_mvfull = (uint64_t)padW * padH * 2 * sizeof(float);                                             
        extMvap = true;                                                                                               
        prep_extra_mvfull_off = (prep_extra_ndc_off + sz_ndc + 255u) / 256u * 256u;
        gen_extra_mvfull_off = (plan_gen.arena_bytes + 255u) / 256u * 256u;
        t_region_off = (prep_extra_mvfull_off + 2u * sz_mvfull + 255u) / 256u * 256u;
        tAliasesPrep = !mlof2_env_on("MLOF2_NO_ZEROCOPY");
        for (bool& r : tRedirect) r = false;
        if (tAliasesPrep) {
            const uint64_t t_off = t_region_off;
            shiftPlan(plan_t, t_off);
            const int from[5] = {9, 11, 12, 13, 3};                                                           
            for (int i = 0; i < 5; ++i)
                if (sameLayout(mlof2_gen_prep_int8_graph, plan_prep, from[i], mlof2_gen_t_int8_graph, plan_t, i)) {
                    pointTensor(plan_t, i, plan_prep.tensor_base[from[i]]);
                    tRedirect[i] = true;
                }
            const Mlof2Tensor& tn = mlof2_gen_t_int8_graph.tensors[5];                                            
                                                                                                                 
            if (tn.fmt == 0 && tn.c == 1 && tn.c_alloc == 1 && tn.n == 1) { pointTensor(plan_t, 5, prep_extra_ndc_off); tRedirect[5] = true; }
            nss_trace("Mlof2Runtime::init: gen_t shares the gen_prep buffer at %llu, inputs in place %d%d%d%d%d%d", (unsigned long long)t_off,
                      tRedirect[0], tRedirect[1], tRedirect[2], tRedirect[3], tRedirect[4], tRedirect[5]);
        }

        int t_pmask = -1;
        for (int i = 0; i < mlof2_gen_t_int8_graph.num_inputs; ++i)
            if (std::string(mlof2_gen_t_int8_graph.io_names[i]) == "pmask") t_pmask = mlof2_gen_t_int8_graph.io[i];
        pmaskInArena = t_pmask >= 0 && !mlof2_env_on("MLOF2_PMASK_COPY");
        if (pmaskInArena) {
            uint64_t off, cnt;
            mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, t_pmask, off, cnt);
            pmask_slot_sz = (cnt + 255u) / 256u * 256u;
            pmask_slot_off = ((tAliasesPrep ? t_region_off : 0u) + plan_t.arena_bytes + 255u) / 256u * 256u;
        }
        for (int k = 1; k <= 3; ++k) {
            meta_t[k - 1] = plan_t.meta;
            if (pmaskInArena) meta_t[k - 1][plan_t.tb + 8u * uint32_t(t_pmask)] = uint32_t(pmask_slot_off + uint64_t(k - 1) * pmask_slot_sz);
            float* mfc = (float*)&meta_t[k - 1][plan_t.fc];
            mfc[MLOF2_FC_T] = float(k) * 0.25f;
            mfc[MLOF2_FC_PAIR_FIRST] = (k == 1 ? 1.0f : 0.0f);
        }

        const VkBufferUsageFlags SB = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        const VkMemoryPropertyFlags DL = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        const VkMemoryPropertyFlags HV = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;

        bArena_enc  = mk(plan_enc.arena_bytes, SB, DL);
        bArena_pair = mk(plan_pair.arena_bytes, SB, DL);
        bArena_gen  = mk(gen_extra_mvfull_off + 2u * sz_mvfull, SB, DL);
        if (ofgMemoryPrune) {
            const uint64_t unused = tAliasesPrep ? (pmaskInArena ? pmask_slot_off + 3u * pmask_slot_sz : t_region_off + plan_t.arena_bytes)
                : prep_extra_mvfull_off + 2u * sz_mvfull + (pmaskInArena ? pmask_slot_off + 3u * pmask_slot_sz : plan_t.arena_bytes);
            bArena_prep = mk(256u, SB, DL);
            bArena_t = tAliasesPrep ? bArena_prep : mk(256u, SB, DL);
            nss_trace("OFG memory prune: omitted %llu bytes of legacy prep/t arenas", (unsigned long long)unused);
        } else if (tAliasesPrep) {
            bArena_prep = mk(pmaskInArena ? pmask_slot_off + 3u * pmask_slot_sz : t_region_off + plan_t.arena_bytes, SB, DL);
            bArena_t = bArena_prep;                                             
        } else {
            bArena_prep = mk(prep_extra_mvfull_off + 2u * sz_mvfull, SB, DL);
            bArena_t    = mk(pmaskInArena ? pmask_slot_off + 3u * pmask_slot_sz : plan_t.arena_bytes, SB, DL);
        }

        bBlob_enc  = mk(std::max<size_t>(blob_enc.size(), 256), SB, DL);
        bBlob_pair = mk(std::max<size_t>(blob_pair.size(), 256), SB, DL);
        bBlob_gen  = mk(std::max<size_t>(blob_gen.size(), 256), SB, DL);
        bBlob_prep = mk(std::max<size_t>(blob_prep.size(), 256), SB, DL);
        bBlob_t    = mk(std::max<size_t>(blob_t.size(), 256), SB, DL);

        bMeta_enc  = mk(plan_enc.meta.size() * 4, SB, DL);
        bMeta_pair = mk(plan_pair.meta.size() * 4, SB, DL);
        bMeta_gen  = mk(plan_gen.meta.size() * 4, SB, DL);
        bMeta_prep = mk(plan_prep.meta.size() * 4, SB, DL);
        for (int k = 0; k < 3; ++k) bMeta_t[k] = mk(meta_t[k].size() * 4, SB, DL);

        enc_features_sz = 0;
        for (int i = 0; i < g_enc.num_outputs; ++i) {
            uint64_t off, cnt;
            mlof2_tensor_span(g_enc, plan_enc, g_enc.io[g_enc.num_inputs + i], off, cnt);
            enc_features_sz += (cnt + 255u) & ~255u;
        }
        bEnc_curr = mk(enc_features_sz, SB, DL);
        bEnc_prev = mk(enc_features_sz, SB, DL);

        uint64_t mv_sz = (uint64_t)padW * padH * 2 * sizeof(float);
        bMv_prev = mk(mv_sz, SB, DL);
        uint64_t of_sz = (uint64_t)(padW / 4) * (padH / 4) * 2 * sizeof(float);
        bOf_prev = mk(ofgMemoryPrune ? 256u : of_sz, SB, DL);

        {
            size_t off_dst = 0;
            assert(g_enc.num_outputs <= 8);
            for (int i = 0; i < g_enc.num_outputs; ++i) {
                uint64_t off, cnt;
                mlof2_tensor_span(g_enc, plan_enc, g_enc.io[2 + i], off, cnt);
                enc_off[i] = off_dst;
                enc_cnt[i] = cnt;
                off_dst += (cnt + 255u) & ~255u;
            }
        }

        uint64_t pmask_sz = 0;
        for (int i = 0; i < mlof2_gen_t_int8_graph.num_inputs; ++i) {
            if (std::string(mlof2_gen_t_int8_graph.io_names[i]) == "pmask") {
                uint64_t off, cnt;
                mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, mlof2_gen_t_int8_graph.io[i], off, cnt);
                pmask_sz = cnt;
                break;
            }
        }
        for (int k = 0; k < 3; ++k) bPmask[k] = mk(pmask_sz > 0 ? pmask_sz : 256, SB, DL);

        imgCabA = mkimg(padW, padH);
        imgCabB = mkimg(padW, padH);
        imgQpA  = mkimg(padW / 4, padH / 4);
        imgQpB  = mkimg(padW / 4, padH / 4);

        VkSamplerCreateInfo sci{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
        sci.magFilter = VK_FILTER_LINEAR; sci.minFilter = VK_FILTER_LINEAR;
        sci.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        sci.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sci.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sci.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        if (vkCreateSampler(dev, &sci, nullptr, &samplerLinear) != VK_SUCCESS) return false;
        nss_trace("Mlof2Runtime::init: buffers and sampler created");

        VkDescriptorSetLayoutBinding lb[11];
        for (int i = 0; i < 3; ++i) lb[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        for (int i = 0; i < 4; ++i) lb[3 + i] = {uint32_t(3 + i), VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        for (int i = 0; i < 4; ++i) lb[7 + i] = {uint32_t(7 + i), VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        VkDescriptorSetLayoutCreateInfo dlci{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dlci.bindingCount = 11; dlci.pBindings = lb;
        if (vkCreateDescriptorSetLayout(dev, &dlci, nullptr, &dsl) != VK_SUCCESS) return false;

        VkDescriptorSetLayoutBinding lbx[7];
        for (int i = 0; i < 7; ++i) lbx[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
        lbx[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;                                                     
        VkDescriptorSetLayoutCreateInfo dlcx{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
        dlcx.bindingCount = 7; dlcx.pBindings = lbx;
        if (vkCreateDescriptorSetLayout(dev, &dlcx, nullptr, &dsl_ext) != VK_SUCCESS) return false;
        extInOn = !mlof2_env_on("MLOF2_NO_EXT_IN");

        VkPushConstantRange pcr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 20};
        VkDescriptorSetLayout pls[2] = {dsl, dsl_ext};
        VkPipelineLayoutCreateInfo plci{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
        plci.setLayoutCount = 2; plci.pSetLayouts = pls;
        plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
        if (vkCreatePipelineLayout(dev, &plci, nullptr, &pl) != VK_SUCCESS) return false;

                                                                                                               
        VkDescriptorPoolSize dps[3] = {
            {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 192},
            {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 128 + 16},                                      
            {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 160 + 6 * 16}                       
        };
        VkDescriptorPoolCreateInfo dpci{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
        dpci.maxSets = 64 + 16; dpci.poolSizeCount = 3; dpci.pPoolSizes = dps;
        if (vkCreateDescriptorPool(dev, &dpci, nullptr, &dp) != VK_SUCCESS) return false;

        std::vector<VkDescriptorSetLayout> layouts(7, dsl);
        VkDescriptorSetAllocateInfo dsai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
        dsai.descriptorPool = dp; dsai.descriptorSetCount = 7; dsai.pSetLayouts = layouts.data();
        VkDescriptorSet sets[7];
        if (vkAllocateDescriptorSets(dev, &dsai, sets) != VK_SUCCESS) return false;

        ds_enc  = sets[0]; ds_pair = sets[1]; ds_gen = sets[2]; ds_prep = sets[3];
        {
            VkDescriptorSetLayout xl[16];
            for (int i = 0; i < 16; ++i) xl[i] = dsl_ext;
            VkDescriptorSetAllocateInfo xai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
            xai.descriptorPool = dp; xai.descriptorSetCount = 16; xai.pSetLayouts = xl;
            if (vkAllocateDescriptorSets(dev, &xai, ds_ext_ring) != VK_SUCCESS) return false;
        }
        ds_t[0] = sets[4]; ds_t[1] = sets[5]; ds_t[2] = sets[6];
        if (ofgPath) {
            VkDescriptorSetLayout ofgl[2] = {dsl, dsl};
            VkDescriptorSetAllocateInfo ofg_ai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
            ofg_ai.descriptorPool = dp; ofg_ai.descriptorSetCount = 2; ofg_ai.pSetLayouts = ofgl;
            VkDescriptorSet ofg_s[2];
            if (vkAllocateDescriptorSets(dev, &ofg_ai, ofg_s) == VK_SUCCESS) {
                ds_oft = ofg_s[0];
                ds_fuse = ofg_s[1];
                writeDescriptorSet(ds_oft, bArena_oft, bBlob_oft, bMeta_oft);
                writeDescriptorSet(ds_fuse, bArena_fuse, bBlob_fuse, bMeta_fuse);
            }
        }

        writeDescriptorSet(ds_enc,  bArena_enc,  bBlob_enc,  bMeta_enc);
        writeDescriptorSet(ds_pair, bArena_pair, bBlob_pair, bMeta_pair);
        writeDescriptorSet(ds_gen,  bArena_gen,  bBlob_gen,  bMeta_gen);
        writeDescriptorSet(ds_prep, bArena_prep, bBlob_prep, bMeta_prep);
        for (int k = 0; k < 3; ++k) writeDescriptorSet(ds_t[k], bArena_t, bBlob_t, bMeta_t[k]);

        {
            std::vector<std::pair<Buf*, std::pair<const void*, size_t>>> uploads;
            uploads.push_back({&bBlob_enc, {blob_enc.data(), blob_enc.size()}});
            uploads.push_back({&bMeta_enc, {plan_enc.meta.data(), plan_enc.meta.size() * 4}});
            uploads.push_back({&bBlob_pair, {blob_pair.data(), blob_pair.size()}});
            uploads.push_back({&bMeta_pair, {plan_pair.meta.data(), plan_pair.meta.size() * 4}});
            uploads.push_back({&bBlob_gen, {blob_gen.data(), blob_gen.size()}});
            uploads.push_back({&bMeta_gen, {plan_gen.meta.data(), plan_gen.meta.size() * 4}});
            uploads.push_back({&bBlob_prep, {blob_prep.data(), blob_prep.size()}});
            uploads.push_back({&bMeta_prep, {plan_prep.meta.data(), plan_prep.meta.size() * 4}});
            uploads.push_back({&bBlob_t, {blob_t.data(), blob_t.size()}});
            for (int k = 0; k < 3; ++k) uploads.push_back({&bMeta_t[k], {meta_t[k].data(), meta_t[k].size() * 4}});
            if (ofgPath) {
                uploads.push_back({&bBlob_oft, {blob_oft.data(), blob_oft.size()}});
                uploads.push_back({&bMeta_oft, {plan_oft.meta.data(), plan_oft.meta.size() * 4}});
                uploads.push_back({&bBlob_fuse, {blob_fuse.data(), blob_fuse.size()}});
                uploads.push_back({&bMeta_fuse, {plan_fuse.meta.data(), plan_fuse.meta.size() * 4}});
            }
            prepareStagingUpload(uploads);
        }

        started = true;
        blkZeroed = false;
        compileAbort = false;
        compileFailed = false;
        imgBarriers = mlof2_env_on("MLOF2_IMG_BARRIERS");
        prof.on = mlof2_env_on("MLOF2_PROFILE");
        if (prof.on) {
            char pv[16];
            mlof2_env("MLOF2_PROFILE", pv, sizeof pv);
            prof.every = atoi(pv) > 1 ? uint32_t(atoi(pv)) : 24u;
            prof.coarse = mlof2_env("MLOF2_PROFILE_COARSE", pv, sizeof pv) ? atoi(pv) : 0;
        }
        if (prof.on) {
            VkPhysicalDeviceProperties pp; vkGetPhysicalDeviceProperties(pd, &pp);
            prof.period_ms = double(pp.limits.timestampPeriod) * 1e-6;
            VkQueryPoolCreateInfo qpi{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
            qpi.queryType = VK_QUERY_TYPE_TIMESTAMP; qpi.queryCount = Prof::kQ;
            for (auto& q : prof.qp) if (vkCreateQueryPool(dev, &qpi, nullptr, &q) != VK_SUCCESS) prof.on = false;
        }
        auto compile = [this]() {
            const bool ok = initPipelines() && initInputPrep() && initGlue();
            if (ok && !compileAbort) {
                nss_trace("Mlof2Runtime::init: pipelines initialized");
                ready = true;
            } else {
                nss_trace("Mlof2Runtime::init: pipeline compilation %s", compileAbort ? "aborted" : "FAILED");
                compileFailed = !compileAbort;
            }
        };
        if (mlof2_env_is("MLOF2_SYNC_COMPILE", "1")) {
            compile();
            return ready.load();
        }
        compileThread = std::thread(compile);
        nss_trace("Mlof2Runtime::init: compiling pipelines in the background");
        return true;
    }

                                                                                                                        
                                                                                                                 
    void destroy(bool waitIdle = true) {
        compileAbort = true;                                                        
        if (compileThread.joinable()) compileThread.join();
        started = false;
        if (dev != VK_NULL_HANDLE && waitIdle) {
            vkDeviceWaitIdle(dev);
        }
        if (dev != VK_NULL_HANDLE && prof.on) {
            profReport();
            for (auto& q : prof.qp) if (q) { vkDestroyQueryPool(dev, q, nullptr); q = VK_NULL_HANDLE; }
        }
        prof = Prof{};

        for (auto& sm : smod) if (sm) vkDestroyShaderModule(dev, sm, nullptr);
        smod.clear();
        for (auto& p : spec_pipes) if (p.second) vkDestroyPipeline(dev, p.second, nullptr);
        spec_pipes.clear();
        for (auto& p : pipe_def) if (p) vkDestroyPipeline(dev, p, nullptr);
        pipe_def.clear();

        if (pipe_out) { vkDestroyPipeline(dev, pipe_out, nullptr); pipe_out = VK_NULL_HANDLE; }
        if (pipe_glue) { vkDestroyPipeline(dev, pipe_glue, nullptr); pipe_glue = VK_NULL_HANDLE; }
        if (pl_glue) { vkDestroyPipelineLayout(dev, pl_glue, nullptr); pl_glue = VK_NULL_HANDLE; }
        if (dsl_glue) { vkDestroyDescriptorSetLayout(dev, dsl_glue, nullptr); dsl_glue = VK_NULL_HANDLE; }
        if (pl_out) { vkDestroyPipelineLayout(dev, pl_out, nullptr); pl_out = VK_NULL_HANDLE; }
        if (dsl_out) { vkDestroyDescriptorSetLayout(dev, dsl_out, nullptr); dsl_out = VK_NULL_HANDLE; }
        if (pipe_prep) { vkDestroyPipeline(dev, pipe_prep, nullptr); pipe_prep = VK_NULL_HANDLE; }
        if (pl_prep) { vkDestroyPipelineLayout(dev, pl_prep, nullptr); pl_prep = VK_NULL_HANDLE; }
        if (dsl_prep) { vkDestroyDescriptorSetLayout(dev, dsl_prep, nullptr); dsl_prep = VK_NULL_HANDLE; }

        if (dp) { vkDestroyDescriptorPool(dev, dp, nullptr); dp = VK_NULL_HANDLE; }
        if (pl) { vkDestroyPipelineLayout(dev, pl, nullptr); pl = VK_NULL_HANDLE; }
        if (dsl) { vkDestroyDescriptorSetLayout(dev, dsl, nullptr); dsl = VK_NULL_HANDLE; }
        if (dsl_ext) { vkDestroyDescriptorSetLayout(dev, dsl_ext, nullptr); dsl_ext = VK_NULL_HANDLE; }
        if (samplerLinear) { vkDestroySampler(dev, samplerLinear, nullptr); samplerLinear = VK_NULL_HANDLE; }

        freeImg(imgCabA); freeImg(imgCabB); freeImg(imgQpA); freeImg(imgQpB);

        if (tAliasesPrep) { bArena_t = Buf{}; tAliasesPrep = false; }
        freeBuf(bArena_enc); freeBuf(bArena_pair); freeBuf(bArena_gen); freeBuf(bArena_prep); freeBuf(bArena_t);
        lightPath = false;                                                      
        freeBuf(bBlob_enc); freeBuf(bBlob_pair); freeBuf(bBlob_gen); freeBuf(bBlob_prep); freeBuf(bBlob_t);
        freeBuf(bMeta_enc); freeBuf(bMeta_pair); freeBuf(bMeta_gen); freeBuf(bMeta_prep);
        for (int k = 0; k < 3; ++k) freeBuf(bMeta_t[k]);
        for (int k = 0; k < 3; ++k) freeBuf(bPmask[k]);
        freeBuf(bEnc_curr); freeBuf(bEnc_prev);
        if (ofgPath) {
            freeBuf(bArena_oft); freeBuf(bBlob_oft); freeBuf(bMeta_oft);
            bArena_fuse.b = VK_NULL_HANDLE; bArena_fuse.m = VK_NULL_HANDLE;
            freeBuf(bBlob_fuse); freeBuf(bMeta_fuse);
            dpipe_oft.clear();
            dpipe_fuse.clear();
        }
        freeBuf(bMv_prev); freeBuf(bOf_prev);

        ready = false;
        dev = VK_NULL_HANDLE;
        nss_trace("Mlof2Runtime::destroy: freed all MLOF2 buffers and pipelines");
    }

    void reset() {
        oftPrefixReady = false;
        has_prev = false;
        pair_first = true;
        prev_pair_valid = false;
        lastPairFrameID = UINT64_MAX;
        snapValid = false;
        nss_trace("Mlof2Runtime::reset: state reset");
    }

    void recordOp(VkCommandBuffer cb, const Mlof2Plan& plan, const std::vector<VkPipeline>& dpipe, const Mlof2Dispatch& d) {
        if (d.barrier_before) {
            VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT;

            VkImageMemoryBarrier imb[4];
            for (int i = 0; i < 4; ++i) {
                imb[i] = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
                imb[i].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
                imb[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
                imb[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                imb[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                imb[i].image = all_imgs[i]->image;
                imb[i].subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
                imb[i].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
                imb[i].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            }

                                                                                                                     
                                                                                                                 
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                                 0, 1, &mb, 0, nullptr, imgBarriers ? 4u : 0u, imgBarriers ? imb : nullptr);
        }
        uint32_t pcv[5] = {d.op, plan.tb, plan.sb, plan.ob, plan.fc};
        VkPipeline pp = dpipe[&d - plan.dispatches.data()];
        if (pp != boundPipe) { vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pp); boundPipe = pp; }
        vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv);
        vkCmdDispatch(cb, d.gx, d.gy, 1);
        traceActive(pp, planStage(plan), d.op, d.kernel, d.gx, d.gy);
        profMark(cb, (planStage(plan) << 16) | d.op, d.kernel);                                            
    }

    void syncPrepToT(VkCommandBuffer cb) {
        uint64_t prep_off_vig, prep_sz_vig, t_off_vig, t_sz_vig;
        uint64_t prep_off_cab, prep_sz_cab, t_off_cab, t_sz_cab;
        uint64_t prep_off_ph,  prep_sz_ph,  t_off_ph,  t_sz_ph;
        uint64_t prep_off_qp,  prep_sz_qp,  t_off_qp,  t_sz_qp;
        uint64_t prep_off_db,  prep_sz_db,  t_off_db,  t_sz_db;
        uint64_t t_off_ndc, t_sz_ndc;
        uint64_t pair_off_co, pair_sz_co,   t_off_co,  t_sz_co;

        mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 9, prep_off_vig, prep_sz_vig);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 0, t_off_vig, t_sz_vig);

        mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 11, prep_off_cab, prep_sz_cab);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 1, t_off_cab, t_sz_cab);

        mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 12, prep_off_ph, prep_sz_ph);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 2, t_off_ph, t_sz_ph);

        mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 13, prep_off_qp, prep_sz_qp);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 3, t_off_qp, t_sz_qp);

        mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 3, prep_off_db, prep_sz_db);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 4, t_off_db, t_sz_db);

        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 5, t_off_ndc, t_sz_ndc);

        mlof2_tensor_span(pairGraph(), plan_pair, pairOut("conf_occ"), pair_off_co, pair_sz_co);
        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, 6, t_off_co, t_sz_co);

        const VkBufferCopy all_xfer[6] = {
            {prep_off_vig, t_off_vig, std::min(prep_sz_vig, t_sz_vig)},
            {prep_off_cab, t_off_cab, std::min(prep_sz_cab, t_sz_cab)},
            {prep_off_ph,  t_off_ph,  std::min(prep_sz_ph,  t_sz_ph)},
            {prep_off_qp,  t_off_qp,  std::min(prep_sz_qp,  t_sz_qp)},
            {prep_off_db,  t_off_db,  std::min(prep_sz_db,  t_sz_db)},
            {prep_extra_ndc_off, t_off_ndc, std::min(sz_ndc, t_sz_ndc)}
        };
        VkBufferCopy bc_xfer[6];                                                                                   
        uint32_t n_xfer = 0;
        for (int i = 0; i < 6; ++i) if (!tRedirect[i]) bc_xfer[n_xfer++] = all_xfer[i];

        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT;
                                                                                                          
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                             0, 1, &mb, 0, nullptr, 0, nullptr);

                              
        if (n_xfer) vkCmdCopyBuffer(cb, bArena_prep.b, bArena_t.b, n_xfer, bc_xfer);
        profMark(cb, (PS_MISC << 16) | 258u, 65026u);             

                                                                                 
        glueCo(cb, ds_glue_t, pair_off_co, t_off_co);

        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

        VkImageMemoryBarrier imb_xfer[4];
        for (int i = 0; i < 4; ++i) {
            imb_xfer[i] = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
            imb_xfer[i].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
            imb_xfer[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
            imb_xfer[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imb_xfer[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imb_xfer[i].image = all_imgs[i]->image;
            imb_xfer[i].subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
            imb_xfer[i].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            imb_xfer[i].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        }
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 4, imb_xfer);
    }

    void recordFrame(VkCommandBuffer cb, const Mlof2FrameInputs& inputs) {
        if (inputs.reset) reset();

        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_enc, 0, nullptr);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
        for (const auto& d : plan_enc.dispatches) {
            recordOp(cb, plan_enc, dpipe_enc, d);
        }

        std::swap(bEnc_prev, bEnc_curr);

        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

        const auto& g_enc = encGraph();
        VkBufferCopy bc[8];
        size_t off_dst = 0;
        for (int i = 0; i < g_enc.num_outputs; ++i) {
            uint64_t off, cnt;
            mlof2_tensor_span(g_enc, plan_enc, g_enc.io[g_enc.num_inputs + i], off, cnt);
            bc[i] = {off, off_dst, cnt};
            off_dst += (cnt + 255u) & ~255u;
        }
        vkCmdCopyBuffer(cb, bArena_enc.b, bEnc_curr.b, uint32_t(g_enc.num_outputs), bc);
        profMark(cb, (PS_MISC << 16) | 259u, 65027u);             

        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
    }

    void syncEncToPair(VkCommandBuffer cb) {
                                                                                                                        
                                                                                            
        const auto& g_pair = pairGraph();
        const auto& g_enc = encGraph();
        const int np = g_pair.num_inputs;
        assert(np <= 8);
        int enc_map[8] = {5, 0, 1, 2, 3, 4, -1, -1};
        for (int i = 0; i < np; ++i) {
            const char* pn = g_pair.io_names[i];
            char want[16];
            snprintf(want, sizeof want, "%s", pn);
            if (pn[0] == 'q') want[0] = 'f';
            for (int j = 0; j < g_enc.num_outputs; ++j)
                if (strcmp(g_enc.io_names[g_enc.num_inputs + j], want) == 0) { enc_map[i] = j; break; }
            assert(enc_map[i] >= 0 && "pair input without an encoder output");
        }

        VkBufferCopy bc0[8];
        VkBufferCopy bc1[8];

        for (int i = 0; i < np; ++i) {
            int e_idx = enc_map[i];
            uint64_t p_off, p_total_cnt;
            mlof2_tensor_span(g_pair, plan_pair, g_pair.io[i], p_off, p_total_cnt);
            uint64_t batch_bytes = p_total_cnt / 2;

            bc0[i] = {enc_off[e_idx], p_off, batch_bytes};
            bc1[i] = {enc_off[e_idx], p_off + batch_bytes, batch_bytes};
        }

        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

                                                
        vkCmdCopyBuffer(cb, bEnc_curr.b, bArena_pair.b, uint32_t(np), bc0);
        profMark(cb, (PS_MISC << 16) | 260u, 65028u);             
                                                
        vkCmdCopyBuffer(cb, bEnc_prev.b, bArena_pair.b, uint32_t(np), bc1);
        profMark(cb, (PS_MISC << 16) | 261u, 65029u);             

        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
    }

    void syncPairToGen(VkCommandBuffer cb, uint32_t mfg) {
        if (ofgMemoryPrune) {
                                                                            
                                                                            
            VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                                 VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
            uint64_t offset, bytes;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 7, offset, bytes);
            const bool mvExt = extMvap && lanesActive && snapValid;
            if (has_prev && !pair_first && bMv_prev.b) {
                VkBufferCopy cp{0, offset, std::min(bytes, uint64_t(bMv_prev.sz))};
                if (!mvExt) vkCmdCopyBuffer(cb, bMv_prev.b, bArena_gen.b, 1, &cp);
            } else vkCmdFillBuffer(cb, bArena_gen.b, offset, bytes, 0u);
            if (bMv_prev.b && !(extMvap && lanesActive)) {
                VkMemoryBarrier war{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
                war.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                war.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT;
                vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &war, 0, nullptr, 0, nullptr);
                mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 5, offset, bytes);
                VkBufferCopy cp = lanesActive ? VkBufferCopy{gen_extra_mvfull_off, 0, std::min(sz_mvfull, uint64_t(bMv_prev.sz))}
                    : VkBufferCopy{offset, 0, std::min(bytes, uint64_t(bMv_prev.sz))};
                vkCmdCopyBuffer(cb, bArena_gen.b, bMv_prev.b, 1, &cp);
            }
            mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
            return;
        }
        const auto& g_pair = pairGraph();
        uint64_t pair_off_of, pair_cnt_of;
        mlof2_tensor_span(g_pair, plan_pair, pairOut("of4"), pair_off_of, pair_cnt_of);
        uint64_t pair_off_co, pair_cnt_co;
        mlof2_tensor_span(g_pair, plan_pair, pairOut("conf_occ"), pair_off_co, pair_cnt_co);

        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

        if (!ofgPath && mfg == 4) {
            uint64_t prep_off_of, prep_cnt_of;
            mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 7, prep_off_of, prep_cnt_of);
            VkBufferCopy bc_of{pair_off_of, prep_off_of, std::min(pair_cnt_of, prep_cnt_of)};
            vkCmdCopyBuffer(cb, bArena_pair.b, bArena_prep.b, 1, &bc_of);
            profMark(cb, (PS_MISC << 16) | 262u, 65030u);             

            uint64_t prep_off_mvap, prep_cnt_mvap;
            mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 6, prep_off_mvap, prep_cnt_mvap);
            uint64_t prep_off_ofprev, prep_cnt_ofprev;
            mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 8, prep_off_ofprev, prep_cnt_ofprev);

            const bool mvExt = extMvap && lanesActive && snapValid;                                            
            if (has_prev && !pair_first && bMv_prev.b && bOf_prev.b) {
                VkBufferCopy bc_mvap{0, prep_off_mvap, std::min((uint64_t)prep_cnt_mvap, (uint64_t)bMv_prev.sz)};
                if (!mvExt) vkCmdCopyBuffer(cb, bMv_prev.b, bArena_prep.b, 1, &bc_mvap);
                profMark(cb, (PS_MISC << 16) | 263u, 65031u);             
                VkBufferCopy bc_ofprev{0, prep_off_ofprev, std::min((uint64_t)prep_cnt_ofprev, (uint64_t)bOf_prev.sz)};
                vkCmdCopyBuffer(cb, bOf_prev.b, bArena_prep.b, 1, &bc_ofprev);
                profMark(cb, (PS_MISC << 16) | 264u, 65032u);             
            } else {
                vkCmdFillBuffer(cb, bArena_prep.b, prep_off_mvap, prep_cnt_mvap, 0);
                vkCmdFillBuffer(cb, bArena_prep.b, prep_off_ofprev, prep_cnt_ofprev, 0);
            }
            {                                                                                     
                VkMemoryBarrier tb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
                tb.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                tb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &tb, 0, nullptr, 0, nullptr);
            }

            uint64_t prep_off_mv, prep_cnt_mv;
            mlof2_tensor_span(mlof2_gen_prep_int8_graph, plan_prep, 4, prep_off_mv, prep_cnt_mv);
            if (bMv_prev.b && bOf_prev.b) {
                VkBufferCopy bc_save_mv = lanesActive ? VkBufferCopy{prep_extra_mvfull_off, 0, std::min(sz_mvfull, (uint64_t)bMv_prev.sz)}
                                                      : VkBufferCopy{prep_off_mv, 0, std::min(prep_cnt_mv, (uint64_t)bMv_prev.sz)};
                if (!(extMvap && lanesActive)) vkCmdCopyBuffer(cb, bArena_prep.b, bMv_prev.b, 1, &bc_save_mv);
                profMark(cb, (PS_MISC << 16) | 265u, 65033u);             
                VkBufferCopy bc_save_of{pair_off_of, 0, std::min(pair_cnt_of, (uint64_t)bOf_prev.sz)};
                vkCmdCopyBuffer(cb, bArena_pair.b, bOf_prev.b, 1, &bc_save_of);
                profMark(cb, (PS_MISC << 16) | 266u, 65034u);              
            }
        } else {
            uint64_t gen_off_of, gen_cnt_of;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 8, gen_off_of, gen_cnt_of);
            uint64_t gen_off_co, gen_cnt_co;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 10, gen_off_co, gen_cnt_co);

            VkBufferCopy bc_of{pair_off_of, gen_off_of, std::min(pair_cnt_of, gen_cnt_of)};
            vkCmdCopyBuffer(cb, bArena_pair.b, bArena_gen.b, 1, &bc_of);
            profMark(cb, (PS_MISC << 16) | 267u, 65035u);              

            glueCo(cb, ds_glue_gen, pair_off_co, gen_off_co);                                                

            uint64_t gen_off_mvap, gen_cnt_mvap;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 7, gen_off_mvap, gen_cnt_mvap);
            uint64_t gen_off_ofprev, gen_cnt_ofprev;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 9, gen_off_ofprev, gen_cnt_ofprev);

            const bool mvExt = extMvap && lanesActive && snapValid;                                            
            if (has_prev && !pair_first && bMv_prev.b && bOf_prev.b) {
                VkBufferCopy bc_mvap{0, gen_off_mvap, std::min((uint64_t)gen_cnt_mvap, (uint64_t)bMv_prev.sz)};
                if (!mvExt) vkCmdCopyBuffer(cb, bMv_prev.b, bArena_gen.b, 1, &bc_mvap);
                profMark(cb, (PS_MISC << 16) | 268u, 65036u);              
                VkBufferCopy bc_ofprev{0, gen_off_ofprev, std::min((uint64_t)gen_cnt_ofprev, (uint64_t)bOf_prev.sz)};
                vkCmdCopyBuffer(cb, bOf_prev.b, bArena_gen.b, 1, &bc_ofprev);
                profMark(cb, (PS_MISC << 16) | 269u, 65037u);              
            } else {
                vkCmdFillBuffer(cb, bArena_gen.b, gen_off_mvap, gen_cnt_mvap, 0);
                vkCmdFillBuffer(cb, bArena_gen.b, gen_off_ofprev, gen_cnt_ofprev, 0);
            }
            {                                                                                     
                VkMemoryBarrier tb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
                tb.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                tb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &tb, 0, nullptr, 0, nullptr);
            }

            uint64_t gen_off_mv, gen_cnt_mv;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 5, gen_off_mv, gen_cnt_mv);
            if (bMv_prev.b && bOf_prev.b) {
                VkBufferCopy bc_save_mv = lanesActive ? VkBufferCopy{gen_extra_mvfull_off, 0, std::min(sz_mvfull, (uint64_t)bMv_prev.sz)}
                                                      : VkBufferCopy{gen_off_mv, 0, std::min(gen_cnt_mv, (uint64_t)bMv_prev.sz)};
                if (!(extMvap && lanesActive)) vkCmdCopyBuffer(cb, bArena_gen.b, bMv_prev.b, 1, &bc_save_mv);
                profMark(cb, (PS_MISC << 16) | 270u, 65038u);              
                VkBufferCopy bc_save_of{pair_off_of, 0, std::min(pair_cnt_of, (uint64_t)bOf_prev.sz)};
                vkCmdCopyBuffer(cb, bArena_pair.b, bOf_prev.b, 1, &bc_save_of);
                profMark(cb, (PS_MISC << 16) | 271u, 65039u);              
            }
        }

        mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
    }

    void recordPair(VkCommandBuffer cb, uint32_t mfg) {
        oftPrefixReady = false;
        syncEncToPair(cb);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_pair, 0, nullptr);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
        for (const auto& d : plan_pair.dispatches) {
            recordOp(cb, plan_pair, dpipe_pair, d);
        }

        if (!ofgPath) {
            syncPairToGen(cb, mfg);
        }

        if (ofgPath) {
            VkMemoryBarrier mb_pair_to_transfer{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_pair_to_transfer.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_pair_to_transfer.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb_pair_to_transfer, 0, nullptr, 0, nullptr);

            const auto& gp = (ofgNoL4) ? mlof2_rec8_nol4::mlof2_pair_int8_graph : pairGraph();
            uint64_t pair_off_of = 0, pair_cnt_of = 0;
            int t_of = 116;                               
            for (int ti = 0; ti < gp.num_tensors; ++ti) {
                if (gp.tensors[ti].c == 2 && gp.tensors[ti].s == 4 && gp.tensors[ti].n == 2 && gp.tensors[ti].fmt == 1) {
                    t_of = ti; break;
                }
            }
            mlof2_tensor_span(gp, plan_pair, t_of, pair_off_of, pair_cnt_of);
            uint64_t batch_sz = pair_cnt_of / 2;

            const auto& go = ofgHalf ? g_mlof2_oft_half_graph : g_mlof2_oft_graph;
            uint64_t off_oft_ca = 0, sz_oft_ca = 0;
            uint64_t off_oft_cb = 0, sz_oft_cb = 0;
            uint64_t off_oft_of_ab = 0, sz_oft_of_ab = 0;
            uint64_t off_oft_of_ba = 0, sz_oft_of_ba = 0;
            mlof2_tensor_span(go, plan_oft, 0, off_oft_ca, sz_oft_ca);
            mlof2_tensor_span(go, plan_oft, 1, off_oft_cb, sz_oft_cb);
            mlof2_tensor_span(go, plan_oft, 2, off_oft_of_ab, sz_oft_of_ab);
            mlof2_tensor_span(go, plan_oft, 3, off_oft_of_ba, sz_oft_of_ba);

            VkBuffer src_gen = bArena_gen.b;
            VkBufferCopy bc_col[2] = {
                {m_off_ca, off_oft_ca, sz_oft_ca},
                {m_off_cb, off_oft_cb, sz_oft_cb}
            };
            vkCmdCopyBuffer(cb, src_gen, bArena_oft.b, 2, bc_col);

            VkBufferCopy bc_flow[2] = {
                {pair_off_of + batch_sz, off_oft_of_ab, std::min(batch_sz, sz_oft_of_ab)},
                {pair_off_of,            off_oft_of_ba, std::min(batch_sz, sz_oft_of_ba)}
            };
            vkCmdCopyBuffer(cb, bArena_pair.b, bArena_oft.b, 2, bc_flow);

            VkMemoryBarrier mb_pair_to_oft{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_pair_to_oft.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            mb_pair_to_oft.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_pair_to_oft, 0, nullptr, 0, nullptr);

                                                                                                            
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_gen, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            if (plan_gen.dispatches.size() > 3) {
                recordOp(cb, plan_gen, dpipe_gen, plan_gen.dispatches[3]);
            }

            VkMemoryBarrier mb_gen_pair{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_gen_pair.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_gen_pair.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_gen_pair, 0, nullptr, 0, nullptr);
        }

        if (!ofgPath && mfg == 4) {
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_prep, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            for (const auto& d : plan_prep.dispatches) {
                recordOp(cb, plan_prep, dpipe_prep, d);
            }
            syncPrepToT(cb);
        }
    }

    void recordGen(VkCommandBuffer cb, float t, uint32_t k, uint32_t mfg, VkImage outImage, VkImageView outView) {
        if (ofgPath) {
                                                                                            
            float* fc_gen = (float*)&plan_gen.meta[plan_gen.fc];
            fc_gen[MLOF2_FC_T] = t;
            cmdUpdateFc(cb, bMeta_gen, plan_gen.fc, (const uint32_t*)fc_gen);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_gen, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            if (plan_gen.dispatches.size() > 5) {
                recordOp(cb, plan_gen, dpipe_gen, plan_gen.dispatches[5]);
            }

            VkMemoryBarrier mb_inv{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_inv.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_inv.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb_inv, 0, nullptr, 0, nullptr);

                                                            
            uint64_t gen_off_inv = 0, gen_sz_inv = 0;
            mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, 17, gen_off_inv, gen_sz_inv);
            VkBufferCopy bc_inv{gen_off_inv, off_cand_inv_mv, gen_sz_inv};
            vkCmdCopyBuffer(cb, bArena_gen.b, bArena_oft.b, 1, &bc_inv);

                                                                   
            float* fc_oft = (float*)&plan_oft.meta[plan_oft.fc];
            fc_oft[MLOF2_FC_T] = t;
            cmdUpdateFc(cb, bMeta_oft, plan_oft.fc, (const uint32_t*)fc_oft);

            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_oft, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            for (const auto& d : plan_oft.dispatches) {
                if (oftPrefixReady && d.op < oftPrefixOps) continue;
                recordOp(cb, plan_oft, dpipe_oft, d);
            }
            oftPrefixReady = true;

                                                                                       
            VkMemoryBarrier mb_sync{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_sync.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
            mb_sync.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                                 VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_sync, 0, nullptr, 0, nullptr);

                                            
            float fc_extra[MLOF2_FC_WORDS] = {};
            fc_extra[MLOF2_FC_T] = t;
            fc_extra[FC_OFG_DEBUG] = float(ofgDebugView);
            fc_extra[FC_EXT_DISP_W] = float(dispW);
            fc_extra[FC_EXT_DISP_H] = float(dispH);
            fc_extra[FC_EXT_OUT] = (outView != VK_NULL_HANDLE) ? 1.0f : 0.0f;
            fc_extra[FC_EXT_HUD] = float(extHudJob);
            cmdUpdateFc(cb, bMeta_fuse, extra_fc, (const uint32_t*)fc_extra);

                                              
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_fuse, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            {
                uint32_t pcv_mv[5] = {0u, extra_tb, extra_sb, extra_ob, extra_fc};
                vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_def[g_mlof2_kernel_cand_mv]); boundPipe = pipe_def[g_mlof2_kernel_cand_mv];
                vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv_mv);
                vkCmdDispatch(cb, (padW * padH + 63u) / 64u, 1, 1);
            }
            profMark(cb, (PS_CAND << 16) | 0u, uint32_t(g_mlof2_kernel_cand_mv));
            traceActive(pipe_def[g_mlof2_kernel_cand_mv], PS_CAND, 0u, uint32_t(g_mlof2_kernel_cand_mv), (padW * padH + 63u) / 64u, 1u);

            VkMemoryBarrier mb_cand{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_cand.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_cand.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_cand, 0, nullptr, 0, nullptr);

                                                
            {
                uint32_t pcv_prep[5] = {1u, extra_tb, extra_sb, extra_ob, extra_fc};
                vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_def[g_mlof2_kernel_fuse_prep]); boundPipe = pipe_def[g_mlof2_kernel_fuse_prep];
                vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv_prep);
                vkCmdDispatch(cb, ((padW / 2u) * (padH / 2u) + 63u) / 64u, 1, 1);
            }
            profMark(cb, (PS_CAND << 16) | 1u, uint32_t(g_mlof2_kernel_fuse_prep));
            traceActive(pipe_def[g_mlof2_kernel_fuse_prep], PS_CAND, 1u, uint32_t(g_mlof2_kernel_fuse_prep), ((padW / 2u) * (padH / 2u) + 63u) / 64u, 1u);

            VkMemoryBarrier mb_prep{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_prep.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_prep.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_prep, 0, nullptr, 0, nullptr);

                                              
            float* fc_fuse = (float*)&plan_fuse.meta[plan_fuse.fc];
            fc_fuse[MLOF2_FC_T] = t;
            cmdUpdateFc(cb, bMeta_fuse, plan_fuse.fc, (const uint32_t*)fc_fuse);

            for (const auto& d : plan_fuse.dispatches) {
                recordOp(cb, plan_fuse, dpipe_fuse, d);
            }

            VkMemoryBarrier mb_fuse{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_fuse.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_fuse.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb_fuse, 0, nullptr, 0, nullptr);

                                                 
            {
                uint32_t pcv_blend[5] = {2u, extra_tb, extra_sb, extra_ob, extra_fc};
                vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_def[g_mlof2_kernel_fuse_blend]); boundPipe = pipe_def[g_mlof2_kernel_fuse_blend];
                vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv_blend);
                vkCmdDispatch(cb, (padW * padH + 63u) / 64u, 1, 1);
            }
            profMark(cb, (PS_BLEND << 16), uint32_t(g_mlof2_kernel_fuse_blend));
            traceActive(pipe_def[g_mlof2_kernel_fuse_blend], PS_BLEND, 0u, uint32_t(g_mlof2_kernel_fuse_blend), (padW * padH + 63u) / 64u, 1u);

            VkMemoryBarrier mb_end{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb_end.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb_end.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb_end, 0, nullptr, 0, nullptr);

            has_prev = true;
            return;
        }
        if (mfg == 4) {
            assert(k >= 1 && k <= 3);
            uint32_t kidx = k - 1;

            uint64_t pmask_off = 0, pmask_cnt = 0;
            for (int i = 0; i < mlof2_gen_t_int8_graph.num_inputs; ++i) {
                if (std::string(mlof2_gen_t_int8_graph.io_names[i]) == "pmask") {
                    mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, mlof2_gen_t_int8_graph.io[i], pmask_off, pmask_cnt);
                    break;
                }
            }

            VkBufferCopy c_in{0, pmask_off, pmask_cnt};
            if (!pmaskInArena) vkCmdCopyBuffer(cb, bPmask[kidx].b, bArena_t.b, 1, &c_in);
            profMark(cb, (PS_MISC << 16) | 272u, 65040u);              

            VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_t[kidx], 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            for (const auto& d : plan_t.dispatches) {
                recordOp(cb, plan_t, dpipe_t, d);
            }

            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

            VkBufferCopy c_out{pmask_off, 0, pmask_cnt};
            if (!pmaskInArena) vkCmdCopyBuffer(cb, bArena_t.b, bPmask[kidx].b, 1, &c_out);
            profMark(cb, (PS_MISC << 16) | 273u, 65041u);              

            mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
        } else {
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_gen, 0, nullptr);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            for (const auto& d : plan_gen.dispatches) {
                recordOp(cb, plan_gen, dpipe_gen, d);
            }
        }

        has_prev = true;
    }

    void recordMlof2Job(VkCommandBuffer cb, const Mlof2JobDesc& desc) {
        nss_trace("recordMlof2Job: begin reset=%d frameID=%llu has_prev=%d k=%u mfg=%u t=%.3f hasCam=%d mvScale=(%.6f, %.6f)",
                  (int)desc.reset, (unsigned long long)desc.frameID, (int)has_prev, desc.k, desc.mfg, desc.t, (int)desc.hasCam,
                  desc.mvScale[0], desc.mvScale[1]);
        if (!ready) {
            static bool s_waitReady = (getenv("MLOF2_WAIT_READY") != nullptr || getenv("HARNESS_DATASET") != nullptr);
            if (s_waitReady) {
                while (!ready && !compileAbort && !compileFailed) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(5));
                }
            }
        }
        if (!ready) { nss_trace("recordMlof2Job: not ready!"); return; }
        if (!weightsUploaded) {
            cmdUploadStagedWeights(cb);
        }
        profBegin(cb);
        boundPipe = VK_NULL_HANDLE;                                                                                  
                                                                         
        if (!blkZeroed && ofgPath) {
            Buf* initBuffers[] = {&bArena_enc, &bArena_pair, &bArena_gen, &bArena_prep, &bArena_oft};
            for (Buf* b : initBuffers) if (b->b && b->sz) vkCmdFillBuffer(cb, b->b, 0, b->sz, 0u);
            if (!tAliasesPrep && bArena_t.b && bArena_t.sz) vkCmdFillBuffer(cb, bArena_t.b, 0, bArena_t.sz, 0u);
        }
        if (!blkZeroed) {                                                                                                
            const struct { Buf* b; const Mlof2Plan* p; } ar[5] = {{&bArena_enc, &plan_enc}, {&bArena_pair, &plan_pair},
                {&bArena_gen, &plan_gen}, {&bArena_prep, &plan_prep}, {&bArena_t, &plan_t}};
            for (const auto& a : ar)
                if (!(ofgMemoryPrune && (a.p == &plan_prep || a.p == &plan_t)) && a.p->blk_hi > a.p->blk_lo)
                    vkCmdFillBuffer(cb, a.b->b, a.p->blk_lo, a.p->blk_hi - a.p->blk_lo, 0u);
            VkMemoryBarrier zb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            zb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            zb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &zb, 0, nullptr, 0, nullptr);
            nss_trace("recordMlof2Job: zeroed channel-blocked regions (enc %llu, pair %llu, gen %llu, prep %llu, t %llu bytes)",
                      (unsigned long long)(plan_enc.blk_hi - plan_enc.blk_lo), (unsigned long long)(plan_pair.blk_hi - plan_pair.blk_lo),
                      (unsigned long long)(plan_gen.blk_hi - plan_gen.blk_lo), (unsigned long long)(plan_prep.blk_hi - plan_prep.blk_lo),
                      (unsigned long long)(plan_t.blk_hi - plan_t.blk_lo));
            blkZeroed = true;
        }
        ringIdx = (ringIdx + 1) % kDsRing;                                                                         
        ds_prep_io = ds_prep_ring[ringIdx];
        ds_out = ds_out_ring[ringIdx];
        ds_ext = ds_ext_ring[ringIdx];
        if (desc.reset || (lastPairFrameID != UINT64_MAX && desc.frameID < lastPairFrameID)) {
            reset();
        }

        VkDescriptorImageInfo dii[5] = {
            {samplerLinear, desc.colCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL},
            {samplerLinear, desc.colPrevView ? desc.colPrevView : desc.colCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL},
            {samplerLinear, desc.depCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL},
            {samplerLinear, desc.depPrevView ? desc.depPrevView : desc.depCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL},
            {samplerLinear, desc.mvView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL}
        };

        VkDescriptorBufferInfo dbi_enc{bArena_enc.b, 0, VK_WHOLE_SIZE};                                       
        VkDescriptorBufferInfo dbi_gen{(!ofgPath && desc.mfg == 4) ? bArena_prep.b : bArena_gen.b, 0, VK_WHOLE_SIZE};

        {
            const bool hud = desc.hudMode != 0u && desc.fullColView != VK_NULL_HANDLE;
            VkDescriptorImageInfo xo{VK_NULL_HANDLE, desc.outView, VK_IMAGE_LAYOUT_GENERAL};
            VkDescriptorImageInfo xf{samplerLinear, hud ? desc.fullColView : desc.colCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
            VkWriteDescriptorSet xw[7];
            for (int i = 0; i < 7; ++i) {
                xw[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
                xw[i].dstSet = ds_ext; xw[i].dstBinding = uint32_t(i); xw[i].descriptorCount = 1;
                xw[i].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER; xw[i].pImageInfo = i < 5 ? &dii[i] : (i == 5 ? &xo : &xf);
            }
            xw[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
            extOutJob = !ofgPath && extInOn && desc.outView != VK_NULL_HANDLE;
            vkUpdateDescriptorSets(dev, desc.outView != VK_NULL_HANDLE ? 7 : 5, xw, 0, nullptr);
            extHudJob = hud ? desc.hudMode : 0u;
        }
        VkWriteDescriptorSet wds[7];
        for (int i = 0; i < 5; ++i) {
            wds[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
            wds[i].dstSet = ds_prep_io;
            wds[i].dstBinding = uint32_t(i);
            wds[i].descriptorCount = 1;
            wds[i].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            wds[i].pImageInfo = &dii[i];
        }
        wds[5] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
        wds[5].dstSet = ds_prep_io; wds[5].dstBinding = 5;
        wds[5].descriptorCount = 1; wds[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        wds[5].pBufferInfo = &dbi_enc;

        wds[6] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
        wds[6].dstSet = ds_prep_io; wds[6].dstBinding = 6;
        wds[6].descriptorCount = 1; wds[6].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        wds[6].pBufferInfo = &dbi_gen;

        nss_trace("recordMlof2Job: updating ds_prep_io");
        vkUpdateDescriptorSets(dev, 7, wds, 0, nullptr);
        nss_trace("recordMlof2Job: ds_prep_io updated");

        const auto& g_enc = encGraph();
        uint64_t off_col = 0, sz_col = 0, off_dep = 0, sz_dep = 0;
        mlof2_tensor_span(g_enc, plan_enc, 0, off_col, sz_col);
        mlof2_tensor_span(g_enc, plan_enc, 1, off_dep, sz_dep);

        const auto& g_target = (!ofgPath && desc.mfg == 4) ? mlof2_gen_prep_int8_graph : mlof2_gen_int8_graph;
        const auto& plan_target = (!ofgPath && desc.mfg == 4) ? plan_prep : plan_gen;

        uint64_t off_ca = 0, sz_ca = 0, off_cb = 0, sz_cb = 0;
        uint64_t off_da = 0, sz_da = 0, off_db = 0, sz_db = 0;
        uint64_t off_ndc = 0, sz_ndc = 0, off_mv = 0, sz_mv = 0, off_mvv = 0, sz_mvv = 0;
        bool genLanes = false;                                                                              

        for (int i = 0; i < g_target.num_inputs; ++i) {
            std::string nm = g_target.io_names[i];
            int t = g_target.io[i];
            if (nm == "col_a") mlof2_tensor_span(g_target, plan_target, t, off_ca, sz_ca);
            else if (nm == "col_b") mlof2_tensor_span(g_target, plan_target, t, off_cb, sz_cb);
            else if (nm == "dep_a") { mlof2_tensor_span(g_target, plan_target, t, off_da, sz_da); genLanes = g_target.tensors[t].s == 4; lanesNext = genLanes; }
            else if (nm == "dep_b") mlof2_tensor_span(g_target, plan_target, t, off_db, sz_db);
            else if (nm == "ndc_a") mlof2_tensor_span(g_target, plan_target, t, off_ndc, sz_ndc);
            else if (nm == "mv") mlof2_tensor_span(g_target, plan_target, t, off_mv, sz_mv);
            else if (nm == "mvv") mlof2_tensor_span(g_target, plan_target, t, off_mvv, sz_mvv);
        }
        m_off_ca = off_ca;
        m_off_cb = off_cb;
        if (!ofgPath && desc.mfg == 4) {
            off_ndc = prep_extra_ndc_off;
        }

        struct PrepPC {
            uint32_t dispW, dispH, padW, padH;
            float mvScaleX, mvScaleY, jitterX, jitterY;
            uint32_t isReverseZ, mode;
            uint32_t off_col, off_dep;
            uint32_t off_col_a, off_col_b, off_dep_a, off_dep_b, off_ndc_a, off_mv, off_mvv;
            uint32_t depW, depH, mvW, mvH;                                                 
            uint32_t off_mv_full;                                                              
        } pc;

        pc.dispW = dispW; pc.dispH = dispH; pc.padW = padW; pc.padH = padH;
        pc.mvScaleX = desc.mvScale[0]; pc.mvScaleY = desc.mvScale[1];
        pc.jitterX = desc.jitter[0]; pc.jitterY = desc.jitter[1];
        pc.isReverseZ = desc.isReverseZ ? 1u : 0u;
        pc.mode = 0u;
        pc.off_col = uint32_t(off_col); pc.off_dep = uint32_t(off_dep);
        pc.off_col_a = uint32_t(off_ca); pc.off_col_b = uint32_t(off_cb);
        pc.off_dep_a = uint32_t(off_da); pc.off_dep_b = uint32_t(off_db);
        pc.off_ndc_a = uint32_t(off_ndc); pc.off_mv = uint32_t(off_mv); pc.off_mvv = uint32_t(off_mvv);
        pc.depW = desc.depW; pc.depH = desc.depH; pc.mvW = desc.mvW; pc.mvH = desc.mvH;
        pc.off_mv_full = uint32_t(((!ofgPath && desc.mfg == 4) ? prep_extra_mvfull_off : gen_extra_mvfull_off) + uint64_t(snapW) * sz_mvfull);                      

        if (desc.frameID != lastPairFrameID) {
            nss_trace("recordMlof2Job: new frame pair frameID=%llu", (unsigned long long)desc.frameID);
                                                                                                                                  
            pc.mode = (ofHalf ? 16u : 0u) | (g_enc.tensors[0].fmt == 0 ? 4u : 0u);
            cmdOfFc(cb, plan_enc, bMeta_enc, desc);
            if (!extOf()) {
                vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_prep); boundPipe = VK_NULL_HANDLE;
                vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl_prep, 0, 1, &ds_prep_io, 0, nullptr);
                vkCmdPushConstants(cb, pl_prep, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
                vkCmdDispatch(cb, (padW + 15u) / 16u, (padH + 15u) / 16u, 1);
                profMark(cb, (PS_MISC << 16) | 0u, 0xFF00u);
            }

            VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

            Mlof2FrameInputs f_inp{};
            f_inp.reset = desc.reset;
            f_inp.frameID = desc.frameID;
            recordFrame(cb, f_inp);

            if (has_prev) {
                                                                                                                     
                                                                                                                      
                prev_pair_valid = !pair_first;
                                                                
                if (!ofgPath && desc.mfg == 4) {
                    float* mfc_prep = (float*)&plan_prep.meta[plan_prep.fc];
                    mfc_prep[MLOF2_FC_T] = desc.t;
                    mfc_prep[MLOF2_FC_HAS_PREV] = prev_pair_valid ? 1.0f : 0.0f;
                    mfc_prep[MLOF2_FC_PAIR_FIRST] = 1.0f;
                    mfc_prep[MLOF2_FC_TRAIL_HOMOG_AUTO] = trailHomog;
                    setExtFc(mfc_prep, desc, prep_extra_mvfull_off);
                    if (desc.hasCam) {
                        memcpy(&mfc_prep[MLOF2_FC_VP_A], desc.vp_a, 16 * sizeof(float));
                        memcpy(&mfc_prep[MLOF2_FC_VP_B], desc.vp_b, 16 * sizeof(float));
                        memcpy(&mfc_prep[MLOF2_FC_INV_VP_A], desc.inv_vp_a, 16 * sizeof(float));
                        mfc_prep[MLOF2_FC_FORCE_HOMOG] = 0.0f;
                    } else {
                        memset(&mfc_prep[MLOF2_FC_VP_A], 0, 16 * sizeof(float));
                        memset(&mfc_prep[MLOF2_FC_VP_B], 0, 16 * sizeof(float));
                        memset(&mfc_prep[MLOF2_FC_INV_VP_A], 0, 16 * sizeof(float));
                        mfc_prep[MLOF2_FC_FORCE_HOMOG] = 1.0f;
                    }
                    cmdUpdateFc(cb, bMeta_prep, plan_prep.fc, &plan_prep.meta[plan_prep.fc]);
                } else {
                    float* mfc = (float*)&plan_gen.meta[plan_gen.fc];
                    mfc[MLOF2_FC_T] = desc.t;
                    mfc[MLOF2_FC_HAS_PREV] = prev_pair_valid ? 1.0f : 0.0f;
                    mfc[MLOF2_FC_PAIR_FIRST] = 1.0f;
                    mfc[MLOF2_FC_TRAIL_HOMOG_AUTO] = trailHomog;
                    setExtFc(mfc, desc, gen_extra_mvfull_off);
                    if (desc.hasCam) {
                        memcpy(&mfc[MLOF2_FC_VP_A], desc.vp_a, 16 * sizeof(float));
                        memcpy(&mfc[MLOF2_FC_VP_B], desc.vp_b, 16 * sizeof(float));
                        memcpy(&mfc[MLOF2_FC_INV_VP_A], desc.inv_vp_a, 16 * sizeof(float));
                        mfc[MLOF2_FC_FORCE_HOMOG] = 0.0f;
                    } else {
                        memset(&mfc[MLOF2_FC_VP_A], 0, 16 * sizeof(float));
                        memset(&mfc[MLOF2_FC_VP_B], 0, 16 * sizeof(float));
                        memset(&mfc[MLOF2_FC_INV_VP_A], 0, 16 * sizeof(float));
                        mfc[MLOF2_FC_FORCE_HOMOG] = 1.0f;
                    }
                    cmdUpdateFc(cb, bMeta_gen, plan_gen.fc, &plan_gen.meta[plan_gen.fc]);
                }

                                                         
                lanesActive = genLanes;
                snapWritten = genLanes;                                           
                pc.mode = genLanes ? 3u : 1u;                                                                              
                if (!extIn() || ofgPath) {
                vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_prep); boundPipe = VK_NULL_HANDLE;
                vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl_prep, 0, 1, &ds_prep_io, 0, nullptr);
                vkCmdPushConstants(cb, pl_prep, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
                vkCmdDispatch(cb, (padW + 15u) / 16u, (padH + 15u) / 16u, 1);
                profMark(cb, (PS_MISC << 16) | 0u, 0xFF00u);
                }

                VkMemoryBarrier mb_prep{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
                mb_prep.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
                mb_prep.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
                vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                                     VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT,
                                     0, 1, &mb_prep, 0, nullptr, 0, nullptr);

                recordPair(cb, desc.mfg);
                pair_first = false;
            }
            lastPairFrameID = desc.frameID;
            if (snapWritten) { snapValid = true; snapW ^= 1u; snapWritten = false; }                                   
        }

        if (has_prev) {
                                       
            if (!ofgPath && desc.mfg == 4) {
                uint32_t kidx = (desc.k >= 1 && desc.k <= 3) ? (desc.k - 1) : 0;
                float* mfc = (float*)&meta_t[kidx][plan_t.fc];
                mfc[MLOF2_FC_T] = float(desc.k) * 0.25f;
                mfc[MLOF2_FC_HAS_PREV] = prev_pair_valid ? 1.0f : 0.0f;
                mfc[MLOF2_FC_PAIR_FIRST] = (desc.k == 1 ? 1.0f : 0.0f);
                mfc[MLOF2_FC_TRAIL_HOMOG_AUTO] = trailHomog;
                setExtFc(mfc, desc, prep_extra_mvfull_off);                                 
                if (desc.hasCam) {
                    memcpy(&mfc[MLOF2_FC_VP_A], desc.vp_a, 16 * sizeof(float));
                    memcpy(&mfc[MLOF2_FC_VP_B], desc.vp_b, 16 * sizeof(float));
                    memcpy(&mfc[MLOF2_FC_INV_VP_A], desc.inv_vp_a, 16 * sizeof(float));
                                                                                                       
                                                                                         
                    if (camq && desc.hasCamP && mfc[MLOF2_FC_T] > 0.001f && mfc[MLOF2_FC_T] < 0.999f) {
                        float vp_b_prime[16];
                        mlof2_calc_quadratic_vp_b(desc.vp_p, &mfc[MLOF2_FC_VP_A], &mfc[MLOF2_FC_VP_B], mfc[MLOF2_FC_T], vp_b_prime);
                        memcpy(&mfc[MLOF2_FC_VP_B], vp_b_prime, 16 * sizeof(float));
                    }
                    mfc[MLOF2_FC_FORCE_HOMOG] = 0.0f;
                } else {
                    memset(&mfc[MLOF2_FC_VP_A], 0, 16 * sizeof(float));
                    memset(&mfc[MLOF2_FC_VP_B], 0, 16 * sizeof(float));
                    memset(&mfc[MLOF2_FC_INV_VP_A], 0, 16 * sizeof(float));
                    mfc[MLOF2_FC_FORCE_HOMOG] = 1.0f;
                }
                cmdUpdateFc(cb, bMeta_t[kidx], plan_t.fc, &meta_t[kidx][plan_t.fc]);
            }

            recordGen(cb, desc.t, desc.k, desc.mfg, desc.outImage, desc.outView);

            uint64_t out_off = 0, out_sz = 0;
        if (ofgPath) {
                const auto& go = ofgHalf ? g_mlof2_oft_half_graph : g_mlof2_oft_graph;
                int out_t = go.io[go.num_inputs];             
                mlof2_tensor_span(go, plan_oft, out_t, out_off, out_sz);
            } else if (desc.mfg == 4) {
                for (int i = 0; i < mlof2_gen_t_int8_graph.num_outputs; ++i) {
                    std::string nm = mlof2_gen_t_int8_graph.io_names[mlof2_gen_t_int8_graph.num_inputs + i];
                    if (nm == "out") {
                        mlof2_tensor_span(mlof2_gen_t_int8_graph, plan_t, mlof2_gen_t_int8_graph.io[mlof2_gen_t_int8_graph.num_inputs + i], out_off, out_sz);
                        break;
                    }
                }
            } else {
                for (int i = 0; i < mlof2_gen_int8_graph.num_outputs; ++i) {
                    std::string nm = mlof2_gen_int8_graph.io_names[mlof2_gen_int8_graph.num_inputs + i];
                    if (nm == "out") {
                        mlof2_tensor_span(mlof2_gen_int8_graph, plan_gen, mlof2_gen_int8_graph.io[mlof2_gen_int8_graph.num_inputs + i], out_off, out_sz);
                        break;
                    }
                }
            }

            VkBuffer src_buf = ofgPath ? bArena_oft.b : ((desc.mfg == 4) ? bArena_t.b : bArena_gen.b);
            if (ofgPath && desc.outView != VK_NULL_HANDLE) extOutJob = true;

            VkDescriptorBufferInfo dbi{src_buf, 0, VK_WHOLE_SIZE};
            VkDescriptorImageInfo di{VK_NULL_HANDLE, desc.outView, VK_IMAGE_LAYOUT_GENERAL};
            const bool hud = desc.hudMode != 0u && desc.fullColView != VK_NULL_HANDLE;
            VkDescriptorImageInfo dfull{samplerLinear, hud ? desc.fullColView : desc.colCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
            VkDescriptorImageInfo dscene{samplerLinear, desc.colCurrView, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};
            VkWriteDescriptorSet owds[4]{};
            owds[0] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_out, 0, 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, nullptr, &dbi, nullptr};
            owds[1] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_out, 1, 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &di, nullptr, nullptr};
            owds[2] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_out, 2, 0, 1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, &dfull, nullptr, nullptr};
            owds[3] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_out, 3, 0, 1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, &dscene, nullptr, nullptr};
            vkUpdateDescriptorSets(dev, 4, owds, 0, nullptr);

            VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);

            if (!extOutJob) {
            vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pipe_out); boundPipe = VK_NULL_HANDLE;
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl_out, 0, 1, &ds_out, 0, nullptr);
            struct OutputPC { uint32_t dispW, dispH, padW, padH, out_off, hudMode; } opc;
            opc.dispW = dispW; opc.dispH = dispH; opc.padW = padW; opc.padH = padH; opc.out_off = uint32_t(out_off);
            opc.hudMode = hud ? desc.hudMode : 0u;
            vkCmdPushConstants(cb, pl_out, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(opc), &opc);
            vkCmdDispatch(cb, (dispW + 15u) / 16u, (dispH + 15u) / 16u, 1);
            profMark(cb, (PS_MISC << 16) | 2u, 0xFF02u);
            }

            mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
            mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
        }

        if (!has_prev) prof.pending[prof.slot] = false;                                                   
        has_prev = true;
        profEnd(cb);
    }
};
