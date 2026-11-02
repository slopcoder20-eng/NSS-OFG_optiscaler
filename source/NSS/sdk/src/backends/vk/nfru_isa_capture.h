#pragma once
                                                                                                                     
                                                                                                                       
                                                                                                                       
                                                                                                                  
                                                                                                               
#include <vulkan/vulkan.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <mutex>
#include <direct.h>

namespace nfru_isa
{
inline const char* dumpDir()
{
    static const char* dir = getenv("NFRU_ISA_DUMP");
    return dir && dir[0] ? dir : nullptr;
}
struct Fns
{
    PFN_vkGetPipelineExecutablePropertiesKHR              props = nullptr;
    PFN_vkGetPipelineExecutableStatisticsKHR              stats = nullptr;
    PFN_vkGetPipelineExecutableInternalRepresentationsKHR reprs = nullptr;
    PFN_vkGetShaderInfoAMD                                amd   = nullptr;
};
inline Fns fns(VkDevice dev)
{
    Fns f;
    if (!dumpDir() || dev == VK_NULL_HANDLE) return f;
    f.props = (PFN_vkGetPipelineExecutablePropertiesKHR) vkGetDeviceProcAddr(dev, "vkGetPipelineExecutablePropertiesKHR");
    f.stats = (PFN_vkGetPipelineExecutableStatisticsKHR) vkGetDeviceProcAddr(dev, "vkGetPipelineExecutableStatisticsKHR");
    f.reprs = (PFN_vkGetPipelineExecutableInternalRepresentationsKHR) vkGetDeviceProcAddr(dev, "vkGetPipelineExecutableInternalRepresentationsKHR");
    f.amd   = (PFN_vkGetShaderInfoAMD) vkGetDeviceProcAddr(dev, "vkGetShaderInfoAMD");
    return f;
}
                                                                                              
inline VkPipelineCreateFlags createFlags(VkDevice dev)
{
    const Fns f = fns(dev);
    return f.props && f.stats && f.reprs ? (VK_PIPELINE_CREATE_CAPTURE_STATISTICS_BIT_KHR | VK_PIPELINE_CREATE_CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR) : 0;
}
inline std::string safeName(const char* name)
{
    std::string s = name && name[0] ? name : "pipeline";
    for (char& c : s)
        if (!(isalnum((unsigned char) c) || c == '_' || c == '-')) c = '_';
    return s;
}
inline std::string csvQuote(const char* s)
{
    std::string r = "\"";
    for (; s && *s; ++s) { if (*s == '"') r += '"'; r += *s; }
    return r + "\"";
}
inline void dump(VkDevice dev, VkPipeline pipe, const char* name)
{
    const char* dir = dumpDir();
    if (!dir || pipe == VK_NULL_HANDLE) return;
    const Fns f = fns(dev);
    if (!(f.props && f.stats) && !f.amd) return;
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);
    static int index = 0;
    _mkdir(dir);
    const std::string base = std::string(dir) + "\\" + (index < 10 ? "0" : "") + std::to_string(index) + "_" + safeName(name);
    ++index;
    _mkdir(base.c_str());
    const std::string summaryPath = std::string(dir) + "\\summary.csv";
    FILE* summary = fopen(summaryPath.c_str(), "a+");
    if (summary)
    {
        fseek(summary, 0, SEEK_END);
        if (ftell(summary) == 0)
            fprintf(summary, "pipeline,executable,subgroup_size,statistic,value\n");
    }
    if (f.props && f.stats)
    {
        VkPipelineInfoKHR info = {VK_STRUCTURE_TYPE_PIPELINE_INFO_KHR, nullptr, pipe};
        uint32_t count = 0;
        if (f.props(dev, &info, &count, nullptr) == VK_SUCCESS && count)
        {
            std::vector<VkPipelineExecutablePropertiesKHR> ep(count, {VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_PROPERTIES_KHR});
            f.props(dev, &info, &count, ep.data());
            FILE* csv = fopen((base + "\\statistics.csv").c_str(), "w");
            if (csv) fprintf(csv, "executable,subgroup_size,name,value,description\n");
            for (uint32_t i = 0; i < count; ++i)
            {
                VkPipelineExecutableInfoKHR ei = {VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INFO_KHR, nullptr, pipe, i};
                uint32_t sc = 0;
                if (f.stats(dev, &ei, &sc, nullptr) != VK_SUCCESS) continue;
                std::vector<VkPipelineExecutableStatisticKHR> st(sc, {VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_STATISTIC_KHR});
                f.stats(dev, &ei, &sc, st.data());
                for (auto& s : st)
                {
                    char value[64];
                    switch (s.format)
                    {
                    case VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_BOOL32_KHR: snprintf(value, sizeof(value), "%u", s.value.b32); break;
                    case VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_INT64_KHR: snprintf(value, sizeof(value), "%lld", (long long) s.value.i64); break;
                    case VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_UINT64_KHR: snprintf(value, sizeof(value), "%llu", (unsigned long long) s.value.u64); break;
                    default: snprintf(value, sizeof(value), "%g", s.value.f64);
                    }
                    if (csv) fprintf(csv, "%s,%u,%s,%s,%s\n", csvQuote(ep[i].name).c_str(), ep[i].subgroupSize, csvQuote(s.name).c_str(), value, csvQuote(s.description).c_str());
                    if (summary) fprintf(summary, "%s,%s,%u,%s,%s\n", csvQuote(name).c_str(), csvQuote(ep[i].name).c_str(), ep[i].subgroupSize, csvQuote(s.name).c_str(), value);
                }
                if (!f.reprs) continue;
                uint32_t rc = 0;
                if (f.reprs(dev, &ei, &rc, nullptr) != VK_SUCCESS || !rc) continue;
                std::vector<VkPipelineExecutableInternalRepresentationKHR> ir(rc, {VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INTERNAL_REPRESENTATION_KHR});
                f.reprs(dev, &ei, &rc, ir.data());
                std::vector<std::vector<char>> buffers(rc);
                for (uint32_t j = 0; j < rc; ++j) { buffers[j].resize(ir[j].dataSize); ir[j].pData = buffers[j].data(); }
                if (f.reprs(dev, &ei, &rc, ir.data()) != VK_SUCCESS) continue;
                for (uint32_t j = 0; j < rc; ++j)
                {
                    const std::string p = base + "\\executable_" + std::to_string(i) + "_" + safeName(ir[j].name) + (ir[j].isText ? ".txt" : ".bin");
                    if (FILE* o = fopen(p.c_str(), "wb")) { fwrite(buffers[j].data(), 1, ir[j].dataSize, o); fclose(o); }
                }
            }
            if (csv) fclose(csv);
        }
    }
    if (f.amd)
    {
        size_t size = 0;
        if (f.amd(dev, pipe, VK_SHADER_STAGE_COMPUTE_BIT, VK_SHADER_INFO_TYPE_DISASSEMBLY_AMD, &size, nullptr) == VK_SUCCESS && size)
        {
            std::vector<char> text(size);
            if (f.amd(dev, pipe, VK_SHADER_STAGE_COMPUTE_BIT, VK_SHADER_INFO_TYPE_DISASSEMBLY_AMD, &size, text.data()) == VK_SUCCESS)
                if (FILE* o = fopen((base + "\\amd_isa.txt").c_str(), "wb")) { fwrite(text.data(), 1, size, o); fclose(o); }
        }
        VkShaderStatisticsInfoAMD st = {};
        size = sizeof(st);
        if (f.amd(dev, pipe, VK_SHADER_STAGE_COMPUTE_BIT, VK_SHADER_INFO_TYPE_STATISTICS_AMD, &size, &st) == VK_SUCCESS)
        {
            if (FILE* o = fopen((base + "\\amd_statistics.txt").c_str(), "w"))
            {
                fprintf(o, "VGPR=%u\nSGPR=%u\nLDS_bytes=%u\nscratch_bytes=%zu\navailableVGPR=%u\navailableSGPR=%u\n", st.resourceUsage.numUsedVgprs,
                        st.resourceUsage.numUsedSgprs, st.resourceUsage.ldsUsageSizeInBytes, st.resourceUsage.scratchMemUsageInBytes,
                        st.numAvailableVgprs, st.numAvailableSgprs);
                fclose(o);
            }
            if (summary)
            {
                fprintf(summary, "%s,\"AMD\",0,\"AMD VGPR\",%u\n", csvQuote(name).c_str(), st.resourceUsage.numUsedVgprs);
                fprintf(summary, "%s,\"AMD\",0,\"AMD SGPR\",%u\n", csvQuote(name).c_str(), st.resourceUsage.numUsedSgprs);
                fprintf(summary, "%s,\"AMD\",0,\"AMD LDS bytes\",%u\n", csvQuote(name).c_str(), st.resourceUsage.ldsUsageSizeInBytes);
                fprintf(summary, "%s,\"AMD\",0,\"AMD scratch bytes\",%zu\n", csvQuote(name).c_str(), st.resourceUsage.scratchMemUsageInBytes);
            }
        }
    }
    if (summary) fclose(summary);
}
}                       
