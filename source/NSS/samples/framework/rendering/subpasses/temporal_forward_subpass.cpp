/* Copyright (c) 2026, Arm Limited and Contributors
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

#include "rendering/subpasses/temporal_forward_subpass.h"

#include <algorithm>

#include <vulkan/vulkan.h>

#include "common/utils.h"
#include "rendering/subpass.h"
#include "scene_graph/components/camera.h"
#include "scene_graph/node.h"

namespace vkb
{
TemporalForwardSubpass::TemporalForwardSubpass(RenderContext &render_context,
                                              ShaderSource &&vertex_shader,
                                              ShaderSource &&fragment_shader,
                                              sg::Scene &scene,
                                              sg::Camera &camera) :
    ForwardSubpass(render_context, std::move(vertex_shader), std::move(fragment_shader), scene, camera)
{
}

void TemporalForwardSubpass::prepare()
{
	ForwardSubpass::prepare();
	prepare_halton_sequence();
}

void TemporalForwardSubpass::set_jitter_scale(float scale)
{
	jitter_scale = std::max(0.0f, scale);
}

float TemporalForwardSubpass::get_jitter_scale() const
{
	return jitter_scale;
}

glm::vec2 TemporalForwardSubpass::get_current_jitter_pixels() const
{
	return current_jitter_pixels;
}

glm::vec2 TemporalForwardSubpass::get_current_jitter_pixels_scaled() const
{
	return current_jitter_pixels * jitter_scale;
}

void TemporalForwardSubpass::set_external_jitter(const glm::vec2 &jitter_pixels)
{
	external_jitter_pixels = jitter_pixels;
}

void TemporalForwardSubpass::clear_external_jitter()
{
	external_jitter_pixels = std::nullopt;
}

uint32_t TemporalForwardSubpass::peek_frame_index() const
{
	return frame_index;
}

glm::mat4 TemporalForwardSubpass::get_view_projection() const
{
	return camera.get_pre_rotation() *
	       vkb::rendering::vulkan_style_projection(camera.get_projection()) *
	       camera.get_view();
}

void TemporalForwardSubpass::set_velocity_stride(uint32_t stride)
{
	velocity_stride = (stride >= 2) ? 2 : 1;
}

void TemporalForwardSubpass::set_mipmap_lod_bias(float bias)
{
	mipmap_lod_bias = bias;
}

                             
float TemporalForwardSubpass::create_halton_sequence(int32_t Index, int32_t Base)
{
	float Result = 0.0f;
	float InvBase = 1.0f / float(Base);
	float Fraction = InvBase;
	while (Index > 0)
	{
		Result += float(Index % Base) * Fraction;
		Index /= Base;
		Fraction *= InvBase;
	}
	return Result;
}

void TemporalForwardSubpass::prepare_halton_sequence()
{
	                                                    
	halton_sequence.clear();
	halton_sequence.reserve(MAX_TAA_SAMPLES);

	for (int i = 1; i <= MAX_TAA_SAMPLES; ++i)
	{
		glm::vec2 offset;

		                                         
		offset.x = create_halton_sequence(i, 2);                       
		offset.y = create_halton_sequence(i, 3);                       

		                                                     
		offset.x -= 0.5f;
		offset.y -= 0.5f;

		halton_sequence.push_back(offset);
	}
}


void TemporalForwardSubpass::update_jitter_settings_buffer()
{
	auto &render_frame = get_render_context().get_active_frame();

	VkExtent2D extent = get_render_target_extent();

	                                                                      
	if (external_jitter_pixels.has_value())
	{
		current_jitter_pixels = *external_jitter_pixels;
	}
	else
	{
		uint32_t jitter_index  = frame_index % MAX_TAA_SAMPLES;
		current_jitter_pixels = halton_sequence[jitter_index];
	}


	                                                                     
	                                                                        
	glm::vec2 ndc_jitter_offset = glm::vec2(
	    current_jitter_pixels.x * (2.0f / extent.width),
	    current_jitter_pixels.y * (2.0f / extent.height));

	                                                                     
	auto current_view_proj = get_view_projection();

	if (first_frame)
	{
		prev_view_proj_matrix      = current_view_proj;
		prev_prev_view_proj_matrix = current_view_proj;
	}

	                                                                    
	glm::mat4 jittered_projection = camera.get_projection();
	jittered_projection[2][0] += ndc_jitter_offset.x * jitter_scale;
	jittered_projection[2][1] += ndc_jitter_offset.y * jitter_scale;

	auto jitter_view_proj = camera.get_pre_rotation() *
	                     vkb::rendering::vulkan_style_projection(jittered_projection) *
	                     camera.get_view();

	                                                               
	JitterSettings jitter_settings_data{};
	jitter_settings_data.jitter_view_proj  = jitter_view_proj;
	                                                                       
	                                                               
	jitter_settings_data.prev_view_proj    = (velocity_stride >= 2) ? prev_prev_view_proj_matrix : prev_view_proj_matrix;
	jitter_settings_data.current_view_proj = current_view_proj;

	jitter_settings_allocation = render_frame.allocate_buffer(VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, sizeof(JitterSettings));
	jitter_settings_allocation.update(jitter_settings_data);

	prev_prev_view_proj_matrix = prev_view_proj_matrix;
	prev_view_proj_matrix      = current_view_proj;
	first_frame                = false;
}

void TemporalForwardSubpass::update_uniform(vkb::core::CommandBufferC &command_buffer, vkb::sg::Node &node, size_t thread_index)
{
	                                                                                   
	ForwardSubpass::update_uniform(command_buffer, node, thread_index);

	                                        
	if (!jitter_settings_allocation.empty())
	{
		auto &alloc = jitter_settings_allocation;
		command_buffer.bind_buffer(alloc.get_buffer(), alloc.get_offset(), alloc.get_size(), 0, 2, 0);
	}

	                                                                    
	auto current_transform = node.get_transform().get_world_matrix();
	auto &motion = node_motion_data[&node];
	if (!motion.initialized)
	{
		motion.previous_transform = current_transform;
		motion.current_transform  = current_transform;
		motion.prev_prev_transform = current_transform;
		motion.initialized        = true;
	}
	else if (motion.last_update_frame != frame_index)
	{
		motion.prev_prev_transform = motion.previous_transform;
		motion.previous_transform = motion.current_transform;
		motion.current_transform  = current_transform;
	}
	else
	{
		motion.current_transform = current_transform;
	}
	motion.last_update_frame = frame_index;

	                                             
	auto &render_frame        = get_render_context().get_active_frame();
	auto  velocity_allocation = render_frame.allocate_buffer(VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, sizeof(VelocitySettings), thread_index);

	VelocitySettings velocity_data{};
	                                                                 
	                                                              
	velocity_data.prev_model    = (velocity_stride >= 2) ? motion.prev_prev_transform : motion.previous_transform;
	velocity_data.current_model = motion.current_transform;

	velocity_allocation.update(velocity_data);

	command_buffer.bind_buffer(velocity_allocation.get_buffer(), velocity_allocation.get_offset(), velocity_allocation.get_size(), 0, 3, 0);
}

void TemporalForwardSubpass::draw(vkb::core::CommandBufferC &command_buffer)
{
	update_jitter_settings_buffer();

	command_buffer.set_specialization_constant(3, mipmap_lod_bias);

	ForwardSubpass::draw(command_buffer);

	frame_index++;
}

}                        
