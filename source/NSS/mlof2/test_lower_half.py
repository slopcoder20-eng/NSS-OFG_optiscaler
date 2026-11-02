import sys, os, torch
sys.path.insert(0, "/mnt/e/nss_VK/NSS/mlof2")
import mlof2_graph as MG
from oft_block import OFTNet
from mlof2_oft_lower import OFTLower, OFT_KINDS

def lower_oft_half(net, num_blocks=4, H=1088, W=1920):
    g = MG.Graph()
    lower = OFTLower(net, g)

                                
                                                               
                                                                 
    col_a = g.t("color_a", 4, 1, 1)
    col_b = g.t("color_b", 4, 1, 1)
    of_ab = g.t("of_ab", 2, 8, 1)
    of_ba = g.t("of_ba", 2, 8, 1)
    g.inputs = [col_a, col_b, of_ab, of_ba]

                                                          
    a_s2 = g.op("resize_area", [col_a], lower.new("a_s2", 4, 2), s_out=2)
    b_s2 = g.op("resize_area", [col_b], lower.new("b_s2", 4, 2), s_out=2)

                                                          
    luma_a_s2 = g.op("oft_luma", [a_s2], lower.new("luma_a_s2", 1, 2), s_out=2)
    luma_b_s2 = g.op("oft_luma", [b_s2], lower.new("luma_b_s2", 1, 2), s_out=2)

                                                          
    a_s4 = g.op("resize_area", [a_s2], lower.new("a_s4", 4, 4), s_out=4)
    b_s4 = g.op("resize_area", [b_s2], lower.new("b_s4", 4, 4), s_out=4)
    a_s8 = g.op("resize_area", [a_s4], lower.new("a_s8", 4, 8), s_out=8)
    b_s8 = g.op("resize_area", [b_s4], lower.new("b_s8", 4, 8), s_out=8)
    a_s16 = g.op("resize_area", [a_s8], lower.new("a_s16", 4, 16), s_out=16)
    b_s16 = resize_b_s16 = g.op("resize_area", [b_s8], lower.new("b_s16", 4, 16), s_out=16)

    pyramid_a = {2: a_s2, 4: a_s4, 8: a_s8, 16: a_s16}
    pyramid_b = {2: b_s2, 4: b_s4, 8: b_s8, 16: b_s16}

                                                                    
    of_ab_s16 = g.op("resize_area", [of_ab], lower.new("of_ab_s16", 2, 16), s_out=16)
    of_ba_s16 = g.op("resize_area", [of_ba], lower.new("of_ba_s16", 2, 16), s_out=16)

                                                              
    fa_cur = lower.new("fa_s16", 2, 16)
    fb_cur = lower.new("fb_s16", 2, 16)
    m_cur = lower.new("m_s16", 1, 16)
    g.op("oft_init", [of_ab_s16, of_ba_s16], fa_cur, out_b=fb_cur, out_m=m_cur)

                                                                          
                                               
    scales = (16, 8, 4, 2)[:num_blocks]
    blocks = net.blocks[:num_blocks]

    for bi, (blk, s) in enumerate(zip(blocks, scales)):
        prefix = f"b{bi}_s{s}"
        c = blk.d2.out_channels

        a_s = pyramid_a[s]
        b_s = pyramid_b[s]

        x_in = g.op("oft_prep", [a_s, b_s, fa_cur, fb_cur, m_cur],
                    lower.new(f"{prefix}_x_in", 16, s, q=f"{prefix}.x_in"),
                    scale_level=s, q=f"{prefix}.x_in")

        d1_out = lower.conv(blk.d1, [(x_in, (13, 16))], f"{prefix}_d1", act="leaky", q=f"{prefix}.d1_out")
        d2_out = lower.conv(blk.d2, [lower.full(d1_out)], f"{prefix}_d2", act="leaky", q=f"{prefix}.d2_out")

        cur = d2_out
        for ri, resc in enumerate(blk.body):
            r_prefix = f"{prefix}_body_{ri}"
            q_r_prefix = f"{prefix}.body_{ri}"
            ya = lower.conv(resc.a, [lower.full(cur)], f"{r_prefix}_a", act="leaky", q=f"{q_r_prefix}.a_out")
            if ri < len(blk.body) - 1:
                cur = lower.conv(resc.b, [lower.full(ya)], f"{r_prefix}_b", act="none", res=cur, res_mode="post",
                                 q=f"{q_r_prefix}.res_add")
            else:
                cur = lower.conv(resc.b, [lower.full(ya)], f"{prefix}_body_out", act="leaky", res=cur, res_mode="pre",
                                 q=f"{prefix}.body_out")

        out80 = lower.conv(blk.out, [lower.full(cur)], f"{prefix}_out80", act="none", q=f"{prefix}.out80")

        fa_acc = lower.new(f"{prefix}_fa_acc", 2, s)
        fb_acc = lower.new(f"{prefix}_fb_acc", 2, s)
        m_acc = lower.new(f"{prefix}_m_acc", 1, s)
        g.op("oft_out", [out80, fa_cur, fb_cur, m_cur], fa_acc, out_b=fb_acc, out_m=m_acc, scale_level=s)

        if s > 2:
            next_s = s // 2
            fa_cur = g.op("resize_bil", [fa_acc], lower.new(f"fa_s{next_s}", 2, next_s), s_out=next_s, mul=[2.0, 2.0])
            fb_cur = g.op("resize_bil", [fb_acc], lower.new(f"fb_s{next_s}", 2, next_s), s_out=next_s, mul=[2.0, 2.0])
            m_cur = g.op("resize_bil", [m_acc], lower.new(f"m_s{next_s}", 1, next_s), s_out=next_s, mul=[1.0, 1.0])
        else:
            fa_cur, fb_cur, m_cur = fa_acc, fb_acc, m_acc

                                                               
    for it in range(3):
        fa_lk2 = lower.new(f"fa_lk_s2_it{it}", 2, 2)
        fb_lk2 = lower.new(f"fb_lk_s2_it{it}", 2, 2)
        g.op("oft_lk", [luma_a_s2, luma_b_s2, fa_cur, fb_cur], fa_lk2, out_b=fb_lk2, scale_level=2)
        fa_cur, fb_cur = fa_lk2, fb_lk2

                                                                     
    fa_s1 = g.op("resize_bil", [fa_cur], lower.new("fa_s1", 2, 1), s_out=1, mul=[2.0, 2.0])
    fb_s1 = g.op("resize_bil", [fb_cur], lower.new("fb_s1", 2, 1), s_out=1, mul=[2.0, 2.0])
    m_s1  = g.op("resize_bil", [m_cur],  lower.new("m_s1", 1, 1), s_out=1, mul=[1.0, 1.0])

                                                                                           
    col_out = lower.new("color_out", 4, 1)
    g.op("oft_final", [col_a, col_b, fa_s1, fb_s1, m_s1], col_out)
    g.outputs = [col_out, fa_s1, fb_s1]

    return g

if __name__ == "__main__":
    net = OFTNet((128, 96, 64, 48), (3, 3, 3, 3))
    ckpt = "/mnt/e/nss_VK/NSS/mlof2/ckpt_oft/oft5_best.pt"
    if os.path.exists(ckpt):
        net.load_state_dict(torch.load(ckpt, map_location="cpu"))
    g4 = lower_oft_half(net, num_blocks=4)
    print("Half-Res 4-Block Graph Summary:", g4.summary())
    print("Total Ops:", len(g4.ops))
    g3 = lower_oft_half(net, num_blocks=3)
    print("Half-Res 3-Block Graph Summary:", g3.summary())
    print("Total Ops:", len(g3.ops))

