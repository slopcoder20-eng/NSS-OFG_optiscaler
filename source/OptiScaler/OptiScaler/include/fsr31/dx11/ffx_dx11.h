// This file is part of the FidelityFX SDK.
//
// Copyright © 2023 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the “Software”), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

/// @defgroup DX11Backend DX11 Backend
/// FidelityFX SDK native backend implementation for DirectX 11.
///
/// @ingroup Backends

#pragma once

#include <d3d11_1.h>
#include "../ffx_interface.h"

namespace Fsr31
{
#if defined(__cplusplus)
extern "C"
{
#endif                            

                                                                                      
       
                                                                                                                      
                
                                                                                                                     
                                                             
       
                
                                                                                       
                            
    FFX_API size_t ffxGetScratchMemorySizeDX11(size_t maxContexts);

                                                                           
       
                                                                                  
       
                
                                      
       
                            
    FFX_API FfxDevice ffxGetDeviceDX11_Fsr31(ID3D11Device* device);

                                                                 
       
                                                                                                                    
                 
                                                                                  
                                                                                                                     
                
                                                                                               
                                    
                                                                                                                      
                
                                                                                                                     
                                                             
       
               
                                                                                     
               
                                                                                                           
       
                            
    FFX_API FfxErrorCode ffxGetInterfaceDX11(FfxInterface* backendInterface, FfxDevice device, void* scratchBuffer,
                                             size_t scratchBufferSize, uint32_t maxContexts);

                                                                                       
       
                                                                                          
       
                
                                            
       
                            
    FFX_API FfxCommandList ffxGetCommandListDX11(ID3D11DeviceContext* deviceContext);

                                                                           
       
                                                                               
                                                                                                                        
                                                                                                                
                                                                                       
       
                
                                         
       
                            
    FFX_API FfxResource ffxGetResourceDX11_Fsr31(const ID3D11Resource* dx11Resource,
                                                 FfxResourceDescription ffxResDescription, wchar_t const* ffxResName,
                                                 FfxResourceStates state = FFX_RESOURCE_STATE_COMPUTE_READ);

    FFX_API FfxSurfaceFormat ffxGetSurfaceFormatDX11(DXGI_FORMAT format);

    FFX_API FfxResourceDescription GetFfxResourceDescriptionDX11(ID3D11Resource* pResource);

#if defined(__cplusplus)
}
#endif                            

}                   