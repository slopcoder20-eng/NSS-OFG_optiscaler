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

#include "core/sampled_image.h"
#include "postprocessing_pass.h"
#include "render_pipeline.h"
#include "subpass.h"

namespace vkb
{
   
                                              
   
struct PairHasher
{
	template <typename TPair>
	size_t operator()(const TPair &pair) const
	{
		std::hash<decltype(pair.first)>  hash1{};
		std::hash<decltype(pair.second)> hash2{};
		return hash1(pair.first) * 43 + pair.second;
	}
};

   
                                                                                    
   
using AttachmentMap = std::unordered_map<std::string, uint32_t>;

   
                                                                         
   
using SampledMap = std::unordered_map<std::string, core::SampledImage>;

   
                                                                                         
   
using StorageImageMap = std::unordered_map<std::string, const core::ImageView *>;

   
                                                              
   
using AttachmentList = std::vector<uint32_t>;

   
                                                             
   
using AttachmentSet = std::unordered_set<uint32_t>;

class PostProcessingRenderPass;

   
                                                           
   
class PostProcessingSubpass : public vkb::rendering::SubpassC
{
  public:
	PostProcessingSubpass(PostProcessingRenderPass *parent, RenderContext &render_context, ShaderSource &&triangle_vs,
	                      ShaderSource &&fs, ShaderVariant &&fs_variant = {});

	PostProcessingSubpass(const PostProcessingSubpass &to_copy)            = delete;
	PostProcessingSubpass &operator=(const PostProcessingSubpass &to_copy) = delete;

	PostProcessingSubpass(PostProcessingSubpass &&to_move);
	PostProcessingSubpass &operator=(PostProcessingSubpass &&to_move) = delete;

	~PostProcessingSubpass() = default;

	   
                                                                                                        
                                                                                                                             
    
	inline const AttachmentMap &get_input_attachments() const
	{
		return input_attachments;
	}

	   
                                                                               
                                                                                                                      
                                                                                                       
                                                                                                                       
    
	inline const SampledMap &get_sampled_images() const
	{
		return sampled_images;
	}

	   
                                                                                  
                                                                                                                            
    
	inline const StorageImageMap &get_storage_images() const
	{
		return storage_images;
	}

	   
                                                                                 
    
	inline ShaderVariant &get_fs_variant()
	{
		return fs_variant;
	}

	   
                                                                                           
    
	inline PostProcessingSubpass &set_fs_variant(ShaderVariant &&new_variant)
	{
		fs_variant = std::move(new_variant);

		return *this;
	}

	   
                                                  
    
	inline PostProcessingSubpass &set_debug_name(const std::string &name)
	{
		Subpass::set_debug_name(name);

		return *this;
	}

	   
                                                                        
    
	PostProcessingSubpass &bind_input_attachment(const std::string &name, uint32_t new_input_attachment);

	   
                                                                     
                                                                               
                                                                                                                              
    
	PostProcessingSubpass &bind_sampled_image(const std::string &name, core::SampledImage &&new_image);

	   
                                                                     
    
	PostProcessingSubpass &bind_storage_image(const std::string &name, const core::ImageView &new_image);

	   
                                                           
    
	void unbind_sampled_image(const std::string &name);

	   
                                                                         
    
	PostProcessingSubpass &set_push_constants(const std::vector<uint8_t> &data);

	   
                                                                         
    
	template <typename T>
	inline PostProcessingSubpass &set_push_constants(const T &data)
	{
		push_constants_data.reserve(sizeof(data));
		auto data_ptr = reinterpret_cast<const uint8_t *>(&data);
		push_constants_data.assign(data_ptr, data_ptr + sizeof(data));

		return *this;
	}

	   
                                                                            
                            
    
	using DrawFunc = std::function<void(vkb::core::CommandBufferC &command_buffer, RenderTarget &render_target)>;

	   
                                                                   
                            
    
	PostProcessingSubpass &set_draw_func(DrawFunc &&new_func);

	   
                                                                                         
    
	static void default_draw_func(vkb::core::CommandBufferC &command_buffer, vkb::RenderTarget &render_target);

  private:
	PostProcessingRenderPass *parent;

	ShaderVariant fs_variant{};

	AttachmentMap   input_attachments{};
	SampledMap      sampled_images{};
	StorageImageMap storage_images{};

	std::vector<uint8_t> push_constants_data{};

	DrawFunc draw_func{&PostProcessingSubpass::default_draw_func};

	void prepare() override;
	void draw(vkb::core::CommandBufferC &command_buffer) override;
};

   
                                                                                         
   
class PostProcessingRenderPass : public PostProcessingPass<PostProcessingRenderPass>
{
  public:
	friend class PostProcessingSubpass;

	PostProcessingRenderPass(PostProcessingPipeline *parent, std::unique_ptr<core::Sampler> &&default_sampler = nullptr);

	PostProcessingRenderPass(const PostProcessingRenderPass &to_copy)            = delete;
	PostProcessingRenderPass &operator=(const PostProcessingRenderPass &to_copy) = delete;

	PostProcessingRenderPass(PostProcessingRenderPass &&to_move)            = default;
	PostProcessingRenderPass &operator=(PostProcessingRenderPass &&to_move) = default;

	void draw(vkb::core::CommandBufferC &command_buffer, RenderTarget &default_render_target) override;

	   
                                            
    
	inline PostProcessingSubpass &get_subpass(size_t index)
	{
		assert(index < pipeline.get_subpasses().size());
		return *dynamic_cast<PostProcessingSubpass *>(pipeline.get_subpasses()[index].get());
	}

	   
                                                                                          
                                                                                                            
                               
    
	template <typename... ConstructorArgs>
	PostProcessingSubpass &add_subpass(ConstructorArgs &&...args)
	{
		ShaderSource vs_copy         = get_triangle_vs();
		auto         new_subpass     = std::make_unique<PostProcessingSubpass>(this, get_render_context(), std::move(vs_copy), std::forward<ConstructorArgs>(args)...);
		auto        &new_subpass_ref = *new_subpass;

		pipeline.add_subpass(std::move(new_subpass));

		return new_subpass_ref;
	}

	   
                                                                
    
	template <typename T>
	inline PostProcessingRenderPass &set_uniform_data(const T &data)
	{
		uniform_data.reserve(sizeof(data));
		auto data_ptr = reinterpret_cast<const uint8_t *>(&data);
		uniform_data.assign(data_ptr, data_ptr + sizeof(data));

		return *this;
	}

	   
                                       
    
	inline PostProcessingRenderPass &set_uniform_data(const std::vector<uint8_t> &data)
	{
		uniform_data = data;

		return *this;
	}

  private:
	                                            
	using SampledAttachmentSet = std::unordered_set<std::pair<RenderTarget *, uint32_t>, PairHasher>;

	   
                                                                           
                                                                                                   
    
	void transition_attachments(const AttachmentSet        &input_attachments,
	                            const SampledAttachmentSet &sampled_attachments,
	                            const AttachmentSet        &output_attachments,
	                            vkb::core::CommandBufferC  &command_buffer,
	                            RenderTarget               &fallback_render_target);

	   
                                                                                     
                                                                                      
                           
                                                                                                   
    
	void update_load_stores(const AttachmentSet        &input_attachments,
	                        const SampledAttachmentSet &sampled_attachments,
	                        const AttachmentSet        &output_attachments,
	                        const RenderTarget         &fallback_render_target);

	   
                                                                      
    
	void prepare_draw(vkb::core::CommandBufferC &command_buffer, RenderTarget &fallback_render_target);

	BarrierInfo get_src_barrier_info() const override;
	BarrierInfo get_dst_barrier_info() const override;

	RenderPipeline                     pipeline{};
	std::unique_ptr<core::Sampler>     default_sampler{};
	std::unique_ptr<core::Sampler>     default_sampler_nearest{};
	RenderTarget                      *draw_render_target{nullptr};
	std::vector<LoadStoreInfo>         load_stores{};
	bool                               load_stores_dirty{true};
	std::vector<uint8_t>               uniform_data{};
	std::shared_ptr<BufferAllocationC> uniform_buffer_alloc{};
};

}                        
