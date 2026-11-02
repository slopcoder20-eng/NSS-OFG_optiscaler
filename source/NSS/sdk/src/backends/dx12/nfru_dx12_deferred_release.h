                                                                                      
                                                                                                                      
                                                                                                                    
                                                                                                                 
                                                                                                 
#pragma once
#include <windows.h>
#include <unknwn.h>
#include <mutex>
#include <vector>
#include <stdint.h>

struct NfruDeferredRelease
{
    struct Item { IUnknown* object; uint64_t tick; uint64_t batch; };
    std::mutex        mutex;
    std::vector<Item> items;
    uint64_t          batches = 0;                                                    

    static NfruDeferredRelease& instance()
    {
        static NfruDeferredRelease* s = new NfruDeferredRelease();                                                   
        return *s;
    }
};

inline void nfruDeferRelease(IUnknown* object)
{
    if (!object) return;
    NfruDeferredRelease& d = NfruDeferredRelease::instance();
    std::lock_guard<std::mutex> lock(d.mutex);
    d.items.push_back({object, GetTickCount64(), d.batches});
}

                                                                                                 
inline void nfruPurgeDeferred(bool countBatch)
{
    NfruDeferredRelease& d = NfruDeferredRelease::instance();
    std::vector<IUnknown*> release;
    {
        std::lock_guard<std::mutex> lock(d.mutex);
        if (countBatch) ++d.batches;
        if (d.items.empty()) return;
        const uint64_t now = GetTickCount64();
        size_t keep = 0;
        for (size_t i = 0; i < d.items.size(); ++i)
        {
            const auto& it = d.items[i];
            if (now - it.tick >= 2000 && d.batches - it.batch >= 16) release.push_back(it.object);
            else d.items[keep++] = it;
        }
        d.items.resize(keep);
    }
    for (IUnknown* o : release) o->Release();                                                       
}
