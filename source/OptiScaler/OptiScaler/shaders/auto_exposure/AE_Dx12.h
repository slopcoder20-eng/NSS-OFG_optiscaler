#pragma once
#include <d3d12.h>
#include <d3dx/d3dx12.h>
#include <shaders/Shader_Dx12Utils.h>
#include <shaders/Shader_Dx12.h>

#define AE_NUM_OF_HEAPS 2

                                                                                                      
class AE_Dx12 : public Shader_Dx12
{
  private:
    struct InternalConstants
    {
        uint32_t RenderWidth;
        uint32_t RenderHeight;
        uint32_t GroupCountX;
        uint32_t GroupCount;
        float DeltaTime;
        uint32_t Reset;
        uint32_t PassIndex;
        float PreExposure;
    };

    FrameDescriptorHeap _frameHeaps[AE_NUM_OF_HEAPS];

                                                  
    ID3D12Resource* _data = nullptr;
    uint32_t _dataElements = 0;

    ID3D12Resource* _exposure = nullptr;
    D3D12_RESOURCE_STATES _exposureState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;

    bool _historyValid = false;

    bool CreateRootSignature(ID3D12Device* InDevice);
    bool EnsureDataBuffer(uint32_t InElements);

  public:
                                                     
    bool Dispatch(ID3D12GraphicsCommandList* InCmdList, ID3D12Resource* InColor, uint32_t InRenderWidth,
                  uint32_t InRenderHeight, float InPreExposure, float InDeltaTimeSeconds, bool InReset);

    ID3D12Resource* Exposure() { return _exposure; }

    AE_Dx12(std::string InName, ID3D12Device* InDevice);

    ~AE_Dx12();
};
