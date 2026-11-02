#pragma once
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <wrl/client.h>
#include <array>
#include <memory>
#include <string>
#include <vector>

namespace mfg {
using Microsoft::WRL::ComPtr;
struct Options {
    unsigned width = 960, height = 540;
    DXGI_FORMAT format = DXGI_FORMAT_B8G8R8A8_UNORM;
    unsigned bufferCount = 4, maxQueuedBatches = 3, copySlots = 12;
    unsigned syncInterval = 0;
    DXGI_COLOR_SPACE_TYPE colorSpace = DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709;
    std::string logPrefix = "mfg";
};
struct Output {
                                                                     
                                                                            
    ComPtr<ID3D12Resource> image;
    ComPtr<ID3D12Fence> readyFence;
    UINT64 readyValue = 0;
    D3D12_RESOURCE_STATES state = D3D12_RESOURCE_STATE_COPY_SOURCE;
};
struct Batch {
    UINT64 frameId = 0;
    unsigned multiplier = 2;                                            
    INT64 anchorQpc = 0, periodQpc = 0;
                                                             
    std::array<Output,4> outputs;
};
INT64 qpc();
INT64 frequency();
std::vector<INT64> targets(INT64 anchor, INT64 period, unsigned multiplier);

                                                                               
                                                                          
class Swapchain {
public:
    Swapchain(ID3D12Device* device, IDXGIFactory4* factory, HWND hwnd, const Options&);
    ~Swapchain();
    Swapchain(const Swapchain&) = delete;
    Swapchain& operator=(const Swapchain&) = delete;
    UINT64 submit(const Batch&);                                                  
    void waitTicket(UINT64);                                               
    void drain();
    void stop();
    HRESULT failure() const;
    UINT64 submittedOutputs() const;
private:
    struct Impl;
    std::unique_ptr<Impl> p;
};
}
