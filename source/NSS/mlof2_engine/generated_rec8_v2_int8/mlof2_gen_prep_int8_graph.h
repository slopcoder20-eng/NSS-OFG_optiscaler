                                                           
#pragma once
#include <stdint.h>
                                                                                           
                                                                               
                                                                                   
#include "mlof2_graph_types.h"
                                                                                           
static const int MLOF2_GEN_PREP_INT8_WEIGHT_FMT = 2;                                                      
static const int MLOF2_GEN_PREP_INT8_NUM_TENSORS = 14, MLOF2_GEN_PREP_INT8_NUM_SEGS = 17, MLOF2_GEN_PREP_INT8_NUM_OPS = 5;
static const uint32_t MLOF2_GEN_PREP_INT8_BLOB_WORDS = 16, MLOF2_GEN_PREP_INT8_ARENA_UNITS = 15620;
static const int MLOF2_GEN_PREP_INT8_T_COL_A = 0;
static const int MLOF2_GEN_PREP_INT8_T_COL_B = 1;
static const int MLOF2_GEN_PREP_INT8_T_DEP_A = 2;
static const int MLOF2_GEN_PREP_INT8_T_DEP_B = 3;
static const int MLOF2_GEN_PREP_INT8_T_MV = 4;
static const int MLOF2_GEN_PREP_INT8_T_MVV = 5;
static const int MLOF2_GEN_PREP_INT8_T_MV_AP = 6;
static const int MLOF2_GEN_PREP_INT8_T_OF = 7;
static const int MLOF2_GEN_PREP_INT8_T_OF_PREV = 8;
static const int MLOF2_GEN_PREP_INT8_T_VIG = 9;
static const int MLOF2_GEN_PREP_INT8_T_CAB = 11;
static const int MLOF2_GEN_PREP_INT8_T_PH = 12;
static const int MLOF2_GEN_PREP_INT8_T_QP = 13;
static const Mlof2Tensor mlof2_gen_prep_int8_tensors[] = {
  {3, 1, 1, 4096u, 1, 4, 1.0f}               ,
  {3, 1, 1, 6144u, 1, 4, 1.0f}               ,
  {1, 1, 1, 12288u, 0, 1, 1.0f}               ,
  {1, 1, 1, 13312u, 0, 1, 1.0f}               ,
  {2, 1, 1, 8192u, 0, 2, 1.0f}            ,
  {1, 1, 1, 14336u, 1, 2, 1.0f}             ,
  {2, 1, 1, 10240u, 0, 2, 1.0f}               ,
  {2, 4, 1, 15360u, 0, 2, 1.0f}            ,
  {2, 4, 1, 15488u, 0, 2, 1.0f}                 ,
  {16, 64, 1, 15616u, 0, 16, 1.0f}             ,
  {16, 4, 1, 0u, 1, 16, 1.0f}                  ,
  {8, 1, 1, 0u, 1, 8, 1.0f}              ,
  {9, 2, 1, 4096u, 1, 10, 1.0f}             ,
  {12, 4, 1, 5376u, 1, 12, 1.0f}             
};
static const Mlof2Seg mlof2_gen_prep_int8_segs[] = {
  {0, 0, 3, 0},
  {1, 0, 3, 0},
  {4, 0, 2, 0},
  {5, 0, 1, 0},
  {10, 0, 16, 0},
  {0, 0, 3, 0},
  {1, 0, 3, 0},
  {9, 0, 16, 0},
  {4, 0, 2, 0},
  {5, 0, 1, 0},
  {6, 0, 2, 0},
  {7, 0, 2, 0},
  {8, 0, 2, 0},
  {11, 0, 8, 0},
  {2, 0, 1, 0},
  {3, 0, 1, 0},
  {6, 0, 2, 0}
};
static const Mlof2Op mlof2_gen_prep_int8_ops[] = {
  {15, 10, 0, 16, 0, 4, {0, 0, 0, 0, 0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}, 0u, 0u, 0u, 0u}                             ,
  {16, 9, 0, 16, 4, 1, {0, 0, 0, 0, 0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}, 0u, 0u, 0u, 0u}                          ,
  {42, 11, 0, 8, 5, 3, {0, 0, 0, 0, 0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}, 0u, 0u, 0u, 0u}                       ,
  {53, 12, 0, 9, 8, 5, {1, 0, 0, 0, 0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}, 0u, 0u, 0u, 0u}                      ,
  {54, 13, 0, 12, 13, 4, {1, 0, 0, 0, 0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}, 0u, 0u, 0u, 0u}                      
};
static const int mlof2_gen_prep_int8_io[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 11, 12, 13};
static const char* const mlof2_gen_prep_int8_io_names[] = {"col_a", "col_b", "dep_a", "dep_b", "mv", "mvv", "mv_ap", "of", "of_prev", "vig", "vig", "cab", "ph", "qp"};
static const Mlof2Graph mlof2_gen_prep_int8_graph = {mlof2_gen_prep_int8_tensors, 14, mlof2_gen_prep_int8_segs, 17, mlof2_gen_prep_int8_ops, 5, 16u, 15620u, "mlof2_gen_prep_int8.bin", mlof2_gen_prep_int8_io, mlof2_gen_prep_int8_io_names, 10, 4, 2};
