/* Copyright (c) 2021-2025, NVIDIA CORPORATION. All rights reserved.
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

#include <camera.h>
#include <common/hpp_error.h>
#include <scene_graph/components/hpp_image.h>
#include <scene_graph/components/hpp_sub_mesh.h>

#include "vulkan_sample.h"

   
                            
   
struct HPPSwapchainBuffer
{
	vk::Image     image;
	vk::ImageView view;
};

   
                                                                                
   
struct HPPTexture
{
	std::unique_ptr<vkb::scene_graph::components::HPPImage> image;
	vk::Sampler                                             sampler;
};

   
                                   
   
struct HPPVertex
{
	glm::vec3 pos;
	glm::vec3 normal;
	glm::vec2 uv;
	glm::vec4 joint0;
	glm::vec4 weight0;
	glm::vec3 color;
};

   
                                                              
  
                                             
   
class HPPApiVulkanSample : public vkb::VulkanSampleCpp
{
  public:
	HPPApiVulkanSample() = default;

	virtual ~HPPApiVulkanSample();

	bool prepare(const vkb::ApplicationOptions &options) override;

	void input_event(const vkb::InputEvent &input_event) override;

	void update(float delta_time) override;

	bool resize(const uint32_t width, const uint32_t height) override;

	virtual void render(float delta_time) = 0;

	enum RenderPassCreateFlags
	{
		ColorAttachmentLoad = 0x00000001
	};

  protected:
	                                      
	std::vector<HPPSwapchainBuffer> swapchain_buffers;

	void create_render_context() override;
	void prepare_render_context() override;

	                                                                            
	vk::Queue queue;

	                                                              
	vk::Format depth_format;

	                      
	vk::CommandPool cmd_pool;

	                                                                            
	vk::PipelineStageFlags submit_pipeline_stages = vk::PipelineStageFlagBits::eColorAttachmentOutput;

	                                                                       
	vk::SubmitInfo submit_info;

	                                     
	std::vector<vk::CommandBuffer> draw_cmd_buffers;

	                                             
	vk::RenderPass render_pass;

	                                                                        
	std::vector<vk::Framebuffer> framebuffers;

	                            
	uint32_t current_buffer = 0;

	                      
	vk::DescriptorPool descriptor_pool;

	                                                      
	std::vector<vk::ShaderModule> shader_modules;

	                        
	vk::PipelineCache pipeline_cache;

	                             
	struct
	{
		                                
		vk::Semaphore acquired_image_ready;

		                                          
		vk::Semaphore render_complete;
	} semaphores;

	                         
	std::vector<vk::Fence> wait_fences;

	   
                                   
                                                 
                                                   
                                                       
                                
    
	vk::Sampler create_default_sampler(vk::SamplerAddressMode address_mode, size_t mipmaps_count, vk::Format format);

	   
                                                                               
    
	void create_swapchain_buffers();

	   
                                                                                                                          
                                                                               
    
	void update_swapchain_image_usage_flags(std::set<vk::ImageUsageFlagBits> const &image_usage_flags);

	   
                                                         
    
	void handle_surface_changes();

	   
                                                                  
                                                          
                                                                                                                                           
    
	vk::ImageLayout descriptor_type_to_image_layout(vk::DescriptorType descriptor_type, vk::Format format) const;

	   
                                    
                                                   
                                                             
                                                                                                                           
    
	HPPTexture
	    load_texture(const std::string &file, vkb::scene_graph::components::HPPImage::ContentType content_type, vk::SamplerAddressMode address_mode = vk::SamplerAddressMode::eRepeat);

	   
                                          
                                                   
                                                             
                                                                                                                                
    
	HPPTexture load_texture_array(const std::string                                  &file,
	                              vkb::scene_graph::components::HPPImage::ContentType content_type,
	                              vk::SamplerAddressMode                              address_mode = vk::SamplerAddressMode::eClampToEdge);

	   
                                            
                                                   
                                                             
    
	HPPTexture load_texture_cubemap(const std::string &file, vkb::scene_graph::components::HPPImage::ContentType content_type);

	   
                                                   
                                                 
                                                                               
                                                         
                                                                                                                
    
	std::unique_ptr<vkb::scene_graph::components::HPPSubMesh> load_model(
	    const std::string &file, uint32_t index = 0, bool storage_buffer = false, vk::BufferUsageFlags additional_buffer_usage_flags = {});

	   
                                                                     
                                  
                                                         
                                                              
    
	void draw_model(std::unique_ptr<vkb::scene_graph::components::HPPSubMesh> &model, vk::CommandBuffer command_buffer, uint32_t instance_count = 1);

	   
                                                                                                                              
                                                                                                  
                                                                                                      
    
	void with_command_buffer(const std::function<void(vk::CommandBuffer command_buffer)> &f, vk::Semaphore signalSemaphore = nullptr);

  public:
	   
                                                                                                            
    
	virtual void view_changed();

	   
                                                                                                              
                                      
                                       
                                                
    
	virtual void mouse_moved(double x, double y, bool &handled);

	   
                                                                                                                
                                                          
    
	virtual void build_command_buffers() = 0;

	   
                                                                                                                               
    
	void rebuild_command_buffers();

	   
                                           
    
	void create_synchronization_primitives();

	   
                                                                               
    
	void create_command_pool();

	   
                                                
    
	virtual void setup_depth_stencil();

	   
                                                                  
                                                                                          
    
	virtual void setup_framebuffer();

	   
                                      
                                                                                          
    
	virtual void setup_render_pass();

	   
                                                                   
                                                        
    
	void update_render_pass_flags(RenderPassCreateFlags flags = {});

	   
                                                                 
    
	bool check_command_buffers();

	   
                                                      
    
	void create_command_buffers();

	   
                                                                                              
    
	void destroy_command_buffers();

	   
                                                      
    
	void create_pipeline_cache();

	   
                               
                                                                              
                                 
    
	vk::PipelineShaderStageCreateInfo load_shader(const std::string &file, vk::ShaderStageFlagBits stage);

	   
                                                                          
                                                                                                      
                                                       
                                 
    
	vk::PipelineShaderStageCreateInfo load_shader(const std::string &sample_folder_name, const std::string &shader_filename, vk::ShaderStageFlagBits stage);

	   
                              
                                                         
                                                                   
    
	void update_overlay(float delta_time, const std::function<void()> &additional_ui) override;

	   
                                                                                      
                                                                                
    
	void draw_ui(const vk::CommandBuffer command_buffer);

	   
                                                                                                     
                                                      
    
	void prepare_frame();

	   
                                      
    
	void submit_frame();

	   
                                                                                                    
                                                                  
    
	virtual void on_update_ui_overlay(vkb::Drawer &drawer);

	   
                                                                                      
    
	virtual void prepare_gui();

  private:
	                                                                                                                               
	bool view_updated = false;
	                                                 
	vk::Extent2D dest_extent;
	bool         resizing = false;

	void handle_mouse_move(int32_t x, int32_t y);

#if defined(VKB_DEBUG) || defined(VKB_VALIDATION_LAYERS)
	                             
	vk::DebugReportCallbackEXT debug_report_callback;
#endif

  public:
	bool         prepared = false;
	vk::Extent2D extent{1280, 720};

	vk::ClearColorValue default_clear_color = std::array<float, 4>({{0.002f, 0.002f, 0.002f, 1.0f}});

	float zoom = 0;

	                                                                       
	                                         
	float timer = 0.0f;
	                                                                
	float timer_speed = 0.0025f;

	bool paused = false;

	                                     
	float rotation_speed = 1.0f;
	                                 
	float zoom_speed = 1.0f;

	vkb::Camera camera;

	glm::vec3 rotation   = glm::vec3();
	glm::vec3 camera_pos = glm::vec3();
	glm::vec2 mouse_pos;

	std::string title = "HPP Vulkan API Example";
	std::string name  = "HPPAPIVulkanExample";

	struct
	{
		vk::Image        image;
		vk::DeviceMemory mem;
		vk::ImageView    view;
	} depth_stencil;

	struct
	{
		bool left   = false;
		bool right  = false;
		bool middle = false;
	} mouse_buttons;

	                                                                
	bool focused = false;
	struct TouchPos
	{
		int32_t x;
		int32_t y;
	} touch_pos;
	bool   touch_down  = false;
	double touch_timer = 0.0;

	uint32_t frame_count      = 0;
	float    accumulated_time = 0.0f;
	uint32_t fps              = 1;                                                     
};
