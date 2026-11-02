                                                                           
                                                               
                                                                                
                                                                                    
                                                              
                                                                         

#pragma once
#include <cstdint>
#include <cstdio>
#include <cstddef>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <algorithm>

#include "mlof2_kernel_table.h"                                                         
#ifndef MLOF2_CONTRACT
#include "generated_cut3_v2_int8/mlof2_graph_types.h"
#endif

                                                                      
#define MLOF2_FC_WORDS 72u
                                                                                                                      
                                                                                                         
inline bool& mlof2_ext_of_ops() { static bool v = false; return v; }

                                                       
#define MLOF2_FC_T 0
#define MLOF2_FC_HAS_PREV 1
#define MLOF2_FC_PAIR_FIRST 2
#define MLOF2_FC_VP_A 4
#define MLOF2_FC_VP_B 20
#define MLOF2_FC_INV_VP_A 36
#define MLOF2_FC_TRAIL_HOMOG_AUTO 3
#define MLOF2_FC_FORCE_HOMOG 52
#define FC_OFG_DEBUG 52

#define FC_EXT_IN 53
#define FC_EXT_SNAP_W 54
#define FC_EXT_DISP_W 55
#define FC_EXT_DISP_H 56
#define FC_EXT_MV_W 57
#define FC_EXT_MV_H 58
#define FC_EXT_DEP_W 59
#define FC_EXT_DEP_H 60
#define FC_EXT_REVZ 61
#define FC_EXT_MVAP 62
#define FC_EXT_MVAP_OFF 63
#define FC_EXT_MV_SX 64
#define FC_EXT_MV_SY 65
#define FC_EXT_OF 66
#define FC_EXT_OUT 67
#define FC_EXT_HUD 68

struct Mlof2Dispatch {
    uint32_t op;
    uint32_t gx, gy;
    uint32_t kernel;                                                                                                        
                                       
    bool barrier_before = true;
    uint32_t fmts = 0xFFFFFFFFu;                                                                                           
                                                                                                                        
    int32_t ip01[2] = {0x7FFFFFFF, 0x7FFFFFFF};                                                                           
    bool wk = false;                                                                                                      
    uint32_t wsc[28] = {};
    uint32_t coop_rt = 1, coop_sw = 8, coop_fuse = 0, coop_pf = 24;                                                                        
                                                                                                                            
};

                                                                                                                    
                                                                                                                      
                                                                                                                      
                                                               
struct Mlof2Blk { bool on = false; uint32_t cb = 0, wp = 0, hp = 0, p = 0; uint64_t bytes = 0; };

struct Mlof2Plan {
    uint32_t tb, sb, ob, fc;
    std::vector<uint32_t> meta;
    std::vector<uint32_t> tensor_base;                         
    std::vector<Mlof2Dispatch> dispatches;
    uint64_t arena_bytes;
    uint64_t blk_lo = 0, blk_hi = 0;                                                                              
    std::vector<Mlof2Blk> blk;                      
    int H, W;
};

inline uint32_t mlof2_f2u(float f) { uint32_t u; memcpy(&u, &f, 4); return u; }

                                                                                                               
                                                                                                                    
                                                                                                                
inline void mlof2_convw_weights(const Mlof2Graph& g, Mlof2Plan& p, std::vector<uint8_t>& blob) {
    for (const Mlof2Dispatch& d : p.dispatches) {
        if (!d.wk) continue;
        const Mlof2Op& o = g.ops[d.op];
        const uint32_t kt = uint32_t(o.ip[0] * o.ip[1]), icw = d.wsc[4], oc = d.wsc[5], nbw = d.wsc[7];
        const uint32_t icw0 = o.kw_words / kt;                                                                       
        const uint32_t nk = (icw + 3u) / 4u, nob = (oc + 16u * nbw - 1u) / (16u * nbw) * nbw;
                                                                                                                       
        uint32_t ks_[6], bs_[6];
        for (int si = 0; si < o.nseg; ++si) {
            ks_[si] = si == 0 ? 0u : d.wsc[9 + si];
            bs_[si] = si == 0 ? 0u : bs_[si - 1] + (uint32_t(g.segs[o.seg0 + si - 1].c) + 3u) / 4u;
        }
        ks_[o.nseg] = icw; bs_[o.nseg] = icw0;
        auto src = [&](uint32_t w) -> int {
            int si = 0;
            while (si + 1 < o.nseg && w >= ks_[si + 1]) ++si;
            const uint32_t lw = w - ks_[si];
            return lw < bs_[si + 1] - bs_[si] ? int(bs_[si] + lw) : -1;
        };
        const size_t base = blob.size();
        blob.resize(base + size_t(nob) * kt * nk * 256u, 0);
        for (uint32_t ob = 0; ob < nob; ++ob)
            for (uint32_t tap = 0; tap < kt; ++tap)
                for (uint32_t kk = 0; kk < nk; ++kk) {
                    uint8_t* f = &blob[base + ((size_t(ob) * kt + tap) * nk + kk) * 256u];
                    for (uint32_t n = 0; n < 16u; ++n) {
                        const uint32_t oc_ = ob * 16u + n;
                        if (oc_ >= oc) continue;
                        for (uint32_t k = 0; k < 16u; ++k) {
                            const uint32_t w = kk * 4u + k / 4u;
                            const int sw_ = w < icw ? src(w) : -1;
                            if (sw_ >= 0) f[n * 16u + k] = blob[(size_t(o.w_off) + size_t(oc_) * o.kw_words + tap * icw0 + uint32_t(sw_)) * 4u + k % 4u];
                        }
                    }
                }
        p.meta[p.ob + 24u * d.op + 18u] = uint32_t(base / 4u);
    }
}

                                      
inline void mlof2_tensor_range(const Mlof2Graph& g, const Mlof2Plan& p, int H, int W, int t, uint64_t& b, uint64_t& e) {
    const Mlof2Tensor& d = g.tensors[t];
    const uint64_t esz = d.fmt == 0 ? 4 : (d.fmt == 1 ? 2 : 1);
    b = p.tensor_base[t];
    e = b + (t < int(p.blk.size()) && p.blk[t].on ? p.blk[t].bytes : uint64_t(d.n) * uint64_t(H / d.s) * uint64_t(W / d.s) * uint64_t(d.c_alloc) * esz);
}

                                                                                                             
inline void mlof2_blk_to_nhwc(const Mlof2Graph& g, const Mlof2Plan& p, int t, const uint8_t* src, std::vector<uint8_t>& out) {
    const Mlof2Tensor& d = g.tensors[t];
    const Mlof2Blk& b = p.blk[t];
    const uint32_t h = uint32_t(p.H / d.s), w = uint32_t(p.W / d.s);
    out.assign(size_t(d.n) * h * w * d.c_alloc, 0);
    for (uint32_t n = 0; n < uint32_t(d.n); ++n)
        for (uint32_t y = 0; y < h; ++y)
            for (uint32_t x = 0; x < w; ++x)
                for (uint32_t c = 0; c < uint32_t(d.c); ++c)
                    out[((size_t(n) * h + y) * w + x) * d.c_alloc + c] =
                        src[((((size_t(n) * b.cb + c / 16u) * b.hp + y + b.p) * b.wp + x + b.p) * 16u) + c % 16u];
}

                                                                                                                       
                                                                                                                 
template <class On>
inline bool mlof2_blk_conv_ok(const Mlof2Graph& g, const Mlof2Op& o, On on) {
    if (o.kind != MLOF2_K_CONV || o.ip[0] != o.ip[1] || o.ip[0] % 2 == 0 || o.ip[2] != 1 || o.ip[3] != o.ip[0] / 2 * o.ip[4]) return false;
    if (o.nseg > 4 || !on(o.out)) return false;
    for (int si = 0; si < o.nseg; ++si) {
        const Mlof2Seg& sg = g.segs[o.seg0 + si];
        if (!on(sg.tensor) || sg.c_off != 0 || sg.c != g.tensors[sg.tensor].c || sg.swap != 0) return false;
    }
    return o.ip[6] < 0 || (on(o.ip[6]) && (o.ip[7] == 0 || o.ip[7] == -1));
}

                                                                                                                     
                                                                                                                  
                                                                                                                      
                                                                                                                     
                                                                                                
inline void mlof2_choose_blocked(const Mlof2Graph& g, int H, int W, std::vector<Mlof2Blk>& blk) {
    blk.assign(g.num_tensors, Mlof2Blk{});
    if (getenv("MLOF2_BLK") && strcmp(getenv("MLOF2_BLK"), "0") == 0) return;
    std::vector<int> writer(g.num_tensors, -1), nwriters(g.num_tensors, 0);
    for (int i = 0; i < g.num_ops; ++i) { writer[g.ops[i].out] = i; ++nwriters[g.ops[i].out]; }
    std::vector<char> io(g.num_tensors, 0);
    for (int i = 0; i < g.num_inputs + g.num_outputs; ++i) io[g.io[i]] = 1;
    std::vector<char> on(g.num_tensors, 0);
    for (int t = 0; t < g.num_tensors; ++t) {
        const Mlof2Tensor& d = g.tensors[t];
                                                                                                                  
        const int minc = getenv("MLOF2_BLK_MINC") ? atoi(getenv("MLOF2_BLK_MINC")) : 32;
        const int minpx = getenv("MLOF2_BLK_MINPX") ? atoi(getenv("MLOF2_BLK_MINPX")) : 256;
        if (d.fmt != 2 || d.c % 16 != 0 || d.c < minc || (H / d.s) * (W / d.s) < minpx || io[t] || nwriters[t] != 1) continue;
        const Mlof2Op& wo = g.ops[writer[t]];
        if (wo.kind != MLOF2_K_CONV || wo.out_coff != 0 || wo.out_c != d.c) continue;
        on[t] = 1;
    }
    auto isOn = [&](int t) { return t >= 0 && on[t] != 0; };
    for (bool changed = true; changed;) {
        changed = false;
        for (int t = 0; t < g.num_tensors; ++t) {
            if (!on[t]) continue;
            const Mlof2Op& wo = g.ops[writer[t]];
            const bool wblk = mlof2_blk_conv_ok(g, wo, isOn);
            bool ok = wblk || wo.ip[6] < 0, gain = wblk;                                                     
            for (int i = 0; i < g.num_ops && ok; ++i) {
                const Mlof2Op& o = g.ops[i];
                bool reads = false;
                for (int si = 0; si < o.nseg; ++si) {
                    const Mlof2Seg& sg = g.segs[o.seg0 + si];
                    if (sg.tensor != t) continue;
                    reads = true;
                    if (sg.c_off != 0 || sg.c != g.tensors[t].c || sg.swap != 0) ok = false;
                }
                const bool res = o.kind == MLOF2_K_CONV && o.ip[6] == t;
                if (!reads && !res) continue;
                if (o.kind != MLOF2_K_CONV) { ok = false; break; }
                const bool rblk = mlof2_blk_conv_ok(g, o, isOn);
                gain |= rblk;
                if (res && !rblk) ok = false;                                                               
            }
            if (!ok || !gain) { on[t] = 0; changed = true; }
        }
    }
    uint32_t P = 2u;
    for (int i = 0; i < g.num_ops; ++i)
        if (g.ops[i].kind == MLOF2_K_CONV) P = std::max(P, uint32_t(g.ops[i].ip[0] / 2 * g.ops[i].ip[4]));
    for (int t = 0; t < g.num_tensors; ++t) {
        if (!on[t]) continue;
        const Mlof2Tensor& d = g.tensors[t];
        Mlof2Blk& b = blk[t];
        b.on = true; b.p = P; b.cb = uint32_t(d.c) / 16u;
        b.wp = (uint32_t(W / d.s) + 15u) / 16u * 16u + 2u * b.p;
        b.hp = (uint32_t(H / d.s) + 7u) / 8u * 8u + 2u * b.p;
        b.bytes = uint64_t(d.n) * b.cb * b.hp * b.wp * 16u;
    }
}
                                                                                        
inline bool mlof2_out_overlaps_inputs(const Mlof2Graph& g, const Mlof2Plan& p, int H, int W, int t, const Mlof2Op& o) {
    uint64_t b, e; mlof2_tensor_range(g, p, H, W, t, b, e);
    for (int si = -1; si < o.nseg; ++si) {
        const int ti = si < 0 ? o.out : g.segs[o.seg0 + si].tensor;
        uint64_t b2, e2; mlof2_tensor_range(g, p, H, W, ti, b2, e2);
        if (b < e2 && b2 < e) return true;
    }
    if (o.ip[6] >= 0) { uint64_t b2, e2; mlof2_tensor_range(g, p, H, W, o.ip[6], b2, e2); if (b < e2 && b2 < e) return true; }              
    return false;
}

                                                                           
inline uint32_t mlof2_coop_region(const Mlof2Op& o, uint32_t rt) {
    return uint32_t((int(4 * rt - 1) * o.ip[2] + (o.ip[0] - 1) * o.ip[4] + 1) * (15 * o.ip[2] + (o.ip[1] - 1) * o.ip[4] + 1));
}

inline bool mlof2_plan(const Mlof2Graph& g, int H, int W, Mlof2Plan& p, bool use_coopmat = true) {
    if (H % 64 != 0 || W % 64 != 0) return false;
    p.H = H; p.W = W;
    const uint64_t unit = uint64_t(H) * W / 4096;
    
                                                    
    p.arena_bytes = uint64_t(g.arena_units) * 16ULL * unit;
    p.tb = 0;
    p.sb = p.tb + 8u * g.num_tensors;
    p.ob = p.sb + 4u * g.num_segs;
    p.fc = p.ob + 24u * g.num_ops;
    p.meta.assign(p.fc + MLOF2_FC_WORDS, 0u);
    p.tensor_base.resize(g.num_tensors);
                                                                                                                    
    if (use_coopmat && (!getenv("MLOF2_CONV_W") || strcmp(getenv("MLOF2_CONV_W"), "0") != 0)) mlof2_choose_blocked(g, H, W, p.blk);
    else p.blk.assign(g.num_tensors, Mlof2Blk{});
    p.blk_lo = p.blk_hi = (p.arena_bytes + 255u) / 256u * 256u;

    for (int t = 0; t < g.num_tensors; ++t) {
        const Mlof2Tensor& d = g.tensors[t];
        uint32_t* m = &p.meta[p.tb + 8u * t];
        p.tensor_base[t] = uint32_t(uint64_t(d.off_units) * 16ULL * unit);
        if (p.blk[t].on) { p.tensor_base[t] = uint32_t(p.blk_hi); p.blk_hi += (p.blk[t].bytes + 255u) / 256u * 256u; }                
        m[0] = p.tensor_base[t];                        
        m[1] = uint32_t(d.c);
        m[2] = uint32_t(W / d.s);
        m[3] = uint32_t(H / d.s);
        m[4] = uint32_t(d.n);
        m[5] = uint32_t(d.s);
        m[6] = (uint32_t(d.fmt) & 0xFFu) | ((uint32_t(d.c_alloc) & 0xFFFFu) << 8);
        m[7] = mlof2_f2u(d.scale);
    }

    for (int i = 0; i < g.num_segs; ++i) {
        uint32_t* m = &p.meta[p.sb + 4u * i];
        m[0] = uint32_t(g.segs[i].tensor);
        m[1] = uint32_t(g.segs[i].c_off);
        m[2] = uint32_t(g.segs[i].c);
        m[3] = uint32_t(g.segs[i].swap);
    }

    if (p.blk_hi > p.blk_lo) p.arena_bytes = p.blk_hi;
    p.dispatches.clear();
                                                                                                                         
                                                                                                               
    const bool convw_default = !getenv("MLOF2_CONV_W") || strcmp(getenv("MLOF2_CONV_W"), "0") != 0;
    const bool no_fuse = getenv("MLOF2_NO_FUSE") ? strcmp(getenv("MLOF2_NO_FUSE"), "0") != 0 : convw_default;
    int skip_op = -1;                                                                        
    struct Span { uint64_t lo, hi; };
    auto overlaps = [](const Span& a, const Span& b) { return a.lo < b.hi && b.lo < a.hi; };
    std::vector<Span> dirty_writes;
    std::vector<Span> active_reads;
    const bool fuse_unshuffle = false;                                                               
    for (int i = 0; i < g.num_ops; ++i) {
        if (fuse_unshuffle && i == 0) continue;                            
        const Mlof2Op& o = g.ops[i];
        uint32_t* m = &p.meta[p.ob + 24u * i];
        m[0] = uint32_t(o.kind);
        m[1] = uint32_t(o.out);
        m[2] = uint32_t(o.out_coff);
        m[3] = uint32_t(o.out_c);
        m[4] = uint32_t(o.seg0);
        m[5] = uint32_t(o.nseg);
        for (int k = 0; k < 8; ++k) m[6 + k] = uint32_t(o.ip[k]);
        for (int k = 0; k < 4; ++k) m[14 + k] = mlof2_f2u(o.fp[k]);
        m[18] = o.w_off;
        m[19] = o.kw_words;
        m[20] = o.scale_off;
        m[21] = o.bias_off;

        const Mlof2Tensor& t = g.tensors[o.out];
        const uint32_t pix = uint32_t(t.n) * uint32_t(H / t.s) * uint32_t(W / t.s);

        Mlof2Dispatch d;
        d.op = uint32_t(i);
        const bool blk_body = mlof2_blk_conv_ok(g, o, [&](int t_) { return t_ >= 0 && p.blk[t_].on; });
        if (blk_body) {
                                                                                                                      
                                                                                                        
            const Mlof2Blk& bo_ = p.blk[o.out];
            const uint32_t obt = uint32_t(o.out_c) / 16u;
            uint32_t tr = 1u, nb = obt <= 2u ? obt : (obt % 2u == 0u ? 2u : 1u);
            if (getenv("MLOF2_BLK_TILE")) {
                unsigned a_ = 2, b_ = 2; sscanf(getenv("MLOF2_BLK_TILE"), "%u,%u", &a_, &b_);
                tr = a_; nb = b_; while (obt % nb) --nb;
            }
            const uint32_t oh = uint32_t(H / t.s), ow = uint32_t(W / t.s);
            if (!getenv("MLOF2_BLK_TILE")) {                                                                                                 
                auto waves = [&](uint32_t r_, uint32_t b_) { return uint32_t(t.n) * (obt / b_) * ((ow + 15u) / 16u) * ((oh + r_ - 1u) / r_); };
                while (waves(tr, nb) < 1024u && (tr > 1u || nb > 1u)) { if (tr > 1u) tr /= 2u; else { --nb; while (obt % nb) --nb; } }
            }
            d.kernel = uint32_t(g_mlof2_kernel_conv_blk); d.wk = true;
            uint32_t segw[5] = {0u, 0xFFFFu, 0xFFFFu, 0xFFFFu, 0xFFFFu}, acc_w = 0u;                                 
            for (int si = 0; si < o.nseg; ++si) { segw[si] = acc_w; acc_w += uint32_t(g.segs[o.seg0 + si].c) / 4u; }
            const uint32_t v[20] = {uint32_t(o.ip[4]), bo_.p, tr, uint32_t(o.ip[5]), uint32_t(o.kw_words / uint32_t(o.ip[0] * o.ip[1])), uint32_t(o.out_c),
                                    bo_.wp, nb, bo_.hp, uint32_t(o.nseg), segw[1], segw[2], segw[3], segw[4], ow, oh, obt, uint32_t(t.n), 0u, 0u};
            memcpy(d.wsc, v, sizeof v);
            d.gx = uint32_t(t.n) * (obt / nb) * ((ow + 15u) / 16u) * ((oh + tr - 1u) / tr);
            d.gy = 1u;
            d.fmts = 0u;
            d.ip01[0] = o.ip[0]; d.ip01[1] = o.ip[1];
        } else if (o.kind == MLOF2_K_CONV) {
            if (fuse_unshuffle && i == 1) {
                d.kernel = 4u;                                            
                d.gx = (pix + 15u) / 16u;
                d.gy = (uint32_t(o.out_c) + 15u) / 16u;
            } else if (use_coopmat && mlof2_coop_region(o, 1) * (o.kw_words / uint32_t(o.ip[0] * o.ip[1]) <= 4 ? 4 : 8) <= 3072) {
                                                                                                                    
                                                                                                                    
                                                                                                            
                d.kernel = 3u;
                d.coop_sw = o.kw_words / uint32_t(o.ip[0] * o.ip[1]) <= 4 ? 4u : 8u;
                d.coop_rt = 1u;                                                                             
                for (uint32_t rt = 4u; rt > 1u; rt /= 2u)
                    if (uint32_t(o.out_c) <= 64u / rt && mlof2_coop_region(o, rt) * d.coop_sw <= 3072) { d.coop_rt = rt; break; }
                if (getenv("MLOF2_COOP_RT1")) d.coop_rt = 1u;        
                uint32_t nw_ = mlof2_coop_region(o, d.coop_rt) * d.coop_sw;
                d.coop_pf = (nw_ + 127u) / 128u;
                if (d.coop_pf < 4u) d.coop_pf = 4u;
                if (d.coop_pf > 24u) d.coop_pf = 24u;
                const uint32_t tr = 4u * d.coop_rt;
                d.gx = uint32_t(t.n) * ((uint32_t(W / t.s) + 15u) / 16u) * ((uint32_t(H / t.s) + tr - 1u) / tr);
                d.gy = (uint32_t(o.out_c) + 64u / d.coop_rt - 1u) / (64u / d.coop_rt);
                                                                                                                    
                                                                                                                    
                if (!no_fuse && i + 1 < g.num_ops && d.gy == 1u) {
                    const Mlof2Op& nx = g.ops[i + 1];
                    const Mlof2Tensor& tt = g.tensors[o.out];
                    const Mlof2Seg& ns = g.segs[nx.seg0];
                    const Mlof2Tensor& t2 = g.tensors[nx.out];
                    if (nx.kind == MLOF2_K_CONV && nx.ip[0] == 1 && nx.ip[1] == 1 && nx.ip[2] == 1 && nx.nseg == 1 && nx.ip[6] < 0 &&
                        ns.tensor == o.out && ns.c_off == 0 && ns.c == tt.c && ns.swap == 0 && tt.fmt == 2 && o.out_coff == 0 &&
                        o.out_c == tt.c && (t2.fmt == 1 || t2.fmt == 2) && t2.s == tt.s && t2.n == tt.n && nx.out_c <= 128 &&
                        !mlof2_out_overlaps_inputs(g, p, H, W, nx.out, o)) {                                          
                                                                                                                        
                                                                                                                 
                        d.coop_fuse = 1u;
                        skip_op = i + 1;
                    }
                }
                                                                                                                     
                const bool convw_on = !getenv("MLOF2_CONV_W") || strcmp(getenv("MLOF2_CONV_W"), "0") != 0;
                bool segs8 = o.nseg <= 5;
                for (int si = 0; si < o.nseg && segs8; ++si) segs8 = g.tensors[g.segs[o.seg0 + si].tensor].fmt == 2;
                if (convw_on && d.coop_fuse == 0u && segs8) {
                    const uint32_t kh = uint32_t(o.ip[0]), kw = uint32_t(o.ip[1]), st = uint32_t(o.ip[2]), dl = uint32_t(o.ip[4]);
                    const uint32_t swmax = getenv("MLOF2_CONV_W_SW") ? uint32_t(atoi(getenv("MLOF2_CONV_W_SW"))) : 8u;                                              
                    const uint32_t icw = o.kw_words / (kh * kw), sw = icw <= 4u ? 4u : swmax;
                    const uint32_t macc = getenv("MLOF2_CONV_W_ACC") ? uint32_t(atoi(getenv("MLOF2_CONV_W_ACC"))) : 2u;                                                                     
                                                                                                                          
                    const uint32_t nblk = (uint32_t(o.out_c) + 15u) / 16u;
                    uint32_t nbw = std::min(4u, nblk), trw = 1u;
                    while (nblk % nbw) --nbw;
                    while (trw * 2u * nbw <= macc) trw *= 2u;
                                                                                                     
                    if (getenv("MLOF2_CONV_W_TILE")) {
                        unsigned mr = 4, mb = 4; sscanf(getenv("MLOF2_CONV_W_TILE"), "%u,%u", &mr, &mb);
                        nbw = std::min(nbw, uint32_t(mb)); trw = std::min(trw, uint32_t(mr));
                        while (trw * nbw > macc && trw > 1u) trw /= 2u;
                    } else {
                                                                                                                     
                                                                                                                      
                        const uint32_t minw = getenv("MLOF2_CONV_W_MINW") ? uint32_t(atoi(getenv("MLOF2_CONV_W_MINW"))) : 1024u;
                        const uint32_t ohh = uint32_t(H / t.s), oww = uint32_t(W / t.s);
                        auto waves = [&](uint32_t r_, uint32_t b_) {
                            return uint32_t(t.n) * ((uint32_t(o.out_c) + 16u * b_ - 1u) / (16u * b_)) * ((oww + 15u) / 16u) * ((ohh + r_ - 1u) / r_);
                        };
                        while (waves(trw, nbw) < minw && (trw > 1u || nbw > 1u)) {
                            if (trw > 1u) trw /= 2u;
                            else { --nbw; while (nblk % nbw) --nbw; }
                        }
                    }
                    const uint32_t rh = (trw - 1u) * st + (kh - 1u) * dl + 1u, rw = 15u * st + (kw - 1u) * dl + 1u;
                    const uint32_t nw = rh * rw * sw;
                    const Mlof2Tensor& ti = g.tensors[g.segs[o.seg0].tensor];
                    if (nw <= 6144u) {
                        d.kernel = uint32_t(g_mlof2_kernel_conv_w); d.wk = true;
                        uint32_t segw[5] = {0u, 0xFFFFu, 0xFFFFu, 0xFFFFu, 0xFFFFu}, acc_w = 0u;
                        for (int si = 0; si < o.nseg; ++si) { segw[si] = acc_w; acc_w += (uint32_t(g.segs[o.seg0 + si].c) + 3u) / 4u; }
                        const uint32_t oh = uint32_t(H / t.s), ow = uint32_t(W / t.s);
                                                                                                                                   
                        bool vec = !getenv("MLOF2_CONV_W_VEC") || strcmp(getenv("MLOF2_CONV_W_VEC"), "0") != 0;
                        for (int si = 0; si < o.nseg && vec; ++si) {
                            const Mlof2Seg& sg = g.segs[o.seg0 + si];
                            vec = sg.c % 16 == 0 && sg.c_off % 16 == 0 && g.tensors[sg.tensor].c_alloc % 16 == 0;
                        }
                                                                                                                        
                                                                                                                        
                                                                             
                        uint32_t icw_k = icw;
                        if (!vec && (!getenv("MLOF2_CONV_W_VEC") || strcmp(getenv("MLOF2_CONV_W_VEC"), "0") != 0)) {
                            bool vp = true;
                            for (int si = 0; si < o.nseg && vp; ++si) {
                                const Mlof2Seg& sg = g.segs[o.seg0 + si];
                                vp = sg.c_off % 16 == 0 && g.tensors[sg.tensor].c_alloc % 16 == 0 && sg.c_off + sg.c <= g.tensors[sg.tensor].c_alloc;
                            }
                            if (vp) {
                                acc_w = 0u;
                                for (int si = 0; si < o.nseg; ++si) { segw[si] = acc_w; acc_w += (uint32_t(g.segs[o.seg0 + si].c) + 15u) / 16u * 4u; }
                                icw_k = acc_w;
                                vec = true;
                            }
                        }
                        const uint32_t v[20] = {st, uint32_t(o.ip[3]), dl, uint32_t(o.ip[5]), icw_k, uint32_t(o.out_c), trw, nbw, sw,
                                                uint32_t(o.nseg), segw[1], segw[2], segw[3], segw[4], uint32_t(H / ti.s), uint32_t(W / ti.s),
                                                oh, ow, std::max(nw, 256u), vec ? 1u : 0u};                                                      
                        memcpy(d.wsc, v, sizeof v);
                                                                                                           
                        for (int si = 0; si < o.nseg; ++si) {                                                                
                            const int tin = g.segs[o.seg0 + si].tensor;
                            if (!p.blk[tin].on) continue;
                            d.wsc[20] |= 1u << si; d.wsc[21] = p.blk[tin].wp; d.wsc[22] = p.blk[tin].hp; d.wsc[23] = p.blk[tin].p;
                        }
                        if (p.blk[o.out].on) { d.wsc[24] = 1u; d.wsc[25] = p.blk[o.out].wp; d.wsc[26] = p.blk[o.out].hp; d.wsc[27] = p.blk[o.out].p; }
                        const uint32_t ng = (uint32_t(o.out_c) + 16u * nbw - 1u) / (16u * nbw);
                        d.gx = uint32_t(t.n) * ng * ((ow + 15u) / 16u) * ((oh + trw - 1u) / trw);
                        d.gy = 1u;
                        d.fmts = 0u;
                        for (int si = 0; si < 6; ++si)
                            d.fmts |= uint32_t(si < o.nseg ? g.tensors[g.segs[o.seg0 + si].tensor].fmt & 0xF : 0xF) << (4 * si);
                        d.fmts |= uint32_t(o.ip[6] >= 0 ? (g.tensors[o.ip[6]].fmt & 0xF) : 0xF) << 24;
                        d.fmts |= uint32_t(t.fmt & 0xF) << 28;
                        d.ip01[0] = o.ip[0]; d.ip01[1] = o.ip[1];
                    }
                }
            } else {
                d.kernel = 0u;                                  
                d.gx = ((pix + 1u) / 2u + 63u) / 64u;
                d.gy = (uint32_t(o.out_c) + 15u) / 16u;
                                                                                                                        
                                                                                                                         
                {
                    static const uint32_t thr = getenv("MLOF2_DP4A_OCSPLIT") ? uint32_t(atoi(getenv("MLOF2_DP4A_OCSPLIT"))) : 2048u;
                    static const uint32_t thr_s = getenv("MLOF2_DP4A_OCSPLIT_SMALL") ? uint32_t(atoi(getenv("MLOF2_DP4A_OCSPLIT_SMALL"))) : 128u;
                    if (thr && o.out_c > 4 && o.out_coff % 4 == 0 &&
                        ((d.gx * d.gy < thr && o.ip[0] == 7 && o.ip[1] == 7 && o.ip[2] == 1) ||
                         (d.gx * d.gy <= thr_s && o.kw_words >= 32u)))
                        d.gy = (uint32_t(o.out_c) + 3u) / 4u;
                }
            }
        } else {
            d.kernel = o.kind < MLOF2_K_VIG_PART ? 1u : 2u;
            d.gx = (pix + 63u) / 64u;                                                       
            d.gy = 1u;
            if (o.kind == MLOF2_K_CORR) {
                d.gx = (pix * ((uint32_t(o.out_c) + 3u) / 4u) + 63u) / 64u;
                d.gy = 1u;
                m[6 + 1] = 0u;
                d.ip01[1] = 0;
                                                                                                          
                const Mlof2Seg& sq = g.segs[o.seg0];
                const Mlof2Seg& sr = g.segs[o.seg0 + 1];
                const Mlof2Tensor& tq = g.tensors[sq.tensor];
                const Mlof2Tensor& tr = g.tensors[sr.tensor];
                const bool tile_on = !getenv("MLOF2_CORR_TILE") || strcmp(getenv("MLOF2_CORR_TILE"), "0") != 0;
                if (tile_on && o.nseg == 2 && o.ip[0] <= 3 && tq.fmt == 2 && tr.fmt == 2 && t.fmt == 2 && sq.c == sr.c && sq.c % 32 == 0 &&
                    sq.c_off % 16 == 0 && sr.c_off % 16 == 0 && tq.c_alloc % 16 == 0 && tr.c_alloc % 16 == 0 && o.out_coff % 4 == 0 &&
                    o.out_c == (2 * o.ip[0] + 1) * (2 * o.ip[0] + 1) && (o.out_c % 4 == 0 || o.out_coff + o.out_c == t.c)) {
                    d.gx = (uint32_t(W / t.s) + 15u) / 16u;
                    d.gy = uint32_t(t.n) * ((uint32_t(H / t.s) + 3u) / 4u);
                    m[6 + 1] = 1u;
                    d.ip01[1] = 1;                                                              
                } else if (tile_on && o.nseg == 2 && o.ip[0] <= 8 && tq.fmt == 2 && tr.fmt == 2 && t.fmt == 2 && sq.c == sr.c && sq.c % 32 == 0 &&
                           sq.c_off % 16 == 0 && sr.c_off % 16 == 0 && tq.c_alloc % 16 == 0 && tr.c_alloc % 16 == 0 && o.out_coff == 0 &&
                           o.out_c == t.c && o.out_c == (2 * o.ip[0] + 1) * (2 * o.ip[0] + 1) && t.c_alloc % 4 == 0 &&
                           t.c_alloc - 4 * (2 * o.ip[0] + 1) * ((2 * o.ip[0] + 1 + 3) / 4 - 1) <= 4 * (2 * o.ip[0] + 1)) {
                                                                                       
                    const uint32_t diam = uint32_t(2 * o.ip[0] + 1);
                    d.gx = (uint32_t(W / t.s) + 15u) / 16u;
                    d.gy = uint32_t(t.n) * uint32_t(H / t.s) * ((diam + 3u) / 4u);
                    m[6 + 1] = 2u;
                    d.ip01[1] = 2;
                }
            }
            if ((o.kind == MLOF2_K_WARP || o.kind == MLOF2_K_RESIZE_BIL) && o.out_c > 16) d.gx = (pix * ((uint32_t(o.out_c) + 15u) / 16u) + 63u) / 64u;                         
            if (o.kind == MLOF2_K_COPY && o.nseg == 1) {                                                                   
                const Mlof2Seg& sa = g.segs[o.seg0];
                const Mlof2Tensor& ta = g.tensors[sa.tensor];
                if ((ta.fmt == 2 || ta.fmt == 1) && t.fmt == 2 && o.out_coff == 0 && o.out_c == t.c && t.c == t.c_alloc && sa.c_off == 0 &&
                    sa.c == o.out_c && o.out_c % 16 == 0 && ta.c_alloc % 16 == 0) {
                    d.gx = (pix * (uint32_t(o.out_c) / 16u) + 63u) / 64u;
                    m[6 + 1] = 1u;
                    d.ip01[1] = 1;
                }
            }
        }
        if (o.kind == MLOF2_K_CONV) {                                                                                
            bool touches = p.blk[o.out].on || (o.ip[6] >= 0 && p.blk[o.ip[6]].on);
            for (int si = 0; si < o.nseg; ++si) touches |= p.blk[g.segs[o.seg0 + si].tensor].on;
            const bool convw_ok = d.wk && d.kernel == uint32_t(g_mlof2_kernel_conv_w) && (d.wsc[20] == 0u || d.wsc[19] == 1u) &&
                                  (!p.blk[o.out].on || o.ip[6] < 0);                                                                
            if (touches && !(blk_body || convw_ok)) {
                fprintf(stderr, "mlof2_plan: op %d touches a blocked tensor but runs on kernel %u (set MLOF2_BLK=0)\n", i, d.kernel);
                return false;
            }
        }
        if (o.kind == MLOF2_K_VIG_PART || o.kind == MLOF2_K_HOMOG_ACC) d.gx = (uint32_t(H / 4) * uint32_t(W / 4) + 63u) / 64u;
        if (o.kind == MLOF2_K_VIG_SOLVE || o.kind == MLOF2_K_MEDIAN || o.kind == MLOF2_K_HOMOG_SOLVE) d.gx = 1u;
        if (o.kind == MLOF2_K_MEDIAN_PICK) d.gx = 1u;
        if (o.kind == MLOF2_K_FEAT4 || o.kind == MLOF2_K_FEAT4C || o.kind == MLOF2_K_Q_PREP) d.gx = (pix * 16u + 63u) / 64u;                               
        if (mlof2_ext_of_ops() && d.kernel == 1u &&
            ((o.kind == MLOF2_K_UNSHUFFLE && o.ip[0] == 4 && o.nseg == 2 && o.out_c == 64 && t.fmt == 2) ||
             (o.kind == MLOF2_K_RESIZE_AREA && o.out_c == 3 && t.s == 4 && g.tensors[g.segs[o.seg0].tensor].s == 1 &&
              g.tensors[g.segs[o.seg0].tensor].c == 3 && g.segs[o.seg0].c_off == 0)))
            d.gx = (pix * 16u + 63u) / 64u;
        if (o.kind == MLOF2_K_POOL) d.gx = (uint32_t(W / t.s) * ((uint32_t(H / t.s) + 7u) / 8u) + 63u) / 64u;                     
        if (o.kind == MLOF2_K_RESIZE_AREA && o.out_c <= 4 && t.s / g.tensors[g.segs[o.seg0].tensor].s >= 16) {
            d.kernel = 5u; d.gx = pix;                                                                   
        }
        if (o.kind == MLOF2_K_MEDIAN_HIST) {                                                                             
            const Mlof2Tensor& ti = g.tensors[g.segs[o.seg0].tensor];
            d.gx = (uint32_t(H / ti.s) * uint32_t(W / ti.s) + 2047u) / 2048u;
        }
        if (o.kind == MLOF2_K_VIG_PART || o.kind == MLOF2_K_VIG_SOLVE || o.kind == MLOF2_K_MEDIAN ||
            o.kind == MLOF2_K_MEDIAN_HIST || o.kind == MLOF2_K_MEDIAN_PICK || o.kind == MLOF2_K_HOMOG_ACC || o.kind == MLOF2_K_HOMOG_SOLVE) d.kernel = 5u;                    

        if (o.kind == 64) { d.kernel = uint32_t(g_mlof2_kernel_oft_init); d.gx = (pix + 63u) / 64u; d.gy = 1u; }
        if (o.kind == 65) { d.kernel = uint32_t(g_mlof2_kernel_oft_prep); d.gx = (pix + 63u) / 64u; d.gy = 1u; }
        if (o.kind == 66) { d.kernel = uint32_t(g_mlof2_kernel_oft_out); d.gx = (pix + 63u) / 64u; d.gy = 1u; }
        if (o.kind == 67) { d.kernel = uint32_t(g_mlof2_kernel_oft_final); d.gx = (uint32_t(H) * uint32_t(W) + 63u) / 64u; d.gy = 1u; }
        if (o.kind == 68) { d.kernel = uint32_t(g_mlof2_kernel_oft_lk); d.gx = (uint32_t(W / t.s) + 15u) / 16u; d.gy = (uint32_t(H / t.s) + 15u) / 16u; }
        if (o.kind == 69) { d.kernel = uint32_t(g_mlof2_kernel_oft_luma); d.gx = (uint32_t(W / t.s) + 63u) / 64u; d.gy = uint32_t(H / t.s); }
        if (o.kind == 70) { d.kernel = uint32_t(g_mlof2_kernel_fuse_prep); d.gx = (uint32_t(W / t.s) * uint32_t(H / t.s) + 63u) / 64u; d.gy = 1u; }
        if (o.kind == 71) { d.kernel = uint32_t(g_mlof2_kernel_fuse_blend); d.gx = (uint32_t(H) * uint32_t(W) + 63u) / 64u; d.gy = 1u; }

        if (d.kernel == 2u && g_mlof2_gen_kernel_of_kind[o.kind & 63] >= 0) d.kernel = uint32_t(g_mlof2_gen_kernel_of_kind[o.kind & 63]);
        if (d.kernel == 1u && g_mlof2_ops_kernel_of_kind[o.kind & 63] >= 0) d.kernel = uint32_t(g_mlof2_ops_kernel_of_kind[o.kind & 63]);
        if (d.kernel != 0u && d.kernel != 3u && d.kernel != 4u) {                                                 
            d.fmts = 0u;
            for (int si = 0; si < 7; ++si)
                d.fmts |= uint32_t(si < o.nseg ? g.tensors[g.segs[o.seg0 + si].tensor].fmt & 0xF : 0xF) << (4 * si);
            if (d.kernel == uint32_t(g_mlof2_kernel_conv_w))
                d.fmts = (d.fmts & ~(0xFu << 24)) | (uint32_t(o.ip[6] >= 0 ? (g.tensors[o.ip[6]].fmt & 0xF) : 0xF) << 24);
            d.fmts |= uint32_t(t.fmt & 0xF) << 28;
            d.ip01[0] = o.ip[0]; if (o.kind != MLOF2_K_CORR && o.kind != MLOF2_K_COPY) d.ip01[1] = o.ip[1];                                      
        }
        std::vector<Span> cur_reads;
        for (uint32_t si = 0; si < o.nseg; ++si) {
            int tin = g.segs[o.seg0 + si].tensor;
            if (tin >= 0) {
                uint64_t b, e; mlof2_tensor_range(g, p, p.H, p.W, tin, b, e);
                cur_reads.push_back({b, e});
            }
        }
        if (o.kind == MLOF2_K_CONV && o.ip[6] >= 0 && o.ip[6] < g.num_tensors) {
            uint64_t b, e; mlof2_tensor_range(g, p, p.H, p.W, o.ip[6], b, e);
            cur_reads.push_back({b, e});
        }

        std::vector<Span> cur_writes;
        {
            uint64_t b, e; mlof2_tensor_range(g, p, p.H, p.W, o.out, b, e);
            cur_writes.push_back({b, e});
        }
        if (d.coop_fuse > 0) {
            int op2 = i + int(d.coop_fuse);
            if (op2 < g.num_ops) {
                uint64_t b, e; mlof2_tensor_range(g, p, p.H, p.W, g.ops[op2].out, b, e);
                cur_writes.push_back({b, e});
            }
        }

        bool hazard = false;
                                                                            
        for (const auto& r : cur_reads) {
            for (const auto& w : dirty_writes) {
                if (overlaps(r, w)) { hazard = true; break; }
            }
            if (hazard) break;
        }
                                                                                                    
        if (!hazard) {
            for (const auto& w : cur_writes) {
                for (const auto& r : active_reads) {
                    if (overlaps(w, r)) { hazard = true; break; }
                }
                if (hazard) break;
                for (const auto& dw : dirty_writes) {
                    if (overlaps(w, dw)) { hazard = true; break; }
                }
                if (hazard) break;
            }
        }

        if (hazard || p.dispatches.empty()) {
            d.barrier_before = true;
            dirty_writes.clear();
            active_reads.clear();
        } else {
            d.barrier_before = false;
        }

        for (const auto& w : cur_writes) dirty_writes.push_back(w);
        for (const auto& r : cur_reads) active_reads.push_back(r);
        if (i != skip_op) p.dispatches.push_back(d);                                                        
    }
    return true;
}

                                                                                                           
                                                                                                             
                                                                                                               
                                                                                                         
inline bool mlof2_plan_dp4a_light(const Mlof2Graph& g, int H, int W, Mlof2Plan& p, bool use_coopmat = false) {
    if (!mlof2_plan(g, H, W, p, use_coopmat)) return false;
    for (auto& d : p.dispatches) {
        const Mlof2Op& o = g.ops[d.op];
        if (o.kind == 63) {
            const Mlof2Tensor& t = g.tensors[o.out];
            if (t.c % 4 != 0) return false;                                                                          
            d.kernel = g_mlof2_kernel_depthwise_dp4a;
            const uint32_t w2 = (uint32_t(W / t.s) + 1u) / 2u;
            d.gx = (uint32_t(t.n) * uint32_t(H / t.s) * w2 * uint32_t(t.c / 4) + 63u) / 64u;
            d.gy = 1;
            d.fmts = 0u;
            for (int si = 0; si < 7; ++si)
                d.fmts |= uint32_t(si < o.nseg ? g.tensors[g.segs[o.seg0 + si].tensor].fmt & 0xF : 0xF) << (4 * si);
            d.fmts |= uint32_t(t.fmt & 0xF) << 28;
            d.ip01[0] = o.ip[0]; d.ip01[1] = o.ip[1];
        } else if (o.kind == MLOF2_K_CONV && getenv("MLOF2_LIGHT_DENSE")) {                                      
            if (d.kernel == 0) d.kernel = g_mlof2_kernel_dense_dp4a;
            d.gy = uint32_t(o.out_c + 3) / 4u;
        }                                                                           
    }
    return true;
}

                                                                            
                                                                                               
inline void mlof2_calc_quadratic_vp_b(const float* vp_p, const float* vp_a, const float* vp_b, float t, float* out_vp_b_prime) {
    float c_p = t * (t - 1.0f) * 0.5f;
    float c_a = (1.0f - t) * (1.0f + t);
    float c_b = t * (t + 1.0f) * 0.5f;
    float inv_t = 1.0f / t;
    for (int i = 0; i < 16; ++i) {
        float vp_t = vp_p[i] * c_p + vp_a[i] * c_a + vp_b[i] * c_b;
        out_vp_b_prime[i] = vp_a[i] + (vp_t - vp_a[i]) * inv_t;
    }
}


inline void mlof2_tensor_span(const Mlof2Graph& g, const Mlof2Plan& p, int t, uint64_t& byte_off, uint64_t& byte_size) {
    const Mlof2Tensor& d = g.tensors[t];
    byte_off = p.tensor_base[t];
    if (t < int(p.blk.size()) && p.blk[t].on) { byte_size = p.blk[t].bytes; return; }                                   
    static const uint64_t esz[] = {4, 2, 1, 1};                                 
    byte_size = uint64_t(d.n) * uint64_t(p.H / d.s) * uint64_t(p.W / d.s) * uint64_t(d.c_alloc) * esz[d.fmt & 3];
}
