/* Copyright (c) 2019-2025, Arm Limited and Contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 the "License";
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

#include "common/helpers.h"
#include "common/vk_common.h"
#include "core/command_buffer.h"
#include "core/command_pool.h"
#include "core/descriptor_set.h"
#include "core/descriptor_set_layout.h"
#include "core/framebuffer.h"
#include "core/pipeline.h"
#include "core/pipeline_layout.h"
#include "core/queue.h"
#include "core/render_pass.h"
#include "core/shader_module.h"
#include "core/swapchain.h"
#include "rendering/pipeline_state.h"
#include "rendering/render_frame.h"
#include "rendering/render_target.h"
#include "resource_cache.h"

namespace vkb
{
class Window;

   
                                                                                           
                                                                                          
                                                                                              
                                                                                       
                                                                                          
  
                                                                                            
  
                                                                                             
                                                                          
  
                                                                                             
                                                                 
   
class RenderContext
{
  public:
	                                                                       
	static VkFormat DEFAULT_VK_FORMAT;

	   
                      
                                
                                                                 
                                                          
                                                                         
                                                                                                             
                                                                                                                 
    
	RenderContext(vkb::core::DeviceC                    &device,
	              VkSurfaceKHR                           surface,
	              const Window                          &window,
	              VkPresentModeKHR                       present_mode                 = VK_PRESENT_MODE_FIFO_KHR,
	              const std::vector<VkPresentModeKHR>   &present_mode_priority_list   = {VK_PRESENT_MODE_FIFO_KHR, VK_PRESENT_MODE_MAILBOX_KHR},
	              const std::vector<VkSurfaceFormatKHR> &surface_format_priority_list = {
	                  {VK_FORMAT_R8G8B8A8_SRGB, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR},
	                  {VK_FORMAT_B8G8R8A8_SRGB, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR}});

	RenderContext(const RenderContext &) = delete;

	RenderContext(RenderContext &&) = delete;

	virtual ~RenderContext() = default;

	RenderContext &operator=(const RenderContext &) = delete;

	RenderContext &operator=(RenderContext &&) = delete;

	   
                                                  
                                                                                                                                     
                                                                                       
    
	void prepare(size_t thread_count = 1, RenderTarget::CreateFunc create_render_target_func = RenderTarget::DEFAULT_CREATE_FUNC);

	   
                                                               
                                                                  
    
	void update_swapchain(const VkExtent2D &extent);

	   
                                                                    
                                                                
    
	void update_swapchain(const uint32_t image_count);

	   
                                                                    
                                                                               
    
	void update_swapchain(const std::set<VkImageUsageFlagBits> &image_usage_flags);

	   
                                                                                     
                                                                  
                                                
    
	void update_swapchain(const VkExtent2D &extent, const VkSurfaceTransformFlagBitsKHR transform);

	   
                                                                              
                                                                                              
                                                                               
    
	void update_swapchain(const VkImageCompressionFlagsEXT compression, const VkImageCompressionFixedRateFlagsEXT compression_fixed_rate);

	   
                                                                  
    
	bool has_swapchain();

	   
                                                                
    
	void recreate();

	   
                                  
    
	void recreate_swapchain();

	   
                                                          
                                                     
                                                                      
                                                                                           
    
	std::shared_ptr<vkb::core::CommandBufferC> begin(vkb::CommandBufferResetMode reset_mode = vkb::CommandBufferResetMode::ResetPool);

	   
                                                        
                                                                       
    
	void submit(std::shared_ptr<vkb::core::CommandBufferC> command_buffer);

	   
                                                              
                                                                       
    
	void submit(const std::vector<std::shared_ptr<vkb::core::CommandBufferC>> &command_buffers);

	   
                      
    
	void begin_frame();

	VkSemaphore submit(const Queue                                                   &queue,
	                   const std::vector<std::shared_ptr<vkb::core::CommandBufferC>> &command_buffers,
	                   VkSemaphore                                                    wait_semaphore,
	                   VkPipelineStageFlags                                           wait_pipeline_stage);

	   
                                                                 
    
	void submit(const Queue &queue, const std::vector<std::shared_ptr<vkb::core::CommandBufferC>> &command_buffers);

	   
                                                
    
	virtual void wait_frame();

	void end_frame(VkSemaphore semaphore);

	   
                                                                
                                                                    
                                    
    
	vkb::rendering::RenderFrameC &get_active_frame();

	   
                                                                
                                                                    
                                          
    
	uint32_t get_active_frame_index();

	   
                                                          
                                                                    
                              
    
	vkb::rendering::RenderFrameC &get_last_rendered_frame();

	VkSemaphore request_semaphore();
	VkSemaphore request_semaphore_with_ownership();
	void        release_owned_semaphore(VkSemaphore semaphore);

	vkb::core::DeviceC &get_device();

	   
                                                                                              
    
	VkFormat get_format() const;

	Swapchain const &get_swapchain() const;

	VkExtent2D const &get_surface_extent() const;

	uint32_t get_active_frame_index() const;

	std::vector<std::unique_ptr<vkb::rendering::RenderFrameC>> &get_render_frames();

	   
                                                                                                  
    
	virtual bool handle_surface_changes(bool force_update = false);

	   
                                                                                            
                                      
    
	VkSemaphore consume_acquired_semaphore();

  protected:
	VkExtent2D surface_extent;

  private:
	vkb::core::DeviceC &device;

	const Window &window;

	                                                                                           
	const Queue &queue;

	std::unique_ptr<Swapchain> swapchain;

	SwapchainProperties swapchain_properties;

	std::vector<std::unique_ptr<vkb::rendering::RenderFrameC>> frames;

	VkSemaphore acquired_semaphore;

	bool prepared{false};

	                              
	uint32_t active_frame_index{0};

	                                    
	bool frame_active{false};

	RenderTarget::CreateFunc create_render_target_func = RenderTarget::DEFAULT_CREATE_FUNC;

	VkSurfaceTransformFlagBitsKHR pre_transform{VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR};

	size_t thread_count{1};
};

}                        
