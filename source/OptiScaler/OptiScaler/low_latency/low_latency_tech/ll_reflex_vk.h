#pragma once

#include "low_latency_tech.h"

#include <vulkan/vulkan.h>

                                                                                      
inline std::optional<VkLatencyMarkerNV> ToVkLatencyMarker(MarkerType type)
{
    if (type == MarkerType::PC_LATENCY_PING)
        return std::nullopt;

    auto value = (uint32_t) type;
    return (VkLatencyMarkerNV) (value > (uint32_t) MarkerType::PC_LATENCY_PING ? value - 1 : value);
}

inline MarkerType FromVkLatencyMarker(VkLatencyMarkerNV marker)
{
    auto value = (uint32_t) marker;
    return (MarkerType) (value >= (uint32_t) MarkerType::PC_LATENCY_PING ? value + 1 : value);
}

                                                                                                                    
                                                                              
class ReflexVk : public LowLatencyTech
{
    VkDevice device = VK_NULL_HANDLE;
    VkSemaphore semaphore = VK_NULL_HANDLE;
    uint64_t semaphore_value = 0;

    SleepMode sleep_mode {};
    bool sleep_mode_known = false;
    bool applied_enabled = false;
    VkSwapchainKHR applied_swapchain = VK_NULL_HANDLE;                               

    PFN_vkWaitSemaphores o_WaitSemaphores = nullptr;
    PFN_vkDestroySemaphore o_DestroySemaphore = nullptr;

                                                                                             
    VkSwapchainKHR swapchain();
    void apply_sleep_mode(VkSwapchainKHR swapchain);

  public:
    ReflexVk() : LowLatencyTech() {}

                          
    bool init(IUnknown* pDevice) override;
    void deinit() override;

    LowLatencyMode get_mode() override { return LowLatencyMode::Reflex; };
    void* get_tech_context() override { return device; };
    void set_fg_type(bool interpolated, uint64_t frame_id) override {};                                             
    void set_low_latency_override(ForceReflex low_latency_override) override
    {
        this->low_latency_override = low_latency_override;
    };
    void set_effective_fg_state(bool effective_fg_state) override { this->effective_fg_state = effective_fg_state; };

    bool is_enabled() override;

                                                                                                
    bool has_swapchain() { return swapchain() != VK_NULL_HANDLE; }

    void get_sleep_status(SleepParams* sleep_params) override;
    void set_sleep_mode(SleepMode* sleep_mode) override;
    void sleep(std::optional<uint32_t> frame_id) override;
    void set_marker(IUnknown* pDevice, const MarkerParams& marker_params) override;
    void set_async_marker(IUnknown* pCommandQueue, const MarkerParams& marker_params) override;

                      
    VkResult get_latency(VkGetLatencyMarkerInfoNV* latency_info);
    void notify_out_of_band(VkQueue queue, VkOutOfBandQueueTypeNV queue_type) const;
};
