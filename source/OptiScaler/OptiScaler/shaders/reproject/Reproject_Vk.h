#pragma once

#include "SysUtils.h"

#include <shaders/Shader_Vk.h>
#include "Reproject.h"

class Reproject_Vk : public Shader_Vk, public Reproject
{
  private:
    struct Image
    {
        VkImage image = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        VkImageView view = VK_NULL_HANDLE;                                     
        VkImageView arrayView = VK_NULL_HANDLE;                                                          
        VkImageLayout layout = VK_IMAGE_LAYOUT_UNDEFINED;
        uint32_t width = 0;
        uint32_t height = 0;
    };

    struct Buffer
    {
        VkBuffer buffer = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        void* mapped = nullptr;                                 
    };

                                                                            
    VkPipeline _maskPipelineH = VK_NULL_HANDLE;
    VkPipeline _maskPipelineV = VK_NULL_HANDLE;
    VkPipeline _latchPipeline = VK_NULL_HANDLE;
    VkPipeline _cachePipeline = VK_NULL_HANDLE;
    VkPipeline _statsPipeline = VK_NULL_HANDLE;

                                          
    VkSampler _pointSampler = VK_NULL_HANDLE;

    Buffer _params;                                  
    VkDeviceSize _paramsStride = 0;

                                                                   
    Buffer _liveInput;
    Buffer _latched;                                                               

    Buffer _stats;
    Buffer _statsReadback[StatsLatency];

                                                
    Image _depthMaskTemp;
    Image _depthMask;
    Image _cacheColor[2];
    Image _cacheGeo[2];
    Image _emptyCube;                                                                     

    uint32_t InNumThreadsX = 16;
    uint32_t InNumThreadsY = 16;

    bool CreateImage(Image& image, VkFormat format, uint32_t width, uint32_t height, bool cube);
    void DestroyImage(Image& image);
    bool CreateBuffer(Buffer& buffer, VkDeviceSize size, VkBufferUsageFlags usage, bool hostVisible);
    void DestroyBuffer(Buffer& buffer);

    bool CreateMaskImages(uint32_t width, uint32_t height);
    bool CreateCacheImages(uint32_t size);
    void ToGeneral(VkCommandBuffer cmdBuffer, Image& image);

  public:
                                                                                                
                                                           
    bool Dispatch(VkCommandBuffer cmdBuffer, ReprojectionParams& params, VkImageView present, VkExtent2D presentExtent,
                  VkImageView hudless, VkImageView depth, VkImageView velocity = VK_NULL_HANDLE);

                                                 
                                                                                      
    static constexpr VkFormat OutputFormat = VK_FORMAT_R16G16B16A16_SFLOAT;

    Reproject_Vk(std::string InName, VkDevice InDevice, VkPhysicalDevice InPhysicalDevice);
    ~Reproject_Vk();
};
