#pragma once
#include <pch.h>
#include <shaders/Shader_Vk.h>

                                                                         
class RF_Vk : public Shader_Vk
{
    uint32_t InNumThreadsX = 16;
    uint32_t InNumThreadsY = 16;

  public:
    RF_Vk(std::string InName, VkDevice InDevice, VkPhysicalDevice InPhysicalDevice);
    ~RF_Vk() = default;

                                                                     
    bool Dispatch(VkCommandBuffer InCmdList, VkImageView InResourceView, VkImageView OutResourceView,
                  VkExtent2D InImageExtent, uint32_t width, uint32_t height, bool velocity);
};
