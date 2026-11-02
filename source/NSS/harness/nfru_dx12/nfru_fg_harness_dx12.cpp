                                                                                                                       
                                                                                                                      
                                                                                                                      
                                                                 
  
                                                                             
                                                                                                               
#define NOMINMAX
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <ffx_api/ffx_api.h>
#include <ffx_api/ffx_framegeneration.h>
#include <ffx_api/dx12/ffx_api_dx12.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <dbghelp.h>
#pragma comment(lib, "dbghelp.lib")
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")

static void fatal(const char* m) { fprintf(stderr, "%s\n", m); exit(1); }
#define HR(x) do { HRESULT hr_ = (x); if (FAILED(hr_)) { fprintf(stderr, "HRESULT 0x%08lx at %s:%d (%s)\n", (unsigned long) hr_, __FILE__, __LINE__, #x); exit(2); } } while (0)

static ID3D12Device* g_dev;
static ID3D12InfoQueue* g_info;

                                                                   
static void dumpDebugMessages(const char* where)
{
    if (!g_info) return;
    const UINT64 n = g_info->GetNumStoredMessages();
    for (UINT64 i = 0; i < n && i < 40; ++i)
    {
        SIZE_T len = 0;
        g_info->GetMessage(i, nullptr, &len);
        std::vector<char> buf(len);
        D3D12_MESSAGE* m = (D3D12_MESSAGE*) buf.data();
        g_info->GetMessage(i, m, &len);
        if (m->Severity <= D3D12_MESSAGE_SEVERITY_WARNING)
            printf("[D3D12 %s %s] %s\n", where, m->Severity == D3D12_MESSAGE_SEVERITY_WARNING ? "warn" : "ERROR", m->pDescription);
    }
    g_info->ClearStoredMessages();
}

                                                                       
struct NfruMfgDesc { ffxDispatchDescHeader header; uint32_t index, count; };
struct NfruHudDesc { ffxDispatchDescHeader header; FfxApiResource fullColor; };

static uint16_t f2h(float f)
{
    uint32_t x;
    memcpy(&x, &f, 4);
    uint32_t sign = (x >> 16) & 0x8000;
    int32_t e = ((x >> 23) & 0xff) - 127 + 15;
    uint32_t m = x & 0x7fffff;
    if (e <= 0) return (uint16_t) sign;
    if (e >= 31) return (uint16_t) (sign | 0x7bff);
    return (uint16_t) (sign | (e << 10) | (m >> 13));
}

                                                             
static void scene(float px, float py, float W, float H, float* rgb)
{
    const float u = px / W, v = py / H;
    float g = 0.5f + 0.5f * std::sin(px * 0.35f) * std::sin(py * 0.27f);
    float cx = u - 0.5f, cy = v - 0.5f;
    float rr = std::sqrt(cx * cx + cy * cy);
    float ring = 0.5f + 0.5f * std::sin(rr * 90.0f);
    rgb[0] = 0.15f + 0.6f * g;
    rgb[1] = 0.10f + 0.6f * ring;
    rgb[2] = 0.20f + 0.5f * (0.5f + 0.5f * std::sin((px + py) * 0.11f));
    if (u > 0.30f && u < 0.60f && v > 0.25f && v < 0.70f)
    {
        rgb[0] = 0.9f; rgb[1] = 0.75f; rgb[2] = 0.15f;
        if (((int) (px / 8) + (int) (py / 8)) & 1) { rgb[0] = 0.1f; rgb[1] = 0.1f; rgb[2] = 0.7f; }
    }
}

static void renderFrame(std::vector<uint8_t>& out, uint32_t W, uint32_t H, float S)
{
    out.resize((size_t) W * H * 4);
    for (uint32_t y = 0; y < H; ++y)
        for (uint32_t x = 0; x < W; ++x)
        {
            float rgb[3];
            scene((float) x + 0.5f - S, (float) y + 0.5f, (float) W, (float) H, rgb);
            uint8_t* p = &out[((size_t) y * W + x) * 4];
            for (int c = 0; c < 3; ++c) p[c] = (uint8_t) (std::fmin(std::fmax(rgb[c], 0.f), 1.f) * 255.f + 0.5f);
            p[3] = 255;
        }
}

static double psnr(const std::vector<uint8_t>& a, const std::vector<uint8_t>& b, uint32_t W, uint32_t H, uint32_t margin)
{
    double se = 0; size_t n = 0;
    for (uint32_t y = margin; y < H - margin; ++y)
        for (uint32_t x = margin; x < W - margin; ++x)
            for (int c = 0; c < 3; ++c)
            {
                double d = (double) a[((size_t) y * W + x) * 4 + c] - (double) b[((size_t) y * W + x) * 4 + c];
                se += d * d; ++n;
            }
    double mse = se / (double) n;
    return mse < 1e-9 ? 99.0 : 10.0 * std::log10(255.0 * 255.0 / mse);
}

static void writePPM(const std::string& path, const std::vector<uint8_t>& px, uint32_t W, uint32_t H)
{
    FILE* f = fopen(path.c_str(), "wb");
    fprintf(f, "P6\n%u %u\n255\n", W, H);
    for (size_t i = 0; i < (size_t) W * H; ++i) fwrite(&px[i * 4], 1, 3, f);
    fclose(f);
}

static ID3D12Resource* makeTex(uint32_t w, uint32_t h, DXGI_FORMAT fmt, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES state)
{
    D3D12_HEAP_PROPERTIES hp = {};
    hp.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    rd.Width = w; rd.Height = h; rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.Format = fmt; rd.SampleDesc.Count = 1;
    rd.Flags = flags;
    ID3D12Resource* r = nullptr;
    HR(g_dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, state, nullptr, IID_PPV_ARGS(&r)));
    return r;
}

static ID3D12Resource* makeBuf(uint64_t bytes, D3D12_HEAP_TYPE type, D3D12_RESOURCE_STATES state)
{
    D3D12_HEAP_PROPERTIES hp = {};
    hp.Type = type;
    D3D12_RESOURCE_DESC rd = {};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width = bytes; rd.Height = 1; rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    ID3D12Resource* r = nullptr;
    HR(g_dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, state, nullptr, IID_PPV_ARGS(&r)));
    return r;
}

static void barrier(ID3D12GraphicsCommandList* cl, ID3D12Resource* r, D3D12_RESOURCE_STATES a, D3D12_RESOURCE_STATES b)
{
    if (a == b) return;
    D3D12_RESOURCE_BARRIER rb = {};
    rb.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    rb.Transition.pResource = r;
    rb.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    rb.Transition.StateBefore = a;
    rb.Transition.StateAfter = b;
    cl->ResourceBarrier(1, &rb);
}

                                         
static void copyBufToTex(ID3D12GraphicsCommandList* cl, ID3D12Resource* buf, ID3D12Resource* tex, uint32_t w, uint32_t h, DXGI_FORMAT fmt, uint32_t pitch)
{
    D3D12_TEXTURE_COPY_LOCATION src = {}, dst = {};
    src.pResource = buf;
    src.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    src.PlacedFootprint.Footprint = { fmt, w, h, 1, pitch };
    dst.pResource = tex;
    dst.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    cl->CopyTextureRegion(&dst, 0, 0, 0, &src, nullptr);
}

static FfxApiResource apiRes(ID3D12Resource* r, uint32_t fmt, uint32_t w, uint32_t h, uint32_t usage, uint32_t state)
{
    FfxApiResource res = {};
    res.resource = r;
    res.description.type = FFX_API_RESOURCE_TYPE_TEXTURE2D;
    res.description.format = fmt;
    res.description.width = w;
    res.description.height = h;
    res.description.depth = 1;
    res.description.mipCount = 1;
    res.description.usage = usage;
    res.state = state;
    return res;
}

                                                                                          
static LONG WINAPI crashFilter(EXCEPTION_POINTERS* ep)
{
    HANDLE proc = GetCurrentProcess();
    SymSetOptions(SYMOPT_LOAD_LINES | SYMOPT_UNDNAME);
    SymInitialize(proc, nullptr, TRUE);
    printf("CRASH code 0x%08lx at %p\n", ep->ExceptionRecord->ExceptionCode, ep->ExceptionRecord->ExceptionAddress);
    CONTEXT ctx = *ep->ContextRecord;
    STACKFRAME64 sf = {};
    sf.AddrPC.Offset = ctx.Rip; sf.AddrPC.Mode = AddrModeFlat;
    sf.AddrFrame.Offset = ctx.Rbp; sf.AddrFrame.Mode = AddrModeFlat;
    sf.AddrStack.Offset = ctx.Rsp; sf.AddrStack.Mode = AddrModeFlat;
    for (int i = 0; i < 24 && StackWalk64(IMAGE_FILE_MACHINE_AMD64, proc, GetCurrentThread(), &sf, &ctx, nullptr, SymFunctionTableAccess64, SymGetModuleBase64, nullptr); ++i)
    {
        char buf[sizeof(SYMBOL_INFO) + 256] = {};
        SYMBOL_INFO* si = (SYMBOL_INFO*) buf;
        si->SizeOfStruct = sizeof(SYMBOL_INFO); si->MaxNameLen = 255;
        DWORD64 d64 = 0; DWORD d32 = 0;
        IMAGEHLP_LINE64 line = { sizeof(line) };
        const bool hasSym = SymFromAddr(proc, sf.AddrPC.Offset, &d64, si);
        const bool hasLine = SymGetLineFromAddr64(proc, sf.AddrPC.Offset, &d32, &line);
        printf("  #%d %p %s %s:%lu\n", i, (void*) sf.AddrPC.Offset, hasSym ? si->Name : "?", hasLine ? line.FileName : "", hasLine ? line.LineNumber : 0);
    }
    fflush(stdout);
    return EXCEPTION_EXECUTE_HANDLER;
}

int main(int argc, char** argv)
{
    setvbuf(stdout, nullptr, _IONBF, 0);
    SetUnhandledExceptionFilter(crashFilter);
    if (argc < 2) fatal("usage: nfru_fg_harness_dx12 <outprefix> [frames] [shiftPx] [W] [H]");
    const std::string prefix = argv[1];
    const int frames = argc > 2 ? atoi(argv[2]) : 12;
    const float shift = argc > 3 ? (float) atof(argv[3]) : 4.0f;
    const uint32_t W = argc > 4 ? atoi(argv[4]) : 640, H = argc > 5 ? atoi(argv[5]) : 360;
    const bool useMv = !getenv("HARNESS_MV") || atoi(getenv("HARNESS_MV")) != 0;
                                                                                      
    const bool bb10 = getenv("HARNESS_BB10") && atoi(getenv("HARNESS_BB10")) != 0;
    const DXGI_FORMAT bbFmt = bb10 ? DXGI_FORMAT_R10G10B10A2_UNORM : DXGI_FORMAT_R8G8B8A8_UNORM;
    const uint32_t bbApiFmt = bb10 ? FFX_API_SURFACE_FORMAT_R10G10B10A2_UNORM : FFX_API_SURFACE_FORMAT_R8G8B8A8_UNORM;
    const float mvSign = getenv("HARNESS_MV_SIGN") ? (float) atof(getenv("HARNESS_MV_SIGN")) : -1.0f;

    if (getenv("HARNESS_DEBUG_LAYER"))
    {
        ID3D12Debug* dbg = nullptr;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&dbg)))) { dbg->EnableDebugLayer(); dbg->Release(); }
    }
    IDXGIFactory6* factory = nullptr;
    HR(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory)));
    IDXGIAdapter1* adapter = nullptr;
    HR(factory->EnumAdapterByGpuPreference(0, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, IID_PPV_ARGS(&adapter)));
    DXGI_ADAPTER_DESC1 ad;
    adapter->GetDesc1(&ad);
    HR(D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&g_dev)));
    if (getenv("HARNESS_DEBUG_LAYER")) g_dev->QueryInterface(IID_PPV_ARGS(&g_info));
                                                                                                                  
    const uint32_t RW = getenv("HARNESS_RW") ? atoi(getenv("HARNESS_RW")) : W, RH = getenv("HARNESS_RH") ? atoi(getenv("HARNESS_RH")) : H;
    const bool hud = getenv("HARNESS_HUD") && atoi(getenv("HARNESS_HUD")) != 0;
    const bool hdrFlag = getenv("HARNESS_HDR") && atoi(getenv("HARNESS_HDR")) != 0;
    const uint32_t mfgCount = getenv("HARNESS_MFG") ? (uint32_t) atoi(getenv("HARNESS_MFG")) : 1;
    const bool copyDest = getenv("HARNESS_COPYDEST") && atoi(getenv("HARNESS_COPYDEST")) != 0;
    printf("render %ux%u hud=%d hdr=%d mfg=%u copyDest=%d debugLayer=%d\n", RW, RH, hud, hdrFlag, mfgCount, copyDest, g_info != nullptr);
    printf("GPU: %ls   scene %ux%u  shift %.1f px/frame  mv=%d sign=%.0f\n", ad.Description, W, H, shift, (int) useMv, mvSign);

                                                                                             
    const D3D12_COMMAND_LIST_TYPE listType =
        getenv("HARNESS_COMPUTE_LIST") && atoi(getenv("HARNESS_COMPUTE_LIST")) ? D3D12_COMMAND_LIST_TYPE_COMPUTE : D3D12_COMMAND_LIST_TYPE_DIRECT;
    printf("command list type: %s\n", listType == D3D12_COMMAND_LIST_TYPE_COMPUTE ? "COMPUTE" : "DIRECT");
    ID3D12CommandQueue* queue = nullptr;
    D3D12_COMMAND_QUEUE_DESC qd = {};
    qd.Type = listType;
    HR(g_dev->CreateCommandQueue(&qd, IID_PPV_ARGS(&queue)));
    ID3D12CommandAllocator* alloc = nullptr;
    HR(g_dev->CreateCommandAllocator(listType, IID_PPV_ARGS(&alloc)));
    ID3D12GraphicsCommandList* cl = nullptr;
    HR(g_dev->CreateCommandList(0, listType, alloc, nullptr, IID_PPV_ARGS(&cl)));
    HR(cl->Close());
    ID3D12Fence* fence = nullptr;
    HR(g_dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
    HANDLE fenceEvent = CreateEventA(nullptr, FALSE, FALSE, nullptr);
    uint64_t fenceValue = 0;

    HMODULE ngsdk = LoadLibraryA("ngsdk_dx12_windows_x64.dll");
    if (!ngsdk) fatal("cannot load ngsdk_dx12_windows_x64.dll");
    auto pCreate = (PfnFfxCreateContext) GetProcAddress(ngsdk, "ffxCreateContext");
    auto pConfigure = (PfnFfxConfigure) GetProcAddress(ngsdk, "ffxConfigure");
    auto pDispatch = (PfnFfxDispatch) GetProcAddress(ngsdk, "ffxDispatch");
    if (!pCreate || !pConfigure || !pDispatch) fatal("missing ffx exports");

    ffxCreateBackendDX12Desc backend = {};
    backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12;
    backend.device = g_dev;

    ffxApiCreateContextDescFrameGeneration cd = {};
    cd.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION;
    cd.header.pNext = &backend.header;
    cd.flags = FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED | FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR | FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH;
    cd.displaySize = { W, H };
    cd.renderSize = { RW, RH };
    if (hdrFlag) cd.flags |= FFX_API_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE;
    cd.backBufferFormat = bbApiFmt;
    cd.fpMessage = [](uint32_t t, const char* m) { printf("[FG msg %u] %s\n", t, m); };
    for (int i = 0; i < 4; ++i) cd.initialViewProjection[i * 5] = 1.0f;

    ffxContext ctx = nullptr;
    ffxReturnCode_t rc = pCreate(&ctx, &cd.header, nullptr);
    printf("ffxCreateContext(FG) -> %u\n", (unsigned) rc);
    dumpDebugMessages("create");
    if (rc != FFX_API_RETURN_OK) return 3;

    ffxApiConfigureDescFrameGeneration cfg = {};
    cfg.header.type = FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION;
    cfg.flags = FFX_API_FG_DISPATCH_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY;
    rc = pConfigure(&ctx, &cfg.header);
    printf("ffxConfigure -> %u\n", (unsigned) rc);

    const D3D12_RESOURCE_STATES srvState = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
    ID3D12Resource* color = makeTex(W, H, bbFmt, D3D12_RESOURCE_FLAG_NONE, srvState);
    const D3D12_RESOURCE_STATES gameState = copyDest ? D3D12_RESOURCE_STATE_COPY_DEST : srvState;
    const uint32_t gameApiState = copyDest ? FFX_API_RESOURCE_STATE_COPY_DEST : FFX_API_RESOURCE_STATE_COMPUTE_READ;
    ID3D12Resource* depth = makeTex(RW, RH, DXGI_FORMAT_R32_FLOAT, D3D12_RESOURCE_FLAG_NONE, gameState);
    ID3D12Resource* mv = makeTex(RW, RH, DXGI_FORMAT_R16G16_FLOAT, D3D12_RESOURCE_FLAG_NONE, gameState);
    ID3D12Resource* hudless = hud ? makeTex(W, H, bbFmt, D3D12_RESOURCE_FLAG_NONE, gameState) : nullptr;
    ID3D12Resource* out = makeTex(W, H, bbFmt, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);

    const uint32_t pitch = (W * 4 + 255) & ~255u;                                      
    const uint32_t rpitch = (RW * 4 + 255) & ~255u;
    const uint64_t stBytes = (uint64_t) pitch * H;
    ID3D12Resource* stColor = makeBuf(stBytes, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* stDepth = makeBuf(stBytes, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* stMv = makeBuf(stBytes, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* rb = makeBuf(stBytes, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST);
    uint8_t *pColor, *pDepth, *pMv, *pRb;
    D3D12_RANGE none = { 0, 0 };
    HR(stColor->Map(0, &none, (void**) &pColor));
    HR(stDepth->Map(0, &none, (void**) &pDepth));
    HR(stMv->Map(0, &none, (void**) &pMv));
    HR(rb->Map(0, nullptr, (void**) &pRb));
    {
        const uint16_t mvx = f2h(useMv ? mvSign * shift : 0.0f), mvy = 0;
        const bool half = getenv("HARNESS_MV_HALF") && atoi(getenv("HARNESS_MV_HALF")) != 0;
        for (uint32_t y = 0; y < RH; ++y)
            for (uint32_t x = 0; x < RW; ++x)
            {
                ((float*) (pDepth + (size_t) y * rpitch))[x] = 0.5f;
                const bool zero = half && x >= RW / 2;
                ((uint16_t*) (pMv + (size_t) y * rpitch))[2 * x] = zero ? 0 : mvx;
                ((uint16_t*) (pMv + (size_t) y * rpitch))[2 * x + 1] = mvy;
            }
    }

    ID3D12QueryHeap* qheap = nullptr;
    D3D12_QUERY_HEAP_DESC qhd = { D3D12_QUERY_HEAP_TYPE_TIMESTAMP, 2, 0 };
    HR(g_dev->CreateQueryHeap(&qhd, IID_PPV_ARGS(&qheap)));
    ID3D12Resource* qrb = makeBuf(16, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST);
    uint64_t tsFreq = 1;
    queue->GetTimestampFrequency(&tsFreq);

    double gpuSum = 0;
    int gpuN = 0;
    std::vector<uint8_t> prevGt, curGt, midGt, outPx(W * H * 4), blend(W * H * 4);
    double sumI = 0, sumR = 0, sumB = 0;
    int counted = 0;
    renderFrame(prevGt, W, H, 0.0f);

    for (int f = 0; f < frames; ++f)
    {
        renderFrame(curGt, W, H, shift * (float) f);
        for (uint32_t y = 0; y < H; ++y)
        {
            if (!bb10) { memcpy(pColor + (size_t) y * pitch, &curGt[(size_t) y * W * 4], W * 4); continue; }
            uint32_t* row = (uint32_t*) (pColor + (size_t) y * pitch);
            for (uint32_t x = 0; x < W; ++x)
            {
                const uint8_t* c = &curGt[((size_t) y * W + x) * 4];
                auto q = [](uint8_t v) { return (uint32_t) ((v * 1023 + 127) / 255); };
                row[x] = q(c[0]) | (q(c[1]) << 10) | (q(c[2]) << 20) | (3u << 30);
            }
        }

        HR(alloc->Reset());
        HR(cl->Reset(alloc, nullptr));

        barrier(cl, color, srvState, D3D12_RESOURCE_STATE_COPY_DEST);
        barrier(cl, depth, gameState, D3D12_RESOURCE_STATE_COPY_DEST);
        barrier(cl, mv, gameState, D3D12_RESOURCE_STATE_COPY_DEST);
        if (hudless) barrier(cl, hudless, gameState, D3D12_RESOURCE_STATE_COPY_DEST);
        copyBufToTex(cl, stColor, color, W, H, bbFmt, pitch);
        if (hudless) copyBufToTex(cl, stColor, hudless, W, H, bbFmt, pitch);
        copyBufToTex(cl, stDepth, depth, RW, RH, DXGI_FORMAT_R32_FLOAT, rpitch);
        copyBufToTex(cl, stMv, mv, RW, RH, DXGI_FORMAT_R16G16_FLOAT, rpitch);
        barrier(cl, color, D3D12_RESOURCE_STATE_COPY_DEST, srvState);
        barrier(cl, depth, D3D12_RESOURCE_STATE_COPY_DEST, gameState);
        barrier(cl, mv, D3D12_RESOURCE_STATE_COPY_DEST, gameState);
        if (hudless) barrier(cl, hudless, D3D12_RESOURCE_STATE_COPY_DEST, gameState);

        cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 0);
        ffxApiDispatchDescFrameGenerationPrepare prep = {};
        prep.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION_PREPARE;
        prep.frameID = (uint64_t) f;
        prep.commandList = cl;
        prep.jitterOffset = { 0.f, 0.f };
        prep.motionVectorScale = { 1.f, 1.f };
        prep.frameTimeDelta = 16.6f;
        prep.cameraNear = 0.1f;
        prep.cameraFar = 1000.0f;
        prep.cameraFovAngleVertical = 1.0f;
        prep.viewSpaceToMetersFactor = 0.0f;
        prep.depth = apiRes(depth, FFX_API_SURFACE_FORMAT_R32_FLOAT, RW, RH, FFX_API_RESOURCE_USAGE_READ_ONLY, gameApiState);
        prep.motionVectors = apiRes(mv, FFX_API_SURFACE_FORMAT_R16G16_FLOAT, RW, RH, FFX_API_RESOURCE_USAGE_READ_ONLY, gameApiState);
        for (int i = 0; i < 4; ++i) prep.viewProjection[i * 5] = 1.0f;
        rc = pDispatch(&ctx, &prep.header);
        if (rc != FFX_API_RETURN_OK) printf("frame %d: Prepare -> %u\n", f, (unsigned) rc);

        for (uint32_t mi = 1; mi <= mfgCount; ++mi)
        {
            ffxApiDispatchDescFrameGeneration disp = {};
            disp.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION;
            disp.commandList = cl;
            disp.presentColor = hudless ? apiRes(hudless, bbApiFmt, W, H, FFX_API_RESOURCE_USAGE_READ_ONLY, gameApiState)
                                        : apiRes(color, bbApiFmt, W, H, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COMPUTE_READ);
            disp.outputs[0] = apiRes(out, bbApiFmt, W, H, FFX_API_RESOURCE_USAGE_UAV, FFX_API_RESOURCE_STATE_UNORDERED_ACCESS);
            disp.numGeneratedFrames = 1;
            disp.reset = (f == 0);
            disp.frameID = (uint64_t) f;
            NfruMfgDesc mfgD = {};
            NfruHudDesc hudD = {};
            if (mfgCount > 1)
            {
                mfgD.header.type = 0x4E46525500000001ull;
                mfgD.index = mi;
                mfgD.count = mfgCount;
                disp.header.pNext = &mfgD.header;
            }
            if (hudless)
            {
                hudD.header.type = 0x4E46525500000002ull;
                hudD.header.pNext = disp.header.pNext;
                hudD.fullColor = apiRes(color, bbApiFmt, W, H, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COMPUTE_READ);
                disp.header.pNext = &hudD.header;
            }
            rc = pDispatch(&ctx, &disp.header);
            if (rc != FFX_API_RETURN_OK) printf("frame %d.%u: Dispatch -> %u\n", f, mi, (unsigned) rc);
        }
        cl->EndQuery(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 1);
        cl->ResolveQueryData(qheap, D3D12_QUERY_TYPE_TIMESTAMP, 0, 2, qrb, 0);
                                                                                                                      
                                                                                                                     
        if (getenv("HARNESS_RECREATE_AT") && f == atoi(getenv("HARNESS_RECREATE_AT")))
        {
            auto pDestroy = (PfnFfxDestroyContext) GetProcAddress(ngsdk, "ffxDestroyContext");
            rc = pDestroy(&ctx, nullptr);
            printf("frame %d: destroyed context with work pending -> %u\n", f, (unsigned) rc);
            ctx = nullptr;
            rc = pCreate(&ctx, &cd.header, nullptr);
            printf("frame %d: recreated context -> %u\n", f, (unsigned) rc);
            rc = pConfigure(&ctx, &cfg.header);
        }

        barrier(cl, out, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);
        D3D12_TEXTURE_COPY_LOCATION src = {}, dst = {};
        src.pResource = out;
        src.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
        dst.pResource = rb;
        dst.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
        dst.PlacedFootprint.Footprint = { bbFmt, W, H, 1, pitch };
        cl->CopyTextureRegion(&dst, 0, 0, 0, &src, nullptr);
        barrier(cl, out, D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        const HRESULT closeHr = cl->Close();
        dumpDebugMessages("record");
        if (FAILED(closeHr)) { printf("frame %d: COMMAND LIST CLOSE FAILED 0x%08lx\n", f, (unsigned long) closeHr); return 5; }
        ID3D12CommandList* lists[] = { cl };
        queue->ExecuteCommandLists(1, lists);
        HR(queue->Signal(fence, ++fenceValue));
        HR(fence->SetEventOnCompletion(fenceValue, fenceEvent));
        WaitForSingleObject(fenceEvent, INFINITE);
        if (FAILED(g_dev->GetDeviceRemovedReason()))
        {
            printf("frame %d: DEVICE REMOVED 0x%08lx\n", f, (unsigned long) g_dev->GetDeviceRemovedReason());
            return 4;
        }

        for (uint32_t y = 0; y < H; ++y)
        {
            if (!bb10) { memcpy(&outPx[(size_t) y * W * 4], pRb + (size_t) y * pitch, W * 4); continue; }
            const uint32_t* row = (const uint32_t*) (pRb + (size_t) y * pitch);
            for (uint32_t x = 0; x < W; ++x)
            {
                uint8_t* o = &outPx[((size_t) y * W + x) * 4];
                for (int c = 0; c < 3; ++c) o[c] = (uint8_t) ((((row[x] >> (10 * c)) & 1023u) * 255 + 511) / 1023);
                o[3] = 255;
            }
        }
        {
            uint64_t* t = nullptr;
            HR(qrb->Map(0, nullptr, (void**) &t));
            const double ms = (double) (t[1] - t[0]) * 1000.0 / (double) tsFreq;
            qrb->Unmap(0, &none);
            if (f >= 3) { gpuSum += ms; ++gpuN; }
        }

        if (f >= 3)
        {
            renderFrame(midGt, W, H, shift * ((float) f - 0.5f));
            for (size_t i = 0; i < blend.size(); ++i) blend[i] = (uint8_t) (((int) prevGt[i] + (int) curGt[i] + 1) / 2);
            const double pi = psnr(outPx, midGt, W, H, 24), pr = psnr(curGt, midGt, W, H, 24), pb = psnr(blend, midGt, W, H, 24);
            printf("frame %2d: interp %.2f dB | repeat-current %.2f dB | 50%% blend %.2f dB\n", f, pi, pr, pb);
            sumI += pi; sumR += pr; sumB += pb; ++counted;
            if (f == frames - 1)
            {
                writePPM(prefix + "_interp.ppm", outPx, W, H);
                writePPM(prefix + "_gt.ppm", midGt, W, H);
            }
        }
        prevGt = curGt;
    }
    if (gpuN) printf("GPU FG time (prepare+dispatch): %.3f ms avg over %d frames\n", gpuSum / gpuN, gpuN);
    if (counted)
        printf("MEAN over %d frames: interp %.2f dB | repeat %.2f dB | blend %.2f dB\n", counted, sumI / counted, sumR / counted, sumB / counted);
    return 0;
}
