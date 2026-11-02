// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2022-2023 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// This file contains function declarations to convert DX12 resources
// to and from API independent FFX resources.

// @defgroup DX12

#pragma once

#include <d3d12.h>
#include "../ffx_fsr2_interface.h"

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                                      
       
                
                                                                                       
    size_t ffxFsr2GetScratchMemorySizeDX12();

                                                                 
       
                                                                                                                        
                 
                                                                                  
                                                                                                                     
                
                                                                                               
                                    
       
               
                                                                                     
               
                                                                                                           
       
                          
    FfxErrorCode ffxFsr2GetInterfaceDX12(FfxFsr2Interface* fsr2Interface, ID3D12Device* device, void* scratchBuffer,
                                         size_t scratchBufferSize);

                                                                               
       
                                                                                  
       
                
                                      
       
                          
    FfxDevice ffxGetDeviceDX12(ID3D12Device* device);

                                                                                     
       
                                                                                        
       
                
                                            
       
                          
    FfxCommandList ffxGetCommandListDX12(ID3D12CommandList* cmdList);

                                                                               
       
                                                                                                        
                                                                                    
                                                                                                                
                                                                                       
                                                                             
       
                
                                         
       
                          
    FfxResource ffxGetResourceDX12(FfxFsr2Context* context, ID3D12Resource* resDx12, const wchar_t* name = nullptr,
                                   FfxResourceStates state = FFX_RESOURCE_STATE_COMPUTE_READ,
                                   UINT shaderComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING);

                                                                                              
                                                                
       
                                                                                                      
                                                             
       
                
                                               
       
                          
    ID3D12Resource* ffxGetDX12ResourcePtr(FfxFsr2Context* context, uint32_t resId);

#if defined(__cplusplus)
}
#endif                            
