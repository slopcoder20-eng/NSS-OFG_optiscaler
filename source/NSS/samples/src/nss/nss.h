/* Copyright (c) 2025-2026, Arm Limited and Contributors
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

#include <cmath>
#include <cstdint>
#include <memory>
#include <vector>

#include <vulkan/vulkan.h>

#include "common/vk_common.h"                      
#include "vulkan_sample.h"

                             
#ifndef FFX_CPU
#define FFX_CPU
#endif

#include <ffx_api_types.h>
#include <ffx_api.hpp>
#include <ffx_nss.hpp>
#include <vk/ffx_api_vk.hpp>

namespace vkb
{
class TemporalForwardSubpass;
class RenderPipeline;
class PostProcessingPipeline;

namespace core
{
class Image;
class ImageView;
}                         

namespace sg
{
class PerspectiveCamera;
}                       
}

class NSSSample : public vkb::VulkanSampleC
{
  public:
	NSSSample();
	virtual ~NSSSample() override;

	virtual bool prepare(const vkb::ApplicationOptions &options) override;
	virtual void update(float delta_time) override;
	virtual void draw_gui() override;
	virtual void draw(vkb::core::CommandBufferC &command_buffer, vkb::RenderTarget &render_target) override;
	virtual void request_gpu_features(vkb::core::PhysicalDeviceC &gpu) override;

	   
                                                 
                                                               
    
	struct ResolutionConfig
	{
		VkExtent2D display_extent;
		VkExtent2D render_extent;
		float      scale_factor;
		float      mipmap_lod_bias;

		   
                                                                         
     
		static ResolutionConfig create(const VkExtent2D &display, float scale)
		{
			ResolutionConfig config;
			config.display_extent = display;
			config.scale_factor   = scale;

			config.render_extent.width  = static_cast<uint32_t>(display.width / scale);
			config.render_extent.height = static_cast<uint32_t>(display.height / scale);

			config.mipmap_lod_bias = -std::log2(scale);

			return config;
		}
	};

	   
                                                                     
    
	enum class DisplayMode : uint32_t
	{
		FinalOutput  = 0,
		NSSDebugView = 1
	};


  private:
	vkb::sg::PerspectiveCamera                  *camera{nullptr};
	std::unique_ptr<vkb::RenderPipeline>         scene_pipeline{};
	std::unique_ptr<vkb::PostProcessingPipeline> postprocessing_pipeline{};
	vkb::TemporalForwardSubpass                 *temporal_subpass{nullptr};

	ResolutionConfig resolution_config{};
	DisplayMode      display_mode{DisplayMode::FinalOutput};

	bool first_frame{true};

	                                                 
	                                           
	enum class Attachments : int
	{
		Depth    = 0,
		Color    = 1,
		Velocity = 2
	};

	std::vector<vkb::LoadStoreInfo>                 scene_load_store{};
	std::vector<std::unique_ptr<vkb::RenderTarget>> low_res_render_targets;

	void create_low_res_render_targets();

	                                                    
	bool nss_enabled{false};

	bool use_fragment_path = true;
	struct FragOrCompConfig
	{
		VkImageUsageFlags    output_usage_bit;                                                                
		uint32_t             context_flags;                                                           
		VkPipelineStageFlags input_read_stage;                                     
		VkPipelineStageFlags output_write_stage;                                        
		VkAccessFlags        output_write_access;                                              
		FfxApiResourceState  input_read_state;                                           
	};
	FragOrCompConfig frag_or_comp_config{};

	                                                                                 
	bool                       nss_force_disabled{false};
	uint32_t                   nss_override_flags{0};
	float                      nss_scale_factor{2.0f};
	FfxApiNssShaderQualityMode nss_quality_mode{FFX_API_NSS_SHADER_QUALITY_MODE_BALANCED};
	uint32_t                   nss_debug_view_mode{0};
	uint32_t                   nss_jitter_phase_count{0};

	float last_delta_time{0.016f};

	ffxContext nss_context{nullptr};

	std::vector<std::unique_ptr<vkb::core::Image>>     nss_output_images;
	std::vector<std::unique_ptr<vkb::core::ImageView>> nss_output_views;

	std::vector<std::unique_ptr<vkb::core::Image>>     nss_debug_images;
	std::vector<std::unique_ptr<vkb::core::ImageView>> nss_debug_views;

	void create_nss_output_images();
	void initialize_nss_context(const VkExtent2D &low_res_extent, const VkExtent2D &display_extent);

	                                                    
	FfxApiResource wrap_resource(const vkb::core::Image &image, FfxApiResourceState state, uint32_t additional_usages = 0);

	                                                   
	bool use_nss_jitter_sequence{true};                                                                
};

std::unique_ptr<vkb::VulkanSampleC> create_nss();