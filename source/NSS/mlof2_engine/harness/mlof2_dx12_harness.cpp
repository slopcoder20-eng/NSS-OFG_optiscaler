                                                                                                             
                                                                                                      
                                                                     
                                                                             
#define NOMINMAX
#include <d3d12.h>
#include <dxgi1_6.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>
#include "../mlof2_engine_host.h"
#include "../generated/mlof2_of_graph.h"
#include "../generated/mlof2_gen_graph.h"
#include "../mlof2_shaders_dxil.h"
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")
#define CK(x) do { HRESULT h_ = (x); if (FAILED(h_)) { printf("FAIL %s = 0x%08lx (line %d)\n", #x, (unsigned long)h_, __LINE__); exit(1); } } while (0)

static std::vector<uint8_t> readFile(const std::string& p) {
    FILE* f = fopen(p.c_str(), "rb"); if (!f) { printf("missing %s\n", p.c_str()); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET); std::vector<uint8_t> v(n); fread(v.data(), 1, n, f); fclose(f); return v;
}

ID3D12Device* dev;
static ID3D12Resource* mkBuf(uint64_t n, D3D12_HEAP_TYPE heap, D3D12_RESOURCE_STATES st, bool uav) {
    D3D12_HEAP_PROPERTIES hp{}; hp.Type = heap;
    D3D12_RESOURCE_DESC d{}; d.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; d.Width = n; d.Height = 1; d.DepthOrArraySize = 1; d.MipLevels = 1;
    d.SampleDesc.Count = 1; d.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR; d.Flags = uav ? D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS : D3D12_RESOURCE_FLAG_NONE;
    ID3D12Resource* r; CK(dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &d, st, nullptr, IID_PPV_ARGS(&r))); return r;
}

int main(int argc, char** argv) {
    if (argc < 4) { printf("usage: mlof2_dx12_harness <generated dir> <io dir> dump|bench|profile [H W]\n"); return 1; }
    std::string gdir = argv[1], io = argv[2], mode = argv[3];
    int H = argc > 5 ? atoi(argv[4]) : 1088, W = argc > 5 ? atoi(argv[5]) : 1920;
    const bool genGraph = getenv("MLOF2_GRAPH") && std::string(getenv("MLOF2_GRAPH")) == "gen";                        
    const Mlof2Graph& g = genGraph ? mlof2_gen_graph : mlof2_of_graph;
    Mlof2Plan plan;
    if (!mlof2_plan(g, H, W, plan)) { printf("bad size\n"); return 1; }
    if (genGraph) {                                                                                 
        auto fcv = readFile(io + "/fc.f32");
        memcpy(&plan.meta[plan.fc], fcv.data(), std::min<size_t>(fcv.size(), MLOF2_FC_WORDS * 4));
    }
    auto inputFile = [&](const char* name) {
        std::string p = io + "/in_" + name + ".f32";
        FILE* f = fopen(p.c_str(), "rb"); if (f) { fclose(f); return p; }
        return io + "/" + name + ".f32";
    };
    auto blob = readFile(gdir + "/" + g.blob_name);
    if (blob.size() != size_t(g.blob_words) * 4) { printf("blob size mismatch\n"); return 1; }

    const bool dbg = getenv("MLOF2_DX12_DEBUG") != nullptr;
    if (dbg) {
        ID3D12Debug1* d;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&d)))) {
            d->EnableDebugLayer();
            if (getenv("MLOF2_GBV")) d->SetEnableGPUBasedValidation(TRUE);                                                  
            printf("debug layer on%s\n", getenv("MLOF2_GBV") ? " + GPU-based validation" : "");
        }
    }
    IDXGIFactory6* fac; CK(CreateDXGIFactory2(0, IID_PPV_ARGS(&fac)));
                                                                                                                       
                                                                                                              
    IDXGIAdapter1* ad;
    if (getenv("MLOF2_WARP")) CK(fac->EnumWarpAdapter(IID_PPV_ARGS(&ad)));
    else CK(fac->EnumAdapterByGpuPreference(0, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, IID_PPV_ARGS(&ad)));
    DXGI_ADAPTER_DESC1 add; ad->GetDesc1(&add);
    CK(D3D12CreateDevice(ad, D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&dev)));
    printf("GPU %ls, %dx%d, %d ops, arena %.1f MiB\n", add.Description, W, H, g.num_ops, plan.arena_floats * 4.0 / 1048576.0);
    D3D12_COMMAND_QUEUE_DESC qd{}; qd.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE; ID3D12CommandQueue* q; CK(dev->CreateCommandQueue(&qd, IID_PPV_ARGS(&q)));
    ID3D12CommandAllocator* ca; CK(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE, IID_PPV_ARGS(&ca)));
    ID3D12GraphicsCommandList* cl; CK(dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_COMPUTE, ca, nullptr, IID_PPV_ARGS(&cl)));
    ID3D12Fence* fence; CK(dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence))); uint64_t fv = 0;
    HANDLE ev = CreateEventA(nullptr, FALSE, FALSE, nullptr);
    ID3D12InfoQueue* iq = nullptr;
    if (dbg) dev->QueryInterface(IID_PPV_ARGS(&iq));
    auto flushMsgs = [&]() {
        if (!iq) return;
        for (UINT64 i = 0, n = iq->GetNumStoredMessages(); i < n; ++i) {
            SIZE_T len = 0; iq->GetMessage(i, nullptr, &len); std::vector<char> b(len); auto* m = (D3D12_MESSAGE*)b.data();
            iq->GetMessage(i, m, &len); printf("D3D12: %s\n", m->pDescription);
        }
        iq->ClearStoredMessages();
    };
    int nsub = 0;
    auto submit = [&]() {
        flushMsgs();
        if (dbg) { printf("submit %d\n", nsub); fflush(stdout); }
        ++nsub;
        CK(cl->Close()); ID3D12CommandList* l[] = {cl}; q->ExecuteCommandLists(1, l); CK(q->Signal(fence, ++fv));
        if (fence->GetCompletedValue() < fv) { fence->SetEventOnCompletion(fv, ev); WaitForSingleObject(ev, INFINITE); }
        HRESULT rr = dev->GetDeviceRemovedReason(); if (FAILED(rr)) { flushMsgs(); printf("device removed 0x%08lx\n", (unsigned long)rr); exit(1); }
        CK(ca->Reset()); CK(cl->Reset(ca, nullptr));
    };

                                 
                                                                                                                       
                                                                                                                  
                                          
    const bool rootDesc = getenv("MLOF2_ROOT_DESC") != nullptr;
    D3D12_DESCRIPTOR_RANGE rg[2]{};
    rg[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV; rg[0].NumDescriptors = 1; rg[0].BaseShaderRegister = 0; rg[0].OffsetInDescriptorsFromTableStart = 0;
    rg[1].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV; rg[1].NumDescriptors = 2; rg[1].BaseShaderRegister = 1; rg[1].OffsetInDescriptorsFromTableStart = 1;
    D3D12_ROOT_PARAMETER rp[4]{};
    rp[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS; rp[0].Constants.ShaderRegister = 0; rp[0].Constants.RegisterSpace = 1; rp[0].Constants.Num32BitValues = 5;
    if (rootDesc) {
        rp[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_UAV; rp[1].Descriptor.ShaderRegister = 0;
        rp[2].ParameterType = D3D12_ROOT_PARAMETER_TYPE_SRV; rp[2].Descriptor.ShaderRegister = 1;
        rp[3].ParameterType = D3D12_ROOT_PARAMETER_TYPE_SRV; rp[3].Descriptor.ShaderRegister = 2;
    } else {
        rp[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE; rp[1].DescriptorTable.NumDescriptorRanges = 2; rp[1].DescriptorTable.pDescriptorRanges = rg;
    }
    for (auto& p : rp) p.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    D3D12_ROOT_SIGNATURE_DESC rsd{}; rsd.NumParameters = rootDesc ? 4 : 2; rsd.pParameters = rp;
    ID3DBlob *rsb, *err; if (FAILED(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1, &rsb, &err))) { printf("rs: %s\n", (char*)err->GetBufferPointer()); return 1; }
    ID3D12RootSignature* rs; CK(dev->CreateRootSignature(0, rsb->GetBufferPointer(), rsb->GetBufferSize(), IID_PPV_ARGS(&rs)));
    ID3D12PipelineState* pso[3];
    const unsigned char* codes[3] = {g_dxil_mlof2_conv, g_dxil_mlof2_ops, g_dxil_mlof2_gen};
    size_t sizes[3] = {g_dxil_mlof2_conv_size, g_dxil_mlof2_ops_size, g_dxil_mlof2_gen_size};
    for (int k = 0; k < 3; ++k) {
        D3D12_COMPUTE_PIPELINE_STATE_DESC pd{}; pd.pRootSignature = rs; pd.CS = {codes[k], sizes[k]};
        CK(dev->CreateComputePipelineState(&pd, IID_PPV_ARGS(&pso[k])));
    }
              
    uint64_t maxT = 0;
    for (int t = 0; t < g.num_tensors; ++t) { uint64_t o, c; mlof2_tensor_span(g, plan, t, o, c); maxT = std::max(maxT, c); }
    uint64_t upN = std::max<uint64_t>(blob.size() + plan.meta.size() * 4, maxT * 4);
    ID3D12Resource* arena = mkBuf(plan.arena_floats * 4, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COMMON, true);
    ID3D12Resource* bBlob = mkBuf(blob.size(), D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COMMON, false);
    ID3D12Resource* bMeta = mkBuf(plan.meta.size() * 4, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COMMON, false);
    ID3D12Resource* up = mkBuf(upN, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ, false);
    ID3D12Resource* rb = mkBuf(maxT * 4, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST, false);
    uint8_t* upp; CK(up->Map(0, nullptr, (void**)&upp));
                                                                                              
    D3D12_DESCRIPTOR_HEAP_DESC hd{}; hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV; hd.NumDescriptors = 3; hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    ID3D12DescriptorHeap* heap; CK(dev->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&heap)));
    const UINT inc = dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = heap->GetCPUDescriptorHandleForHeapStart();
        D3D12_UNORDERED_ACCESS_VIEW_DESC u{}; u.Format = DXGI_FORMAT_R32_TYPELESS; u.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
        u.Buffer.NumElements = UINT(plan.arena_floats); u.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
        dev->CreateUnorderedAccessView(arena, nullptr, &u, h);
        ID3D12Resource* srcs[2] = {bBlob, bMeta}; UINT nel[2] = {UINT(blob.size() / 4), UINT(plan.meta.size())};
        for (int i = 0; i < 2; ++i) {
            h.ptr += inc;
            D3D12_SHADER_RESOURCE_VIEW_DESC s{}; s.Format = DXGI_FORMAT_R32_TYPELESS; s.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
            s.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING; s.Buffer.NumElements = nel[i]; s.Buffer.Flags = D3D12_BUFFER_SRV_FLAG_RAW;
            dev->CreateShaderResourceView(srcs[i], &s, h);
        }
    }
    auto trans = [&](ID3D12Resource* r, D3D12_RESOURCE_STATES a, D3D12_RESOURCE_STATES b) {
        D3D12_RESOURCE_BARRIER br{}; br.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION; br.Transition.pResource = r; br.Transition.StateBefore = a; br.Transition.StateAfter = b;
        br.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES; cl->ResourceBarrier(1, &br);
    };
    auto uavb = [&]() { D3D12_RESOURCE_BARRIER br{}; br.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV; br.UAV.pResource = arena; cl->ResourceBarrier(1, &br); };
    memcpy(upp, blob.data(), blob.size()); memcpy(upp + blob.size(), plan.meta.data(), plan.meta.size() * 4);
    cl->CopyBufferRegion(bBlob, 0, up, 0, blob.size()); cl->CopyBufferRegion(bMeta, 0, up, blob.size(), plan.meta.size() * 4);
    submit();
                                                           
    if (!getenv("MLOF2_NO_NAN")) {
        std::vector<uint32_t> nanv(size_t(std::min<uint64_t>(upN / 4, plan.arena_floats)), 0x7fc00000u);
        memcpy(upp, nanv.data(), nanv.size() * 4);
        for (uint64_t o = 0; o < plan.arena_floats; o += nanv.size()) {
            uint64_t c = std::min<uint64_t>(nanv.size(), plan.arena_floats - o);
            cl->CopyBufferRegion(arena, o * 4, up, 0, c * 4); submit();
        }
    }
    for (int i = 0; i < g.num_inputs && !getenv("MLOF2_NO_INPUT"); ++i) {
        uint64_t off, cnt; mlof2_tensor_span(g, plan, g.io[i], off, cnt);
        auto v = readFile(inputFile(g.io_names[i]));
        if (v.size() != cnt * 4) { printf("%s: size mismatch\n", g.io_names[i]); return 1; }
        memcpy(upp, v.data(), v.size()); cl->CopyBufferRegion(arena, off * 4, up, 0, cnt * 4); submit();
    }
    bool arenaUav = false;                                                                                                  
    auto beginCompute = [&]() {
        if (!arenaUav) { trans(arena, D3D12_RESOURCE_STATE_COMMON, D3D12_RESOURCE_STATE_UNORDERED_ACCESS); arenaUav = true; }
        trans(bBlob, D3D12_RESOURCE_STATE_COMMON, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        trans(bMeta, D3D12_RESOURCE_STATE_COMMON, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        cl->SetComputeRootSignature(rs);
        if (rootDesc) {
            cl->SetComputeRootUnorderedAccessView(1, arena->GetGPUVirtualAddress());
            cl->SetComputeRootShaderResourceView(2, bBlob->GetGPUVirtualAddress());
            cl->SetComputeRootShaderResourceView(3, bMeta->GetGPUVirtualAddress());
        } else {
            ID3D12DescriptorHeap* hs[] = {heap}; cl->SetDescriptorHeaps(1, hs);
            cl->SetComputeRootDescriptorTable(1, heap->GetGPUDescriptorHandleForHeapStart());
        }
    };
    auto endCompute = [&]() {
        trans(bBlob, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE, D3D12_RESOURCE_STATE_COMMON);
        trans(bMeta, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE, D3D12_RESOURCE_STATE_COMMON);
    };
    auto record = [&](const Mlof2Dispatch& d) {
        uint32_t pcv[5] = {d.op, plan.tb, plan.sb, plan.ob, plan.fc};
        cl->SetPipelineState(pso[d.kernel]);
        cl->SetComputeRoot32BitConstants(0, 5, pcv, 0);
        cl->Dispatch(d.gx, d.gy, 1);
        uavb();
    };
    auto readTensor = [&](int t, const std::string& fn) {
        uint64_t off, cnt; mlof2_tensor_span(g, plan, t, off, cnt);
        trans(arena, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);
        cl->CopyBufferRegion(rb, 0, arena, off * 4, cnt * 4);
        trans(arena, D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        endCompute(); submit();
        void* p; D3D12_RANGE r{0, size_t(cnt * 4)}; CK(rb->Map(0, &r, &p));
        FILE* f = fopen((io + fn).c_str(), "wb"); fwrite(p, 4, cnt, f); fclose(f);
        D3D12_RANGE w{0, 0}; rb->Unmap(0, &w);
    };
    if (mode == "dump") {
        const uint32_t maxOps = getenv("MLOF2_MAX_OPS") ? uint32_t(atoi(getenv("MLOF2_MAX_OPS"))) : 1000000u;
        for (const auto& d : plan.dispatches) {
            if (d.op >= maxOps) break;
            if (getenv("MLOF2_START_OP") && d.op < uint32_t(atoi(getenv("MLOF2_START_OP")))) continue;
            beginCompute(); record(d);
            char fn[64]; snprintf(fn, sizeof fn, "/dx_op_%03u.f32", d.op);
            readTensor(g.ops[d.op].out, fn);
        }
        printf("dumped %zu ops (dx_op_NNN.f32) to %s\n", plan.dispatches.size(), io.c_str());
    } else {
        const bool prof = mode == "profile";
        const uint32_t N = uint32_t(plan.dispatches.size()), R = prof ? 3 : 10;
        const uint32_t nq = prof ? 2 * N : 2 * R;
        D3D12_QUERY_HEAP_DESC qh{}; qh.Type = D3D12_QUERY_HEAP_TYPE_TIMESTAMP; qh.Count = nq; ID3D12QueryHeap* qheap; CK(dev->CreateQueryHeap(&qh, IID_PPV_ARGS(&qheap)));
        ID3D12Resource* qrb = mkBuf(nq * 8, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST, false);
        uint64_t freq; CK(q->GetTimestampFrequency(&freq));
        std::vector<double> acc(N, 0.0), runs;
        for (uint32_t r = 0; r < R; ++r) {
            beginCompute();
            if (prof) {
                for (uint32_t i = 0; i < N; ++i) { cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 2 * i); record(plan.dispatches[i]); cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 2 * i + 1); }
            } else {
                cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 2 * r);
                for (const auto& d : plan.dispatches) record(d);
                cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 2 * r + 1);
            }
            cl->ResolveQueryData(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 0, nq, qrb, 0);
            endCompute(); submit();
            uint64_t* t; CK(qrb->Map(0, nullptr, (void**)&t));
            if (prof && r) for (uint32_t i = 0; i < N; ++i) acc[i] += double(t[2 * i + 1] - t[2 * i]) * 1000.0 / freq / (R - 1);
            if (!prof) runs.push_back(double(t[2 * r + 1] - t[2 * r]) * 1000.0 / freq);
            D3D12_RANGE w{0, 0}; qrb->Unmap(0, &w);
        }
        if (prof) {
            double tot = 0; for (double a : acc) tot += a;
            printf("total %.2f ms (sum of per-op times)\n", tot);
        } else {
            std::sort(runs.begin(), runs.end());
            printf("OF graph (both directions) %dx%d: median %.2f ms, min %.2f, max %.2f over %u runs\n", W, H, runs[R / 2], runs[0], runs[R - 1], R);
        }
        beginCompute();
        for (int oi = 0; oi < g.num_outputs; ++oi) {
            beginCompute();
            readTensor(g.io[g.num_inputs + oi], std::string("/dx_out_") + g.io_names[g.num_inputs + oi] + ".f32");
        }
    }
    return 0;
}
