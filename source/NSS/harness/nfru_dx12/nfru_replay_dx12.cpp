                                                                                                                   
                                                                                                     
                                                                                                                 
                                                                     
                                                                      
#define NOMINMAX
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <ffx_api/ffx_api.h>
#include <ffx_api/ffx_framegeneration.h>
#include <ffx_api/dx12/ffx_api_dx12.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <map>
#include <sstream>
#include <string>
#include <vector>
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "dxgi.lib")

#define HR(x) do { HRESULT h_ = (x); if (FAILED(h_)) { printf("HR 0x%08lx line %d (%s)\n", (unsigned long) h_, __LINE__, #x); exit(2); } } while (0)

struct NfruMfgDesc { ffxDispatchDescHeader header; uint32_t index, count; };
struct NfruHudDesc { ffxDispatchDescHeader header; FfxApiResource fullColor; };

struct FrameMeta
{
    uint32_t dw = 0, dh = 0, rw = 0, rh = 0, mw = 0, mh = 0, depthInv = 0, hdr = 0, mfgCount = 1, reset = 0;
    int hudSplit = 0;
    float mvsx = 1, mvsy = 1, jx = 0, jy = 0, dt = 16.6f, nearZ = 0, farZ = 0, fov = 1;
    float vp[16] = {};
};
struct FileInfo { uint32_t w = 0, h = 0; int fmt = 0; uint64_t rowBytes = 0; };

static ID3D12Device* g_dev;

static ID3D12Resource* makeTex(uint32_t w, uint32_t h, DXGI_FORMAT fmt, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES st)
{
    D3D12_HEAP_PROPERTIES hp = {}; hp.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC rd = {}; rd.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D; rd.Width = w; rd.Height = h;
    rd.DepthOrArraySize = 1; rd.MipLevels = 1; rd.Format = fmt; rd.SampleDesc.Count = 1; rd.Flags = flags;
    ID3D12Resource* r = nullptr; HR(g_dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, st, nullptr, IID_PPV_ARGS(&r))); return r;
}
static ID3D12Resource* makeBuf(uint64_t n, D3D12_HEAP_TYPE t, D3D12_RESOURCE_STATES st)
{
    D3D12_HEAP_PROPERTIES hp = {}; hp.Type = t;
    D3D12_RESOURCE_DESC rd = {}; rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; rd.Width = n; rd.Height = 1; rd.DepthOrArraySize = 1;
    rd.MipLevels = 1; rd.SampleDesc.Count = 1; rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    ID3D12Resource* r = nullptr; HR(g_dev->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd, st, nullptr, IID_PPV_ARGS(&r))); return r;
}
static void barrier(ID3D12GraphicsCommandList* cl, ID3D12Resource* r, D3D12_RESOURCE_STATES a, D3D12_RESOURCE_STATES b)
{
    if (a == b) return;
    D3D12_RESOURCE_BARRIER rb = {}; rb.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION; rb.Transition.pResource = r;
    rb.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES; rb.Transition.StateBefore = a; rb.Transition.StateAfter = b;
    cl->ResourceBarrier(1, &rb);
}
static FfxApiResource apiRes(ID3D12Resource* r, uint32_t fmt, uint32_t w, uint32_t h, uint32_t usage, uint32_t state)
{
    FfxApiResource res = {}; res.resource = r; res.description.type = FFX_API_RESOURCE_TYPE_TEXTURE2D; res.description.format = fmt;
    res.description.width = w; res.description.height = h; res.description.depth = 1; res.description.mipCount = 1;
    res.description.usage = usage; res.state = state; return res;
}
static std::vector<uint8_t> readFile(const std::string& p)
{
    std::vector<uint8_t> d; FILE* f = fopen(p.c_str(), "rb"); if (!f) return d;
    fseek(f, 0, SEEK_END); d.resize(ftell(f)); fseek(f, 0, SEEK_SET); fread(d.data(), 1, d.size(), f); fclose(f); return d;
}
                                                                                                         
static void writePPM10(const std::string& path, const uint8_t* data, uint32_t w, uint32_t h, uint32_t pitch)
{
    FILE* f = fopen(path.c_str(), "wb"); fprintf(f, "P6\n%u %u\n255\n", w, h);
    std::vector<uint8_t> row(w * 3);
    for (uint32_t y = 0; y < h; ++y)
    {
        const uint32_t* s = (const uint32_t*) (data + (size_t) y * pitch);
        for (uint32_t x = 0; x < w; ++x) for (int c = 0; c < 3; ++c) row[x * 3 + c] = (uint8_t) ((((s[x] >> (10 * c)) & 1023u) * 255 + 511) / 1023);
        fwrite(row.data(), 1, row.size(), f);
    }
    fclose(f);
}

int main(int argc, char** argv)
{
    setvbuf(stdout, nullptr, _IONBF, 0);
    if (argc < 3) { printf("usage: nfru_replay_dx12 <capture dir> <out prefix> [first] [count]\n"); return 1; }
    const std::string dir = argv[1], prefix = argv[2];

                    
    std::map<int, FrameMeta> metas; std::map<std::string, FileInfo> files;
    {
                                                                                                                   
        const std::string metaName = getenv("REPLAY_META") ? getenv("REPLAY_META") : "meta.txt";
        FILE* f = fopen((dir + "\\" + metaName).c_str(), "rt"); if (!f) { printf("no %s\n", metaName.c_str()); return 1; }
        char line[2048];
        while (fgets(line, sizeof line, f))
        {
            std::istringstream ss(line); std::string tag; ss >> tag;
            if (tag == "frame")
            {
                int idx; std::string kind; ss >> idx >> kind; FrameMeta& m = metas[idx];
                if (kind == "viewProjection") { for (float& v : m.vp) ss >> v; continue; }
                sscanf(line, "frame %*d display %ux%u render %ux%u mv %ux%u mvScale %f %f jitter %f %f dt %f near %f far %f fov %f depthInv %u hdr %u hudSplit %d mfgCount %u reset %u",
                       &m.dw, &m.dh, &m.rw, &m.rh, &m.mw, &m.mh, &m.mvsx, &m.mvsy, &m.jx, &m.jy, &m.dt, &m.nearZ, &m.farZ, &m.fov, &m.depthInv, &m.hdr,
                       &m.hudSplit, &m.mfgCount, &m.reset);
            }
            else if (tag == "file")
            {
                std::string name, fmtTag, rbTag; FileInfo fi; ss >> name >> fi.w >> fi.h >> fmtTag >> fi.fmt >> rbTag >> fi.rowBytes; files[name] = fi;
            }
        }
        fclose(f);
    }
    if (metas.empty()) { printf("no frames\n"); return 1; }
    const int first = argc > 3 ? atoi(argv[3]) : 0;
    const int count = argc > 4 ? atoi(argv[4]) : (int) metas.size();
    const FrameMeta& m0 = metas.begin()->second;
    const FileInfo depthInfo = files["000_depth"], mvInfo = files["000_mv"], colInfo = files["000_hudless"];
    printf("capture: display %ux%u render %ux%u depth tex %ux%u mv %ux%u colour fmt %d, %zu frames, mfgCount %u\n", m0.dw, m0.dh, m0.rw, m0.rh,
           depthInfo.w, depthInfo.h, mvInfo.w, mvInfo.h, colInfo.fmt, metas.size(), m0.mfgCount);

                                                                                 
    IDXGIFactory6* factory = nullptr; HR(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory)));
    IDXGIAdapter1* adapter = nullptr; HR(factory->EnumAdapterByGpuPreference(0, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, IID_PPV_ARGS(&adapter)));
    HR(D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&g_dev)));
    ID3D12CommandQueue* q; D3D12_COMMAND_QUEUE_DESC qd = {}; qd.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE; HR(g_dev->CreateCommandQueue(&qd, IID_PPV_ARGS(&q)));
    ID3D12CommandAllocator* al; HR(g_dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE, IID_PPV_ARGS(&al)));
    ID3D12GraphicsCommandList* cl; HR(g_dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_COMPUTE, al, nullptr, IID_PPV_ARGS(&cl)));
    ID3D12Fence* fence; HR(g_dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
    HANDLE ev = CreateEventA(nullptr, FALSE, FALSE, nullptr); uint64_t fv = 0;
    auto submit = [&]() { HR(cl->Close()); ID3D12CommandList* l[] = { cl }; q->ExecuteCommandLists(1, l); HR(q->Signal(fence, ++fv));
                          HR(fence->SetEventOnCompletion(fv, ev)); WaitForSingleObject(ev, INFINITE); HR(g_dev->GetDeviceRemovedReason());
                          HR(al->Reset()); HR(cl->Reset(al, nullptr)); };

    HMODULE ngsdk = LoadLibraryA("ngsdk_dx12_windows_x64.dll"); if (!ngsdk) { printf("no ngsdk_dx12\n"); return 1; }
    auto pCreate = (PfnFfxCreateContext) GetProcAddress(ngsdk, "ffxCreateContext");
    auto pConfigure = (PfnFfxConfigure) GetProcAddress(ngsdk, "ffxConfigure");
    auto pDispatch = (PfnFfxDispatch) GetProcAddress(ngsdk, "ffxDispatch");

                                                                                            
    ffxCreateBackendDX12Desc backend = {}; backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12; backend.device = g_dev;
    ffxApiCreateContextDescFrameGeneration cd = {}; cd.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION; cd.header.pNext = &backend.header;
    cd.flags = FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_COLOR | FFX_API_FG_CONTEXT_FLAG_MANAGE_PREVIOUS_DEPTH;
    if (m0.depthInv) cd.flags |= FFX_API_FG_CONTEXT_FLAG_ENABLE_DEPTH_INVERTED;
    if (m0.hdr) cd.flags |= FFX_API_FG_CONTEXT_FLAG_ENABLE_HIGH_DYNAMIC_RANGE;
    cd.displaySize = { m0.dw, m0.dh }; cd.renderSize = { m0.rw, m0.rh };
    const uint32_t colApi = FFX_API_SURFACE_FORMAT_R10G10B10A2_UNORM;
    cd.backBufferFormat = colApi;
    cd.fpMessage = [](uint32_t t, const char* msg) { printf("[FG msg %u] %s\n", t, msg); };
    for (int i = 0; i < 4; ++i) cd.initialViewProjection[i * 5] = 1.0f;
    ffxContext ctx = nullptr;
    printf("create -> %u\n", (unsigned) pCreate(&ctx, &cd.header, nullptr));
    ffxApiConfigureDescFrameGeneration cfg = {}; cfg.header.type = FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION;
    cfg.flags = FFX_API_FG_DISPATCH_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY; cfg.frameGenerationEnabled = true;
    pConfigure(&ctx, &cfg.header);

    const D3D12_RESOURCE_STATES copyDest = D3D12_RESOURCE_STATE_COPY_DEST, srv = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
    ID3D12Resource* depth = makeTex(depthInfo.w, depthInfo.h, DXGI_FORMAT_R32_FLOAT, D3D12_RESOURCE_FLAG_NONE, copyDest);
    ID3D12Resource* mv = makeTex(mvInfo.w, mvInfo.h, DXGI_FORMAT_R16G16_FLOAT, D3D12_RESOURCE_FLAG_NONE, copyDest);
    ID3D12Resource* hudless = makeTex(colInfo.w, colInfo.h, DXGI_FORMAT_R10G10B10A2_UNORM, D3D12_RESOURCE_FLAG_NONE, copyDest);
    ID3D12Resource* back = makeTex(colInfo.w, colInfo.h, DXGI_FORMAT_R10G10B10A2_UNORM, D3D12_RESOURCE_FLAG_NONE, srv);
    ID3D12Resource* out = makeTex(colInfo.w, colInfo.h, DXGI_FORMAT_R10G10B10A2_UNORM, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
    auto pitchOf = [](uint64_t rb) { return (uint32_t) ((rb + 255) & ~255ull); };
    const uint32_t dp = pitchOf(depthInfo.rowBytes), mp = pitchOf(mvInfo.rowBytes), cp = pitchOf(colInfo.rowBytes);
    ID3D12Resource* upD = makeBuf((uint64_t) dp * depthInfo.h, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* upM = makeBuf((uint64_t) mp * mvInfo.h, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* upH = makeBuf((uint64_t) cp * colInfo.h, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* upB = makeBuf((uint64_t) cp * colInfo.h, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
    ID3D12Resource* rb = makeBuf((uint64_t) cp * colInfo.h, D3D12_HEAP_TYPE_READBACK, copyDest);

    auto upload = [&](ID3D12Resource* up, uint32_t pitch, const FileInfo& fi, const std::string& name) {
        std::vector<uint8_t> d = readFile(dir + "\\" + name + ".bin");
        if (d.size() < fi.rowBytes * fi.h) { printf("missing %s\n", name.c_str()); return false; }
        uint8_t* p; up->Map(0, nullptr, (void**) &p);
        for (uint32_t y = 0; y < fi.h; ++y) memcpy(p + (size_t) y * pitch, d.data() + (size_t) y * fi.rowBytes, (size_t) fi.rowBytes);
        up->Unmap(0, nullptr); return true; };
    auto copyIn = [&](ID3D12Resource* up, ID3D12Resource* tex, DXGI_FORMAT fmt, const FileInfo& fi, uint32_t pitch) {
        D3D12_TEXTURE_COPY_LOCATION s = {}, d = {}; s.pResource = up; s.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
        s.PlacedFootprint.Footprint = { fmt, fi.w, fi.h, 1, pitch }; d.pResource = tex; d.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
        cl->CopyTextureRegion(&d, 0, 0, 0, &s, nullptr); };

                                                                                                                             
                                                                                                                        
    const bool skip = getenv("REPLAY_SKIP") && atoi(getenv("REPLAY_SKIP")) != 0;
    auto uploadMv2 = [&](int f) {
        char a[16], b[16]; snprintf(a, sizeof a, "%03d_mv", f); snprintf(b, sizeof b, "%03d_mv", f - 1);
        std::vector<uint8_t> da = readFile(dir + "\\" + a + ".bin"), db = readFile(dir + "\\" + b + ".bin");
        const uint32_t w = mvInfo.w, h = mvInfo.h;
        if (da.size() < (size_t) w * h * 4 || db.size() < (size_t) w * h * 4) return false;
        auto h2f = [](uint16_t x) { uint32_t s = (x & 0x8000u) << 16, e = (x >> 10) & 31u, mm = x & 1023u, r;
            if (e == 0) { if (!mm) r = s; else { e = 127 - 15 + 1; while (!(mm & 1024u)) { mm <<= 1; --e; } mm &= 1023u; r = s | (e << 23) | (mm << 13); } }
            else if (e == 31) r = s | 0x7f800000u | (mm << 13); else r = s | ((e + 112) << 23) | (mm << 13);
            float o; memcpy(&o, &r, 4); return o; };
        auto f2h = [](float v) { uint32_t x; memcpy(&x, &v, 4); uint32_t s = (x >> 16) & 0x8000u; int e = int((x >> 23) & 255u) - 112; uint32_t mm = x & 0x7fffffu;
            if (e <= 0) return (uint16_t) s; if (e >= 31) return (uint16_t) (s | 0x7c00u); return (uint16_t) (s | (e << 10) | ((mm + 0x1000u) >> 13)); };
        const uint16_t* A = (const uint16_t*) da.data(); const uint16_t* B = (const uint16_t*) db.data();
        uint8_t* p; upM->Map(0, nullptr, (void**) &p);
        for (uint32_t y = 0; y < h; ++y)
        {
            uint16_t* row = (uint16_t*) (p + (size_t) y * mp);
            for (uint32_t x = 0; x < w; ++x)
            {
                const float mx = h2f(A[(y * w + x) * 2]), my = h2f(A[(y * w + x) * 2 + 1]);
                                                                                                                         
                const float px = std::min(std::max(x + 0.5f + mx - 0.5f, 0.0f), float(w - 1)), py = std::min(std::max(y + 0.5f + my - 0.5f, 0.0f), float(h - 1));
                const int x0 = (int) px, y0 = (int) py, x1 = std::min(x0 + 1, (int) w - 1), y1 = std::min(y0 + 1, (int) h - 1);
                const float fx = px - x0, fy = py - y0;
                float o[2];
                for (int c = 0; c < 2; ++c)
                    o[c] = (h2f(B[(y0 * w + x0) * 2 + c]) * (1 - fx) + h2f(B[(y0 * w + x1) * 2 + c]) * fx) * (1 - fy) +
                           (h2f(B[(y1 * w + x0) * 2 + c]) * (1 - fx) + h2f(B[(y1 * w + x1) * 2 + c]) * fx) * fy;
                row[x * 2] = f2h(mx + o[0]); row[x * 2 + 1] = f2h(my + o[1]);
            }
        }
        upM->Unmap(0, nullptr); return true; };

    for (int fi = first; fi < first + count && metas.count(fi); fi += skip ? 2 : 1)
    {
        FrameMeta m = metas[fi];
        if (skip) { m.mfgCount = 1; m.dt *= 2.0f; }
        char base[16]; snprintf(base, sizeof base, "%03d_", fi);
        if (!upload(upD, dp, depthInfo, base + std::string("depth")) ||
            !(skip && fi > first ? uploadMv2(fi) : upload(upM, mp, mvInfo, base + std::string("mv"))) ||
            !upload(upH, cp, colInfo, base + std::string("hudless")) || !upload(upB, cp, colInfo, base + std::string("backbuffer"))) break;
        copyIn(upD, depth, DXGI_FORMAT_R32_FLOAT, depthInfo, dp);
        copyIn(upM, mv, DXGI_FORMAT_R16G16_FLOAT, mvInfo, mp);
        copyIn(upH, hudless, DXGI_FORMAT_R10G10B10A2_UNORM, colInfo, cp);
        barrier(cl, back, srv, copyDest); copyIn(upB, back, DXGI_FORMAT_R10G10B10A2_UNORM, colInfo, cp); barrier(cl, back, copyDest, srv);

                                                                                                                     
        const uint64_t frameId = (uint64_t) ((fi - first) / (skip ? 2 : 1) + 1);
        for (uint32_t idx = 1; idx <= m.mfgCount; ++idx)
        {
                                                                                 
            ffxApiDispatchDescFrameGenerationPrepare prep = {}; prep.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION_PREPARE;
            prep.frameID = frameId; prep.commandList = cl; prep.jitterOffset = { m.jx, m.jy }; prep.motionVectorScale = { m.mvsx, m.mvsy };
            prep.frameTimeDelta = m.dt; prep.cameraNear = m.nearZ; prep.cameraFar = m.farZ; prep.cameraFovAngleVertical = m.fov;
            prep.viewSpaceToMetersFactor = 1.0f;
            prep.depth = apiRes(depth, FFX_API_SURFACE_FORMAT_R32_FLOAT, depthInfo.w, depthInfo.h, FFX_API_RESOURCE_USAGE_DEPTHTARGET, FFX_API_RESOURCE_STATE_COPY_DEST);
            prep.motionVectors = apiRes(mv, FFX_API_SURFACE_FORMAT_R16G16_FLOAT, mvInfo.w, mvInfo.h, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COPY_DEST);
            memcpy(prep.viewProjection, m.vp, sizeof m.vp);
            ffxReturnCode_t rc = pDispatch(&ctx, &prep.header);
            if (rc) printf("frame %d.%u prepare -> %u\n", fi, idx, (unsigned) rc);

            ffxApiDispatchDescFrameGeneration disp = {}; disp.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION; disp.commandList = cl;
            disp.presentColor = m.hudSplit ? apiRes(hudless, colApi, colInfo.w, colInfo.h, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COPY_DEST)
                                           : apiRes(back, colApi, colInfo.w, colInfo.h, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COMPUTE_READ);
            disp.outputs[0] = apiRes(out, colApi, colInfo.w, colInfo.h, FFX_API_RESOURCE_USAGE_UAV, FFX_API_RESOURCE_STATE_UNORDERED_ACCESS);
            disp.numGeneratedFrames = 1; disp.reset = fi == first; disp.frameID = frameId;
            NfruMfgDesc mfgD = {}; NfruHudDesc hudD = {};
            if (m.mfgCount > 1) { mfgD.header.type = 0x4E46525500000001ull; mfgD.index = idx; mfgD.count = m.mfgCount; disp.header.pNext = &mfgD.header; }
            if (m.hudSplit)
            {
                hudD.header.type = 0x4E46525500000002ull; hudD.header.pNext = disp.header.pNext;
                hudD.fullColor = apiRes(back, colApi, colInfo.w, colInfo.h, FFX_API_RESOURCE_USAGE_READ_ONLY, FFX_API_RESOURCE_STATE_COMPUTE_READ);
                disp.header.pNext = &hudD.header;
            }
            rc = pDispatch(&ctx, &disp.header);
            if (rc) printf("frame %d.%u dispatch -> %u\n", fi, idx, (unsigned) rc);

            barrier(cl, out, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);
            D3D12_TEXTURE_COPY_LOCATION s = {}, d = {}; s.pResource = out; s.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
            d.pResource = rb; d.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT; d.PlacedFootprint.Footprint = { DXGI_FORMAT_R10G10B10A2_UNORM, colInfo.w, colInfo.h, 1, cp };
            cl->CopyTextureRegion(&d, 0, 0, 0, &s, nullptr);
            barrier(cl, out, D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
            submit();
            uint8_t* p; rb->Map(0, nullptr, (void**) &p);
            char name[64]; snprintf(name, sizeof name, "_%03d_%u.ppm", fi, idx);
            writePPM10(prefix + name, p, colInfo.w, colInfo.h, cp);
            D3D12_RANGE none = { 0, 0 }; rb->Unmap(0, &none);
        }
        printf("frame %d done\n", fi);
    }
    return 0;
}
