#include "pch.h"
#include "NfruGameSwapchain.h"
#include "NFRU_Dx12.h"
extern thread_local bool nfruInternalPresentation;
namespace {
HRESULT producerResizeArgs(IDXGISwapChain4* real, HWND hwnd, UINT& width, UINT& height, UINT& flags) {
    DXGI_SWAP_CHAIN_DESC1 desc{};
    auto hr=real->GetDesc1(&desc);if(FAILED(hr))return hr;
    flags=desc.Flags;
    if(!width||!height){RECT r{};if(!GetClientRect(hwnd,&r))return HRESULT_FROM_WIN32(GetLastError());if(!width)width=std::max(1L,r.right-r.left);if(!height)height=std::max(1L,r.bottom-r.top);}
    return S_OK;
}
}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::QueryInterface(REFIID riid, void** ppvObject){if(!ppvObject)return E_POINTER;*ppvObject=nullptr;if(riid==__uuidof(IUnknown)||riid==__uuidof(IDXGIObject)||riid==__uuidof(IDXGIDeviceSubObject)||riid==__uuidof(IDXGISwapChain)||riid==__uuidof(IDXGISwapChain1)||riid==__uuidof(IDXGISwapChain2)||riid==__uuidof(IDXGISwapChain3)||riid==__uuidof(IDXGISwapChain4)){*ppvObject=static_cast<IDXGISwapChain4*>(this);AddRef();return S_OK;}return E_NOINTERFACE;}
ULONG STDMETHODCALLTYPE NfruGameSwapchain::AddRef(){return ++refs;}
ULONG STDMETHODCALLTYPE NfruGameSwapchain::Release(){auto n=--refs;if(!n)delete this;return n;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetPrivateData(REFGUID Name, UINT DataSize, const void* pData){return real->SetPrivateData(Name,DataSize,pData);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetPrivateDataInterface(REFGUID Name, const IUnknown* pUnknown){return real->SetPrivateDataInterface(Name,pUnknown);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetPrivateData(REFGUID Name, UINT* pDataSize, void* pData){return real->GetPrivateData(Name,pDataSize,pData);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetParent(REFIID riid, void** ppParent){return real->GetParent(riid,ppParent);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetDevice(REFIID riid, void** ppDevice){return real->GetDevice(riid,ppDevice);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::Present(UINT SyncInterval, UINT Flags){std::lock_guard guard(access);if(Flags&DXGI_PRESENT_TEST)return S_OK;return owner?owner->SubmitFrame(real.Get(),SyncInterval,Flags):DXGI_ERROR_DEVICE_REMOVED;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetBuffer(UINT Buffer, REFIID riid, void** ppSurface){std::lock_guard guard(access);return real->GetBuffer(Buffer,riid,ppSurface);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetFullscreenState(BOOL Fullscreen, IDXGIOutput* pTarget){return Fullscreen?DXGI_ERROR_UNSUPPORTED:S_OK;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetFullscreenState(BOOL* pFullscreen, IDXGIOutput** ppTarget){if(pFullscreen)*pFullscreen=FALSE;if(ppTarget)*ppTarget=nullptr;return S_OK;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetDesc(DXGI_SWAP_CHAIN_DESC* pDesc){std::lock_guard guard(access);auto hr=real->GetDesc(pDesc);if(SUCCEEDED(hr)){pDesc->OutputWindow=hwnd;pDesc->Windowed=TRUE;pDesc->Flags=gameFlags;}return hr;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::ResizeBuffers(UINT BufferCount, UINT Width, UINT Height, DXGI_FORMAT NewFormat, UINT SwapChainFlags){std::lock_guard guard(access);if(owner){auto hr=owner->BeforeResize();if(FAILED(hr))return hr;}UINT producerFlags=0;auto hr=producerResizeArgs(real.Get(),hwnd,Width,Height,producerFlags);if(FAILED(hr))return hr;hr=real->ResizeBuffers(BufferCount,Width,Height,NewFormat,producerFlags);if(hr==DXGI_ERROR_INVALID_CALL)hr=RecreateProducer(BufferCount,Width,Height,NewFormat);if(SUCCEEDED(hr))gameFlags=SwapChainFlags;LOG_INFO("NFRU producer resize result={:X} size={}x{} gameFlags={:X} producerFlags={:X}",UINT(hr),Width,Height,SwapChainFlags,producerFlags);return hr;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::ResizeTarget(const DXGI_MODE_DESC* pNewTargetParameters){return real->ResizeTarget(pNewTargetParameters);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetContainingOutput(IDXGIOutput** ppOutput){return real->GetContainingOutput(ppOutput);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetFrameStatistics(DXGI_FRAME_STATISTICS* pStats){return real->GetFrameStatistics(pStats);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetLastPresentCount(UINT* pLastPresentCount){return real->GetLastPresentCount(pLastPresentCount);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetDesc1(DXGI_SWAP_CHAIN_DESC1* pDesc){std::lock_guard guard(access);auto hr=real->GetDesc1(pDesc);if(SUCCEEDED(hr))pDesc->Flags=gameFlags;return hr;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetFullscreenDesc(DXGI_SWAP_CHAIN_FULLSCREEN_DESC* pDesc){return real->GetFullscreenDesc(pDesc);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetHwnd(HWND* pHwnd){if(!pHwnd)return E_POINTER;*pHwnd=hwnd;return S_OK;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetCoreWindow(REFIID refiid, void** ppUnk){return real->GetCoreWindow(refiid,ppUnk);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::Present1(UINT SyncInterval, UINT PresentFlags, const DXGI_PRESENT_PARAMETERS* pPresentParameters){return Present(SyncInterval,PresentFlags);}
BOOL STDMETHODCALLTYPE NfruGameSwapchain::IsTemporaryMonoSupported(void){return real->IsTemporaryMonoSupported();}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetRestrictToOutput(IDXGIOutput** ppRestrictToOutput){return real->GetRestrictToOutput(ppRestrictToOutput);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetBackgroundColor(const DXGI_RGBA* pColor){return real->SetBackgroundColor(pColor);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetBackgroundColor(DXGI_RGBA* pColor){return real->GetBackgroundColor(pColor);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetRotation(DXGI_MODE_ROTATION Rotation){return real->SetRotation(Rotation);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetRotation(DXGI_MODE_ROTATION* pRotation){return real->GetRotation(pRotation);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetSourceSize(UINT Width, UINT Height){return real->SetSourceSize(Width,Height);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetSourceSize(UINT* pWidth, UINT* pHeight){return real->GetSourceSize(pWidth,pHeight);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetMaximumFrameLatency(UINT MaxLatency){return real->SetMaximumFrameLatency(MaxLatency);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetMaximumFrameLatency(UINT* pMaxLatency){return real->GetMaximumFrameLatency(pMaxLatency);}
HANDLE STDMETHODCALLTYPE NfruGameSwapchain::GetFrameLatencyWaitableObject(void){return real->GetFrameLatencyWaitableObject();}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetMatrixTransform(const DXGI_MATRIX_3X2_F* pMatrix){return real->SetMatrixTransform(pMatrix);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::GetMatrixTransform(DXGI_MATRIX_3X2_F* pMatrix){return real->GetMatrixTransform(pMatrix);}
UINT STDMETHODCALLTYPE NfruGameSwapchain::GetCurrentBackBufferIndex(void){std::lock_guard guard(access);return real->GetCurrentBackBufferIndex();}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::CheckColorSpaceSupport(DXGI_COLOR_SPACE_TYPE ColorSpace, UINT* pColorSpaceSupport){return real->CheckColorSpaceSupport(ColorSpace,pColorSpaceSupport);}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetColorSpace1(DXGI_COLOR_SPACE_TYPE ColorSpace){std::lock_guard guard(access);if(owner)owner->ColorSpace(ColorSpace);auto hr=real->SetColorSpace1(ColorSpace);if(SUCCEEDED(hr))colorSpace=ColorSpace;return hr;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::ResizeBuffers1(UINT BufferCount, UINT Width, UINT Height, DXGI_FORMAT Format, UINT SwapChainFlags, const UINT* pCreationNodeMask, IUnknown* const* ppPresentQueue){std::lock_guard guard(access);if(owner){auto hr=owner->BeforeResize();if(FAILED(hr))return hr;}UINT producerFlags=0;auto hr=producerResizeArgs(real.Get(),hwnd,Width,Height,producerFlags);if(FAILED(hr))return hr;hr=real->ResizeBuffers1(BufferCount,Width,Height,Format,producerFlags,pCreationNodeMask,ppPresentQueue);if(hr==DXGI_ERROR_INVALID_CALL&&!pCreationNodeMask&&!ppPresentQueue)hr=RecreateProducer(BufferCount,Width,Height,Format);if(SUCCEEDED(hr))gameFlags=SwapChainFlags;LOG_INFO("NFRU producer resize result={:X} size={}x{} gameFlags={:X} producerFlags={:X}",UINT(hr),Width,Height,SwapChainFlags,producerFlags);return hr;}
HRESULT STDMETHODCALLTYPE NfruGameSwapchain::SetHDRMetaData(DXGI_HDR_METADATA_TYPE Type, UINT Size, void* pMetaData){return real->SetHDRMetaData(Type,Size,pMetaData);}

NfruGameSwapchain::~NfruGameSwapchain(){if(owner)owner->DetachGameSwapchain(this);}

HRESULT NfruGameSwapchain::RecreateProducer(UINT count,UINT width,UINT height,DXGI_FORMAT format){
                                                                                  
                                                                                   
    Microsoft::WRL::ComPtr<ID3D12Device> device;
    auto hr=producerQueue->GetDevice(IID_PPV_ARGS(&device));if(FAILED(hr))return hr;
    hr=device->GetDeviceRemovedReason();if(FAILED(hr))return hr;
    DXGI_SWAP_CHAIN_DESC1 desc{};hr=real->GetDesc1(&desc);if(FAILED(hr))return hr;
    if(count)desc.BufferCount=count;desc.Width=width;desc.Height=height;if(format!=DXGI_FORMAT_UNKNOWN)desc.Format=format;
    Microsoft::WRL::ComPtr<IDXGIFactory2> factory;hr=real->GetParent(IID_PPV_ARGS(&factory));if(FAILED(hr))return hr;
    struct Internal {bool old=nfruInternalPresentation;Internal(){nfruInternalPresentation=true;}~Internal(){nfruInternalPresentation=old;}} internal;
    Microsoft::WRL::ComPtr<IDXGISwapChain1> next;hr=factory->CreateSwapChainForComposition(producerQueue.Get(),&desc,nullptr,&next);if(FAILED(hr))return hr;
    Microsoft::WRL::ComPtr<IDXGISwapChain4> next4;hr=next.As(&next4);if(FAILED(hr))return hr;
    hr=next4->SetColorSpace1(colorSpace);if(FAILED(hr))return hr;
    real=std::move(next4);LOG_WARN("NFRU recovered producer resize by replacing offscreen buffers; external old-buffer references were not force-released");return S_OK;
}
