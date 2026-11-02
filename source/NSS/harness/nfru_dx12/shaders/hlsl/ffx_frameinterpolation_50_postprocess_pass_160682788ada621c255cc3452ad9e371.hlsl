static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3081[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3368 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3368.x >= cbFI_DisplaySize.x, _3368.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3368] = float4(r_present_backbuffer.Load(int3(_3368, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3730 = (float2(_3368) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3741 = int2(floor(_3730 * float2(cbFI_MvDepthLaneSize)));
        int2 _3746 = int2(floor(_3730 * float2(cbFI_FlowLaneSize)));
        float4 _5462 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3730 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5468 = r_warped_filled_flow_tm1.Load(int3(_3746, 0)).xy;
        float2 _5474 = r_warped_filled_motion_tp1.Load(int3(_3741, 0)).xy;
        bool _5496 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9014;
        if (_5496)
        {
            float _5509 = ((2.0f * _3730.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9014 = float2(atan(_5509) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3730.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5509 * _5509))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9014 = _3730;
        }
        bool _3767 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9035;
        bool _9056;
        int2 _9067;
        float3 _10119;
        if (_3767)
        {
            float _9016;
            float _9018;
            _9018 = 2.0f;
            _9016 = -1.0f;
            uint _3430[9];
            float _10510;
            float _10513;
            for (int _9015 = 0; _9015 < 9; _9018 = _10513, _9016 = _10510, _9015++)
            {
                _3430[_9015] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3741 + int2((_9015 % 3) - 1, (_9015 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3430[_9015] != 0u)
                {
                    float _10505;
                    if (_3430[_9015] == 0u)
                    {
                        _10505 = -1.0f;
                    }
                    else
                    {
                        _10505 = float((_3430[_9015] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10513 = min(_9018, _10505);
                    _10510 = max(_9016, _10505);
                }
                else
                {
                    _10513 = _9018;
                    _10510 = _9016;
                }
            }
            float _3813 = float(_9016 >= 0.0f);
            float3 _8825 = 0.0f.xxx;
            _8825.y = _3813;
            float2 _9036;
            bool _9057;
            int2 _9068;
            float3 _10120;
            if ((_9016 - _9018) > 0.0199999995529651641845703125f)
            {
                float _9024;
                int2 _9025;
                float2 _9026;
                int2 _9028;
                float2 _9034;
                _9034 = _5474;
                _9028 = _3741;
                _9026 = _5474;
                _9025 = _3741;
                _9024 = -1.0f;
                float _10518;
                int2 _10522;
                float2 _10533;
                int2 _10544;
                float2 _10577;
                float _10623;
                int _9023 = 0;
                float _10486 = 1000000000.0f;
                for (; _9023 < 9; _10486 = _10623, _9034 = _10577, _9028 = _10544, _9026 = _10533, _9025 = _10522, _9024 = _10518, _9023++)
                {
                    if (_3430[_9023] == 0u)
                    {
                        _10623 = _10486;
                        _10577 = _9034;
                        _10544 = _9028;
                        _10533 = _9026;
                        _10522 = _9025;
                        _10518 = _9024;
                        continue;
                    }
                    int2 _3848 = clamp(_3741 + int2((_9023 % 3) - 1, (_9023 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5584 = _3430[_9023] & 2147483647u;
                    uint _5616 = uint(max((int((_5584 >> 16u) & 15u) - 6), 0));
                    float2 _3854 = (float2(float((1 - (2 * int((_5584 >> 15u) & 1u))) * int(((_5584 >> uint(7)) & 127u) << _5616)), float((1 - (2 * int((_5584 >> 14u) & 1u))) * int((_5584 & 127u) << _5616))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10472;
                    if (_3430[_9023] == 0u)
                    {
                        _10472 = -1.0f;
                    }
                    else
                    {
                        _10472 = float((_3430[_9023] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3859 = _10472 - 0.100000001490116119384765625f;
                    float2 _10473;
                    if (_5496)
                    {
                        float2 _5693 = clamp((((_9014 + (_3854 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5696 = tan(_5693.x);
                        _10473 = (float2(_5696 / cbFI_DeviceToViewDepth.z, (tan(_5693.y) * sqrt(1.0f + (_5696 * _5696))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10473 = _9014 + (_3854 * cbFI_Timestep);
                    }
                    float _3866 = cbFI_Timestep - 1.0f;
                    float2 _10474;
                    if (_5496)
                    {
                        float2 _5764 = clamp((((_9014 + (_3854 * _3866)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5767 = tan(_5764.x);
                        _10474 = (float2(_5767 / cbFI_DeviceToViewDepth.z, (tan(_5764.y) * sqrt(1.0f + (_5767 * _5767))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10474 = _9014 + (_3854 * _3866);
                    }
                    bool _5800 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                    bool _5806;
                    if (_5800)
                    {
                        _5806 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5806 = _5800;
                    }
                    float _10477;
                    if (_5806)
                    {
                        uint _5813_dummy_parameter;
                        _10477 = max((_3859 - (log((r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5813_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10477 = 0.0f;
                    }
                    bool _5843 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                    bool _5849;
                    if (_5843)
                    {
                        _5849 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5849 = _5843;
                    }
                    float _10478;
                    if (_5849)
                    {
                        uint _5856_dummy_parameter;
                        _10478 = _10477 + max((_3859 - (log((r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5856_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10478 = _10477;
                    }
                    float _10519;
                    int2 _10523;
                    float2 _10534;
                    int2 _10545;
                    float2 _10578;
                    float _10624;
                    if (_10478 == 0.0f)
                    {
                        bool _3901 = _3859 > _9024;
                        bool2 _10632 = _3901.xx;
                        _10624 = _10486;
                        _10578 = float2(_10632.x ? _3854.x : _9034.x, _10632.y ? _3854.y : _9034.y);
                        _10545 = int2(_10632.x ? _3848.x : _9028.x, _10632.y ? _3848.y : _9028.y);
                        _10534 = _9026;
                        _10523 = _9025;
                        _10519 = _3901 ? _3859 : _9024;
                    }
                    else
                    {
                        bool _3910 = _10478 < _10486;
                        bool2 _10628 = _3910.xx;
                        _10624 = _3910 ? _10478 : _10486;
                        _10578 = _9034;
                        _10545 = _9028;
                        _10534 = float2(_10628.x ? _3854.x : _9026.x, _10628.y ? _3854.y : _9026.y);
                        _10523 = int2(_10628.x ? _3848.x : _9025.x, _10628.y ? _3848.y : _9025.y);
                        _10519 = _9024;
                    }
                    _10623 = _10624;
                    _10577 = _10578;
                    _10544 = _10545;
                    _10533 = _10534;
                    _10522 = _10523;
                    _10518 = _10519;
                }
                bool _3922 = _9024 < 0.0f;
                bool2 _10638 = _3922.xx;
                int2 _10641 = int2(_10638.x ? _9025.x : _9028.x, _10638.y ? _9025.y : _9028.y);
                _10120 = float3(1.0f, _3813, float(any(bool2(_10641.x != _3741.x, _10641.y != _3741.y))));
                _9068 = _10641;
                _9057 = _3922 ? false : true;
                _9036 = float2(_10638.x ? _9026.x : _9034.x, _10638.y ? _9026.y : _9034.y);
            }
            else
            {
                _10120 = _8825;
                _9068 = _3741;
                _9057 = false;
                _9036 = _5474;
            }
            _10119 = _10120;
            _9067 = _9068;
            _9056 = _9057;
            _9035 = _9036;
        }
        else
        {
            _10119 = 0.0f.xxx;
            _9067 = _3741;
            _9056 = false;
            _9035 = _5474;
        }
        float2 _9037;
        if (_5496)
        {
            float2 _5921 = clamp((((_9014 + (_9035 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5924 = tan(_5921.x);
            _9037 = (float2(_5924 / cbFI_DeviceToViewDepth.z, (tan(_5921.y) * sqrt(1.0f + (_5924 * _5924))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9037 = _9014 + (_9035 * cbFI_Timestep);
        }
        float _3945 = cbFI_Timestep - 1.0f;
        float2 _9039;
        if (_5496)
        {
            float2 _5992 = clamp((((_9014 + (_9035 * _3945)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5995 = tan(_5992.x);
            _9039 = (float2(_5995 / cbFI_DeviceToViewDepth.z, (tan(_5992.y) * sqrt(1.0f + (_5995 * _5995))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9039 = _9014 + (_9035 * _3945);
        }
        float _3950 = -cbFI_Timestep;
        float2 _9040;
        if (_5496)
        {
            float2 _6063 = clamp((((_9014 + (_5468 * _3950)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6066 = tan(_6063.x);
            _9040 = (float2(_6066 / cbFI_DeviceToViewDepth.z, (tan(_6063.y) * sqrt(1.0f + (_6066 * _6066))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9040 = _9014 + (_5468 * _3950);
        }
        float _3955 = 1.0f - cbFI_Timestep;
        float2 _9041;
        if (_5496)
        {
            float2 _6134 = clamp((((_9014 + (_5468 * _3955)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6137 = tan(_6134.x);
            _9041 = (float2(_6137 / cbFI_DeviceToViewDepth.z, (tan(_6134.y) * sqrt(1.0f + (_6137 * _6137))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9041 = _9014 + (_5468 * _3955);
        }
        float4 _6172 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9037, 0.0f);
        float3 _6173 = _6172.xyz;
        float4 _6180 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9039, 0.0f);
        float3 _6181 = _6180.xyz;
        float4 _6188 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9040, 0.0f);
        float3 _6189 = _6188.xyz;
        float4 _6196 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9041, 0.0f);
        float3 _6197 = _6196.xyz;
        float4 _6211 = exp(_5462 - max(max(max(_5462.x, _5462.y), _5462.z), _5462.w).xxxx);
        float4 _6218 = _6211 / (dot(_6211, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3974 = _3767 && (!_9056);
        bool _3983;
        if (_3974)
        {
            _3983 = (_6218.z + _6218.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3983 = _3974;
        }
        bool _3994;
        if (_3983)
        {
            _3994 = length((_9040 - _9037) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3994 = _3983;
        }
        bool _9080;
        if (_3994)
        {
            uint4 _6237 = r_warped_motion_qdata_tp1.Load(int3(_9067, 0));
            uint _6238 = _6237.x;
            bool _9083;
            if (_6238 != 0u)
            {
                float _9069;
                if (_6238 == 0u)
                {
                    _9069 = -1.0f;
                }
                else
                {
                    _9069 = float((_6238 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4004 = _9069 - 0.12000000476837158203125f;
                bool _6257 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                bool _6263;
                if (_6257)
                {
                    _6263 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                }
                else
                {
                    _6263 = _6257;
                }
                bool _4014;
                if (_6263)
                {
                    uint _6270_dummy_parameter;
                    _4014 = (log((r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6270_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4004;
                }
                else
                {
                    _4014 = _6263;
                }
                bool _4028;
                if (!_4014)
                {
                    bool _6300 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                    bool _6306;
                    if (_6300)
                    {
                        _6306 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6306 = _6300;
                    }
                    bool _4026;
                    if (_6306)
                    {
                        uint _6313_dummy_parameter;
                        _4026 = (log((r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6313_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4004;
                    }
                    else
                    {
                        _4026 = _6306;
                    }
                    _4028 = _4026;
                }
                else
                {
                    _4028 = _4014;
                }
                _9083 = _4028;
            }
            else
            {
                _9083 = false;
            }
            _9080 = _9083;
        }
        else
        {
            _9080 = false;
        }
        bool _4033 = _9056 || _9080;
        bool _4038;
        if (_4033)
        {
            bool _6343 = all(bool2(_9037.x > 0.0f.xx.x, _9037.y > 0.0f.xx.y));
            bool _6349;
            if (_6343)
            {
                _6349 = all(bool2(_9037.x < 1.0f.xx.x, _9037.y < 1.0f.xx.y));
            }
            else
            {
                _6349 = _6343;
            }
            _4038 = _6349;
        }
        else
        {
            _4038 = _4033;
        }
        bool _4043;
        if (_4038)
        {
            bool _6354 = all(bool2(_9039.x > 0.0f.xx.x, _9039.y > 0.0f.xx.y));
            bool _6360;
            if (_6354)
            {
                _6360 = all(bool2(_9039.x < 1.0f.xx.x, _9039.y < 1.0f.xx.y));
            }
            else
            {
                _6360 = _6354;
            }
            _4043 = _6360;
        }
        else
        {
            _4043 = _4038;
        }
        float4 _9174;
        if (_4043)
        {
            float _4046 = _6218.x;
            float _4048 = _6218.y;
            float _4049 = _4046 + _4048;
            float _4054 = _6218.z + _6218.w;
            float _9098;
            if (_4049 > 0.001000000047497451305389404296875f)
            {
                _9098 = _4046 / _4049;
            }
            else
            {
                _9098 = _3955;
            }
            _9174 = float4(_4046 + (_4054 * _9098), _4048 + (_4054 * (1.0f - _9098)), 0.0f, 0.0f);
        }
        else
        {
            _9174 = _6218;
        }
        bool _6388 = (cbFI_pad0 & 1024u) != 0u;
        bool _6364 = !_6388;
        bool _6365 = !_6364;
        bool _6382;
        if (_6365)
        {
            _6382 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9067.y * cbFI_MvDepthLaneSize.x) + _9067.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6382 = _6364;
        }
        bool _6414;
        if (_6365)
        {
            _6414 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3746.y * cbFI_FlowLaneSize.x) + _3746.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6414 = _6364;
        }
        float _4089 = float(_6414);
        bool _9186;
        float4 _9216;
        float3 _9975;
        if (_6388)
        {
            bool _4099;
            if (_6382)
            {
                _4099 = all(bool2(_9037.x > 0.0f.xx.x, _9037.y > 0.0f.xx.y));
            }
            else
            {
                _4099 = _6382;
            }
            bool _4105;
            if (_4099)
            {
                _4105 = all(bool2(_9037.x < 1.0f.xx.x, _9037.y < 1.0f.xx.y));
            }
            else
            {
                _4105 = _4099;
            }
            bool _4112;
            if (_6382)
            {
                _4112 = all(bool2(_9039.x > 0.0f.xx.x, _9039.y > 0.0f.xx.y));
            }
            else
            {
                _4112 = _6382;
            }
            bool _4118;
            if (_4112)
            {
                _4118 = all(bool2(_9039.x < 1.0f.xx.x, _9039.y < 1.0f.xx.y));
            }
            else
            {
                _4118 = _4112;
            }
            bool _4125;
            if (_6414)
            {
                _4125 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
            }
            else
            {
                _4125 = _6414;
            }
            bool _4131;
            if (_4125)
            {
                _4131 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
            }
            else
            {
                _4131 = _4125;
            }
            bool _4138;
            if (_6414)
            {
                _4138 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
            }
            else
            {
                _4138 = _6414;
            }
            bool _4144;
            if (_4138)
            {
                _4144 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
            }
            else
            {
                _4144 = _4138;
            }
            bool _4146 = !_6382;
            if (_4146)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6456;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6456);
                }
            }
            bool _4151 = !_6414;
            if (_4151)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6466;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6466);
                }
            }
            if (_6382 && _4151)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6476;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6476);
                }
            }
            if (_4146 && _6414)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6486;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6486);
                }
            }
            float _4170 = float(_4105);
            float _4172 = float(_4118);
            bool _4175 = _4131 && _4144;
            float _9132;
            if (_4175)
            {
                _9132 = 1.0f;
            }
            else
            {
                _9132 = (_4131 || _4144) ? 0.5f : 0.0f;
            }
            bool _9137;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4105)) && (!_4118))
            {
                bool _4205;
                if (_4175)
                {
                    float _9135;
                    do
                    {
                        bool _6570 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                        bool _6576;
                        if (_6570)
                        {
                            _6576 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6576 = _6570;
                        }
                        bool _6507 = !_6576;
                        bool _6514;
                        if (!_6507)
                        {
                            bool _6581 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                            bool _6587;
                            if (_6581)
                            {
                                _6587 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6587 = _6581;
                            }
                            _6514 = !_6587;
                        }
                        else
                        {
                            _6514 = _6507;
                        }
                        if (_6514)
                        {
                            _9135 = 0.0f;
                            break;
                        }
                        uint _6594_dummy_parameter;
                        uint _6610_dummy_parameter;
                        float4 _6535 = mul(float4((float2(_9040.x, 1.0f - _9040.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6594_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6537 = _6535.w;
                        if (abs(_6537) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9135 = 0.0f;
                            break;
                        }
                        float _6548 = abs(cbFI_DeviceToViewDepth.y / ((_6535.z / _6537) - cbFI_DeviceToViewDepth.x));
                        float _6551 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6610_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9135 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6548 - _6551) / max(max(_6548, _6551), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4205 = _9135 >= 0.5f;
                }
                else
                {
                    _4205 = _4175;
                }
                bool _9138;
                if (_4205)
                {
                    uint _6660_dummy_parameter;
                    float2 _9136;
                    do
                    {
                        float _6686 = 1.0f - _9040.y;
                        float4 _6697 = mul(float4((float2(_9040.x, _6686) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6660_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6699 = _6697.w;
                        if (!(_6699 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9136 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6712 = ((_6697.xy / _6699.xx) + 1.0f.xx) * 0.5f;
                        _9136 = float2(_6712.x - _9040.x, _6686 - _6712.y);
                        break;
                    } while(false);
                    float2 _4219 = float2(cbFI_DisplaySize);
                    _9138 = length(((_9040 + _9136) - _9041) * _4219) <= ((0.100000001490116119384765625f * length(_9136 * _4219)) + 8.0f);
                }
                else
                {
                    _9138 = _4205;
                }
                _9137 = _9138;
            }
            else
            {
                _9137 = true;
            }
            bool _4233 = !_9137;
            bool _10642 = _4233 ? false : _4144;
            bool _10643 = _4233 ? false : _4131;
            bool _9187;
            float4 _9217;
            if (!(((_4105 && _4118) && _10643) && _10642))
            {
                float4 _4255 = _9174 * float4(_4170, _4172, float(_10643), float(_10642));
                float _4257 = dot(_4255, 1.0f.xxxx);
                bool _4260 = !(_4257 > 0.0f);
                float4 _9218;
                if (!_4260)
                {
                    _9218 = _4255 / _4257.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6734;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6734);
                    }
                    _9218 = 0.0f.xxxx;
                }
                _9217 = _9218;
                _9187 = _4260;
            }
            else
            {
                _9217 = _9174;
                _9187 = false;
            }
            _9975 = float3(_4170, _4172, _9132);
            _9216 = _9217;
            _9186 = _9187;
        }
        else
        {
            _9975 = float3(float(_6382), _4089, 0.0f);
            _9216 = _9174;
            _9186 = false;
        }
        float4 _9705;
        bool _9725;
        float3 _9838;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9186))
        {
            bool _4283 = _9216.x > 0.00999999977648258209228515625f;
            bool _4286 = _9216.y > 0.00999999977648258209228515625f;
            bool _4295 = (_9216.z + _9216.w) > 0.0199999995529651641845703125f;
            bool _4301;
            if (_4295)
            {
                bool _6740 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                bool _6746;
                if (_6740)
                {
                    _6746 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                }
                else
                {
                    _6746 = _6740;
                }
                _4301 = _6746;
            }
            else
            {
                _4301 = _4295;
            }
            bool _4306;
            if (_4301)
            {
                bool _6751 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                bool _6757;
                if (_6751)
                {
                    _6757 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                }
                else
                {
                    _6757 = _6751;
                }
                _4306 = _6757;
            }
            else
            {
                _4306 = _4301;
            }
            bool _4313;
            if (_4306)
            {
                float _9220;
                do
                {
                    bool _6840 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                    bool _6846;
                    if (_6840)
                    {
                        _6846 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6846 = _6840;
                    }
                    bool _6777 = !_6846;
                    bool _6784;
                    if (!_6777)
                    {
                        bool _6851 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                        bool _6857;
                        if (_6851)
                        {
                            _6857 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6857 = _6851;
                        }
                        _6784 = !_6857;
                    }
                    else
                    {
                        _6784 = _6777;
                    }
                    if (_6784)
                    {
                        _9220 = 0.0f;
                        break;
                    }
                    uint _6864_dummy_parameter;
                    uint _6880_dummy_parameter;
                    float4 _6805 = mul(float4((float2(_9040.x, 1.0f - _9040.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6864_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6807 = _6805.w;
                    if (abs(_6807) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9220 = 0.0f;
                        break;
                    }
                    float _6818 = abs(cbFI_DeviceToViewDepth.y / ((_6805.z / _6807) - cbFI_DeviceToViewDepth.x));
                    float _6821 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6880_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9220 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6818 - _6821) / max(max(_6818, _6821), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4313 = _9220 < 0.5f;
            }
            else
            {
                _4313 = _4306;
            }
            float4 _9235;
            if (_4313)
            {
                uint _6930_dummy_parameter;
                uint _6961_dummy_parameter;
                float4 _9236;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6930_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6961_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9236 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9236 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9235 = _9236;
            }
            else
            {
                _9235 = 1.0f.xxxx;
            }
            bool _4337;
            if (_6382)
            {
                bool _6990 = all(bool2(_9037.x > 0.0f.xx.x, _9037.y > 0.0f.xx.y));
                bool _6996;
                if (_6990)
                {
                    _6996 = all(bool2(_9037.x < 1.0f.xx.x, _9037.y < 1.0f.xx.y));
                }
                else
                {
                    _6996 = _6990;
                }
                _4337 = _6996;
            }
            else
            {
                _4337 = _6382;
            }
            bool _4343;
            if (_6382)
            {
                bool _7001 = all(bool2(_9039.x > 0.0f.xx.x, _9039.y > 0.0f.xx.y));
                bool _7007;
                if (_7001)
                {
                    _7007 = all(bool2(_9039.x < 1.0f.xx.x, _9039.y < 1.0f.xx.y));
                }
                else
                {
                    _7007 = _7001;
                }
                _4343 = _7007;
            }
            else
            {
                _4343 = _6382;
            }
            bool _4349;
            if (_6414)
            {
                bool _7012 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                bool _7018;
                if (_7012)
                {
                    _7018 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                }
                else
                {
                    _7018 = _7012;
                }
                _4349 = _7018;
            }
            else
            {
                _4349 = _6414;
            }
            bool _4355;
            if (_6414)
            {
                bool _7023 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                bool _7029;
                if (_7023)
                {
                    _7029 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                }
                else
                {
                    _7029 = _7023;
                }
                _4355 = _7029;
            }
            else
            {
                _4355 = _6414;
            }
            bool _4358 = _4349 != _4355;
            bool _4364;
            if (_4358)
            {
                _4364 = _4337 || _4343;
            }
            else
            {
                _4364 = _4358;
            }
            float4 _9317;
            if (_4364)
            {
                float4 _8910 = _9235;
                _8910.z = 0.0f;
                _8910.w = 0.0f;
                _9317 = _8910;
            }
            else
            {
                _9317 = _9235;
            }
            bool _4371 = _4337 && _4283;
            bool _4374 = _4343 && _4286;
            float4 _9422;
            float3 _9875;
            if (_4371 || _4374)
            {
                float _9312;
                do
                {
                    uint4 _7168 = r_warped_motion_qdata_tp1.Load(int3(_9067, 0));
                    uint _7169 = _7168.x;
                    if (_7169 != 0u)
                    {
                        float _9311;
                        if (_7169 == 0u)
                        {
                            _9311 = -1.0f;
                        }
                        else
                        {
                            _9311 = float((_7169 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9312 = _9311;
                        break;
                    }
                    int _9294;
                    uint _9295;
                    _9295 = _7169;
                    _9294 = -1;
                    uint _9310;
                    for (; _9294 <= 1; _9295 = _9310, _9294++)
                    {
                        _9310 = _9295;
                        for (int _9308 = -1; _9308 <= 1; )
                        {
                            _9310 = max(_9310, r_warped_motion_qdata_tp1.Load(int3(clamp(_9067 + int2(_9308, _9294), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9308++;
                            continue;
                        }
                    }
                    if (_9295 != 0u)
                    {
                        float _9307;
                        if (_9295 == 0u)
                        {
                            _9307 = -1.0f;
                        }
                        else
                        {
                            _9307 = float((_9295 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9312 = _9307;
                        break;
                    }
                    uint _9297;
                    _9297 = 4294967295u;
                    uint _10614;
                    for (int _9296 = 0; _9296 < 8; _9297 = _10614, _9296++)
                    {
                        int _9300 = 0;
                        for (;;)
                        {
                            if (_9300 < 5)
                            {
                                int2 _7119 = _9067 + (_1085[_9296] * _1094[_9300].xx);
                                bool _7122 = any(bool2(_7119.x < int2(0, 0).x, _7119.y < int2(0, 0).y));
                                bool _7130;
                                if (!_7122)
                                {
                                    _7130 = any(bool2(_7119.x >= cbFI_MvDepthLaneSize.x, _7119.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7130 = _7122;
                                }
                                if (_7130)
                                {
                                    _10614 = _9297;
                                    break;
                                }
                                uint4 _7208 = r_warped_motion_qdata_tp1.Load(int3(_7119, 0));
                                uint _7209 = _7208.x;
                                if (_7209 != 0u)
                                {
                                    _10614 = min(_9297, _7209);
                                    break;
                                }
                                _9300++;
                                continue;
                            }
                            else
                            {
                                _10614 = _9297;
                                break;
                            }
                        }
                    }
                    float _9299;
                    if (_9297 == 4294967295u)
                    {
                        _9299 = -1.0f;
                    }
                    else
                    {
                        float _9298;
                        if (_9297 == 0u)
                        {
                            _9298 = -1.0f;
                        }
                        else
                        {
                            _9298 = float((_9297 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9299 = _9298;
                    }
                    _9312 = _9299;
                    break;
                } while(false);
                bool _4382 = _9312 < 0.0f;
                float _9313;
                if (_4382)
                {
                    _9313 = 0.0f;
                }
                else
                {
                    _9313 = _9312 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7230_dummy_parameter;
                uint _7262_dummy_parameter;
                float4 _9350;
                if ((_4382 && _4371) && _4374)
                {
                    uint _7294_dummy_parameter;
                    float _7318 = log((r_depth_tm1.Load(int3(int2(floor(_9037 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7294_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7326_dummy_parameter;
                    float _7350 = log((r_depth_tp1.Load(int3(int2(floor(_9039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7326_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9351;
                    if (_7318 > (_7350 + 0.07999999821186065673828125f))
                    {
                        float4 _8914 = _9317;
                        _8914.x = 0.0f;
                        _9351 = _8914;
                    }
                    else
                    {
                        float4 _9352;
                        if (_7350 > (_7318 + 0.07999999821186065673828125f))
                        {
                            float4 _8916 = _9317;
                            _8916.y = 0.0f;
                            _9352 = _8916;
                        }
                        else
                        {
                            _9352 = _9317;
                        }
                        _9351 = _9352;
                    }
                    _9350 = _9351;
                }
                else
                {
                    _9350 = _9317;
                }
                float _4434 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4436 = _9312 >= 0.0f;
                float _9333;
                if (_4436)
                {
                    _9333 = _9312 - _4434;
                }
                else
                {
                    float _9329;
                    if (_4371)
                    {
                        float _9328;
                        _9328 = 2.0f;
                        float _7408;
                        for (int _9327 = 0; _9327 < 24; _9328 = _7408, _9327++)
                        {
                            float _7372 = float(_9327 & 7) * 0.785398185253143310546875f;
                            int _7374 = _9327 >> 3;
                            int _9330;
                            if (_7374 == 0)
                            {
                                _9330 = 16;
                            }
                            else
                            {
                                _9330 = (_7374 == 1) ? 48 : 96;
                            }
                            uint _7424_dummy_parameter;
                            _7408 = min(_9328, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9037 + ((cbFI_MvDepthLaneSizeRcp * float(_9330)) * float2(cos(_7372), sin(_7372))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7424_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9329 = _9328;
                    }
                    else
                    {
                        _9329 = 0.0f;
                    }
                    _9333 = _9329;
                }
                float _9340;
                if (_4436)
                {
                    _9340 = _9312 - _4434;
                }
                else
                {
                    float _9336;
                    if (_4374)
                    {
                        float _9335;
                        _9335 = 2.0f;
                        float _7522;
                        for (int _9334 = 0; _9334 < 24; _9335 = _7522, _9334++)
                        {
                            float _7486 = float(_9334 & 7) * 0.785398185253143310546875f;
                            int _7488 = _9334 >> 3;
                            int _9337;
                            if (_7488 == 0)
                            {
                                _9337 = 16;
                            }
                            else
                            {
                                _9337 = (_7488 == 1) ? 48 : 96;
                            }
                            uint _7554_dummy_parameter;
                            _7522 = min(_9335, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9039 + ((cbFI_MvDepthLaneSizeRcp * float(_9337)) * float2(cos(_7486), sin(_7486))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7554_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9336 = _9335;
                    }
                    else
                    {
                        _9336 = 0.0f;
                    }
                    _9340 = _9336;
                }
                float _9341;
                if (_4371)
                {
                    uint _7586_dummy_parameter;
                    _9341 = r_depth_tm1.Load(int3(int2(floor(_9037 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7586_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9341 = 0.0f;
                }
                float _9342;
                if (_4374)
                {
                    uint _7605_dummy_parameter;
                    _9342 = r_depth_tp1.Load(int3(int2(floor(_9039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7605_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9342 = 0.0f;
                }
                bool _4491;
                if (_4371)
                {
                    _4491 = _9341 > ((exp((_9333 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4491 = _4371;
                }
                float4 _9358;
                if (_4491)
                {
                    float4 _8918 = _9350;
                    _8918.x = 0.0f;
                    _9358 = _8918;
                }
                else
                {
                    _9358 = _9350;
                }
                bool _4503;
                if (_4374)
                {
                    _4503 = _9342 > ((exp((_9340 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4503 = _4374;
                }
                float4 _9360;
                if (_4503)
                {
                    float4 _8920 = _9358;
                    _8920.y = 0.0f;
                    _9360 = _8920;
                }
                else
                {
                    _9360 = _9358;
                }
                float4 _9423;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4436)
                {
                    bool _4523;
                    if (_4371)
                    {
                        _4523 = _9341 < ((exp((_9333 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4523 = _4371;
                    }
                    float4 _9362;
                    if (_4523)
                    {
                        float4 _8922 = _9360;
                        _8922.x = 0.0f;
                        _9362 = _8922;
                    }
                    else
                    {
                        _9362 = _9360;
                    }
                    bool _4535;
                    if (_4374)
                    {
                        _4535 = _9342 < ((exp((_9340 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4535 = _4374;
                    }
                    float4 _9424;
                    if (_4535)
                    {
                        float4 _8924 = _9362;
                        _8924.y = 0.0f;
                        _9424 = _8924;
                    }
                    else
                    {
                        _9424 = _9362;
                    }
                    _9423 = _9424;
                }
                else
                {
                    _9423 = _9360;
                }
                _9875 = float3(_9313, log((r_depth_tm1.Load(int3(int2(floor(_9037 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7230_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7262_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9422 = _9423;
            }
            else
            {
                _9875 = float3(0.0f, 0.0f, 0.5f);
                _9422 = _9317;
            }
            bool _4546 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4295;
            bool _4552;
            if (_4546)
            {
                _4552 = _4349 || _4355;
            }
            else
            {
                _4552 = _4546;
            }
            float4 _9444;
            if (_4552)
            {
                float _9417;
                do
                {
                    uint4 _7784 = r_warped_motion_qdata_tp1.Load(int3(_9067, 0));
                    uint _7785 = _7784.x;
                    if (_7785 != 0u)
                    {
                        float _9416;
                        if (_7785 == 0u)
                        {
                            _9416 = -1.0f;
                        }
                        else
                        {
                            _9416 = float((_7785 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9417 = _9416;
                        break;
                    }
                    int _9399;
                    uint _9400;
                    _9400 = _7785;
                    _9399 = -1;
                    uint _9415;
                    for (; _9399 <= 1; _9400 = _9415, _9399++)
                    {
                        _9415 = _9400;
                        for (int _9413 = -1; _9413 <= 1; )
                        {
                            _9415 = max(_9415, r_warped_motion_qdata_tp1.Load(int3(clamp(_9067 + int2(_9413, _9399), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9413++;
                            continue;
                        }
                    }
                    if (_9400 != 0u)
                    {
                        float _9412;
                        if (_9400 == 0u)
                        {
                            _9412 = -1.0f;
                        }
                        else
                        {
                            _9412 = float((_9400 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9417 = _9412;
                        break;
                    }
                    uint _9402;
                    _9402 = 4294967295u;
                    uint _10615;
                    for (int _9401 = 0; _9401 < 8; _9402 = _10615, _9401++)
                    {
                        int _9405 = 0;
                        for (;;)
                        {
                            if (_9405 < 5)
                            {
                                int2 _7735 = _9067 + (_1085[_9401] * _1094[_9405].xx);
                                bool _7738 = any(bool2(_7735.x < int2(0, 0).x, _7735.y < int2(0, 0).y));
                                bool _7746;
                                if (!_7738)
                                {
                                    _7746 = any(bool2(_7735.x >= cbFI_MvDepthLaneSize.x, _7735.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7746 = _7738;
                                }
                                if (_7746)
                                {
                                    _10615 = _9402;
                                    break;
                                }
                                uint4 _7824 = r_warped_motion_qdata_tp1.Load(int3(_7735, 0));
                                uint _7825 = _7824.x;
                                if (_7825 != 0u)
                                {
                                    _10615 = min(_9402, _7825);
                                    break;
                                }
                                _9405++;
                                continue;
                            }
                            else
                            {
                                _10615 = _9402;
                                break;
                            }
                        }
                    }
                    float _9404;
                    if (_9402 == 4294967295u)
                    {
                        _9404 = -1.0f;
                    }
                    else
                    {
                        float _9403;
                        if (_9402 == 0u)
                        {
                            _9403 = -1.0f;
                        }
                        else
                        {
                            _9403 = float((_9402 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9404 = _9403;
                    }
                    _9417 = _9404;
                    break;
                } while(false);
                float4 _9445;
                if (_9417 >= 0.0f)
                {
                    float _7846 = (exp((_9417 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4571;
                    if (_4349)
                    {
                        uint _7853_dummy_parameter;
                        _4571 = r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7853_dummy_parameter))))), 0)).x > _7846;
                    }
                    else
                    {
                        _4571 = _4349;
                    }
                    float4 _9435;
                    if (_4571)
                    {
                        float4 _8926 = _9422;
                        _8926.z = 0.0f;
                        _9435 = _8926;
                    }
                    else
                    {
                        _9435 = _9422;
                    }
                    bool _4583;
                    if (_4355)
                    {
                        uint _7872_dummy_parameter;
                        _4583 = r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7872_dummy_parameter))))), 0)).x > _7846;
                    }
                    else
                    {
                        _4583 = _4355;
                    }
                    float4 _9446;
                    if (_4583)
                    {
                        float4 _8928 = _9435;
                        _8928.w = 0.0f;
                        _9446 = _8928;
                    }
                    else
                    {
                        _9446 = _9435;
                    }
                    _9445 = _9446;
                }
                else
                {
                    _9445 = _9422;
                }
                _9444 = _9445;
            }
            else
            {
                _9444 = _9422;
            }
            bool _4591 = _4337 != _4343;
            bool _4598;
            if (_4591)
            {
                _4598 = _4337 ? _4283 : _4286;
            }
            else
            {
                _4598 = _4591;
            }
            float4 _9528;
            if (_4598)
            {
                bool2 _4603 = _4337.xx;
                float2 _4604 = float2(_4603.x ? _9037.x : _9039.x, _4603.y ? _9037.y : _9039.y);
                float _9437;
                if (_4337)
                {
                    uint _7891_dummy_parameter;
                    _9437 = r_depth_tm1.Load(int3(int2(floor(_4604 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7891_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7907_dummy_parameter;
                    _9437 = r_depth_tp1.Load(int3(int2(floor(_4604 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7907_dummy_parameter))))), 0)).x;
                }
                float4x4 _9438;
                if (_4337)
                {
                    _9438 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9438 = cbFI_MotionTP1ToTM1;
                }
                float2 _9439;
                do
                {
                    float _7934 = _4604.x;
                    float _7937 = 1.0f - _4604.y;
                    float4 _7948 = mul(float4((float2(_7934, _7937) * 2.0f) - 1.0f.xx, _9437, 1.0f), _9438);
                    float _7950 = _7948.w;
                    if (!(_7950 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9439 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7963 = ((_7948.xy / _7950.xx) + 1.0f.xx) * 0.5f;
                    _9439 = float2(_7963.x - _7934, _7937 - _7963.y);
                    break;
                } while(false);
                float2 _4634 = float2(cbFI_DisplaySize);
                float4 _9529;
                if (!(length(((_4604 + _9439) - float2(_4603.x ? _9039.x : _9037.x, _4603.y ? _9039.y : _9037.y)) * _4634) <= ((0.100000001490116119384765625f * length(_9439 * _4634)) + 8.0f)))
                {
                    float4 _9530;
                    if (_4337)
                    {
                        float4 _8938 = _9444;
                        _8938.x = 0.0f;
                        _9530 = _8938;
                    }
                    else
                    {
                        float4 _8940 = _9444;
                        _8940.y = 0.0f;
                        _9530 = _8940;
                    }
                    _9529 = _9530;
                }
                else
                {
                    _9529 = _9444;
                }
                _9528 = _9529;
            }
            else
            {
                _9528 = _9444;
            }
            float4 _4659 = _9216 * _9528;
            float _4661 = dot(_4659, 1.0f.xxxx);
            float4 _9706;
            bool _9726;
            if (_4661 > 0.0f)
            {
                _9726 = _9186;
                _9706 = _4659 / _4661.xxxx;
            }
            else
            {
                bool _4672 = any(bool4(_9528.x < 1.0f.xxxx.x, _9528.y < 1.0f.xxxx.y, _9528.z < 1.0f.xxxx.z, _9528.w < 1.0f.xxxx.w));
                if (_4672)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7985;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7985);
                    }
                }
                bool4 _10645 = _4672.xxxx;
                _9726 = _4672 ? true : _9186;
                _9706 = float4(_10645.x ? 0.0f.xxxx.x : _9216.x, _10645.y ? 0.0f.xxxx.y : _9216.y, _10645.z ? 0.0f.xxxx.z : _9216.z, _10645.w ? 0.0f.xxxx.w : _9216.w);
            }
            _9838 = _9875;
            _9725 = _9726;
            _9705 = _9706;
        }
        else
        {
            _9838 = float3(0.0f, 0.0f, 0.5f);
            _9725 = _9186;
            _9705 = _9216;
        }
        uint _4681 = (cbFI_pad0 >> 24u) & 31u;
        uint _4685 = (cbFI_pad0 >> 16u) & 255u;
        bool _4687 = _4681 != 0u;
        bool _4689 = _4685 == 12u;
        bool _4692 = _4685 == 13u;
        float4 _9722;
        if ((_4687 || _4689) || _4692)
        {
            float _9531;
            do
            {
                bool _8069 = all(bool2(_9040.x > 0.0f.xx.x, _9040.y > 0.0f.xx.y));
                bool _8075;
                if (_8069)
                {
                    _8075 = all(bool2(_9040.x < 1.0f.xx.x, _9040.y < 1.0f.xx.y));
                }
                else
                {
                    _8075 = _8069;
                }
                bool _8006 = !_8075;
                bool _8013;
                if (!_8006)
                {
                    bool _8080 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
                    bool _8086;
                    if (_8080)
                    {
                        _8086 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8086 = _8080;
                    }
                    _8013 = !_8086;
                }
                else
                {
                    _8013 = _8006;
                }
                if (_8013)
                {
                    _9531 = 0.0f;
                    break;
                }
                uint _8093_dummy_parameter;
                uint _8109_dummy_parameter;
                float4 _8034 = mul(float4((float2(_9040.x, 1.0f - _9040.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9040 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8093_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8036 = _8034.w;
                if (abs(_8036) < 9.9999999747524270787835121154785e-07f)
                {
                    _9531 = 0.0f;
                    break;
                }
                float _8047 = abs(cbFI_DeviceToViewDepth.y / ((_8034.z / _8036) - cbFI_DeviceToViewDepth.x));
                float _8050 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8109_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9531 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8047 - _8050) / max(max(_8047, _8050), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8157 = all(bool2(_9041.x > 0.0f.xx.x, _9041.y > 0.0f.xx.y));
            bool _8163;
            if (_8157)
            {
                _8163 = all(bool2(_9041.x < 1.0f.xx.x, _9041.y < 1.0f.xx.y));
            }
            else
            {
                _8163 = _8157;
            }
            float _9532;
            if (_8163)
            {
                uint _8170_dummy_parameter;
                _9532 = length((_5468 + (r_motion_tp1.Load(int3(int2(floor(_9041 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8170_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9532 = 1000000.0f;
            }
            float _9543;
            if ((_4681 & 1u) != 0u)
            {
                _9543 = _9531;
            }
            else
            {
                _9543 = 1.0f;
            }
            float _9544;
            if ((_4681 & 2u) != 0u)
            {
                _9544 = _9543 * (1.0f - smoothstep(2.0f, 8.0f, _9532));
            }
            else
            {
                _9544 = _9543;
            }
            float _9545;
            if ((_4681 & 4u) != 0u)
            {
                _9545 = _9544 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6189 - _6197) - length(_6173 - _6181))));
            }
            else
            {
                _9545 = _9544;
            }
            float _9716;
            if ((_4681 & 8u) != 0u)
            {
                _9716 = lerp(1.0f, _9545, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6173 - _6181)));
            }
            else
            {
                _9716 = _9545;
            }
            bool _4767 = (_4681 & 16u) != 0u;
            bool _4776;
            if (_4767)
            {
                _4776 = length(_9035 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4776 = _4767;
            }
            float _10647 = _4776 ? 1.0f : _9716;
            bool _4782 = _4687 && _6382;
            bool _4787;
            if (_4782)
            {
                bool _8195 = all(bool2(_9037.x > 0.0f.xx.x, _9037.y > 0.0f.xx.y));
                bool _8201;
                if (_8195)
                {
                    _8201 = all(bool2(_9037.x < 1.0f.xx.x, _9037.y < 1.0f.xx.y));
                }
                else
                {
                    _8201 = _8195;
                }
                _4787 = _8201;
            }
            else
            {
                _4787 = _4782;
            }
            bool _4792;
            if (_4787)
            {
                bool _8206 = all(bool2(_9039.x > 0.0f.xx.x, _9039.y > 0.0f.xx.y));
                bool _8212;
                if (_8206)
                {
                    _8212 = all(bool2(_9039.x < 1.0f.xx.x, _9039.y < 1.0f.xx.y));
                }
                else
                {
                    _8212 = _8206;
                }
                _4792 = _8212;
            }
            else
            {
                _4792 = _4787;
            }
            float4 _9723;
            if (_4792)
            {
                float _4798 = _9705.x + _9705.y;
                float _4807 = (_9705.z + _9705.w) * (1.0f - _10647);
                float _9719;
                if (_4798 > 9.9999997473787516355514526367188e-06f)
                {
                    _9719 = _9705.x / _4798;
                }
                else
                {
                    _9719 = _3955;
                }
                _9723 = float4(_9705.x + (_4807 * _9719), _9705.y + (_4807 * (1.0f - _9719)), _9705.zw * _10647);
            }
            else
            {
                _9723 = _9705;
            }
            _9722 = _9723;
        }
        else
        {
            _9722 = _9705;
        }
        float3 _10418;
        if (_9725)
        {
            float3 _8218 = r_current_interpolation_source.Load(int3(_3368, 0)).xyz;
            float3 _10419;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6382)
            {
                uint _8225_dummy_parameter;
                float _9829;
                _9829 = r_depth_tm1.Load(int3(int2(floor(_9037 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8225_dummy_parameter))))), 0)).x;
                float _4919;
                for (int _9828 = 0; _9828 < 24; _9829 = _4919, _9828++)
                {
                    float _4891 = float(_9828 & 7) * 0.785398185253143310546875f;
                    int _4893 = _9828 >> 3;
                    int _10469;
                    if (_4893 == 0)
                    {
                        _10469 = 16;
                    }
                    else
                    {
                        _10469 = (_4893 == 1) ? 48 : 96;
                    }
                    uint _8245_dummy_parameter;
                    _4919 = min(_9829, r_depth_tm1.Load(int3(int2(floor(clamp(_9037 + ((cbFI_MvDepthLaneSizeRcp * float(_10469)) * float2(cos(_4891), sin(_4891))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8245_dummy_parameter))))), 0)).x);
                }
                float2 _9830;
                do
                {
                    float _8267 = 1.0f - _9037.y;
                    float4 _8278 = mul(float4((float2(_9037.x, _8267) * 2.0f) - 1.0f.xx, _9829, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8280 = _8278.w;
                    if (!(_8280 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9830 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8293 = ((_8278.xy / _8280.xx) + 1.0f.xx) * 0.5f;
                    _9830 = float2(_8293.x - _9037.x, _8267 - _8293.y);
                    break;
                } while(false);
                float2 _4930 = _9037 + _9830;
                bool _8311 = all(bool2(_4930.x > 0.0f.xx.x, _4930.y > 0.0f.xx.y));
                bool _8317;
                if (_8311)
                {
                    _8317 = all(bool2(_4930.x < 1.0f.xx.x, _4930.y < 1.0f.xx.y));
                }
                else
                {
                    _8317 = _8311;
                }
                float3 _10420;
                if (_8317)
                {
                    float _4936 = abs(cbFI_DeviceToViewDepth.y / (_9829 - cbFI_DeviceToViewDepth.x));
                    uint _8337_dummy_parameter;
                    int2 _8337 = int2(spvTextureSize(r_depth_m2, uint(0), _8337_dummy_parameter));
                    float _4940 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4930 * float2(_8337))), int2(0, 0), _8337 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10425;
                    if (abs(_4940 - _4936) <= (0.20000000298023223876953125f * max(_4940, _4936)))
                    {
                        uint _8371_dummy_parameter;
                        int2 _8371 = int2(spvTextureSize(r_colour_m2, uint(0), _8371_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8394;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8394);
                        }
                        _10425 = r_colour_m2.Load(int3(clamp(int2(floor(_4930 * float2(_8371))), int2(0, 0), _8371 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8404;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8404);
                        }
                        _10425 = _8218;
                    }
                    _10420 = _10425;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8414;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8414);
                    }
                    _10420 = _8218;
                }
                _10419 = _10420;
            }
            else
            {
                _10419 = _8218;
            }
            _10418 = _10419;
        }
        else
        {
            _10418 = (((_6173 * _9722.x) + (_6181 * _9722.y)) + (_6189 * _9722.z)) + (_6197 * _9722.w);
        }
        uint _4968 = cbFI_pad0 & 255u;
        bool _10311;
        float3 _10417;
        if (_4968 != 0u)
        {
            float3 _4973 = r_present_backbuffer.Load(int3(_3368, 0)).xyz;
            float3 _4977 = r_current_interpolation_source.Load(int3(_3368, 0)).xyz;
            float3 _4981 = abs(_4973 - _4977);
            float3 _9833;
            if (_4968 == 2u)
            {
                _9833 = (abs(_4977) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9833 = 0.000244140625f.xxx;
            }
            bool _4997 = any(bool3(_4981.x > _9833.x, _4981.y > _9833.y, _4981.z > _9833.z));
            bool3 _10648 = _4997.xxx;
            _10417 = float3(_10648.x ? _4973.x : _10418.x, _10648.y ? _4973.y : _10418.y, _10648.z ? _4973.z : _10418.z);
            _10311 = _4997;
        }
        else
        {
            _10417 = _10418;
            _10311 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8429;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8429);
        }
        float3 _10400;
        if (_4685 == 1u)
        {
            _10400 = lerp(_6173, _6181, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10401;
            if (_4685 == 2u)
            {
                _10401 = lerp(_6189, _6197, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10402;
                if (_4685 == 3u)
                {
                    _10402 = float(_10311).xxx;
                }
                else
                {
                    float3 _10403;
                    if (_4685 == 4u)
                    {
                        _10403 = float3(((_9035 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10404;
                        if (_4685 == 5u)
                        {
                            _10404 = float3(((_5468 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10405;
                            if (_4685 == 6u)
                            {
                                _10405 = float3(_9722.xy, _9722.z + _9722.w);
                            }
                            else
                            {
                                float3 _10406;
                                if (_4685 == 7u)
                                {
                                    _10406 = r_current_interpolation_source.Load(int3(_3368, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10407;
                                    if (_4685 == 8u)
                                    {
                                        _10407 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3730, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10408;
                                        if (_4689)
                                        {
                                            uint _8451_dummy_parameter;
                                            uint _8483_dummy_parameter;
                                            _10408 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3730 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8451_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3730 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8483_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10409;
                                            if (_4692)
                                            {
                                                _10409 = _6189;
                                            }
                                            else
                                            {
                                                float3 _10410;
                                                if (_4685 == 20u)
                                                {
                                                    _10410 = _6173;
                                                }
                                                else
                                                {
                                                    float3 _10411;
                                                    if (_4685 == 21u)
                                                    {
                                                        _10411 = _6181;
                                                    }
                                                    else
                                                    {
                                                        float3 _10412;
                                                        if (_4685 == 22u)
                                                        {
                                                            _10412 = _6197;
                                                        }
                                                        else
                                                        {
                                                            float3 _10413;
                                                            if (_4685 == 18u)
                                                            {
                                                                _10413 = _10119;
                                                            }
                                                            else
                                                            {
                                                                float3 _10414;
                                                                if (_4685 == 19u)
                                                                {
                                                                    _10414 = _9975;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10650 = (_4685 == 23u).xxx;
                                                                    _10414 = float3(_10650.x ? _9838.x : _10417.x, _10650.y ? _9838.y : _10417.y, _10650.z ? _9838.z : _10417.z);
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
                            _10404 = _10405;
                        }
                        _10403 = _10404;
                    }
                    _10402 = _10403;
                }
                _10401 = _10402;
            }
            _10400 = _10401;
        }
        float3 _10399;
        if ((_4685 >= 9u) && (_4685 <= 11u))
        {
            uint _5161 = 64u + uint((_9067.y * cbFI_MvDepthLaneSize.x) + _9067.x);
            uint _5165 = rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) & 15u;
            float3 _10430;
            if (_4685 == 10u)
            {
                float3 _10398;
                if ((rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) & 32u) != 0u)
                {
                    _10398 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10397;
                    if ((rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) & 16u) != 0u)
                    {
                        _10397 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5186 = ((rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) & 64u) != 0u).xxx;
                        _10397 = float3(_5186.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5186.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5186.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10398 = _10397;
                }
                _10430 = _10398;
            }
            else
            {
                float3 _10431;
                if (_4685 == 11u)
                {
                    uint _5199 = (rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) >> 8u) & 15u;
                    uint _5202 = (rw_nfru_diagnostics.Load<uint>(_5161 * 4 + 0) >> 12u) & 15u;
                    float3 _10390;
                    if ((_5165 == 2u) || (_5165 == 3u))
                    {
                        _10390 = _3081[_5165];
                    }
                    else
                    {
                        bool _5214 = _5199 == 3u;
                        bool _5216 = _5202 == 3u;
                        float3 _10391;
                        if (_5214 && _5216)
                        {
                            _10391 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10392;
                            if (_5214)
                            {
                                _10392 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10393;
                                if (_5216)
                                {
                                    _10393 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10394;
                                    if ((_5199 == 4u) || (_5202 == 4u))
                                    {
                                        _10394 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10395;
                                        if ((_5199 == 1u) || (_5202 == 1u))
                                        {
                                            _10395 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10652 = (_5165 == 1u).xxx;
                                            _10395 = float3(_10652.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10652.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10652.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10394 = _10395;
                                    }
                                    _10393 = _10394;
                                }
                                _10392 = _10393;
                            }
                            _10391 = _10392;
                        }
                        _10390 = _10391;
                    }
                    _10431 = _10390;
                }
                else
                {
                    _10431 = _3081[min(_5165, 7u)];
                }
                _10430 = _10431;
            }
            _10399 = _10430;
        }
        else
        {
            _10399 = _10400;
        }
        float4 _10434;
        if ((_4685 >= 14u) && (_4685 <= 16u))
        {
            float2 _10432;
            if (_4685 == 14u)
            {
                uint _5272_dummy_parameter;
                uint _5278_dummy_parameter;
                _10432 = r_flow_tm1.Load(int3(clamp(int2(floor(_3730 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5272_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5278_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10433;
                if (_4685 == 16u)
                {
                    uint _8534 = r_warped_flow_qdata_tm1.Load(int3(_3746, 0)).x & 2147483647u;
                    uint _8566 = uint(max((int((_8534 >> 16u) & 15u) - 6), 0));
                    _10433 = ((float2(float((1 - (2 * int((_8534 >> 15u) & 1u))) * int(((_8534 >> uint(7)) & 127u) << _8566)), float((1 - (2 * int((_8534 >> 14u) & 1u))) * int((_8534 & 127u) << _8566))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10433 = _5468 * float2(cbFI_DisplaySize);
                }
                _10432 = _10433;
            }
            uint2 _5311 = uint2(clamp(round(_10432 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5313 = _5311.x;
            uint _5320 = _5311.y;
            _10434 = float4(float(_5313 & 255u), float((_5313 >> 8u) | ((_5320 & 15u) << 4u)), float(_5320 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10435;
            if (_4685 == 17u)
            {
                _10435 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3746, 0)).x != 0u), _4089, 0.0f, 1.0f);
            }
            else
            {
                _10435 = float4(_10399, 1.0f);
            }
            _10434 = _10435;
        }
        rw_output[_3368] = _10434.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5364 = ((uint(_3368.y) * uint(cbFI_DisplaySize.x)) + uint(_3368.x)) * 6u;
            uint _8612 = spvPackHalf2x16(clamp(_6172.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5364 * 4 + 0, (((_8612 & 32767u) >> 4u) | ((((_8612 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6172.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8647 = spvPackHalf2x16(clamp(_6180.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5364 + 1u) * 4 + 0, (((_8647 & 32767u) >> 4u) | ((((_8647 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6180.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8682 = spvPackHalf2x16(clamp(_6188.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5364 + 2u) * 4 + 0, (((_8682 & 32767u) >> 4u) | ((((_8682 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6188.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8717 = spvPackHalf2x16(clamp(_6196.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5364 + 3u) * 4 + 0, (((_8717 & 32767u) >> 4u) | ((((_8717 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6196.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8744 = r_current_interpolation_source.Load(int3(_3368, 0));
            uint _8758 = spvPackHalf2x16(clamp(_8744.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5364 + 4u) * 4 + 0, (((_8758 & 32767u) >> 4u) | ((((_8758 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8744.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10468;
            if (_10311 || (_4685 != 0u))
            {
                _10468 = 4294967295u;
            }
            else
            {
                uint _8793 = spvPackHalf2x16(clamp(_10434.xy, 0.0f.xx, 65000.0f.xx));
                _10468 = (((_8793 & 32767u) >> 4u) | ((((_8793 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10434.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5364 + 5u) * 4 + 0, _10468);
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
