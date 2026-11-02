#pragma once

#include <vulkan/vulkan.h>

#include <cstdint>
#include <memory>
#include <string>

struct EmbeddedOfBinding
{
    uint32_t set = 0;
    uint32_t binding = 0;
    VkImageLayout layout = VK_IMAGE_LAYOUT_UNDEFINED;
};

enum class EmbeddedOfPerformance : uint32_t
{
    Medium,
    Fast,
    Slow,
    Unknown,
};

struct EmbeddedOpticalFlowConfig
{
    uint32_t width = 0;
    uint32_t height = 0;
    uint32_t lastEstimationLevel = 2;
    bool useHint = false;
    bool outputCost = false;
    EmbeddedOfPerformance performance = EmbeddedOfPerformance::Medium;
    int maxSearchRange = 3;
    VkFormat imageFormat = VK_FORMAT_UNDEFINED;
    VkFormat flowFormat = VK_FORMAT_UNDEFINED;
    VkFormat costFormat = VK_FORMAT_R16_UINT;
    EmbeddedOfBinding reference;
    EmbeddedOfBinding input;
    EmbeddedOfBinding hint;
    EmbeddedOfBinding flow;
    EmbeddedOfBinding cost;
};

struct EmbeddedOfImage
{
    uint32_t set = 0;
    uint32_t binding = 0;
    VkImageView view = VK_NULL_HANDLE;
};

class EmbeddedOpticalFlow
{
  public:
    static std::unique_ptr<EmbeddedOpticalFlow> create(
        VkInstance instance,
        VkPhysicalDevice physicalDevice,
        VkDevice device,
        PFN_vkGetInstanceProcAddr getInstanceProcAddr,
        PFN_vkGetDeviceProcAddr getDeviceProcAddr,
        const EmbeddedOpticalFlowConfig& config,
        std::string& error);

    ~EmbeddedOpticalFlow();

    bool dispatch(
        VkCommandBuffer commandBuffer,
        const EmbeddedOfImage* images,
        uint32_t imageCount,
        VkDataGraphOpticalFlowExecuteFlagsARM flags,
        uint32_t meanFlowL1NormHint,
        std::string& error);

    EmbeddedOpticalFlow(const EmbeddedOpticalFlow&) = delete;
    EmbeddedOpticalFlow& operator=(const EmbeddedOpticalFlow&) = delete;

  private:
    EmbeddedOpticalFlow() = default;
    bool initialize(
        VkInstance instance,
        VkPhysicalDevice physicalDevice,
        VkDevice device,
        PFN_vkGetInstanceProcAddr getInstanceProcAddr,
        PFN_vkGetDeviceProcAddr getDeviceProcAddr,
        const EmbeddedOpticalFlowConfig& config,
        std::string& error);
    bool allocateAndBind(const VkMemoryRequirements& requirements, bool cache, std::string& error);

    struct Impl;
    std::unique_ptr<Impl> impl_;
};
