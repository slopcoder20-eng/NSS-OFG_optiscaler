/* Copyright (c) 2018-2025, Arm Limited and Contributors
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
#include "glm/gtx/quaternion.hpp"

#include "filesystem/legacy.h"
#include "rendering/pipeline_state.h"
#include "rendering/render_context.h"
#include "scene_graph/components/sub_mesh.h"
#include "scene_graph/scene.h"

namespace vkb
{
   
                                            
                                            
                        
   
std::string get_extension(const std::string &uri);
   
                                        
              
                                     
   
size_t calculate_hash(const std::vector<uint8_t> &data);

   
                                              
                                             
   
std::string to_snake_case(const std::string &name);

   
                                                                                              
                                                 
                                                             
   
void screenshot(RenderContext &render_context, const std::string &filename);

   
                                                                 
                                             
                             
                                            
                                            
                                                                 
                                                                    
                                            
   
sg::Light &add_light(sg::Scene &scene, sg::LightType type, const glm::vec3 &position, const glm::quat &rotation = {}, const sg::LightProperties &props = {}, sg::Node *parent_node = nullptr);

   
                                                                       
                                             
                                            
                                                                 
                                                                    
                                            
   
sg::Light &add_point_light(sg::Scene &scene, const glm::vec3 &position, const sg::LightProperties &props = {}, sg::Node *parent_node = nullptr);

   
                                                                             
                                             
                                            
                                                                 
                                                                    
                                            
   
sg::Light &add_directional_light(sg::Scene &scene, const glm::quat &rotation, const sg::LightProperties &props = {}, sg::Node *parent_node = nullptr);

   
                                                                      
                                             
                                            
                                            
                                                                 
                                                                    
                                            
   
sg::Light &add_spot_light(sg::Scene &scene, const glm::vec3 &position, const glm::quat &rotation, const sg::LightProperties &props = {}, sg::Node *parent_node = nullptr);

   
                                                                
                                                           
                                              
                                       
                                                     
                                                          
   
sg::Node &add_free_camera(sg::Scene &scene, const std::string &node_name, VkExtent2D extent);

}                        
