                                                                                                               
#pragma once
#include "../ffx_api.h"
#include <d3d12.h>

#define FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12 0x0000002u
struct ffxCreateBackendDX12Desc
{
    ffxCreateContextDescHeader header;
    ID3D12Device*              device;                                            
};
