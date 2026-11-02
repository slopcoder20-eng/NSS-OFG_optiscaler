#include "embedded_optical_flow.h"

#include "optical_flow.hpp"
#include "pipeline_cache.hpp"

#include <map>
#include <stdexcept>
#include <tuple>

using mlsdk::el::compute::PipelineCache;
using mlsdk::el::compute::optical_flow::OpticalFlow;
using mlsdk::el::compute::optical_flow::OpticalFlowDescriptorMap;

struct EmbeddedOpticalFlow::Impl
{
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    std::shared_ptr<vk::detail::DispatchLoaderDynamic> loader;
    std::shared_ptr<PipelineCache> pipelineCache;
    std::unique_ptr<OpticalFlow> flow;
    VkDeviceMemory cacheMemory = VK_NULL_HANDLE;
    VkDeviceMemory transientMemory = VK_NULL_HANDLE;
};

std::unique_ptr<EmbeddedOpticalFlow> EmbeddedOpticalFlow::create(
    VkInstance instance,
    VkPhysicalDevice physicalDevice,
    VkDevice device,
    PFN_vkGetInstanceProcAddr getInstanceProcAddr,
    PFN_vkGetDeviceProcAddr getDeviceProcAddr,
    const EmbeddedOpticalFlowConfig& config,
    std::string& error)
{
    auto result = std::unique_ptr<EmbeddedOpticalFlow>(new EmbeddedOpticalFlow());
    if (!result->initialize(instance, physicalDevice, device, getInstanceProcAddr, getDeviceProcAddr, config, error))
        return {};
    return result;
}

EmbeddedOpticalFlow::~EmbeddedOpticalFlow()
{
    if (!impl_)
        return;
    impl_->flow.reset();
    impl_->pipelineCache.reset();
    if (impl_->cacheMemory != VK_NULL_HANDLE)
        impl_->loader->vkFreeMemory(impl_->device, impl_->cacheMemory, nullptr);
    if (impl_->transientMemory != VK_NULL_HANDLE)
        impl_->loader->vkFreeMemory(impl_->device, impl_->transientMemory, nullptr);
}

bool EmbeddedOpticalFlow::initialize(
    VkInstance instance,
    VkPhysicalDevice physicalDevice,
    VkDevice device,
    PFN_vkGetInstanceProcAddr getInstanceProcAddr,
    PFN_vkGetDeviceProcAddr getDeviceProcAddr,
    const EmbeddedOpticalFlowConfig& config,
    std::string& error)
{
    try
    {
        impl_ = std::make_unique<Impl>();
        impl_->physicalDevice = physicalDevice;
        impl_->device = device;
        impl_->loader = std::make_shared<vk::detail::DispatchLoaderDynamic>(
            instance, getInstanceProcAddr, device, getDeviceProcAddr);
        impl_->pipelineCache = std::make_shared<PipelineCache>(nullptr, 0, VK_NULL_HANDLE);

        OpticalFlow::Config vkml{};
        vkml.width = config.width;
        vkml.height = config.height;
        vkml.levelOfLastEstimation = config.lastEstimationLevel;
        vkml.useMvInput = config.useHint;
        vkml.outputCost = config.outputCost;
        vkml.maxSearchRange = config.maxSearchRange;
        vkml.imageFormat = config.imageFormat;
        vkml.flowFormat = config.flowFormat;
        vkml.costFormat = config.costFormat;
        switch (config.performance)
        {
        case EmbeddedOfPerformance::Fast: vkml.performanceLevel = OpticalFlow::PerformanceLevel::FAST; break;
        case EmbeddedOfPerformance::Slow: vkml.performanceLevel = OpticalFlow::PerformanceLevel::SLOW; break;
        case EmbeddedOfPerformance::Unknown: vkml.performanceLevel = OpticalFlow::PerformanceLevel::UNKNOWN; break;
        default: vkml.performanceLevel = OpticalFlow::PerformanceLevel::MEDIUM; break;
        }
        auto convert = [](const EmbeddedOfBinding& in) {
            return OpticalFlow::Config::InputImage{in.binding, in.set, in.layout};
        };
        vkml.srcSearch = convert(config.reference);
        vkml.srcTemplate = convert(config.input);
        vkml.srcFlow = convert(config.hint);
        vkml.dstFlow = convert(config.flow);
        vkml.dstCost = convert(config.cost);

        impl_->flow = std::make_unique<OpticalFlow>(impl_->loader, physicalDevice, device, impl_->pipelineCache);
        impl_->flow->init(vkml);
        if (!allocateAndBind(impl_->flow->getCacheMemoryRequirements(), true, error))
            return false;
        if (!allocateAndBind(impl_->flow->getTransientMemoryRequirements(), false, error))
            return false;
        return true;
    }
    catch (const std::exception& e)
    {
        error = e.what();
        return false;
    }
}

bool EmbeddedOpticalFlow::allocateAndBind(const VkMemoryRequirements& requirements, bool cache, std::string& error)
{
    if (requirements.size == 0)
        return true;
    VkPhysicalDeviceMemoryProperties properties{};
    impl_->loader->vkGetPhysicalDeviceMemoryProperties(impl_->physicalDevice, &properties);
    uint32_t typeIndex = UINT32_MAX;
    for (uint32_t i = 0; i < properties.memoryTypeCount; ++i)
    {
        if ((requirements.memoryTypeBits & (1u << i)) &&
            (properties.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
        {
            typeIndex = i;
            break;
        }
    }
    if (typeIndex == UINT32_MAX)
    {
        error = "No compatible device-local memory type for embedded VKML OF";
        return false;
    }
    VkMemoryAllocateInfo info{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    info.allocationSize = requirements.size;
    info.memoryTypeIndex = typeIndex;
    VkDeviceMemory& memory = cache ? impl_->cacheMemory : impl_->transientMemory;
    if (impl_->loader->vkAllocateMemory(impl_->device, &info, nullptr, &memory) != VK_SUCCESS)
    {
        error = "Failed to allocate embedded VKML OF session memory";
        return false;
    }
    try
    {
        if (cache)
            impl_->flow->bindSessionCacheMemory(memory, 0);
        else
            impl_->flow->bindSessionTransientMemory(memory, 0);
    }
    catch (const std::exception& e)
    {
        error = e.what();
        return false;
    }
    return true;
}

bool EmbeddedOpticalFlow::dispatch(
    VkCommandBuffer commandBuffer,
    const EmbeddedOfImage* images,
    uint32_t imageCount,
    VkDataGraphOpticalFlowExecuteFlagsARM flags,
    uint32_t meanFlowL1NormHint,
    std::string& error)
{
    try
    {
        OpticalFlowDescriptorMap descriptors;
        for (uint32_t i = 0; i < imageCount; ++i)
            descriptors[{images[i].set, images[i].binding, 0}] = {VK_NULL_HANDLE, images[i].view};
        impl_->flow->updateDescriptorSets(descriptors);
        impl_->flow->cmdBindAndDispatch(commandBuffer, flags, meanFlowL1NormHint);
        return true;
    }
    catch (const std::exception& e)
    {
        error = e.what();
        return false;
    }
}
