/* Copyright (c) 2024, Mobica Limited
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

#include <array>
#include <imgui.h>
#include <stdint.h>
#include <string>
#include <vector>

namespace vkb
{
class Drawer;

   
                                                           
   
class Drawer
{
  public:
	enum class ColorOp
	{
		Edit,
		Pick
	};

	Drawer() = default;

	   
                                   
    
	void clear();

	   
                                                      
    
	bool is_dirty();

	   
                                             
    
	void set_dirty(bool dirty);

	   
                                                    
                                      
                                               
    
	bool header(const char *caption);

	   
                                     
                                      
                                                         
                                               
    
	bool checkbox(const char *caption, bool *value);

	   
                                     
                                      
                                                         
                                               
    
	bool checkbox(const char *caption, int32_t *value);

	   
                                         
                                      
                                                                                 
                                                                                     
                                               
    
	bool radio_button(const char *caption, int32_t *selectedOption, const int32_t elementOption);

	   
                                               
                                      
                                    
                                  
                                  
                                               
    
	bool input_float(const char *caption, float *value, float step, const char* precision);

	   
                                                                     
                                      
                                    
                                
                                
                                               
    
	bool slider_float(const char *caption, float *value, float min, float max);

	   
                                                              
                                      
                                    
                                
                                
                                               
    
	bool slider_int(const char *caption, int32_t *value, int32_t min, int32_t max);

	   
                                                     
                                      
                                              
                                                
                                               
    
	bool combo_box(const char *caption, int32_t *itemindex, std::vector<std::string> items);

	   
                                             
                                      
                                               
    
	bool button(const char *caption);

	   
                                  
                                      
    
	void text(const char *formatstr, ...);

	   
                                         
                                      
                                                                                                       
                                                                                      
                                                                            
    
	bool color_picker(const char *caption, std::array<float, 3> &color, float width = 0.0f, ImGuiColorEditFlags flags = 0);

	   
                                         
                                      
                                                                                                       
                                                                                      
                                                                            
    
	bool color_picker(const char *caption, std::array<float, 4> &color, float width = 0.0f, ImGuiColorEditFlags flags = 0);

	   
                                       
                                      
                                                                                                       
                                                                                      
                                                                            
    
	bool color_edit(const char *caption, std::array<float, 3> &color, float width = 0.0f, ImGuiColorEditFlags flags = 0);

	   
                                       
                                         
                                                  
                                      
                                                                                                       
                                                                                      
                                                                            
    
	template <ColorOp OP, size_t N>
	bool color_op(const std::string &caption, std::array<float, N> &color, float width = 0.0f, ImGuiColorEditFlags flags = 0)
	{
		static_assert((N == 3) || (N == 4), "The channel count must be 3 or 4.");

		ImGui::PushItemWidth(width);
		bool res = color_op_impl<OP, N>(caption.c_str(), color.data(), flags);
		ImGui::PopItemWidth();
		if (res)
			dirty = true;
		return res;
	}

  private:
	template <ColorOp OP, size_t N>
	inline bool color_op_impl(const char *caption, float *colors, ImGuiColorEditFlags flags)
	{
		assert(false);
		return false;
	}

	bool dirty{false};
};

template <>
bool Drawer::color_op_impl<Drawer::ColorOp::Edit, 3>(const char *caption, float *colors, ImGuiColorEditFlags flags);

template <>
bool Drawer::color_op_impl<Drawer::ColorOp::Edit, 4>(const char *caption, float *colors, ImGuiColorEditFlags flags);

template <>
bool Drawer::color_op_impl<Drawer::ColorOp::Pick, 3>(const char *caption, float *colors, ImGuiColorEditFlags flags);

template <>
bool Drawer::color_op_impl<Drawer::ColorOp::Pick, 4>(const char *caption, float *colors, ImGuiColorEditFlags flags);

}                        
