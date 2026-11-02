static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3012[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3299 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3299.x >= cbFI_DisplaySize.x, _3299.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3299] = float4(r_present_backbuffer.Load(int3(_3299, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3649 = (float2(_3299) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3660 = int2(floor(_3649 * float2(cbFI_MvDepthLaneSize)));
        int2 _3665 = int2(floor(_3649 * float2(cbFI_FlowLaneSize)));
        float4 _5326 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3649 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5332 = r_warped_filled_flow_tm1.Load(int3(_3665, 0)).xy;
        float2 _5338 = r_warped_filled_motion_tp1.Load(int3(_3660, 0)).xy;
        bool _5360 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8746;
        if (_5360)
        {
            float _5373 = ((2.0f * _3649.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8746 = float2(atan(_5373) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3649.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5373 * _5373))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8746 = _3649;
        }
        bool _3686 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8767;
        bool _8788;
        int2 _8799;
        float3 _9690;
        if (_3686)
        {
            float _8748;
            float _8750;
            _8750 = 2.0f;
            _8748 = -1.0f;
            uint _3361[9];
            float _10074;
            float _10077;
            for (int _8747 = 0; _8747 < 9; _8750 = _10077, _8748 = _10074, _8747++)
            {
                _3361[_8747] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3660 + int2((_8747 % 3) - 1, (_8747 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3361[_8747] != 0u)
                {
                    float _10069;
                    if (_3361[_8747] == 0u)
                    {
                        _10069 = -1.0f;
                    }
                    else
                    {
                        _10069 = float((_3361[_8747] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10077 = min(_8750, _10069);
                    _10074 = max(_8748, _10069);
                }
                else
                {
                    _10077 = _8750;
                    _10074 = _8748;
                }
            }
            float _3732 = float(_8748 >= 0.0f);
            float3 _8561 = 0.0f.xxx;
            _8561.y = _3732;
            float2 _8768;
            bool _8789;
            int2 _8800;
            float3 _9691;
            if ((_8748 - _8750) > 0.0199999995529651641845703125f)
            {
                float _8756;
                int2 _8757;
                float2 _8758;
                int2 _8760;
                float2 _8766;
                _8766 = _5338;
                _8760 = _3660;
                _8758 = _5338;
                _8757 = _3660;
                _8756 = -1.0f;
                float _10082;
                int2 _10086;
                float2 _10097;
                int2 _10108;
                float2 _10141;
                float _10186;
                int _8755 = 0;
                float _10050 = 1000000000.0f;
                for (; _8755 < 9; _10050 = _10186, _8766 = _10141, _8760 = _10108, _8758 = _10097, _8757 = _10086, _8756 = _10082, _8755++)
                {
                    if (_3361[_8755] == 0u)
                    {
                        _10186 = _10050;
                        _10141 = _8766;
                        _10108 = _8760;
                        _10097 = _8758;
                        _10086 = _8757;
                        _10082 = _8756;
                        continue;
                    }
                    int2 _3767 = clamp(_3660 + int2((_8755 % 3) - 1, (_8755 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5448 = _3361[_8755] & 2147483647u;
                    uint _5480 = uint(max((int((_5448 >> 16u) & 15u) - 6), 0));
                    float2 _3773 = (float2(float((1 - (2 * int((_5448 >> 15u) & 1u))) * int(((_5448 >> uint(7)) & 127u) << _5480)), float((1 - (2 * int((_5448 >> 14u) & 1u))) * int((_5448 & 127u) << _5480))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10036;
                    if (_3361[_8755] == 0u)
                    {
                        _10036 = -1.0f;
                    }
                    else
                    {
                        _10036 = float((_3361[_8755] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3778 = _10036 - 0.100000001490116119384765625f;
                    float2 _10037;
                    if (_5360)
                    {
                        float2 _5557 = clamp((((_8746 + (_3773 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5560 = tan(_5557.x);
                        _10037 = (float2(_5560 / cbFI_DeviceToViewDepth.z, (tan(_5557.y) * sqrt(1.0f + (_5560 * _5560))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10037 = _8746 + (_3773 * cbFI_Timestep);
                    }
                    float _3785 = cbFI_Timestep - 1.0f;
                    float2 _10038;
                    if (_5360)
                    {
                        float2 _5628 = clamp((((_8746 + (_3773 * _3785)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5631 = tan(_5628.x);
                        _10038 = (float2(_5631 / cbFI_DeviceToViewDepth.z, (tan(_5628.y) * sqrt(1.0f + (_5631 * _5631))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10038 = _8746 + (_3773 * _3785);
                    }
                    bool _5664 = all(bool2(_10037.x > 0.0f.xx.x, _10037.y > 0.0f.xx.y));
                    bool _5670;
                    if (_5664)
                    {
                        _5670 = all(bool2(_10037.x < 1.0f.xx.x, _10037.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5670 = _5664;
                    }
                    float _10041;
                    if (_5670)
                    {
                        uint _5677_dummy_parameter;
                        _10041 = max((_3778 - (log((r_depth_tm1.Load(int3(int2(floor(_10037 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5677_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10041 = 0.0f;
                    }
                    bool _5707 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
                    bool _5713;
                    if (_5707)
                    {
                        _5713 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5713 = _5707;
                    }
                    float _10042;
                    if (_5713)
                    {
                        uint _5720_dummy_parameter;
                        _10042 = _10041 + max((_3778 - (log((r_depth_tp1.Load(int3(int2(floor(_10038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5720_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10042 = _10041;
                    }
                    float _10083;
                    int2 _10087;
                    float2 _10098;
                    int2 _10109;
                    float2 _10142;
                    float _10187;
                    if (_10042 == 0.0f)
                    {
                        bool _3820 = _3778 > _8756;
                        bool2 _10195 = _3820.xx;
                        _10187 = _10050;
                        _10142 = float2(_10195.x ? _3773.x : _8766.x, _10195.y ? _3773.y : _8766.y);
                        _10109 = int2(_10195.x ? _3767.x : _8760.x, _10195.y ? _3767.y : _8760.y);
                        _10098 = _8758;
                        _10087 = _8757;
                        _10083 = _3820 ? _3778 : _8756;
                    }
                    else
                    {
                        bool _3829 = _10042 < _10050;
                        bool2 _10191 = _3829.xx;
                        _10187 = _3829 ? _10042 : _10050;
                        _10142 = _8766;
                        _10109 = _8760;
                        _10098 = float2(_10191.x ? _3773.x : _8758.x, _10191.y ? _3773.y : _8758.y);
                        _10087 = int2(_10191.x ? _3767.x : _8757.x, _10191.y ? _3767.y : _8757.y);
                        _10083 = _8756;
                    }
                    _10186 = _10187;
                    _10141 = _10142;
                    _10108 = _10109;
                    _10097 = _10098;
                    _10086 = _10087;
                    _10082 = _10083;
                }
                bool _3841 = _8756 < 0.0f;
                bool2 _10201 = _3841.xx;
                int2 _10204 = int2(_10201.x ? _8757.x : _8760.x, _10201.y ? _8757.y : _8760.y);
                _9691 = float3(1.0f, _3732, float(any(bool2(_10204.x != _3660.x, _10204.y != _3660.y))));
                _8800 = _10204;
                _8789 = _3841 ? false : true;
                _8768 = float2(_10201.x ? _8758.x : _8766.x, _10201.y ? _8758.y : _8766.y);
            }
            else
            {
                _9691 = _8561;
                _8800 = _3660;
                _8789 = false;
                _8768 = _5338;
            }
            _9690 = _9691;
            _8799 = _8800;
            _8788 = _8789;
            _8767 = _8768;
        }
        else
        {
            _9690 = 0.0f.xxx;
            _8799 = _3660;
            _8788 = false;
            _8767 = _5338;
        }
        float2 _8769;
        if (_5360)
        {
            float2 _5785 = clamp((((_8746 + (_8767 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5788 = tan(_5785.x);
            _8769 = (float2(_5788 / cbFI_DeviceToViewDepth.z, (tan(_5785.y) * sqrt(1.0f + (_5788 * _5788))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8769 = _8746 + (_8767 * cbFI_Timestep);
        }
        float _3864 = cbFI_Timestep - 1.0f;
        float2 _8771;
        if (_5360)
        {
            float2 _5856 = clamp((((_8746 + (_8767 * _3864)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5859 = tan(_5856.x);
            _8771 = (float2(_5859 / cbFI_DeviceToViewDepth.z, (tan(_5856.y) * sqrt(1.0f + (_5859 * _5859))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8771 = _8746 + (_8767 * _3864);
        }
        float _3869 = -cbFI_Timestep;
        float2 _8772;
        if (_5360)
        {
            float2 _5927 = clamp((((_8746 + (_5332 * _3869)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5930 = tan(_5927.x);
            _8772 = (float2(_5930 / cbFI_DeviceToViewDepth.z, (tan(_5927.y) * sqrt(1.0f + (_5930 * _5930))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8772 = _8746 + (_5332 * _3869);
        }
        float _3874 = 1.0f - cbFI_Timestep;
        float2 _8773;
        if (_5360)
        {
            float2 _5998 = clamp((((_8746 + (_5332 * _3874)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6001 = tan(_5998.x);
            _8773 = (float2(_6001 / cbFI_DeviceToViewDepth.z, (tan(_5998.y) * sqrt(1.0f + (_6001 * _6001))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8773 = _8746 + (_5332 * _3874);
        }
        float4 _6036 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8769, 0.0f);
        float3 _6037 = _6036.xyz;
        float4 _6044 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8771, 0.0f);
        float3 _6045 = _6044.xyz;
        float4 _6052 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8772, 0.0f);
        float3 _6053 = _6052.xyz;
        float4 _6060 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8773, 0.0f);
        float3 _6061 = _6060.xyz;
        float4 _6075 = exp(_5326 - max(max(max(_5326.x, _5326.y), _5326.z), _5326.w).xxxx);
        float4 _6082 = _6075 / (dot(_6075, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3893 = _3686 && (!_8788);
        bool _3902;
        if (_3893)
        {
            _3902 = (_6082.z + _6082.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3902 = _3893;
        }
        bool _3913;
        if (_3902)
        {
            _3913 = length((_8772 - _8769) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3913 = _3902;
        }
        bool _8812;
        if (_3913)
        {
            uint4 _6101 = r_warped_motion_qdata_tp1.Load(int3(_8799, 0));
            uint _6102 = _6101.x;
            bool _8815;
            if (_6102 != 0u)
            {
                float _8801;
                if (_6102 == 0u)
                {
                    _8801 = -1.0f;
                }
                else
                {
                    _8801 = float((_6102 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3923 = _8801 - 0.12000000476837158203125f;
                bool _6121 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                bool _6127;
                if (_6121)
                {
                    _6127 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                }
                else
                {
                    _6127 = _6121;
                }
                bool _3933;
                if (_6127)
                {
                    uint _6134_dummy_parameter;
                    _3933 = (log((r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6134_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3923;
                }
                else
                {
                    _3933 = _6127;
                }
                bool _3947;
                if (!_3933)
                {
                    bool _6164 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                    bool _6170;
                    if (_6164)
                    {
                        _6170 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6170 = _6164;
                    }
                    bool _3945;
                    if (_6170)
                    {
                        uint _6177_dummy_parameter;
                        _3945 = (log((r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6177_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3923;
                    }
                    else
                    {
                        _3945 = _6170;
                    }
                    _3947 = _3945;
                }
                else
                {
                    _3947 = _3933;
                }
                _8815 = _3947;
            }
            else
            {
                _8815 = false;
            }
            _8812 = _8815;
        }
        else
        {
            _8812 = false;
        }
        bool _3952 = _8788 || _8812;
        bool _3957;
        if (_3952)
        {
            bool _6207 = all(bool2(_8769.x > 0.0f.xx.x, _8769.y > 0.0f.xx.y));
            bool _6213;
            if (_6207)
            {
                _6213 = all(bool2(_8769.x < 1.0f.xx.x, _8769.y < 1.0f.xx.y));
            }
            else
            {
                _6213 = _6207;
            }
            _3957 = _6213;
        }
        else
        {
            _3957 = _3952;
        }
        bool _3962;
        if (_3957)
        {
            bool _6218 = all(bool2(_8771.x > 0.0f.xx.x, _8771.y > 0.0f.xx.y));
            bool _6224;
            if (_6218)
            {
                _6224 = all(bool2(_8771.x < 1.0f.xx.x, _8771.y < 1.0f.xx.y));
            }
            else
            {
                _6224 = _6218;
            }
            _3962 = _6224;
        }
        else
        {
            _3962 = _3957;
        }
        float4 _8906;
        if (_3962)
        {
            float _3965 = _6082.x;
            float _3967 = _6082.y;
            float _3968 = _3965 + _3967;
            float _3973 = _6082.z + _6082.w;
            float _8830;
            if (_3968 > 0.001000000047497451305389404296875f)
            {
                _8830 = _3965 / _3968;
            }
            else
            {
                _8830 = _3874;
            }
            _8906 = float4(_3965 + (_3973 * _8830), _3967 + (_3973 * (1.0f - _8830)), 0.0f, 0.0f);
        }
        else
        {
            _8906 = _6082;
        }
        bool _6252 = (cbFI_pad0 & 1024u) != 0u;
        bool _6228 = !_6252;
        bool _6229 = !_6228;
        bool _6246;
        if (_6229)
        {
            _6246 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8799.y * cbFI_MvDepthLaneSize.x) + _8799.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6246 = _6228;
        }
        bool _6278;
        if (_6229)
        {
            _6278 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3665.y * cbFI_FlowLaneSize.x) + _3665.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6278 = _6228;
        }
        float _4008 = float(_6278);
        bool _8918;
        float4 _8948;
        float3 _9550;
        if (_6252)
        {
            bool _4018;
            if (_6246)
            {
                _4018 = all(bool2(_8769.x > 0.0f.xx.x, _8769.y > 0.0f.xx.y));
            }
            else
            {
                _4018 = _6246;
            }
            bool _4024;
            if (_4018)
            {
                _4024 = all(bool2(_8769.x < 1.0f.xx.x, _8769.y < 1.0f.xx.y));
            }
            else
            {
                _4024 = _4018;
            }
            bool _4031;
            if (_6246)
            {
                _4031 = all(bool2(_8771.x > 0.0f.xx.x, _8771.y > 0.0f.xx.y));
            }
            else
            {
                _4031 = _6246;
            }
            bool _4037;
            if (_4031)
            {
                _4037 = all(bool2(_8771.x < 1.0f.xx.x, _8771.y < 1.0f.xx.y));
            }
            else
            {
                _4037 = _4031;
            }
            bool _4044;
            if (_6278)
            {
                _4044 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
            }
            else
            {
                _4044 = _6278;
            }
            bool _4050;
            if (_4044)
            {
                _4050 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
            }
            else
            {
                _4050 = _4044;
            }
            bool _4057;
            if (_6278)
            {
                _4057 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
            }
            else
            {
                _4057 = _6278;
            }
            bool _4063;
            if (_4057)
            {
                _4063 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
            }
            else
            {
                _4063 = _4057;
            }
            bool _4065 = !_6246;
            if (_4065)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6320;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6320);
                }
            }
            bool _4070 = !_6278;
            if (_4070)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6330;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6330);
                }
            }
            if (_6246 && _4070)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6340;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6340);
                }
            }
            if (_4065 && _6278)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6350;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6350);
                }
            }
            float _4089 = float(_4024);
            float _4091 = float(_4037);
            bool _4094 = _4050 && _4063;
            float _8864;
            if (_4094)
            {
                _8864 = 1.0f;
            }
            else
            {
                _8864 = (_4050 || _4063) ? 0.5f : 0.0f;
            }
            bool _8869;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4024)) && (!_4037))
            {
                bool _4124;
                if (_4094)
                {
                    float _8867;
                    do
                    {
                        bool _6434 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                        bool _6440;
                        if (_6434)
                        {
                            _6440 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6440 = _6434;
                        }
                        bool _6371 = !_6440;
                        bool _6378;
                        if (!_6371)
                        {
                            bool _6445 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                            bool _6451;
                            if (_6445)
                            {
                                _6451 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6451 = _6445;
                            }
                            _6378 = !_6451;
                        }
                        else
                        {
                            _6378 = _6371;
                        }
                        if (_6378)
                        {
                            _8867 = 0.0f;
                            break;
                        }
                        uint _6458_dummy_parameter;
                        uint _6474_dummy_parameter;
                        float4 _6399 = mul(float4((float2(_8772.x, 1.0f - _8772.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6458_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6401 = _6399.w;
                        if (abs(_6401) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8867 = 0.0f;
                            break;
                        }
                        float _6412 = abs(cbFI_DeviceToViewDepth.y / ((_6399.z / _6401) - cbFI_DeviceToViewDepth.x));
                        float _6415 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6474_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8867 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6412 - _6415) / max(max(_6412, _6415), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4124 = _8867 >= 0.5f;
                }
                else
                {
                    _4124 = _4094;
                }
                bool _8870;
                if (_4124)
                {
                    uint _6524_dummy_parameter;
                    float2 _8868;
                    do
                    {
                        float _6550 = 1.0f - _8772.y;
                        float4 _6561 = mul(float4((float2(_8772.x, _6550) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6524_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6563 = _6561.w;
                        if (!(_6563 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8868 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6576 = ((_6561.xy / _6563.xx) + 1.0f.xx) * 0.5f;
                        _8868 = float2(_6576.x - _8772.x, _6550 - _6576.y);
                        break;
                    } while(false);
                    float2 _4138 = float2(cbFI_DisplaySize);
                    _8870 = length(((_8772 + _8868) - _8773) * _4138) <= ((0.100000001490116119384765625f * length(_8868 * _4138)) + 8.0f);
                }
                else
                {
                    _8870 = _4124;
                }
                _8869 = _8870;
            }
            else
            {
                _8869 = true;
            }
            bool _4152 = !_8869;
            bool _10205 = _4152 ? false : _4063;
            bool _10206 = _4152 ? false : _4050;
            bool _8919;
            float4 _8949;
            if (!(((_4024 && _4037) && _10206) && _10205))
            {
                float4 _4174 = _8906 * float4(_4089, _4091, float(_10206), float(_10205));
                float _4176 = dot(_4174, 1.0f.xxxx);
                bool _4179 = !(_4176 > 0.0f);
                float4 _8950;
                if (!_4179)
                {
                    _8950 = _4174 / _4176.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6598;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6598);
                    }
                    _8950 = 0.0f.xxxx;
                }
                _8949 = _8950;
                _8919 = _4179;
            }
            else
            {
                _8949 = _8906;
                _8919 = false;
            }
            _9550 = float3(_4089, _4091, _8864);
            _8948 = _8949;
            _8918 = _8919;
        }
        else
        {
            _9550 = float3(float(_6246), _4008, 0.0f);
            _8948 = _8906;
            _8918 = false;
        }
        float4 _9420;
        bool _9440;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8918))
        {
            bool _4202 = _8948.x > 0.00999999977648258209228515625f;
            bool _4205 = _8948.y > 0.00999999977648258209228515625f;
            bool _4214 = (_8948.z + _8948.w) > 0.0199999995529651641845703125f;
            bool _4220;
            if (_4214)
            {
                bool _6604 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                bool _6610;
                if (_6604)
                {
                    _6610 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                }
                else
                {
                    _6610 = _6604;
                }
                _4220 = _6610;
            }
            else
            {
                _4220 = _4214;
            }
            bool _4225;
            if (_4220)
            {
                bool _6615 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                bool _6621;
                if (_6615)
                {
                    _6621 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                }
                else
                {
                    _6621 = _6615;
                }
                _4225 = _6621;
            }
            else
            {
                _4225 = _4220;
            }
            bool _4232;
            if (_4225)
            {
                float _8952;
                do
                {
                    bool _6704 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                    bool _6710;
                    if (_6704)
                    {
                        _6710 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6710 = _6704;
                    }
                    bool _6641 = !_6710;
                    bool _6648;
                    if (!_6641)
                    {
                        bool _6715 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                        bool _6721;
                        if (_6715)
                        {
                            _6721 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6721 = _6715;
                        }
                        _6648 = !_6721;
                    }
                    else
                    {
                        _6648 = _6641;
                    }
                    if (_6648)
                    {
                        _8952 = 0.0f;
                        break;
                    }
                    uint _6728_dummy_parameter;
                    uint _6744_dummy_parameter;
                    float4 _6669 = mul(float4((float2(_8772.x, 1.0f - _8772.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6728_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6671 = _6669.w;
                    if (abs(_6671) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8952 = 0.0f;
                        break;
                    }
                    float _6682 = abs(cbFI_DeviceToViewDepth.y / ((_6669.z / _6671) - cbFI_DeviceToViewDepth.x));
                    float _6685 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6744_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8952 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6682 - _6685) / max(max(_6682, _6685), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4232 = _8952 < 0.5f;
            }
            else
            {
                _4232 = _4225;
            }
            float4 _8967;
            if (_4232)
            {
                uint _6794_dummy_parameter;
                uint _6825_dummy_parameter;
                float4 _8968;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6794_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6825_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _8968 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _8968 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _8967 = _8968;
            }
            else
            {
                _8967 = 1.0f.xxxx;
            }
            bool _4256;
            if (_6246)
            {
                bool _6854 = all(bool2(_8769.x > 0.0f.xx.x, _8769.y > 0.0f.xx.y));
                bool _6860;
                if (_6854)
                {
                    _6860 = all(bool2(_8769.x < 1.0f.xx.x, _8769.y < 1.0f.xx.y));
                }
                else
                {
                    _6860 = _6854;
                }
                _4256 = _6860;
            }
            else
            {
                _4256 = _6246;
            }
            bool _4262;
            if (_6246)
            {
                bool _6865 = all(bool2(_8771.x > 0.0f.xx.x, _8771.y > 0.0f.xx.y));
                bool _6871;
                if (_6865)
                {
                    _6871 = all(bool2(_8771.x < 1.0f.xx.x, _8771.y < 1.0f.xx.y));
                }
                else
                {
                    _6871 = _6865;
                }
                _4262 = _6871;
            }
            else
            {
                _4262 = _6246;
            }
            bool _4268;
            if (_6278)
            {
                bool _6876 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                bool _6882;
                if (_6876)
                {
                    _6882 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                }
                else
                {
                    _6882 = _6876;
                }
                _4268 = _6882;
            }
            else
            {
                _4268 = _6278;
            }
            bool _4274;
            if (_6278)
            {
                bool _6887 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                bool _6893;
                if (_6887)
                {
                    _6893 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                }
                else
                {
                    _6893 = _6887;
                }
                _4274 = _6893;
            }
            else
            {
                _4274 = _6278;
            }
            bool _4277 = _4268 != _4274;
            bool _4283;
            if (_4277)
            {
                _4283 = _4256 || _4262;
            }
            else
            {
                _4283 = _4277;
            }
            float4 _9070;
            if (_4283)
            {
                float4 _8646 = _8967;
                _8646.z = 0.0f;
                _8646.w = 0.0f;
                _9070 = _8646;
            }
            else
            {
                _9070 = _8967;
            }
            bool _4290 = _4256 && _4202;
            bool _4293 = _4262 && _4205;
            float4 _9145;
            if (_4290 || _4293)
            {
                float _9044;
                do
                {
                    uint4 _7032 = r_warped_motion_qdata_tp1.Load(int3(_8799, 0));
                    uint _7033 = _7032.x;
                    if (_7033 != 0u)
                    {
                        float _9043;
                        if (_7033 == 0u)
                        {
                            _9043 = -1.0f;
                        }
                        else
                        {
                            _9043 = float((_7033 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9044 = _9043;
                        break;
                    }
                    int _9026;
                    uint _9027;
                    _9027 = _7033;
                    _9026 = -1;
                    uint _9042;
                    for (; _9026 <= 1; _9027 = _9042, _9026++)
                    {
                        _9042 = _9027;
                        for (int _9040 = -1; _9040 <= 1; )
                        {
                            _9042 = max(_9042, r_warped_motion_qdata_tp1.Load(int3(clamp(_8799 + int2(_9040, _9026), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9040++;
                            continue;
                        }
                    }
                    if (_9027 != 0u)
                    {
                        float _9039;
                        if (_9027 == 0u)
                        {
                            _9039 = -1.0f;
                        }
                        else
                        {
                            _9039 = float((_9027 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9044 = _9039;
                        break;
                    }
                    uint _9029;
                    _9029 = 4294967295u;
                    uint _10178;
                    for (int _9028 = 0; _9028 < 8; _9029 = _10178, _9028++)
                    {
                        int _9032 = 0;
                        for (;;)
                        {
                            if (_9032 < 5)
                            {
                                int2 _6983 = _8799 + (_1085[_9028] * _1094[_9032].xx);
                                bool _6986 = any(bool2(_6983.x < int2(0, 0).x, _6983.y < int2(0, 0).y));
                                bool _6994;
                                if (!_6986)
                                {
                                    _6994 = any(bool2(_6983.x >= cbFI_MvDepthLaneSize.x, _6983.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _6994 = _6986;
                                }
                                if (_6994)
                                {
                                    _10178 = _9029;
                                    break;
                                }
                                uint4 _7072 = r_warped_motion_qdata_tp1.Load(int3(_6983, 0));
                                uint _7073 = _7072.x;
                                if (_7073 != 0u)
                                {
                                    _10178 = min(_9029, _7073);
                                    break;
                                }
                                _9032++;
                                continue;
                            }
                            else
                            {
                                _10178 = _9029;
                                break;
                            }
                        }
                    }
                    float _9031;
                    if (_9029 == 4294967295u)
                    {
                        _9031 = -1.0f;
                    }
                    else
                    {
                        float _9030;
                        if (_9029 == 0u)
                        {
                            _9030 = -1.0f;
                        }
                        else
                        {
                            _9030 = float((_9029 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9031 = _9030;
                    }
                    _9044 = _9031;
                    break;
                } while(false);
                float _4304 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4306 = _9044 >= 0.0f;
                float _9051;
                if (_4306)
                {
                    _9051 = _9044 - _4304;
                }
                else
                {
                    float _9047;
                    if (_4290)
                    {
                        float _9046;
                        _9046 = 2.0f;
                        float _7144;
                        for (int _9045 = 0; _9045 < 24; _9046 = _7144, _9045++)
                        {
                            float _7108 = float(_9045 & 7) * 0.785398185253143310546875f;
                            int _7110 = _9045 >> 3;
                            int _9048;
                            if (_7110 == 0)
                            {
                                _9048 = 16;
                            }
                            else
                            {
                                _9048 = (_7110 == 1) ? 48 : 96;
                            }
                            uint _7160_dummy_parameter;
                            _7144 = min(_9046, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8769 + ((cbFI_MvDepthLaneSizeRcp * float(_9048)) * float2(cos(_7108), sin(_7108))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7160_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9047 = _9046;
                    }
                    else
                    {
                        _9047 = 0.0f;
                    }
                    _9051 = _9047;
                }
                float _9058;
                if (_4306)
                {
                    _9058 = _9044 - _4304;
                }
                else
                {
                    float _9054;
                    if (_4293)
                    {
                        float _9053;
                        _9053 = 2.0f;
                        float _7258;
                        for (int _9052 = 0; _9052 < 24; _9053 = _7258, _9052++)
                        {
                            float _7222 = float(_9052 & 7) * 0.785398185253143310546875f;
                            int _7224 = _9052 >> 3;
                            int _9055;
                            if (_7224 == 0)
                            {
                                _9055 = 16;
                            }
                            else
                            {
                                _9055 = (_7224 == 1) ? 48 : 96;
                            }
                            uint _7290_dummy_parameter;
                            _7258 = min(_9053, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8771 + ((cbFI_MvDepthLaneSizeRcp * float(_9055)) * float2(cos(_7222), sin(_7222))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7290_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9054 = _9053;
                    }
                    else
                    {
                        _9054 = 0.0f;
                    }
                    _9058 = _9054;
                }
                float _9059;
                if (_4290)
                {
                    uint _7322_dummy_parameter;
                    _9059 = r_depth_tm1.Load(int3(int2(floor(_8769 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7322_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9059 = 0.0f;
                }
                float _9060;
                if (_4293)
                {
                    uint _7341_dummy_parameter;
                    _9060 = r_depth_tp1.Load(int3(int2(floor(_8771 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7341_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9060 = 0.0f;
                }
                bool _4361;
                if (_4290)
                {
                    _4361 = _9059 > ((exp((_9051 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4361 = _4290;
                }
                float4 _9085;
                if (_4361)
                {
                    float4 _8650 = _9070;
                    _8650.x = 0.0f;
                    _9085 = _8650;
                }
                else
                {
                    _9085 = _9070;
                }
                bool _4373;
                if (_4293)
                {
                    _4373 = _9060 > ((exp((_9058 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4373 = _4293;
                }
                float4 _9087;
                if (_4373)
                {
                    float4 _8652 = _9085;
                    _8652.y = 0.0f;
                    _9087 = _8652;
                }
                else
                {
                    _9087 = _9085;
                }
                float4 _9146;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4306)
                {
                    bool _4393;
                    if (_4290)
                    {
                        _4393 = _9059 < ((exp((_9051 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4393 = _4290;
                    }
                    float4 _9089;
                    if (_4393)
                    {
                        float4 _8654 = _9087;
                        _8654.x = 0.0f;
                        _9089 = _8654;
                    }
                    else
                    {
                        _9089 = _9087;
                    }
                    bool _4405;
                    if (_4293)
                    {
                        _4405 = _9060 < ((exp((_9058 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4405 = _4293;
                    }
                    float4 _9147;
                    if (_4405)
                    {
                        float4 _8656 = _9089;
                        _8656.y = 0.0f;
                        _9147 = _8656;
                    }
                    else
                    {
                        _9147 = _9089;
                    }
                    _9146 = _9147;
                }
                else
                {
                    _9146 = _9087;
                }
                _9145 = _9146;
            }
            else
            {
                _9145 = _9070;
            }
            bool _4416 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4214;
            bool _4422;
            if (_4416)
            {
                _4422 = _4268 || _4274;
            }
            else
            {
                _4422 = _4416;
            }
            float4 _9167;
            if (_4422)
            {
                float _9140;
                do
                {
                    uint4 _7520 = r_warped_motion_qdata_tp1.Load(int3(_8799, 0));
                    uint _7521 = _7520.x;
                    if (_7521 != 0u)
                    {
                        float _9139;
                        if (_7521 == 0u)
                        {
                            _9139 = -1.0f;
                        }
                        else
                        {
                            _9139 = float((_7521 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9140 = _9139;
                        break;
                    }
                    int _9122;
                    uint _9123;
                    _9123 = _7521;
                    _9122 = -1;
                    uint _9138;
                    for (; _9122 <= 1; _9123 = _9138, _9122++)
                    {
                        _9138 = _9123;
                        for (int _9136 = -1; _9136 <= 1; )
                        {
                            _9138 = max(_9138, r_warped_motion_qdata_tp1.Load(int3(clamp(_8799 + int2(_9136, _9122), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9136++;
                            continue;
                        }
                    }
                    if (_9123 != 0u)
                    {
                        float _9135;
                        if (_9123 == 0u)
                        {
                            _9135 = -1.0f;
                        }
                        else
                        {
                            _9135 = float((_9123 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9140 = _9135;
                        break;
                    }
                    uint _9125;
                    _9125 = 4294967295u;
                    uint _10179;
                    for (int _9124 = 0; _9124 < 8; _9125 = _10179, _9124++)
                    {
                        int _9128 = 0;
                        for (;;)
                        {
                            if (_9128 < 5)
                            {
                                int2 _7471 = _8799 + (_1085[_9124] * _1094[_9128].xx);
                                bool _7474 = any(bool2(_7471.x < int2(0, 0).x, _7471.y < int2(0, 0).y));
                                bool _7482;
                                if (!_7474)
                                {
                                    _7482 = any(bool2(_7471.x >= cbFI_MvDepthLaneSize.x, _7471.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7482 = _7474;
                                }
                                if (_7482)
                                {
                                    _10179 = _9125;
                                    break;
                                }
                                uint4 _7560 = r_warped_motion_qdata_tp1.Load(int3(_7471, 0));
                                uint _7561 = _7560.x;
                                if (_7561 != 0u)
                                {
                                    _10179 = min(_9125, _7561);
                                    break;
                                }
                                _9128++;
                                continue;
                            }
                            else
                            {
                                _10179 = _9125;
                                break;
                            }
                        }
                    }
                    float _9127;
                    if (_9125 == 4294967295u)
                    {
                        _9127 = -1.0f;
                    }
                    else
                    {
                        float _9126;
                        if (_9125 == 0u)
                        {
                            _9126 = -1.0f;
                        }
                        else
                        {
                            _9126 = float((_9125 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9127 = _9126;
                    }
                    _9140 = _9127;
                    break;
                } while(false);
                float4 _9168;
                if (_9140 >= 0.0f)
                {
                    float _7582 = (exp((_9140 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4441;
                    if (_4268)
                    {
                        uint _7589_dummy_parameter;
                        _4441 = r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7589_dummy_parameter))))), 0)).x > _7582;
                    }
                    else
                    {
                        _4441 = _4268;
                    }
                    float4 _9158;
                    if (_4441)
                    {
                        float4 _8658 = _9145;
                        _8658.z = 0.0f;
                        _9158 = _8658;
                    }
                    else
                    {
                        _9158 = _9145;
                    }
                    bool _4453;
                    if (_4274)
                    {
                        uint _7608_dummy_parameter;
                        _4453 = r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7608_dummy_parameter))))), 0)).x > _7582;
                    }
                    else
                    {
                        _4453 = _4274;
                    }
                    float4 _9169;
                    if (_4453)
                    {
                        float4 _8660 = _9158;
                        _8660.w = 0.0f;
                        _9169 = _8660;
                    }
                    else
                    {
                        _9169 = _9158;
                    }
                    _9168 = _9169;
                }
                else
                {
                    _9168 = _9145;
                }
                _9167 = _9168;
            }
            else
            {
                _9167 = _9145;
            }
            bool _4461 = _4256 != _4262;
            bool _4468;
            if (_4461)
            {
                _4468 = _4256 ? _4202 : _4205;
            }
            else
            {
                _4468 = _4461;
            }
            float4 _9247;
            if (_4468)
            {
                bool2 _4473 = _4256.xx;
                float2 _4474 = float2(_4473.x ? _8769.x : _8771.x, _4473.y ? _8769.y : _8771.y);
                float _9160;
                if (_4256)
                {
                    uint _7627_dummy_parameter;
                    _9160 = r_depth_tm1.Load(int3(int2(floor(_4474 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7627_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7643_dummy_parameter;
                    _9160 = r_depth_tp1.Load(int3(int2(floor(_4474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7643_dummy_parameter))))), 0)).x;
                }
                float4x4 _9161;
                if (_4256)
                {
                    _9161 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9161 = cbFI_MotionTP1ToTM1;
                }
                float2 _9162;
                do
                {
                    float _7670 = _4474.x;
                    float _7673 = 1.0f - _4474.y;
                    float4 _7684 = mul(float4((float2(_7670, _7673) * 2.0f) - 1.0f.xx, _9160, 1.0f), _9161);
                    float _7686 = _7684.w;
                    if (!(_7686 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9162 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7699 = ((_7684.xy / _7686.xx) + 1.0f.xx) * 0.5f;
                    _9162 = float2(_7699.x - _7670, _7673 - _7699.y);
                    break;
                } while(false);
                float2 _4504 = float2(cbFI_DisplaySize);
                float4 _9248;
                if (!(length(((_4474 + _9162) - float2(_4473.x ? _8771.x : _8769.x, _4473.y ? _8771.y : _8769.y)) * _4504) <= ((0.100000001490116119384765625f * length(_9162 * _4504)) + 8.0f)))
                {
                    float4 _9249;
                    if (_4256)
                    {
                        float4 _8670 = _9167;
                        _8670.x = 0.0f;
                        _9249 = _8670;
                    }
                    else
                    {
                        float4 _8672 = _9167;
                        _8672.y = 0.0f;
                        _9249 = _8672;
                    }
                    _9248 = _9249;
                }
                else
                {
                    _9248 = _9167;
                }
                _9247 = _9248;
            }
            else
            {
                _9247 = _9167;
            }
            float4 _4529 = _8948 * _9247;
            float _4531 = dot(_4529, 1.0f.xxxx);
            float4 _9421;
            bool _9441;
            if (_4531 > 0.0f)
            {
                _9441 = _8918;
                _9421 = _4529 / _4531.xxxx;
            }
            else
            {
                bool _4542 = any(bool4(_9247.x < 1.0f.xxxx.x, _9247.y < 1.0f.xxxx.y, _9247.z < 1.0f.xxxx.z, _9247.w < 1.0f.xxxx.w));
                if (_4542)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7721;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7721);
                    }
                }
                bool4 _10208 = _4542.xxxx;
                _9441 = _4542 ? true : _8918;
                _9421 = float4(_10208.x ? 0.0f.xxxx.x : _8948.x, _10208.y ? 0.0f.xxxx.y : _8948.y, _10208.z ? 0.0f.xxxx.z : _8948.z, _10208.w ? 0.0f.xxxx.w : _8948.w);
            }
            _9440 = _9441;
            _9420 = _9421;
        }
        else
        {
            _9440 = _8918;
            _9420 = _8948;
        }
        uint _4551 = (cbFI_pad0 >> 24u) & 31u;
        uint _4555 = (cbFI_pad0 >> 16u) & 255u;
        bool _4557 = _4551 != 0u;
        bool _4559 = _4555 == 12u;
        bool _4562 = _4555 == 13u;
        float4 _9437;
        if ((_4557 || _4559) || _4562)
        {
            float _9250;
            do
            {
                bool _7805 = all(bool2(_8772.x > 0.0f.xx.x, _8772.y > 0.0f.xx.y));
                bool _7811;
                if (_7805)
                {
                    _7811 = all(bool2(_8772.x < 1.0f.xx.x, _8772.y < 1.0f.xx.y));
                }
                else
                {
                    _7811 = _7805;
                }
                bool _7742 = !_7811;
                bool _7749;
                if (!_7742)
                {
                    bool _7816 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
                    bool _7822;
                    if (_7816)
                    {
                        _7822 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7822 = _7816;
                    }
                    _7749 = !_7822;
                }
                else
                {
                    _7749 = _7742;
                }
                if (_7749)
                {
                    _9250 = 0.0f;
                    break;
                }
                uint _7829_dummy_parameter;
                uint _7845_dummy_parameter;
                float4 _7770 = mul(float4((float2(_8772.x, 1.0f - _8772.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8772 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7829_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7772 = _7770.w;
                if (abs(_7772) < 9.9999999747524270787835121154785e-07f)
                {
                    _9250 = 0.0f;
                    break;
                }
                float _7783 = abs(cbFI_DeviceToViewDepth.y / ((_7770.z / _7772) - cbFI_DeviceToViewDepth.x));
                float _7786 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7845_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9250 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7783 - _7786) / max(max(_7783, _7786), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7893 = all(bool2(_8773.x > 0.0f.xx.x, _8773.y > 0.0f.xx.y));
            bool _7899;
            if (_7893)
            {
                _7899 = all(bool2(_8773.x < 1.0f.xx.x, _8773.y < 1.0f.xx.y));
            }
            else
            {
                _7899 = _7893;
            }
            float _9251;
            if (_7899)
            {
                uint _7906_dummy_parameter;
                _9251 = length((_5332 + (r_motion_tp1.Load(int3(int2(floor(_8773 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7906_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9251 = 1000000.0f;
            }
            float _9262;
            if ((_4551 & 1u) != 0u)
            {
                _9262 = _9250;
            }
            else
            {
                _9262 = 1.0f;
            }
            float _9263;
            if ((_4551 & 2u) != 0u)
            {
                _9263 = _9262 * (1.0f - smoothstep(2.0f, 8.0f, _9251));
            }
            else
            {
                _9263 = _9262;
            }
            float _9264;
            if ((_4551 & 4u) != 0u)
            {
                _9264 = _9263 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6053 - _6061) - length(_6037 - _6045))));
            }
            else
            {
                _9264 = _9263;
            }
            float _9431;
            if ((_4551 & 8u) != 0u)
            {
                _9431 = lerp(1.0f, _9264, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6037 - _6045)));
            }
            else
            {
                _9431 = _9264;
            }
            bool _4637 = (_4551 & 16u) != 0u;
            bool _4646;
            if (_4637)
            {
                _4646 = length(_8767 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4646 = _4637;
            }
            float _10210 = _4646 ? 1.0f : _9431;
            bool _4652 = _4557 && _6246;
            bool _4657;
            if (_4652)
            {
                bool _7931 = all(bool2(_8769.x > 0.0f.xx.x, _8769.y > 0.0f.xx.y));
                bool _7937;
                if (_7931)
                {
                    _7937 = all(bool2(_8769.x < 1.0f.xx.x, _8769.y < 1.0f.xx.y));
                }
                else
                {
                    _7937 = _7931;
                }
                _4657 = _7937;
            }
            else
            {
                _4657 = _4652;
            }
            bool _4662;
            if (_4657)
            {
                bool _7942 = all(bool2(_8771.x > 0.0f.xx.x, _8771.y > 0.0f.xx.y));
                bool _7948;
                if (_7942)
                {
                    _7948 = all(bool2(_8771.x < 1.0f.xx.x, _8771.y < 1.0f.xx.y));
                }
                else
                {
                    _7948 = _7942;
                }
                _4662 = _7948;
            }
            else
            {
                _4662 = _4657;
            }
            float4 _9438;
            if (_4662)
            {
                float _4668 = _9420.x + _9420.y;
                float _4677 = (_9420.z + _9420.w) * (1.0f - _10210);
                float _9434;
                if (_4668 > 9.9999997473787516355514526367188e-06f)
                {
                    _9434 = _9420.x / _4668;
                }
                else
                {
                    _9434 = _3874;
                }
                _9438 = float4(_9420.x + (_4677 * _9434), _9420.y + (_4677 * (1.0f - _9434)), _9420.zw * _10210);
            }
            else
            {
                _9438 = _9420;
            }
            _9437 = _9438;
        }
        else
        {
            _9437 = _9420;
        }
        float3 _9983;
        if (_9440)
        {
            float3 _7954 = r_current_interpolation_source.Load(int3(_3299, 0)).xyz;
            float3 _9984;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6246)
            {
                uint _7961_dummy_parameter;
                float _9540;
                _9540 = r_depth_tm1.Load(int3(int2(floor(_8769 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7961_dummy_parameter))))), 0)).x;
                float _4789;
                for (int _9539 = 0; _9539 < 24; _9540 = _4789, _9539++)
                {
                    float _4761 = float(_9539 & 7) * 0.785398185253143310546875f;
                    int _4763 = _9539 >> 3;
                    int _10033;
                    if (_4763 == 0)
                    {
                        _10033 = 16;
                    }
                    else
                    {
                        _10033 = (_4763 == 1) ? 48 : 96;
                    }
                    uint _7981_dummy_parameter;
                    _4789 = min(_9540, r_depth_tm1.Load(int3(int2(floor(clamp(_8769 + ((cbFI_MvDepthLaneSizeRcp * float(_10033)) * float2(cos(_4761), sin(_4761))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7981_dummy_parameter))))), 0)).x);
                }
                float2 _9541;
                do
                {
                    float _8003 = 1.0f - _8769.y;
                    float4 _8014 = mul(float4((float2(_8769.x, _8003) * 2.0f) - 1.0f.xx, _9540, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8016 = _8014.w;
                    if (!(_8016 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9541 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8029 = ((_8014.xy / _8016.xx) + 1.0f.xx) * 0.5f;
                    _9541 = float2(_8029.x - _8769.x, _8003 - _8029.y);
                    break;
                } while(false);
                float2 _4800 = _8769 + _9541;
                bool _8047 = all(bool2(_4800.x > 0.0f.xx.x, _4800.y > 0.0f.xx.y));
                bool _8053;
                if (_8047)
                {
                    _8053 = all(bool2(_4800.x < 1.0f.xx.x, _4800.y < 1.0f.xx.y));
                }
                else
                {
                    _8053 = _8047;
                }
                float3 _9985;
                if (_8053)
                {
                    float _4806 = abs(cbFI_DeviceToViewDepth.y / (_9540 - cbFI_DeviceToViewDepth.x));
                    uint _8073_dummy_parameter;
                    int2 _8073 = int2(spvTextureSize(r_depth_m2, uint(0), _8073_dummy_parameter));
                    float _4810 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4800 * float2(_8073))), int2(0, 0), _8073 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _9990;
                    if (abs(_4810 - _4806) <= (0.20000000298023223876953125f * max(_4810, _4806)))
                    {
                        uint _8107_dummy_parameter;
                        int2 _8107 = int2(spvTextureSize(r_colour_m2, uint(0), _8107_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8130;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8130);
                        }
                        _9990 = r_colour_m2.Load(int3(clamp(int2(floor(_4800 * float2(_8107))), int2(0, 0), _8107 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8140;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8140);
                        }
                        _9990 = _7954;
                    }
                    _9985 = _9990;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8150;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8150);
                    }
                    _9985 = _7954;
                }
                _9984 = _9985;
            }
            else
            {
                _9984 = _7954;
            }
            _9983 = _9984;
        }
        else
        {
            _9983 = (((_6037 * _9437.x) + (_6045 * _9437.y)) + (_6053 * _9437.z)) + (_6061 * _9437.w);
        }
        uint _4838 = cbFI_pad0 & 255u;
        bool _9878;
        float3 _9982;
        if (_4838 != 0u)
        {
            float3 _4843 = r_present_backbuffer.Load(int3(_3299, 0)).xyz;
            float3 _4847 = r_current_interpolation_source.Load(int3(_3299, 0)).xyz;
            float3 _4851 = abs(_4843 - _4847);
            float3 _9544;
            if (_4838 == 2u)
            {
                _9544 = (abs(_4847) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9544 = 0.000244140625f.xxx;
            }
            bool _4867 = any(bool3(_4851.x > _9544.x, _4851.y > _9544.y, _4851.z > _9544.z));
            bool3 _10211 = _4867.xxx;
            _9982 = float3(_10211.x ? _4843.x : _9983.x, _10211.y ? _4843.y : _9983.y, _10211.z ? _4843.z : _9983.z);
            _9878 = _4867;
        }
        else
        {
            _9982 = _9983;
            _9878 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8165;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8165);
        }
        float3 _9966;
        if (_4555 == 1u)
        {
            _9966 = lerp(_6037, _6045, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _9967;
            if (_4555 == 2u)
            {
                _9967 = lerp(_6053, _6061, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _9968;
                if (_4555 == 3u)
                {
                    _9968 = float(_9878).xxx;
                }
                else
                {
                    float3 _9969;
                    if (_4555 == 4u)
                    {
                        _9969 = float3(((_8767 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _9970;
                        if (_4555 == 5u)
                        {
                            _9970 = float3(((_5332 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _9971;
                            if (_4555 == 6u)
                            {
                                _9971 = float3(_9437.xy, _9437.z + _9437.w);
                            }
                            else
                            {
                                float3 _9972;
                                if (_4555 == 7u)
                                {
                                    _9972 = r_current_interpolation_source.Load(int3(_3299, 0)).xyz;
                                }
                                else
                                {
                                    float3 _9973;
                                    if (_4555 == 8u)
                                    {
                                        _9973 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3649, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _9974;
                                        if (_4559)
                                        {
                                            uint _8187_dummy_parameter;
                                            uint _8219_dummy_parameter;
                                            _9974 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3649 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8187_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3649 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8219_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _9975;
                                            if (_4562)
                                            {
                                                _9975 = _6053;
                                            }
                                            else
                                            {
                                                float3 _9976;
                                                if (_4555 == 20u)
                                                {
                                                    _9976 = _6037;
                                                }
                                                else
                                                {
                                                    float3 _9977;
                                                    if (_4555 == 21u)
                                                    {
                                                        _9977 = _6045;
                                                    }
                                                    else
                                                    {
                                                        float3 _9978;
                                                        if (_4555 == 22u)
                                                        {
                                                            _9978 = _6061;
                                                        }
                                                        else
                                                        {
                                                            float3 _9979;
                                                            if (_4555 == 18u)
                                                            {
                                                                _9979 = _9690;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10213 = (_4555 == 19u).xxx;
                                                                _9979 = float3(_10213.x ? _9550.x : _9982.x, _10213.y ? _9550.y : _9982.y, _10213.z ? _9550.z : _9982.z);
                                                            }
                                                            _9978 = _9979;
                                                        }
                                                        _9977 = _9978;
                                                    }
                                                    _9976 = _9977;
                                                }
                                                _9975 = _9976;
                                            }
                                            _9974 = _9975;
                                        }
                                        _9973 = _9974;
                                    }
                                    _9972 = _9973;
                                }
                                _9971 = _9972;
                            }
                            _9970 = _9971;
                        }
                        _9969 = _9970;
                    }
                    _9968 = _9969;
                }
                _9967 = _9968;
            }
            _9966 = _9967;
        }
        float3 _9965;
        if ((_4555 >= 9u) && (_4555 <= 11u))
        {
            uint _5025 = 64u + uint((_8799.y * cbFI_MvDepthLaneSize.x) + _8799.x);
            uint _5029 = rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) & 15u;
            float3 _9995;
            if (_4555 == 10u)
            {
                float3 _9964;
                if ((rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) & 32u) != 0u)
                {
                    _9964 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _9963;
                    if ((rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) & 16u) != 0u)
                    {
                        _9963 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5050 = ((rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) & 64u) != 0u).xxx;
                        _9963 = float3(_5050.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5050.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5050.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _9964 = _9963;
                }
                _9995 = _9964;
            }
            else
            {
                float3 _9996;
                if (_4555 == 11u)
                {
                    uint _5063 = (rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) >> 8u) & 15u;
                    uint _5066 = (rw_nfru_diagnostics.Load<uint>(_5025 * 4 + 0) >> 12u) & 15u;
                    float3 _9956;
                    if ((_5029 == 2u) || (_5029 == 3u))
                    {
                        _9956 = _3012[_5029];
                    }
                    else
                    {
                        bool _5078 = _5063 == 3u;
                        bool _5080 = _5066 == 3u;
                        float3 _9957;
                        if (_5078 && _5080)
                        {
                            _9957 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _9958;
                            if (_5078)
                            {
                                _9958 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _9959;
                                if (_5080)
                                {
                                    _9959 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _9960;
                                    if ((_5063 == 4u) || (_5066 == 4u))
                                    {
                                        _9960 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _9961;
                                        if ((_5063 == 1u) || (_5066 == 1u))
                                        {
                                            _9961 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10215 = (_5029 == 1u).xxx;
                                            _9961 = float3(_10215.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10215.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10215.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _9960 = _9961;
                                    }
                                    _9959 = _9960;
                                }
                                _9958 = _9959;
                            }
                            _9957 = _9958;
                        }
                        _9956 = _9957;
                    }
                    _9996 = _9956;
                }
                else
                {
                    _9996 = _3012[min(_5029, 7u)];
                }
                _9995 = _9996;
            }
            _9965 = _9995;
        }
        else
        {
            _9965 = _9966;
        }
        float4 _9999;
        if ((_4555 >= 14u) && (_4555 <= 16u))
        {
            float2 _9997;
            if (_4555 == 14u)
            {
                uint _5136_dummy_parameter;
                uint _5142_dummy_parameter;
                _9997 = r_flow_tm1.Load(int3(clamp(int2(floor(_3649 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5136_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5142_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _9998;
                if (_4555 == 16u)
                {
                    uint _8270 = r_warped_flow_qdata_tm1.Load(int3(_3665, 0)).x & 2147483647u;
                    uint _8302 = uint(max((int((_8270 >> 16u) & 15u) - 6), 0));
                    _9998 = ((float2(float((1 - (2 * int((_8270 >> 15u) & 1u))) * int(((_8270 >> uint(7)) & 127u) << _8302)), float((1 - (2 * int((_8270 >> 14u) & 1u))) * int((_8270 & 127u) << _8302))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _9998 = _5332 * float2(cbFI_DisplaySize);
                }
                _9997 = _9998;
            }
            uint2 _5175 = uint2(clamp(round(_9997 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5177 = _5175.x;
            uint _5184 = _5175.y;
            _9999 = float4(float(_5177 & 255u), float((_5177 >> 8u) | ((_5184 & 15u) << 4u)), float(_5184 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10000;
            if (_4555 == 17u)
            {
                _10000 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3665, 0)).x != 0u), _4008, 0.0f, 1.0f);
            }
            else
            {
                _10000 = float4(_9965, 1.0f);
            }
            _9999 = _10000;
        }
        rw_output[_3299] = _9999.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5228 = ((uint(_3299.y) * uint(cbFI_DisplaySize.x)) + uint(_3299.x)) * 6u;
            uint _8348 = spvPackHalf2x16(clamp(_6036.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5228 * 4 + 0, (((_8348 & 32767u) >> 4u) | ((((_8348 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6036.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8383 = spvPackHalf2x16(clamp(_6044.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5228 + 1u) * 4 + 0, (((_8383 & 32767u) >> 4u) | ((((_8383 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6044.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8418 = spvPackHalf2x16(clamp(_6052.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5228 + 2u) * 4 + 0, (((_8418 & 32767u) >> 4u) | ((((_8418 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6052.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8453 = spvPackHalf2x16(clamp(_6060.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5228 + 3u) * 4 + 0, (((_8453 & 32767u) >> 4u) | ((((_8453 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6060.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8480 = r_current_interpolation_source.Load(int3(_3299, 0));
            uint _8494 = spvPackHalf2x16(clamp(_8480.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5228 + 4u) * 4 + 0, (((_8494 & 32767u) >> 4u) | ((((_8494 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8480.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10032;
            if (_9878 || (_4555 != 0u))
            {
                _10032 = 4294967295u;
            }
            else
            {
                uint _8529 = spvPackHalf2x16(clamp(_9999.xy, 0.0f.xx, 65000.0f.xx));
                _10032 = (((_8529 & 32767u) >> 4u) | ((((_8529 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9999.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5228 + 5u) * 4 + 0, _10032);
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
