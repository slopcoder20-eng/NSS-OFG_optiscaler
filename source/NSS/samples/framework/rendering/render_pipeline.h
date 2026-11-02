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

#include "common/helpers.h"
#include "common/utils.h"
#include "core/buffer.h"
#include "rendering/render_frame.h"
#include "rendering/subpass.h"

namespace vkb
{
   
                                                            
                                                          
                                                           
                                                                          
                        
  
                                                                                               
                                                                                                                                             
                                                                                                                     
   
class RenderPipeline
{
  public:
	RenderPipeline(std::vector<std::unique_ptr<vkb::rendering::SubpassC>> &&subpasses = {});

	RenderPipeline(const RenderPipeline &) = delete;

	RenderPipeline(RenderPipeline &&) = default;

	virtual ~RenderPipeline() = default;

	RenderPipeline &operator=(const RenderPipeline &) = delete;

	RenderPipeline &operator=(RenderPipeline &&) = default;

	   
                                 
    
	void prepare();

	   
                           
    
	const std::vector<LoadStoreInfo> &get_load_store() const;

	   
                                            
    
	void set_load_store(const std::vector<LoadStoreInfo> &load_store);

	   
                        
    
	const std::vector<VkClearValue> &get_clear_value() const;

	   
                                           
    
	void set_clear_value(const std::vector<VkClearValue> &clear_values);

	   
                                            
                                    
    
	void add_subpass(std::unique_ptr<vkb::rendering::SubpassC> &&subpass);

	std::vector<std::unique_ptr<vkb::rendering::SubpassC>> &get_subpasses();

	   
                                                
    
	void draw(vkb::core::CommandBufferC &command_buffer, RenderTarget &render_target, VkSubpassContents contents = VK_SUBPASS_CONTENTS_INLINE);

	   
                                                              
                                      
    
	std::unique_ptr<vkb::rendering::SubpassC> &get_active_subpass();

  private:
	std::vector<std::unique_ptr<vkb::rendering::SubpassC>> subpasses;

	                             
	std::vector<LoadStoreInfo> load_store = std::vector<LoadStoreInfo>(2);

	                               
	std::vector<VkClearValue> clear_value = std::vector<VkClearValue>(2);

	size_t active_subpass_index{0};
};
}                        
