#ifndef NOMINMAX
#define NOMINMAX
#endif
extern thread_local bool nfruInternalPresentation;
#include "MfgSwapchain.h"
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>
#include <stdexcept>
#include <atomic>
#include <cstdio>
#include <algorithm>

namespace mfg {
INT64 qpc(){LARGE_INTEGER n;QueryPerformanceCounter(&n);return n.QuadPart;}
INT64 frequency(){static const INT64 f=[](){LARGE_INTEGER n;QueryPerformanceFrequency(&n);return n.QuadPart;}();return f;}
std::vector<INT64> targets(INT64 anchor, INT64 period, unsigned n){
    if(n<1||n>4||anchor<0||period<n||anchor>INT64_MAX-period)throw std::invalid_argument("invalid MFG timeline");
    std::vector<INT64> r;for(unsigned i=1;i<=n;i++)r.push_back(anchor+(period/n)*i+(period%n)*i/n);return r;
}
static void check(HRESULT hr,const char* what){if(FAILED(hr)){char s[180];sprintf_s(s,"%s failed %08lx",what,(unsigned long)hr);throw std::runtime_error(s);}}
static void waitFence(ID3D12Fence* fence,UINT64 value,HANDLE event){
    UINT64 c=fence->GetCompletedValue();if(c==UINT64_MAX)throw std::runtime_error("device removed while waiting");if(c>=value)return;
    check(fence->SetEventOnCompletion(value,event),"SetEventOnCompletion");
    if(WaitForSingleObject(event,5000)!=WAIT_OBJECT_0)throw std::runtime_error("GPU fence timeout");
    if(fence->GetCompletedValue()==UINT64_MAX)throw std::runtime_error("device removed");
}
static D3D12_RESOURCE_BARRIER transition(ID3D12Resource* r,D3D12_RESOURCE_STATES a,D3D12_RESOURCE_STATES b){
    D3D12_RESOURCE_BARRIER x{};x.Type=D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;x.Transition={r,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,a,b};return x;
}
struct Swapchain::Impl {
    Options opts;ComPtr<ID3D12Device> device;ComPtr<ID3D12CommandQueue> queue;
    ComPtr<IDXGISwapChain4> sc;ComPtr<ID3D12Fence> copies,retired;
    struct Slot {ComPtr<ID3D12CommandAllocator> allocator;ComPtr<ID3D12GraphicsCommandList> list;Output keepAlive;UINT64 fence=0;};
    std::vector<Slot> slots;std::vector<ComPtr<ID3D12Resource>> backbuffers;
    struct Item{Batch batch;UINT64 ticket;};std::deque<Item> batches;
    std::mutex mutex;std::condition_variable cv;std::thread worker;
    bool stopping=false;UINT64 submitted=0,copied=0,lastFrame=0;INT64 lastTarget=0;
    std::atomic<UINT64> outputs=0;std::atomic<HRESULT> error=S_OK;
    HANDLE copyEvent=nullptr,retireEvent=nullptr,timer=nullptr;
    std::mutex waitMutex;
    FILE* log=nullptr;FILE* csv=nullptr;bool tearing=false;
    ~Impl(){
        if(worker.joinable()){ {std::lock_guard l(mutex);stopping=true;}cv.notify_all();worker.join();}
        if(timer)CloseHandle(timer);if(copyEvent)CloseHandle(copyEvent);if(retireEvent)CloseHandle(retireEvent);
        if(csv)fclose(csv);if(log)fclose(log);
    }
    void until(INT64 target){
                                                                              
                                                                                           
        for(;;){INT64 left=target-qpc();if(left<=0)return;
            if(left>frequency()/2000){
                LARGE_INTEGER due;due.QuadPart=-std::max<INT64>(1,(left-frequency()/5000)*10000000/frequency());
                if(!SetWaitableTimer(timer,&due,0,nullptr,nullptr,FALSE))throw std::runtime_error("SetWaitableTimer");
                if(WaitForSingleObject(timer,5000)!=WAIT_OBJECT_0)throw std::runtime_error("pacing timer timeout");
            }else YieldProcessor();
        }
    }
    void run(){
        try{
            SetThreadDescription(GetCurrentThread(),L"MFG CPU presenter");
            for(;;){Item item;
                {std::unique_lock l(mutex);cv.wait(l,[&]{return stopping||!batches.empty();});if(batches.empty())break;item=std::move(batches.front());batches.pop_front();}cv.notify_all();
                auto& b=item.batch;auto ts=targets(b.anchorQpc,b.periodQpc,b.multiplier);
                for(unsigned i=0;i<b.multiplier;i++){
                    auto& o=b.outputs[i];auto& slot=slots[copied%slots.size()];
                    const INT64 reuseStart=qpc();if(slot.fence)waitFence(copies.Get(),slot.fence,copyEvent);
                    const INT64 reuseEnd=qpc();
                    slot.keepAlive=o;                                                          
                    check(slot.allocator->Reset(),"copy allocator reset");check(slot.list->Reset(slot.allocator.Get(),nullptr),"copy list reset");
                    const unsigned bi=sc->GetCurrentBackBufferIndex();auto* bb=backbuffers[bi].Get();
                    if(o.readyFence)check(queue->Wait(o.readyFence.Get(),o.readyValue),"GPU ready wait");
                    auto pre=transition(bb,D3D12_RESOURCE_STATE_PRESENT,D3D12_RESOURCE_STATE_COPY_DEST);slot.list->ResourceBarrier(1,&pre);
                    if(o.state!=D3D12_RESOURCE_STATE_COPY_SOURCE){auto x=transition(o.image.Get(),o.state,D3D12_RESOURCE_STATE_COPY_SOURCE);slot.list->ResourceBarrier(1,&x);}
                    slot.list->CopyResource(bb,o.image.Get());
                    if(o.state!=D3D12_RESOURCE_STATE_COPY_SOURCE){auto x=transition(o.image.Get(),D3D12_RESOURCE_STATE_COPY_SOURCE,o.state);slot.list->ResourceBarrier(1,&x);}
                    auto post=transition(bb,D3D12_RESOURCE_STATE_COPY_DEST,D3D12_RESOURCE_STATE_PRESENT);slot.list->ResourceBarrier(1,&post);
                    check(slot.list->Close(),"copy close");ID3D12CommandList* commands[]={slot.list.Get()};queue->ExecuteCommandLists(1,commands);
                    check(queue->Signal(copies.Get(),++copied),"copy signal");slot.fence=copied;
                                                                                      
                    const INT64 readyBegin=qpc();
                    waitFence(copies.Get(),copied,copyEvent);
                    const INT64 readyEnd=qpc();
                    until(ts[i]);
                    const INT64 targetEnd=qpc();
                    const INT64 cpuFenceTicks=readyEnd-readyBegin;
                    const INT64 cpuTargetTicks=targetEnd-readyEnd;
                    const INT64 presentBegin=qpc();
                    bool internalOld=nfruInternalPresentation;nfruInternalPresentation=true;
                    HRESULT hr=sc->Present(opts.syncInterval,(tearing&&opts.syncInterval==0)?DXGI_PRESENT_ALLOW_TEARING:0);
                    nfruInternalPresentation=internalOld;const INT64 presentEnd=qpc();check(hr,"Present");
                    UINT dxgiCount=0;HRESULT countHr=sc->GetLastPresentCount(&dxgiCount);
                    ++outputs;
                    fprintf(csv,"%llu,%llu,%u,%u,%.9f,%lld,%lld,%lld,%lld,%lld,%lld,%08lx,%lu,%u,%08lx\n",
                        item.ticket,b.frameId,i,b.multiplier,double(i+1)/b.multiplier,ts[i],presentBegin,
                        cpuFenceTicks,cpuTargetTicks,reuseEnd-reuseStart,presentEnd,(unsigned long)hr,
                        GetCurrentThreadId(),dxgiCount,(unsigned long)countHr);
                }
                                                                                  
                check(queue->Signal(retired.Get(),item.ticket),"batch retirement signal");
            }
            waitFence(copies.Get(),copied,copyEvent);
            fprintf(log,"DONE outputs=%llu submitted_batches=%llu device_removed=%08lx HWFQ_USE=NOT_MEASURED\n",outputs.load(),submitted,(unsigned long)device->GetDeviceRemovedReason());
        }catch(const std::exception& e){error=E_FAIL;fprintf(log,"ERROR %s device_removed=%08lx\n",e.what(),(unsigned long)device->GetDeviceRemovedReason());
            if(SUCCEEDED(device->GetDeviceRemovedReason()))try{check(queue->Signal(copies.Get(),++copied),"failure drain");waitFence(copies.Get(),copied,copyEvent);}catch(...){}
        }
        cv.notify_all();fflush(log);fflush(csv);
    }
};
Swapchain::Swapchain(ID3D12Device* dev,IDXGIFactory4* factory,HWND hwnd,const Options& opts):p(new Impl){
    if(!dev||!factory||!hwnd||opts.bufferCount<2||opts.bufferCount>16||opts.copySlots<4||opts.maxQueuedBatches<1||opts.maxQueuedBatches>8||opts.syncInterval>1)throw std::invalid_argument("invalid swapchain options");
    p->opts=opts;p->device=dev;
    p->log=fopen("NUL","wb");p->csv=fopen("NUL","wb");
    if(!p->log||!p->csv)throw std::runtime_error("cannot create logs");
    fprintf(p->log,"MFG_CPU_SWAPCHAIN QPC_FREQUENCY=%lld\n",frequency());
    fprintf(p->log,"HWFQ_USE=NOT_MEASURED\n");
    fprintf(p->csv,"ticket,frame_id,phase,multiplier,t,target_qpc,present_begin_qpc,cpu_fence_ticks,cpu_target_ticks,copy_reuse_ticks,present_end_qpc,present_hr,present_tid,dxgi_present_count,dxgi_count_hr\n");
    D3D12_COMMAND_QUEUE_DESC q{};q.Type=D3D12_COMMAND_LIST_TYPE_DIRECT;check(dev->CreateCommandQueue(&q,IID_PPV_ARGS(&p->queue)),"present queue");
    p->queue->SetName(L"MFG CPU present queue");
    ComPtr<IDXGIFactory5> f5;BOOL allow=FALSE;if(SUCCEEDED(factory->QueryInterface(IID_PPV_ARGS(&f5))))f5->CheckFeatureSupport(DXGI_FEATURE_PRESENT_ALLOW_TEARING,&allow,sizeof(allow));p->tearing=allow;
    DXGI_SWAP_CHAIN_DESC1 d{};d.Width=opts.width;d.Height=opts.height;d.Format=opts.format;
    d.SampleDesc.Count=1;d.BufferUsage=DXGI_USAGE_RENDER_TARGET_OUTPUT;d.BufferCount=opts.bufferCount;d.SwapEffect=DXGI_SWAP_EFFECT_FLIP_DISCARD;d.Flags=allow?DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING:0;
    ComPtr<IDXGISwapChain1> s;check(factory->CreateSwapChainForHwnd(p->queue.Get(),hwnd,&d,nullptr,nullptr,&s),"swapchain create");check(s.As(&p->sc),"swapchain4");
    factory->MakeWindowAssociation(hwnd,DXGI_MWA_NO_ALT_ENTER);
    check(p->sc->SetColorSpace1(opts.colorSpace),"color space");
    p->backbuffers.resize(opts.bufferCount);for(unsigned i=0;i<opts.bufferCount;i++)check(p->sc->GetBuffer(i,IID_PPV_ARGS(&p->backbuffers[i])),"backbuffer");
    check(dev->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&p->copies)),"copy fence");check(dev->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&p->retired)),"batch fence");
    p->copyEvent=CreateEvent(nullptr,FALSE,FALSE,nullptr);p->retireEvent=CreateEvent(nullptr,FALSE,FALSE,nullptr);
    p->timer=CreateWaitableTimerExW(nullptr,nullptr,CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,TIMER_ALL_ACCESS);
    if(!p->timer)p->timer=CreateWaitableTimerW(nullptr,FALSE,nullptr);
    if(!p->copyEvent||!p->retireEvent||!p->timer)throw std::runtime_error("event/timer create");
    p->slots.resize(opts.copySlots);for(auto& x:p->slots){check(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,IID_PPV_ARGS(&x.allocator)),"copy allocator");check(dev->CreateCommandList(0,D3D12_COMMAND_LIST_TYPE_DIRECT,x.allocator.Get(),nullptr,IID_PPV_ARGS(&x.list)),"copy list");check(x.list->Close(),"initial close");}
    fprintf(p->log,"BACKEND_READY=cpu buffers=%u copy_slots=%u batch_capacity=%u\n",opts.bufferCount,opts.copySlots,opts.maxQueuedBatches);fflush(p->log);
    p->worker=std::thread([this]{p->run();});
}
Swapchain::~Swapchain(){try{stop();}catch(...){} }
UINT64 Swapchain::submit(const Batch& b){
    const auto ts=targets(b.anchorQpc,b.periodQpc,b.multiplier);
    for(unsigned i=0;i<b.multiplier;i++){
        const auto& o=b.outputs[i];if(!o.image||!o.readyFence||!o.readyValue)throw std::invalid_argument("image and GPU readiness fence required");
        auto d=o.image->GetDesc();if(d.Dimension!=D3D12_RESOURCE_DIMENSION_TEXTURE2D||d.Width!=p->opts.width||d.Height!=p->opts.height||d.Format!=p->opts.format||d.MipLevels!=1||d.DepthOrArraySize!=1||d.SampleDesc.Count!=1)throw std::invalid_argument("display image description mismatch");
    }
    std::unique_lock l(p->mutex);
    if((p->submitted&&b.frameId<=p->lastFrame)||ts.front()<=p->lastTarget)throw std::invalid_argument("batch IDs/targets must be strictly increasing");
    if(!p->cv.wait_for(l,std::chrono::seconds(5),[&]{return p->stopping||FAILED(p->error)||p->batches.size()<p->opts.maxQueuedBatches;}))throw std::runtime_error("batch queue timeout");
    if(p->stopping||FAILED(p->error))throw std::runtime_error("presenter stopped/failed");
    UINT64 ticket=++p->submitted;p->lastFrame=b.frameId;p->lastTarget=ts.back();p->batches.push_back({b,ticket});l.unlock();p->cv.notify_all();return ticket;
}
void Swapchain::waitTicket(UINT64 v){
    std::lock_guard l(p->waitMutex);if(FAILED(p->error))throw std::runtime_error("presenter failed");waitFence(p->retired.Get(),v,p->retireEvent);if(FAILED(p->error))throw std::runtime_error("presenter failed");
}
void Swapchain::drain(){UINT64 v;{std::lock_guard l(p->mutex);v=p->submitted;}if(v)waitTicket(v);}
void Swapchain::stop(){if(!p||!p->worker.joinable())return;{std::lock_guard l(p->mutex);p->stopping=true;}p->cv.notify_all();p->worker.join();}
HRESULT Swapchain::failure()const{return p->error;}
UINT64 Swapchain::submittedOutputs()const{return p->outputs;}
}
