#pragma once

                                                                                 
                                                                           
                                                                               
                                                                               
                                                                         
                                                                              
#include <vulkan/vulkan.h>
#include <algorithm>
#include <atomic>
#include <cstring>
#include <memory>
#include <mutex>
#include <optional>
#include <unordered_map>
#include <vector>

namespace NfruAsyncVk
{
struct Reservation { uint32_t family, index; };
using Plan = std::vector<Reservation>;
struct Queue
{
    VkQueue handle = VK_NULL_HANDLE;
    uint32_t family = 0;
    std::mutex submitMutex;
};
inline std::mutex registryMutex;
inline std::unordered_map<VkDevice, std::unordered_map<uint32_t, std::shared_ptr<Queue>>> queues;
inline std::atomic_bool hasQueues{false};

inline Plan Reserve(VkPhysicalDevice pd, VkDeviceCreateInfo& ci, bool enabled,
                    std::vector<VkDeviceQueueCreateInfo>& storage,
                    std::vector<std::vector<float>>& priorities)
{
    Plan plan;
    if (!enabled) return plan;
    for (auto p = reinterpret_cast<const VkBaseInStructure*>(ci.pNext); p; p = p->pNext)
    {
        if (p->sType == VK_STRUCTURE_TYPE_DEVICE_GROUP_DEVICE_CREATE_INFO &&
            reinterpret_cast<const VkDeviceGroupDeviceCreateInfo*>(p)->physicalDeviceCount != 1)
            return plan;
                                                                                  
        if (p->sType == VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT &&
            reinterpret_cast<const VkPhysicalDeviceDescriptorBufferFeaturesEXT*>(p)->descriptorBuffer)
            return plan;
        if (p->sType == VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT &&
            reinterpret_cast<const VkPhysicalDeviceShaderObjectFeaturesEXT*>(p)->shaderObject)
            return plan;
    }
    uint32_t count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &count, nullptr);
    std::vector<VkQueueFamilyProperties> props(count);
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &count, props.data());
    storage.assign(ci.pQueueCreateInfos, ci.pQueueCreateInfos + ci.queueCreateInfoCount);
    priorities.resize(storage.size());
    for (size_t i = 0; i < storage.size(); ++i)
    {
        auto& q = storage[i];
        priorities[i].assign(q.pQueuePriorities, q.pQueuePriorities + q.queueCount);
        bool protectedFamily = false;
        for (const auto& other : storage)
            protectedFamily |= other.queueFamilyIndex == q.queueFamilyIndex && other.flags != 0;
        if (!protectedFamily && q.queueFamilyIndex < count &&
            (props[q.queueFamilyIndex].queueFlags & VK_QUEUE_COMPUTE_BIT) &&
            q.queueCount < props[q.queueFamilyIndex].queueCount)
        {
            plan.push_back({q.queueFamilyIndex, q.queueCount++});
            priorities[i].push_back(1.0f);
        }
        q.pQueuePriorities = priorities[i].data();
    }
    ci.pQueueCreateInfos = storage.data();
    return plan;
}

inline void Register(VkDevice device, const Plan& plan)
{
    std::lock_guard lock(registryMutex);
    auto& dst = queues[device];
    for (auto p : plan)
    {
        auto queue = std::make_shared<Queue>();
        queue->family = p.family;
        vkGetDeviceQueue(device, p.family, p.index, &queue->handle);
        if (queue->handle) dst[p.family] = std::move(queue);
    }
    hasQueues = std::any_of(queues.begin(), queues.end(), [](const auto& p) { return !p.second.empty(); });
}

struct Frame
{
    VkDevice device = VK_NULL_HANDLE;
    std::shared_ptr<Queue> queue;
    VkCommandPool pool = VK_NULL_HANDLE;
    VkCommandBuffer work = VK_NULL_HANDLE, continuation = VK_NULL_HANDLE, source = VK_NULL_HANDLE;
    VkSemaphore ready = VK_NULL_HANDLE, done = VK_NULL_HANDLE;
    VkFence completion = VK_NULL_HANDLE;
    uint64_t recordOrder = 0;
    std::atomic_bool submitted{false}, retired{false}, failed{false};
    std::atomic_bool actualAsync{false};
    std::mutex mutex;

    bool Wait()
    {
        if (failed) return false;
        return !submitted || vkWaitForFences(device, 1, &completion, VK_TRUE, UINT64_MAX) == VK_SUCCESS;
    }
    void Release()
    {
        if (!device) return;
                                                                               
                                                                           
        if (submitted && !failed) Wait();
        if (failed) vkDeviceWaitIdle(device);                                            
        if (completion) vkDestroyFence(device, completion, nullptr);
        if (ready) vkDestroySemaphore(device, ready, nullptr);
        if (done) vkDestroySemaphore(device, done, nullptr);
        if (pool) vkDestroyCommandPool(device, pool, nullptr);
        completion = VK_NULL_HANDLE; ready = done = VK_NULL_HANDLE;
        pool = VK_NULL_HANDLE; work = continuation = VK_NULL_HANDLE; device = VK_NULL_HANDLE;
    }
    ~Frame() { Release(); }
};
inline std::unordered_map<VkCommandBuffer, std::shared_ptr<Frame>> pending;
inline std::vector<std::weak_ptr<Frame>> allFrames;

inline void BeforeDestroyDevice(VkDevice device)
{
    std::vector<std::shared_ptr<Frame>> frames;
    {
        std::lock_guard lock(registryMutex);
        for (auto& weak : allFrames) if (auto f = weak.lock()) if (f->device == device) frames.push_back(f);
        for (auto it = pending.begin(); it != pending.end();)
            if (it->second->device == device) it = pending.erase(it); else ++it;
        queues.erase(device);
        hasQueues = std::any_of(queues.begin(), queues.end(), [](const auto& p) { return !p.second.empty(); });
    }
    if (!frames.empty()) vkDeviceWaitIdle(device);                        
    for (auto& f : frames) { std::lock_guard lock(f->mutex); f->Release(); }
}

inline void Forget(VkCommandBuffer source)
{
    std::shared_ptr<Frame> frame;
    {
        std::lock_guard lock(registryMutex);
        auto it = pending.find(source);
        if (it == pending.end()) return;
        frame = it->second;
        pending.erase(it);
    }
    std::lock_guard lock(frame->mutex);
    frame->retired = true;
}

inline std::shared_ptr<Frame> Find(VkCommandBuffer source)
{
    std::lock_guard lock(registryMutex);
    auto it = pending.find(source);
    return it == pending.end() ? nullptr : it->second;
}

class Context
{
                                                                                
    std::vector<std::shared_ptr<Frame>> frames;
    uint64_t nextOrder = 0;
  public:
    bool BeforeRecord()
    {
                                                                            
                                                                              
                                                                        
        if (frames.size() < 3) return true;
        std::shared_ptr<Frame> oldest;
        for (auto& f : frames)
        {
            if (f->failed) return false;
            if (f->retired && (!f->submitted || vkGetFenceStatus(f->device, f->completion) == VK_SUCCESS)) return true;
            if (f->submitted && (!oldest || f->recordOrder < oldest->recordOrder)) oldest = f;
        }
                                                                              
                                                                       
        if (!oldest) return false;
        { std::lock_guard lock(oldest->mutex); if (!oldest->Wait()) return false; }
        Forget(oldest->source);
        return true;
    }
    bool Drain()
    {
                                                                                
                                                                           
        for (auto& f : frames)
        {
            if (f->retired && !f->submitted) continue;
            if (!f->submitted || f->failed) return false;
            { std::lock_guard lock(f->mutex); if (!f->Wait()) return false; }
            Forget(f->source);
        }
        return true;
    }
    void Abandon()
    {
                                                                                
                                                                                    
        for (auto& f : frames) f->device = VK_NULL_HANDLE;
    }
    ~Context()
    {
        for (auto& f : frames) if (f->source) Forget(f->source);
        frames.clear();
    }
    std::shared_ptr<Frame> Begin(VkDevice device, uint32_t family, VkCommandBuffer source)
    {
        if (!BeforeRecord()) return nullptr;
        std::shared_ptr<Queue> queue;
        {
            std::lock_guard lock(registryMutex);
            auto d = queues.find(device);
            if (d == queues.end()) return nullptr;
            auto q = d->second.find(family);
            if (q == d->second.end() || pending.count(source)) return nullptr;
            queue = q->second;
        }
        std::shared_ptr<Frame> f;
        for (auto& slot : frames)
            if (slot->queue == queue && slot->retired && (!slot->submitted ||
                vkGetFenceStatus(device, slot->completion) == VK_SUCCESS)) { f = slot; break; }
        if (!f && frames.size() < 3)
        {
            f = std::make_shared<Frame>(); f->device = device; f->queue = queue;
            VkCommandPoolCreateInfo pi{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
            pi.queueFamilyIndex = family; pi.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
            if (vkCreateCommandPool(device, &pi, nullptr, &f->pool) != VK_SUCCESS) return nullptr;
            VkCommandBufferAllocateInfo ai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
            ai.commandPool = f->pool; ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; ai.commandBufferCount = 2;
            VkCommandBuffer cb[2];
            if (vkAllocateCommandBuffers(device, &ai, cb) != VK_SUCCESS) return nullptr;
            f->work = cb[0]; f->continuation = cb[1];
            VkSemaphoreCreateInfo si{VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
            VkFenceCreateInfo fi{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
            if (vkCreateSemaphore(device, &si, nullptr, &f->ready) != VK_SUCCESS ||
                vkCreateSemaphore(device, &si, nullptr, &f->done) != VK_SUCCESS ||
                vkCreateFence(device, &fi, nullptr, &f->completion) != VK_SUCCESS) return nullptr;
            frames.push_back(f);
            { std::lock_guard registryLock(registryMutex);
              std::erase_if(allFrames, [](const auto& weak) { return weak.expired(); });
              allFrames.push_back(f); }
        }
        if (!f) return nullptr;                                                      
        std::lock_guard lock(f->mutex);
        if (!f->Wait() || vkResetCommandPool(device, f->pool, 0) != VK_SUCCESS) return nullptr;
        f->source = source; f->submitted = false; f->retired = false; f->actualAsync = false;
        f->recordOrder = ++nextOrder;
        VkCommandBufferBeginInfo bi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        if (vkBeginCommandBuffer(f->work, &bi) != VK_SUCCESS ||
            vkBeginCommandBuffer(f->continuation, &bi) != VK_SUCCESS) { f->retired = true; return nullptr; }
                                                                                
        VkMemoryBarrier mb{VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
        vkCmdPipelineBarrier(f->work, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             0, 1, &mb, 0, nullptr, 0, nullptr);
        vkCmdPipelineBarrier(f->continuation, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             0, 1, &mb, 0, nullptr, 0, nullptr);
        return f;
    }
};

inline bool Publish(const std::shared_ptr<Frame>& f)
{
    if (vkEndCommandBuffer(f->work) != VK_SUCCESS) { f->retired = true; return false; }
    std::lock_guard lock(registryMutex);
    if (pending.count(f->source)) { f->retired = true; return false; }
    pending[f->source] = f;
    return true;
}

inline bool TimelineOnly(const void* pNext)
{
    auto p = reinterpret_cast<const VkBaseInStructure*>(pNext);
    return !p || (p->sType == VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO && !p->pNext);
}

struct SubmissionChain
{
    std::vector<std::unique_ptr<unsigned char[]>> nodes;
    const void* head = nullptr;
    bool CopyWithMasks(const void* chain, const std::vector<uint32_t>& masks)
    {
        VkBaseOutStructure* previous = nullptr;
        for (auto p = reinterpret_cast<const VkBaseInStructure*>(chain); p; p = p->pNext)
        {
            size_t size = 0;
            switch (p->sType)
            {
            case VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO: size = sizeof(VkTimelineSemaphoreSubmitInfo); break;
            case VK_STRUCTURE_TYPE_DEVICE_GROUP_SUBMIT_INFO: size = sizeof(VkDeviceGroupSubmitInfo); break;
            case VK_STRUCTURE_TYPE_PROTECTED_SUBMIT_INFO: size = sizeof(VkProtectedSubmitInfo); break;
            case VK_STRUCTURE_TYPE_PERFORMANCE_QUERY_SUBMIT_INFO_KHR: size = sizeof(VkPerformanceQuerySubmitInfoKHR); break;
#ifdef VK_EXT_frame_boundary
            case VK_STRUCTURE_TYPE_FRAME_BOUNDARY_EXT: size = sizeof(VkFrameBoundaryEXT); break;
#endif
#ifdef VK_NV_low_latency2
            case VK_STRUCTURE_TYPE_LATENCY_SUBMISSION_PRESENT_ID_NV: size = sizeof(VkLatencySubmissionPresentIdNV); break;
#endif
#ifdef VK_USE_PLATFORM_WIN32_KHR
            case VK_STRUCTURE_TYPE_D3D12_FENCE_SUBMIT_INFO_KHR: size = sizeof(VkD3D12FenceSubmitInfoKHR); break;
            case VK_STRUCTURE_TYPE_WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_KHR: size = sizeof(VkWin32KeyedMutexAcquireReleaseInfoKHR); break;
            case VK_STRUCTURE_TYPE_WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_NV: size = sizeof(VkWin32KeyedMutexAcquireReleaseInfoNV); break;
#endif
            default: return false;                                                                         
            }
            auto data = std::make_unique<unsigned char[]>(size);
            std::memcpy(data.get(), p, size);
            auto copy = reinterpret_cast<VkBaseOutStructure*>(data.get()); copy->pNext = nullptr;
            if (p->sType == VK_STRUCTURE_TYPE_DEVICE_GROUP_SUBMIT_INFO)
            {
                auto group = reinterpret_cast<VkDeviceGroupSubmitInfo*>(copy);
                group->commandBufferCount = uint32_t(masks.size());
                group->pCommandBufferDeviceMasks = masks.data();
            }
            if (previous) previous->pNext = copy; else head = copy;
            previous = copy; nodes.push_back(std::move(data));
        }
        return true;
    }
};

                                                                            
                                                                                 
template<class Submit>
inline VkResult Retire(const std::shared_ptr<Frame>& f, Submit submit)
{
    auto r = vkResetFences(f->device, 1, &f->completion);
    if (r == VK_SUCCESS) r = submit(f->completion);
    f->submitted = r == VK_SUCCESS;
    f->failed = r != VK_SUCCESS;
    return r;
}

inline std::optional<VkResult> Submit(VkQueue queue, uint32_t count, const VkSubmitInfo* infos,
                                    VkFence fence, PFN_vkQueueSubmit original)
{
    bool found = false;
    for (uint32_t i = 0; i < count; ++i)
        for (uint32_t j = 0; j < infos[i].commandBufferCount; ++j)
            found |= bool(Find(infos[i].pCommandBuffers[j]));
    if (!found) return std::nullopt;
    for (uint32_t i = 0; i < count; ++i)
    {
        const auto& in = infos[i];
        std::vector<std::shared_ptr<Frame>> jobs;
        for (uint32_t j = 0; j < in.commandBufferCount; ++j)
            if (auto f = Find(in.pCommandBuffers[j])) jobs.push_back(f);
        if (jobs.empty())
        {
            auto r = original(queue, 1, &in, i + 1 == count ? fence : VK_NULL_HANDLE);
            if (r != VK_SUCCESS) return r;
            continue;
        }
                                                                                 
                                                                         
        if (!TimelineOnly(in.pNext) || queue == jobs.front()->queue->handle)
        {
            std::vector<VkCommandBuffer> cb;
            std::vector<uint32_t> masks;
            const VkDeviceGroupSubmitInfo* group = nullptr;
            for (auto p = reinterpret_cast<const VkBaseInStructure*>(in.pNext); p; p = p->pNext)
                if (p->sType == VK_STRUCTURE_TYPE_DEVICE_GROUP_SUBMIT_INFO)
                    group = reinterpret_cast<const VkDeviceGroupSubmitInfo*>(p);
            for (uint32_t j = 0; j < in.commandBufferCount; ++j)
            {
                auto f = Find(in.pCommandBuffers[j]);
                cb.push_back(in.pCommandBuffers[j]);
                if (group) masks.push_back(group->pCommandBufferDeviceMasks[j]);
                if (f)
                {
                    if (f->submitted) return VK_ERROR_VALIDATION_FAILED_EXT;
                    cb.push_back(f->work); cb.push_back(f->continuation);
                    if (group) { masks.push_back(1); masks.push_back(1); }
                }
            }
            VkSubmitInfo copy = in; copy.commandBufferCount = uint32_t(cb.size()); copy.pCommandBuffers = cb.data();
            SubmissionChain chain;
            if (group) { if (!chain.CopyWithMasks(in.pNext, masks)) return VK_ERROR_FEATURE_NOT_PRESENT;
                         copy.pNext = chain.head; }
            auto r = original(queue, 1, &copy, i + 1 == count ? fence : VK_NULL_HANDLE);
            if (r != VK_SUCCESS) { for (auto& f : jobs) f->failed = true; return r; }
            for (auto& f : jobs)
            {
                VkSubmitInfo empty{VK_STRUCTURE_TYPE_SUBMIT_INFO};
                r = Retire(f, [&](VkFence done) { return original(queue, 1, &empty, done); });
                if (r != VK_SUCCESS) return r;
            }
            continue;
        }
        const auto* timeline = reinterpret_cast<const VkTimelineSemaphoreSubmitInfo*>(in.pNext);
        uint32_t start = 0;
        for (uint32_t j = 0; j < in.commandBufferCount; ++j)
        {
            auto f = Find(in.pCommandBuffers[j]);
            if (!f) continue;
            std::lock_guard frameLock(f->mutex);
            if (f->submitted) return VK_ERROR_VALIDATION_FAILED_EXT;
            const uint64_t zero = 0;
            VkTimelineSemaphoreSubmitInfo pt{VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO};
            VkSubmitInfo prefix{VK_STRUCTURE_TYPE_SUBMIT_INFO};
            prefix.commandBufferCount = j + 1 - start; prefix.pCommandBuffers = in.pCommandBuffers + start;
            if (start == 0) { prefix.waitSemaphoreCount = in.waitSemaphoreCount; prefix.pWaitSemaphores = in.pWaitSemaphores;
                             prefix.pWaitDstStageMask = in.pWaitDstStageMask; }
            prefix.signalSemaphoreCount = 1; prefix.pSignalSemaphores = &f->ready;
            if (timeline) { pt.waitSemaphoreValueCount = prefix.waitSemaphoreCount;
                pt.pWaitSemaphoreValues = timeline->pWaitSemaphoreValues;
                pt.signalSemaphoreValueCount = 1; pt.pSignalSemaphoreValues = &zero; prefix.pNext = &pt; }
            auto r = original(queue, 1, &prefix, VK_NULL_HANDLE);
            if (r != VK_SUCCESS) { f->failed = true; return r; }
            VkPipelineStageFlags stage = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT;
            VkSubmitInfo work{VK_STRUCTURE_TYPE_SUBMIT_INFO};
            work.waitSemaphoreCount = 1; work.pWaitSemaphores = &f->ready; work.pWaitDstStageMask = &stage;
            work.commandBufferCount = 1; work.pCommandBuffers = &f->work;
            work.signalSemaphoreCount = 1; work.pSignalSemaphores = &f->done;
            { std::lock_guard qLock(f->queue->submitMutex); r = original(f->queue->handle, 1, &work, VK_NULL_HANDLE); }
            if (r != VK_SUCCESS) { f->failed = true; return r; }
            f->actualAsync = true;
            uint32_t next = j + 1;
            while (next < in.commandBufferCount && !Find(in.pCommandBuffers[next])) ++next;
            std::vector<VkCommandBuffer> tail{f->continuation};
            tail.insert(tail.end(), in.pCommandBuffers + j + 1, in.pCommandBuffers + next);
            const bool last = next == in.commandBufferCount;
            VkSubmitInfo post{VK_STRUCTURE_TYPE_SUBMIT_INFO};
            post.waitSemaphoreCount = 1; post.pWaitSemaphores = &f->done; post.pWaitDstStageMask = &stage;
            post.commandBufferCount = uint32_t(tail.size()); post.pCommandBuffers = tail.data();
            if (last) { post.signalSemaphoreCount = in.signalSemaphoreCount; post.pSignalSemaphores = in.pSignalSemaphores; }
            VkTimelineSemaphoreSubmitInfo tt{VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO};
            if (timeline) { tt.waitSemaphoreValueCount = 1; tt.pWaitSemaphoreValues = &zero;
                tt.signalSemaphoreValueCount = post.signalSemaphoreCount; tt.pSignalSemaphoreValues = timeline->pSignalSemaphoreValues;
                post.pNext = &tt; }
            r = original(queue, 1, &post, last && i + 1 == count ? fence : VK_NULL_HANDLE);
            if (r != VK_SUCCESS) { f->failed = true; return r; }
            VkSubmitInfo empty{VK_STRUCTURE_TYPE_SUBMIT_INFO};
            r = Retire(f, [&](VkFence done) { return original(queue, 1, &empty, done); });
            if (r != VK_SUCCESS) return r;
            start = next; j = next - 1;
        }
    }
    return VK_SUCCESS;
}

                                                                             
inline std::optional<VkResult> Submit2(VkQueue queue, uint32_t count, const VkSubmitInfo2* infos,
                                     VkFence fence, PFN_vkQueueSubmit2 original)
{
    bool found = false;
    for (uint32_t i = 0; i < count; ++i)
        for (uint32_t j = 0; j < infos[i].commandBufferInfoCount; ++j)
            found |= bool(Find(infos[i].pCommandBufferInfos[j].commandBuffer));
    if (!found) return std::nullopt;
    for (uint32_t i = 0; i < count; ++i)
    {
        auto copy = infos[i];
        bool canAsync = copy.pNext == nullptr && copy.flags == 0;
        bool hasJob = false;
        for (uint32_t j = 0; j < copy.commandBufferInfoCount; ++j)
        {
            const auto& c = copy.pCommandBufferInfos[j];
            canAsync &= c.pNext == nullptr && c.deviceMask <= 1;
            if (auto f = Find(c.commandBuffer)) { hasJob = true; canAsync &= queue != f->queue->handle; }
        }
        if (canAsync && hasJob)
        {
            uint32_t start = 0;
            for (uint32_t j = 0; j < copy.commandBufferInfoCount; ++j)
            {
                auto f = Find(copy.pCommandBufferInfos[j].commandBuffer);
                if (!f) continue;
                std::lock_guard frameLock(f->mutex);
                if (f->submitted) return VK_ERROR_VALIDATION_FAILED_EXT;
                VkSemaphoreSubmitInfo ready{VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO};
                ready.semaphore = f->ready; ready.stageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
                VkSubmitInfo2 prefix{VK_STRUCTURE_TYPE_SUBMIT_INFO_2};
                prefix.commandBufferInfoCount = j + 1 - start;
                prefix.pCommandBufferInfos = copy.pCommandBufferInfos + start;
                if (start == 0) { prefix.waitSemaphoreInfoCount = copy.waitSemaphoreInfoCount;
                                 prefix.pWaitSemaphoreInfos = copy.pWaitSemaphoreInfos; }
                prefix.signalSemaphoreInfoCount = 1; prefix.pSignalSemaphoreInfos = &ready;
                auto r = original(queue, 1, &prefix, VK_NULL_HANDLE);
                if (r != VK_SUCCESS) { f->failed = true; return r; }
                VkSemaphoreSubmitInfo done{VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO};
                done.semaphore = f->done; done.stageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
                VkCommandBufferSubmitInfo workCb{VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO};
                workCb.commandBuffer = f->work; workCb.deviceMask = 1;
                VkSubmitInfo2 work{VK_STRUCTURE_TYPE_SUBMIT_INFO_2};
                work.waitSemaphoreInfoCount = 1; work.pWaitSemaphoreInfos = &ready;
                work.commandBufferInfoCount = 1; work.pCommandBufferInfos = &workCb;
                work.signalSemaphoreInfoCount = 1; work.pSignalSemaphoreInfos = &done;
                { std::lock_guard qLock(f->queue->submitMutex); r = original(f->queue->handle, 1, &work, VK_NULL_HANDLE); }
                if (r != VK_SUCCESS) { f->failed = true; return r; }
                f->actualAsync = true;
                uint32_t next = j + 1;
                while (next < copy.commandBufferInfoCount && !Find(copy.pCommandBufferInfos[next].commandBuffer)) ++next;
                VkCommandBufferSubmitInfo postCb{VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO};
                postCb.commandBuffer = f->continuation; postCb.deviceMask = 1;
                std::vector<VkCommandBufferSubmitInfo> tail{postCb};
                tail.insert(tail.end(), copy.pCommandBufferInfos + j + 1, copy.pCommandBufferInfos + next);
                const bool last = next == copy.commandBufferInfoCount;
                VkSubmitInfo2 post{VK_STRUCTURE_TYPE_SUBMIT_INFO_2};
                post.waitSemaphoreInfoCount = 1; post.pWaitSemaphoreInfos = &done;
                post.commandBufferInfoCount = uint32_t(tail.size()); post.pCommandBufferInfos = tail.data();
                if (last) { post.signalSemaphoreInfoCount = copy.signalSemaphoreInfoCount;
                            post.pSignalSemaphoreInfos = copy.pSignalSemaphoreInfos; }
                r = original(queue, 1, &post, last && i + 1 == count ? fence : VK_NULL_HANDLE);
                if (r != VK_SUCCESS) { f->failed = true; return r; }
                VkSubmitInfo2 empty{VK_STRUCTURE_TYPE_SUBMIT_INFO_2};
                r = Retire(f, [&](VkFence doneFence) { return original(queue, 1, &empty, doneFence); });
                if (r != VK_SUCCESS) return r;
                start = next; j = next - 1;
            }
            continue;
        }
        std::vector<VkCommandBufferSubmitInfo> cb;
        std::vector<std::shared_ptr<Frame>> jobs;
        for (uint32_t j = 0; j < copy.commandBufferInfoCount; ++j)
        {
            auto c = copy.pCommandBufferInfos[j]; cb.push_back(c);
            if (auto f = Find(c.commandBuffer))
            {
                if (f->submitted) return VK_ERROR_VALIDATION_FAILED_EXT;
                c.commandBuffer = f->work; cb.push_back(c);
                c.commandBuffer = f->continuation; cb.push_back(c); jobs.push_back(f);
            }
        }
        copy.commandBufferInfoCount = uint32_t(cb.size()); copy.pCommandBufferInfos = cb.data();
        auto r = original(queue, 1, &copy, i + 1 == count ? fence : VK_NULL_HANDLE);
        if (r != VK_SUCCESS) { for (auto& f : jobs) f->failed = true; return r; }
        for (auto& f : jobs)
        {
            VkSubmitInfo2 empty{VK_STRUCTURE_TYPE_SUBMIT_INFO_2};
            r = Retire(f, [&](VkFence done) { return original(queue, 1, &empty, done); });
            if (r != VK_SUCCESS) return r;
        }
    }
    return VK_SUCCESS;
}
}                         
