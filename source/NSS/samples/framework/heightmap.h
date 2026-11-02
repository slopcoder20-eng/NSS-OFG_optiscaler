/* Copyright (c) 2019-2021, Sascha Willems
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

#include <ktx.h>
#include <string>

namespace vkb
{
   
                                                                  
   
class HeightMap
{
  public:
	   
                                                
                                        
                                   
    
	HeightMap(const std::string &filename, const uint32_t patchsize);

	~HeightMap();

	   
                                                                         
                             
                             
                                 
    
	float get_height(const uint32_t x, const uint32_t y);

  private:
	uint16_t *data;

	uint32_t dim;

	uint32_t scale;
};
}                        
