#pragma once
#include "MenuBlur_Common.h"

#include <d3d12.h>
#include <d3dx/d3dx12.h>
#include <shaders/Shader_Dx12.h>
#include <imgui/imgui_impl_dx12.h>

                                                                   
class MenuBlur_Dx12 : public Shader_Dx12, public MenuBlur_Common
{
  private:
    static constexpr UINT MaxBackBuffers = 16;                               

                                                          
                                                          
    static constexpr UINT HorizontalTable = MaxBackBuffers * 2;                          
    static constexpr UINT VerticalTable = HorizontalTable + 2;                           
    static constexpr UINT DescriptorCount = VerticalTable + 2;

    ID3D12DescriptorHeap* _heap = nullptr;
    UINT _descriptorSize = 0;

                                  
    ID3D12Resource* _blurA = nullptr;
    ID3D12Resource* _blurB = nullptr;
    D3D12_RESOURCE_STATES _blurAState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
    D3D12_RESOURCE_STATES _blurBState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;

                                      
    DescriptorHeapAllocator* _imguiHeapAlloc = nullptr;
    D3D12_CPU_DESCRIPTOR_HANDLE _imguiSrvCpu {};
    D3D12_GPU_DESCRIPTOR_HANDLE _imguiSrvGpu {};

                                                             
    ImVec2 _uvScale { 1.0f, 1.0f };

    D3D12_CPU_DESCRIPTOR_HANDLE CpuHandle(UINT index) const;
    D3D12_GPU_DESCRIPTOR_HANDLE GpuHandle(UINT index) const;
    bool CreateRootSignature(ID3D12Device* InDevice);
    void DispatchPass(ID3D12GraphicsCommandList* InCmdList, UINT InTable, BlurMode InMode, float InSpacing,
                      UINT InWidth, UINT InHeight);
    void ReleaseTextures();

    static DXGI_FORMAT BackBufferSrvFormat(DXGI_FORMAT InFormat);

  public:
                                                                                                
    bool Prepare(ID3D12Resource* InBackBuffer);

                                                                                                                 
    bool Dispatch(ID3D12GraphicsCommandList* InCmdList, ID3D12Resource* InBackBuffer, UINT InBackBufferIndex);

    ImTextureID TextureId() const { return (ImTextureID) _imguiSrvGpu.ptr; }
    ImVec2 UVScale() const { return _uvScale; }

    MenuBlur_Dx12(std::string InName, ID3D12Device* InDevice, DescriptorHeapAllocator* InImGuiHeapAlloc);

    ~MenuBlur_Dx12();
};
