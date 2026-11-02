/* Copyright (c) 2019-2025, Arm Limited and Contributors
 * Copyright (c) 2021-2025, NVIDIA CORPORATION. All rights reserved.
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

#include "common/hpp_utils.h"
#include "core/debug.h"
#include "gui.h"
#include "hpp_gltf_loader.h"
#include "platform/application.h"
#include "platform/window.h"
#include "rendering/hpp_render_pipeline.h"
#include "stats/hpp_stats.h"

#if defined(PLATFORM__MACOS)
#	include <TargetConditionals.h>
#endif

namespace vkb
{
   
                                      
  
                                         
  
                                                    
                                                                                
                                                                            
                                                                                     
                                                                                     
                                                                                      
  
                                                
                                                                                         
                                            
                                                                                
                                                                                  
                                                                                          
                          
                        
                           
                                                
                                
                          
                                                      
                            
                     
  
                                           
  
                                     
                                                                                
                                                                            
                                                            
  
                                  
                                                                               
                                     
  
                                                        
                                                                                 
                             
                               
                           
                                                                                          
                                                                                                   
                                                                
                                                                 
                                                             
  
                                                       
                                                                                          
                                             
                                                                                           
                                                                          
  
                                                    
  
                  
                
                 
                   
                 
                  
               
                                                                                     
   

class RenderPipeline;
class Stats;

namespace core
{
class HPPDevice;
class HPPInstance;
class HPPPhysicalDevice;
}                         

namespace rendering
{
class HPPRenderContext;
class HPPRenderTarget;
}                              

namespace stats
{
class HPPStats;
}

template <vkb::BindingType bindingType>
class VulkanSample : public vkb::Application
{
	using Parent = vkb::Application;

	             
	                    
	              
  public:
	VulkanSample() = default;
	~VulkanSample() override;

	using RenderContextType  = typename std::conditional<bindingType == BindingType::Cpp, vkb::rendering::HPPRenderContext, vkb::RenderContext>::type;
	using RenderPipelineType = typename std::conditional<bindingType == BindingType::Cpp, vkb::rendering::HPPRenderPipeline, vkb::RenderPipeline>::type;
	using RenderTargetType   = typename std::conditional<bindingType == BindingType::Cpp, vkb::rendering::HPPRenderTarget, vkb::RenderTarget>::type;
	using SceneType          = typename std::conditional<bindingType == BindingType::Cpp, vkb::scene_graph::HPPScene, vkb::sg::Scene>::type;
	using StatsType          = typename std::conditional<bindingType == BindingType::Cpp, vkb::stats::HPPStats, vkb::Stats>::type;
	using Extent2DType       = typename std::conditional<bindingType == BindingType::Cpp, vk::Extent2D, VkExtent2D>::type;
	using LayerSettingType   = typename std::conditional<bindingType == BindingType::Cpp, vk::LayerSettingEXT, VkLayerSettingEXT>::type;
	using SurfaceFormatType  = typename std::conditional<bindingType == BindingType::Cpp, vk::SurfaceFormatKHR, VkSurfaceFormatKHR>::type;
	using SurfaceType        = typename std::conditional<bindingType == BindingType::Cpp, vk::SurfaceKHR, VkSurfaceKHR>::type;

	Configuration           &get_configuration();
	RenderContextType       &get_render_context();
	RenderContextType const &get_render_context() const;
	bool                     has_render_context() const;

	             
	                               
	              
  protected:
	                   
	void input_event(const InputEvent &input_event) override;
	void finish() override;
	bool resize(uint32_t width, uint32_t height) override;

	   
                                                       
                                                               
    
	virtual std::unique_ptr<vkb::core::Device<bindingType>> create_device(vkb::core::PhysicalDevice<bindingType> &gpu);

	   
                                                         
                                                                 
    
	virtual std::unique_ptr<vkb::core::Instance<bindingType>> create_instance();

	   
                                                                        
    
	virtual void create_render_context();

	   
                                                                              
                                                                      
                                                                 
    
	virtual void draw(vkb::core::CommandBuffer<bindingType> &command_buffer, RenderTargetType &render_target);

	   
                                                                        
    
	virtual void draw_gui();

	   
                                                                                              
                                                                      
                                                                 
    
	virtual void draw_renderpass(vkb::core::CommandBuffer<bindingType> &command_buffer, RenderTargetType &render_target);

	   
                                                                                      
    
	virtual void prepare_render_context();

	   
                                                                                                            
                                                                      
    
	virtual void render(vkb::core::CommandBuffer<bindingType> &command_buffer);

	   
                                                                   
    
	virtual void request_gpu_features(vkb::core::PhysicalDevice<bindingType> &gpu);

	   
                                                                      
                                                         
                                                         
    
	virtual void reset_stats_view();

	   
                                                                                                
    
	virtual void update_debug_window();

	             
	                       
	              
	   
                                                 
                                       
                                                                
    
	void add_device_extension(const char *extension, bool optional = false);

	   
                                                   
                                       
                                                                
    
	void add_instance_extension(const char *extension, bool optional = false);

	   
                                               
                               
                                                                
    
	void add_instance_layer(const char *layer, bool optional = false);

	   
                                              
                                         
    
	void add_layer_setting(LayerSettingType const &layerSetting);

	void create_gui(const Window &window, StatsType const *stats = nullptr, const float font_size = 21.0f, bool explicit_update = false);

	   
                                              
    
	void create_render_context(const std::vector<SurfaceFormatType> &surface_priority_list);

	vkb::core::Device<bindingType>         &get_device();
	vkb::core::Device<bindingType> const   &get_device() const;
	vkb::Gui<bindingType>                  &get_gui();
	vkb::Gui<bindingType> const            &get_gui() const;
	vkb::core::Instance<bindingType>       &get_instance();
	vkb::core::Instance<bindingType> const &get_instance() const;
	RenderPipelineType                     &get_render_pipeline();
	RenderPipelineType const               &get_render_pipeline() const;
	SceneType                              &get_scene();
	StatsType                              &get_stats();
	SurfaceType                             get_surface() const;
	std::vector<SurfaceFormatType>         &get_surface_priority_list();
	std::vector<SurfaceFormatType> const   &get_surface_priority_list() const;
	bool                                    has_device() const;
	bool                                    has_instance() const;
	bool                                    has_gui() const;
	bool                                    has_render_pipeline() const;
	bool                                    has_scene();

	   
                          
   
                                         
    
	void load_scene(const std::string &path);

	   
                                           
    
	bool prepare(const ApplicationOptions &options) override;

	   
                                                                          
    
	void set_api_version(uint32_t requested_api_version);

	   
                                                                                                      
                                                                 
                                        
                                                                                           
                                                               
    
	void set_high_priority_graphics_queue_enable(bool enable);

	void set_render_context(std::unique_ptr<RenderContextType> &&render_context);

	void set_render_pipeline(std::unique_ptr<RenderPipelineType> &&render_pipeline);

	   
                                  
    
	void update(float delta_time) override;

	   
                     
                     
    
	void update_gui(float delta_time);

	   
                       
                     
    
	void update_scene(float delta_time);

	   
                                
                     
    
	void update_stats(float delta_time);

	   
                                                                              
    
	static void set_viewport_and_scissor(vkb::core::CommandBuffer<bindingType> const &command_buffer, Extent2DType const &extent);

	             
	                     
	              
  private:
	void        create_render_context_impl(const std::vector<vk::SurfaceFormatKHR> &surface_priority_list);
	void        draw_impl(vkb::core::CommandBufferCpp &command_buffer, vkb::rendering::HPPRenderTarget &render_target);
	void        draw_renderpass_impl(vkb::core::CommandBufferCpp &command_buffer, vkb::rendering::HPPRenderTarget &render_target);
	void        render_impl(vkb::core::CommandBufferCpp &command_buffer);
	static void set_viewport_and_scissor_impl(vkb::core::CommandBufferCpp const &command_buffer, vk::Extent2D const &extent);

	   
                                                 
   
                                                                                                
    
	std::unordered_map<const char *, bool> const &get_device_extensions() const;

	   
                                                   
   
                                                                                                  
    
	std::unordered_map<const char *, bool> const &get_instance_extensions() const;

	   
                                               
   
                                                                                              
    
	std::unordered_map<const char *, bool> const &get_instance_layers() const;

	   
                                              
   
                                                              
    
	std::vector<LayerSettingType> const &get_layer_settings() const;

	             
	                   
	              
  private:
	   
                              
    
	std::unique_ptr<vkb::core::InstanceCpp> instance;

	   
                            
    
	std::unique_ptr<vkb::core::DeviceCpp> device;

	   
                                                                                                            
    
	std::unique_ptr<vkb::rendering::HPPRenderContext> render_context;

	   
                                                                                  
    
	std::unique_ptr<vkb::rendering::HPPRenderPipeline> render_pipeline;

	   
                                      
    
	std::unique_ptr<vkb::scene_graph::HPPScene> scene;

	std::unique_ptr<vkb::GuiCpp> gui;

	std::unique_ptr<vkb::stats::HPPStats> stats;

	static constexpr float STATS_VIEW_RESET_TIME{10.0f};                     

	   
                             
    
	vk::SurfaceKHR surface;

	   
                                                                                                                        
    
	std::vector<vk::SurfaceFormatKHR> surface_priority_list = {
	    {vk::Format::eR8G8B8A8Srgb, vk::ColorSpaceKHR::eSrgbNonlinear},
	    {vk::Format::eB8G8R8A8Srgb, vk::ColorSpaceKHR::eSrgbNonlinear}};

	   
                                          
    
	Configuration configuration{};

	                                                                                                                                            
	std::unordered_map<const char *, bool> device_extensions;

	                                                                                                                                              
	std::unordered_map<const char *, bool> instance_extensions;

	                                                                                                                                          
	std::unordered_map<const char *, bool> instance_layers;

	                                                                                                              
	std::vector<vk::LayerSettingEXT> layer_settings;

	                                                                                         
	uint32_t api_version = VK_API_VERSION_1_1;

	                                                                    
	bool high_priority_graphics_queue{false};

	std::unique_ptr<vkb::core::HPPDebugUtils> debug_utils;
};

using VulkanSampleC   = VulkanSample<vkb::BindingType::C>;
using VulkanSampleCpp = VulkanSample<vkb::BindingType::Cpp>;

                              

template <vkb::BindingType bindingType>
inline VulkanSample<bindingType>::~VulkanSample()
{
	if (device)
	{
		device->get_handle().waitIdle();
	}

	scene.reset();
	stats.reset();
	gui.reset();
	render_context.reset();
	device.reset();

	if (surface)
	{
		instance->get_handle().destroySurfaceKHR(surface);
	}

	instance.reset();
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::add_device_extension(const char *extension, bool optional)
{
	device_extensions[extension] = optional;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::add_instance_extension(const char *extension, bool optional)
{
	instance_extensions[extension] = optional;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::add_layer_setting(LayerSettingType const &layerSetting)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		layer_settings.push_back(layerSetting);
	}
	else
	{
		layer_settings.push_back(reinterpret_cast<vk::LayerSettingEXT const &>(layerSetting));
	}
}

template <vkb::BindingType bindingType>
inline std::unique_ptr<typename vkb::core::Device<bindingType>> VulkanSample<bindingType>::create_device(vkb::core::PhysicalDevice<bindingType> &gpu)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return std::make_unique<vkb::core::DeviceCpp>(gpu, surface, std::move(debug_utils), get_device_extensions());
	}
	else
	{
		return std::make_unique<vkb::core::DeviceC>(gpu,
		                                            static_cast<VkSurfaceKHR>(surface),
		                                            std::unique_ptr<vkb::DebugUtils>(reinterpret_cast<vkb::DebugUtils *>(debug_utils.release())),
		                                            get_device_extensions());
	}
}

template <vkb::BindingType bindingType>
inline std::unique_ptr<vkb::core::Instance<bindingType>> VulkanSample<bindingType>::create_instance()
{
	return std::make_unique<vkb::core::Instance<bindingType>>(get_name(), get_instance_extensions(), get_instance_layers(), get_layer_settings(), api_version);
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::create_render_context()
{
	create_render_context_impl(surface_priority_list);
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::create_render_context(const std::vector<SurfaceFormatType> &surface_priority_list)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		create_render_context_impl(surface_priority_list);
	}
	else
	{
		create_render_context_impl(reinterpret_cast<std::vector<vk::SurfaceFormatKHR> const &>(surface_priority_list));
	}
}

template <vkb::BindingType bindingType>
void VulkanSample<bindingType>::create_render_context_impl(const std::vector<vk::SurfaceFormatKHR> &surface_priority_list)
{
#ifdef VK_USE_PLATFORM_ANDROID_KHR
	vk::PresentModeKHR              present_mode = (window->get_properties().vsync == Window::Vsync::OFF) ? vk::PresentModeKHR::eMailbox : vk::PresentModeKHR::eFifo;
	std::vector<vk::PresentModeKHR> present_mode_priority_list{vk::PresentModeKHR::eFifo, vk::PresentModeKHR::eMailbox, vk::PresentModeKHR::eImmediate};
#else
	vk::PresentModeKHR              present_mode = (window->get_properties().vsync == Window::Vsync::ON) ? vk::PresentModeKHR::eFifo : vk::PresentModeKHR::eMailbox;
	std::vector<vk::PresentModeKHR> present_mode_priority_list{vk::PresentModeKHR::eMailbox, vk::PresentModeKHR::eImmediate, vk::PresentModeKHR::eFifo};
#endif

	render_context =
	    std::make_unique<vkb::rendering::HPPRenderContext>(*device, surface, *window, present_mode, present_mode_priority_list, surface_priority_list);
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::draw(vkb::core::CommandBuffer<bindingType> &command_buffer, RenderTargetType &render_target)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		draw_impl(command_buffer, render_target);
	}
	else
	{
		draw_impl(reinterpret_cast<vkb::core::CommandBufferCpp &>(command_buffer),
		          reinterpret_cast<vkb::rendering::HPPRenderTarget &>(render_target));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::draw_impl(vkb::core::CommandBufferCpp     &command_buffer,
                                                 vkb::rendering::HPPRenderTarget &render_target)
{
	auto &views = render_target.get_views();

	{
		                           
		vkb::common::HPPImageMemoryBarrier memory_barrier{};
		memory_barrier.old_layout      = vk::ImageLayout::eUndefined;
		memory_barrier.new_layout      = vk::ImageLayout::eColorAttachmentOptimal;
		memory_barrier.src_access_mask = {};
		memory_barrier.dst_access_mask = vk::AccessFlagBits::eColorAttachmentWrite;
		memory_barrier.src_stage_mask  = vk::PipelineStageFlagBits::eColorAttachmentOutput;
		memory_barrier.dst_stage_mask  = vk::PipelineStageFlagBits::eColorAttachmentOutput;

		command_buffer.image_memory_barrier(views[0], memory_barrier);
		render_target.set_layout(0, memory_barrier.new_layout);

		                                                              
		for (size_t i = 2; i < views.size(); ++i)
		{
			command_buffer.image_memory_barrier(views[i], memory_barrier);
			render_target.set_layout(static_cast<uint32_t>(i), memory_barrier.new_layout);
		}
	}

	{
		vkb::common::HPPImageMemoryBarrier memory_barrier{};
		memory_barrier.old_layout      = vk::ImageLayout::eUndefined;
		memory_barrier.new_layout      = vk::ImageLayout::eDepthStencilAttachmentOptimal;
		memory_barrier.src_access_mask = {};
		memory_barrier.dst_access_mask = vk::AccessFlagBits::eDepthStencilAttachmentRead | vk::AccessFlagBits::eDepthStencilAttachmentWrite;
		memory_barrier.src_stage_mask  = vk::PipelineStageFlagBits::eTopOfPipe;
		memory_barrier.dst_stage_mask  = vk::PipelineStageFlagBits::eEarlyFragmentTests | vk::PipelineStageFlagBits::eLateFragmentTests;

		command_buffer.image_memory_barrier(views[1], memory_barrier);
		render_target.set_layout(1, memory_barrier.new_layout);
	}

	                                                                                                                      
	if constexpr (bindingType == BindingType::Cpp)
	{
		draw_renderpass(command_buffer, render_target);
	}
	else
	{
		draw_renderpass(reinterpret_cast<vkb::core::CommandBufferC &>(command_buffer), reinterpret_cast<vkb::RenderTarget &>(render_target));
	}

	{
		vkb::common::HPPImageMemoryBarrier memory_barrier{};
		memory_barrier.old_layout      = vk::ImageLayout::eColorAttachmentOptimal;
		memory_barrier.new_layout      = vk::ImageLayout::ePresentSrcKHR;
		memory_barrier.src_access_mask = vk::AccessFlagBits::eColorAttachmentWrite;
		memory_barrier.src_stage_mask  = vk::PipelineStageFlagBits::eColorAttachmentOutput;
		memory_barrier.dst_stage_mask  = vk::PipelineStageFlagBits::eBottomOfPipe;

		command_buffer.image_memory_barrier(views[0], memory_barrier);
		render_target.set_layout(0, memory_barrier.new_layout);
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::draw_gui()
{
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::draw_renderpass(vkb::core::CommandBuffer<bindingType> &command_buffer, RenderTargetType &render_target)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		draw_renderpass_impl(command_buffer, render_target);
	}
	else
	{
		draw_renderpass_impl(reinterpret_cast<vkb::core::CommandBufferCpp &>(command_buffer),
		                     reinterpret_cast<vkb::rendering::HPPRenderTarget &>(render_target));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::draw_renderpass_impl(vkb::core::CommandBufferCpp     &command_buffer,
                                                            vkb::rendering::HPPRenderTarget &render_target)
{
	set_viewport_and_scissor_impl(command_buffer, render_target.get_extent());

	                                                                                                    
	if constexpr (bindingType == BindingType::Cpp)
	{
		render(command_buffer);
	}
	else
	{
		render(reinterpret_cast<vkb::core::CommandBufferC &>(command_buffer));
	}

	if (gui)
	{
		gui->draw(command_buffer);
	}

	command_buffer.get_handle().endRenderPass();
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::finish()
{
	Parent::finish();

	if (device)
	{
		device->get_handle().waitIdle();
	}
}

template <vkb::BindingType bindingType>
inline Configuration &VulkanSample<bindingType>::get_configuration()
{
	return configuration;
}

template <vkb::BindingType bindingType>
inline vkb::core::Device<bindingType> const &VulkanSample<bindingType>::get_device() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *device;
	}
	else
	{
		return reinterpret_cast<vkb::core::DeviceC const &>(*device);
	}
}

template <vkb::BindingType bindingType>
inline vkb::core::Device<bindingType> &VulkanSample<bindingType>::get_device()
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *device;
	}
	else
	{
		return reinterpret_cast<vkb::core::DeviceC &>(*device);
	}
}

template <vkb::BindingType bindingType>
inline std::unordered_map<const char *, bool> const &VulkanSample<bindingType>::get_device_extensions() const
{
	return device_extensions;
}

template <vkb::BindingType bindingType>
inline vkb::Gui<bindingType> &VulkanSample<bindingType>::get_gui()
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *gui;
	}
	else
	{
		return reinterpret_cast<vkb::GuiC &>(*gui);
	}
}

template <vkb::BindingType bindingType>
inline vkb::Gui<bindingType> const &VulkanSample<bindingType>::get_gui() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *gui;
	}
	else
	{
		return reinterpret_cast<vkb::GuiC const &>(*gui);
	}
}

template <vkb::BindingType bindingType>
inline std::vector<typename VulkanSample<bindingType>::SurfaceFormatType> &VulkanSample<bindingType>::get_surface_priority_list()
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return surface_priority_list;
	}
	else
	{
		return reinterpret_cast<std::vector<VkSurfaceFormatKHR> &>(surface_priority_list);
	}
}

template <vkb::BindingType bindingType>
inline std::vector<typename VulkanSample<bindingType>::SurfaceFormatType> const &VulkanSample<bindingType>::get_surface_priority_list() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return surface_priority_list;
	}
	else
	{
		return reinterpret_cast<std::vector<VkSurfaceFormatKHR> const &>(surface_priority_list);
	}
}

template <vkb::BindingType bindingType>
inline vkb::core::Instance<bindingType> &VulkanSample<bindingType>::get_instance()
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *instance;
	}
	else
	{
		return reinterpret_cast<vkb::core::InstanceC &>(*instance);
	}
}

template <vkb::BindingType bindingType>
inline vkb::core::Instance<bindingType> const &VulkanSample<bindingType>::get_instance() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *instance;
	}
	else
	{
		return reinterpret_cast<vkb::core::InstanceC const &>(*instance);
	}
}

template <vkb::BindingType bindingType>
inline std::unordered_map<const char *, bool> const &VulkanSample<bindingType>::get_instance_extensions() const
{
	return instance_extensions;
}

template <vkb::BindingType bindingType>
inline std::unordered_map<const char *, bool> const &VulkanSample<bindingType>::get_instance_layers() const
{
	return instance_layers;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::add_instance_layer(const char *layer, bool optional)
{
	instance_layers[layer] = optional;
}

template <vkb::BindingType bindingType>
inline std::vector<typename VulkanSample<bindingType>::LayerSettingType> const &VulkanSample<bindingType>::get_layer_settings() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return layer_settings;
	}
	else
	{
		return reinterpret_cast<std::vector<VkLayerSettingEXT> const &>(layer_settings);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::RenderContextType const &VulkanSample<bindingType>::get_render_context() const
{
	assert(render_context && "Render context is not valid");
	if constexpr (bindingType == BindingType::Cpp)
	{
		return reinterpret_cast<vkb::rendering::HPPRenderContext const &>(*render_context);
	}
	else
	{
		return *render_context;
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::RenderContextType &VulkanSample<bindingType>::get_render_context()
{
	assert(render_context && "Render context is not valid");
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *render_context;
	}
	else
	{
		return reinterpret_cast<vkb::RenderContext &>(*render_context);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::RenderPipelineType const &VulkanSample<bindingType>::get_render_pipeline() const
{
	assert(render_pipeline && "Render pipeline was not created");
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *render_pipeline;
	}
	else
	{
		return reinterpret_cast<vkb::RenderPipeline const &>(*render_pipeline);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::RenderPipelineType &VulkanSample<bindingType>::get_render_pipeline()
{
	assert(render_pipeline && "Render pipeline was not created");
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *render_pipeline;
	}
	else
	{
		return reinterpret_cast<vkb::RenderPipeline &>(*render_pipeline);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::SceneType &VulkanSample<bindingType>::get_scene()
{
	assert(scene && "Scene not loaded");
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *scene;
	}
	else
	{
		return reinterpret_cast<vkb::sg::Scene &>(*scene);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::StatsType &VulkanSample<bindingType>::get_stats()
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return *stats;
	}
	else
	{
		return reinterpret_cast<vkb::Stats &>(*stats);
	}
}

template <vkb::BindingType bindingType>
inline typename VulkanSample<bindingType>::SurfaceType VulkanSample<bindingType>::get_surface() const
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		return surface;
	}
	else
	{
		return static_cast<VkSurfaceKHR>(surface);
	}
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::has_device() const
{
	return device != nullptr;
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::has_instance() const
{
	return instance != nullptr;
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::has_gui() const
{
	return gui != nullptr;
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::has_render_context() const
{
	return render_context != nullptr;
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::has_render_pipeline() const
{
	return render_pipeline != nullptr;
}

template <vkb::BindingType bindingType>
bool VulkanSample<bindingType>::has_scene()
{
	return scene != nullptr;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::input_event(const InputEvent &input_event)
{
	Parent::input_event(input_event);

	bool gui_captures_event = false;

	if (gui)
	{
		gui_captures_event = gui->input_event(input_event);
	}

	if (!gui_captures_event)
	{
		if (scene && scene->has_component<sg::Script>())
		{
			auto scripts = scene->get_components<sg::Script>();

			for (auto script : scripts)
			{
				script->input_event(input_event);
			}
		}
	}

	if (input_event.get_source() == EventSource::Keyboard)
	{
		const auto &key_event = static_cast<const KeyInputEvent &>(input_event);
		if (key_event.get_action() == KeyAction::Down &&
		    (key_event.get_code() == KeyCode::PrintScreen || key_event.get_code() == KeyCode::F12))
		{
			vkb::common::screenshot(*render_context, "screenshot-" + get_name());
		}
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::load_scene(const std::string &path)
{
	vkb::HPPGLTFLoader loader(*device);

	scene = loader.read_scene_from_file(path);

	if (!scene)
	{
		LOGE("Cannot load scene: {}", path.c_str());
		throw std::runtime_error("Cannot load scene: " + path);
	}
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::prepare(const ApplicationOptions &options)
{
	if (!Parent::prepare(options))
	{
		return false;
	}

	LOGI("Initializing Vulkan sample");

	                                                         
#if defined(_HPP_VULKAN_LIBRARY)
	static vk::detail::DynamicLoader dl(_HPP_VULKAN_LIBRARY);
#else
	static vk::detail::DynamicLoader dl;
#endif
	VULKAN_HPP_DEFAULT_DISPATCHER.init(dl.getProcAddress<PFN_vkGetInstanceProcAddr>("vkGetInstanceProcAddr"));

	bool headless = window->get_window_mode() == Window::Mode::Headless;

	                                                                                           
	VkResult result = volkInitialize();
	if (result)
	{
		throw VulkanException(result, "Failed to initialize volk.");
	}

	                               
	for (const char *extension_name : window->get_required_surface_extensions())
	{
		add_instance_extension(extension_name);
	}

#ifdef VKB_VULKAN_DEBUG
	{
		std::vector<vk::ExtensionProperties> available_instance_extensions = vk::enumerateInstanceExtensionProperties();
		auto                                 debugExtensionIt =
		    std::ranges::find_if(available_instance_extensions,
		                         [](vk::ExtensionProperties const &ep) { return strcmp(ep.extensionName, VK_EXT_DEBUG_UTILS_EXTENSION_NAME) == 0; });
		if (debugExtensionIt != available_instance_extensions.end())
		{
			LOGI("Vulkan debug utils enabled ({})", VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

			debug_utils = std::make_unique<vkb::core::HPPDebugUtilsExtDebugUtils>();
			add_instance_extension(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
		}
	}
#endif

	if constexpr (bindingType == BindingType::Cpp)
	{
		instance = create_instance();
	}
	else
	{
		instance.reset(reinterpret_cast<vkb::core::InstanceCpp *>(create_instance().release()));
	}

	                                                          
	VULKAN_HPP_DEFAULT_DISPATCHER.init(instance->get_handle());

	                                                   
	surface = static_cast<vk::SurfaceKHR>(window->create_surface(reinterpret_cast<vkb::core::InstanceC &>(*instance)));
	if (!surface)
	{
		throw std::runtime_error("Failed to create window surface.");
	}

	auto &gpu = instance->get_suitable_gpu(surface, headless);
	gpu.set_high_priority_graphics_queue_enable(high_priority_graphics_queue);

	                         
	if (gpu.get_features().textureCompressionASTC_LDR)
	{
		gpu.get_mutable_requested_features().textureCompressionASTC_LDR = true;
	}

	                                       
	if constexpr (bindingType == BindingType::Cpp)
	{
		request_gpu_features(gpu);
	}
	else
	{
		request_gpu_features(reinterpret_cast<vkb::core::PhysicalDeviceC &>(gpu));
	}

	                                                                    
	                                                                         
	{
		add_device_extension(VK_KHR_SWAPCHAIN_EXTENSION_NAME);

		if (instance_extensions.find(VK_KHR_DISPLAY_EXTENSION_NAME) != instance_extensions.end())
		{
			add_device_extension(VK_KHR_DISPLAY_SWAPCHAIN_EXTENSION_NAME,              true);
		}
	}

#ifdef VKB_ENABLE_PORTABILITY
	                                                                                                                             
	add_device_extension(VK_KHR_PORTABILITY_SUBSET_EXTENSION_NAME,              true);
#endif

#ifdef VKB_VULKAN_DEBUG
	if (!debug_utils)
	{
		std::vector<vk::ExtensionProperties> available_device_extensions = gpu.get_handle().enumerateDeviceExtensionProperties();
		auto                                 debugExtensionIt =
		    std::ranges::find_if(available_device_extensions,
		                         [](vk::ExtensionProperties const &ep) { return strcmp(ep.extensionName, VK_EXT_DEBUG_MARKER_EXTENSION_NAME) == 0; });
		if (debugExtensionIt != available_device_extensions.end())
		{
			LOGI("Vulkan debug utils enabled ({})", VK_EXT_DEBUG_MARKER_EXTENSION_NAME);

			debug_utils = std::make_unique<vkb::core::HPPDebugMarkerExtDebugUtils>();
			add_device_extension(VK_EXT_DEBUG_MARKER_EXTENSION_NAME);
		}
	}

	if (!debug_utils)
	{
		LOGW("Vulkan debug utils were requested, but no extension that provides them was found");
	}
#endif

	if (!debug_utils)
	{
		debug_utils = std::make_unique<vkb::core::HPPDummyDebugUtils>();
	}

	if constexpr (bindingType == BindingType::Cpp)
	{
		device = create_device(gpu);
	}
	else
	{
		device.reset(reinterpret_cast<vkb::core::DeviceCpp *>(create_device(reinterpret_cast<vkb::core::PhysicalDeviceC &>(gpu)).release()));
	}

	                                                                  
	VULKAN_HPP_DEFAULT_DISPATCHER.init(device->get_handle());

	create_render_context();
	prepare_render_context();

	stats = std::make_unique<vkb::stats::HPPStats>(*render_context);

	                                                  
	configuration.reset();

	return true;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::create_gui(const Window &window, StatsType const *stats, const float font_size, bool explicit_update)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		gui = std::make_unique<vkb::GuiCpp>(get_render_context(), window, stats, font_size, explicit_update);
	}
	else
	{
		gui = std::make_unique<vkb::GuiCpp>(reinterpret_cast<vkb::rendering::HPPRenderContext &>(get_render_context()),
		                                    window,
		                                    reinterpret_cast<vkb::stats::HPPStats const *>(stats),
		                                    font_size,
		                                    explicit_update);
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::prepare_render_context()
{
	render_context->prepare();
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::render(vkb::core::CommandBuffer<bindingType> &command_buffer)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		render_impl(command_buffer);
	}
	else
	{
		render_impl(reinterpret_cast<vkb::core::CommandBufferCpp &>(command_buffer));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::render_impl(vkb::core::CommandBufferCpp &command_buffer)
{
	if (render_pipeline)
	{
		render_pipeline->draw(command_buffer, render_context->get_active_frame().get_render_target());
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::request_gpu_features(vkb::core::PhysicalDevice<bindingType> &gpu)
{
	                             
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::reset_stats_view()
{
}

template <vkb::BindingType bindingType>
inline bool VulkanSample<bindingType>::resize(uint32_t width, uint32_t height)
{
	if (!Parent::resize(width, height))
	{
		return false;
	}

	if (gui)
	{
		gui->resize(width, height);
	}

	if (scene && scene->has_component<sg::Script>())
	{
		auto scripts = scene->get_components<sg::Script>();

		for (auto script : scripts)
		{
			script->resize(width, height);
		}
	}

	if (stats)
	{
		stats->resize(width);
	}
	return true;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_api_version(uint32_t requested_api_version)
{
	api_version = requested_api_version;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_high_priority_graphics_queue_enable(bool enable)
{
	high_priority_graphics_queue = enable;
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_render_context(std::unique_ptr<RenderContextType> &&rc)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		render_context.reset(rc.release());
	}
	else
	{
		render_context.reset(reinterpret_cast<vkb::rendering::HPPRenderContext *>(rc.release()));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_render_pipeline(std::unique_ptr<RenderPipelineType> &&rp)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		render_pipeline.reset(rp.release());
	}
	else
	{
		render_pipeline.reset(reinterpret_cast<vkb::rendering::HPPRenderPipeline *>(rp.release()));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_viewport_and_scissor(vkb::core::CommandBuffer<bindingType> const &command_buffer, Extent2DType const &extent)
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		set_viewport_and_scissor_impl(command_buffer, extent);
	}
	else
	{
		set_viewport_and_scissor_impl(reinterpret_cast<vkb::core::CommandBufferCpp const &>(command_buffer),
		                              reinterpret_cast<vk::Extent2D const &>(extent));
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::set_viewport_and_scissor_impl(vkb::core::CommandBufferCpp const &command_buffer,
                                                                     vk::Extent2D const                &extent)
{
	command_buffer.get_handle().setViewport(0, {{0.0f, 0.0f, static_cast<float>(extent.width), static_cast<float>(extent.height), 0.0f, 1.0f}});
	command_buffer.get_handle().setScissor(0, vk::Rect2D{{}, extent});
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::update(float delta_time)
{
	vkb::Application::update(delta_time);

	update_scene(delta_time);

	update_gui(delta_time);

	auto command_buffer = render_context->begin();

	                                                     
	update_stats(delta_time);

	command_buffer->begin(vk::CommandBufferUsageFlagBits::eOneTimeSubmit);
	stats->begin_sampling(*command_buffer);

	if constexpr (bindingType == BindingType::Cpp)
	{
		draw(*command_buffer, render_context->get_active_frame().get_render_target());
	}
	else
	{
		draw(reinterpret_cast<vkb::core::CommandBufferC &>(*command_buffer),
		     reinterpret_cast<vkb::RenderTarget &>(render_context->get_active_frame().get_render_target()));
	}

	stats->end_sampling(*command_buffer);
	command_buffer->end();

	render_context->submit(*command_buffer);
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::update_debug_window()
{
	auto        driver_version     = device->get_gpu().get_driver_version();
	std::string driver_version_str = fmt::format("major: {} minor: {} patch: {}", driver_version.major, driver_version.minor, driver_version.patch);

	get_debug_info().template insert<field::Static, std::string>("driver_version", driver_version_str);
	get_debug_info().template insert<field::Static, std::string>("resolution",
	                                                             to_string(static_cast<VkExtent2D const &>(render_context->get_swapchain().get_extent())));
	get_debug_info().template insert<field::Static, std::string>("surface_format",
	                                                             to_string(render_context->get_swapchain().get_format()) + " (" +
	                                                                 to_string(vkb::common::get_bits_per_pixel(render_context->get_swapchain().get_format())) +
	                                                                 "bpp)");

	if (scene != nullptr)
	{
		get_debug_info().template insert<field::Static, uint32_t>("mesh_count", to_u32(scene->get_components<sg::SubMesh>().size()));
		get_debug_info().template insert<field::Static, uint32_t>("texture_count", to_u32(scene->get_components<sg::Texture>().size()));

		if (auto camera = scene->get_components<vkb::sg::Camera>()[0])
		{
			if (auto camera_node = camera->get_node())
			{
				const glm::vec3 &pos = camera_node->get_transform().get_translation();
				get_debug_info().template insert<field::Vector, float>("camera_pos", pos.x, pos.y, pos.z);
			}
		}
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::update_gui(float delta_time)
{
	if (gui)
	{
		if (gui->is_debug_view_active())
		{
			update_debug_window();
		}

		gui->new_frame();

		gui->show_top_window(get_name(), stats.get(), &get_debug_info());

		                            
		draw_gui();

		gui->update(delta_time);
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::update_scene(float delta_time)
{
	if (scene)
	{
		                 
		if (scene->has_component<sg::Script>())
		{
			auto scripts = scene->get_components<sg::Script>();

			for (auto script : scripts)
			{
				script->update(delta_time);
			}
		}

		                    
		if (scene->has_component<sg::Animation>())
		{
			auto animations = scene->get_components<sg::Animation>();

			for (auto animation : animations)
			{
				animation->update(delta_time);
			}
		}
	}
}

template <vkb::BindingType bindingType>
inline void VulkanSample<bindingType>::update_stats(float delta_time)
{
	if (stats)
	{
		stats->update(delta_time);

		static float stats_view_count = 0.0f;
		stats_view_count += delta_time;

		                                            
		if (stats_view_count > STATS_VIEW_RESET_TIME)
		{
			reset_stats_view();
			stats_view_count = 0.0f;
		}
	}
}

}                        
