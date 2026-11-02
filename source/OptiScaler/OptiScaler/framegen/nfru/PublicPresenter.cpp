#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "PublicPresenter.h"
#include <d3d11_4.h>
#include <d3d11sdklayers.h>
#include <dxgi1_6.h>
#include <dcomp.h>
#include <presentation.h>
#include <cstdio>
#include <stdexcept>
#include <algorithm>
#include <set>

namespace public_mfg {
UINT64 presentationTime100ns(){
    LARGE_INTEGER t,f;QueryPerformanceCounter(&t);QueryPerformanceFrequency(&f);
                                                                           
                                                                              
                                                                             
    const UINT64 value=UINT64(t.QuadPart),freq=UINT64(f.QuadPart);
    return value/freq*10000000+(value%freq)*10000000/freq;
}
static INT64 qpc(){LARGE_INTEGER t;QueryPerformanceCounter(&t);return t.QuadPart;}
static void ck(HRESULT h,const char* what){if(FAILED(h)){char b[180];sprintf_s(b,"%s: %08lx",what,(unsigned long)h);throw std::runtime_error(b);}}
std::vector<UINT64> Presenter::phaseTargets(UINT64 a,UINT64 p,unsigned n){
    if(n<1||n>4||p<n||a>UINT64_MAX-p)throw std::invalid_argument("invalid phase timeline");
    std::vector<UINT64> t;for(unsigned i=1;i<=n;i++)t.push_back(a+p/n*i+p%n*i/n);return t;
}
struct Presenter::Impl {
    Options options;ComPtr<ID3D12Device> d12;ComPtr<ID3D12CommandQueue> queue;
    ComPtr<ID3D11Device> d11;ComPtr<ID3D11Device5> d115;
    ComPtr<ID3D11DeviceContext> context;ComPtr<ID3D11DeviceContext4> c4;
    ComPtr<ID3D12Fence> ready12;ComPtr<ID3D11Fence> ready11;
    ComPtr<IPresentationFactory> factory;ComPtr<IPresentationManager> manager;ComPtr<IPresentationSurface> surface;
    ComPtr<IDCompositionDevice> composition;ComPtr<IDCompositionTarget> target;ComPtr<IDCompositionVisual> visual;
    ComPtr<IUnknown> content;
    struct Slot {ComPtr<ID3D11Texture2D> tex11;ComPtr<ID3D12Resource> tex12;ComPtr<IPresentationBuffer> buffer;HANDLE available=nullptr;bool acquired=false;};
    std::vector<Slot> slots;
    HANDLE surfaceHandle=nullptr,lost=nullptr,readyEvent=nullptr,statsAvailable=nullptr;
    FILE* log=nullptr,*submissions=nullptr,*stats=nullptr,*readiness=nullptr;
    UINT64 fenceValue=0,count=0,lastTarget=0,lastId=0,lastPeriod=0,resets=0;double leadMs=0;
    unsigned nextSlot=0;DWORD owner=GetCurrentThreadId();bool finished=false;
    void thread()const{if(GetCurrentThreadId()!=owner)throw std::runtime_error("presentation API used from wrong thread");}
    ~Impl(){
                                                                            
        if(visual)visual->SetContent(nullptr);if(composition)composition->Commit();
        manager.Reset();surface.Reset();content.Reset();visual.Reset();target.Reset();composition.Reset();
        for(auto& s:slots)if(s.available)CloseHandle(s.available);
        if(statsAvailable)CloseHandle(statsAvailable);if(lost)CloseHandle(lost);if(surfaceHandle)CloseHandle(surfaceHandle);if(readyEvent)CloseHandle(readyEvent);
        if(log)fclose(log);if(submissions)fclose(submissions);if(stats)fclose(stats);if(readiness)fclose(readiness);
    }
};
Presenter::Presenter(ID3D12Device* device,ID3D12CommandQueue* queue,HWND hwnd,const Options& o):p(new Impl){
    if(!device||!queue||!hwnd||o.buffers<8||o.buffers>24||!o.width||!o.height)throw std::invalid_argument("invalid presenter config");
    p->d12=device;p->queue=queue;p->options=o;
    p->log=fopen("NUL","wb");p->submissions=fopen("NUL","wb");p->stats=fopen("NUL","wb");
    p->readiness=fopen("NUL","wb");
    if(!p->log||!p->submissions||!p->stats||!p->readiness)throw std::runtime_error("log create");
    fprintf(p->readiness,"frame_id,cpu_ready_batch,signal_begin_time100ns,signal_end_time100ns,gate_end_time100ns,interop_end_time100ns,completed_before_gate,completed_after_gate,ready_fence\n");
    fprintf(p->log,"readiness_mode=%s\n",o.cpuReadyBatch?"cpu-batch-complete":"queued-shared-wait");
    fprintf(p->log,"MFG_HANDSHAKE_PRESENTATION clock_source=QPC_scaled_100ns\n");
    fprintf(p->submissions,"present_id,frame_id,phase,multiplier,target_time100ns,submit_time100ns,return_time100ns,submit_qpc,return_qpc,ready_fence,slot,force_interrupt,hr,requested_target_time100ns,schedule_shift_time100ns\n");
    fprintf(p->stats,"kind,present_id,display_time100ns,duration_time100ns,status,report_time100ns,adapter_high,adapter_low,source\n");
    ComPtr<IDXGIFactory4> dxgi;ck(CreateDXGIFactory2(0,IID_PPV_ARGS(&dxgi)),"DXGI factory");
    ComPtr<IDXGIAdapter> adapter;ck(dxgi->EnumAdapterByLuid(device->GetAdapterLuid(),IID_PPV_ARGS(&adapter)),"same adapter");
    UINT flags=D3D11_CREATE_DEVICE_BGRA_SUPPORT|D3D11_CREATE_DEVICE_SINGLETHREADED|D3D11_CREATE_DEVICE_PREVENT_INTERNAL_THREADING_OPTIMIZATIONS;
    if(o.debug)flags|=D3D11_CREATE_DEVICE_DEBUG;
    ck(D3D11CreateDevice(adapter.Get(),D3D_DRIVER_TYPE_UNKNOWN,nullptr,flags,nullptr,0,D3D11_SDK_VERSION,&p->d11,nullptr,&p->context),"D3D11 presentation device");
    ck(p->d11.As(&p->d115),"D3D11Device5");ck(p->context.As(&p->c4),"D3D11Context4");
    ck(CreatePresentationFactory(p->d11.Get(),IID_PPV_ARGS(&p->factory)),"CreatePresentationFactory");
    fprintf(p->log,"supported=%u independent_flip_capable=%u\n",unsigned(p->factory->IsPresentationSupported()),unsigned(p->factory->IsPresentationSupportedWithIndependentFlip()));
    if(!p->factory->IsPresentationSupportedWithIndependentFlip())throw std::runtime_error("public direct presentation unavailable; use separate CPU/DXGI baseline");
    ck(p->factory->CreatePresentationManager(&p->manager),"presentation manager");
    ck(p->manager->GetLostEvent(&p->lost),"lost event");
    ck(p->manager->GetPresentStatisticsAvailableEvent(&p->statsAvailable),"statistics available event");
    for(auto k:{PresentStatisticsKind_PresentStatus,PresentStatisticsKind_CompositionFrame,PresentStatisticsKind_IndependentFlipFrame})ck(p->manager->EnablePresentStatisticsKind(k,true),"statistics enable");
    ck(DCompositionCreateSurfaceHandle(COMPOSITIONOBJECT_ALL_ACCESS,nullptr,&p->surfaceHandle),"surface handle");
    ck(p->manager->CreatePresentationSurface(p->surfaceHandle,&p->surface),"presentation surface");
    ck(p->surface->SetAlphaMode(DXGI_ALPHA_MODE_IGNORE),"alpha");ck(p->surface->SetColorSpace(DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709),"color space");
    RECT rect{0,0,LONG(o.width),LONG(o.height)};ck(p->surface->SetSourceRect(&rect),"source rect");PresentationTransform transform{};transform.M11=transform.M22=1;ck(p->surface->SetTransform(&transform),"transform");
    ComPtr<IDXGIDevice> dxgiDevice;ck(p->d11.As(&dxgiDevice),"DXGI device");
    ck(DCompositionCreateDevice(dxgiDevice.Get(),IID_PPV_ARGS(&p->composition)),"composition device");
    ck(p->composition->CreateTargetForHwnd(hwnd,TRUE,&p->target),"composition target");ck(p->composition->CreateVisual(&p->visual),"visual");
    ck(p->composition->CreateSurfaceFromHandle(p->surfaceHandle,&p->content),"surface content");
    ck(p->visual->SetContent(p->content.Get()),"visual content");ck(p->target->SetRoot(p->visual.Get()),"root visual");ck(p->composition->Commit(),"composition commit");
    ck(device->CreateFence(0,D3D12_FENCE_FLAG_SHARED,IID_PPV_ARGS(&p->ready12)),"shared readiness fence");
    HANDLE shared=nullptr;ck(device->CreateSharedHandle(p->ready12.Get(),nullptr,GENERIC_ALL,nullptr,&shared),"shared fence handle");
    HRESULT h=p->d115->OpenSharedFence(shared,IID_PPV_ARGS(&p->ready11));CloseHandle(shared);ck(h,"open readiness fence in D3D11");
    p->readyEvent=CreateEvent(nullptr,FALSE,FALSE,nullptr);if(!p->readyEvent)throw std::runtime_error("ready event");
    p->slots.resize(o.buffers);
    for(auto& s:p->slots){
        D3D11_TEXTURE2D_DESC d{};d.Width=o.width;d.Height=o.height;d.ArraySize=d.MipLevels=d.SampleDesc.Count=1;d.Format=o.format;
        d.BindFlags=D3D11_BIND_RENDER_TARGET|D3D11_BIND_SHADER_RESOURCE;d.MiscFlags=D3D11_RESOURCE_MISC_SHARED|D3D11_RESOURCE_MISC_SHARED_NTHANDLE|D3D11_RESOURCE_MISC_SHARED_DISPLAYABLE;
        ck(p->d11->CreateTexture2D(&d,nullptr,&s.tex11),"displayable texture");
        ComPtr<IDXGIResource1> resource;ck(s.tex11.As(&resource),"shared resource");
        ck(resource->CreateSharedHandle(nullptr,DXGI_SHARED_RESOURCE_READ|DXGI_SHARED_RESOURCE_WRITE,nullptr,&shared),"texture NT handle");
        h=device->OpenSharedHandle(shared,IID_PPV_ARGS(&s.tex12));CloseHandle(shared);ck(h,"D3D12 same-allocation open");
        ck(p->manager->AddBufferFromResource(s.tex11.Get(),&s.buffer),"register displayable buffer");ck(s.buffer->GetAvailableEvent(&s.available),"buffer availability event");
        auto desc=s.tex12->GetDesc();if(!(desc.Flags&D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET))throw std::runtime_error("shared texture not renderable in D3D12");
    }
    fprintf(p->log,"shared_displayable_buffers=%u size=%ux%u render_api=D3D12 states=COMMON_to_RT_to_COMMON gpu_fence_interop=1\n",o.buffers,o.width,o.height);fflush(p->log);
}
Presenter::~Presenter(){if(p&&!p->finished)try{finish(100);}catch(...){} }
void Presenter::trimPending(){
    if(p->options.lowLatency&&p->lastPeriod&&p->lastTarget>presentationTime100ns()+p->lastPeriod){
                                                                                         
        ck(p->manager->CancelPresentsFrom(1),"trim stale presentation backlog");p->lastTarget=0;++p->resets;
    }
}
std::vector<unsigned> Presenter::acquire(unsigned n){
    p->thread();if(n<1||n>4)throw std::invalid_argument("multiplier");trimPending();
    std::vector<unsigned> result;const auto deadline=GetTickCount64()+5000;
    for(unsigned i=0;i<n;i++){
        for(;;){bool found=false;std::vector<HANDLE> handles{p->lost};
            for(unsigned k=0;k<p->slots.size();++k){auto index=(p->nextSlot+k)%p->slots.size();auto& s=p->slots[index];if(s.acquired)continue;
                boolean available=false;ck(s.buffer->IsAvailable(&available),"IsAvailable");
                if(available){s.acquired=true;result.push_back(index);p->nextSlot=(index+1)%p->slots.size();found=true;break;}
                handles.push_back(s.available);
            }
            if(found)break;collectStatistics();if(GetTickCount64()>=deadline)throw std::runtime_error("display buffer reuse timeout");
            const auto waitNow=GetTickCount64();if(waitNow>=deadline)throw std::runtime_error("display buffer reuse timeout");DWORD wait=WaitForMultipleObjects(UINT(handles.size()),handles.data(),FALSE,DWORD(deadline-waitNow));
            if(wait==WAIT_OBJECT_0)throw std::runtime_error("presentation manager lost");if(wait==WAIT_FAILED||wait==WAIT_TIMEOUT)throw std::runtime_error("display buffer reuse wait failed");
        }
    }return result;
}
ID3D12Resource* Presenter::image(unsigned i)const{return p->slots.at(i).tex12.Get();}
HANDLE Presenter::sharedImageHandle(unsigned i)const{
    p->thread();ComPtr<IDXGIResource1> resource;ck(p->slots.at(i).tex11.As(&resource),"share image query");
    HANDLE handle=nullptr;ck(resource->CreateSharedHandle(nullptr,DXGI_SHARED_RESOURCE_READ|DXGI_SHARED_RESOURCE_WRITE,nullptr,&handle),"share image handle");return handle;
}
UINT64 Presenter::schedule(const Batch& b){
    p->thread();auto targets=phaseTargets(b.anchorInterrupt,b.period100ns,b.multiplier);
    if(b.slots.size()!=b.multiplier||std::set<unsigned>(b.slots.begin(),b.slots.end()).size()!=b.multiplier||b.frameId<=p->lastId)throw std::invalid_argument("batch identity/ordering");
    for(auto i:b.slots)if(!p->slots.at(i).acquired)throw std::invalid_argument("slot not acquired");
    const UINT64 signalBegin=presentationTime100ns();
    ck(p->queue->Signal(p->ready12.Get(),++p->fenceValue),"producer ready signal");
    const UINT64 signalEnd=presentationTime100ns(),completedBefore=p->ready12->GetCompletedValue();
    if(p->options.cpuReadyBatch)waitGpu(p->fenceValue);
    const UINT64 gateEnd=presentationTime100ns(),completedAfter=p->ready12->GetCompletedValue();
    if(p->options.cpuReadyBatch&&(completedAfter==UINT64_MAX||completedAfter<p->fenceValue))throw std::runtime_error("batch readiness gate failed");
                                                                             
                                                                                 
    ck(p->c4->Wait(p->ready11.Get(),p->fenceValue),"presentation readiness wait");p->context->Flush();
    const UINT64 interopEnd=presentationTime100ns();
    fprintf(p->readiness,"%llu,%u,%llu,%llu,%llu,%llu,%llu,%llu,%llu\n",b.frameId,unsigned(p->options.cpuReadyBatch),signalBegin,signalEnd,gateEnd,interopEnd,completedBefore,completedAfter,p->fenceValue);
    const auto requested=targets;
                                                                            
                                                                          
    const UINT64 step=b.period100ns/b.multiplier;
    p->lastPeriod=b.period100ns;trimPending();
    if(p->options.lowLatency)targets=phaseTargets(presentationTime100ns()+20000-step,b.period100ns,b.multiplier);
    const UINT64 firstAllowed=std::max(presentationTime100ns()+20000,p->lastTarget? p->lastTarget+step:0);
    const UINT64 shift=targets.front()<firstAllowed?firstAllowed-targets.front():0;
    if(targets.back()>UINT64_MAX-shift)throw std::invalid_argument("shifted timeline overflow");
    for(auto& t:targets)t+=shift;
    ck(p->manager->SetPreferredPresentDuration({b.period100ns/b.multiplier},{0}),"preferred output duration");
    for(unsigned i=0;i<b.multiplier;i++){
        const bool interrupt=p->options.interruptEveryOutput||i+1==b.multiplier;
        ck(p->surface->SetBuffer(p->slots[b.slots[i]].buffer.Get()),"SetBuffer");
        ck(p->manager->SetTargetTime({targets[i]}),"SetTargetTime");ck(p->manager->ForceVSyncInterrupt(interrupt),"ForceVSyncInterrupt");
        UINT64 id=p->manager->GetNextPresentId();UINT64 before=presentationTime100ns();INT64 qp=qpc();HRESULT hr=p->manager->Present();INT64 qe=qpc();UINT64 after=presentationTime100ns();
        fprintf(p->submissions,"%llu,%llu,%u,%u,%llu,%llu,%llu,%lld,%lld,%llu,%u,%u,%08lx,%llu,%llu\n",id,b.frameId,i,b.multiplier,targets[i],before,after,qp,qe,p->fenceValue,b.slots[i],unsigned(interrupt),(unsigned long)hr,requested[i],shift);
        ck(hr,"public Present");p->slots[b.slots[i]].acquired=false;++p->count;
    }
    p->lastTarget=targets.back();const UINT64 reportNow=presentationTime100ns();p->leadMs=double(p->lastTarget>reportNow?p->lastTarget-reportNow:0)/10000.0;p->lastId=b.frameId;collectStatistics();return p->fenceValue;
}
void Presenter::waitGpu(UINT64 value){
    p->thread();UINT64 done=p->ready12->GetCompletedValue();if(done==UINT64_MAX)throw std::runtime_error("D3D12 device removed");
    if(done<value){ck(p->ready12->SetEventOnCompletion(value,p->readyEvent),"GPU reuse event");if(WaitForSingleObject(p->readyEvent,5000)!=WAIT_OBJECT_0)throw std::runtime_error("GPU reuse timeout");}
}
void Presenter::collectStatistics(){
    p->thread();
    for(;;){
        if(WaitForSingleObject(p->statsAvailable,0)!=WAIT_OBJECT_0)break;
        ComPtr<IPresentStatistics> s;HRESULT hr=p->manager->GetNextPresentStatistics(&s);if(hr==S_FALSE)break;ck(hr,"GetNextPresentStatistics");if(!s)break;
        UINT64 id=s->GetPresentId(),now=presentationTime100ns();auto kind=s->GetKind();
        if(kind==PresentStatisticsKind_IndependentFlipFrame){ComPtr<IIndependentFlipFramePresentStatistics> x;ck(s.As(&x),"independent stats");auto luid=x->GetOutputAdapterLUID();
            fprintf(p->stats,"independent,%llu,%llu,%llu,0,%llu,%ld,%lu,%u\n",id,x->GetDisplayedTime().value,x->GetPresentDuration().value,now,luid.HighPart,luid.LowPart,x->GetOutputVidPnSourceId());
        }else if(kind==PresentStatisticsKind_PresentStatus){ComPtr<IPresentStatusPresentStatistics> x;ck(s.As(&x),"status stats");fprintf(p->stats,"status,%llu,0,0,%u,%llu,0,0,0\n",id,unsigned(x->GetPresentStatus()),now);
        }else fprintf(p->stats,"composed,%llu,0,0,0,%llu,0,0,0\n",id,now);
    }
}
void Presenter::finish(unsigned feedbackMs){
    p->thread();if(p->finished)return;waitGpu(p->fenceValue);
    ck(p->manager->CancelPresentsFrom(1),"cancel pending presents before teardown");
    const UINT64 deadline=presentationTime100ns()+UINT64(feedbackMs)*10000;
    while(presentationTime100ns()<deadline){collectStatistics();Sleep(2);}collectStatistics();
                                                                          
    ck(p->manager->CancelPresentsFrom(1),"cancel remaining presents");
    unsigned errors=0;ComPtr<ID3D11InfoQueue> info;
    if(p->options.debug&&SUCCEEDED(p->d11.As(&info))){
        for(UINT64 i=0;i<info->GetNumStoredMessages();i++){SIZE_T size=0;info->GetMessage(i,nullptr,&size);std::vector<unsigned char> mem(size);auto* m=(D3D11_MESSAGE*)mem.data();
            if(SUCCEEDED(info->GetMessage(i,m,&size))&&m->Severity<=D3D11_MESSAGE_SEVERITY_ERROR){fprintf(p->log,"D3D11_ERROR %s\n",m->pDescription);++errors;}}
    }
    fprintf(p->log,"D3D11_errors=%u\n",errors);
    fprintf(p->log,"DONE submitted=%llu D3D12_removed=%08lx D3D11_removed=%08lx\n",p->count,(unsigned long)p->d12->GetDeviceRemovedReason(),(unsigned long)p->d11->GetDeviceRemovedReason());
    fflush(p->log);fflush(p->submissions);fflush(p->stats);fflush(p->readiness);p->finished=true;
    if(errors||FAILED(p->d12->GetDeviceRemovedReason())||FAILED(p->d11->GetDeviceRemovedReason()))throw std::runtime_error("presentation GPU/debug validation failed");
}
UINT64 Presenter::submitted()const{return p->count;}
double Presenter::queueLeadMs()const{return p->leadMs;}
UINT64 Presenter::timelineResets()const{return p->resets;}
}
