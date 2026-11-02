#include "pch.h"
#include "NFRU_Dx12.h"
#include "SubmittedRateTracker.h"
#include "NfruGameSwapchain.h"
#include "MfgSwapchain.h"
#include "PublicPresenter.h"
#include "NfruPresentationController.h"
#include <framegen/nvngx/Nvngx_NFRU.h>
#include <NVNGX_Parameter.h>
#include <d3dcompiler.h>
#include <d3dkmthk.h>
#include <menu/menu_overlay_dx.h>
#include <menu/menu_overlay_base.h>
#include <chrono>
#include <map>
#include <mutex>
#include <stdexcept>
#pragma comment(lib,"dcomp.lib")
#pragma comment(lib,"ole32.lib")
#pragma comment(lib,"onecore.lib")
#pragma comment(lib,"d3dcompiler.lib")
using Microsoft::WRL::ComPtr;
thread_local bool nfruInternalPresentation=false;
namespace {
void ck(HRESULT h,const char* s){if(FAILED(h))throw std::runtime_error(std::format("{} {:08X}",s,UINT(h)));}
void barrier(ID3D12GraphicsCommandList* c,ID3D12Resource* r,D3D12_RESOURCE_STATES a,D3D12_RESOURCE_STATES b){if(a==b)return;D3D12_RESOURCE_BARRIER x{};x.Type=D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;x.Transition={r,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,a,b};c->ResourceBarrier(1,&x);}
bool hwfqEnabled(ID3D12Device* d){
 HMODULE m=LoadLibraryExW(L"gdi32.dll",nullptr,LOAD_LIBRARY_SEARCH_SYSTEM32);if(!m)return false;
 auto op=(decltype(&D3DKMTOpenAdapterFromLuid))GetProcAddress(m,"D3DKMTOpenAdapterFromLuid");auto qu=(decltype(&D3DKMTQueryAdapterInfo))GetProcAddress(m,"D3DKMTQueryAdapterInfo");auto cl=(decltype(&D3DKMTCloseAdapter))GetProcAddress(m,"D3DKMTCloseAdapter");
 bool yes=false;D3DKMT_OPENADAPTERFROMLUID a{};a.AdapterLuid=d->GetAdapterLuid();
 if(op&&qu&&cl&&op(&a)>=0){D3DKMT_WDDM_3_0_CAPS v{};D3DKMT_QUERYADAPTERINFO q{};q.hAdapter=a.hAdapter;q.Type=KMTQAITYPE_WDDM_3_0_CAPS;q.pPrivateDriverData=&v;q.PrivateDriverDataSize=sizeof(v);yes=qu(&q)>=0&&v.HwFlipQueueEnabled;D3DKMT_CLOSEADAPTER z{};z.hAdapter=a.hAdapter;cl(&z);}FreeLibrary(m);return yes;
}
struct InternalScope{bool old=nfruInternalPresentation;InternalScope(){nfruInternalPresentation=true;}~InternalScope(){nfruInternalPresentation=old;}};
}
struct NFRU_Dx12::Impl {
 SubmittedRateTracker rates;NfruPresentationController controller;std::mutex operationMutex;
 ComPtr<ID3D12Device> dev;ComPtr<ID3D12CommandQueue> queue;ComPtr<IDXGIFactory4> factory;NfruGameSwapchain* game=nullptr;
 std::unique_ptr<public_mfg::Presenter> handshake;std::unique_ptr<mfg::Swapchain> cpu;
 std::vector<ComPtr<ID3D12Resource>> images;std::vector<UINT64> tickets;UINT cursor=0;
 unsigned lastMultiplier=0;bool sawForeground=false,suspended=false;bool historyValid=false;float projection[BUFFER_COUNT][16]{};bool projectionValid[BUFFER_COUNT]{},cameraIncluded[BUFFER_COUNT]{};
 Nvngx_NFRU sdk;NVNGX_Parameters params{DX12,false};NVSDK_NGX_Handle* handle=nullptr;
 struct Ring{ComPtr<ID3D12CommandAllocator> allocator;ComPtr<ID3D12GraphicsCommandList> list;ComPtr<ID3D12Resource> generated[3],sceneColor,hudColor;ID3D12Resource* depth=nullptr;ID3D12Resource* mv=nullptr;ID3D12Resource* hud=nullptr;UINT64 fence=0;bool measuredGenerated=false;std::vector<ComPtr<ID3D12Resource>> keepInputs;};
 Ring ring[3];ComPtr<ID3D12Fence> fence;HANDLE event=nullptr;UINT64 fenceValue=0,frame=0,anchor=0;
 ComPtr<ID3D12RootSignature> root;ComPtr<ID3D12DescriptorHeap> srv,rtv;std::map<DXGI_FORMAT,ComPtr<ID3D12PipelineState>> pipelines;ComPtr<ID3DBlob> vs,ps;
 UINT sw=0,sh=0;DXGI_FORMAT format=DXGI_FORMAT_UNKNOWN;DXGI_COLOR_SPACE_TYPE colorSpace=DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709;
 ComPtr<ID3D12QueryHeap> timing;ComPtr<ID3D12Resource> timingRead;UINT64* timingMap=nullptr;UINT64 timingHz=0;
 double gpuNN=0,gpuBlend=0,gateMs=0,submitMs=0,producerMs=0,queueAhead=0;UINT64 perfCount=0,timelineResets=0;std::string metrics;
 std::mutex statusMutex;std::string mode="Not initialized",reason="Waiting for the first DX12 present",inputStatus;
 void status(std::string m,std::string r){std::lock_guard l(statusMutex);if(mode!=m)LOG_INFO("NFRU presentation mode: {} ({})",m,r);mode=std::move(m);reason=std::move(r);}
 void wait(UINT64 v){if(!v)return;auto done=fence->GetCompletedValue();if(done==UINT64_MAX)throw std::runtime_error("device removed");if(done<v){ck(fence->SetEventOnCompletion(v,event),"allocator fence");if(WaitForSingleObject(event,5000)!=WAIT_OBJECT_0)throw std::runtime_error("allocator timeout");}}
 void drain(){if(!queue||!fence)return;ck(queue->Signal(fence.Get(),++fenceValue),"drain signal");wait(fenceValue);controller.Run([&]{if(handshake)handshake->finish(0);if(cpu){cpu->drain();ck(cpu->failure(),"CPU present");}});}
 void clear(){drain();rates.Reset();if(handle){auto* native=reinterpret_cast<Nvngx_NFRU_Handle*>(handle);if(native->ctx){auto destroy=FfxApiProxy::D3D12_NSS_DestroyContext();if(!destroy||destroy(&native->ctx,nullptr)!=FFX_API_RETURN_OK)throw std::runtime_error("NFRU context destruction failed after GPU idle");native->ctx=nullptr;}sdk.D3D12_ReleaseFeature(handle);handle=nullptr;}controller.Run([&]{handshake.reset();cpu.reset();images.clear();tickets.clear();});for(auto& r:ring){if(r.depth)r.depth->Release();if(r.mv)r.mv->Release();if(r.hud)r.hud->Release();r=Ring{};}if(timingMap&&timingRead)timingRead->Unmap(0,nullptr);timingMap=nullptr;timingRead.Reset();timing.Reset();root.Reset();srv.Reset();rtv.Reset();pipelines.clear();sw=sh=0;anchor=0;frame=0;cursor=0;historyValid=false;status("Not initialized","Presentation resources were reset");}
 ~Impl(){try{clear();}catch(...){ }if(event)CloseHandle(event);}
 void init(HWND window,ID3D12Resource* source){
  auto d=source->GetDesc();sw=UINT(d.Width);sh=d.Height;format=d.Format;
  if(!fence){ck(dev->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&fence)),"fence");event=CreateEvent(nullptr,FALSE,FALSE,nullptr);if(!event)throw std::runtime_error("fence event");}
  controller.Run([&]{InternalScope internal;ck(CreateDXGIFactory2(0,IID_PPV_ARGS(&factory)),"factory");
  const bool enabled=hwfqEnabled(dev.Get());
  const bool sdr=colorSpace==DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709 && (format==DXGI_FORMAT_R8G8B8A8_UNORM||format==DXGI_FORMAT_B8G8R8A8_UNORM||format==DXGI_FORMAT_R10G10B10A2_UNORM);
  std::string fallback=enabled?"Handshake is limited to SDR; CPU fallback for this format/color space":"WDDM HwFlipQueueEnabled is disabled or unavailable";
  if(enabled&&sdr){try{public_mfg::Options o;o.width=sw;o.height=sh;o.buffers=12;o.format=format;o.debug=false;o.interruptEveryOutput=false;o.logPrefix="NUL";handshake=std::make_unique<public_mfg::Presenter>(dev.Get(),queue.Get(),window,o);status("Handshake","WDDM HWFQ enabled; scheduled presentation initialized. Per-present HWFQ use is not measured.");for(unsigned i=0;i<12;++i)images.emplace_back(handshake->image(i));}catch(const std::exception& e){handshake.reset();fallback=std::string("Handshake initialization failed: ")+e.what();}}
  if(!handshake){mfg::Options o;o.width=sw;o.height=sh;o.format=format;o.colorSpace=colorSpace;o.bufferCount=4;o.logPrefix="NUL";cpu=std::make_unique<mfg::Swapchain>(dev.Get(),factory.Get(),window,o);status("CPU fallback",fallback);
   for(unsigned i=0;i<12;++i){D3D12_HEAP_PROPERTIES hp{};hp.Type=D3D12_HEAP_TYPE_DEFAULT;auto rd=d;rd.Flags=D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;ComPtr<ID3D12Resource> r;ck(dev->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,D3D12_RESOURCE_STATE_COMMON,nullptr,IID_PPV_ARGS(&r)),"present image");images.push_back(r);}}
  tickets.assign(12,0);});
  ck(queue->GetTimestampFrequency(&timingHz),"timestamp frequency");D3D12_QUERY_HEAP_DESC qd{};qd.Type=D3D12_QUERY_HEAP_TYPE_TIMESTAMP;qd.Count=9;ck(dev->CreateQueryHeap(&qd,IID_PPV_ARGS(&timing)),"timestamp heap");
  D3D12_HEAP_PROPERTIES th{};th.Type=D3D12_HEAP_TYPE_READBACK;D3D12_RESOURCE_DESC td{};td.Dimension=D3D12_RESOURCE_DIMENSION_BUFFER;td.Width=9*sizeof(UINT64);td.Height=td.DepthOrArraySize=td.MipLevels=td.SampleDesc.Count=1;td.Layout=D3D12_TEXTURE_LAYOUT_ROW_MAJOR;ck(dev->CreateCommittedResource(&th,D3D12_HEAP_FLAG_NONE,&td,D3D12_RESOURCE_STATE_COPY_DEST,nullptr,IID_PPV_ARGS(&timingRead)),"timestamp readback");D3D12_RANGE tr{0,SIZE_T(td.Width)};ck(timingRead->Map(0,&tr,reinterpret_cast<void**>(&timingMap)),"timestamp map");
  for(auto& r:ring){ck(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,IID_PPV_ARGS(&r.allocator)),"allocator");ck(dev->CreateCommandList(0,D3D12_COMMAND_LIST_TYPE_DIRECT,r.allocator.Get(),nullptr,IID_PPV_ARGS(&r.list)),"list");ck(r.list->Close(),"initial list");
   for(auto& out:r.generated){D3D12_HEAP_PROPERTIES hp{};hp.Type=D3D12_HEAP_TYPE_DEFAULT;auto rd=d;rd.Format=(format==DXGI_FORMAT_B8G8R8A8_UNORM)?DXGI_FORMAT_R8G8B8A8_UNORM:format;rd.Flags=D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;ck(dev->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,D3D12_RESOURCE_STATE_UNORDERED_ACCESS,nullptr,IID_PPV_ARGS(&out)),"interpolated image");}}
  if(format==DXGI_FORMAT_B8G8R8A8_UNORM){for(auto& r:ring){D3D12_HEAP_PROPERTIES hp{};hp.Type=D3D12_HEAP_TYPE_DEFAULT;auto rd=d;rd.Format=DXGI_FORMAT_R8G8B8A8_UNORM;rd.Flags=D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;ck(dev->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,D3D12_RESOURCE_STATE_COMMON,nullptr,IID_PPV_ARGS(&r.sceneColor)),"NFRU BGRA scene conversion");ck(dev->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,D3D12_RESOURCE_STATE_COMMON,nullptr,IID_PPV_ARGS(&r.hudColor)),"NFRU BGRA HUD conversion");}}
  D3D12_DESCRIPTOR_HEAP_DESC hd{};hd.Type=D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;hd.NumDescriptors=24;hd.Flags=D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;ck(dev->CreateDescriptorHeap(&hd,IID_PPV_ARGS(&srv)),"SRV heap");hd.Type=D3D12_DESCRIPTOR_HEAP_TYPE_RTV;hd.Flags=D3D12_DESCRIPTOR_HEAP_FLAG_NONE;ck(dev->CreateDescriptorHeap(&hd,IID_PPV_ARGS(&rtv)),"RTV heap");
  const char* shader="Texture2D<float4> img:register(t0);struct V{float4 p:SV_Position;};V vs(uint i:SV_VertexID){V v;v.p=float4((i==2?3:-1),(i==1?3:-1),0,1);return v;}float4 ps(V v):SV_Target{return img.Load(int3(int2(v.p.xy),0));}";
  ComPtr<ID3DBlob> errors;ck(D3DCompile(shader,strlen(shader),nullptr,nullptr,nullptr,"vs","vs_5_0",0,0,&vs,&errors),"blit VS");ck(D3DCompile(shader,strlen(shader),nullptr,nullptr,nullptr,"ps","ps_5_0",0,0,&ps,&errors),"blit PS");
  D3D12_DESCRIPTOR_RANGE range{};range.RangeType=D3D12_DESCRIPTOR_RANGE_TYPE_SRV;range.NumDescriptors=1;D3D12_ROOT_PARAMETER param{};param.ParameterType=D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;param.DescriptorTable={1,&range};param.ShaderVisibility=D3D12_SHADER_VISIBILITY_PIXEL;D3D12_ROOT_SIGNATURE_DESC rs{};rs.NumParameters=1;rs.pParameters=&param;rs.Flags=D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;ComPtr<ID3DBlob> blob;ck(D3D12SerializeRootSignature(&rs,D3D_ROOT_SIGNATURE_VERSION_1,&blob,&errors),"root serialization");ck(dev->CreateRootSignature(0,blob->GetBufferPointer(),blob->GetBufferSize(),IID_PPV_ARGS(&root)),"root");
  sdk.D3D12_Init_Ext(0,L"",dev.Get(),NVSDK_NGX_Version_API,nullptr);
 }
 void blit(ID3D12GraphicsCommandList* c,ID3D12Resource* src,D3D12_RESOURCE_STATES state,ID3D12Resource* dst,UINT index){
  auto fmt=dst->GetDesc().Format;auto& pipe=pipelines[fmt];if(!pipe){D3D12_GRAPHICS_PIPELINE_STATE_DESC x{};x.pRootSignature=root.Get();x.VS={vs->GetBufferPointer(),vs->GetBufferSize()};x.PS={ps->GetBufferPointer(),ps->GetBufferSize()};x.SampleMask=UINT_MAX;x.RasterizerState.FillMode=D3D12_FILL_MODE_SOLID;x.RasterizerState.CullMode=D3D12_CULL_MODE_NONE;x.RasterizerState.DepthClipEnable=TRUE;auto& rt=x.BlendState.RenderTarget[0];rt.SrcBlend=D3D12_BLEND_ONE;rt.DestBlend=D3D12_BLEND_ZERO;rt.BlendOp=D3D12_BLEND_OP_ADD;rt.SrcBlendAlpha=D3D12_BLEND_ONE;rt.DestBlendAlpha=D3D12_BLEND_ZERO;rt.BlendOpAlpha=D3D12_BLEND_OP_ADD;rt.LogicOp=D3D12_LOGIC_OP_NOOP;rt.RenderTargetWriteMask=15;x.DepthStencilState.DepthFunc=D3D12_COMPARISON_FUNC_ALWAYS;x.DepthStencilState.DepthWriteMask=D3D12_DEPTH_WRITE_MASK_ZERO;x.DepthStencilState.FrontFace={D3D12_STENCIL_OP_KEEP,D3D12_STENCIL_OP_KEEP,D3D12_STENCIL_OP_KEEP,D3D12_COMPARISON_FUNC_ALWAYS};x.DepthStencilState.BackFace=x.DepthStencilState.FrontFace;x.PrimitiveTopologyType=D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;x.NumRenderTargets=1;x.RTVFormats[0]=fmt;x.SampleDesc.Count=1;ck(dev->CreateGraphicsPipelineState(&x,IID_PPV_ARGS(&pipe)),"blit pipeline");}
  auto shandle=srv->GetCPUDescriptorHandleForHeapStart();shandle.ptr+=SIZE_T(index)*dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);auto gpu=srv->GetGPUDescriptorHandleForHeapStart();gpu.ptr+=UINT64(index)*dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);auto rh=rtv->GetCPUDescriptorHandleForHeapStart();rh.ptr+=SIZE_T(index)*dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
  D3D12_SHADER_RESOURCE_VIEW_DESC sd{};sd.Format=src->GetDesc().Format;sd.ViewDimension=D3D12_SRV_DIMENSION_TEXTURE2D;sd.Shader4ComponentMapping=D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;sd.Texture2D.MipLevels=1;dev->CreateShaderResourceView(src,&sd,shandle);dev->CreateRenderTargetView(dst,nullptr,rh);
  barrier(c,src,state,D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE);barrier(c,dst,D3D12_RESOURCE_STATE_COMMON,D3D12_RESOURCE_STATE_RENDER_TARGET);
  c->SetPipelineState(pipe.Get());c->SetGraphicsRootSignature(root.Get());ID3D12DescriptorHeap* heaps[]={srv.Get()};c->SetDescriptorHeaps(1,heaps);c->SetGraphicsRootDescriptorTable(0,gpu);c->OMSetRenderTargets(1,&rh,FALSE,nullptr);D3D12_VIEWPORT vp{0,0,float(sw),float(sh),0,1};D3D12_RECT rect{0,0,LONG(sw),LONG(sh)};c->RSSetViewports(1,&vp);c->RSSetScissorRects(1,&rect);c->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);c->DrawInstanced(3,1,0,0);
  barrier(c,dst,D3D12_RESOURCE_STATE_RENDER_TARGET,D3D12_RESOURCE_STATE_COMMON);barrier(c,src,D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE,state);
 }
};
NFRU_Dx12::NFRU_Dx12():p(std::make_unique<Impl>()){_maxInterpolationCount=3;_framesToInterpolate=1;}
NFRU_Dx12::~NFRU_Dx12(){try{Shutdown();}catch(...){ }if(p->game)p->game->owner=nullptr;}
std::pair<double,double> NFRU_Dx12::SubmittedRates()const{return p->rates.Rates(Util::MillisecondsNow());}
const char* NFRU_Dx12::PacingMode()const {std::lock_guard l(p->statusMutex);return p->mode=="Handshake"?"Handshake":p->mode=="CPU fallback"?"CPU fallback":p->mode=="Unavailable"?"Unavailable":p->mode=="Suspended"?"Suspended":"Not initialized";}
std::string NFRU_Dx12::PacingReason()const{std::lock_guard l(p->statusMutex);return p->reason+(p->inputStatus.empty()?"":" | "+p->inputStatus)+(p->metrics.empty()?"":" | "+p->metrics);}
void NFRU_Dx12::CreateObjects(ID3D12Device* d){if(!p->dev){_device=d;p->dev=d;}}
void NFRU_Dx12::ReleaseObjects(){BeforeResize();ReleaseResourceCopies();}
void NFRU_Dx12::CreateContext(ID3D12Device* d,FG_Constants& c){CreateObjects(d);_constants=c;}
void NFRU_Dx12::EvaluateState(ID3D12Device* d,FG_Constants& c){if(p->handle&&(State::Instance().fgChanged||_constants.flags!=c.flags||_constants.displayWidth!=c.displayWidth||_constants.displayHeight!=c.displayHeight))BeforeResize();CreateContext(d,c);_framesToInterpolate=std::clamp(Config::Instance()->NfruMultiplier.value_or_default(),2,4)-1;if(Config::Instance()->IsFGEnabled())Activate();else Deactivate();}
void NFRU_Dx12::Activate(){if(!_isActive){UpdateTarget();_isActive=true;}}
void NFRU_Dx12::Deactivate(){_isActive=false;}
void NFRU_Dx12::DestroyFGContext(){Deactivate();ReleaseObjects();}
bool NFRU_Dx12::Shutdown(){DestroyFGContext();return true;}
bool NFRU_Dx12::ReleaseSwapchain(HWND){BeforeResize();_swapChain=nullptr;return true;}
void* NFRU_Dx12::FrameGenerationContext(){return p.get();}
void* NFRU_Dx12::SwapchainContext(){return p.get();}
bool NFRU_Dx12::SetInterpolatedFrameCount(UINT n){if(n>3)return false;_framesToInterpolate=int(n);return true;}
void NFRU_Dx12::SetCommandQueue(FG_ResourceType,ID3D12CommandQueue* q){if(!_gameCommandQueue){_gameCommandQueue=q;p->queue=q;}}
HRESULT NFRU_Dx12::BeforeResize(){std::lock_guard lock(p->operationMutex);try{p->clear();MenuOverlayDx::CleanupRenderTarget(true,_hwnd);ReleaseResourceCopies();for(int i=0;i<BUFFER_COUNT;++i){std::unique_lock lock(_resourceMutex[i]);_frameResources[i].clear();}return S_OK;}catch(const std::exception& e){p->status("Unavailable",e.what());return DXGI_ERROR_DEVICE_REMOVED;}}
void NFRU_Dx12::ColorSpace(DXGI_COLOR_SPACE_TYPE s){if(p->colorSpace!=s){BeforeResize();p->colorSpace=s;}}
bool NFRU_Dx12::CreateSwapchainInternal(IDXGIFactory* f,ID3D12CommandQueue* q,DXGI_SWAP_CHAIN_DESC* d,IDXGISwapChain** out){DXGI_SWAP_CHAIN_DESC1 s{};s.Width=d->BufferDesc.Width;s.Height=d->BufferDesc.Height;s.Format=d->BufferDesc.Format;s.SampleDesc=d->SampleDesc;s.BufferUsage=d->BufferUsage;s.BufferCount=d->BufferCount;s.Flags=d->Flags;IDXGISwapChain1* sc=nullptr;if(!CreateSwapchain1Internal(f,q,d->OutputWindow,&s,nullptr,&sc))return false;*out=sc;return true;}
bool NFRU_Dx12::CreateSwapchain1Internal(IDXGIFactory* f,ID3D12CommandQueue* q,HWND window,DXGI_SWAP_CHAIN_DESC1* d,DXGI_SWAP_CHAIN_FULLSCREEN_DESC* full,IDXGISwapChain1** out){
 if(!out||!d||!q||(full&&!full->Windowed))return false;
 try{ck(q->GetDevice(IID_PPV_ARGS(&p->dev)),"device");_device=p->dev.Get();p->queue=q;_gameCommandQueue=q;_hwnd=window;State::Instance().swapchainApi=API::DX12;
  ComPtr<IDXGIFactory2> factory;ck(f->QueryInterface(IID_PPV_ARGS(&factory)),"factory2");auto desc=*d;desc.Scaling=DXGI_SCALING_STRETCH;desc.SwapEffect=DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;desc.AlphaMode=DXGI_ALPHA_MODE_IGNORE;desc.Flags=0;desc.BufferUsage|=DXGI_USAGE_SHADER_INPUT|DXGI_USAGE_RENDER_TARGET_OUTPUT;desc.BufferCount=std::clamp(desc.BufferCount,2u,4u);desc.SampleDesc={1,0};if(!desc.Width||!desc.Height){RECT r{};GetClientRect(window,&r);desc.Width=r.right;desc.Height=r.bottom;}
  ComPtr<IDXGISwapChain1> real;InternalScope internal;ck(factory->CreateSwapChainForComposition(q,&desc,nullptr,&real),"producer swapchain");ComPtr<IDXGISwapChain4> r4;ck(real.As(&r4),"producer swapchain4");p->game=new NfruGameSwapchain(r4.Get(),this,window,d->Flags,q);*out=p->game;_swapChain=p->game;return true;
 }catch(const std::exception& e){p->status("Unavailable",e.what());LOG_ERROR("NFRU swapchain: {}",e.what());return false;}}
bool NFRU_Dx12::SetResource(Dx12Resource* in){
 if(!in||!in->resource)return false;int i=in->frameIndex<0?GetIndex():in->frameIndex;if(i<0||i>=BUFFER_COUNT)return false;
 std::unique_lock lock(_resourceMutex[i]);Dx12Resource r=*in;r.copy=nullptr;
 if(in->validity==FG_ResourceValidity::ValidNow||in->validity==FG_ResourceValidity::ValidButMakeCopy){if(!in->cmdList||!_device)return false;auto& copy=_resourceCopy[i][in->type];if(!CopyResource(in->cmdList,in->resource,&copy,in->state))return false;r.copy=copy;r.state=D3D12_RESOURCE_STATE_COPY_DEST;r.validity=FG_ResourceValidity::UntilPresent;}
 _frameResources[i][in->type]=r;if(in->type==FG_ResourceType::HudlessColor)_noHudless[i]=false;if(in->type==FG_ResourceType::UIColor)_noUi[i]=false;SetResourceReady(in->type,i);return true;
}
HRESULT NFRU_Dx12::SubmitFrame(IDXGISwapChain4* producer,UINT sync,UINT flags){
 if(flags&DXGI_PRESENT_TEST)return S_OK;
 const auto cpuStart=std::chrono::steady_clock::now();auto cpuMs=[&](auto t){return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count();};
 std::lock_guard lock(p->operationMutex);try{
  double cpuGate=0;const auto foreground=GetForegroundWindow();const bool focused=foreground&&GetAncestor(foreground,GA_ROOT)==GetAncestor(_hwnd,GA_ROOT);
  if(focused)p->sawForeground=true;
  if(IsIconic(_hwnd)||(p->sawForeground&&!focused)){
   requested=false;if(!p->suspended){p->clear();MenuOverlayDx::CleanupRenderTarget(true,_hwnd);MenuOverlayBase::HideMenu();p->suspended=true;p->status("Suspended","Window inactive or minimized; frame generation and display submission paused");LOG_INFO("NFRU presentation suspended on focus loss");}return S_OK;
  }
  if(p->suspended){p->suspended=false;p->historyValid=false;p->anchor=0;LOG_INFO("NFRU presentation resumed with history reset");}
  if(p->game)MenuOverlayDx::Present(p->game,sync,flags,nullptr,p->queue.Get(),_hwnd,false);
  ComPtr<ID3D12Resource> source;ck(producer->GetBuffer(producer->GetCurrentBackBufferIndex(),IID_PPV_ARGS(&source)),"backbuffer");auto desc=source->GetDesc();if(p->sw&&(p->sw!=desc.Width||p->sh!=desc.Height||p->format!=desc.Format))p->clear();if(!p->sw)p->init(_hwnd,source.Get());
  auto& r=p->ring[p->frame%3];auto gateStart=std::chrono::steady_clock::now();p->wait(r.fence);cpuGate+=cpuMs(gateStart);const UINT queryBase=UINT(p->frame%3)*3;
  if(r.fence&&r.measuredGenerated&&p->timingHz){auto* t=p->timingMap+queryBase;const double scale=1000.0/double(p->timingHz);p->gpuNN=double(t[1]-t[0])*scale;p->gpuBlend=double(t[2]-t[1])*scale;}
  r.keepInputs.clear();ck(r.allocator->Reset(),"allocator reset");ck(r.list->Reset(r.allocator.Get(),nullptr),"list reset");auto c=r.list.Get();c->EndQuery(p->timing.Get(),D3D12_QUERY_TYPE_TIMESTAMP,queryBase);
  const int fi=GetIndexWillBeDispatched();std::optional<Dx12Resource> depth,mv,hud;
  {std::shared_lock lock(_resourceMutex[fi]);auto capture=[&](FG_ResourceType type,std::optional<Dx12Resource>& out){auto it=_frameResources[fi].find(type);if(it!=_frameResources[fi].end()){out=it->second;r.keepInputs.emplace_back(out->GetResource());}};capture(FG_ResourceType::Depth,depth);capture(FG_ResourceType::Velocity,mv);capture(FG_ResourceType::HudlessColor,hud);}
  const auto validRect=[](std::optional<Dx12Resource>& in){if(!in)return false;auto d=in->GetResource()->GetDesc();auto w=in->width?in->width:d.Width;auto h=in->height?in->height:d.Height;return w&&h&&in->left<=d.Width&&w<=d.Width-in->left&&in->top<=d.Height&&h<=d.Height-in->top;};
  const bool generate=!MenuOverlayBase::IsVisible()&&validRect(depth)&&validRect(mv)&&!IsJitteredMVs()&&requested&&IsActive()&&!IsPaused()&&depth&&mv&&Config::Instance()->IsFGEnabled();requested=false;
  unsigned n=generate?unsigned(std::clamp(Config::Instance()->NfruMultiplier.value_or_default(),2,4)):1;if(p->lastMultiplier!=n){p->historyValid=false;p->lastMultiplier=n;LOG_INFO("NFRU native multiplier applied: {} outputs",n);}_framesToInterpolate=int(n)-1;{std::lock_guard status(p->statusMutex);p->inputStatus=generate?std::format("{} outputs per real frame",n):IsJitteredMVs()?"Real frames only: jittered motion vectors are not supported":"Real frames only: inactive FG or missing/unsupported input resources";}
  if(generate){
   auto snapshot=[&](Dx12Resource& in,ID3D12Resource** out){auto src=in.GetResource();auto desc=src->GetDesc();UINT w=UINT(in.width?in.width:desc.Width),h=in.height?in.height:desc.Height;if(!in.left&&!in.top&&w==desc.Width&&h==desc.Height)return CopyResource(c,src,out,in.state);if(!CreateBufferResourceWithSize(_device,src,D3D12_RESOURCE_STATE_COPY_DEST,out,w,h,false,in.type==FG_ResourceType::Depth))return false;barrier(c,src,in.state,D3D12_RESOURCE_STATE_COPY_SOURCE);D3D12_TEXTURE_COPY_LOCATION a{},b{};a.pResource=src;a.Type=D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;b.pResource=*out;b.Type=D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;D3D12_BOX box{in.left,in.top,0,in.left+w,in.top+h,1};c->CopyTextureRegion(&b,0,0,0,&a,&box);barrier(c,src,D3D12_RESOURCE_STATE_COPY_SOURCE,in.state);return true;};
   if(!snapshot(*depth,&r.depth)||!snapshot(*mv,&r.mv))throw std::runtime_error("NFRU input snapshot failed");
   if(hud&&validRect(hud)&&!snapshot(*hud,&r.hud))throw std::runtime_error("NFRU HUD snapshot failed");
   ID3D12Resource* color=source.Get();ID3D12Resource* hudInput=hud&&validRect(hud)?r.hud:nullptr;
   if(r.sceneColor){p->blit(c,source.Get(),D3D12_RESOURCE_STATE_PRESENT,r.sceneColor.Get(),UINT(p->frame%3)*8+4);color=r.sceneColor.Get();if(hudInput&&hudInput->GetDesc().Format==DXGI_FORMAT_B8G8R8A8_UNORM){p->blit(c,hudInput,D3D12_RESOURCE_STATE_COPY_DEST,r.hudColor.Get(),UINT(p->frame%3)*8+5);barrier(c,r.hudColor.Get(),D3D12_RESOURCE_STATE_COMMON,D3D12_RESOURCE_STATE_COPY_DEST);hudInput=r.hudColor.Get();}}
   auto& x=p->params;x.Set("Width",UINT(desc.Width));x.Set("Height",desc.Height);x.Set("DLSSG.Backbuffer",color);x.Set("DLSSG.Depth",r.depth);x.Set("DLSSG.MVecs",r.mv);x.Set("DLSSG.HUDLess",hudInput);x.Set("DLSSG.MVecsSubrectWidth",UINT(r.mv->GetDesc().Width));x.Set("DLSSG.MVecsSubrectHeight",r.mv->GetDesc().Height);x.Set("DLSSG.DepthSubrectWidth",UINT(r.depth->GetDesc().Width));x.Set("DLSSG.DepthSubrectHeight",r.depth->GetDesc().Height);
   x.Set("DLSSG.MvecScaleX",_mvScaleX[fi]);x.Set("DLSSG.MvecScaleY",_mvScaleY[fi]);x.Set("DLSSG.JitterOffsetX",_jitterX[fi]);x.Set("DLSSG.JitterOffsetY",_jitterY[fi]);x.Set("DLSSG.CameraNear",_cameraNear[fi]);x.Set("DLSSG.CameraFar",IsInfiniteDepth()?0.0f:_cameraFar[fi]);x.Set("DLSSG.CameraFOV",_cameraVFov[fi]);x.Set("FSR.frameTimeDelta",float(_ftDelta[fi]));x.Set("DLSSG.DepthInverted",UINT(IsInvertedDepth()));x.Set("DLSSG.ColorBuffersHDR",UINT(IsHdr()));x.Set("DLSSG.MvecJittered",UINT(IsJitteredMVs()));x.Set("DLSSG.Reset",UINT(_reset[fi]||!p->historyValid));
   x.Set("DLSSG.CameraMotionIncluded",UINT(State::Instance().activeFgInput==FGInput::FSRFG||p->cameraIncluded[fi]));
   x.Set("DLSSG.CameraViewToClip",p->projectionValid[fi]?static_cast<void*>(p->projection[fi]):nullptr);
   const char* pos[]={"DLSSG.CameraPosX","DLSSG.CameraPosY","DLSSG.CameraPosZ"};const char* right[]={"DLSSG.CameraRightX","DLSSG.CameraRightY","DLSSG.CameraRightZ"};const char* up[]={"DLSSG.CameraUpX","DLSSG.CameraUpY","DLSSG.CameraUpZ"};const char* fwd[]={"DLSSG.CameraFwdX","DLSSG.CameraFwdY","DLSSG.CameraFwdZ"};for(int axis=0;axis<3;++axis){x.Set(pos[axis],_cameraPosition[fi][axis]);x.Set(right[axis],_cameraRight[fi][axis]);x.Set(up[axis],_cameraUp[fi][axis]);x.Set(fwd[axis],_cameraForward[fi][axis]);}
   x.Set("DLSSG.MultiFrameCount",n-1);x.Set("DLSSG.OutputReal",static_cast<ID3D12Resource*>(nullptr));
   if(!p->handle&&p->sdk.D3D12_CreateFeature(c,NVSDK_NGX_Feature_FrameGeneration,&x,&p->handle)!=NVSDK_NGX_Result_Success)throw std::runtime_error("NFRU create failed");
   barrier(c,color,D3D12_RESOURCE_STATE_COMMON,D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
   for(unsigned k=0;k<n-1;++k){x.Set("DLSSG.MultiFrameIndex",k+1);x.Set("DLSSG.OutputInterpolated",r.generated[k].Get());if(p->sdk.D3D12_EvaluateFeature(c,p->handle,&x,nullptr)!=NVSDK_NGX_Result_Success)throw std::runtime_error("NFRU generation failed");}
   barrier(c,color,D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,D3D12_RESOURCE_STATE_COMMON);if(hudInput==r.hudColor.Get()&&r.hudColor)barrier(c,hudInput,D3D12_RESOURCE_STATE_COPY_DEST,D3D12_RESOURCE_STATE_COMMON);_lastDispatchedFrame=_frameCount;p->historyValid=true;
  }
  r.measuredGenerated=generate;if(!generate)p->historyValid=false;
  c->EndQuery(p->timing.Get(),D3D12_QUERY_TYPE_TIMESTAMP,queryBase+1);gateStart=std::chrono::steady_clock::now();
  std::vector<unsigned> slots;p->controller.Run([&]{if(p->handshake)slots=p->handshake->acquire(n);else for(unsigned i=0;i<n;++i){unsigned id=p->cursor++%12;if(p->tickets[id])p->cpu->waitTicket(p->tickets[id]);slots.push_back(id);}});cpuGate+=cpuMs(gateStart);
  for(unsigned k=0;k<n;++k)p->blit(c,k+1<n?r.generated[k].Get():source.Get(),k+1<n?D3D12_RESOURCE_STATE_UNORDERED_ACCESS:D3D12_RESOURCE_STATE_PRESENT,p->images[slots[k]].Get(),UINT(p->frame%3)*8+k);
  c->EndQuery(p->timing.Get(),D3D12_QUERY_TYPE_TIMESTAMP,queryBase+2);c->ResolveQueryData(p->timing.Get(),D3D12_QUERY_TYPE_TIMESTAMP,queryBase,3,p->timingRead.Get(),queryBase*sizeof(UINT64));
  ck(c->Close(),"list close");ID3D12CommandList* lists[]={c};p->queue->ExecuteCommandLists(1,lists);r.fence=++p->fenceValue;ck(p->queue->Signal(p->fence.Get(),r.fence),"ready signal");
  UINT64 period=UINT64(std::clamp(_ftDelta[fi]>0?_ftDelta[fi]:16.6667,1.0,1000.0)*10000.0);auto now=public_mfg::presentationTime100ns();if(p->handshake||!p->anchor||p->anchor+period<now)p->anchor=now;UINT64 frame=++p->frame;
  p->controller.Run([&]{if(p->handshake){public_mfg::Batch b;b.frameId=frame;b.multiplier=n;b.anchorInterrupt=p->anchor;b.period100ns=period;b.slots=slots;p->handshake->schedule(b);p->queueAhead=p->handshake->queueLeadMs();p->timelineResets=p->handshake->timelineResets();}else{mfg::Batch b;b.frameId=frame;b.multiplier=n;auto f=UINT64(mfg::frequency());auto ticks=[&](UINT64 t){return INT64(t/10000000*f+t%10000000*f/10000000);};b.anchorQpc=ticks(p->anchor);b.periodQpc=ticks(period);for(unsigned k=0;k<n;++k){b.outputs[k].image=p->images[slots[k]];b.outputs[k].readyFence=p->fence;b.outputs[k].readyValue=r.fence;b.outputs[k].state=D3D12_RESOURCE_STATE_COMMON;}auto ticket=p->cpu->submit(b);for(auto id:slots)p->tickets[id]=ticket;}});
  p->anchor+=period;auto presentStart=std::chrono::steady_clock::now();InternalScope internal;auto hr=producer->Present(0,0);p->producerMs=cpuMs(presentStart);p->gateMs=cpuGate;p->submitMs=cpuMs(cpuStart);++p->perfCount;
  {std::lock_guard status(p->statusMutex);p->metrics=std::format("GPU NN {:.2f} ms, blend {:.2f} ms; CPU submit {:.2f} ms (reuse {:.2f}, producer {:.2f}); reserved ahead {:.2f} ms; timeline resyncs {}",p->gpuNN,p->gpuBlend,p->submitMs,p->gateMs,p->producerMs,p->queueAhead,p->timelineResets)+" (GPU: last completed generated batch)";}
  if(SUCCEEDED(hr))p->rates.Record(Util::MillisecondsNow(),n);if(p->perfCount%120==0)LOG_INFO("NFRU perf: {}",p->metrics);return SUCCEEDED(hr)?S_OK:hr;
 }catch(const std::exception& e){p->status("Unavailable",e.what());LOG_ERROR("NFRU presentation failed: {}",e.what());return DXGI_ERROR_DEVICE_REMOVED;}
}

void NFRU_Dx12::DetachGameSwapchain(NfruGameSwapchain* sc){if(p->game==sc){p->game=nullptr;_swapChain=nullptr;}}

void NFRU_Dx12::SetCameraInput(const float* matrix,bool included){auto i=GetIndex();p->projectionValid[i]=matrix!=nullptr;if(matrix)std::copy(matrix,matrix+16,p->projection[i]);p->cameraIncluded[i]=included;}

