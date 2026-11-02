                                                                  
#pragma once
                                                                                  
static const int g_mlof2_gen_kernel_of_kind[64] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, -1, 20, 21, 22, 23, 24, 25, 26, 27, -1, -1, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, -1, -1, 47};
                                                                                 
static const int g_mlof2_ops_kernel_of_kind[64] = {-1, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
static const int g_mlof2_kernel_conv_w = 70;
static const int g_mlof2_kernel_conv_blk = 71;
static const int g_mlof2_kernel_dense_dp4a = 72;
static const int g_mlof2_kernel_depthwise_dp4a = 73;
static const int g_mlof2_kernel_oft_init = 74;
static const int g_mlof2_kernel_oft_prep = 75;
static const int g_mlof2_kernel_oft_out = 76;
static const int g_mlof2_kernel_oft_final = 77;
static const int g_mlof2_kernel_oft_lk = 78;
static const int g_mlof2_kernel_oft_luma = 79;
static const int g_mlof2_kernel_fuse_prep = 80;
static const int g_mlof2_kernel_fuse_blend = 81;
static const int g_mlof2_kernel_cand_mv = 82;
