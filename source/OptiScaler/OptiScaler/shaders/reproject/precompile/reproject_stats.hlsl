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

Texture2D<float> Depth : register(t2);
Texture2D<float> DepthMask : register(t4);
Texture2D<float2> Velocity : register(t10);

                                                                                                          
RWStructuredBuffer<uint> StatsOut : register(u6);

#define STATS_BINS 128
#define STATS_COUNTERS 12
#define LOG_SCALE_MIN -3.0f
#define LOG_SCALE_MAX 6.0f

#define GRID_X 128
#define GRID_Y 72
#define THREADS 256

                                                                                                       
#define MIN_EXPECTED_PX 8.0f

           
#define CENTER_SAMPLES 0                                               
#define CENTER_VALID 1                                                                     
#define CENTER_LOCKED 2                                                              
#define OUTER_VALID 3                                                                                
#define OUTER_MATCH 4                                                                              
#define CENTER_AT_PIVOT 5                                                                                
#define OUTER_X_VALID 6                                                                                       
#define OUTER_X_OPPOSITE 7                                                                                    
#define OUTER_Y_VALID 8                    
#define OUTER_Y_OPPOSITE 9                               
#define MOVE_ALONG 10                                                         
#define MOVE_AGAINST 11                                                                                    

groupshared uint Histogram[STATS_BINS];
groupshared uint Counters[STATS_COUNTERS];

                         
bool IsDepthCutout(float2 uv)
{
    int2 maskPixel = int2(uv * float2(DepthWidth - 1, DepthHeight - 1));
    return DepthMask.Load(int3(maskPixel, 0)) > 0.5f;
}

float3 RayFromUV(float2 uv)
{
    float2 ndc = uv * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
    return float3(ndc * float2(TanHalfFovX, TanHalfFovY), 1.0f);
}

bool ProjectRay(float3 ray, out float2 uv)
{
    uv = 0.0f;

    if (ray.z <= 0.00001f)
        return false;

    float2 ndc = (ray.xy / ray.z) * float2(InvTanHalfFovX, InvTanHalfFovY);
    uv = ndc * float2(0.5f, -0.5f) + 0.5f;
    return true;
}

                                                      
bool Matches(float2 measuredPx, float2 expectedPx)
{
    float measuredLen = length(measuredPx);
    float expectedLen = length(expectedPx);

    return dot(measuredPx, expectedPx) > 0.7f * measuredLen * expectedLen && measuredLen > 0.5f * expectedLen &&
           measuredLen < 2.0f * expectedLen;
}

                                                                    
float LinearViewZ(float d)
{
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

                                                                                                           
  
                                                                                                              
                                                                                                                     
                                                                                                         
                                                                                                                    
                                                                                                     
                                                                                                                  
                                                                                       
  
                                                                                                                  
                                                                                                                  
                                                                                                         
[numthreads(16, 16, 1)]
void CSMain(uint groupIndex : SV_GroupIndex)
{
    for (uint i = groupIndex; i < STATS_BINS; i += THREADS)
        Histogram[i] = 0;

    if (groupIndex < STATS_COUNTERS)
        Counters[groupIndex] = 0;

    GroupMemoryBarrierWithGroupSync();

    const float2 screenPx = float2(ScreenWidth, ScreenHeight);
    const float2 invTan = float2(InvTanHalfFovX, InvTanHalfFovY);
    const bool parallax = CameraNear > 0.0f && dot(PrevViewMove.xyz, PrevViewMove.xyz) > 0.0f;
    const bool knownScale = CameraNear > 0.0f && PrevViewMove.w > 0.0f;
    const float binsPerDecade = STATS_BINS / (LOG_SCALE_MAX - LOG_SCALE_MIN);

    [loop]
    for (uint s = groupIndex; s < GRID_X * GRID_Y; s += THREADS)
    {
        float2 uv = (float2(s % GRID_X, s / GRID_X) + 0.5f) / float2(GRID_X, GRID_Y);

        if (IsDepthCutout(uv))
            continue;

        int2 depthPixel = min(int2(uv * float2(DepthWidth, DepthHeight)), int2(DepthWidth - 1, DepthHeight - 1));
        float d = Depth.Load(int3(depthPixel, 0));

                                          
        if (InvertedDepth ? d <= 0.0f : d >= 1.0f)
            continue;

        int2 mvPixel = min(int2(uv * float2(MvWidth, MvHeight)), int2(MvWidth - 1, MvHeight - 1));
        float2 measured = uv + Velocity.Load(int3(mvPixel, 0)) * MvToUv;

                                                                                
        float3 ray = RayFromUV(uv);
        float3 rotated = float3(dot(ray, PrevViewX.xyz), dot(ray, PrevViewY.xyz), dot(ray, PrevViewZ.xyz));

        float2 rotatedUV;
        if (!ProjectRay(rotated, rotatedUV))
            continue;

        float viewZ = LinearViewZ(d);

                                                                                  
        float2 expectedUV = rotatedUV;
        if (knownScale && !ProjectRay(rotated * viewZ + PrevViewMove.xyz * PrevViewMove.w, expectedUV))
            continue;

        float2 expectedPx = (expectedUV - uv) * screenPx;
        float2 rotationPx = (rotatedUV - uv) * screenPx;
        float2 measuredPx = (measured - uv) * screenPx;
        float expectedLen = length(expectedPx);
        float measuredLen = length(measuredPx);

        bool center = all(uv > float2(0.3f, 0.3f)) && all(uv < float2(0.7f, 0.9f));

        if (center)
        {
                                                                                                            
            if (knownScale)
            {
                InterlockedAdd(Counters[CENTER_SAMPLES], 1);

                if (viewZ > 0.5f * OrbitPivotDepth && viewZ < 1.3f * OrbitPivotDepth)
                    InterlockedAdd(Counters[CENTER_AT_PIVOT], 1);

                if (expectedLen >= MIN_EXPECTED_PX)
                {
                    InterlockedAdd(Counters[CENTER_VALID], 1);

                    if (measuredLen < 0.25f * expectedLen)
                        InterlockedAdd(Counters[CENTER_LOCKED], 1);
                }
            }
        }
        else if (max(expectedLen, length(rotationPx)) >= MIN_EXPECTED_PX)
        {
            InterlockedAdd(Counters[OUTER_VALID], 1);

                                                                                                                   
                                                                
            if (Matches(measuredPx, expectedPx) || Matches(measuredPx, rotationPx))
                InterlockedAdd(Counters[OUTER_MATCH], 1);

                                                                                                 
                                                                
                                                                                                                     
                                                                                                                
                                                                                                      
            float2 movePx = knownScale ? expectedPx - rotationPx : 0.0f;
            float2 rotationOnlyPx = measuredPx - movePx;

            [unroll]
            for (int a = 0; a < 2; ++a)
            {
                if (abs(rotationPx[a]) >= MIN_EXPECTED_PX && abs(movePx[a]) < 0.5f * abs(rotationPx[a]) &&
                    abs(rotationOnlyPx[a]) >= 1.0f)
                {
                    InterlockedAdd(Counters[OUTER_X_VALID + 2 * a], 1);

                    if (rotationOnlyPx[a] * rotationPx[a] < 0.0f)
                        InterlockedAdd(Counters[OUTER_X_OPPOSITE + 2 * a], 1);
                }
            }
        }

                                                                    
        if (!parallax || length(measuredPx - rotationPx) < 1.5f)
            continue;

                                                                                                               
                                                                                 
        float3 a = rotated * viewZ;
        float3 b = PrevViewMove.xyz;
        float2 ndc = measured * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);

        float2 c = invTan * b.xy - ndc * b.z;
        float2 e = ndc * a.z - invTan * a.xy;

        float cc = dot(c, c);
        if (!(cc > 1e-20f))
            continue;

        float k = dot(c, e) / cc;
        if (!(abs(k) > 0.0f))
            continue;

                                                                
        if (length(e - k * c) > 0.35f * length(e))
            continue;

        if (k < 0.0f)
        {
            InterlockedAdd(Counters[MOVE_AGAINST], 1);
            continue;
        }

        InterlockedAdd(Counters[MOVE_ALONG], 1);

        int bin = int(floor((-log10(k) - LOG_SCALE_MIN) * binsPerDecade));
        if (bin >= 0 && bin < STATS_BINS)
            InterlockedAdd(Histogram[bin], 1);
    }

    GroupMemoryBarrierWithGroupSync();

    for (uint j = groupIndex; j < STATS_BINS; j += THREADS)
        StatsOut[j] = Histogram[j];

    if (groupIndex < STATS_COUNTERS)
        StatsOut[STATS_BINS + groupIndex] = Counters[groupIndex];
}
