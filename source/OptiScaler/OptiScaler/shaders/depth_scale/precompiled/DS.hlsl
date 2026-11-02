cbuffer Params : register(b0)
{
    float DepthScale;
};

                
Texture2D<float> SourceTexture : register(t0);

                 
RWTexture2D<float> DestinationTexture : register(u0);

                                   
[numthreads(16, 16, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
                                                        
    uint2 pixelCoord = dispatchThreadID.xy;

                                                   
    float srcColor = SourceTexture.Load(int3(pixelCoord, 0));
    float normalizedColor = srcColor / DepthScale;

                                                       
    DestinationTexture[pixelCoord] = saturate(normalizedColor);
}
