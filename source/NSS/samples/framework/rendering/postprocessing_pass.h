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

#include "core/command_buffer.h"
#include "render_context.h"
#include "render_target.h"
#include <functional>

namespace vkb
{
class PostProcessingPipeline;

   
                                                                           
   
class PostProcessingPassBase
{
	friend class PostProcessingPipeline;

  public:
	PostProcessingPassBase(PostProcessingPipeline *parent);

	PostProcessingPassBase(const PostProcessingPassBase &to_copy)            = delete;
	PostProcessingPassBase &operator=(const PostProcessingPassBase &to_copy) = delete;

	PostProcessingPassBase(PostProcessingPassBase &&to_move)            = default;
	PostProcessingPassBase &operator=(PostProcessingPassBase &&to_move) = default;

	virtual ~PostProcessingPassBase() = default;

  protected:
	   
                                                                                
                                                                                        
                                      
    
	virtual void prepare(vkb::core::CommandBufferC &command_buffer, RenderTarget &default_render_target)
	{
		prepared = true;
	}

	   
                                                                            
                                                                                        
                                      
    
	virtual void draw(vkb::core::CommandBufferC &command_buffer, RenderTarget &default_render_target)
	{}

	   
                                                           
                                                  
    
	using HookFunc = std::function<void()>;

	                                                                                      
	PostProcessingPipeline *parent{nullptr};
	bool                    prepared{false};

	std::string debug_name{};

	RenderTarget                  *render_target{nullptr};
	std::shared_ptr<core::Sampler> default_sampler{};

	HookFunc pre_draw{};
	HookFunc post_draw{};

	   
                                               
    
	RenderContext &get_render_context() const;

	   
                                                                         
    
	ShaderSource &get_triangle_vs() const;

	struct BarrierInfo
	{
		VkPipelineStageFlags pipeline_stage;                                                          
		VkAccessFlags        image_read_access;                                                      
		VkAccessFlags        image_write_access;                                                         
	};

	   
                                                                                  
                                                                                       
    
	virtual BarrierInfo get_src_barrier_info() const = 0;

	   
                                                                                  
                                                                               
    
	virtual BarrierInfo get_dst_barrier_info() const = 0;

	   
                                                                                                       
                                                                                              
    
	BarrierInfo get_predecessor_src_barrier_info(BarrierInfo fallback = {}) const;
};

   
                                                                            
   
template <typename Self>
class PostProcessingPass : public PostProcessingPassBase
{
  public:
	using PostProcessingPassBase::PostProcessingPassBase;

	PostProcessingPass(const PostProcessingPass &to_copy)            = delete;
	PostProcessingPass &operator=(const PostProcessingPass &to_copy) = delete;

	PostProcessingPass(PostProcessingPass &&to_move)            = default;
	PostProcessingPass &operator=(PostProcessingPass &&to_move) = default;

	virtual ~PostProcessingPass() = default;

	   
                                                                                        
                                                                                                         
    
	inline Self &set_pre_draw_func(HookFunc &&new_func)
	{
		pre_draw = std::move(new_func);

		return static_cast<Self &>(*this);
	}

	   
                                                                                       
                                                                                            
    
	inline Self &set_post_draw_func(HookFunc &&new_func)
	{
		post_draw = std::move(new_func);

		return static_cast<Self &>(*this);
	}

	   
                                      
                                                                                                        
    
	inline RenderTarget *get_render_target() const
	{
		return render_target;
	}

	   
                                      
                                                                                                        
                                                                
    
	inline Self &set_render_target(RenderTarget *new_render_target)
	{
		render_target = new_render_target;

		return static_cast<Self &>(*this);
	}

	   
                                                   
    
	inline const std::string &get_debug_name() const
	{
		return debug_name;
	}

	   
                                            
    
	inline Self &set_debug_name(const std::string &new_debug_name)
	{
		debug_name = new_debug_name;

		return static_cast<Self &>(*this);
	}

	   
                                                                                   
    
	inline PostProcessingPipeline &get_parent() const
	{
		return *parent;
	}
};

}                        
