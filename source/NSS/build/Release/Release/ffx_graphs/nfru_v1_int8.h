#include "nfru_v1_int8_graph_0.h"
#include "nfru_v1_int8_constants.h"

typedef struct nfru_v1_int8_Info {
    const uint32_t       constantNums;
    const uint32_t*      constantIds;
    const uint32_t*      constantFormats;
    const uint32_t*      constantShapeSize;
    const uint64_t**     constantShapes;
    const int64_t*       constantSparsityDimensions;
    const uint32_t*      constantDataSize;
    const unsigned char** constantDatas;

    const char*          graphEntryPoint;
    const uint32_t       graphDataSize;
    const unsigned char* graphData;

    const uint32_t       inputTensorNums;
    const char**         inputTensorNames;
    const uint32_t*      inputTensorSets;
    const uint32_t*      inputTensorBindings;
    const uint32_t*      inputTensorFormats;
    const uint32_t*      inputTensorDimSize;
    const int64_t**     inputTensorDims;
    const uint32_t       outputTensorNums;
    const char**         outputTensorNames;
    const uint32_t*      outputTensorSets;
    const uint32_t*      outputTensorBindings;
    const uint32_t*      outputTensorFormats;
    const uint32_t*      outputTensorDimSize;
    const int64_t**     outputTensorDims;
} nfru_v1_int8_Info;

static const nfru_v1_int8_Info g_nfru_v1_int8_Info = {
    17, 
    g_nfru_v1_int8_constants_id, 
    g_nfru_v1_int8_constants_format, 
    g_nfru_v1_int8_constants_shape_size, 
    g_nfru_v1_int8_constants_shape, 
    g_nfru_v1_int8_constants_sparsity_dimension, 
    g_nfru_v1_int8_constants_data_size, 
    g_nfru_v1_int8_constants_data, 
    g_nfru_v1_int8_graph_0_entry_point, 
    g_nfru_v1_int8_graph_0_data_size, 
    g_nfru_v1_int8_graph_0_data, 
    g_nfru_v1_int8_graph_0_input_tensor_nums, 
    g_nfru_v1_int8_graph_0_input_tensor_names, 
    g_nfru_v1_int8_graph_0_input_tensor_sets, 
    g_nfru_v1_int8_graph_0_input_tensor_bindings, 
    g_nfru_v1_int8_graph_0_input_tensor_formats, 
    g_nfru_v1_int8_graph_0_input_tensor_dim_size, 
    g_nfru_v1_int8_graph_0_input_tensor_dims, 
    g_nfru_v1_int8_graph_0_output_tensor_nums, 
    g_nfru_v1_int8_graph_0_output_tensor_names, 
    g_nfru_v1_int8_graph_0_output_tensor_sets, 
    g_nfru_v1_int8_graph_0_output_tensor_bindings, 
    g_nfru_v1_int8_graph_0_output_tensor_formats, 
    g_nfru_v1_int8_graph_0_output_tensor_dim_size, 
    g_nfru_v1_int8_graph_0_output_tensor_dims 
};

