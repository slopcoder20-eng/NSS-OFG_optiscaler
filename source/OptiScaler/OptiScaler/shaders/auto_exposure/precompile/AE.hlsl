                                                                                              
                                                                                                 
                                                                   

cbuffer Params : register(b0)
{
    uint2 RenderSize;
    uint GroupCountX;
    uint GroupCount;
    float DeltaTime;           
    uint Reset;
    uint PassIndex;
    float PreExposure;
};

Texture2D<float4> Color : register(t0);
                                                                              
RWStructuredBuffer<float> Data : register(u0);
RWTexture2D<float> Exposure : register(u1);

#define THREADS 256
#define TILE 32

static const float Epsilon = 6.10e-05f;
static const float Fp16Max = 65504.0f;

groupshared float Shared[THREADS];

float LogLuma(uint2 pos)
{
                                                                                                  
    const float3 rgb = max(0.0f, Color.Load(int3(pos, 0)).rgb) / PreExposure;
    const float luma = min(dot(rgb, float3(0.2126f, 0.7152f, 0.0722f)), Fp16Max);
    return log(max(Epsilon, luma));
}

float GroupSum(float value, uint tid)
{
    Shared[tid] = value;
    GroupMemoryBarrierWithGroupSync();

    [unroll]
    for (uint stride = THREADS / 2; stride > 0; stride >>= 1)
    {
        if (tid < stride)
            Shared[tid] += Shared[tid + stride];

        GroupMemoryBarrierWithGroupSync();
    }

    return Shared[0];
}

float ComputeAutoExposureFromLavg(float Lavg)
{
    Lavg = exp(Lavg);

    const float S = 100.0f;                        
    const float K = 12.5f;
    const float ExposureISO100 = log2((Lavg * S) / K);

    const float q = 0.65f;
    const float Lmax = (78.0f / (q * S)) * pow(2.0f, ExposureISO100);

    return 1.0f / Lmax;
}

[numthreads(16, 16, 1)]
void CSMain(uint3 gid : SV_GroupID, uint3 gtid : SV_GroupThreadID, uint tid : SV_GroupIndex)
{
    if (PassIndex == 0)
    {
        float sum = 0.0f;

        [unroll]
        for (uint y = 0; y < TILE; y += 16)
        {
            [unroll]
            for (uint x = 0; x < TILE; x += 16)
            {
                const uint2 pos = gid.xy * TILE + gtid.xy + uint2(x, y);

                if (all(pos < RenderSize))
                    sum += LogLuma(pos);
            }
        }

        const float total = GroupSum(sum, tid);

        if (tid == 0)
            Data[1 + gid.y * GroupCountX + gid.x] = total;
    }
    else
    {
        float sum = 0.0f;

        for (uint i = tid; i < GroupCount; i += THREADS)
            sum += Data[1 + i];

        const float total = GroupSum(sum, tid);

        if (tid == 0)
        {
            float logLuma = total / (float(RenderSize.x) * float(RenderSize.y));

            if (Reset == 0)
            {
                const float prevLogLuma = Data[0];
                logLuma = prevLogLuma + (logLuma - prevLogLuma) * (1.0f - exp(-DeltaTime));
            }

            Data[0] = logLuma;
            Exposure[uint2(0, 0)] = ComputeAutoExposureFromLavg(logLuma);
        }
    }
}
