static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3071[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3358 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3358.x >= cbFI_DisplaySize.x, _3358.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3358] = float4(r_present_backbuffer.Load(int3(_3358, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3719 = (float2(_3358) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3730 = int2(floor(_3719 * float2(cbFI_MvDepthLaneSize)));
        int2 _3735 = int2(floor(_3719 * float2(cbFI_FlowLaneSize)));
        float4 _5441 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3719 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5447 = r_warped_filled_flow_tm1.Load(int3(_3735, 0)).xy;
        float2 _5453 = r_warped_filled_motion_tp1.Load(int3(_3730, 0)).xy;
        bool _5475 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8997;
        if (_5475)
        {
            float _5488 = ((2.0f * _3719.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8997 = float2(atan(_5488) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3719.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5488 * _5488))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8997 = _3719;
        }
        bool _3756 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9018;
        bool _9039;
        int2 _9050;
        float3 _10095;
        if (_3756)
        {
            float _8999;
            float _9001;
            _9001 = 2.0f;
            _8999 = -1.0f;
            uint _3420[9];
            float _10485;
            float _10488;
            for (int _8998 = 0; _8998 < 9; _9001 = _10488, _8999 = _10485, _8998++)
            {
                _3420[_8998] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3730 + int2((_8998 % 3) - 1, (_8998 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3420[_8998] != 0u)
                {
                    float _10480;
                    if (_3420[_8998] == 0u)
                    {
                        _10480 = -1.0f;
                    }
                    else
                    {
                        _10480 = float((_3420[_8998] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10488 = min(_9001, _10480);
                    _10485 = max(_8999, _10480);
                }
                else
                {
                    _10488 = _9001;
                    _10485 = _8999;
                }
            }
            float _3802 = float(_8999 >= 0.0f);
            float3 _8808 = 0.0f.xxx;
            _8808.y = _3802;
            float2 _9019;
            bool _9040;
            int2 _9051;
            float3 _10096;
            if ((_8999 - _9001) > 0.0199999995529651641845703125f)
            {
                float _9007;
                int2 _9008;
                float2 _9009;
                int2 _9011;
                float2 _9017;
                _9017 = _5453;
                _9011 = _3730;
                _9009 = _5453;
                _9008 = _3730;
                _9007 = -1.0f;
                float _10493;
                int2 _10497;
                float2 _10508;
                int2 _10519;
                float2 _10552;
                float _10598;
                int _9006 = 0;
                float _10461 = 1000000000.0f;
                for (; _9006 < 9; _10461 = _10598, _9017 = _10552, _9011 = _10519, _9009 = _10508, _9008 = _10497, _9007 = _10493, _9006++)
                {
                    if (_3420[_9006] == 0u)
                    {
                        _10598 = _10461;
                        _10552 = _9017;
                        _10519 = _9011;
                        _10508 = _9009;
                        _10497 = _9008;
                        _10493 = _9007;
                        continue;
                    }
                    int2 _3837 = clamp(_3730 + int2((_9006 % 3) - 1, (_9006 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5563 = _3420[_9006] & 2147483647u;
                    uint _5595 = uint(max((int((_5563 >> 16u) & 15u) - 6), 0));
                    float2 _3843 = (float2(float((1 - (2 * int((_5563 >> 15u) & 1u))) * int(((_5563 >> uint(7)) & 127u) << _5595)), float((1 - (2 * int((_5563 >> 14u) & 1u))) * int((_5563 & 127u) << _5595))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10447;
                    if (_3420[_9006] == 0u)
                    {
                        _10447 = -1.0f;
                    }
                    else
                    {
                        _10447 = float((_3420[_9006] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3848 = _10447 - 0.100000001490116119384765625f;
                    float2 _10448;
                    if (_5475)
                    {
                        float2 _5672 = clamp((((_8997 + (_3843 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5675 = tan(_5672.x);
                        _10448 = (float2(_5675 / cbFI_DeviceToViewDepth.z, (tan(_5672.y) * sqrt(1.0f + (_5675 * _5675))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10448 = _8997 + (_3843 * cbFI_Timestep);
                    }
                    float _3855 = cbFI_Timestep - 1.0f;
                    float2 _10449;
                    if (_5475)
                    {
                        float2 _5743 = clamp((((_8997 + (_3843 * _3855)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5746 = tan(_5743.x);
                        _10449 = (float2(_5746 / cbFI_DeviceToViewDepth.z, (tan(_5743.y) * sqrt(1.0f + (_5746 * _5746))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10449 = _8997 + (_3843 * _3855);
                    }
                    bool _5779 = all(bool2(_10448.x > 0.0f.xx.x, _10448.y > 0.0f.xx.y));
                    bool _5785;
                    if (_5779)
                    {
                        _5785 = all(bool2(_10448.x < 1.0f.xx.x, _10448.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5785 = _5779;
                    }
                    float _10452;
                    if (_5785)
                    {
                        uint _5792_dummy_parameter;
                        _10452 = max((_3848 - (log(((r_depth_tm1.Load(int3(int2(floor(_10448 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5792_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10452 = 0.0f;
                    }
                    bool _5822 = all(bool2(_10449.x > 0.0f.xx.x, _10449.y > 0.0f.xx.y));
                    bool _5828;
                    if (_5822)
                    {
                        _5828 = all(bool2(_10449.x < 1.0f.xx.x, _10449.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5828 = _5822;
                    }
                    float _10453;
                    if (_5828)
                    {
                        uint _5835_dummy_parameter;
                        _10453 = _10452 + max((_3848 - (log(((r_depth_tp1.Load(int3(int2(floor(_10449 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5835_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10453 = _10452;
                    }
                    float _10494;
                    int2 _10498;
                    float2 _10509;
                    int2 _10520;
                    float2 _10553;
                    float _10599;
                    if (_10453 == 0.0f)
                    {
                        bool _3890 = _3848 > _9007;
                        bool2 _10607 = _3890.xx;
                        _10599 = _10461;
                        _10553 = float2(_10607.x ? _3843.x : _9017.x, _10607.y ? _3843.y : _9017.y);
                        _10520 = int2(_10607.x ? _3837.x : _9011.x, _10607.y ? _3837.y : _9011.y);
                        _10509 = _9009;
                        _10498 = _9008;
                        _10494 = _3890 ? _3848 : _9007;
                    }
                    else
                    {
                        bool _3899 = _10453 < _10461;
                        bool2 _10603 = _3899.xx;
                        _10599 = _3899 ? _10453 : _10461;
                        _10553 = _9017;
                        _10520 = _9011;
                        _10509 = float2(_10603.x ? _3843.x : _9009.x, _10603.y ? _3843.y : _9009.y);
                        _10498 = int2(_10603.x ? _3837.x : _9008.x, _10603.y ? _3837.y : _9008.y);
                        _10494 = _9007;
                    }
                    _10598 = _10599;
                    _10552 = _10553;
                    _10519 = _10520;
                    _10508 = _10509;
                    _10497 = _10498;
                    _10493 = _10494;
                }
                bool _3911 = _9007 < 0.0f;
                bool2 _10613 = _3911.xx;
                int2 _10616 = int2(_10613.x ? _9008.x : _9011.x, _10613.y ? _9008.y : _9011.y);
                _10096 = float3(1.0f, _3802, float(any(bool2(_10616.x != _3730.x, _10616.y != _3730.y))));
                _9051 = _10616;
                _9040 = _3911 ? false : true;
                _9019 = float2(_10613.x ? _9009.x : _9017.x, _10613.y ? _9009.y : _9017.y);
            }
            else
            {
                _10096 = _8808;
                _9051 = _3730;
                _9040 = false;
                _9019 = _5453;
            }
            _10095 = _10096;
            _9050 = _9051;
            _9039 = _9040;
            _9018 = _9019;
        }
        else
        {
            _10095 = 0.0f.xxx;
            _9050 = _3730;
            _9039 = false;
            _9018 = _5453;
        }
        float2 _9020;
        if (_5475)
        {
            float2 _5900 = clamp((((_8997 + (_9018 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5903 = tan(_5900.x);
            _9020 = (float2(_5903 / cbFI_DeviceToViewDepth.z, (tan(_5900.y) * sqrt(1.0f + (_5903 * _5903))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9020 = _8997 + (_9018 * cbFI_Timestep);
        }
        float _3934 = cbFI_Timestep - 1.0f;
        float2 _9022;
        if (_5475)
        {
            float2 _5971 = clamp((((_8997 + (_9018 * _3934)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5974 = tan(_5971.x);
            _9022 = (float2(_5974 / cbFI_DeviceToViewDepth.z, (tan(_5971.y) * sqrt(1.0f + (_5974 * _5974))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9022 = _8997 + (_9018 * _3934);
        }
        float _3939 = -cbFI_Timestep;
        float2 _9023;
        if (_5475)
        {
            float2 _6042 = clamp((((_8997 + (_5447 * _3939)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6045 = tan(_6042.x);
            _9023 = (float2(_6045 / cbFI_DeviceToViewDepth.z, (tan(_6042.y) * sqrt(1.0f + (_6045 * _6045))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9023 = _8997 + (_5447 * _3939);
        }
        float _3944 = 1.0f - cbFI_Timestep;
        float2 _9024;
        if (_5475)
        {
            float2 _6113 = clamp((((_8997 + (_5447 * _3944)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6116 = tan(_6113.x);
            _9024 = (float2(_6116 / cbFI_DeviceToViewDepth.z, (tan(_6113.y) * sqrt(1.0f + (_6116 * _6116))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9024 = _8997 + (_5447 * _3944);
        }
        float4 _6151 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9020, 0.0f);
        float3 _6152 = _6151.xyz;
        float4 _6159 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9022, 0.0f);
        float3 _6160 = _6159.xyz;
        float4 _6167 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9023, 0.0f);
        float3 _6168 = _6167.xyz;
        float4 _6175 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9024, 0.0f);
        float3 _6176 = _6175.xyz;
        float4 _6190 = exp(_5441 - max(max(max(_5441.x, _5441.y), _5441.z), _5441.w).xxxx);
        float4 _6197 = _6190 / (dot(_6190, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3963 = _3756 && (!_9039);
        bool _3972;
        if (_3963)
        {
            _3972 = (_6197.z + _6197.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3972 = _3963;
        }
        bool _3983;
        if (_3972)
        {
            _3983 = length((_9023 - _9020) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3983 = _3972;
        }
        bool _9063;
        if (_3983)
        {
            uint4 _6216 = r_warped_motion_qdata_tp1.Load(int3(_9050, 0));
            uint _6217 = _6216.x;
            bool _9066;
            if (_6217 != 0u)
            {
                float _9052;
                if (_6217 == 0u)
                {
                    _9052 = -1.0f;
                }
                else
                {
                    _9052 = float((_6217 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3993 = _9052 - 0.12000000476837158203125f;
                bool _6236 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                bool _6242;
                if (_6236)
                {
                    _6242 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                }
                else
                {
                    _6242 = _6236;
                }
                bool _4003;
                if (_6242)
                {
                    uint _6249_dummy_parameter;
                    _4003 = (log(((r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6249_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3993;
                }
                else
                {
                    _4003 = _6242;
                }
                bool _4017;
                if (!_4003)
                {
                    bool _6279 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                    bool _6285;
                    if (_6279)
                    {
                        _6285 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6285 = _6279;
                    }
                    bool _4015;
                    if (_6285)
                    {
                        uint _6292_dummy_parameter;
                        _4015 = (log(((r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6292_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3993;
                    }
                    else
                    {
                        _4015 = _6285;
                    }
                    _4017 = _4015;
                }
                else
                {
                    _4017 = _4003;
                }
                _9066 = _4017;
            }
            else
            {
                _9066 = false;
            }
            _9063 = _9066;
        }
        else
        {
            _9063 = false;
        }
        bool _4022 = _9039 || _9063;
        bool _4027;
        if (_4022)
        {
            bool _6322 = all(bool2(_9020.x > 0.0f.xx.x, _9020.y > 0.0f.xx.y));
            bool _6328;
            if (_6322)
            {
                _6328 = all(bool2(_9020.x < 1.0f.xx.x, _9020.y < 1.0f.xx.y));
            }
            else
            {
                _6328 = _6322;
            }
            _4027 = _6328;
        }
        else
        {
            _4027 = _4022;
        }
        bool _4032;
        if (_4027)
        {
            bool _6333 = all(bool2(_9022.x > 0.0f.xx.x, _9022.y > 0.0f.xx.y));
            bool _6339;
            if (_6333)
            {
                _6339 = all(bool2(_9022.x < 1.0f.xx.x, _9022.y < 1.0f.xx.y));
            }
            else
            {
                _6339 = _6333;
            }
            _4032 = _6339;
        }
        else
        {
            _4032 = _4027;
        }
        float4 _9157;
        if (_4032)
        {
            float _4035 = _6197.x;
            float _4037 = _6197.y;
            float _4038 = _4035 + _4037;
            float _4043 = _6197.z + _6197.w;
            float _9081;
            if (_4038 > 0.001000000047497451305389404296875f)
            {
                _9081 = _4035 / _4038;
            }
            else
            {
                _9081 = _3944;
            }
            _9157 = float4(_4035 + (_4043 * _9081), _4037 + (_4043 * (1.0f - _9081)), 0.0f, 0.0f);
        }
        else
        {
            _9157 = _6197;
        }
        bool _6367 = (cbFI_pad0 & 1024u) != 0u;
        bool _6343 = !_6367;
        bool _6344 = !_6343;
        bool _6361;
        if (_6344)
        {
            _6361 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9050.y * cbFI_MvDepthLaneSize.x) + _9050.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6361 = _6343;
        }
        bool _6393;
        if (_6344)
        {
            _6393 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3735.y * cbFI_FlowLaneSize.x) + _3735.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6393 = _6343;
        }
        float _4078 = float(_6393);
        bool _9169;
        float4 _9199;
        float3 _9952;
        if (_6367)
        {
            bool _4088;
            if (_6361)
            {
                _4088 = all(bool2(_9020.x > 0.0f.xx.x, _9020.y > 0.0f.xx.y));
            }
            else
            {
                _4088 = _6361;
            }
            bool _4094;
            if (_4088)
            {
                _4094 = all(bool2(_9020.x < 1.0f.xx.x, _9020.y < 1.0f.xx.y));
            }
            else
            {
                _4094 = _4088;
            }
            bool _4101;
            if (_6361)
            {
                _4101 = all(bool2(_9022.x > 0.0f.xx.x, _9022.y > 0.0f.xx.y));
            }
            else
            {
                _4101 = _6361;
            }
            bool _4107;
            if (_4101)
            {
                _4107 = all(bool2(_9022.x < 1.0f.xx.x, _9022.y < 1.0f.xx.y));
            }
            else
            {
                _4107 = _4101;
            }
            bool _4114;
            if (_6393)
            {
                _4114 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
            }
            else
            {
                _4114 = _6393;
            }
            bool _4120;
            if (_4114)
            {
                _4120 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
            }
            else
            {
                _4120 = _4114;
            }
            bool _4127;
            if (_6393)
            {
                _4127 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
            }
            else
            {
                _4127 = _6393;
            }
            bool _4133;
            if (_4127)
            {
                _4133 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
            }
            else
            {
                _4133 = _4127;
            }
            bool _4135 = !_6361;
            if (_4135)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6435;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6435);
                }
            }
            bool _4140 = !_6393;
            if (_4140)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6445;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6445);
                }
            }
            if (_6361 && _4140)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6455;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6455);
                }
            }
            if (_4135 && _6393)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6465;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6465);
                }
            }
            float _4159 = float(_4094);
            float _4161 = float(_4107);
            bool _4164 = _4120 && _4133;
            float _9115;
            if (_4164)
            {
                _9115 = 1.0f;
            }
            else
            {
                _9115 = (_4120 || _4133) ? 0.5f : 0.0f;
            }
            bool _9120;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4094)) && (!_4107))
            {
                bool _4194;
                if (_4164)
                {
                    float _9118;
                    do
                    {
                        bool _6549 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                        bool _6555;
                        if (_6549)
                        {
                            _6555 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6555 = _6549;
                        }
                        bool _6486 = !_6555;
                        bool _6493;
                        if (!_6486)
                        {
                            bool _6560 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                            bool _6566;
                            if (_6560)
                            {
                                _6566 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6566 = _6560;
                            }
                            _6493 = !_6566;
                        }
                        else
                        {
                            _6493 = _6486;
                        }
                        if (_6493)
                        {
                            _9118 = 0.0f;
                            break;
                        }
                        uint _6573_dummy_parameter;
                        uint _6589_dummy_parameter;
                        float4 _6514 = mul(float4((float2(_9023.x, 1.0f - _9023.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6573_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6516 = _6514.w;
                        if (abs(_6516) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9118 = 0.0f;
                            break;
                        }
                        float _6527 = abs(cbFI_DeviceToViewDepth.y / ((_6514.z / _6516) - cbFI_DeviceToViewDepth.x));
                        float _6530 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6589_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9118 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6527 - _6530) / max(max(_6527, _6530), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4194 = _9118 >= 0.5f;
                }
                else
                {
                    _4194 = _4164;
                }
                bool _9121;
                if (_4194)
                {
                    uint _6639_dummy_parameter;
                    float2 _9119;
                    do
                    {
                        float _6665 = 1.0f - _9023.y;
                        float4 _6676 = mul(float4((float2(_9023.x, _6665) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6639_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6678 = _6676.w;
                        if (!(_6678 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9119 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6691 = ((_6676.xy / _6678.xx) + 1.0f.xx) * 0.5f;
                        _9119 = float2(_6691.x - _9023.x, _6665 - _6691.y);
                        break;
                    } while(false);
                    float2 _4208 = float2(cbFI_DisplaySize);
                    _9121 = length(((_9023 + _9119) - _9024) * _4208) <= ((0.100000001490116119384765625f * length(_9119 * _4208)) + 8.0f);
                }
                else
                {
                    _9121 = _4194;
                }
                _9120 = _9121;
            }
            else
            {
                _9120 = true;
            }
            bool _4222 = !_9120;
            bool _10617 = _4222 ? false : _4133;
            bool _10618 = _4222 ? false : _4120;
            bool _9170;
            float4 _9200;
            if (!(((_4094 && _4107) && _10618) && _10617))
            {
                float4 _4244 = _9157 * float4(_4159, _4161, float(_10618), float(_10617));
                float _4246 = dot(_4244, 1.0f.xxxx);
                bool _4249 = !(_4246 > 0.0f);
                float4 _9201;
                if (!_4249)
                {
                    _9201 = _4244 / _4246.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6713;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6713);
                    }
                    _9201 = 0.0f.xxxx;
                }
                _9200 = _9201;
                _9170 = _4249;
            }
            else
            {
                _9200 = _9157;
                _9170 = false;
            }
            _9952 = float3(_4159, _4161, _9115);
            _9199 = _9200;
            _9169 = _9170;
        }
        else
        {
            _9952 = float3(float(_6361), _4078, 0.0f);
            _9199 = _9157;
            _9169 = false;
        }
        float4 _9683;
        bool _9703;
        float3 _9815;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9169))
        {
            bool _4272 = _9199.x > 0.00999999977648258209228515625f;
            bool _4275 = _9199.y > 0.00999999977648258209228515625f;
            bool _4284 = (_9199.z + _9199.w) > 0.0199999995529651641845703125f;
            bool _4290;
            if (_4284)
            {
                bool _6719 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                bool _6725;
                if (_6719)
                {
                    _6725 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                }
                else
                {
                    _6725 = _6719;
                }
                _4290 = _6725;
            }
            else
            {
                _4290 = _4284;
            }
            bool _4295;
            if (_4290)
            {
                bool _6730 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                bool _6736;
                if (_6730)
                {
                    _6736 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                }
                else
                {
                    _6736 = _6730;
                }
                _4295 = _6736;
            }
            else
            {
                _4295 = _4290;
            }
            bool _4302;
            if (_4295)
            {
                float _9203;
                do
                {
                    bool _6819 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                    bool _6825;
                    if (_6819)
                    {
                        _6825 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6825 = _6819;
                    }
                    bool _6756 = !_6825;
                    bool _6763;
                    if (!_6756)
                    {
                        bool _6830 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                        bool _6836;
                        if (_6830)
                        {
                            _6836 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6836 = _6830;
                        }
                        _6763 = !_6836;
                    }
                    else
                    {
                        _6763 = _6756;
                    }
                    if (_6763)
                    {
                        _9203 = 0.0f;
                        break;
                    }
                    uint _6843_dummy_parameter;
                    uint _6859_dummy_parameter;
                    float4 _6784 = mul(float4((float2(_9023.x, 1.0f - _9023.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6843_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6786 = _6784.w;
                    if (abs(_6786) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9203 = 0.0f;
                        break;
                    }
                    float _6797 = abs(cbFI_DeviceToViewDepth.y / ((_6784.z / _6786) - cbFI_DeviceToViewDepth.x));
                    float _6800 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6859_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9203 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6797 - _6800) / max(max(_6797, _6800), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4302 = _9203 < 0.5f;
            }
            else
            {
                _4302 = _4295;
            }
            float4 _9218;
            if (_4302)
            {
                uint _6909_dummy_parameter;
                uint _6940_dummy_parameter;
                float4 _9219;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6909_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6940_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9219 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9219 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9218 = _9219;
            }
            else
            {
                _9218 = 1.0f.xxxx;
            }
            bool _4326;
            if (_6361)
            {
                bool _6969 = all(bool2(_9020.x > 0.0f.xx.x, _9020.y > 0.0f.xx.y));
                bool _6975;
                if (_6969)
                {
                    _6975 = all(bool2(_9020.x < 1.0f.xx.x, _9020.y < 1.0f.xx.y));
                }
                else
                {
                    _6975 = _6969;
                }
                _4326 = _6975;
            }
            else
            {
                _4326 = _6361;
            }
            bool _4332;
            if (_6361)
            {
                bool _6980 = all(bool2(_9022.x > 0.0f.xx.x, _9022.y > 0.0f.xx.y));
                bool _6986;
                if (_6980)
                {
                    _6986 = all(bool2(_9022.x < 1.0f.xx.x, _9022.y < 1.0f.xx.y));
                }
                else
                {
                    _6986 = _6980;
                }
                _4332 = _6986;
            }
            else
            {
                _4332 = _6361;
            }
            bool _4338;
            if (_6393)
            {
                bool _6991 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                bool _6997;
                if (_6991)
                {
                    _6997 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                }
                else
                {
                    _6997 = _6991;
                }
                _4338 = _6997;
            }
            else
            {
                _4338 = _6393;
            }
            bool _4344;
            if (_6393)
            {
                bool _7002 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                bool _7008;
                if (_7002)
                {
                    _7008 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                }
                else
                {
                    _7008 = _7002;
                }
                _4344 = _7008;
            }
            else
            {
                _4344 = _6393;
            }
            bool _4347 = _4338 != _4344;
            bool _4353;
            if (_4347)
            {
                _4353 = _4326 || _4332;
            }
            else
            {
                _4353 = _4347;
            }
            float4 _9298;
            if (_4353)
            {
                float4 _8893 = _9218;
                _8893.z = 0.0f;
                _8893.w = 0.0f;
                _9298 = _8893;
            }
            else
            {
                _9298 = _9218;
            }
            bool _4360 = _4326 && _4272;
            bool _4363 = _4332 && _4275;
            float4 _9402;
            float3 _9852;
            if (_4360 || _4363)
            {
                float _9295;
                do
                {
                    uint4 _7147 = r_warped_motion_qdata_tp1.Load(int3(_9050, 0));
                    uint _7148 = _7147.x;
                    if (_7148 != 0u)
                    {
                        float _9294;
                        if (_7148 == 0u)
                        {
                            _9294 = -1.0f;
                        }
                        else
                        {
                            _9294 = float((_7148 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9295 = _9294;
                        break;
                    }
                    int _9277;
                    uint _9278;
                    _9278 = _7148;
                    _9277 = -1;
                    uint _9293;
                    for (; _9277 <= 1; _9278 = _9293, _9277++)
                    {
                        _9293 = _9278;
                        for (int _9291 = -1; _9291 <= 1; )
                        {
                            _9293 = max(_9293, r_warped_motion_qdata_tp1.Load(int3(clamp(_9050 + int2(_9291, _9277), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9291++;
                            continue;
                        }
                    }
                    if (_9278 != 0u)
                    {
                        float _9290;
                        if (_9278 == 0u)
                        {
                            _9290 = -1.0f;
                        }
                        else
                        {
                            _9290 = float((_9278 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9295 = _9290;
                        break;
                    }
                    uint _9280;
                    _9280 = 4294967295u;
                    uint _10589;
                    for (int _9279 = 0; _9279 < 8; _9280 = _10589, _9279++)
                    {
                        int _9283 = 0;
                        for (;;)
                        {
                            if (_9283 < 5)
                            {
                                int2 _7098 = _9050 + (_1085[_9279] * _1094[_9283].xx);
                                bool _7101 = any(bool2(_7098.x < int2(0, 0).x, _7098.y < int2(0, 0).y));
                                bool _7109;
                                if (!_7101)
                                {
                                    _7109 = any(bool2(_7098.x >= cbFI_MvDepthLaneSize.x, _7098.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7109 = _7101;
                                }
                                if (_7109)
                                {
                                    _10589 = _9280;
                                    break;
                                }
                                uint4 _7187 = r_warped_motion_qdata_tp1.Load(int3(_7098, 0));
                                uint _7188 = _7187.x;
                                if (_7188 != 0u)
                                {
                                    _10589 = min(_9280, _7188);
                                    break;
                                }
                                _9283++;
                                continue;
                            }
                            else
                            {
                                _10589 = _9280;
                                break;
                            }
                        }
                    }
                    float _9282;
                    if (_9280 == 4294967295u)
                    {
                        _9282 = -1.0f;
                    }
                    else
                    {
                        float _9281;
                        if (_9280 == 0u)
                        {
                            _9281 = -1.0f;
                        }
                        else
                        {
                            _9281 = float((_9280 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9282 = _9281;
                    }
                    _9295 = _9282;
                    break;
                } while(false);
                bool _4371 = _9295 < 0.0f;
                uint _7209_dummy_parameter;
                uint _7241_dummy_parameter;
                float4 _9331;
                if ((_4371 && _4360) && _4363)
                {
                    uint _7273_dummy_parameter;
                    float _7297 = log(((r_depth_tm1.Load(int3(int2(floor(_9020 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7273_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7305_dummy_parameter;
                    float _7329 = log(((r_depth_tp1.Load(int3(int2(floor(_9022 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7305_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9332;
                    if (_7297 > (_7329 + 0.07999999821186065673828125f))
                    {
                        float4 _8897 = _9298;
                        _8897.x = 0.0f;
                        _9332 = _8897;
                    }
                    else
                    {
                        float4 _9333;
                        if (_7329 > (_7297 + 0.07999999821186065673828125f))
                        {
                            float4 _8899 = _9298;
                            _8899.y = 0.0f;
                            _9333 = _8899;
                        }
                        else
                        {
                            _9333 = _9298;
                        }
                        _9332 = _9333;
                    }
                    _9331 = _9332;
                }
                else
                {
                    _9331 = _9298;
                }
                float _4413 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4415 = _9295 >= 0.0f;
                float _9314;
                if (_4415)
                {
                    _9314 = _9295 - _4413;
                }
                else
                {
                    float _9310;
                    if (_4360)
                    {
                        float _9309;
                        _9309 = 2.0f;
                        float _7387;
                        for (int _9308 = 0; _9308 < 24; _9309 = _7387, _9308++)
                        {
                            float _7351 = float(_9308 & 7) * 0.785398185253143310546875f;
                            int _7353 = _9308 >> 3;
                            int _9311;
                            if (_7353 == 0)
                            {
                                _9311 = 16;
                            }
                            else
                            {
                                _9311 = (_7353 == 1) ? 48 : 96;
                            }
                            uint _7403_dummy_parameter;
                            _7387 = min(_9309, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9020 + ((cbFI_MvDepthLaneSizeRcp * float(_9311)) * float2(cos(_7351), sin(_7351))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7403_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9310 = _9309;
                    }
                    else
                    {
                        _9310 = 0.0f;
                    }
                    _9314 = _9310;
                }
                float _9321;
                if (_4415)
                {
                    _9321 = _9295 - _4413;
                }
                else
                {
                    float _9317;
                    if (_4363)
                    {
                        float _9316;
                        _9316 = 2.0f;
                        float _7501;
                        for (int _9315 = 0; _9315 < 24; _9316 = _7501, _9315++)
                        {
                            float _7465 = float(_9315 & 7) * 0.785398185253143310546875f;
                            int _7467 = _9315 >> 3;
                            int _9318;
                            if (_7467 == 0)
                            {
                                _9318 = 16;
                            }
                            else
                            {
                                _9318 = (_7467 == 1) ? 48 : 96;
                            }
                            uint _7533_dummy_parameter;
                            _7501 = min(_9316, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9022 + ((cbFI_MvDepthLaneSizeRcp * float(_9318)) * float2(cos(_7465), sin(_7465))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7533_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9317 = _9316;
                    }
                    else
                    {
                        _9317 = 0.0f;
                    }
                    _9321 = _9317;
                }
                float _9322;
                if (_4360)
                {
                    uint _7565_dummy_parameter;
                    _9322 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9020 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7565_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9322 = 0.0f;
                }
                float _9323;
                if (_4363)
                {
                    uint _7585_dummy_parameter;
                    _9323 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9022 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7585_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9323 = 0.0f;
                }
                bool _4470;
                if (_4360)
                {
                    _4470 = _9322 > ((exp((_9314 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4470 = _4360;
                }
                float4 _9339;
                if (_4470)
                {
                    float4 _8901 = _9331;
                    _8901.x = 0.0f;
                    _9339 = _8901;
                }
                else
                {
                    _9339 = _9331;
                }
                bool _4482;
                if (_4363)
                {
                    _4482 = _9323 > ((exp((_9321 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4482 = _4363;
                }
                float4 _9341;
                if (_4482)
                {
                    float4 _8903 = _9339;
                    _8903.y = 0.0f;
                    _9341 = _8903;
                }
                else
                {
                    _9341 = _9339;
                }
                float4 _9403;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4415)
                {
                    bool _4502;
                    if (_4360)
                    {
                        _4502 = _9322 < ((exp((_9314 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4502 = _4360;
                    }
                    float4 _9343;
                    if (_4502)
                    {
                        float4 _8905 = _9341;
                        _8905.x = 0.0f;
                        _9343 = _8905;
                    }
                    else
                    {
                        _9343 = _9341;
                    }
                    bool _4514;
                    if (_4363)
                    {
                        _4514 = _9323 < ((exp((_9321 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4514 = _4363;
                    }
                    float4 _9404;
                    if (_4514)
                    {
                        float4 _8907 = _9343;
                        _8907.y = 0.0f;
                        _9404 = _8907;
                    }
                    else
                    {
                        _9404 = _9343;
                    }
                    _9403 = _9404;
                }
                else
                {
                    _9403 = _9341;
                }
                _9852 = float3(float(_4371), log(((r_depth_tm1.Load(int3(int2(floor(_9020 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7209_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9022 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7241_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9402 = _9403;
            }
            else
            {
                _9852 = float3(0.0f, 0.0f, 0.5f);
                _9402 = _9298;
            }
            bool _4525 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4284;
            bool _4531;
            if (_4525)
            {
                _4531 = _4338 || _4344;
            }
            else
            {
                _4531 = _4525;
            }
            float4 _9424;
            if (_4531)
            {
                float _9397;
                do
                {
                    uint4 _7765 = r_warped_motion_qdata_tp1.Load(int3(_9050, 0));
                    uint _7766 = _7765.x;
                    if (_7766 != 0u)
                    {
                        float _9396;
                        if (_7766 == 0u)
                        {
                            _9396 = -1.0f;
                        }
                        else
                        {
                            _9396 = float((_7766 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9397 = _9396;
                        break;
                    }
                    int _9379;
                    uint _9380;
                    _9380 = _7766;
                    _9379 = -1;
                    uint _9395;
                    for (; _9379 <= 1; _9380 = _9395, _9379++)
                    {
                        _9395 = _9380;
                        for (int _9393 = -1; _9393 <= 1; )
                        {
                            _9395 = max(_9395, r_warped_motion_qdata_tp1.Load(int3(clamp(_9050 + int2(_9393, _9379), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9393++;
                            continue;
                        }
                    }
                    if (_9380 != 0u)
                    {
                        float _9392;
                        if (_9380 == 0u)
                        {
                            _9392 = -1.0f;
                        }
                        else
                        {
                            _9392 = float((_9380 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9397 = _9392;
                        break;
                    }
                    uint _9382;
                    _9382 = 4294967295u;
                    uint _10590;
                    for (int _9381 = 0; _9381 < 8; _9382 = _10590, _9381++)
                    {
                        int _9385 = 0;
                        for (;;)
                        {
                            if (_9385 < 5)
                            {
                                int2 _7716 = _9050 + (_1085[_9381] * _1094[_9385].xx);
                                bool _7719 = any(bool2(_7716.x < int2(0, 0).x, _7716.y < int2(0, 0).y));
                                bool _7727;
                                if (!_7719)
                                {
                                    _7727 = any(bool2(_7716.x >= cbFI_MvDepthLaneSize.x, _7716.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7727 = _7719;
                                }
                                if (_7727)
                                {
                                    _10590 = _9382;
                                    break;
                                }
                                uint4 _7805 = r_warped_motion_qdata_tp1.Load(int3(_7716, 0));
                                uint _7806 = _7805.x;
                                if (_7806 != 0u)
                                {
                                    _10590 = min(_9382, _7806);
                                    break;
                                }
                                _9385++;
                                continue;
                            }
                            else
                            {
                                _10590 = _9382;
                                break;
                            }
                        }
                    }
                    float _9384;
                    if (_9382 == 4294967295u)
                    {
                        _9384 = -1.0f;
                    }
                    else
                    {
                        float _9383;
                        if (_9382 == 0u)
                        {
                            _9383 = -1.0f;
                        }
                        else
                        {
                            _9383 = float((_9382 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9384 = _9383;
                    }
                    _9397 = _9384;
                    break;
                } while(false);
                float4 _9425;
                if (_9397 >= 0.0f)
                {
                    float _7827 = (exp((_9397 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4550;
                    if (_4338)
                    {
                        uint _7834_dummy_parameter;
                        _4550 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7834_dummy_parameter))))), 0)).x) > _7827;
                    }
                    else
                    {
                        _4550 = _4338;
                    }
                    float4 _9415;
                    if (_4550)
                    {
                        float4 _8909 = _9402;
                        _8909.z = 0.0f;
                        _9415 = _8909;
                    }
                    else
                    {
                        _9415 = _9402;
                    }
                    bool _4562;
                    if (_4344)
                    {
                        uint _7854_dummy_parameter;
                        _4562 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7854_dummy_parameter))))), 0)).x) > _7827;
                    }
                    else
                    {
                        _4562 = _4344;
                    }
                    float4 _9426;
                    if (_4562)
                    {
                        float4 _8911 = _9415;
                        _8911.w = 0.0f;
                        _9426 = _8911;
                    }
                    else
                    {
                        _9426 = _9415;
                    }
                    _9425 = _9426;
                }
                else
                {
                    _9425 = _9402;
                }
                _9424 = _9425;
            }
            else
            {
                _9424 = _9402;
            }
            bool _4570 = _4326 != _4332;
            bool _4577;
            if (_4570)
            {
                _4577 = _4326 ? _4272 : _4275;
            }
            else
            {
                _4577 = _4570;
            }
            float4 _9507;
            if (_4577)
            {
                bool2 _4582 = _4326.xx;
                float2 _4583 = float2(_4582.x ? _9020.x : _9022.x, _4582.y ? _9020.y : _9022.y);
                float _9417;
                if (_4326)
                {
                    uint _7874_dummy_parameter;
                    _9417 = r_depth_tm1.Load(int3(int2(floor(_4583 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7874_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7890_dummy_parameter;
                    _9417 = r_depth_tp1.Load(int3(int2(floor(_4583 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7890_dummy_parameter))))), 0)).x;
                }
                float4x4 _9418;
                if (_4326)
                {
                    _9418 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9418 = cbFI_MotionTP1ToTM1;
                }
                float2 _9419;
                do
                {
                    float _7917 = _4583.x;
                    float _7920 = 1.0f - _4583.y;
                    float4 _7931 = mul(float4((float2(_7917, _7920) * 2.0f) - 1.0f.xx, _9417, 1.0f), _9418);
                    float _7933 = _7931.w;
                    if (!(_7933 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9419 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7946 = ((_7931.xy / _7933.xx) + 1.0f.xx) * 0.5f;
                    _9419 = float2(_7946.x - _7917, _7920 - _7946.y);
                    break;
                } while(false);
                float2 _4613 = float2(cbFI_DisplaySize);
                float4 _9508;
                if (!(length(((_4583 + _9419) - float2(_4582.x ? _9022.x : _9020.x, _4582.y ? _9022.y : _9020.y)) * _4613) <= ((0.100000001490116119384765625f * length(_9419 * _4613)) + 8.0f)))
                {
                    float4 _9509;
                    if (_4326)
                    {
                        float4 _8921 = _9424;
                        _8921.x = 0.0f;
                        _9509 = _8921;
                    }
                    else
                    {
                        float4 _8923 = _9424;
                        _8923.y = 0.0f;
                        _9509 = _8923;
                    }
                    _9508 = _9509;
                }
                else
                {
                    _9508 = _9424;
                }
                _9507 = _9508;
            }
            else
            {
                _9507 = _9424;
            }
            float4 _4638 = _9199 * _9507;
            float _4640 = dot(_4638, 1.0f.xxxx);
            float4 _9684;
            bool _9704;
            if (_4640 > 0.0f)
            {
                _9704 = _9169;
                _9684 = _4638 / _4640.xxxx;
            }
            else
            {
                bool _4651 = any(bool4(_9507.x < 1.0f.xxxx.x, _9507.y < 1.0f.xxxx.y, _9507.z < 1.0f.xxxx.z, _9507.w < 1.0f.xxxx.w));
                if (_4651)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7968;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7968);
                    }
                }
                bool4 _10620 = _4651.xxxx;
                _9704 = _4651 ? true : _9169;
                _9684 = float4(_10620.x ? 0.0f.xxxx.x : _9199.x, _10620.y ? 0.0f.xxxx.y : _9199.y, _10620.z ? 0.0f.xxxx.z : _9199.z, _10620.w ? 0.0f.xxxx.w : _9199.w);
            }
            _9815 = _9852;
            _9703 = _9704;
            _9683 = _9684;
        }
        else
        {
            _9815 = float3(0.0f, 0.0f, 0.5f);
            _9703 = _9169;
            _9683 = _9199;
        }
        uint _4660 = (cbFI_pad0 >> 24u) & 31u;
        uint _4664 = (cbFI_pad0 >> 16u) & 255u;
        bool _4666 = _4660 != 0u;
        bool _4668 = _4664 == 12u;
        bool _4671 = _4664 == 13u;
        float4 _9700;
        if ((_4666 || _4668) || _4671)
        {
            float _9510;
            do
            {
                bool _8052 = all(bool2(_9023.x > 0.0f.xx.x, _9023.y > 0.0f.xx.y));
                bool _8058;
                if (_8052)
                {
                    _8058 = all(bool2(_9023.x < 1.0f.xx.x, _9023.y < 1.0f.xx.y));
                }
                else
                {
                    _8058 = _8052;
                }
                bool _7989 = !_8058;
                bool _7996;
                if (!_7989)
                {
                    bool _8063 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
                    bool _8069;
                    if (_8063)
                    {
                        _8069 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8069 = _8063;
                    }
                    _7996 = !_8069;
                }
                else
                {
                    _7996 = _7989;
                }
                if (_7996)
                {
                    _9510 = 0.0f;
                    break;
                }
                uint _8076_dummy_parameter;
                uint _8092_dummy_parameter;
                float4 _8017 = mul(float4((float2(_9023.x, 1.0f - _9023.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9023 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8076_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8019 = _8017.w;
                if (abs(_8019) < 9.9999999747524270787835121154785e-07f)
                {
                    _9510 = 0.0f;
                    break;
                }
                float _8030 = abs(cbFI_DeviceToViewDepth.y / ((_8017.z / _8019) - cbFI_DeviceToViewDepth.x));
                float _8033 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8092_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9510 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8030 - _8033) / max(max(_8030, _8033), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8140 = all(bool2(_9024.x > 0.0f.xx.x, _9024.y > 0.0f.xx.y));
            bool _8146;
            if (_8140)
            {
                _8146 = all(bool2(_9024.x < 1.0f.xx.x, _9024.y < 1.0f.xx.y));
            }
            else
            {
                _8146 = _8140;
            }
            float _9511;
            if (_8146)
            {
                uint _8153_dummy_parameter;
                _9511 = length((_5447 + (r_motion_tp1.Load(int3(int2(floor(_9024 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8153_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9511 = 1000000.0f;
            }
            float _9522;
            if ((_4660 & 1u) != 0u)
            {
                _9522 = _9510;
            }
            else
            {
                _9522 = 1.0f;
            }
            float _9523;
            if ((_4660 & 2u) != 0u)
            {
                _9523 = _9522 * (1.0f - smoothstep(2.0f, 8.0f, _9511));
            }
            else
            {
                _9523 = _9522;
            }
            float _9524;
            if ((_4660 & 4u) != 0u)
            {
                _9524 = _9523 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6168 - _6176) - length(_6152 - _6160))));
            }
            else
            {
                _9524 = _9523;
            }
            float _9694;
            if ((_4660 & 8u) != 0u)
            {
                _9694 = lerp(1.0f, _9524, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6152 - _6160)));
            }
            else
            {
                _9694 = _9524;
            }
            bool _4746 = (_4660 & 16u) != 0u;
            bool _4755;
            if (_4746)
            {
                _4755 = length(_9018 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4755 = _4746;
            }
            float _10622 = _4755 ? 1.0f : _9694;
            bool _4761 = _4666 && _6361;
            bool _4766;
            if (_4761)
            {
                bool _8178 = all(bool2(_9020.x > 0.0f.xx.x, _9020.y > 0.0f.xx.y));
                bool _8184;
                if (_8178)
                {
                    _8184 = all(bool2(_9020.x < 1.0f.xx.x, _9020.y < 1.0f.xx.y));
                }
                else
                {
                    _8184 = _8178;
                }
                _4766 = _8184;
            }
            else
            {
                _4766 = _4761;
            }
            bool _4771;
            if (_4766)
            {
                bool _8189 = all(bool2(_9022.x > 0.0f.xx.x, _9022.y > 0.0f.xx.y));
                bool _8195;
                if (_8189)
                {
                    _8195 = all(bool2(_9022.x < 1.0f.xx.x, _9022.y < 1.0f.xx.y));
                }
                else
                {
                    _8195 = _8189;
                }
                _4771 = _8195;
            }
            else
            {
                _4771 = _4766;
            }
            float4 _9701;
            if (_4771)
            {
                float _4777 = _9683.x + _9683.y;
                float _4786 = (_9683.z + _9683.w) * (1.0f - _10622);
                float _9697;
                if (_4777 > 9.9999997473787516355514526367188e-06f)
                {
                    _9697 = _9683.x / _4777;
                }
                else
                {
                    _9697 = _3944;
                }
                _9701 = float4(_9683.x + (_4786 * _9697), _9683.y + (_4786 * (1.0f - _9697)), _9683.zw * _10622);
            }
            else
            {
                _9701 = _9683;
            }
            _9700 = _9701;
        }
        else
        {
            _9700 = _9683;
        }
        float3 _10393;
        if (_9703)
        {
            float3 _8201 = r_current_interpolation_source.Load(int3(_3358, 0)).xyz;
            float3 _10394;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6361)
            {
                uint _8208_dummy_parameter;
                float _9806;
                _9806 = r_depth_tm1.Load(int3(int2(floor(_9020 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8208_dummy_parameter))))), 0)).x;
                float _4898;
                for (int _9805 = 0; _9805 < 24; _9806 = _4898, _9805++)
                {
                    float _4870 = float(_9805 & 7) * 0.785398185253143310546875f;
                    int _4872 = _9805 >> 3;
                    int _10444;
                    if (_4872 == 0)
                    {
                        _10444 = 16;
                    }
                    else
                    {
                        _10444 = (_4872 == 1) ? 48 : 96;
                    }
                    uint _8228_dummy_parameter;
                    _4898 = max(_9806, r_depth_tm1.Load(int3(int2(floor(clamp(_9020 + ((cbFI_MvDepthLaneSizeRcp * float(_10444)) * float2(cos(_4870), sin(_4870))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8228_dummy_parameter))))), 0)).x);
                }
                float2 _9807;
                do
                {
                    float _8250 = 1.0f - _9020.y;
                    float4 _8261 = mul(float4((float2(_9020.x, _8250) * 2.0f) - 1.0f.xx, _9806, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8263 = _8261.w;
                    if (!(_8263 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9807 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8276 = ((_8261.xy / _8263.xx) + 1.0f.xx) * 0.5f;
                    _9807 = float2(_8276.x - _9020.x, _8250 - _8276.y);
                    break;
                } while(false);
                float2 _4909 = _9020 + _9807;
                bool _8294 = all(bool2(_4909.x > 0.0f.xx.x, _4909.y > 0.0f.xx.y));
                bool _8300;
                if (_8294)
                {
                    _8300 = all(bool2(_4909.x < 1.0f.xx.x, _4909.y < 1.0f.xx.y));
                }
                else
                {
                    _8300 = _8294;
                }
                float3 _10395;
                if (_8300)
                {
                    float _4915 = abs(cbFI_DeviceToViewDepth.y / (_9806 - cbFI_DeviceToViewDepth.x));
                    uint _8320_dummy_parameter;
                    int2 _8320 = int2(spvTextureSize(r_depth_m2, uint(0), _8320_dummy_parameter));
                    float _4919 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4909 * float2(_8320))), int2(0, 0), _8320 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10400;
                    if (abs(_4919 - _4915) <= (0.20000000298023223876953125f * max(_4919, _4915)))
                    {
                        uint _8354_dummy_parameter;
                        int2 _8354 = int2(spvTextureSize(r_colour_m2, uint(0), _8354_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8377;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8377);
                        }
                        _10400 = r_colour_m2.Load(int3(clamp(int2(floor(_4909 * float2(_8354))), int2(0, 0), _8354 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8387;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8387);
                        }
                        _10400 = _8201;
                    }
                    _10395 = _10400;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8397;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8397);
                    }
                    _10395 = _8201;
                }
                _10394 = _10395;
            }
            else
            {
                _10394 = _8201;
            }
            _10393 = _10394;
        }
        else
        {
            _10393 = (((_6152 * _9700.x) + (_6160 * _9700.y)) + (_6168 * _9700.z)) + (_6176 * _9700.w);
        }
        uint _4947 = cbFI_pad0 & 255u;
        bool _10286;
        float3 _10392;
        if (_4947 != 0u)
        {
            float3 _4952 = r_present_backbuffer.Load(int3(_3358, 0)).xyz;
            float3 _4956 = r_current_interpolation_source.Load(int3(_3358, 0)).xyz;
            float3 _4960 = abs(_4952 - _4956);
            float3 _9810;
            if (_4947 == 2u)
            {
                _9810 = (abs(_4956) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9810 = 0.000244140625f.xxx;
            }
            bool _4976 = any(bool3(_4960.x > _9810.x, _4960.y > _9810.y, _4960.z > _9810.z));
            bool3 _10623 = _4976.xxx;
            _10392 = float3(_10623.x ? _4952.x : _10393.x, _10623.y ? _4952.y : _10393.y, _10623.z ? _4952.z : _10393.z);
            _10286 = _4976;
        }
        else
        {
            _10392 = _10393;
            _10286 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8412;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8412);
        }
        float3 _10375;
        if (_4664 == 1u)
        {
            _10375 = lerp(_6152, _6160, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10376;
            if (_4664 == 2u)
            {
                _10376 = lerp(_6168, _6176, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10377;
                if (_4664 == 3u)
                {
                    _10377 = float(_10286).xxx;
                }
                else
                {
                    float3 _10378;
                    if (_4664 == 4u)
                    {
                        _10378 = float3(((_9018 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10379;
                        if (_4664 == 5u)
                        {
                            _10379 = float3(((_5447 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10380;
                            if (_4664 == 6u)
                            {
                                _10380 = float3(_9700.xy, _9700.z + _9700.w);
                            }
                            else
                            {
                                float3 _10381;
                                if (_4664 == 7u)
                                {
                                    _10381 = r_current_interpolation_source.Load(int3(_3358, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10382;
                                    if (_4664 == 8u)
                                    {
                                        _10382 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3719, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10383;
                                        if (_4668)
                                        {
                                            uint _8434_dummy_parameter;
                                            uint _8466_dummy_parameter;
                                            _10383 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3719 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8434_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3719 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8466_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10384;
                                            if (_4671)
                                            {
                                                _10384 = _6168;
                                            }
                                            else
                                            {
                                                float3 _10385;
                                                if (_4664 == 20u)
                                                {
                                                    _10385 = _6152;
                                                }
                                                else
                                                {
                                                    float3 _10386;
                                                    if (_4664 == 21u)
                                                    {
                                                        _10386 = _6160;
                                                    }
                                                    else
                                                    {
                                                        float3 _10387;
                                                        if (_4664 == 22u)
                                                        {
                                                            _10387 = _6176;
                                                        }
                                                        else
                                                        {
                                                            float3 _10388;
                                                            if (_4664 == 18u)
                                                            {
                                                                _10388 = _10095;
                                                            }
                                                            else
                                                            {
                                                                float3 _10389;
                                                                if (_4664 == 19u)
                                                                {
                                                                    _10389 = _9952;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10625 = (_4664 == 23u).xxx;
                                                                    _10389 = float3(_10625.x ? _9815.x : _10392.x, _10625.y ? _9815.y : _10392.y, _10625.z ? _9815.z : _10392.z);
                                                                }
                                                                _10388 = _10389;
                                                            }
                                                            _10387 = _10388;
                                                        }
                                                        _10386 = _10387;
                                                    }
                                                    _10385 = _10386;
                                                }
                                                _10384 = _10385;
                                            }
                                            _10383 = _10384;
                                        }
                                        _10382 = _10383;
                                    }
                                    _10381 = _10382;
                                }
                                _10380 = _10381;
                            }
                            _10379 = _10380;
                        }
                        _10378 = _10379;
                    }
                    _10377 = _10378;
                }
                _10376 = _10377;
            }
            _10375 = _10376;
        }
        float3 _10374;
        if ((_4664 >= 9u) && (_4664 <= 11u))
        {
            uint _5140 = 64u + uint((_9050.y * cbFI_MvDepthLaneSize.x) + _9050.x);
            uint _5144 = rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) & 15u;
            float3 _10405;
            if (_4664 == 10u)
            {
                float3 _10373;
                if ((rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) & 32u) != 0u)
                {
                    _10373 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10372;
                    if ((rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) & 16u) != 0u)
                    {
                        _10372 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5165 = ((rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) & 64u) != 0u).xxx;
                        _10372 = float3(_5165.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5165.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5165.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10373 = _10372;
                }
                _10405 = _10373;
            }
            else
            {
                float3 _10406;
                if (_4664 == 11u)
                {
                    uint _5178 = (rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) >> 8u) & 15u;
                    uint _5181 = (rw_nfru_diagnostics.Load<uint>(_5140 * 4 + 0) >> 12u) & 15u;
                    float3 _10365;
                    if ((_5144 == 2u) || (_5144 == 3u))
                    {
                        _10365 = _3071[_5144];
                    }
                    else
                    {
                        bool _5193 = _5178 == 3u;
                        bool _5195 = _5181 == 3u;
                        float3 _10366;
                        if (_5193 && _5195)
                        {
                            _10366 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10367;
                            if (_5193)
                            {
                                _10367 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10368;
                                if (_5195)
                                {
                                    _10368 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10369;
                                    if ((_5178 == 4u) || (_5181 == 4u))
                                    {
                                        _10369 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10370;
                                        if ((_5178 == 1u) || (_5181 == 1u))
                                        {
                                            _10370 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10627 = (_5144 == 1u).xxx;
                                            _10370 = float3(_10627.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10627.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10627.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10369 = _10370;
                                    }
                                    _10368 = _10369;
                                }
                                _10367 = _10368;
                            }
                            _10366 = _10367;
                        }
                        _10365 = _10366;
                    }
                    _10406 = _10365;
                }
                else
                {
                    _10406 = _3071[min(_5144, 7u)];
                }
                _10405 = _10406;
            }
            _10374 = _10405;
        }
        else
        {
            _10374 = _10375;
        }
        float4 _10409;
        if ((_4664 >= 14u) && (_4664 <= 16u))
        {
            float2 _10407;
            if (_4664 == 14u)
            {
                uint _5251_dummy_parameter;
                uint _5257_dummy_parameter;
                _10407 = r_flow_tm1.Load(int3(clamp(int2(floor(_3719 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5251_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5257_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10408;
                if (_4664 == 16u)
                {
                    uint _8517 = r_warped_flow_qdata_tm1.Load(int3(_3735, 0)).x & 2147483647u;
                    uint _8549 = uint(max((int((_8517 >> 16u) & 15u) - 6), 0));
                    _10408 = ((float2(float((1 - (2 * int((_8517 >> 15u) & 1u))) * int(((_8517 >> uint(7)) & 127u) << _8549)), float((1 - (2 * int((_8517 >> 14u) & 1u))) * int((_8517 & 127u) << _8549))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10408 = _5447 * float2(cbFI_DisplaySize);
                }
                _10407 = _10408;
            }
            uint2 _5290 = uint2(clamp(round(_10407 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5292 = _5290.x;
            uint _5299 = _5290.y;
            _10409 = float4(float(_5292 & 255u), float((_5292 >> 8u) | ((_5299 & 15u) << 4u)), float(_5299 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10410;
            if (_4664 == 17u)
            {
                _10410 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3735, 0)).x != 0u), _4078, 0.0f, 1.0f);
            }
            else
            {
                _10410 = float4(_10374, 1.0f);
            }
            _10409 = _10410;
        }
        rw_output[_3358] = _10409.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5343 = ((uint(_3358.y) * uint(cbFI_DisplaySize.x)) + uint(_3358.x)) * 6u;
            uint _8595 = spvPackHalf2x16(clamp(_6151.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5343 * 4 + 0, (((_8595 & 32767u) >> 4u) | ((((_8595 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6151.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8630 = spvPackHalf2x16(clamp(_6159.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5343 + 1u) * 4 + 0, (((_8630 & 32767u) >> 4u) | ((((_8630 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6159.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8665 = spvPackHalf2x16(clamp(_6167.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5343 + 2u) * 4 + 0, (((_8665 & 32767u) >> 4u) | ((((_8665 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6167.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8700 = spvPackHalf2x16(clamp(_6175.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5343 + 3u) * 4 + 0, (((_8700 & 32767u) >> 4u) | ((((_8700 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6175.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8727 = r_current_interpolation_source.Load(int3(_3358, 0));
            uint _8741 = spvPackHalf2x16(clamp(_8727.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5343 + 4u) * 4 + 0, (((_8741 & 32767u) >> 4u) | ((((_8741 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8727.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10443;
            if (_10286 || (_4664 != 0u))
            {
                _10443 = 4294967295u;
            }
            else
            {
                uint _8776 = spvPackHalf2x16(clamp(_10409.xy, 0.0f.xx, 65000.0f.xx));
                _10443 = (((_8776 & 32767u) >> 4u) | ((((_8776 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10409.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5343 + 5u) * 4 + 0, _10443);
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
