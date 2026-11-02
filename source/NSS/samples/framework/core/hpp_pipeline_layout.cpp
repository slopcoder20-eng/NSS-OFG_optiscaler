/* Copyright (c) 2023-2025, NVIDIA CORPORATION. All rights reserved.
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

#include "hpp_pipeline_layout.h"
#include "core/device.h"

#include <core/hpp_shader_module.h>

namespace vkb
{
namespace core
{
HPPPipelineLayout::HPPPipelineLayout(vkb::core::DeviceCpp &device, const std::vector<vkb::core::HPPShaderModule *> &shader_modules) :
    device{device},
    shader_modules{shader_modules}
{
	                                                                               
	                                                                          
	for (auto *shader_module : shader_modules)
	{
		for (const auto &shader_resource : shader_module->get_resources())
		{
			std::string key = shader_resource.name;

			                                                                                        
			if (shader_resource.type == vkb::core::HPPShaderResourceType::Input || shader_resource.type == vkb::core::HPPShaderResourceType::Output)
			{
				key = std::to_string(static_cast<uint32_t>(shader_resource.stages)) + "_" + key;
			}

			auto it = shader_resources.find(key);

			if (it != shader_resources.end())
			{
				                                                
				it->second.stages |= shader_resource.stages;
			}
			else
			{
				                                
				shader_resources.emplace(key, shader_resource);
			}
		}
	}

	                                                        
	                                           
	for (auto &it : shader_resources)
	{
		auto &shader_resource = it.second;

		                                        
		auto it2 = shader_sets.find(shader_resource.set);

		if (it2 != shader_sets.end())
		{
			                                      
			it2->second.push_back(shader_resource);
		}
		else
		{
			                                                     
			shader_sets.emplace(shader_resource.set, std::vector<vkb::core::HPPShaderResource>{shader_resource});
		}
	}

	                                                                           
	for (auto &shader_set_it : shader_sets)
	{
		descriptor_set_layouts.emplace_back(
		    &device.get_resource_cache().request_descriptor_set_layout(shader_set_it.first, shader_modules, shader_set_it.second));
	}

	                                                                       
	std::vector<vk::DescriptorSetLayout> descriptor_set_layout_handles;
	for (auto descriptor_set_layout : descriptor_set_layouts)
	{
		descriptor_set_layout_handles.push_back(descriptor_set_layout ? descriptor_set_layout->get_handle() : nullptr);
	}

	                                                 
	std::vector<vk::PushConstantRange> push_constant_ranges;
	for (auto &push_constant_resource : get_resources(vkb::core::HPPShaderResourceType::PushConstant))
	{
		push_constant_ranges.push_back({push_constant_resource.stages, push_constant_resource.offset, push_constant_resource.size});
	}

	vk::PipelineLayoutCreateInfo create_info{.setLayoutCount         = static_cast<uint32_t>(descriptor_set_layout_handles.size()),
	                                         .pSetLayouts            = descriptor_set_layout_handles.data(),
	                                         .pushConstantRangeCount = static_cast<uint32_t>(push_constant_ranges.size()),
	                                         .pPushConstantRanges    = push_constant_ranges.data()};

	                                           
	handle = device.get_handle().createPipelineLayout(create_info);
}

HPPPipelineLayout::HPPPipelineLayout(HPPPipelineLayout &&other) :
    device{other.device},
    handle{other.handle},
    shader_modules{std::move(other.shader_modules)},
    shader_resources{std::move(other.shader_resources)},
    shader_sets{std::move(other.shader_sets)},
    descriptor_set_layouts{std::move(other.descriptor_set_layouts)}
{
	other.handle = nullptr;
}

HPPPipelineLayout::~HPPPipelineLayout()
{
	                          
	if (handle)
	{
		device.get_handle().destroyPipelineLayout(handle);
	}
}

vkb::core::HPPDescriptorSetLayout const &HPPPipelineLayout::get_descriptor_set_layout(const uint32_t set_index) const
{
	auto it = std::ranges::find_if(descriptor_set_layouts,
	                               [&set_index](auto const *descriptor_set_layout) { return descriptor_set_layout->get_index() == set_index; });
	if (it == descriptor_set_layouts.end())
	{
		throw std::runtime_error("Couldn't find descriptor set layout at set index " + to_string(set_index));
	}
	return **it;
}

vk::PipelineLayout HPPPipelineLayout::get_handle() const
{
	return handle;
}

vk::ShaderStageFlags HPPPipelineLayout::get_push_constant_range_stage(uint32_t size, uint32_t offset) const
{
	vk::ShaderStageFlags stages;

	for (auto &push_constant_resource : get_resources(vkb::core::HPPShaderResourceType::PushConstant))
	{
		if (push_constant_resource.offset <= offset && offset + size <= push_constant_resource.offset + push_constant_resource.size)
		{
			stages |= push_constant_resource.stages;
		}
	}
	return stages;
}

std::vector<vkb::core::HPPShaderResource> HPPPipelineLayout::get_resources(const vkb::core::HPPShaderResourceType &type, vk::ShaderStageFlagBits stage) const
{
	std::vector<vkb::core::HPPShaderResource> found_resources;

	for (auto &it : shader_resources)
	{
		auto &shader_resource = it.second;

		if (shader_resource.type == type || type == vkb::core::HPPShaderResourceType::All)
		{
			if (shader_resource.stages == stage || stage == vk::ShaderStageFlagBits::eAll)
			{
				found_resources.push_back(shader_resource);
			}
		}
	}

	return found_resources;
}

const std::vector<vkb::core::HPPShaderModule *> &HPPPipelineLayout::get_shader_modules() const
{
	return shader_modules;
}

const std::unordered_map<uint32_t, std::vector<vkb::core::HPPShaderResource>> &HPPPipelineLayout::get_shader_sets() const
{
	return shader_sets;
}

bool HPPPipelineLayout::has_descriptor_set_layout(const uint32_t set_index) const
{
	return set_index < descriptor_set_layouts.size();
}

}                         
}                        
