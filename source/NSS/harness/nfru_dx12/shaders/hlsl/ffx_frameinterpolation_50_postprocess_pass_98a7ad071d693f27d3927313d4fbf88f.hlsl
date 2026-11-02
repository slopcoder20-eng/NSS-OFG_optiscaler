static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3025[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3329 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3329.x >= cbFI_DisplaySize.x, _3329.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3329] = float4(r_present_backbuffer.Load(int3(_3329, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3329] = float4(r_current_interpolation_source.Load(int3(_3329, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3688 = (float2(_3329) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3699 = int2(floor(_3688 * float2(cbFI_MvDepthLaneSize)));
        int2 _3704 = int2(floor(_3688 * float2(cbFI_FlowLaneSize)));
        float4 _5386 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3688 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5392 = r_warped_filled_flow_tm1.Load(int3(_3704, 0)).xy;
        float2 _5398 = r_warped_filled_motion_tp1.Load(int3(_3699, 0)).xy;
        bool _5420 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8756;
        if (_5420)
        {
            float _5433 = ((2.0f * _3688.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8756 = float2(atan(_5433) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3688.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5433 * _5433))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8756 = _3688;
        }
        bool _3725 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8777;
        bool _8798;
        int2 _8809;
        float3 _9700;
        if (_3725)
        {
            float _8758;
            float _8760;
            _8760 = 2.0f;
            _8758 = -1.0f;
            uint _3393[9];
            float _10153;
            float _10156;
            for (int _8757 = 0; _8757 < 9; _8760 = _10156, _8758 = _10153, _8757++)
            {
                _3393[_8757] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3699 + int2((_8757 % 3) - 1, (_8757 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3393[_8757] != 0u)
                {
                    float _10148;
                    if (_3393[_8757] == 0u)
                    {
                        _10148 = -1.0f;
                    }
                    else
                    {
                        _10148 = float((_3393[_8757] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10156 = min(_8760, _10148);
                    _10153 = max(_8758, _10148);
                }
                else
                {
                    _10156 = _8760;
                    _10153 = _8758;
                }
            }
            float _3771 = float(_8758 >= 0.0f);
            float3 _8571 = 0.0f.xxx;
            _8571.y = _3771;
            float2 _8778;
            bool _8799;
            int2 _8810;
            float3 _9701;
            if ((_8758 - _8760) > 0.0199999995529651641845703125f)
            {
                float _8766;
                int2 _8767;
                float2 _8768;
                int2 _8770;
                float2 _8776;
                _8776 = _5398;
                _8770 = _3699;
                _8768 = _5398;
                _8767 = _3699;
                _8766 = -1.0f;
                float _10161;
                int2 _10165;
                float2 _10176;
                int2 _10187;
                float2 _10220;
                float _10268;
                int _8765 = 0;
                float _10129 = 1000000000.0f;
                for (; _8765 < 9; _10129 = _10268, _8776 = _10220, _8770 = _10187, _8768 = _10176, _8767 = _10165, _8766 = _10161, _8765++)
                {
                    if (_3393[_8765] == 0u)
                    {
                        _10268 = _10129;
                        _10220 = _8776;
                        _10187 = _8770;
                        _10176 = _8768;
                        _10165 = _8767;
                        _10161 = _8766;
                        continue;
                    }
                    int2 _3806 = clamp(_3699 + int2((_8765 % 3) - 1, (_8765 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5508 = _3393[_8765] & 2147483647u;
                    uint _5540 = uint(max((int((_5508 >> 16u) & 15u) - 6), 0));
                    float2 _3812 = (float2(float((1 - (2 * int((_5508 >> 15u) & 1u))) * int(((_5508 >> uint(7)) & 127u) << _5540)), float((1 - (2 * int((_5508 >> 14u) & 1u))) * int((_5508 & 127u) << _5540))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10115;
                    if (_3393[_8765] == 0u)
                    {
                        _10115 = -1.0f;
                    }
                    else
                    {
                        _10115 = float((_3393[_8765] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3817 = _10115 - 0.100000001490116119384765625f;
                    float2 _10116;
                    if (_5420)
                    {
                        float2 _5617 = clamp((((_8756 + (_3812 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5620 = tan(_5617.x);
                        _10116 = (float2(_5620 / cbFI_DeviceToViewDepth.z, (tan(_5617.y) * sqrt(1.0f + (_5620 * _5620))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10116 = _8756 + (_3812 * cbFI_Timestep);
                    }
                    float _3824 = cbFI_Timestep - 1.0f;
                    float2 _10117;
                    if (_5420)
                    {
                        float2 _5688 = clamp((((_8756 + (_3812 * _3824)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5691 = tan(_5688.x);
                        _10117 = (float2(_5691 / cbFI_DeviceToViewDepth.z, (tan(_5688.y) * sqrt(1.0f + (_5691 * _5691))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10117 = _8756 + (_3812 * _3824);
                    }
                    bool _5724 = all(bool2(_10116.x > 0.0f.xx.x, _10116.y > 0.0f.xx.y));
                    bool _5730;
                    if (_5724)
                    {
                        _5730 = all(bool2(_10116.x < 1.0f.xx.x, _10116.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5730 = _5724;
                    }
                    float _10120;
                    if (_5730)
                    {
                        uint _5737_dummy_parameter;
                        _10120 = max((_3817 - (log(((r_depth_tm1.Load(int3(int2(floor(_10116 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5737_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10120 = 0.0f;
                    }
                    bool _5767 = all(bool2(_10117.x > 0.0f.xx.x, _10117.y > 0.0f.xx.y));
                    bool _5773;
                    if (_5767)
                    {
                        _5773 = all(bool2(_10117.x < 1.0f.xx.x, _10117.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5773 = _5767;
                    }
                    float _10121;
                    if (_5773)
                    {
                        uint _5780_dummy_parameter;
                        _10121 = _10120 + max((_3817 - (log(((r_depth_tp1.Load(int3(int2(floor(_10117 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5780_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10121 = _10120;
                    }
                    float _10162;
                    int2 _10166;
                    float2 _10177;
                    int2 _10188;
                    float2 _10221;
                    float _10269;
                    if (_10121 == 0.0f)
                    {
                        bool _3859 = _3817 > _8766;
                        bool2 _10277 = _3859.xx;
                        _10269 = _10129;
                        _10221 = float2(_10277.x ? _3812.x : _8776.x, _10277.y ? _3812.y : _8776.y);
                        _10188 = int2(_10277.x ? _3806.x : _8770.x, _10277.y ? _3806.y : _8770.y);
                        _10177 = _8768;
                        _10166 = _8767;
                        _10162 = _3859 ? _3817 : _8766;
                    }
                    else
                    {
                        bool _3868 = _10121 < _10129;
                        bool2 _10273 = _3868.xx;
                        _10269 = _3868 ? _10121 : _10129;
                        _10221 = _8776;
                        _10188 = _8770;
                        _10177 = float2(_10273.x ? _3812.x : _8768.x, _10273.y ? _3812.y : _8768.y);
                        _10166 = int2(_10273.x ? _3806.x : _8767.x, _10273.y ? _3806.y : _8767.y);
                        _10162 = _8766;
                    }
                    _10268 = _10269;
                    _10220 = _10221;
                    _10187 = _10188;
                    _10176 = _10177;
                    _10165 = _10166;
                    _10161 = _10162;
                }
                bool _3880 = _8766 < 0.0f;
                bool2 _10283 = _3880.xx;
                int2 _10286 = int2(_10283.x ? _8767.x : _8770.x, _10283.y ? _8767.y : _8770.y);
                _9701 = float3(1.0f, _3771, float(any(bool2(_10286.x != _3699.x, _10286.y != _3699.y))));
                _8810 = _10286;
                _8799 = _3880 ? false : true;
                _8778 = float2(_10283.x ? _8768.x : _8776.x, _10283.y ? _8768.y : _8776.y);
            }
            else
            {
                _9701 = _8571;
                _8810 = _3699;
                _8799 = false;
                _8778 = _5398;
            }
            _9700 = _9701;
            _8809 = _8810;
            _8798 = _8799;
            _8777 = _8778;
        }
        else
        {
            _9700 = 0.0f.xxx;
            _8809 = _3699;
            _8798 = false;
            _8777 = _5398;
        }
        float2 _8779;
        if (_5420)
        {
            float2 _5845 = clamp((((_8756 + (_8777 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5848 = tan(_5845.x);
            _8779 = (float2(_5848 / cbFI_DeviceToViewDepth.z, (tan(_5845.y) * sqrt(1.0f + (_5848 * _5848))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8779 = _8756 + (_8777 * cbFI_Timestep);
        }
        float _3903 = cbFI_Timestep - 1.0f;
        float2 _8781;
        if (_5420)
        {
            float2 _5916 = clamp((((_8756 + (_8777 * _3903)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5919 = tan(_5916.x);
            _8781 = (float2(_5919 / cbFI_DeviceToViewDepth.z, (tan(_5916.y) * sqrt(1.0f + (_5919 * _5919))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8781 = _8756 + (_8777 * _3903);
        }
        float _3908 = -cbFI_Timestep;
        float2 _8782;
        if (_5420)
        {
            float2 _5987 = clamp((((_8756 + (_5392 * _3908)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5990 = tan(_5987.x);
            _8782 = (float2(_5990 / cbFI_DeviceToViewDepth.z, (tan(_5987.y) * sqrt(1.0f + (_5990 * _5990))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8782 = _8756 + (_5392 * _3908);
        }
        float _3913 = 1.0f - cbFI_Timestep;
        float2 _8783;
        if (_5420)
        {
            float2 _6058 = clamp((((_8756 + (_5392 * _3913)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6061 = tan(_6058.x);
            _8783 = (float2(_6061 / cbFI_DeviceToViewDepth.z, (tan(_6058.y) * sqrt(1.0f + (_6061 * _6061))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8783 = _8756 + (_5392 * _3913);
        }
        float4 _6096 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8779, 0.0f);
        float3 _6097 = _6096.xyz;
        float4 _6104 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8781, 0.0f);
        float3 _6105 = _6104.xyz;
        float4 _6112 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8782, 0.0f);
        float3 _6113 = _6112.xyz;
        float4 _6120 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8783, 0.0f);
        float3 _6121 = _6120.xyz;
        float4 _6135 = exp(_5386 - max(max(max(_5386.x, _5386.y), _5386.z), _5386.w).xxxx);
        float4 _6142 = _6135 / (dot(_6135, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3932 = _3725 && (!_8798);
        bool _3941;
        if (_3932)
        {
            _3941 = (_6142.z + _6142.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3941 = _3932;
        }
        bool _3952;
        if (_3941)
        {
            _3952 = length((_8782 - _8779) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3952 = _3941;
        }
        bool _8822;
        if (_3952)
        {
            uint4 _6161 = r_warped_motion_qdata_tp1.Load(int3(_8809, 0));
            uint _6162 = _6161.x;
            bool _8825;
            if (_6162 != 0u)
            {
                float _8811;
                if (_6162 == 0u)
                {
                    _8811 = -1.0f;
                }
                else
                {
                    _8811 = float((_6162 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3962 = _8811 - 0.12000000476837158203125f;
                bool _6181 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                bool _6187;
                if (_6181)
                {
                    _6187 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                }
                else
                {
                    _6187 = _6181;
                }
                bool _3972;
                if (_6187)
                {
                    uint _6194_dummy_parameter;
                    _3972 = (log(((r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6194_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3962;
                }
                else
                {
                    _3972 = _6187;
                }
                bool _3986;
                if (!_3972)
                {
                    bool _6224 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                    bool _6230;
                    if (_6224)
                    {
                        _6230 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6230 = _6224;
                    }
                    bool _3984;
                    if (_6230)
                    {
                        uint _6237_dummy_parameter;
                        _3984 = (log(((r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6237_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3962;
                    }
                    else
                    {
                        _3984 = _6230;
                    }
                    _3986 = _3984;
                }
                else
                {
                    _3986 = _3972;
                }
                _8825 = _3986;
            }
            else
            {
                _8825 = false;
            }
            _8822 = _8825;
        }
        else
        {
            _8822 = false;
        }
        bool _3991 = _8798 || _8822;
        bool _3996;
        if (_3991)
        {
            bool _6267 = all(bool2(_8779.x > 0.0f.xx.x, _8779.y > 0.0f.xx.y));
            bool _6273;
            if (_6267)
            {
                _6273 = all(bool2(_8779.x < 1.0f.xx.x, _8779.y < 1.0f.xx.y));
            }
            else
            {
                _6273 = _6267;
            }
            _3996 = _6273;
        }
        else
        {
            _3996 = _3991;
        }
        bool _4001;
        if (_3996)
        {
            bool _6278 = all(bool2(_8781.x > 0.0f.xx.x, _8781.y > 0.0f.xx.y));
            bool _6284;
            if (_6278)
            {
                _6284 = all(bool2(_8781.x < 1.0f.xx.x, _8781.y < 1.0f.xx.y));
            }
            else
            {
                _6284 = _6278;
            }
            _4001 = _6284;
        }
        else
        {
            _4001 = _3996;
        }
        float4 _8916;
        if (_4001)
        {
            float _4004 = _6142.x;
            float _4006 = _6142.y;
            float _4007 = _4004 + _4006;
            float _4012 = _6142.z + _6142.w;
            float _8840;
            if (_4007 > 0.001000000047497451305389404296875f)
            {
                _8840 = _4004 / _4007;
            }
            else
            {
                _8840 = _3913;
            }
            _8916 = float4(_4004 + (_4012 * _8840), _4006 + (_4012 * (1.0f - _8840)), 0.0f, 0.0f);
        }
        else
        {
            _8916 = _6142;
        }
        bool _6312 = (cbFI_pad0 & 1024u) != 0u;
        bool _6288 = !_6312;
        bool _6289 = !_6288;
        bool _6306;
        if (_6289)
        {
            _6306 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8809.y * cbFI_MvDepthLaneSize.x) + _8809.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6306 = _6288;
        }
        bool _6338;
        if (_6289)
        {
            _6338 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3704.y * cbFI_FlowLaneSize.x) + _3704.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6338 = _6288;
        }
        float _4047 = float(_6338);
        bool _8928;
        float4 _8958;
        float3 _9560;
        if (_6312)
        {
            bool _4057;
            if (_6306)
            {
                _4057 = all(bool2(_8779.x > 0.0f.xx.x, _8779.y > 0.0f.xx.y));
            }
            else
            {
                _4057 = _6306;
            }
            bool _4063;
            if (_4057)
            {
                _4063 = all(bool2(_8779.x < 1.0f.xx.x, _8779.y < 1.0f.xx.y));
            }
            else
            {
                _4063 = _4057;
            }
            bool _4070;
            if (_6306)
            {
                _4070 = all(bool2(_8781.x > 0.0f.xx.x, _8781.y > 0.0f.xx.y));
            }
            else
            {
                _4070 = _6306;
            }
            bool _4076;
            if (_4070)
            {
                _4076 = all(bool2(_8781.x < 1.0f.xx.x, _8781.y < 1.0f.xx.y));
            }
            else
            {
                _4076 = _4070;
            }
            bool _4083;
            if (_6338)
            {
                _4083 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
            }
            else
            {
                _4083 = _6338;
            }
            bool _4089;
            if (_4083)
            {
                _4089 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
            }
            else
            {
                _4089 = _4083;
            }
            bool _4096;
            if (_6338)
            {
                _4096 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
            }
            else
            {
                _4096 = _6338;
            }
            bool _4102;
            if (_4096)
            {
                _4102 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
            }
            else
            {
                _4102 = _4096;
            }
            bool _4104 = !_6306;
            if (_4104)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6380;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6380);
                }
            }
            bool _4109 = !_6338;
            if (_4109)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6390;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6390);
                }
            }
            if (_6306 && _4109)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6400;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6400);
                }
            }
            if (_4104 && _6338)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6410;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6410);
                }
            }
            float _4128 = float(_4063);
            float _4130 = float(_4076);
            bool _4133 = _4089 && _4102;
            float _8874;
            if (_4133)
            {
                _8874 = 1.0f;
            }
            else
            {
                _8874 = (_4089 || _4102) ? 0.5f : 0.0f;
            }
            bool _8879;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4063)) && (!_4076))
            {
                bool _4163;
                if (_4133)
                {
                    float _8877;
                    do
                    {
                        bool _6494 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                        bool _6500;
                        if (_6494)
                        {
                            _6500 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6500 = _6494;
                        }
                        bool _6431 = !_6500;
                        bool _6438;
                        if (!_6431)
                        {
                            bool _6505 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                            bool _6511;
                            if (_6505)
                            {
                                _6511 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6511 = _6505;
                            }
                            _6438 = !_6511;
                        }
                        else
                        {
                            _6438 = _6431;
                        }
                        if (_6438)
                        {
                            _8877 = 0.0f;
                            break;
                        }
                        uint _6518_dummy_parameter;
                        uint _6534_dummy_parameter;
                        float4 _6459 = mul(float4((float2(_8782.x, 1.0f - _8782.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6518_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6461 = _6459.w;
                        if (abs(_6461) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8877 = 0.0f;
                            break;
                        }
                        float _6472 = abs(cbFI_DeviceToViewDepth.y / ((_6459.z / _6461) - cbFI_DeviceToViewDepth.x));
                        float _6475 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6534_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8877 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6472 - _6475) / max(max(_6472, _6475), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4163 = _8877 >= 0.5f;
                }
                else
                {
                    _4163 = _4133;
                }
                bool _8880;
                if (_4163)
                {
                    uint _6584_dummy_parameter;
                    float2 _8878;
                    do
                    {
                        float _6610 = 1.0f - _8782.y;
                        float4 _6621 = mul(float4((float2(_8782.x, _6610) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6584_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6623 = _6621.w;
                        if (!(_6623 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8878 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6636 = ((_6621.xy / _6623.xx) + 1.0f.xx) * 0.5f;
                        _8878 = float2(_6636.x - _8782.x, _6610 - _6636.y);
                        break;
                    } while(false);
                    float2 _4177 = float2(cbFI_DisplaySize);
                    _8880 = length(((_8782 + _8878) - _8783) * _4177) <= ((0.100000001490116119384765625f * length(_8878 * _4177)) + 8.0f);
                }
                else
                {
                    _8880 = _4163;
                }
                _8879 = _8880;
            }
            else
            {
                _8879 = true;
            }
            bool _4191 = !_8879;
            bool _10287 = _4191 ? false : _4102;
            bool _10288 = _4191 ? false : _4089;
            bool _8929;
            float4 _8959;
            if (!(((_4063 && _4076) && _10288) && _10287))
            {
                float4 _4213 = _8916 * float4(_4128, _4130, float(_10288), float(_10287));
                float _4215 = dot(_4213, 1.0f.xxxx);
                bool _4218 = !(_4215 > 0.0f);
                float4 _8960;
                if (!_4218)
                {
                    _8960 = _4213 / _4215.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6658;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6658);
                    }
                    _8960 = 0.0f.xxxx;
                }
                _8959 = _8960;
                _8929 = _4218;
            }
            else
            {
                _8959 = _8916;
                _8929 = false;
            }
            _9560 = float3(_4128, _4130, _8874);
            _8958 = _8959;
            _8928 = _8929;
        }
        else
        {
            _9560 = float3(float(_6306), _4047, 0.0f);
            _8958 = _8916;
            _8928 = false;
        }
        float4 _9430;
        bool _9450;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8928))
        {
            bool _4241 = _8958.x > 0.00999999977648258209228515625f;
            bool _4244 = _8958.y > 0.00999999977648258209228515625f;
            bool _4253 = (_8958.z + _8958.w) > 0.0199999995529651641845703125f;
            bool _4259;
            if (_4253)
            {
                bool _6664 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                bool _6670;
                if (_6664)
                {
                    _6670 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                }
                else
                {
                    _6670 = _6664;
                }
                _4259 = _6670;
            }
            else
            {
                _4259 = _4253;
            }
            bool _4264;
            if (_4259)
            {
                bool _6675 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                bool _6681;
                if (_6675)
                {
                    _6681 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                }
                else
                {
                    _6681 = _6675;
                }
                _4264 = _6681;
            }
            else
            {
                _4264 = _4259;
            }
            bool _4271;
            if (_4264)
            {
                float _8962;
                do
                {
                    bool _6764 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                    bool _6770;
                    if (_6764)
                    {
                        _6770 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6770 = _6764;
                    }
                    bool _6701 = !_6770;
                    bool _6708;
                    if (!_6701)
                    {
                        bool _6775 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                        bool _6781;
                        if (_6775)
                        {
                            _6781 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6781 = _6775;
                        }
                        _6708 = !_6781;
                    }
                    else
                    {
                        _6708 = _6701;
                    }
                    if (_6708)
                    {
                        _8962 = 0.0f;
                        break;
                    }
                    uint _6788_dummy_parameter;
                    uint _6804_dummy_parameter;
                    float4 _6729 = mul(float4((float2(_8782.x, 1.0f - _8782.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6788_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6731 = _6729.w;
                    if (abs(_6731) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8962 = 0.0f;
                        break;
                    }
                    float _6742 = abs(cbFI_DeviceToViewDepth.y / ((_6729.z / _6731) - cbFI_DeviceToViewDepth.x));
                    float _6745 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6804_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8962 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6742 - _6745) / max(max(_6742, _6745), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4271 = _8962 < 0.5f;
            }
            else
            {
                _4271 = _4264;
            }
            float4 _8977;
            if (_4271)
            {
                uint _6854_dummy_parameter;
                uint _6885_dummy_parameter;
                float4 _8978;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6854_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6885_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _8978 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _8978 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _8977 = _8978;
            }
            else
            {
                _8977 = 1.0f.xxxx;
            }
            bool _4295;
            if (_6306)
            {
                bool _6914 = all(bool2(_8779.x > 0.0f.xx.x, _8779.y > 0.0f.xx.y));
                bool _6920;
                if (_6914)
                {
                    _6920 = all(bool2(_8779.x < 1.0f.xx.x, _8779.y < 1.0f.xx.y));
                }
                else
                {
                    _6920 = _6914;
                }
                _4295 = _6920;
            }
            else
            {
                _4295 = _6306;
            }
            bool _4301;
            if (_6306)
            {
                bool _6925 = all(bool2(_8781.x > 0.0f.xx.x, _8781.y > 0.0f.xx.y));
                bool _6931;
                if (_6925)
                {
                    _6931 = all(bool2(_8781.x < 1.0f.xx.x, _8781.y < 1.0f.xx.y));
                }
                else
                {
                    _6931 = _6925;
                }
                _4301 = _6931;
            }
            else
            {
                _4301 = _6306;
            }
            bool _4307;
            if (_6338)
            {
                bool _6936 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                bool _6942;
                if (_6936)
                {
                    _6942 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                }
                else
                {
                    _6942 = _6936;
                }
                _4307 = _6942;
            }
            else
            {
                _4307 = _6338;
            }
            bool _4313;
            if (_6338)
            {
                bool _6947 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                bool _6953;
                if (_6947)
                {
                    _6953 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                }
                else
                {
                    _6953 = _6947;
                }
                _4313 = _6953;
            }
            else
            {
                _4313 = _6338;
            }
            bool _4316 = _4307 != _4313;
            bool _4322;
            if (_4316)
            {
                _4322 = _4295 || _4301;
            }
            else
            {
                _4322 = _4316;
            }
            float4 _9080;
            if (_4322)
            {
                float4 _8656 = _8977;
                _8656.z = 0.0f;
                _8656.w = 0.0f;
                _9080 = _8656;
            }
            else
            {
                _9080 = _8977;
            }
            bool _4329 = _4295 && _4241;
            bool _4332 = _4301 && _4244;
            float4 _9155;
            if (_4329 || _4332)
            {
                float _9054;
                do
                {
                    uint4 _7092 = r_warped_motion_qdata_tp1.Load(int3(_8809, 0));
                    uint _7093 = _7092.x;
                    if (_7093 != 0u)
                    {
                        float _9053;
                        if (_7093 == 0u)
                        {
                            _9053 = -1.0f;
                        }
                        else
                        {
                            _9053 = float((_7093 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9054 = _9053;
                        break;
                    }
                    int _9036;
                    uint _9037;
                    _9037 = _7093;
                    _9036 = -1;
                    uint _9052;
                    for (; _9036 <= 1; _9037 = _9052, _9036++)
                    {
                        _9052 = _9037;
                        for (int _9050 = -1; _9050 <= 1; )
                        {
                            _9052 = max(_9052, r_warped_motion_qdata_tp1.Load(int3(clamp(_8809 + int2(_9050, _9036), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9050++;
                            continue;
                        }
                    }
                    if (_9037 != 0u)
                    {
                        float _9049;
                        if (_9037 == 0u)
                        {
                            _9049 = -1.0f;
                        }
                        else
                        {
                            _9049 = float((_9037 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9054 = _9049;
                        break;
                    }
                    uint _9039;
                    _9039 = 4294967295u;
                    uint _10257;
                    for (int _9038 = 0; _9038 < 8; _9039 = _10257, _9038++)
                    {
                        int _9042 = 0;
                        for (;;)
                        {
                            if (_9042 < 5)
                            {
                                int2 _7043 = _8809 + (_1093[_9038] * _1102[_9042].xx);
                                bool _7046 = any(bool2(_7043.x < int2(0, 0).x, _7043.y < int2(0, 0).y));
                                bool _7054;
                                if (!_7046)
                                {
                                    _7054 = any(bool2(_7043.x >= cbFI_MvDepthLaneSize.x, _7043.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7054 = _7046;
                                }
                                if (_7054)
                                {
                                    _10257 = _9039;
                                    break;
                                }
                                uint4 _7132 = r_warped_motion_qdata_tp1.Load(int3(_7043, 0));
                                uint _7133 = _7132.x;
                                if (_7133 != 0u)
                                {
                                    _10257 = min(_9039, _7133);
                                    break;
                                }
                                _9042++;
                                continue;
                            }
                            else
                            {
                                _10257 = _9039;
                                break;
                            }
                        }
                    }
                    float _9041;
                    if (_9039 == 4294967295u)
                    {
                        _9041 = -1.0f;
                    }
                    else
                    {
                        float _9040;
                        if (_9039 == 0u)
                        {
                            _9040 = -1.0f;
                        }
                        else
                        {
                            _9040 = float((_9039 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9041 = _9040;
                    }
                    _9054 = _9041;
                    break;
                } while(false);
                float _4343 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4345 = _9054 >= 0.0f;
                float _9061;
                if (_4345)
                {
                    _9061 = _9054 - _4343;
                }
                else
                {
                    float _9057;
                    if (_4329)
                    {
                        float _9056;
                        _9056 = 2.0f;
                        float _7204;
                        for (int _9055 = 0; _9055 < 24; _9056 = _7204, _9055++)
                        {
                            float _7168 = float(_9055 & 7) * 0.785398185253143310546875f;
                            int _7170 = _9055 >> 3;
                            int _9058;
                            if (_7170 == 0)
                            {
                                _9058 = 16;
                            }
                            else
                            {
                                _9058 = (_7170 == 1) ? 48 : 96;
                            }
                            uint _7220_dummy_parameter;
                            _7204 = min(_9056, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8779 + ((cbFI_MvDepthLaneSizeRcp * float(_9058)) * float2(cos(_7168), sin(_7168))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7220_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9057 = _9056;
                    }
                    else
                    {
                        _9057 = 0.0f;
                    }
                    _9061 = _9057;
                }
                float _9068;
                if (_4345)
                {
                    _9068 = _9054 - _4343;
                }
                else
                {
                    float _9064;
                    if (_4332)
                    {
                        float _9063;
                        _9063 = 2.0f;
                        float _7318;
                        for (int _9062 = 0; _9062 < 24; _9063 = _7318, _9062++)
                        {
                            float _7282 = float(_9062 & 7) * 0.785398185253143310546875f;
                            int _7284 = _9062 >> 3;
                            int _9065;
                            if (_7284 == 0)
                            {
                                _9065 = 16;
                            }
                            else
                            {
                                _9065 = (_7284 == 1) ? 48 : 96;
                            }
                            uint _7350_dummy_parameter;
                            _7318 = min(_9063, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8781 + ((cbFI_MvDepthLaneSizeRcp * float(_9065)) * float2(cos(_7282), sin(_7282))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7350_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9064 = _9063;
                    }
                    else
                    {
                        _9064 = 0.0f;
                    }
                    _9068 = _9064;
                }
                float _9069;
                if (_4329)
                {
                    uint _7382_dummy_parameter;
                    _9069 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8779 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7382_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9069 = 0.0f;
                }
                float _9070;
                if (_4332)
                {
                    uint _7402_dummy_parameter;
                    _9070 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8781 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7402_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9070 = 0.0f;
                }
                bool _4400;
                if (_4329)
                {
                    _4400 = _9069 > ((exp((_9061 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4400 = _4329;
                }
                float4 _9095;
                if (_4400)
                {
                    float4 _8660 = _9080;
                    _8660.x = 0.0f;
                    _9095 = _8660;
                }
                else
                {
                    _9095 = _9080;
                }
                bool _4412;
                if (_4332)
                {
                    _4412 = _9070 > ((exp((_9068 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4412 = _4332;
                }
                float4 _9097;
                if (_4412)
                {
                    float4 _8662 = _9095;
                    _8662.y = 0.0f;
                    _9097 = _8662;
                }
                else
                {
                    _9097 = _9095;
                }
                float4 _9156;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4345)
                {
                    bool _4432;
                    if (_4329)
                    {
                        _4432 = _9069 < ((exp((_9061 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4432 = _4329;
                    }
                    float4 _9099;
                    if (_4432)
                    {
                        float4 _8664 = _9097;
                        _8664.x = 0.0f;
                        _9099 = _8664;
                    }
                    else
                    {
                        _9099 = _9097;
                    }
                    bool _4444;
                    if (_4332)
                    {
                        _4444 = _9070 < ((exp((_9068 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4444 = _4332;
                    }
                    float4 _9157;
                    if (_4444)
                    {
                        float4 _8666 = _9099;
                        _8666.y = 0.0f;
                        _9157 = _8666;
                    }
                    else
                    {
                        _9157 = _9099;
                    }
                    _9156 = _9157;
                }
                else
                {
                    _9156 = _9097;
                }
                _9155 = _9156;
            }
            else
            {
                _9155 = _9080;
            }
            bool _4455 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4253;
            bool _4461;
            if (_4455)
            {
                _4461 = _4307 || _4313;
            }
            else
            {
                _4461 = _4455;
            }
            float4 _9177;
            if (_4461)
            {
                float _9150;
                do
                {
                    uint4 _7582 = r_warped_motion_qdata_tp1.Load(int3(_8809, 0));
                    uint _7583 = _7582.x;
                    if (_7583 != 0u)
                    {
                        float _9149;
                        if (_7583 == 0u)
                        {
                            _9149 = -1.0f;
                        }
                        else
                        {
                            _9149 = float((_7583 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9150 = _9149;
                        break;
                    }
                    int _9132;
                    uint _9133;
                    _9133 = _7583;
                    _9132 = -1;
                    uint _9148;
                    for (; _9132 <= 1; _9133 = _9148, _9132++)
                    {
                        _9148 = _9133;
                        for (int _9146 = -1; _9146 <= 1; )
                        {
                            _9148 = max(_9148, r_warped_motion_qdata_tp1.Load(int3(clamp(_8809 + int2(_9146, _9132), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9146++;
                            continue;
                        }
                    }
                    if (_9133 != 0u)
                    {
                        float _9145;
                        if (_9133 == 0u)
                        {
                            _9145 = -1.0f;
                        }
                        else
                        {
                            _9145 = float((_9133 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9150 = _9145;
                        break;
                    }
                    uint _9135;
                    _9135 = 4294967295u;
                    uint _10258;
                    for (int _9134 = 0; _9134 < 8; _9135 = _10258, _9134++)
                    {
                        int _9138 = 0;
                        for (;;)
                        {
                            if (_9138 < 5)
                            {
                                int2 _7533 = _8809 + (_1093[_9134] * _1102[_9138].xx);
                                bool _7536 = any(bool2(_7533.x < int2(0, 0).x, _7533.y < int2(0, 0).y));
                                bool _7544;
                                if (!_7536)
                                {
                                    _7544 = any(bool2(_7533.x >= cbFI_MvDepthLaneSize.x, _7533.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7544 = _7536;
                                }
                                if (_7544)
                                {
                                    _10258 = _9135;
                                    break;
                                }
                                uint4 _7622 = r_warped_motion_qdata_tp1.Load(int3(_7533, 0));
                                uint _7623 = _7622.x;
                                if (_7623 != 0u)
                                {
                                    _10258 = min(_9135, _7623);
                                    break;
                                }
                                _9138++;
                                continue;
                            }
                            else
                            {
                                _10258 = _9135;
                                break;
                            }
                        }
                    }
                    float _9137;
                    if (_9135 == 4294967295u)
                    {
                        _9137 = -1.0f;
                    }
                    else
                    {
                        float _9136;
                        if (_9135 == 0u)
                        {
                            _9136 = -1.0f;
                        }
                        else
                        {
                            _9136 = float((_9135 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9137 = _9136;
                    }
                    _9150 = _9137;
                    break;
                } while(false);
                float4 _9178;
                if (_9150 >= 0.0f)
                {
                    float _7644 = (exp((_9150 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4480;
                    if (_4307)
                    {
                        uint _7651_dummy_parameter;
                        _4480 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7651_dummy_parameter))))), 0)).x) > _7644;
                    }
                    else
                    {
                        _4480 = _4307;
                    }
                    float4 _9168;
                    if (_4480)
                    {
                        float4 _8668 = _9155;
                        _8668.z = 0.0f;
                        _9168 = _8668;
                    }
                    else
                    {
                        _9168 = _9155;
                    }
                    bool _4492;
                    if (_4313)
                    {
                        uint _7671_dummy_parameter;
                        _4492 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7671_dummy_parameter))))), 0)).x) > _7644;
                    }
                    else
                    {
                        _4492 = _4313;
                    }
                    float4 _9179;
                    if (_4492)
                    {
                        float4 _8670 = _9168;
                        _8670.w = 0.0f;
                        _9179 = _8670;
                    }
                    else
                    {
                        _9179 = _9168;
                    }
                    _9178 = _9179;
                }
                else
                {
                    _9178 = _9155;
                }
                _9177 = _9178;
            }
            else
            {
                _9177 = _9155;
            }
            bool _4500 = _4295 != _4301;
            bool _4507;
            if (_4500)
            {
                _4507 = _4295 ? _4241 : _4244;
            }
            else
            {
                _4507 = _4500;
            }
            float4 _9257;
            if (_4507)
            {
                bool2 _4512 = _4295.xx;
                float2 _4513 = float2(_4512.x ? _8779.x : _8781.x, _4512.y ? _8779.y : _8781.y);
                float _9170;
                if (_4295)
                {
                    uint _7691_dummy_parameter;
                    _9170 = r_depth_tm1.Load(int3(int2(floor(_4513 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7691_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7707_dummy_parameter;
                    _9170 = r_depth_tp1.Load(int3(int2(floor(_4513 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7707_dummy_parameter))))), 0)).x;
                }
                float4x4 _9171;
                if (_4295)
                {
                    _9171 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9171 = cbFI_MotionTP1ToTM1;
                }
                float2 _9172;
                do
                {
                    float _7734 = _4513.x;
                    float _7737 = 1.0f - _4513.y;
                    float4 _7748 = mul(float4((float2(_7734, _7737) * 2.0f) - 1.0f.xx, _9170, 1.0f), _9171);
                    float _7750 = _7748.w;
                    if (!(_7750 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9172 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7763 = ((_7748.xy / _7750.xx) + 1.0f.xx) * 0.5f;
                    _9172 = float2(_7763.x - _7734, _7737 - _7763.y);
                    break;
                } while(false);
                float2 _4543 = float2(cbFI_DisplaySize);
                float4 _9258;
                if (!(length(((_4513 + _9172) - float2(_4512.x ? _8781.x : _8779.x, _4512.y ? _8781.y : _8779.y)) * _4543) <= ((0.100000001490116119384765625f * length(_9172 * _4543)) + 8.0f)))
                {
                    float4 _9259;
                    if (_4295)
                    {
                        float4 _8680 = _9177;
                        _8680.x = 0.0f;
                        _9259 = _8680;
                    }
                    else
                    {
                        float4 _8682 = _9177;
                        _8682.y = 0.0f;
                        _9259 = _8682;
                    }
                    _9258 = _9259;
                }
                else
                {
                    _9258 = _9177;
                }
                _9257 = _9258;
            }
            else
            {
                _9257 = _9177;
            }
            float4 _4568 = _8958 * _9257;
            float _4570 = dot(_4568, 1.0f.xxxx);
            float4 _9431;
            bool _9451;
            if (_4570 > 0.0f)
            {
                _9451 = _8928;
                _9431 = _4568 / _4570.xxxx;
            }
            else
            {
                bool _4581 = any(bool4(_9257.x < 1.0f.xxxx.x, _9257.y < 1.0f.xxxx.y, _9257.z < 1.0f.xxxx.z, _9257.w < 1.0f.xxxx.w));
                if (_4581)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7785;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7785);
                    }
                }
                bool4 _10290 = _4581.xxxx;
                _9451 = _4581 ? true : _8928;
                _9431 = float4(_10290.x ? 0.0f.xxxx.x : _8958.x, _10290.y ? 0.0f.xxxx.y : _8958.y, _10290.z ? 0.0f.xxxx.z : _8958.z, _10290.w ? 0.0f.xxxx.w : _8958.w);
            }
            _9450 = _9451;
            _9430 = _9431;
        }
        else
        {
            _9450 = _8928;
            _9430 = _8958;
        }
        uint _4590 = (cbFI_pad0 >> 24u) & 31u;
        uint _4594 = (cbFI_pad0 >> 16u) & 255u;
        bool _4596 = _4590 != 0u;
        bool _4598 = _4594 == 12u;
        bool _4601 = _4594 == 13u;
        float4 _9447;
        float _9853;
        float _9880;
        float _9906;
        if ((_4596 || _4598) || _4601)
        {
            float _9260;
            do
            {
                bool _7869 = all(bool2(_8782.x > 0.0f.xx.x, _8782.y > 0.0f.xx.y));
                bool _7875;
                if (_7869)
                {
                    _7875 = all(bool2(_8782.x < 1.0f.xx.x, _8782.y < 1.0f.xx.y));
                }
                else
                {
                    _7875 = _7869;
                }
                bool _7806 = !_7875;
                bool _7813;
                if (!_7806)
                {
                    bool _7880 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
                    bool _7886;
                    if (_7880)
                    {
                        _7886 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7886 = _7880;
                    }
                    _7813 = !_7886;
                }
                else
                {
                    _7813 = _7806;
                }
                if (_7813)
                {
                    _9260 = 0.0f;
                    break;
                }
                uint _7893_dummy_parameter;
                uint _7909_dummy_parameter;
                float4 _7834 = mul(float4((float2(_8782.x, 1.0f - _8782.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8782 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7893_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7836 = _7834.w;
                if (abs(_7836) < 9.9999999747524270787835121154785e-07f)
                {
                    _9260 = 0.0f;
                    break;
                }
                float _7847 = abs(cbFI_DeviceToViewDepth.y / ((_7834.z / _7836) - cbFI_DeviceToViewDepth.x));
                float _7850 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7909_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9260 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7847 - _7850) / max(max(_7847, _7850), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7957 = all(bool2(_8783.x > 0.0f.xx.x, _8783.y > 0.0f.xx.y));
            bool _7963;
            if (_7957)
            {
                _7963 = all(bool2(_8783.x < 1.0f.xx.x, _8783.y < 1.0f.xx.y));
            }
            else
            {
                _7963 = _7957;
            }
            float _9261;
            if (_7963)
            {
                uint _7970_dummy_parameter;
                _9261 = length((_5392 + (r_motion_tp1.Load(int3(int2(floor(_8783 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7970_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9261 = 1000000.0f;
            }
            float _4621 = 1.0f - smoothstep(2.0f, 8.0f, _9261);
            float _9272;
            if ((_4590 & 1u) != 0u)
            {
                _9272 = _9260;
            }
            else
            {
                _9272 = 1.0f;
            }
            float _9273;
            if ((_4590 & 2u) != 0u)
            {
                _9273 = _9272 * _4621;
            }
            else
            {
                _9273 = _9272;
            }
            float _9274;
            if ((_4590 & 4u) != 0u)
            {
                _9274 = _9273 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6113 - _6121) - length(_6097 - _6105))));
            }
            else
            {
                _9274 = _9273;
            }
            float _9441;
            if ((_4590 & 8u) != 0u)
            {
                _9441 = lerp(1.0f, _9274, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6097 - _6105)));
            }
            else
            {
                _9441 = _9274;
            }
            bool _4676 = (_4590 & 16u) != 0u;
            bool _4685;
            if (_4676)
            {
                _4685 = length(_8777 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4685 = _4676;
            }
            float _10292 = _4685 ? 1.0f : _9441;
            bool _4691 = _4596 && _6306;
            bool _4696;
            if (_4691)
            {
                bool _7995 = all(bool2(_8779.x > 0.0f.xx.x, _8779.y > 0.0f.xx.y));
                bool _8001;
                if (_7995)
                {
                    _8001 = all(bool2(_8779.x < 1.0f.xx.x, _8779.y < 1.0f.xx.y));
                }
                else
                {
                    _8001 = _7995;
                }
                _4696 = _8001;
            }
            else
            {
                _4696 = _4691;
            }
            bool _4701;
            if (_4696)
            {
                bool _8006 = all(bool2(_8781.x > 0.0f.xx.x, _8781.y > 0.0f.xx.y));
                bool _8012;
                if (_8006)
                {
                    _8012 = all(bool2(_8781.x < 1.0f.xx.x, _8781.y < 1.0f.xx.y));
                }
                else
                {
                    _8012 = _8006;
                }
                _4701 = _8012;
            }
            else
            {
                _4701 = _4696;
            }
            float4 _9448;
            if (_4701)
            {
                float _4707 = _9430.x + _9430.y;
                float _4716 = (_9430.z + _9430.w) * (1.0f - _10292);
                float _9444;
                if (_4707 > 9.9999997473787516355514526367188e-06f)
                {
                    _9444 = _9430.x / _4707;
                }
                else
                {
                    _9444 = _3913;
                }
                _9448 = float4(_9430.x + (_4716 * _9444), _9430.y + (_4716 * (1.0f - _9444)), _9430.zw * _10292);
            }
            else
            {
                _9448 = _9430;
            }
            _9906 = _10292;
            _9880 = _4621;
            _9853 = _9260;
            _9447 = _9448;
        }
        else
        {
            _9906 = 1.0f;
            _9880 = 1.0f;
            _9853 = 1.0f;
            _9447 = _9430;
        }
        float3 _10062;
        if (_9450)
        {
            float3 _8018 = r_current_interpolation_source.Load(int3(_3329, 0)).xyz;
            float3 _10063;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6306)
            {
                uint _8025_dummy_parameter;
                float _9550;
                _9550 = r_depth_tm1.Load(int3(int2(floor(_8779 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8025_dummy_parameter))))), 0)).x;
                float _4828;
                for (int _9549 = 0; _9549 < 24; _9550 = _4828, _9549++)
                {
                    float _4800 = float(_9549 & 7) * 0.785398185253143310546875f;
                    int _4802 = _9549 >> 3;
                    int _10112;
                    if (_4802 == 0)
                    {
                        _10112 = 16;
                    }
                    else
                    {
                        _10112 = (_4802 == 1) ? 48 : 96;
                    }
                    uint _8045_dummy_parameter;
                    _4828 = max(_9550, r_depth_tm1.Load(int3(int2(floor(clamp(_8779 + ((cbFI_MvDepthLaneSizeRcp * float(_10112)) * float2(cos(_4800), sin(_4800))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8045_dummy_parameter))))), 0)).x);
                }
                float2 _9551;
                do
                {
                    float _8067 = 1.0f - _8779.y;
                    float4 _8078 = mul(float4((float2(_8779.x, _8067) * 2.0f) - 1.0f.xx, _9550, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8080 = _8078.w;
                    if (!(_8080 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9551 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8093 = ((_8078.xy / _8080.xx) + 1.0f.xx) * 0.5f;
                    _9551 = float2(_8093.x - _8779.x, _8067 - _8093.y);
                    break;
                } while(false);
                float2 _4839 = _8779 + _9551;
                bool _8111 = all(bool2(_4839.x > 0.0f.xx.x, _4839.y > 0.0f.xx.y));
                bool _8117;
                if (_8111)
                {
                    _8117 = all(bool2(_4839.x < 1.0f.xx.x, _4839.y < 1.0f.xx.y));
                }
                else
                {
                    _8117 = _8111;
                }
                float3 _10064;
                if (_8117)
                {
                    float _4845 = abs(cbFI_DeviceToViewDepth.y / (_9550 - cbFI_DeviceToViewDepth.x));
                    uint _8137_dummy_parameter;
                    int2 _8137 = int2(spvTextureSize(r_depth_m2, uint(0), _8137_dummy_parameter));
                    float _4849 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4839 * float2(_8137))), int2(0, 0), _8137 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10069;
                    if (abs(_4849 - _4845) <= (0.20000000298023223876953125f * max(_4849, _4845)))
                    {
                        uint _8171_dummy_parameter;
                        int2 _8171 = int2(spvTextureSize(r_colour_m2, uint(0), _8171_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8194;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8194);
                        }
                        _10069 = r_colour_m2.Load(int3(clamp(int2(floor(_4839 * float2(_8171))), int2(0, 0), _8171 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8204;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8204);
                        }
                        _10069 = _8018;
                    }
                    _10064 = _10069;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8214;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8214);
                    }
                    _10064 = _8018;
                }
                _10063 = _10064;
            }
            else
            {
                _10063 = _8018;
            }
            _10062 = _10063;
        }
        else
        {
            _10062 = (((_6097 * _9447.x) + (_6105 * _9447.y)) + (_6113 * _9447.z)) + (_6121 * _9447.w);
        }
        uint _4877 = cbFI_pad0 & 255u;
        bool _9957;
        float3 _10061;
        if (_4877 != 0u)
        {
            float3 _4882 = r_present_backbuffer.Load(int3(_3329, 0)).xyz;
            float3 _4886 = r_current_interpolation_source.Load(int3(_3329, 0)).xyz;
            float3 _4890 = abs(_4882 - _4886);
            float3 _9554;
            if (_4877 == 2u)
            {
                _9554 = (abs(_4886) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9554 = 0.000244140625f.xxx;
            }
            bool _4906 = any(bool3(_4890.x > _9554.x, _4890.y > _9554.y, _4890.z > _9554.z));
            bool3 _10293 = _4906.xxx;
            _10061 = float3(_10293.x ? _4882.x : _10062.x, _10293.y ? _4882.y : _10062.y, _10293.z ? _4882.z : _10062.z);
            _9957 = _4906;
        }
        else
        {
            _10061 = _10062;
            _9957 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8229;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8229);
        }
        float3 _10045;
        if (_4594 == 1u)
        {
            _10045 = lerp(_6097, _6105, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10046;
            if (_4594 == 2u)
            {
                _10046 = lerp(_6113, _6121, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10047;
                if (_4594 == 3u)
                {
                    _10047 = float(_9957).xxx;
                }
                else
                {
                    float3 _10048;
                    if (_4594 == 4u)
                    {
                        _10048 = float3(((_8777 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10049;
                        if (_4594 == 5u)
                        {
                            _10049 = float3(((_5392 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10050;
                            if (_4594 == 6u)
                            {
                                _10050 = float3(_9447.xy, _9447.z + _9447.w);
                            }
                            else
                            {
                                float3 _10051;
                                if (_4594 == 7u)
                                {
                                    _10051 = r_current_interpolation_source.Load(int3(_3329, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10052;
                                    if (_4594 == 8u)
                                    {
                                        _10052 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3688, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10053;
                                        if (_4598)
                                        {
                                            _10053 = float3(_9853, _9880, _9906);
                                        }
                                        else
                                        {
                                            float3 _10054;
                                            if (_4601)
                                            {
                                                _10054 = _6113;
                                            }
                                            else
                                            {
                                                float3 _10055;
                                                if (_4594 == 20u)
                                                {
                                                    _10055 = _6097;
                                                }
                                                else
                                                {
                                                    float3 _10056;
                                                    if (_4594 == 21u)
                                                    {
                                                        _10056 = _6105;
                                                    }
                                                    else
                                                    {
                                                        float3 _10057;
                                                        if (_4594 == 22u)
                                                        {
                                                            _10057 = _6121;
                                                        }
                                                        else
                                                        {
                                                            float3 _10058;
                                                            if (_4594 == 18u)
                                                            {
                                                                _10058 = _9700;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10295 = (_4594 == 19u).xxx;
                                                                _10058 = float3(_10295.x ? _9560.x : _10061.x, _10295.y ? _9560.y : _10061.y, _10295.z ? _9560.z : _10061.z);
                                                            }
                                                            _10057 = _10058;
                                                        }
                                                        _10056 = _10057;
                                                    }
                                                    _10055 = _10056;
                                                }
                                                _10054 = _10055;
                                            }
                                            _10053 = _10054;
                                        }
                                        _10052 = _10053;
                                    }
                                    _10051 = _10052;
                                }
                                _10050 = _10051;
                            }
                            _10049 = _10050;
                        }
                        _10048 = _10049;
                    }
                    _10047 = _10048;
                }
                _10046 = _10047;
            }
            _10045 = _10046;
        }
        float3 _10044;
        if ((_4594 >= 9u) && (_4594 <= 11u))
        {
            uint _5061 = 64u + uint((_8809.y * cbFI_MvDepthLaneSize.x) + _8809.x);
            uint _5065 = rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) & 15u;
            float3 _10074;
            if (_4594 == 10u)
            {
                float3 _10043;
                if ((rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) & 32u) != 0u)
                {
                    _10043 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10042;
                    if ((rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) & 16u) != 0u)
                    {
                        _10042 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5086 = ((rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) & 64u) != 0u).xxx;
                        _10042 = float3(_5086.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5086.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5086.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10043 = _10042;
                }
                _10074 = _10043;
            }
            else
            {
                float3 _10075;
                if (_4594 == 11u)
                {
                    uint _5099 = (rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) >> 8u) & 15u;
                    uint _5102 = (rw_nfru_diagnostics.Load<uint>(_5061 * 4 + 0) >> 12u) & 15u;
                    float3 _10035;
                    if ((_5065 == 2u) || (_5065 == 3u))
                    {
                        _10035 = _3025[_5065];
                    }
                    else
                    {
                        bool _5114 = _5099 == 3u;
                        bool _5116 = _5102 == 3u;
                        float3 _10036;
                        if (_5114 && _5116)
                        {
                            _10036 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10037;
                            if (_5114)
                            {
                                _10037 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10038;
                                if (_5116)
                                {
                                    _10038 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10039;
                                    if ((_5099 == 4u) || (_5102 == 4u))
                                    {
                                        _10039 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10040;
                                        if ((_5099 == 1u) || (_5102 == 1u))
                                        {
                                            _10040 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10297 = (_5065 == 1u).xxx;
                                            _10040 = float3(_10297.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10297.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10297.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10039 = _10040;
                                    }
                                    _10038 = _10039;
                                }
                                _10037 = _10038;
                            }
                            _10036 = _10037;
                        }
                        _10035 = _10036;
                    }
                    _10075 = _10035;
                }
                else
                {
                    _10075 = _3025[min(_5065, 7u)];
                }
                _10074 = _10075;
            }
            _10044 = _10074;
        }
        else
        {
            _10044 = _10045;
        }
        float4 _10078;
        if ((_4594 >= 14u) && (_4594 <= 16u))
        {
            float2 _10076;
            if (_4594 == 14u)
            {
                uint _5172_dummy_parameter;
                uint _5178_dummy_parameter;
                _10076 = r_flow_tm1.Load(int3(clamp(int2(floor(_3688 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5172_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5178_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10077;
                if (_4594 == 16u)
                {
                    uint _8270 = r_warped_flow_qdata_tm1.Load(int3(_3704, 0)).x & 2147483647u;
                    uint _8302 = uint(max((int((_8270 >> 16u) & 15u) - 6), 0));
                    _10077 = ((float2(float((1 - (2 * int((_8270 >> 15u) & 1u))) * int(((_8270 >> uint(7)) & 127u) << _8302)), float((1 - (2 * int((_8270 >> 14u) & 1u))) * int((_8270 & 127u) << _8302))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10077 = _5392 * float2(cbFI_DisplaySize);
                }
                _10076 = _10077;
            }
            uint2 _5211 = uint2(clamp(round(_10076 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5213 = _5211.x;
            uint _5220 = _5211.y;
            _10078 = float4(float(_5213 & 255u), float((_5213 >> 8u) | ((_5220 & 15u) << 4u)), float(_5220 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10079;
            if (_4594 == 17u)
            {
                _10079 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3704, 0)).x != 0u), _4047, 0.0f, 1.0f);
            }
            else
            {
                _10079 = float4(_10044, 1.0f);
            }
            _10078 = _10079;
        }
        rw_output[_3329] = _10078.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5264 = ((uint(_3329.y) * uint(cbFI_DisplaySize.x)) + uint(_3329.x)) * 6u;
            uint _8348 = spvPackHalf2x16(clamp(_6096.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5264 * 4 + 0, (((_8348 & 32767u) >> 4u) | ((((_8348 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6096.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8383 = spvPackHalf2x16(clamp(_6104.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5264 + 1u) * 4 + 0, (((_8383 & 32767u) >> 4u) | ((((_8383 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6104.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8418 = spvPackHalf2x16(clamp(_6112.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5264 + 2u) * 4 + 0, (((_8418 & 32767u) >> 4u) | ((((_8418 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6112.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8453 = spvPackHalf2x16(clamp(_6120.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5264 + 3u) * 4 + 0, (((_8453 & 32767u) >> 4u) | ((((_8453 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6120.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8480 = r_current_interpolation_source.Load(int3(_3329, 0));
            uint _8494 = spvPackHalf2x16(clamp(_8480.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5264 + 4u) * 4 + 0, (((_8494 & 32767u) >> 4u) | ((((_8494 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8480.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10111;
            if (_9957 || (_4594 != 0u))
            {
                _10111 = 4294967295u;
            }
            else
            {
                uint _8529 = spvPackHalf2x16(clamp(_10078.xy, 0.0f.xx, 65000.0f.xx));
                _10111 = (((_8529 & 32767u) >> 4u) | ((((_8529 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10078.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5264 + 5u) * 4 + 0, _10111);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3329] = float4(r_current_interpolation_source.Load(int3(_3329, 0)).xyz, 1.0f).xyz;
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
