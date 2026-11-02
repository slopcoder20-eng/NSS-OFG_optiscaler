static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _271[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

cbuffer Uniforms : register(b0, space0)
{
    row_major float4x4 ubo_MotionMatM1P1 : packoffset(c0);
    int2 ubo_OutputDims : packoffset(c4);
    int2 ubo_DepthDims : packoffset(c4.z);
    float2 ubo_InvDepthDims : packoffset(c5);
    int2 ubo_ColorDims : packoffset(c5.z);
};

Texture2D<float4> r_depth_tm1 : register(t1, space0);
RWTexture2D<float2> rw_motion_vectors : register(u2, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

void comp_main()
{
    int2 _324 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_324.x >= ubo_OutputDims.x, _324.y >= ubo_OutputDims.y)))
        {
            break;
        }
        int2 _370 = _324 * (ubo_DepthDims / ubo_OutputDims);
        int2 _377 = ubo_DepthDims - int2(1, 1);
        float _343[9];
        _343[0] = r_depth_tm1.Load(int3(clamp(_370, int2(0, 0), _377), 0)).x;
        _343[1] = r_depth_tm1.Load(int3(clamp(_370 + int2(1, 0), int2(0, 0), _377), 0)).x;
        _343[2] = r_depth_tm1.Load(int3(clamp(_370 + int2(0, 1), int2(0, 0), _377), 0)).x;
        _343[3] = r_depth_tm1.Load(int3(clamp(_370 + int2(0, -1), int2(0, 0), _377), 0)).x;
        _343[4] = r_depth_tm1.Load(int3(clamp(_370 + int2(-1, 0), int2(0, 0), _377), 0)).x;
        _343[5] = r_depth_tm1.Load(int3(clamp(_370 + int2(-1, 1), int2(0, 0), _377), 0)).x;
        _343[6] = r_depth_tm1.Load(int3(clamp(_370 + int2(1, 1), int2(0, 0), _377), 0)).x;
        _343[7] = r_depth_tm1.Load(int3(clamp(_370 + int2(-1, -1), int2(0, 0), _377), 0)).x;
        _343[8] = r_depth_tm1.Load(int3(clamp(_370 + int2(1, -1), int2(0, 0), _377), 0)).x;
        int _585;
        _585 = 0;
        float _590;
        int _591;
        int _584 = 1;
        float _586 = _343[0];
        for (; _584 < 9; _586 = _590, _585 = _591, _584++)
        {
            bool _467 = _343[_584] < _586;
            _590 = _467 ? _343[_584] : _586;
            _591 = _467 ? _584 : _585;
        }
        float2 _490 = clamp((float2(_370 + _271[_585]) + 0.5f.xx) * ubo_InvDepthDims, 0.0f.xx, 1.0f.xx);
        float2 _523 = float2(_490.x, 1.0f - _490.y);
        float4 _534 = mul(float4((_523 * 2.0f) - 1.0f.xx, _343[_585], 1.0f), ubo_MotionMatM1P1);
        min16float2 _547 = min16float2(_523 - (((_534.xy / _534.w.xx) + 1.0f.xx) * 0.5f));
        min16float2 _549 = abs(_547);
        bool2 _555 = all(bool2(_549.x < min16float(9.953975677490234375e-06).xx.x, _549.y < min16float(9.953975677490234375e-06).xx.y)).xx;
        min16float2 _556 = min16float2(_555.x ? min16float(0.0).xx.x : _547.x, _555.y ? min16float(0.0).xx.y : _547.y);
        bool2 _561 = any(isnan(_556)).xx;
        min16float2 _562 = min16float2(_561.x ? min16float(0.0).xx.x : _556.x, _561.y ? min16float(0.0).xx.y : _556.y);
        bool2 _567 = any(isinf(_562)).xx;
        min16float2 _568 = min16float2(_567.x ? min16float(0.0).xx.x : _562.x, _567.y ? min16float(0.0).xx.y : _562.y);
        rw_motion_vectors[_324] = float4(min16float4(min16float2(-_568.x, _568.y) * min16float2(ubo_ColorDims), min16float(0.0), min16float(0.0))).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
