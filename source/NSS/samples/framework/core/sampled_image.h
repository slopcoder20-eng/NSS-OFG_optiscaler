/* Copyright (c) 2021, Arm Limited and Contributors
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

#include "core/image.h"
#include "core/sampler.h"
#include <memory>

namespace vkb
{
class RenderTarget;

namespace core
{
   
                                                                               
                                                                               
  
class SampledImage
{
  public:
	   
                                                                                           
                                                                   
   
	SampledImage(const ImageView &image_view, Sampler *sampler = nullptr);

	   
                                                                                        
                                                                 
                                                              
   
	SampledImage(uint32_t target_attachment, RenderTarget *render_target = nullptr, Sampler *sampler = nullptr, bool isDepthResolve = false);

	SampledImage(const SampledImage &to_copy);
	SampledImage &operator=(const SampledImage &to_copy);

	SampledImage(SampledImage &&to_move);
	SampledImage &operator=(SampledImage &&to_move);

	~SampledImage() = default;

	   
                                                              
    
	inline void set_image_view(const ImageView &new_view)
	{
		image_view = &new_view;
	}

	   
                                                                                                    
    
	inline void set_image_view(uint32_t new_attachment)
	{
		image_view        = nullptr;
		target_attachment = new_attachment;
	}

	   
                                                                                             
                                     
                                                                                      
    
	const uint32_t *get_target_attachment() const;

	   
                                                                                                 
                                                                                       
    
	const ImageView &get_image_view(const vkb::RenderTarget &default_target) const;

	   
                                                     
    
	inline Sampler *get_sampler() const
	{
		return sampler;
	}

	   
                                                  
    
	inline void set_sampler(Sampler *new_sampler)
	{
		sampler = new_sampler;
	}

	   
                                            
    
	inline RenderTarget *get_render_target() const
	{
		return render_target;
	}

	   
                                                                                                   
    
	inline RenderTarget &get_render_target(RenderTarget &fallback) const
	{
		return render_target ? *render_target : fallback;
	}

	   
                                                  
                                                                   
    
	inline void set_render_target(RenderTarget *new_render_target)
	{
		render_target = std::move(new_render_target);
	}

	inline bool is_depth_resolve() const
	{
		return isDepthResolve;
	}

  private:
	const ImageView *image_view;
	uint32_t         target_attachment;
	RenderTarget *   render_target;
	Sampler *        sampler;
	bool             isDepthResolve;
};

}                         
}                        