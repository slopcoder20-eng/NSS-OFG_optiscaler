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

#include "platform/window.h"

namespace vkb
{
   
                                                                                
                                                                                               
                                                          
   
class HeadlessWindow : public Window
{
  public:
	HeadlessWindow(const Window::Properties &properties);

	virtual ~HeadlessWindow() = default;

	   
                                                 
                           
    
	VkSurfaceKHR create_surface(vkb::core::InstanceC &instance) override;

	   
                                                 
                    
    
	VkSurfaceKHR create_surface(VkInstance instance, VkPhysicalDevice physical_device) override;

	bool should_close() override;

	void close() override;

	float get_dpi_factor() const override;

	std::vector<const char *> get_required_surface_extensions() const override;

  private:
	bool closed{false};
};
}                        
