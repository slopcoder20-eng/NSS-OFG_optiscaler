#pragma once
#include "SysUtils.h"

#include <functional>

                                                               
                                                                                                       
                                                                                                     
                                                                                                            
namespace DeferredRelease
{
                                                                                                
void Enqueue(std::function<void()> destroy, uint64_t owner = 0);

                        
void Process();

                                                                                           
                                                                                                  
void Collect();

                                                                                                                  
                                                                                 
void DropOwnersExcept(uint64_t keep);

template <typename T> void Release(T*& object)
{
    if (object == nullptr)
        return;

    auto* captured = object;
    object = nullptr;

    Enqueue([captured]() { captured->Release(); });
}
}                             
