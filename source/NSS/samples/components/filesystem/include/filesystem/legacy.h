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

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <string>
#include <sys/stat.h>
#include <unordered_map>
#include <vector>

namespace vkb
{
namespace fs
{
namespace path
{
enum Type
{
	                 
	Assets,
	Shaders,
	Storage,
	Screenshots,
	Logs,
	               
	TotalRelativePathTypes,

	                
	ExternalStorage,
	Temp
};

extern const std::unordered_map<Type, std::string> relative_paths;

   
                                                                   
                                    
                                      
                                                                                                                                   
                                                  
   
const std::string get(const Type type, const std::string &file = "");
}                         

   
                                                       
                                    
                                                                     
   
bool is_directory(const std::string &path);

   
                                 
                                        
                                                                
   
bool is_file(const std::string &filename);

   
                                                                
                                    
   
void create_directory(const std::string &path);

   
                                         
                                                              
                                                              
   
void create_path(const std::string &root, const std::string &path);

   
                                                        
  
                                                                          
                                                       
   
std::vector<uint8_t> read_asset(const std::string &filename);

   
                                                         
  
                                                                          
                                        
   
std::string read_text_file(const std::string &filename);

   
                                                                                
  
                                                                          
                                                       
   
std::vector<uint32_t> read_shader_binary_u32(const std::string &filename);

   
                                                           
  
                                                                                     
                                                       
   
std::vector<uint8_t> read_temp(const std::string &filename);

   
                                                        
  
                                                 
                                                                                     
                        
   
void write_temp(const std::vector<uint8_t> &data, const std::string &filename);
   
                                                             
  
                                                                                    
                                                                    
                                           
                                            
                                                    
                                                           
   
void write_image(const uint8_t *data, const std::string &filename, const uint32_t width, const uint32_t height, const uint32_t components, const uint32_t row_stride);
}                       
}                        
