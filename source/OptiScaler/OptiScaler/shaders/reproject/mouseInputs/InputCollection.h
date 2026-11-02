#pragma once

#include <shared_mutex>
#include <vector>
#include <DirectXMath.h>

struct InputDelta
{
    int32_t x;
    int32_t y;
    uint64_t startTimestampNs;

                                                                
    constexpr InputDelta& operator+=(const InputDelta& other)
    {
        x += other.x;
        y += other.y;
        return *this;
    }

    constexpr InputDelta& operator-=(const InputDelta& other)
    {
        x -= other.x;
        y -= other.y;
        return *this;
    }

    constexpr InputDelta& operator*=(double mul)
    {
        x = static_cast<int32_t>(x * mul);
        y = static_cast<int32_t>(y * mul);
        return *this;
    }

    constexpr InputDelta& operator/=(double div)
    {
        x = static_cast<int32_t>(x / div);
        y = static_cast<int32_t>(y / div);
        return *this;
    }

    constexpr InputDelta operator+(const InputDelta& other) const { return InputDelta { x + other.x, y + other.y }; }

    constexpr InputDelta operator-(const InputDelta& other) const { return InputDelta { x - other.x, y - other.y }; }

    constexpr InputDelta operator*(double mul) const
    {
        return InputDelta { static_cast<int32_t>(x * mul), static_cast<int32_t>(y * mul) };
    }

    constexpr InputDelta operator/(double div) const
    {
        return InputDelta { static_cast<int32_t>(x / div), static_cast<int32_t>(y / div) };
    }

                    
    operator DirectX::XMINT2() const { return { x, y }; }
};

class InputCollection
{
    std::shared_mutex mutex;
    std::shared_mutex simDeltasMutex;

    InputDelta simToPresentDeltas[8] {};
    InputDelta inProgressSimToSimDelta {};                                  
    InputDelta simToSimDeltas[8] {};                          

                                                                                                            
    uint32_t cumulativeX = 0;
    uint32_t cumulativeY = 0;
    DirectX::XMINT2 simStartCumulative[8] {};

                                                                                         
    uint64_t lastSimFrameId = UINT64_MAX;

                                                                                                  
    std::vector<volatile uint64_t*> liveSinks;

    void writeLiveSinks();

  public:
    static InputCollection& getInstance()
    {
        static InputCollection instance;
        return instance;
    }

    void addNewDelta(InputDelta delta);

                                                                                           
    void startCollectingForFrame(uint64_t frameId);

                                                                          
    InputDelta readSimsDelta(uint64_t frameId);

                                                                       
    InputDelta readDeltaSinceSim(uint64_t frameId);

                                                                            
    DirectX::XMINT2 readCumulativeAtSim(uint64_t frameId);

                                                                                                 
    void registerLiveSink(void* sink);
    void unregisterLiveSink(void* sink);
};