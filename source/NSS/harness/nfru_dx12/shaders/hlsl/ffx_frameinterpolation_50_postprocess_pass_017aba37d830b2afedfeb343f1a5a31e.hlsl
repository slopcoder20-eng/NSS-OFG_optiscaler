static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3082[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3369 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3369.x >= cbFI_DisplaySize.x, _3369.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3369] = float4(r_present_backbuffer.Load(int3(_3369, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3731 = (float2(_3369) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3742 = int2(floor(_3731 * float2(cbFI_MvDepthLaneSize)));
        int2 _3747 = int2(floor(_3731 * float2(cbFI_FlowLaneSize)));
        float4 _5463 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3731 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5469 = r_warped_filled_flow_tm1.Load(int3(_3747, 0)).xy;
        float2 _5475 = r_warped_filled_motion_tp1.Load(int3(_3742, 0)).xy;
        bool _5497 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9019;
        if (_5497)
        {
            float _5510 = ((2.0f * _3731.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9019 = float2(atan(_5510) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3731.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5510 * _5510))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9019 = _3731;
        }
        bool _3768 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9040;
        bool _9061;
        int2 _9072;
        float3 _10124;
        if (_3768)
        {
            float _9021;
            float _9023;
            _9023 = 2.0f;
            _9021 = -1.0f;
            uint _3431[9];
            float _10515;
            float _10518;
            for (int _9020 = 0; _9020 < 9; _9023 = _10518, _9021 = _10515, _9020++)
            {
                _3431[_9020] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3742 + int2((_9020 % 3) - 1, (_9020 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3431[_9020] != 0u)
                {
                    float _10510;
                    if (_3431[_9020] == 0u)
                    {
                        _10510 = -1.0f;
                    }
                    else
                    {
                        _10510 = float((_3431[_9020] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10518 = min(_9023, _10510);
                    _10515 = max(_9021, _10510);
                }
                else
                {
                    _10518 = _9023;
                    _10515 = _9021;
                }
            }
            float _3814 = float(_9021 >= 0.0f);
            float3 _8830 = 0.0f.xxx;
            _8830.y = _3814;
            float2 _9041;
            bool _9062;
            int2 _9073;
            float3 _10125;
            if ((_9021 - _9023) > 0.0199999995529651641845703125f)
            {
                float _9029;
                int2 _9030;
                float2 _9031;
                int2 _9033;
                float2 _9039;
                _9039 = _5475;
                _9033 = _3742;
                _9031 = _5475;
                _9030 = _3742;
                _9029 = -1.0f;
                float _10523;
                int2 _10527;
                float2 _10538;
                int2 _10549;
                float2 _10582;
                float _10628;
                int _9028 = 0;
                float _10491 = 1000000000.0f;
                for (; _9028 < 9; _10491 = _10628, _9039 = _10582, _9033 = _10549, _9031 = _10538, _9030 = _10527, _9029 = _10523, _9028++)
                {
                    if (_3431[_9028] == 0u)
                    {
                        _10628 = _10491;
                        _10582 = _9039;
                        _10549 = _9033;
                        _10538 = _9031;
                        _10527 = _9030;
                        _10523 = _9029;
                        continue;
                    }
                    int2 _3849 = clamp(_3742 + int2((_9028 % 3) - 1, (_9028 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5585 = _3431[_9028] & 2147483647u;
                    uint _5617 = uint(max((int((_5585 >> 16u) & 15u) - 6), 0));
                    float2 _3855 = (float2(float((1 - (2 * int((_5585 >> 15u) & 1u))) * int(((_5585 >> uint(7)) & 127u) << _5617)), float((1 - (2 * int((_5585 >> 14u) & 1u))) * int((_5585 & 127u) << _5617))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10477;
                    if (_3431[_9028] == 0u)
                    {
                        _10477 = -1.0f;
                    }
                    else
                    {
                        _10477 = float((_3431[_9028] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3860 = _10477 - 0.100000001490116119384765625f;
                    float2 _10478;
                    if (_5497)
                    {
                        float2 _5694 = clamp((((_9019 + (_3855 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5697 = tan(_5694.x);
                        _10478 = (float2(_5697 / cbFI_DeviceToViewDepth.z, (tan(_5694.y) * sqrt(1.0f + (_5697 * _5697))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10478 = _9019 + (_3855 * cbFI_Timestep);
                    }
                    float _3867 = cbFI_Timestep - 1.0f;
                    float2 _10479;
                    if (_5497)
                    {
                        float2 _5765 = clamp((((_9019 + (_3855 * _3867)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5768 = tan(_5765.x);
                        _10479 = (float2(_5768 / cbFI_DeviceToViewDepth.z, (tan(_5765.y) * sqrt(1.0f + (_5768 * _5768))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10479 = _9019 + (_3855 * _3867);
                    }
                    bool _5801 = all(bool2(_10478.x > 0.0f.xx.x, _10478.y > 0.0f.xx.y));
                    bool _5807;
                    if (_5801)
                    {
                        _5807 = all(bool2(_10478.x < 1.0f.xx.x, _10478.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5807 = _5801;
                    }
                    float _10482;
                    if (_5807)
                    {
                        uint _5814_dummy_parameter;
                        _10482 = max((_3860 - (log(((r_depth_tm1.Load(int3(int2(floor(_10478 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5814_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10482 = 0.0f;
                    }
                    bool _5844 = all(bool2(_10479.x > 0.0f.xx.x, _10479.y > 0.0f.xx.y));
                    bool _5850;
                    if (_5844)
                    {
                        _5850 = all(bool2(_10479.x < 1.0f.xx.x, _10479.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5850 = _5844;
                    }
                    float _10483;
                    if (_5850)
                    {
                        uint _5857_dummy_parameter;
                        _10483 = _10482 + max((_3860 - (log(((r_depth_tp1.Load(int3(int2(floor(_10479 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5857_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10483 = _10482;
                    }
                    float _10524;
                    int2 _10528;
                    float2 _10539;
                    int2 _10550;
                    float2 _10583;
                    float _10629;
                    if (_10483 == 0.0f)
                    {
                        bool _3902 = _3860 > _9029;
                        bool2 _10637 = _3902.xx;
                        _10629 = _10491;
                        _10583 = float2(_10637.x ? _3855.x : _9039.x, _10637.y ? _3855.y : _9039.y);
                        _10550 = int2(_10637.x ? _3849.x : _9033.x, _10637.y ? _3849.y : _9033.y);
                        _10539 = _9031;
                        _10528 = _9030;
                        _10524 = _3902 ? _3860 : _9029;
                    }
                    else
                    {
                        bool _3911 = _10483 < _10491;
                        bool2 _10633 = _3911.xx;
                        _10629 = _3911 ? _10483 : _10491;
                        _10583 = _9039;
                        _10550 = _9033;
                        _10539 = float2(_10633.x ? _3855.x : _9031.x, _10633.y ? _3855.y : _9031.y);
                        _10528 = int2(_10633.x ? _3849.x : _9030.x, _10633.y ? _3849.y : _9030.y);
                        _10524 = _9029;
                    }
                    _10628 = _10629;
                    _10582 = _10583;
                    _10549 = _10550;
                    _10538 = _10539;
                    _10527 = _10528;
                    _10523 = _10524;
                }
                bool _3923 = _9029 < 0.0f;
                bool2 _10643 = _3923.xx;
                int2 _10646 = int2(_10643.x ? _9030.x : _9033.x, _10643.y ? _9030.y : _9033.y);
                _10125 = float3(1.0f, _3814, float(any(bool2(_10646.x != _3742.x, _10646.y != _3742.y))));
                _9073 = _10646;
                _9062 = _3923 ? false : true;
                _9041 = float2(_10643.x ? _9031.x : _9039.x, _10643.y ? _9031.y : _9039.y);
            }
            else
            {
                _10125 = _8830;
                _9073 = _3742;
                _9062 = false;
                _9041 = _5475;
            }
            _10124 = _10125;
            _9072 = _9073;
            _9061 = _9062;
            _9040 = _9041;
        }
        else
        {
            _10124 = 0.0f.xxx;
            _9072 = _3742;
            _9061 = false;
            _9040 = _5475;
        }
        float2 _9042;
        if (_5497)
        {
            float2 _5922 = clamp((((_9019 + (_9040 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5925 = tan(_5922.x);
            _9042 = (float2(_5925 / cbFI_DeviceToViewDepth.z, (tan(_5922.y) * sqrt(1.0f + (_5925 * _5925))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9042 = _9019 + (_9040 * cbFI_Timestep);
        }
        float _3946 = cbFI_Timestep - 1.0f;
        float2 _9044;
        if (_5497)
        {
            float2 _5993 = clamp((((_9019 + (_9040 * _3946)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5996 = tan(_5993.x);
            _9044 = (float2(_5996 / cbFI_DeviceToViewDepth.z, (tan(_5993.y) * sqrt(1.0f + (_5996 * _5996))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9044 = _9019 + (_9040 * _3946);
        }
        float _3951 = -cbFI_Timestep;
        float2 _9045;
        if (_5497)
        {
            float2 _6064 = clamp((((_9019 + (_5469 * _3951)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6067 = tan(_6064.x);
            _9045 = (float2(_6067 / cbFI_DeviceToViewDepth.z, (tan(_6064.y) * sqrt(1.0f + (_6067 * _6067))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9045 = _9019 + (_5469 * _3951);
        }
        float _3956 = 1.0f - cbFI_Timestep;
        float2 _9046;
        if (_5497)
        {
            float2 _6135 = clamp((((_9019 + (_5469 * _3956)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6138 = tan(_6135.x);
            _9046 = (float2(_6138 / cbFI_DeviceToViewDepth.z, (tan(_6135.y) * sqrt(1.0f + (_6138 * _6138))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9046 = _9019 + (_5469 * _3956);
        }
        float4 _6173 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9042, 0.0f);
        float3 _6174 = _6173.xyz;
        float4 _6181 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9044, 0.0f);
        float3 _6182 = _6181.xyz;
        float4 _6189 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9045, 0.0f);
        float3 _6190 = _6189.xyz;
        float4 _6197 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9046, 0.0f);
        float3 _6198 = _6197.xyz;
        float4 _6212 = exp(_5463 - max(max(max(_5463.x, _5463.y), _5463.z), _5463.w).xxxx);
        float4 _6219 = _6212 / (dot(_6212, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3975 = _3768 && (!_9061);
        bool _3984;
        if (_3975)
        {
            _3984 = (_6219.z + _6219.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3984 = _3975;
        }
        bool _3995;
        if (_3984)
        {
            _3995 = length((_9045 - _9042) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3995 = _3984;
        }
        bool _9085;
        if (_3995)
        {
            uint4 _6238 = r_warped_motion_qdata_tp1.Load(int3(_9072, 0));
            uint _6239 = _6238.x;
            bool _9088;
            if (_6239 != 0u)
            {
                float _9074;
                if (_6239 == 0u)
                {
                    _9074 = -1.0f;
                }
                else
                {
                    _9074 = float((_6239 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4005 = _9074 - 0.12000000476837158203125f;
                bool _6258 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                bool _6264;
                if (_6258)
                {
                    _6264 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                }
                else
                {
                    _6264 = _6258;
                }
                bool _4015;
                if (_6264)
                {
                    uint _6271_dummy_parameter;
                    _4015 = (log(((r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6271_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4005;
                }
                else
                {
                    _4015 = _6264;
                }
                bool _4029;
                if (!_4015)
                {
                    bool _6301 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                    bool _6307;
                    if (_6301)
                    {
                        _6307 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6307 = _6301;
                    }
                    bool _4027;
                    if (_6307)
                    {
                        uint _6314_dummy_parameter;
                        _4027 = (log(((r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6314_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4005;
                    }
                    else
                    {
                        _4027 = _6307;
                    }
                    _4029 = _4027;
                }
                else
                {
                    _4029 = _4015;
                }
                _9088 = _4029;
            }
            else
            {
                _9088 = false;
            }
            _9085 = _9088;
        }
        else
        {
            _9085 = false;
        }
        bool _4034 = _9061 || _9085;
        bool _4039;
        if (_4034)
        {
            bool _6344 = all(bool2(_9042.x > 0.0f.xx.x, _9042.y > 0.0f.xx.y));
            bool _6350;
            if (_6344)
            {
                _6350 = all(bool2(_9042.x < 1.0f.xx.x, _9042.y < 1.0f.xx.y));
            }
            else
            {
                _6350 = _6344;
            }
            _4039 = _6350;
        }
        else
        {
            _4039 = _4034;
        }
        bool _4044;
        if (_4039)
        {
            bool _6355 = all(bool2(_9044.x > 0.0f.xx.x, _9044.y > 0.0f.xx.y));
            bool _6361;
            if (_6355)
            {
                _6361 = all(bool2(_9044.x < 1.0f.xx.x, _9044.y < 1.0f.xx.y));
            }
            else
            {
                _6361 = _6355;
            }
            _4044 = _6361;
        }
        else
        {
            _4044 = _4039;
        }
        float4 _9179;
        if (_4044)
        {
            float _4047 = _6219.x;
            float _4049 = _6219.y;
            float _4050 = _4047 + _4049;
            float _4055 = _6219.z + _6219.w;
            float _9103;
            if (_4050 > 0.001000000047497451305389404296875f)
            {
                _9103 = _4047 / _4050;
            }
            else
            {
                _9103 = _3956;
            }
            _9179 = float4(_4047 + (_4055 * _9103), _4049 + (_4055 * (1.0f - _9103)), 0.0f, 0.0f);
        }
        else
        {
            _9179 = _6219;
        }
        bool _6389 = (cbFI_pad0 & 1024u) != 0u;
        bool _6365 = !_6389;
        bool _6366 = !_6365;
        bool _6383;
        if (_6366)
        {
            _6383 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9072.y * cbFI_MvDepthLaneSize.x) + _9072.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6383 = _6365;
        }
        bool _6415;
        if (_6366)
        {
            _6415 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3747.y * cbFI_FlowLaneSize.x) + _3747.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6415 = _6365;
        }
        float _4090 = float(_6415);
        bool _9191;
        float4 _9221;
        float3 _9980;
        if (_6389)
        {
            bool _4100;
            if (_6383)
            {
                _4100 = all(bool2(_9042.x > 0.0f.xx.x, _9042.y > 0.0f.xx.y));
            }
            else
            {
                _4100 = _6383;
            }
            bool _4106;
            if (_4100)
            {
                _4106 = all(bool2(_9042.x < 1.0f.xx.x, _9042.y < 1.0f.xx.y));
            }
            else
            {
                _4106 = _4100;
            }
            bool _4113;
            if (_6383)
            {
                _4113 = all(bool2(_9044.x > 0.0f.xx.x, _9044.y > 0.0f.xx.y));
            }
            else
            {
                _4113 = _6383;
            }
            bool _4119;
            if (_4113)
            {
                _4119 = all(bool2(_9044.x < 1.0f.xx.x, _9044.y < 1.0f.xx.y));
            }
            else
            {
                _4119 = _4113;
            }
            bool _4126;
            if (_6415)
            {
                _4126 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
            }
            else
            {
                _4126 = _6415;
            }
            bool _4132;
            if (_4126)
            {
                _4132 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
            }
            else
            {
                _4132 = _4126;
            }
            bool _4139;
            if (_6415)
            {
                _4139 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
            }
            else
            {
                _4139 = _6415;
            }
            bool _4145;
            if (_4139)
            {
                _4145 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
            }
            else
            {
                _4145 = _4139;
            }
            bool _4147 = !_6383;
            if (_4147)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6457;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6457);
                }
            }
            bool _4152 = !_6415;
            if (_4152)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6467;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6467);
                }
            }
            if (_6383 && _4152)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6477;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6477);
                }
            }
            if (_4147 && _6415)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6487;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6487);
                }
            }
            float _4171 = float(_4106);
            float _4173 = float(_4119);
            bool _4176 = _4132 && _4145;
            float _9137;
            if (_4176)
            {
                _9137 = 1.0f;
            }
            else
            {
                _9137 = (_4132 || _4145) ? 0.5f : 0.0f;
            }
            bool _9142;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4106)) && (!_4119))
            {
                bool _4206;
                if (_4176)
                {
                    float _9140;
                    do
                    {
                        bool _6571 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                        bool _6577;
                        if (_6571)
                        {
                            _6577 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6577 = _6571;
                        }
                        bool _6508 = !_6577;
                        bool _6515;
                        if (!_6508)
                        {
                            bool _6582 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                            bool _6588;
                            if (_6582)
                            {
                                _6588 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6588 = _6582;
                            }
                            _6515 = !_6588;
                        }
                        else
                        {
                            _6515 = _6508;
                        }
                        if (_6515)
                        {
                            _9140 = 0.0f;
                            break;
                        }
                        uint _6595_dummy_parameter;
                        uint _6611_dummy_parameter;
                        float4 _6536 = mul(float4((float2(_9045.x, 1.0f - _9045.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6595_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6538 = _6536.w;
                        if (abs(_6538) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9140 = 0.0f;
                            break;
                        }
                        float _6549 = abs(cbFI_DeviceToViewDepth.y / ((_6536.z / _6538) - cbFI_DeviceToViewDepth.x));
                        float _6552 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6611_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9140 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6549 - _6552) / max(max(_6549, _6552), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4206 = _9140 >= 0.5f;
                }
                else
                {
                    _4206 = _4176;
                }
                bool _9143;
                if (_4206)
                {
                    uint _6661_dummy_parameter;
                    float2 _9141;
                    do
                    {
                        float _6687 = 1.0f - _9045.y;
                        float4 _6698 = mul(float4((float2(_9045.x, _6687) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6661_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6700 = _6698.w;
                        if (!(_6700 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9141 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6713 = ((_6698.xy / _6700.xx) + 1.0f.xx) * 0.5f;
                        _9141 = float2(_6713.x - _9045.x, _6687 - _6713.y);
                        break;
                    } while(false);
                    float2 _4220 = float2(cbFI_DisplaySize);
                    _9143 = length(((_9045 + _9141) - _9046) * _4220) <= ((0.100000001490116119384765625f * length(_9141 * _4220)) + 8.0f);
                }
                else
                {
                    _9143 = _4206;
                }
                _9142 = _9143;
            }
            else
            {
                _9142 = true;
            }
            bool _4234 = !_9142;
            bool _10647 = _4234 ? false : _4145;
            bool _10648 = _4234 ? false : _4132;
            bool _9192;
            float4 _9222;
            if (!(((_4106 && _4119) && _10648) && _10647))
            {
                float4 _4256 = _9179 * float4(_4171, _4173, float(_10648), float(_10647));
                float _4258 = dot(_4256, 1.0f.xxxx);
                bool _4261 = !(_4258 > 0.0f);
                float4 _9223;
                if (!_4261)
                {
                    _9223 = _4256 / _4258.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6735;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6735);
                    }
                    _9223 = 0.0f.xxxx;
                }
                _9222 = _9223;
                _9192 = _4261;
            }
            else
            {
                _9222 = _9179;
                _9192 = false;
            }
            _9980 = float3(_4171, _4173, _9137);
            _9221 = _9222;
            _9191 = _9192;
        }
        else
        {
            _9980 = float3(float(_6383), _4090, 0.0f);
            _9221 = _9179;
            _9191 = false;
        }
        float4 _9710;
        bool _9730;
        float3 _9843;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9191))
        {
            bool _4284 = _9221.x > 0.00999999977648258209228515625f;
            bool _4287 = _9221.y > 0.00999999977648258209228515625f;
            bool _4296 = (_9221.z + _9221.w) > 0.0199999995529651641845703125f;
            bool _4302;
            if (_4296)
            {
                bool _6741 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                bool _6747;
                if (_6741)
                {
                    _6747 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                }
                else
                {
                    _6747 = _6741;
                }
                _4302 = _6747;
            }
            else
            {
                _4302 = _4296;
            }
            bool _4307;
            if (_4302)
            {
                bool _6752 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                bool _6758;
                if (_6752)
                {
                    _6758 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                }
                else
                {
                    _6758 = _6752;
                }
                _4307 = _6758;
            }
            else
            {
                _4307 = _4302;
            }
            bool _4314;
            if (_4307)
            {
                float _9225;
                do
                {
                    bool _6841 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                    bool _6847;
                    if (_6841)
                    {
                        _6847 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6847 = _6841;
                    }
                    bool _6778 = !_6847;
                    bool _6785;
                    if (!_6778)
                    {
                        bool _6852 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                        bool _6858;
                        if (_6852)
                        {
                            _6858 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6858 = _6852;
                        }
                        _6785 = !_6858;
                    }
                    else
                    {
                        _6785 = _6778;
                    }
                    if (_6785)
                    {
                        _9225 = 0.0f;
                        break;
                    }
                    uint _6865_dummy_parameter;
                    uint _6881_dummy_parameter;
                    float4 _6806 = mul(float4((float2(_9045.x, 1.0f - _9045.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6865_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6808 = _6806.w;
                    if (abs(_6808) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9225 = 0.0f;
                        break;
                    }
                    float _6819 = abs(cbFI_DeviceToViewDepth.y / ((_6806.z / _6808) - cbFI_DeviceToViewDepth.x));
                    float _6822 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6881_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9225 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6819 - _6822) / max(max(_6819, _6822), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4314 = _9225 < 0.5f;
            }
            else
            {
                _4314 = _4307;
            }
            float4 _9240;
            if (_4314)
            {
                uint _6931_dummy_parameter;
                uint _6962_dummy_parameter;
                float4 _9241;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6931_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6962_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9241 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9241 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9240 = _9241;
            }
            else
            {
                _9240 = 1.0f.xxxx;
            }
            bool _4338;
            if (_6383)
            {
                bool _6991 = all(bool2(_9042.x > 0.0f.xx.x, _9042.y > 0.0f.xx.y));
                bool _6997;
                if (_6991)
                {
                    _6997 = all(bool2(_9042.x < 1.0f.xx.x, _9042.y < 1.0f.xx.y));
                }
                else
                {
                    _6997 = _6991;
                }
                _4338 = _6997;
            }
            else
            {
                _4338 = _6383;
            }
            bool _4344;
            if (_6383)
            {
                bool _7002 = all(bool2(_9044.x > 0.0f.xx.x, _9044.y > 0.0f.xx.y));
                bool _7008;
                if (_7002)
                {
                    _7008 = all(bool2(_9044.x < 1.0f.xx.x, _9044.y < 1.0f.xx.y));
                }
                else
                {
                    _7008 = _7002;
                }
                _4344 = _7008;
            }
            else
            {
                _4344 = _6383;
            }
            bool _4350;
            if (_6415)
            {
                bool _7013 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                bool _7019;
                if (_7013)
                {
                    _7019 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                }
                else
                {
                    _7019 = _7013;
                }
                _4350 = _7019;
            }
            else
            {
                _4350 = _6415;
            }
            bool _4356;
            if (_6415)
            {
                bool _7024 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                bool _7030;
                if (_7024)
                {
                    _7030 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                }
                else
                {
                    _7030 = _7024;
                }
                _4356 = _7030;
            }
            else
            {
                _4356 = _6415;
            }
            bool _4359 = _4350 != _4356;
            bool _4365;
            if (_4359)
            {
                _4365 = _4338 || _4344;
            }
            else
            {
                _4365 = _4359;
            }
            float4 _9322;
            if (_4365)
            {
                float4 _8915 = _9240;
                _8915.z = 0.0f;
                _8915.w = 0.0f;
                _9322 = _8915;
            }
            else
            {
                _9322 = _9240;
            }
            bool _4372 = _4338 && _4284;
            bool _4375 = _4344 && _4287;
            float4 _9427;
            float3 _9880;
            if (_4372 || _4375)
            {
                float _9317;
                do
                {
                    uint4 _7169 = r_warped_motion_qdata_tp1.Load(int3(_9072, 0));
                    uint _7170 = _7169.x;
                    if (_7170 != 0u)
                    {
                        float _9316;
                        if (_7170 == 0u)
                        {
                            _9316 = -1.0f;
                        }
                        else
                        {
                            _9316 = float((_7170 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9317 = _9316;
                        break;
                    }
                    int _9299;
                    uint _9300;
                    _9300 = _7170;
                    _9299 = -1;
                    uint _9315;
                    for (; _9299 <= 1; _9300 = _9315, _9299++)
                    {
                        _9315 = _9300;
                        for (int _9313 = -1; _9313 <= 1; )
                        {
                            _9315 = max(_9315, r_warped_motion_qdata_tp1.Load(int3(clamp(_9072 + int2(_9313, _9299), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9313++;
                            continue;
                        }
                    }
                    if (_9300 != 0u)
                    {
                        float _9312;
                        if (_9300 == 0u)
                        {
                            _9312 = -1.0f;
                        }
                        else
                        {
                            _9312 = float((_9300 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9317 = _9312;
                        break;
                    }
                    uint _9302;
                    _9302 = 4294967295u;
                    uint _10619;
                    for (int _9301 = 0; _9301 < 8; _9302 = _10619, _9301++)
                    {
                        int _9305 = 0;
                        for (;;)
                        {
                            if (_9305 < 5)
                            {
                                int2 _7120 = _9072 + (_1085[_9301] * _1094[_9305].xx);
                                bool _7123 = any(bool2(_7120.x < int2(0, 0).x, _7120.y < int2(0, 0).y));
                                bool _7131;
                                if (!_7123)
                                {
                                    _7131 = any(bool2(_7120.x >= cbFI_MvDepthLaneSize.x, _7120.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7131 = _7123;
                                }
                                if (_7131)
                                {
                                    _10619 = _9302;
                                    break;
                                }
                                uint4 _7209 = r_warped_motion_qdata_tp1.Load(int3(_7120, 0));
                                uint _7210 = _7209.x;
                                if (_7210 != 0u)
                                {
                                    _10619 = min(_9302, _7210);
                                    break;
                                }
                                _9305++;
                                continue;
                            }
                            else
                            {
                                _10619 = _9302;
                                break;
                            }
                        }
                    }
                    float _9304;
                    if (_9302 == 4294967295u)
                    {
                        _9304 = -1.0f;
                    }
                    else
                    {
                        float _9303;
                        if (_9302 == 0u)
                        {
                            _9303 = -1.0f;
                        }
                        else
                        {
                            _9303 = float((_9302 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9304 = _9303;
                    }
                    _9317 = _9304;
                    break;
                } while(false);
                bool _4383 = _9317 < 0.0f;
                float _9318;
                if (_4383)
                {
                    _9318 = 0.0f;
                }
                else
                {
                    _9318 = _9317 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7231_dummy_parameter;
                uint _7263_dummy_parameter;
                float4 _9355;
                if ((_4383 && _4372) && _4375)
                {
                    uint _7295_dummy_parameter;
                    float _7319 = log(((r_depth_tm1.Load(int3(int2(floor(_9042 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7295_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7327_dummy_parameter;
                    float _7351 = log(((r_depth_tp1.Load(int3(int2(floor(_9044 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7327_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9356;
                    if (_7319 > (_7351 + 0.07999999821186065673828125f))
                    {
                        float4 _8919 = _9322;
                        _8919.x = 0.0f;
                        _9356 = _8919;
                    }
                    else
                    {
                        float4 _9357;
                        if (_7351 > (_7319 + 0.07999999821186065673828125f))
                        {
                            float4 _8921 = _9322;
                            _8921.y = 0.0f;
                            _9357 = _8921;
                        }
                        else
                        {
                            _9357 = _9322;
                        }
                        _9356 = _9357;
                    }
                    _9355 = _9356;
                }
                else
                {
                    _9355 = _9322;
                }
                float _4435 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4437 = _9317 >= 0.0f;
                float _9338;
                if (_4437)
                {
                    _9338 = _9317 - _4435;
                }
                else
                {
                    float _9334;
                    if (_4372)
                    {
                        float _9333;
                        _9333 = 2.0f;
                        float _7409;
                        for (int _9332 = 0; _9332 < 24; _9333 = _7409, _9332++)
                        {
                            float _7373 = float(_9332 & 7) * 0.785398185253143310546875f;
                            int _7375 = _9332 >> 3;
                            int _9335;
                            if (_7375 == 0)
                            {
                                _9335 = 16;
                            }
                            else
                            {
                                _9335 = (_7375 == 1) ? 48 : 96;
                            }
                            uint _7425_dummy_parameter;
                            _7409 = min(_9333, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9042 + ((cbFI_MvDepthLaneSizeRcp * float(_9335)) * float2(cos(_7373), sin(_7373))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7425_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9334 = _9333;
                    }
                    else
                    {
                        _9334 = 0.0f;
                    }
                    _9338 = _9334;
                }
                float _9345;
                if (_4437)
                {
                    _9345 = _9317 - _4435;
                }
                else
                {
                    float _9341;
                    if (_4375)
                    {
                        float _9340;
                        _9340 = 2.0f;
                        float _7523;
                        for (int _9339 = 0; _9339 < 24; _9340 = _7523, _9339++)
                        {
                            float _7487 = float(_9339 & 7) * 0.785398185253143310546875f;
                            int _7489 = _9339 >> 3;
                            int _9342;
                            if (_7489 == 0)
                            {
                                _9342 = 16;
                            }
                            else
                            {
                                _9342 = (_7489 == 1) ? 48 : 96;
                            }
                            uint _7555_dummy_parameter;
                            _7523 = min(_9340, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9044 + ((cbFI_MvDepthLaneSizeRcp * float(_9342)) * float2(cos(_7487), sin(_7487))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7555_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9341 = _9340;
                    }
                    else
                    {
                        _9341 = 0.0f;
                    }
                    _9345 = _9341;
                }
                float _9346;
                if (_4372)
                {
                    uint _7587_dummy_parameter;
                    _9346 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9042 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7587_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9346 = 0.0f;
                }
                float _9347;
                if (_4375)
                {
                    uint _7607_dummy_parameter;
                    _9347 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9044 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7607_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9347 = 0.0f;
                }
                bool _4492;
                if (_4372)
                {
                    _4492 = _9346 > ((exp((_9338 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4492 = _4372;
                }
                float4 _9363;
                if (_4492)
                {
                    float4 _8923 = _9355;
                    _8923.x = 0.0f;
                    _9363 = _8923;
                }
                else
                {
                    _9363 = _9355;
                }
                bool _4504;
                if (_4375)
                {
                    _4504 = _9347 > ((exp((_9345 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4504 = _4375;
                }
                float4 _9365;
                if (_4504)
                {
                    float4 _8925 = _9363;
                    _8925.y = 0.0f;
                    _9365 = _8925;
                }
                else
                {
                    _9365 = _9363;
                }
                float4 _9428;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4437)
                {
                    bool _4524;
                    if (_4372)
                    {
                        _4524 = _9346 < ((exp((_9338 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4524 = _4372;
                    }
                    float4 _9367;
                    if (_4524)
                    {
                        float4 _8927 = _9365;
                        _8927.x = 0.0f;
                        _9367 = _8927;
                    }
                    else
                    {
                        _9367 = _9365;
                    }
                    bool _4536;
                    if (_4375)
                    {
                        _4536 = _9347 < ((exp((_9345 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4536 = _4375;
                    }
                    float4 _9429;
                    if (_4536)
                    {
                        float4 _8929 = _9367;
                        _8929.y = 0.0f;
                        _9429 = _8929;
                    }
                    else
                    {
                        _9429 = _9367;
                    }
                    _9428 = _9429;
                }
                else
                {
                    _9428 = _9365;
                }
                _9880 = float3(_9318, log(((r_depth_tm1.Load(int3(int2(floor(_9042 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7231_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9044 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7263_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9427 = _9428;
            }
            else
            {
                _9880 = float3(0.0f, 0.0f, 0.5f);
                _9427 = _9322;
            }
            bool _4547 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4296;
            bool _4553;
            if (_4547)
            {
                _4553 = _4350 || _4356;
            }
            else
            {
                _4553 = _4547;
            }
            float4 _9449;
            if (_4553)
            {
                float _9422;
                do
                {
                    uint4 _7787 = r_warped_motion_qdata_tp1.Load(int3(_9072, 0));
                    uint _7788 = _7787.x;
                    if (_7788 != 0u)
                    {
                        float _9421;
                        if (_7788 == 0u)
                        {
                            _9421 = -1.0f;
                        }
                        else
                        {
                            _9421 = float((_7788 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9422 = _9421;
                        break;
                    }
                    int _9404;
                    uint _9405;
                    _9405 = _7788;
                    _9404 = -1;
                    uint _9420;
                    for (; _9404 <= 1; _9405 = _9420, _9404++)
                    {
                        _9420 = _9405;
                        for (int _9418 = -1; _9418 <= 1; )
                        {
                            _9420 = max(_9420, r_warped_motion_qdata_tp1.Load(int3(clamp(_9072 + int2(_9418, _9404), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9418++;
                            continue;
                        }
                    }
                    if (_9405 != 0u)
                    {
                        float _9417;
                        if (_9405 == 0u)
                        {
                            _9417 = -1.0f;
                        }
                        else
                        {
                            _9417 = float((_9405 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9422 = _9417;
                        break;
                    }
                    uint _9407;
                    _9407 = 4294967295u;
                    uint _10620;
                    for (int _9406 = 0; _9406 < 8; _9407 = _10620, _9406++)
                    {
                        int _9410 = 0;
                        for (;;)
                        {
                            if (_9410 < 5)
                            {
                                int2 _7738 = _9072 + (_1085[_9406] * _1094[_9410].xx);
                                bool _7741 = any(bool2(_7738.x < int2(0, 0).x, _7738.y < int2(0, 0).y));
                                bool _7749;
                                if (!_7741)
                                {
                                    _7749 = any(bool2(_7738.x >= cbFI_MvDepthLaneSize.x, _7738.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7749 = _7741;
                                }
                                if (_7749)
                                {
                                    _10620 = _9407;
                                    break;
                                }
                                uint4 _7827 = r_warped_motion_qdata_tp1.Load(int3(_7738, 0));
                                uint _7828 = _7827.x;
                                if (_7828 != 0u)
                                {
                                    _10620 = min(_9407, _7828);
                                    break;
                                }
                                _9410++;
                                continue;
                            }
                            else
                            {
                                _10620 = _9407;
                                break;
                            }
                        }
                    }
                    float _9409;
                    if (_9407 == 4294967295u)
                    {
                        _9409 = -1.0f;
                    }
                    else
                    {
                        float _9408;
                        if (_9407 == 0u)
                        {
                            _9408 = -1.0f;
                        }
                        else
                        {
                            _9408 = float((_9407 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9409 = _9408;
                    }
                    _9422 = _9409;
                    break;
                } while(false);
                float4 _9450;
                if (_9422 >= 0.0f)
                {
                    float _7849 = (exp((_9422 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4572;
                    if (_4350)
                    {
                        uint _7856_dummy_parameter;
                        _4572 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7856_dummy_parameter))))), 0)).x) > _7849;
                    }
                    else
                    {
                        _4572 = _4350;
                    }
                    float4 _9440;
                    if (_4572)
                    {
                        float4 _8931 = _9427;
                        _8931.z = 0.0f;
                        _9440 = _8931;
                    }
                    else
                    {
                        _9440 = _9427;
                    }
                    bool _4584;
                    if (_4356)
                    {
                        uint _7876_dummy_parameter;
                        _4584 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7876_dummy_parameter))))), 0)).x) > _7849;
                    }
                    else
                    {
                        _4584 = _4356;
                    }
                    float4 _9451;
                    if (_4584)
                    {
                        float4 _8933 = _9440;
                        _8933.w = 0.0f;
                        _9451 = _8933;
                    }
                    else
                    {
                        _9451 = _9440;
                    }
                    _9450 = _9451;
                }
                else
                {
                    _9450 = _9427;
                }
                _9449 = _9450;
            }
            else
            {
                _9449 = _9427;
            }
            bool _4592 = _4338 != _4344;
            bool _4599;
            if (_4592)
            {
                _4599 = _4338 ? _4284 : _4287;
            }
            else
            {
                _4599 = _4592;
            }
            float4 _9533;
            if (_4599)
            {
                bool2 _4604 = _4338.xx;
                float2 _4605 = float2(_4604.x ? _9042.x : _9044.x, _4604.y ? _9042.y : _9044.y);
                float _9442;
                if (_4338)
                {
                    uint _7896_dummy_parameter;
                    _9442 = r_depth_tm1.Load(int3(int2(floor(_4605 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7896_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7912_dummy_parameter;
                    _9442 = r_depth_tp1.Load(int3(int2(floor(_4605 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7912_dummy_parameter))))), 0)).x;
                }
                float4x4 _9443;
                if (_4338)
                {
                    _9443 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9443 = cbFI_MotionTP1ToTM1;
                }
                float2 _9444;
                do
                {
                    float _7939 = _4605.x;
                    float _7942 = 1.0f - _4605.y;
                    float4 _7953 = mul(float4((float2(_7939, _7942) * 2.0f) - 1.0f.xx, _9442, 1.0f), _9443);
                    float _7955 = _7953.w;
                    if (!(_7955 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9444 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7968 = ((_7953.xy / _7955.xx) + 1.0f.xx) * 0.5f;
                    _9444 = float2(_7968.x - _7939, _7942 - _7968.y);
                    break;
                } while(false);
                float2 _4635 = float2(cbFI_DisplaySize);
                float4 _9534;
                if (!(length(((_4605 + _9444) - float2(_4604.x ? _9044.x : _9042.x, _4604.y ? _9044.y : _9042.y)) * _4635) <= ((0.100000001490116119384765625f * length(_9444 * _4635)) + 8.0f)))
                {
                    float4 _9535;
                    if (_4338)
                    {
                        float4 _8943 = _9449;
                        _8943.x = 0.0f;
                        _9535 = _8943;
                    }
                    else
                    {
                        float4 _8945 = _9449;
                        _8945.y = 0.0f;
                        _9535 = _8945;
                    }
                    _9534 = _9535;
                }
                else
                {
                    _9534 = _9449;
                }
                _9533 = _9534;
            }
            else
            {
                _9533 = _9449;
            }
            float4 _4660 = _9221 * _9533;
            float _4662 = dot(_4660, 1.0f.xxxx);
            float4 _9711;
            bool _9731;
            if (_4662 > 0.0f)
            {
                _9731 = _9191;
                _9711 = _4660 / _4662.xxxx;
            }
            else
            {
                bool _4673 = any(bool4(_9533.x < 1.0f.xxxx.x, _9533.y < 1.0f.xxxx.y, _9533.z < 1.0f.xxxx.z, _9533.w < 1.0f.xxxx.w));
                if (_4673)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7990;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7990);
                    }
                }
                bool4 _10650 = _4673.xxxx;
                _9731 = _4673 ? true : _9191;
                _9711 = float4(_10650.x ? 0.0f.xxxx.x : _9221.x, _10650.y ? 0.0f.xxxx.y : _9221.y, _10650.z ? 0.0f.xxxx.z : _9221.z, _10650.w ? 0.0f.xxxx.w : _9221.w);
            }
            _9843 = _9880;
            _9730 = _9731;
            _9710 = _9711;
        }
        else
        {
            _9843 = float3(0.0f, 0.0f, 0.5f);
            _9730 = _9191;
            _9710 = _9221;
        }
        uint _4682 = (cbFI_pad0 >> 24u) & 31u;
        uint _4686 = (cbFI_pad0 >> 16u) & 255u;
        bool _4688 = _4682 != 0u;
        bool _4690 = _4686 == 12u;
        bool _4693 = _4686 == 13u;
        float4 _9727;
        if ((_4688 || _4690) || _4693)
        {
            float _9536;
            do
            {
                bool _8074 = all(bool2(_9045.x > 0.0f.xx.x, _9045.y > 0.0f.xx.y));
                bool _8080;
                if (_8074)
                {
                    _8080 = all(bool2(_9045.x < 1.0f.xx.x, _9045.y < 1.0f.xx.y));
                }
                else
                {
                    _8080 = _8074;
                }
                bool _8011 = !_8080;
                bool _8018;
                if (!_8011)
                {
                    bool _8085 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
                    bool _8091;
                    if (_8085)
                    {
                        _8091 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8091 = _8085;
                    }
                    _8018 = !_8091;
                }
                else
                {
                    _8018 = _8011;
                }
                if (_8018)
                {
                    _9536 = 0.0f;
                    break;
                }
                uint _8098_dummy_parameter;
                uint _8114_dummy_parameter;
                float4 _8039 = mul(float4((float2(_9045.x, 1.0f - _9045.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8098_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8041 = _8039.w;
                if (abs(_8041) < 9.9999999747524270787835121154785e-07f)
                {
                    _9536 = 0.0f;
                    break;
                }
                float _8052 = abs(cbFI_DeviceToViewDepth.y / ((_8039.z / _8041) - cbFI_DeviceToViewDepth.x));
                float _8055 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8114_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9536 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8052 - _8055) / max(max(_8052, _8055), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8162 = all(bool2(_9046.x > 0.0f.xx.x, _9046.y > 0.0f.xx.y));
            bool _8168;
            if (_8162)
            {
                _8168 = all(bool2(_9046.x < 1.0f.xx.x, _9046.y < 1.0f.xx.y));
            }
            else
            {
                _8168 = _8162;
            }
            float _9537;
            if (_8168)
            {
                uint _8175_dummy_parameter;
                _9537 = length((_5469 + (r_motion_tp1.Load(int3(int2(floor(_9046 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8175_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9537 = 1000000.0f;
            }
            float _9548;
            if ((_4682 & 1u) != 0u)
            {
                _9548 = _9536;
            }
            else
            {
                _9548 = 1.0f;
            }
            float _9549;
            if ((_4682 & 2u) != 0u)
            {
                _9549 = _9548 * (1.0f - smoothstep(2.0f, 8.0f, _9537));
            }
            else
            {
                _9549 = _9548;
            }
            float _9550;
            if ((_4682 & 4u) != 0u)
            {
                _9550 = _9549 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6190 - _6198) - length(_6174 - _6182))));
            }
            else
            {
                _9550 = _9549;
            }
            float _9721;
            if ((_4682 & 8u) != 0u)
            {
                _9721 = lerp(1.0f, _9550, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6174 - _6182)));
            }
            else
            {
                _9721 = _9550;
            }
            bool _4768 = (_4682 & 16u) != 0u;
            bool _4777;
            if (_4768)
            {
                _4777 = length(_9040 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4777 = _4768;
            }
            float _10652 = _4777 ? 1.0f : _9721;
            bool _4783 = _4688 && _6383;
            bool _4788;
            if (_4783)
            {
                bool _8200 = all(bool2(_9042.x > 0.0f.xx.x, _9042.y > 0.0f.xx.y));
                bool _8206;
                if (_8200)
                {
                    _8206 = all(bool2(_9042.x < 1.0f.xx.x, _9042.y < 1.0f.xx.y));
                }
                else
                {
                    _8206 = _8200;
                }
                _4788 = _8206;
            }
            else
            {
                _4788 = _4783;
            }
            bool _4793;
            if (_4788)
            {
                bool _8211 = all(bool2(_9044.x > 0.0f.xx.x, _9044.y > 0.0f.xx.y));
                bool _8217;
                if (_8211)
                {
                    _8217 = all(bool2(_9044.x < 1.0f.xx.x, _9044.y < 1.0f.xx.y));
                }
                else
                {
                    _8217 = _8211;
                }
                _4793 = _8217;
            }
            else
            {
                _4793 = _4788;
            }
            float4 _9728;
            if (_4793)
            {
                float _4799 = _9710.x + _9710.y;
                float _4808 = (_9710.z + _9710.w) * (1.0f - _10652);
                float _9724;
                if (_4799 > 9.9999997473787516355514526367188e-06f)
                {
                    _9724 = _9710.x / _4799;
                }
                else
                {
                    _9724 = _3956;
                }
                _9728 = float4(_9710.x + (_4808 * _9724), _9710.y + (_4808 * (1.0f - _9724)), _9710.zw * _10652);
            }
            else
            {
                _9728 = _9710;
            }
            _9727 = _9728;
        }
        else
        {
            _9727 = _9710;
        }
        float3 _10423;
        if (_9730)
        {
            float3 _8223 = r_current_interpolation_source.Load(int3(_3369, 0)).xyz;
            float3 _10424;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6383)
            {
                uint _8230_dummy_parameter;
                float _9834;
                _9834 = r_depth_tm1.Load(int3(int2(floor(_9042 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8230_dummy_parameter))))), 0)).x;
                float _4920;
                for (int _9833 = 0; _9833 < 24; _9834 = _4920, _9833++)
                {
                    float _4892 = float(_9833 & 7) * 0.785398185253143310546875f;
                    int _4894 = _9833 >> 3;
                    int _10474;
                    if (_4894 == 0)
                    {
                        _10474 = 16;
                    }
                    else
                    {
                        _10474 = (_4894 == 1) ? 48 : 96;
                    }
                    uint _8250_dummy_parameter;
                    _4920 = max(_9834, r_depth_tm1.Load(int3(int2(floor(clamp(_9042 + ((cbFI_MvDepthLaneSizeRcp * float(_10474)) * float2(cos(_4892), sin(_4892))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8250_dummy_parameter))))), 0)).x);
                }
                float2 _9835;
                do
                {
                    float _8272 = 1.0f - _9042.y;
                    float4 _8283 = mul(float4((float2(_9042.x, _8272) * 2.0f) - 1.0f.xx, _9834, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8285 = _8283.w;
                    if (!(_8285 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9835 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8298 = ((_8283.xy / _8285.xx) + 1.0f.xx) * 0.5f;
                    _9835 = float2(_8298.x - _9042.x, _8272 - _8298.y);
                    break;
                } while(false);
                float2 _4931 = _9042 + _9835;
                bool _8316 = all(bool2(_4931.x > 0.0f.xx.x, _4931.y > 0.0f.xx.y));
                bool _8322;
                if (_8316)
                {
                    _8322 = all(bool2(_4931.x < 1.0f.xx.x, _4931.y < 1.0f.xx.y));
                }
                else
                {
                    _8322 = _8316;
                }
                float3 _10425;
                if (_8322)
                {
                    float _4937 = abs(cbFI_DeviceToViewDepth.y / (_9834 - cbFI_DeviceToViewDepth.x));
                    uint _8342_dummy_parameter;
                    int2 _8342 = int2(spvTextureSize(r_depth_m2, uint(0), _8342_dummy_parameter));
                    float _4941 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4931 * float2(_8342))), int2(0, 0), _8342 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10430;
                    if (abs(_4941 - _4937) <= (0.20000000298023223876953125f * max(_4941, _4937)))
                    {
                        uint _8376_dummy_parameter;
                        int2 _8376 = int2(spvTextureSize(r_colour_m2, uint(0), _8376_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8399;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8399);
                        }
                        _10430 = r_colour_m2.Load(int3(clamp(int2(floor(_4931 * float2(_8376))), int2(0, 0), _8376 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8409;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8409);
                        }
                        _10430 = _8223;
                    }
                    _10425 = _10430;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8419;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8419);
                    }
                    _10425 = _8223;
                }
                _10424 = _10425;
            }
            else
            {
                _10424 = _8223;
            }
            _10423 = _10424;
        }
        else
        {
            _10423 = (((_6174 * _9727.x) + (_6182 * _9727.y)) + (_6190 * _9727.z)) + (_6198 * _9727.w);
        }
        uint _4969 = cbFI_pad0 & 255u;
        bool _10316;
        float3 _10422;
        if (_4969 != 0u)
        {
            float3 _4974 = r_present_backbuffer.Load(int3(_3369, 0)).xyz;
            float3 _4978 = r_current_interpolation_source.Load(int3(_3369, 0)).xyz;
            float3 _4982 = abs(_4974 - _4978);
            float3 _9838;
            if (_4969 == 2u)
            {
                _9838 = (abs(_4978) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9838 = 0.000244140625f.xxx;
            }
            bool _4998 = any(bool3(_4982.x > _9838.x, _4982.y > _9838.y, _4982.z > _9838.z));
            bool3 _10653 = _4998.xxx;
            _10422 = float3(_10653.x ? _4974.x : _10423.x, _10653.y ? _4974.y : _10423.y, _10653.z ? _4974.z : _10423.z);
            _10316 = _4998;
        }
        else
        {
            _10422 = _10423;
            _10316 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8434;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8434);
        }
        float3 _10405;
        if (_4686 == 1u)
        {
            _10405 = lerp(_6174, _6182, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10406;
            if (_4686 == 2u)
            {
                _10406 = lerp(_6190, _6198, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10407;
                if (_4686 == 3u)
                {
                    _10407 = float(_10316).xxx;
                }
                else
                {
                    float3 _10408;
                    if (_4686 == 4u)
                    {
                        _10408 = float3(((_9040 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10409;
                        if (_4686 == 5u)
                        {
                            _10409 = float3(((_5469 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10410;
                            if (_4686 == 6u)
                            {
                                _10410 = float3(_9727.xy, _9727.z + _9727.w);
                            }
                            else
                            {
                                float3 _10411;
                                if (_4686 == 7u)
                                {
                                    _10411 = r_current_interpolation_source.Load(int3(_3369, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10412;
                                    if (_4686 == 8u)
                                    {
                                        _10412 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3731, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10413;
                                        if (_4690)
                                        {
                                            uint _8456_dummy_parameter;
                                            uint _8488_dummy_parameter;
                                            _10413 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3731 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8456_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3731 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8488_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10414;
                                            if (_4693)
                                            {
                                                _10414 = _6190;
                                            }
                                            else
                                            {
                                                float3 _10415;
                                                if (_4686 == 20u)
                                                {
                                                    _10415 = _6174;
                                                }
                                                else
                                                {
                                                    float3 _10416;
                                                    if (_4686 == 21u)
                                                    {
                                                        _10416 = _6182;
                                                    }
                                                    else
                                                    {
                                                        float3 _10417;
                                                        if (_4686 == 22u)
                                                        {
                                                            _10417 = _6198;
                                                        }
                                                        else
                                                        {
                                                            float3 _10418;
                                                            if (_4686 == 18u)
                                                            {
                                                                _10418 = _10124;
                                                            }
                                                            else
                                                            {
                                                                float3 _10419;
                                                                if (_4686 == 19u)
                                                                {
                                                                    _10419 = _9980;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10655 = (_4686 == 23u).xxx;
                                                                    _10419 = float3(_10655.x ? _9843.x : _10422.x, _10655.y ? _9843.y : _10422.y, _10655.z ? _9843.z : _10422.z);
                                                                }
                                                                _10418 = _10419;
                                                            }
                                                            _10417 = _10418;
                                                        }
                                                        _10416 = _10417;
                                                    }
                                                    _10415 = _10416;
                                                }
                                                _10414 = _10415;
                                            }
                                            _10413 = _10414;
                                        }
                                        _10412 = _10413;
                                    }
                                    _10411 = _10412;
                                }
                                _10410 = _10411;
                            }
                            _10409 = _10410;
                        }
                        _10408 = _10409;
                    }
                    _10407 = _10408;
                }
                _10406 = _10407;
            }
            _10405 = _10406;
        }
        float3 _10404;
        if ((_4686 >= 9u) && (_4686 <= 11u))
        {
            uint _5162 = 64u + uint((_9072.y * cbFI_MvDepthLaneSize.x) + _9072.x);
            uint _5166 = rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) & 15u;
            float3 _10435;
            if (_4686 == 10u)
            {
                float3 _10403;
                if ((rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) & 32u) != 0u)
                {
                    _10403 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10402;
                    if ((rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) & 16u) != 0u)
                    {
                        _10402 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5187 = ((rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) & 64u) != 0u).xxx;
                        _10402 = float3(_5187.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5187.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5187.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10403 = _10402;
                }
                _10435 = _10403;
            }
            else
            {
                float3 _10436;
                if (_4686 == 11u)
                {
                    uint _5200 = (rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) >> 8u) & 15u;
                    uint _5203 = (rw_nfru_diagnostics.Load<uint>(_5162 * 4 + 0) >> 12u) & 15u;
                    float3 _10395;
                    if ((_5166 == 2u) || (_5166 == 3u))
                    {
                        _10395 = _3082[_5166];
                    }
                    else
                    {
                        bool _5215 = _5200 == 3u;
                        bool _5217 = _5203 == 3u;
                        float3 _10396;
                        if (_5215 && _5217)
                        {
                            _10396 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10397;
                            if (_5215)
                            {
                                _10397 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10398;
                                if (_5217)
                                {
                                    _10398 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10399;
                                    if ((_5200 == 4u) || (_5203 == 4u))
                                    {
                                        _10399 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10400;
                                        if ((_5200 == 1u) || (_5203 == 1u))
                                        {
                                            _10400 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10657 = (_5166 == 1u).xxx;
                                            _10400 = float3(_10657.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10657.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10657.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10399 = _10400;
                                    }
                                    _10398 = _10399;
                                }
                                _10397 = _10398;
                            }
                            _10396 = _10397;
                        }
                        _10395 = _10396;
                    }
                    _10436 = _10395;
                }
                else
                {
                    _10436 = _3082[min(_5166, 7u)];
                }
                _10435 = _10436;
            }
            _10404 = _10435;
        }
        else
        {
            _10404 = _10405;
        }
        float4 _10439;
        if ((_4686 >= 14u) && (_4686 <= 16u))
        {
            float2 _10437;
            if (_4686 == 14u)
            {
                uint _5273_dummy_parameter;
                uint _5279_dummy_parameter;
                _10437 = r_flow_tm1.Load(int3(clamp(int2(floor(_3731 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5273_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5279_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10438;
                if (_4686 == 16u)
                {
                    uint _8539 = r_warped_flow_qdata_tm1.Load(int3(_3747, 0)).x & 2147483647u;
                    uint _8571 = uint(max((int((_8539 >> 16u) & 15u) - 6), 0));
                    _10438 = ((float2(float((1 - (2 * int((_8539 >> 15u) & 1u))) * int(((_8539 >> uint(7)) & 127u) << _8571)), float((1 - (2 * int((_8539 >> 14u) & 1u))) * int((_8539 & 127u) << _8571))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10438 = _5469 * float2(cbFI_DisplaySize);
                }
                _10437 = _10438;
            }
            uint2 _5312 = uint2(clamp(round(_10437 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5314 = _5312.x;
            uint _5321 = _5312.y;
            _10439 = float4(float(_5314 & 255u), float((_5314 >> 8u) | ((_5321 & 15u) << 4u)), float(_5321 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10440;
            if (_4686 == 17u)
            {
                _10440 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3747, 0)).x != 0u), _4090, 0.0f, 1.0f);
            }
            else
            {
                _10440 = float4(_10404, 1.0f);
            }
            _10439 = _10440;
        }
        rw_output[_3369] = _10439.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5365 = ((uint(_3369.y) * uint(cbFI_DisplaySize.x)) + uint(_3369.x)) * 6u;
            uint _8617 = spvPackHalf2x16(clamp(_6173.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5365 * 4 + 0, (((_8617 & 32767u) >> 4u) | ((((_8617 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6173.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8652 = spvPackHalf2x16(clamp(_6181.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5365 + 1u) * 4 + 0, (((_8652 & 32767u) >> 4u) | ((((_8652 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6181.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8687 = spvPackHalf2x16(clamp(_6189.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5365 + 2u) * 4 + 0, (((_8687 & 32767u) >> 4u) | ((((_8687 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6189.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8722 = spvPackHalf2x16(clamp(_6197.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5365 + 3u) * 4 + 0, (((_8722 & 32767u) >> 4u) | ((((_8722 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6197.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8749 = r_current_interpolation_source.Load(int3(_3369, 0));
            uint _8763 = spvPackHalf2x16(clamp(_8749.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5365 + 4u) * 4 + 0, (((_8763 & 32767u) >> 4u) | ((((_8763 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8749.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10473;
            if (_10316 || (_4686 != 0u))
            {
                _10473 = 4294967295u;
            }
            else
            {
                uint _8798 = spvPackHalf2x16(clamp(_10439.xy, 0.0f.xx, 65000.0f.xx));
                _10473 = (((_8798 & 32767u) >> 4u) | ((((_8798 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10439.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5365 + 5u) * 4 + 0, _10473);
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
