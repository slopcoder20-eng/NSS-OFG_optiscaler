// This file is part of the Anti-Lag 2.0 SDK.
//
// Copyright (c) 2024 Advanced Micro Devices, Inc. All rights reserved.
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

#pragma once

#include <d3d11.h>

namespace AMD {
namespace AntiLag2DX11 {

    struct Context;

                                                                       
                                                                                                                                                    
                                                                                                                 
                                                                                     
    HRESULT Initialize( Context* context );

                                                      
                                                      
                                                                                   
    ULONG DeInitialize( Context* context );

                                                                               
                                                      
                                                 
                                                                      
    HRESULT Update( Context* context, bool enable, unsigned int maxFPS );

      
                                 
                                            
      

                                                                             
    class IAmdDxExtInterface
    {
    public:
        virtual unsigned int AddRef() = 0;
        virtual unsigned int Release() = 0;

    protected:
        IAmdDxExtInterface() {}                                
        virtual ~IAmdDxExtInterface() = 0;
    };

    inline IAmdDxExtInterface::~IAmdDxExtInterface() {}

                                            
    struct APIData_v1
    {
        unsigned int    uiSize;
        unsigned int    uiVersion;
        unsigned int    eMode;
        const char*     sControlStr;
        unsigned int    uiControlStrLength;
        unsigned int    maxFPS;
    };
    static_assert(sizeof(APIData_v1) == 32, "Check structure packing compiler settings.");

                                                                         
    struct IAmdDxExtAntiLagApi : public IAmdDxExtInterface
    {
    public:
        virtual HRESULT UpdateAntiLagStateDx11( APIData_v1* pApiCallbackData ) = 0;
    };

                                                                                                        
                                                                                                                                   
    struct Context
    {
        IAmdDxExtAntiLagApi*  m_pAntiLagAPI = nullptr;
        bool                  m_enabled = false;
        unsigned int          m_maxFPS = 0;
    };

    inline HRESULT Initialize( Context* context )
    {
        HRESULT hr = E_INVALIDARG;
        if ( context && context->m_pAntiLagAPI == nullptr )
        {
            HMODULE hModule = GetModuleHandleA("amdxx64.dll");                            
            if ( hModule )
            {
                typedef HRESULT(__cdecl* PFNAmdDxExtCreate11)(ID3D11Device* pDevice, IAmdDxExtInterface** ppAntiLagApi);
                PFNAmdDxExtCreate11 AmdDxExtCreate11 = reinterpret_cast<PFNAmdDxExtCreate11>((VOID*)GetProcAddress(hModule, "AmdDxExtCreate11"));
                if ( AmdDxExtCreate11 )
                {
                    *(__int64*)&context->m_pAntiLagAPI = 0xbf380ebc5ab4d0a6;                                  
                    hr = AmdDxExtCreate11( nullptr, (IAmdDxExtInterface**)&context->m_pAntiLagAPI );
                    if ( hr == S_OK )
                    {
                        APIData_v1 data = {};
                        data.uiSize = sizeof(data);
                        data.uiVersion = 1;
                        data.eMode = 2;                                                  
                        data.sControlStr = nullptr;
                        data.uiControlStrLength = 0;
                        data.maxFPS = 0;

                        hr = context->m_pAntiLagAPI->UpdateAntiLagStateDx11( &data );
                    }

                    if ( hr != S_OK )
                    {
                        DeInitialize( context );
                    }
                }
            }
            else
            {
                hr = E_HANDLE;
            }
        }
        return hr;
    }

    inline ULONG DeInitialize( Context* context )
    {
        ULONG refCount = 0;
        if ( context )
        {
            if ( context->m_pAntiLagAPI )
            {
                refCount = context->m_pAntiLagAPI->Release();
                context->m_pAntiLagAPI = nullptr;
            }
            context->m_enabled = false;
        }
        return refCount;
    }

    inline HRESULT Update( Context* context, bool enabled, unsigned int maxFPS )
    {
                                                                                 
                                                                             
        if ( context && context->m_pAntiLagAPI )
        {
                                                                          
            if ( context->m_enabled != enabled || context->m_maxFPS != maxFPS )
            {
                context->m_enabled = enabled;
                context->m_maxFPS = maxFPS;

                APIData_v1 data = {};
                data.uiSize = sizeof(data);
                data.uiVersion = 1;
                data.eMode = enabled ? 1 : 2;
                data.maxFPS = maxFPS;
                static const char params[] = "delag_next_osd_supported_in_dxxp = 1";
                data.sControlStr = params;
                data.uiControlStrLength = _countof( params ) - 1;

                                                                                     
                                                              
                context->m_pAntiLagAPI->UpdateAntiLagStateDx11( &data );
            }

                                                                                     
                                                                                         
            HRESULT hr = context->m_pAntiLagAPI->UpdateAntiLagStateDx11( nullptr );
            if ( hr == S_OK || hr == S_FALSE )
            {
                return S_OK;
            }
            else
            {
                return hr;
            }
        }
        else
        {
            return E_NOINTERFACE;
        }
    }

}                          
}                 