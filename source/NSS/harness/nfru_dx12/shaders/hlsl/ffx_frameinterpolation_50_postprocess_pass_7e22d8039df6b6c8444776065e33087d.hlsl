static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3290[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3594 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3594.x >= cbFI_DisplaySize.x, _3594.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3594] = float4(r_present_backbuffer.Load(int3(_3594, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3594] = float4(r_current_interpolation_source.Load(int3(_3594, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3993 = (float2(_3594) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4004 = int2(floor(_3993 * float2(cbFI_MvDepthLaneSize)));
        int2 _4009 = int2(floor(_3993 * float2(cbFI_FlowLaneSize)));
        float4 _5909 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3993 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5915 = r_warped_filled_flow_tm1.Load(int3(_4009, 0)).xy;
        float2 _5921 = r_warped_filled_motion_tp1.Load(int3(_4004, 0)).xy;
        bool _5943 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10005;
        if (_5943)
        {
            float _5956 = ((2.0f * _3993.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10005 = float2(atan(_5956) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3993.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5956 * _5956))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10005 = _3993;
        }
        bool _4030 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10026;
        bool _10047;
        int2 _10058;
        float3 _11404;
        if (_4030)
        {
            float _10007;
            float _10009;
            _10009 = 2.0f;
            _10007 = -1.0f;
            uint _3658[9];
            float _11835;
            float _11838;
            for (int _10006 = 0; _10006 < 9; _10009 = _11838, _10007 = _11835, _10006++)
            {
                _3658[_10006] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4004 + int2((_10006 % 3) - 1, (_10006 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3658[_10006] != 0u)
                {
                    float _11830;
                    if (_3658[_10006] == 0u)
                    {
                        _11830 = -1.0f;
                    }
                    else
                    {
                        _11830 = float((_3658[_10006] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11838 = min(_10009, _11830);
                    _11835 = max(_10007, _11830);
                }
                else
                {
                    _11838 = _10009;
                    _11835 = _10007;
                }
            }
            float _4076 = float(_10007 >= 0.0f);
            float3 _9806 = 0.0f.xxx;
            _9806.y = _4076;
            float2 _10027;
            bool _10048;
            int2 _10059;
            float3 _11405;
            if ((_10007 - _10009) > 0.0199999995529651641845703125f)
            {
                float _10015;
                int2 _10016;
                float2 _10017;
                int2 _10019;
                float2 _10025;
                _10025 = _5921;
                _10019 = _4004;
                _10017 = _5921;
                _10016 = _4004;
                _10015 = -1.0f;
                float _11843;
                int2 _11847;
                float2 _11858;
                int2 _11869;
                float2 _11902;
                float _11949;
                int _10014 = 0;
                float _11811 = 1000000000.0f;
                for (; _10014 < 9; _11811 = _11949, _10025 = _11902, _10019 = _11869, _10017 = _11858, _10016 = _11847, _10015 = _11843, _10014++)
                {
                    if (_3658[_10014] == 0u)
                    {
                        _11949 = _11811;
                        _11902 = _10025;
                        _11869 = _10019;
                        _11858 = _10017;
                        _11847 = _10016;
                        _11843 = _10015;
                        continue;
                    }
                    int2 _4111 = clamp(_4004 + int2((_10014 % 3) - 1, (_10014 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6031 = _3658[_10014] & 2147483647u;
                    uint _6063 = uint(max((int((_6031 >> 16u) & 15u) - 6), 0));
                    float2 _4117 = (float2(float((1 - (2 * int((_6031 >> 15u) & 1u))) * int(((_6031 >> uint(7)) & 127u) << _6063)), float((1 - (2 * int((_6031 >> 14u) & 1u))) * int((_6031 & 127u) << _6063))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11797;
                    if (_3658[_10014] == 0u)
                    {
                        _11797 = -1.0f;
                    }
                    else
                    {
                        _11797 = float((_3658[_10014] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4122 = _11797 - 0.100000001490116119384765625f;
                    float2 _11798;
                    if (_5943)
                    {
                        float2 _6140 = clamp((((_10005 + (_4117 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6143 = tan(_6140.x);
                        _11798 = (float2(_6143 / cbFI_DeviceToViewDepth.z, (tan(_6140.y) * sqrt(1.0f + (_6143 * _6143))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11798 = _10005 + (_4117 * cbFI_Timestep);
                    }
                    float _4129 = cbFI_Timestep - 1.0f;
                    float2 _11799;
                    if (_5943)
                    {
                        float2 _6211 = clamp((((_10005 + (_4117 * _4129)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6214 = tan(_6211.x);
                        _11799 = (float2(_6214 / cbFI_DeviceToViewDepth.z, (tan(_6211.y) * sqrt(1.0f + (_6214 * _6214))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11799 = _10005 + (_4117 * _4129);
                    }
                    bool _6247 = all(bool2(_11798.x > 0.0f.xx.x, _11798.y > 0.0f.xx.y));
                    bool _6253;
                    if (_6247)
                    {
                        _6253 = all(bool2(_11798.x < 1.0f.xx.x, _11798.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6253 = _6247;
                    }
                    float _11802;
                    if (_6253)
                    {
                        uint _6260_dummy_parameter;
                        _11802 = max((_4122 - (log(((r_depth_tm1.Load(int3(int2(floor(_11798 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6260_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11802 = 0.0f;
                    }
                    bool _6290 = all(bool2(_11799.x > 0.0f.xx.x, _11799.y > 0.0f.xx.y));
                    bool _6296;
                    if (_6290)
                    {
                        _6296 = all(bool2(_11799.x < 1.0f.xx.x, _11799.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6296 = _6290;
                    }
                    float _11803;
                    if (_6296)
                    {
                        uint _6303_dummy_parameter;
                        _11803 = _11802 + max((_4122 - (log(((r_depth_tp1.Load(int3(int2(floor(_11799 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6303_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11803 = _11802;
                    }
                    float _11844;
                    int2 _11848;
                    float2 _11859;
                    int2 _11870;
                    float2 _11903;
                    float _11950;
                    if (_11803 == 0.0f)
                    {
                        bool _4164 = _4122 > _10015;
                        bool2 _11958 = _4164.xx;
                        _11950 = _11811;
                        _11903 = float2(_11958.x ? _4117.x : _10025.x, _11958.y ? _4117.y : _10025.y);
                        _11870 = int2(_11958.x ? _4111.x : _10019.x, _11958.y ? _4111.y : _10019.y);
                        _11859 = _10017;
                        _11848 = _10016;
                        _11844 = _4164 ? _4122 : _10015;
                    }
                    else
                    {
                        bool _4173 = _11803 < _11811;
                        bool2 _11954 = _4173.xx;
                        _11950 = _4173 ? _11803 : _11811;
                        _11903 = _10025;
                        _11870 = _10019;
                        _11859 = float2(_11954.x ? _4117.x : _10017.x, _11954.y ? _4117.y : _10017.y);
                        _11848 = int2(_11954.x ? _4111.x : _10016.x, _11954.y ? _4111.y : _10016.y);
                        _11844 = _10015;
                    }
                    _11949 = _11950;
                    _11902 = _11903;
                    _11869 = _11870;
                    _11858 = _11859;
                    _11847 = _11848;
                    _11843 = _11844;
                }
                bool _4185 = _10015 < 0.0f;
                bool2 _11964 = _4185.xx;
                int2 _11967 = int2(_11964.x ? _10016.x : _10019.x, _11964.y ? _10016.y : _10019.y);
                _11405 = float3(1.0f, _4076, float(any(bool2(_11967.x != _4004.x, _11967.y != _4004.y))));
                _10059 = _11967;
                _10048 = _4185 ? false : true;
                _10027 = float2(_11964.x ? _10017.x : _10025.x, _11964.y ? _10017.y : _10025.y);
            }
            else
            {
                _11405 = _9806;
                _10059 = _4004;
                _10048 = false;
                _10027 = _5921;
            }
            _11404 = _11405;
            _10058 = _10059;
            _10047 = _10048;
            _10026 = _10027;
        }
        else
        {
            _11404 = 0.0f.xxx;
            _10058 = _4004;
            _10047 = false;
            _10026 = _5921;
        }
        float2 _10028;
        if (_5943)
        {
            float2 _6368 = clamp((((_10005 + (_10026 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6371 = tan(_6368.x);
            _10028 = (float2(_6371 / cbFI_DeviceToViewDepth.z, (tan(_6368.y) * sqrt(1.0f + (_6371 * _6371))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10028 = _10005 + (_10026 * cbFI_Timestep);
        }
        float _4208 = cbFI_Timestep - 1.0f;
        float2 _10030;
        if (_5943)
        {
            float2 _6439 = clamp((((_10005 + (_10026 * _4208)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6442 = tan(_6439.x);
            _10030 = (float2(_6442 / cbFI_DeviceToViewDepth.z, (tan(_6439.y) * sqrt(1.0f + (_6442 * _6442))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10030 = _10005 + (_10026 * _4208);
        }
        float _4213 = -cbFI_Timestep;
        float2 _10031;
        if (_5943)
        {
            float2 _6510 = clamp((((_10005 + (_5915 * _4213)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6513 = tan(_6510.x);
            _10031 = (float2(_6513 / cbFI_DeviceToViewDepth.z, (tan(_6510.y) * sqrt(1.0f + (_6513 * _6513))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10031 = _10005 + (_5915 * _4213);
        }
        float _4218 = 1.0f - cbFI_Timestep;
        float2 _10032;
        if (_5943)
        {
            float2 _6581 = clamp((((_10005 + (_5915 * _4218)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6584 = tan(_6581.x);
            _10032 = (float2(_6584 / cbFI_DeviceToViewDepth.z, (tan(_6581.y) * sqrt(1.0f + (_6584 * _6584))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10032 = _10005 + (_5915 * _4218);
        }
        float4 _6619 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10028, 0.0f);
        float3 _6620 = _6619.xyz;
        float4 _6627 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10030, 0.0f);
        float3 _6628 = _6627.xyz;
        float4 _6635 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10031, 0.0f);
        float3 _6636 = _6635.xyz;
        float4 _6643 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10032, 0.0f);
        float3 _6644 = _6643.xyz;
        float4 _6658 = exp(_5909 - max(max(max(_5909.x, _5909.y), _5909.z), _5909.w).xxxx);
        float4 _6665 = _6658 / (dot(_6658, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4237 = _4030 && (!_10047);
        bool _4246;
        if (_4237)
        {
            _4246 = (_6665.z + _6665.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4246 = _4237;
        }
        bool _4257;
        if (_4246)
        {
            _4257 = length((_10031 - _10028) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4257 = _4246;
        }
        bool _10071;
        if (_4257)
        {
            uint4 _6684 = r_warped_motion_qdata_tp1.Load(int3(_10058, 0));
            uint _6685 = _6684.x;
            bool _10074;
            if (_6685 != 0u)
            {
                float _10060;
                if (_6685 == 0u)
                {
                    _10060 = -1.0f;
                }
                else
                {
                    _10060 = float((_6685 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4267 = _10060 - 0.12000000476837158203125f;
                bool _6704 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                bool _6710;
                if (_6704)
                {
                    _6710 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                }
                else
                {
                    _6710 = _6704;
                }
                bool _4277;
                if (_6710)
                {
                    uint _6717_dummy_parameter;
                    _4277 = (log(((r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6717_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4267;
                }
                else
                {
                    _4277 = _6710;
                }
                bool _4291;
                if (!_4277)
                {
                    bool _6747 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                    bool _6753;
                    if (_6747)
                    {
                        _6753 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6753 = _6747;
                    }
                    bool _4289;
                    if (_6753)
                    {
                        uint _6760_dummy_parameter;
                        _4289 = (log(((r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6760_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4267;
                    }
                    else
                    {
                        _4289 = _6753;
                    }
                    _4291 = _4289;
                }
                else
                {
                    _4291 = _4277;
                }
                _10074 = _4291;
            }
            else
            {
                _10074 = false;
            }
            _10071 = _10074;
        }
        else
        {
            _10071 = false;
        }
        bool _4296 = _10047 || _10071;
        bool _4301;
        if (_4296)
        {
            bool _6790 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
            bool _6796;
            if (_6790)
            {
                _6796 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
            }
            else
            {
                _6796 = _6790;
            }
            _4301 = _6796;
        }
        else
        {
            _4301 = _4296;
        }
        bool _4306;
        if (_4301)
        {
            bool _6801 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
            bool _6807;
            if (_6801)
            {
                _6807 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
            }
            else
            {
                _6807 = _6801;
            }
            _4306 = _6807;
        }
        else
        {
            _4306 = _4301;
        }
        float4 _10168;
        if (_4306)
        {
            float _4309 = _6665.x;
            float _4311 = _6665.y;
            float _4312 = _4309 + _4311;
            float _4317 = _6665.z + _6665.w;
            float _10089;
            if (_4312 > 0.001000000047497451305389404296875f)
            {
                _10089 = _4309 / _4312;
            }
            else
            {
                _10089 = _4218;
            }
            _10168 = float4(_4309 + (_4317 * _10089), _4311 + (_4317 * (1.0f - _10089)), 0.0f, 0.0f);
        }
        else
        {
            _10168 = _6665;
        }
        bool _6835 = (cbFI_pad0 & 1024u) != 0u;
        bool _6811 = !_6835;
        bool _6812 = !_6811;
        bool _6829;
        if (_6812)
        {
            _6829 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10058.y * cbFI_MvDepthLaneSize.x) + _10058.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6829 = _6811;
        }
        bool _6861;
        if (_6812)
        {
            _6861 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4009.y * cbFI_FlowLaneSize.x) + _4009.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6861 = _6811;
        }
        float _4352 = float(_6861);
        bool _10181;
        float4 _10266;
        float3 _11220;
        if (_6835)
        {
            bool _4362;
            if (_6829)
            {
                _4362 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
            }
            else
            {
                _4362 = _6829;
            }
            bool _4368;
            if (_4362)
            {
                _4368 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
            }
            else
            {
                _4368 = _4362;
            }
            bool _4375;
            if (_6829)
            {
                _4375 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
            }
            else
            {
                _4375 = _6829;
            }
            bool _4381;
            if (_4375)
            {
                _4381 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
            }
            else
            {
                _4381 = _4375;
            }
            bool _4388;
            if (_6861)
            {
                _4388 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
            }
            else
            {
                _4388 = _6861;
            }
            bool _4394;
            if (_4388)
            {
                _4394 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
            }
            else
            {
                _4394 = _4388;
            }
            bool _4401;
            if (_6861)
            {
                _4401 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
            }
            else
            {
                _4401 = _6861;
            }
            bool _4407;
            if (_4401)
            {
                _4407 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
            }
            else
            {
                _4407 = _4401;
            }
            bool _4409 = !_6829;
            if (_4409)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6903;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6903);
                }
            }
            bool _4414 = !_6861;
            if (_4414)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6913;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6913);
                }
            }
            if (_6829 && _4414)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6923;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6923);
                }
            }
            if (_4409 && _6861)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6933;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6933);
                }
            }
            float _4433 = float(_4368);
            float _4435 = float(_4381);
            bool _4438 = _4394 && _4407;
            float _10123;
            if (_4438)
            {
                _10123 = 1.0f;
            }
            else
            {
                _10123 = (_4394 || _4407) ? 0.5f : 0.0f;
            }
            bool _10128;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4368)) && (!_4381))
            {
                bool _4468;
                if (_4438)
                {
                    float _10126;
                    do
                    {
                        bool _7017 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                        bool _7023;
                        if (_7017)
                        {
                            _7023 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7023 = _7017;
                        }
                        bool _6954 = !_7023;
                        bool _6961;
                        if (!_6954)
                        {
                            bool _7028 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                            bool _7034;
                            if (_7028)
                            {
                                _7034 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7034 = _7028;
                            }
                            _6961 = !_7034;
                        }
                        else
                        {
                            _6961 = _6954;
                        }
                        if (_6961)
                        {
                            _10126 = 0.0f;
                            break;
                        }
                        uint _7041_dummy_parameter;
                        uint _7057_dummy_parameter;
                        float4 _6982 = mul(float4((float2(_10031.x, 1.0f - _10031.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7041_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6984 = _6982.w;
                        if (abs(_6984) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10126 = 0.0f;
                            break;
                        }
                        float _6995 = abs(cbFI_DeviceToViewDepth.y / ((_6982.z / _6984) - cbFI_DeviceToViewDepth.x));
                        float _6998 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7057_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10126 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6995 - _6998) / max(max(_6995, _6998), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4468 = _10126 >= 0.5f;
                }
                else
                {
                    _4468 = _4438;
                }
                bool _4476;
                if (_4468)
                {
                    _4476 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4476 = _4468;
                }
                bool _10129;
                if (_4476)
                {
                    uint _7107_dummy_parameter;
                    float2 _10127;
                    do
                    {
                        float _7133 = 1.0f - _10031.y;
                        float4 _7144 = mul(float4((float2(_10031.x, _7133) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7107_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7146 = _7144.w;
                        if (!(_7146 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10127 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7159 = ((_7144.xy / _7146.xx) + 1.0f.xx) * 0.5f;
                        _10127 = float2(_7159.x - _10031.x, _7133 - _7159.y);
                        break;
                    } while(false);
                    float2 _4489 = float2(cbFI_DisplaySize);
                    _10129 = length(((_10031 + _10127) - _10032) * _4489) <= ((0.100000001490116119384765625f * length(_10127 * _4489)) + 8.0f);
                }
                else
                {
                    _10129 = _4468;
                }
                _10128 = _10129;
            }
            else
            {
                _10128 = true;
            }
            bool _4503 = !_10128;
            bool _11968 = _4503 ? false : _4407;
            bool _11969 = _4503 ? false : _4394;
            bool _10182;
            float4 _10267;
            if (!(((_4368 && _4381) && _11969) && _11968))
            {
                float4 _4525 = _10168 * float4(_4433, _4435, float(_11969), float(_11968));
                float _4527 = dot(_4525, 1.0f.xxxx);
                bool _4530 = !(_4527 > 0.0f);
                float4 _10268;
                if (!_4530)
                {
                    _10268 = _4525 / _4527.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7181;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7181);
                    }
                    _10268 = 0.0f.xxxx;
                }
                _10267 = _10268;
                _10182 = _4530;
            }
            else
            {
                _10267 = _10168;
                _10182 = false;
            }
            _11220 = float3(_4433, _4435, _10123);
            _10266 = _10267;
            _10181 = _10182;
        }
        else
        {
            _11220 = float3(float(_6829), _4352, 0.0f);
            _10266 = _10168;
            _10181 = false;
        }
        bool _4548 = !_10181;
        float4 _10364;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4548) && _6829)
        {
            float _10263;
            do
            {
                uint4 _7321 = r_warped_motion_qdata_tp1.Load(int3(_10058, 0));
                uint _7322 = _7321.x;
                if (_7322 != 0u)
                {
                    float _10262;
                    if (_7322 == 0u)
                    {
                        _10262 = -1.0f;
                    }
                    else
                    {
                        _10262 = float((_7322 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10263 = _10262;
                    break;
                }
                int _10245;
                uint _10246;
                _10246 = _7322;
                _10245 = -1;
                uint _10261;
                for (; _10245 <= 1; _10246 = _10261, _10245++)
                {
                    _10261 = _10246;
                    for (int _10259 = -1; _10259 <= 1; )
                    {
                        _10261 = max(_10261, r_warped_motion_qdata_tp1.Load(int3(clamp(_10058 + int2(_10259, _10245), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10259++;
                        continue;
                    }
                }
                if (_10246 != 0u)
                {
                    float _10258;
                    if (_10246 == 0u)
                    {
                        _10258 = -1.0f;
                    }
                    else
                    {
                        _10258 = float((_10246 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10263 = _10258;
                    break;
                }
                uint _10248;
                _10248 = 4294967295u;
                uint _11939;
                for (int _10247 = 0; _10247 < 8; _10248 = _11939, _10247++)
                {
                    int _10251 = 0;
                    for (;;)
                    {
                        if (_10251 < 5)
                        {
                            int2 _7272 = _10058 + (_1093[_10247] * _1102[_10251].xx);
                            bool _7275 = any(bool2(_7272.x < int2(0, 0).x, _7272.y < int2(0, 0).y));
                            bool _7283;
                            if (!_7275)
                            {
                                _7283 = any(bool2(_7272.x >= cbFI_MvDepthLaneSize.x, _7272.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7283 = _7275;
                            }
                            if (_7283)
                            {
                                _11939 = _10248;
                                break;
                            }
                            uint4 _7361 = r_warped_motion_qdata_tp1.Load(int3(_7272, 0));
                            uint _7362 = _7361.x;
                            if (_7362 != 0u)
                            {
                                _11939 = min(_10248, _7362);
                                break;
                            }
                            _10251++;
                            continue;
                        }
                        else
                        {
                            _11939 = _10248;
                            break;
                        }
                    }
                }
                float _10250;
                if (_10248 == 4294967295u)
                {
                    _10250 = -1.0f;
                }
                else
                {
                    float _10249;
                    if (_10248 == 0u)
                    {
                        _10249 = -1.0f;
                    }
                    else
                    {
                        _10249 = float((_10248 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10250 = _10249;
                }
                _10263 = _10250;
                break;
            } while(false);
            float _4559 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4563 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4569;
            if (_4563)
            {
                _4569 = _10266.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4569 = _4563;
            }
            bool _4574;
            if (_4569)
            {
                bool _7381 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
                bool _7387;
                if (_7381)
                {
                    _7387 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
                }
                else
                {
                    _7387 = _7381;
                }
                _4574 = _7387;
            }
            else
            {
                _4574 = _4569;
            }
            float4 _10309;
            if (_4574)
            {
                float _10284;
                if (_10263 >= 0.0f)
                {
                    _10284 = _10263 - _4559;
                }
                else
                {
                    float _10280;
                    _10280 = 2.0f;
                    float _7444;
                    for (int _10279 = 0; _10279 < 24; _10280 = _7444, _10279++)
                    {
                        float _7408 = float(_10279 & 7) * 0.785398185253143310546875f;
                        int _7410 = _10279 >> 3;
                        int _10281;
                        if (_7410 == 0)
                        {
                            _10281 = 16;
                        }
                        else
                        {
                            _10281 = (_7410 == 1) ? 48 : 96;
                        }
                        uint _7476_dummy_parameter;
                        _7444 = min(_10280, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10030 + ((cbFI_MvDepthLaneSizeRcp * float(_10281)) * float2(cos(_7408), sin(_7408))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7476_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10284 = _10280;
                }
                uint _7508_dummy_parameter;
                float4 _10310;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10030 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7508_dummy_parameter))))), 0)).x) > ((exp((_10284 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10310 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10310 = 1.0f.xxxx;
                }
                _10309 = _10310;
            }
            else
            {
                _10309 = 1.0f.xxxx;
            }
            bool _4601 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4607;
            if (_4601)
            {
                _4607 = _10266.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4607 = _4601;
            }
            bool _4612;
            if (_4607)
            {
                bool _7533 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
                bool _7539;
                if (_7533)
                {
                    _7539 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
                }
                else
                {
                    _7539 = _7533;
                }
                _4612 = _7539;
            }
            else
            {
                _4612 = _4607;
            }
            float4 _10313;
            if (_4612)
            {
                float _10304;
                if (_10263 >= 0.0f)
                {
                    _10304 = _10263 - _4559;
                }
                else
                {
                    float _10300;
                    _10300 = 2.0f;
                    float _7596;
                    for (int _10299 = 0; _10299 < 24; _10300 = _7596, _10299++)
                    {
                        float _7560 = float(_10299 & 7) * 0.785398185253143310546875f;
                        int _7562 = _10299 >> 3;
                        int _10301;
                        if (_7562 == 0)
                        {
                            _10301 = 16;
                        }
                        else
                        {
                            _10301 = (_7562 == 1) ? 48 : 96;
                        }
                        uint _7612_dummy_parameter;
                        _7596 = min(_10300, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10028 + ((cbFI_MvDepthLaneSizeRcp * float(_10301)) * float2(cos(_7560), sin(_7560))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7612_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10304 = _10300;
                }
                uint _7660_dummy_parameter;
                float4 _10314;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7660_dummy_parameter))))), 0)).x) > ((exp((_10304 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9874 = _10309;
                    _9874.x = 0.0f;
                    _10314 = _9874;
                }
                else
                {
                    _10314 = _10309;
                }
                _10313 = _10314;
            }
            else
            {
                _10313 = _10309;
            }
            float4 _10365;
            if (any(bool4(_10313.x < 1.0f.xxxx.x, _10313.y < 1.0f.xxxx.y, _10313.z < 1.0f.xxxx.z, _10313.w < 1.0f.xxxx.w)))
            {
                float4 _4642 = _10266 * _10313;
                float _4644 = dot(_4642, 1.0f.xxxx);
                float4 _10366;
                if (_4644 > 0.0f)
                {
                    _10366 = _4642 / _4644.xxxx;
                }
                else
                {
                    bool _4655 = _10313.y == 0.0f;
                    bool _4661;
                    if (_4655)
                    {
                        _4661 = _10313.x > 0.0f;
                    }
                    else
                    {
                        _4661 = _4655;
                    }
                    bool _4666;
                    if (_4661)
                    {
                        bool _7685 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
                        bool _7691;
                        if (_7685)
                        {
                            _7691 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7691 = _7685;
                        }
                        _4666 = _7691;
                    }
                    else
                    {
                        _4666 = _4661;
                    }
                    float4 _10367;
                    if (_4666)
                    {
                        _10367 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4671 = _10313.x == 0.0f;
                        bool _4677;
                        if (_4671)
                        {
                            _4677 = _10313.y > 0.0f;
                        }
                        else
                        {
                            _4677 = _4671;
                        }
                        bool _4682;
                        if (_4677)
                        {
                            bool _7696 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
                            bool _7702;
                            if (_7696)
                            {
                                _7702 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7702 = _7696;
                            }
                            _4682 = _7702;
                        }
                        else
                        {
                            _4682 = _4677;
                        }
                        bool4 _11970 = _4682.xxxx;
                        _10367 = float4(_11970.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10266.x, _11970.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10266.y, _11970.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10266.z, _11970.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10266.w);
                    }
                    _10366 = _10367;
                }
                _10365 = _10366;
            }
            else
            {
                _10365 = _10266;
            }
            _10364 = _10365;
        }
        else
        {
            _10364 = _10266;
        }
        float4 _10908;
        bool _10928;
        float3 _11042;
        if (((cbFI_pad0 & 32768u) != 0u) && _4548)
        {
            bool _4699 = _10364.x > 0.00999999977648258209228515625f;
            bool _4702 = _10364.y > 0.00999999977648258209228515625f;
            bool _4711 = (_10364.z + _10364.w) > 0.0199999995529651641845703125f;
            bool _4717;
            if (_4711)
            {
                bool _7707 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                bool _7713;
                if (_7707)
                {
                    _7713 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                }
                else
                {
                    _7713 = _7707;
                }
                _4717 = _7713;
            }
            else
            {
                _4717 = _4711;
            }
            bool _4722;
            if (_4717)
            {
                bool _7718 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                bool _7724;
                if (_7718)
                {
                    _7724 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                }
                else
                {
                    _7724 = _7718;
                }
                _4722 = _7724;
            }
            else
            {
                _4722 = _4717;
            }
            bool _4729;
            if (_4722)
            {
                float _10375;
                do
                {
                    bool _7807 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                    bool _7813;
                    if (_7807)
                    {
                        _7813 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7813 = _7807;
                    }
                    bool _7744 = !_7813;
                    bool _7751;
                    if (!_7744)
                    {
                        bool _7818 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                        bool _7824;
                        if (_7818)
                        {
                            _7824 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7824 = _7818;
                        }
                        _7751 = !_7824;
                    }
                    else
                    {
                        _7751 = _7744;
                    }
                    if (_7751)
                    {
                        _10375 = 0.0f;
                        break;
                    }
                    uint _7831_dummy_parameter;
                    uint _7847_dummy_parameter;
                    float4 _7772 = mul(float4((float2(_10031.x, 1.0f - _10031.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7831_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7774 = _7772.w;
                    if (abs(_7774) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10375 = 0.0f;
                        break;
                    }
                    float _7785 = abs(cbFI_DeviceToViewDepth.y / ((_7772.z / _7774) - cbFI_DeviceToViewDepth.x));
                    float _7788 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7847_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10375 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7785 - _7788) / max(max(_7785, _7788), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4729 = _10375 < 0.5f;
            }
            else
            {
                _4729 = _4722;
            }
            float4 _10390;
            if (_4729)
            {
                uint _7897_dummy_parameter;
                uint _7928_dummy_parameter;
                float4 _10391;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7897_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7928_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10391 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10391 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10390 = _10391;
            }
            else
            {
                _10390 = 1.0f.xxxx;
            }
            bool _4753;
            if (_6829)
            {
                bool _7957 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
                bool _7963;
                if (_7957)
                {
                    _7963 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
                }
                else
                {
                    _7963 = _7957;
                }
                _4753 = _7963;
            }
            else
            {
                _4753 = _6829;
            }
            bool _4759;
            if (_6829)
            {
                bool _7968 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
                bool _7974;
                if (_7968)
                {
                    _7974 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
                }
                else
                {
                    _7974 = _7968;
                }
                _4759 = _7974;
            }
            else
            {
                _4759 = _6829;
            }
            bool _4765;
            if (_6861)
            {
                bool _7979 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                bool _7985;
                if (_7979)
                {
                    _7985 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                }
                else
                {
                    _7985 = _7979;
                }
                _4765 = _7985;
            }
            else
            {
                _4765 = _6861;
            }
            bool _4771;
            if (_6861)
            {
                bool _7990 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                bool _7996;
                if (_7990)
                {
                    _7996 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                }
                else
                {
                    _7996 = _7990;
                }
                _4771 = _7996;
            }
            else
            {
                _4771 = _6861;
            }
            bool _4774 = _4765 != _4771;
            bool _4780;
            if (_4774)
            {
                _4780 = _4753 || _4759;
            }
            else
            {
                _4780 = _4774;
            }
            float4 _10478;
            if (_4780)
            {
                float4 _9901 = _10390;
                _9901.z = 0.0f;
                _9901.w = 0.0f;
                _10478 = _9901;
            }
            else
            {
                _10478 = _10390;
            }
            bool _4787 = _4753 && _4699;
            bool _4790 = _4759 && _4702;
            float4 _10583;
            float3 _11119;
            if (_4787 || _4790)
            {
                float _10473;
                do
                {
                    uint4 _8135 = r_warped_motion_qdata_tp1.Load(int3(_10058, 0));
                    uint _8136 = _8135.x;
                    if (_8136 != 0u)
                    {
                        float _10472;
                        if (_8136 == 0u)
                        {
                            _10472 = -1.0f;
                        }
                        else
                        {
                            _10472 = float((_8136 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10473 = _10472;
                        break;
                    }
                    int _10455;
                    uint _10456;
                    _10456 = _8136;
                    _10455 = -1;
                    uint _10471;
                    for (; _10455 <= 1; _10456 = _10471, _10455++)
                    {
                        _10471 = _10456;
                        for (int _10469 = -1; _10469 <= 1; )
                        {
                            _10471 = max(_10471, r_warped_motion_qdata_tp1.Load(int3(clamp(_10058 + int2(_10469, _10455), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10469++;
                            continue;
                        }
                    }
                    if (_10456 != 0u)
                    {
                        float _10468;
                        if (_10456 == 0u)
                        {
                            _10468 = -1.0f;
                        }
                        else
                        {
                            _10468 = float((_10456 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10473 = _10468;
                        break;
                    }
                    uint _10458;
                    _10458 = 4294967295u;
                    uint _11940;
                    for (int _10457 = 0; _10457 < 8; _10458 = _11940, _10457++)
                    {
                        int _10461 = 0;
                        for (;;)
                        {
                            if (_10461 < 5)
                            {
                                int2 _8086 = _10058 + (_1093[_10457] * _1102[_10461].xx);
                                bool _8089 = any(bool2(_8086.x < int2(0, 0).x, _8086.y < int2(0, 0).y));
                                bool _8097;
                                if (!_8089)
                                {
                                    _8097 = any(bool2(_8086.x >= cbFI_MvDepthLaneSize.x, _8086.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8097 = _8089;
                                }
                                if (_8097)
                                {
                                    _11940 = _10458;
                                    break;
                                }
                                uint4 _8175 = r_warped_motion_qdata_tp1.Load(int3(_8086, 0));
                                uint _8176 = _8175.x;
                                if (_8176 != 0u)
                                {
                                    _11940 = min(_10458, _8176);
                                    break;
                                }
                                _10461++;
                                continue;
                            }
                            else
                            {
                                _11940 = _10458;
                                break;
                            }
                        }
                    }
                    float _10460;
                    if (_10458 == 4294967295u)
                    {
                        _10460 = -1.0f;
                    }
                    else
                    {
                        float _10459;
                        if (_10458 == 0u)
                        {
                            _10459 = -1.0f;
                        }
                        else
                        {
                            _10459 = float((_10458 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10460 = _10459;
                    }
                    _10473 = _10460;
                    break;
                } while(false);
                bool _4798 = _10473 < 0.0f;
                float _10474;
                if (_4798)
                {
                    _10474 = 0.0f;
                }
                else
                {
                    _10474 = _10473 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8197_dummy_parameter;
                uint _8229_dummy_parameter;
                float4 _10511;
                if ((_4798 && _4787) && _4790)
                {
                    uint _8261_dummy_parameter;
                    float _8285 = log(((r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8261_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8293_dummy_parameter;
                    float _8317 = log(((r_depth_tp1.Load(int3(int2(floor(_10030 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8293_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10512;
                    if (_8285 > (_8317 + 0.07999999821186065673828125f))
                    {
                        float4 _9905 = _10478;
                        _9905.x = 0.0f;
                        _10512 = _9905;
                    }
                    else
                    {
                        float4 _10513;
                        if (_8317 > (_8285 + 0.07999999821186065673828125f))
                        {
                            float4 _9907 = _10478;
                            _9907.y = 0.0f;
                            _10513 = _9907;
                        }
                        else
                        {
                            _10513 = _10478;
                        }
                        _10512 = _10513;
                    }
                    _10511 = _10512;
                }
                else
                {
                    _10511 = _10478;
                }
                float _4850 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4852 = _10473 >= 0.0f;
                float _10494;
                if (_4852)
                {
                    _10494 = _10473 - _4850;
                }
                else
                {
                    float _10490;
                    if (_4787)
                    {
                        float _10489;
                        _10489 = 2.0f;
                        float _8375;
                        for (int _10488 = 0; _10488 < 24; _10489 = _8375, _10488++)
                        {
                            float _8339 = float(_10488 & 7) * 0.785398185253143310546875f;
                            int _8341 = _10488 >> 3;
                            int _10491;
                            if (_8341 == 0)
                            {
                                _10491 = 16;
                            }
                            else
                            {
                                _10491 = (_8341 == 1) ? 48 : 96;
                            }
                            uint _8391_dummy_parameter;
                            _8375 = min(_10489, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10028 + ((cbFI_MvDepthLaneSizeRcp * float(_10491)) * float2(cos(_8339), sin(_8339))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8391_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10490 = _10489;
                    }
                    else
                    {
                        _10490 = 0.0f;
                    }
                    _10494 = _10490;
                }
                float _10501;
                if (_4852)
                {
                    _10501 = _10473 - _4850;
                }
                else
                {
                    float _10497;
                    if (_4790)
                    {
                        float _10496;
                        _10496 = 2.0f;
                        float _8489;
                        for (int _10495 = 0; _10495 < 24; _10496 = _8489, _10495++)
                        {
                            float _8453 = float(_10495 & 7) * 0.785398185253143310546875f;
                            int _8455 = _10495 >> 3;
                            int _10498;
                            if (_8455 == 0)
                            {
                                _10498 = 16;
                            }
                            else
                            {
                                _10498 = (_8455 == 1) ? 48 : 96;
                            }
                            uint _8521_dummy_parameter;
                            _8489 = min(_10496, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10030 + ((cbFI_MvDepthLaneSizeRcp * float(_10498)) * float2(cos(_8453), sin(_8453))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8521_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10497 = _10496;
                    }
                    else
                    {
                        _10497 = 0.0f;
                    }
                    _10501 = _10497;
                }
                float _10502;
                if (_4787)
                {
                    uint _8553_dummy_parameter;
                    _10502 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8553_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10502 = 0.0f;
                }
                float _10503;
                if (_4790)
                {
                    uint _8573_dummy_parameter;
                    _10503 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10030 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8573_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10503 = 0.0f;
                }
                bool _4907;
                if (_4787)
                {
                    _4907 = _10502 > ((exp((_10494 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4907 = _4787;
                }
                float4 _10519;
                if (_4907)
                {
                    float4 _9909 = _10511;
                    _9909.x = 0.0f;
                    _10519 = _9909;
                }
                else
                {
                    _10519 = _10511;
                }
                bool _4919;
                if (_4790)
                {
                    _4919 = _10503 > ((exp((_10501 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4919 = _4790;
                }
                float4 _10521;
                if (_4919)
                {
                    float4 _9911 = _10519;
                    _9911.y = 0.0f;
                    _10521 = _9911;
                }
                else
                {
                    _10521 = _10519;
                }
                float4 _10584;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4852)
                {
                    bool _4939;
                    if (_4787)
                    {
                        _4939 = _10502 < ((exp((_10494 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4939 = _4787;
                    }
                    float4 _10523;
                    if (_4939)
                    {
                        float4 _9913 = _10521;
                        _9913.x = 0.0f;
                        _10523 = _9913;
                    }
                    else
                    {
                        _10523 = _10521;
                    }
                    bool _4951;
                    if (_4790)
                    {
                        _4951 = _10503 < ((exp((_10501 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4951 = _4790;
                    }
                    float4 _10585;
                    if (_4951)
                    {
                        float4 _9915 = _10523;
                        _9915.y = 0.0f;
                        _10585 = _9915;
                    }
                    else
                    {
                        _10585 = _10523;
                    }
                    _10584 = _10585;
                }
                else
                {
                    _10584 = _10521;
                }
                _11119 = float3(_10474, log(((r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8197_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10030 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8229_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10583 = _10584;
            }
            else
            {
                _11119 = float3(0.0f, 0.0f, 0.5f);
                _10583 = _10478;
            }
            bool _4962 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4711;
            bool _4968;
            if (_4962)
            {
                _4968 = _4765 || _4771;
            }
            else
            {
                _4968 = _4962;
            }
            float4 _10606;
            if (_4968)
            {
                float _10578;
                do
                {
                    uint4 _8753 = r_warped_motion_qdata_tp1.Load(int3(_10058, 0));
                    uint _8754 = _8753.x;
                    if (_8754 != 0u)
                    {
                        float _10577;
                        if (_8754 == 0u)
                        {
                            _10577 = -1.0f;
                        }
                        else
                        {
                            _10577 = float((_8754 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10578 = _10577;
                        break;
                    }
                    int _10560;
                    uint _10561;
                    _10561 = _8754;
                    _10560 = -1;
                    uint _10576;
                    for (; _10560 <= 1; _10561 = _10576, _10560++)
                    {
                        _10576 = _10561;
                        for (int _10574 = -1; _10574 <= 1; )
                        {
                            _10576 = max(_10576, r_warped_motion_qdata_tp1.Load(int3(clamp(_10058 + int2(_10574, _10560), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10574++;
                            continue;
                        }
                    }
                    if (_10561 != 0u)
                    {
                        float _10573;
                        if (_10561 == 0u)
                        {
                            _10573 = -1.0f;
                        }
                        else
                        {
                            _10573 = float((_10561 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10578 = _10573;
                        break;
                    }
                    uint _10563;
                    _10563 = 4294967295u;
                    uint _11941;
                    for (int _10562 = 0; _10562 < 8; _10563 = _11941, _10562++)
                    {
                        int _10566 = 0;
                        for (;;)
                        {
                            if (_10566 < 5)
                            {
                                int2 _8704 = _10058 + (_1093[_10562] * _1102[_10566].xx);
                                bool _8707 = any(bool2(_8704.x < int2(0, 0).x, _8704.y < int2(0, 0).y));
                                bool _8715;
                                if (!_8707)
                                {
                                    _8715 = any(bool2(_8704.x >= cbFI_MvDepthLaneSize.x, _8704.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8715 = _8707;
                                }
                                if (_8715)
                                {
                                    _11941 = _10563;
                                    break;
                                }
                                uint4 _8793 = r_warped_motion_qdata_tp1.Load(int3(_8704, 0));
                                uint _8794 = _8793.x;
                                if (_8794 != 0u)
                                {
                                    _11941 = min(_10563, _8794);
                                    break;
                                }
                                _10566++;
                                continue;
                            }
                            else
                            {
                                _11941 = _10563;
                                break;
                            }
                        }
                    }
                    float _10565;
                    if (_10563 == 4294967295u)
                    {
                        _10565 = -1.0f;
                    }
                    else
                    {
                        float _10564;
                        if (_10563 == 0u)
                        {
                            _10564 = -1.0f;
                        }
                        else
                        {
                            _10564 = float((_10563 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10565 = _10564;
                    }
                    _10578 = _10565;
                    break;
                } while(false);
                float4 _10607;
                if (_10578 >= 0.0f)
                {
                    float _8815 = (exp((_10578 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4987;
                    if (_4765)
                    {
                        uint _8822_dummy_parameter;
                        _4987 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8822_dummy_parameter))))), 0)).x) > _8815;
                    }
                    else
                    {
                        _4987 = _4765;
                    }
                    float4 _10596;
                    if (_4987)
                    {
                        float4 _9917 = _10583;
                        _9917.z = 0.0f;
                        _10596 = _9917;
                    }
                    else
                    {
                        _10596 = _10583;
                    }
                    bool _4999;
                    if (_4771)
                    {
                        uint _8842_dummy_parameter;
                        _4999 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8842_dummy_parameter))))), 0)).x) > _8815;
                    }
                    else
                    {
                        _4999 = _4771;
                    }
                    float4 _10608;
                    if (_4999)
                    {
                        float4 _9919 = _10596;
                        _9919.w = 0.0f;
                        _10608 = _9919;
                    }
                    else
                    {
                        _10608 = _10596;
                    }
                    _10607 = _10608;
                }
                else
                {
                    _10607 = _10583;
                }
                _10606 = _10607;
            }
            else
            {
                _10606 = _10583;
            }
            bool _5007 = _4753 != _4759;
            bool _5014;
            if (_5007)
            {
                _5014 = _4753 ? _4699 : _4702;
            }
            else
            {
                _5014 = _5007;
            }
            bool _5021;
            if (_5014)
            {
                _5021 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5021 = _5014;
            }
            float4 _10691;
            if (_5021)
            {
                bool2 _5026 = _4753.xx;
                float2 _5027 = float2(_5026.x ? _10028.x : _10030.x, _5026.y ? _10028.y : _10030.y);
                float _10598;
                if (_4753)
                {
                    uint _8862_dummy_parameter;
                    _10598 = r_depth_tm1.Load(int3(int2(floor(_5027 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8862_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8878_dummy_parameter;
                    _10598 = r_depth_tp1.Load(int3(int2(floor(_5027 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8878_dummy_parameter))))), 0)).x;
                }
                float4x4 _10599;
                if (_4753)
                {
                    _10599 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10599 = cbFI_MotionTP1ToTM1;
                }
                float2 _10600;
                do
                {
                    float _8905 = _5027.x;
                    float _8908 = 1.0f - _5027.y;
                    float4 _8919 = mul(float4((float2(_8905, _8908) * 2.0f) - 1.0f.xx, _10598, 1.0f), _10599);
                    float _8921 = _8919.w;
                    if (!(_8921 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10600 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8934 = ((_8919.xy / _8921.xx) + 1.0f.xx) * 0.5f;
                    _10600 = float2(_8934.x - _8905, _8908 - _8934.y);
                    break;
                } while(false);
                float2 _5057 = float2(cbFI_DisplaySize);
                float4 _10692;
                if (!(length(((_5027 + _10600) - float2(_5026.x ? _10030.x : _10028.x, _5026.y ? _10030.y : _10028.y)) * _5057) <= ((0.100000001490116119384765625f * length(_10600 * _5057)) + 8.0f)))
                {
                    float4 _10693;
                    if (_4753)
                    {
                        float4 _9929 = _10606;
                        _9929.x = 0.0f;
                        _10693 = _9929;
                    }
                    else
                    {
                        float4 _9931 = _10606;
                        _9931.y = 0.0f;
                        _10693 = _9931;
                    }
                    _10692 = _10693;
                }
                else
                {
                    _10692 = _10606;
                }
                _10691 = _10692;
            }
            else
            {
                _10691 = _10606;
            }
            float4 _5082 = _10364 * _10691;
            float _5084 = dot(_5082, 1.0f.xxxx);
            float4 _10909;
            bool _10929;
            if (_5084 > 0.0f)
            {
                _10929 = _10181;
                _10909 = _5082 / _5084.xxxx;
            }
            else
            {
                bool _5095 = any(bool4(_10691.x < 1.0f.xxxx.x, _10691.y < 1.0f.xxxx.y, _10691.z < 1.0f.xxxx.z, _10691.w < 1.0f.xxxx.w));
                if (_5095)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8956;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8956);
                    }
                }
                bool4 _11973 = _5095.xxxx;
                _10929 = _5095 ? true : _10181;
                _10909 = float4(_11973.x ? 0.0f.xxxx.x : _10364.x, _11973.y ? 0.0f.xxxx.y : _10364.y, _11973.z ? 0.0f.xxxx.z : _10364.z, _11973.w ? 0.0f.xxxx.w : _10364.w);
            }
            _11042 = _11119;
            _10928 = _10929;
            _10908 = _10909;
        }
        else
        {
            _11042 = float3(0.0f, 0.0f, 0.5f);
            _10928 = _10181;
            _10908 = _10364;
        }
        uint _5104 = (cbFI_pad0 >> 24u) & 31u;
        uint _5108 = (cbFI_pad0 >> 16u) & 255u;
        bool _5110 = _5104 != 0u;
        bool _5112 = _5108 == 12u;
        bool _5115 = _5108 == 13u;
        float4 _10925;
        if ((_5110 || _5112) || _5115)
        {
            float _10694;
            do
            {
                bool _9040 = all(bool2(_10031.x > 0.0f.xx.x, _10031.y > 0.0f.xx.y));
                bool _9046;
                if (_9040)
                {
                    _9046 = all(bool2(_10031.x < 1.0f.xx.x, _10031.y < 1.0f.xx.y));
                }
                else
                {
                    _9046 = _9040;
                }
                bool _8977 = !_9046;
                bool _8984;
                if (!_8977)
                {
                    bool _9051 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
                    bool _9057;
                    if (_9051)
                    {
                        _9057 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9057 = _9051;
                    }
                    _8984 = !_9057;
                }
                else
                {
                    _8984 = _8977;
                }
                if (_8984)
                {
                    _10694 = 0.0f;
                    break;
                }
                uint _9064_dummy_parameter;
                uint _9080_dummy_parameter;
                float4 _9005 = mul(float4((float2(_10031.x, 1.0f - _10031.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9064_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9007 = _9005.w;
                if (abs(_9007) < 9.9999999747524270787835121154785e-07f)
                {
                    _10694 = 0.0f;
                    break;
                }
                float _9018 = abs(cbFI_DeviceToViewDepth.y / ((_9005.z / _9007) - cbFI_DeviceToViewDepth.x));
                float _9021 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9080_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10694 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9018 - _9021) / max(max(_9018, _9021), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9128 = all(bool2(_10032.x > 0.0f.xx.x, _10032.y > 0.0f.xx.y));
            bool _9134;
            if (_9128)
            {
                _9134 = all(bool2(_10032.x < 1.0f.xx.x, _10032.y < 1.0f.xx.y));
            }
            else
            {
                _9134 = _9128;
            }
            float _10695;
            if (_9134)
            {
                uint _9141_dummy_parameter;
                _10695 = length((_5915 + (r_motion_tp1.Load(int3(int2(floor(_10032 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9141_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10695 = 1000000.0f;
            }
            float _10706;
            if ((_5104 & 1u) != 0u)
            {
                _10706 = _10694;
            }
            else
            {
                _10706 = 1.0f;
            }
            float _10707;
            if ((_5104 & 2u) != 0u)
            {
                _10707 = _10706 * (1.0f - smoothstep(2.0f, 8.0f, _10695));
            }
            else
            {
                _10707 = _10706;
            }
            float _10708;
            if ((_5104 & 4u) != 0u)
            {
                _10708 = _10707 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6636 - _6644) - length(_6620 - _6628))));
            }
            else
            {
                _10708 = _10707;
            }
            float _10919;
            if ((_5104 & 8u) != 0u)
            {
                _10919 = lerp(1.0f, _10708, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6620 - _6628)));
            }
            else
            {
                _10919 = _10708;
            }
            bool _5190 = (_5104 & 16u) != 0u;
            bool _5199;
            if (_5190)
            {
                _5199 = length(_10026 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5199 = _5190;
            }
            float _11975 = _5199 ? 1.0f : _10919;
            bool _5205 = _5110 && _6829;
            bool _5210;
            if (_5205)
            {
                bool _9166 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
                bool _9172;
                if (_9166)
                {
                    _9172 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
                }
                else
                {
                    _9172 = _9166;
                }
                _5210 = _9172;
            }
            else
            {
                _5210 = _5205;
            }
            bool _5215;
            if (_5210)
            {
                bool _9177 = all(bool2(_10030.x > 0.0f.xx.x, _10030.y > 0.0f.xx.y));
                bool _9183;
                if (_9177)
                {
                    _9183 = all(bool2(_10030.x < 1.0f.xx.x, _10030.y < 1.0f.xx.y));
                }
                else
                {
                    _9183 = _9177;
                }
                _5215 = _9183;
            }
            else
            {
                _5215 = _5210;
            }
            float4 _10926;
            if (_5215)
            {
                float _5221 = _10908.x + _10908.y;
                float _5230 = (_10908.z + _10908.w) * (1.0f - _11975);
                float _10922;
                if (_5221 > 9.9999997473787516355514526367188e-06f)
                {
                    _10922 = _10908.x / _5221;
                }
                else
                {
                    _10922 = _4218;
                }
                _10926 = float4(_10908.x + (_5230 * _10922), _10908.y + (_5230 * (1.0f - _10922)), _10908.zw * _11975);
            }
            else
            {
                _10926 = _10908;
            }
            _10925 = _10926;
        }
        else
        {
            _10925 = _10908;
        }
        float3 _11743;
        if (_10928)
        {
            float3 _9189 = r_current_interpolation_source.Load(int3(_3594, 0)).xyz;
            float3 _11744;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6829)
            {
                uint _9196_dummy_parameter;
                float _11033;
                _11033 = r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9196_dummy_parameter))))), 0)).x;
                float _5342;
                for (int _11032 = 0; _11032 < 24; _11033 = _5342, _11032++)
                {
                    float _5314 = float(_11032 & 7) * 0.785398185253143310546875f;
                    int _5316 = _11032 >> 3;
                    int _11794;
                    if (_5316 == 0)
                    {
                        _11794 = 16;
                    }
                    else
                    {
                        _11794 = (_5316 == 1) ? 48 : 96;
                    }
                    uint _9216_dummy_parameter;
                    _5342 = max(_11033, r_depth_tm1.Load(int3(int2(floor(clamp(_10028 + ((cbFI_MvDepthLaneSizeRcp * float(_11794)) * float2(cos(_5314), sin(_5314))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9216_dummy_parameter))))), 0)).x);
                }
                float2 _11034;
                do
                {
                    float _9238 = 1.0f - _10028.y;
                    float4 _9249 = mul(float4((float2(_10028.x, _9238) * 2.0f) - 1.0f.xx, _11033, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9251 = _9249.w;
                    if (!(_9251 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11034 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9264 = ((_9249.xy / _9251.xx) + 1.0f.xx) * 0.5f;
                    _11034 = float2(_9264.x - _10028.x, _9238 - _9264.y);
                    break;
                } while(false);
                float2 _5353 = _10028 + _11034;
                bool _9282 = all(bool2(_5353.x > 0.0f.xx.x, _5353.y > 0.0f.xx.y));
                bool _9288;
                if (_9282)
                {
                    _9288 = all(bool2(_5353.x < 1.0f.xx.x, _5353.y < 1.0f.xx.y));
                }
                else
                {
                    _9288 = _9282;
                }
                float3 _11745;
                if (_9288)
                {
                    float _5359 = abs(cbFI_DeviceToViewDepth.y / (_11033 - cbFI_DeviceToViewDepth.x));
                    uint _9308_dummy_parameter;
                    int2 _9308 = int2(spvTextureSize(r_depth_m2, uint(0), _9308_dummy_parameter));
                    float _5363 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5353 * float2(_9308))), int2(0, 0), _9308 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11750;
                    if (abs(_5363 - _5359) <= (0.20000000298023223876953125f * max(_5363, _5359)))
                    {
                        uint _9342_dummy_parameter;
                        int2 _9342 = int2(spvTextureSize(r_colour_m2, uint(0), _9342_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9365;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9365);
                        }
                        _11750 = r_colour_m2.Load(int3(clamp(int2(floor(_5353 * float2(_9342))), int2(0, 0), _9342 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9375;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9375);
                        }
                        _11750 = _9189;
                    }
                    _11745 = _11750;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9385;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9385);
                    }
                    _11745 = _9189;
                }
                _11744 = _11745;
            }
            else
            {
                _11744 = _9189;
            }
            _11743 = _11744;
        }
        else
        {
            _11743 = (((_6620 * _10925.x) + (_6628 * _10925.y)) + (_6636 * _10925.z)) + (_6644 * _10925.w);
        }
        uint _5391 = cbFI_pad0 & 255u;
        bool _11635;
        float3 _11742;
        if (_5391 != 0u)
        {
            float3 _5396 = r_present_backbuffer.Load(int3(_3594, 0)).xyz;
            float3 _5400 = r_current_interpolation_source.Load(int3(_3594, 0)).xyz;
            float3 _5404 = abs(_5396 - _5400);
            float3 _11037;
            if (_5391 == 2u)
            {
                _11037 = (abs(_5400) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11037 = 0.000244140625f.xxx;
            }
            bool _5420 = any(bool3(_5404.x > _11037.x, _5404.y > _11037.y, _5404.z > _11037.z));
            bool3 _11976 = _5420.xxx;
            _11742 = float3(_11976.x ? _5396.x : _11743.x, _11976.y ? _5396.y : _11743.y, _11976.z ? _5396.z : _11743.z);
            _11635 = _5420;
        }
        else
        {
            _11742 = _11743;
            _11635 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9400;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9400);
        }
        float3 _11725;
        if (_5108 == 1u)
        {
            _11725 = lerp(_6620, _6628, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11726;
            if (_5108 == 2u)
            {
                _11726 = lerp(_6636, _6644, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11727;
                if (_5108 == 3u)
                {
                    _11727 = float(_11635).xxx;
                }
                else
                {
                    float3 _11728;
                    if (_5108 == 4u)
                    {
                        _11728 = float3(((_10026 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11729;
                        if (_5108 == 5u)
                        {
                            _11729 = float3(((_5915 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11730;
                            if (_5108 == 6u)
                            {
                                _11730 = float3(_10925.xy, _10925.z + _10925.w);
                            }
                            else
                            {
                                float3 _11731;
                                if (_5108 == 7u)
                                {
                                    _11731 = r_current_interpolation_source.Load(int3(_3594, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11732;
                                    if (_5108 == 8u)
                                    {
                                        _11732 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3993, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11733;
                                        if (_5112)
                                        {
                                            uint _9422_dummy_parameter;
                                            uint _9454_dummy_parameter;
                                            _11733 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3993 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9422_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9454_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11734;
                                            if (_5115)
                                            {
                                                _11734 = _6636;
                                            }
                                            else
                                            {
                                                float3 _11735;
                                                if (_5108 == 20u)
                                                {
                                                    _11735 = _6620;
                                                }
                                                else
                                                {
                                                    float3 _11736;
                                                    if (_5108 == 21u)
                                                    {
                                                        _11736 = _6628;
                                                    }
                                                    else
                                                    {
                                                        float3 _11737;
                                                        if (_5108 == 22u)
                                                        {
                                                            _11737 = _6644;
                                                        }
                                                        else
                                                        {
                                                            float3 _11738;
                                                            if (_5108 == 18u)
                                                            {
                                                                _11738 = _11404;
                                                            }
                                                            else
                                                            {
                                                                float3 _11739;
                                                                if (_5108 == 19u)
                                                                {
                                                                    _11739 = _11220;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11978 = (_5108 == 23u).xxx;
                                                                    _11739 = float3(_11978.x ? _11042.x : _11742.x, _11978.y ? _11042.y : _11742.y, _11978.z ? _11042.z : _11742.z);
                                                                }
                                                                _11738 = _11739;
                                                            }
                                                            _11737 = _11738;
                                                        }
                                                        _11736 = _11737;
                                                    }
                                                    _11735 = _11736;
                                                }
                                                _11734 = _11735;
                                            }
                                            _11733 = _11734;
                                        }
                                        _11732 = _11733;
                                    }
                                    _11731 = _11732;
                                }
                                _11730 = _11731;
                            }
                            _11729 = _11730;
                        }
                        _11728 = _11729;
                    }
                    _11727 = _11728;
                }
                _11726 = _11727;
            }
            _11725 = _11726;
        }
        float3 _11724;
        if ((_5108 >= 9u) && (_5108 <= 11u))
        {
            uint _5584 = 64u + uint((_10058.y * cbFI_MvDepthLaneSize.x) + _10058.x);
            uint _5588 = rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) & 15u;
            float3 _11755;
            if (_5108 == 10u)
            {
                float3 _11723;
                if ((rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) & 32u) != 0u)
                {
                    _11723 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11722;
                    if ((rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) & 16u) != 0u)
                    {
                        _11722 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5609 = ((rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) & 64u) != 0u).xxx;
                        _11722 = float3(_5609.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5609.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5609.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11723 = _11722;
                }
                _11755 = _11723;
            }
            else
            {
                float3 _11756;
                if (_5108 == 11u)
                {
                    uint _5622 = (rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) >> 8u) & 15u;
                    uint _5625 = (rw_nfru_diagnostics.Load<uint>(_5584 * 4 + 0) >> 12u) & 15u;
                    float3 _11715;
                    if ((_5588 == 2u) || (_5588 == 3u))
                    {
                        _11715 = _3290[_5588];
                    }
                    else
                    {
                        bool _5637 = _5622 == 3u;
                        bool _5639 = _5625 == 3u;
                        float3 _11716;
                        if (_5637 && _5639)
                        {
                            _11716 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11717;
                            if (_5637)
                            {
                                _11717 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11718;
                                if (_5639)
                                {
                                    _11718 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11719;
                                    if ((_5622 == 4u) || (_5625 == 4u))
                                    {
                                        _11719 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11720;
                                        if ((_5622 == 1u) || (_5625 == 1u))
                                        {
                                            _11720 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11980 = (_5588 == 1u).xxx;
                                            _11720 = float3(_11980.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11980.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11980.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11719 = _11720;
                                    }
                                    _11718 = _11719;
                                }
                                _11717 = _11718;
                            }
                            _11716 = _11717;
                        }
                        _11715 = _11716;
                    }
                    _11756 = _11715;
                }
                else
                {
                    _11756 = _3290[min(_5588, 7u)];
                }
                _11755 = _11756;
            }
            _11724 = _11755;
        }
        else
        {
            _11724 = _11725;
        }
        float4 _11759;
        if ((_5108 >= 14u) && (_5108 <= 16u))
        {
            float2 _11757;
            if (_5108 == 14u)
            {
                uint _5695_dummy_parameter;
                uint _5701_dummy_parameter;
                _11757 = r_flow_tm1.Load(int3(clamp(int2(floor(_3993 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5695_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5701_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11758;
                if (_5108 == 16u)
                {
                    uint _9505 = r_warped_flow_qdata_tm1.Load(int3(_4009, 0)).x & 2147483647u;
                    uint _9537 = uint(max((int((_9505 >> 16u) & 15u) - 6), 0));
                    _11758 = ((float2(float((1 - (2 * int((_9505 >> 15u) & 1u))) * int(((_9505 >> uint(7)) & 127u) << _9537)), float((1 - (2 * int((_9505 >> 14u) & 1u))) * int((_9505 & 127u) << _9537))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11758 = _5915 * float2(cbFI_DisplaySize);
                }
                _11757 = _11758;
            }
            uint2 _5734 = uint2(clamp(round(_11757 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5736 = _5734.x;
            uint _5743 = _5734.y;
            _11759 = float4(float(_5736 & 255u), float((_5736 >> 8u) | ((_5743 & 15u) << 4u)), float(_5743 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11760;
            if (_5108 == 17u)
            {
                _11760 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4009, 0)).x != 0u), _4352, 0.0f, 1.0f);
            }
            else
            {
                _11760 = float4(_11724, 1.0f);
            }
            _11759 = _11760;
        }
        rw_output[_3594] = _11759.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5787 = ((uint(_3594.y) * uint(cbFI_DisplaySize.x)) + uint(_3594.x)) * 6u;
            uint _9583 = spvPackHalf2x16(clamp(_6619.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5787 * 4 + 0, (((_9583 & 32767u) >> 4u) | ((((_9583 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6619.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9618 = spvPackHalf2x16(clamp(_6627.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5787 + 1u) * 4 + 0, (((_9618 & 32767u) >> 4u) | ((((_9618 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6627.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9653 = spvPackHalf2x16(clamp(_6635.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5787 + 2u) * 4 + 0, (((_9653 & 32767u) >> 4u) | ((((_9653 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6635.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9688 = spvPackHalf2x16(clamp(_6643.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5787 + 3u) * 4 + 0, (((_9688 & 32767u) >> 4u) | ((((_9688 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6643.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9715 = r_current_interpolation_source.Load(int3(_3594, 0));
            uint _9729 = spvPackHalf2x16(clamp(_9715.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5787 + 4u) * 4 + 0, (((_9729 & 32767u) >> 4u) | ((((_9729 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9715.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11793;
            if (_11635 || (_5108 != 0u))
            {
                _11793 = 4294967295u;
            }
            else
            {
                uint _9764 = spvPackHalf2x16(clamp(_11759.xy, 0.0f.xx, 65000.0f.xx));
                _11793 = (((_9764 & 32767u) >> 4u) | ((((_9764 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11759.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5787 + 5u) * 4 + 0, _11793);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3594] = float4(r_current_interpolation_source.Load(int3(_3594, 0)).xyz, 1.0f).xyz;
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
