/* Copyright (c) 2026, Arm Limited and Contributors
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

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include <volk.h>

   
                                                                          
  
                                                                             
                                                                          
                       
   
class DatasetLoader
{
  public:
	                                                                  
	struct FrameParams
	{
		float viewProjection[16];                                                     
		float jitterX;                                                              
		float jitterY;                                                              
		float cameraNear;                                             
		float cameraFar;                                             
		float cameraFovAngleVertical;                            
		float frameTimeDelta;                                      
		float motionVectorScaleX;                                     
		float motionVectorScaleY;                                     
	};

	~DatasetLoader();

	                                                                                
	bool init(VkDevice device, VkPhysicalDevice gpu,
	          const std::string &dataset_dir, const std::string &dataset_sequence,
	          uint32_t swapchain_count);

	int  total_frames() const;

	                                                                          
	int  interpolated_source_frame(int frame) const { return frame * 2 - 1; }

	                                                                               
	bool get_frame_params(int frame, FrameParams &out) const;

	                                                                         
	bool load_frame(int frame, uint32_t swapchain_index, FrameParams &out);

	                                                               
	VkBuffer get_color_staging(uint32_t swapchain_index) const;
	VkBuffer get_depth_staging(uint32_t swapchain_index) const;
	VkBuffer get_mv_staging(uint32_t swapchain_index) const;

	VkExtent2D get_display_size() const;
	VkExtent2D get_render_size() const;

  private:
	struct FrameData
	{
		float viewProjection[16]{};
		float fovY       = 0.75f;
		float cameraNear = 10.0f;
		float cameraFar  = 5000.0f;
		float jitterX    = 0.0f;
		float jitterY    = 0.0f;
	};

	std::vector<FrameData> frames_;
	float                   fps_            = 60.0f;
	bool                    reverse_z_      = false;

	std::string color_dir_;
	std::string depth_dir_;
	std::string mv_dir_;

	VkExtent2D display_size_{};
	VkExtent2D render_size_{};

	                                       
	                                                 
	                                                                 
	VkDevice device_ = VK_NULL_HANDLE;
	struct StagingBuffer
	{
		VkBuffer       buffer = VK_NULL_HANDLE;
		VkDeviceMemory memory = VK_NULL_HANDLE;
		void          *mapped = nullptr;
	};
	std::vector<StagingBuffer> color_staging_;
	std::vector<StagingBuffer> depth_staging_;
	std::vector<StagingBuffer> mv_staging_;

	StagingBuffer create_staging_buffer(VkPhysicalDevice gpu, VkDeviceSize size);
	void          destroy_staging_buffer(StagingBuffer &sb);
};
