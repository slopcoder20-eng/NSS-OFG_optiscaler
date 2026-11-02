#pragma once
#include <framegen/IFGFeature_Dx12.h>
#include <memory>
class NfruGameSwapchain;
class NFRU_Dx12 final : public IFGFeature_Dx12 {
    struct Impl;
    std::unique_ptr<Impl> p;
    bool requested=false;
protected:
    void CreateObjects(ID3D12Device*) override;
    void ReleaseObjects() override;
public:
    NFRU_Dx12();
    ~NFRU_Dx12();
    const char* Name() override { return "NFRU"; }
    feature_version Version() override { return {0,1,0}; }
    HWND Hwnd() override { return _hwnd; }
    bool CreateSwapchainInternal(IDXGIFactory*,ID3D12CommandQueue*,DXGI_SWAP_CHAIN_DESC*,IDXGISwapChain**) override;
    bool CreateSwapchain1Internal(IDXGIFactory*,ID3D12CommandQueue*,HWND,DXGI_SWAP_CHAIN_DESC1*,DXGI_SWAP_CHAIN_FULLSCREEN_DESC*,IDXGISwapChain1**) override;
    void CreateContext(ID3D12Device*,FG_Constants&) override;
    void EvaluateState(ID3D12Device*,FG_Constants&) override;
    void Activate() override;
    void Deactivate() override;
    void DestroyFGContext() override;
    bool ReleaseSwapchain(HWND) override;
    bool Shutdown() override;
    bool Present() override { requested=true;return true; }
    bool SetResource(Dx12Resource*) override;
    void SetCommandQueue(FG_ResourceType,ID3D12CommandQueue*) override;
    void* FrameGenerationContext() override;
    void* SwapchainContext() override;
    bool SetInterpolatedFrameCount(UINT) override;
    HRESULT SubmitFrame(IDXGISwapChain4*,UINT,UINT);
    void DetachGameSwapchain(NfruGameSwapchain*);
    HRESULT BeforeResize();
    void SetCameraInput(const float*,bool);
    void ColorSpace(DXGI_COLOR_SPACE_TYPE);
    std::pair<double,double> SubmittedRates() const;
    const char* PacingMode() const;
    std::string PacingReason() const;
};
