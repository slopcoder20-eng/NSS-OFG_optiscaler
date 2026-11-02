/* Copyright (c) 2019-2025, Sascha Willems
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

#ifdef _WIN32
#	pragma comment(linker, "/subsystem:windows")
#	include <ShellScalingAPI.h>
#	include <fcntl.h>
#	include <io.h>
#	include <windows.h>
#endif

#include <chrono>
#include <iostream>
#include <random>
#include <sys/stat.h>

#include "camera.h"
#include "common/vk_common.h"
#include "common/vk_initializers.h"
#include "core/buffer.h"
#include "core/swapchain.h"
#include "gui.h"
#include "platform/platform.h"
#include "rendering/render_context.h"
#include "scene_graph/components/image.h"
#include "scene_graph/components/sampler.h"
#include "scene_graph/components/texture.h"
#include "vulkan_sample.h"

   
                            
   
struct SwapchainBuffer
{
	VkImage     image;
	VkImageView view;
};

   
                                                                                
   
struct Texture
{
	std::unique_ptr<vkb::sg::Image> image;
	VkSampler                       sampler;
};

   
                                   
   
struct Vertex
{
	glm::vec3 pos;
	glm::vec3 normal;
	glm::vec2 uv;
	glm::vec4 joint0;
	glm::vec4 weight0;
	glm::vec3 color;
};

   
                                                      
                                                         
   
struct AlignedVertex
{
	glm::vec4 pos;
	glm::vec4 normal;
};

   
                                                    
   
struct Meshlet
{
	uint32_t vertices[64];
	uint32_t indices[126];
	uint32_t vertex_count;
	uint32_t index_count;
};

   
                                                                                    
  
                                          
   
class ApiVulkanSample : public vkb::VulkanSampleC
{
  public:
	ApiVulkanSample() = default;

	virtual ~ApiVulkanSample();

	virtual bool prepare(const vkb::ApplicationOptions &options) override;

	virtual void input_event(const vkb::InputEvent &input_event) override;

	virtual void update(float delta_time) override;

	virtual bool resize(const uint32_t width, const uint32_t height) override;

	virtual void render(float delta_time) = 0;

	enum RenderPassCreateFlags
	{
		ColorAttachmentLoad = 0x00000001
	};

  protected:
	                                      
	std::vector<SwapchainBuffer> swapchain_buffers;

	virtual void create_render_context() override;

	                                                                            
	VkQueue queue;

	                                                              
	VkFormat depth_format;

	                      
	VkCommandPool cmd_pool;

	                                                                            
	VkPipelineStageFlags submit_pipeline_stages = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

	                                                                       
	VkSubmitInfo submit_info;

	                                     
	std::vector<VkCommandBuffer> draw_cmd_buffers;

	                                             
	VkRenderPass render_pass;

	                                                                        
	std::vector<VkFramebuffer> framebuffers;

	                            
	uint32_t current_buffer = 0;

	                      
	VkDescriptorPool descriptor_pool = VK_NULL_HANDLE;

	                                                      
	std::vector<VkShaderModule> shader_modules;

	                        
	VkPipelineCache pipeline_cache;

	                             
	struct
	{
		                                
		VkSemaphore acquired_image_ready;

		                                          
		VkSemaphore render_complete;
	} semaphores;

	                         
	std::vector<VkFence> wait_fences;

	   
                                                                               
    
	void create_swapchain_buffers();

	   
                                                                                                                          
                                                                               
    
	void update_swapchain_image_usage_flags(std::set<VkImageUsageFlagBits> image_usage_flags);

	   
                                                         
    
	void handle_surface_changes();

	   
                                      
                                                                     
                                                                   
                                                           
    
	VkDescriptorBufferInfo create_descriptor(vkb::core::BufferC &buffer, VkDeviceSize size = VK_WHOLE_SIZE, VkDeviceSize offset = 0);

	   
                                      
                                                                       
                                                                                                            
    
	VkDescriptorImageInfo create_descriptor(Texture &texture, VkDescriptorType descriptor_type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER);

	   
                                    
                                                   
                                                             
    
	Texture load_texture(const std::string &file, vkb::sg::Image::ContentType content_type);

	   
                                          
                                                   
                                                             
    
	Texture load_texture_array(const std::string &file, vkb::sg::Image::ContentType content_type);

	   
                                            
                                                   
                                                             
    
	Texture load_texture_cubemap(const std::string &file, vkb::sg::Image::ContentType content_type);

	   
                                                   
                                                 
                                                                               
                                                         
                                                                                                                
    
	std::unique_ptr<vkb::sg::SubMesh> load_model(const std::string &file, uint32_t index = 0, bool storage_buffer = false, VkBufferUsageFlags additional_buffer_usage_flags = 0);

	   
                                                                     
                                  
                                                         
                                                              
    
	void draw_model(std::unique_ptr<vkb::sg::SubMesh> &model, VkCommandBuffer command_buffer, uint32_t instance_count = 1);

	   
                                                                                                                              
                                                                                                  
                                                                                                      
    
	void with_command_buffer(const std::function<void(VkCommandBuffer command_buffer)> &f, VkSemaphore signalSemaphore = VK_NULL_HANDLE);

	   
                                                                                                                                          
                                                                                                  
    
	void with_vkb_command_buffer(const std::function<void(vkb::core::CommandBufferC &command_buffer)> &f);

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

	   
                                                                   
                                                        
    
	void update_render_pass_flags(uint32_t flags = 0);

	   
                                                                 
    
	bool check_command_buffers();

	   
                                                      
    
	void create_command_buffers();

	   
                                                                                              
    
	void destroy_command_buffers();

	   
                                                                              
    
	void recreate_current_command_buffer();

	   
                                                      
    
	void create_pipeline_cache();

	   
                               
                                                                              
                                 
    
	VkPipelineShaderStageCreateInfo load_shader(const std::string &file, VkShaderStageFlagBits stage);

	   
                                                                          
                                                                                                      
                                                       
                                 
    
	VkPipelineShaderStageCreateInfo load_shader(const std::string &sample_folder_name, const std::string &shader_filename, VkShaderStageFlagBits stage);

	   
                              
                                                         
                                                                   
    
	void update_overlay(float delta_time, const std::function<void()> &additional_ui) override;

	   
                                                                                      
                                                                                
    
	void draw_ui(const VkCommandBuffer command_buffer);

	   
                                                                                                     
                                                      
    
	void prepare_frame();

	   
                                      
    
	void submit_frame();

	   
                                                                                                    
                                                                  
    
	virtual void on_update_ui_overlay(vkb::Drawer &drawer);

	   
                                                                                      
    
	virtual void prepare_gui();

  private:
	                                                                                                                               
	bool view_updated = false;
	                                                 
	uint32_t dest_width;
	uint32_t dest_height;
	bool     resizing = false;

	void handle_mouse_move(int32_t x, int32_t y);

#if defined(VKB_DEBUG) || defined(VKB_VALIDATION_LAYERS)
	                             
	VkDebugReportCallbackEXT debug_report_callback{VK_NULL_HANDLE};
#endif

  public:
	bool     prepared = false;
	uint32_t width    = 1280;
	uint32_t height   = 720;

	VkClearColorValue default_clear_color = {{0.002f, 0.002f, 0.002f, 1.0f}};

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

	std::string title = "Vulkan Example";
	std::string name  = "vulkanExample";

	struct ImageData
	{
		VkImage        image{VK_NULL_HANDLE};
		VkDeviceMemory mem{VK_NULL_HANDLE};
		VkImageView    view{VK_NULL_HANDLE};
	} depth_stencil;

	struct
	{
		bool left   = false;
		bool right  = false;
		bool middle = false;
	} mouse_buttons;

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
