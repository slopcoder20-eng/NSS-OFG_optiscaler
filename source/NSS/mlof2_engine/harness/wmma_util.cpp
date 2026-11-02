                                                                                                                 
                                                                                                                      
                                                                                                   
#include "../mlof2_engine_host.h"
#include "../generated_cut3_v2_int8/mlof2_enc_int8_graph.h"
#include "../generated_cut3_v2_int8/mlof2_pair_int8_graph.h"
#include "../generated_cut3_v2_int8/mlof2_gen_prep_int8_graph.h"
#include "../generated_cut3_v2_int8/mlof2_gen_t_int8_graph.h"
#include "../generated_dp4a_light_v2/mlof2_light_graph.h"
#include <cmath>

static const char* kname(uint32_t k) {
    if (k == uint32_t(g_mlof2_kernel_conv_w)) return "conv_w";
    if (k == uint32_t(g_mlof2_kernel_conv_blk)) return "conv_blk";
    if (k == 3u) return "conv_coop";
    if (k == 0u) return "conv(dp4a)";
    if (k == uint32_t(g_mlof2_kernel_dense_dp4a)) return "dense_dp4a";
    return "?";
}
static uint32_t up(uint32_t a, uint32_t b) { return (a + b - 1u) / b * b; }

static void report(const char* name, const Mlof2Graph& g, bool coop, int H, int W, double per) {
    Mlof2Plan p;
    if (!mlof2_plan(g, H, W, p, coop)) { printf("%s: plan failed\n", name); return; }
    double use = 0, issued = 0, um = 0, un = 0, uk = 0;
    printf("== %s (%s)\n  op   kernel      s   n  oc  cin(K/tap)  k  | eff M    N    K   total | GMAC\n", name, coop ? "coopmat" : "dp4a");
    for (const Mlof2Dispatch& d : p.dispatches) {
        const Mlof2Op& o = g.ops[d.op];
        if (o.kind != MLOF2_K_CONV) continue;
        const Mlof2Tensor& t = g.tensors[o.out];
        const uint32_t oh = uint32_t(H / t.s), ow = uint32_t(W / t.s), taps = uint32_t(o.ip[0] * o.ip[1]);
        uint32_t cin = 0, cin_issued = 0;
        for (int si = 0; si < o.nseg; ++si) cin += uint32_t(g.segs[o.seg0 + si].c);
        uint32_t rows = 1, nblkw = 1;
        double effn;
        if (d.kernel == uint32_t(g_mlof2_kernel_conv_w)) {
            rows = d.wsc[6]; nblkw = d.wsc[7];
            const uint32_t icwk = d.wsc[4];
            cin_issued = up(icwk * 4u, 16u);
            const uint32_t ng = (uint32_t(o.out_c) + 16u * nblkw - 1u) / (16u * nblkw);
            effn = double(o.out_c) / double(ng * 16u * nblkw);
        } else if (d.kernel == uint32_t(g_mlof2_kernel_conv_blk)) {
            rows = d.wsc[2]; nblkw = d.wsc[7];
            cin_issued = up(cin, 16u);
            effn = double(o.out_c) / double(up(uint32_t(o.out_c), 16u));
        } else if (d.kernel == 3u) {
            rows = 4u * d.coop_rt;
            uint32_t c4 = 0;
            for (int si = 0; si < o.nseg; ++si) c4 += up(uint32_t(g.segs[o.seg0 + si].c), 4u);
            cin_issued = up(c4, 16u);
            effn = double(o.out_c) / double(up(uint32_t(o.out_c), 16u));
        } else {                                                                                                 
            uint32_t c4 = 0;
            for (int si = 0; si < o.nseg; ++si) c4 += up(uint32_t(g.segs[o.seg0 + si].c), 4u);
            cin_issued = c4; effn = 1.0; rows = 1;
        }
        const bool wmma = d.kernel == 3u || d.kernel == uint32_t(g_mlof2_kernel_conv_w) || d.kernel == uint32_t(g_mlof2_kernel_conv_blk);
        const double effm = wmma ? double(ow) / up(ow, 16u) * double(oh) / up(oh, rows) : 1.0;
        const double effk = double(cin) / double(cin_issued);
        const double mac = double(t.n) * oh * ow * double(o.out_c) * cin * taps;
        const double eff = effm * effn * effk;
        use += mac; issued += mac / eff;
        printf("  %-4u %-10s %3d %2d %4d %4u(%4u) %2d  | %5.2f %5.2f %5.2f  %5.2f | %6.3f\n", d.op, kname(d.kernel), t.s, t.n, o.out_c, cin,
               cin_issued, o.ip[0], effm, effn, effk, eff, mac * 1e-9);
    }
    printf("  total %.2f GMAC useful, %.2f issued -> utilisation %.1f%%  (x%.0f per real frame)\n", use * 1e-9, issued * 1e-9,
           100.0 * use / issued, per);
}

int main(int argc, char** argv) {
    const bool coop = argc < 2 || atoi(argv[1]) != 0;
    const int H = 1088, W = 1920;
    report("light (enc A+B + pair)", mlof2_light_graph, coop, H, W, 1);
    report("full enc (one frame)", mlof2_enc_int8_graph, coop, H, W, 1);
    report("full pair", mlof2_pair_int8_graph, coop, H, W, 1);
    return 0;
}
