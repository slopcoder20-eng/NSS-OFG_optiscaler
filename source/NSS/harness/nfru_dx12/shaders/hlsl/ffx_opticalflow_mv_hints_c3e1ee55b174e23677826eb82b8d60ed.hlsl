static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _266[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _316 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_316.x >= ubo_OutputDims.x, _316.y >= ubo_OutputDims.y)))
        {
            break;
        }
        int2 _362 = _316 * (ubo_DepthDims / ubo_OutputDims);
        int2 _369 = ubo_DepthDims - int2(1, 1);
        float _335[9];
        _335[0] = r_depth_tm1.Load(int3(clamp(_362, int2(0, 0), _369), 0)).x;
        _335[1] = r_depth_tm1.Load(int3(clamp(_362 + int2(1, 0), int2(0, 0), _369), 0)).x;
        _335[2] = r_depth_tm1.Load(int3(clamp(_362 + int2(0, 1), int2(0, 0), _369), 0)).x;
        _335[3] = r_depth_tm1.Load(int3(clamp(_362 + int2(0, -1), int2(0, 0), _369), 0)).x;
        _335[4] = r_depth_tm1.Load(int3(clamp(_362 + int2(-1, 0), int2(0, 0), _369), 0)).x;
        _335[5] = r_depth_tm1.Load(int3(clamp(_362 + int2(-1, 1), int2(0, 0), _369), 0)).x;
        _335[6] = r_depth_tm1.Load(int3(clamp(_362 + int2(1, 1), int2(0, 0), _369), 0)).x;
        _335[7] = r_depth_tm1.Load(int3(clamp(_362 + int2(-1, -1), int2(0, 0), _369), 0)).x;
        _335[8] = r_depth_tm1.Load(int3(clamp(_362 + int2(1, -1), int2(0, 0), _369), 0)).x;
        int _574;
        _574 = 0;
        float _579;
        int _580;
        int _573 = 1;
        float _575 = _335[0];
        for (; _573 < 9; _575 = _579, _574 = _580, _573++)
        {
            bool _459 = _335[_573] < _575;
            _579 = _459 ? _335[_573] : _575;
            _580 = _459 ? _573 : _574;
        }
        float2 _482 = clamp((float2(_362 + _266[_574]) + 0.5f.xx) * ubo_InvDepthDims, 0.0f.xx, 1.0f.xx);
        float2 _514 = float2(_482.x, 1.0f - _482.y);
        float4 _525 = mul(float4((_514 * 2.0f) - 1.0f.xx, _335[_574], 1.0f), ubo_MotionMatM1P1);
        float2 _537 = _514 - (((_525.xy / _525.w.xx) + 1.0f.xx) * 0.5f);
        float2 _539 = abs(_537);
        bool2 _545 = all(bool2(_539.x < 9.9999997473787516355514526367188e-06f.xx.x, _539.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _546 = float2(_545.x ? 0.0f.xx.x : _537.x, _545.y ? 0.0f.xx.y : _537.y);
        bool2 _551 = any(isnan(_546)).xx;
        float2 _552 = float2(_551.x ? 0.0f.xx.x : _546.x, _551.y ? 0.0f.xx.y : _546.y);
        bool2 _557 = any(isinf(_552)).xx;
        float2 _558 = float2(_557.x ? 0.0f.xx.x : _552.x, _557.y ? 0.0f.xx.y : _552.y);
        rw_motion_vectors[_316] = float4(float2(-_558.x, _558.y) * float2(ubo_ColorDims), 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
