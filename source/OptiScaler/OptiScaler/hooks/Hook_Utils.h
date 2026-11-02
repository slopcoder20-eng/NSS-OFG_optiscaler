#pragma once

#include <type_traits>

                                                               
                                                                                                         
template <typename T> struct rewrite_signature;
template <typename Ret, typename Class, typename... Args> struct rewrite_signature<Ret (Class::*)(Args...)>
{
    using type = Ret(WINAPI*)(Class*, Args...);
};

                                                                              
#define VALIDATE_MEMBER_HOOK(HookName, PfnType)                                                                        \
    static_assert(std::is_same_v<decltype(&HookName), PfnType>,                                                        \
                  "Signature mismatch: " #HookName " does not match " #PfnType);

                                                                         
                                                          
                                                                
#define VALIDATE_HOOK(HookName, PfnType)                                                                               \
    extern std::remove_pointer_t<PfnType> HookName;                                                                    \
    VALIDATE_MEMBER_HOOK(HookName, PfnType)