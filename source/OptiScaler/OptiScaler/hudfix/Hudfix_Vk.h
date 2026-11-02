#pragma once
#include "SysUtils.h"

#include <vulkan/vulkan.h>

                                                                             
                                                                                                                    
                                                                                                              
                                                      
class Hudfix_Vk
{
  public:
    static void HookDevice(VkDevice device);

    static void UpscaleEnd(VkCommandBuffer cmdBuffer);
    static void PresentStart();

    static void CheckImage(VkCommandBuffer cmdBuffer, VkImage image, VkFormat format, VkExtent2D extent,
                           VkImageLayout layout);
    static void AddSwapchainImages(const VkImage* images, uint32_t count);
};
