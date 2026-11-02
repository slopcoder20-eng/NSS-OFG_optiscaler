#pragma once

#include <mutex>
#include <shared_mutex>

namespace Dx11wDx12Sync
{
                                                                         
inline std::shared_mutex& PresentResizeMutex()
{
    static std::shared_mutex mutex;
    return mutex;
}
}                           
