// This file is part of the FidelityFX SDK.
//
// Copyright (c) 2023 Advanced Micro Devices, Inc. All rights reserved.
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

// @defgroup DX11

#pragma once

#include <d3d11.h>
#include "../ffx_fsr2_interface.h"

#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                                      
       
                
                                                                                       
    size_t ffxFsr2GetScratchMemorySizeDX11();

                                                                 
       
                                                                                                                        
                 
                                                                                  
                                                                                                                     
                
                                                                                               
                                    
       
               
                                                                                     
               
                                                                                                           
       
                          
    FfxErrorCode ffxFsr2GetInterfaceDX11(FfxFsr2Interface* fsr2Interface, ID3D11Device* device, void* scratchBuffer,
                                         size_t scratchBufferSize);

                                                                               
       
                                                                                  
       
                
                                      
       
                          
    FfxDevice ffxGetDeviceDX11(ID3D11Device* device);

                                                                               
       
                                                                                                        
                                                                                    
                                                                                                                
                                                                                       
       
                
                                         
       
                          
    FfxResource ffxGetResourceDX11(FfxFsr2Context* context, ID3D11Resource* resDx11, const wchar_t* name = nullptr,
                                   FfxResourceStates state = FFX_RESOURCE_STATE_COMPUTE_READ);

                                                                                              
                                                                
       
                                                                                                      
                                                           
       
                
                                               
       
                          
    ID3D11Resource* ffxGetDX11ResourcePtr(FfxFsr2Context* context, uint32_t resId);

#if defined(__cplusplus)
}
#endif                            
