                                              
#include "pipeline_cache.hpp"
#include "vkml_of_shaders_spv.hpp"
#include <numeric>
#include <stdexcept>

namespace mlsdk::el::compute {
PipelineCache::PipelineCache(const void*, size_t, VkPipelineCache cache) : pipelineCache(cache) {}

SpirvBinary PipelineCache::lookup(std::string_view shaderName, const KeyList& keys, const ReplaceList&) {
    const auto key = makeKey(shaderName, keys);
    const auto it = precompiledSpirvModules.find(key);
    if (it == precompiledSpirvModules.end())
        throw std::runtime_error("Missing embedded VKML OF shader: " + key);
    const auto [data, size] = it->second;
    return {data, size};
}

VkPipelineCache PipelineCache::getPipelineCache() const { return pipelineCache; }

std::string PipelineCache::makeKey(std::string_view shaderName, const KeyList& keys) {
    return std::accumulate(keys.begin(), keys.end(), std::string(shaderName),
        [](const std::string& acc, std::string_view key) { return acc + '_' + std::string(key); });
}

std::vector<uint32_t> PipelineCache::replaceCompileGlsl(std::string_view, const ReplaceList&) {
    throw std::runtime_error("Runtime GLSL compilation is disabled for embedded VKML OF");
}
}                                
