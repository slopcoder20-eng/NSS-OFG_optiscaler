                                                                                                    
         
                                                                           
#include <vulkan/vulkan.h>
#define NOMINMAX
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>
#include "../mlof2_engine_host.h"
#include "../../sdk/src/backends/vk/nfru_isa_capture.h"

                                                                        
                                                                                                                     
#ifndef MLOF2_OF_GEN_DIR
#define MLOF2_OF_GEN_DIR generated_cut3_v2_int8
#endif
#define MLOF2_STR2(x) #x
#define MLOF2_STR(x) MLOF2_STR2(x)
#include MLOF2_STR(../MLOF2_OF_GEN_DIR/mlof2_enc_int8_graph.h)
#include MLOF2_STR(../MLOF2_OF_GEN_DIR/mlof2_pair_int8_graph.h)
#include "../generated_cut3_v2_int8/mlof2_gen_int8_graph.h"
#include "../generated_cut3_v2_int8/mlof2_gen_prep_int8_graph.h"
#include "../generated_cut3_v2_int8/mlof2_gen_t_int8_graph.h"
#include "../generated_oft_v2_int8/mlof2_oft_graph.h"
#include "../generated_oft_half_v2_int8/mlof2_oft_half_graph.h"
#include "../generated_fuse_v2_int8/mlof2_fuse_graph.h"
#include "../generated_cut3_v2_fp8/mlof2_enc_fp8_graph.h"
#include "../generated_cut3_v2_fp8/mlof2_pair_fp8_graph.h"
#include "../generated_cut3_v2_fp8/mlof2_gen_fp8_graph.h"

#include <cassert>
#include "mlof2_caps.h"
#include "../mlof2_shaders_spv.h"

#define CK(x) do { VkResult r_ = (x); if (r_) { printf("FAIL %s = %d (line %d)\n", #x, r_, __LINE__); exit(1); } } while (0)

static std::vector<uint8_t> readFile(const std::string& p) {
    FILE* f = fopen(p.c_str(), "rb"); if (!f) { printf("missing %s\n", p.c_str()); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET); std::vector<uint8_t> v(n); fread(v.data(), 1, n, f); fclose(f); return v;
}

VkDevice dev; VkPhysicalDeviceMemoryProperties mp;
static uint32_t memType(uint32_t bits, VkMemoryPropertyFlags want) {
    for (uint32_t i = 0; i < mp.memoryTypeCount; ++i) if ((bits >> i & 1) && (mp.memoryTypes[i].propertyFlags & want) == want) return i;
    printf("no memtype\n"); exit(1);
}
struct Buf { VkBuffer b; VkDeviceMemory m; size_t n; };
static Buf mk(size_t n, VkBufferUsageFlags u, VkMemoryPropertyFlags p) {
    Buf r{}; r.n = n; VkBufferCreateInfo bi{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; bi.size = n; bi.usage = u;
    CK(vkCreateBuffer(dev, &bi, nullptr, &r.b)); VkMemoryRequirements q; vkGetBufferMemoryRequirements(dev, r.b, &q);
    VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; ai.allocationSize = q.size; ai.memoryTypeIndex = memType(q.memoryTypeBits, p);
    CK(vkAllocateMemory(dev, &ai, nullptr, &r.m)); CK(vkBindBufferMemory(dev, r.b, r.m, 0)); return r;
}


int run_gen_4x(const std::string& gdir, const std::string& io, const std::string& mode, int H, int W, bool use_coop) {
    const Mlof2Graph& g_prep = mlof2_gen_prep_int8_graph;
    const Mlof2Graph& g_t = mlof2_gen_t_int8_graph;

    Mlof2Plan plan_prep, plan_t;
    if (!mlof2_plan(g_prep, H, W, plan_prep, use_coop)) { printf("bad size prep %dx%d\n", W, H); return 1; }
    if (!mlof2_plan(g_t, H, W, plan_t, use_coop)) { printf("bad size t %dx%d\n", W, H); return 1; }

    auto blob_t = readFile(gdir + "/" + g_t.blob_name);
    if (blob_t.size() != size_t(g_t.blob_words) * 4) { printf("blob size %zu != %u words\n", blob_t.size(), g_t.blob_words); return 1; }
    mlof2_convw_weights(g_t, plan_t, blob_t);

    auto blob_prep = readFile(gdir + "/" + g_prep.blob_name);
    mlof2_convw_weights(g_prep, plan_prep, blob_prep);

    std::string fcPath = io + "/fc.f32";
    auto fcv = readFile(fcPath);
    memcpy(&plan_prep.meta[plan_prep.fc], fcv.data(), std::min<size_t>(fcv.size(), MLOF2_FC_WORDS * 4));
    ((float*)&plan_prep.meta[plan_prep.fc])[MLOF2_FC_PAIR_FIRST] = 1.0f;

    std::vector<uint32_t> meta_t[3];
    std::string vpPrevPath = io + "/vp_prev.f32";
    std::vector<uint8_t> vpp;
    FILE* fp = fopen(vpPrevPath.c_str(), "rb");
    if (fp) { fclose(fp); vpp = readFile(vpPrevPath); }

    for (int k = 1; k <= 3; ++k) {
        meta_t[k - 1] = plan_t.meta;
        float* mfc = (float*)&meta_t[k - 1][plan_t.fc];
        memcpy(mfc, fcv.data(), std::min<size_t>(fcv.size(), MLOF2_FC_WORDS * 4));
        mfc[MLOF2_FC_T] = float(k) * 0.25f;
        mfc[MLOF2_FC_PAIR_FIRST] = (k == 1 ? 1.0f : 0.0f);
        if (vpp.size() >= 64 && mfc[MLOF2_FC_T] > 0.001f && mfc[MLOF2_FC_T] < 0.999f) {
            float vp_b_prime[16];
            mlof2_calc_quadratic_vp_b((const float*)vpp.data(), &mfc[MLOF2_FC_VP_A], &mfc[MLOF2_FC_VP_B], mfc[MLOF2_FC_T], vp_b_prime);
            memcpy(&mfc[MLOF2_FC_VP_B], vp_b_prime, 16 * 4);
        }
        if (getenv("MLOF2_FORCE_HOMOG") && std::string(getenv("MLOF2_FORCE_HOMOG")) != "0") {
            mfc[MLOF2_FC_FORCE_HOMOG] = 1.0f;
        }
    }

    auto inputFile = [&](const char* name) {
        std::string p_bin = io + "/in_" + name + ".bin";
        FILE* f = fopen(p_bin.c_str(), "rb"); if (f) { fclose(f); return p_bin; }
        std::string p_f32 = io + "/in_" + name + ".f32";
        f = fopen(p_f32.c_str(), "rb"); if (f) { fclose(f); return p_f32; }
        std::string p_raw = io + "/" + name + ".bin";
        f = fopen(p_raw.c_str(), "rb"); if (f) { fclose(f); return p_raw; }
        return io + "/" + name + ".f32";
    };

    VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.apiVersion = VK_API_VERSION_1_3;
    VkInstanceCreateInfo ici{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO}; ici.pApplicationInfo = &app; VkInstance inst; CK(vkCreateInstance(&ici, nullptr, &inst));
    uint32_t nd = 0; vkEnumeratePhysicalDevices(inst, &nd, nullptr); std::vector<VkPhysicalDevice> pds(nd); vkEnumeratePhysicalDevices(inst, &nd, pds.data());
    VkPhysicalDevice pd = pds[0];
    vkGetPhysicalDeviceMemoryProperties(pd, &mp);
    VkPhysicalDeviceProperties pr; vkGetPhysicalDeviceProperties(pd, &pr);
    uint32_t nq = 0; vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, nullptr); std::vector<VkQueueFamilyProperties> qp(nq); vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, qp.data());
    uint32_t qf = 0; for (uint32_t i = 0; i < nq; ++i) if (qp[i].queueFlags & VK_QUEUE_COMPUTE_BIT) { qf = i; break; }
    float prio = 1.0f; VkDeviceQueueCreateInfo qi{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO}; qi.queueFamilyIndex = qf; qi.queueCount = 1; qi.pQueuePriorities = &prio;

    uint32_t extCount = 0; vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, nullptr);
    std::vector<VkExtensionProperties> availExts(extCount); vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, availExts.data());
    Mlof2Caps caps = mlof2_query_caps(inst, pd);
    VkQueue q = VK_NULL_HANDLE;
    if (!mlof2_create_device(inst, pd, caps, qf, &dev, &q)) return 1;

    VkMemoryPropertyFlags DL = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, HV = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    VkBufferUsageFlags SB = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT;

    Buf bArena_prep = mk(plan_prep.arena_bytes, SB, DL);
    Buf bArena_t    = mk(plan_t.arena_bytes, SB, DL);
    uint64_t blob_sz = std::max(blob_prep.size(), blob_t.size());
    uint64_t meta_prep_sz = plan_prep.meta.size() * 4;
    uint64_t meta_t_sz = plan_t.meta.size() * 4;

    Buf bBlob_prep = mk(std::max<size_t>(blob_prep.size(), 256), SB, DL);
    Buf bBlob_t    = mk(std::max<size_t>(blob_t.size(), 256), SB, DL);
    Buf bMeta_prep = mk(meta_prep_sz, SB, DL);
    Buf bMeta_t[3] = { mk(meta_t_sz, SB, DL), mk(meta_t_sz, SB, DL), mk(meta_t_sz, SB, DL) };

    uint64_t maxT = 0;
    for (int t = 0; t < g_prep.num_tensors; ++t) { uint64_t o, c; mlof2_tensor_span(g_prep, plan_prep, t, o, c); maxT = std::max(maxT, c); }
    for (int t = 0; t < g_t.num_tensors; ++t) { uint64_t o, c; mlof2_tensor_span(g_t, plan_t, t, o, c); maxT = std::max(maxT, c); }
    size_t init_st_needed = ((blob_prep.size() + 255u) & ~255u) +
                            ((blob_t.size() + 255u) & ~255u) +
                            ((meta_prep_sz + 255u) & ~255u) +
                            3 * ((meta_t_sz + 255u) & ~255u);
    size_t stN = std::max<size_t>({init_st_needed, size_t(maxT), size_t(W) * size_t(H) * 16u});
    Buf st = mk(stN, VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, HV);
    uint8_t* sp; CK(vkMapMemory(dev, st.m, 0, stN, 0, (void**)&sp));

    struct Img {
        VkImage image = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        VkImageView view = VK_NULL_HANDLE;
        uint32_t width = 0, height = 0;
    };
    auto mkimg = [&](uint32_t w, uint32_t h) -> Img {
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
        CK(vkCreateImage(dev, &ici, nullptr, &img.image));
        VkMemoryRequirements mr; vkGetImageMemoryRequirements(dev, img.image, &mr);
        VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, nullptr, mr.size, memType(mr.memoryTypeBits, DL)};
        CK(vkAllocateMemory(dev, &mai, nullptr, &img.memory));
        CK(vkBindImageMemory(dev, img.image, img.memory, 0));
        VkImageViewCreateInfo ivci{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        ivci.image = img.image; ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        ivci.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        ivci.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        CK(vkCreateImageView(dev, &ivci, nullptr, &img.view));
        return img;
    };

    Img imgCabA = mkimg(W, H);
    Img imgCabB = mkimg(W, H);
    Img imgQpA  = mkimg(W / 4, H / 4);
    Img imgQpB  = mkimg(W / 4, H / 4);
    Img* all_imgs[4] = {&imgCabA, &imgCabB, &imgQpA, &imgQpB};

    VkSamplerCreateInfo sci{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
    sci.magFilter = VK_FILTER_LINEAR; sci.minFilter = VK_FILTER_LINEAR;
    sci.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sci.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    sci.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    sci.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    sci.borderColor = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
    VkSampler samplerLinear; CK(vkCreateSampler(dev, &sci, nullptr, &samplerLinear));

    VkDescriptorSetLayoutBinding dslb[11];
    for (int i = 0; i < 3; ++i) dslb[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    for (int i = 0; i < 4; ++i) dslb[3 + i] = {uint32_t(3 + i), VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    for (int i = 0; i < 4; ++i) dslb[7 + i] = {uint32_t(7 + i), VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    VkDescriptorSetLayoutCreateInfo dsli{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dsli.bindingCount = 11; dsli.pBindings = dslb;
    VkDescriptorSetLayout dsl; CK(vkCreateDescriptorSetLayout(dev, &dsli, nullptr, &dsl));
                                                                                                                   
    VkDescriptorSetLayoutBinding xlb[7];
    for (int i = 0; i < 7; ++i) xlb[i] = {uint32_t(i), i == 5 ? VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    VkDescriptorSetLayoutCreateInfo xli{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; xli.bindingCount = 7; xli.pBindings = xlb;
    VkDescriptorSetLayout dsl_ext; CK(vkCreateDescriptorSetLayout(dev, &xli, nullptr, &dsl_ext));
    VkDescriptorSetLayout pls[2] = {dsl, dsl_ext};

    VkPushConstantRange pcr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 20};
    VkPipelineLayoutCreateInfo pli{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; pli.setLayoutCount = 2; pli.pSetLayouts = pls; pli.pushConstantRangeCount = 1; pli.pPushConstantRanges = &pcr;
    VkPipelineLayout pl; CK(vkCreatePipelineLayout(dev, &pli, nullptr, &pl));

    VkDescriptorPoolSize dps[3] = {
        {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 3 * 4},
        {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 4 * 4 + 1},
        {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 4 * 4 + 6}
    };
    VkDescriptorPoolCreateInfo dpi{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dpi.maxSets = 5; dpi.poolSizeCount = 3; dpi.pPoolSizes = dps;
    VkDescriptorPool dp; CK(vkCreateDescriptorPool(dev, &dpi, nullptr, &dp));

    VkDescriptorSetLayout layouts[4] = {dsl, dsl, dsl, dsl};
    VkDescriptorSetAllocateInfo dai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; dai.descriptorPool = dp; dai.descriptorSetCount = 4; dai.pSetLayouts = layouts;
    VkDescriptorSet dsets[4]; CK(vkAllocateDescriptorSets(dev, &dai, dsets));
    VkDescriptorSet ds_prep = dsets[0], ds_t[3] = {dsets[1], dsets[2], dsets[3]};
    VkDescriptorSet ds_ext;
    {
        VkDescriptorSetAllocateInfo xai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; xai.descriptorPool = dp; xai.descriptorSetCount = 1; xai.pSetLayouts = &dsl_ext;
        CK(vkAllocateDescriptorSets(dev, &xai, &ds_ext));
        VkDescriptorImageInfo xs{samplerLinear, imgCabA.view, VK_IMAGE_LAYOUT_GENERAL}, xo{VK_NULL_HANDLE, imgCabB.view, VK_IMAGE_LAYOUT_GENERAL};
        VkWriteDescriptorSet xw[7];
        for (int i = 0; i < 7; ++i) xw[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_ext, uint32_t(i), 0, 1, i == 5 ? VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, i == 5 ? &xo : &xs, nullptr, nullptr};
        vkUpdateDescriptorSets(dev, 7, xw, 0, nullptr);
    }

    auto writeDS = [&](VkDescriptorSet target_ds, Buf& meta_buf, Buf& arena_buf, Buf& blob_buf) {
        VkDescriptorBufferInfo dbi[3] = {
            {arena_buf.b, 0, VK_WHOLE_SIZE},
            {blob_buf.b, 0, VK_WHOLE_SIZE},
            {meta_buf.b, 0, VK_WHOLE_SIZE}
        };
        VkDescriptorImageInfo dii_storage[4], dii_sampler[4];
        for (int i = 0; i < 4; ++i) dii_storage[i] = {VK_NULL_HANDLE, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL};
        for (int i = 0; i < 4; ++i) dii_sampler[i] = {samplerLinear, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL};
        VkWriteDescriptorSet wr[11];
        for (int i = 0; i < 3; ++i) wr[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, target_ds, uint32_t(i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, nullptr, &dbi[i], nullptr};
        for (int i = 0; i < 4; ++i) wr[3 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, target_ds, uint32_t(3 + i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &dii_storage[i], nullptr, nullptr};
        for (int i = 0; i < 4; ++i) wr[7 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, target_ds, uint32_t(7 + i), 0, 1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, &dii_sampler[i], nullptr, nullptr};
        vkUpdateDescriptorSets(dev, 11, wr, 0, nullptr);
    };
    writeDS(ds_prep, bMeta_prep, bArena_prep, bBlob_prep);
    writeDS(ds_t[0], bMeta_t[0], bArena_t, bBlob_t);
    writeDS(ds_t[1], bMeta_t[1], bArena_t, bBlob_t);
    writeDS(ds_t[2], bMeta_t[2], bArena_t, bBlob_t);

    const char* const* k_names = g_mlof2_kernel_names;
    const uint32_t* const* codes = g_mlof2_kernel_spv;
    const size_t* sizes = g_mlof2_kernel_spv_size;
    VkPipelineCreateFlags p_flags = nfru_isa::createFlags(dev);
    std::vector<VkShaderModule> smod(g_mlof2_num_kernels);
    for (int k = 0; k < g_mlof2_num_kernels; ++k) {
        VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smi.codeSize = sizes[k]; smi.pCode = codes[k];
        CK(vkCreateShaderModule(dev, &smi, nullptr, &smod[k]));
    }

    struct SpecKey { uint32_t kernel, fmts; int32_t ip0, ip1; uint32_t rt, sw, ksp, pf; };
    std::vector<std::pair<SpecKey, VkPipeline>> spec_pipes;
    auto mkpipe = [&](int k, uint32_t fmts, int32_t ip0, int32_t ip1, uint32_t rt, uint32_t sw, uint32_t ksp, uint32_t pf = 24u) -> VkPipeline {
        uint32_t sd[7] = {fmts, uint32_t(ip0), uint32_t(ip1), rt, sw, ksp, pf};
        VkSpecializationMapEntry me[7] = {{0u, 0u, 4u}, {1u, 4u, 4u}, {2u, 8u, 4u}, {3u, 12u, 4u}, {4u, 16u, 4u}, {5u, 20u, 4u}, {6u, 24u, 4u}};
        VkSpecializationInfo spi{7u, me, 28u, sd};
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpi.flags = p_flags;
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        const bool is_coop = caps.use_coopmat;
        const bool wave32 = is_coop || (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);
        const bool wave64 = !is_coop && !getenv("MLOF2_DP4A_WAVE32");
        rss.requiredSubgroupSize = wave32 ? 32u : 64u;
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (wave32 || wave64) ? &rss : nullptr,
                     wave32 ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                     VK_SHADER_STAGE_COMPUTE_BIT, smod[k], "main", &spi};
        cpi.layout = pl;
        VkPipeline pp; CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp));
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
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, &rss, VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT),
                     VK_SHADER_STAGE_COMPUTE_BIT, smod[d.kernel], "main", &spi};
        cpi.layout = pl;
        VkPipeline pp; CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp));
        return pp;
    };
    std::vector<VkPipeline> pipe_def(g_mlof2_num_kernels);
    for (int k = 0; k < g_mlof2_num_kernels; ++k) {
        if (k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk) { pipe_def[k] = VK_NULL_HANDLE; continue; }
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpi.flags = p_flags;
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        const bool is_coop = caps.use_coopmat;
        const bool wave32 = is_coop || (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);
        const bool wave64 = !is_coop && !getenv("MLOF2_DP4A_WAVE32");
        rss.requiredSubgroupSize = wave32 ? 32u : 64u;
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (wave32 || wave64) ? &rss : nullptr,
                     wave32 ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                     VK_SHADER_STAGE_COMPUTE_BIT, smod[k], "main", nullptr};
        cpi.layout = pl;
        CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pipe_def[k]));
    }

    auto getDispatchPipelines = [&](const Mlof2Plan& plan) {
        std::vector<VkPipeline> dpipe(plan.dispatches.size());
        for (size_t i = 0; i < plan.dispatches.size(); ++i) {
            const Mlof2Dispatch& d = plan.dispatches[i];
            if (d.wk) { dpipe[i] = mkpipe_w(d); continue; }
            if (d.fmts == 0xFFFFFFFFu && d.coop_rt == 1u && d.coop_sw == 8u && d.coop_fuse == 0u && d.coop_pf == 24u) { dpipe[i] = pipe_def[d.kernel]; continue; }
            const SpecKey key = {d.kernel, uint32_t(d.fmts), int32_t(d.ip01[0]), int32_t(d.ip01[1]), uint32_t(d.coop_rt), uint32_t(d.coop_sw), uint32_t(d.coop_fuse), uint32_t(d.coop_pf)};
            auto it = std::find_if(spec_pipes.begin(), spec_pipes.end(), [&](const std::pair<SpecKey, VkPipeline>& e) {
                return e.first.kernel == key.kernel && e.first.fmts == key.fmts && e.first.ip0 == key.ip0 && e.first.ip1 == key.ip1 &&
                       e.first.rt == key.rt && e.first.sw == key.sw && e.first.ksp == key.ksp && e.first.pf == key.pf; });
            if (it == spec_pipes.end()) {
                spec_pipes.push_back({key, mkpipe(int(d.kernel), key.fmts, key.ip0, key.ip1, key.rt, key.sw, key.ksp, key.pf)});
                it = spec_pipes.end() - 1;
            }
            dpipe[i] = it->second;
        }
        return dpipe;
    };
    std::vector<VkPipeline> dpipe_prep = getDispatchPipelines(plan_prep);
    std::vector<VkPipeline> dpipe_t = getDispatchPipelines(plan_t);

    VkCommandPoolCreateInfo cpo{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO}; cpo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT; cpo.queueFamilyIndex = qf; VkCommandPool cp; CK(vkCreateCommandPool(dev, &cpo, nullptr, &cp));
    VkCommandBufferAllocateInfo cai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO}; cai.commandPool = cp; cai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; cai.commandBufferCount = 1; VkCommandBuffer cb; CK(vkAllocateCommandBuffers(dev, &cai, &cb));
    VkCommandBufferBeginInfo bbi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER}; mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT; mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT;
    auto barrier = [&]() { vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr); };
    auto submit = [&]() { CK(vkEndCommandBuffer(cb)); VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount = 1; si.pCommandBuffers = &cb; CK(vkQueueSubmit(q, 1, &si, VK_NULL_HANDLE)); CK(vkQueueWaitIdle(q)); CK(vkResetCommandBuffer(cb, 0)); };

                                                                     
    size_t st_off = 0;
    assert(st_off + blob_prep.size() <= stN);
    memcpy(sp + st_off, blob_prep.data(), blob_prep.size());
    VkBufferCopy cblob_prep{st_off, 0, blob_prep.size()};
    st_off += (blob_prep.size() + 255u) & ~255u;

    assert(st_off + blob_t.size() <= stN);
    memcpy(sp + st_off, blob_t.data(), blob_t.size());
    VkBufferCopy cblob_t{st_off, 0, blob_t.size()};
    st_off += (blob_t.size() + 255u) & ~255u;

    assert(st_off + meta_prep_sz <= stN);
    memcpy(sp + st_off, plan_prep.meta.data(), meta_prep_sz);
    VkBufferCopy cmprep{st_off, 0, meta_prep_sz};
    st_off += (meta_prep_sz + 255u) & ~255u;

    VkBufferCopy cmt[3];
    for (int k = 0; k < 3; ++k) {
        assert(st_off + meta_t_sz <= stN);
        memcpy(sp + st_off, meta_t[k].data(), meta_t_sz);
        cmt[k] = {st_off, 0, meta_t_sz};
        st_off += (meta_t_sz + 255u) & ~255u;
    }

    CK(vkBeginCommandBuffer(cb, &bbi));
    vkCmdCopyBuffer(cb, st.b, bBlob_prep.b, 1, &cblob_prep);
    vkCmdCopyBuffer(cb, st.b, bBlob_t.b, 1, &cblob_t);
    vkCmdCopyBuffer(cb, st.b, bMeta_prep.b, 1, &cmprep);
    for (int k = 0; k < 3; ++k) {
        vkCmdCopyBuffer(cb, st.b, bMeta_t[k].b, 1, &cmt[k]);
    }

    VkImageMemoryBarrier init_imb[4];
    for (int i = 0; i < 4; ++i) {
        init_imb[i] = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
        init_imb[i].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED; init_imb[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
        init_imb[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED; init_imb[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        init_imb[i].image = all_imgs[i]->image; init_imb[i].subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        init_imb[i].srcAccessMask = 0; init_imb[i].dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
    }
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 4, init_imb);
    vkCmdFillBuffer(cb, bArena_prep.b, 0, VK_WHOLE_SIZE, 0xFFFFFFFFu);
    vkCmdFillBuffer(cb, bArena_t.b, 0, VK_WHOLE_SIZE, 0xFFFFFFFFu);
    submit();

                    
    auto uploadTensor = [&](const Mlof2Graph& g, const Mlof2Plan& plan, Buf& target_arena, int t_idx, const char* name) -> std::vector<uint8_t> {
        uint64_t off, cnt_bytes; mlof2_tensor_span(g, plan, t_idx, off, cnt_bytes);
        std::string fn = inputFile(name);
        auto v = readFile(fn);
        const Mlof2Tensor& td = g.tensors[t_idx];
        if (td.fmt == 1 && fn.size() > 4 && fn.substr(fn.size() - 4) == ".f32") {
            const size_t npx = size_t(td.n) * (H / td.s) * (W / td.s);
            std::vector<uint8_t> h(cnt_bytes, 0);
            const float* f = (const float*)v.data(); uint16_t* o = (uint16_t*)h.data();
            auto f2h = [](float x) -> uint16_t {
                uint32_t u; memcpy(&u, &x, 4); uint32_t sgn = (u >> 16) & 0x8000u; int e = int((u >> 23) & 0xFF) - 127 + 15; uint32_t m = u & 0x7FFFFFu;
                if (((u >> 23) & 0xFF) == 0xFF) return uint16_t(sgn | 0x7C00u | (m ? 0x200u : 0u));
                if (e >= 31) return uint16_t(sgn | 0x7C00u);
                if (e <= 0) { if (e < -10) return uint16_t(sgn); m |= 0x800000u; uint32_t sh = uint32_t(14 - e); uint32_t r = m >> sh, rem = m & ((1u << sh) - 1u), half = 1u << (sh - 1);
                              if (rem > half || (rem == half && (r & 1u))) ++r; return uint16_t(sgn | r); }
                uint32_t r = (uint32_t(e) << 10) | (m >> 13), rem = m & 0x1FFFu;
                if (rem > 0x1000u || (rem == 0x1000u && (r & 1u))) ++r; return uint16_t(sgn | r);
            };
            for (size_t px = 0; px < npx; ++px) for (int c = 0; c < td.c; ++c) o[px * td.c_alloc + c] = f2h(f[px * td.c + c]);
            v.swap(h);
        }
        if (v.size() > cnt_bytes) v.resize(cnt_bytes);
        memcpy(sp, v.data(), v.size());
        CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{0, off, cnt_bytes}; vkCmdCopyBuffer(cb, st.b, target_arena.b, 1, &c); submit();
        return v;
    };

    for (int i = 0; i < g_prep.num_inputs; ++i) uploadTensor(g_prep, plan_prep, bArena_prep, g_prep.io[i], g_prep.io_names[i]);
    std::vector<uint8_t> pmask_init;
    int pmask_tid = -1;
    for (int i = 0; i < g_t.num_inputs; ++i) {
        std::string nm = g_t.io_names[i];
        if (nm == "pmask") pmask_tid = g_t.io[i];
        if (nm == "dep_b" || nm == "ndc_a" || nm == "co" || nm == "pmask") {
            auto v = uploadTensor(g_t, plan_t, bArena_t, g_t.io[i], nm.c_str());
            if (nm == "pmask") pmask_init = v;
        }
    }
    uint64_t pmask_off = 0, pmask_cnt = 0;
    if (pmask_tid >= 0) mlof2_tensor_span(g_t, plan_t, pmask_tid, pmask_off, pmask_cnt);
    Buf bPmask[3] = { mk(pmask_cnt, SB, DL), mk(pmask_cnt, SB, DL), mk(pmask_cnt, SB, DL) };
    if (pmask_tid >= 0 && pmask_init.size() == pmask_cnt) {
        assert(pmask_cnt <= stN);
        memcpy(sp, pmask_init.data(), pmask_cnt);
        CK(vkBeginCommandBuffer(cb, &bbi));
        for (int k = 0; k < 3; ++k) {
            VkBufferCopy c{0, 0, pmask_cnt};
            vkCmdCopyBuffer(cb, st.b, bPmask[k].b, 1, &c);
        }
        submit();
    }

                                                                           
    uint64_t prep_off_vig = 0, prep_sz_vig = 0, t_off_vig = 0, t_sz_vig = 0;
    uint64_t prep_off_ph  = 0, prep_sz_ph  = 0, t_off_ph  = 0, t_sz_ph  = 0;
    uint64_t prep_off_qp  = 0, prep_sz_qp  = 0, t_off_qp  = 0, t_sz_qp  = 0;

    for (int i = 0; i < g_prep.num_outputs; ++i) {
        std::string nm = g_prep.io_names[g_prep.num_inputs + i];
        int t = g_prep.io[g_prep.num_inputs + i];
        if (nm == "vig") mlof2_tensor_span(g_prep, plan_prep, t, prep_off_vig, prep_sz_vig);
        if (nm == "ph")  mlof2_tensor_span(g_prep, plan_prep, t, prep_off_ph,  prep_sz_ph);
        if (nm == "qp")  mlof2_tensor_span(g_prep, plan_prep, t, prep_off_qp,  prep_sz_qp);
    }
    for (int i = 0; i < g_t.num_inputs; ++i) {
        std::string nm = g_t.io_names[i];
        int t = g_t.io[i];
        if (nm == "vig") mlof2_tensor_span(g_t, plan_t, t, t_off_vig, t_sz_vig);
        if (nm == "ph")  mlof2_tensor_span(g_t, plan_t, t, t_off_ph,  t_sz_ph);
        if (nm == "qp")  mlof2_tensor_span(g_t, plan_t, t, t_off_qp,  t_sz_qp);
    }
    VkBufferCopy bc_xfer[3] = {
        {prep_off_vig, t_off_vig, std::min(prep_sz_vig, t_sz_vig)},
        {prep_off_ph,  t_off_ph,  std::min(prep_sz_ph,  t_sz_ph)},
        {prep_off_qp,  t_off_qp,  std::min(prep_sz_qp,  t_sz_qp)}
    };

    auto syncPrepToT = [&]() {
        barrier();
        vkCmdCopyBuffer(cb, bArena_prep.b, bArena_t.b, 3, bc_xfer);
        barrier();
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
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                             0, 0, nullptr, 0, nullptr, 4, imb_xfer);
    };

    VkPipeline cur_pipe = VK_NULL_HANDLE;
    auto recordOp = [&](const Mlof2Plan& plan, const std::vector<VkPipeline>& dpipe, const Mlof2Dispatch& d) {
        if (d.barrier_before) barrier();
        uint32_t pcv[5] = {d.op, plan.tb, plan.sb, plan.ob, plan.fc};
        VkPipeline pp = dpipe[&d - plan.dispatches.data()];
        if (pp != cur_pipe) { vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pp); cur_pipe = pp; }
        vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv);
        vkCmdDispatch(cb, d.gx, d.gy, 1);
    };

    int num_pairs = 1;
    if (getenv("MLOF2_PAIRS")) num_pairs = std::max(1, atoi(getenv("MLOF2_PAIRS")));

    if (mode == "dump") {
        for (int pair_idx = 0; pair_idx < num_pairs; ++pair_idx) {
            std::string pair_pfx = (num_pairs > 1 && pair_idx > 0) ? ("/pair" + std::to_string(pair_idx + 1) + "_") : "/";

            if (num_pairs > 1 && pair_idx > 0) {
                plan_prep.meta[plan_prep.fc + MLOF2_FC_HAS_PREV] = mlof2_f2u(1.0f);
                for (int k = 0; k < 3; ++k) meta_t[k][plan_t.fc + MLOF2_FC_HAS_PREV] = mlof2_f2u(1.0f);
                size_t m_off = 0;
                memcpy(sp + m_off, plan_prep.meta.data(), meta_prep_sz);
                VkBufferCopy cmprep_up{m_off, 0, meta_prep_sz};
                m_off += (meta_prep_sz + 255u) & ~255u;
                VkBufferCopy cmt_up[3];
                for (int k = 0; k < 3; ++k) {
                    memcpy(sp + m_off, meta_t[k].data(), meta_t_sz);
                    cmt_up[k] = {m_off, 0, meta_t_sz};
                    m_off += (meta_t_sz + 255u) & ~255u;
                }
                assert(m_off <= stN);
                CK(vkBeginCommandBuffer(cb, &bbi));
                vkCmdCopyBuffer(cb, st.b, bMeta_prep.b, 1, &cmprep_up);
                for (int k = 0; k < 3; ++k) vkCmdCopyBuffer(cb, st.b, bMeta_t[k].b, 1, &cmt_up[k]);
                submit();
            }

                           
            for (const auto& d : plan_prep.dispatches) {
                CK(vkBeginCommandBuffer(cb, &bbi));
                vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_prep, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
                cur_pipe = VK_NULL_HANDLE;
                barrier();
                recordOp(plan_prep, dpipe_prep, d);
                barrier();
                uint64_t off, cnt_bytes; mlof2_tensor_span(g_prep, plan_prep, g_prep.ops[d.op].out, off, cnt_bytes);
                char fn[64]; snprintf(fn, sizeof fn, "%sop_%03u.bin", pair_pfx.c_str(), d.op);
                if (g_prep.ops[d.op].kind == MLOF2_K_PREP_C) {
                    VkImageMemoryBarrier imb_read[2] = {
                        {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_TRANSFER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgCabA.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}},
                        {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_TRANSFER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgCabB.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}}
                    };
                    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0, nullptr, 2, imb_read);
                    VkBufferImageCopy bicA{}; bicA.bufferOffset = 0; bicA.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicA.imageExtent = {uint32_t(W), uint32_t(H), 1};
                    vkCmdCopyImageToBuffer(cb, imgCabA.image, VK_IMAGE_LAYOUT_GENERAL, st.b, 1, &bicA);
                    VkBufferImageCopy bicB{}; bicB.bufferOffset = uint64_t(W) * H * 8; bicB.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicB.imageExtent = {uint32_t(W), uint32_t(H), 1};
                    vkCmdCopyImageToBuffer(cb, imgCabB.image, VK_IMAGE_LAYOUT_GENERAL, st.b, 1, &bicB);
                    submit();
                    std::vector<uint8_t> cab_nhwc(cnt_bytes);
                    const uint16_t* srcA = (const uint16_t*)sp;
                    const uint16_t* srcB = (const uint16_t*)(sp + uint64_t(W) * H * 8);
                    uint16_t* dst = (uint16_t*)cab_nhwc.data();
                    for (size_t px = 0; px < size_t(W) * H; ++px) {
                        for (int c = 0; c < 4; ++c) dst[8 * px + c] = srcA[4 * px + c];
                        for (int c = 0; c < 4; ++c) dst[8 * px + 4 + c] = srcB[4 * px + c];
                    }
                    FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(cab_nhwc.data(), 1, cnt_bytes, f); fclose(f);
                    if (pair_idx == 0) {
                        FILE* f_cab = fopen((io + "/out_cab.bin").c_str(), "wb"); fwrite(cab_nhwc.data(), 1, cnt_bytes, f_cab); fclose(f_cab);
                    }
                    memcpy(sp, cab_nhwc.data(), cnt_bytes);
                    CK(vkBeginCommandBuffer(cb, &bbi));
                    VkBufferCopy c_cab{0, off, cnt_bytes}; vkCmdCopyBuffer(cb, st.b, bArena_prep.b, 1, &c_cab); submit();
                } else {
                    VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena_prep.b, st.b, 1, &c); submit();
                    FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
                }
            }
            for (int oi = 0; oi < g_prep.num_outputs; ++oi) {
                std::string nm = g_prep.io_names[g_prep.num_inputs + oi];
                if (nm == "cab") continue;
                int t = g_prep.io[g_prep.num_inputs + oi];
                uint64_t off, cnt_bytes; mlof2_tensor_span(g_prep, plan_prep, t, off, cnt_bytes);
                CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena_prep.b, st.b, 1, &c); submit();
                char fn[64]; snprintf(fn, sizeof fn, "%sout_%s.bin", pair_pfx.c_str(), nm.c_str());
                FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
            }

                                                                  
            CK(vkBeginCommandBuffer(cb, &bbi));
            syncPrepToT();
            submit();

                                              
            for (int k = 1; k <= 3; ++k) {
                int kidx = k - 1;
                                                     
                char fc_fn[64]; snprintf(fc_fn, sizeof fc_fn, "%st%d_fc.f32", pair_pfx.c_str(), k);
                FILE* ffc = fopen((io + fc_fn).c_str(), "wb");
                fwrite(&meta_t[kidx][plan_t.fc], 1, MLOF2_FC_WORDS * 4, ffc);
                fclose(ffc);

                                                       
                if (pmask_tid >= 0 && pmask_cnt > 0) {
                    CK(vkBeginCommandBuffer(cb, &bbi));
                    VkBufferCopy c{0, pmask_off, pmask_cnt};
                    vkCmdCopyBuffer(cb, bPmask[kidx].b, bArena_t.b, 1, &c);
                    barrier();
                    submit();
                }

                for (const auto& d : plan_t.dispatches) {
                    CK(vkBeginCommandBuffer(cb, &bbi));
                    vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_t[kidx], 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
                    cur_pipe = VK_NULL_HANDLE;
                    barrier();
                    recordOp(plan_t, dpipe_t, d);
                    barrier();
                    uint64_t off, cnt_bytes; mlof2_tensor_span(g_t, plan_t, g_t.ops[d.op].out, off, cnt_bytes);
                    char fn[64]; snprintf(fn, sizeof fn, "%st%d_op_%03u.bin", pair_pfx.c_str(), k, d.op);
                    VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena_t.b, st.b, 1, &c); submit();
                    FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
                }

                                                                          
                if (pmask_tid >= 0 && pmask_cnt > 0) {
                    CK(vkBeginCommandBuffer(cb, &bbi));
                    barrier();
                    VkBufferCopy c{pmask_off, 0, pmask_cnt};
                    vkCmdCopyBuffer(cb, bArena_t.b, bPmask[kidx].b, 1, &c);
                    submit();
                }

                for (int oi = 0; oi < g_t.num_outputs; ++oi) {
                    int t = g_t.io[g_t.num_inputs + oi];
                    uint64_t off, cnt_bytes; mlof2_tensor_span(g_t, plan_t, t, off, cnt_bytes);
                    CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena_t.b, st.b, 1, &c); submit();
                    char fn[64]; snprintf(fn, sizeof fn, "%st%d_out_%s.bin", pair_pfx.c_str(), k, g_t.io_names[g_t.num_inputs + oi]);
                    FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
                }
            }
        }
        printf("Dumped 4x sequential (%d pairs): gen_prep (5 ops) and gen_t x 3 (29 ops each) to %s (Contract v2 binary format)\n", num_pairs, io.c_str());
    } else {
                                             
        const int R = 20;
        VkQueryPoolCreateInfo qpi{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO}; qpi.queryType = VK_QUERY_TYPE_TIMESTAMP; qpi.queryCount = 8 * R;
        VkQueryPool qp_bench; CK(vkCreateQueryPool(dev, &qpi, nullptr, &qp_bench));

        std::vector<double> ms_prep(R), ms_t1(R), ms_t2(R), ms_t3(R), ms_tot(R);
        for (int r = 0; r < R; ++r) {
            CK(vkBeginCommandBuffer(cb, &bbi));
            vkCmdResetQueryPool(cb, qp_bench, 8 * r, 8);

                                      
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_prep, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            cur_pipe = VK_NULL_HANDLE;
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp_bench, 8 * r + 0);
            for (const auto& d : plan_prep.dispatches) recordOp(plan_prep, dpipe_prep, d);
            syncPrepToT();
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp_bench, 8 * r + 1);

                                   
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{0, pmask_off, pmask_cnt};
                vkCmdCopyBuffer(cb, bPmask[0].b, bArena_t.b, 1, &c);
                barrier();
            }
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_t[0], 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            cur_pipe = VK_NULL_HANDLE;
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp_bench, 8 * r + 2);
            for (const auto& d : plan_t.dispatches) recordOp(plan_t, dpipe_t, d);
            barrier();
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp_bench, 8 * r + 3);
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{pmask_off, 0, pmask_cnt};
                vkCmdCopyBuffer(cb, bArena_t.b, bPmask[0].b, 1, &c);
                barrier();
            }

                                   
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{0, pmask_off, pmask_cnt};
                vkCmdCopyBuffer(cb, bPmask[1].b, bArena_t.b, 1, &c);
                barrier();
            }
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_t[1], 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            cur_pipe = VK_NULL_HANDLE;
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp_bench, 8 * r + 4);
            for (const auto& d : plan_t.dispatches) recordOp(plan_t, dpipe_t, d);
            barrier();
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp_bench, 8 * r + 5);
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{pmask_off, 0, pmask_cnt};
                vkCmdCopyBuffer(cb, bArena_t.b, bPmask[1].b, 1, &c);
                barrier();
            }

                                   
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{0, pmask_off, pmask_cnt};
                vkCmdCopyBuffer(cb, bPmask[2].b, bArena_t.b, 1, &c);
                barrier();
            }
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds_t[2], 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            cur_pipe = VK_NULL_HANDLE;
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp_bench, 8 * r + 6);
            for (const auto& d : plan_t.dispatches) recordOp(plan_t, dpipe_t, d);
            barrier();
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp_bench, 8 * r + 7);
            if (pmask_tid >= 0 && pmask_cnt > 0) {
                VkBufferCopy c{pmask_off, 0, pmask_cnt};
                vkCmdCopyBuffer(cb, bArena_t.b, bPmask[2].b, 1, &c);
                barrier();
            }

            submit();
        }

        std::vector<uint64_t> ts(8 * R);
        CK(vkGetQueryPoolResults(dev, qp_bench, 0, 8 * R, ts.size() * 8, ts.data(), 8, VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT));
        for (int r = 0; r < R; ++r) {
            ms_prep[r] = double(ts[8 * r + 1] - ts[8 * r + 0]) * pr.limits.timestampPeriod * 1e-6;
            ms_t1[r]   = double(ts[8 * r + 3] - ts[8 * r + 2]) * pr.limits.timestampPeriod * 1e-6;
            ms_t2[r]   = double(ts[8 * r + 5] - ts[8 * r + 4]) * pr.limits.timestampPeriod * 1e-6;
            ms_t3[r]   = double(ts[8 * r + 7] - ts[8 * r + 6]) * pr.limits.timestampPeriod * 1e-6;
            ms_tot[r]  = ms_prep[r] + ms_t1[r] + ms_t2[r] + ms_t3[r];
        }
        std::sort(ms_prep.begin(), ms_prep.end());
        std::sort(ms_t1.begin(), ms_t1.end());
        std::sort(ms_t2.begin(), ms_t2.end());
        std::sort(ms_t3.begin(), ms_t3.end());
        std::sort(ms_tot.begin(), ms_tot.end());

        printf("Graph gen_4x %dx%d: total median %.2f ms (prep %.2f, t1 %.2f, t2 %.2f, t3 %.2f) -> %.2f ms / generated frame over %d runs\n",
               W, H, ms_tot[R / 2], ms_prep[R / 2], ms_t1[R / 2], ms_t2[R / 2], ms_t3[R / 2], ms_tot[R / 2] / 3.0, R);

                       
        for (int oi = 0; oi < g_t.num_outputs; ++oi) {
            int t = g_t.io[g_t.num_inputs + oi];
            uint64_t off, cnt_bytes; mlof2_tensor_span(g_t, plan_t, t, off, cnt_bytes);
            CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena_t.b, st.b, 1, &c); submit();
            char fn[64]; snprintf(fn, sizeof fn, "/out_%s.bin", g_t.io_names[g_t.num_inputs + oi]);
            FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
        }
    }
    return 0;
}

int main(int argc, char** argv) {
    if (argc < 4) { printf("usage: mlof2_vk_harness <generated dir> <io dir> dump|bench|profile [H W]\n"); return 1; }
    std::string gdir = argv[1], io = argv[2], mode = argv[3];
    int H = argc > 5 ? atoi(argv[4]) : 1088, W = argc > 5 ? atoi(argv[5]) : 1920;

    std::string graphName = "pair";
    if (getenv("MLOF2_GRAPH")) graphName = getenv("MLOF2_GRAPH");
    
    const bool use_coop = !getenv("MLOF2_USE_COOPMAT") || std::string(getenv("MLOF2_USE_COOPMAT")) != "0";
    if (graphName == "gen_4x") return run_gen_4x(gdir, io, mode, H, W, use_coop);

    bool is_fp8 = (gdir.find("fp8") != std::string::npos) || (getenv("MLOF2_FP8") && std::string(getenv("MLOF2_FP8")) != "0");
    const Mlof2Graph* pGraph = nullptr;
    if (is_fp8) {
        if (graphName == "enc") pGraph = &mlof2_enc_fp8_graph;
        else if (graphName == "gen") pGraph = &mlof2_gen_fp8_graph;
        else pGraph = &mlof2_pair_fp8_graph;
    } else {
                                                
        if (graphName == "enc") pGraph = &mlof2_enc_int8_graph;
        else if (graphName == "gen") pGraph = &mlof2_gen_int8_graph;
        else if (graphName == "gen_prep") pGraph = &mlof2_gen_prep_int8_graph;
        else if (graphName == "gen_t") pGraph = &mlof2_gen_t_int8_graph;
        else if (graphName == "oft") {
            if (getenv("MLOF2_OFT_HALF") && strcmp(getenv("MLOF2_OFT_HALF"), "1") == 0) {
                pGraph = &g_mlof2_oft_half_graph;
                if (gdir.find("half") == std::string::npos && gdir.find("generated_oft_v2_int8") != std::string::npos) {
                    gdir = gdir.substr(0, gdir.find("generated_oft_v2_int8")) + "generated_oft_half_v2_int8";
                }
            } else {
                pGraph = &g_mlof2_oft_graph;
            }
        }
        else if (graphName == "oft_half") pGraph = &g_mlof2_oft_half_graph;
        else if (graphName.find("fuse") != std::string::npos) pGraph = &g_mlof2_fuse_graph;
        else pGraph = &mlof2_pair_int8_graph;
    }
    const Mlof2Graph& g = *pGraph;
                                                                                                                   
    if (g.weight_fmt != 2) { printf("graph %s: weight_fmt %d, this build runs int8 (2) only\n", g.blob_name, g.weight_fmt); return 1; }

    Mlof2Plan plan;
    if (!mlof2_plan(g, H, W, plan, use_coop)) { printf("bad size %dx%d\n", W, H); return 1; }

    if (graphName == "oft" || graphName == "oft_half") {
        float* meta_fc = (float*)&plan.meta[plan.fc];
        meta_fc[MLOF2_FC_T] = getenv("MLOF2_T") ? float(atof(getenv("MLOF2_T"))) : 0.5f;
    }

    if (graphName == "gen" || graphName == "gen_prep" || graphName == "gen_t") {
        std::string fcPath = io + "/fc.f32";
        FILE* ff = fopen(fcPath.c_str(), "rb");
        if (ff) {
            fclose(ff);
            auto fcv = readFile(fcPath);
            memcpy(&plan.meta[plan.fc], fcv.data(), std::min<size_t>(fcv.size(), MLOF2_FC_WORDS * 4));
            
                                                                             
            std::string vpPrevPath = io + "/vp_prev.f32";
            FILE* fp = fopen(vpPrevPath.c_str(), "rb");
            if (fp) {
                fclose(fp);
                auto vpp = readFile(vpPrevPath);
                if (vpp.size() >= 64) {
                    float* meta_fc = (float*)&plan.meta[plan.fc];
                    float t = meta_fc[MLOF2_FC_T];
                    if (t > 0.001f && t < 0.999f) {
                        float vp_b_prime[16];
                        mlof2_calc_quadratic_vp_b((const float*)vpp.data(), &meta_fc[MLOF2_FC_VP_A], &meta_fc[MLOF2_FC_VP_B], t, vp_b_prime);
                        memcpy(&meta_fc[MLOF2_FC_VP_B], vp_b_prime, 16 * 4);
                        printf("Applied 2nd-order quadratic camera interpolation (t = %.3f)\n", t);
                    }
                }
            }
        }
    }

    auto inputFile = [&](const char* name) {
        std::string p_bin = io + "/in_" + name + ".bin";
        FILE* f = fopen(p_bin.c_str(), "rb"); if (f) { fclose(f); return p_bin; }
        std::string p_f32 = io + "/in_" + name + ".f32";
        f = fopen(p_f32.c_str(), "rb"); if (f) { fclose(f); return p_f32; }
        std::string p_raw = io + "/" + name + ".bin";
        f = fopen(p_raw.c_str(), "rb"); if (f) { fclose(f); return p_raw; }
        return io + "/" + name + ".f32";
    };

    auto blob = readFile(gdir + "/" + g.blob_name);
    if (blob.size() != size_t(g.blob_words) * 4) { printf("blob size %zu != %u words\n", blob.size(), g.blob_words); return 1; }
    mlof2_convw_weights(g, plan, blob);                                            

    VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.apiVersion = VK_API_VERSION_1_3;
    VkInstanceCreateInfo ici{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO}; ici.pApplicationInfo = &app; VkInstance inst; CK(vkCreateInstance(&ici, nullptr, &inst));

    uint32_t nd = 0; vkEnumeratePhysicalDevices(inst, &nd, nullptr); std::vector<VkPhysicalDevice> pds(nd); vkEnumeratePhysicalDevices(inst, &nd, pds.data());
    VkPhysicalDevice pd = pds[0];
    vkGetPhysicalDeviceMemoryProperties(pd, &mp);
    VkPhysicalDeviceProperties pr; vkGetPhysicalDeviceProperties(pd, &pr);
    uint32_t nq = 0; vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, nullptr); std::vector<VkQueueFamilyProperties> qp(nq); vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, qp.data());
    uint32_t qf = 0; for (uint32_t i = 0; i < nq; ++i) if (qp[i].queueFlags & VK_QUEUE_COMPUTE_BIT) { qf = i; break; }
    float prio = 1.0f; VkDeviceQueueCreateInfo qi{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO}; qi.queueFamilyIndex = qf; qi.queueCount = 1; qi.pQueuePriorities = &prio;

                                       
    uint32_t extCount = 0;
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, nullptr);
    std::vector<VkExtensionProperties> availExts(extCount);
    vkEnumerateDeviceExtensionProperties(pd, nullptr, &extCount, availExts.data());
    Mlof2Caps caps = mlof2_query_caps(inst, pd);
    VkQueue q = VK_NULL_HANDLE;
    if (!mlof2_create_device(inst, pd, caps, qf, &dev, &q)) return 1;

    VkMemoryPropertyFlags DL = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, HV = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    VkBufferUsageFlags SB = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    
                                                   
    Buf bArena = mk(plan.arena_bytes, SB, DL), bBlob = mk(blob.size(), SB, DL), bMeta = mk(plan.meta.size() * 4, SB, DL);
    
                                                                           
    uint64_t maxT = 0;
    for (int t = 0; t < g.num_tensors; ++t) { uint64_t o, c; mlof2_tensor_span(g, plan, t, o, c); maxT = std::max(maxT, c); }
    size_t init_st_needed = ((blob.size() + 255u) & ~255u) + ((plan.meta.size() * 4 + 255u) & ~255u);
    size_t stN = std::max<size_t>({init_st_needed, size_t(maxT), size_t(W) * size_t(H) * 16u});
    Buf st = mk(stN, VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, HV);
    uint8_t* sp; CK(vkMapMemory(dev, st.m, 0, stN, 0, (void**)&sp));

    struct Img {
        VkImage image = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        VkImageView view = VK_NULL_HANDLE;
        uint32_t width = 0, height = 0;
    };
    auto mkimg = [&](uint32_t w, uint32_t h) -> Img {
        Img img; img.width = w; img.height = h;
        VkImageCreateInfo ici{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
        ici.imageType = VK_IMAGE_TYPE_2D;
        ici.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        ici.extent = {w, h, 1};
        ici.mipLevels = 1;
        ici.arrayLayers = 1;
        ici.samples = VK_SAMPLE_COUNT_1_BIT;
        ici.tiling = VK_IMAGE_TILING_OPTIMAL;
        ici.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        ici.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        ici.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        CK(vkCreateImage(dev, &ici, nullptr, &img.image));
        VkMemoryRequirements mr; vkGetImageMemoryRequirements(dev, img.image, &mr);
        VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, nullptr, mr.size, memType(mr.memoryTypeBits, DL)};
        CK(vkAllocateMemory(dev, &mai, nullptr, &img.memory));
        CK(vkBindImageMemory(dev, img.image, img.memory, 0));
        VkImageViewCreateInfo ivci{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        ivci.image = img.image;
        ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        ivci.format = VK_FORMAT_R16G16B16A16_SFLOAT;
        ivci.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        CK(vkCreateImageView(dev, &ivci, nullptr, &img.view));
        return img;
    };
    Img imgCabA = mkimg(W, H);
    Img imgCabB = mkimg(W, H);
    Img imgQpA = mkimg(W / 4, H / 4);
    Img imgQpB = mkimg(W / 4, H / 4);
    Img* all_imgs[4] = {&imgCabA, &imgCabB, &imgQpA, &imgQpB};

    VkSampler samplerLinear;
    {
        VkSamplerCreateInfo sci{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
        sci.magFilter = VK_FILTER_LINEAR;
        sci.minFilter = VK_FILTER_LINEAR;
        sci.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        sci.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
        sci.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
        sci.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
        sci.borderColor = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
        sci.unnormalizedCoordinates = VK_FALSE;
        CK(vkCreateSampler(dev, &sci, nullptr, &samplerLinear));
    }

    VkDescriptorSetLayoutBinding lb[11];
    for (int i = 0; i < 3; ++i) lb[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    for (int i = 3; i < 7; ++i) lb[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    for (int i = 7; i < 11; ++i) lb[i] = {uint32_t(i), VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    VkDescriptorSetLayoutCreateInfo dli{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dli.bindingCount = 11; dli.pBindings = lb; VkDescriptorSetLayout dsl; CK(vkCreateDescriptorSetLayout(dev, &dli, nullptr, &dsl));
                                                                                                                   
    VkDescriptorSetLayoutBinding xlb[7];
    for (int i = 0; i < 7; ++i) xlb[i] = {uint32_t(i), i == 5 ? VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_COMPUTE_BIT, nullptr};
    VkDescriptorSetLayoutCreateInfo xli{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; xli.bindingCount = 7; xli.pBindings = xlb;
    VkDescriptorSetLayout dsl_ext; CK(vkCreateDescriptorSetLayout(dev, &xli, nullptr, &dsl_ext));
    VkDescriptorSetLayout pls[2] = {dsl, dsl_ext};
    VkPushConstantRange pcr{VK_SHADER_STAGE_COMPUTE_BIT, 0, 20};
    VkPipelineLayoutCreateInfo pli{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; pli.setLayoutCount = 2; pli.pSetLayouts = pls; pli.pushConstantRangeCount = 1; pli.pPushConstantRanges = &pcr;
    VkPipelineLayout pl; CK(vkCreatePipelineLayout(dev, &pli, nullptr, &pl));
    const char* const* k_names = g_mlof2_kernel_names;
    std::vector<VkPipeline> pipe(g_mlof2_num_kernels);
    const uint32_t* const* codes = g_mlof2_kernel_spv;
    const size_t* sizes = g_mlof2_kernel_spv_size;
    VkPipelineCreateFlags p_flags = nfru_isa::createFlags(dev);
                                                                                                               
                                                                     
    std::vector<VkShaderModule> smod(g_mlof2_num_kernels);
    struct SpecKey { uint32_t kernel, fmts; int32_t ip0, ip1; uint32_t rt, sw, ksp, pf; };
    std::vector<std::pair<SpecKey, VkPipeline>> spec_pipes;
    auto mkpipe = [&](int k, uint32_t fmts, int32_t ip0, int32_t ip1, uint32_t rt, uint32_t sw, uint32_t ksp, uint32_t pf = 24u) -> VkPipeline {
        uint32_t sd[7] = {fmts, uint32_t(ip0), uint32_t(ip1), rt, sw, ksp, pf};
        VkSpecializationMapEntry me[7] = {{0u, 0u, 4u}, {1u, 4u, 4u}, {2u, 8u, 4u}, {3u, 12u, 4u}, {4u, 16u, 4u}, {5u, 20u, 4u}, {6u, 24u, 4u}};
        VkSpecializationInfo spi{7u, me, 28u, sd};
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpi.flags = p_flags;
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        const bool wave32 = (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);                                                                         
        const bool wave64 = (k == 0 || k == 1) && !getenv("MLOF2_DP4A_WAVE32");                                       
        rss.requiredSubgroupSize = wave32 ? 32u : 64u;
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (wave32 || wave64) ? &rss : nullptr,
                     wave32 ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                     VK_SHADER_STAGE_COMPUTE_BIT, smod[k], "main", &spi};
        cpi.layout = pl;
        VkPipeline pp; CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp));
        return pp;
    };
    bool used_kernel[128] = {false};
    for (const auto& d : plan.dispatches) if (d.kernel < 128) used_kernel[d.kernel] = true;
    for (int k = 0; k < g_mlof2_num_kernels; ++k) {
        VkShaderModuleCreateInfo smi{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; smi.codeSize = sizes[k]; smi.pCode = codes[k]; VkShaderModule sm; CK(vkCreateShaderModule(dev, &smi, nullptr, &sm));
        smod[k] = sm;
        if (k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk) { pipe[k] = VK_NULL_HANDLE; continue; }                                    
        if (!used_kernel[k]) { pipe[k] = VK_NULL_HANDLE; continue; }
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpi.flags = p_flags;
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        const bool wave32 = (k == 3 || k == g_mlof2_kernel_conv_w || k == g_mlof2_kernel_conv_blk);                                                                         
        const bool wave64 = (k == 0 || k == 1) && !getenv("MLOF2_DP4A_WAVE32");                                       
        rss.requiredSubgroupSize = wave32 ? 32u : 64u;
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, (wave32 || wave64) ? &rss : nullptr,
                     wave32 ? VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT) : 0u,
                     VK_SHADER_STAGE_COMPUTE_BIT, sm, "main", nullptr};
        cpi.layout = pl;
        CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pipe[k]));
        nfru_isa::dump(dev, pipe[k], k_names[k]);
    }
    const bool no_spec = getenv("MLOF2_NO_SPEC") && std::string(getenv("MLOF2_NO_SPEC")) != "0";                            
    std::vector<VkPipeline> dpipe(plan.dispatches.size());
    auto mkpipe_w = [&](const Mlof2Dispatch& d) -> VkPipeline {                                                              
        uint32_t sd[31] = {d.fmts, uint32_t(d.ip01[0]), uint32_t(d.ip01[1])};
        VkSpecializationMapEntry me[31];
        for (uint32_t j = 0; j < 3; ++j) me[j] = {j, 4u * j, 4u};
        for (uint32_t j = 0; j < 28; ++j) { sd[3 + j] = d.wsc[j]; me[3 + j] = {10u + j, 4u * (3u + j), 4u}; }
        VkSpecializationInfo spi{31u, me, sizeof sd, sd};
        VkPipelineShaderStageRequiredSubgroupSizeCreateInfo rss{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};
        rss.requiredSubgroupSize = 32u;
        VkComputePipelineCreateInfo cpi{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
        cpi.flags = p_flags;
        cpi.stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, &rss, VkPipelineShaderStageCreateFlags(VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT),
                     VK_SHADER_STAGE_COMPUTE_BIT, smod[d.kernel], "main", &spi};
        cpi.layout = pl;
        VkPipeline pp; CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, nullptr, &pp));
        return pp;
    };
    int n_w = 0;
    for (size_t i = 0; i < plan.dispatches.size(); ++i) {
        const Mlof2Dispatch& d = plan.dispatches[i];
        if (d.wk) {
            dpipe[i] = mkpipe_w(d);
            char nm[64]; snprintf(nm, sizeof nm, d.kernel == uint32_t(g_mlof2_kernel_conv_blk) ? "mlof2_conv_blk_op%u" : "mlof2_conv_w_op%u", d.op);
            nfru_isa::dump(dev, dpipe[i], nm);
            ++n_w;
            continue;
        }
        if (d.fmts == 0xFFFFFFFFu && d.coop_rt == 1u && d.coop_sw == 8u && d.coop_fuse == 0u && d.coop_pf == 24u) { dpipe[i] = pipe[d.kernel]; continue; }
        const SpecKey key = no_spec ? SpecKey{d.kernel, 0xFFFFFFFFu, 0x7FFFFFFF, 0x7FFFFFFF, d.coop_rt, d.coop_sw, d.coop_fuse, d.coop_pf}
                                    : SpecKey{d.kernel, d.fmts, d.ip01[0], d.ip01[1], d.coop_rt, d.coop_sw, d.coop_fuse, d.coop_pf};
        auto it = std::find_if(spec_pipes.begin(), spec_pipes.end(), [&](const std::pair<SpecKey, VkPipeline>& e) {
            return e.first.kernel == key.kernel && e.first.fmts == key.fmts && e.first.ip0 == key.ip0 && e.first.ip1 == key.ip1 &&
                   e.first.rt == key.rt && e.first.sw == key.sw && e.first.ksp == key.ksp && e.first.pf == key.pf; });
        if (it == spec_pipes.end()) {
            spec_pipes.push_back({key, mkpipe(int(d.kernel), key.fmts, key.ip0, key.ip1, key.rt, key.sw, key.ksp, key.pf)});
            char nm[96]; snprintf(nm, sizeof nm, "%s_f%08x_i%d_%d_r%u_s%u_k%u_p%u", k_names[d.kernel], key.fmts, key.ip0, key.ip1, key.rt, key.sw, key.ksp, key.pf);
            nfru_isa::dump(dev, spec_pipes.back().second, nm);
            it = spec_pipes.end() - 1;
        }
        dpipe[i] = it->second;
    }
    printf("%zu pipelines with constant formats, %d one-wave conv pipelines%s\n", spec_pipes.size(), n_w, no_spec ? " (MLOF2_NO_SPEC: off)" : "");
    VkDescriptorPoolSize dps[3] = {
        {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 3},
        {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 4 + 1},
        {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 4 + 6}
    };
    VkDescriptorPoolCreateInfo dpi{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dpi.maxSets = 2; dpi.poolSizeCount = 3; dpi.pPoolSizes = dps;
    VkDescriptorPool dp; CK(vkCreateDescriptorPool(dev, &dpi, nullptr, &dp));
    VkDescriptorSetAllocateInfo dai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; dai.descriptorPool = dp; dai.descriptorSetCount = 1; dai.pSetLayouts = &dsl; VkDescriptorSet ds; CK(vkAllocateDescriptorSets(dev, &dai, &ds));
    VkDescriptorSet ds_ext;
    {
        VkDescriptorSetAllocateInfo xai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; xai.descriptorPool = dp; xai.descriptorSetCount = 1; xai.pSetLayouts = &dsl_ext;
        CK(vkAllocateDescriptorSets(dev, &xai, &ds_ext));
        VkDescriptorImageInfo xs{samplerLinear, imgCabA.view, VK_IMAGE_LAYOUT_GENERAL}, xo{VK_NULL_HANDLE, imgCabB.view, VK_IMAGE_LAYOUT_GENERAL};
        VkWriteDescriptorSet xw[7];
        for (int i = 0; i < 7; ++i) xw[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds_ext, uint32_t(i), 0, 1, i == 5 ? VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, i == 5 ? &xo : &xs, nullptr, nullptr};
        vkUpdateDescriptorSets(dev, 7, xw, 0, nullptr);
    }
    Buf* bs[3] = {&bArena, &bBlob, &bMeta}; VkDescriptorBufferInfo dbi[3];
    VkDescriptorImageInfo dii_storage[4];
    VkDescriptorImageInfo dii_sampler[4];
    VkWriteDescriptorSet wr[11];
    for (int i = 0; i < 3; ++i) { dbi[i] = {bs[i]->b, 0, VK_WHOLE_SIZE}; wr[i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds, uint32_t(i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, nullptr, &dbi[i], nullptr}; }
    for (int i = 0; i < 4; ++i) { dii_storage[i] = {VK_NULL_HANDLE, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL}; wr[3 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds, uint32_t(3 + i), 0, 1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &dii_storage[i], nullptr, nullptr}; }
    for (int i = 0; i < 4; ++i) { dii_sampler[i] = {samplerLinear, all_imgs[i]->view, VK_IMAGE_LAYOUT_GENERAL}; wr[7 + i] = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, nullptr, ds, uint32_t(7 + i), 0, 1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, &dii_sampler[i], nullptr, nullptr}; }
    vkUpdateDescriptorSets(dev, 11, wr, 0, nullptr);
    VkCommandPoolCreateInfo cpo{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO}; cpo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT; cpo.queueFamilyIndex = qf; VkCommandPool cp; CK(vkCreateCommandPool(dev, &cpo, nullptr, &cp));
    VkCommandBufferAllocateInfo cai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO}; cai.commandPool = cp; cai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; cai.commandBufferCount = 1; VkCommandBuffer cb; CK(vkAllocateCommandBuffers(dev, &cai, &cb));
    VkCommandBufferBeginInfo bbi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER}; mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT; mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT;
    auto barrier = [&]() { vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr); };
    auto submit = [&]() { CK(vkEndCommandBuffer(cb)); VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount = 1; si.pCommandBuffers = &cb; CK(vkQueueSubmit(q, 1, &si, VK_NULL_HANDLE)); CK(vkQueueWaitIdle(q)); CK(vkResetCommandBuffer(cb, 0)); };

                                                                                        
    size_t meta_off = (blob.size() + 255u) & ~255u;
    assert(blob.size() <= stN);
    memcpy(sp, blob.data(), blob.size());
    assert(meta_off + plan.meta.size() * 4 <= stN);
    memcpy(sp + meta_off, plan.meta.data(), plan.meta.size() * 4);
    CK(vkBeginCommandBuffer(cb, &bbi));
    VkImageMemoryBarrier init_imb[4];
    for (int i = 0; i < 4; ++i) {
        init_imb[i] = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
        init_imb[i].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        init_imb[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
        init_imb[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        init_imb[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        init_imb[i].image = all_imgs[i]->image;
        init_imb[i].subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        init_imb[i].srcAccessMask = 0;
        init_imb[i].dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
    }
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 4, init_imb);
    VkBufferCopy c0{0, 0, blob.size()}, c1{meta_off, 0, plan.meta.size() * 4};
    vkCmdCopyBuffer(cb, st.b, bBlob.b, 1, &c0); vkCmdCopyBuffer(cb, st.b, bMeta.b, 1, &c1);
    vkCmdFillBuffer(cb, bArena.b, 0, VK_WHOLE_SIZE, 0xFFFFFFFFu);
    if (plan.blk_hi > plan.blk_lo) {                                                                          
        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER}; mb.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT; mb.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 1, &mb, 0, nullptr, 0, nullptr);
        vkCmdFillBuffer(cb, bArena.b, plan.blk_lo, plan.blk_hi - plan.blk_lo, 0u);
    }
    submit();
    int n_blk = 0; for (const Mlof2Blk& b : plan.blk) n_blk += b.on;
    if (n_blk) printf("%d channel-blocked tensors, %.2f MB\n", n_blk, double(plan.blk_hi - plan.blk_lo) / 1048576.0);

                    
    for (int i = 0; i < g.num_inputs; ++i) {
        uint64_t off, cnt_bytes; mlof2_tensor_span(g, plan, g.io[i], off, cnt_bytes);
        std::string fn = inputFile(g.io_names[i]);
        auto v = readFile(fn);
        const Mlof2Tensor& td = g.tensors[g.io[i]];
        if (td.fmt == 1 && fn.size() > 4 && fn.substr(fn.size() - 4) == ".f32") {
                                                                                                                 
            const size_t npx = size_t(td.n) * (H / td.s) * (W / td.s);
            if (v.size() < npx * td.c * 4) { printf("%s: %zu bytes, expected >= %zu (fp32)\n", g.io_names[i], v.size(), npx * td.c * 4); return 1; }
            std::vector<uint8_t> h(cnt_bytes, 0);
            const float* f = (const float*)v.data(); uint16_t* o = (uint16_t*)h.data();
            auto f2h = [](float x) -> uint16_t {
                uint32_t u; memcpy(&u, &x, 4); uint32_t sgn = (u >> 16) & 0x8000u; int e = int((u >> 23) & 0xFF) - 127 + 15; uint32_t m = u & 0x7FFFFFu;
                if (((u >> 23) & 0xFF) == 0xFF) return uint16_t(sgn | 0x7C00u | (m ? 0x200u : 0u));
                if (e >= 31) return uint16_t(sgn | 0x7C00u);
                if (e <= 0) { if (e < -10) return uint16_t(sgn); m |= 0x800000u; uint32_t sh = uint32_t(14 - e); uint32_t r = m >> sh, rem = m & ((1u << sh) - 1u), half = 1u << (sh - 1);
                              if (rem > half || (rem == half && (r & 1u))) ++r; return uint16_t(sgn | r); }
                uint32_t r = (uint32_t(e) << 10) | (m >> 13), rem = m & 0x1FFFu;
                if (rem > 0x1000u || (rem == 0x1000u && (r & 1u))) ++r;
                return uint16_t(sgn | r);
            };
            for (size_t px = 0; px < npx; ++px) for (int c = 0; c < td.c; ++c) o[px * td.c_alloc + c] = f2h(f[px * td.c + c]);
            v.swap(h);
        }
        if (v.size() > cnt_bytes) {
                                                                                              
            v.resize(cnt_bytes);
        } else if (v.size() != cnt_bytes) {
            printf("%s: %zu bytes, expected %llu\n", g.io_names[i], v.size(), (unsigned long long)cnt_bytes);
            return 1;
        }
        memcpy(sp, v.data(), v.size());
        CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{0, off, cnt_bytes}; vkCmdCopyBuffer(cb, st.b, bArena.b, 1, &c); submit();
        if (graphName == "gen_t" && std::string(g.io_names[i]) == "cab") {
            const size_t npx = size_t(W) * H;
            const uint16_t* cab_src = (const uint16_t*)v.data();
            uint16_t* dstA = (uint16_t*)sp;
            uint16_t* dstB = (uint16_t*)(sp + uint64_t(W) * H * 8);
            for (size_t px = 0; px < npx; ++px) {
                dstA[4 * px + 0] = cab_src[8 * px + 0];
                dstA[4 * px + 1] = cab_src[8 * px + 1];
                dstA[4 * px + 2] = cab_src[8 * px + 2];
                dstA[4 * px + 3] = cab_src[8 * px + 3];
                dstB[4 * px + 0] = cab_src[8 * px + 4];
                dstB[4 * px + 1] = cab_src[8 * px + 5];
                dstB[4 * px + 2] = cab_src[8 * px + 6];
                dstB[4 * px + 3] = cab_src[8 * px + 7];
            }
            CK(vkBeginCommandBuffer(cb, &bbi));
            VkBufferImageCopy bicA{}; bicA.bufferOffset = 0; bicA.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicA.imageExtent = {uint32_t(W), uint32_t(H), 1};
            vkCmdCopyBufferToImage(cb, st.b, imgCabA.image, VK_IMAGE_LAYOUT_GENERAL, 1, &bicA);
            VkBufferImageCopy bicB{}; bicB.bufferOffset = uint64_t(W) * H * 8; bicB.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicB.imageExtent = {uint32_t(W), uint32_t(H), 1};
            vkCmdCopyBufferToImage(cb, st.b, imgCabB.image, VK_IMAGE_LAYOUT_GENERAL, 1, &bicB);
            VkImageMemoryBarrier imb_cab[2] = {
                {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgCabA.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}},
                {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgCabB.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}}
            };
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 2, imb_cab);
            submit();
        }
        if (graphName == "gen_t" && std::string(g.io_names[i]) == "qp") {
            const size_t npx = size_t(W / 4) * (H / 4);
            const uint16_t* qp_src = (const uint16_t*)v.data();
            uint16_t* dstA = (uint16_t*)sp;
            uint16_t* dstB = (uint16_t*)(sp + uint64_t(W / 4) * (H / 4) * 8);
            for (size_t px = 0; px < npx; ++px) {
                dstA[4 * px + 0] = qp_src[12 * px + 0];
                dstA[4 * px + 1] = qp_src[12 * px + 1];
                dstA[4 * px + 2] = qp_src[12 * px + 2];
                dstA[4 * px + 3] = qp_src[12 * px + 3];
                dstB[4 * px + 0] = qp_src[12 * px + 4];
                dstB[4 * px + 1] = qp_src[12 * px + 5];
                dstB[4 * px + 2] = qp_src[12 * px + 6];
                dstB[4 * px + 3] = qp_src[12 * px + 7];
            }
            CK(vkBeginCommandBuffer(cb, &bbi));
            VkBufferImageCopy bicA{}; bicA.bufferOffset = 0; bicA.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicA.imageExtent = {uint32_t(W / 4), uint32_t(H / 4), 1};
            vkCmdCopyBufferToImage(cb, st.b, imgQpA.image, VK_IMAGE_LAYOUT_GENERAL, 1, &bicA);
            VkBufferImageCopy bicB{}; bicB.bufferOffset = uint64_t(W / 4) * (H / 4) * 8; bicB.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1}; bicB.imageExtent = {uint32_t(W / 4), uint32_t(H / 4), 1};
            vkCmdCopyBufferToImage(cb, st.b, imgQpB.image, VK_IMAGE_LAYOUT_GENERAL, 1, &bicB);
            VkImageMemoryBarrier imb_qp[2] = {
                {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgQpA.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}},
                {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, imgQpB.image, {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}}
            };
            vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0, nullptr, 2, imb_qp);
            submit();
        }
    }

    VkPipeline cur_pipe = VK_NULL_HANDLE;
    const bool prof_empty = mode == "profile" && getenv("MLOF2_PROF_EMPTY") && strcmp(getenv("MLOF2_PROF_EMPTY"), "0") != 0;
    auto record = [&](const Mlof2Dispatch& d) {
        if (d.barrier_before) barrier();
        uint32_t pcv[5] = {d.op, plan.tb, plan.sb, plan.ob, plan.fc};
        VkPipeline pp = dpipe[&d - plan.dispatches.data()];
        if (pp != cur_pipe) {
            vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pp);
            cur_pipe = pp;
        }
        vkCmdPushConstants(cb, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 20, pcv);
        if (prof_empty) vkCmdDispatch(cb, 1, 1, 1);                                                                       
        else vkCmdDispatch(cb, d.gx, d.gy, 1);
    };

    if (mode == "dump") {
        for (const auto& d : plan.dispatches) {
            CK(vkBeginCommandBuffer(cb, &bbi));
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);                      
            cur_pipe = VK_NULL_HANDLE;                                                                                        
            barrier();
            record(d);
            barrier();
            uint64_t off, cnt_bytes; mlof2_tensor_span(g, plan, g.ops[d.op].out, off, cnt_bytes);
            char fn[64]; snprintf(fn, sizeof fn, "/op_%03u.bin", d.op);
            FILE* f = nullptr;
            if (g.ops[d.op].kind == MLOF2_K_PREP_C) {
                                                                                            
                VkBufferImageCopy bicA{};
                bicA.bufferOffset = 0;
                bicA.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
                bicA.imageExtent = {uint32_t(W), uint32_t(H), 1};
                vkCmdCopyImageToBuffer(cb, imgCabA.image, VK_IMAGE_LAYOUT_GENERAL, st.b, 1, &bicA);
                VkBufferImageCopy bicB{};
                bicB.bufferOffset = uint64_t(W) * H * 8;
                bicB.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
                bicB.imageExtent = {uint32_t(W), uint32_t(H), 1};
                vkCmdCopyImageToBuffer(cb, imgCabB.image, VK_IMAGE_LAYOUT_GENERAL, st.b, 1, &bicB);
                submit();

                std::vector<uint8_t> cab_nhwc(cnt_bytes);
                const uint16_t* srcA = (const uint16_t*)sp;
                const uint16_t* srcB = (const uint16_t*)(sp + uint64_t(W) * H * 8);
                uint16_t* dst = (uint16_t*)cab_nhwc.data();
                size_t npx = size_t(W) * H;
                for (size_t px = 0; px < npx; ++px) {
                    dst[8 * px + 0] = srcA[4 * px + 0];
                    dst[8 * px + 1] = srcA[4 * px + 1];
                    dst[8 * px + 2] = srcA[4 * px + 2];
                    dst[8 * px + 3] = srcA[4 * px + 3];
                    dst[8 * px + 4] = srcB[4 * px + 0];
                    dst[8 * px + 5] = srcB[4 * px + 1];
                    dst[8 * px + 6] = srcB[4 * px + 2];
                    dst[8 * px + 7] = srcB[4 * px + 3];
                }
                f = fopen((io + fn).c_str(), "wb");
                fwrite(cab_nhwc.data(), 1, cnt_bytes, f);
                fclose(f);

                                                                                 
                memcpy(sp, cab_nhwc.data(), cnt_bytes);
                CK(vkBeginCommandBuffer(cb, &bbi));
                VkBufferCopy c_cab{0, off, cnt_bytes};
                vkCmdCopyBuffer(cb, st.b, bArena.b, 1, &c_cab);
                submit();
            } else {
                VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena.b, st.b, 1, &c);
                submit();
                f = fopen((io + fn).c_str(), "wb");
                if (plan.blk[g.ops[d.op].out].on) {
                    std::vector<uint8_t> nhwc; mlof2_blk_to_nhwc(g, plan, g.ops[d.op].out, sp, nhwc);
                    fwrite(nhwc.data(), 1, nhwc.size(), f);
                } else fwrite(sp, 1, cnt_bytes, f);
                fclose(f);
            }
            if (d.coop_fuse) {                                                                     
                const uint32_t op2 = d.op + d.coop_fuse;
                mlof2_tensor_span(g, plan, g.ops[op2].out, off, cnt_bytes);
                CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c2{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena.b, st.b, 1, &c2); submit();
                snprintf(fn, sizeof fn, "/op_%03u.bin", op2);
                f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
            }
        }
        printf("Dumped %zu ops to %s (Contract v2 binary format)\n", plan.dispatches.size(), io.c_str());
    } else if (mode == "profile") {
        const uint32_t N = uint32_t(plan.dispatches.size());
        VkQueryPoolCreateInfo qpi{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO}; qpi.queryType = VK_QUERY_TYPE_TIMESTAMP; qpi.queryCount = 2 * N; VkQueryPool qp; CK(vkCreateQueryPool(dev, &qpi, nullptr, &qp));
        std::vector<double> acc(N, 0.0);
        const int R = getenv("MLOF2_PROF_ALL") ? 11 : 5;                                              
        std::vector<std::vector<double>> runs(N);
        const bool prof_serial = getenv("MLOF2_PROF_SERIAL") && strcmp(getenv("MLOF2_PROF_SERIAL"), "0") != 0;
        for (int r = 0; r < R; ++r) {
            CK(vkBeginCommandBuffer(cb, &bbi));
            vkCmdResetQueryPool(cb, qp, 0, 2 * N);
            vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
            cur_pipe = VK_NULL_HANDLE;
            for (uint32_t i = 0; i < N; ++i) {
                if (prof_serial) barrier();                                                                
                                                                                                                          
                vkCmdWriteTimestamp(cb, prof_serial ? VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp, 2 * i);
                record(plan.dispatches[i]);
                vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp, 2 * i + 1);
            }
            submit();
            std::vector<uint64_t> ts(2 * N); CK(vkGetQueryPoolResults(dev, qp, 0, 2 * N, ts.size() * 8, ts.data(), 8, VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT));
            if (r) for (uint32_t i = 0; i < N; ++i) {
                const double v = double(ts[2 * i + 1] - ts[2 * i]) * pr.limits.timestampPeriod * 1e-6;
                acc[i] += v / (R - 1); runs[i].push_back(v);
            }
        }
        static const char* kn[] = {"conv", "unshuffle", "resize_area", "resize_bil", "warp", "corr", "absdiff", "round_trip", "spread", "axpy", "scale", "zeros", "copy", "convex_up", "prop_step",
            "vig_part", "vig_solve", "vig_apply", "mul", "invert_t", "warp_noise", "off_frame", "flowdist", "sigmoid", "fill_t", "up_nearest", "softmax_blend", "rule_prep", "pool",
            "luma_grad", "mask_mul", "median", "rule_score", "axpy_t", "rule_carry", "blend_mask", "cam_flow", "trail_sel", "warp_noise4", "feat4", "median_hist", "median_pick", "prep_c", "prep_f", "blend_prep", "carry", "cam_inv", "final", "prep", "inv3", "feat4c", "blend9", "final3",
            "prep_h", "q_prep", "q_cand", "q_feat", "q_rule1", "q_rule2", "cam_inv_q", "final4", "homog_acc", "homog_solve", "depthwise_dp4a",
            "oft_init", "oft_prep", "oft_out", "oft_final", "oft_lk", "oft_luma", "fuse_prep", "fuse_blend"};
        const int NK = int(sizeof(kn) / sizeof(kn[0]));
        double tot = 0, per_kind[128] = {0}; for (uint32_t i = 0; i < N; ++i) { tot += acc[i]; per_kind[g.ops[plan.dispatches[i].op].kind] += acc[i]; }
        printf("Total %.2f ms; per kind:", tot); for (int k = 0; k < NK; ++k) if (per_kind[k] > 0.01) printf(" %s %.2f", kn[k], per_kind[k]); printf("\n");
        std::vector<uint32_t> idx(N); for (uint32_t i = 0; i < N; ++i) idx[i] = i;
        std::sort(idx.begin(), idx.end(), [&](uint32_t a, uint32_t b) { return acc[a] > acc[b]; });
        if (getenv("MLOF2_PROF_ALL")) {                                                                               
            printf("ALL op kind kernel groups barrier us\n");
            for (uint32_t i = 0; i < N; ++i) {
                std::vector<double> v = runs[i]; std::sort(v.begin(), v.end());
                const Mlof2Dispatch& d = plan.dispatches[i];
                printf("ALL %u %s %u %u %d %.2f\n", d.op, kn[g.ops[d.op].kind], d.kernel, d.gx * d.gy, d.barrier_before ? 1 : 0, v[v.size() / 2] * 1e3);
            }
        }
        const int ntop = getenv("MLOF2_PROF_TOP") ? atoi(getenv("MLOF2_PROF_TOP")) : 15;
        for (int k = 0; k < ntop && k < int(N); ++k) {
            const Mlof2Op& o = g.ops[plan.dispatches[idx[k]].op]; const Mlof2Tensor& t = g.tensors[o.out];
            printf("  op %3u %-10s %8.2f ms (gx=%u) out %dx%d x%d ch (n %d)%s\n", plan.dispatches[idx[k]].op, kn[o.kind], acc[idx[k]], plan.dispatches[idx[k]].gx, W / t.s, H / t.s, o.out_c, t.n,
                   o.kind == 0 ? (" k" + std::to_string(o.ip[0]) + " dil" + std::to_string(o.ip[4]) + " icw" + std::to_string(o.kw_words / (o.ip[0] * o.ip[1]))).c_str() : "");
        }
    } else {
        const int R = 20;
        VkQueryPoolCreateInfo qpi{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO}; qpi.queryType = VK_QUERY_TYPE_TIMESTAMP; qpi.queryCount = 2 * R; VkQueryPool qp; CK(vkCreateQueryPool(dev, &qpi, nullptr, &qp));
                                                                                                                    
        const int reps = getenv("MLOF2_BENCH_REPEAT") ? std::max(1, atoi(getenv("MLOF2_BENCH_REPEAT"))) : 1;
                                                                                                                            
                                                                                                              
        const int gap = getenv("MLOF2_BENCH_GAP") ? atoi(getenv("MLOF2_BENCH_GAP")) : -1;
                                                                                                                       
                                                                                               
        const size_t flushMB = getenv("MLOF2_BENCH_FLUSH") ? size_t(atoi(getenv("MLOF2_BENCH_FLUSH"))) : 0;
        Buf flushBuf{};
        if (flushMB) flushBuf = mk(flushMB << 20, VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        auto flush = [&]() {
            if (!flushMB) return;
            vkCmdFillBuffer(cb, flushBuf.b, 0, VK_WHOLE_SIZE, 0x5A5A5A5Au);
            barrier();
        };
        for (int rep = 0; rep < reps; ++rep) {
        if (gap >= 0) {
            for (int r = 0; r < R; ++r) {
                Sleep(DWORD(gap));
                CK(vkBeginCommandBuffer(cb, &bbi));
                vkCmdResetQueryPool(cb, qp, 2 * r, 2);
                vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
                cur_pipe = VK_NULL_HANDLE;
                flush();
                                                                                                            
                vkCmdWriteTimestamp(cb, flushMB ? VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp, 2 * r);
                for (const auto& d : plan.dispatches) record(d);
                barrier();
                vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp, 2 * r + 1);
                submit();
            }
        } else {
        CK(vkBeginCommandBuffer(cb, &bbi));
        vkCmdResetQueryPool(cb, qp, 0, 2 * R);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds, 0, nullptr); vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 1, 1, &ds_ext, 0, nullptr);
        cur_pipe = VK_NULL_HANDLE;
        for (int r = 0; r < R; ++r) {
            flush();
                                                                                                        
            vkCmdWriteTimestamp(cb, flushMB ? VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, qp, 2 * r);
            for (const auto& d : plan.dispatches) record(d);
            barrier();
            vkCmdWriteTimestamp(cb, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, qp, 2 * r + 1);
        }
        submit();
        }
        std::vector<uint64_t> ts(2 * R); CK(vkGetQueryPoolResults(dev, qp, 0, 2 * R, ts.size() * 8, ts.data(), 8, VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT));
        std::vector<double> ms(R); for (int r = 0; r < R; ++r) ms[r] = double(ts[2 * r + 1] - ts[2 * r]) * pr.limits.timestampPeriod * 1e-6;
        std::sort(ms.begin(), ms.end());
        if (rep == reps - 1) printf("Graph %s %dx%d: median %.2f ms, min %.2f, max %.2f over %d runs\n", graphName.c_str(), W, H, ms[R / 2], ms[0], ms[R - 1], R);
        }

                        
        for (int oi = 0; oi < g.num_outputs; ++oi) {
            int t = g.io[g.num_inputs + oi];
            uint64_t off, cnt_bytes; mlof2_tensor_span(g, plan, t, off, cnt_bytes);
            CK(vkBeginCommandBuffer(cb, &bbi)); VkBufferCopy c{off, 0, cnt_bytes}; vkCmdCopyBuffer(cb, bArena.b, st.b, 1, &c); submit();
            char fn[64]; snprintf(fn, sizeof fn, "/out_%s.bin", g.io_names[g.num_inputs + oi]);
            FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(sp, 1, cnt_bytes, f); fclose(f);
        }
    }
    return 0;
}
