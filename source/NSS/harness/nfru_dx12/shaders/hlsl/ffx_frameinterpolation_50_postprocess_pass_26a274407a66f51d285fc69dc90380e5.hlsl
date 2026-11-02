static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3005[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3292 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3292.x >= cbFI_DisplaySize.x, _3292.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3292] = float4(r_present_backbuffer.Load(int3(_3292, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3638 = (float2(_3292) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3649 = int2(floor(_3638 * float2(cbFI_MvDepthLaneSize)));
        int2 _3654 = int2(floor(_3638 * float2(cbFI_FlowLaneSize)));
        float4 _5312 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3638 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5318 = r_warped_filled_flow_tm1.Load(int3(_3654, 0)).xy;
        float2 _5324 = r_warped_filled_motion_tp1.Load(int3(_3649, 0)).xy;
        bool _5346 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8668;
        if (_5346)
        {
            float _5359 = ((2.0f * _3638.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8668 = float2(atan(_5359) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3638.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5359 * _5359))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8668 = _3638;
        }
        bool _3675 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8689;
        bool _8710;
        int2 _8721;
        float3 _9612;
        if (_3675)
        {
            float _8670;
            float _8672;
            _8672 = 2.0f;
            _8670 = -1.0f;
            uint _3354[9];
            float _10065;
            float _10068;
            for (int _8669 = 0; _8669 < 9; _8672 = _10068, _8670 = _10065, _8669++)
            {
                _3354[_8669] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3649 + int2((_8669 % 3) - 1, (_8669 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3354[_8669] != 0u)
                {
                    float _10060;
                    if (_3354[_8669] == 0u)
                    {
                        _10060 = -1.0f;
                    }
                    else
                    {
                        _10060 = float((_3354[_8669] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10068 = min(_8672, _10060);
                    _10065 = max(_8670, _10060);
                }
                else
                {
                    _10068 = _8672;
                    _10065 = _8670;
                }
            }
            float _3721 = float(_8670 >= 0.0f);
            float3 _8483 = 0.0f.xxx;
            _8483.y = _3721;
            float2 _8690;
            bool _8711;
            int2 _8722;
            float3 _9613;
            if ((_8670 - _8672) > 0.0199999995529651641845703125f)
            {
                float _8678;
                int2 _8679;
                float2 _8680;
                int2 _8682;
                float2 _8688;
                _8688 = _5324;
                _8682 = _3649;
                _8680 = _5324;
                _8679 = _3649;
                _8678 = -1.0f;
                float _10073;
                int2 _10077;
                float2 _10088;
                int2 _10099;
                float2 _10132;
                float _10180;
                int _8677 = 0;
                float _10041 = 1000000000.0f;
                for (; _8677 < 9; _10041 = _10180, _8688 = _10132, _8682 = _10099, _8680 = _10088, _8679 = _10077, _8678 = _10073, _8677++)
                {
                    if (_3354[_8677] == 0u)
                    {
                        _10180 = _10041;
                        _10132 = _8688;
                        _10099 = _8682;
                        _10088 = _8680;
                        _10077 = _8679;
                        _10073 = _8678;
                        continue;
                    }
                    int2 _3756 = clamp(_3649 + int2((_8677 % 3) - 1, (_8677 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5434 = _3354[_8677] & 2147483647u;
                    uint _5466 = uint(max((int((_5434 >> 16u) & 15u) - 6), 0));
                    float2 _3762 = (float2(float((1 - (2 * int((_5434 >> 15u) & 1u))) * int(((_5434 >> uint(7)) & 127u) << _5466)), float((1 - (2 * int((_5434 >> 14u) & 1u))) * int((_5434 & 127u) << _5466))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10027;
                    if (_3354[_8677] == 0u)
                    {
                        _10027 = -1.0f;
                    }
                    else
                    {
                        _10027 = float((_3354[_8677] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3767 = _10027 - 0.100000001490116119384765625f;
                    float2 _10028;
                    if (_5346)
                    {
                        float2 _5543 = clamp((((_8668 + (_3762 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5546 = tan(_5543.x);
                        _10028 = (float2(_5546 / cbFI_DeviceToViewDepth.z, (tan(_5543.y) * sqrt(1.0f + (_5546 * _5546))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10028 = _8668 + (_3762 * cbFI_Timestep);
                    }
                    float _3774 = cbFI_Timestep - 1.0f;
                    float2 _10029;
                    if (_5346)
                    {
                        float2 _5614 = clamp((((_8668 + (_3762 * _3774)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5617 = tan(_5614.x);
                        _10029 = (float2(_5617 / cbFI_DeviceToViewDepth.z, (tan(_5614.y) * sqrt(1.0f + (_5617 * _5617))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10029 = _8668 + (_3762 * _3774);
                    }
                    bool _5650 = all(bool2(_10028.x > 0.0f.xx.x, _10028.y > 0.0f.xx.y));
                    bool _5656;
                    if (_5650)
                    {
                        _5656 = all(bool2(_10028.x < 1.0f.xx.x, _10028.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5656 = _5650;
                    }
                    float _10032;
                    if (_5656)
                    {
                        uint _5663_dummy_parameter;
                        _10032 = max((_3767 - (log((r_depth_tm1.Load(int3(int2(floor(_10028 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5663_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10032 = 0.0f;
                    }
                    bool _5693 = all(bool2(_10029.x > 0.0f.xx.x, _10029.y > 0.0f.xx.y));
                    bool _5699;
                    if (_5693)
                    {
                        _5699 = all(bool2(_10029.x < 1.0f.xx.x, _10029.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5699 = _5693;
                    }
                    float _10033;
                    if (_5699)
                    {
                        uint _5706_dummy_parameter;
                        _10033 = _10032 + max((_3767 - (log((r_depth_tp1.Load(int3(int2(floor(_10029 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5706_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10033 = _10032;
                    }
                    float _10074;
                    int2 _10078;
                    float2 _10089;
                    int2 _10100;
                    float2 _10133;
                    float _10181;
                    if (_10033 == 0.0f)
                    {
                        bool _3809 = _3767 > _8678;
                        bool2 _10189 = _3809.xx;
                        _10181 = _10041;
                        _10133 = float2(_10189.x ? _3762.x : _8688.x, _10189.y ? _3762.y : _8688.y);
                        _10100 = int2(_10189.x ? _3756.x : _8682.x, _10189.y ? _3756.y : _8682.y);
                        _10089 = _8680;
                        _10078 = _8679;
                        _10074 = _3809 ? _3767 : _8678;
                    }
                    else
                    {
                        bool _3818 = _10033 < _10041;
                        bool2 _10185 = _3818.xx;
                        _10181 = _3818 ? _10033 : _10041;
                        _10133 = _8688;
                        _10100 = _8682;
                        _10089 = float2(_10185.x ? _3762.x : _8680.x, _10185.y ? _3762.y : _8680.y);
                        _10078 = int2(_10185.x ? _3756.x : _8679.x, _10185.y ? _3756.y : _8679.y);
                        _10074 = _8678;
                    }
                    _10180 = _10181;
                    _10132 = _10133;
                    _10099 = _10100;
                    _10088 = _10089;
                    _10077 = _10078;
                    _10073 = _10074;
                }
                bool _3830 = _8678 < 0.0f;
                bool2 _10195 = _3830.xx;
                int2 _10198 = int2(_10195.x ? _8679.x : _8682.x, _10195.y ? _8679.y : _8682.y);
                _9613 = float3(1.0f, _3721, float(any(bool2(_10198.x != _3649.x, _10198.y != _3649.y))));
                _8722 = _10198;
                _8711 = _3830 ? false : true;
                _8690 = float2(_10195.x ? _8680.x : _8688.x, _10195.y ? _8680.y : _8688.y);
            }
            else
            {
                _9613 = _8483;
                _8722 = _3649;
                _8711 = false;
                _8690 = _5324;
            }
            _9612 = _9613;
            _8721 = _8722;
            _8710 = _8711;
            _8689 = _8690;
        }
        else
        {
            _9612 = 0.0f.xxx;
            _8721 = _3649;
            _8710 = false;
            _8689 = _5324;
        }
        float2 _8691;
        if (_5346)
        {
            float2 _5771 = clamp((((_8668 + (_8689 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5774 = tan(_5771.x);
            _8691 = (float2(_5774 / cbFI_DeviceToViewDepth.z, (tan(_5771.y) * sqrt(1.0f + (_5774 * _5774))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8691 = _8668 + (_8689 * cbFI_Timestep);
        }
        float _3853 = cbFI_Timestep - 1.0f;
        float2 _8693;
        if (_5346)
        {
            float2 _5842 = clamp((((_8668 + (_8689 * _3853)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5845 = tan(_5842.x);
            _8693 = (float2(_5845 / cbFI_DeviceToViewDepth.z, (tan(_5842.y) * sqrt(1.0f + (_5845 * _5845))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8693 = _8668 + (_8689 * _3853);
        }
        float _3858 = -cbFI_Timestep;
        float2 _8694;
        if (_5346)
        {
            float2 _5913 = clamp((((_8668 + (_5318 * _3858)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5916 = tan(_5913.x);
            _8694 = (float2(_5916 / cbFI_DeviceToViewDepth.z, (tan(_5913.y) * sqrt(1.0f + (_5916 * _5916))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8694 = _8668 + (_5318 * _3858);
        }
        float _3863 = 1.0f - cbFI_Timestep;
        float2 _8695;
        if (_5346)
        {
            float2 _5984 = clamp((((_8668 + (_5318 * _3863)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5987 = tan(_5984.x);
            _8695 = (float2(_5987 / cbFI_DeviceToViewDepth.z, (tan(_5984.y) * sqrt(1.0f + (_5987 * _5987))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8695 = _8668 + (_5318 * _3863);
        }
        float4 _6022 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8691, 0.0f);
        float3 _6023 = _6022.xyz;
        float4 _6030 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8693, 0.0f);
        float3 _6031 = _6030.xyz;
        float4 _6038 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8694, 0.0f);
        float3 _6039 = _6038.xyz;
        float4 _6046 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8695, 0.0f);
        float3 _6047 = _6046.xyz;
        float4 _6061 = exp(_5312 - max(max(max(_5312.x, _5312.y), _5312.z), _5312.w).xxxx);
        float4 _6068 = _6061 / (dot(_6061, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3882 = _3675 && (!_8710);
        bool _3891;
        if (_3882)
        {
            _3891 = (_6068.z + _6068.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3891 = _3882;
        }
        bool _3902;
        if (_3891)
        {
            _3902 = length((_8694 - _8691) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3902 = _3891;
        }
        bool _8734;
        if (_3902)
        {
            uint4 _6087 = r_warped_motion_qdata_tp1.Load(int3(_8721, 0));
            uint _6088 = _6087.x;
            bool _8737;
            if (_6088 != 0u)
            {
                float _8723;
                if (_6088 == 0u)
                {
                    _8723 = -1.0f;
                }
                else
                {
                    _8723 = float((_6088 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3912 = _8723 - 0.12000000476837158203125f;
                bool _6107 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                bool _6113;
                if (_6107)
                {
                    _6113 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                }
                else
                {
                    _6113 = _6107;
                }
                bool _3922;
                if (_6113)
                {
                    uint _6120_dummy_parameter;
                    _3922 = (log((r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6120_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3912;
                }
                else
                {
                    _3922 = _6113;
                }
                bool _3936;
                if (!_3922)
                {
                    bool _6150 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                    bool _6156;
                    if (_6150)
                    {
                        _6156 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6156 = _6150;
                    }
                    bool _3934;
                    if (_6156)
                    {
                        uint _6163_dummy_parameter;
                        _3934 = (log((r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6163_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3912;
                    }
                    else
                    {
                        _3934 = _6156;
                    }
                    _3936 = _3934;
                }
                else
                {
                    _3936 = _3922;
                }
                _8737 = _3936;
            }
            else
            {
                _8737 = false;
            }
            _8734 = _8737;
        }
        else
        {
            _8734 = false;
        }
        bool _3941 = _8710 || _8734;
        bool _3946;
        if (_3941)
        {
            bool _6193 = all(bool2(_8691.x > 0.0f.xx.x, _8691.y > 0.0f.xx.y));
            bool _6199;
            if (_6193)
            {
                _6199 = all(bool2(_8691.x < 1.0f.xx.x, _8691.y < 1.0f.xx.y));
            }
            else
            {
                _6199 = _6193;
            }
            _3946 = _6199;
        }
        else
        {
            _3946 = _3941;
        }
        bool _3951;
        if (_3946)
        {
            bool _6204 = all(bool2(_8693.x > 0.0f.xx.x, _8693.y > 0.0f.xx.y));
            bool _6210;
            if (_6204)
            {
                _6210 = all(bool2(_8693.x < 1.0f.xx.x, _8693.y < 1.0f.xx.y));
            }
            else
            {
                _6210 = _6204;
            }
            _3951 = _6210;
        }
        else
        {
            _3951 = _3946;
        }
        float4 _8828;
        if (_3951)
        {
            float _3954 = _6068.x;
            float _3956 = _6068.y;
            float _3957 = _3954 + _3956;
            float _3962 = _6068.z + _6068.w;
            float _8752;
            if (_3957 > 0.001000000047497451305389404296875f)
            {
                _8752 = _3954 / _3957;
            }
            else
            {
                _8752 = _3863;
            }
            _8828 = float4(_3954 + (_3962 * _8752), _3956 + (_3962 * (1.0f - _8752)), 0.0f, 0.0f);
        }
        else
        {
            _8828 = _6068;
        }
        bool _6238 = (cbFI_pad0 & 1024u) != 0u;
        bool _6214 = !_6238;
        bool _6215 = !_6214;
        bool _6232;
        if (_6215)
        {
            _6232 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8721.y * cbFI_MvDepthLaneSize.x) + _8721.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6232 = _6214;
        }
        bool _6264;
        if (_6215)
        {
            _6264 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3654.y * cbFI_FlowLaneSize.x) + _3654.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6264 = _6214;
        }
        float _3997 = float(_6264);
        bool _8840;
        float4 _8870;
        float3 _9472;
        if (_6238)
        {
            bool _4007;
            if (_6232)
            {
                _4007 = all(bool2(_8691.x > 0.0f.xx.x, _8691.y > 0.0f.xx.y));
            }
            else
            {
                _4007 = _6232;
            }
            bool _4013;
            if (_4007)
            {
                _4013 = all(bool2(_8691.x < 1.0f.xx.x, _8691.y < 1.0f.xx.y));
            }
            else
            {
                _4013 = _4007;
            }
            bool _4020;
            if (_6232)
            {
                _4020 = all(bool2(_8693.x > 0.0f.xx.x, _8693.y > 0.0f.xx.y));
            }
            else
            {
                _4020 = _6232;
            }
            bool _4026;
            if (_4020)
            {
                _4026 = all(bool2(_8693.x < 1.0f.xx.x, _8693.y < 1.0f.xx.y));
            }
            else
            {
                _4026 = _4020;
            }
            bool _4033;
            if (_6264)
            {
                _4033 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
            }
            else
            {
                _4033 = _6264;
            }
            bool _4039;
            if (_4033)
            {
                _4039 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
            }
            else
            {
                _4039 = _4033;
            }
            bool _4046;
            if (_6264)
            {
                _4046 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
            }
            else
            {
                _4046 = _6264;
            }
            bool _4052;
            if (_4046)
            {
                _4052 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
            }
            else
            {
                _4052 = _4046;
            }
            bool _4054 = !_6232;
            if (_4054)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6306;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6306);
                }
            }
            bool _4059 = !_6264;
            if (_4059)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6316;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6316);
                }
            }
            if (_6232 && _4059)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6326;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6326);
                }
            }
            if (_4054 && _6264)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6336;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6336);
                }
            }
            float _4078 = float(_4013);
            float _4080 = float(_4026);
            bool _4083 = _4039 && _4052;
            float _8786;
            if (_4083)
            {
                _8786 = 1.0f;
            }
            else
            {
                _8786 = (_4039 || _4052) ? 0.5f : 0.0f;
            }
            bool _8791;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4013)) && (!_4026))
            {
                bool _4113;
                if (_4083)
                {
                    float _8789;
                    do
                    {
                        bool _6420 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                        bool _6426;
                        if (_6420)
                        {
                            _6426 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6426 = _6420;
                        }
                        bool _6357 = !_6426;
                        bool _6364;
                        if (!_6357)
                        {
                            bool _6431 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                            bool _6437;
                            if (_6431)
                            {
                                _6437 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6437 = _6431;
                            }
                            _6364 = !_6437;
                        }
                        else
                        {
                            _6364 = _6357;
                        }
                        if (_6364)
                        {
                            _8789 = 0.0f;
                            break;
                        }
                        uint _6444_dummy_parameter;
                        uint _6460_dummy_parameter;
                        float4 _6385 = mul(float4((float2(_8694.x, 1.0f - _8694.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6444_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6387 = _6385.w;
                        if (abs(_6387) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8789 = 0.0f;
                            break;
                        }
                        float _6398 = abs(cbFI_DeviceToViewDepth.y / ((_6385.z / _6387) - cbFI_DeviceToViewDepth.x));
                        float _6401 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6460_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8789 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6398 - _6401) / max(max(_6398, _6401), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4113 = _8789 >= 0.5f;
                }
                else
                {
                    _4113 = _4083;
                }
                bool _8792;
                if (_4113)
                {
                    uint _6510_dummy_parameter;
                    float2 _8790;
                    do
                    {
                        float _6536 = 1.0f - _8694.y;
                        float4 _6547 = mul(float4((float2(_8694.x, _6536) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6510_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6549 = _6547.w;
                        if (!(_6549 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8790 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6562 = ((_6547.xy / _6549.xx) + 1.0f.xx) * 0.5f;
                        _8790 = float2(_6562.x - _8694.x, _6536 - _6562.y);
                        break;
                    } while(false);
                    float2 _4127 = float2(cbFI_DisplaySize);
                    _8792 = length(((_8694 + _8790) - _8695) * _4127) <= ((0.100000001490116119384765625f * length(_8790 * _4127)) + 8.0f);
                }
                else
                {
                    _8792 = _4113;
                }
                _8791 = _8792;
            }
            else
            {
                _8791 = true;
            }
            bool _4141 = !_8791;
            bool _10199 = _4141 ? false : _4052;
            bool _10200 = _4141 ? false : _4039;
            bool _8841;
            float4 _8871;
            if (!(((_4013 && _4026) && _10200) && _10199))
            {
                float4 _4163 = _8828 * float4(_4078, _4080, float(_10200), float(_10199));
                float _4165 = dot(_4163, 1.0f.xxxx);
                bool _4168 = !(_4165 > 0.0f);
                float4 _8872;
                if (!_4168)
                {
                    _8872 = _4163 / _4165.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6584;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6584);
                    }
                    _8872 = 0.0f.xxxx;
                }
                _8871 = _8872;
                _8841 = _4168;
            }
            else
            {
                _8871 = _8828;
                _8841 = false;
            }
            _9472 = float3(_4078, _4080, _8786);
            _8870 = _8871;
            _8840 = _8841;
        }
        else
        {
            _9472 = float3(float(_6232), _3997, 0.0f);
            _8870 = _8828;
            _8840 = false;
        }
        float4 _9342;
        bool _9362;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8840))
        {
            bool _4191 = _8870.x > 0.00999999977648258209228515625f;
            bool _4194 = _8870.y > 0.00999999977648258209228515625f;
            bool _4203 = (_8870.z + _8870.w) > 0.0199999995529651641845703125f;
            bool _4209;
            if (_4203)
            {
                bool _6590 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                bool _6596;
                if (_6590)
                {
                    _6596 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                }
                else
                {
                    _6596 = _6590;
                }
                _4209 = _6596;
            }
            else
            {
                _4209 = _4203;
            }
            bool _4214;
            if (_4209)
            {
                bool _6601 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                bool _6607;
                if (_6601)
                {
                    _6607 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                }
                else
                {
                    _6607 = _6601;
                }
                _4214 = _6607;
            }
            else
            {
                _4214 = _4209;
            }
            bool _4221;
            if (_4214)
            {
                float _8874;
                do
                {
                    bool _6690 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                    bool _6696;
                    if (_6690)
                    {
                        _6696 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6696 = _6690;
                    }
                    bool _6627 = !_6696;
                    bool _6634;
                    if (!_6627)
                    {
                        bool _6701 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                        bool _6707;
                        if (_6701)
                        {
                            _6707 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6707 = _6701;
                        }
                        _6634 = !_6707;
                    }
                    else
                    {
                        _6634 = _6627;
                    }
                    if (_6634)
                    {
                        _8874 = 0.0f;
                        break;
                    }
                    uint _6714_dummy_parameter;
                    uint _6730_dummy_parameter;
                    float4 _6655 = mul(float4((float2(_8694.x, 1.0f - _8694.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6714_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6657 = _6655.w;
                    if (abs(_6657) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8874 = 0.0f;
                        break;
                    }
                    float _6668 = abs(cbFI_DeviceToViewDepth.y / ((_6655.z / _6657) - cbFI_DeviceToViewDepth.x));
                    float _6671 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6730_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8874 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6668 - _6671) / max(max(_6668, _6671), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4221 = _8874 < 0.5f;
            }
            else
            {
                _4221 = _4214;
            }
            float4 _8889;
            if (_4221)
            {
                uint _6780_dummy_parameter;
                uint _6811_dummy_parameter;
                float4 _8890;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6780_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6811_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _8890 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _8890 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _8889 = _8890;
            }
            else
            {
                _8889 = 1.0f.xxxx;
            }
            bool _4245;
            if (_6232)
            {
                bool _6840 = all(bool2(_8691.x > 0.0f.xx.x, _8691.y > 0.0f.xx.y));
                bool _6846;
                if (_6840)
                {
                    _6846 = all(bool2(_8691.x < 1.0f.xx.x, _8691.y < 1.0f.xx.y));
                }
                else
                {
                    _6846 = _6840;
                }
                _4245 = _6846;
            }
            else
            {
                _4245 = _6232;
            }
            bool _4251;
            if (_6232)
            {
                bool _6851 = all(bool2(_8693.x > 0.0f.xx.x, _8693.y > 0.0f.xx.y));
                bool _6857;
                if (_6851)
                {
                    _6857 = all(bool2(_8693.x < 1.0f.xx.x, _8693.y < 1.0f.xx.y));
                }
                else
                {
                    _6857 = _6851;
                }
                _4251 = _6857;
            }
            else
            {
                _4251 = _6232;
            }
            bool _4257;
            if (_6264)
            {
                bool _6862 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                bool _6868;
                if (_6862)
                {
                    _6868 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                }
                else
                {
                    _6868 = _6862;
                }
                _4257 = _6868;
            }
            else
            {
                _4257 = _6264;
            }
            bool _4263;
            if (_6264)
            {
                bool _6873 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                bool _6879;
                if (_6873)
                {
                    _6879 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                }
                else
                {
                    _6879 = _6873;
                }
                _4263 = _6879;
            }
            else
            {
                _4263 = _6264;
            }
            bool _4266 = _4257 != _4263;
            bool _4272;
            if (_4266)
            {
                _4272 = _4245 || _4251;
            }
            else
            {
                _4272 = _4266;
            }
            float4 _8992;
            if (_4272)
            {
                float4 _8568 = _8889;
                _8568.z = 0.0f;
                _8568.w = 0.0f;
                _8992 = _8568;
            }
            else
            {
                _8992 = _8889;
            }
            bool _4279 = _4245 && _4191;
            bool _4282 = _4251 && _4194;
            float4 _9067;
            if (_4279 || _4282)
            {
                float _8966;
                do
                {
                    uint4 _7018 = r_warped_motion_qdata_tp1.Load(int3(_8721, 0));
                    uint _7019 = _7018.x;
                    if (_7019 != 0u)
                    {
                        float _8965;
                        if (_7019 == 0u)
                        {
                            _8965 = -1.0f;
                        }
                        else
                        {
                            _8965 = float((_7019 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8966 = _8965;
                        break;
                    }
                    int _8948;
                    uint _8949;
                    _8949 = _7019;
                    _8948 = -1;
                    uint _8964;
                    for (; _8948 <= 1; _8949 = _8964, _8948++)
                    {
                        _8964 = _8949;
                        for (int _8962 = -1; _8962 <= 1; )
                        {
                            _8964 = max(_8964, r_warped_motion_qdata_tp1.Load(int3(clamp(_8721 + int2(_8962, _8948), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _8962++;
                            continue;
                        }
                    }
                    if (_8949 != 0u)
                    {
                        float _8961;
                        if (_8949 == 0u)
                        {
                            _8961 = -1.0f;
                        }
                        else
                        {
                            _8961 = float((_8949 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8966 = _8961;
                        break;
                    }
                    uint _8951;
                    _8951 = 4294967295u;
                    uint _10169;
                    for (int _8950 = 0; _8950 < 8; _8951 = _10169, _8950++)
                    {
                        int _8954 = 0;
                        for (;;)
                        {
                            if (_8954 < 5)
                            {
                                int2 _6969 = _8721 + (_1085[_8950] * _1094[_8954].xx);
                                bool _6972 = any(bool2(_6969.x < int2(0, 0).x, _6969.y < int2(0, 0).y));
                                bool _6980;
                                if (!_6972)
                                {
                                    _6980 = any(bool2(_6969.x >= cbFI_MvDepthLaneSize.x, _6969.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _6980 = _6972;
                                }
                                if (_6980)
                                {
                                    _10169 = _8951;
                                    break;
                                }
                                uint4 _7058 = r_warped_motion_qdata_tp1.Load(int3(_6969, 0));
                                uint _7059 = _7058.x;
                                if (_7059 != 0u)
                                {
                                    _10169 = min(_8951, _7059);
                                    break;
                                }
                                _8954++;
                                continue;
                            }
                            else
                            {
                                _10169 = _8951;
                                break;
                            }
                        }
                    }
                    float _8953;
                    if (_8951 == 4294967295u)
                    {
                        _8953 = -1.0f;
                    }
                    else
                    {
                        float _8952;
                        if (_8951 == 0u)
                        {
                            _8952 = -1.0f;
                        }
                        else
                        {
                            _8952 = float((_8951 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8953 = _8952;
                    }
                    _8966 = _8953;
                    break;
                } while(false);
                float _4293 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4295 = _8966 >= 0.0f;
                float _8973;
                if (_4295)
                {
                    _8973 = _8966 - _4293;
                }
                else
                {
                    float _8969;
                    if (_4279)
                    {
                        float _8968;
                        _8968 = 2.0f;
                        float _7130;
                        for (int _8967 = 0; _8967 < 24; _8968 = _7130, _8967++)
                        {
                            float _7094 = float(_8967 & 7) * 0.785398185253143310546875f;
                            int _7096 = _8967 >> 3;
                            int _8970;
                            if (_7096 == 0)
                            {
                                _8970 = 16;
                            }
                            else
                            {
                                _8970 = (_7096 == 1) ? 48 : 96;
                            }
                            uint _7146_dummy_parameter;
                            _7130 = min(_8968, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8691 + ((cbFI_MvDepthLaneSizeRcp * float(_8970)) * float2(cos(_7094), sin(_7094))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7146_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _8969 = _8968;
                    }
                    else
                    {
                        _8969 = 0.0f;
                    }
                    _8973 = _8969;
                }
                float _8980;
                if (_4295)
                {
                    _8980 = _8966 - _4293;
                }
                else
                {
                    float _8976;
                    if (_4282)
                    {
                        float _8975;
                        _8975 = 2.0f;
                        float _7244;
                        for (int _8974 = 0; _8974 < 24; _8975 = _7244, _8974++)
                        {
                            float _7208 = float(_8974 & 7) * 0.785398185253143310546875f;
                            int _7210 = _8974 >> 3;
                            int _8977;
                            if (_7210 == 0)
                            {
                                _8977 = 16;
                            }
                            else
                            {
                                _8977 = (_7210 == 1) ? 48 : 96;
                            }
                            uint _7276_dummy_parameter;
                            _7244 = min(_8975, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8693 + ((cbFI_MvDepthLaneSizeRcp * float(_8977)) * float2(cos(_7208), sin(_7208))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7276_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _8976 = _8975;
                    }
                    else
                    {
                        _8976 = 0.0f;
                    }
                    _8980 = _8976;
                }
                float _8981;
                if (_4279)
                {
                    uint _7308_dummy_parameter;
                    _8981 = r_depth_tm1.Load(int3(int2(floor(_8691 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7308_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _8981 = 0.0f;
                }
                float _8982;
                if (_4282)
                {
                    uint _7327_dummy_parameter;
                    _8982 = r_depth_tp1.Load(int3(int2(floor(_8693 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7327_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _8982 = 0.0f;
                }
                bool _4350;
                if (_4279)
                {
                    _4350 = _8981 > ((exp((_8973 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4350 = _4279;
                }
                float4 _9007;
                if (_4350)
                {
                    float4 _8572 = _8992;
                    _8572.x = 0.0f;
                    _9007 = _8572;
                }
                else
                {
                    _9007 = _8992;
                }
                bool _4362;
                if (_4282)
                {
                    _4362 = _8982 > ((exp((_8980 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4362 = _4282;
                }
                float4 _9009;
                if (_4362)
                {
                    float4 _8574 = _9007;
                    _8574.y = 0.0f;
                    _9009 = _8574;
                }
                else
                {
                    _9009 = _9007;
                }
                float4 _9068;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4295)
                {
                    bool _4382;
                    if (_4279)
                    {
                        _4382 = _8981 < ((exp((_8973 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4382 = _4279;
                    }
                    float4 _9011;
                    if (_4382)
                    {
                        float4 _8576 = _9009;
                        _8576.x = 0.0f;
                        _9011 = _8576;
                    }
                    else
                    {
                        _9011 = _9009;
                    }
                    bool _4394;
                    if (_4282)
                    {
                        _4394 = _8982 < ((exp((_8980 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4394 = _4282;
                    }
                    float4 _9069;
                    if (_4394)
                    {
                        float4 _8578 = _9011;
                        _8578.y = 0.0f;
                        _9069 = _8578;
                    }
                    else
                    {
                        _9069 = _9011;
                    }
                    _9068 = _9069;
                }
                else
                {
                    _9068 = _9009;
                }
                _9067 = _9068;
            }
            else
            {
                _9067 = _8992;
            }
            bool _4405 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4203;
            bool _4411;
            if (_4405)
            {
                _4411 = _4257 || _4263;
            }
            else
            {
                _4411 = _4405;
            }
            float4 _9089;
            if (_4411)
            {
                float _9062;
                do
                {
                    uint4 _7506 = r_warped_motion_qdata_tp1.Load(int3(_8721, 0));
                    uint _7507 = _7506.x;
                    if (_7507 != 0u)
                    {
                        float _9061;
                        if (_7507 == 0u)
                        {
                            _9061 = -1.0f;
                        }
                        else
                        {
                            _9061 = float((_7507 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9062 = _9061;
                        break;
                    }
                    int _9044;
                    uint _9045;
                    _9045 = _7507;
                    _9044 = -1;
                    uint _9060;
                    for (; _9044 <= 1; _9045 = _9060, _9044++)
                    {
                        _9060 = _9045;
                        for (int _9058 = -1; _9058 <= 1; )
                        {
                            _9060 = max(_9060, r_warped_motion_qdata_tp1.Load(int3(clamp(_8721 + int2(_9058, _9044), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9058++;
                            continue;
                        }
                    }
                    if (_9045 != 0u)
                    {
                        float _9057;
                        if (_9045 == 0u)
                        {
                            _9057 = -1.0f;
                        }
                        else
                        {
                            _9057 = float((_9045 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9062 = _9057;
                        break;
                    }
                    uint _9047;
                    _9047 = 4294967295u;
                    uint _10170;
                    for (int _9046 = 0; _9046 < 8; _9047 = _10170, _9046++)
                    {
                        int _9050 = 0;
                        for (;;)
                        {
                            if (_9050 < 5)
                            {
                                int2 _7457 = _8721 + (_1085[_9046] * _1094[_9050].xx);
                                bool _7460 = any(bool2(_7457.x < int2(0, 0).x, _7457.y < int2(0, 0).y));
                                bool _7468;
                                if (!_7460)
                                {
                                    _7468 = any(bool2(_7457.x >= cbFI_MvDepthLaneSize.x, _7457.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7468 = _7460;
                                }
                                if (_7468)
                                {
                                    _10170 = _9047;
                                    break;
                                }
                                uint4 _7546 = r_warped_motion_qdata_tp1.Load(int3(_7457, 0));
                                uint _7547 = _7546.x;
                                if (_7547 != 0u)
                                {
                                    _10170 = min(_9047, _7547);
                                    break;
                                }
                                _9050++;
                                continue;
                            }
                            else
                            {
                                _10170 = _9047;
                                break;
                            }
                        }
                    }
                    float _9049;
                    if (_9047 == 4294967295u)
                    {
                        _9049 = -1.0f;
                    }
                    else
                    {
                        float _9048;
                        if (_9047 == 0u)
                        {
                            _9048 = -1.0f;
                        }
                        else
                        {
                            _9048 = float((_9047 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9049 = _9048;
                    }
                    _9062 = _9049;
                    break;
                } while(false);
                float4 _9090;
                if (_9062 >= 0.0f)
                {
                    float _7568 = (exp((_9062 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4430;
                    if (_4257)
                    {
                        uint _7575_dummy_parameter;
                        _4430 = r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7575_dummy_parameter))))), 0)).x > _7568;
                    }
                    else
                    {
                        _4430 = _4257;
                    }
                    float4 _9080;
                    if (_4430)
                    {
                        float4 _8580 = _9067;
                        _8580.z = 0.0f;
                        _9080 = _8580;
                    }
                    else
                    {
                        _9080 = _9067;
                    }
                    bool _4442;
                    if (_4263)
                    {
                        uint _7594_dummy_parameter;
                        _4442 = r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7594_dummy_parameter))))), 0)).x > _7568;
                    }
                    else
                    {
                        _4442 = _4263;
                    }
                    float4 _9091;
                    if (_4442)
                    {
                        float4 _8582 = _9080;
                        _8582.w = 0.0f;
                        _9091 = _8582;
                    }
                    else
                    {
                        _9091 = _9080;
                    }
                    _9090 = _9091;
                }
                else
                {
                    _9090 = _9067;
                }
                _9089 = _9090;
            }
            else
            {
                _9089 = _9067;
            }
            bool _4450 = _4245 != _4251;
            bool _4457;
            if (_4450)
            {
                _4457 = _4245 ? _4191 : _4194;
            }
            else
            {
                _4457 = _4450;
            }
            float4 _9169;
            if (_4457)
            {
                bool2 _4462 = _4245.xx;
                float2 _4463 = float2(_4462.x ? _8691.x : _8693.x, _4462.y ? _8691.y : _8693.y);
                float _9082;
                if (_4245)
                {
                    uint _7613_dummy_parameter;
                    _9082 = r_depth_tm1.Load(int3(int2(floor(_4463 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7613_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7629_dummy_parameter;
                    _9082 = r_depth_tp1.Load(int3(int2(floor(_4463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7629_dummy_parameter))))), 0)).x;
                }
                float4x4 _9083;
                if (_4245)
                {
                    _9083 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9083 = cbFI_MotionTP1ToTM1;
                }
                float2 _9084;
                do
                {
                    float _7656 = _4463.x;
                    float _7659 = 1.0f - _4463.y;
                    float4 _7670 = mul(float4((float2(_7656, _7659) * 2.0f) - 1.0f.xx, _9082, 1.0f), _9083);
                    float _7672 = _7670.w;
                    if (!(_7672 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9084 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7685 = ((_7670.xy / _7672.xx) + 1.0f.xx) * 0.5f;
                    _9084 = float2(_7685.x - _7656, _7659 - _7685.y);
                    break;
                } while(false);
                float2 _4493 = float2(cbFI_DisplaySize);
                float4 _9170;
                if (!(length(((_4463 + _9084) - float2(_4462.x ? _8693.x : _8691.x, _4462.y ? _8693.y : _8691.y)) * _4493) <= ((0.100000001490116119384765625f * length(_9084 * _4493)) + 8.0f)))
                {
                    float4 _9171;
                    if (_4245)
                    {
                        float4 _8592 = _9089;
                        _8592.x = 0.0f;
                        _9171 = _8592;
                    }
                    else
                    {
                        float4 _8594 = _9089;
                        _8594.y = 0.0f;
                        _9171 = _8594;
                    }
                    _9170 = _9171;
                }
                else
                {
                    _9170 = _9089;
                }
                _9169 = _9170;
            }
            else
            {
                _9169 = _9089;
            }
            float4 _4518 = _8870 * _9169;
            float _4520 = dot(_4518, 1.0f.xxxx);
            float4 _9343;
            bool _9363;
            if (_4520 > 0.0f)
            {
                _9363 = _8840;
                _9343 = _4518 / _4520.xxxx;
            }
            else
            {
                bool _4531 = any(bool4(_9169.x < 1.0f.xxxx.x, _9169.y < 1.0f.xxxx.y, _9169.z < 1.0f.xxxx.z, _9169.w < 1.0f.xxxx.w));
                if (_4531)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7707;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7707);
                    }
                }
                bool4 _10202 = _4531.xxxx;
                _9363 = _4531 ? true : _8840;
                _9343 = float4(_10202.x ? 0.0f.xxxx.x : _8870.x, _10202.y ? 0.0f.xxxx.y : _8870.y, _10202.z ? 0.0f.xxxx.z : _8870.z, _10202.w ? 0.0f.xxxx.w : _8870.w);
            }
            _9362 = _9363;
            _9342 = _9343;
        }
        else
        {
            _9362 = _8840;
            _9342 = _8870;
        }
        uint _4540 = (cbFI_pad0 >> 24u) & 31u;
        uint _4544 = (cbFI_pad0 >> 16u) & 255u;
        bool _4546 = _4540 != 0u;
        bool _4548 = _4544 == 12u;
        bool _4551 = _4544 == 13u;
        float4 _9359;
        float _9765;
        float _9792;
        float _9818;
        if ((_4546 || _4548) || _4551)
        {
            float _9172;
            do
            {
                bool _7791 = all(bool2(_8694.x > 0.0f.xx.x, _8694.y > 0.0f.xx.y));
                bool _7797;
                if (_7791)
                {
                    _7797 = all(bool2(_8694.x < 1.0f.xx.x, _8694.y < 1.0f.xx.y));
                }
                else
                {
                    _7797 = _7791;
                }
                bool _7728 = !_7797;
                bool _7735;
                if (!_7728)
                {
                    bool _7802 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
                    bool _7808;
                    if (_7802)
                    {
                        _7808 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7808 = _7802;
                    }
                    _7735 = !_7808;
                }
                else
                {
                    _7735 = _7728;
                }
                if (_7735)
                {
                    _9172 = 0.0f;
                    break;
                }
                uint _7815_dummy_parameter;
                uint _7831_dummy_parameter;
                float4 _7756 = mul(float4((float2(_8694.x, 1.0f - _8694.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7815_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7758 = _7756.w;
                if (abs(_7758) < 9.9999999747524270787835121154785e-07f)
                {
                    _9172 = 0.0f;
                    break;
                }
                float _7769 = abs(cbFI_DeviceToViewDepth.y / ((_7756.z / _7758) - cbFI_DeviceToViewDepth.x));
                float _7772 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7831_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9172 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7769 - _7772) / max(max(_7769, _7772), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7879 = all(bool2(_8695.x > 0.0f.xx.x, _8695.y > 0.0f.xx.y));
            bool _7885;
            if (_7879)
            {
                _7885 = all(bool2(_8695.x < 1.0f.xx.x, _8695.y < 1.0f.xx.y));
            }
            else
            {
                _7885 = _7879;
            }
            float _9173;
            if (_7885)
            {
                uint _7892_dummy_parameter;
                _9173 = length((_5318 + (r_motion_tp1.Load(int3(int2(floor(_8695 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7892_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9173 = 1000000.0f;
            }
            float _4571 = 1.0f - smoothstep(2.0f, 8.0f, _9173);
            float _9184;
            if ((_4540 & 1u) != 0u)
            {
                _9184 = _9172;
            }
            else
            {
                _9184 = 1.0f;
            }
            float _9185;
            if ((_4540 & 2u) != 0u)
            {
                _9185 = _9184 * _4571;
            }
            else
            {
                _9185 = _9184;
            }
            float _9186;
            if ((_4540 & 4u) != 0u)
            {
                _9186 = _9185 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6039 - _6047) - length(_6023 - _6031))));
            }
            else
            {
                _9186 = _9185;
            }
            float _9353;
            if ((_4540 & 8u) != 0u)
            {
                _9353 = lerp(1.0f, _9186, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6023 - _6031)));
            }
            else
            {
                _9353 = _9186;
            }
            bool _4626 = (_4540 & 16u) != 0u;
            bool _4635;
            if (_4626)
            {
                _4635 = length(_8689 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4635 = _4626;
            }
            float _10204 = _4635 ? 1.0f : _9353;
            bool _4641 = _4546 && _6232;
            bool _4646;
            if (_4641)
            {
                bool _7917 = all(bool2(_8691.x > 0.0f.xx.x, _8691.y > 0.0f.xx.y));
                bool _7923;
                if (_7917)
                {
                    _7923 = all(bool2(_8691.x < 1.0f.xx.x, _8691.y < 1.0f.xx.y));
                }
                else
                {
                    _7923 = _7917;
                }
                _4646 = _7923;
            }
            else
            {
                _4646 = _4641;
            }
            bool _4651;
            if (_4646)
            {
                bool _7928 = all(bool2(_8693.x > 0.0f.xx.x, _8693.y > 0.0f.xx.y));
                bool _7934;
                if (_7928)
                {
                    _7934 = all(bool2(_8693.x < 1.0f.xx.x, _8693.y < 1.0f.xx.y));
                }
                else
                {
                    _7934 = _7928;
                }
                _4651 = _7934;
            }
            else
            {
                _4651 = _4646;
            }
            float4 _9360;
            if (_4651)
            {
                float _4657 = _9342.x + _9342.y;
                float _4666 = (_9342.z + _9342.w) * (1.0f - _10204);
                float _9356;
                if (_4657 > 9.9999997473787516355514526367188e-06f)
                {
                    _9356 = _9342.x / _4657;
                }
                else
                {
                    _9356 = _3863;
                }
                _9360 = float4(_9342.x + (_4666 * _9356), _9342.y + (_4666 * (1.0f - _9356)), _9342.zw * _10204);
            }
            else
            {
                _9360 = _9342;
            }
            _9818 = _10204;
            _9792 = _4571;
            _9765 = _9172;
            _9359 = _9360;
        }
        else
        {
            _9818 = 1.0f;
            _9792 = 1.0f;
            _9765 = 1.0f;
            _9359 = _9342;
        }
        float3 _9974;
        if (_9362)
        {
            float3 _7940 = r_current_interpolation_source.Load(int3(_3292, 0)).xyz;
            float3 _9975;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6232)
            {
                uint _7947_dummy_parameter;
                float _9462;
                _9462 = r_depth_tm1.Load(int3(int2(floor(_8691 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7947_dummy_parameter))))), 0)).x;
                float _4778;
                for (int _9461 = 0; _9461 < 24; _9462 = _4778, _9461++)
                {
                    float _4750 = float(_9461 & 7) * 0.785398185253143310546875f;
                    int _4752 = _9461 >> 3;
                    int _10024;
                    if (_4752 == 0)
                    {
                        _10024 = 16;
                    }
                    else
                    {
                        _10024 = (_4752 == 1) ? 48 : 96;
                    }
                    uint _7967_dummy_parameter;
                    _4778 = min(_9462, r_depth_tm1.Load(int3(int2(floor(clamp(_8691 + ((cbFI_MvDepthLaneSizeRcp * float(_10024)) * float2(cos(_4750), sin(_4750))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7967_dummy_parameter))))), 0)).x);
                }
                float2 _9463;
                do
                {
                    float _7989 = 1.0f - _8691.y;
                    float4 _8000 = mul(float4((float2(_8691.x, _7989) * 2.0f) - 1.0f.xx, _9462, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8002 = _8000.w;
                    if (!(_8002 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9463 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8015 = ((_8000.xy / _8002.xx) + 1.0f.xx) * 0.5f;
                    _9463 = float2(_8015.x - _8691.x, _7989 - _8015.y);
                    break;
                } while(false);
                float2 _4789 = _8691 + _9463;
                bool _8033 = all(bool2(_4789.x > 0.0f.xx.x, _4789.y > 0.0f.xx.y));
                bool _8039;
                if (_8033)
                {
                    _8039 = all(bool2(_4789.x < 1.0f.xx.x, _4789.y < 1.0f.xx.y));
                }
                else
                {
                    _8039 = _8033;
                }
                float3 _9976;
                if (_8039)
                {
                    float _4795 = abs(cbFI_DeviceToViewDepth.y / (_9462 - cbFI_DeviceToViewDepth.x));
                    uint _8059_dummy_parameter;
                    int2 _8059 = int2(spvTextureSize(r_depth_m2, uint(0), _8059_dummy_parameter));
                    float _4799 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4789 * float2(_8059))), int2(0, 0), _8059 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _9981;
                    if (abs(_4799 - _4795) <= (0.20000000298023223876953125f * max(_4799, _4795)))
                    {
                        uint _8093_dummy_parameter;
                        int2 _8093 = int2(spvTextureSize(r_colour_m2, uint(0), _8093_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8116;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8116);
                        }
                        _9981 = r_colour_m2.Load(int3(clamp(int2(floor(_4789 * float2(_8093))), int2(0, 0), _8093 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8126;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8126);
                        }
                        _9981 = _7940;
                    }
                    _9976 = _9981;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8136;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8136);
                    }
                    _9976 = _7940;
                }
                _9975 = _9976;
            }
            else
            {
                _9975 = _7940;
            }
            _9974 = _9975;
        }
        else
        {
            _9974 = (((_6023 * _9359.x) + (_6031 * _9359.y)) + (_6039 * _9359.z)) + (_6047 * _9359.w);
        }
        uint _4827 = cbFI_pad0 & 255u;
        bool _9869;
        float3 _9973;
        if (_4827 != 0u)
        {
            float3 _4832 = r_present_backbuffer.Load(int3(_3292, 0)).xyz;
            float3 _4836 = r_current_interpolation_source.Load(int3(_3292, 0)).xyz;
            float3 _4840 = abs(_4832 - _4836);
            float3 _9466;
            if (_4827 == 2u)
            {
                _9466 = (abs(_4836) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9466 = 0.000244140625f.xxx;
            }
            bool _4856 = any(bool3(_4840.x > _9466.x, _4840.y > _9466.y, _4840.z > _9466.z));
            bool3 _10205 = _4856.xxx;
            _9973 = float3(_10205.x ? _4832.x : _9974.x, _10205.y ? _4832.y : _9974.y, _10205.z ? _4832.z : _9974.z);
            _9869 = _4856;
        }
        else
        {
            _9973 = _9974;
            _9869 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8151;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8151);
        }
        float3 _9957;
        if (_4544 == 1u)
        {
            _9957 = lerp(_6023, _6031, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _9958;
            if (_4544 == 2u)
            {
                _9958 = lerp(_6039, _6047, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _9959;
                if (_4544 == 3u)
                {
                    _9959 = float(_9869).xxx;
                }
                else
                {
                    float3 _9960;
                    if (_4544 == 4u)
                    {
                        _9960 = float3(((_8689 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _9961;
                        if (_4544 == 5u)
                        {
                            _9961 = float3(((_5318 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _9962;
                            if (_4544 == 6u)
                            {
                                _9962 = float3(_9359.xy, _9359.z + _9359.w);
                            }
                            else
                            {
                                float3 _9963;
                                if (_4544 == 7u)
                                {
                                    _9963 = r_current_interpolation_source.Load(int3(_3292, 0)).xyz;
                                }
                                else
                                {
                                    float3 _9964;
                                    if (_4544 == 8u)
                                    {
                                        _9964 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3638, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _9965;
                                        if (_4548)
                                        {
                                            _9965 = float3(_9765, _9792, _9818);
                                        }
                                        else
                                        {
                                            float3 _9966;
                                            if (_4551)
                                            {
                                                _9966 = _6039;
                                            }
                                            else
                                            {
                                                float3 _9967;
                                                if (_4544 == 20u)
                                                {
                                                    _9967 = _6023;
                                                }
                                                else
                                                {
                                                    float3 _9968;
                                                    if (_4544 == 21u)
                                                    {
                                                        _9968 = _6031;
                                                    }
                                                    else
                                                    {
                                                        float3 _9969;
                                                        if (_4544 == 22u)
                                                        {
                                                            _9969 = _6047;
                                                        }
                                                        else
                                                        {
                                                            float3 _9970;
                                                            if (_4544 == 18u)
                                                            {
                                                                _9970 = _9612;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10207 = (_4544 == 19u).xxx;
                                                                _9970 = float3(_10207.x ? _9472.x : _9973.x, _10207.y ? _9472.y : _9973.y, _10207.z ? _9472.z : _9973.z);
                                                            }
                                                            _9969 = _9970;
                                                        }
                                                        _9968 = _9969;
                                                    }
                                                    _9967 = _9968;
                                                }
                                                _9966 = _9967;
                                            }
                                            _9965 = _9966;
                                        }
                                        _9964 = _9965;
                                    }
                                    _9963 = _9964;
                                }
                                _9962 = _9963;
                            }
                            _9961 = _9962;
                        }
                        _9960 = _9961;
                    }
                    _9959 = _9960;
                }
                _9958 = _9959;
            }
            _9957 = _9958;
        }
        float3 _9956;
        if ((_4544 >= 9u) && (_4544 <= 11u))
        {
            uint _5011 = 64u + uint((_8721.y * cbFI_MvDepthLaneSize.x) + _8721.x);
            uint _5015 = rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) & 15u;
            float3 _9986;
            if (_4544 == 10u)
            {
                float3 _9955;
                if ((rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) & 32u) != 0u)
                {
                    _9955 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _9954;
                    if ((rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) & 16u) != 0u)
                    {
                        _9954 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5036 = ((rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) & 64u) != 0u).xxx;
                        _9954 = float3(_5036.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5036.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5036.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _9955 = _9954;
                }
                _9986 = _9955;
            }
            else
            {
                float3 _9987;
                if (_4544 == 11u)
                {
                    uint _5049 = (rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) >> 8u) & 15u;
                    uint _5052 = (rw_nfru_diagnostics.Load<uint>(_5011 * 4 + 0) >> 12u) & 15u;
                    float3 _9947;
                    if ((_5015 == 2u) || (_5015 == 3u))
                    {
                        _9947 = _3005[_5015];
                    }
                    else
                    {
                        bool _5064 = _5049 == 3u;
                        bool _5066 = _5052 == 3u;
                        float3 _9948;
                        if (_5064 && _5066)
                        {
                            _9948 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _9949;
                            if (_5064)
                            {
                                _9949 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _9950;
                                if (_5066)
                                {
                                    _9950 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _9951;
                                    if ((_5049 == 4u) || (_5052 == 4u))
                                    {
                                        _9951 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _9952;
                                        if ((_5049 == 1u) || (_5052 == 1u))
                                        {
                                            _9952 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10209 = (_5015 == 1u).xxx;
                                            _9952 = float3(_10209.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10209.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10209.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _9951 = _9952;
                                    }
                                    _9950 = _9951;
                                }
                                _9949 = _9950;
                            }
                            _9948 = _9949;
                        }
                        _9947 = _9948;
                    }
                    _9987 = _9947;
                }
                else
                {
                    _9987 = _3005[min(_5015, 7u)];
                }
                _9986 = _9987;
            }
            _9956 = _9986;
        }
        else
        {
            _9956 = _9957;
        }
        float4 _9990;
        if ((_4544 >= 14u) && (_4544 <= 16u))
        {
            float2 _9988;
            if (_4544 == 14u)
            {
                uint _5122_dummy_parameter;
                uint _5128_dummy_parameter;
                _9988 = r_flow_tm1.Load(int3(clamp(int2(floor(_3638 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5122_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5128_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _9989;
                if (_4544 == 16u)
                {
                    uint _8192 = r_warped_flow_qdata_tm1.Load(int3(_3654, 0)).x & 2147483647u;
                    uint _8224 = uint(max((int((_8192 >> 16u) & 15u) - 6), 0));
                    _9989 = ((float2(float((1 - (2 * int((_8192 >> 15u) & 1u))) * int(((_8192 >> uint(7)) & 127u) << _8224)), float((1 - (2 * int((_8192 >> 14u) & 1u))) * int((_8192 & 127u) << _8224))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _9989 = _5318 * float2(cbFI_DisplaySize);
                }
                _9988 = _9989;
            }
            uint2 _5161 = uint2(clamp(round(_9988 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5163 = _5161.x;
            uint _5170 = _5161.y;
            _9990 = float4(float(_5163 & 255u), float((_5163 >> 8u) | ((_5170 & 15u) << 4u)), float(_5170 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _9991;
            if (_4544 == 17u)
            {
                _9991 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3654, 0)).x != 0u), _3997, 0.0f, 1.0f);
            }
            else
            {
                _9991 = float4(_9956, 1.0f);
            }
            _9990 = _9991;
        }
        rw_output[_3292] = _9990.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5214 = ((uint(_3292.y) * uint(cbFI_DisplaySize.x)) + uint(_3292.x)) * 6u;
            uint _8270 = spvPackHalf2x16(clamp(_6022.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5214 * 4 + 0, (((_8270 & 32767u) >> 4u) | ((((_8270 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6022.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8305 = spvPackHalf2x16(clamp(_6030.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5214 + 1u) * 4 + 0, (((_8305 & 32767u) >> 4u) | ((((_8305 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6030.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8340 = spvPackHalf2x16(clamp(_6038.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5214 + 2u) * 4 + 0, (((_8340 & 32767u) >> 4u) | ((((_8340 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6038.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8375 = spvPackHalf2x16(clamp(_6046.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5214 + 3u) * 4 + 0, (((_8375 & 32767u) >> 4u) | ((((_8375 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6046.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8402 = r_current_interpolation_source.Load(int3(_3292, 0));
            uint _8416 = spvPackHalf2x16(clamp(_8402.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5214 + 4u) * 4 + 0, (((_8416 & 32767u) >> 4u) | ((((_8416 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8402.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10023;
            if (_9869 || (_4544 != 0u))
            {
                _10023 = 4294967295u;
            }
            else
            {
                uint _8451 = spvPackHalf2x16(clamp(_9990.xy, 0.0f.xx, 65000.0f.xx));
                _10023 = (((_8451 & 32767u) >> 4u) | ((((_8451 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9990.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5214 + 5u) * 4 + 0, _10023);
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
