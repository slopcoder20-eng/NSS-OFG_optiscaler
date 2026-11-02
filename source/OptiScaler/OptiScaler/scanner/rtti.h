#pragma once

#include "SysUtils.h"

                                                                                                    
                                                                     
namespace rtti
{
                                                                                           
                                                                                                              
void** FindVtable(HMODULE module, std::string_view className);

                                                                     
size_t CountVirtualFunctions(HMODULE module, void** vtable);

}                  
