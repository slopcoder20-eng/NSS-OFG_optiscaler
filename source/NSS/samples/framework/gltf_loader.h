/* Copyright (c) 2018-2025, Arm Limited and Contributors
 * Copyright (c) 2019-2025, Sascha Willems
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
#include <memory>
#include <mutex>

#define TINYGLTF_NO_STB_IMAGE
#define TINYGLTF_NO_STB_IMAGE_WRITE
#define TINYGLTF_NO_EXTERNAL_IMAGE
#include <tiny_gltf.h>

#include "timer.h"

#include "vulkan/vulkan.h"

#define KHR_LIGHTS_PUNCTUAL_EXTENSION "KHR_lights_punctual"

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceCpp = Device<vkb::BindingType::Cpp>;
using DeviceC   = Device<vkb::BindingType::C>;
}                         

namespace sg
{
class Camera;
class Image;
class Light;
class Mesh;
class Node;
class PBRMaterial;
class Sampler;
class Scene;
class SubMesh;
class Texture;
}                       

   
                                                                
                                                                                                           
           
           
   
template <class T, class Y>
struct TypeCast
{
	Y operator()(T value) const noexcept
	{
		return static_cast<Y>(value);
	}
};

                                                                         
                                                                                   
                                                                    
class GLTFLoader
{
  public:
	GLTFLoader(vkb::core::DeviceC &device);

	virtual ~GLTFLoader() = default;

	std::unique_ptr<sg::Scene> read_scene_from_file(const std::string &file_name, int scene_index = -1, VkBufferUsageFlags additional_buffer_usage_flags = 0);

	   
                                                                            
                                                                  
    
	std::unique_ptr<sg::SubMesh> read_model_from_file(const std::string &file_name, uint32_t index, bool storage_buffer = false, VkBufferUsageFlags additional_buffer_usage_flags = 0);

  protected:
	virtual std::unique_ptr<sg::Node> parse_node(const tinygltf::Node &gltf_node, size_t index) const;

	virtual std::unique_ptr<sg::Camera> parse_camera(const tinygltf::Camera &gltf_camera) const;

	virtual std::unique_ptr<sg::Mesh> parse_mesh(const tinygltf::Mesh &gltf_mesh) const;

	virtual std::unique_ptr<sg::PBRMaterial> parse_material(const tinygltf::Material &gltf_material) const;

	virtual std::unique_ptr<sg::Image> parse_image(tinygltf::Image &gltf_image) const;

	virtual std::unique_ptr<sg::Sampler> parse_sampler(const tinygltf::Sampler &gltf_sampler) const;

	virtual std::unique_ptr<sg::Texture> parse_texture(const tinygltf::Texture &gltf_texture) const;

	virtual std::unique_ptr<sg::PBRMaterial> create_default_material();

	virtual std::unique_ptr<sg::Sampler> create_default_sampler(int filter);

	virtual std::unique_ptr<sg::Camera> create_default_camera();

	   
                                                                                                 
    
	std::vector<std::unique_ptr<sg::Light>> parse_khr_lights_punctual();

	   
                                                                                                  
                                                     
                                                                                                                
    
	bool is_extension_enabled(const std::string &requested_extension);

	   
                                                                                                   
                                                                                        
                                           
                                                                                      
    
	tinygltf::Value *get_extension(tinygltf::ExtensionMap &tinygltf_extensions, const std::string &extension);

	vkb::core::DeviceC &device;

	tinygltf::Model model;

	std::string model_path;

	                                                                                               
	static std::unordered_map<std::string, bool> supported_extensions;

  private:
	sg::Scene load_scene(int scene_index = -1, VkBufferUsageFlags additional_buffer_usage_flags = 0);

	std::unique_ptr<sg::SubMesh> load_model(uint32_t index, bool storage_buffer = false, VkBufferUsageFlags additional_buffer_usage_flags = 0);
};
}                        
