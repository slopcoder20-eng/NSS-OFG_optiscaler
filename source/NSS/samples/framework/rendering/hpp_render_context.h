/* Copyright (c) 2022-2025, NVIDIA CORPORATION. All rights reserved.
 * Copyright (c) 2024-2025, Arm Limited and Contributors
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

#include "common/vk_common.h"
#include "core/hpp_swapchain.h"
#include "rendering/hpp_render_target.h"
#include "rendering/render_frame.h"

namespace vkb
{
class Window;

namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferCpp = CommandBuffer<vkb::BindingType::Cpp>;

class HPPQueue;
}                         

namespace rendering
{
   
                                                                                                   
  
                                           
   
class HPPRenderContext
{
  public:
	                                                                       
	static vk::Format DEFAULT_VK_FORMAT;

	   
                      
                                
                                                          
                                                          
                                                                         
                                                                                                             
                                                                                                                 
    
	HPPRenderContext(vkb::core::DeviceCpp                    &device,
	                 vk::SurfaceKHR                           surface,
	                 const vkb::Window                       &window,
	                 vk::PresentModeKHR                       present_mode                 = vk::PresentModeKHR::eFifo,
	                 std::vector<vk::PresentModeKHR> const   &present_mode_priority_list   = {vk::PresentModeKHR::eFifo, vk::PresentModeKHR::eMailbox},
	                 std::vector<vk::SurfaceFormatKHR> const &surface_format_priority_list = {
	                     {vk::Format::eR8G8B8A8Srgb, vk::ColorSpaceKHR::eSrgbNonlinear}, {vk::Format::eB8G8R8A8Srgb, vk::ColorSpaceKHR::eSrgbNonlinear}});

	HPPRenderContext(const HPPRenderContext &) = delete;

	HPPRenderContext(HPPRenderContext &&) = delete;

	virtual ~HPPRenderContext() = default;

	HPPRenderContext &operator=(const HPPRenderContext &) = delete;

	HPPRenderContext &operator=(HPPRenderContext &&) = delete;

	   
                                                  
                                                                                                                                     
                                                                                       
    
	void prepare(size_t thread_count = 1, HPPRenderTarget::CreateFunc create_render_target_func = HPPRenderTarget::DEFAULT_CREATE_FUNC);

	   
                                                               
                                                                  
    
	void update_swapchain(const vk::Extent2D &extent);

	   
                                                                    
                                                                
    
	void update_swapchain(const uint32_t image_count);

	   
                                                                    
                                                                               
    
	void update_swapchain(const std::set<vk::ImageUsageFlagBits> &image_usage_flags);

	   
                                                                                     
                                                                  
                                                
    
	void update_swapchain(const vk::Extent2D &extent, const vk::SurfaceTransformFlagBitsKHR transform);

	   
                                                                     
    
	bool has_swapchain();

	   
                                                                
    
	void recreate();

	   
                                  
    
	void recreate_swapchain();

	   
                                                          
                                                     
                                                                      
                                                                                           
    
	std::shared_ptr<vkb::core::CommandBufferCpp> begin(vkb::CommandBufferResetMode reset_mode = vkb::CommandBufferResetMode::ResetPool);

	   
                                                        
                                                                       
    
	void submit(vkb::core::CommandBufferCpp &command_buffer);

	   
                                                              
                                                                       
    
	void submit(const std::vector<vkb::core::CommandBufferCpp *> &command_buffers);

	   
                      
    
	void begin_frame();

	vk::Semaphore submit(const vkb::core::HPPQueue                        &queue,
	                     const std::vector<vkb::core::CommandBufferCpp *> &command_buffers,
	                     vk::Semaphore                                     wait_semaphore,
	                     vk::PipelineStageFlags                            wait_pipeline_stage);

	   
                                                                 
    
	void submit(const vkb::core::HPPQueue &queue, const std::vector<vkb::core::CommandBufferCpp *> &command_buffers);

	   
                                                
    
	virtual void wait_frame();

	void end_frame(vk::Semaphore semaphore);

	   
                                                                
                                                                    
                                    
    
	vkb::rendering::RenderFrameCpp &get_active_frame();

	   
                                                                
                                                                    
                                          
    
	uint32_t get_active_frame_index();

	   
                                                          
                                                                    
                              
    
	vkb::rendering::RenderFrameCpp &get_last_rendered_frame();

	vk::Semaphore request_semaphore();
	vk::Semaphore request_semaphore_with_ownership();
	void          release_owned_semaphore(vk::Semaphore semaphore);

	vkb::core::DeviceCpp &get_device();

	   
                                                                                                 
    
	vk::Format get_format() const;

	vkb::core::HPPSwapchain const &get_swapchain() const;

	vk::Extent2D const &get_surface_extent() const;

	uint32_t get_active_frame_index() const;

	std::vector<std::unique_ptr<vkb::rendering::RenderFrameCpp>> &get_render_frames();

	   
                                                                                                  
    
	virtual bool handle_surface_changes(bool force_update = false);

	   
                                                                                            
                                      
    
	vk::Semaphore consume_acquired_semaphore();

  protected:
	vk::Extent2D surface_extent;

  private:
	vkb::core::DeviceCpp &device;

	const vkb::Window &window;

	                                                                                           
	const vkb::core::HPPQueue &queue;

	std::unique_ptr<vkb::core::HPPSwapchain> swapchain;

	vkb::core::HPPSwapchainProperties swapchain_properties;

	std::vector<std::unique_ptr<vkb::rendering::RenderFrameCpp>> frames;

	vk::Semaphore acquired_semaphore;

	bool prepared{false};

	                              
	uint32_t active_frame_index{0};

	                                    
	bool frame_active{false};

	HPPRenderTarget::CreateFunc create_render_target_func = HPPRenderTarget::DEFAULT_CREATE_FUNC;

	vk::SurfaceTransformFlagBitsKHR pre_transform{vk::SurfaceTransformFlagBitsKHR::eIdentity};

	size_t thread_count{1};
};

}                              
}                        
