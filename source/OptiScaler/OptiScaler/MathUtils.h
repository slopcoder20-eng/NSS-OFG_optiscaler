#pragma once
#include <numbers>
#include <cmath>

namespace OptiMath
{
                                                              
inline constexpr float DegToRad = std::numbers::pi_v<float> / 180.0f;
                                                              
inline constexpr float RadToDeg = 180.0f / std::numbers::pi_v<float>;

                                               
[[nodiscard]] inline constexpr float GetRadiansFromDeg(const float deg) { return deg * DegToRad; }

                                               
[[nodiscard]] inline constexpr float GetDegreesFromRad(const float rad) { return rad * RadToDeg; }

   
                                                                                            
                                                                                                  
                                           
                                             
                                               
                                  
   
[[nodiscard]] inline float GetVerticalFovFromHorizontal(const float hFovRad, const float width, const float height)
{
    if (width <= 0.0f)
        return 0.0f;
    return 2.0f * std::atan(std::tan(hFovRad * 0.5f) * (height / width));
}

   
                                                                                            
                                                                                                  
                                                    
                                             
                                               
                                    
   
[[nodiscard]] inline float GetHorizontalFovFromVertical(const float vFovRad, const float width, const float height)
{
    if (height <= 0.0f)
        return 0.0f;
    return 2.0f * std::atan(std::tan(vFovRad * 0.5f) * (width / height));
}
}                      