#pragma once
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <wrl/client.h>
#include <memory>
#include <vector>
#include <string>
namespace public_mfg {
using Microsoft::WRL::ComPtr;
UINT64 presentationTime100ns();                                                    
struct Options {
    unsigned width=1920,height=1080,buffers=12;
    DXGI_FORMAT format=DXGI_FORMAT_B8G8R8A8_UNORM;
    bool lowLatency=true;
    bool debug=true, interruptEveryOutput=true, cpuReadyBatch=false;
    std::string logPrefix="public_mfg";
};
struct Batch {
    UINT64 frameId=0,anchorInterrupt=0,period100ns=0;
    unsigned multiplier=4;
    std::vector<unsigned> slots;                                          
};
                                                                             
                                                                         
                                                                           
class Presenter {
public:
    Presenter(ID3D12Device*,ID3D12CommandQueue*,HWND,const Options&);
    ~Presenter();
    Presenter(const Presenter&)=delete;
    Presenter& operator=(const Presenter&)=delete;
    std::vector<unsigned> acquire(unsigned count);
    ID3D12Resource* image(unsigned slot) const;                                  
    HANDLE sharedImageHandle(unsigned slot) const;                                    
    UINT64 schedule(const Batch&);                                                                       
    void waitGpu(UINT64 value);                                               
    void collectStatistics();
    void finish(unsigned feedbackMs=500);
    UINT64 submitted() const;
    double queueLeadMs() const;
    UINT64 timelineResets() const;
    static std::vector<UINT64> phaseTargets(UINT64 anchor,UINT64 period,unsigned n);
private:
    void trimPending();
    struct Impl;
    std::unique_ptr<Impl> p;
};
}
