#pragma once

#include "SysUtils.h"
#include "CM_Common.h"

#include <d3d12.h>
#include <d3dx/d3dx12.h>
#include <shaders/Shader_Dx12Utils.h>
#include <shaders/Shader_Dx12.h>

                                                                                                           
class CM_Dx12 : public Shader_Dx12
{
  private:
                                                                                                     
    FrameDescriptorHeap _frameHeaps[BUFFER_COUNT];
    ID3D12Resource* _constantBuffers[BUFFER_COUNT] {};
    ID3D12Resource* _buffers[BUFFER_COUNT] {};

    uint32_t InNumThreadsX = 16;
    uint32_t InNumThreadsY = 16;

  public:
                                                                                        
    ID3D12Resource* Dispatch(ID3D12GraphicsCommandList* InCmdList, int InIndex, ID3D12Resource* InVelocity,
                             D3D12_RESOURCE_STATES InVelocityState, ID3D12Resource* InDepth,
                             D3D12_RESOURCE_STATES InDepthState, const CMConstants& InConstants);

    CM_Dx12(std::string InName, ID3D12Device* InDevice);

    ~CM_Dx12();
};
