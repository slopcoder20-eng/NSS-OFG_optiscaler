                                                                                         
            

#pragma once
#include "../../imgui.h"                  
#ifndef IMGUI_DISABLE

         
                                                                                         
                                                                                        
                                                            

                                           
                                                                                            
                                                                                          

                       
struct ImFontAtlas;
struct ImFontLoader;

                                                     
                                                                                                   
                                                                                               
                                                                                           
                                                                                               
                                                                    
                                                                                
enum ImGuiFreeTypeBuilderFlags
{
    ImGuiFreeTypeBuilderFlags_NoHinting     = 1 << 0,                                                                                                                                      
    ImGuiFreeTypeBuilderFlags_NoAutoHint    = 1 << 1,                          
    ImGuiFreeTypeBuilderFlags_ForceAutoHint = 1 << 2,                                                                                
    ImGuiFreeTypeBuilderFlags_LightHinting  = 1 << 3,                                                                                                                                                                                                                                                                                                                                                     
    ImGuiFreeTypeBuilderFlags_MonoHinting   = 1 << 4,                                                                              
    ImGuiFreeTypeBuilderFlags_Bold          = 1 << 5,                                                        
    ImGuiFreeTypeBuilderFlags_Oblique       = 1 << 6,                                                                
    ImGuiFreeTypeBuilderFlags_Monochrome    = 1 << 7,                                                                            
    ImGuiFreeTypeBuilderFlags_LoadColor     = 1 << 8,                                          
    ImGuiFreeTypeBuilderFlags_Bitmap        = 1 << 9                                    
};

namespace ImGuiFreeType
{
                                                                                 
                                                                   
                                                                                                       
                                                                                                                          
    IMGUI_API const ImFontLoader*       GetFontLoader();

                                                                                  
                                                                                                                                       
    IMGUI_API void                      SetAllocatorFunctions(void* (*alloc_func)(size_t sz, void* user_data), void (*free_func)(void* ptr, void* user_data), void* user_data = nullptr);

                                                                                                  
    IMGUI_API bool                      DebugEditFontBuilderFlags(unsigned int* p_font_loader_flags);

                                       
#ifndef IMGUI_DISABLE_OBSOLETE_FUNCTIONS
                                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                               
#endif
}

#endif                         
