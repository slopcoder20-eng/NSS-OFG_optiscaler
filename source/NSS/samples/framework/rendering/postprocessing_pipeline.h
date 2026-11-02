/* Copyright (c) 2020-2025, Arm Limited and Contributors
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

#include "postprocessing_pass.h"

namespace vkb
{
class PostProcessingRenderPass;

   
                                                                                             
   
class PostProcessingPipeline
{
  public:
	friend class PostProcessingPassBase;

	   
                                                                                              
    
	PostProcessingPipeline(RenderContext &render_context, ShaderSource triangle_vs);

	PostProcessingPipeline(const PostProcessingPipeline &to_copy)            = delete;
	PostProcessingPipeline &operator=(const PostProcessingPipeline &to_copy) = delete;

	PostProcessingPipeline(PostProcessingPipeline &&to_move)            = delete;
	PostProcessingPipeline &operator=(PostProcessingPipeline &&to_move) = delete;

	virtual ~PostProcessingPipeline() = default;

	   
                                                                                                    
                                                                                                          
                                      
    
	void draw(vkb::core::CommandBufferC &command_buffer, RenderTarget &default_render_target);

	   
                                                  
    
	inline std::vector<std::unique_ptr<PostProcessingPassBase>> &get_passes()
	{
		return passes;
	}

	   
                                                        
    
	template <typename TPass = vkb::PostProcessingRenderPass>
	inline TPass &get_pass(size_t index)
	{
		return *dynamic_cast<TPass *>(passes[index].get());
	}

	   
                                                                                                
    
	template <typename TPass = vkb::PostProcessingRenderPass, typename... ConstructorArgs>
	TPass &add_pass(ConstructorArgs &&...args)
	{
		passes.emplace_back(std::make_unique<TPass>(this, std::forward<ConstructorArgs>(args)...));
		auto &added_pass = *dynamic_cast<TPass *>(passes.back().get());
		return added_pass;
	}

	   
                                              
    
	inline RenderContext &get_render_context() const
	{
		return *render_context;
	}

	   
                                                               
    
	inline size_t get_current_pass_index() const
	{
		return current_pass_index;
	}

  private:
	RenderContext                                       *render_context{nullptr};
	ShaderSource                                         triangle_vs;
	std::vector<std::unique_ptr<PostProcessingPassBase>> passes{};
	size_t                                               current_pass_index{0};
};

}                        