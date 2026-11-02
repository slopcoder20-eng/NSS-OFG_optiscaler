#pragma once
#include <memory>
#include <string>
#include <string_view>
#include <vector>
#include <vulkan/vulkan.hpp>

namespace mlsdk::el::utils {
template <typename T> T roundUp(const T data, size_t multiple) {
    return static_cast<T>(((data + multiple - 1) / multiple) * multiple);
}
inline uint32_t divideRoundUp(uint32_t value, uint32_t divide) { return (value + divide - 1) / divide; }
inline void replaceAll(std::string& str, std::string_view pattern, std::string_view replacement) {
    if (pattern.empty()) return;
    for (size_t pos = str.find(pattern.data(), 0, pattern.size()); pos != std::string::npos;
         pos = str.find(pattern.data(), pos, pattern.size())) {
        str.replace(pos, pattern.size(), replacement.data(), replacement.size());
        pos += replacement.size();
    }
}
template <typename T> class Span {
    const T* data_;
    size_t size_;
  public:
    Span(const T* data, size_t size) : data_(data), size_(size) {}
    const T* data() const { return data_; }
    size_t size() const { return size_; }
};
inline void setDebugUtilsObjectName(
    const std::shared_ptr<VULKAN_HPP_NAMESPACE::detail::DispatchLoaderDynamic>&,
    VkDevice, VkObjectType, uint64_t, const std::string&) {}
}                              
