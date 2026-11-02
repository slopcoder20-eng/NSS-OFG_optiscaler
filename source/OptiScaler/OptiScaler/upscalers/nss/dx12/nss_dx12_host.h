                                                                                                         
                                                                                                                
                                                                                                            
                                                                                                             
#pragma once
#define NOMINMAX
#include <windows.h>
#include <d3d12.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <cfloat>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
                                                                                                         
#ifndef NSSDX_LOG
#define NSSDX_LOG(...) NSSDX_LOG(__VA_ARGS__)
#endif
#include "nss_dx12_shaders.h"
#include "nss_model_high_data.h"

namespace nssdx
{
using Microsoft::WRL::ComPtr;

#define NSSDX_HR(x)                                                                                        \
    do                                                                                                     \
    {                                                                                                      \
        HRESULT hr_ = (x);                                                                                 \
        if (FAILED(hr_))                                                                                   \
        {                                                                                                  \
            NSSDX_LOG("[NssDx12] HRESULT 0x%08X at %s:%d: %s\n", (unsigned) hr_, __FILE__, __LINE__, #x); \
            return false;                                                                                  \
        }                                                                                                  \
    } while (0)

                                                                                        
struct Constants
{
    float _DeviceToViewDepth[4];
    float _JitterOffset[4];
    float _JitterOffsetTm1[4];
    float _ScaleFactor[4];
    uint32_t _OutputDims[2];
    uint32_t _InputDims[2];
    float _InvOutputDims[2];
    float _InvInputDims[2];
    uint32_t _DepthTm1Size[2];
    float _InvDepthTm1Size[2];
    uint32_t _InputTensorSize[2];
    float _InputTensorSizeRcp[2];
    uint32_t _KpnDimension[2];
    float _MotionVectorScale[2];
    float _PaddingScale[2];
    float _DepthClipRequiredSepScale;
    float _DepthClipPower;
    float _KpnScale[2];
    uint32_t _DebugViewMode;
    float _NotHistoryReset;
    float _Exposure[2];
    uint32_t _IndexModulo[2];
    uint32_t _ReducedInputModulo[2];
    uint32_t _LutOffset[2];
};
static_assert(sizeof(Constants) == 208, "NssConstants layout");

struct InitDesc
{
    ID3D12Device* device = nullptr;
    uint32_t renderW = 0, renderH = 0, dispW = 0, dispH = 0;
    bool depthInverted = true;
    bool depthInfinite = false;
};

struct Frame
{
    ID3D12GraphicsCommandList* cl = nullptr;
    ID3D12Resource *color = nullptr, *depth = nullptr, *motion = nullptr, *output = nullptr;
    DXGI_FORMAT colorFmt = DXGI_FORMAT_R16G16B16A16_FLOAT, depthFmt = DXGI_FORMAT_R32_FLOAT, motionFmt = DXGI_FORMAT_R16G16_FLOAT;
    DXGI_FORMAT outputFmt = DXGI_FORMAT_R11G11B10_FLOAT;
    float jitterX = 0, jitterY = 0, mvScaleX = 1, mvScaleY = 1, fovY = 1.0f, camNear = 0.1f, camFar = 100.0f, exposure = 1.0f;
    bool reset = false;
};

class Nss
{
  public:
    bool Init(const InitDesc& d);
                                                                                                                     
    bool Record(const Frame& f);
    double LastCpuMs = 0;
                                                                                                 
                                                                                              
                                                                               
    bool GetEngineTicks(uint64_t& t0, uint64_t& t1) const
    {
        if (!qbEngineMap) return false;
        t0 = qbEngineMap[0];
        t1 = qbEngineMap[1];
        return true;
    }
    bool GetLayerTicks(uint64_t* out28) const
    {
        if (!qbLayersMap) return false;
        for (int i = 0; i < 28; ++i) out28[i] = qbLayersMap[i];
        return true;
    }

  private:
    struct Res
    {
        ComPtr<ID3D12Resource> r;
        D3D12_RESOURCE_STATES s = D3D12_RESOURCE_STATE_COMMON;
        UINT64 size = 0;
    };
    struct LayerRun
    {
        Res *in, *in2, *out;
        uint32_t inW, inH, outW, outH, in1c;
        bool up;
    };
    struct ConvParams
    {
        uint32_t in_w, in_h, out_w, out_h, in_c, out_c;
        int32_t pad_y, pad_x, stride_y, stride_x, out_zp, has_table;
        uint32_t in1_c, upsample, w_off, b_off, m_off, s_off, t_off;
    };

    static constexpr uint32_t kRing = 8;                                                                   
    static constexpr uint32_t kTable = 8 + 12 + 13;                                   
    static constexpr uint32_t kTablesPerFrame = 5;                                                                 
    static constexpr uint32_t kClearSlots = 8;

    ComPtr<ID3D12Device> dev;
    InitDesc d;
    UINT inc = 0;

                                                            
    ComPtr<ID3D12RootSignature> rs;
    ComPtr<ID3D12PipelineState> psoDepth, psoPre, psoLut, psoPost, psoB2T;
             
    ComPtr<ID3D12RootSignature> rsConv;
    ComPtr<ID3D12PipelineState> psoConv;
    ComPtr<ID3D12PipelineState> psoConvTiledS1;                                                  
    ComPtr<ID3D12PipelineState> psoConvTiledS1T16;                                                     
                                                                                             
                                                                                         
    ComPtr<ID3D12RootSignature> rsConvHint;
    ComPtr<ID3D12PipelineState> psoConvHint;
                                                                                              
    ComPtr<ID3D12PipelineState> psoConvO0, psoConvSm66;
    ComPtr<ID3D12PipelineState> psoConvC16, psoConvC4;
                                                                                                    
                                                                                               
                                               
    ComPtr<ID3D12QueryHeap> qhEngine;
    ComPtr<ID3D12Resource> qbEngine;
    uint64_t* qbEngineMap = nullptr;
    ComPtr<ID3D12QueryHeap> qhLayers;
    ComPtr<ID3D12Resource> qbLayers;
    uint64_t* qbLayersMap = nullptr;
    ComPtr<ID3D12DescriptorHeap> convHeap;
    LayerRun runs[14];
    Res model;
    Res tIn, tL1, tL2, tL3, tL4, tL5, tL6, tL7, tD1, tD2, tKpn, tD3, tD4, tD5, tFdbk;

            
    ComPtr<ID3D12DescriptorHeap> heap;                                                     
    ComPtr<ID3D12DescriptorHeap> cpuHeap;                                           
    Res constUpload;
    uint8_t* constMap = nullptr;

                             
    Res depthTm1, luma1, luma2, nearest, feedbackImg, history1, history2, offsetLut, preTensor;

                           
    uint32_t dsW = 0, dsH = 0, dgW = 0, dgH = 0, kpnW = 0, kpnH = 0;
    bool dynLut = false;
    uint32_t hrW = 2, hrH = 2, lrW = 1, lrH = 1, lutW = 0, lutH = 0;
    int permIndex = 0;

    Constants c = {};
    bool firstExecution = true;
    uint32_t frameIndex = 0;                                                             
    uint32_t ringFrame = 0;

                        
    bool MakeBuffer(Res& out, UINT64 bytes, D3D12_HEAP_TYPE heapType, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES init);
    bool MakeTexture(Res& out, uint32_t w, uint32_t h, DXGI_FORMAT fmt, D3D12_RESOURCE_FLAGS flags);
    void To(ID3D12GraphicsCommandList* cl, Res& r, D3D12_RESOURCE_STATES to);
    static void UavBarrier(ID3D12GraphicsCommandList* cl);
    bool MakePso(ComPtr<ID3D12PipelineState>& pso, ID3D12RootSignature* sig, const NssShaderBlob& b, const char* name);
    bool InitEngine();
    void RecordEngine(ID3D12GraphicsCommandList* cl);
    void SetupConstants(const Frame& f);

    struct Table
    {
        D3D12_CPU_DESCRIPTOR_HANDLE cpu;
        D3D12_GPU_DESCRIPTOR_HANDLE gpu;
    };
    Table TableAt(uint32_t frameSlot, uint32_t idx) const;
    void NullTable(const Table& t) const;
    void Srv2D(const Table& t, uint32_t reg, ID3D12Resource* r, DXGI_FORMAT fmt) const;
    void SrvRaw(const Table& t, uint32_t reg, Res& r) const;
    void Uav2D(const Table& t, uint32_t reg, ID3D12Resource* r, DXGI_FORMAT fmt) const;
    void UavRaw(const Table& t, uint32_t reg, Res& r) const;
    void Cbv(const Table& t, uint32_t reg, D3D12_GPU_VIRTUAL_ADDRESS va) const;
};

                                                                                                                     
inline bool Nss::MakeBuffer(Res& out, UINT64 bytes, D3D12_HEAP_TYPE heapType, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES init)
{
    bytes = (bytes + 255) & ~255ull;
    D3D12_HEAP_PROPERTIES hp = { heapType };
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width = bytes;
    rd.Height = rd.DepthOrArraySize = rd.MipLevels = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags = flags;
    NSSDX_HR(dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, init, nullptr, IID_PPV_ARGS(&out.r)));
    out.s = init;
    out.size = bytes;
    return true;
}

inline bool Nss::MakeTexture(Res& out, uint32_t w, uint32_t h, DXGI_FORMAT fmt, D3D12_RESOURCE_FLAGS flags)
{
    D3D12_HEAP_PROPERTIES hp = { D3D12_HEAP_TYPE_DEFAULT };
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    rd.Width = w;
    rd.Height = h;
    rd.DepthOrArraySize = rd.MipLevels = 1;
    rd.Format = fmt;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
    rd.Flags = flags;
    NSSDX_HR(dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COMMON, nullptr, IID_PPV_ARGS(&out.r)));
    out.s = D3D12_RESOURCE_STATE_COMMON;
    return true;
}

inline void Nss::To(ID3D12GraphicsCommandList* cl, Res& r, D3D12_RESOURCE_STATES to)
{
    if (r.s == to)
        return;
    D3D12_RESOURCE_BARRIER b = {};
    b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    b.Transition = { r.r.Get(), D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, r.s, to };
    cl->ResourceBarrier(1, &b);
    r.s = to;
}

inline void Nss::UavBarrier(ID3D12GraphicsCommandList* cl)
{
    D3D12_RESOURCE_BARRIER b = {};
    b.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
    cl->ResourceBarrier(1, &b);
}

inline bool Nss::MakePso(ComPtr<ID3D12PipelineState>& pso, ID3D12RootSignature* sig, const NssShaderBlob& b, const char* name)
{
    if (!b.data)
    {
        NSSDX_LOG("[NssDx12] missing shader %s\n", name);
        return false;
    }
    D3D12_COMPUTE_PIPELINE_STATE_DESC pd = {};
    pd.pRootSignature = sig;
    pd.CS = { b.data, b.size };
    const HRESULT hr = dev->CreateComputePipelineState(&pd, IID_PPV_ARGS(&pso));
    if (FAILED(hr))
    {
        NSSDX_LOG("[NssDx12] PSO %s failed 0x%08X\n", name, (unsigned) hr);
        return false;
    }
    return true;
}

inline Nss::Table Nss::TableAt(uint32_t frameSlot, uint32_t idx) const
{
    const UINT slot = kClearSlots + (frameSlot * kTablesPerFrame + idx) * kTable;
    Table t;
    t.cpu = heap->GetCPUDescriptorHandleForHeapStart();
    t.cpu.ptr += (SIZE_T) slot * inc;
    t.gpu = heap->GetGPUDescriptorHandleForHeapStart();
    t.gpu.ptr += (UINT64) slot * inc;
    return t;
}

inline void Nss::NullTable(const Table& t) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    for (uint32_t i = 0; i < 8; ++i, h.ptr += inc)
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC sd = {};
        sd.Format = DXGI_FORMAT_R32_FLOAT;
        sd.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
        sd.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        sd.Texture2D.MipLevels = 1;
        dev->CreateShaderResourceView(nullptr, &sd, h);
    }
    for (uint32_t i = 0; i < 12; ++i, h.ptr += inc)
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC ud = {};
        ud.Format = DXGI_FORMAT_R32_FLOAT;
        ud.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
        dev->CreateUnorderedAccessView(nullptr, nullptr, &ud, h);
    }
    for (uint32_t i = 0; i < 13; ++i, h.ptr += inc)
        dev->CreateConstantBufferView(nullptr, h);
}

inline void Nss::Srv2D(const Table& t, uint32_t reg, ID3D12Resource* r, DXGI_FORMAT fmt) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    h.ptr += (SIZE_T) reg * inc;
    D3D12_SHADER_RESOURCE_VIEW_DESC sd = {};
    sd.Format = fmt;
    sd.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
    sd.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    sd.Texture2D.MipLevels = 1;
    dev->CreateShaderResourceView(r, &sd, h);
}

inline void Nss::SrvRaw(const Table& t, uint32_t reg, Res& r) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    h.ptr += (SIZE_T) reg * inc;
    D3D12_SHADER_RESOURCE_VIEW_DESC sd = {};
    sd.Format = DXGI_FORMAT_R32_TYPELESS;
    sd.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
    sd.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    sd.Buffer = { 0, (UINT) (r.size / 4), 0, D3D12_BUFFER_SRV_FLAG_RAW };
    dev->CreateShaderResourceView(r.r.Get(), &sd, h);
}

inline void Nss::Uav2D(const Table& t, uint32_t reg, ID3D12Resource* r, DXGI_FORMAT fmt) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    h.ptr += (SIZE_T) (8 + reg) * inc;
    D3D12_UNORDERED_ACCESS_VIEW_DESC ud = {};
    ud.Format = fmt;
    ud.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
    dev->CreateUnorderedAccessView(r, nullptr, &ud, h);
}

inline void Nss::UavRaw(const Table& t, uint32_t reg, Res& r) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    h.ptr += (SIZE_T) (8 + reg) * inc;
    D3D12_UNORDERED_ACCESS_VIEW_DESC ud = {};
    ud.Format = DXGI_FORMAT_R32_TYPELESS;
    ud.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
    ud.Buffer = { 0, (UINT) (r.size / 4), 0, 0, D3D12_BUFFER_UAV_FLAG_RAW };
    dev->CreateUnorderedAccessView(r.r.Get(), nullptr, &ud, h);
}

inline void Nss::Cbv(const Table& t, uint32_t reg, D3D12_GPU_VIRTUAL_ADDRESS va) const
{
    D3D12_CPU_DESCRIPTOR_HANDLE h = t.cpu;
    h.ptr += (SIZE_T) (20 + reg) * inc;
    D3D12_CONSTANT_BUFFER_VIEW_DESC cd = { va, 256 };
    dev->CreateConstantBufferView(&cd, h);
}

                                                                                                                     
inline bool Nss::Init(const InitDesc& desc)
{
    d = desc;
    dev = d.device;
    inc = dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    D3D12_FEATURE_DATA_SHADER_MODEL sm = { D3D_SHADER_MODEL_6_6 };
    if (FAILED(dev->CheckFeatureSupport(D3D12_FEATURE_SHADER_MODEL, &sm, sizeof(sm))) || sm.HighestShaderModel < D3D_SHADER_MODEL_6_6)
    {
        NSSDX_LOG("[NssDx12] shader model 6.6 required\n");
        return false;
    }
    D3D12_FEATURE_DATA_D3D12_OPTIONS4 o4 = {};
    dev->CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS4, &o4, sizeof(o4));
    if (!o4.Native16BitShaderOpsSupported)
    {
        NSSDX_LOG("[NssDx12] native 16-bit shader ops required\n");
        return false;
    }

                                                                                                
    dsW = d.renderW / 2;
    dsH = d.renderH / 2;
    dgW = (d.renderW + 7) & ~7u;
    dgH = (d.renderH + 7) & ~7u;
    kpnW = dgW / 4;
    kpnH = dgH / 4;
    dynLut = !(d.dispW == 2 * d.renderW && d.dispH == 2 * d.renderH);
    if (dynLut)
    {
        auto gcd = [](uint32_t a, uint32_t b) { while (b) { uint32_t t = b; b = a % b; a = t; } return a ? a : 1u; };
        const uint32_t gw = gcd(d.dispW, d.renderW), gh = gcd(d.dispH, d.renderH);
        hrW = d.dispW / gw;
        lrW = d.renderW / gw;
        hrH = d.dispH / gh;
        lrH = d.renderH / gh;
        lutW = 3 * hrW;                                   
        lutH = hrH;
    }
    permIndex = (d.depthInverted ? 2 : 0) + (dynLut ? 0 : 1);

                                                                                                                
    D3D12_DESCRIPTOR_RANGE ranges[3] = {};
    ranges[0] = { D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 8, 0, 0, 0 };
    ranges[1] = { D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 12, 0, 0, 8 };
    ranges[2] = { D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 13, 0, 0, 20 };
    D3D12_ROOT_PARAMETER rp = {};
    rp.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    rp.DescriptorTable = { 3, ranges };
    D3D12_STATIC_SAMPLER_DESC ss[2] = {};
    for (int i = 0; i < 2; ++i)
    {
        ss[i].Filter = i == 0 ? D3D12_FILTER_MIN_MAG_MIP_POINT : D3D12_FILTER_MIN_MAG_MIP_LINEAR;
        ss[i].AddressU = ss[i].AddressV = ss[i].AddressW = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
        ss[i].ComparisonFunc = D3D12_COMPARISON_FUNC_NEVER;
        ss[i].MaxLOD = D3D12_FLOAT32_MAX;
        ss[i].ShaderRegister = 1000 + i;
        ss[i].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    }
    D3D12_ROOT_SIGNATURE_DESC rsd = { 1, &rp, 2, ss, D3D12_ROOT_SIGNATURE_FLAG_NONE };
    ComPtr<ID3DBlob> blob, err;
    NSSDX_HR(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &err));
    NSSDX_HR(dev->CreateRootSignature(0, blob->GetBufferPointer(), blob->GetBufferSize(), IID_PPV_ARGS(&rs)));

    if (!MakePso(psoDepth, rs.Get(), kBlobs_depth_scatter[permIndex], "depth_scatter") ||
        !MakePso(psoPre, rs.Get(), kBlobs_pre_process[permIndex], "pre_process") ||
        !MakePso(psoPost, rs.Get(), kBlobs_post_process[permIndex], "post_process") ||
        !MakePso(psoB2T, rs.Get(), kBlobs_buf2tex[0], "buf2tex"))
        return false;
    if (dynLut && !MakePso(psoLut, rs.Get(), kBlobs_generate_offset_lut[permIndex], "generate_offset_lut"))
        return false;

                      
    D3D12_DESCRIPTOR_HEAP_DESC hd = { D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, kClearSlots + kRing * kTablesPerFrame * kTable, D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE };
    NSSDX_HR(dev->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&heap)));
    D3D12_DESCRIPTOR_HEAP_DESC cd = { D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, kClearSlots, D3D12_DESCRIPTOR_HEAP_FLAG_NONE };
    NSSDX_HR(dev->CreateDescriptorHeap(&cd, IID_PPV_ARGS(&cpuHeap)));

                                                         
    if (!MakeBuffer(constUpload, 256ull * (kRing + 1), D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ))
        return false;
    NSSDX_HR(constUpload.r->Map(0, nullptr, (void**) &constMap));
                                                                              
    reinterpret_cast<uint32_t*>(constMap + 256ull * kRing)[0] = dgW;
    reinterpret_cast<uint32_t*>(constMap + 256ull * kRing)[1] = dgH;

                                                                               
    const D3D12_RESOURCE_FLAGS uav = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    if (!MakeTexture(depthTm1, dsW, dsH, DXGI_FORMAT_R32_UINT, uav) || !MakeTexture(luma1, dgW, dgH, DXGI_FORMAT_R8G8B8A8_SNORM, uav) ||
        !MakeTexture(luma2, dgW, dgH, DXGI_FORMAT_R8G8B8A8_SNORM, uav) || !MakeTexture(nearest, dgW, dgH, DXGI_FORMAT_R8_UNORM, uav) ||
        !MakeTexture(feedbackImg, dgW, dgH, DXGI_FORMAT_R8G8B8A8_TYPELESS, uav) ||
        !MakeTexture(history1, d.dispW, d.dispH, DXGI_FORMAT_R11G11B10_FLOAT, uav) || !MakeTexture(history2, d.dispW, d.dispH, DXGI_FORMAT_R11G11B10_FLOAT, uav))
        return false;
    if (dynLut && !MakeTexture(offsetLut, lutW, lutH, DXGI_FORMAT_R32G32B32A32_UINT, uav))
        return false;

                                                                                                                      
    {
        struct ClearDesc { ID3D12Resource* r; DXGI_FORMAT f; } cds[7] = {
            { luma1.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM }, { luma2.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM }, { nearest.r.Get(), DXGI_FORMAT_R8_UNORM },
            { feedbackImg.r.Get(), DXGI_FORMAT_R8G8B8A8_UINT }, { history1.r.Get(), DXGI_FORMAT_R11G11B10_FLOAT },
            { history2.r.Get(), DXGI_FORMAT_R11G11B10_FLOAT }, { depthTm1.r.Get(), DXGI_FORMAT_R32_UINT } };
        D3D12_CPU_DESCRIPTOR_HANDLE hv = heap->GetCPUDescriptorHandleForHeapStart(), hc = cpuHeap->GetCPUDescriptorHandleForHeapStart();
        for (int i = 0; i < 7; ++i, hv.ptr += inc, hc.ptr += inc)
        {
            D3D12_UNORDERED_ACCESS_VIEW_DESC ud = {};
            ud.Format = cds[i].f;
            ud.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
            dev->CreateUnorderedAccessView(cds[i].r, nullptr, &ud, hv);
            dev->CreateUnorderedAccessView(cds[i].r, nullptr, &ud, hc);
        }
    }

                                                                                                            
    const D3D12_RESOURCE_FLAGS bu = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    if (!MakeBuffer(tIn, (UINT64) dgW * dgH * 12 + 256, D3D12_HEAP_TYPE_DEFAULT, bu, D3D12_RESOURCE_STATE_COMMON) ||
        !MakeBuffer(tKpn, (UINT64) kpnW * kpnH * 36 + 256, D3D12_HEAP_TYPE_DEFAULT, bu, D3D12_RESOURCE_STATE_COMMON) ||
        !MakeBuffer(tFdbk, (UINT64) dgW * dgH * 4 + 256, D3D12_HEAP_TYPE_DEFAULT, bu, D3D12_RESOURCE_STATE_COMMON))
        return false;

    return InitEngine();
}

inline bool Nss::InitEngine()
{
                                                                          
    D3D12_DESCRIPTOR_RANGE ranges[2] = {};
    ranges[0] = { D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 4, 0, 0, 0 };
    ranges[1] = { D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 1, 0, 0, 4 };
    D3D12_ROOT_PARAMETER rp[2] = {};
    rp[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    rp[0].Constants = { 0, 0, sizeof(ConvParams) / 4 };
    rp[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    rp[1].DescriptorTable = { 2, ranges };
    D3D12_ROOT_SIGNATURE_DESC rsd = { 2, rp, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_NONE };
    ComPtr<ID3DBlob> blob, err;
    NSSDX_HR(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &err));
    NSSDX_HR(dev->CreateRootSignature(0, blob->GetBufferPointer(), blob->GetBufferSize(), IID_PPV_ARGS(&rsConv)));
    if (!MakePso(psoConv, rsConv.Get(), kBlobs_conv_dp4a[0], "conv_dp4a"))
        return false;
    if (!MakePso(psoConvTiledS1, rsConv.Get(), kBlobs_conv_dp4a_tiled_s1[0], "conv_dp4a_tiled_s1"))
        return false;
    if (!MakePso(psoConvTiledS1T16, rsConv.Get(), kBlobs_conv_dp4a_tiled_s1_t16[0], "conv_dp4a_tiled_s1_t16"))
        return false;

    MakePso(psoConvO0, rsConv.Get(), kBlobs_conv_dp4a_o0[0], "conv_dp4a_o0");
    MakePso(psoConvSm66, rsConv.Get(), kBlobs_conv_dp4a_sm66[0], "conv_dp4a_sm66");
    MakePso(psoConvC16, rsConv.Get(), kBlobs_conv_dp4a_c16[0], "conv_dp4a_c16");
    MakePso(psoConvC4, rsConv.Get(), kBlobs_conv_dp4a_c4[0], "conv_dp4a_c4");

                                                                                                  
                                                                                                
                                                                                                  
                                                                                                      
    {
        D3D12_FEATURE_DATA_ROOT_SIGNATURE frs = { D3D_ROOT_SIGNATURE_VERSION_1_1 };
        if (FAILED(dev->CheckFeatureSupport(D3D12_FEATURE_ROOT_SIGNATURE, &frs, sizeof(frs))))
            frs.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_0;
        if (frs.HighestVersion >= D3D_ROOT_SIGNATURE_VERSION_1_1)
        {
            D3D12_DESCRIPTOR_RANGE1 ranges1[2] = {};
            ranges1[0] = { D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 4, 0, 0, D3D12_DESCRIPTOR_RANGE_FLAG_DATA_STATIC_WHILE_SET_AT_EXECUTE, 0 };
            ranges1[1] = { D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 1, 0, 0, D3D12_DESCRIPTOR_RANGE_FLAG_NONE, 4 };
            D3D12_ROOT_PARAMETER1 rp1[2] = {};
            rp1[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
            rp1[0].Constants = { 0, 0, sizeof(ConvParams) / 4 };
            rp1[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            rp1[1].DescriptorTable = { 2, ranges1 };
            D3D12_VERSIONED_ROOT_SIGNATURE_DESC vrsd = {};
            vrsd.Version = D3D_ROOT_SIGNATURE_VERSION_1_1;
            vrsd.Desc_1_1 = { 2, rp1, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_NONE };
            ComPtr<ID3DBlob> hblob, herr;
            if (SUCCEEDED(D3D12SerializeVersionedRootSignature(&vrsd, &hblob, &herr)) &&
                SUCCEEDED(dev->CreateRootSignature(0, hblob->GetBufferPointer(), hblob->GetBufferSize(), IID_PPV_ARGS(&rsConvHint))))
            {
                MakePso(psoConvHint, rsConvHint.Get(), kBlobs_conv_dp4a[0], "conv_dp4a_hint");
            }
        }
    }

                                                                                                                              
    const NssLayerParam* layers = g_nss_high_layers;
    const size_t blobSize = g_nss_high_blob_size;
    std::vector<uint8_t> blob8((const uint8_t*) g_nss_high_blob, (const uint8_t*) g_nss_high_blob + blobSize);
    for (int l = 0; l < 14; ++l)
    {
        const uint32_t oc = layers[l].out_channels, ic = layers[l].in_channels;
        const uint32_t ict = (ic + 15) / 16, oct_ = (oc + 15) / 16;
        const int8_t* wt = (const int8_t*) blob8.data() + layers[l].weight_tiled_offset;
        int32_t* bias = (int32_t*) (blob8.data() + layers[l].bias_offset);
        for (uint32_t n = 0; n < oc; ++n)
        {
            int64_t sum = 0;
            const uint32_t ot = n / 16, nn = n % 16;
            for (uint32_t ky = 0; ky < 3; ++ky)
                for (uint32_t kx = 0; kx < 3; ++kx)
                    for (uint32_t it = 0; it < ict; ++it)
                        for (uint32_t k = 0; k < 16; ++k)
                            sum += wt[((((ky * 3 + kx) * ict + it) * oct_ + ot) * 16 + k) * 16 + nn];
            bias[n] += (int32_t) (128 * sum);
        }
    }
    {
        std::vector<uint8_t> src = blob8;
        for (int l = 0; l < 14; ++l)
        {
            const size_t off = layers[l].weight_tiled_offset, sz = layers[l].weight_tiled_size;
            for (size_t t = 0; t < sz; t += 256)
            {
                const int8_t* s = (const int8_t*) src.data() + off + t;
                uint32_t* dd = (uint32_t*) (blob8.data() + off + t);
                for (int sub = 0; sub < 4; ++sub)
                    for (int oc = 0; oc < 16; ++oc)
                        dd[sub * 16 + oc] = (uint32_t) (uint8_t) s[(sub * 4 + 0) * 16 + oc] | ((uint32_t) (uint8_t) s[(sub * 4 + 1) * 16 + oc] << 8) |
                                            ((uint32_t) (uint8_t) s[(sub * 4 + 2) * 16 + oc] << 16) | ((uint32_t) (uint8_t) s[(sub * 4 + 3) * 16 + oc] << 24);
            }
        }
    }

                              
    const uint32_t W = dgW, H = dgH, w2 = W / 2, h2 = H / 2, w4 = W / 4, h4 = H / 4, w8 = W / 8, h8 = H / 8;
    const D3D12_RESOURCE_FLAGS uav = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    auto tensor = [&](Res& r, UINT64 bytes) { return MakeBuffer(r, bytes + 256, D3D12_HEAP_TYPE_DEFAULT, uav, D3D12_RESOURCE_STATE_COMMON); };
    if (!tensor(tL1, (UINT64) w2 * h2 * 32) || !tensor(tL2, (UINT64) w2 * h2 * 32) || !tensor(tL3, (UINT64) w4 * h4 * 32) ||
        !tensor(tL4, (UINT64) w4 * h4 * 32) || !tensor(tL5, (UINT64) w8 * h8 * 64) || !tensor(tL6, (UINT64) w8 * h8 * 64) ||
        !tensor(tL7, (UINT64) w8 * h8 * 32) || !tensor(tD1, (UINT64) w4 * h4 * 16) || !tensor(tD2, (UINT64) w4 * h4 * 32) ||
        !tensor(tD3, (UINT64) w2 * h2 * 16) || !tensor(tD4, (UINT64) w2 * h2 * 16) || !tensor(tD5, (UINT64) w2 * h2 * 16))
        return false;
    if (!MakeBuffer(model, blobSize + 256, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST))
        return false;

                                                                         
    {
        Res up;
        if (!MakeBuffer(up, blobSize + 256, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ))
            return false;
        void* p = nullptr;
        NSSDX_HR(up.r->Map(0, nullptr, &p));
        std::memcpy(p, blob8.data(), blobSize);
        up.r->Unmap(0, nullptr);
        D3D12_COMMAND_QUEUE_DESC qd = { D3D12_COMMAND_LIST_TYPE_DIRECT };
        ComPtr<ID3D12CommandQueue> q;
        ComPtr<ID3D12CommandAllocator> a;
        ComPtr<ID3D12GraphicsCommandList> cl;
        ComPtr<ID3D12Fence> fence;
        NSSDX_HR(dev->CreateCommandQueue(&qd, IID_PPV_ARGS(&q)));
        NSSDX_HR(dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&a)));
        NSSDX_HR(dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, a.Get(), nullptr, IID_PPV_ARGS(&cl)));
        NSSDX_HR(dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
        cl->CopyBufferRegion(model.r.Get(), 0, up.r.Get(), 0, blobSize);
        To(cl.Get(), model, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        NSSDX_HR(cl->Close());
        ID3D12CommandList* lists[] = { cl.Get() };
        q->ExecuteCommandLists(1, lists);
        NSSDX_HR(q->Signal(fence.Get(), 1));
        HANDLE ev = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        fence->SetEventOnCompletion(1, ev);
        WaitForSingleObject(ev, INFINITE);
        CloseHandle(ev);
    }

    D3D12_DESCRIPTOR_HEAP_DESC hd = { D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, 14 * 5, D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE };
    NSSDX_HR(dev->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&convHeap)));

    LayerRun r[14] = {
        { &tIn, &tIn, &tL1, W, H, w2, h2, 0, false },      { &tL1, &tL1, &tL2, w2, h2, w2, h2, 0, false },
        { &tL2, &tL2, &tL3, w2, h2, w4, h4, 0, false },    { &tL3, &tL3, &tL4, w4, h4, w4, h4, 0, false },
        { &tL4, &tL4, &tL5, w4, h4, w8, h8, 0, false },    { &tL5, &tL5, &tL6, w8, h8, w8, h8, 0, false },
        { &tL6, &tL6, &tL7, w8, h8, w8, h8, 0, false },    { &tL7, &tL7, &tD1, w4, h4, w4, h4, 0, true },
        { &tD1, &tL4, &tD2, w4, h4, w4, h4, 16, false },   { &tD2, &tD2, &tKpn, w4, h4, w4, h4, 0, false },
        { &tD2, &tD2, &tD3, w2, h2, w2, h2, 0, true },     { &tD3, &tL2, &tD4, w2, h2, w2, h2, 16, false },
        { &tD4, &tD4, &tD5, w2, h2, w2, h2, 0, false },    { &tD5, &tD5, &tFdbk, W, H, W, H, 0, true } };
    std::memcpy(runs, r, sizeof(r));
    for (int l = 0; l < 14; ++l)
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = convHeap->GetCPUDescriptorHandleForHeapStart();
        h.ptr += (SIZE_T) l * 5 * inc;
        auto srvStructured = [&](Res& b) {
            D3D12_SHADER_RESOURCE_VIEW_DESC sd = {};
            sd.Format = DXGI_FORMAT_UNKNOWN;
            sd.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
            sd.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
            sd.Buffer = { 0, (UINT) (b.size / 16), 16, D3D12_BUFFER_SRV_FLAG_NONE };
            dev->CreateShaderResourceView(b.r.Get(), &sd, h);
            h.ptr += inc;
        };
        auto srvRawE = [&](Res& b) {
            D3D12_SHADER_RESOURCE_VIEW_DESC sd = {};
            sd.Format = DXGI_FORMAT_R32_TYPELESS;
            sd.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
            sd.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
            sd.Buffer = { 0, (UINT) (b.size / 4), 0, D3D12_BUFFER_SRV_FLAG_RAW };
            dev->CreateShaderResourceView(b.r.Get(), &sd, h);
            h.ptr += inc;
        };
        srvStructured(*runs[l].in);
        srvRawE(*runs[l].in);
        srvStructured(*runs[l].in2);
        srvRawE(model);
        D3D12_UNORDERED_ACCESS_VIEW_DESC ud = {};
        ud.Format = DXGI_FORMAT_R32_TYPELESS;
        ud.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
        ud.Buffer = { 0, (UINT) (runs[l].out->size / 4), 0, 0, D3D12_BUFFER_UAV_FLAG_RAW };
        dev->CreateUnorderedAccessView(runs[l].out->r.Get(), nullptr, &ud, h);
    }
    return true;
}

inline void Nss::RecordEngine(ID3D12GraphicsCommandList* cl)
{
                                                                                                 
                                                                                               
                                                                                               
    static const bool tryTiledS1 = std::getenv("NSS_DX12_TILED_S1") != nullptr;
    static const bool tryTile16 = std::getenv("NSS_DX12_TILE16") != nullptr;
                                                                                               
                                                                                                 
    static const bool tryCacheHint = std::getenv("NSS_DX12_CACHE_HINT") != nullptr;
                                                                                              
                                                                                                 
                                                   
    static const bool tryO0 = std::getenv("NSS_DX12_O0") != nullptr;
    static const bool trySm66 = std::getenv("NSS_DX12_SM66") != nullptr;
    const bool useHint = tryCacheHint && psoConvHint && rsConvHint;
    ID3D12PipelineState* flagPso = tryO0 && psoConvO0 ? psoConvO0.Get() : (trySm66 && psoConvSm66 ? psoConvSm66.Get() : nullptr);
    static const bool layerProfile = std::getenv("NSS_DX12_LAYER_PROFILE") != nullptr;
    if (layerProfile && !qhLayers)
    {
        D3D12_QUERY_HEAP_DESC qhd = { D3D12_QUERY_HEAP_TYPE_TIMESTAMP, 28 };
        dev->CreateQueryHeap(&qhd, IID_PPV_ARGS(&qhLayers));
        D3D12_HEAP_PROPERTIES hp = { D3D12_HEAP_TYPE_READBACK };
        D3D12_RESOURCE_DESC rd = {};
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Width = 28 * sizeof(uint64_t);
        rd.Height = 1; rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.SampleDesc.Count = 1;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COPY_DEST, nullptr, IID_PPV_ARGS(&qbLayers));
        D3D12_RANGE noRead = { 0, 0 };
        qbLayers->Map(0, &noRead, (void**) &qbLayersMap);
    }
    ID3D12DescriptorHeap* heaps[] = { convHeap.Get() };
    cl->SetDescriptorHeaps(1, heaps);
    cl->SetComputeRootSignature(useHint ? rsConvHint.Get() : rsConv.Get());
    if (useHint) cl->SetPipelineState(psoConvHint.Get());
    const NssLayerParam* layers = g_nss_high_layers;
    ID3D12PipelineState* boundPso = useHint ? psoConvHint.Get() : nullptr;
    for (int l = 0; l < 14; ++l)
    {
        const NssLayerParam& lp = layers[l];
        LayerRun& r = runs[l];
        const bool tiled = !useHint && !flagPso && tryTiledS1 && psoConvTiledS1 && lp.stride_y == 1 && lp.stride_x == 1 && lp.pad_y == 1 && lp.pad_x == 1;
        const bool tiled16 = tiled && tryTile16 && psoConvTiledS1T16;
        ID3D12PipelineState* wantPso = psoConv.Get();
        if (useHint) wantPso = psoConvHint.Get();
        else if (flagPso) wantPso = flagPso;
        else if (tiled16) wantPso = psoConvTiledS1T16.Get();
        else if (tiled) wantPso = psoConvTiledS1.Get();
        else if (lp.out_channels == 4 && psoConvC4) wantPso = psoConvC4.Get();
        else if (lp.out_channels <= 16 && psoConvC16) wantPso = psoConvC16.Get();
        if (wantPso != boundPso) { cl->SetPipelineState(wantPso); boundPso = wantPso; }
        To(cl, *r.in, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        if (r.in2 != r.in)
            To(cl, *r.in2, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, *r.out, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        ConvParams pc = { r.inW, r.inH, r.outW, r.outH, lp.in_channels, lp.out_channels, lp.pad_y, lp.pad_x, lp.stride_y, lp.stride_x,
                          lp.out_zp == 128 ? -128 : lp.out_zp, lp.has_table, r.in1c, r.up ? 1u : 0u, (uint32_t) lp.weight_tiled_offset,
                          (uint32_t) lp.bias_offset, (uint32_t) lp.mul_offset, (uint32_t) lp.shift_offset, (uint32_t) lp.table_offset };
        cl->SetComputeRoot32BitConstants(0, sizeof(pc) / 4, &pc, 0);
        D3D12_GPU_DESCRIPTOR_HANDLE gh = convHeap->GetGPUDescriptorHandleForHeapStart();
        gh.ptr += (UINT64) l * 5 * inc;
        cl->SetComputeRootDescriptorTable(1, gh);
        if (layerProfile) cl->EndQuery(qhLayers.Get(), D3D12_QUERY_TYPE_TIMESTAMP, l * 2 + 0);
        if (tiled16)
            cl->Dispatch((r.outW + 15) / 16, (r.outH + 15) / 16, ((lp.out_channels + 15) / 16 + 1) / 2);
        else if (tiled)
            cl->Dispatch((r.outW + 7) / 8, (r.outH + 7) / 8, ((lp.out_channels + 15) / 16 + 1) / 2);
        else
            cl->Dispatch((r.outW * r.outH + 63) / 64, ((lp.out_channels + 15) / 16 + 1) / 2, 1);
        D3D12_RESOURCE_BARRIER ub = {};
        ub.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        ub.UAV.pResource = r.out->r.Get();
        cl->ResourceBarrier(1, &ub);
        if (layerProfile) cl->EndQuery(qhLayers.Get(), D3D12_QUERY_TYPE_TIMESTAMP, l * 2 + 1);
    }
    if (layerProfile)
    {
        cl->ResolveQueryData(qhLayers.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 0, 28, qbLayers.Get(), 0);
    }
}

                                                                                                                     
inline void Nss::SetupConstants(const Frame& f)
{
    const bool needReset = firstExecution || f.reset;
    if (needReset)
        std::memset(&c, 0, sizeof(c));

                                                                          
    {
        const bool inv = d.depthInverted, inf = d.depthInfinite;
        float fMin = std::min(f.camNear, f.camFar), fMax = std::max(f.camNear, f.camFar);
        if (inv)
            std::swap(fMin, fMax);
        const float fQ = fMax / (fMin - fMax);
        const float dd = -1.0f;
        const float ec[2][2] = { { fQ, -1.0f - FLT_EPSILON }, { fQ, 0.0f + FLT_EPSILON } };
        const float ee[2][2] = { { fQ * fMin, -fMin - FLT_EPSILON }, { fQ * fMin, fMax } };
        c._DeviceToViewDepth[0] = dd * ec[inv][inf];
        c._DeviceToViewDepth[1] = ee[inv][inf];
        const float aspect = d.renderW / float(d.renderH);
        const float cot = std::cos(0.5f * f.fovY) / std::sin(0.5f * f.fovY);
        c._DeviceToViewDepth[2] = 1.0f / (cot / aspect);
        c._DeviceToViewDepth[3] = 1.0f / cot;
    }

    c._InputDims[0] = d.renderW;
    c._InputDims[1] = d.renderH;
    c._InvInputDims[0] = 1.f / float(d.renderW);
    c._InvInputDims[1] = 1.f / float(d.renderH);
    c._OutputDims[0] = d.dispW;
    c._OutputDims[1] = d.dispH;
    c._InvOutputDims[0] = 1.f / float(d.dispW);
    c._InvOutputDims[1] = 1.f / float(d.dispH);
    c._InputTensorSize[0] = dgW;
    c._InputTensorSize[1] = dgH;
    c._InputTensorSizeRcp[0] = 1.0f / float(dgW);
    c._InputTensorSizeRcp[1] = 1.0f / float(dgH);

    if (needReset)
    {
        c._JitterOffsetTm1[0] = f.jitterX;
        c._JitterOffsetTm1[1] = f.jitterY;
        c._JitterOffsetTm1[2] = f.jitterX / float(d.renderW);
        c._JitterOffsetTm1[3] = f.jitterY / float(d.renderH);
    }
    else
    {
        std::memcpy(c._JitterOffsetTm1, c._JitterOffset, sizeof(c._JitterOffset));
    }
    c._JitterOffset[0] = f.jitterX;
    c._JitterOffset[1] = f.jitterY;
    c._JitterOffset[2] = f.jitterX / float(d.renderW);
    c._JitterOffset[3] = f.jitterY / float(d.renderH);

    c._ScaleFactor[0] = c._OutputDims[0] / float(c._InputDims[0]);
    c._ScaleFactor[1] = c._OutputDims[1] / float(c._InputDims[1]);
    c._ScaleFactor[2] = c._InputDims[0] / float(c._OutputDims[0]);
    c._ScaleFactor[3] = c._InputDims[1] / float(c._OutputDims[1]);

    c._MotionVectorScale[0] = f.mvScaleX;
    c._MotionVectorScale[1] = f.mvScaleY;
    c._PaddingScale[0] = c._InputDims[0] / float(dgW);
    c._PaddingScale[1] = c._InputDims[1] / float(dgH);
    c._DepthTm1Size[0] = dsW;
    c._DepthTm1Size[1] = dsH;
    c._InvDepthTm1Size[0] = 1.f / float(dsW);
    c._InvDepthTm1Size[1] = 1.f / float(dsH);
    c._KpnDimension[0] = kpnW;
    c._KpnDimension[1] = kpnH;

    const float halfViewport = std::sqrt(float(d.renderW * d.renderW + d.renderH * d.renderH));
    const float cornerLen = std::sqrt(c._DeviceToViewDepth[2] * c._DeviceToViewDepth[2] + c._DeviceToViewDepth[3] * c._DeviceToViewDepth[3] + 1.0f);
    c._DepthClipRequiredSepScale = 1.37e-05f * cornerLen * halfViewport;
    c._DepthClipPower = 1.0f + 2.0f * std::min(std::max(halfViewport / 2202.9071700822983f, 0.0f), 1.0f);

    c._KpnScale[0] = float(kpnW) / float(dgW);
    c._KpnScale[1] = float(kpnH) / float(dgH);
    c._DebugViewMode = 0;

    const float exposure = (f.exposure <= 0.0f) ? float(std::exp(2.0)) : f.exposure;
    c._NotHistoryReset = needReset ? 0.0f : 1.0f;
    c._Exposure[0] = exposure;
    c._Exposure[1] = 1.f / exposure;
    c._IndexModulo[0] = hrW;
    c._IndexModulo[1] = hrH;
    c._ReducedInputModulo[0] = lrW;
    c._ReducedInputModulo[1] = lrH;

    int32_t off[2] = { 0, 0 };
    if (!dynLut)
    {
        const float sx = c._ScaleFactor[0], sy = c._ScaleFactor[1];
        const int baseX = (int) std::floor(0.5f * sx), baseY = (int) std::floor(0.5f * sy);
        const int jx = (int) std::floor((c._JitterOffset[0] + 0.5f) * sx), jy = (int) std::floor((c._JitterOffset[1] + 0.5f) * sy);
        const int mx = (int) hrW, my = (int) hrH;
        int ox = (jx - baseX) % mx, oy = (jy - baseY) % my;
        if (ox < 0) ox += mx;
        if (oy < 0) oy += my;
        off[0] = ox;
        off[1] = oy;
    }
    c._LutOffset[0] = (uint32_t) off[0];
    c._LutOffset[1] = (uint32_t) off[1];
}

inline bool Nss::Record(const Frame& f)
{
    ID3D12GraphicsCommandList* cl = f.cl;
    if (!cl || !f.color || !f.depth || !f.motion || !f.output)
        return false;

    const bool needReset = firstExecution || f.reset;
    SetupConstants(f);
    const uint32_t slot = ringFrame++ % kRing;
    std::memcpy(constMap + 256ull * slot, &c, sizeof(c));
    const D3D12_GPU_VIRTUAL_ADDRESS cva = constUpload.r->GetGPUVirtualAddress() + 256ull * slot;

    ID3D12DescriptorHeap* heaps[] = { heap.Get() };
    cl->SetDescriptorHeaps(1, heaps);
    cl->SetComputeRootSignature(rs.Get());

                                                                             
    const bool odd = (frameIndex & 1) != 0;
    Res& lumaSrv = odd ? luma2 : luma1;
    Res& lumaUav = odd ? luma1 : luma2;
    Res& histSrv = odd ? history2 : history1;
    Res& histUav = odd ? history1 : history2;

    const D3D12_GPU_DESCRIPTOR_HANDLE clearGpu0 = heap->GetGPUDescriptorHandleForHeapStart();
    const D3D12_CPU_DESCRIPTOR_HANDLE clearCpu0 = cpuHeap->GetCPUDescriptorHandleForHeapStart();
    auto clearAt = [&](int i, Res& r, bool asUint, uint32_t uval) {
        To(cl, r, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        D3D12_GPU_DESCRIPTOR_HANDLE g = clearGpu0;
        g.ptr += (UINT64) i * inc;
        D3D12_CPU_DESCRIPTOR_HANDLE cp = clearCpu0;
        cp.ptr += (SIZE_T) i * inc;
        if (asUint)
        {
            const UINT v[4] = { uval, uval, uval, uval };
            cl->ClearUnorderedAccessViewUint(g, cp, r.r.Get(), v, 0, nullptr);
        }
        else
        {
            const FLOAT v[4] = {};
            cl->ClearUnorderedAccessViewFloat(g, cp, r.r.Get(), v, 0, nullptr);
        }
    };

    if (needReset)
    {
        clearAt(0, luma1, false, 0);
        clearAt(1, luma2, false, 0);
        clearAt(2, nearest, false, 0);
        clearAt(3, feedbackImg, true, 0);
        clearAt(4, history1, false, 0);
        clearAt(5, history2, false, 0);
    }

                              
    clearAt(6, depthTm1, true, d.depthInverted ? 0u : 0x7fffffffu);
    {
        const Table t = TableAt(slot, 0);
        NullTable(t);
        Srv2D(t, 1, f.depth, f.depthFmt);
        Srv2D(t, 2, f.motion, f.motionFmt);
        Uav2D(t, 3, depthTm1.r.Get(), DXGI_FORMAT_R32_UINT);
        Cbv(t, 4, cva);
        cl->SetPipelineState(psoDepth.Get());
        cl->SetComputeRootDescriptorTable(0, t.gpu);
        cl->Dispatch((dsW + 15) / 16, (dsH + 15) / 16, 1);
        UavBarrier(cl);
    }

                           
    {
        To(cl, depthTm1, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, lumaSrv, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, histSrv, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, feedbackImg, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, lumaUav, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        To(cl, nearest, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        To(cl, tIn, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        const Table t = TableAt(slot, 1);
        NullTable(t);
        Srv2D(t, 0, f.color, f.colorFmt);
        Srv2D(t, 1, f.depth, f.depthFmt);
        Srv2D(t, 2, f.motion, f.motionFmt);
        Srv2D(t, 3, histSrv.r.Get(), DXGI_FORMAT_R11G11B10_FLOAT);
        Srv2D(t, 4, feedbackImg.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM);
        Srv2D(t, 5, depthTm1.r.Get(), DXGI_FORMAT_R32_UINT);
        Srv2D(t, 6, lumaSrv.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM);
        UavRaw(t, 8, tIn);
        Uav2D(t, 9, lumaUav.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM);
        Uav2D(t, 10, nearest.r.Get(), DXGI_FORMAT_R8_UNORM);
        Cbv(t, 12, cva);
        cl->SetPipelineState(psoPre.Get());
        cl->SetComputeRootDescriptorTable(0, t.gpu);
        cl->Dispatch((dgW + 15) / 16, (dgH + 15) / 16, 1);
        UavBarrier(cl);
    }

                                                           
    static const bool engineProfile = std::getenv("NSS_DX12_ENGINE_PROFILE") != nullptr;
    if (engineProfile)
    {
        if (!qhEngine)
        {
            D3D12_QUERY_HEAP_DESC qhd = { D3D12_QUERY_HEAP_TYPE_TIMESTAMP, 2, 0 };
            dev->CreateQueryHeap(&qhd, IID_PPV_ARGS(&qhEngine));
            D3D12_HEAP_PROPERTIES hp = { D3D12_HEAP_TYPE_READBACK };
            D3D12_RESOURCE_DESC rd = {};
            rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
            rd.Width = 16;
            rd.Height = 1; rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.SampleDesc.Count = 1;
            rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
            dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COPY_DEST, nullptr, IID_PPV_ARGS(&qbEngine));
            D3D12_RANGE noRead = { 0, 0 };
            qbEngine->Map(0, &noRead, (void**) &qbEngineMap);
        }
        cl->EndQuery(qhEngine.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 0);
    }
    RecordEngine(cl);
    if (engineProfile)
    {
        cl->EndQuery(qhEngine.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 1);
        cl->ResolveQueryData(qhEngine.Get(), D3D12_QUERY_TYPE_TIMESTAMP, 0, 2, qbEngine.Get(), 0);
    }

                                 
    cl->SetDescriptorHeaps(1, heaps);
    cl->SetComputeRootSignature(rs.Get());

                                           
    {
        To(cl, tFdbk, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, feedbackImg, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        const Table t = TableAt(slot, 2);
        NullTable(t);
        SrvRaw(t, 0, tFdbk);
        Uav2D(t, 0, feedbackImg.r.Get(), DXGI_FORMAT_R8G8B8A8_UINT);
        Cbv(t, 0, constUpload.r->GetGPUVirtualAddress() + 256ull * kRing);
        cl->SetPipelineState(psoB2T.Get());
        cl->SetComputeRootDescriptorTable(0, t.gpu);
        cl->Dispatch((dgW + 7) / 8, (dgH + 7) / 8, 1);
        UavBarrier(cl);
    }

                                         
    if (dynLut)
    {
        To(cl, offsetLut, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        const Table t = TableAt(slot, 3);
        NullTable(t);
        Uav2D(t, 0, offsetLut.r.Get(), DXGI_FORMAT_R32G32B32A32_UINT);
        Cbv(t, 11, cva);
        cl->SetPipelineState(psoLut.Get());
        cl->SetComputeRootDescriptorTable(0, t.gpu);
        cl->Dispatch((hrW * hrH + 63) / 64, 1, 1);
        UavBarrier(cl);
    }

                            
    {
        To(cl, tKpn, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, feedbackImg, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, nearest, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        if (dynLut)
            To(cl, offsetLut, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        To(cl, histUav, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        To(cl, histSrv, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
        const Table t = TableAt(slot, 4);
        NullTable(t);
        Srv2D(t, 0, f.color, f.colorFmt);
        Srv2D(t, 1, f.motion, f.motionFmt);
        Srv2D(t, 2, histSrv.r.Get(), DXGI_FORMAT_R11G11B10_FLOAT);
        SrvRaw(t, 3, tKpn);
        Srv2D(t, 4, feedbackImg.r.Get(), DXGI_FORMAT_R8G8B8A8_SNORM);
        Srv2D(t, 5, nearest.r.Get(), DXGI_FORMAT_R8_UNORM);
        if (dynLut)
            Srv2D(t, 6, offsetLut.r.Get(), DXGI_FORMAT_R32G32B32A32_UINT);
        Uav2D(t, 7, f.output, f.outputFmt);
        Uav2D(t, 8, histUav.r.Get(), DXGI_FORMAT_R11G11B10_FLOAT);
        Cbv(t, 9, cva);
        cl->SetPipelineState(psoPost.Get());
        cl->SetComputeRootDescriptorTable(0, t.gpu);
        cl->Dispatch((d.dispW + 15) / 16, (d.dispH + 15) / 16, 1);
        UavBarrier(cl);
    }

    firstExecution = false;
    frameIndex = (frameIndex + 1) % 2;
    return true;
}

}                    
