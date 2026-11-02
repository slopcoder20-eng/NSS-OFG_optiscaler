#pragma once

#include "SysUtils.h"
#include "OptiTypes.h"

                                                                                              
  
                                                                                                  
                                                                                          
class FSR4Models
{
  public:
                                                      
    static void Hook(HMODULE module);

    static bool ModuleHasModel(HMODULE module, FSR4Model model);
    static bool CanGpuRun(FSR4Model model);

                                                                                               
    static std::vector<FSR4Model> SelectableModels(HMODULE module);

                                                                     
    static std::optional<FSR4Model> ActiveModel(HMODULE module);

    static const char* Name(FSR4Model model);
};
