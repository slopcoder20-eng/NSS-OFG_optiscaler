static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3101[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3405 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3405.x >= cbFI_DisplaySize.x, _3405.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3405] = float4(r_present_backbuffer.Load(int3(_3405, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3405] = float4(r_current_interpolation_source.Load(int3(_3405, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3780 = (float2(_3405) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3791 = int2(floor(_3780 * float2(cbFI_MvDepthLaneSize)));
        int2 _3796 = int2(floor(_3780 * float2(cbFI_FlowLaneSize)));
        float4 _5536 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3780 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5542 = r_warped_filled_flow_tm1.Load(int3(_3796, 0)).xy;
        float2 _5548 = r_warped_filled_motion_tp1.Load(int3(_3791, 0)).xy;
        bool _5570 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9102;
        if (_5570)
        {
            float _5583 = ((2.0f * _3780.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9102 = float2(atan(_5583) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3780.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5583 * _5583))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9102 = _3780;
        }
        bool _3817 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9123;
        bool _9144;
        int2 _9155;
        float3 _10207;
        if (_3817)
        {
            float _9104;
            float _9106;
            _9106 = 2.0f;
            _9104 = -1.0f;
            uint _3469[9];
            float _10598;
            float _10601;
            for (int _9103 = 0; _9103 < 9; _9106 = _10601, _9104 = _10598, _9103++)
            {
                _3469[_9103] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3791 + int2((_9103 % 3) - 1, (_9103 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3469[_9103] != 0u)
                {
                    float _10593;
                    if (_3469[_9103] == 0u)
                    {
                        _10593 = -1.0f;
                    }
                    else
                    {
                        _10593 = float((_3469[_9103] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10601 = min(_9106, _10593);
                    _10598 = max(_9104, _10593);
                }
                else
                {
                    _10601 = _9106;
                    _10598 = _9104;
                }
            }
            float _3863 = float(_9104 >= 0.0f);
            float3 _8913 = 0.0f.xxx;
            _8913.y = _3863;
            float2 _9124;
            bool _9145;
            int2 _9156;
            float3 _10208;
            if ((_9104 - _9106) > 0.0199999995529651641845703125f)
            {
                float _9112;
                int2 _9113;
                float2 _9114;
                int2 _9116;
                float2 _9122;
                _9122 = _5548;
                _9116 = _3791;
                _9114 = _5548;
                _9113 = _3791;
                _9112 = -1.0f;
                float _10606;
                int2 _10610;
                float2 _10621;
                int2 _10632;
                float2 _10665;
                float _10711;
                int _9111 = 0;
                float _10574 = 1000000000.0f;
                for (; _9111 < 9; _10574 = _10711, _9122 = _10665, _9116 = _10632, _9114 = _10621, _9113 = _10610, _9112 = _10606, _9111++)
                {
                    if (_3469[_9111] == 0u)
                    {
                        _10711 = _10574;
                        _10665 = _9122;
                        _10632 = _9116;
                        _10621 = _9114;
                        _10610 = _9113;
                        _10606 = _9112;
                        continue;
                    }
                    int2 _3898 = clamp(_3791 + int2((_9111 % 3) - 1, (_9111 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5658 = _3469[_9111] & 2147483647u;
                    uint _5690 = uint(max((int((_5658 >> 16u) & 15u) - 6), 0));
                    float2 _3904 = (float2(float((1 - (2 * int((_5658 >> 15u) & 1u))) * int(((_5658 >> uint(7)) & 127u) << _5690)), float((1 - (2 * int((_5658 >> 14u) & 1u))) * int((_5658 & 127u) << _5690))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10560;
                    if (_3469[_9111] == 0u)
                    {
                        _10560 = -1.0f;
                    }
                    else
                    {
                        _10560 = float((_3469[_9111] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3909 = _10560 - 0.100000001490116119384765625f;
                    float2 _10561;
                    if (_5570)
                    {
                        float2 _5767 = clamp((((_9102 + (_3904 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5770 = tan(_5767.x);
                        _10561 = (float2(_5770 / cbFI_DeviceToViewDepth.z, (tan(_5767.y) * sqrt(1.0f + (_5770 * _5770))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10561 = _9102 + (_3904 * cbFI_Timestep);
                    }
                    float _3916 = cbFI_Timestep - 1.0f;
                    float2 _10562;
                    if (_5570)
                    {
                        float2 _5838 = clamp((((_9102 + (_3904 * _3916)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5841 = tan(_5838.x);
                        _10562 = (float2(_5841 / cbFI_DeviceToViewDepth.z, (tan(_5838.y) * sqrt(1.0f + (_5841 * _5841))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10562 = _9102 + (_3904 * _3916);
                    }
                    bool _5874 = all(bool2(_10561.x > 0.0f.xx.x, _10561.y > 0.0f.xx.y));
                    bool _5880;
                    if (_5874)
                    {
                        _5880 = all(bool2(_10561.x < 1.0f.xx.x, _10561.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5880 = _5874;
                    }
                    float _10565;
                    if (_5880)
                    {
                        uint _5887_dummy_parameter;
                        _10565 = max((_3909 - (log(((r_depth_tm1.Load(int3(int2(floor(_10561 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5887_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10565 = 0.0f;
                    }
                    bool _5917 = all(bool2(_10562.x > 0.0f.xx.x, _10562.y > 0.0f.xx.y));
                    bool _5923;
                    if (_5917)
                    {
                        _5923 = all(bool2(_10562.x < 1.0f.xx.x, _10562.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5923 = _5917;
                    }
                    float _10566;
                    if (_5923)
                    {
                        uint _5930_dummy_parameter;
                        _10566 = _10565 + max((_3909 - (log(((r_depth_tp1.Load(int3(int2(floor(_10562 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5930_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10566 = _10565;
                    }
                    float _10607;
                    int2 _10611;
                    float2 _10622;
                    int2 _10633;
                    float2 _10666;
                    float _10712;
                    if (_10566 == 0.0f)
                    {
                        bool _3951 = _3909 > _9112;
                        bool2 _10720 = _3951.xx;
                        _10712 = _10574;
                        _10666 = float2(_10720.x ? _3904.x : _9122.x, _10720.y ? _3904.y : _9122.y);
                        _10633 = int2(_10720.x ? _3898.x : _9116.x, _10720.y ? _3898.y : _9116.y);
                        _10622 = _9114;
                        _10611 = _9113;
                        _10607 = _3951 ? _3909 : _9112;
                    }
                    else
                    {
                        bool _3960 = _10566 < _10574;
                        bool2 _10716 = _3960.xx;
                        _10712 = _3960 ? _10566 : _10574;
                        _10666 = _9122;
                        _10633 = _9116;
                        _10622 = float2(_10716.x ? _3904.x : _9114.x, _10716.y ? _3904.y : _9114.y);
                        _10611 = int2(_10716.x ? _3898.x : _9113.x, _10716.y ? _3898.y : _9113.y);
                        _10607 = _9112;
                    }
                    _10711 = _10712;
                    _10665 = _10666;
                    _10632 = _10633;
                    _10621 = _10622;
                    _10610 = _10611;
                    _10606 = _10607;
                }
                bool _3972 = _9112 < 0.0f;
                bool2 _10726 = _3972.xx;
                int2 _10729 = int2(_10726.x ? _9113.x : _9116.x, _10726.y ? _9113.y : _9116.y);
                _10208 = float3(1.0f, _3863, float(any(bool2(_10729.x != _3791.x, _10729.y != _3791.y))));
                _9156 = _10729;
                _9145 = _3972 ? false : true;
                _9124 = float2(_10726.x ? _9114.x : _9122.x, _10726.y ? _9114.y : _9122.y);
            }
            else
            {
                _10208 = _8913;
                _9156 = _3791;
                _9145 = false;
                _9124 = _5548;
            }
            _10207 = _10208;
            _9155 = _9156;
            _9144 = _9145;
            _9123 = _9124;
        }
        else
        {
            _10207 = 0.0f.xxx;
            _9155 = _3791;
            _9144 = false;
            _9123 = _5548;
        }
        float2 _9125;
        if (_5570)
        {
            float2 _5995 = clamp((((_9102 + (_9123 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5998 = tan(_5995.x);
            _9125 = (float2(_5998 / cbFI_DeviceToViewDepth.z, (tan(_5995.y) * sqrt(1.0f + (_5998 * _5998))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9125 = _9102 + (_9123 * cbFI_Timestep);
        }
        float _3995 = cbFI_Timestep - 1.0f;
        float2 _9127;
        if (_5570)
        {
            float2 _6066 = clamp((((_9102 + (_9123 * _3995)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6069 = tan(_6066.x);
            _9127 = (float2(_6069 / cbFI_DeviceToViewDepth.z, (tan(_6066.y) * sqrt(1.0f + (_6069 * _6069))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9127 = _9102 + (_9123 * _3995);
        }
        float _4000 = -cbFI_Timestep;
        float2 _9128;
        if (_5570)
        {
            float2 _6137 = clamp((((_9102 + (_5542 * _4000)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6140 = tan(_6137.x);
            _9128 = (float2(_6140 / cbFI_DeviceToViewDepth.z, (tan(_6137.y) * sqrt(1.0f + (_6140 * _6140))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9128 = _9102 + (_5542 * _4000);
        }
        float _4005 = 1.0f - cbFI_Timestep;
        float2 _9129;
        if (_5570)
        {
            float2 _6208 = clamp((((_9102 + (_5542 * _4005)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6211 = tan(_6208.x);
            _9129 = (float2(_6211 / cbFI_DeviceToViewDepth.z, (tan(_6208.y) * sqrt(1.0f + (_6211 * _6211))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9129 = _9102 + (_5542 * _4005);
        }
        float4 _6246 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9125, 0.0f);
        float3 _6247 = _6246.xyz;
        float4 _6254 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9127, 0.0f);
        float3 _6255 = _6254.xyz;
        float4 _6262 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9128, 0.0f);
        float3 _6263 = _6262.xyz;
        float4 _6270 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9129, 0.0f);
        float3 _6271 = _6270.xyz;
        float4 _6285 = exp(_5536 - max(max(max(_5536.x, _5536.y), _5536.z), _5536.w).xxxx);
        float4 _6292 = _6285 / (dot(_6285, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4024 = _3817 && (!_9144);
        bool _4033;
        if (_4024)
        {
            _4033 = (_6292.z + _6292.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4033 = _4024;
        }
        bool _4044;
        if (_4033)
        {
            _4044 = length((_9128 - _9125) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4044 = _4033;
        }
        bool _9168;
        if (_4044)
        {
            uint4 _6311 = r_warped_motion_qdata_tp1.Load(int3(_9155, 0));
            uint _6312 = _6311.x;
            bool _9171;
            if (_6312 != 0u)
            {
                float _9157;
                if (_6312 == 0u)
                {
                    _9157 = -1.0f;
                }
                else
                {
                    _9157 = float((_6312 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4054 = _9157 - 0.12000000476837158203125f;
                bool _6331 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                bool _6337;
                if (_6331)
                {
                    _6337 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                }
                else
                {
                    _6337 = _6331;
                }
                bool _4064;
                if (_6337)
                {
                    uint _6344_dummy_parameter;
                    _4064 = (log(((r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6344_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4054;
                }
                else
                {
                    _4064 = _6337;
                }
                bool _4078;
                if (!_4064)
                {
                    bool _6374 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                    bool _6380;
                    if (_6374)
                    {
                        _6380 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6380 = _6374;
                    }
                    bool _4076;
                    if (_6380)
                    {
                        uint _6387_dummy_parameter;
                        _4076 = (log(((r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6387_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4054;
                    }
                    else
                    {
                        _4076 = _6380;
                    }
                    _4078 = _4076;
                }
                else
                {
                    _4078 = _4064;
                }
                _9171 = _4078;
            }
            else
            {
                _9171 = false;
            }
            _9168 = _9171;
        }
        else
        {
            _9168 = false;
        }
        bool _4083 = _9144 || _9168;
        bool _4088;
        if (_4083)
        {
            bool _6417 = all(bool2(_9125.x > 0.0f.xx.x, _9125.y > 0.0f.xx.y));
            bool _6423;
            if (_6417)
            {
                _6423 = all(bool2(_9125.x < 1.0f.xx.x, _9125.y < 1.0f.xx.y));
            }
            else
            {
                _6423 = _6417;
            }
            _4088 = _6423;
        }
        else
        {
            _4088 = _4083;
        }
        bool _4093;
        if (_4088)
        {
            bool _6428 = all(bool2(_9127.x > 0.0f.xx.x, _9127.y > 0.0f.xx.y));
            bool _6434;
            if (_6428)
            {
                _6434 = all(bool2(_9127.x < 1.0f.xx.x, _9127.y < 1.0f.xx.y));
            }
            else
            {
                _6434 = _6428;
            }
            _4093 = _6434;
        }
        else
        {
            _4093 = _4088;
        }
        float4 _9262;
        if (_4093)
        {
            float _4096 = _6292.x;
            float _4098 = _6292.y;
            float _4099 = _4096 + _4098;
            float _4104 = _6292.z + _6292.w;
            float _9186;
            if (_4099 > 0.001000000047497451305389404296875f)
            {
                _9186 = _4096 / _4099;
            }
            else
            {
                _9186 = _4005;
            }
            _9262 = float4(_4096 + (_4104 * _9186), _4098 + (_4104 * (1.0f - _9186)), 0.0f, 0.0f);
        }
        else
        {
            _9262 = _6292;
        }
        bool _6462 = (cbFI_pad0 & 1024u) != 0u;
        bool _6438 = !_6462;
        bool _6439 = !_6438;
        bool _6456;
        if (_6439)
        {
            _6456 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9155.y * cbFI_MvDepthLaneSize.x) + _9155.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6456 = _6438;
        }
        bool _6488;
        if (_6439)
        {
            _6488 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3796.y * cbFI_FlowLaneSize.x) + _3796.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6488 = _6438;
        }
        float _4139 = float(_6488);
        bool _9274;
        float4 _9304;
        float3 _10063;
        if (_6462)
        {
            bool _4149;
            if (_6456)
            {
                _4149 = all(bool2(_9125.x > 0.0f.xx.x, _9125.y > 0.0f.xx.y));
            }
            else
            {
                _4149 = _6456;
            }
            bool _4155;
            if (_4149)
            {
                _4155 = all(bool2(_9125.x < 1.0f.xx.x, _9125.y < 1.0f.xx.y));
            }
            else
            {
                _4155 = _4149;
            }
            bool _4162;
            if (_6456)
            {
                _4162 = all(bool2(_9127.x > 0.0f.xx.x, _9127.y > 0.0f.xx.y));
            }
            else
            {
                _4162 = _6456;
            }
            bool _4168;
            if (_4162)
            {
                _4168 = all(bool2(_9127.x < 1.0f.xx.x, _9127.y < 1.0f.xx.y));
            }
            else
            {
                _4168 = _4162;
            }
            bool _4175;
            if (_6488)
            {
                _4175 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
            }
            else
            {
                _4175 = _6488;
            }
            bool _4181;
            if (_4175)
            {
                _4181 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
            }
            else
            {
                _4181 = _4175;
            }
            bool _4188;
            if (_6488)
            {
                _4188 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
            }
            else
            {
                _4188 = _6488;
            }
            bool _4194;
            if (_4188)
            {
                _4194 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
            }
            else
            {
                _4194 = _4188;
            }
            bool _4196 = !_6456;
            if (_4196)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6530;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6530);
                }
            }
            bool _4201 = !_6488;
            if (_4201)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6540;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6540);
                }
            }
            if (_6456 && _4201)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6550;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6550);
                }
            }
            if (_4196 && _6488)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6560;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6560);
                }
            }
            float _4220 = float(_4155);
            float _4222 = float(_4168);
            bool _4225 = _4181 && _4194;
            float _9220;
            if (_4225)
            {
                _9220 = 1.0f;
            }
            else
            {
                _9220 = (_4181 || _4194) ? 0.5f : 0.0f;
            }
            bool _9225;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4155)) && (!_4168))
            {
                bool _4255;
                if (_4225)
                {
                    float _9223;
                    do
                    {
                        bool _6644 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                        bool _6650;
                        if (_6644)
                        {
                            _6650 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6650 = _6644;
                        }
                        bool _6581 = !_6650;
                        bool _6588;
                        if (!_6581)
                        {
                            bool _6655 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                            bool _6661;
                            if (_6655)
                            {
                                _6661 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6661 = _6655;
                            }
                            _6588 = !_6661;
                        }
                        else
                        {
                            _6588 = _6581;
                        }
                        if (_6588)
                        {
                            _9223 = 0.0f;
                            break;
                        }
                        uint _6668_dummy_parameter;
                        uint _6684_dummy_parameter;
                        float4 _6609 = mul(float4((float2(_9128.x, 1.0f - _9128.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6668_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6611 = _6609.w;
                        if (abs(_6611) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9223 = 0.0f;
                            break;
                        }
                        float _6622 = abs(cbFI_DeviceToViewDepth.y / ((_6609.z / _6611) - cbFI_DeviceToViewDepth.x));
                        float _6625 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6684_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9223 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6622 - _6625) / max(max(_6622, _6625), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4255 = _9223 >= 0.5f;
                }
                else
                {
                    _4255 = _4225;
                }
                bool _9226;
                if (_4255)
                {
                    uint _6734_dummy_parameter;
                    float2 _9224;
                    do
                    {
                        float _6760 = 1.0f - _9128.y;
                        float4 _6771 = mul(float4((float2(_9128.x, _6760) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6734_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6773 = _6771.w;
                        if (!(_6773 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9224 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6786 = ((_6771.xy / _6773.xx) + 1.0f.xx) * 0.5f;
                        _9224 = float2(_6786.x - _9128.x, _6760 - _6786.y);
                        break;
                    } while(false);
                    float2 _4269 = float2(cbFI_DisplaySize);
                    _9226 = length(((_9128 + _9224) - _9129) * _4269) <= ((0.100000001490116119384765625f * length(_9224 * _4269)) + 8.0f);
                }
                else
                {
                    _9226 = _4255;
                }
                _9225 = _9226;
            }
            else
            {
                _9225 = true;
            }
            bool _4283 = !_9225;
            bool _10730 = _4283 ? false : _4194;
            bool _10731 = _4283 ? false : _4181;
            bool _9275;
            float4 _9305;
            if (!(((_4155 && _4168) && _10731) && _10730))
            {
                float4 _4305 = _9262 * float4(_4220, _4222, float(_10731), float(_10730));
                float _4307 = dot(_4305, 1.0f.xxxx);
                bool _4310 = !(_4307 > 0.0f);
                float4 _9306;
                if (!_4310)
                {
                    _9306 = _4305 / _4307.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6808;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6808);
                    }
                    _9306 = 0.0f.xxxx;
                }
                _9305 = _9306;
                _9275 = _4310;
            }
            else
            {
                _9305 = _9262;
                _9275 = false;
            }
            _10063 = float3(_4220, _4222, _9220);
            _9304 = _9305;
            _9274 = _9275;
        }
        else
        {
            _10063 = float3(float(_6456), _4139, 0.0f);
            _9304 = _9262;
            _9274 = false;
        }
        float4 _9793;
        bool _9813;
        float3 _9926;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9274))
        {
            bool _4333 = _9304.x > 0.00999999977648258209228515625f;
            bool _4336 = _9304.y > 0.00999999977648258209228515625f;
            bool _4345 = (_9304.z + _9304.w) > 0.0199999995529651641845703125f;
            bool _4351;
            if (_4345)
            {
                bool _6814 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                bool _6820;
                if (_6814)
                {
                    _6820 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                }
                else
                {
                    _6820 = _6814;
                }
                _4351 = _6820;
            }
            else
            {
                _4351 = _4345;
            }
            bool _4356;
            if (_4351)
            {
                bool _6825 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                bool _6831;
                if (_6825)
                {
                    _6831 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                }
                else
                {
                    _6831 = _6825;
                }
                _4356 = _6831;
            }
            else
            {
                _4356 = _4351;
            }
            bool _4363;
            if (_4356)
            {
                float _9308;
                do
                {
                    bool _6914 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                    bool _6920;
                    if (_6914)
                    {
                        _6920 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6920 = _6914;
                    }
                    bool _6851 = !_6920;
                    bool _6858;
                    if (!_6851)
                    {
                        bool _6925 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                        bool _6931;
                        if (_6925)
                        {
                            _6931 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6931 = _6925;
                        }
                        _6858 = !_6931;
                    }
                    else
                    {
                        _6858 = _6851;
                    }
                    if (_6858)
                    {
                        _9308 = 0.0f;
                        break;
                    }
                    uint _6938_dummy_parameter;
                    uint _6954_dummy_parameter;
                    float4 _6879 = mul(float4((float2(_9128.x, 1.0f - _9128.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6938_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6881 = _6879.w;
                    if (abs(_6881) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9308 = 0.0f;
                        break;
                    }
                    float _6892 = abs(cbFI_DeviceToViewDepth.y / ((_6879.z / _6881) - cbFI_DeviceToViewDepth.x));
                    float _6895 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6954_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9308 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6892 - _6895) / max(max(_6892, _6895), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4363 = _9308 < 0.5f;
            }
            else
            {
                _4363 = _4356;
            }
            float4 _9323;
            if (_4363)
            {
                uint _7004_dummy_parameter;
                uint _7035_dummy_parameter;
                float4 _9324;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7004_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7035_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9324 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9324 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9323 = _9324;
            }
            else
            {
                _9323 = 1.0f.xxxx;
            }
            bool _4387;
            if (_6456)
            {
                bool _7064 = all(bool2(_9125.x > 0.0f.xx.x, _9125.y > 0.0f.xx.y));
                bool _7070;
                if (_7064)
                {
                    _7070 = all(bool2(_9125.x < 1.0f.xx.x, _9125.y < 1.0f.xx.y));
                }
                else
                {
                    _7070 = _7064;
                }
                _4387 = _7070;
            }
            else
            {
                _4387 = _6456;
            }
            bool _4393;
            if (_6456)
            {
                bool _7075 = all(bool2(_9127.x > 0.0f.xx.x, _9127.y > 0.0f.xx.y));
                bool _7081;
                if (_7075)
                {
                    _7081 = all(bool2(_9127.x < 1.0f.xx.x, _9127.y < 1.0f.xx.y));
                }
                else
                {
                    _7081 = _7075;
                }
                _4393 = _7081;
            }
            else
            {
                _4393 = _6456;
            }
            bool _4399;
            if (_6488)
            {
                bool _7086 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                bool _7092;
                if (_7086)
                {
                    _7092 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                }
                else
                {
                    _7092 = _7086;
                }
                _4399 = _7092;
            }
            else
            {
                _4399 = _6488;
            }
            bool _4405;
            if (_6488)
            {
                bool _7097 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                bool _7103;
                if (_7097)
                {
                    _7103 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                }
                else
                {
                    _7103 = _7097;
                }
                _4405 = _7103;
            }
            else
            {
                _4405 = _6488;
            }
            bool _4408 = _4399 != _4405;
            bool _4414;
            if (_4408)
            {
                _4414 = _4387 || _4393;
            }
            else
            {
                _4414 = _4408;
            }
            float4 _9405;
            if (_4414)
            {
                float4 _8998 = _9323;
                _8998.z = 0.0f;
                _8998.w = 0.0f;
                _9405 = _8998;
            }
            else
            {
                _9405 = _9323;
            }
            bool _4421 = _4387 && _4333;
            bool _4424 = _4393 && _4336;
            float4 _9510;
            float3 _9963;
            if (_4421 || _4424)
            {
                float _9400;
                do
                {
                    uint4 _7242 = r_warped_motion_qdata_tp1.Load(int3(_9155, 0));
                    uint _7243 = _7242.x;
                    if (_7243 != 0u)
                    {
                        float _9399;
                        if (_7243 == 0u)
                        {
                            _9399 = -1.0f;
                        }
                        else
                        {
                            _9399 = float((_7243 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9400 = _9399;
                        break;
                    }
                    int _9382;
                    uint _9383;
                    _9383 = _7243;
                    _9382 = -1;
                    uint _9398;
                    for (; _9382 <= 1; _9383 = _9398, _9382++)
                    {
                        _9398 = _9383;
                        for (int _9396 = -1; _9396 <= 1; )
                        {
                            _9398 = max(_9398, r_warped_motion_qdata_tp1.Load(int3(clamp(_9155 + int2(_9396, _9382), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9396++;
                            continue;
                        }
                    }
                    if (_9383 != 0u)
                    {
                        float _9395;
                        if (_9383 == 0u)
                        {
                            _9395 = -1.0f;
                        }
                        else
                        {
                            _9395 = float((_9383 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9400 = _9395;
                        break;
                    }
                    uint _9385;
                    _9385 = 4294967295u;
                    uint _10702;
                    for (int _9384 = 0; _9384 < 8; _9385 = _10702, _9384++)
                    {
                        int _9388 = 0;
                        for (;;)
                        {
                            if (_9388 < 5)
                            {
                                int2 _7193 = _9155 + (_1093[_9384] * _1102[_9388].xx);
                                bool _7196 = any(bool2(_7193.x < int2(0, 0).x, _7193.y < int2(0, 0).y));
                                bool _7204;
                                if (!_7196)
                                {
                                    _7204 = any(bool2(_7193.x >= cbFI_MvDepthLaneSize.x, _7193.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7204 = _7196;
                                }
                                if (_7204)
                                {
                                    _10702 = _9385;
                                    break;
                                }
                                uint4 _7282 = r_warped_motion_qdata_tp1.Load(int3(_7193, 0));
                                uint _7283 = _7282.x;
                                if (_7283 != 0u)
                                {
                                    _10702 = min(_9385, _7283);
                                    break;
                                }
                                _9388++;
                                continue;
                            }
                            else
                            {
                                _10702 = _9385;
                                break;
                            }
                        }
                    }
                    float _9387;
                    if (_9385 == 4294967295u)
                    {
                        _9387 = -1.0f;
                    }
                    else
                    {
                        float _9386;
                        if (_9385 == 0u)
                        {
                            _9386 = -1.0f;
                        }
                        else
                        {
                            _9386 = float((_9385 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9387 = _9386;
                    }
                    _9400 = _9387;
                    break;
                } while(false);
                bool _4432 = _9400 < 0.0f;
                float _9401;
                if (_4432)
                {
                    _9401 = 0.0f;
                }
                else
                {
                    _9401 = _9400 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7304_dummy_parameter;
                uint _7336_dummy_parameter;
                float4 _9438;
                if ((_4432 && _4421) && _4424)
                {
                    uint _7368_dummy_parameter;
                    float _7392 = log(((r_depth_tm1.Load(int3(int2(floor(_9125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7368_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7400_dummy_parameter;
                    float _7424 = log(((r_depth_tp1.Load(int3(int2(floor(_9127 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7400_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9439;
                    if (_7392 > (_7424 + 0.07999999821186065673828125f))
                    {
                        float4 _9002 = _9405;
                        _9002.x = 0.0f;
                        _9439 = _9002;
                    }
                    else
                    {
                        float4 _9440;
                        if (_7424 > (_7392 + 0.07999999821186065673828125f))
                        {
                            float4 _9004 = _9405;
                            _9004.y = 0.0f;
                            _9440 = _9004;
                        }
                        else
                        {
                            _9440 = _9405;
                        }
                        _9439 = _9440;
                    }
                    _9438 = _9439;
                }
                else
                {
                    _9438 = _9405;
                }
                float _4484 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4486 = _9400 >= 0.0f;
                float _9421;
                if (_4486)
                {
                    _9421 = _9400 - _4484;
                }
                else
                {
                    float _9417;
                    if (_4421)
                    {
                        float _9416;
                        _9416 = 2.0f;
                        float _7482;
                        for (int _9415 = 0; _9415 < 24; _9416 = _7482, _9415++)
                        {
                            float _7446 = float(_9415 & 7) * 0.785398185253143310546875f;
                            int _7448 = _9415 >> 3;
                            int _9418;
                            if (_7448 == 0)
                            {
                                _9418 = 16;
                            }
                            else
                            {
                                _9418 = (_7448 == 1) ? 48 : 96;
                            }
                            uint _7498_dummy_parameter;
                            _7482 = min(_9416, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9125 + ((cbFI_MvDepthLaneSizeRcp * float(_9418)) * float2(cos(_7446), sin(_7446))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7498_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9417 = _9416;
                    }
                    else
                    {
                        _9417 = 0.0f;
                    }
                    _9421 = _9417;
                }
                float _9428;
                if (_4486)
                {
                    _9428 = _9400 - _4484;
                }
                else
                {
                    float _9424;
                    if (_4424)
                    {
                        float _9423;
                        _9423 = 2.0f;
                        float _7596;
                        for (int _9422 = 0; _9422 < 24; _9423 = _7596, _9422++)
                        {
                            float _7560 = float(_9422 & 7) * 0.785398185253143310546875f;
                            int _7562 = _9422 >> 3;
                            int _9425;
                            if (_7562 == 0)
                            {
                                _9425 = 16;
                            }
                            else
                            {
                                _9425 = (_7562 == 1) ? 48 : 96;
                            }
                            uint _7628_dummy_parameter;
                            _7596 = min(_9423, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9127 + ((cbFI_MvDepthLaneSizeRcp * float(_9425)) * float2(cos(_7560), sin(_7560))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7628_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9424 = _9423;
                    }
                    else
                    {
                        _9424 = 0.0f;
                    }
                    _9428 = _9424;
                }
                float _9429;
                if (_4421)
                {
                    uint _7660_dummy_parameter;
                    _9429 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7660_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9429 = 0.0f;
                }
                float _9430;
                if (_4424)
                {
                    uint _7680_dummy_parameter;
                    _9430 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9127 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7680_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9430 = 0.0f;
                }
                bool _4541;
                if (_4421)
                {
                    _4541 = _9429 > ((exp((_9421 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4541 = _4421;
                }
                float4 _9446;
                if (_4541)
                {
                    float4 _9006 = _9438;
                    _9006.x = 0.0f;
                    _9446 = _9006;
                }
                else
                {
                    _9446 = _9438;
                }
                bool _4553;
                if (_4424)
                {
                    _4553 = _9430 > ((exp((_9428 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4553 = _4424;
                }
                float4 _9448;
                if (_4553)
                {
                    float4 _9008 = _9446;
                    _9008.y = 0.0f;
                    _9448 = _9008;
                }
                else
                {
                    _9448 = _9446;
                }
                float4 _9511;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4486)
                {
                    bool _4573;
                    if (_4421)
                    {
                        _4573 = _9429 < ((exp((_9421 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4573 = _4421;
                    }
                    float4 _9450;
                    if (_4573)
                    {
                        float4 _9010 = _9448;
                        _9010.x = 0.0f;
                        _9450 = _9010;
                    }
                    else
                    {
                        _9450 = _9448;
                    }
                    bool _4585;
                    if (_4424)
                    {
                        _4585 = _9430 < ((exp((_9428 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4585 = _4424;
                    }
                    float4 _9512;
                    if (_4585)
                    {
                        float4 _9012 = _9450;
                        _9012.y = 0.0f;
                        _9512 = _9012;
                    }
                    else
                    {
                        _9512 = _9450;
                    }
                    _9511 = _9512;
                }
                else
                {
                    _9511 = _9448;
                }
                _9963 = float3(_9401, log(((r_depth_tm1.Load(int3(int2(floor(_9125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7304_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9127 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7336_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9510 = _9511;
            }
            else
            {
                _9963 = float3(0.0f, 0.0f, 0.5f);
                _9510 = _9405;
            }
            bool _4596 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4345;
            bool _4602;
            if (_4596)
            {
                _4602 = _4399 || _4405;
            }
            else
            {
                _4602 = _4596;
            }
            float4 _9532;
            if (_4602)
            {
                float _9505;
                do
                {
                    uint4 _7860 = r_warped_motion_qdata_tp1.Load(int3(_9155, 0));
                    uint _7861 = _7860.x;
                    if (_7861 != 0u)
                    {
                        float _9504;
                        if (_7861 == 0u)
                        {
                            _9504 = -1.0f;
                        }
                        else
                        {
                            _9504 = float((_7861 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9505 = _9504;
                        break;
                    }
                    int _9487;
                    uint _9488;
                    _9488 = _7861;
                    _9487 = -1;
                    uint _9503;
                    for (; _9487 <= 1; _9488 = _9503, _9487++)
                    {
                        _9503 = _9488;
                        for (int _9501 = -1; _9501 <= 1; )
                        {
                            _9503 = max(_9503, r_warped_motion_qdata_tp1.Load(int3(clamp(_9155 + int2(_9501, _9487), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9501++;
                            continue;
                        }
                    }
                    if (_9488 != 0u)
                    {
                        float _9500;
                        if (_9488 == 0u)
                        {
                            _9500 = -1.0f;
                        }
                        else
                        {
                            _9500 = float((_9488 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9505 = _9500;
                        break;
                    }
                    uint _9490;
                    _9490 = 4294967295u;
                    uint _10703;
                    for (int _9489 = 0; _9489 < 8; _9490 = _10703, _9489++)
                    {
                        int _9493 = 0;
                        for (;;)
                        {
                            if (_9493 < 5)
                            {
                                int2 _7811 = _9155 + (_1093[_9489] * _1102[_9493].xx);
                                bool _7814 = any(bool2(_7811.x < int2(0, 0).x, _7811.y < int2(0, 0).y));
                                bool _7822;
                                if (!_7814)
                                {
                                    _7822 = any(bool2(_7811.x >= cbFI_MvDepthLaneSize.x, _7811.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7822 = _7814;
                                }
                                if (_7822)
                                {
                                    _10703 = _9490;
                                    break;
                                }
                                uint4 _7900 = r_warped_motion_qdata_tp1.Load(int3(_7811, 0));
                                uint _7901 = _7900.x;
                                if (_7901 != 0u)
                                {
                                    _10703 = min(_9490, _7901);
                                    break;
                                }
                                _9493++;
                                continue;
                            }
                            else
                            {
                                _10703 = _9490;
                                break;
                            }
                        }
                    }
                    float _9492;
                    if (_9490 == 4294967295u)
                    {
                        _9492 = -1.0f;
                    }
                    else
                    {
                        float _9491;
                        if (_9490 == 0u)
                        {
                            _9491 = -1.0f;
                        }
                        else
                        {
                            _9491 = float((_9490 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9492 = _9491;
                    }
                    _9505 = _9492;
                    break;
                } while(false);
                float4 _9533;
                if (_9505 >= 0.0f)
                {
                    float _7922 = (exp((_9505 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4621;
                    if (_4399)
                    {
                        uint _7929_dummy_parameter;
                        _4621 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7929_dummy_parameter))))), 0)).x) > _7922;
                    }
                    else
                    {
                        _4621 = _4399;
                    }
                    float4 _9523;
                    if (_4621)
                    {
                        float4 _9014 = _9510;
                        _9014.z = 0.0f;
                        _9523 = _9014;
                    }
                    else
                    {
                        _9523 = _9510;
                    }
                    bool _4633;
                    if (_4405)
                    {
                        uint _7949_dummy_parameter;
                        _4633 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7949_dummy_parameter))))), 0)).x) > _7922;
                    }
                    else
                    {
                        _4633 = _4405;
                    }
                    float4 _9534;
                    if (_4633)
                    {
                        float4 _9016 = _9523;
                        _9016.w = 0.0f;
                        _9534 = _9016;
                    }
                    else
                    {
                        _9534 = _9523;
                    }
                    _9533 = _9534;
                }
                else
                {
                    _9533 = _9510;
                }
                _9532 = _9533;
            }
            else
            {
                _9532 = _9510;
            }
            bool _4641 = _4387 != _4393;
            bool _4648;
            if (_4641)
            {
                _4648 = _4387 ? _4333 : _4336;
            }
            else
            {
                _4648 = _4641;
            }
            float4 _9616;
            if (_4648)
            {
                bool2 _4653 = _4387.xx;
                float2 _4654 = float2(_4653.x ? _9125.x : _9127.x, _4653.y ? _9125.y : _9127.y);
                float _9525;
                if (_4387)
                {
                    uint _7969_dummy_parameter;
                    _9525 = r_depth_tm1.Load(int3(int2(floor(_4654 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7969_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7985_dummy_parameter;
                    _9525 = r_depth_tp1.Load(int3(int2(floor(_4654 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7985_dummy_parameter))))), 0)).x;
                }
                float4x4 _9526;
                if (_4387)
                {
                    _9526 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9526 = cbFI_MotionTP1ToTM1;
                }
                float2 _9527;
                do
                {
                    float _8012 = _4654.x;
                    float _8015 = 1.0f - _4654.y;
                    float4 _8026 = mul(float4((float2(_8012, _8015) * 2.0f) - 1.0f.xx, _9525, 1.0f), _9526);
                    float _8028 = _8026.w;
                    if (!(_8028 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9527 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8041 = ((_8026.xy / _8028.xx) + 1.0f.xx) * 0.5f;
                    _9527 = float2(_8041.x - _8012, _8015 - _8041.y);
                    break;
                } while(false);
                float2 _4684 = float2(cbFI_DisplaySize);
                float4 _9617;
                if (!(length(((_4654 + _9527) - float2(_4653.x ? _9127.x : _9125.x, _4653.y ? _9127.y : _9125.y)) * _4684) <= ((0.100000001490116119384765625f * length(_9527 * _4684)) + 8.0f)))
                {
                    float4 _9618;
                    if (_4387)
                    {
                        float4 _9026 = _9532;
                        _9026.x = 0.0f;
                        _9618 = _9026;
                    }
                    else
                    {
                        float4 _9028 = _9532;
                        _9028.y = 0.0f;
                        _9618 = _9028;
                    }
                    _9617 = _9618;
                }
                else
                {
                    _9617 = _9532;
                }
                _9616 = _9617;
            }
            else
            {
                _9616 = _9532;
            }
            float4 _4709 = _9304 * _9616;
            float _4711 = dot(_4709, 1.0f.xxxx);
            float4 _9794;
            bool _9814;
            if (_4711 > 0.0f)
            {
                _9814 = _9274;
                _9794 = _4709 / _4711.xxxx;
            }
            else
            {
                bool _4722 = any(bool4(_9616.x < 1.0f.xxxx.x, _9616.y < 1.0f.xxxx.y, _9616.z < 1.0f.xxxx.z, _9616.w < 1.0f.xxxx.w));
                if (_4722)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8063;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8063);
                    }
                }
                bool4 _10733 = _4722.xxxx;
                _9814 = _4722 ? true : _9274;
                _9794 = float4(_10733.x ? 0.0f.xxxx.x : _9304.x, _10733.y ? 0.0f.xxxx.y : _9304.y, _10733.z ? 0.0f.xxxx.z : _9304.z, _10733.w ? 0.0f.xxxx.w : _9304.w);
            }
            _9926 = _9963;
            _9813 = _9814;
            _9793 = _9794;
        }
        else
        {
            _9926 = float3(0.0f, 0.0f, 0.5f);
            _9813 = _9274;
            _9793 = _9304;
        }
        uint _4731 = (cbFI_pad0 >> 24u) & 31u;
        uint _4735 = (cbFI_pad0 >> 16u) & 255u;
        bool _4737 = _4731 != 0u;
        bool _4739 = _4735 == 12u;
        bool _4742 = _4735 == 13u;
        float4 _9810;
        if ((_4737 || _4739) || _4742)
        {
            float _9619;
            do
            {
                bool _8147 = all(bool2(_9128.x > 0.0f.xx.x, _9128.y > 0.0f.xx.y));
                bool _8153;
                if (_8147)
                {
                    _8153 = all(bool2(_9128.x < 1.0f.xx.x, _9128.y < 1.0f.xx.y));
                }
                else
                {
                    _8153 = _8147;
                }
                bool _8084 = !_8153;
                bool _8091;
                if (!_8084)
                {
                    bool _8158 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
                    bool _8164;
                    if (_8158)
                    {
                        _8164 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8164 = _8158;
                    }
                    _8091 = !_8164;
                }
                else
                {
                    _8091 = _8084;
                }
                if (_8091)
                {
                    _9619 = 0.0f;
                    break;
                }
                uint _8171_dummy_parameter;
                uint _8187_dummy_parameter;
                float4 _8112 = mul(float4((float2(_9128.x, 1.0f - _9128.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8171_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8114 = _8112.w;
                if (abs(_8114) < 9.9999999747524270787835121154785e-07f)
                {
                    _9619 = 0.0f;
                    break;
                }
                float _8125 = abs(cbFI_DeviceToViewDepth.y / ((_8112.z / _8114) - cbFI_DeviceToViewDepth.x));
                float _8128 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8187_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9619 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8125 - _8128) / max(max(_8125, _8128), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8235 = all(bool2(_9129.x > 0.0f.xx.x, _9129.y > 0.0f.xx.y));
            bool _8241;
            if (_8235)
            {
                _8241 = all(bool2(_9129.x < 1.0f.xx.x, _9129.y < 1.0f.xx.y));
            }
            else
            {
                _8241 = _8235;
            }
            float _9620;
            if (_8241)
            {
                uint _8248_dummy_parameter;
                _9620 = length((_5542 + (r_motion_tp1.Load(int3(int2(floor(_9129 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8248_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9620 = 1000000.0f;
            }
            float _9631;
            if ((_4731 & 1u) != 0u)
            {
                _9631 = _9619;
            }
            else
            {
                _9631 = 1.0f;
            }
            float _9632;
            if ((_4731 & 2u) != 0u)
            {
                _9632 = _9631 * (1.0f - smoothstep(2.0f, 8.0f, _9620));
            }
            else
            {
                _9632 = _9631;
            }
            float _9633;
            if ((_4731 & 4u) != 0u)
            {
                _9633 = _9632 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6263 - _6271) - length(_6247 - _6255))));
            }
            else
            {
                _9633 = _9632;
            }
            float _9804;
            if ((_4731 & 8u) != 0u)
            {
                _9804 = lerp(1.0f, _9633, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6247 - _6255)));
            }
            else
            {
                _9804 = _9633;
            }
            bool _4817 = (_4731 & 16u) != 0u;
            bool _4826;
            if (_4817)
            {
                _4826 = length(_9123 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4826 = _4817;
            }
            float _10735 = _4826 ? 1.0f : _9804;
            bool _4832 = _4737 && _6456;
            bool _4837;
            if (_4832)
            {
                bool _8273 = all(bool2(_9125.x > 0.0f.xx.x, _9125.y > 0.0f.xx.y));
                bool _8279;
                if (_8273)
                {
                    _8279 = all(bool2(_9125.x < 1.0f.xx.x, _9125.y < 1.0f.xx.y));
                }
                else
                {
                    _8279 = _8273;
                }
                _4837 = _8279;
            }
            else
            {
                _4837 = _4832;
            }
            bool _4842;
            if (_4837)
            {
                bool _8284 = all(bool2(_9127.x > 0.0f.xx.x, _9127.y > 0.0f.xx.y));
                bool _8290;
                if (_8284)
                {
                    _8290 = all(bool2(_9127.x < 1.0f.xx.x, _9127.y < 1.0f.xx.y));
                }
                else
                {
                    _8290 = _8284;
                }
                _4842 = _8290;
            }
            else
            {
                _4842 = _4837;
            }
            float4 _9811;
            if (_4842)
            {
                float _4848 = _9793.x + _9793.y;
                float _4857 = (_9793.z + _9793.w) * (1.0f - _10735);
                float _9807;
                if (_4848 > 9.9999997473787516355514526367188e-06f)
                {
                    _9807 = _9793.x / _4848;
                }
                else
                {
                    _9807 = _4005;
                }
                _9811 = float4(_9793.x + (_4857 * _9807), _9793.y + (_4857 * (1.0f - _9807)), _9793.zw * _10735);
            }
            else
            {
                _9811 = _9793;
            }
            _9810 = _9811;
        }
        else
        {
            _9810 = _9793;
        }
        float3 _10506;
        if (_9813)
        {
            float3 _8296 = r_current_interpolation_source.Load(int3(_3405, 0)).xyz;
            float3 _10507;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6456)
            {
                uint _8303_dummy_parameter;
                float _9917;
                _9917 = r_depth_tm1.Load(int3(int2(floor(_9125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8303_dummy_parameter))))), 0)).x;
                float _4969;
                for (int _9916 = 0; _9916 < 24; _9917 = _4969, _9916++)
                {
                    float _4941 = float(_9916 & 7) * 0.785398185253143310546875f;
                    int _4943 = _9916 >> 3;
                    int _10557;
                    if (_4943 == 0)
                    {
                        _10557 = 16;
                    }
                    else
                    {
                        _10557 = (_4943 == 1) ? 48 : 96;
                    }
                    uint _8323_dummy_parameter;
                    _4969 = max(_9917, r_depth_tm1.Load(int3(int2(floor(clamp(_9125 + ((cbFI_MvDepthLaneSizeRcp * float(_10557)) * float2(cos(_4941), sin(_4941))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8323_dummy_parameter))))), 0)).x);
                }
                float2 _9918;
                do
                {
                    float _8345 = 1.0f - _9125.y;
                    float4 _8356 = mul(float4((float2(_9125.x, _8345) * 2.0f) - 1.0f.xx, _9917, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8358 = _8356.w;
                    if (!(_8358 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9918 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8371 = ((_8356.xy / _8358.xx) + 1.0f.xx) * 0.5f;
                    _9918 = float2(_8371.x - _9125.x, _8345 - _8371.y);
                    break;
                } while(false);
                float2 _4980 = _9125 + _9918;
                bool _8389 = all(bool2(_4980.x > 0.0f.xx.x, _4980.y > 0.0f.xx.y));
                bool _8395;
                if (_8389)
                {
                    _8395 = all(bool2(_4980.x < 1.0f.xx.x, _4980.y < 1.0f.xx.y));
                }
                else
                {
                    _8395 = _8389;
                }
                float3 _10508;
                if (_8395)
                {
                    float _4986 = abs(cbFI_DeviceToViewDepth.y / (_9917 - cbFI_DeviceToViewDepth.x));
                    uint _8415_dummy_parameter;
                    int2 _8415 = int2(spvTextureSize(r_depth_m2, uint(0), _8415_dummy_parameter));
                    float _4990 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4980 * float2(_8415))), int2(0, 0), _8415 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10513;
                    if (abs(_4990 - _4986) <= (0.20000000298023223876953125f * max(_4990, _4986)))
                    {
                        uint _8449_dummy_parameter;
                        int2 _8449 = int2(spvTextureSize(r_colour_m2, uint(0), _8449_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8472;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8472);
                        }
                        _10513 = r_colour_m2.Load(int3(clamp(int2(floor(_4980 * float2(_8449))), int2(0, 0), _8449 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8482;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8482);
                        }
                        _10513 = _8296;
                    }
                    _10508 = _10513;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8492;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8492);
                    }
                    _10508 = _8296;
                }
                _10507 = _10508;
            }
            else
            {
                _10507 = _8296;
            }
            _10506 = _10507;
        }
        else
        {
            _10506 = (((_6247 * _9810.x) + (_6255 * _9810.y)) + (_6263 * _9810.z)) + (_6271 * _9810.w);
        }
        uint _5018 = cbFI_pad0 & 255u;
        bool _10399;
        float3 _10505;
        if (_5018 != 0u)
        {
            float3 _5023 = r_present_backbuffer.Load(int3(_3405, 0)).xyz;
            float3 _5027 = r_current_interpolation_source.Load(int3(_3405, 0)).xyz;
            float3 _5031 = abs(_5023 - _5027);
            float3 _9921;
            if (_5018 == 2u)
            {
                _9921 = (abs(_5027) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9921 = 0.000244140625f.xxx;
            }
            bool _5047 = any(bool3(_5031.x > _9921.x, _5031.y > _9921.y, _5031.z > _9921.z));
            bool3 _10736 = _5047.xxx;
            _10505 = float3(_10736.x ? _5023.x : _10506.x, _10736.y ? _5023.y : _10506.y, _10736.z ? _5023.z : _10506.z);
            _10399 = _5047;
        }
        else
        {
            _10505 = _10506;
            _10399 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8507;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8507);
        }
        float3 _10488;
        if (_4735 == 1u)
        {
            _10488 = lerp(_6247, _6255, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10489;
            if (_4735 == 2u)
            {
                _10489 = lerp(_6263, _6271, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10490;
                if (_4735 == 3u)
                {
                    _10490 = float(_10399).xxx;
                }
                else
                {
                    float3 _10491;
                    if (_4735 == 4u)
                    {
                        _10491 = float3(((_9123 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10492;
                        if (_4735 == 5u)
                        {
                            _10492 = float3(((_5542 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10493;
                            if (_4735 == 6u)
                            {
                                _10493 = float3(_9810.xy, _9810.z + _9810.w);
                            }
                            else
                            {
                                float3 _10494;
                                if (_4735 == 7u)
                                {
                                    _10494 = r_current_interpolation_source.Load(int3(_3405, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10495;
                                    if (_4735 == 8u)
                                    {
                                        _10495 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3780, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10496;
                                        if (_4739)
                                        {
                                            uint _8529_dummy_parameter;
                                            uint _8561_dummy_parameter;
                                            _10496 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3780 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8529_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3780 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8561_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10497;
                                            if (_4742)
                                            {
                                                _10497 = _6263;
                                            }
                                            else
                                            {
                                                float3 _10498;
                                                if (_4735 == 20u)
                                                {
                                                    _10498 = _6247;
                                                }
                                                else
                                                {
                                                    float3 _10499;
                                                    if (_4735 == 21u)
                                                    {
                                                        _10499 = _6255;
                                                    }
                                                    else
                                                    {
                                                        float3 _10500;
                                                        if (_4735 == 22u)
                                                        {
                                                            _10500 = _6271;
                                                        }
                                                        else
                                                        {
                                                            float3 _10501;
                                                            if (_4735 == 18u)
                                                            {
                                                                _10501 = _10207;
                                                            }
                                                            else
                                                            {
                                                                float3 _10502;
                                                                if (_4735 == 19u)
                                                                {
                                                                    _10502 = _10063;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10738 = (_4735 == 23u).xxx;
                                                                    _10502 = float3(_10738.x ? _9926.x : _10505.x, _10738.y ? _9926.y : _10505.y, _10738.z ? _9926.z : _10505.z);
                                                                }
                                                                _10501 = _10502;
                                                            }
                                                            _10500 = _10501;
                                                        }
                                                        _10499 = _10500;
                                                    }
                                                    _10498 = _10499;
                                                }
                                                _10497 = _10498;
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
        float3 _10487;
        if ((_4735 >= 9u) && (_4735 <= 11u))
        {
            uint _5211 = 64u + uint((_9155.y * cbFI_MvDepthLaneSize.x) + _9155.x);
            uint _5215 = rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) & 15u;
            float3 _10518;
            if (_4735 == 10u)
            {
                float3 _10486;
                if ((rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) & 32u) != 0u)
                {
                    _10486 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10485;
                    if ((rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) & 16u) != 0u)
                    {
                        _10485 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5236 = ((rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) & 64u) != 0u).xxx;
                        _10485 = float3(_5236.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5236.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5236.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10486 = _10485;
                }
                _10518 = _10486;
            }
            else
            {
                float3 _10519;
                if (_4735 == 11u)
                {
                    uint _5249 = (rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) >> 8u) & 15u;
                    uint _5252 = (rw_nfru_diagnostics.Load<uint>(_5211 * 4 + 0) >> 12u) & 15u;
                    float3 _10478;
                    if ((_5215 == 2u) || (_5215 == 3u))
                    {
                        _10478 = _3101[_5215];
                    }
                    else
                    {
                        bool _5264 = _5249 == 3u;
                        bool _5266 = _5252 == 3u;
                        float3 _10479;
                        if (_5264 && _5266)
                        {
                            _10479 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10480;
                            if (_5264)
                            {
                                _10480 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10481;
                                if (_5266)
                                {
                                    _10481 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10482;
                                    if ((_5249 == 4u) || (_5252 == 4u))
                                    {
                                        _10482 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10483;
                                        if ((_5249 == 1u) || (_5252 == 1u))
                                        {
                                            _10483 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10740 = (_5215 == 1u).xxx;
                                            _10483 = float3(_10740.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10740.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10740.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10482 = _10483;
                                    }
                                    _10481 = _10482;
                                }
                                _10480 = _10481;
                            }
                            _10479 = _10480;
                        }
                        _10478 = _10479;
                    }
                    _10519 = _10478;
                }
                else
                {
                    _10519 = _3101[min(_5215, 7u)];
                }
                _10518 = _10519;
            }
            _10487 = _10518;
        }
        else
        {
            _10487 = _10488;
        }
        float4 _10522;
        if ((_4735 >= 14u) && (_4735 <= 16u))
        {
            float2 _10520;
            if (_4735 == 14u)
            {
                uint _5322_dummy_parameter;
                uint _5328_dummy_parameter;
                _10520 = r_flow_tm1.Load(int3(clamp(int2(floor(_3780 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5322_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5328_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10521;
                if (_4735 == 16u)
                {
                    uint _8612 = r_warped_flow_qdata_tm1.Load(int3(_3796, 0)).x & 2147483647u;
                    uint _8644 = uint(max((int((_8612 >> 16u) & 15u) - 6), 0));
                    _10521 = ((float2(float((1 - (2 * int((_8612 >> 15u) & 1u))) * int(((_8612 >> uint(7)) & 127u) << _8644)), float((1 - (2 * int((_8612 >> 14u) & 1u))) * int((_8612 & 127u) << _8644))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10521 = _5542 * float2(cbFI_DisplaySize);
                }
                _10520 = _10521;
            }
            uint2 _5361 = uint2(clamp(round(_10520 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5363 = _5361.x;
            uint _5370 = _5361.y;
            _10522 = float4(float(_5363 & 255u), float((_5363 >> 8u) | ((_5370 & 15u) << 4u)), float(_5370 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10523;
            if (_4735 == 17u)
            {
                _10523 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3796, 0)).x != 0u), _4139, 0.0f, 1.0f);
            }
            else
            {
                _10523 = float4(_10487, 1.0f);
            }
            _10522 = _10523;
        }
        rw_output[_3405] = _10522.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5414 = ((uint(_3405.y) * uint(cbFI_DisplaySize.x)) + uint(_3405.x)) * 6u;
            uint _8690 = spvPackHalf2x16(clamp(_6246.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5414 * 4 + 0, (((_8690 & 32767u) >> 4u) | ((((_8690 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6246.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8725 = spvPackHalf2x16(clamp(_6254.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5414 + 1u) * 4 + 0, (((_8725 & 32767u) >> 4u) | ((((_8725 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6254.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8760 = spvPackHalf2x16(clamp(_6262.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5414 + 2u) * 4 + 0, (((_8760 & 32767u) >> 4u) | ((((_8760 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6262.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8795 = spvPackHalf2x16(clamp(_6270.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5414 + 3u) * 4 + 0, (((_8795 & 32767u) >> 4u) | ((((_8795 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6270.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8822 = r_current_interpolation_source.Load(int3(_3405, 0));
            uint _8836 = spvPackHalf2x16(clamp(_8822.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5414 + 4u) * 4 + 0, (((_8836 & 32767u) >> 4u) | ((((_8836 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8822.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10556;
            if (_10399 || (_4735 != 0u))
            {
                _10556 = 4294967295u;
            }
            else
            {
                uint _8871 = spvPackHalf2x16(clamp(_10522.xy, 0.0f.xx, 65000.0f.xx));
                _10556 = (((_8871 & 32767u) >> 4u) | ((((_8871 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10522.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5414 + 5u) * 4 + 0, _10556);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3405] = float4(r_current_interpolation_source.Load(int3(_3405, 0)).xyz, 1.0f).xyz;
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
