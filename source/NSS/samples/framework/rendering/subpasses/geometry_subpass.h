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

#include "common/error.h"

#include "common/glm_common.h"

#include "rendering/subpass.h"

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferC = CommandBuffer<vkb::BindingType::C>;
}                         

namespace sg
{
class Scene;
class Node;
class Mesh;
class SubMesh;
class Camera;
}                       

   
                                                  
   
struct alignas(16) GlobalUniform
{
	glm::mat4 model;

	glm::mat4 camera_view_proj;

	glm::vec3 camera_position;
};

   
                                              
   
struct PBRMaterialUniform
{
	glm::vec4 base_color_factor;

	float metallic_factor;

	float roughness_factor;
};

   
                                                           
   
class GeometrySubpass : public vkb::rendering::SubpassC
{
  public:
	   
                                                                           
                                        
                                             
                                                 
                                                
                                                  
    
	GeometrySubpass(RenderContext &render_context, ShaderSource &&vertex_shader, ShaderSource &&fragment_shader, sg::Scene &scene, sg::Camera &camera);

	virtual ~GeometrySubpass() = default;

	virtual void prepare() override;

	   
                               
    
	virtual void draw(vkb::core::CommandBufferC &command_buffer) override;

	   
                                                       
    
	void set_thread_index(uint32_t index);

  protected:
	virtual void update_uniform(vkb::core::CommandBufferC &command_buffer, sg::Node &node, size_t thread_index);

	void draw_submesh(vkb::core::CommandBufferC &command_buffer, sg::SubMesh &sub_mesh, VkFrontFace front_face = VK_FRONT_FACE_COUNTER_CLOCKWISE);

	virtual void prepare_pipeline_state(vkb::core::CommandBufferC &command_buffer, VkFrontFace front_face, bool double_sided_material);

	virtual PipelineLayout &prepare_pipeline_layout(vkb::core::CommandBufferC         &command_buffer,
	                                                const std::vector<ShaderModule *> &shader_modules);

	virtual void prepare_push_constants(vkb::core::CommandBufferC &command_buffer, sg::SubMesh &sub_mesh);

	virtual void draw_submesh_command(vkb::core::CommandBufferC &command_buffer, sg::SubMesh &sub_mesh);

	   
                                                                          
                                                             
    
	void get_sorted_nodes(std::multimap<float, std::pair<sg::Node *, sg::SubMesh *>> &opaque_nodes,
	                      std::multimap<float, std::pair<sg::Node *, sg::SubMesh *>> &transparent_nodes);

	sg::Camera &camera;

	std::vector<sg::Mesh *> meshes;

	sg::Scene &scene;

	uint32_t thread_index{0};

	vkb::RasterizationState base_rasterization_state{};
};

}                        
