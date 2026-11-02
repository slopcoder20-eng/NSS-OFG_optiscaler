                                             
                                                                   

                        
                                                                                                                                             
                                                                                                                         
                                                                                                          
                                                                                                                                                        
                                                                                                                              

                                                                                             
                                                                                                                                 

                                                                                                              
                                                                                                                                              
                          
                                                   
                                                               
                                                                                       
                                                         

#pragma once
#include "imgui.h"                       
#ifndef IMGUI_DISABLE
#include <dxgiformat.h>               
#include <d3d12.h>                                    

                                   
                             
struct DescriptorHeapAllocator
{
    ID3D12DescriptorHeap* Heap = nullptr;
    D3D12_DESCRIPTOR_HEAP_TYPE HeapType = D3D12_DESCRIPTOR_HEAP_TYPE_NUM_TYPES;
    D3D12_CPU_DESCRIPTOR_HANDLE HeapStartCpu;
    D3D12_GPU_DESCRIPTOR_HANDLE HeapStartGpu;
    UINT HeapHandleIncrement;
    ImVector<int> FreeIndices;

    void Create(ID3D12Device* device, ID3D12DescriptorHeap* heap)
    {
        IM_ASSERT(Heap == nullptr && FreeIndices.empty());
        Heap = heap;
        D3D12_DESCRIPTOR_HEAP_DESC desc = heap->GetDesc();
        HeapType = desc.Type;
        HeapStartCpu = Heap->GetCPUDescriptorHandleForHeapStart();
        HeapStartGpu = Heap->GetGPUDescriptorHandleForHeapStart();
        HeapHandleIncrement = device->GetDescriptorHandleIncrementSize(HeapType);
        FreeIndices.reserve((int) desc.NumDescriptors);
        for (int n = desc.NumDescriptors; n > 0; n--)
            FreeIndices.push_back(n - 1);
    }
    void Destroy()
    {
        Heap = nullptr;
        FreeIndices.clear();
    }
    void Alloc(D3D12_CPU_DESCRIPTOR_HANDLE* out_cpu_desc_handle, D3D12_GPU_DESCRIPTOR_HANDLE* out_gpu_desc_handle)
    {
        IM_ASSERT(FreeIndices.Size > 0);
        int idx = FreeIndices.back();
        FreeIndices.pop_back();
        out_cpu_desc_handle->ptr = HeapStartCpu.ptr + (idx * HeapHandleIncrement);
        out_gpu_desc_handle->ptr = HeapStartGpu.ptr + (idx * HeapHandleIncrement);
    }
    void Free(D3D12_CPU_DESCRIPTOR_HANDLE out_cpu_desc_handle, D3D12_GPU_DESCRIPTOR_HANDLE out_gpu_desc_handle)
    {
        int cpu_idx = (int) ((out_cpu_desc_handle.ptr - HeapStartCpu.ptr) / HeapHandleIncrement);
        int gpu_idx = (int) ((out_gpu_desc_handle.ptr - HeapStartGpu.ptr) / HeapHandleIncrement);
        IM_ASSERT(cpu_idx == gpu_idx);
        FreeIndices.push_back(cpu_idx);
    }
};

                                                 
struct ImGui_ImplDX12_InitInfo
{
    ID3D12Device*               Device;
    ID3D12CommandQueue*         CommandQueue;                                                         
    int                         NumFramesInFlight;
    DXGI_FORMAT                 RTVFormat;                                 
    DXGI_FORMAT                 DSVFormat;                                     
    void*                       UserData;

                                                                                                 
                                                                                                                           
    ID3D12DescriptorHeap*       SrvDescriptorHeap;
    void                        (*SrvDescriptorAllocFn)(ImGui_ImplDX12_InitInfo* info, D3D12_CPU_DESCRIPTOR_HANDLE* out_cpu_desc_handle, D3D12_GPU_DESCRIPTOR_HANDLE* out_gpu_desc_handle);
    void                        (*SrvDescriptorFreeFn)(ImGui_ImplDX12_InitInfo* info, D3D12_CPU_DESCRIPTOR_HANDLE cpu_desc_handle, D3D12_GPU_DESCRIPTOR_HANDLE gpu_desc_handle);
#ifndef IMGUI_DISABLE_OBSOLETE_FUNCTIONS
    D3D12_CPU_DESCRIPTOR_HANDLE LegacySingleSrvCpuDescriptor;                                                                                             
    D3D12_GPU_DESCRIPTOR_HANDLE LegacySingleSrvGpuDescriptor;
#endif

    ImGui_ImplDX12_InitInfo()   { memset((void*)this, 0, sizeof(*this)); }
};

                                                                                          
IMGUI_IMPL_API bool     ImGui_ImplDX12_Init(ImGui_ImplDX12_InitInfo* info);
IMGUI_IMPL_API void     ImGui_ImplDX12_Shutdown(bool shutdown_platform = true, bool invalidate = true);
IMGUI_IMPL_API void     ImGui_ImplDX12_NewFrame();
IMGUI_IMPL_API void     ImGui_ImplDX12_RenderDrawData(ImDrawData* draw_data, ID3D12GraphicsCommandList* graphics_command_list);

#ifndef IMGUI_DISABLE_OBSOLETE_FUNCTIONS
                                                
                                                                                                                                                                             
                                                                                                                    
IMGUI_IMPL_API bool     ImGui_ImplDX12_Init(ID3D12Device* device, int num_frames_in_flight, DXGI_FORMAT rtv_format, ID3D12DescriptorHeap* srv_descriptor_heap, D3D12_CPU_DESCRIPTOR_HANDLE font_srv_cpu_desc_handle, D3D12_GPU_DESCRIPTOR_HANDLE font_srv_gpu_desc_handle);
#endif

                                                                                  
IMGUI_IMPL_API bool     ImGui_ImplDX12_CreateDeviceObjects();
IMGUI_IMPL_API void     ImGui_ImplDX12_InvalidateDeviceObjects();

                                                                                                                                                                                  
IMGUI_IMPL_API void     ImGui_ImplDX12_UpdateTexture(ImTextureData* tex);

                                                           
                                                                                                                      
                                                                  
struct ImGui_ImplDX12_RenderState
{
    ID3D12Device*               Device;
    ID3D12GraphicsCommandList*  CommandList;
};

#endif                         
