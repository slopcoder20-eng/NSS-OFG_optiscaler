/*
 * SPDX-FileCopyrightText: Copyright 2023-2025 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef ML_SDK_VGF_LIB_DECODER_API_H
#define ML_SDK_VGF_LIB_DECODER_API_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif                        
#ifdef __GNUC__             
#    define MLSDK_EXPORT __attribute__((visibility("default")))
#    define MLSDK_IMPORT
#else
#    ifdef _MSC_VER
#        define MLSDK_EXPORT __declspec(dllexport)
#        define MLSDK_IMPORT __declspec(dllimport)
#    else
#        define MLSDK_EXPORT
#        define MLSDK_IMPORT
#        pragma warning Undefined dynamic library export / import semantic for detected toolchain.
#    endif
#endif
#ifdef MLSDK_DYNAMIC_LIB                                 
#    ifdef MLSDK_EXPORT_API                                   
#        define MLSDKAPI MLSDK_EXPORT
#    else
#        define MLSDKAPI MLSDK_IMPORT
#    endif
#else
#    define MLSDKAPI
#endif

typedef struct mlsdk_decoder_header_decoder_s *mlsdk_decoder_header_decoder;
typedef struct mlsdk_decoder_module_table_decoder_s *mlsdk_decoder_module_table_decoder;
typedef struct mlsdk_decoder_push_constants_range_decoder_s *mlsdk_decoder_push_constants_range_decoder;
typedef struct mlsdk_decoder_model_sequence_decoder_s *mlsdk_decoder_model_sequence_decoder;
typedef struct mlsdk_decoder_model_resource_table_decoder_s *mlsdk_decoder_model_resource_table_decoder;
typedef struct mlsdk_decoder_constant_table_decoder_s *mlsdk_decoder_constant_table_decoder;

   
                                  
     
   

   
                                    
  
   
typedef uint16_t mlsdk_vk_header_version;

   
                                               
  
   
typedef enum {
    mlsdk_decoder_section_modules = 0,
    mlsdk_decoder_section_model_sequence = 1,
    mlsdk_decoder_section_resources = 2,
    mlsdk_decoder_section_constants = 3,
} mlsdk_decoder_section;

   
                                        
  
   
typedef int32_t mlsdk_vk_descriptor_type;

   
                                           
  
   
typedef struct {
    mlsdk_vk_descriptor_type value;
    bool has_value;
} mlsdk_vk_descriptor_type_optional;

   
                                   
  
   
typedef int32_t mlsdk_vk_format;

   
                                                                                       
  
   
MLSDKAPI mlsdk_vk_format mlsdk_vk_format_undefined();

   
                               
  
   
typedef enum {
    mlsdk_decoder_module_type_compute = 0,
    mlsdk_decoder_module_type_graph = 1,
} mlsdk_decoder_module_type;

   
                                                
  
   
typedef enum {
    mlsdk_decoder_mrt_category_input,
    mlsdk_decoder_mrt_category_output,
    mlsdk_decoder_mrt_category_intermediate,
    mlsdk_decoder_mrt_category_constant,
} mlsdk_decoder_mrt_category;

   
                                             
                                                                                           
                                                             
   
typedef struct {
    uint8_t major;
    uint8_t minor;
    uint8_t patch;
} mlsdk_decoder_vgf_version;

   
                                                                         
  
   
typedef struct {
    uint64_t offset;                                                                 
    uint64_t size;                                       
} mlsdk_decoder_vgf_section_info;

   
                              
   
typedef struct {
    const uint32_t *code;
    size_t words;
} mlsdk_decoder_spirv_code;

   
                                
   
typedef struct {
    const uint8_t *data;
    size_t size;
} mlsdk_decoder_constant_data;

   
                                 
   
typedef struct {
    uint32_t data[3];
} mlsdk_decoder_dispatch_shape;

   
                           
   
typedef struct {
    const uint32_t *data;
    size_t size;
} mlsdk_decoder_constant_indexes;

   
                             
                                               
   
typedef struct {
    const int64_t *data;
    size_t size;
} mlsdk_decoder_tensor_dimensions;

   
                                  
  
                                                                            
   
MLSDKAPI void mlsdk_decoder_get_version(mlsdk_decoder_vgf_version *version);

   
                                                             
                                                   
   
MLSDKAPI size_t mlsdk_decoder_header_size();

   
                                                                                                     
                                                                              
   
MLSDKAPI size_t mlsdk_decoder_header_decoder_mem_reqs();

   
                                    
  
                                                   
                                                                         
                                                   
   
MLSDKAPI mlsdk_decoder_header_decoder *mlsdk_decoder_create_header_decoder(const void *const headerData,
                                                                           void *decoderMemory);

   
                                       
  
                                                                  
                                                                         
   
MLSDKAPI bool mlsdk_decoder_is_header_valid(const mlsdk_decoder_header_decoder *const decoder);

   
                                                                        
  
                                                                  
                                                                               
   
MLSDKAPI bool mlsdk_decoder_is_header_compatible(const mlsdk_decoder_header_decoder *const decoder);

   
                                                                       
  
                                                                  
                                                                                            
   
MLSDKAPI void mlsdk_decoder_get_encoder_vk_header_version(const mlsdk_decoder_header_decoder *const decoder,
                                                          mlsdk_vk_header_version *vkHeaderVersion);

   
                                   
  
                                                                  
                                                                  
   
MLSDKAPI void mlsdk_decoder_get_header_version(const mlsdk_decoder_header_decoder *const decoder,
                                               mlsdk_decoder_vgf_version *version);

   
                                                                   
  
                                                                  
                                  
                                                     
  
   
MLSDKAPI void mlsdk_decoder_get_header_section_info(const mlsdk_decoder_header_decoder *const decoder,
                                                    mlsdk_decoder_section sectionName,
                                                    mlsdk_decoder_vgf_section_info *section);

   
                                                                                                           
                                                                                    
   
MLSDKAPI size_t mlsdk_decoder_module_table_decoder_mem_reqs();

   
                                                             
  
                                                 
                                            
                                                               
   
MLSDKAPI bool mlsdk_decoder_is_valid_module_table(const void *moduleTableData, uint64_t size);

   
                                          
  
                                                              
                                                                         
                                                   
   
MLSDKAPI mlsdk_decoder_module_table_decoder *
mlsdk_decoder_create_module_table_decoder(const void *const moduleTableData, void *decoderMemory);

   
                                                           
  
                                                         
                                             
   
MLSDKAPI size_t mlsdk_decoder_get_module_table_num_entries(const mlsdk_decoder_module_table_decoder *const decoder);

   
                                                  
  
                                                         
                                                         
                                       
   
MLSDKAPI mlsdk_decoder_module_type
mlsdk_decoder_get_module_type(const mlsdk_decoder_module_table_decoder *const decoder, uint32_t idx);

   
                                                  
  
                                                         
                                                         
                                          
   
MLSDKAPI const char *mlsdk_decoder_get_module_name(const mlsdk_decoder_module_table_decoder *const decoder,
                                                   uint32_t idx);

   
                                                                  
  
                                                         
                                                         
                                               
  
                                                                        
   
MLSDKAPI const char *mlsdk_decoder_get_module_entry_point(const mlsdk_decoder_module_table_decoder *const decoder,
                                                          uint32_t idx);

   
                                                   
  
                                                         
                                                         
                                                            
  
                                                                                                        
   
MLSDKAPI void mlsdk_decoder_get_module_code(const mlsdk_decoder_module_table_decoder *const decoder, uint32_t idx,
                                            mlsdk_decoder_spirv_code *spirvCode);

                                                                                                                        

   
                                                                         
  
   
typedef struct mlsdk_decoder_binding_slots_handle_s const *mlsdk_decoder_binding_slots_handle;

   
                                             
  
                                                                        
                                                      
                                                    
   
MLSDKAPI size_t mlsdk_decoder_binding_slot_size(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                                mlsdk_decoder_binding_slots_handle handle);

   
                                                        
  
                                                                        
                                                      
                                                                          
                                                        
   
MLSDKAPI uint32_t
mlsdk_decoder_binding_slot_binding_id(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                      mlsdk_decoder_binding_slots_handle handle, uint32_t slotIdx);

   
                                                       
  
                                                                        
                                                      
                                                                             
                                                       
   
MLSDKAPI uint32_t
mlsdk_decoder_binding_slot_mrt_index(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                     mlsdk_decoder_binding_slots_handle handle, uint32_t slotIdx);

                                                                                                                        

   
                                                             
  
   
typedef struct mlsdk_decoder_push_constant_ranges_handle_s const *mlsdk_decoder_push_constant_ranges_handle;

   
                                                    
  
                                                                        
                                                       
                                         
   
MLSDKAPI size_t
mlsdk_decoder_get_push_constant_ranges_size(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                            mlsdk_decoder_push_constant_ranges_handle handle);

   
                                                                
  
                                                                        
                                                       
                                                                                                  
                                                                 
   
MLSDKAPI uint32_t mlsdk_decoder_get_push_constant_range_stage_flags(
    const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
    mlsdk_decoder_push_constant_ranges_handle handle, uint32_t rangeIdx);

   
                                                           
  
                                                                        
                                                       
                                                                                                  
                                                            
   
MLSDKAPI uint32_t
mlsdk_decoder_get_push_constant_range_offset(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                             mlsdk_decoder_push_constant_ranges_handle handle, uint32_t rangeIdx);

   
                                                                             
  
                                                                        
                                                       
                                                                                                  
                                                                              
   
MLSDKAPI uint32_t
mlsdk_decoder_get_push_constant_range_size(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                           mlsdk_decoder_push_constant_ranges_handle handle, uint32_t rangeIdx);

                                                                                                                        

   
                                                               
  
                                                   
                                            
                                                               
   
MLSDKAPI bool mlsdk_decoder_is_valid_model_sequence(const void *modelSequenceData, uint64_t size);

   
                                           
  
                                                                  
                                                                                      
                                                                  
   
MLSDKAPI mlsdk_decoder_model_sequence_decoder *
mlsdk_decoder_create_model_sequence_decoder(const void *const modelSequenceData, void *modelSequenceDecoderMemory);

   
                                                                                                             
  
                                                                                      
   
MLSDKAPI size_t mlsdk_decoder_model_sequence_decoder_mem_reqs();

   
                                                                  
  
                                                                        
                                                       
   
MLSDKAPI size_t
mlsdk_decoder_get_model_sequence_table_size(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder);

   
                                                                                        
  
                                                                        
                                                                
                                                                     
   
MLSDKAPI size_t mlsdk_decoder_model_sequence_get_segment_descriptorset_info_size(
    const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                                                   
  
                                                                        
                                                           
                                                                  
   
MLSDKAPI void mlsdk_decoder_model_sequence_get_segment_constant_indexes(
    const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx,
    mlsdk_decoder_constant_indexes *constant);

   
                                                               
  
                                                                        
                                                                
                                            
   
MLSDKAPI mlsdk_decoder_module_type mlsdk_decoder_model_sequence_get_segment_type(
    const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                             
  
                                                                        
                                                                
                                            
   
MLSDKAPI const char *
mlsdk_decoder_model_sequence_get_segment_name(const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder,
                                              uint32_t segIdx);

   
                                                                                                 
  
                                                                        
                                                                
                                                                                  
   
MLSDKAPI uint32_t mlsdk_decoder_model_sequence_get_segment_module_index(
    const mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                                    
  
                                                                        
                                                                
                                                                                 
   
MLSDKAPI void mlsdk_decoder_model_sequence_get_segment_dispatch_shape(
    mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx,
    mlsdk_decoder_dispatch_shape *dispatchShape);

   
                                                                           
  
                                                                        
                                                                
                                             
   
MLSDKAPI mlsdk_decoder_push_constant_ranges_handle mlsdk_decoder_model_sequence_get_segment_push_constant_range(
    mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                                                          
  
                                                                        
                                                                
                                                             
                                            
                                           
   
MLSDKAPI mlsdk_decoder_binding_slots_handle mlsdk_decoder_model_sequence_get_segment_descriptor_binding_slot(
    mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx, uint32_t descIdx);

   
                                                                          
  
                                                                        
                                                                
                                            
     
MLSDKAPI mlsdk_decoder_binding_slots_handle mlsdk_decoder_model_sequence_get_segment_input_binding_slot(
    mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                                           
  
                                                                        
                                                                
                                            
   
MLSDKAPI
mlsdk_decoder_binding_slots_handle mlsdk_decoder_model_sequence_get_segment_output_binding_slot(
    mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder, uint32_t segIdx);

   
                                                       
  
                                                                        
                                            
   

MLSDKAPI mlsdk_decoder_binding_slots_handle
mlsdk_decoder_model_sequence_get_input_binding_slot(mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder);
   
                                                        
  
                                                                        
                                            
   

MLSDKAPI mlsdk_decoder_binding_slots_handle
mlsdk_decoder_model_sequence_get_output_binding_slot(mlsdk_decoder_model_sequence_decoder *const modelSequenceDecoder);
   
                                                                                                                   
                                                                                            
   
MLSDKAPI size_t mlsdk_decoder_model_resource_table_decoder_mem_reqs();

   
                                                                     
  
                                                        
                                            
                                                               
   
MLSDKAPI bool mlsdk_decoder_is_valid_model_resource_table(const void *modelResourceTableData, uint64_t size);

   
                                                 
  
                                                                              
                                                                         
                                                   
   
MLSDKAPI mlsdk_decoder_model_resource_table_decoder *
mlsdk_decoder_create_model_resource_table_decoder(const void *const modelResourceTableData, void *decoderMemory);

   
                                                                   
  
                                                                                   
                                             
   
MLSDKAPI size_t mlsdk_decoder_get_model_resource_table_num_entries(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder);

   
                                                                                     
                                                                                   
  
                                                                                   
                                                                 
                                                             
   
MLSDKAPI mlsdk_vk_descriptor_type_optional mlsdk_decoder_get_vk_descriptor_type(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder, uint32_t idx);

   
                                                                            
  
                                                                                   
                                                                 
                                                    
   
MLSDKAPI mlsdk_vk_format mlsdk_decoder_get_vk_format(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder, uint32_t idx);

   
                                                                           
  
                                                                                   
                                                                    
                                    
   
MLSDKAPI mlsdk_decoder_mrt_category mlsdk_decoder_model_resource_table_get_category(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder, uint32_t mrtIdx);

   
                                                                     
  
                                                                                   
                                                                    
                                                                               
   
MLSDKAPI void mlsdk_decoder_model_resource_table_get_tensor_shape(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder, uint32_t mrtIdx,
    mlsdk_decoder_tensor_dimensions *dimensions);

   
                                                                       
  
                                                                                   
                                                                    
                                                                                 
   
MLSDKAPI void mlsdk_decoder_model_resource_table_get_tensor_strides(
    const mlsdk_decoder_model_resource_table_decoder *const modelResourceTableDecoder, uint32_t mrtIdx,
    mlsdk_decoder_tensor_dimensions *dimensions);

                                                                                                                        

   
                                                               
  
                                                   
                                            
                                                               
   
MLSDKAPI bool mlsdk_decoder_is_valid_constant_table(const void *constantTableData, uint64_t size);

   
                                           
  
                                                                  
                                                                                 
                                                   
   
MLSDKAPI mlsdk_decoder_constant_table_decoder *
mlsdk_decoder_create_constant_table_decoder(const void *const constantTableData, void *constantDecoderMemory);

   
                                                                                                            
                                                                                      
   
MLSDKAPI size_t mlsdk_decoder_constant_table_decoder_mem_reqs();

   
                                                                                      
  
                                                                   
                                                           
                                                                 
  
                                                                                  
   
MLSDKAPI void mlsdk_decoder_constant_table_get_data(const mlsdk_decoder_constant_table_decoder *const constantDecoder,
                                                    uint32_t idx, mlsdk_decoder_constant_data *constantData);

   
                                                                                     
  
                                                                   
                                                                
                                                  
   
MLSDKAPI uint32_t mlsdk_decoder_constant_table_get_mrt_index(
    const mlsdk_decoder_constant_table_decoder *const constantDecoder, uint32_t constidx);

   
                                                                 
  
                                                                   
                                                                
                                                       
   
MLSDKAPI bool mlsdk_decoder_constant_table_is_sparse(const mlsdk_decoder_constant_table_decoder *const constantDecoder,
                                                     uint32_t constidx);

   
                                                               
  
                                                                   
                                                                
                                                        
   
MLSDKAPI int64_t mlsdk_decoder_constant_table_get_sparsity_dimension(
    const mlsdk_decoder_constant_table_decoder *const constantDecoder, uint32_t constidx);

   
                                                             
  
                                                                   
                                             
   
MLSDKAPI size_t
mlsdk_decoder_get_constant_table_num_entries(const mlsdk_decoder_constant_table_decoder *const constantDecoder);

       

#ifdef __cplusplus
}
#endif               
#endif                                
