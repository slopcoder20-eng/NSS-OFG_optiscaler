static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3293[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3597 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3597.x >= cbFI_DisplaySize.x, _3597.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3597] = float4(r_present_backbuffer.Load(int3(_3597, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3597] = float4(r_current_interpolation_source.Load(int3(_3597, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3997 = (float2(_3597) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4008 = int2(floor(_3997 * float2(cbFI_MvDepthLaneSize)));
        int2 _4013 = int2(floor(_3997 * float2(cbFI_FlowLaneSize)));
        float4 _5914 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3997 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5920 = r_warped_filled_flow_tm1.Load(int3(_4013, 0)).xy;
        float2 _5926 = r_warped_filled_motion_tp1.Load(int3(_4008, 0)).xy;
        bool _5948 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10020;
        if (_5948)
        {
            float _5961 = ((2.0f * _3997.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10020 = float2(atan(_5961) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3997.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5961 * _5961))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10020 = _3997;
        }
        bool _4034 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10041;
        bool _10062;
        int2 _10073;
        float3 _11426;
        if (_4034)
        {
            float _10022;
            float _10024;
            _10024 = 2.0f;
            _10022 = -1.0f;
            uint _3661[9];
            float _11858;
            float _11861;
            for (int _10021 = 0; _10021 < 9; _10024 = _11861, _10022 = _11858, _10021++)
            {
                _3661[_10021] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4008 + int2((_10021 % 3) - 1, (_10021 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3661[_10021] != 0u)
                {
                    float _11853;
                    if (_3661[_10021] == 0u)
                    {
                        _11853 = -1.0f;
                    }
                    else
                    {
                        _11853 = float((_3661[_10021] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11861 = min(_10024, _11853);
                    _11858 = max(_10022, _11853);
                }
                else
                {
                    _11861 = _10024;
                    _11858 = _10022;
                }
            }
            float _4080 = float(_10022 >= 0.0f);
            float3 _9821 = 0.0f.xxx;
            _9821.y = _4080;
            float2 _10042;
            bool _10063;
            int2 _10074;
            float3 _11427;
            if ((_10022 - _10024) > 0.0199999995529651641845703125f)
            {
                float _10030;
                int2 _10031;
                float2 _10032;
                int2 _10034;
                float2 _10040;
                _10040 = _5926;
                _10034 = _4008;
                _10032 = _5926;
                _10031 = _4008;
                _10030 = -1.0f;
                float _11866;
                int2 _11870;
                float2 _11881;
                int2 _11892;
                float2 _11925;
                float _11972;
                int _10029 = 0;
                float _11834 = 1000000000.0f;
                for (; _10029 < 9; _11834 = _11972, _10040 = _11925, _10034 = _11892, _10032 = _11881, _10031 = _11870, _10030 = _11866, _10029++)
                {
                    if (_3661[_10029] == 0u)
                    {
                        _11972 = _11834;
                        _11925 = _10040;
                        _11892 = _10034;
                        _11881 = _10032;
                        _11870 = _10031;
                        _11866 = _10030;
                        continue;
                    }
                    int2 _4115 = clamp(_4008 + int2((_10029 % 3) - 1, (_10029 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6036 = _3661[_10029] & 2147483647u;
                    uint _6068 = uint(max((int((_6036 >> 16u) & 15u) - 6), 0));
                    float2 _4121 = (float2(float((1 - (2 * int((_6036 >> 15u) & 1u))) * int(((_6036 >> uint(7)) & 127u) << _6068)), float((1 - (2 * int((_6036 >> 14u) & 1u))) * int((_6036 & 127u) << _6068))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11820;
                    if (_3661[_10029] == 0u)
                    {
                        _11820 = -1.0f;
                    }
                    else
                    {
                        _11820 = float((_3661[_10029] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4126 = _11820 - 0.100000001490116119384765625f;
                    float2 _11821;
                    if (_5948)
                    {
                        float2 _6145 = clamp((((_10020 + (_4121 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6148 = tan(_6145.x);
                        _11821 = (float2(_6148 / cbFI_DeviceToViewDepth.z, (tan(_6145.y) * sqrt(1.0f + (_6148 * _6148))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11821 = _10020 + (_4121 * cbFI_Timestep);
                    }
                    float _4133 = cbFI_Timestep - 1.0f;
                    float2 _11822;
                    if (_5948)
                    {
                        float2 _6216 = clamp((((_10020 + (_4121 * _4133)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6219 = tan(_6216.x);
                        _11822 = (float2(_6219 / cbFI_DeviceToViewDepth.z, (tan(_6216.y) * sqrt(1.0f + (_6219 * _6219))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11822 = _10020 + (_4121 * _4133);
                    }
                    bool _6252 = all(bool2(_11821.x > 0.0f.xx.x, _11821.y > 0.0f.xx.y));
                    bool _6258;
                    if (_6252)
                    {
                        _6258 = all(bool2(_11821.x < 1.0f.xx.x, _11821.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6258 = _6252;
                    }
                    float _11825;
                    if (_6258)
                    {
                        uint _6265_dummy_parameter;
                        _11825 = max((_4126 - (log(((r_depth_tm1.Load(int3(int2(floor(_11821 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6265_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11825 = 0.0f;
                    }
                    bool _6295 = all(bool2(_11822.x > 0.0f.xx.x, _11822.y > 0.0f.xx.y));
                    bool _6301;
                    if (_6295)
                    {
                        _6301 = all(bool2(_11822.x < 1.0f.xx.x, _11822.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6301 = _6295;
                    }
                    float _11826;
                    if (_6301)
                    {
                        uint _6308_dummy_parameter;
                        _11826 = _11825 + max((_4126 - (log(((r_depth_tp1.Load(int3(int2(floor(_11822 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6308_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11826 = _11825;
                    }
                    float _11867;
                    int2 _11871;
                    float2 _11882;
                    int2 _11893;
                    float2 _11926;
                    float _11973;
                    if (_11826 == 0.0f)
                    {
                        bool _4168 = _4126 > _10030;
                        bool2 _11981 = _4168.xx;
                        _11973 = _11834;
                        _11926 = float2(_11981.x ? _4121.x : _10040.x, _11981.y ? _4121.y : _10040.y);
                        _11893 = int2(_11981.x ? _4115.x : _10034.x, _11981.y ? _4115.y : _10034.y);
                        _11882 = _10032;
                        _11871 = _10031;
                        _11867 = _4168 ? _4126 : _10030;
                    }
                    else
                    {
                        bool _4177 = _11826 < _11834;
                        bool2 _11977 = _4177.xx;
                        _11973 = _4177 ? _11826 : _11834;
                        _11926 = _10040;
                        _11893 = _10034;
                        _11882 = float2(_11977.x ? _4121.x : _10032.x, _11977.y ? _4121.y : _10032.y);
                        _11871 = int2(_11977.x ? _4115.x : _10031.x, _11977.y ? _4115.y : _10031.y);
                        _11867 = _10030;
                    }
                    _11972 = _11973;
                    _11925 = _11926;
                    _11892 = _11893;
                    _11881 = _11882;
                    _11870 = _11871;
                    _11866 = _11867;
                }
                bool _4189 = _10030 < 0.0f;
                bool2 _11987 = _4189.xx;
                int2 _11990 = int2(_11987.x ? _10031.x : _10034.x, _11987.y ? _10031.y : _10034.y);
                _11427 = float3(1.0f, _4080, float(any(bool2(_11990.x != _4008.x, _11990.y != _4008.y))));
                _10074 = _11990;
                _10063 = _4189 ? false : true;
                _10042 = float2(_11987.x ? _10032.x : _10040.x, _11987.y ? _10032.y : _10040.y);
            }
            else
            {
                _11427 = _9821;
                _10074 = _4008;
                _10063 = false;
                _10042 = _5926;
            }
            _11426 = _11427;
            _10073 = _10074;
            _10062 = _10063;
            _10041 = _10042;
        }
        else
        {
            _11426 = 0.0f.xxx;
            _10073 = _4008;
            _10062 = false;
            _10041 = _5926;
        }
        float2 _10043;
        if (_5948)
        {
            float2 _6373 = clamp((((_10020 + (_10041 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6376 = tan(_6373.x);
            _10043 = (float2(_6376 / cbFI_DeviceToViewDepth.z, (tan(_6373.y) * sqrt(1.0f + (_6376 * _6376))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10043 = _10020 + (_10041 * cbFI_Timestep);
        }
        float _4212 = cbFI_Timestep - 1.0f;
        float2 _10045;
        if (_5948)
        {
            float2 _6444 = clamp((((_10020 + (_10041 * _4212)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6447 = tan(_6444.x);
            _10045 = (float2(_6447 / cbFI_DeviceToViewDepth.z, (tan(_6444.y) * sqrt(1.0f + (_6447 * _6447))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10045 = _10020 + (_10041 * _4212);
        }
        float _4217 = -cbFI_Timestep;
        float2 _10046;
        if (_5948)
        {
            float2 _6515 = clamp((((_10020 + (_5920 * _4217)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6518 = tan(_6515.x);
            _10046 = (float2(_6518 / cbFI_DeviceToViewDepth.z, (tan(_6515.y) * sqrt(1.0f + (_6518 * _6518))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10046 = _10020 + (_5920 * _4217);
        }
        float _4222 = 1.0f - cbFI_Timestep;
        float2 _10047;
        if (_5948)
        {
            float2 _6586 = clamp((((_10020 + (_5920 * _4222)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6589 = tan(_6586.x);
            _10047 = (float2(_6589 / cbFI_DeviceToViewDepth.z, (tan(_6586.y) * sqrt(1.0f + (_6589 * _6589))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10047 = _10020 + (_5920 * _4222);
        }
        float4 _6624 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10043, 0.0f);
        float3 _6625 = _6624.xyz;
        float4 _6632 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10045, 0.0f);
        float3 _6633 = _6632.xyz;
        float4 _6640 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10046, 0.0f);
        float3 _6641 = _6640.xyz;
        float4 _6648 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10047, 0.0f);
        float3 _6649 = _6648.xyz;
        float4 _6663 = exp(_5914 - max(max(max(_5914.x, _5914.y), _5914.z), _5914.w).xxxx);
        float4 _6670 = _6663 / (dot(_6663, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4241 = _4034 && (!_10062);
        bool _4250;
        if (_4241)
        {
            _4250 = (_6670.z + _6670.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4250 = _4241;
        }
        bool _4261;
        if (_4250)
        {
            _4261 = length((_10046 - _10043) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4261 = _4250;
        }
        bool _10086;
        if (_4261)
        {
            uint4 _6689 = r_warped_motion_qdata_tp1.Load(int3(_10073, 0));
            uint _6690 = _6689.x;
            bool _10089;
            if (_6690 != 0u)
            {
                float _10075;
                if (_6690 == 0u)
                {
                    _10075 = -1.0f;
                }
                else
                {
                    _10075 = float((_6690 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4271 = _10075 - 0.12000000476837158203125f;
                bool _6709 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                bool _6715;
                if (_6709)
                {
                    _6715 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                }
                else
                {
                    _6715 = _6709;
                }
                bool _4281;
                if (_6715)
                {
                    uint _6722_dummy_parameter;
                    _4281 = (log(((r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6722_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4271;
                }
                else
                {
                    _4281 = _6715;
                }
                bool _4295;
                if (!_4281)
                {
                    bool _6752 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                    bool _6758;
                    if (_6752)
                    {
                        _6758 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6758 = _6752;
                    }
                    bool _4293;
                    if (_6758)
                    {
                        uint _6765_dummy_parameter;
                        _4293 = (log(((r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6765_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4271;
                    }
                    else
                    {
                        _4293 = _6758;
                    }
                    _4295 = _4293;
                }
                else
                {
                    _4295 = _4281;
                }
                _10089 = _4295;
            }
            else
            {
                _10089 = false;
            }
            _10086 = _10089;
        }
        else
        {
            _10086 = false;
        }
        bool _4300 = _10062 || _10086;
        bool _4305;
        if (_4300)
        {
            bool _6795 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
            bool _6801;
            if (_6795)
            {
                _6801 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
            }
            else
            {
                _6801 = _6795;
            }
            _4305 = _6801;
        }
        else
        {
            _4305 = _4300;
        }
        bool _4310;
        if (_4305)
        {
            bool _6806 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
            bool _6812;
            if (_6806)
            {
                _6812 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
            }
            else
            {
                _6812 = _6806;
            }
            _4310 = _6812;
        }
        else
        {
            _4310 = _4305;
        }
        float4 _10183;
        if (_4310)
        {
            float _4313 = _6670.x;
            float _4315 = _6670.y;
            float _4316 = _4313 + _4315;
            float _4321 = _6670.z + _6670.w;
            float _10104;
            if (_4316 > 0.001000000047497451305389404296875f)
            {
                _10104 = _4313 / _4316;
            }
            else
            {
                _10104 = _4222;
            }
            _10183 = float4(_4313 + (_4321 * _10104), _4315 + (_4321 * (1.0f - _10104)), 0.0f, 0.0f);
        }
        else
        {
            _10183 = _6670;
        }
        bool _6840 = (cbFI_pad0 & 1024u) != 0u;
        bool _6816 = !_6840;
        bool _6817 = !_6816;
        bool _6834;
        if (_6817)
        {
            _6834 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10073.y * cbFI_MvDepthLaneSize.x) + _10073.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6834 = _6816;
        }
        bool _6866;
        if (_6817)
        {
            _6866 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4013.y * cbFI_FlowLaneSize.x) + _4013.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6866 = _6816;
        }
        float _4356 = float(_6866);
        bool _10196;
        float4 _10281;
        float3 _11241;
        if (_6840)
        {
            bool _4366;
            if (_6834)
            {
                _4366 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
            }
            else
            {
                _4366 = _6834;
            }
            bool _4372;
            if (_4366)
            {
                _4372 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
            }
            else
            {
                _4372 = _4366;
            }
            bool _4379;
            if (_6834)
            {
                _4379 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
            }
            else
            {
                _4379 = _6834;
            }
            bool _4385;
            if (_4379)
            {
                _4385 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
            }
            else
            {
                _4385 = _4379;
            }
            bool _4392;
            if (_6866)
            {
                _4392 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
            }
            else
            {
                _4392 = _6866;
            }
            bool _4398;
            if (_4392)
            {
                _4398 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
            }
            else
            {
                _4398 = _4392;
            }
            bool _4405;
            if (_6866)
            {
                _4405 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
            }
            else
            {
                _4405 = _6866;
            }
            bool _4411;
            if (_4405)
            {
                _4411 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
            }
            else
            {
                _4411 = _4405;
            }
            bool _4413 = !_6834;
            if (_4413)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6908;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6908);
                }
            }
            bool _4418 = !_6866;
            if (_4418)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6918;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6918);
                }
            }
            if (_6834 && _4418)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6928;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6928);
                }
            }
            if (_4413 && _6866)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6938;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6938);
                }
            }
            float _4437 = float(_4372);
            float _4439 = float(_4385);
            bool _4442 = _4398 && _4411;
            float _10138;
            if (_4442)
            {
                _10138 = 1.0f;
            }
            else
            {
                _10138 = (_4398 || _4411) ? 0.5f : 0.0f;
            }
            bool _10143;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4372)) && (!_4385))
            {
                bool _4472;
                if (_4442)
                {
                    float _10141;
                    do
                    {
                        bool _7022 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                        bool _7028;
                        if (_7022)
                        {
                            _7028 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7028 = _7022;
                        }
                        bool _6959 = !_7028;
                        bool _6966;
                        if (!_6959)
                        {
                            bool _7033 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                            bool _7039;
                            if (_7033)
                            {
                                _7039 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7039 = _7033;
                            }
                            _6966 = !_7039;
                        }
                        else
                        {
                            _6966 = _6959;
                        }
                        if (_6966)
                        {
                            _10141 = 0.0f;
                            break;
                        }
                        uint _7046_dummy_parameter;
                        uint _7062_dummy_parameter;
                        float4 _6987 = mul(float4((float2(_10046.x, 1.0f - _10046.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7046_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6989 = _6987.w;
                        if (abs(_6989) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10141 = 0.0f;
                            break;
                        }
                        float _7000 = abs(cbFI_DeviceToViewDepth.y / ((_6987.z / _6989) - cbFI_DeviceToViewDepth.x));
                        float _7003 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7062_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10141 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7000 - _7003) / max(max(_7000, _7003), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4472 = _10141 >= 0.5f;
                }
                else
                {
                    _4472 = _4442;
                }
                bool _4480;
                if (_4472)
                {
                    _4480 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4480 = _4472;
                }
                bool _10144;
                if (_4480)
                {
                    uint _7112_dummy_parameter;
                    float2 _10142;
                    do
                    {
                        float _7138 = 1.0f - _10046.y;
                        float4 _7149 = mul(float4((float2(_10046.x, _7138) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7112_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7151 = _7149.w;
                        if (!(_7151 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10142 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7164 = ((_7149.xy / _7151.xx) + 1.0f.xx) * 0.5f;
                        _10142 = float2(_7164.x - _10046.x, _7138 - _7164.y);
                        break;
                    } while(false);
                    float2 _4493 = float2(cbFI_DisplaySize);
                    _10144 = length(((_10046 + _10142) - _10047) * _4493) <= ((0.100000001490116119384765625f * length(_10142 * _4493)) + 8.0f);
                }
                else
                {
                    _10144 = _4472;
                }
                _10143 = _10144;
            }
            else
            {
                _10143 = true;
            }
            bool _4507 = !_10143;
            bool _11991 = _4507 ? false : _4411;
            bool _11992 = _4507 ? false : _4398;
            bool _10197;
            float4 _10282;
            if (!(((_4372 && _4385) && _11992) && _11991))
            {
                float4 _4529 = _10183 * float4(_4437, _4439, float(_11992), float(_11991));
                float _4531 = dot(_4529, 1.0f.xxxx);
                bool _4534 = !(_4531 > 0.0f);
                float4 _10283;
                if (!_4534)
                {
                    _10283 = _4529 / _4531.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7186;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7186);
                    }
                    _10283 = 0.0f.xxxx;
                }
                _10282 = _10283;
                _10197 = _4534;
            }
            else
            {
                _10282 = _10183;
                _10197 = false;
            }
            _11241 = float3(_4437, _4439, _10138);
            _10281 = _10282;
            _10196 = _10197;
        }
        else
        {
            _11241 = float3(float(_6834), _4356, 0.0f);
            _10281 = _10183;
            _10196 = false;
        }
        bool _4552 = !_10196;
        float4 _10382;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4552) && _6834)
        {
            float _10278;
            do
            {
                uint4 _7326 = r_warped_motion_qdata_tp1.Load(int3(_10073, 0));
                uint _7327 = _7326.x;
                if (_7327 != 0u)
                {
                    float _10277;
                    if (_7327 == 0u)
                    {
                        _10277 = -1.0f;
                    }
                    else
                    {
                        _10277 = float((_7327 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10278 = _10277;
                    break;
                }
                int _10260;
                uint _10261;
                _10261 = _7327;
                _10260 = -1;
                uint _10276;
                for (; _10260 <= 1; _10261 = _10276, _10260++)
                {
                    _10276 = _10261;
                    for (int _10274 = -1; _10274 <= 1; )
                    {
                        _10276 = max(_10276, r_warped_motion_qdata_tp1.Load(int3(clamp(_10073 + int2(_10274, _10260), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10274++;
                        continue;
                    }
                }
                if (_10261 != 0u)
                {
                    float _10273;
                    if (_10261 == 0u)
                    {
                        _10273 = -1.0f;
                    }
                    else
                    {
                        _10273 = float((_10261 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10278 = _10273;
                    break;
                }
                uint _10263;
                _10263 = 4294967295u;
                uint _11962;
                for (int _10262 = 0; _10262 < 8; _10263 = _11962, _10262++)
                {
                    int _10266 = 0;
                    for (;;)
                    {
                        if (_10266 < 5)
                        {
                            int2 _7277 = _10073 + (_1093[_10262] * _1102[_10266].xx);
                            bool _7280 = any(bool2(_7277.x < int2(0, 0).x, _7277.y < int2(0, 0).y));
                            bool _7288;
                            if (!_7280)
                            {
                                _7288 = any(bool2(_7277.x >= cbFI_MvDepthLaneSize.x, _7277.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7288 = _7280;
                            }
                            if (_7288)
                            {
                                _11962 = _10263;
                                break;
                            }
                            uint4 _7366 = r_warped_motion_qdata_tp1.Load(int3(_7277, 0));
                            uint _7367 = _7366.x;
                            if (_7367 != 0u)
                            {
                                _11962 = min(_10263, _7367);
                                break;
                            }
                            _10266++;
                            continue;
                        }
                        else
                        {
                            _11962 = _10263;
                            break;
                        }
                    }
                }
                float _10265;
                if (_10263 == 4294967295u)
                {
                    _10265 = -1.0f;
                }
                else
                {
                    float _10264;
                    if (_10263 == 0u)
                    {
                        _10264 = -1.0f;
                    }
                    else
                    {
                        _10264 = float((_10263 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10265 = _10264;
                }
                _10278 = _10265;
                break;
            } while(false);
            float _4563 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4567 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4573;
            if (_4567)
            {
                _4573 = _10281.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4573 = _4567;
            }
            bool _4578;
            if (_4573)
            {
                bool _7386 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
                bool _7392;
                if (_7386)
                {
                    _7392 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
                }
                else
                {
                    _7392 = _7386;
                }
                _4578 = _7392;
            }
            else
            {
                _4578 = _4573;
            }
            float4 _10324;
            if (_4578)
            {
                float _10299;
                if (_10278 >= 0.0f)
                {
                    _10299 = _10278 - _4563;
                }
                else
                {
                    float _10295;
                    _10295 = 2.0f;
                    float _7449;
                    for (int _10294 = 0; _10294 < 24; _10295 = _7449, _10294++)
                    {
                        float _7413 = float(_10294 & 7) * 0.785398185253143310546875f;
                        int _7415 = _10294 >> 3;
                        int _10296;
                        if (_7415 == 0)
                        {
                            _10296 = 16;
                        }
                        else
                        {
                            _10296 = (_7415 == 1) ? 48 : 96;
                        }
                        uint _7481_dummy_parameter;
                        _7449 = min(_10295, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10045 + ((cbFI_MvDepthLaneSizeRcp * float(_10296)) * float2(cos(_7413), sin(_7413))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7481_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10299 = _10295;
                }
                uint _7513_dummy_parameter;
                float4 _10325;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7513_dummy_parameter))))), 0)).x) > ((exp((_10299 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10325 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10325 = 1.0f.xxxx;
                }
                _10324 = _10325;
            }
            else
            {
                _10324 = 1.0f.xxxx;
            }
            bool _4605 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4611;
            if (_4605)
            {
                _4611 = _10281.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4611 = _4605;
            }
            bool _4616;
            if (_4611)
            {
                bool _7538 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
                bool _7544;
                if (_7538)
                {
                    _7544 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
                }
                else
                {
                    _7544 = _7538;
                }
                _4616 = _7544;
            }
            else
            {
                _4616 = _4611;
            }
            float4 _10328;
            if (_4616)
            {
                float _10319;
                if (_10278 >= 0.0f)
                {
                    _10319 = _10278 - _4563;
                }
                else
                {
                    float _10315;
                    _10315 = 2.0f;
                    float _7601;
                    for (int _10314 = 0; _10314 < 24; _10315 = _7601, _10314++)
                    {
                        float _7565 = float(_10314 & 7) * 0.785398185253143310546875f;
                        int _7567 = _10314 >> 3;
                        int _10316;
                        if (_7567 == 0)
                        {
                            _10316 = 16;
                        }
                        else
                        {
                            _10316 = (_7567 == 1) ? 48 : 96;
                        }
                        uint _7617_dummy_parameter;
                        _7601 = min(_10315, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10043 + ((cbFI_MvDepthLaneSizeRcp * float(_10316)) * float2(cos(_7565), sin(_7565))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7617_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10319 = _10315;
                }
                uint _7665_dummy_parameter;
                float4 _10329;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7665_dummy_parameter))))), 0)).x) > ((exp((_10319 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9889 = _10324;
                    _9889.x = 0.0f;
                    _10329 = _9889;
                }
                else
                {
                    _10329 = _10324;
                }
                _10328 = _10329;
            }
            else
            {
                _10328 = _10324;
            }
            float4 _10383;
            if (any(bool4(_10328.x < 1.0f.xxxx.x, _10328.y < 1.0f.xxxx.y, _10328.z < 1.0f.xxxx.z, _10328.w < 1.0f.xxxx.w)))
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7694;
                    rw_nfru_diagnostics.InterlockedAdd(240, 1u, _7694);
                }
                float4 _4647 = _10281 * _10328;
                float _4649 = dot(_4647, 1.0f.xxxx);
                float4 _10384;
                if (_4649 > 0.0f)
                {
                    _10384 = _4647 / _4649.xxxx;
                }
                else
                {
                    bool _4660 = _10328.y == 0.0f;
                    bool _4666;
                    if (_4660)
                    {
                        _4666 = _10328.x > 0.0f;
                    }
                    else
                    {
                        _4666 = _4660;
                    }
                    bool _4671;
                    if (_4666)
                    {
                        bool _7700 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
                        bool _7706;
                        if (_7700)
                        {
                            _7706 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7706 = _7700;
                        }
                        _4671 = _7706;
                    }
                    else
                    {
                        _4671 = _4666;
                    }
                    float4 _10385;
                    if (_4671)
                    {
                        _10385 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4676 = _10328.x == 0.0f;
                        bool _4682;
                        if (_4676)
                        {
                            _4682 = _10328.y > 0.0f;
                        }
                        else
                        {
                            _4682 = _4676;
                        }
                        bool _4687;
                        if (_4682)
                        {
                            bool _7711 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
                            bool _7717;
                            if (_7711)
                            {
                                _7717 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7717 = _7711;
                            }
                            _4687 = _7717;
                        }
                        else
                        {
                            _4687 = _4682;
                        }
                        bool4 _11993 = _4687.xxxx;
                        _10385 = float4(_11993.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10281.x, _11993.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10281.y, _11993.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10281.z, _11993.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10281.w);
                    }
                    _10384 = _10385;
                }
                _10383 = _10384;
            }
            else
            {
                _10383 = _10281;
            }
            _10382 = _10383;
        }
        else
        {
            _10382 = _10281;
        }
        float4 _10928;
        bool _10948;
        float3 _11062;
        if (((cbFI_pad0 & 32768u) != 0u) && _4552)
        {
            bool _4704 = _10382.x > 0.00999999977648258209228515625f;
            bool _4707 = _10382.y > 0.00999999977648258209228515625f;
            bool _4716 = (_10382.z + _10382.w) > 0.0199999995529651641845703125f;
            bool _4722;
            if (_4716)
            {
                bool _7722 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                bool _7728;
                if (_7722)
                {
                    _7728 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                }
                else
                {
                    _7728 = _7722;
                }
                _4722 = _7728;
            }
            else
            {
                _4722 = _4716;
            }
            bool _4727;
            if (_4722)
            {
                bool _7733 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                bool _7739;
                if (_7733)
                {
                    _7739 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                }
                else
                {
                    _7739 = _7733;
                }
                _4727 = _7739;
            }
            else
            {
                _4727 = _4722;
            }
            bool _4734;
            if (_4727)
            {
                float _10393;
                do
                {
                    bool _7822 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                    bool _7828;
                    if (_7822)
                    {
                        _7828 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7828 = _7822;
                    }
                    bool _7759 = !_7828;
                    bool _7766;
                    if (!_7759)
                    {
                        bool _7833 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                        bool _7839;
                        if (_7833)
                        {
                            _7839 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7839 = _7833;
                        }
                        _7766 = !_7839;
                    }
                    else
                    {
                        _7766 = _7759;
                    }
                    if (_7766)
                    {
                        _10393 = 0.0f;
                        break;
                    }
                    uint _7846_dummy_parameter;
                    uint _7862_dummy_parameter;
                    float4 _7787 = mul(float4((float2(_10046.x, 1.0f - _10046.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7846_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7789 = _7787.w;
                    if (abs(_7789) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10393 = 0.0f;
                        break;
                    }
                    float _7800 = abs(cbFI_DeviceToViewDepth.y / ((_7787.z / _7789) - cbFI_DeviceToViewDepth.x));
                    float _7803 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7862_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10393 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7800 - _7803) / max(max(_7800, _7803), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4734 = _10393 < 0.5f;
            }
            else
            {
                _4734 = _4727;
            }
            float4 _10408;
            if (_4734)
            {
                uint _7912_dummy_parameter;
                uint _7943_dummy_parameter;
                float4 _10409;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7912_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7943_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10409 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10409 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10408 = _10409;
            }
            else
            {
                _10408 = 1.0f.xxxx;
            }
            bool _4758;
            if (_6834)
            {
                bool _7972 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
                bool _7978;
                if (_7972)
                {
                    _7978 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
                }
                else
                {
                    _7978 = _7972;
                }
                _4758 = _7978;
            }
            else
            {
                _4758 = _6834;
            }
            bool _4764;
            if (_6834)
            {
                bool _7983 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
                bool _7989;
                if (_7983)
                {
                    _7989 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
                }
                else
                {
                    _7989 = _7983;
                }
                _4764 = _7989;
            }
            else
            {
                _4764 = _6834;
            }
            bool _4770;
            if (_6866)
            {
                bool _7994 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                bool _8000;
                if (_7994)
                {
                    _8000 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                }
                else
                {
                    _8000 = _7994;
                }
                _4770 = _8000;
            }
            else
            {
                _4770 = _6866;
            }
            bool _4776;
            if (_6866)
            {
                bool _8005 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                bool _8011;
                if (_8005)
                {
                    _8011 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                }
                else
                {
                    _8011 = _8005;
                }
                _4776 = _8011;
            }
            else
            {
                _4776 = _6866;
            }
            bool _4779 = _4770 != _4776;
            bool _4785;
            if (_4779)
            {
                _4785 = _4758 || _4764;
            }
            else
            {
                _4785 = _4779;
            }
            float4 _10497;
            if (_4785)
            {
                float4 _9916 = _10408;
                _9916.z = 0.0f;
                _9916.w = 0.0f;
                _10497 = _9916;
            }
            else
            {
                _10497 = _10408;
            }
            bool _4792 = _4758 && _4704;
            bool _4795 = _4764 && _4707;
            float4 _10602;
            float3 _11140;
            if (_4792 || _4795)
            {
                float _10492;
                do
                {
                    uint4 _8150 = r_warped_motion_qdata_tp1.Load(int3(_10073, 0));
                    uint _8151 = _8150.x;
                    if (_8151 != 0u)
                    {
                        float _10491;
                        if (_8151 == 0u)
                        {
                            _10491 = -1.0f;
                        }
                        else
                        {
                            _10491 = float((_8151 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10492 = _10491;
                        break;
                    }
                    int _10474;
                    uint _10475;
                    _10475 = _8151;
                    _10474 = -1;
                    uint _10490;
                    for (; _10474 <= 1; _10475 = _10490, _10474++)
                    {
                        _10490 = _10475;
                        for (int _10488 = -1; _10488 <= 1; )
                        {
                            _10490 = max(_10490, r_warped_motion_qdata_tp1.Load(int3(clamp(_10073 + int2(_10488, _10474), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10488++;
                            continue;
                        }
                    }
                    if (_10475 != 0u)
                    {
                        float _10487;
                        if (_10475 == 0u)
                        {
                            _10487 = -1.0f;
                        }
                        else
                        {
                            _10487 = float((_10475 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10492 = _10487;
                        break;
                    }
                    uint _10477;
                    _10477 = 4294967295u;
                    uint _11963;
                    for (int _10476 = 0; _10476 < 8; _10477 = _11963, _10476++)
                    {
                        int _10480 = 0;
                        for (;;)
                        {
                            if (_10480 < 5)
                            {
                                int2 _8101 = _10073 + (_1093[_10476] * _1102[_10480].xx);
                                bool _8104 = any(bool2(_8101.x < int2(0, 0).x, _8101.y < int2(0, 0).y));
                                bool _8112;
                                if (!_8104)
                                {
                                    _8112 = any(bool2(_8101.x >= cbFI_MvDepthLaneSize.x, _8101.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8112 = _8104;
                                }
                                if (_8112)
                                {
                                    _11963 = _10477;
                                    break;
                                }
                                uint4 _8190 = r_warped_motion_qdata_tp1.Load(int3(_8101, 0));
                                uint _8191 = _8190.x;
                                if (_8191 != 0u)
                                {
                                    _11963 = min(_10477, _8191);
                                    break;
                                }
                                _10480++;
                                continue;
                            }
                            else
                            {
                                _11963 = _10477;
                                break;
                            }
                        }
                    }
                    float _10479;
                    if (_10477 == 4294967295u)
                    {
                        _10479 = -1.0f;
                    }
                    else
                    {
                        float _10478;
                        if (_10477 == 0u)
                        {
                            _10478 = -1.0f;
                        }
                        else
                        {
                            _10478 = float((_10477 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10479 = _10478;
                    }
                    _10492 = _10479;
                    break;
                } while(false);
                bool _4803 = _10492 < 0.0f;
                float _10493;
                if (_4803)
                {
                    _10493 = 0.0f;
                }
                else
                {
                    _10493 = _10492 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8212_dummy_parameter;
                uint _8244_dummy_parameter;
                float4 _10530;
                if ((_4803 && _4792) && _4795)
                {
                    uint _8276_dummy_parameter;
                    float _8300 = log(((r_depth_tm1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8276_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8308_dummy_parameter;
                    float _8332 = log(((r_depth_tp1.Load(int3(int2(floor(_10045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8308_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10531;
                    if (_8300 > (_8332 + 0.07999999821186065673828125f))
                    {
                        float4 _9920 = _10497;
                        _9920.x = 0.0f;
                        _10531 = _9920;
                    }
                    else
                    {
                        float4 _10532;
                        if (_8332 > (_8300 + 0.07999999821186065673828125f))
                        {
                            float4 _9922 = _10497;
                            _9922.y = 0.0f;
                            _10532 = _9922;
                        }
                        else
                        {
                            _10532 = _10497;
                        }
                        _10531 = _10532;
                    }
                    _10530 = _10531;
                }
                else
                {
                    _10530 = _10497;
                }
                float _4855 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4857 = _10492 >= 0.0f;
                float _10513;
                if (_4857)
                {
                    _10513 = _10492 - _4855;
                }
                else
                {
                    float _10509;
                    if (_4792)
                    {
                        float _10508;
                        _10508 = 2.0f;
                        float _8390;
                        for (int _10507 = 0; _10507 < 24; _10508 = _8390, _10507++)
                        {
                            float _8354 = float(_10507 & 7) * 0.785398185253143310546875f;
                            int _8356 = _10507 >> 3;
                            int _10510;
                            if (_8356 == 0)
                            {
                                _10510 = 16;
                            }
                            else
                            {
                                _10510 = (_8356 == 1) ? 48 : 96;
                            }
                            uint _8406_dummy_parameter;
                            _8390 = min(_10508, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10043 + ((cbFI_MvDepthLaneSizeRcp * float(_10510)) * float2(cos(_8354), sin(_8354))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8406_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10509 = _10508;
                    }
                    else
                    {
                        _10509 = 0.0f;
                    }
                    _10513 = _10509;
                }
                float _10520;
                if (_4857)
                {
                    _10520 = _10492 - _4855;
                }
                else
                {
                    float _10516;
                    if (_4795)
                    {
                        float _10515;
                        _10515 = 2.0f;
                        float _8504;
                        for (int _10514 = 0; _10514 < 24; _10515 = _8504, _10514++)
                        {
                            float _8468 = float(_10514 & 7) * 0.785398185253143310546875f;
                            int _8470 = _10514 >> 3;
                            int _10517;
                            if (_8470 == 0)
                            {
                                _10517 = 16;
                            }
                            else
                            {
                                _10517 = (_8470 == 1) ? 48 : 96;
                            }
                            uint _8536_dummy_parameter;
                            _8504 = min(_10515, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10045 + ((cbFI_MvDepthLaneSizeRcp * float(_10517)) * float2(cos(_8468), sin(_8468))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8536_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10516 = _10515;
                    }
                    else
                    {
                        _10516 = 0.0f;
                    }
                    _10520 = _10516;
                }
                float _10521;
                if (_4792)
                {
                    uint _8568_dummy_parameter;
                    _10521 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8568_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10521 = 0.0f;
                }
                float _10522;
                if (_4795)
                {
                    uint _8588_dummy_parameter;
                    _10522 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8588_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10522 = 0.0f;
                }
                bool _4912;
                if (_4792)
                {
                    _4912 = _10521 > ((exp((_10513 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4912 = _4792;
                }
                float4 _10538;
                if (_4912)
                {
                    float4 _9924 = _10530;
                    _9924.x = 0.0f;
                    _10538 = _9924;
                }
                else
                {
                    _10538 = _10530;
                }
                bool _4924;
                if (_4795)
                {
                    _4924 = _10522 > ((exp((_10520 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4924 = _4795;
                }
                float4 _10540;
                if (_4924)
                {
                    float4 _9926 = _10538;
                    _9926.y = 0.0f;
                    _10540 = _9926;
                }
                else
                {
                    _10540 = _10538;
                }
                float4 _10603;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4857)
                {
                    bool _4944;
                    if (_4792)
                    {
                        _4944 = _10521 < ((exp((_10513 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4944 = _4792;
                    }
                    float4 _10542;
                    if (_4944)
                    {
                        float4 _9928 = _10540;
                        _9928.x = 0.0f;
                        _10542 = _9928;
                    }
                    else
                    {
                        _10542 = _10540;
                    }
                    bool _4956;
                    if (_4795)
                    {
                        _4956 = _10522 < ((exp((_10520 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4956 = _4795;
                    }
                    float4 _10604;
                    if (_4956)
                    {
                        float4 _9930 = _10542;
                        _9930.y = 0.0f;
                        _10604 = _9930;
                    }
                    else
                    {
                        _10604 = _10542;
                    }
                    _10603 = _10604;
                }
                else
                {
                    _10603 = _10540;
                }
                _11140 = float3(_10493, log(((r_depth_tm1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8212_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8244_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10602 = _10603;
            }
            else
            {
                _11140 = float3(0.0f, 0.0f, 0.5f);
                _10602 = _10497;
            }
            bool _4967 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4716;
            bool _4973;
            if (_4967)
            {
                _4973 = _4770 || _4776;
            }
            else
            {
                _4973 = _4967;
            }
            float4 _10625;
            if (_4973)
            {
                float _10597;
                do
                {
                    uint4 _8768 = r_warped_motion_qdata_tp1.Load(int3(_10073, 0));
                    uint _8769 = _8768.x;
                    if (_8769 != 0u)
                    {
                        float _10596;
                        if (_8769 == 0u)
                        {
                            _10596 = -1.0f;
                        }
                        else
                        {
                            _10596 = float((_8769 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10597 = _10596;
                        break;
                    }
                    int _10579;
                    uint _10580;
                    _10580 = _8769;
                    _10579 = -1;
                    uint _10595;
                    for (; _10579 <= 1; _10580 = _10595, _10579++)
                    {
                        _10595 = _10580;
                        for (int _10593 = -1; _10593 <= 1; )
                        {
                            _10595 = max(_10595, r_warped_motion_qdata_tp1.Load(int3(clamp(_10073 + int2(_10593, _10579), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10593++;
                            continue;
                        }
                    }
                    if (_10580 != 0u)
                    {
                        float _10592;
                        if (_10580 == 0u)
                        {
                            _10592 = -1.0f;
                        }
                        else
                        {
                            _10592 = float((_10580 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10597 = _10592;
                        break;
                    }
                    uint _10582;
                    _10582 = 4294967295u;
                    uint _11964;
                    for (int _10581 = 0; _10581 < 8; _10582 = _11964, _10581++)
                    {
                        int _10585 = 0;
                        for (;;)
                        {
                            if (_10585 < 5)
                            {
                                int2 _8719 = _10073 + (_1093[_10581] * _1102[_10585].xx);
                                bool _8722 = any(bool2(_8719.x < int2(0, 0).x, _8719.y < int2(0, 0).y));
                                bool _8730;
                                if (!_8722)
                                {
                                    _8730 = any(bool2(_8719.x >= cbFI_MvDepthLaneSize.x, _8719.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8730 = _8722;
                                }
                                if (_8730)
                                {
                                    _11964 = _10582;
                                    break;
                                }
                                uint4 _8808 = r_warped_motion_qdata_tp1.Load(int3(_8719, 0));
                                uint _8809 = _8808.x;
                                if (_8809 != 0u)
                                {
                                    _11964 = min(_10582, _8809);
                                    break;
                                }
                                _10585++;
                                continue;
                            }
                            else
                            {
                                _11964 = _10582;
                                break;
                            }
                        }
                    }
                    float _10584;
                    if (_10582 == 4294967295u)
                    {
                        _10584 = -1.0f;
                    }
                    else
                    {
                        float _10583;
                        if (_10582 == 0u)
                        {
                            _10583 = -1.0f;
                        }
                        else
                        {
                            _10583 = float((_10582 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10584 = _10583;
                    }
                    _10597 = _10584;
                    break;
                } while(false);
                float4 _10626;
                if (_10597 >= 0.0f)
                {
                    float _8830 = (exp((_10597 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4992;
                    if (_4770)
                    {
                        uint _8837_dummy_parameter;
                        _4992 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8837_dummy_parameter))))), 0)).x) > _8830;
                    }
                    else
                    {
                        _4992 = _4770;
                    }
                    float4 _10615;
                    if (_4992)
                    {
                        float4 _9932 = _10602;
                        _9932.z = 0.0f;
                        _10615 = _9932;
                    }
                    else
                    {
                        _10615 = _10602;
                    }
                    bool _5004;
                    if (_4776)
                    {
                        uint _8857_dummy_parameter;
                        _5004 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8857_dummy_parameter))))), 0)).x) > _8830;
                    }
                    else
                    {
                        _5004 = _4776;
                    }
                    float4 _10627;
                    if (_5004)
                    {
                        float4 _9934 = _10615;
                        _9934.w = 0.0f;
                        _10627 = _9934;
                    }
                    else
                    {
                        _10627 = _10615;
                    }
                    _10626 = _10627;
                }
                else
                {
                    _10626 = _10602;
                }
                _10625 = _10626;
            }
            else
            {
                _10625 = _10602;
            }
            bool _5012 = _4758 != _4764;
            bool _5019;
            if (_5012)
            {
                _5019 = _4758 ? _4704 : _4707;
            }
            else
            {
                _5019 = _5012;
            }
            bool _5026;
            if (_5019)
            {
                _5026 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5026 = _5019;
            }
            float4 _10710;
            if (_5026)
            {
                bool2 _5031 = _4758.xx;
                float2 _5032 = float2(_5031.x ? _10043.x : _10045.x, _5031.y ? _10043.y : _10045.y);
                float _10617;
                if (_4758)
                {
                    uint _8877_dummy_parameter;
                    _10617 = r_depth_tm1.Load(int3(int2(floor(_5032 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8877_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8893_dummy_parameter;
                    _10617 = r_depth_tp1.Load(int3(int2(floor(_5032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8893_dummy_parameter))))), 0)).x;
                }
                float4x4 _10618;
                if (_4758)
                {
                    _10618 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10618 = cbFI_MotionTP1ToTM1;
                }
                float2 _10619;
                do
                {
                    float _8920 = _5032.x;
                    float _8923 = 1.0f - _5032.y;
                    float4 _8934 = mul(float4((float2(_8920, _8923) * 2.0f) - 1.0f.xx, _10617, 1.0f), _10618);
                    float _8936 = _8934.w;
                    if (!(_8936 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10619 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8949 = ((_8934.xy / _8936.xx) + 1.0f.xx) * 0.5f;
                    _10619 = float2(_8949.x - _8920, _8923 - _8949.y);
                    break;
                } while(false);
                float2 _5062 = float2(cbFI_DisplaySize);
                float4 _10711;
                if (!(length(((_5032 + _10619) - float2(_5031.x ? _10045.x : _10043.x, _5031.y ? _10045.y : _10043.y)) * _5062) <= ((0.100000001490116119384765625f * length(_10619 * _5062)) + 8.0f)))
                {
                    float4 _10712;
                    if (_4758)
                    {
                        float4 _9944 = _10625;
                        _9944.x = 0.0f;
                        _10712 = _9944;
                    }
                    else
                    {
                        float4 _9946 = _10625;
                        _9946.y = 0.0f;
                        _10712 = _9946;
                    }
                    _10711 = _10712;
                }
                else
                {
                    _10711 = _10625;
                }
                _10710 = _10711;
            }
            else
            {
                _10710 = _10625;
            }
            float4 _5087 = _10382 * _10710;
            float _5089 = dot(_5087, 1.0f.xxxx);
            float4 _10929;
            bool _10949;
            if (_5089 > 0.0f)
            {
                _10949 = _10196;
                _10929 = _5087 / _5089.xxxx;
            }
            else
            {
                bool _5100 = any(bool4(_10710.x < 1.0f.xxxx.x, _10710.y < 1.0f.xxxx.y, _10710.z < 1.0f.xxxx.z, _10710.w < 1.0f.xxxx.w));
                if (_5100)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8971;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8971);
                    }
                }
                bool4 _11996 = _5100.xxxx;
                _10949 = _5100 ? true : _10196;
                _10929 = float4(_11996.x ? 0.0f.xxxx.x : _10382.x, _11996.y ? 0.0f.xxxx.y : _10382.y, _11996.z ? 0.0f.xxxx.z : _10382.z, _11996.w ? 0.0f.xxxx.w : _10382.w);
            }
            _11062 = _11140;
            _10948 = _10949;
            _10928 = _10929;
        }
        else
        {
            _11062 = float3(0.0f, 0.0f, 0.5f);
            _10948 = _10196;
            _10928 = _10382;
        }
        uint _5109 = (cbFI_pad0 >> 24u) & 31u;
        uint _5113 = (cbFI_pad0 >> 16u) & 255u;
        bool _5115 = _5109 != 0u;
        bool _5117 = _5113 == 12u;
        bool _5120 = _5113 == 13u;
        float4 _10945;
        if ((_5115 || _5117) || _5120)
        {
            float _10713;
            do
            {
                bool _9055 = all(bool2(_10046.x > 0.0f.xx.x, _10046.y > 0.0f.xx.y));
                bool _9061;
                if (_9055)
                {
                    _9061 = all(bool2(_10046.x < 1.0f.xx.x, _10046.y < 1.0f.xx.y));
                }
                else
                {
                    _9061 = _9055;
                }
                bool _8992 = !_9061;
                bool _8999;
                if (!_8992)
                {
                    bool _9066 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
                    bool _9072;
                    if (_9066)
                    {
                        _9072 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9072 = _9066;
                    }
                    _8999 = !_9072;
                }
                else
                {
                    _8999 = _8992;
                }
                if (_8999)
                {
                    _10713 = 0.0f;
                    break;
                }
                uint _9079_dummy_parameter;
                uint _9095_dummy_parameter;
                float4 _9020 = mul(float4((float2(_10046.x, 1.0f - _10046.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10046 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9079_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9022 = _9020.w;
                if (abs(_9022) < 9.9999999747524270787835121154785e-07f)
                {
                    _10713 = 0.0f;
                    break;
                }
                float _9033 = abs(cbFI_DeviceToViewDepth.y / ((_9020.z / _9022) - cbFI_DeviceToViewDepth.x));
                float _9036 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9095_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10713 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9033 - _9036) / max(max(_9033, _9036), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9143 = all(bool2(_10047.x > 0.0f.xx.x, _10047.y > 0.0f.xx.y));
            bool _9149;
            if (_9143)
            {
                _9149 = all(bool2(_10047.x < 1.0f.xx.x, _10047.y < 1.0f.xx.y));
            }
            else
            {
                _9149 = _9143;
            }
            float _10714;
            if (_9149)
            {
                uint _9156_dummy_parameter;
                _10714 = length((_5920 + (r_motion_tp1.Load(int3(int2(floor(_10047 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9156_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10714 = 1000000.0f;
            }
            float _10725;
            if ((_5109 & 1u) != 0u)
            {
                _10725 = _10713;
            }
            else
            {
                _10725 = 1.0f;
            }
            float _10726;
            if ((_5109 & 2u) != 0u)
            {
                _10726 = _10725 * (1.0f - smoothstep(2.0f, 8.0f, _10714));
            }
            else
            {
                _10726 = _10725;
            }
            float _10727;
            if ((_5109 & 4u) != 0u)
            {
                _10727 = _10726 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6641 - _6649) - length(_6625 - _6633))));
            }
            else
            {
                _10727 = _10726;
            }
            float _10939;
            if ((_5109 & 8u) != 0u)
            {
                _10939 = lerp(1.0f, _10727, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6625 - _6633)));
            }
            else
            {
                _10939 = _10727;
            }
            bool _5195 = (_5109 & 16u) != 0u;
            bool _5204;
            if (_5195)
            {
                _5204 = length(_10041 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5204 = _5195;
            }
            float _11998 = _5204 ? 1.0f : _10939;
            bool _5210 = _5115 && _6834;
            bool _5215;
            if (_5210)
            {
                bool _9181 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
                bool _9187;
                if (_9181)
                {
                    _9187 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
                }
                else
                {
                    _9187 = _9181;
                }
                _5215 = _9187;
            }
            else
            {
                _5215 = _5210;
            }
            bool _5220;
            if (_5215)
            {
                bool _9192 = all(bool2(_10045.x > 0.0f.xx.x, _10045.y > 0.0f.xx.y));
                bool _9198;
                if (_9192)
                {
                    _9198 = all(bool2(_10045.x < 1.0f.xx.x, _10045.y < 1.0f.xx.y));
                }
                else
                {
                    _9198 = _9192;
                }
                _5220 = _9198;
            }
            else
            {
                _5220 = _5215;
            }
            float4 _10946;
            if (_5220)
            {
                float _5226 = _10928.x + _10928.y;
                float _5235 = (_10928.z + _10928.w) * (1.0f - _11998);
                float _10942;
                if (_5226 > 9.9999997473787516355514526367188e-06f)
                {
                    _10942 = _10928.x / _5226;
                }
                else
                {
                    _10942 = _4222;
                }
                _10946 = float4(_10928.x + (_5235 * _10942), _10928.y + (_5235 * (1.0f - _10942)), _10928.zw * _11998);
            }
            else
            {
                _10946 = _10928;
            }
            _10945 = _10946;
        }
        else
        {
            _10945 = _10928;
        }
        float3 _11766;
        if (_10948)
        {
            float3 _9204 = r_current_interpolation_source.Load(int3(_3597, 0)).xyz;
            float3 _11767;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6834)
            {
                uint _9211_dummy_parameter;
                float _11053;
                _11053 = r_depth_tm1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9211_dummy_parameter))))), 0)).x;
                float _5347;
                for (int _11052 = 0; _11052 < 24; _11053 = _5347, _11052++)
                {
                    float _5319 = float(_11052 & 7) * 0.785398185253143310546875f;
                    int _5321 = _11052 >> 3;
                    int _11817;
                    if (_5321 == 0)
                    {
                        _11817 = 16;
                    }
                    else
                    {
                        _11817 = (_5321 == 1) ? 48 : 96;
                    }
                    uint _9231_dummy_parameter;
                    _5347 = max(_11053, r_depth_tm1.Load(int3(int2(floor(clamp(_10043 + ((cbFI_MvDepthLaneSizeRcp * float(_11817)) * float2(cos(_5319), sin(_5319))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9231_dummy_parameter))))), 0)).x);
                }
                float2 _11054;
                do
                {
                    float _9253 = 1.0f - _10043.y;
                    float4 _9264 = mul(float4((float2(_10043.x, _9253) * 2.0f) - 1.0f.xx, _11053, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9266 = _9264.w;
                    if (!(_9266 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11054 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9279 = ((_9264.xy / _9266.xx) + 1.0f.xx) * 0.5f;
                    _11054 = float2(_9279.x - _10043.x, _9253 - _9279.y);
                    break;
                } while(false);
                float2 _5358 = _10043 + _11054;
                bool _9297 = all(bool2(_5358.x > 0.0f.xx.x, _5358.y > 0.0f.xx.y));
                bool _9303;
                if (_9297)
                {
                    _9303 = all(bool2(_5358.x < 1.0f.xx.x, _5358.y < 1.0f.xx.y));
                }
                else
                {
                    _9303 = _9297;
                }
                float3 _11768;
                if (_9303)
                {
                    float _5364 = abs(cbFI_DeviceToViewDepth.y / (_11053 - cbFI_DeviceToViewDepth.x));
                    uint _9323_dummy_parameter;
                    int2 _9323 = int2(spvTextureSize(r_depth_m2, uint(0), _9323_dummy_parameter));
                    float _5368 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5358 * float2(_9323))), int2(0, 0), _9323 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11773;
                    if (abs(_5368 - _5364) <= (0.20000000298023223876953125f * max(_5368, _5364)))
                    {
                        uint _9357_dummy_parameter;
                        int2 _9357 = int2(spvTextureSize(r_colour_m2, uint(0), _9357_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9380;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9380);
                        }
                        _11773 = r_colour_m2.Load(int3(clamp(int2(floor(_5358 * float2(_9357))), int2(0, 0), _9357 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9390;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9390);
                        }
                        _11773 = _9204;
                    }
                    _11768 = _11773;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9400;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9400);
                    }
                    _11768 = _9204;
                }
                _11767 = _11768;
            }
            else
            {
                _11767 = _9204;
            }
            _11766 = _11767;
        }
        else
        {
            _11766 = (((_6625 * _10945.x) + (_6633 * _10945.y)) + (_6641 * _10945.z)) + (_6649 * _10945.w);
        }
        uint _5396 = cbFI_pad0 & 255u;
        bool _11658;
        float3 _11765;
        if (_5396 != 0u)
        {
            float3 _5401 = r_present_backbuffer.Load(int3(_3597, 0)).xyz;
            float3 _5405 = r_current_interpolation_source.Load(int3(_3597, 0)).xyz;
            float3 _5409 = abs(_5401 - _5405);
            float3 _11057;
            if (_5396 == 2u)
            {
                _11057 = (abs(_5405) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11057 = 0.000244140625f.xxx;
            }
            bool _5425 = any(bool3(_5409.x > _11057.x, _5409.y > _11057.y, _5409.z > _11057.z));
            bool3 _11999 = _5425.xxx;
            _11765 = float3(_11999.x ? _5401.x : _11766.x, _11999.y ? _5401.y : _11766.y, _11999.z ? _5401.z : _11766.z);
            _11658 = _5425;
        }
        else
        {
            _11765 = _11766;
            _11658 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9415;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9415);
        }
        float3 _11748;
        if (_5113 == 1u)
        {
            _11748 = lerp(_6625, _6633, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11749;
            if (_5113 == 2u)
            {
                _11749 = lerp(_6641, _6649, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11750;
                if (_5113 == 3u)
                {
                    _11750 = float(_11658).xxx;
                }
                else
                {
                    float3 _11751;
                    if (_5113 == 4u)
                    {
                        _11751 = float3(((_10041 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11752;
                        if (_5113 == 5u)
                        {
                            _11752 = float3(((_5920 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11753;
                            if (_5113 == 6u)
                            {
                                _11753 = float3(_10945.xy, _10945.z + _10945.w);
                            }
                            else
                            {
                                float3 _11754;
                                if (_5113 == 7u)
                                {
                                    _11754 = r_current_interpolation_source.Load(int3(_3597, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11755;
                                    if (_5113 == 8u)
                                    {
                                        _11755 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3997, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11756;
                                        if (_5117)
                                        {
                                            uint _9437_dummy_parameter;
                                            uint _9469_dummy_parameter;
                                            _11756 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3997 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9437_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3997 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9469_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11757;
                                            if (_5120)
                                            {
                                                _11757 = _6641;
                                            }
                                            else
                                            {
                                                float3 _11758;
                                                if (_5113 == 20u)
                                                {
                                                    _11758 = _6625;
                                                }
                                                else
                                                {
                                                    float3 _11759;
                                                    if (_5113 == 21u)
                                                    {
                                                        _11759 = _6633;
                                                    }
                                                    else
                                                    {
                                                        float3 _11760;
                                                        if (_5113 == 22u)
                                                        {
                                                            _11760 = _6649;
                                                        }
                                                        else
                                                        {
                                                            float3 _11761;
                                                            if (_5113 == 18u)
                                                            {
                                                                _11761 = _11426;
                                                            }
                                                            else
                                                            {
                                                                float3 _11762;
                                                                if (_5113 == 19u)
                                                                {
                                                                    _11762 = _11241;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12001 = (_5113 == 23u).xxx;
                                                                    _11762 = float3(_12001.x ? _11062.x : _11765.x, _12001.y ? _11062.y : _11765.y, _12001.z ? _11062.z : _11765.z);
                                                                }
                                                                _11761 = _11762;
                                                            }
                                                            _11760 = _11761;
                                                        }
                                                        _11759 = _11760;
                                                    }
                                                    _11758 = _11759;
                                                }
                                                _11757 = _11758;
                                            }
                                            _11756 = _11757;
                                        }
                                        _11755 = _11756;
                                    }
                                    _11754 = _11755;
                                }
                                _11753 = _11754;
                            }
                            _11752 = _11753;
                        }
                        _11751 = _11752;
                    }
                    _11750 = _11751;
                }
                _11749 = _11750;
            }
            _11748 = _11749;
        }
        float3 _11747;
        if ((_5113 >= 9u) && (_5113 <= 11u))
        {
            uint _5589 = 64u + uint((_10073.y * cbFI_MvDepthLaneSize.x) + _10073.x);
            uint _5593 = rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) & 15u;
            float3 _11778;
            if (_5113 == 10u)
            {
                float3 _11746;
                if ((rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) & 32u) != 0u)
                {
                    _11746 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11745;
                    if ((rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) & 16u) != 0u)
                    {
                        _11745 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5614 = ((rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) & 64u) != 0u).xxx;
                        _11745 = float3(_5614.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5614.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5614.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11746 = _11745;
                }
                _11778 = _11746;
            }
            else
            {
                float3 _11779;
                if (_5113 == 11u)
                {
                    uint _5627 = (rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) >> 8u) & 15u;
                    uint _5630 = (rw_nfru_diagnostics.Load<uint>(_5589 * 4 + 0) >> 12u) & 15u;
                    float3 _11738;
                    if ((_5593 == 2u) || (_5593 == 3u))
                    {
                        _11738 = _3293[_5593];
                    }
                    else
                    {
                        bool _5642 = _5627 == 3u;
                        bool _5644 = _5630 == 3u;
                        float3 _11739;
                        if (_5642 && _5644)
                        {
                            _11739 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11740;
                            if (_5642)
                            {
                                _11740 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11741;
                                if (_5644)
                                {
                                    _11741 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11742;
                                    if ((_5627 == 4u) || (_5630 == 4u))
                                    {
                                        _11742 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11743;
                                        if ((_5627 == 1u) || (_5630 == 1u))
                                        {
                                            _11743 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12003 = (_5593 == 1u).xxx;
                                            _11743 = float3(_12003.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12003.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12003.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11742 = _11743;
                                    }
                                    _11741 = _11742;
                                }
                                _11740 = _11741;
                            }
                            _11739 = _11740;
                        }
                        _11738 = _11739;
                    }
                    _11779 = _11738;
                }
                else
                {
                    _11779 = _3293[min(_5593, 7u)];
                }
                _11778 = _11779;
            }
            _11747 = _11778;
        }
        else
        {
            _11747 = _11748;
        }
        float4 _11782;
        if ((_5113 >= 14u) && (_5113 <= 16u))
        {
            float2 _11780;
            if (_5113 == 14u)
            {
                uint _5700_dummy_parameter;
                uint _5706_dummy_parameter;
                _11780 = r_flow_tm1.Load(int3(clamp(int2(floor(_3997 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5700_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5706_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11781;
                if (_5113 == 16u)
                {
                    uint _9520 = r_warped_flow_qdata_tm1.Load(int3(_4013, 0)).x & 2147483647u;
                    uint _9552 = uint(max((int((_9520 >> 16u) & 15u) - 6), 0));
                    _11781 = ((float2(float((1 - (2 * int((_9520 >> 15u) & 1u))) * int(((_9520 >> uint(7)) & 127u) << _9552)), float((1 - (2 * int((_9520 >> 14u) & 1u))) * int((_9520 & 127u) << _9552))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11781 = _5920 * float2(cbFI_DisplaySize);
                }
                _11780 = _11781;
            }
            uint2 _5739 = uint2(clamp(round(_11780 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5741 = _5739.x;
            uint _5748 = _5739.y;
            _11782 = float4(float(_5741 & 255u), float((_5741 >> 8u) | ((_5748 & 15u) << 4u)), float(_5748 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11783;
            if (_5113 == 17u)
            {
                _11783 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4013, 0)).x != 0u), _4356, 0.0f, 1.0f);
            }
            else
            {
                _11783 = float4(_11747, 1.0f);
            }
            _11782 = _11783;
        }
        rw_output[_3597] = _11782.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5792 = ((uint(_3597.y) * uint(cbFI_DisplaySize.x)) + uint(_3597.x)) * 6u;
            uint _9598 = spvPackHalf2x16(clamp(_6624.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5792 * 4 + 0, (((_9598 & 32767u) >> 4u) | ((((_9598 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6624.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9633 = spvPackHalf2x16(clamp(_6632.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5792 + 1u) * 4 + 0, (((_9633 & 32767u) >> 4u) | ((((_9633 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6632.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9668 = spvPackHalf2x16(clamp(_6640.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5792 + 2u) * 4 + 0, (((_9668 & 32767u) >> 4u) | ((((_9668 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6640.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9703 = spvPackHalf2x16(clamp(_6648.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5792 + 3u) * 4 + 0, (((_9703 & 32767u) >> 4u) | ((((_9703 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6648.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9730 = r_current_interpolation_source.Load(int3(_3597, 0));
            uint _9744 = spvPackHalf2x16(clamp(_9730.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5792 + 4u) * 4 + 0, (((_9744 & 32767u) >> 4u) | ((((_9744 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9730.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11816;
            if (_11658 || (_5113 != 0u))
            {
                _11816 = 4294967295u;
            }
            else
            {
                uint _9779 = spvPackHalf2x16(clamp(_11782.xy, 0.0f.xx, 65000.0f.xx));
                _11816 = (((_9779 & 32767u) >> 4u) | ((((_9779 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11782.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5792 + 5u) * 4 + 0, _11816);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3597] = float4(r_current_interpolation_source.Load(int3(_3597, 0)).xyz, 1.0f).xyz;
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
