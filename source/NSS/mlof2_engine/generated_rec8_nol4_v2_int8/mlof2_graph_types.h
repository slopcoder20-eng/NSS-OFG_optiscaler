                                                           
#ifndef MLOF2_GRAPH_TYPES_H
#define MLOF2_GRAPH_TYPES_H
#include <stdint.h>
enum Mlof2OpKind {MLOF2_K_CONV = 0, MLOF2_K_UNSHUFFLE = 1, MLOF2_K_RESIZE_AREA = 2, MLOF2_K_RESIZE_BIL = 3, MLOF2_K_WARP = 4, MLOF2_K_CORR = 5, MLOF2_K_ABSDIFF = 6, MLOF2_K_ROUND_TRIP = 7, MLOF2_K_SPREAD = 8, MLOF2_K_AXPY = 9, MLOF2_K_SCALE = 10, MLOF2_K_ZEROS = 11, MLOF2_K_COPY = 12, MLOF2_K_CONVEX_UP = 13, MLOF2_K_PROP_STEP = 14, MLOF2_K_VIG_PART = 15, MLOF2_K_VIG_SOLVE = 16, MLOF2_K_VIG_APPLY = 17, MLOF2_K_MUL = 18, MLOF2_K_INVERT_T = 19, MLOF2_K_WARP_NOISE = 20, MLOF2_K_OFF_FRAME = 21, MLOF2_K_FLOWDIST = 22, MLOF2_K_SIGMOID = 23, MLOF2_K_FILL_T = 24, MLOF2_K_UP_NEAREST = 25, MLOF2_K_SOFTMAX_BLEND = 26, MLOF2_K_RULE_PREP = 27, MLOF2_K_POOL = 28, MLOF2_K_LUMA_GRAD = 29, MLOF2_K_MASK_MUL = 30, MLOF2_K_MEDIAN = 31, MLOF2_K_RULE_SCORE = 32, MLOF2_K_AXPY_T = 33, MLOF2_K_RULE_CARRY = 34, MLOF2_K_BLEND_MASK = 35, MLOF2_K_CAM_FLOW = 36, MLOF2_K_TRAIL_SEL = 37, MLOF2_K_WARP_NOISE4 = 38, MLOF2_K_FEAT4 = 39, MLOF2_K_MEDIAN_HIST = 40, MLOF2_K_MEDIAN_PICK = 41, MLOF2_K_PREP_C = 42, MLOF2_K_PREP_F = 43, MLOF2_K_BLEND_PREP = 44, MLOF2_K_CARRY = 45, MLOF2_K_CAM_INV = 46, MLOF2_K_FINAL = 47, MLOF2_K_PREP = 48, MLOF2_K_INV3 = 49, MLOF2_K_FEAT4C = 50, MLOF2_K_BLEND9 = 51, MLOF2_K_FINAL3 = 52, MLOF2_K_PREP_H = 53, MLOF2_K_Q_PREP = 54, MLOF2_K_Q_CAND = 55, MLOF2_K_Q_FEAT = 56, MLOF2_K_Q_RULE1 = 57, MLOF2_K_Q_RULE2 = 58, MLOF2_K_CAM_INV_Q = 59, MLOF2_K_FINAL4 = 60, MLOF2_K_HOMOG_ACC = 61, MLOF2_K_HOMOG_SOLVE = 62};
#define MLOF2_CONTRACT 2
                                                                                                    
                                                                                                          
struct Mlof2Tensor { int32_t c, s, n; uint32_t off_units; int32_t fmt, c_alloc; float scale; };
struct Mlof2Seg { int32_t tensor, c_off, c, swap; };
struct Mlof2Op { int32_t kind, out, out_coff, out_c, seg0, nseg; int32_t ip[8]; float fp[4];
  uint32_t w_off, kw_words, scale_off, bias_off; };
struct Mlof2Graph { const Mlof2Tensor* tensors; int num_tensors; const Mlof2Seg* segs; int num_segs;
  const Mlof2Op* ops; int num_ops; uint32_t blob_words, arena_units; const char* blob_name;
  const int* io; const char* const* io_names; int num_inputs, num_outputs;                            
  int32_t weight_fmt; };                                                                                  
#endif
