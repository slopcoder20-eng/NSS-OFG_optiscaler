static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3100[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

cbuffer cbFI_t : register(b7, space0)
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

RWByteAddressBuffer rw_nfru_diagnostics : register(u10, space0);
RWByteAddressBuffer rw_nfru_select : register(u19, space0);
Texture2D<float4> r_depth_m2 : register(t17, space0);
Texture2D<float4> r_colour_m2 : register(t16, space0);
Texture2D<float4> r_present_backbuffer : register(t9, space0);
Texture2D<float4> r_motion_tp1 : register(t13, space0);
Texture2D<float4> r_depth_tp1 : register(t11, space0);
Texture2D<float4> r_depth_tm1 : register(t12, space0);
Texture2D<uint4> r_warped_motion_qdata_tp1 : register(t18, space0);
Texture2D<uint4> r_warped_flow_qdata_tm1 : register(t15, space0);
Texture2D<float4> r_warped_filled_motion_tp1 : register(t1, space0);
Texture2D<float4> r_warped_filled_flow_tm1 : register(t2, space0);
Texture2D<float4> r_previous_interpolation_source : register(t4, space0);
SamplerState s_LinearClamp : register(s1001, space0);
Texture2D<float4> r_current_interpolation_source : register(t5, space0);
Texture2D<float4> r_out_params_tensor : register(t0, space0);
RWTexture2D<float3> rw_output : register(u6, space0);
RWTexture2D<float3> rw_previous_interpolation_source : register(u8, space0);
Texture2D<float4> r_flow_tm1 : register(t14, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

uint spvPackHalf2x16(float2 value)
{
    uint2 Packed = f32tof16(value);
    return Packed.x | (Packed.y << 16);
}

float2 spvUnpackHalf2x16(uint value)
{
    return f16tof32(uint2(value & 0xffff, value >> 16));
}

void comp_main()
{
    int2 _3404 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3404.x >= cbFI_DisplaySize.x, _3404.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3404] = float4(r_present_backbuffer.Load(int3(_3404, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3404] = float4(r_current_interpolation_source.Load(int3(_3404, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3779 = (float2(_3404) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3790 = int2(floor(_3779 * float2(cbFI_MvDepthLaneSize)));
        int2 _3795 = int2(floor(_3779 * float2(cbFI_FlowLaneSize)));
        float4 _5535 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3779 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5541 = r_warped_filled_flow_tm1.Load(int3(_3795, 0)).xy;
        float2 _5547 = r_warped_filled_motion_tp1.Load(int3(_3790, 0)).xy;
        bool _5569 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9097;
        if (_5569)
        {
            float _5582 = ((2.0f * _3779.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9097 = float2(atan(_5582) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3779.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5582 * _5582))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9097 = _3779;
        }
        bool _3816 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9118;
        bool _9139;
        int2 _9150;
        float3 _10202;
        if (_3816)
        {
            float _9099;
            float _9101;
            _9101 = 2.0f;
            _9099 = -1.0f;
            uint _3468[9];
            float _10593;
            float _10596;
            for (int _9098 = 0; _9098 < 9; _9101 = _10596, _9099 = _10593, _9098++)
            {
                _3468[_9098] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3790 + int2((_9098 % 3) - 1, (_9098 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3468[_9098] != 0u)
                {
                    float _10588;
                    if (_3468[_9098] == 0u)
                    {
                        _10588 = -1.0f;
                    }
                    else
                    {
                        _10588 = float((_3468[_9098] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10596 = min(_9101, _10588);
                    _10593 = max(_9099, _10588);
                }
                else
                {
                    _10596 = _9101;
                    _10593 = _9099;
                }
            }
            float _3862 = float(_9099 >= 0.0f);
            float3 _8908 = 0.0f.xxx;
            _8908.y = _3862;
            float2 _9119;
            bool _9140;
            int2 _9151;
            float3 _10203;
            if ((_9099 - _9101) > 0.0199999995529651641845703125f)
            {
                float _9107;
                int2 _9108;
                float2 _9109;
                int2 _9111;
                float2 _9117;
                _9117 = _5547;
                _9111 = _3790;
                _9109 = _5547;
                _9108 = _3790;
                _9107 = -1.0f;
                float _10601;
                int2 _10605;
                float2 _10616;
                int2 _10627;
                float2 _10660;
                float _10706;
                int _9106 = 0;
                float _10569 = 1000000000.0f;
                for (; _9106 < 9; _10569 = _10706, _9117 = _10660, _9111 = _10627, _9109 = _10616, _9108 = _10605, _9107 = _10601, _9106++)
                {
                    if (_3468[_9106] == 0u)
                    {
                        _10706 = _10569;
                        _10660 = _9117;
                        _10627 = _9111;
                        _10616 = _9109;
                        _10605 = _9108;
                        _10601 = _9107;
                        continue;
                    }
                    int2 _3897 = clamp(_3790 + int2((_9106 % 3) - 1, (_9106 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5657 = _3468[_9106] & 2147483647u;
                    uint _5689 = uint(max((int((_5657 >> 16u) & 15u) - 6), 0));
                    float2 _3903 = (float2(float((1 - (2 * int((_5657 >> 15u) & 1u))) * int(((_5657 >> uint(7)) & 127u) << _5689)), float((1 - (2 * int((_5657 >> 14u) & 1u))) * int((_5657 & 127u) << _5689))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10555;
                    if (_3468[_9106] == 0u)
                    {
                        _10555 = -1.0f;
                    }
                    else
                    {
                        _10555 = float((_3468[_9106] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3908 = _10555 - 0.100000001490116119384765625f;
                    float2 _10556;
                    if (_5569)
                    {
                        float2 _5766 = clamp((((_9097 + (_3903 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5769 = tan(_5766.x);
                        _10556 = (float2(_5769 / cbFI_DeviceToViewDepth.z, (tan(_5766.y) * sqrt(1.0f + (_5769 * _5769))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10556 = _9097 + (_3903 * cbFI_Timestep);
                    }
                    float _3915 = cbFI_Timestep - 1.0f;
                    float2 _10557;
                    if (_5569)
                    {
                        float2 _5837 = clamp((((_9097 + (_3903 * _3915)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5840 = tan(_5837.x);
                        _10557 = (float2(_5840 / cbFI_DeviceToViewDepth.z, (tan(_5837.y) * sqrt(1.0f + (_5840 * _5840))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10557 = _9097 + (_3903 * _3915);
                    }
                    bool _5873 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                    bool _5879;
                    if (_5873)
                    {
                        _5879 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5879 = _5873;
                    }
                    float _10560;
                    if (_5879)
                    {
                        uint _5886_dummy_parameter;
                        _10560 = max((_3908 - (log((r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5886_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10560 = 0.0f;
                    }
                    bool _5916 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                    bool _5922;
                    if (_5916)
                    {
                        _5922 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5922 = _5916;
                    }
                    float _10561;
                    if (_5922)
                    {
                        uint _5929_dummy_parameter;
                        _10561 = _10560 + max((_3908 - (log((r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5929_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10561 = _10560;
                    }
                    float _10602;
                    int2 _10606;
                    float2 _10617;
                    int2 _10628;
                    float2 _10661;
                    float _10707;
                    if (_10561 == 0.0f)
                    {
                        bool _3950 = _3908 > _9107;
                        bool2 _10715 = _3950.xx;
                        _10707 = _10569;
                        _10661 = float2(_10715.x ? _3903.x : _9117.x, _10715.y ? _3903.y : _9117.y);
                        _10628 = int2(_10715.x ? _3897.x : _9111.x, _10715.y ? _3897.y : _9111.y);
                        _10617 = _9109;
                        _10606 = _9108;
                        _10602 = _3950 ? _3908 : _9107;
                    }
                    else
                    {
                        bool _3959 = _10561 < _10569;
                        bool2 _10711 = _3959.xx;
                        _10707 = _3959 ? _10561 : _10569;
                        _10661 = _9117;
                        _10628 = _9111;
                        _10617 = float2(_10711.x ? _3903.x : _9109.x, _10711.y ? _3903.y : _9109.y);
                        _10606 = int2(_10711.x ? _3897.x : _9108.x, _10711.y ? _3897.y : _9108.y);
                        _10602 = _9107;
                    }
                    _10706 = _10707;
                    _10660 = _10661;
                    _10627 = _10628;
                    _10616 = _10617;
                    _10605 = _10606;
                    _10601 = _10602;
                }
                bool _3971 = _9107 < 0.0f;
                bool2 _10721 = _3971.xx;
                int2 _10724 = int2(_10721.x ? _9108.x : _9111.x, _10721.y ? _9108.y : _9111.y);
                _10203 = float3(1.0f, _3862, float(any(bool2(_10724.x != _3790.x, _10724.y != _3790.y))));
                _9151 = _10724;
                _9140 = _3971 ? false : true;
                _9119 = float2(_10721.x ? _9109.x : _9117.x, _10721.y ? _9109.y : _9117.y);
            }
            else
            {
                _10203 = _8908;
                _9151 = _3790;
                _9140 = false;
                _9119 = _5547;
            }
            _10202 = _10203;
            _9150 = _9151;
            _9139 = _9140;
            _9118 = _9119;
        }
        else
        {
            _10202 = 0.0f.xxx;
            _9150 = _3790;
            _9139 = false;
            _9118 = _5547;
        }
        float2 _9120;
        if (_5569)
        {
            float2 _5994 = clamp((((_9097 + (_9118 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5997 = tan(_5994.x);
            _9120 = (float2(_5997 / cbFI_DeviceToViewDepth.z, (tan(_5994.y) * sqrt(1.0f + (_5997 * _5997))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9120 = _9097 + (_9118 * cbFI_Timestep);
        }
        float _3994 = cbFI_Timestep - 1.0f;
        float2 _9122;
        if (_5569)
        {
            float2 _6065 = clamp((((_9097 + (_9118 * _3994)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6068 = tan(_6065.x);
            _9122 = (float2(_6068 / cbFI_DeviceToViewDepth.z, (tan(_6065.y) * sqrt(1.0f + (_6068 * _6068))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9122 = _9097 + (_9118 * _3994);
        }
        float _3999 = -cbFI_Timestep;
        float2 _9123;
        if (_5569)
        {
            float2 _6136 = clamp((((_9097 + (_5541 * _3999)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6139 = tan(_6136.x);
            _9123 = (float2(_6139 / cbFI_DeviceToViewDepth.z, (tan(_6136.y) * sqrt(1.0f + (_6139 * _6139))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9123 = _9097 + (_5541 * _3999);
        }
        float _4004 = 1.0f - cbFI_Timestep;
        float2 _9124;
        if (_5569)
        {
            float2 _6207 = clamp((((_9097 + (_5541 * _4004)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6210 = tan(_6207.x);
            _9124 = (float2(_6210 / cbFI_DeviceToViewDepth.z, (tan(_6207.y) * sqrt(1.0f + (_6210 * _6210))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9124 = _9097 + (_5541 * _4004);
        }
        float4 _6245 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9120, 0.0f);
        float3 _6246 = _6245.xyz;
        float4 _6253 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9122, 0.0f);
        float3 _6254 = _6253.xyz;
        float4 _6261 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9123, 0.0f);
        float3 _6262 = _6261.xyz;
        float4 _6269 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9124, 0.0f);
        float3 _6270 = _6269.xyz;
        float4 _6284 = exp(_5535 - max(max(max(_5535.x, _5535.y), _5535.z), _5535.w).xxxx);
        float4 _6291 = _6284 / (dot(_6284, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4023 = _3816 && (!_9139);
        bool _4032;
        if (_4023)
        {
            _4032 = (_6291.z + _6291.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4032 = _4023;
        }
        bool _4043;
        if (_4032)
        {
            _4043 = length((_9123 - _9120) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4043 = _4032;
        }
        bool _9163;
        if (_4043)
        {
            uint4 _6310 = r_warped_motion_qdata_tp1.Load(int3(_9150, 0));
            uint _6311 = _6310.x;
            bool _9166;
            if (_6311 != 0u)
            {
                float _9152;
                if (_6311 == 0u)
                {
                    _9152 = -1.0f;
                }
                else
                {
                    _9152 = float((_6311 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4053 = _9152 - 0.12000000476837158203125f;
                bool _6330 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                bool _6336;
                if (_6330)
                {
                    _6336 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                }
                else
                {
                    _6336 = _6330;
                }
                bool _4063;
                if (_6336)
                {
                    uint _6343_dummy_parameter;
                    _4063 = (log((r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6343_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4053;
                }
                else
                {
                    _4063 = _6336;
                }
                bool _4077;
                if (!_4063)
                {
                    bool _6373 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                    bool _6379;
                    if (_6373)
                    {
                        _6379 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6379 = _6373;
                    }
                    bool _4075;
                    if (_6379)
                    {
                        uint _6386_dummy_parameter;
                        _4075 = (log((r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6386_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4053;
                    }
                    else
                    {
                        _4075 = _6379;
                    }
                    _4077 = _4075;
                }
                else
                {
                    _4077 = _4063;
                }
                _9166 = _4077;
            }
            else
            {
                _9166 = false;
            }
            _9163 = _9166;
        }
        else
        {
            _9163 = false;
        }
        bool _4082 = _9139 || _9163;
        bool _4087;
        if (_4082)
        {
            bool _6416 = all(bool2(_9120.x > 0.0f.xx.x, _9120.y > 0.0f.xx.y));
            bool _6422;
            if (_6416)
            {
                _6422 = all(bool2(_9120.x < 1.0f.xx.x, _9120.y < 1.0f.xx.y));
            }
            else
            {
                _6422 = _6416;
            }
            _4087 = _6422;
        }
        else
        {
            _4087 = _4082;
        }
        bool _4092;
        if (_4087)
        {
            bool _6427 = all(bool2(_9122.x > 0.0f.xx.x, _9122.y > 0.0f.xx.y));
            bool _6433;
            if (_6427)
            {
                _6433 = all(bool2(_9122.x < 1.0f.xx.x, _9122.y < 1.0f.xx.y));
            }
            else
            {
                _6433 = _6427;
            }
            _4092 = _6433;
        }
        else
        {
            _4092 = _4087;
        }
        float4 _9257;
        if (_4092)
        {
            float _4095 = _6291.x;
            float _4097 = _6291.y;
            float _4098 = _4095 + _4097;
            float _4103 = _6291.z + _6291.w;
            float _9181;
            if (_4098 > 0.001000000047497451305389404296875f)
            {
                _9181 = _4095 / _4098;
            }
            else
            {
                _9181 = _4004;
            }
            _9257 = float4(_4095 + (_4103 * _9181), _4097 + (_4103 * (1.0f - _9181)), 0.0f, 0.0f);
        }
        else
        {
            _9257 = _6291;
        }
        bool _6461 = (cbFI_pad0 & 1024u) != 0u;
        bool _6437 = !_6461;
        bool _6438 = !_6437;
        bool _6455;
        if (_6438)
        {
            _6455 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9150.y * cbFI_MvDepthLaneSize.x) + _9150.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6455 = _6437;
        }
        bool _6487;
        if (_6438)
        {
            _6487 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3795.y * cbFI_FlowLaneSize.x) + _3795.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6487 = _6437;
        }
        float _4138 = float(_6487);
        bool _9269;
        float4 _9299;
        float3 _10058;
        if (_6461)
        {
            bool _4148;
            if (_6455)
            {
                _4148 = all(bool2(_9120.x > 0.0f.xx.x, _9120.y > 0.0f.xx.y));
            }
            else
            {
                _4148 = _6455;
            }
            bool _4154;
            if (_4148)
            {
                _4154 = all(bool2(_9120.x < 1.0f.xx.x, _9120.y < 1.0f.xx.y));
            }
            else
            {
                _4154 = _4148;
            }
            bool _4161;
            if (_6455)
            {
                _4161 = all(bool2(_9122.x > 0.0f.xx.x, _9122.y > 0.0f.xx.y));
            }
            else
            {
                _4161 = _6455;
            }
            bool _4167;
            if (_4161)
            {
                _4167 = all(bool2(_9122.x < 1.0f.xx.x, _9122.y < 1.0f.xx.y));
            }
            else
            {
                _4167 = _4161;
            }
            bool _4174;
            if (_6487)
            {
                _4174 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
            }
            else
            {
                _4174 = _6487;
            }
            bool _4180;
            if (_4174)
            {
                _4180 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
            }
            else
            {
                _4180 = _4174;
            }
            bool _4187;
            if (_6487)
            {
                _4187 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
            }
            else
            {
                _4187 = _6487;
            }
            bool _4193;
            if (_4187)
            {
                _4193 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
            }
            else
            {
                _4193 = _4187;
            }
            bool _4195 = !_6455;
            if (_4195)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6529;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6529);
                }
            }
            bool _4200 = !_6487;
            if (_4200)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6539;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6539);
                }
            }
            if (_6455 && _4200)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6549;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6549);
                }
            }
            if (_4195 && _6487)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6559;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6559);
                }
            }
            float _4219 = float(_4154);
            float _4221 = float(_4167);
            bool _4224 = _4180 && _4193;
            float _9215;
            if (_4224)
            {
                _9215 = 1.0f;
            }
            else
            {
                _9215 = (_4180 || _4193) ? 0.5f : 0.0f;
            }
            bool _9220;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4154)) && (!_4167))
            {
                bool _4254;
                if (_4224)
                {
                    float _9218;
                    do
                    {
                        bool _6643 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                        bool _6649;
                        if (_6643)
                        {
                            _6649 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6649 = _6643;
                        }
                        bool _6580 = !_6649;
                        bool _6587;
                        if (!_6580)
                        {
                            bool _6654 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                            bool _6660;
                            if (_6654)
                            {
                                _6660 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6660 = _6654;
                            }
                            _6587 = !_6660;
                        }
                        else
                        {
                            _6587 = _6580;
                        }
                        if (_6587)
                        {
                            _9218 = 0.0f;
                            break;
                        }
                        uint _6667_dummy_parameter;
                        uint _6683_dummy_parameter;
                        float4 _6608 = mul(float4((float2(_9123.x, 1.0f - _9123.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6667_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6610 = _6608.w;
                        if (abs(_6610) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9218 = 0.0f;
                            break;
                        }
                        float _6621 = abs(cbFI_DeviceToViewDepth.y / ((_6608.z / _6610) - cbFI_DeviceToViewDepth.x));
                        float _6624 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6683_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9218 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6621 - _6624) / max(max(_6621, _6624), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4254 = _9218 >= 0.5f;
                }
                else
                {
                    _4254 = _4224;
                }
                bool _9221;
                if (_4254)
                {
                    uint _6733_dummy_parameter;
                    float2 _9219;
                    do
                    {
                        float _6759 = 1.0f - _9123.y;
                        float4 _6770 = mul(float4((float2(_9123.x, _6759) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6733_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6772 = _6770.w;
                        if (!(_6772 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9219 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6785 = ((_6770.xy / _6772.xx) + 1.0f.xx) * 0.5f;
                        _9219 = float2(_6785.x - _9123.x, _6759 - _6785.y);
                        break;
                    } while(false);
                    float2 _4268 = float2(cbFI_DisplaySize);
                    _9221 = length(((_9123 + _9219) - _9124) * _4268) <= ((0.100000001490116119384765625f * length(_9219 * _4268)) + 8.0f);
                }
                else
                {
                    _9221 = _4254;
                }
                _9220 = _9221;
            }
            else
            {
                _9220 = true;
            }
            bool _4282 = !_9220;
            bool _10725 = _4282 ? false : _4193;
            bool _10726 = _4282 ? false : _4180;
            bool _9270;
            float4 _9300;
            if (!(((_4154 && _4167) && _10726) && _10725))
            {
                float4 _4304 = _9257 * float4(_4219, _4221, float(_10726), float(_10725));
                float _4306 = dot(_4304, 1.0f.xxxx);
                bool _4309 = !(_4306 > 0.0f);
                float4 _9301;
                if (!_4309)
                {
                    _9301 = _4304 / _4306.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6807;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6807);
                    }
                    _9301 = 0.0f.xxxx;
                }
                _9300 = _9301;
                _9270 = _4309;
            }
            else
            {
                _9300 = _9257;
                _9270 = false;
            }
            _10058 = float3(_4219, _4221, _9215);
            _9299 = _9300;
            _9269 = _9270;
        }
        else
        {
            _10058 = float3(float(_6455), _4138, 0.0f);
            _9299 = _9257;
            _9269 = false;
        }
        float4 _9788;
        bool _9808;
        float3 _9921;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9269))
        {
            bool _4332 = _9299.x > 0.00999999977648258209228515625f;
            bool _4335 = _9299.y > 0.00999999977648258209228515625f;
            bool _4344 = (_9299.z + _9299.w) > 0.0199999995529651641845703125f;
            bool _4350;
            if (_4344)
            {
                bool _6813 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                bool _6819;
                if (_6813)
                {
                    _6819 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                }
                else
                {
                    _6819 = _6813;
                }
                _4350 = _6819;
            }
            else
            {
                _4350 = _4344;
            }
            bool _4355;
            if (_4350)
            {
                bool _6824 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                bool _6830;
                if (_6824)
                {
                    _6830 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                }
                else
                {
                    _6830 = _6824;
                }
                _4355 = _6830;
            }
            else
            {
                _4355 = _4350;
            }
            bool _4362;
            if (_4355)
            {
                float _9303;
                do
                {
                    bool _6913 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                    bool _6919;
                    if (_6913)
                    {
                        _6919 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6919 = _6913;
                    }
                    bool _6850 = !_6919;
                    bool _6857;
                    if (!_6850)
                    {
                        bool _6924 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                        bool _6930;
                        if (_6924)
                        {
                            _6930 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6930 = _6924;
                        }
                        _6857 = !_6930;
                    }
                    else
                    {
                        _6857 = _6850;
                    }
                    if (_6857)
                    {
                        _9303 = 0.0f;
                        break;
                    }
                    uint _6937_dummy_parameter;
                    uint _6953_dummy_parameter;
                    float4 _6878 = mul(float4((float2(_9123.x, 1.0f - _9123.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6937_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6880 = _6878.w;
                    if (abs(_6880) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9303 = 0.0f;
                        break;
                    }
                    float _6891 = abs(cbFI_DeviceToViewDepth.y / ((_6878.z / _6880) - cbFI_DeviceToViewDepth.x));
                    float _6894 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6953_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9303 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6891 - _6894) / max(max(_6891, _6894), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4362 = _9303 < 0.5f;
            }
            else
            {
                _4362 = _4355;
            }
            float4 _9318;
            if (_4362)
            {
                uint _7003_dummy_parameter;
                uint _7034_dummy_parameter;
                float4 _9319;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7003_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7034_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9319 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9319 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9318 = _9319;
            }
            else
            {
                _9318 = 1.0f.xxxx;
            }
            bool _4386;
            if (_6455)
            {
                bool _7063 = all(bool2(_9120.x > 0.0f.xx.x, _9120.y > 0.0f.xx.y));
                bool _7069;
                if (_7063)
                {
                    _7069 = all(bool2(_9120.x < 1.0f.xx.x, _9120.y < 1.0f.xx.y));
                }
                else
                {
                    _7069 = _7063;
                }
                _4386 = _7069;
            }
            else
            {
                _4386 = _6455;
            }
            bool _4392;
            if (_6455)
            {
                bool _7074 = all(bool2(_9122.x > 0.0f.xx.x, _9122.y > 0.0f.xx.y));
                bool _7080;
                if (_7074)
                {
                    _7080 = all(bool2(_9122.x < 1.0f.xx.x, _9122.y < 1.0f.xx.y));
                }
                else
                {
                    _7080 = _7074;
                }
                _4392 = _7080;
            }
            else
            {
                _4392 = _6455;
            }
            bool _4398;
            if (_6487)
            {
                bool _7085 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                bool _7091;
                if (_7085)
                {
                    _7091 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                }
                else
                {
                    _7091 = _7085;
                }
                _4398 = _7091;
            }
            else
            {
                _4398 = _6487;
            }
            bool _4404;
            if (_6487)
            {
                bool _7096 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                bool _7102;
                if (_7096)
                {
                    _7102 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                }
                else
                {
                    _7102 = _7096;
                }
                _4404 = _7102;
            }
            else
            {
                _4404 = _6487;
            }
            bool _4407 = _4398 != _4404;
            bool _4413;
            if (_4407)
            {
                _4413 = _4386 || _4392;
            }
            else
            {
                _4413 = _4407;
            }
            float4 _9400;
            if (_4413)
            {
                float4 _8993 = _9318;
                _8993.z = 0.0f;
                _8993.w = 0.0f;
                _9400 = _8993;
            }
            else
            {
                _9400 = _9318;
            }
            bool _4420 = _4386 && _4332;
            bool _4423 = _4392 && _4335;
            float4 _9505;
            float3 _9958;
            if (_4420 || _4423)
            {
                float _9395;
                do
                {
                    uint4 _7241 = r_warped_motion_qdata_tp1.Load(int3(_9150, 0));
                    uint _7242 = _7241.x;
                    if (_7242 != 0u)
                    {
                        float _9394;
                        if (_7242 == 0u)
                        {
                            _9394 = -1.0f;
                        }
                        else
                        {
                            _9394 = float((_7242 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9395 = _9394;
                        break;
                    }
                    int _9377;
                    uint _9378;
                    _9378 = _7242;
                    _9377 = -1;
                    uint _9393;
                    for (; _9377 <= 1; _9378 = _9393, _9377++)
                    {
                        _9393 = _9378;
                        for (int _9391 = -1; _9391 <= 1; )
                        {
                            _9393 = max(_9393, r_warped_motion_qdata_tp1.Load(int3(clamp(_9150 + int2(_9391, _9377), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9391++;
                            continue;
                        }
                    }
                    if (_9378 != 0u)
                    {
                        float _9390;
                        if (_9378 == 0u)
                        {
                            _9390 = -1.0f;
                        }
                        else
                        {
                            _9390 = float((_9378 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9395 = _9390;
                        break;
                    }
                    uint _9380;
                    _9380 = 4294967295u;
                    uint _10697;
                    for (int _9379 = 0; _9379 < 8; _9380 = _10697, _9379++)
                    {
                        int _9383 = 0;
                        for (;;)
                        {
                            if (_9383 < 5)
                            {
                                int2 _7192 = _9150 + (_1093[_9379] * _1102[_9383].xx);
                                bool _7195 = any(bool2(_7192.x < int2(0, 0).x, _7192.y < int2(0, 0).y));
                                bool _7203;
                                if (!_7195)
                                {
                                    _7203 = any(bool2(_7192.x >= cbFI_MvDepthLaneSize.x, _7192.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7203 = _7195;
                                }
                                if (_7203)
                                {
                                    _10697 = _9380;
                                    break;
                                }
                                uint4 _7281 = r_warped_motion_qdata_tp1.Load(int3(_7192, 0));
                                uint _7282 = _7281.x;
                                if (_7282 != 0u)
                                {
                                    _10697 = min(_9380, _7282);
                                    break;
                                }
                                _9383++;
                                continue;
                            }
                            else
                            {
                                _10697 = _9380;
                                break;
                            }
                        }
                    }
                    float _9382;
                    if (_9380 == 4294967295u)
                    {
                        _9382 = -1.0f;
                    }
                    else
                    {
                        float _9381;
                        if (_9380 == 0u)
                        {
                            _9381 = -1.0f;
                        }
                        else
                        {
                            _9381 = float((_9380 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9382 = _9381;
                    }
                    _9395 = _9382;
                    break;
                } while(false);
                bool _4431 = _9395 < 0.0f;
                float _9396;
                if (_4431)
                {
                    _9396 = 0.0f;
                }
                else
                {
                    _9396 = _9395 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7303_dummy_parameter;
                uint _7335_dummy_parameter;
                float4 _9433;
                if ((_4431 && _4420) && _4423)
                {
                    uint _7367_dummy_parameter;
                    float _7391 = log((r_depth_tm1.Load(int3(int2(floor(_9120 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7367_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7399_dummy_parameter;
                    float _7423 = log((r_depth_tp1.Load(int3(int2(floor(_9122 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7399_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9434;
                    if (_7391 > (_7423 + 0.07999999821186065673828125f))
                    {
                        float4 _8997 = _9400;
                        _8997.x = 0.0f;
                        _9434 = _8997;
                    }
                    else
                    {
                        float4 _9435;
                        if (_7423 > (_7391 + 0.07999999821186065673828125f))
                        {
                            float4 _8999 = _9400;
                            _8999.y = 0.0f;
                            _9435 = _8999;
                        }
                        else
                        {
                            _9435 = _9400;
                        }
                        _9434 = _9435;
                    }
                    _9433 = _9434;
                }
                else
                {
                    _9433 = _9400;
                }
                float _4483 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4485 = _9395 >= 0.0f;
                float _9416;
                if (_4485)
                {
                    _9416 = _9395 - _4483;
                }
                else
                {
                    float _9412;
                    if (_4420)
                    {
                        float _9411;
                        _9411 = 2.0f;
                        float _7481;
                        for (int _9410 = 0; _9410 < 24; _9411 = _7481, _9410++)
                        {
                            float _7445 = float(_9410 & 7) * 0.785398185253143310546875f;
                            int _7447 = _9410 >> 3;
                            int _9413;
                            if (_7447 == 0)
                            {
                                _9413 = 16;
                            }
                            else
                            {
                                _9413 = (_7447 == 1) ? 48 : 96;
                            }
                            uint _7497_dummy_parameter;
                            _7481 = min(_9411, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9120 + ((cbFI_MvDepthLaneSizeRcp * float(_9413)) * float2(cos(_7445), sin(_7445))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7497_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9412 = _9411;
                    }
                    else
                    {
                        _9412 = 0.0f;
                    }
                    _9416 = _9412;
                }
                float _9423;
                if (_4485)
                {
                    _9423 = _9395 - _4483;
                }
                else
                {
                    float _9419;
                    if (_4423)
                    {
                        float _9418;
                        _9418 = 2.0f;
                        float _7595;
                        for (int _9417 = 0; _9417 < 24; _9418 = _7595, _9417++)
                        {
                            float _7559 = float(_9417 & 7) * 0.785398185253143310546875f;
                            int _7561 = _9417 >> 3;
                            int _9420;
                            if (_7561 == 0)
                            {
                                _9420 = 16;
                            }
                            else
                            {
                                _9420 = (_7561 == 1) ? 48 : 96;
                            }
                            uint _7627_dummy_parameter;
                            _7595 = min(_9418, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9122 + ((cbFI_MvDepthLaneSizeRcp * float(_9420)) * float2(cos(_7559), sin(_7559))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7627_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9419 = _9418;
                    }
                    else
                    {
                        _9419 = 0.0f;
                    }
                    _9423 = _9419;
                }
                float _9424;
                if (_4420)
                {
                    uint _7659_dummy_parameter;
                    _9424 = r_depth_tm1.Load(int3(int2(floor(_9120 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7659_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9424 = 0.0f;
                }
                float _9425;
                if (_4423)
                {
                    uint _7678_dummy_parameter;
                    _9425 = r_depth_tp1.Load(int3(int2(floor(_9122 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7678_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9425 = 0.0f;
                }
                bool _4540;
                if (_4420)
                {
                    _4540 = _9424 > ((exp((_9416 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4540 = _4420;
                }
                float4 _9441;
                if (_4540)
                {
                    float4 _9001 = _9433;
                    _9001.x = 0.0f;
                    _9441 = _9001;
                }
                else
                {
                    _9441 = _9433;
                }
                bool _4552;
                if (_4423)
                {
                    _4552 = _9425 > ((exp((_9423 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4552 = _4423;
                }
                float4 _9443;
                if (_4552)
                {
                    float4 _9003 = _9441;
                    _9003.y = 0.0f;
                    _9443 = _9003;
                }
                else
                {
                    _9443 = _9441;
                }
                float4 _9506;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4485)
                {
                    bool _4572;
                    if (_4420)
                    {
                        _4572 = _9424 < ((exp((_9416 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4572 = _4420;
                    }
                    float4 _9445;
                    if (_4572)
                    {
                        float4 _9005 = _9443;
                        _9005.x = 0.0f;
                        _9445 = _9005;
                    }
                    else
                    {
                        _9445 = _9443;
                    }
                    bool _4584;
                    if (_4423)
                    {
                        _4584 = _9425 < ((exp((_9423 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4584 = _4423;
                    }
                    float4 _9507;
                    if (_4584)
                    {
                        float4 _9007 = _9445;
                        _9007.y = 0.0f;
                        _9507 = _9007;
                    }
                    else
                    {
                        _9507 = _9445;
                    }
                    _9506 = _9507;
                }
                else
                {
                    _9506 = _9443;
                }
                _9958 = float3(_9396, log((r_depth_tm1.Load(int3(int2(floor(_9120 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7303_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9122 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7335_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9505 = _9506;
            }
            else
            {
                _9958 = float3(0.0f, 0.0f, 0.5f);
                _9505 = _9400;
            }
            bool _4595 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4344;
            bool _4601;
            if (_4595)
            {
                _4601 = _4398 || _4404;
            }
            else
            {
                _4601 = _4595;
            }
            float4 _9527;
            if (_4601)
            {
                float _9500;
                do
                {
                    uint4 _7857 = r_warped_motion_qdata_tp1.Load(int3(_9150, 0));
                    uint _7858 = _7857.x;
                    if (_7858 != 0u)
                    {
                        float _9499;
                        if (_7858 == 0u)
                        {
                            _9499 = -1.0f;
                        }
                        else
                        {
                            _9499 = float((_7858 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9500 = _9499;
                        break;
                    }
                    int _9482;
                    uint _9483;
                    _9483 = _7858;
                    _9482 = -1;
                    uint _9498;
                    for (; _9482 <= 1; _9483 = _9498, _9482++)
                    {
                        _9498 = _9483;
                        for (int _9496 = -1; _9496 <= 1; )
                        {
                            _9498 = max(_9498, r_warped_motion_qdata_tp1.Load(int3(clamp(_9150 + int2(_9496, _9482), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9496++;
                            continue;
                        }
                    }
                    if (_9483 != 0u)
                    {
                        float _9495;
                        if (_9483 == 0u)
                        {
                            _9495 = -1.0f;
                        }
                        else
                        {
                            _9495 = float((_9483 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9500 = _9495;
                        break;
                    }
                    uint _9485;
                    _9485 = 4294967295u;
                    uint _10698;
                    for (int _9484 = 0; _9484 < 8; _9485 = _10698, _9484++)
                    {
                        int _9488 = 0;
                        for (;;)
                        {
                            if (_9488 < 5)
                            {
                                int2 _7808 = _9150 + (_1093[_9484] * _1102[_9488].xx);
                                bool _7811 = any(bool2(_7808.x < int2(0, 0).x, _7808.y < int2(0, 0).y));
                                bool _7819;
                                if (!_7811)
                                {
                                    _7819 = any(bool2(_7808.x >= cbFI_MvDepthLaneSize.x, _7808.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7819 = _7811;
                                }
                                if (_7819)
                                {
                                    _10698 = _9485;
                                    break;
                                }
                                uint4 _7897 = r_warped_motion_qdata_tp1.Load(int3(_7808, 0));
                                uint _7898 = _7897.x;
                                if (_7898 != 0u)
                                {
                                    _10698 = min(_9485, _7898);
                                    break;
                                }
                                _9488++;
                                continue;
                            }
                            else
                            {
                                _10698 = _9485;
                                break;
                            }
                        }
                    }
                    float _9487;
                    if (_9485 == 4294967295u)
                    {
                        _9487 = -1.0f;
                    }
                    else
                    {
                        float _9486;
                        if (_9485 == 0u)
                        {
                            _9486 = -1.0f;
                        }
                        else
                        {
                            _9486 = float((_9485 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9487 = _9486;
                    }
                    _9500 = _9487;
                    break;
                } while(false);
                float4 _9528;
                if (_9500 >= 0.0f)
                {
                    float _7919 = (exp((_9500 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4620;
                    if (_4398)
                    {
                        uint _7926_dummy_parameter;
                        _4620 = r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7926_dummy_parameter))))), 0)).x > _7919;
                    }
                    else
                    {
                        _4620 = _4398;
                    }
                    float4 _9518;
                    if (_4620)
                    {
                        float4 _9009 = _9505;
                        _9009.z = 0.0f;
                        _9518 = _9009;
                    }
                    else
                    {
                        _9518 = _9505;
                    }
                    bool _4632;
                    if (_4404)
                    {
                        uint _7945_dummy_parameter;
                        _4632 = r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7945_dummy_parameter))))), 0)).x > _7919;
                    }
                    else
                    {
                        _4632 = _4404;
                    }
                    float4 _9529;
                    if (_4632)
                    {
                        float4 _9011 = _9518;
                        _9011.w = 0.0f;
                        _9529 = _9011;
                    }
                    else
                    {
                        _9529 = _9518;
                    }
                    _9528 = _9529;
                }
                else
                {
                    _9528 = _9505;
                }
                _9527 = _9528;
            }
            else
            {
                _9527 = _9505;
            }
            bool _4640 = _4386 != _4392;
            bool _4647;
            if (_4640)
            {
                _4647 = _4386 ? _4332 : _4335;
            }
            else
            {
                _4647 = _4640;
            }
            float4 _9611;
            if (_4647)
            {
                bool2 _4652 = _4386.xx;
                float2 _4653 = float2(_4652.x ? _9120.x : _9122.x, _4652.y ? _9120.y : _9122.y);
                float _9520;
                if (_4386)
                {
                    uint _7964_dummy_parameter;
                    _9520 = r_depth_tm1.Load(int3(int2(floor(_4653 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7964_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7980_dummy_parameter;
                    _9520 = r_depth_tp1.Load(int3(int2(floor(_4653 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7980_dummy_parameter))))), 0)).x;
                }
                float4x4 _9521;
                if (_4386)
                {
                    _9521 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9521 = cbFI_MotionTP1ToTM1;
                }
                float2 _9522;
                do
                {
                    float _8007 = _4653.x;
                    float _8010 = 1.0f - _4653.y;
                    float4 _8021 = mul(float4((float2(_8007, _8010) * 2.0f) - 1.0f.xx, _9520, 1.0f), _9521);
                    float _8023 = _8021.w;
                    if (!(_8023 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9522 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8036 = ((_8021.xy / _8023.xx) + 1.0f.xx) * 0.5f;
                    _9522 = float2(_8036.x - _8007, _8010 - _8036.y);
                    break;
                } while(false);
                float2 _4683 = float2(cbFI_DisplaySize);
                float4 _9612;
                if (!(length(((_4653 + _9522) - float2(_4652.x ? _9122.x : _9120.x, _4652.y ? _9122.y : _9120.y)) * _4683) <= ((0.100000001490116119384765625f * length(_9522 * _4683)) + 8.0f)))
                {
                    float4 _9613;
                    if (_4386)
                    {
                        float4 _9021 = _9527;
                        _9021.x = 0.0f;
                        _9613 = _9021;
                    }
                    else
                    {
                        float4 _9023 = _9527;
                        _9023.y = 0.0f;
                        _9613 = _9023;
                    }
                    _9612 = _9613;
                }
                else
                {
                    _9612 = _9527;
                }
                _9611 = _9612;
            }
            else
            {
                _9611 = _9527;
            }
            float4 _4708 = _9299 * _9611;
            float _4710 = dot(_4708, 1.0f.xxxx);
            float4 _9789;
            bool _9809;
            if (_4710 > 0.0f)
            {
                _9809 = _9269;
                _9789 = _4708 / _4710.xxxx;
            }
            else
            {
                bool _4721 = any(bool4(_9611.x < 1.0f.xxxx.x, _9611.y < 1.0f.xxxx.y, _9611.z < 1.0f.xxxx.z, _9611.w < 1.0f.xxxx.w));
                if (_4721)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8058;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8058);
                    }
                }
                bool4 _10728 = _4721.xxxx;
                _9809 = _4721 ? true : _9269;
                _9789 = float4(_10728.x ? 0.0f.xxxx.x : _9299.x, _10728.y ? 0.0f.xxxx.y : _9299.y, _10728.z ? 0.0f.xxxx.z : _9299.z, _10728.w ? 0.0f.xxxx.w : _9299.w);
            }
            _9921 = _9958;
            _9808 = _9809;
            _9788 = _9789;
        }
        else
        {
            _9921 = float3(0.0f, 0.0f, 0.5f);
            _9808 = _9269;
            _9788 = _9299;
        }
        uint _4730 = (cbFI_pad0 >> 24u) & 31u;
        uint _4734 = (cbFI_pad0 >> 16u) & 255u;
        bool _4736 = _4730 != 0u;
        bool _4738 = _4734 == 12u;
        bool _4741 = _4734 == 13u;
        float4 _9805;
        if ((_4736 || _4738) || _4741)
        {
            float _9614;
            do
            {
                bool _8142 = all(bool2(_9123.x > 0.0f.xx.x, _9123.y > 0.0f.xx.y));
                bool _8148;
                if (_8142)
                {
                    _8148 = all(bool2(_9123.x < 1.0f.xx.x, _9123.y < 1.0f.xx.y));
                }
                else
                {
                    _8148 = _8142;
                }
                bool _8079 = !_8148;
                bool _8086;
                if (!_8079)
                {
                    bool _8153 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
                    bool _8159;
                    if (_8153)
                    {
                        _8159 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8159 = _8153;
                    }
                    _8086 = !_8159;
                }
                else
                {
                    _8086 = _8079;
                }
                if (_8086)
                {
                    _9614 = 0.0f;
                    break;
                }
                uint _8166_dummy_parameter;
                uint _8182_dummy_parameter;
                float4 _8107 = mul(float4((float2(_9123.x, 1.0f - _9123.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9123 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8166_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8109 = _8107.w;
                if (abs(_8109) < 9.9999999747524270787835121154785e-07f)
                {
                    _9614 = 0.0f;
                    break;
                }
                float _8120 = abs(cbFI_DeviceToViewDepth.y / ((_8107.z / _8109) - cbFI_DeviceToViewDepth.x));
                float _8123 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8182_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9614 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8120 - _8123) / max(max(_8120, _8123), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8230 = all(bool2(_9124.x > 0.0f.xx.x, _9124.y > 0.0f.xx.y));
            bool _8236;
            if (_8230)
            {
                _8236 = all(bool2(_9124.x < 1.0f.xx.x, _9124.y < 1.0f.xx.y));
            }
            else
            {
                _8236 = _8230;
            }
            float _9615;
            if (_8236)
            {
                uint _8243_dummy_parameter;
                _9615 = length((_5541 + (r_motion_tp1.Load(int3(int2(floor(_9124 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8243_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9615 = 1000000.0f;
            }
            float _9626;
            if ((_4730 & 1u) != 0u)
            {
                _9626 = _9614;
            }
            else
            {
                _9626 = 1.0f;
            }
            float _9627;
            if ((_4730 & 2u) != 0u)
            {
                _9627 = _9626 * (1.0f - smoothstep(2.0f, 8.0f, _9615));
            }
            else
            {
                _9627 = _9626;
            }
            float _9628;
            if ((_4730 & 4u) != 0u)
            {
                _9628 = _9627 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6262 - _6270) - length(_6246 - _6254))));
            }
            else
            {
                _9628 = _9627;
            }
            float _9799;
            if ((_4730 & 8u) != 0u)
            {
                _9799 = lerp(1.0f, _9628, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6246 - _6254)));
            }
            else
            {
                _9799 = _9628;
            }
            bool _4816 = (_4730 & 16u) != 0u;
            bool _4825;
            if (_4816)
            {
                _4825 = length(_9118 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4825 = _4816;
            }
            float _10730 = _4825 ? 1.0f : _9799;
            bool _4831 = _4736 && _6455;
            bool _4836;
            if (_4831)
            {
                bool _8268 = all(bool2(_9120.x > 0.0f.xx.x, _9120.y > 0.0f.xx.y));
                bool _8274;
                if (_8268)
                {
                    _8274 = all(bool2(_9120.x < 1.0f.xx.x, _9120.y < 1.0f.xx.y));
                }
                else
                {
                    _8274 = _8268;
                }
                _4836 = _8274;
            }
            else
            {
                _4836 = _4831;
            }
            bool _4841;
            if (_4836)
            {
                bool _8279 = all(bool2(_9122.x > 0.0f.xx.x, _9122.y > 0.0f.xx.y));
                bool _8285;
                if (_8279)
                {
                    _8285 = all(bool2(_9122.x < 1.0f.xx.x, _9122.y < 1.0f.xx.y));
                }
                else
                {
                    _8285 = _8279;
                }
                _4841 = _8285;
            }
            else
            {
                _4841 = _4836;
            }
            float4 _9806;
            if (_4841)
            {
                float _4847 = _9788.x + _9788.y;
                float _4856 = (_9788.z + _9788.w) * (1.0f - _10730);
                float _9802;
                if (_4847 > 9.9999997473787516355514526367188e-06f)
                {
                    _9802 = _9788.x / _4847;
                }
                else
                {
                    _9802 = _4004;
                }
                _9806 = float4(_9788.x + (_4856 * _9802), _9788.y + (_4856 * (1.0f - _9802)), _9788.zw * _10730);
            }
            else
            {
                _9806 = _9788;
            }
            _9805 = _9806;
        }
        else
        {
            _9805 = _9788;
        }
        float3 _10501;
        if (_9808)
        {
            float3 _8291 = r_current_interpolation_source.Load(int3(_3404, 0)).xyz;
            float3 _10502;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6455)
            {
                uint _8298_dummy_parameter;
                float _9912;
                _9912 = r_depth_tm1.Load(int3(int2(floor(_9120 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8298_dummy_parameter))))), 0)).x;
                float _4968;
                for (int _9911 = 0; _9911 < 24; _9912 = _4968, _9911++)
                {
                    float _4940 = float(_9911 & 7) * 0.785398185253143310546875f;
                    int _4942 = _9911 >> 3;
                    int _10552;
                    if (_4942 == 0)
                    {
                        _10552 = 16;
                    }
                    else
                    {
                        _10552 = (_4942 == 1) ? 48 : 96;
                    }
                    uint _8318_dummy_parameter;
                    _4968 = min(_9912, r_depth_tm1.Load(int3(int2(floor(clamp(_9120 + ((cbFI_MvDepthLaneSizeRcp * float(_10552)) * float2(cos(_4940), sin(_4940))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8318_dummy_parameter))))), 0)).x);
                }
                float2 _9913;
                do
                {
                    float _8340 = 1.0f - _9120.y;
                    float4 _8351 = mul(float4((float2(_9120.x, _8340) * 2.0f) - 1.0f.xx, _9912, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8353 = _8351.w;
                    if (!(_8353 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9913 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8366 = ((_8351.xy / _8353.xx) + 1.0f.xx) * 0.5f;
                    _9913 = float2(_8366.x - _9120.x, _8340 - _8366.y);
                    break;
                } while(false);
                float2 _4979 = _9120 + _9913;
                bool _8384 = all(bool2(_4979.x > 0.0f.xx.x, _4979.y > 0.0f.xx.y));
                bool _8390;
                if (_8384)
                {
                    _8390 = all(bool2(_4979.x < 1.0f.xx.x, _4979.y < 1.0f.xx.y));
                }
                else
                {
                    _8390 = _8384;
                }
                float3 _10503;
                if (_8390)
                {
                    float _4985 = abs(cbFI_DeviceToViewDepth.y / (_9912 - cbFI_DeviceToViewDepth.x));
                    uint _8410_dummy_parameter;
                    int2 _8410 = int2(spvTextureSize(r_depth_m2, uint(0), _8410_dummy_parameter));
                    float _4989 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4979 * float2(_8410))), int2(0, 0), _8410 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10508;
                    if (abs(_4989 - _4985) <= (0.20000000298023223876953125f * max(_4989, _4985)))
                    {
                        uint _8444_dummy_parameter;
                        int2 _8444 = int2(spvTextureSize(r_colour_m2, uint(0), _8444_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8467;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8467);
                        }
                        _10508 = r_colour_m2.Load(int3(clamp(int2(floor(_4979 * float2(_8444))), int2(0, 0), _8444 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8477;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8477);
                        }
                        _10508 = _8291;
                    }
                    _10503 = _10508;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8487;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8487);
                    }
                    _10503 = _8291;
                }
                _10502 = _10503;
            }
            else
            {
                _10502 = _8291;
            }
            _10501 = _10502;
        }
        else
        {
            _10501 = (((_6246 * _9805.x) + (_6254 * _9805.y)) + (_6262 * _9805.z)) + (_6270 * _9805.w);
        }
        uint _5017 = cbFI_pad0 & 255u;
        bool _10394;
        float3 _10500;
        if (_5017 != 0u)
        {
            float3 _5022 = r_present_backbuffer.Load(int3(_3404, 0)).xyz;
            float3 _5026 = r_current_interpolation_source.Load(int3(_3404, 0)).xyz;
            float3 _5030 = abs(_5022 - _5026);
            float3 _9916;
            if (_5017 == 2u)
            {
                _9916 = (abs(_5026) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9916 = 0.000244140625f.xxx;
            }
            bool _5046 = any(bool3(_5030.x > _9916.x, _5030.y > _9916.y, _5030.z > _9916.z));
            bool3 _10731 = _5046.xxx;
            _10500 = float3(_10731.x ? _5022.x : _10501.x, _10731.y ? _5022.y : _10501.y, _10731.z ? _5022.z : _10501.z);
            _10394 = _5046;
        }
        else
        {
            _10500 = _10501;
            _10394 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8502;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8502);
        }
        float3 _10483;
        if (_4734 == 1u)
        {
            _10483 = lerp(_6246, _6254, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10484;
            if (_4734 == 2u)
            {
                _10484 = lerp(_6262, _6270, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10485;
                if (_4734 == 3u)
                {
                    _10485 = float(_10394).xxx;
                }
                else
                {
                    float3 _10486;
                    if (_4734 == 4u)
                    {
                        _10486 = float3(((_9118 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10487;
                        if (_4734 == 5u)
                        {
                            _10487 = float3(((_5541 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10488;
                            if (_4734 == 6u)
                            {
                                _10488 = float3(_9805.xy, _9805.z + _9805.w);
                            }
                            else
                            {
                                float3 _10489;
                                if (_4734 == 7u)
                                {
                                    _10489 = r_current_interpolation_source.Load(int3(_3404, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10490;
                                    if (_4734 == 8u)
                                    {
                                        _10490 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3779, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10491;
                                        if (_4738)
                                        {
                                            uint _8524_dummy_parameter;
                                            uint _8556_dummy_parameter;
                                            _10491 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3779 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8524_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3779 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8556_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10492;
                                            if (_4741)
                                            {
                                                _10492 = _6262;
                                            }
                                            else
                                            {
                                                float3 _10493;
                                                if (_4734 == 20u)
                                                {
                                                    _10493 = _6246;
                                                }
                                                else
                                                {
                                                    float3 _10494;
                                                    if (_4734 == 21u)
                                                    {
                                                        _10494 = _6254;
                                                    }
                                                    else
                                                    {
                                                        float3 _10495;
                                                        if (_4734 == 22u)
                                                        {
                                                            _10495 = _6270;
                                                        }
                                                        else
                                                        {
                                                            float3 _10496;
                                                            if (_4734 == 18u)
                                                            {
                                                                _10496 = _10202;
                                                            }
                                                            else
                                                            {
                                                                float3 _10497;
                                                                if (_4734 == 19u)
                                                                {
                                                                    _10497 = _10058;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10733 = (_4734 == 23u).xxx;
                                                                    _10497 = float3(_10733.x ? _9921.x : _10500.x, _10733.y ? _9921.y : _10500.y, _10733.z ? _9921.z : _10500.z);
                                                                }
                                                                _10496 = _10497;
                                                            }
                                                            _10495 = _10496;
                                                        }
                                                        _10494 = _10495;
                                                    }
                                                    _10493 = _10494;
                                                }
                                                _10492 = _10493;
                                            }
                                            _10491 = _10492;
                                        }
                                        _10490 = _10491;
                                    }
                                    _10489 = _10490;
                                }
                                _10488 = _10489;
                            }
                            _10487 = _10488;
                        }
                        _10486 = _10487;
                    }
                    _10485 = _10486;
                }
                _10484 = _10485;
            }
            _10483 = _10484;
        }
        float3 _10482;
        if ((_4734 >= 9u) && (_4734 <= 11u))
        {
            uint _5210 = 64u + uint((_9150.y * cbFI_MvDepthLaneSize.x) + _9150.x);
            uint _5214 = rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) & 15u;
            float3 _10513;
            if (_4734 == 10u)
            {
                float3 _10481;
                if ((rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) & 32u) != 0u)
                {
                    _10481 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10480;
                    if ((rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) & 16u) != 0u)
                    {
                        _10480 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5235 = ((rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) & 64u) != 0u).xxx;
                        _10480 = float3(_5235.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5235.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5235.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10481 = _10480;
                }
                _10513 = _10481;
            }
            else
            {
                float3 _10514;
                if (_4734 == 11u)
                {
                    uint _5248 = (rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) >> 8u) & 15u;
                    uint _5251 = (rw_nfru_diagnostics.Load<uint>(_5210 * 4 + 0) >> 12u) & 15u;
                    float3 _10473;
                    if ((_5214 == 2u) || (_5214 == 3u))
                    {
                        _10473 = _3100[_5214];
                    }
                    else
                    {
                        bool _5263 = _5248 == 3u;
                        bool _5265 = _5251 == 3u;
                        float3 _10474;
                        if (_5263 && _5265)
                        {
                            _10474 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10475;
                            if (_5263)
                            {
                                _10475 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10476;
                                if (_5265)
                                {
                                    _10476 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10477;
                                    if ((_5248 == 4u) || (_5251 == 4u))
                                    {
                                        _10477 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10478;
                                        if ((_5248 == 1u) || (_5251 == 1u))
                                        {
                                            _10478 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10735 = (_5214 == 1u).xxx;
                                            _10478 = float3(_10735.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10735.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10735.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10477 = _10478;
                                    }
                                    _10476 = _10477;
                                }
                                _10475 = _10476;
                            }
                            _10474 = _10475;
                        }
                        _10473 = _10474;
                    }
                    _10514 = _10473;
                }
                else
                {
                    _10514 = _3100[min(_5214, 7u)];
                }
                _10513 = _10514;
            }
            _10482 = _10513;
        }
        else
        {
            _10482 = _10483;
        }
        float4 _10517;
        if ((_4734 >= 14u) && (_4734 <= 16u))
        {
            float2 _10515;
            if (_4734 == 14u)
            {
                uint _5321_dummy_parameter;
                uint _5327_dummy_parameter;
                _10515 = r_flow_tm1.Load(int3(clamp(int2(floor(_3779 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5321_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5327_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10516;
                if (_4734 == 16u)
                {
                    uint _8607 = r_warped_flow_qdata_tm1.Load(int3(_3795, 0)).x & 2147483647u;
                    uint _8639 = uint(max((int((_8607 >> 16u) & 15u) - 6), 0));
                    _10516 = ((float2(float((1 - (2 * int((_8607 >> 15u) & 1u))) * int(((_8607 >> uint(7)) & 127u) << _8639)), float((1 - (2 * int((_8607 >> 14u) & 1u))) * int((_8607 & 127u) << _8639))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10516 = _5541 * float2(cbFI_DisplaySize);
                }
                _10515 = _10516;
            }
            uint2 _5360 = uint2(clamp(round(_10515 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5362 = _5360.x;
            uint _5369 = _5360.y;
            _10517 = float4(float(_5362 & 255u), float((_5362 >> 8u) | ((_5369 & 15u) << 4u)), float(_5369 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10518;
            if (_4734 == 17u)
            {
                _10518 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3795, 0)).x != 0u), _4138, 0.0f, 1.0f);
            }
            else
            {
                _10518 = float4(_10482, 1.0f);
            }
            _10517 = _10518;
        }
        rw_output[_3404] = _10517.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5413 = ((uint(_3404.y) * uint(cbFI_DisplaySize.x)) + uint(_3404.x)) * 6u;
            uint _8685 = spvPackHalf2x16(clamp(_6245.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5413 * 4 + 0, (((_8685 & 32767u) >> 4u) | ((((_8685 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6245.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8720 = spvPackHalf2x16(clamp(_6253.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5413 + 1u) * 4 + 0, (((_8720 & 32767u) >> 4u) | ((((_8720 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6253.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8755 = spvPackHalf2x16(clamp(_6261.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5413 + 2u) * 4 + 0, (((_8755 & 32767u) >> 4u) | ((((_8755 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6261.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8790 = spvPackHalf2x16(clamp(_6269.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5413 + 3u) * 4 + 0, (((_8790 & 32767u) >> 4u) | ((((_8790 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6269.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8817 = r_current_interpolation_source.Load(int3(_3404, 0));
            uint _8831 = spvPackHalf2x16(clamp(_8817.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5413 + 4u) * 4 + 0, (((_8831 & 32767u) >> 4u) | ((((_8831 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8817.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10551;
            if (_10394 || (_4734 != 0u))
            {
                _10551 = 4294967295u;
            }
            else
            {
                uint _8866 = spvPackHalf2x16(clamp(_10517.xy, 0.0f.xx, 65000.0f.xx));
                _10551 = (((_8866 & 32767u) >> 4u) | ((((_8866 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10517.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5413 + 5u) * 4 + 0, _10551);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3404] = float4(r_current_interpolation_source.Load(int3(_3404, 0)).xyz, 1.0f).xyz;
        }
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
