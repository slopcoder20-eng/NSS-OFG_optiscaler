static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const float _896[3] = { 8.0f, 3.0f, 1.5f };

cbuffer cbFI_t : register(b4, space0)
{
    row_major float4x4 cbFI_MotionTM1ToTP1 : packoffset(c0);
    row_major float4x4 cbFI_MotionTP1ToTM1 : packoffset(c4);
    float4 cbFI_QuantParamsSINT : packoffset(c8);
    float4 cbFI_QuantParamsSNORM : packoffset(c9);
    float4 cbFI_DeviceToViewDepth : packoffset(c10);
    int2 cbFI_RenderSize : packoffset(c11);
    int2 cbFI_DisplaySize : packoffset(c11.z);
    int2 cbFI_OfSize : packoffset(c12);
    float2 cbFI_RenderSizeRcp : packoffset(c12.z);
    float2 cbFI_DisplaySizeRcp : packoffset(c13);
    float2 cbFI_OfSizeRcp : packoffset(c13.z);
    float2 cbFI_Jitter : packoffset(c14);
    float2 cbFI_MotionVectorScale : packoffset(c14.z);
    float2 cbFI_MvSimilarityThresholds : packoffset(c15);
    int2 cbFI_InputTensorSize : packoffset(c15.z);
    float2 cbFI_InputTensorSizeRcp : packoffset(c16);
    int cbFI_Reset : packoffset(c16.z);
    float cbFI_Timestep : packoffset(c16.w);
    uint cbFI_RandomSeed : packoffset(c17);
    uint cbFI_pad0 : packoffset(c17.y);
    int2 cbFI_MvDepthLaneSize : packoffset(c17.z);
    float2 cbFI_MvDepthLaneSizeRcp : packoffset(c18);
    int2 cbFI_FlowLaneSize : packoffset(c18.z);
    float2 cbFI_FlowLaneSizeRcp : packoffset(c19);
    float cbFI_OfGridSizeRcp : packoffset(c19.z);
    row_major float4x4 cbFI_MotionTM1ToTM2 : packoffset(c20);
    uint cbFI_NfruT2Flags : packoffset(c24);
};

RWByteAddressBuffer rw_nfru_diagnostics : register(u8, space0);
Texture2D<float4> r_motion_tp1 : register(t5, space0);
Texture2D<float4> r_depth_tp1 : register(t6, space0);
Texture2D<float4> r_depth_tm1 : register(t7, space0);
RWTexture2D<uint> rw_warped_motion_qdata_tp1 : register(u0, space0);
RWTexture2D<uint> rw_warped_flow_qdata_tm1 : register(u1, space0);
RWTexture2D<unorm float> rw_mv_holes_tp1 : register(u2, space0);
RWTexture2D<unorm float> rw_mv_holes_tm1 : register(u3, space0);

static uint3 gl_WorkGroupID;
static uint3 gl_GlobalInvocationID;
static uint gl_LocalInvocationIndex;
struct SPIRV_Cross_Input
{
    uint3 gl_WorkGroupID : SV_GroupID;
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
    uint gl_LocalInvocationIndex : SV_GroupIndex;
};

groupshared float nfruFitRed[256];
groupshared float nfruFitDepthScale;
groupshared float nfruFitTheta[16];

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

                                           
float spvDet2x2(float a1, float a2, float b1, float b2)
{
    return a1 * b2 - b1 * a2;
}

                                           
float spvDet3x3(float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3)
{
    return a1 * spvDet2x2(b2, b3, c2, c3) - b1 * spvDet2x2(a2, a3, c2, c3) + c1 * spvDet2x2(a2, a3, b2, b3);
}

                                                                                       
                                                                                   
float4x4 spvInverse(float4x4 m)
{
    float4x4 adj;	                                                             

                                                                                     
    adj[0][0] =  spvDet3x3(m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][1] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][2] =  spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[3][1], m[3][2], m[3][3]);
    adj[0][3] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3]);

    adj[1][0] = -spvDet3x3(m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][1] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][2] = -spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[3][0], m[3][2], m[3][3]);
    adj[1][3] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3]);

    adj[2][0] =  spvDet3x3(m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][1] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][2] =  spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[3][0], m[3][1], m[3][3]);
    adj[2][3] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3]);

    adj[3][0] = -spvDet3x3(m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][1] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][2] = -spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[3][0], m[3][1], m[3][2]);
    adj[3][3] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]);

                                                                                    
    float det = (adj[0][0] * m[0][0]) + (adj[0][1] * m[1][0]) + (adj[0][2] * m[2][0]) + (adj[0][3] * m[3][0]);

                                                              
                                                                               
    return (det != 0.0f) ? (adj * (1.0f / det)) : m;
}

void comp_main()
{
    int2 _1780 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_1780.x < cbFI_MvDepthLaneSize.x, _1780.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_1780] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_1780] = 0.0f.x;
        rw_mv_holes_tm1[_1780] = 0.0f.x;
    }
    if (all(bool2(_1780.x < cbFI_FlowLaneSize.x, _1780.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_1780] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _1789 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _1797;
    if (_1789)
    {
        _1797 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _1797 = _1789;
    }
    bool _1803;
    if (_1797)
    {
        _1803 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _1803 = _1797;
    }
    if (_1803)
    {
        float2 _2018 = float2(cbFI_RenderSize) * 0.5f;
        float _4262;
        float _4265;
        _4265 = 0.0f;
        _4262 = 0.0f;
        for (uint _4261 = 0u; _4261 < 16u; )
        {
            uint _2027 = gl_LocalInvocationIndex + (256u * _4261);
            uint _2955_dummy_parameter;
            _4265 += 1.0f;
            _4262 += r_depth_tp1.Load(int3(int2(floor((0.02999999932944774627685546875f.xx + ((float2(float(_2027 % 64u) + 0.5f, float(_2027 / 64u) + 0.5f) * 0.015625f.xx) * 0.939999997615814208984375f)) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2955_dummy_parameter))))), 0)).x;
            _4261++;
            continue;
        }
        nfruFitRed[gl_LocalInvocationIndex] = _4262;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4263 = 128u; _4263 > 0u; _4263 = _4263 >> 1u)
        {
            if (gl_LocalInvocationIndex < _4263)
            {
                nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4263];
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _2997 = nfruFitRed[0];
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        nfruFitRed[gl_LocalInvocationIndex] = _4265;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4266 = 128u; _4266 > 0u; _4266 = _4266 >> 1u)
        {
            if (gl_LocalInvocationIndex < _4266)
            {
                nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4266];
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _3031 = nfruFitRed[0];
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _2061 = gl_LocalInvocationIndex == 0u;
        if (_2061)
        {
            nfruFitDepthScale = 1.0f / max(_2997 / max(_3031, 1.0f), 9.9999999747524270787835121154785e-07f);
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _1892[11];
        for (int _4267 = 0; _4267 < 11; )
        {
            _1892[_4267] = 0.0f;
            _4267++;
            continue;
        }
        float _4313;
        _4313 = 0.0f;
        float _3276;
        float _1899[66];
        float _1901[11];
        float _1942[121];
        float _1944[11];
        float _1952[11];
        int _4268 = 0;
        bool _4387 = false;
        for (; _4268 < 3; _4387 = true, _4313 = _3276, _4268++)
        {
            for (int _4381 = 0; _4381 < 66; )
            {
                _1899[_4381] = 0.0f;
                _4381++;
                continue;
            }
            for (int _4382 = 0; _4382 < 11; )
            {
                _1901[_4382] = 0.0f;
                _4382++;
                continue;
            }
            float _4388;
            float _4391;
            float _4394;
            _4394 = 0.0f;
            _4391 = 0.0f;
            _4388 = 0.0f;
            float _4601;
            float _4606;
            float _4612;
            for (uint _4383 = 0u; _4383 < 16u; _4394 = _4612, _4391 = _4606, _4388 = _4601, _4383++)
            {
                uint _2113 = gl_LocalInvocationIndex + (256u * _4383);
                float2 _3057 = 0.02999999932944774627685546875f.xx + ((float2(float(_2113 % 64u) + 0.5f, float(_2113 / 64u) + 0.5f) * 0.015625f.xx) * 0.939999997615814208984375f);
                uint _3123_dummy_parameter;
                float2 _3138 = r_motion_tp1.Load(int3(int2(floor(_3057 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3123_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                uint _3150_dummy_parameter;
                float2 _3064 = _3057 + _3138;
                bool _3067 = all(bool2(_3064.x > 0.0f.xx.x, _3064.y > 0.0f.xx.y));
                bool _3073;
                if (_3067)
                {
                    _3073 = all(bool2(_3064.x < 1.0f.xx.x, _3064.y < 1.0f.xx.y));
                }
                else
                {
                    _3073 = _3067;
                }
                bool _3080;
                if (_3073)
                {
                    _3080 = !any(isnan(_3138));
                }
                else
                {
                    _3080 = _3073;
                }
                bool _3087;
                if (_3080)
                {
                    _3087 = !any(isinf(_3138));
                }
                else
                {
                    _3087 = _3080;
                }
                float _3091 = (2.0f * _3057.x) - 1.0f;
                float _3095 = 1.0f - (2.0f * _3057.y);
                float _3098 = r_depth_tp1.Load(int3(int2(floor(_3057 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3150_dummy_parameter))))), 0)).x * nfruFitDepthScale;
                float _3102 = 2.0f * _3064.x;
                float _3103 = _3102 - 1.0f;
                float _3106 = 2.0f * _3064.y;
                float _3107 = 1.0f - _3106;
                if (!_3087)
                {
                    _4612 = _4394;
                    _4606 = _4391;
                    _4601 = _4388;
                    continue;
                }
                float _4482;
                float _4603;
                float _4608;
                if (_4387)
                {
                    float _2145 = (((_1892[8] * _3091) + (_1892[9] * _3095)) + (_1892[10] * _3098)) + 1.0f;
                    float _2211 = length(float2(((((((_1892[0] * _3091) + (_1892[1] * _3095)) + (_1892[2] * _3098)) + _1892[3]) / _2145) - _3103) * _2018.x, ((((((_1892[4] * _3091) + (_1892[5] * _3095)) + (_1892[6] * _3098)) + _1892[7]) / _2145) - _3107) * _2018.y));
                    float _4462;
                    if (_2211 < _896[_4268])
                    {
                        _4462 = 1.0f;
                    }
                    else
                    {
                        _4462 = _896[_4268] / max(_2211, 9.9999999747524270787835121154785e-07f);
                    }
                    float _4604;
                    float _4609;
                    if (_2211 < 2.0f)
                    {
                        _4609 = _4391 + _2211;
                        _4604 = _4388 + 1.0f;
                    }
                    else
                    {
                        _4609 = _4391;
                        _4604 = _4388;
                    }
                    _4608 = _4609;
                    _4603 = _4604;
                    _4482 = _4462;
                }
                else
                {
                    _4608 = _4391;
                    _4603 = _4388;
                    _4482 = 1.0f;
                }
                float _2249 = 1.0f - _3102;
                float _2265[11] = { _3091, _3095, _3098, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, _2249 * _3091, _2249 * _3095, _2249 * _3098 };
                float _1925[11] = _2265;
                float _2276 = _3106 - 1.0f;
                float _2292[11] = { 0.0f, 0.0f, 0.0f, 0.0f, _3091, _3095, _3098, 1.0f, _2276 * _3091, _2276 * _3095, _2276 * _3098 };
                float _1926[11] = _2292;
                int _4477;
                _4477 = 0;
                int _4484;
                for (int _4485 = 0; _4477 < 11; _4477++, _4485 = _4484)
                {
                    _4484 = _4485;
                    for (int _4478 = _4477; _4478 < 11; )
                    {
                        _1899[_4484] += (_4482 * ((_1925[_4477] * _1925[_4478]) + (_1926[_4477] * _1926[_4478])));
                        _4484++;
                        _4478++;
                        continue;
                    }
                    _1901[_4477] += (_4482 * ((_1925[_4477] * _3103) + (_1926[_4477] * _3107)));
                }
                _4612 = _4394 + 1.0f;
                _4606 = _4608;
                _4601 = _4603;
            }
            if (_4387)
            {
                nfruFitRed[gl_LocalInvocationIndex] = _4388;
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                for (uint _4389 = 128u; _4389 > 0u; _4389 = _4389 >> 1u)
                {
                    if (gl_LocalInvocationIndex < _4389)
                    {
                        nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4389];
                    }
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                }
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                nfruFitRed[gl_LocalInvocationIndex] = _4391;
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                for (uint _4392 = 128u; _4392 > 0u; _4392 = _4392 >> 1u)
                {
                    if (gl_LocalInvocationIndex < _4392)
                    {
                        nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4392];
                    }
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                }
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
            }
            nfruFitRed[gl_LocalInvocationIndex] = _4394;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            for (uint _4397 = 128u; _4397 > 0u; _4397 = _4397 >> 1u)
            {
                if (gl_LocalInvocationIndex < _4397)
                {
                    nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4397];
                }
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
            }
            _3276 = nfruFitRed[0];
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            int _4446;
            for (int _4398 = 0, _4447 = 0; _4398 < 11; _4398++, _4447 = _4446)
            {
                _4446 = _4447;
                int _2401;
                for (int _4444 = _4398; _4444 < 11; _4446 = _2401, _4444++)
                {
                    nfruFitRed[gl_LocalInvocationIndex] = _1899[_4446];
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                    for (uint _4448 = 128u; _4448 > 0u; _4448 = _4448 >> 1u)
                    {
                        if (gl_LocalInvocationIndex < _4448)
                        {
                            nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4448];
                        }
                        AllMemoryBarrier();
                        GroupMemoryBarrierWithGroupSync();
                    }
                    float _3310 = nfruFitRed[0];
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                    _1942[(_4398 * 11) + _4444] = _3310;
                    _1942[(_4444 * 11) + _4398] = _3310;
                    _2401 = _4446 + 1;
                }
            }
            for (int _4399 = 0; _4399 < 11; _4399++)
            {
                nfruFitRed[gl_LocalInvocationIndex] = _1901[_4399];
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                for (uint _4441 = 128u; _4441 > 0u; _4441 = _4441 >> 1u)
                {
                    if (gl_LocalInvocationIndex < _4441)
                    {
                        nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4441];
                    }
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                }
                float _3344 = nfruFitRed[0];
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                _1944[_4399] = _3344;
            }
            if (_2061)
            {
                float _2430 = _1942[0];
                float _2432 = _1942[12];
                float _2434 = 9.9999999747524270787835121154785e-07f * (_2430 + _2432);
                _1942[24] += _2434;
                _1942[72] += _2434;
                _1942[120] += _2434;
                float _1949[121] = _1942;
                float _1950[11] = _1944;
                int _3379;
                for (int _4400 = 0; _4400 < 11; _4400 = _3379)
                {
                    int _3372 = _4400 * 11;
                    int _3374 = _3372 + _4400;
                    float _3377 = abs(_1949[_3374]);
                    _3379 = _4400 + 1;
                    int _4426;
                    _4426 = _4400;
                    int _4647;
                    float _4642;
                    int _4425 = _3379;
                    float _4439 = _3377;
                    for (; _4425 < 11; _4439 = _4642, _4426 = _4647, _4425++)
                    {
                        int _3389 = (_4425 * 11) + _4400;
                        bool _3394 = abs(_1949[_3389]) > _4439;
                        if (_3394)
                        {
                            _4642 = abs(_1949[_3389]);
                        }
                        else
                        {
                            _4642 = _4439;
                        }
                        _4647 = _3394 ? _4425 : _4426;
                    }
                    if (_4426 != _4400)
                    {
                        for (int _4428 = 0; _4428 < 11; )
                        {
                            int _3422 = _3372 + _4428;
                            float _3424 = _1949[_3422];
                            int _3432 = (_4426 * 11) + _4428;
                            _1949[_3422] = _1949[_3432];
                            _1949[_3432] = _3424;
                            _4428++;
                            continue;
                        }
                        float _3448 = _1950[_4400];
                        _1950[_4400] = _1950[_4426];
                        _1950[_4426] = _3448;
                    }
                    float _4432;
                    if (abs(_1949[_3374]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _4432 = _1949[_3374];
                    }
                    else
                    {
                        _4432 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (int _4434 = _3379; _4434 < 11; _4434++)
                    {
                        int _3485 = _4434 * 11;
                        float _3489 = _1949[_3485 + _4400];
                        float _3491 = _3489 / _4432;
                        for (int _4436 = _4400; _4436 < 11; )
                        {
                            int _3502 = _3485 + _4436;
                            _1949[_3502] -= (_3491 * _1949[_3372 + _4436]);
                            _4436++;
                            continue;
                        }
                        _1950[_4434] -= (_3491 * _1950[_4400]);
                    }
                }
                int _4401;
                _4401 = 10;
                for (; _4401 >= 0; _4401--)
                {
                    int _3548 = _4401 + 1;
                    float _4422;
                    _4422 = _1950[_4401];
                    for (int _4420 = _3548; _4420 < 11; )
                    {
                        _4422 -= (_1949[(_4401 * 11) + _4420] * _1952[_4420]);
                        _4420++;
                        continue;
                    }
                    int _3576 = (_4401 * 11) + _4401;
                    float _4423;
                    if (abs(_1949[_3576]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _4423 = _1949[_3576];
                    }
                    else
                    {
                        _4423 = 9.9999996826552253889678874634872e-21f;
                    }
                    _1952[_4401] = _4422 / _4423;
                }
                for (int _4402 = 11; _4402 < 11; )
                {
                    _1952[_4402] = 0.0f;
                    _4402++;
                    continue;
                }
                _1942 = _1949;
                _1944 = _1950;
                float _1948[11] = _1952;
                for (int _4403 = 0; _4403 < 11; )
                {
                    nfruFitTheta[_4403] = _1948[_4403];
                    _4403++;
                    continue;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            for (int _4404 = 0; _4404 < 11; )
            {
                _1892[_4404] = nfruFitTheta[_4404];
                _4404++;
                continue;
            }
        }
        float _1958[14];
        for (int _4269 = 0; _4269 < 14; )
        {
            _1958[_4269] = 0.0f;
            _4269++;
            continue;
        }
        float _4271;
        float _4275;
        _4275 = 0.0f;
        _4271 = 0.0f;
        float _4498;
        float _4503;
        for (uint _4270 = 0u; _4270 < 16u; _4275 = _4503, _4271 = _4498, _4270++)
        {
            uint _2508 = gl_LocalInvocationIndex + (256u * _4270);
            float2 _3633 = 0.02999999932944774627685546875f.xx + ((float2(float(_2508 % 64u) + 0.5f, float(_2508 / 64u) + 0.5f) * 0.015625f.xx) * 0.939999997615814208984375f);
            uint _3699_dummy_parameter;
            float2 _3714 = r_motion_tp1.Load(int3(int2(floor(_3633 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3699_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            uint _3726_dummy_parameter;
            float2 _3640 = _3633 + _3714;
            bool _3643 = all(bool2(_3640.x > 0.0f.xx.x, _3640.y > 0.0f.xx.y));
            bool _3649;
            if (_3643)
            {
                _3649 = all(bool2(_3640.x < 1.0f.xx.x, _3640.y < 1.0f.xx.y));
            }
            else
            {
                _3649 = _3643;
            }
            bool _3656;
            if (_3649)
            {
                _3656 = !any(isnan(_3714));
            }
            else
            {
                _3656 = _3649;
            }
            bool _3663;
            if (_3656)
            {
                _3663 = !any(isinf(_3714));
            }
            else
            {
                _3663 = _3656;
            }
            float _3667 = (2.0f * _3633.x) - 1.0f;
            float _3671 = 1.0f - (2.0f * _3633.y);
            float _3674 = r_depth_tp1.Load(int3(int2(floor(_3633 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3726_dummy_parameter))))), 0)).x * nfruFitDepthScale;
            float _4358;
            if (_3663)
            {
                uint _3742_dummy_parameter;
                _4358 = r_depth_tm1.Load(int3(int2(floor(_3640 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _3742_dummy_parameter))))), 0)).x;
            }
            else
            {
                _4358 = 0.0f;
            }
            if (!_3663)
            {
                _4503 = _4275;
                _4498 = _4271;
                continue;
            }
            float _2538 = (((_1892[8] * _3667) + (_1892[9] * _3671)) + (_1892[10] * _3674)) + 1.0f;
            float _2604 = length(float2(((((((_1892[0] * _3667) + (_1892[1] * _3671)) + (_1892[2] * _3674)) + _1892[3]) / _2538) - ((2.0f * _3640.x) - 1.0f)) * _2018.x, ((((((_1892[4] * _3667) + (_1892[5] * _3671)) + (_1892[6] * _3674)) + _1892[7]) / _2538) - (1.0f - (2.0f * _3640.y))) * _2018.y));
            float _4500;
            float _4505;
            if (_2604 < 2.0f)
            {
                _4505 = _4275 + _2604;
                _4500 = _4271 + 1.0f;
            }
            else
            {
                _4505 = _4275;
                _4500 = _4271;
            }
            if (_3663 && (_2604 < 1.5f))
            {
                float4 _1975 = float4(_3667, _3671, _3674, 1.0f);
                float _2624 = (_4358 * nfruFitDepthScale) * _2538;
                int _4367;
                _4367 = 0;
                int _4370;
                for (int _4371 = 0; _4367 < 4; _4367++, _4371 = _4370)
                {
                    _4370 = _4371;
                    for (int _4368 = _4367; _4368 < 4; )
                    {
                        _1958[_4370] += (_1975[_4367] * _1975[_4368]);
                        _4370++;
                        _4368++;
                        continue;
                    }
                    int _2655 = 10 + _4367;
                    _1958[_2655] += (_1975[_4367] * _2624);
                }
            }
            _4503 = _4505;
            _4498 = _4500;
        }
        nfruFitRed[gl_LocalInvocationIndex] = _4271;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4273 = 128u; _4273 > 0u; _4273 = _4273 >> 1u)
        {
            if (gl_LocalInvocationIndex < _4273)
            {
                nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4273];
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _3784 = nfruFitRed[0];
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        nfruFitRed[gl_LocalInvocationIndex] = _4275;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4277 = 128u; _4277 > 0u; _4277 = _4277 >> 1u)
        {
            if (gl_LocalInvocationIndex < _4277)
            {
                nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4277];
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _3818 = nfruFitRed[0];
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _1990[121];
        int _4349;
        for (int _4278 = 0, _4350 = 0; _4278 < 4; _4278++, _4350 = _4349)
        {
            _4349 = _4350;
            int _2709;
            for (int _4347 = _4278; _4347 < 4; _4349 = _2709, _4347++)
            {
                nfruFitRed[gl_LocalInvocationIndex] = _1958[_4349];
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                for (uint _4351 = 128u; _4351 > 0u; _4351 = _4351 >> 1u)
                {
                    if (gl_LocalInvocationIndex < _4351)
                    {
                        nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4351];
                    }
                    AllMemoryBarrier();
                    GroupMemoryBarrierWithGroupSync();
                }
                float _3852 = nfruFitRed[0];
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                _1990[(_4278 * 11) + _4347] = _3852;
                _1990[(_4347 * 11) + _4278] = _3852;
                _2709 = _4349 + 1;
            }
        }
        float _1992[11];
        for (int _4279 = 0; _4279 < 4; _4279++)
        {
            nfruFitRed[gl_LocalInvocationIndex] = _1958[10 + _4279];
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            for (uint _4344 = 128u; _4344 > 0u; _4344 = _4344 >> 1u)
            {
                if (gl_LocalInvocationIndex < _4344)
                {
                    nfruFitRed[gl_LocalInvocationIndex] += nfruFitRed[gl_LocalInvocationIndex + _4344];
                }
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
            }
            float _3886 = nfruFitRed[0];
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            _1992[_4279] = _3886;
        }
        if (_2061)
        {
            float _2744 = 9.9999999747524270787835121154785e-07f * ((_1990[0] + _1990[12]) + 9.999999717180685365747194737196e-10f);
            for (int _4280 = 0; _4280 < 4; )
            {
                int _2753 = (_4280 * 11) + _4280;
                _1990[_2753] += _2744;
                _4280++;
                continue;
            }
            float _1998[121] = _1990;
            float _1999[11] = _1992;
            int _3921;
            for (int _4281 = 0; _4281 < 4; _4281 = _3921)
            {
                int _3914 = _4281 * 11;
                int _3916 = _3914 + _4281;
                float _3919 = abs(_1998[_3916]);
                _3921 = _4281 + 1;
                int _4329;
                _4329 = _4281;
                int _4648;
                float _4590;
                int _4328 = _3921;
                float _4342 = _3919;
                for (; _4328 < 4; _4342 = _4590, _4329 = _4648, _4328++)
                {
                    int _3931 = (_4328 * 11) + _4281;
                    bool _3936 = abs(_1998[_3931]) > _4342;
                    if (_3936)
                    {
                        _4590 = abs(_1998[_3931]);
                    }
                    else
                    {
                        _4590 = _4342;
                    }
                    _4648 = _3936 ? _4328 : _4329;
                }
                if (_4329 != _4281)
                {
                    for (int _4331 = 0; _4331 < 4; )
                    {
                        int _3964 = _3914 + _4331;
                        float _3966 = _1998[_3964];
                        int _3974 = (_4329 * 11) + _4331;
                        _1998[_3964] = _1998[_3974];
                        _1998[_3974] = _3966;
                        _4331++;
                        continue;
                    }
                    float _3990 = _1999[_4281];
                    _1999[_4281] = _1999[_4329];
                    _1999[_4329] = _3990;
                }
                float _4335;
                if (abs(_1998[_3916]) > 9.9999996826552253889678874634872e-21f)
                {
                    _4335 = _1998[_3916];
                }
                else
                {
                    _4335 = 9.9999996826552253889678874634872e-21f;
                }
                for (int _4337 = _3921; _4337 < 4; _4337++)
                {
                    int _4027 = _4337 * 11;
                    float _4031 = _1998[_4027 + _4281];
                    float _4033 = _4031 / _4335;
                    for (int _4339 = _4281; _4339 < 4; )
                    {
                        int _4044 = _4027 + _4339;
                        _1998[_4044] -= (_4033 * _1998[_3914 + _4339]);
                        _4339++;
                        continue;
                    }
                    _1999[_4337] -= (_4033 * _1999[_4281]);
                }
            }
            int _4282;
            _4282 = 3;
            float _2001[11];
            for (; _4282 >= 0; _4282--)
            {
                int _4090 = _4282 + 1;
                float _4325;
                _4325 = _1999[_4282];
                for (int _4323 = _4090; _4323 < 4; )
                {
                    _4325 -= (_1998[(_4282 * 11) + _4323] * _2001[_4323]);
                    _4323++;
                    continue;
                }
                int _4118 = (_4282 * 11) + _4282;
                float _4326;
                if (abs(_1998[_4118]) > 9.9999996826552253889678874634872e-21f)
                {
                    _4326 = _1998[_4118];
                }
                else
                {
                    _4326 = 9.9999996826552253889678874634872e-21f;
                }
                _2001[_4282] = _4325 / _4326;
            }
            for (int _4283 = 4; _4283 < 11; )
            {
                _2001[_4283] = 0.0f;
                _4283++;
                continue;
            }
            _1990 = _1998;
            _1992 = _1999;
            float4x4 _2840 = transpose(float4x4(float4(_1892[0], _1892[1], _1892[2] * nfruFitDepthScale, _1892[3]), float4(_1892[4], _1892[5], _1892[6] * nfruFitDepthScale, _1892[7]), float4(_2001[0], _2001[1], _2001[2] * nfruFitDepthScale, _2001[3]) / nfruFitDepthScale.xxxx, float4(_1892[8], _1892[9], _1892[10] * nfruFitDepthScale, 1.0f)));
            float4x4 _2007 = _2840;
            float4x4 _2008 = spvInverse(_2840);
            uint _4160 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            uint _4284;
            _4284 = 0u;
            for (; _4284 < 4u; _4284++)
            {
                for (uint _4321 = 0u; _4321 < 4u; )
                {
                    uint _2856 = _4284 * 4u;
                    rw_nfru_diagnostics.Store<uint>(((_4160 + _2856) + _4321) * 4 + 0, asuint(_2007[_4284][_4321]));
                    rw_nfru_diagnostics.Store<uint>((((_4160 + 16u) + _2856) + _4321) * 4 + 0, asuint(_2008[_4284][_4321]));
                    _4321++;
                    continue;
                }
            }
            float _4300;
            if (_3784 > 0.0f)
            {
                _4300 = _3818 / _3784;
            }
            else
            {
                _4300 = 1000000000.0f;
            }
            bool _2897 = _4313 > 500.0f;
            bool _2904;
            if (_2897)
            {
                _2904 = _3784 > (0.4000000059604644775390625f * _4313);
            }
            else
            {
                _2904 = _2897;
            }
            bool _2907 = _2904 && (_4300 < 1.0f);
            bool _2915;
            if (_2907)
            {
                _2915 = !any(isnan(_2007[0]));
            }
            else
            {
                _2915 = _2907;
            }
            bool _2923;
            if (_2915)
            {
                _2923 = !any(isnan(_2008[0]));
            }
            else
            {
                _2923 = _2915;
            }
            rw_nfru_diagnostics.Store<uint>((_4160 + 32u) * 4 + 0, uint(_2923));
            rw_nfru_diagnostics.Store<uint>((_4160 + 33u) * 4 + 0, asuint(_4300));
            rw_nfru_diagnostics.Store<uint>((_4160 + 34u) * 4 + 0, uint(_3784));
            rw_nfru_diagnostics.Store<uint>((_4160 + 35u) * 4 + 0, uint(_4313));
        }
    }
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_WorkGroupID = stage_input.gl_WorkGroupID;
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    gl_LocalInvocationIndex = stage_input.gl_LocalInvocationIndex;
    comp_main();
}
