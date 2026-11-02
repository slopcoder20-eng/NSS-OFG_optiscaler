#pragma once

#include <vulkan/vulkan.h>
#include <stdint.h>
#include <stddef.h>

                                                                             
                                                               
#define NSS_API

#ifdef __cplusplus
extern "C" {
#endif

typedef enum NssModelQuality {
    NSS_QUALITY_HIGH = 0,
    NSS_QUALITY_MID_LOW = 1
} NssModelQuality;

typedef enum NssBackendType {
    NSS_BACKEND_AUTO = 0,
    NSS_BACKEND_COOPMAT = 1,
    NSS_BACKEND_DP4A = 2
} NssBackendType;

typedef struct NssEngineConfig {
    VkInstance       instance;
    VkPhysicalDevice physicalDevice;
    VkDevice         device;
    NssModelQuality  quality;
    NssBackendType   backend;
} NssEngineConfig;

typedef struct NssFrameParameters {
    VkImageView in_color_jittered;
    VkImageView in_depth;
    VkImageView in_motion_vectors;
    VkImageView in_exposure;                                           
    VkImageView in_reactive_mask;                                      
    VkImageView out_upscaled_color;

    uint32_t render_width;
    uint32_t render_height;
    uint32_t display_width;
    uint32_t display_height;

    float jitter_offset_x;
    float jitter_offset_y;
    float pre_exposure;
    int   reset_history;
} NssFrameParameters;

typedef void* NssEngineHandle;

                                                         
NSS_API int nss_engine_create(const NssEngineConfig* config, NssEngineHandle* out_handle);

                                                                                     
NSS_API int nss_engine_setup_resolution(NssEngineHandle handle, uint32_t input_width, uint32_t input_height);

                                              
NSS_API int nss_engine_set_backend(NssEngineHandle handle, NssBackendType backend);
NSS_API NssBackendType nss_engine_get_backend(NssEngineHandle handle);

                                                                
                                     
                                                                                 
                                           
NSS_API int nss_engine_dispatch(
    NssEngineHandle handle,
    VkCommandBuffer cmd_buffer,
    VkBuffer input_buf,          VkDeviceSize input_offset,
    VkBuffer out_kpn_buf,        VkDeviceSize kpn_offset,
    VkBuffer out_feedback_buf,   VkDeviceSize feedback_offset
);

                                                                                                         
NSS_API int nss_engine_dispatch_frame(
    NssEngineHandle handle,
    VkCommandBuffer cmd_buffer,
    const NssFrameParameters* params
);

                                           
NSS_API void nss_engine_destroy(NssEngineHandle handle);

#ifdef __cplusplus
}
#endif
