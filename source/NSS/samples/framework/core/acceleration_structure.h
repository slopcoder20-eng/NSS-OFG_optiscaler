/* Copyright (c) 2021-2025, Sascha Willems
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
#include "core/buffer.h"

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceC = Device<vkb::BindingType::C>;

   
                                                                                              
   
class AccelerationStructure
{
  public:
	   
                                                                                            
                                       
                                                                             
    
	AccelerationStructure(vkb::core::DeviceC            &device,
	                      VkAccelerationStructureTypeKHR type);

	~AccelerationStructure();

	   
                                                                                             
                                                                                                     
                                                   
                                                 
                                                            
                                                               
                                                              
                                                       
                                                                                
                                                       
                                         
                                           
                                                                                           
                                                                                         
                                                                                                 
    
	uint64_t add_triangle_geometry(vkb::core::BufferC &vertex_buffer,
	                               vkb::core::BufferC &index_buffer,
	                               vkb::core::BufferC &transform_buffer,
	                               uint32_t            triangle_count,
	                               uint32_t            max_vertex,
	                               VkDeviceSize        vertex_stride,
	                               uint32_t            transform_offset              = 0,
	                               VkFormat            vertex_format                 = VK_FORMAT_R32G32B32_SFLOAT,
	                               VkIndexType         index_type                    = VK_INDEX_TYPE_UINT32,
	                               VkGeometryFlagsKHR  flags                         = VK_GEOMETRY_OPAQUE_BIT_KHR,
	                               uint64_t            vertex_buffer_data_address    = 0,
	                               uint64_t            index_buffer_data_address     = 0,
	                               uint64_t            transform_buffer_data_address = 0);

	void update_triangle_geometry(uint64_t triangleUUID, std::unique_ptr<vkb::core::BufferC> &vertex_buffer,
	                              std::unique_ptr<vkb::core::BufferC> &index_buffer,
	                              std::unique_ptr<vkb::core::BufferC> &transform_buffer,
	                              uint32_t                             triangle_count,
	                              uint32_t                             max_vertex,
	                              VkDeviceSize                         vertex_stride,
	                              uint32_t                             transform_offset              = 0,
	                              VkFormat                             vertex_format                 = VK_FORMAT_R32G32B32_SFLOAT,
	                              VkGeometryFlagsKHR                   flags                         = VK_GEOMETRY_OPAQUE_BIT_KHR,
	                              uint64_t                             vertex_buffer_data_address    = 0,
	                              uint64_t                             index_buffer_data_address     = 0,
	                              uint64_t                             transform_buffer_data_address = 0);

	   
                                                                                          
                                                               
                                                      
                                                               
                                                                                
                                           
    
	uint64_t add_instance_geometry(std::unique_ptr<vkb::core::BufferC> &instance_buffer,
	                               uint32_t                             instance_count,
	                               uint32_t                             transform_offset = 0,
	                               VkGeometryFlagsKHR                   flags            = VK_GEOMETRY_OPAQUE_BIT_KHR);

	void update_instance_geometry(uint64_t instance_UID, std::unique_ptr<vkb::core::BufferC> &instance_buffer,
	                              uint32_t           instance_count,
	                              uint32_t           transform_offset = 0,
	                              VkGeometryFlagsKHR flags            = VK_GEOMETRY_OPAQUE_BIT_KHR);

	   
                                                                                                       
                                                   
                            
                                            
    
	void build(VkQueue                              queue,
	           VkBuildAccelerationStructureFlagsKHR flags = VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR,
	           VkBuildAccelerationStructureModeKHR  mode  = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR);

	VkAccelerationStructureKHR get_handle() const;

	const VkAccelerationStructureKHR *get() const;

	uint64_t get_device_address() const;

	vkb::core::BufferC *get_buffer() const
	{
		return buffer.get();
	}

	void resetGeometries()
	{
		geometries.clear();
	}

  private:
	vkb::core::DeviceC &device;

	VkAccelerationStructureKHR handle{VK_NULL_HANDLE};

	uint64_t device_address{0};

	VkAccelerationStructureTypeKHR type{};

	VkAccelerationStructureBuildSizesInfoKHR build_sizes_info{};

	struct Geometry
	{
		VkAccelerationStructureGeometryKHR geometry{};
		uint32_t                           primitive_count{};
		uint32_t                           transform_offset{};
		bool                               updated = false;
	};

	std::unique_ptr<vkb::core::BufferC> scratch_buffer;

	std::map<uint64_t, Geometry> geometries{};

	std::unique_ptr<vkb::core::BufferC> buffer{nullptr};
};
}                         
}                        