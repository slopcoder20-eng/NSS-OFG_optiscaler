#ifdef VK_MODE
cbuffer Params : register(b0, space0)
#else
cbuffer MagnifierCB : register(b0)
#endif
{
    float2 Resolution;                                          
    int2 CursorPos;                                        
    
    float2 Offset;                                                         
    float Radius;                                              
    int ZoomFactor;                                              
    
    float BorderThickness;                                             
    float3 Padding;                                         
};

#ifdef VK_MODE
[[vk::binding(1, 0)]]
#endif
Texture2D<float4> InTexture : register(t0);

#ifdef VK_MODE
[[vk::binding(2, 0)]]
#endif
RWTexture2D<float4> OutTexture : register(u0);

[numthreads(16, 16, 1)]
void CSMain(uint3 dispatchThreadId : SV_DispatchThreadID)
{
                                                                                      
    if (dispatchThreadId.x >= (uint) Resolution.x || dispatchThreadId.y >= (uint) Resolution.y)
    {
        return;
    }

                                                
    int2 currentPixelInt = dispatchThreadId.xy;
    float2 currentPixel = float2(currentPixelInt);
    
                                                     
    float2 lensCenter = float2(CursorPos) + Offset;
    
                                                                     
    float2 vecToCenter = currentPixel - lensCenter;
    float dist = length(vecToCenter);
    
    float4 finalColor;
    
                                                                  
    if (dist > Radius)
    {
        finalColor = InTexture.Load(int3(currentPixelInt, 0));
    }
                                        
    else if (dist > Radius - BorderThickness)
    {
        finalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);                
    }
                                                     
    else
    {
        int maxZoom = max(1, ZoomFactor);                            
        int2 scaledOffset = int2(floor(vecToCenter / (float) maxZoom));
        
                                                                                  
        int2 srcPixel = CursorPos + scaledOffset;
        
                                                                                 
        srcPixel = clamp(srcPixel, int2(0, 0), int2(Resolution) - int2(1, 1));
        
        finalColor = InTexture.Load(int3(srcPixel, 0));
    }
    
                                                          
    OutTexture[currentPixelInt] = finalColor;
}