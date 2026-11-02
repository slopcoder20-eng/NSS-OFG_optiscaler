                                                                                                          
                                                                                  
                                                             
                                                                                                                    
                                                                
#define NOMINMAX
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include "nfru_engine_dx12.h"
#include <string>
#include <algorithm>
#include <vector>
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")

#define HR(x) do { HRESULT hr_ = (x); if (FAILED(hr_)) { printf("HRESULT 0x%08lx line %d (%s)\n", (unsigned long) hr_, __LINE__, #x); exit(2); } } while (0)

static ID3D12Device*              g_dev;
static ID3D12CommandQueue*        g_q;
static ID3D12CommandAllocator*    g_alloc;
static ID3D12GraphicsCommandList* g_cl;
static ID3D12Fence*               g_fence;
static HANDLE                     g_event;
static uint64_t                   g_fv;

static void submitWait()
{
    HR(g_cl->Close());
    ID3D12CommandList* l[] = { g_cl };
    g_q->ExecuteCommandLists(1, l);
    HR(g_q->Signal(g_fence, ++g_fv));
    HR(g_fence->SetEventOnCompletion(g_fv, g_event));
    WaitForSingleObject(g_event, INFINITE);
    HR(g_dev->GetDeviceRemovedReason());
    HR(g_alloc->Reset());
    HR(g_cl->Reset(g_alloc, nullptr));
}

static void transition(ID3D12Resource* r, D3D12_RESOURCE_STATES a, D3D12_RESOURCE_STATES b)
{
    D3D12_RESOURCE_BARRIER rb = {};
    rb.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    rb.Transition.pResource = r;
    rb.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    rb.Transition.StateBefore = a;
    rb.Transition.StateAfter = b;
    g_cl->ResourceBarrier(1, &rb);
}

int main(int argc, char** argv)
{
    setvbuf(stdout, nullptr, _IONBF, 0);
    if (argc < 4) { printf("usage: nfru_engine_test_dx12 <refdir> <W> <H> [bench]\n"); return 1; }
    const std::string dir = argv[1];
    const uint32_t W = atoi(argv[2]), H = atoi(argv[3]);
    const int bench = argc > 4 ? atoi(argv[4]) : 0;

    IDXGIFactory6* factory = nullptr;
    HR(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory)));
    IDXGIAdapter1* adapter = nullptr;
    HR(factory->EnumAdapterByGpuPreference(0, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, IID_PPV_ARGS(&adapter)));
    DXGI_ADAPTER_DESC1 ad;
    adapter->GetDesc1(&ad);
    printf("GPU: %ls\n", ad.Description);
    HR(D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&g_dev)));
    D3D12_COMMAND_QUEUE_DESC qd = {};
    qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    HR(g_dev->CreateCommandQueue(&qd, IID_PPV_ARGS(&g_q)));
    HR(g_dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&g_alloc)));
    HR(g_dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, g_alloc, nullptr, IID_PPV_ARGS(&g_cl)));
    HR(g_dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&g_fence)));
    g_event = CreateEventA(nullptr, FALSE, FALSE, nullptr);

    NfruEngineDX12 eng;
    if (!eng.init(g_dev, W, H)) { printf("engine init failed\n"); return 2; }

                                                                                
    const uint64_t inBytes = (uint64_t) W * H * NFRU_INPUT_CHANNELS;
    const uint64_t outBytes = eng.tensorBytes[NFRU_OUTPUT_TENSOR];
    ID3D12Resource* in = NfruEngineDX12::makeBuffer(g_dev, inBytes, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COMMON, true);
    ID3D12Resource* out = NfruEngineDX12::makeBuffer(g_dev, outBytes, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COMMON, true);

    std::vector<int8_t> host(inBytes);
    FILE* f = fopen((dir + "/in.bin").c_str(), "rb");
    if (!f) { printf("missing %s/in.bin\n", dir.c_str()); return 3; }
    const size_t got = fread(host.data(), 1, host.size(), f);
    fclose(f);
    if (got != host.size()) { printf("in.bin has %zu bytes, expected %llu\n", got, (unsigned long long) inBytes); return 3; }

    uint64_t maxSz = 0;
    for (int t = 0; t <= NFRU_NUM_OPS; ++t) maxSz = eng.tensorBytes[t] > maxSz ? eng.tensorBytes[t] : maxSz;
    ID3D12Resource* up = NfruEngineDX12::makeBuffer(g_dev, inBytes, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ, false);
    ID3D12Resource* rb = NfruEngineDX12::makeBuffer(g_dev, maxSz, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST, false);
    void* p = nullptr;
    HR(up->Map(0, nullptr, &p));
    memcpy(p, host.data(), host.size());
    up->Unmap(0, nullptr);

    transition(in, D3D12_RESOURCE_STATE_COMMON, D3D12_RESOURCE_STATE_COPY_DEST);
    g_cl->CopyBufferRegion(in, 0, up, 0, inBytes);
    transition(in, D3D12_RESOURCE_STATE_COPY_DEST, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
    transition(out, D3D12_RESOURCE_STATE_COMMON, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
    if (!eng.bindIO(in, out, inBytes, outBytes)) { printf("bindIO failed\n"); return 2; }
    eng.record(g_cl);
    submitWait();

                                        
    static const char* kinds[] = { "conv", "concat", "resize" };
    for (int i = 0; i < NFRU_NUM_OPS; ++i)
    {
        const NfruOp& op = g_nfru_ops[i];
        const int t = op.out;
        if (eng.alias[t] >= 0) continue;
        const uint64_t bytes = (uint64_t) eng.dim[t].w * eng.dim[t].h * eng.dim[t].c;
        ID3D12Resource* src = eng.tensor[t];
        transition(src, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);
        g_cl->CopyBufferRegion(rb, 0, src, 0, bytes);
        transition(src, D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        submitWait();
        void* m = nullptr;
        HR(rb->Map(0, nullptr, &m));
        char name[64];
        snprintf(name, sizeof name, "/eng_op%02d_%s.bin", i, kinds[op.kind]);
        FILE* o = fopen((dir + name).c_str(), "wb");
        fwrite(m, 1, bytes, o);
        fclose(o);
        D3D12_RANGE none = { 0, 0 };
        rb->Unmap(0, &none);
    }
    printf("dumped engine tensors to %s\n", dir.c_str());

    if (bench > 0)
    {
        ID3D12QueryHeap* qh = nullptr;
        D3D12_QUERY_HEAP_DESC qhd = { D3D12_QUERY_HEAP_TYPE_TIMESTAMP, 2, 0 };
        HR(g_dev->CreateQueryHeap(&qhd, IID_PPV_ARGS(&qh)));
        ID3D12Resource* qrb = NfruEngineDX12::makeBuffer(g_dev, 16, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST, false);
        uint64_t freq = 1;
        g_q->GetTimestampFrequency(&freq);
        std::vector<double> ms;
        for (int it = 0; it < bench; ++it)
        {
            g_cl->EndQuery(qh, D3D12_QUERY_TYPE_TIMESTAMP, 0);
            eng.record(g_cl);
            g_cl->EndQuery(qh, D3D12_QUERY_TYPE_TIMESTAMP, 1);
            g_cl->ResolveQueryData(qh, D3D12_QUERY_TYPE_TIMESTAMP, 0, 2, qrb, 0);
            submitWait();
            uint64_t* t = nullptr;
            HR(qrb->Map(0, nullptr, (void**) &t));
            ms.push_back((double) (t[1] - t[0]) * 1000.0 / (double) freq);
            qrb->Unmap(0, nullptr);
        }
        std::sort(ms.begin(), ms.end());
        printf("network %ux%u: median %.3f ms  (min %.3f, %d iters)\n", W, H, ms[ms.size() / 2], ms[0], bench);
    }
    return 0;
}
