cbuffer Params : register(b0)
{
    uint ScreenWidth;
    uint ScreenHeight;
    float InvScreenWidth;
    float InvScreenHeight;

    uint DepthWidth;
    uint DepthHeight;
    float2 _Pad0;

    float UiDiffThreshold;
    float DepthCutoff;
    float DitherWidthPx;
    uint CutoffExpandPx;

    uint EdgeMode;
    uint ShowStaticElements;
    uint InvertedDepth;
    uint FakeFrame;                               

    float TanHalfFovX;
    float TanHalfFovY;
    float InvTanHalfFovX;
    float InvTanHalfFovY;

    float4 CameraRight;
    float4 CameraUp;
    float4 CameraForward;
    float4 Calibration;                                              

    float PixelAngle;
    float YawSign;
    float PitchSign;
    uint LateLatch;

    int2 MouseDelta;
    int2 SimStartMouse;

    float4 CameraDelta;                                                                              

    float CameraNear;
    float CameraFar;                
    uint CacheSize;
    float InvCacheSize;

    uint CacheEnabled;
    uint CacheReset;
    float CacheDecay;
    float CacheMaxDistance;

                                                         
    float4 PrevViewX;                                                                                         
    float4 PrevViewY;
    float4 PrevViewZ;
    float4 PrevViewMove;                                                                                          
                                                                                                 

    float2 MvToUv;                                                    
    uint MvWidth;
    uint MvHeight;

    float OrbitPivotDepth;                                                                                    
    float3 _Pad1;
};

Texture2D<float3> Hudless : register(t0);
Texture2D<float> Depth : register(t2);
Texture2D<float> DepthMask : register(t4);
TextureCube<float3> PrevCacheColor : register(t6);
TextureCube<float2> PrevCacheGeo : register(t7);

                                                                                             
                                                                          
                                                               
#ifdef VK_MODE
[[vk::image_format("rgba16f")]]
#endif
RWTexture2DArray<float3> CacheColorOut : register(u4);
#ifdef VK_MODE
[[vk::image_format("rg16f")]]
#endif
RWTexture2DArray<float2> CacheGeoOut : register(u5);

SamplerState BilinearClampSampler : register(s1);

                         
bool IsDepthCutout(float2 uv)
{
    int2 maskPixel = int2(uv * float2(DepthWidth - 1, DepthHeight - 1));
    return DepthMask.Load(int3(maskPixel, 0)) > 0.5f;
}

float LinearViewZ(float2 uv)
{
    int2 depthPixel = min(int2(uv * float2(DepthWidth, DepthHeight)), int2(DepthWidth - 1, DepthHeight - 1));
    float d = Depth.Load(int3(depthPixel, 0));

    if (InvertedDepth)
    {
        if (CameraFar <= 0.0f)
            return CameraNear / d;

        return CameraNear * CameraFar / (CameraNear + d * (CameraFar - CameraNear));
    }

    if (CameraFar <= 0.0f)
        return CameraNear / (1.0f - d);

    return CameraNear * CameraFar / (CameraFar - d * (CameraFar - CameraNear));
}

                       
float3 CubeTexelDir(uint3 id)
{
    float2 st = (float2(id.xy) + 0.5f) * InvCacheSize * 2.0f - 1.0f;
    float u = st.x;
    float v = st.y;

    float3 dir;
    if (id.z == 0)
        dir = float3(1.0f, -v, -u);
    else if (id.z == 1)
        dir = float3(-1.0f, -v, u);
    else if (id.z == 2)
        dir = float3(u, 1.0f, v);
    else if (id.z == 3)
        dir = float3(u, -1.0f, -v);
    else if (id.z == 4)
        dir = float3(u, -v, 1.0f);
    else
        dir = float3(-u, -v, -1.0f);

    return normalize(dir);
}

bool SamplePrev(float3 dir, out float3 color, out float dist, out float weight)
{
    float2 geo = PrevCacheGeo.SampleLevel(BilinearClampSampler, dir, 0.0f);
    weight = geo.y;

    if (weight < 0.01f)
    {
        color = 0.0f;
        dist = 0.0f;
        return false;
    }

    color = PrevCacheColor.SampleLevel(BilinearClampSampler, dir, 0.0f) / weight;
    dist = geo.x / weight;
    return true;
}

void WriteCache(uint3 id, float3 color, float dist, float weight)
{
                                                            
    dist = (dist >= 0.0f && dist < CacheMaxDistance) ? dist : CacheMaxDistance;

    CacheColorOut[id] = color * weight;
    CacheGeoOut[id] = float2(dist * weight, weight);
}

                                                        
                                                                                                  
                                                                 
[numthreads(8, 8, 1)]
void CSMain(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= CacheSize || id.y >= CacheSize)
        return;

    float3 dir = CubeTexelDir(id);

                                                                                                       
    float3 view = float3(dot(dir, CameraRight.xyz), dot(dir, CameraUp.xyz), dot(dir, CameraForward.xyz));

    if (view.z > 0.0001f)
    {
        float2 ndc = (view.xy / view.z) * float2(InvTanHalfFovX, InvTanHalfFovY);
        float2 uv = ndc * float2(0.5f, -0.5f) + 0.5f;

                                                                                           
        if (all(uv > 0.0f) && all(uv < 1.0f) && !IsDepthCutout(uv))
        {
            float3 color = Hudless.SampleLevel(BilinearClampSampler, uv, 0.0f);
            WriteCache(id, color, LinearViewZ(uv) / view.z, 1.0f);
            return;
        }
    }

    if (CacheReset)
    {
        WriteCache(id, 0.0f, 0.0f, 0.0f);
        return;
    }

    float3 color;
    float dist;
    float weight;

    if (!SamplePrev(dir, color, dist, weight))
    {
        WriteCache(id, 0.0f, 0.0f, 0.0f);
        return;
    }

                                                              
                                                                                                 
    float t = dist;
    float3 prevDir = dir;

    [unroll]
    for (int i = 0; i < 3; ++i)
    {
        prevDir = normalize(dir * t + CameraDelta.xyz);

        if (!SamplePrev(prevDir, color, dist, weight))
        {
            WriteCache(id, 0.0f, 0.0f, 0.0f);
            return;
        }

        float3 surface = prevDir * dist - CameraDelta.xyz;
        t = max(dot(surface, dir), CameraNear);
    }

                                                                                                             
                                                                                
    if (dot(prevDir, dir) < 0.996f)              
    {
        WriteCache(id, 0.0f, 0.0f, 0.0f);
        return;
    }

    WriteCache(id, color, t, saturate(weight - CacheDecay));
}
