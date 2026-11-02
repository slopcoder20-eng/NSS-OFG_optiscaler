                                                              
                                                                                  

                        
                                                                                              
                                                                        
                                                                                                                                                                              
                                                                                                      
                                                                                                                           

           
                                                                                                                 
                                                                                                                

                                                                                                              
                                                                                                                                              
                                                                                                      
                                                                 

#pragma once
#include "imgui.h"                       

IMGUI_IMPL_API bool     ImGui_ImplUwp_Init(void* core_window);                                        
IMGUI_IMPL_API bool     ImGui_ImplUwp_InitForCurrentView();
IMGUI_IMPL_API bool     ImGui_ImplUwp_InitForSwapChainPanel(void* swapchain_panel);                                                      
IMGUI_IMPL_API void     ImGui_ImplUwp_Shutdown();
IMGUI_IMPL_API void     ImGui_ImplUwp_NewFrame(ImVec2 displaySize);

typedef void (*PFN_KeyUp)(unsigned int vKey);
void ImGui_BindUwpKeyUp(PFN_KeyUp keyUpMethod);
