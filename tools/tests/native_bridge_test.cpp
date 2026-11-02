#include "pch.h"
#include <framegen/nfru/NFRU_Dx12.h>
#include <proxies/KernelBase_Proxy.h>
#include <proxies/Ntdll_Proxy.h>
#include <d3d12sdklayers.h>
#include <wrl/client.h>
#include <cstdio>
#include <menu/menu_overlay_base.h>
extern void KeyUp(UINT);
using Microsoft::WRL::ComPtr;
static void ok(HRESULT h,const char* s){if(FAILED(h))throw std::runtime_error(std::format("{} {:08X}",s,UINT(h)));}
static void tr(ID3D12GraphicsCommandList* c,ID3D12Resource* r,D3D12_RESOURCE_STATES a,D3D12_RESOURCE_STATES b){D3D12_RESOURCE_BARRIER x{};x.Type=D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;x.Transition={r,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,a,b};c->ResourceBarrier(1,&x);}
int main(int argc,char** argv){
 const UINT ow=argc>8?1920:640,oh=argc>8?1080:368,iw=argc>8?1122:320,ih=argc>8?631:184;const bool bench=argc>7;auto benchBegin=std::chrono::steady_clock::now();
 try{
  for(int i=0;i<300;++i){State::Instance().frameTimes.push_back(16.6667);State::Instance().upscaleTimes.push_back(0);}
  KernelBaseProxy::Init();NtdllProxy::Init();State::Instance().api=DX12;State::Instance().activeFgOutput=FGOutput::NFRU;State::Instance().activeFgInput=(argc>2&&std::string(argv[2])=="sl")?FGInput::DLSSG:FGInput::FSRFG;
  wchar_t exe[MAX_PATH];GetModuleFileNameW(nullptr,exe,MAX_PATH);Config::Instance()->MainDllPath=std::filesystem::path(exe).parent_path().wstring();Config::Instance()->FGEnabled=true;Config::Instance()->FGOutput=FGOutput::NFRU;Config::Instance()->FGInput=State::Instance().activeFgInput;Config::Instance()->NfruMvCoverage=1;
  ComPtr<ID3D12Debug> debug;if(SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&debug))))debug->EnableDebugLayer();
  ComPtr<ID3D12Device> dev;ok(D3D12CreateDevice(nullptr,D3D_FEATURE_LEVEL_12_0,IID_PPV_ARGS(&dev)),"device");ComPtr<ID3D12CommandQueue> q;D3D12_COMMAND_QUEUE_DESC qd{};ok(dev->CreateCommandQueue(&qd,IID_PPV_ARGS(&q)),"queue");
  ComPtr<IDXGIFactory2> factory;ok(CreateDXGIFactory2(0,IID_PPV_ARGS(&factory)),"factory");
  HWND window=CreateWindowExW(0,L"STATIC",L"NFRU integration smoke",WS_OVERLAPPEDWINDOW,0,0,640,368,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);if(!window)throw std::runtime_error("window");
  unsigned multiplier=argc>1?atoi(argv[1]):4;Config::Instance()->NfruMultiplier=int(multiplier);
  {
   NFRU_Dx12 fg;State::Instance().currentFG=&fg;struct ResetCurrentFG{~ResetCurrentFG(){State::Instance().currentFG=nullptr;}} resetCurrentFG;FG_Constants constants{};constants.displayWidth=ow;constants.displayHeight=oh;fg.CreateContext(dev.Get(),constants);fg.Activate();
   DXGI_SWAP_CHAIN_DESC1 desc{};desc.Width=ow;desc.Height=oh;desc.Format=(argc>3&&std::string(argv[3])=="bgra")?DXGI_FORMAT_B8G8R8A8_UNORM:DXGI_FORMAT_R8G8B8A8_UNORM;if(argc>3&&std::string(argv[3])=="ue"){desc.Width=1920;desc.Height=1080;desc.Format=DXGI_FORMAT_R10G10B10A2_UNORM;desc.Flags=0x802;}if(argc>3&&std::string(argv[3])=="r10"){desc.Format=DXGI_FORMAT_R10G10B10A2_UNORM;desc.Flags=0x802;}desc.SampleDesc.Count=1;desc.BufferCount=3;desc.BufferUsage=DXGI_USAGE_RENDER_TARGET_OUTPUT;desc.SwapEffect=DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
   ComPtr<IDXGISwapChain1> sc1;if(!fg.CreateSwapchain1Internal(factory.Get(),q.Get(),window,&desc,nullptr,&sc1))throw std::runtime_error("producer swapchain: "+fg.PacingReason());ComPtr<IDXGISwapChain4> sc;ok(sc1.As(&sc),"swapchain4");struct DrainOnExit{NFRU_Dx12* fg;~DrainOnExit(){fg->BeforeResize();}} drainOnExit{&fg};if(State::Instance().swapchainApi!=API::DX12)throw std::runtime_error("native DX12 API was not registered");
   if(argc>3&&std::string(argv[3])=="ue"){
    ok(sc->ResizeBuffers(3,1920,1080,DXGI_FORMAT_R10G10B10A2_UNORM,0x802),"UE exact startup resize");
    DXGI_SWAP_CHAIN_DESC1 logical{};ok(sc->GetDesc1(&logical),"logical desc");if(logical.Flags!=0x802)throw std::runtime_error("logical flags lost");
    ok(sc->ResizeBuffers(3,1280,720,DXGI_FORMAT_R8G8B8A8_UNORM,0x802),"UE format resize");
    UINT masks[3]={1,1,1};IUnknown* queues[3]={q.Get(),q.Get(),q.Get()};
    ok(sc->ResizeBuffers1(3,1920,1080,DXGI_FORMAT_R10G10B10A2_UNORM,0x802,masks,queues),"UE resize1");
    ok(sc->ResizeBuffers(0,0,0,DXGI_FORMAT_UNKNOWN,0x802),"UE client-size resize");
    ok(sc->GetDesc1(&logical),"logical desc after resize");if(logical.Flags!=0x802||!logical.Width||!logical.Height)throw std::runtime_error("invalid logical desc");
    printf("UE_RESIZE_REGRESSION_PASS flags=%x format=%u size=%ux%u\n",logical.Flags,logical.Format,logical.Width,logical.Height);DestroyWindow(window);return 0;
   }
   ComPtr<ID3D12DescriptorHeap> heaps,heapsCpu,rtv;D3D12_DESCRIPTOR_HEAP_DESC hd{};hd.NumDescriptors=2;hd.Type=D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;hd.Flags=D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;ok(dev->CreateDescriptorHeap(&hd,IID_PPV_ARGS(&heaps)),"clear descriptors");hd.Flags=D3D12_DESCRIPTOR_HEAP_FLAG_NONE;ok(dev->CreateDescriptorHeap(&hd,IID_PPV_ARGS(&heapsCpu)),"CPU clear descriptors");hd.Type=D3D12_DESCRIPTOR_HEAP_TYPE_RTV;hd.NumDescriptors=1;hd.Flags=D3D12_DESCRIPTOR_HEAP_FLAG_NONE;ok(dev->CreateDescriptorHeap(&hd,IID_PPV_ARGS(&rtv)),"RTV heap");
   ComPtr<ID3D12Resource> depth,mv;auto tex=[&](DXGI_FORMAT f,ComPtr<ID3D12Resource>& r){D3D12_HEAP_PROPERTIES hp{};hp.Type=D3D12_HEAP_TYPE_DEFAULT;D3D12_RESOURCE_DESC d{};d.Dimension=D3D12_RESOURCE_DIMENSION_TEXTURE2D;d.Width=iw;d.Height=ih;d.DepthOrArraySize=d.MipLevels=d.SampleDesc.Count=1;d.Format=f;d.Flags=D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;ok(dev->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&d,D3D12_RESOURCE_STATE_UNORDERED_ACCESS,nullptr,IID_PPV_ARGS(&r)),"input texture");};tex(DXGI_FORMAT_R32_FLOAT,depth);tex(DXGI_FORMAT_R16G16_FLOAT,mv);
   auto cpu=heapsCpu->GetCPUDescriptorHandleForHeapStart();auto gpu=heaps->GetGPUDescriptorHandleForHeapStart();UINT stride=dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);dev->CreateUnorderedAccessView(depth.Get(),nullptr,nullptr,cpu);auto cpuMv=cpu;cpuMv.ptr+=stride;auto gpuMv=gpu;gpuMv.ptr+=stride;dev->CreateUnorderedAccessView(mv.Get(),nullptr,nullptr,cpuMv);dev->CopyDescriptorsSimple(2,heaps->GetCPUDescriptorHandleForHeapStart(),cpu,D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
   ComPtr<ID3D12CommandAllocator> allocator;ComPtr<ID3D12GraphicsCommandList> list;ok(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,IID_PPV_ARGS(&allocator)),"allocator");ok(dev->CreateCommandList(0,D3D12_COMMAND_LIST_TYPE_DIRECT,allocator.Get(),nullptr,IID_PPV_ARGS(&list)),"list");ok(list->Close(),"close");ComPtr<ID3D12Fence> fence;ok(dev->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&fence)),"fence");HANDLE event=CreateEvent(nullptr,FALSE,FALSE,nullptr);UINT64 value=0;
   for(unsigned i=0;i<(bench?160u:argc>5?9u:argc>4?6u:2u);++i){
    ok(allocator->Reset(),"reset allocator");ok(list->Reset(allocator.Get(),nullptr),"reset list");ID3D12DescriptorHeap* h[]={heaps.Get()};list->SetDescriptorHeaps(1,h);float d[]={0.5f,0,0,0},m[]={0,0,0,0};list->ClearUnorderedAccessViewFloat(gpu,cpu,depth.Get(),d,0,nullptr);list->ClearUnorderedAccessViewFloat(gpuMv,cpuMv,mv.Get(),m,0,nullptr);
    ComPtr<ID3D12Resource> bb;ok(sc->GetBuffer(sc->GetCurrentBackBufferIndex(),IID_PPV_ARGS(&bb)),"backbuffer");auto rh=rtv->GetCPUDescriptorHandleForHeapStart();dev->CreateRenderTargetView(bb.Get(),nullptr,rh);tr(list.Get(),bb.Get(),D3D12_RESOURCE_STATE_PRESENT,D3D12_RESOURCE_STATE_RENDER_TARGET);float color[]={0.2f+0.05f*i,0.3f,0.4f,1};list->ClearRenderTargetView(rh,color,0,nullptr);tr(list.Get(),bb.Get(),D3D12_RESOURCE_STATE_RENDER_TARGET,D3D12_RESOURCE_STATE_PRESENT);ok(list->Close(),"close draw");ID3D12CommandList* l[]={list.Get()};q->ExecuteCommandLists(1,l);q->Signal(fence.Get(),++value);fence->SetEventOnCompletion(value,event);if(WaitForSingleObject(event,5000)!=WAIT_OBJECT_0)throw std::runtime_error("input timeout");
    if(!bench&&argc>6){Config::Instance()->NfruMultiplier=int(2+i%3);fg.Activate();}
    fg.SetFrameCount(100+i*20);fg.SetFrameTimeDelta(16.6667);fg.SetCameraValues(0.1f,1000.0f,1.0f,float(ow)/float(oh));fg.SetMVScale(iw,ih);fg.SetReset(i==0);if(State::Instance().activeFgInput==FGInput::DLSSG){float projection[16]{};projection[0]=1.0f/std::tan(0.5f)/(float(ow)/float(oh));projection[5]=1.0f/std::tan(0.5f);projection[10]=1000.0f/999.9f;projection[11]=1;projection[14]=-100.0f/999.9f;float pos[]={0,0,0},right[]={1,0,0},up[]={0,1,0},fwd[]={0,0,1};fg.SetCameraData(pos,up,right,fwd);fg.SetCameraInput(projection,true);}
    Dx12Resource a{};a.type=FG_ResourceType::Depth;a.resource=depth.Get();a.state=D3D12_RESOURCE_STATE_UNORDERED_ACCESS;a.validity=FG_ResourceValidity::UntilPresent;a.width=iw;a.height=ih;fg.SetResource(&a);a.type=FG_ResourceType::Velocity;a.resource=mv.Get();fg.SetResource(&a);
    if(!bench&&argc>5){if(i==4||i==5)KeyUp(VK_INSERT);if(i==6)ShowWindow(window,SW_MINIMIZE);if(i==7){ShowWindow(window,SW_SHOWNOACTIVATE);ShowWindow(window,SW_HIDE);}}
    fg.Present();HRESULT present=sc->Present(0,0);ComPtr<ID3D12InfoQueue> info;if(SUCCEEDED(dev.As(&info))){for(UINT64 mi=0;mi<info->GetNumStoredMessagesAllowedByRetrievalFilter();++mi){SIZE_T bytes=0;info->GetMessage(mi,nullptr,&bytes);std::vector<unsigned char> b(bytes);auto* msg=(D3D12_MESSAGE*)b.data();if(SUCCEEDED(info->GetMessage(mi,msg,&bytes)) && msg->Severity<=D3D12_MESSAGE_SEVERITY_WARNING)printf("D3D12_DEBUG severity=%u id=%u %s\n",msg->Severity,msg->ID,msg->pDescription);}info->ClearStoredMessages();}ok(present,"NFRU present");if(!bench&&argc>6){if(State::Instance().activeFgOutput!=FGOutput::NFRU||Config::Instance()->FGOutput.value_or_default()!=FGOutput::NFRU)throw std::runtime_error("menu reset native NFRU output");if(i!=4&&i!=6&&fg.GetInterpolatedFrameCount()+1!=unsigned(Config::Instance()->NfruMultiplier.value_or_default()))throw std::runtime_error("native multiplier did not apply");}if(!bench&&argc>5){if(i==4&&!MenuOverlayBase::IsVisible())throw std::runtime_error("Insert did not open menu");if(i==5&&MenuOverlayBase::IsVisible())throw std::runtime_error("Insert did not close menu");if(i==6&&std::string(fg.PacingMode())!="Suspended")throw std::runtime_error("minimize did not suspend");if(i==7&&std::string(fg.PacingMode())=="Suspended")throw std::runtime_error("restore did not resume");}printf("FRAME %u multiplier=%u mode=%s reason=%s\n",i,multiplier,fg.PacingMode(),fg.PacingReason().c_str());
    if(!bench&&argc>4&&i==1){bb.Reset();ok(sc->ResizeBuffers(3,ow,oh,desc.Format,desc.Flags),"resize during sequence");printf("MID_SEQUENCE_RESIZE_PASS\n");}
   }
   if(bench)printf("BENCH frames=160 cpu_elapsed_ms=%.3f metrics=%s\n",std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-benchBegin).count(),fg.PacingReason().c_str());
   ComPtr<ID3D12Resource> retained;ok(sc->GetBuffer(0,IID_PPV_ARGS(&retained)),"retained reference");
   ok(sc->ResizeBuffers(3,ow,oh,desc.Format,desc.Flags),"resize after generation");ComPtr<ID3D12Resource> replacement;ok(sc->GetBuffer(0,IID_PPV_ARGS(&replacement)),"replacement reference");if(retained.Get()==replacement.Get())throw std::runtime_error("producer recovery failed");replacement.Reset();retained.Reset();printf("RETAINED_REFERENCE_RECOVERY_PASS\n");printf("POST_GENERATION_RESIZE_PASS\n");ok(fg.BeforeResize(),"teardown");ok(dev->GetDeviceRemovedReason(),"device state");CloseHandle(event);printf("NFRU_NATIVE_BRIDGE_SMOKE_PASS multiplier=%u\n",multiplier);
  }
  DestroyWindow(window);return 0;
 }catch(const std::exception& e){printf("FAIL %s\n",e.what());return 2;}
}
