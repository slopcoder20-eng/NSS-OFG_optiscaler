#pragma once

#include "XeFG_DynamicCount.h"
#include "XeFG_DynamicCap.h"

#include <Windows.h>

                                                                                                    
class XeFG_DynamicMFG
{
  public:
    struct Result
    {
        bool dynamic = false;                                     
        bool ownChange = false;                                                                           
        int count = 1;                                                                         
        bool generationOff = false;                           
    };

                                                                                  
    Result Update(int targetCount, int framesToInterpolate, bool generationOff, double presentWaitMs, HWND window);

                                                                  
    void Restart();

  private:
    XeFG_DynamicCount _count;
    XeFG_DynamicCap _cap;                                                                       
    bool _active = false;
    bool _capActive = false;
    double _logMs = 0.0;
    int _refreshRate = 0;
    double _refreshCheckedMs = 0.0;
    bool _unfocused = false;                                                      

                                                                              
    static int Focused(HWND window);
    float DisplayRefreshFps(double nowMs, HWND window);
    float TargetFps(double nowMs, HWND window);
};
