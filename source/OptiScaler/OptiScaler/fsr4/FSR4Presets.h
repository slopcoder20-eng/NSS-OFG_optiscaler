#pragma once

#include "SysUtils.h"

                                                                                     
  
                                                                                                               
                                                                                                      
                                                                                
class FSR4Presets
{
  public:
                                                      
    static void Hook(HMODULE module);

    static bool IsAnyModuleHooked();
    static bool IsModuleHooked(HMODULE module);
};
