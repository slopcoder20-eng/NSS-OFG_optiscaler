                                                                                                                    
                                                                                                                           
                                                                                                                
#pragma once
#include <d3d12.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "../vk/nss_engine/nfru_model_data.h"
#include "nfru_dx12_engine_shaders.h"
#include "nfru_dx12_copy_shader.h"
#include "nfru_dx12_deferred_release.h"

struct NfruEngineDX12
{
    struct Dim { uint32_t w = 0, h = 0, c = 0; };

    ID3D12Device*         dev = nullptr;
    ID3D12Resource*       blob = nullptr;                                            
    ID3D12Resource*       blobUpload = nullptr;                                                 
    bool                  blobPending = false;
    ID3D12Resource*       tensor[NFRU_NUM_OPS + 1] = {};                                                                       
    uint64_t              tensorBytes[NFRU_NUM_OPS + 1] = {};
    Dim                   dim[NFRU_NUM_OPS + 1];
    int                   alias[NFRU_NUM_OPS + 1];
    ID3D12RootSignature*  rootSig = nullptr;                                                                                
    ID3D12PipelineState*  psoConv = nullptr, *psoNarrow = nullptr, *psoC16 = nullptr, *psoConcat = nullptr, *psoToImage = nullptr;
    ID3D12DescriptorHeap* heap = nullptr;                                                                                                 
    UINT                  descSize = 0;
    uint32_t              width = 0, height = 0;
    bool                  ready = false;
    ID3D12Resource*       ioIn = nullptr, *ioOut = nullptr, *ioImage = nullptr;

    struct ConvPC { uint32_t in_w, in_h, out_w, out_h, in_c, out_c; int32_t pad_t, pad_l, stride_y, stride_x; uint32_t kh, kw; int32_t out_zp, mult, shift; uint32_t upsample; };
    struct ConcatPC { uint32_t pixels, count; };
    static constexpr uint32_t kSlots = 9;                            

    static ID3D12Resource* makeBuffer(ID3D12Device* d, uint64_t bytes, D3D12_HEAP_TYPE heapType, D3D12_RESOURCE_STATES state, bool uav)
    {
        D3D12_HEAP_PROPERTIES hp = {};
        hp.Type = heapType;
        D3D12_RESOURCE_DESC rd = {};
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Width = (bytes + 255) & ~uint64_t(255);
        rd.Height = 1; rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.SampleDesc.Count = 1;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        rd.Flags = uav ? D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS : D3D12_RESOURCE_FLAG_NONE;
        ID3D12Resource* r = nullptr;
        if (FAILED(d->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, state, nullptr, IID_PPV_ARGS(&r)))) return nullptr;
        return r;
    }

    ID3D12PipelineState* pso(const unsigned char* code, size_t size)
    {
        D3D12_COMPUTE_PIPELINE_STATE_DESC pd = {};
        pd.pRootSignature = rootSig;
        pd.CS = { code, size };
        ID3D12PipelineState* p = nullptr;
        if (FAILED(dev->CreateComputePipelineState(&pd, IID_PPV_ARGS(&p)))) return nullptr;
        return p;
    }

    bool init(ID3D12Device* d, uint32_t w, uint32_t h)
    {
        dev = d; width = w; height = h;
        if ((w % 4) || (h % 4)) { fprintf(stderr, "NFRU DX12: size must be a multiple of 4\n"); return false; }

        dim[0] = { w, h, NFRU_INPUT_CHANNELS };
        for (int i = 0; i <= NFRU_NUM_OPS; ++i) alias[i] = -1;
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            const Dim in0 = dim[op.in[0]];
            if (op.kind == NFRU_OP_CONV)
                dim[op.out] = { op.stride_x == 1 ? in0.w : in0.w / 2, op.stride_y == 1 ? in0.h : in0.h / 2, (uint32_t) op.out_c };
            else if (op.kind == NFRU_OP_CONCAT)
                dim[op.out] = { in0.w, in0.h, in0.c * (uint32_t) op.in_c };
            else
            {
                dim[op.out] = { in0.w * 2, in0.h * 2, in0.c };
                alias[op.out] = op.in[0];
            }
        }
        for (int t = 0; t <= NFRU_NUM_OPS; ++t)
        {
            tensorBytes[t] = (uint64_t) dim[t].w * dim[t].h * dim[t].c + 64;
            if (alias[t] >= 0 || t == 0 || t == NFRU_OUTPUT_TENSOR) continue;                             
            if (!(tensor[t] = makeBuffer(dev, tensorBytes[t], D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, true))) return false;
        }

                                                                                      
        blob = makeBuffer(dev, g_nfru_blob_size + 256, D3D12_HEAP_TYPE_DEFAULT, D3D12_RESOURCE_STATE_COPY_DEST, false);
        blobUpload = makeBuffer(dev, g_nfru_blob_size + 256, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ, false);
        if (!blob || !blobUpload) return false;
        void* p = nullptr;
        D3D12_RANGE none = { 0, 0 };
        if (FAILED(blobUpload->Map(0, &none, &p))) return false;
        memcpy(p, g_nfru_blob, g_nfru_blob_size);
        blobUpload->Unmap(0, nullptr);
        blobPending = true;

                                               
        D3D12_DESCRIPTOR_RANGE ranges[2] = {};
        ranges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV; ranges[0].NumDescriptors = 4; ranges[0].BaseShaderRegister = 0;
        ranges[0].OffsetInDescriptorsFromTableStart = 0;
        ranges[1].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV; ranges[1].NumDescriptors = 5; ranges[1].BaseShaderRegister = 0;
        ranges[1].OffsetInDescriptorsFromTableStart = 4;
        D3D12_ROOT_PARAMETER params[2] = {};
        params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
        params[0].DescriptorTable = { 2, ranges };
        params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
        params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
        params[1].Constants = { 0, 1, 16 };
        params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
        D3D12_ROOT_SIGNATURE_DESC rs = { 2, params, 0, nullptr, D3D12_ROOT_SIGNATURE_FLAG_NONE };
        ID3DBlob* sig = nullptr, *err = nullptr;
        if (FAILED(D3D12SerializeRootSignature(&rs, D3D_ROOT_SIGNATURE_VERSION_1, &sig, &err)))
        {
            if (err) { fprintf(stderr, "NFRU DX12 root signature: %s\n", (const char*) err->GetBufferPointer()); err->Release(); }
            return false;
        }
        const HRESULT hr = dev->CreateRootSignature(0, sig->GetBufferPointer(), sig->GetBufferSize(), IID_PPV_ARGS(&rootSig));
        sig->Release();
        if (FAILED(hr)) return false;

        psoConv = pso(g_dxil_nfru_conv, g_dxil_nfru_conv_size);
        psoNarrow = pso(g_dxil_nfru_conv_narrow_tiled, g_dxil_nfru_conv_narrow_tiled_size);
        psoC16 = pso(g_dxil_nfru_conv_dp4a_c16_1x1, g_dxil_nfru_conv_dp4a_c16_1x1_size);
        psoConcat = pso(g_dxil_nfru_concat, g_dxil_nfru_concat_size);
        psoToImage = pso(g_dxil_nfru_tensor_to_image, g_dxil_nfru_tensor_to_image_size);
        if (!psoConv || !psoConcat || !psoToImage) return false;

        D3D12_DESCRIPTOR_HEAP_DESC hd = { D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, (NFRU_NUM_OPS + 1) * kSlots, D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE, 0 };
        if (FAILED(dev->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&heap)))) return false;
        descSize = dev->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        ready = true;
        return true;
    }

    int srcTensor(int t) const { return alias[t] >= 0 ? alias[t] : t; }

    D3D12_CPU_DESCRIPTOR_HANDLE slot(int op, uint32_t s) const
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = heap->GetCPUDescriptorHandleForHeapStart();
        h.ptr += SIZE_T(op * kSlots + s) * descSize;
        return h;
    }

                                                                             
    void srv(D3D12_CPU_DESCRIPTOR_HANDLE h, ID3D12Resource* r, uint64_t offset, uint64_t bytes) const
    {
        D3D12_SHADER_RESOURCE_VIEW_DESC d = {};
        d.Format = DXGI_FORMAT_R32_TYPELESS;
        d.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
        d.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        d.Buffer.FirstElement = offset / 4;
        d.Buffer.NumElements = UINT(r ? (bytes + 3) / 4 : 1);
        d.Buffer.Flags = D3D12_BUFFER_SRV_FLAG_RAW;
        dev->CreateShaderResourceView(r, &d, h);
    }
    void uav(D3D12_CPU_DESCRIPTOR_HANDLE h, ID3D12Resource* r, uint64_t bytes) const
    {
        D3D12_UNORDERED_ACCESS_VIEW_DESC d = {};
        d.Format = DXGI_FORMAT_R32_TYPELESS;
        d.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
        d.Buffer.NumElements = UINT(r ? (bytes + 3) / 4 : 1);
        d.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
        dev->CreateUnorderedAccessView(r, nullptr, &d, h);
    }

                                                                                                                        
                                                                             
    bool bindIO(ID3D12Resource* in, ID3D12Resource* out, uint64_t inBytes, uint64_t outBytes)
    {
        if (!ready || !in || !out) return false;
        if (in == ioIn && out == ioOut) return true;
        ioIn = in; ioOut = out; ioImage = nullptr;
        tensor[0] = in; tensorBytes[0] = inBytes;
        tensor[NFRU_OUTPUT_TENSOR] = out; tensorBytes[NFRU_OUTPUT_TENSOR] = outBytes;
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            if (op.kind == NFRU_OP_RESIZE) continue;
            for (uint32_t s = 0; s < 4; ++s) srv(slot(i, s), nullptr, 0, 0);
            for (uint32_t s = 0; s < 5; ++s) uav(slot(i, 4 + s), nullptr, 0);
            if (op.kind == NFRU_OP_CONV)
            {
                const int src = srcTensor(op.in[0]);
                const uint64_t ict = op.in_c / 16, oct = (op.out_c + 15) / 16;
                srv(slot(i, 0), tensor[src], 0, tensorBytes[src]);
                srv(slot(i, 2), blob, op.weight_off, (uint64_t) op.kh * op.kw * ict * oct * 256);
                srv(slot(i, 3), blob, op.bias_off, (uint64_t) ((op.out_c + 3) / 4) * 16);
                uav(slot(i, 4 + 1), tensor[op.out], tensorBytes[op.out]);
            }
            else
            {
                for (int k = 0; k < 4; ++k)
                {
                    const int t = srcTensor(op.in[k < op.in_c ? k : 0]);
                    srv(slot(i, k), tensor[t], 0, tensorBytes[t]);
                }
                uav(slot(i, 4 + 4), tensor[op.out], tensorBytes[op.out]);
            }
        }
        return true;
    }

    void destroy()
    {
        auto rel = [](auto*& p) { if (p) { nfruDeferRelease(p); p = nullptr; } };                            
        for (int t = 1; t < NFRU_OUTPUT_TENSOR; ++t) if (alias[t] < 0) rel(tensor[t]);
        tensor[0] = tensor[NFRU_OUTPUT_TENSOR] = nullptr;
        rel(blob); rel(blobUpload); rel(heap);
        rel(psoConv); rel(psoNarrow); rel(psoC16); rel(psoConcat); rel(psoToImage); rel(rootSig);
        ready = false;
    }

    static void uavBarrier(ID3D12GraphicsCommandList* cl)
    {
        D3D12_RESOURCE_BARRIER b = {};
        b.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
        cl->ResourceBarrier(1, &b);
    }

                                                                                                                        
                                                                                                                
                                                                          
    void record(ID3D12GraphicsCommandList* cl)
    {
        if (blobPending)
        {
            cl->CopyBufferRegion(blob, 0, blobUpload, 0, g_nfru_blob_size);
            D3D12_RESOURCE_BARRIER b = {};
            b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
            b.Transition.pResource = blob;
            b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            b.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
            b.Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
            cl->ResourceBarrier(1, &b);
            blobPending = false;
        }
        ID3D12DescriptorHeap* heaps[] = { heap };
        cl->SetDescriptorHeaps(1, heaps);
        cl->SetComputeRootSignature(rootSig);
        static const bool tryNarrow = getenv("NFRU_NARROW_TILED") == nullptr || getenv("NFRU_NARROW_TILED")[0] != '0';
        static const bool tryC16 = getenv("NFRU_C16_1X1") == nullptr || getenv("NFRU_C16_1X1")[0] != '0';
        for (int i = 0; i < NFRU_NUM_OPS; ++i)
        {
            const NfruOp& op = g_nfru_ops[i];
            if (op.kind == NFRU_OP_RESIZE) continue;                                                 
            D3D12_GPU_DESCRIPTOR_HANDLE table = heap->GetGPUDescriptorHandleForHeapStart();
            table.ptr += UINT64(i * kSlots) * descSize;
            cl->SetComputeRootDescriptorTable(0, table);
            if (op.kind == NFRU_OP_CONV)
            {
                const Dim in = dim[op.in[0]], out = dim[op.out];
                ConvPC pc = { in.w, in.h, out.w, out.h, (uint32_t) op.in_c, (uint32_t) op.out_c, op.pad_t, op.pad_l, op.stride_y, op.stride_x,
                              (uint32_t) op.kh, (uint32_t) op.kw, op.out_zp, op.mult, op.shift, alias[op.in[0]] >= 0 ? 1u : 0u };
                const bool narrow = tryNarrow && psoNarrow && op.kh == 5 && op.kw == 5 && op.stride_y == 1 && op.stride_x == 1 &&
                                    op.pad_t == 2 && op.pad_l == 2 && op.in_c == 16 && op.out_c < 16 && pc.upsample == 0u;
                const bool c16 = tryC16 && psoC16 && op.kh == 1 && op.kw == 1 && op.stride_y == 1 && op.stride_x == 1 &&
                                 op.pad_t == 0 && op.pad_l == 0 && op.out_c == 16 && pc.upsample == 0u;
                cl->SetPipelineState(narrow ? psoNarrow : (c16 ? psoC16 : psoConv));
                cl->SetComputeRoot32BitConstants(1, sizeof(pc) / 4, &pc, 0);
                if (narrow)
                    cl->Dispatch((out.w + 7) / 8, (out.h + 7) / 8, 1);
                else if (c16)
                    cl->Dispatch((out.w + 15) / 16, (out.h + 3) / 4, 1);
                else
                    cl->Dispatch((out.w * out.h + 63) / 64, (((uint32_t) op.out_c + 15) / 16 + 1) / 2, 1);
            }
            else
            {
                const Dim out = dim[op.out];
                ConcatPC pc = { out.w * out.h, (uint32_t) op.in_c };
                cl->SetPipelineState(psoConcat);
                cl->SetComputeRoot32BitConstants(1, sizeof(pc) / 4, &pc, 0);
                cl->Dispatch((pc.pixels * pc.count + 63) / 64, 1, 1);
            }
            uavBarrier(cl);
        }
    }

                                                                                                                       
                                                                                                                    
    void recordToImage(ID3D12GraphicsCommandList* cl, ID3D12Resource* image)
    {
        if (image != ioImage)
        {
            ioImage = image;
            for (uint32_t s = 0; s < 4; ++s) srv(slot(NFRU_NUM_OPS, s), s ? nullptr : tensor[NFRU_OUTPUT_TENSOR], 0, s ? 0 : tensorBytes[NFRU_OUTPUT_TENSOR]);
            D3D12_UNORDERED_ACCESS_VIEW_DESC d = {};
            d.Format = DXGI_FORMAT_R8G8B8A8_UINT;
            d.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
            dev->CreateUnorderedAccessView(image, nullptr, &d, slot(NFRU_NUM_OPS, 4));
            for (uint32_t s = 1; s < 5; ++s) uav(slot(NFRU_NUM_OPS, 4 + s), nullptr, 0);
        }
        ID3D12DescriptorHeap* heaps[] = { heap };
        cl->SetDescriptorHeaps(1, heaps);
        cl->SetComputeRootSignature(rootSig);
        D3D12_GPU_DESCRIPTOR_HANDLE table = heap->GetGPUDescriptorHandleForHeapStart();
        table.ptr += UINT64(NFRU_NUM_OPS * kSlots) * descSize;
        cl->SetComputeRootDescriptorTable(0, table);
        const uint32_t pc[2] = { width, height };
        cl->SetPipelineState(psoToImage);
        cl->SetComputeRoot32BitConstants(1, 2, pc, 0);
        cl->Dispatch((width + 7) / 8, (height + 7) / 8, 1);
    }
};
