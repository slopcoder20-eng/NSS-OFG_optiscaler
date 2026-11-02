static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19718;

static const int2 _1240[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1249[5] = { 2, 4, 7, 11, 16 };
static const float3 _4547[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4848 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4848.x >= cbFI_DisplaySize.x, _4848.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4848] = float4(r_present_backbuffer.Load(int3(_4848, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7701 = cbFI_DisplaySize - int2(1, 1);
                int2 _7702 = clamp(_4848, int2(0, 0), _7701);
                uint _7712 = uint((_7702.y * cbFI_DisplaySize.x) + _7702.x) * 2u;
                uint _7715 = rw_nfru_select.Load<uint>(_7712 * 4 + 0);
                float2 _7716 = spvUnpackHalf2x16(_7715);
                uint _7720 = rw_nfru_select.Load<uint>((_7712 + 1u) * 4 + 0);
                float2 _7721 = spvUnpackHalf2x16(_7720);
                float _7722 = _7716.x;
                float _7724 = _7721.x;
                if (_7721.y > 1.5f)
                {
                    rw_output[_4848] = float4(_7722, _7716.y, _7724, 1.0f).xyz;
                    break;
                }
                int _23155;
                float _23156;
                float3 _23157;
                float _23158;
                float _23159;
                _23159 = 0.0f;
                _23158 = 0.0f;
                _23157 = 0.0f.xxx;
                _23156 = 0.0f;
                _23155 = -2;
                float3 _23162;
                float _23163;
                float _23164;
                float _23165;
                for (; _23155 <= 2; _23159 = _23165, _23158 = _23164, _23157 = _23162, _23156 = _23163, _23155++)
                {
                    _23165 = _23159;
                    _23164 = _23158;
                    _23163 = _23156;
                    _23162 = _23157;
                    for (int _23160 = -2; _23160 <= 2; )
                    {
                        float _7618 = float((_23160 * _23160) + (_23155 * _23155));
                        float _7623 = exp(_7618 * (-0.319999992847442626953125f));
                        int2 _7628 = int2(_23160, _23155);
                        int2 _7738 = clamp(_4848 + (_7628 * int2(2, 2)), int2(0, 0), _7701);
                        uint _7748 = uint((_7738.y * cbFI_DisplaySize.x) + _7738.x) * 2u;
                        float _7645 = exp(_7618 * (-0.5f));
                        int2 _7770 = clamp(_4848 + (_7628 * int2(6, 6)), int2(0, 0), _7701);
                        _23165 += _7645;
                        _23164 += (_7645 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7770.y * cbFI_DisplaySize.x) + _7770.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23163 += _7623;
                        _23162 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7748 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7748 + 1u) * 4 + 0)).x, _19718).xyz * _7623);
                        _23160++;
                        continue;
                    }
                }
                float3 _7675 = _23157 / _23156.xxx;
                rw_output[_4848] = float4(_7675 + ((float4(_7722, _7716.y, _7724, _7721.y).xyz - _7675) * clamp(_23158 / _23159, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5347 = (float2(_4848) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5349 = float2(cbFI_MvDepthLaneSize);
        int2 _5358 = int2(floor(_5347 * _5349));
        int2 _5363 = int2(floor(_5347 * float2(cbFI_FlowLaneSize)));
        float4 _7841 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5347 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7847 = r_warped_filled_flow_tm1.Load(int3(_5363, 0)).xy;
        float2 _7853 = r_warped_filled_motion_tp1.Load(int3(_5358, 0)).xy;
        bool _7875 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19719;
        if (_7875)
        {
            float _7888 = ((2.0f * _5347.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19719 = float2(atan(_7888) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5347.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7888 * _7888))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19719 = _5347;
        }
        bool _5384 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19740;
        bool _19882;
        int2 _19963;
        float3 _22247;
        if (_5384)
        {
            float _19721;
            float _19723;
            _19723 = 2.0f;
            _19721 = -1.0f;
            uint _4945[9];
            float _23166;
            float _23169;
            for (int _19720 = 0; _19720 < 9; _19723 = _23169, _19721 = _23166, _19720++)
            {
                _4945[_19720] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5358 + int2((_19720 % 3) - 1, (_19720 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4945[_19720] != 0u)
                {
                    float _23150;
                    if (_4945[_19720] == 0u)
                    {
                        _23150 = -1.0f;
                    }
                    else
                    {
                        _23150 = float((_4945[_19720] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23169 = min(_19723, _23150);
                    _23166 = max(_19721, _23150);
                }
                else
                {
                    _23169 = _19723;
                    _23166 = _19721;
                }
            }
            float _5430 = float(_19721 >= 0.0f);
            float3 _19286 = 0.0f.xxx;
            _19286.y = _5430;
            float2 _19741;
            bool _19883;
            int2 _19964;
            float3 _22248;
            if ((_19721 - _19723) > 0.0199999995529651641845703125f)
            {
                float _19729;
                int2 _19730;
                float2 _19731;
                int2 _19733;
                float2 _19739;
                _19739 = _7853;
                _19733 = _5358;
                _19731 = _7853;
                _19730 = _5358;
                _19729 = -1.0f;
                float _23174;
                int2 _23178;
                float2 _23189;
                int2 _23200;
                float2 _23233;
                float _23618;
                int _19728 = 0;
                float _23131 = 1000000000.0f;
                for (; _19728 < 9; _23131 = _23618, _19739 = _23233, _19733 = _23200, _19731 = _23189, _19730 = _23178, _19729 = _23174, _19728++)
                {
                    if (_4945[_19728] == 0u)
                    {
                        _23618 = _23131;
                        _23233 = _19739;
                        _23200 = _19733;
                        _23189 = _19731;
                        _23178 = _19730;
                        _23174 = _19729;
                        continue;
                    }
                    int2 _5465 = clamp(_5358 + int2((_19728 % 3) - 1, (_19728 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7963 = _4945[_19728] & 2147483647u;
                    uint _7995 = uint(max((int((_7963 >> 16u) & 15u) - 6), 0));
                    float2 _5471 = (float2(float((1 - (2 * int((_7963 >> 15u) & 1u))) * int(((_7963 >> uint(7)) & 127u) << _7995)), float((1 - (2 * int((_7963 >> 14u) & 1u))) * int((_7963 & 127u) << _7995))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23117;
                    if (_4945[_19728] == 0u)
                    {
                        _23117 = -1.0f;
                    }
                    else
                    {
                        _23117 = float((_4945[_19728] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5476 = _23117 - 0.100000001490116119384765625f;
                    float2 _23118;
                    if (_7875)
                    {
                        float2 _8072 = clamp((((_19719 + (_5471 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8075 = tan(_8072.x);
                        _23118 = (float2(_8075 / cbFI_DeviceToViewDepth.z, (tan(_8072.y) * sqrt(1.0f + (_8075 * _8075))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23118 = _19719 + (_5471 * cbFI_Timestep);
                    }
                    float _5483 = cbFI_Timestep - 1.0f;
                    float2 _23119;
                    if (_7875)
                    {
                        float2 _8143 = clamp((((_19719 + (_5471 * _5483)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8146 = tan(_8143.x);
                        _23119 = (float2(_8146 / cbFI_DeviceToViewDepth.z, (tan(_8143.y) * sqrt(1.0f + (_8146 * _8146))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23119 = _19719 + (_5471 * _5483);
                    }
                    bool _8179 = all(bool2(_23118.x > 0.0f.xx.x, _23118.y > 0.0f.xx.y));
                    bool _8185;
                    if (_8179)
                    {
                        _8185 = all(bool2(_23118.x < 1.0f.xx.x, _23118.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8185 = _8179;
                    }
                    float _23122;
                    if (_8185)
                    {
                        uint _8192_dummy_parameter;
                        _23122 = max((_5476 - (log((r_depth_tm1.Load(int3(int2(floor(_23118 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8192_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23122 = 0.0f;
                    }
                    bool _8222 = all(bool2(_23119.x > 0.0f.xx.x, _23119.y > 0.0f.xx.y));
                    bool _8228;
                    if (_8222)
                    {
                        _8228 = all(bool2(_23119.x < 1.0f.xx.x, _23119.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8228 = _8222;
                    }
                    float _23123;
                    if (_8228)
                    {
                        uint _8235_dummy_parameter;
                        _23123 = _23122 + max((_5476 - (log((r_depth_tp1.Load(int3(int2(floor(_23119 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8235_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23123 = _23122;
                    }
                    float _23175;
                    int2 _23179;
                    float2 _23190;
                    int2 _23201;
                    float2 _23234;
                    float _23619;
                    if (_23123 == 0.0f)
                    {
                        bool _5518 = _5476 > _19729;
                        bool2 _23627 = _5518.xx;
                        _23619 = _23131;
                        _23234 = float2(_23627.x ? _5471.x : _19739.x, _23627.y ? _5471.y : _19739.y);
                        _23201 = int2(_23627.x ? _5465.x : _19733.x, _23627.y ? _5465.y : _19733.y);
                        _23190 = _19731;
                        _23179 = _19730;
                        _23175 = _5518 ? _5476 : _19729;
                    }
                    else
                    {
                        bool _5527 = _23123 < _23131;
                        bool2 _23623 = _5527.xx;
                        _23619 = _5527 ? _23123 : _23131;
                        _23234 = _19739;
                        _23201 = _19733;
                        _23190 = float2(_23623.x ? _5471.x : _19731.x, _23623.y ? _5471.y : _19731.y);
                        _23179 = int2(_23623.x ? _5465.x : _19730.x, _23623.y ? _5465.y : _19730.y);
                        _23175 = _19729;
                    }
                    _23618 = _23619;
                    _23233 = _23234;
                    _23200 = _23201;
                    _23189 = _23190;
                    _23178 = _23179;
                    _23174 = _23175;
                }
                bool _5539 = _19729 < 0.0f;
                bool2 _23633 = _5539.xx;
                int2 _23636 = int2(_23633.x ? _19730.x : _19733.x, _23633.y ? _19730.y : _19733.y);
                _22248 = float3(1.0f, _5430, float(any(bool2(_23636.x != _5358.x, _23636.y != _5358.y))));
                _19964 = _23636;
                _19883 = _5539 ? false : true;
                _19741 = float2(_23633.x ? _19731.x : _19739.x, _23633.y ? _19731.y : _19739.y);
            }
            else
            {
                _22248 = _19286;
                _19964 = _5358;
                _19883 = false;
                _19741 = _7853;
            }
            _22247 = _22248;
            _19963 = _19964;
            _19882 = _19883;
            _19740 = _19741;
        }
        else
        {
            _22247 = 0.0f.xxx;
            _19963 = _5358;
            _19882 = false;
            _19740 = _7853;
        }
        float2 _19742;
        if (_7875)
        {
            float2 _8300 = clamp((((_19719 + (_19740 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8303 = tan(_8300.x);
            _19742 = (float2(_8303 / cbFI_DeviceToViewDepth.z, (tan(_8300.y) * sqrt(1.0f + (_8303 * _8303))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19742 = _19719 + (_19740 * cbFI_Timestep);
        }
        float _5562 = cbFI_Timestep - 1.0f;
        float2 _19744;
        if (_7875)
        {
            float2 _8371 = clamp((((_19719 + (_19740 * _5562)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8374 = tan(_8371.x);
            _19744 = (float2(_8374 / cbFI_DeviceToViewDepth.z, (tan(_8371.y) * sqrt(1.0f + (_8374 * _8374))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19744 = _19719 + (_19740 * _5562);
        }
        float _5567 = -cbFI_Timestep;
        float2 _19745;
        if (_7875)
        {
            float2 _8442 = clamp((((_19719 + (_7847 * _5567)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8445 = tan(_8442.x);
            _19745 = (float2(_8445 / cbFI_DeviceToViewDepth.z, (tan(_8442.y) * sqrt(1.0f + (_8445 * _8445))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19745 = _19719 + (_7847 * _5567);
        }
        float _5572 = 1.0f - cbFI_Timestep;
        float2 _19746;
        if (_7875)
        {
            float2 _8513 = clamp((((_19719 + (_7847 * _5572)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8516 = tan(_8513.x);
            _19746 = (float2(_8516 / cbFI_DeviceToViewDepth.z, (tan(_8513.y) * sqrt(1.0f + (_8516 * _8516))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19746 = _19719 + (_7847 * _5572);
        }
        float4 _8551 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19742, 0.0f);
        float3 _8552 = _8551.xyz;
        float4 _8559 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19744, 0.0f);
        float3 _8560 = _8559.xyz;
        float4 _8567 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19745, 0.0f);
        float3 _8568 = _8567.xyz;
        float4 _8575 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19746, 0.0f);
        float3 _8576 = _8575.xyz;
        float4 _8590 = exp(_7841 - max(max(max(_7841.x, _7841.y), _7841.z), _7841.w).xxxx);
        float4 _8597 = _8590 / (dot(_8590, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5588 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19953;
        float _21261;
        if (_5588)
        {
            float2 _5594 = 0.5f.xx / _5349;
            float _5597 = _5594.x;
            float _5598 = -_5597;
            float _5600 = _5594.y;
            float _5601 = -_5600;
            float2 _5603 = _5347 + float2(_5598, _5601);
            float2 _5605 = float2(cbFI_DisplaySize);
            bool _19763;
            do
            {
                bool _8677 = all(bool2(_5603.x > 0.0f.xx.x, _5603.y > 0.0f.xx.y));
                bool _8683;
                if (_8677)
                {
                    _8683 = all(bool2(_5603.x < 1.0f.xx.x, _5603.y < 1.0f.xx.y));
                }
                else
                {
                    _8683 = _8677;
                }
                if (!_8683)
                {
                    _19763 = false;
                    break;
                }
                uint _8690_dummy_parameter;
                float4x4 _19761;
                do
                {
                    float4x4 _8704;
                    bool _19760;
                    do
                    {
                        _8704 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19760 = false;
                            break;
                        }
                        uint _8738 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8738 + 32u) * 4 + 0) != 1u)
                        {
                            _19760 = false;
                            break;
                        }
                        uint _19757;
                        _19757 = 0u;
                        for (; _19757 < 4u; _19757++)
                        {
                            for (uint _19758 = 0u; _19758 < 4u; )
                            {
                                _8704[_19757][_19758] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8738 + (_19757 * 4u)) + _19758) * 4 + 0));
                                _19758++;
                                continue;
                            }
                        }
                        _19760 = true;
                        break;
                    } while(false);
                    if (_19760)
                    {
                        _19761 = _8704;
                        break;
                    }
                    _19761 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19762;
                do
                {
                    float _8815 = _5603.x;
                    float _8818 = 1.0f - _5603.y;
                    float4 _8829 = mul(float4((float2(_8815, _8818) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5603 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8690_dummy_parameter))))), 0)).x, 1.0f), _19761);
                    float _8831 = _8829.w;
                    if (!(_8831 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19762 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8844 = ((_8829.xy / _8831.xx) + 1.0f.xx) * 0.5f;
                    _19762 = float2(_8844.x - _8815, _8818 - _8844.y);
                    break;
                } while(false);
                float2 _8641 = abs(_19762);
                if (any(bool2(_8641.x > 100000.0f.xx.x, _8641.y > 100000.0f.xx.y)))
                {
                    _19763 = false;
                    break;
                }
                float _8649 = length(_19762 * _5605);
                uint _8864_dummy_parameter;
                bool _8663 = _8649 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8670;
                if (_8663)
                {
                    _8670 = length((r_motion_tp1.Load(int3(int2(floor(_5603 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8864_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _8649);
                }
                else
                {
                    _8670 = _8663;
                }
                _19763 = _8670;
                break;
            } while(false);
            float2 _5615 = _5347 + float2(_5597, _5601);
            bool _19770;
            do
            {
                bool _8950 = all(bool2(_5615.x > 0.0f.xx.x, _5615.y > 0.0f.xx.y));
                bool _8956;
                if (_8950)
                {
                    _8956 = all(bool2(_5615.x < 1.0f.xx.x, _5615.y < 1.0f.xx.y));
                }
                else
                {
                    _8956 = _8950;
                }
                if (!_8956)
                {
                    _19770 = false;
                    break;
                }
                uint _8963_dummy_parameter;
                float4x4 _19768;
                do
                {
                    float4x4 _8977;
                    bool _19767;
                    do
                    {
                        _8977 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19767 = false;
                            break;
                        }
                        uint _9011 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9011 + 32u) * 4 + 0) != 1u)
                        {
                            _19767 = false;
                            break;
                        }
                        uint _19764;
                        _19764 = 0u;
                        for (; _19764 < 4u; _19764++)
                        {
                            for (uint _19765 = 0u; _19765 < 4u; )
                            {
                                _8977[_19764][_19765] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9011 + (_19764 * 4u)) + _19765) * 4 + 0));
                                _19765++;
                                continue;
                            }
                        }
                        _19767 = true;
                        break;
                    } while(false);
                    if (_19767)
                    {
                        _19768 = _8977;
                        break;
                    }
                    _19768 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19769;
                do
                {
                    float _9088 = _5615.x;
                    float _9091 = 1.0f - _5615.y;
                    float4 _9102 = mul(float4((float2(_9088, _9091) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5615 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8963_dummy_parameter))))), 0)).x, 1.0f), _19768);
                    float _9104 = _9102.w;
                    if (!(_9104 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19769 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9117 = ((_9102.xy / _9104.xx) + 1.0f.xx) * 0.5f;
                    _19769 = float2(_9117.x - _9088, _9091 - _9117.y);
                    break;
                } while(false);
                float2 _8914 = abs(_19769);
                if (any(bool2(_8914.x > 100000.0f.xx.x, _8914.y > 100000.0f.xx.y)))
                {
                    _19770 = false;
                    break;
                }
                float _8922 = length(_19769 * _5605);
                uint _9137_dummy_parameter;
                bool _8936 = _8922 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8943;
                if (_8936)
                {
                    _8943 = length((r_motion_tp1.Load(int3(int2(floor(_5615 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9137_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _8922);
                }
                else
                {
                    _8943 = _8936;
                }
                _19770 = _8943;
                break;
            } while(false);
            float2 _5628 = _5347 + float2(_5598, _5600);
            bool _19777;
            do
            {
                bool _9223 = all(bool2(_5628.x > 0.0f.xx.x, _5628.y > 0.0f.xx.y));
                bool _9229;
                if (_9223)
                {
                    _9229 = all(bool2(_5628.x < 1.0f.xx.x, _5628.y < 1.0f.xx.y));
                }
                else
                {
                    _9229 = _9223;
                }
                if (!_9229)
                {
                    _19777 = false;
                    break;
                }
                uint _9236_dummy_parameter;
                float4x4 _19775;
                do
                {
                    float4x4 _9250;
                    bool _19774;
                    do
                    {
                        _9250 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19774 = false;
                            break;
                        }
                        uint _9284 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9284 + 32u) * 4 + 0) != 1u)
                        {
                            _19774 = false;
                            break;
                        }
                        uint _19771;
                        _19771 = 0u;
                        for (; _19771 < 4u; _19771++)
                        {
                            for (uint _19772 = 0u; _19772 < 4u; )
                            {
                                _9250[_19771][_19772] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9284 + (_19771 * 4u)) + _19772) * 4 + 0));
                                _19772++;
                                continue;
                            }
                        }
                        _19774 = true;
                        break;
                    } while(false);
                    if (_19774)
                    {
                        _19775 = _9250;
                        break;
                    }
                    _19775 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19776;
                do
                {
                    float _9361 = _5628.x;
                    float _9364 = 1.0f - _5628.y;
                    float4 _9375 = mul(float4((float2(_9361, _9364) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5628 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9236_dummy_parameter))))), 0)).x, 1.0f), _19775);
                    float _9377 = _9375.w;
                    if (!(_9377 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19776 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9390 = ((_9375.xy / _9377.xx) + 1.0f.xx) * 0.5f;
                    _19776 = float2(_9390.x - _9361, _9364 - _9390.y);
                    break;
                } while(false);
                float2 _9187 = abs(_19776);
                if (any(bool2(_9187.x > 100000.0f.xx.x, _9187.y > 100000.0f.xx.y)))
                {
                    _19777 = false;
                    break;
                }
                float _9195 = length(_19776 * _5605);
                uint _9410_dummy_parameter;
                bool _9209 = _9195 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9216;
                if (_9209)
                {
                    _9216 = length((r_motion_tp1.Load(int3(int2(floor(_5628 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9410_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _9195);
                }
                else
                {
                    _9216 = _9209;
                }
                _19777 = _9216;
                break;
            } while(false);
            float2 _5640 = _5347 + _5594;
            bool _19784;
            do
            {
                bool _9496 = all(bool2(_5640.x > 0.0f.xx.x, _5640.y > 0.0f.xx.y));
                bool _9502;
                if (_9496)
                {
                    _9502 = all(bool2(_5640.x < 1.0f.xx.x, _5640.y < 1.0f.xx.y));
                }
                else
                {
                    _9502 = _9496;
                }
                if (!_9502)
                {
                    _19784 = false;
                    break;
                }
                uint _9509_dummy_parameter;
                float4x4 _19782;
                do
                {
                    float4x4 _9523;
                    bool _19781;
                    do
                    {
                        _9523 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19781 = false;
                            break;
                        }
                        uint _9557 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9557 + 32u) * 4 + 0) != 1u)
                        {
                            _19781 = false;
                            break;
                        }
                        uint _19778;
                        _19778 = 0u;
                        for (; _19778 < 4u; _19778++)
                        {
                            for (uint _19779 = 0u; _19779 < 4u; )
                            {
                                _9523[_19778][_19779] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9557 + (_19778 * 4u)) + _19779) * 4 + 0));
                                _19779++;
                                continue;
                            }
                        }
                        _19781 = true;
                        break;
                    } while(false);
                    if (_19781)
                    {
                        _19782 = _9523;
                        break;
                    }
                    _19782 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19783;
                do
                {
                    float _9634 = _5640.x;
                    float _9637 = 1.0f - _5640.y;
                    float4 _9648 = mul(float4((float2(_9634, _9637) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5640 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9509_dummy_parameter))))), 0)).x, 1.0f), _19782);
                    float _9650 = _9648.w;
                    if (!(_9650 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19783 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9663 = ((_9648.xy / _9650.xx) + 1.0f.xx) * 0.5f;
                    _19783 = float2(_9663.x - _9634, _9637 - _9663.y);
                    break;
                } while(false);
                float2 _9460 = abs(_19783);
                if (any(bool2(_9460.x > 100000.0f.xx.x, _9460.y > 100000.0f.xx.y)))
                {
                    _19784 = false;
                    break;
                }
                float _9468 = length(_19783 * _5605);
                uint _9683_dummy_parameter;
                bool _9482 = _9468 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9489;
                if (_9482)
                {
                    _9489 = length((r_motion_tp1.Load(int3(int2(floor(_5640 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9683_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _9468);
                }
                else
                {
                    _9489 = _9482;
                }
                _19784 = _9489;
                break;
            } while(false);
            float _5646 = 0.25f * (((float(_19763) + float(_19770)) + float(_19777)) + float(_19784));
            float4 _19954;
            if (_5646 < 1.0f)
            {
                bool _19791;
                do
                {
                    bool _9769 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                    bool _9775;
                    if (_9769)
                    {
                        _9775 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9775 = _9769;
                    }
                    if (!_9775)
                    {
                        _19791 = false;
                        break;
                    }
                    uint _9782_dummy_parameter;
                    float4x4 _19789;
                    do
                    {
                        float4x4 _9796;
                        bool _19788;
                        do
                        {
                            _9796 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19788 = false;
                                break;
                            }
                            uint _9830 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9830 + 32u) * 4 + 0) != 1u)
                            {
                                _19788 = false;
                                break;
                            }
                            uint _19785;
                            _19785 = 0u;
                            for (; _19785 < 4u; _19785++)
                            {
                                for (uint _19786 = 0u; _19786 < 4u; )
                                {
                                    _9796[_19785][_19786] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9830 + (_19785 * 4u)) + _19786) * 4 + 0));
                                    _19786++;
                                    continue;
                                }
                            }
                            _19788 = true;
                            break;
                        } while(false);
                        if (_19788)
                        {
                            _19789 = _9796;
                            break;
                        }
                        _19789 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19790;
                    do
                    {
                        float _9910 = 1.0f - _19742.y;
                        float4 _9921 = mul(float4((float2(_19742.x, _9910) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9782_dummy_parameter))))), 0)).x, 1.0f), _19789);
                        float _9923 = _9921.w;
                        if (!(_9923 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19790 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9936 = ((_9921.xy / _9923.xx) + 1.0f.xx) * 0.5f;
                        _19790 = float2(_9936.x - _19742.x, _9910 - _9936.y);
                        break;
                    } while(false);
                    float2 _9733 = abs(_19790);
                    if (any(bool2(_9733.x > 100000.0f.xx.x, _9733.y > 100000.0f.xx.y)))
                    {
                        _19791 = false;
                        break;
                    }
                    float _9741 = length(_19790 * _5605);
                    uint _9956_dummy_parameter;
                    bool _9755 = _9741 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9762;
                    if (_9755)
                    {
                        _9762 = length((r_motion_tp1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9956_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _9741);
                    }
                    else
                    {
                        _9762 = _9755;
                    }
                    _19791 = _9762;
                    break;
                } while(false);
                bool _19798;
                do
                {
                    bool _10042 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                    bool _10048;
                    if (_10042)
                    {
                        _10048 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10048 = _10042;
                    }
                    if (!_10048)
                    {
                        _19798 = false;
                        break;
                    }
                    uint _10055_dummy_parameter;
                    float4x4 _19796;
                    do
                    {
                        float4x4 _10069;
                        bool _19795;
                        do
                        {
                            _10069 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19795 = false;
                                break;
                            }
                            uint _10103 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10103 + 32u) * 4 + 0) != 1u)
                            {
                                _19795 = false;
                                break;
                            }
                            uint _19792;
                            _19792 = 0u;
                            for (; _19792 < 4u; _19792++)
                            {
                                for (uint _19793 = 0u; _19793 < 4u; )
                                {
                                    _10069[_19792][_19793] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10103 + (_19792 * 4u)) + _19793) * 4 + 0));
                                    _19793++;
                                    continue;
                                }
                            }
                            _19795 = true;
                            break;
                        } while(false);
                        if (_19795)
                        {
                            _19796 = _10069;
                            break;
                        }
                        _19796 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19797;
                    do
                    {
                        float _10183 = 1.0f - _19744.y;
                        float4 _10194 = mul(float4((float2(_19744.x, _10183) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10055_dummy_parameter))))), 0)).x, 1.0f), _19796);
                        float _10196 = _10194.w;
                        if (!(_10196 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19797 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10209 = ((_10194.xy / _10196.xx) + 1.0f.xx) * 0.5f;
                        _19797 = float2(_10209.x - _19744.x, _10183 - _10209.y);
                        break;
                    } while(false);
                    float2 _10006 = abs(_19797);
                    if (any(bool2(_10006.x > 100000.0f.xx.x, _10006.y > 100000.0f.xx.y)))
                    {
                        _19798 = false;
                        break;
                    }
                    float _10014 = length(_19797 * _5605);
                    uint _10229_dummy_parameter;
                    bool _10028 = _10014 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10035;
                    if (_10028)
                    {
                        _10035 = length((r_motion_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10229_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _10014);
                    }
                    else
                    {
                        _10035 = _10028;
                    }
                    _19798 = _10035;
                    break;
                } while(false);
                bool _19805;
                do
                {
                    bool _10315 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _10321;
                    if (_10315)
                    {
                        _10321 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10321 = _10315;
                    }
                    if (!_10321)
                    {
                        _19805 = false;
                        break;
                    }
                    uint _10328_dummy_parameter;
                    float4x4 _19803;
                    do
                    {
                        float4x4 _10342;
                        bool _19802;
                        do
                        {
                            _10342 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19802 = false;
                                break;
                            }
                            uint _10376 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10376 + 32u) * 4 + 0) != 1u)
                            {
                                _19802 = false;
                                break;
                            }
                            uint _19799;
                            _19799 = 0u;
                            for (; _19799 < 4u; _19799++)
                            {
                                for (uint _19800 = 0u; _19800 < 4u; )
                                {
                                    _10342[_19799][_19800] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10376 + (_19799 * 4u)) + _19800) * 4 + 0));
                                    _19800++;
                                    continue;
                                }
                            }
                            _19802 = true;
                            break;
                        } while(false);
                        if (_19802)
                        {
                            _19803 = _10342;
                            break;
                        }
                        _19803 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19804;
                    do
                    {
                        float _10456 = 1.0f - _19745.y;
                        float4 _10467 = mul(float4((float2(_19745.x, _10456) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10328_dummy_parameter))))), 0)).x, 1.0f), _19803);
                        float _10469 = _10467.w;
                        if (!(_10469 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19804 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10482 = ((_10467.xy / _10469.xx) + 1.0f.xx) * 0.5f;
                        _19804 = float2(_10482.x - _19745.x, _10456 - _10482.y);
                        break;
                    } while(false);
                    float2 _10279 = abs(_19804);
                    if (any(bool2(_10279.x > 100000.0f.xx.x, _10279.y > 100000.0f.xx.y)))
                    {
                        _19805 = false;
                        break;
                    }
                    float _10287 = length(_19804 * _5605);
                    uint _10502_dummy_parameter;
                    bool _10301 = _10287 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10308;
                    if (_10301)
                    {
                        _10308 = length((r_motion_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10502_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _10287);
                    }
                    else
                    {
                        _10308 = _10301;
                    }
                    _19805 = _10308;
                    break;
                } while(false);
                bool _19812;
                do
                {
                    bool _10588 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                    bool _10594;
                    if (_10588)
                    {
                        _10594 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10594 = _10588;
                    }
                    if (!_10594)
                    {
                        _19812 = false;
                        break;
                    }
                    uint _10601_dummy_parameter;
                    float4x4 _19810;
                    do
                    {
                        float4x4 _10615;
                        bool _19809;
                        do
                        {
                            _10615 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19809 = false;
                                break;
                            }
                            uint _10649 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10649 + 32u) * 4 + 0) != 1u)
                            {
                                _19809 = false;
                                break;
                            }
                            uint _19806;
                            _19806 = 0u;
                            for (; _19806 < 4u; _19806++)
                            {
                                for (uint _19807 = 0u; _19807 < 4u; )
                                {
                                    _10615[_19806][_19807] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10649 + (_19806 * 4u)) + _19807) * 4 + 0));
                                    _19807++;
                                    continue;
                                }
                            }
                            _19809 = true;
                            break;
                        } while(false);
                        if (_19809)
                        {
                            _19810 = _10615;
                            break;
                        }
                        _19810 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19811;
                    do
                    {
                        float _10729 = 1.0f - _19746.y;
                        float4 _10740 = mul(float4((float2(_19746.x, _10729) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10601_dummy_parameter))))), 0)).x, 1.0f), _19810);
                        float _10742 = _10740.w;
                        if (!(_10742 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19811 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10755 = ((_10740.xy / _10742.xx) + 1.0f.xx) * 0.5f;
                        _19811 = float2(_10755.x - _19746.x, _10729 - _10755.y);
                        break;
                    } while(false);
                    float2 _10552 = abs(_19811);
                    if (any(bool2(_10552.x > 100000.0f.xx.x, _10552.y > 100000.0f.xx.y)))
                    {
                        _19812 = false;
                        break;
                    }
                    float _10560 = length(_19811 * _5605);
                    uint _10775_dummy_parameter;
                    bool _10574 = _10560 > ((8.0f * _5605.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10581;
                    if (_10574)
                    {
                        _10581 = length((r_motion_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10775_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5605) < (0.20000000298023223876953125f * _10560);
                    }
                    else
                    {
                        _10581 = _10574;
                    }
                    _19812 = _10581;
                    break;
                } while(false);
                float4 _5673 = _8597 * float4(_19791 ? 0.0f : 1.0f, _19798 ? 0.0f : 1.0f, _19805 ? 0.0f : 1.0f, _19812 ? 0.0f : 1.0f);
                float _5675 = dot(_5673, 1.0f.xxxx);
                float4 _19955;
                if (_5675 > 0.001000000047497451305389404296875f)
                {
                    _19955 = _5673 / _5675.xxxx;
                }
                else
                {
                    _19955 = _8597;
                }
                _19954 = _19955;
            }
            else
            {
                _19954 = _8597;
            }
            _21261 = _5646;
            _19953 = _19954;
        }
        else
        {
            _21261 = 0.0f;
            _19953 = _8597;
        }
        bool _5692 = _5384 && (!_19882);
        bool _5701;
        if (_5692)
        {
            _5701 = (_19953.z + _19953.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5701 = _5692;
        }
        bool _5712;
        if (_5701)
        {
            _5712 = length((_19745 - _19742) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5712 = _5701;
        }
        bool _20042;
        if (_5712)
        {
            uint4 _10804 = r_warped_motion_qdata_tp1.Load(int3(_19963, 0));
            uint _10805 = _10804.x;
            bool _20045;
            if (_10805 != 0u)
            {
                float _20031;
                if (_10805 == 0u)
                {
                    _20031 = -1.0f;
                }
                else
                {
                    _20031 = float((_10805 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5722 = _20031 - 0.12000000476837158203125f;
                bool _10824 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _10830;
                if (_10824)
                {
                    _10830 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _10830 = _10824;
                }
                bool _5732;
                if (_10830)
                {
                    uint _10837_dummy_parameter;
                    _5732 = (log((r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10837_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5722;
                }
                else
                {
                    _5732 = _10830;
                }
                bool _5746;
                if (!_5732)
                {
                    bool _10867 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                    bool _10873;
                    if (_10867)
                    {
                        _10873 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10873 = _10867;
                    }
                    bool _5744;
                    if (_10873)
                    {
                        uint _10880_dummy_parameter;
                        _5744 = (log((r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10880_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5722;
                    }
                    else
                    {
                        _5744 = _10873;
                    }
                    _5746 = _5744;
                }
                else
                {
                    _5746 = _5732;
                }
                _20045 = _5746;
            }
            else
            {
                _20045 = false;
            }
            _20042 = _20045;
        }
        else
        {
            _20042 = false;
        }
        bool _5751 = _19882 || _20042;
        bool _5756;
        if (_5751)
        {
            bool _10910 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
            bool _10916;
            if (_10910)
            {
                _10916 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
            }
            else
            {
                _10916 = _10910;
            }
            _5756 = _10916;
        }
        else
        {
            _5756 = _5751;
        }
        bool _5761;
        if (_5756)
        {
            bool _10921 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
            bool _10927;
            if (_10921)
            {
                _10927 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
            }
            else
            {
                _10927 = _10921;
            }
            _5761 = _10927;
        }
        else
        {
            _5761 = _5756;
        }
        float4 _20165;
        if (_5761)
        {
            float _5767 = _19953.x + _19953.y;
            float _5772 = _19953.z + _19953.w;
            float _20060;
            if (_5767 > 0.001000000047497451305389404296875f)
            {
                _20060 = _19953.x / _5767;
            }
            else
            {
                _20060 = _5572;
            }
            _20165 = float4(_19953.x + (_5772 * _20060), _19953.y + (_5772 * (1.0f - _20060)), 0.0f, 0.0f);
        }
        else
        {
            _20165 = _19953;
        }
        bool _10955 = (cbFI_pad0 & 1024u) != 0u;
        bool _10931 = !_10955;
        bool _10932 = !_10931;
        bool _10949;
        if (_10932)
        {
            _10949 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19963.y * cbFI_MvDepthLaneSize.x) + _19963.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10949 = _10931;
        }
        bool _10981;
        if (_10932)
        {
            _10981 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5363.y * cbFI_FlowLaneSize.x) + _5363.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10981 = _10931;
        }
        float _5807 = float(_10981);
        bool _20186;
        float4 _20225;
        float3 _21981;
        if (_10955)
        {
            bool _5817;
            if (_10949)
            {
                _5817 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
            }
            else
            {
                _5817 = _10949;
            }
            bool _5823;
            if (_5817)
            {
                _5823 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
            }
            else
            {
                _5823 = _5817;
            }
            bool _5830;
            if (_10949)
            {
                _5830 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
            }
            else
            {
                _5830 = _10949;
            }
            bool _5836;
            if (_5830)
            {
                _5836 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
            }
            else
            {
                _5836 = _5830;
            }
            bool _5843;
            if (_10981)
            {
                _5843 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
            }
            else
            {
                _5843 = _10981;
            }
            bool _5849;
            if (_5843)
            {
                _5849 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
            }
            else
            {
                _5849 = _5843;
            }
            bool _5856;
            if (_10981)
            {
                _5856 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
            }
            else
            {
                _5856 = _10981;
            }
            bool _5862;
            if (_5856)
            {
                _5862 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
            }
            else
            {
                _5862 = _5856;
            }
            bool _5864 = !_10949;
            if (_5864)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11023;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11023);
                }
            }
            bool _5869 = !_10981;
            if (_5869)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11033;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11033);
                }
            }
            if (_10949 && _5869)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11043;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11043);
                }
            }
            if (_5864 && _10981)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11053;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11053);
                }
            }
            float _5888 = float(_5823);
            float _5890 = float(_5836);
            bool _5893 = _5849 && _5862;
            float _20094;
            if (_5893)
            {
                _20094 = 1.0f;
            }
            else
            {
                _20094 = (_5849 || _5862) ? 0.5f : 0.0f;
            }
            bool _20109;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5823)) && (!_5836))
            {
                bool _5923;
                if (_5893)
                {
                    float _20102;
                    do
                    {
                        bool _11137 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                        bool _11143;
                        if (_11137)
                        {
                            _11143 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11143 = _11137;
                        }
                        bool _11074 = !_11143;
                        bool _11081;
                        if (!_11074)
                        {
                            bool _11148 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                            bool _11154;
                            if (_11148)
                            {
                                _11154 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11154 = _11148;
                            }
                            _11081 = !_11154;
                        }
                        else
                        {
                            _11081 = _11074;
                        }
                        if (_11081)
                        {
                            _20102 = 0.0f;
                            break;
                        }
                        uint _11161_dummy_parameter;
                        uint _11177_dummy_parameter;
                        float4x4 _20101;
                        do
                        {
                            float4x4 _11191;
                            bool _20100;
                            do
                            {
                                _11191 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20100 = false;
                                    break;
                                }
                                uint _11225 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11225 + 32u) * 4 + 0) != 1u)
                                {
                                    _20100 = false;
                                    break;
                                }
                                uint _20097;
                                _20097 = 0u;
                                for (; _20097 < 4u; _20097++)
                                {
                                    for (uint _20098 = 0u; _20098 < 4u; )
                                    {
                                        _11191[_20097][_20098] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11225 + 16u) + (_20097 * 4u)) + _20098) * 4 + 0));
                                        _20098++;
                                        continue;
                                    }
                                }
                                _20100 = true;
                                break;
                            } while(false);
                            if (_20100)
                            {
                                _20101 = _11191;
                                break;
                            }
                            _20101 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11102 = mul(float4((float2(_19745.x, 1.0f - _19745.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11161_dummy_parameter))))), 0)).x, 1.0f), _20101);
                        float _11104 = _11102.w;
                        if (abs(_11104) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20102 = 0.0f;
                            break;
                        }
                        float _11115 = abs(cbFI_DeviceToViewDepth.y / ((_11102.z / _11104) - cbFI_DeviceToViewDepth.x));
                        float _11118 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11177_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20102 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11115 - _11118) / max(max(_11115, _11118), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5923 = _20102 >= 0.5f;
                }
                else
                {
                    _5923 = _5893;
                }
                bool _5931;
                if (_5923)
                {
                    _5931 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5931 = _5923;
                }
                bool _20110;
                if (_5931)
                {
                    uint _11329_dummy_parameter;
                    float4x4 _20107;
                    do
                    {
                        float4x4 _11343;
                        bool _20106;
                        do
                        {
                            _11343 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20106 = false;
                                break;
                            }
                            uint _11377 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11377 + 32u) * 4 + 0) != 1u)
                            {
                                _20106 = false;
                                break;
                            }
                            uint _20103;
                            _20103 = 0u;
                            for (; _20103 < 4u; _20103++)
                            {
                                for (uint _20104 = 0u; _20104 < 4u; )
                                {
                                    _11343[_20103][_20104] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11377 + 16u) + (_20103 * 4u)) + _20104) * 4 + 0));
                                    _20104++;
                                    continue;
                                }
                            }
                            _20106 = true;
                            break;
                        } while(false);
                        if (_20106)
                        {
                            _20107 = _11343;
                            break;
                        }
                        _20107 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20108;
                    do
                    {
                        float _11457 = 1.0f - _19745.y;
                        float4 _11468 = mul(float4((float2(_19745.x, _11457) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11329_dummy_parameter))))), 0)).x, 1.0f), _20107);
                        float _11470 = _11468.w;
                        if (!(_11470 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20108 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11483 = ((_11468.xy / _11470.xx) + 1.0f.xx) * 0.5f;
                        _20108 = float2(_11483.x - _19745.x, _11457 - _11483.y);
                        break;
                    } while(false);
                    float2 _5944 = float2(cbFI_DisplaySize);
                    _20110 = length(((_19745 + _20108) - _19746) * _5944) <= ((0.100000001490116119384765625f * length(_20108 * _5944)) + 8.0f);
                }
                else
                {
                    _20110 = _5923;
                }
                _20109 = _20110;
            }
            else
            {
                _20109 = true;
            }
            bool _5958 = !_20109;
            bool _23637 = _5958 ? false : _5862;
            bool _23638 = _5958 ? false : _5849;
            bool _20187;
            float4 _20226;
            if (!(((_5823 && _5836) && _23638) && _23637))
            {
                float4 _5980 = _20165 * float4(_5888, _5890, float(_23638), float(_23637));
                float _5982 = dot(_5980, 1.0f.xxxx);
                bool _5985 = !(_5982 > 0.0f);
                float4 _20227;
                if (!_5985)
                {
                    _20227 = _5980 / _5982.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11505;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11505);
                    }
                    _20227 = 0.0f.xxxx;
                }
                _20226 = _20227;
                _20187 = _5985;
            }
            else
            {
                _20226 = _20165;
                _20187 = false;
            }
            _21981 = float3(_5888, _5890, _20094);
            _20225 = _20226;
            _20186 = _20187;
        }
        else
        {
            _21981 = float3(float(_10949), _5807, 0.0f);
            _20225 = _20165;
            _20186 = false;
        }
        bool _6003 = !_20186;
        float4 _20318;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6003)
        {
            float _6010 = _20225.x + _20225.y;
            float4 _20319;
            if (_6010 > 0.001000000047497451305389404296875f)
            {
                _20319 = float4(_20225.x / _6010, _20225.y / _6010, 0.0f, 0.0f);
            }
            else
            {
                _20319 = float4(_5572, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20318 = _20319;
        }
        else
        {
            _20318 = _20225;
        }
        float4 _20495;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6003) && _10949)
        {
            float _20292;
            do
            {
                uint4 _11645 = r_warped_motion_qdata_tp1.Load(int3(_19963, 0));
                uint _11646 = _11645.x;
                if (_11646 != 0u)
                {
                    float _20291;
                    if (_11646 == 0u)
                    {
                        _20291 = -1.0f;
                    }
                    else
                    {
                        _20291 = float((_11646 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20292 = _20291;
                    break;
                }
                int _20274;
                uint _20275;
                _20275 = _11646;
                _20274 = -1;
                uint _20290;
                for (; _20274 <= 1; _20275 = _20290, _20274++)
                {
                    _20290 = _20275;
                    for (int _20288 = -1; _20288 <= 1; )
                    {
                        _20290 = max(_20290, r_warped_motion_qdata_tp1.Load(int3(clamp(_19963 + int2(_20288, _20274), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20288++;
                        continue;
                    }
                }
                if (_20275 != 0u)
                {
                    float _20287;
                    if (_20275 == 0u)
                    {
                        _20287 = -1.0f;
                    }
                    else
                    {
                        _20287 = float((_20275 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20292 = _20287;
                    break;
                }
                uint _20277;
                _20277 = 4294967295u;
                uint _23270;
                for (int _20276 = 0; _20276 < 8; _20277 = _23270, _20276++)
                {
                    int _20280 = 0;
                    for (;;)
                    {
                        if (_20280 < 5)
                        {
                            int2 _11596 = _19963 + (_1240[_20276] * _1249[_20280].xx);
                            bool _11599 = any(bool2(_11596.x < int2(0, 0).x, _11596.y < int2(0, 0).y));
                            bool _11607;
                            if (!_11599)
                            {
                                _11607 = any(bool2(_11596.x >= cbFI_MvDepthLaneSize.x, _11596.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11607 = _11599;
                            }
                            if (_11607)
                            {
                                _23270 = _20277;
                                break;
                            }
                            uint4 _11685 = r_warped_motion_qdata_tp1.Load(int3(_11596, 0));
                            uint _11686 = _11685.x;
                            if (_11686 != 0u)
                            {
                                _23270 = min(_20277, _11686);
                                break;
                            }
                            _20280++;
                            continue;
                        }
                        else
                        {
                            _23270 = _20277;
                            break;
                        }
                    }
                }
                float _20279;
                if (_20277 == 4294967295u)
                {
                    _20279 = -1.0f;
                }
                else
                {
                    float _20278;
                    if (_20277 == 0u)
                    {
                        _20278 = -1.0f;
                    }
                    else
                    {
                        _20278 = float((_20277 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20279 = _20278;
                }
                _20292 = _20279;
                break;
            } while(false);
            float _6046 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6049 = r_warped_motion_qdata_tp1.Load(int3(_19963, 0)).x == 0u;
            bool _6055;
            if (_6049)
            {
                bool _11711 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                bool _11717;
                if (_11711)
                {
                    _11717 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                }
                else
                {
                    _11717 = _11711;
                }
                _6055 = _11717;
            }
            else
            {
                _6055 = _6049;
            }
            bool _6060;
            if (_6055)
            {
                bool _11722 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _11728;
                if (_11722)
                {
                    _11728 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _11728 = _11722;
                }
                _6060 = _11728;
            }
            else
            {
                _6060 = _6055;
            }
            bool _20304;
            float4 _20313;
            if (_6060)
            {
                uint _11735_dummy_parameter;
                float _11759 = log((r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11735_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11767_dummy_parameter;
                float _11791 = log((r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11767_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6071 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6078;
                if (_6071)
                {
                    _6078 = _11791 > (_11759 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6078 = _6071;
                }
                bool _20309;
                float4 _20331;
                if (_6078)
                {
                    _20331 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20309 = true;
                }
                else
                {
                    bool _6084 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6091;
                    if (_6084)
                    {
                        _6091 = _11759 > (_11791 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6091 = _6084;
                    }
                    bool4 _23639 = _6091.xxxx;
                    _20331 = float4(_23639.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20318.x, _23639.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20318.y, _23639.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20318.z, _23639.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20318.w);
                    _20309 = _6091 ? true : false;
                }
                _20313 = _20331;
                _20304 = _20309;
            }
            else
            {
                _20313 = _20318;
                _20304 = false;
            }
            float4 _20386;
            if (_20304)
            {
                _20386 = 1.0f.xxxx;
            }
            else
            {
                bool _6102 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6108;
                if (_6102)
                {
                    _6108 = _20313.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6108 = _6102;
                }
                bool _6113;
                if (_6108)
                {
                    bool _11797 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                    bool _11803;
                    if (_11797)
                    {
                        _11803 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11803 = _11797;
                    }
                    _6113 = _11803;
                }
                else
                {
                    _6113 = _6108;
                }
                float4 _20387;
                if (_6113)
                {
                    float _20340;
                    if (_20292 >= 0.0f)
                    {
                        _20340 = _20292 - _6046;
                    }
                    else
                    {
                        float _20336;
                        _20336 = 2.0f;
                        float _11860;
                        for (int _20335 = 0; _20335 < 24; _20336 = _11860, _20335++)
                        {
                            float _11824 = float(_20335 & 7) * 0.785398185253143310546875f;
                            int _11826 = _20335 >> 3;
                            int _20337;
                            if (_11826 == 0)
                            {
                                _20337 = 16;
                            }
                            else
                            {
                                _20337 = (_11826 == 1) ? 48 : 96;
                            }
                            uint _11892_dummy_parameter;
                            _11860 = min(_20336, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19744 + ((cbFI_MvDepthLaneSizeRcp * float(_20337)) * float2(cos(_11824), sin(_11824))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11892_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20340 = _20336;
                    }
                    uint _11924_dummy_parameter;
                    float4 _20388;
                    if (r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11924_dummy_parameter))))), 0)).x > ((exp((_20340 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20388 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20388 = 1.0f.xxxx;
                    }
                    _20387 = _20388;
                }
                else
                {
                    _20387 = 1.0f.xxxx;
                }
                _20386 = _20387;
            }
            bool _6141 = _20292 >= 0.0f;
            bool _6142 = (!_20304) && _6141;
            bool _6149;
            if (_6142)
            {
                _6149 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6149 = _6142;
            }
            bool _6155;
            if (_6149)
            {
                _6155 = _20313.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6155 = _6149;
            }
            bool _6160;
            if (_6155)
            {
                bool _11948 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                bool _11954;
                if (_11948)
                {
                    _11954 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                }
                else
                {
                    _11954 = _11948;
                }
                _6160 = _11954;
            }
            else
            {
                _6160 = _6155;
            }
            float4 _20411;
            if (_6160)
            {
                float _20380;
                if (_6141)
                {
                    _20380 = _20292 - _6046;
                }
                else
                {
                    float _20376;
                    _20376 = 2.0f;
                    float _12011;
                    for (int _20375 = 0; _20375 < 24; _20376 = _12011, _20375++)
                    {
                        float _11975 = float(_20375 & 7) * 0.785398185253143310546875f;
                        int _11977 = _20375 >> 3;
                        int _20377;
                        if (_11977 == 0)
                        {
                            _20377 = 16;
                        }
                        else
                        {
                            _20377 = (_11977 == 1) ? 48 : 96;
                        }
                        uint _12027_dummy_parameter;
                        _12011 = min(_20376, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19742 + ((cbFI_MvDepthLaneSizeRcp * float(_20377)) * float2(cos(_11975), sin(_11975))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12027_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20380 = _20376;
                }
                uint _12075_dummy_parameter;
                float4 _20412;
                if (r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12075_dummy_parameter))))), 0)).x > ((exp((_20380 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19438 = _20386;
                    _19438.x = 0.0f;
                    _20412 = _19438;
                }
                else
                {
                    _20412 = _20386;
                }
                _20411 = _20412;
            }
            else
            {
                _20411 = _20386;
            }
            float4 _20424;
            if (_6142)
            {
                float _12101 = (exp(((_20292 - _6046) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6198 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6204;
                if (_6198)
                {
                    _6204 = _20313.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6204 = _6198;
                }
                bool _6209;
                if (_6204)
                {
                    bool _12106 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                    bool _12112;
                    if (_12106)
                    {
                        _12112 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12112 = _12106;
                    }
                    _6209 = _12112;
                }
                else
                {
                    _6209 = _6204;
                }
                bool _6217;
                if (_6209)
                {
                    uint _12119_dummy_parameter;
                    _6217 = r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12119_dummy_parameter))))), 0)).x > _12101;
                }
                else
                {
                    _6217 = _6209;
                }
                float4 _20422;
                if (_6217)
                {
                    float4 _19441 = _20411;
                    _19441.w = 0.0f;
                    _20422 = _19441;
                }
                else
                {
                    _20422 = _20411;
                }
                bool _6224 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6230;
                if (_6224)
                {
                    _6230 = _20313.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6230 = _6224;
                }
                bool _6235;
                if (_6230)
                {
                    bool _12136 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _12142;
                    if (_12136)
                    {
                        _12142 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12142 = _12136;
                    }
                    _6235 = _12142;
                }
                else
                {
                    _6235 = _6230;
                }
                bool _6243;
                if (_6235)
                {
                    uint _12149_dummy_parameter;
                    _6243 = r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12149_dummy_parameter))))), 0)).x > _12101;
                }
                else
                {
                    _6243 = _6235;
                }
                float4 _20425;
                if (_6243)
                {
                    float4 _19444 = _20422;
                    _19444.z = 0.0f;
                    _20425 = _19444;
                }
                else
                {
                    _20425 = _20422;
                }
                _20424 = _20425;
            }
            else
            {
                _20424 = _20411;
            }
            float4 _20496;
            if (any(bool4(_20424.x < 1.0f.xxxx.x, _20424.y < 1.0f.xxxx.y, _20424.z < 1.0f.xxxx.z, _20424.w < 1.0f.xxxx.w)))
            {
                float4 _6254 = _20313 * _20424;
                float _6256 = dot(_6254, 1.0f.xxxx);
                float4 _20497;
                if (_6256 > 0.0f)
                {
                    _20497 = _6254 / _6256.xxxx;
                }
                else
                {
                    bool _6267 = _20424.y == 0.0f;
                    bool _6273;
                    if (_6267)
                    {
                        _6273 = _20424.x > 0.0f;
                    }
                    else
                    {
                        _6273 = _6267;
                    }
                    bool _6278;
                    if (_6273)
                    {
                        bool _12166 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                        bool _12172;
                        if (_12166)
                        {
                            _12172 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12172 = _12166;
                        }
                        _6278 = _12172;
                    }
                    else
                    {
                        _6278 = _6273;
                    }
                    float4 _20498;
                    if (_6278)
                    {
                        _20498 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6283 = _20424.x == 0.0f;
                        bool _6289;
                        if (_6283)
                        {
                            _6289 = _20424.y > 0.0f;
                        }
                        else
                        {
                            _6289 = _6283;
                        }
                        bool _6294;
                        if (_6289)
                        {
                            bool _12177 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                            bool _12183;
                            if (_12177)
                            {
                                _12183 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12183 = _12177;
                            }
                            _6294 = _12183;
                        }
                        else
                        {
                            _6294 = _6289;
                        }
                        bool4 _23642 = _6294.xxxx;
                        _20498 = float4(_23642.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20313.x, _23642.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20313.y, _23642.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20313.z, _23642.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20313.w);
                    }
                    _20497 = _20498;
                }
                _20496 = _20497;
            }
            else
            {
                _20496 = _20313;
            }
            _20495 = _20496;
        }
        else
        {
            _20495 = _20318;
        }
        float4 _21225;
        bool _21531;
        float3 _21721;
        if (((cbFI_pad0 & 32768u) != 0u) && _6003)
        {
            bool _6311 = _20495.x > 0.00999999977648258209228515625f;
            bool _6314 = _20495.y > 0.00999999977648258209228515625f;
            bool _6323 = (_20495.z + _20495.w) > 0.0199999995529651641845703125f;
            bool _6329;
            if (_6323)
            {
                bool _12188 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _12194;
                if (_12188)
                {
                    _12194 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _12194 = _12188;
                }
                _6329 = _12194;
            }
            else
            {
                _6329 = _6323;
            }
            bool _6334;
            if (_6329)
            {
                bool _12199 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                bool _12205;
                if (_12199)
                {
                    _12205 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                }
                else
                {
                    _12205 = _12199;
                }
                _6334 = _12205;
            }
            else
            {
                _6334 = _6329;
            }
            bool _6341;
            if (_6334)
            {
                float _20511;
                do
                {
                    bool _12288 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _12294;
                    if (_12288)
                    {
                        _12294 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12294 = _12288;
                    }
                    bool _12225 = !_12294;
                    bool _12232;
                    if (!_12225)
                    {
                        bool _12299 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                        bool _12305;
                        if (_12299)
                        {
                            _12305 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12305 = _12299;
                        }
                        _12232 = !_12305;
                    }
                    else
                    {
                        _12232 = _12225;
                    }
                    if (_12232)
                    {
                        _20511 = 0.0f;
                        break;
                    }
                    uint _12312_dummy_parameter;
                    uint _12328_dummy_parameter;
                    float4x4 _20510;
                    do
                    {
                        float4x4 _12342;
                        bool _20509;
                        do
                        {
                            _12342 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20509 = false;
                                break;
                            }
                            uint _12376 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12376 + 32u) * 4 + 0) != 1u)
                            {
                                _20509 = false;
                                break;
                            }
                            uint _20506;
                            _20506 = 0u;
                            for (; _20506 < 4u; _20506++)
                            {
                                for (uint _20507 = 0u; _20507 < 4u; )
                                {
                                    _12342[_20506][_20507] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12376 + 16u) + (_20506 * 4u)) + _20507) * 4 + 0));
                                    _20507++;
                                    continue;
                                }
                            }
                            _20509 = true;
                            break;
                        } while(false);
                        if (_20509)
                        {
                            _20510 = _12342;
                            break;
                        }
                        _20510 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12253 = mul(float4((float2(_19745.x, 1.0f - _19745.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12312_dummy_parameter))))), 0)).x, 1.0f), _20510);
                    float _12255 = _12253.w;
                    if (abs(_12255) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20511 = 0.0f;
                        break;
                    }
                    float _12266 = abs(cbFI_DeviceToViewDepth.y / ((_12253.z / _12255) - cbFI_DeviceToViewDepth.x));
                    float _12269 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12328_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20511 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12266 - _12269) / max(max(_12266, _12269), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6341 = _20511 < 0.5f;
            }
            else
            {
                _6341 = _6334;
            }
            float4 _20530;
            if (_6341)
            {
                uint _12480_dummy_parameter;
                uint _12511_dummy_parameter;
                float4 _20531;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12480_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12511_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20531 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20531 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20530 = _20531;
            }
            else
            {
                _20530 = 1.0f.xxxx;
            }
            bool _6365;
            if (_10949)
            {
                bool _12540 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                bool _12546;
                if (_12540)
                {
                    _12546 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                }
                else
                {
                    _12546 = _12540;
                }
                _6365 = _12546;
            }
            else
            {
                _6365 = _10949;
            }
            bool _6371;
            if (_10949)
            {
                bool _12551 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _12557;
                if (_12551)
                {
                    _12557 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _12557 = _12551;
                }
                _6371 = _12557;
            }
            else
            {
                _6371 = _10949;
            }
            bool _6377;
            if (_10981)
            {
                bool _12562 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _12568;
                if (_12562)
                {
                    _12568 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _12568 = _12562;
                }
                _6377 = _12568;
            }
            else
            {
                _6377 = _10981;
            }
            bool _6383;
            if (_10981)
            {
                bool _12573 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                bool _12579;
                if (_12573)
                {
                    _12579 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                }
                else
                {
                    _12579 = _12573;
                }
                _6383 = _12579;
            }
            else
            {
                _6383 = _10981;
            }
            bool _6386 = _6377 != _6383;
            bool _6392;
            if (_6386)
            {
                _6392 = _6365 || _6371;
            }
            else
            {
                _6392 = _6386;
            }
            float4 _20633;
            if (_6392)
            {
                float4 _19471 = _20530;
                _19471.z = 0.0f;
                _19471.w = 0.0f;
                _20633 = _19471;
            }
            else
            {
                _20633 = _20530;
            }
            bool _6399 = _6365 && _6311;
            bool _6402 = _6371 && _6314;
            float4 _20738;
            float3 _21830;
            if (_6399 || _6402)
            {
                float _20628;
                do
                {
                    uint4 _12718 = r_warped_motion_qdata_tp1.Load(int3(_19963, 0));
                    uint _12719 = _12718.x;
                    if (_12719 != 0u)
                    {
                        float _20627;
                        if (_12719 == 0u)
                        {
                            _20627 = -1.0f;
                        }
                        else
                        {
                            _20627 = float((_12719 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20628 = _20627;
                        break;
                    }
                    int _20610;
                    uint _20611;
                    _20611 = _12719;
                    _20610 = -1;
                    uint _20626;
                    for (; _20610 <= 1; _20611 = _20626, _20610++)
                    {
                        _20626 = _20611;
                        for (int _20624 = -1; _20624 <= 1; )
                        {
                            _20626 = max(_20626, r_warped_motion_qdata_tp1.Load(int3(clamp(_19963 + int2(_20624, _20610), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20624++;
                            continue;
                        }
                    }
                    if (_20611 != 0u)
                    {
                        float _20623;
                        if (_20611 == 0u)
                        {
                            _20623 = -1.0f;
                        }
                        else
                        {
                            _20623 = float((_20611 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20628 = _20623;
                        break;
                    }
                    uint _20613;
                    _20613 = 4294967295u;
                    uint _23271;
                    for (int _20612 = 0; _20612 < 8; _20613 = _23271, _20612++)
                    {
                        int _20616 = 0;
                        for (;;)
                        {
                            if (_20616 < 5)
                            {
                                int2 _12669 = _19963 + (_1240[_20612] * _1249[_20616].xx);
                                bool _12672 = any(bool2(_12669.x < int2(0, 0).x, _12669.y < int2(0, 0).y));
                                bool _12680;
                                if (!_12672)
                                {
                                    _12680 = any(bool2(_12669.x >= cbFI_MvDepthLaneSize.x, _12669.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12680 = _12672;
                                }
                                if (_12680)
                                {
                                    _23271 = _20613;
                                    break;
                                }
                                uint4 _12758 = r_warped_motion_qdata_tp1.Load(int3(_12669, 0));
                                uint _12759 = _12758.x;
                                if (_12759 != 0u)
                                {
                                    _23271 = min(_20613, _12759);
                                    break;
                                }
                                _20616++;
                                continue;
                            }
                            else
                            {
                                _23271 = _20613;
                                break;
                            }
                        }
                    }
                    float _20615;
                    if (_20613 == 4294967295u)
                    {
                        _20615 = -1.0f;
                    }
                    else
                    {
                        float _20614;
                        if (_20613 == 0u)
                        {
                            _20614 = -1.0f;
                        }
                        else
                        {
                            _20614 = float((_20613 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20615 = _20614;
                    }
                    _20628 = _20615;
                    break;
                } while(false);
                bool _6410 = _20628 < 0.0f;
                float _20629;
                if (_6410)
                {
                    _20629 = 0.0f;
                }
                else
                {
                    _20629 = _20628 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12780_dummy_parameter;
                uint _12812_dummy_parameter;
                float4 _20666;
                if ((_6410 && _6399) && _6402)
                {
                    uint _12844_dummy_parameter;
                    float _12868 = log((r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12844_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12876_dummy_parameter;
                    float _12900 = log((r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12876_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20667;
                    if (_12868 > (_12900 + 0.07999999821186065673828125f))
                    {
                        float4 _19475 = _20633;
                        _19475.x = 0.0f;
                        _20667 = _19475;
                    }
                    else
                    {
                        float4 _20668;
                        if (_12900 > (_12868 + 0.07999999821186065673828125f))
                        {
                            float4 _19477 = _20633;
                            _19477.y = 0.0f;
                            _20668 = _19477;
                        }
                        else
                        {
                            _20668 = _20633;
                        }
                        _20667 = _20668;
                    }
                    _20666 = _20667;
                }
                else
                {
                    _20666 = _20633;
                }
                float _6462 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6464 = _20628 >= 0.0f;
                float _20649;
                if (_6464)
                {
                    _20649 = _20628 - _6462;
                }
                else
                {
                    float _20645;
                    if (_6399)
                    {
                        float _20644;
                        _20644 = 2.0f;
                        float _12958;
                        for (int _20643 = 0; _20643 < 24; _20644 = _12958, _20643++)
                        {
                            float _12922 = float(_20643 & 7) * 0.785398185253143310546875f;
                            int _12924 = _20643 >> 3;
                            int _20646;
                            if (_12924 == 0)
                            {
                                _20646 = 16;
                            }
                            else
                            {
                                _20646 = (_12924 == 1) ? 48 : 96;
                            }
                            uint _12974_dummy_parameter;
                            _12958 = min(_20644, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19742 + ((cbFI_MvDepthLaneSizeRcp * float(_20646)) * float2(cos(_12922), sin(_12922))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12974_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20645 = _20644;
                    }
                    else
                    {
                        _20645 = 0.0f;
                    }
                    _20649 = _20645;
                }
                float _20656;
                if (_6464)
                {
                    _20656 = _20628 - _6462;
                }
                else
                {
                    float _20652;
                    if (_6402)
                    {
                        float _20651;
                        _20651 = 2.0f;
                        float _13072;
                        for (int _20650 = 0; _20650 < 24; _20651 = _13072, _20650++)
                        {
                            float _13036 = float(_20650 & 7) * 0.785398185253143310546875f;
                            int _13038 = _20650 >> 3;
                            int _20653;
                            if (_13038 == 0)
                            {
                                _20653 = 16;
                            }
                            else
                            {
                                _20653 = (_13038 == 1) ? 48 : 96;
                            }
                            uint _13104_dummy_parameter;
                            _13072 = min(_20651, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19744 + ((cbFI_MvDepthLaneSizeRcp * float(_20653)) * float2(cos(_13036), sin(_13036))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13104_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20652 = _20651;
                    }
                    else
                    {
                        _20652 = 0.0f;
                    }
                    _20656 = _20652;
                }
                float _20657;
                if (_6399)
                {
                    uint _13136_dummy_parameter;
                    _20657 = r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13136_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20657 = 0.0f;
                }
                float _20658;
                if (_6402)
                {
                    uint _13155_dummy_parameter;
                    _20658 = r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13155_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20658 = 0.0f;
                }
                bool _6519;
                if (_6399)
                {
                    _6519 = _20657 > ((exp((_20649 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6519 = _6399;
                }
                float4 _20674;
                if (_6519)
                {
                    float4 _19479 = _20666;
                    _19479.x = 0.0f;
                    _20674 = _19479;
                }
                else
                {
                    _20674 = _20666;
                }
                bool _6531;
                if (_6402)
                {
                    _6531 = _20658 > ((exp((_20656 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6531 = _6402;
                }
                float4 _20676;
                if (_6531)
                {
                    float4 _19481 = _20674;
                    _19481.y = 0.0f;
                    _20676 = _19481;
                }
                else
                {
                    _20676 = _20674;
                }
                float4 _20739;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6464)
                {
                    bool _6551;
                    if (_6399)
                    {
                        _6551 = _20657 < ((exp((_20649 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6551 = _6399;
                    }
                    float4 _20678;
                    if (_6551)
                    {
                        float4 _19483 = _20676;
                        _19483.x = 0.0f;
                        _20678 = _19483;
                    }
                    else
                    {
                        _20678 = _20676;
                    }
                    bool _6563;
                    if (_6402)
                    {
                        _6563 = _20658 < ((exp((_20656 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6563 = _6402;
                    }
                    float4 _20740;
                    if (_6563)
                    {
                        float4 _19485 = _20678;
                        _19485.y = 0.0f;
                        _20740 = _19485;
                    }
                    else
                    {
                        _20740 = _20678;
                    }
                    _20739 = _20740;
                }
                else
                {
                    _20739 = _20676;
                }
                _21830 = float3(_20629, log((r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12780_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12812_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20738 = _20739;
            }
            else
            {
                _21830 = float3(0.0f, 0.0f, 0.5f);
                _20738 = _20633;
            }
            bool _6574 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6323;
            bool _6580;
            if (_6574)
            {
                _6580 = _6377 || _6383;
            }
            else
            {
                _6580 = _6574;
            }
            float4 _20781;
            if (_6580)
            {
                float _20733;
                do
                {
                    uint4 _13334 = r_warped_motion_qdata_tp1.Load(int3(_19963, 0));
                    uint _13335 = _13334.x;
                    if (_13335 != 0u)
                    {
                        float _20732;
                        if (_13335 == 0u)
                        {
                            _20732 = -1.0f;
                        }
                        else
                        {
                            _20732 = float((_13335 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20733 = _20732;
                        break;
                    }
                    int _20715;
                    uint _20716;
                    _20716 = _13335;
                    _20715 = -1;
                    uint _20731;
                    for (; _20715 <= 1; _20716 = _20731, _20715++)
                    {
                        _20731 = _20716;
                        for (int _20729 = -1; _20729 <= 1; )
                        {
                            _20731 = max(_20731, r_warped_motion_qdata_tp1.Load(int3(clamp(_19963 + int2(_20729, _20715), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20729++;
                            continue;
                        }
                    }
                    if (_20716 != 0u)
                    {
                        float _20728;
                        if (_20716 == 0u)
                        {
                            _20728 = -1.0f;
                        }
                        else
                        {
                            _20728 = float((_20716 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20733 = _20728;
                        break;
                    }
                    uint _20718;
                    _20718 = 4294967295u;
                    uint _23272;
                    for (int _20717 = 0; _20717 < 8; _20718 = _23272, _20717++)
                    {
                        int _20721 = 0;
                        for (;;)
                        {
                            if (_20721 < 5)
                            {
                                int2 _13285 = _19963 + (_1240[_20717] * _1249[_20721].xx);
                                bool _13288 = any(bool2(_13285.x < int2(0, 0).x, _13285.y < int2(0, 0).y));
                                bool _13296;
                                if (!_13288)
                                {
                                    _13296 = any(bool2(_13285.x >= cbFI_MvDepthLaneSize.x, _13285.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13296 = _13288;
                                }
                                if (_13296)
                                {
                                    _23272 = _20718;
                                    break;
                                }
                                uint4 _13374 = r_warped_motion_qdata_tp1.Load(int3(_13285, 0));
                                uint _13375 = _13374.x;
                                if (_13375 != 0u)
                                {
                                    _23272 = min(_20718, _13375);
                                    break;
                                }
                                _20721++;
                                continue;
                            }
                            else
                            {
                                _23272 = _20718;
                                break;
                            }
                        }
                    }
                    float _20720;
                    if (_20718 == 4294967295u)
                    {
                        _20720 = -1.0f;
                    }
                    else
                    {
                        float _20719;
                        if (_20718 == 0u)
                        {
                            _20719 = -1.0f;
                        }
                        else
                        {
                            _20719 = float((_20718 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20720 = _20719;
                    }
                    _20733 = _20720;
                    break;
                } while(false);
                float4 _20782;
                if (_20733 >= 0.0f)
                {
                    float _13396 = (exp((_20733 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6599;
                    if (_6377)
                    {
                        uint _13403_dummy_parameter;
                        _6599 = r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13403_dummy_parameter))))), 0)).x > _13396;
                    }
                    else
                    {
                        _6599 = _6377;
                    }
                    float4 _20751;
                    if (_6599)
                    {
                        float4 _19487 = _20738;
                        _19487.z = 0.0f;
                        _20751 = _19487;
                    }
                    else
                    {
                        _20751 = _20738;
                    }
                    bool _6611;
                    if (_6383)
                    {
                        uint _13422_dummy_parameter;
                        _6611 = r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13422_dummy_parameter))))), 0)).x > _13396;
                    }
                    else
                    {
                        _6611 = _6383;
                    }
                    float4 _20783;
                    if (_6611)
                    {
                        float4 _19489 = _20751;
                        _19489.w = 0.0f;
                        _20783 = _19489;
                    }
                    else
                    {
                        _20783 = _20751;
                    }
                    _20782 = _20783;
                }
                else
                {
                    _20782 = _20738;
                }
                _20781 = _20782;
            }
            else
            {
                _20781 = _20738;
            }
            bool _6619 = _6365 != _6371;
            bool _6626;
            if (_6619)
            {
                _6626 = _6365 ? _6311 : _6314;
            }
            else
            {
                _6626 = _6619;
            }
            bool _6633;
            if (_6626)
            {
                _6633 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6633 = _6626;
            }
            float4 _20884;
            if (_6633)
            {
                bool2 _6638 = _6365.xx;
                float2 _6639 = float2(_6638.x ? _19742.x : _19744.x, _6638.y ? _19742.y : _19744.y);
                float _20765;
                if (_6365)
                {
                    uint _13441_dummy_parameter;
                    _20765 = r_depth_tm1.Load(int3(int2(floor(_6639 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13441_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13457_dummy_parameter;
                    _20765 = r_depth_tp1.Load(int3(int2(floor(_6639 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13457_dummy_parameter))))), 0)).x;
                }
                float4x4 _20772;
                if (_6365)
                {
                    float4x4 _20761;
                    do
                    {
                        float4x4 _13471;
                        bool _20760;
                        do
                        {
                            _13471 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20760 = false;
                                break;
                            }
                            uint _13505 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13505 + 32u) * 4 + 0) != 1u)
                            {
                                _20760 = false;
                                break;
                            }
                            uint _20757;
                            _20757 = 0u;
                            for (; _20757 < 4u; _20757++)
                            {
                                for (uint _20758 = 0u; _20758 < 4u; )
                                {
                                    _13471[_20757][_20758] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13505 + 16u) + (_20757 * 4u)) + _20758) * 4 + 0));
                                    _20758++;
                                    continue;
                                }
                            }
                            _20760 = true;
                            break;
                        } while(false);
                        if (_20760)
                        {
                            _20761 = _13471;
                            break;
                        }
                        _20761 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20772 = _20761;
                }
                else
                {
                    float4x4 _20756;
                    do
                    {
                        float4x4 _13577;
                        bool _20755;
                        do
                        {
                            _13577 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20755 = false;
                                break;
                            }
                            uint _13611 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13611 + 32u) * 4 + 0) != 1u)
                            {
                                _20755 = false;
                                break;
                            }
                            uint _20752;
                            _20752 = 0u;
                            for (; _20752 < 4u; _20752++)
                            {
                                for (uint _20753 = 0u; _20753 < 4u; )
                                {
                                    _13577[_20752][_20753] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13611 + (_20752 * 4u)) + _20753) * 4 + 0));
                                    _20753++;
                                    continue;
                                }
                            }
                            _20755 = true;
                            break;
                        } while(false);
                        if (_20755)
                        {
                            _20756 = _13577;
                            break;
                        }
                        _20756 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20772 = _20756;
                }
                float2 _20773;
                do
                {
                    float _13688 = _6639.x;
                    float _13691 = 1.0f - _6639.y;
                    float4 _13702 = mul(float4((float2(_13688, _13691) * 2.0f) - 1.0f.xx, _20765, 1.0f), _20772);
                    float _13704 = _13702.w;
                    if (!(_13704 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20773 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13717 = ((_13702.xy / _13704.xx) + 1.0f.xx) * 0.5f;
                    _20773 = float2(_13717.x - _13688, _13691 - _13717.y);
                    break;
                } while(false);
                float2 _6669 = float2(cbFI_DisplaySize);
                float4 _20885;
                if (!(length(((_6639 + _20773) - float2(_6638.x ? _19744.x : _19742.x, _6638.y ? _19744.y : _19742.y)) * _6669) <= ((0.100000001490116119384765625f * length(_20773 * _6669)) + 8.0f)))
                {
                    float4 _20886;
                    if (_6365)
                    {
                        float4 _19499 = _20781;
                        _19499.x = 0.0f;
                        _20886 = _19499;
                    }
                    else
                    {
                        float4 _19501 = _20781;
                        _19501.y = 0.0f;
                        _20886 = _19501;
                    }
                    _20885 = _20886;
                }
                else
                {
                    _20885 = _20781;
                }
                _20884 = _20885;
            }
            else
            {
                _20884 = _20781;
            }
            float4 _6694 = _20495 * _20884;
            float _6696 = dot(_6694, 1.0f.xxxx);
            float4 _21226;
            bool _21532;
            if (_6696 > 0.0f)
            {
                _21532 = _20186;
                _21226 = _6694 / _6696.xxxx;
            }
            else
            {
                bool _6707 = any(bool4(_20884.x < 1.0f.xxxx.x, _20884.y < 1.0f.xxxx.y, _20884.z < 1.0f.xxxx.z, _20884.w < 1.0f.xxxx.w));
                if (_6707)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13739;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13739);
                    }
                }
                bool4 _23645 = _6707.xxxx;
                _21532 = _6707 ? true : _20186;
                _21226 = float4(_23645.x ? 0.0f.xxxx.x : _20495.x, _23645.y ? 0.0f.xxxx.y : _20495.y, _23645.z ? 0.0f.xxxx.z : _20495.z, _23645.w ? 0.0f.xxxx.w : _20495.w);
            }
            _21721 = _21830;
            _21531 = _21532;
            _21225 = _21226;
        }
        else
        {
            _21721 = float3(0.0f, 0.0f, 0.5f);
            _21531 = _20186;
            _21225 = _20495;
        }
        uint _6716 = (cbFI_pad0 >> 24u) & 31u;
        uint _6720 = (cbFI_pad0 >> 16u) & 255u;
        bool _6722 = _6716 != 0u;
        bool _6724 = _6720 == 12u;
        bool _6727 = _6720 == 13u;
        float4 _21246;
        if ((_6722 || _6724) || _6727)
        {
            float _20892;
            do
            {
                bool _13823 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _13829;
                if (_13823)
                {
                    _13829 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _13829 = _13823;
                }
                bool _13760 = !_13829;
                bool _13767;
                if (!_13760)
                {
                    bool _13834 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
                    bool _13840;
                    if (_13834)
                    {
                        _13840 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13840 = _13834;
                    }
                    _13767 = !_13840;
                }
                else
                {
                    _13767 = _13760;
                }
                if (_13767)
                {
                    _20892 = 0.0f;
                    break;
                }
                uint _13847_dummy_parameter;
                uint _13863_dummy_parameter;
                float4x4 _20891;
                do
                {
                    float4x4 _13877;
                    bool _20890;
                    do
                    {
                        _13877 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20890 = false;
                            break;
                        }
                        uint _13911 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13911 + 32u) * 4 + 0) != 1u)
                        {
                            _20890 = false;
                            break;
                        }
                        uint _20887;
                        _20887 = 0u;
                        for (; _20887 < 4u; _20887++)
                        {
                            for (uint _20888 = 0u; _20888 < 4u; )
                            {
                                _13877[_20887][_20888] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13911 + 16u) + (_20887 * 4u)) + _20888) * 4 + 0));
                                _20888++;
                                continue;
                            }
                        }
                        _20890 = true;
                        break;
                    } while(false);
                    if (_20890)
                    {
                        _20891 = _13877;
                        break;
                    }
                    _20891 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13788 = mul(float4((float2(_19745.x, 1.0f - _19745.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13847_dummy_parameter))))), 0)).x, 1.0f), _20891);
                float _13790 = _13788.w;
                if (abs(_13790) < 9.9999999747524270787835121154785e-07f)
                {
                    _20892 = 0.0f;
                    break;
                }
                float _13801 = abs(cbFI_DeviceToViewDepth.y / ((_13788.z / _13790) - cbFI_DeviceToViewDepth.x));
                float _13804 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13863_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20892 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13801 - _13804) / max(max(_13801, _13804), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14013 = all(bool2(_19746.x > 0.0f.xx.x, _19746.y > 0.0f.xx.y));
            bool _14019;
            if (_14013)
            {
                _14019 = all(bool2(_19746.x < 1.0f.xx.x, _19746.y < 1.0f.xx.y));
            }
            else
            {
                _14019 = _14013;
            }
            float _20893;
            if (_14019)
            {
                uint _14026_dummy_parameter;
                _20893 = length((_7847 + (r_motion_tp1.Load(int3(int2(floor(_19746 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14026_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20893 = 1000000.0f;
            }
            float _20908;
            if ((_6716 & 1u) != 0u)
            {
                _20908 = _20892;
            }
            else
            {
                _20908 = 1.0f;
            }
            float _20909;
            if ((_6716 & 2u) != 0u)
            {
                _20909 = _20908 * (1.0f - smoothstep(2.0f, 8.0f, _20893));
            }
            else
            {
                _20909 = _20908;
            }
            float _20910;
            if ((_6716 & 4u) != 0u)
            {
                _20910 = _20909 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8568 - _8576) - length(_8552 - _8560))));
            }
            else
            {
                _20910 = _20909;
            }
            float _21240;
            if ((_6716 & 8u) != 0u)
            {
                _21240 = lerp(1.0f, _20910, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8552 - _8560)));
            }
            else
            {
                _21240 = _20910;
            }
            bool _6802 = (_6716 & 16u) != 0u;
            bool _6811;
            if (_6802)
            {
                _6811 = length(_19740 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6811 = _6802;
            }
            float _23647 = _6811 ? 1.0f : _21240;
            bool _6817 = _6722 && _10949;
            bool _6822;
            if (_6817)
            {
                bool _14051 = all(bool2(_19742.x > 0.0f.xx.x, _19742.y > 0.0f.xx.y));
                bool _14057;
                if (_14051)
                {
                    _14057 = all(bool2(_19742.x < 1.0f.xx.x, _19742.y < 1.0f.xx.y));
                }
                else
                {
                    _14057 = _14051;
                }
                _6822 = _14057;
            }
            else
            {
                _6822 = _6817;
            }
            bool _6827;
            if (_6822)
            {
                bool _14062 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _14068;
                if (_14062)
                {
                    _14068 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _14068 = _14062;
                }
                _6827 = _14068;
            }
            else
            {
                _6827 = _6822;
            }
            float4 _21247;
            if (_6827)
            {
                float _6833 = _21225.x + _21225.y;
                float _6842 = (_21225.z + _21225.w) * (1.0f - _23647);
                float _21243;
                if (_6833 > 9.9999997473787516355514526367188e-06f)
                {
                    _21243 = _21225.x / _6833;
                }
                else
                {
                    _21243 = _5572;
                }
                _21247 = float4(_21225.x + (_6842 * _21243), _21225.y + (_6842 * (1.0f - _21243)), _21225.zw * _23647);
            }
            else
            {
                _21247 = _21225;
            }
            _21246 = _21247;
        }
        else
        {
            _21246 = _21225;
        }
        float3 _6903 = (((_8552 * _21246.x) + (_8560 * _21246.y)) + (_8568 * _21246.z)) + (_8576 * _21246.w);
        float3 _22846;
        if (_5588 && (_21261 > 0.0f))
        {
            uint _14075_dummy_parameter;
            float2 _14090 = r_motion_tp1.Load(int3(int2(floor(_5347 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14075_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21523;
            if (_7875)
            {
                float2 _14135 = clamp((((_19719 + (_14090 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14138 = tan(_14135.x);
                _21523 = (float2(_14138 / cbFI_DeviceToViewDepth.z, (tan(_14135.y) * sqrt(1.0f + (_14138 * _14138))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21523 = _19719 + (_14090 * cbFI_Timestep);
            }
            float2 _21524;
            if (_7875)
            {
                float2 _14214 = clamp((((_19719 + (_14090 * _5562)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14217 = tan(_14214.x);
                _21524 = (float2(_14217 / cbFI_DeviceToViewDepth.z, (tan(_14214.y) * sqrt(1.0f + (_14217 * _14217))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21524 = _19719 + (_14090 * _5562);
            }
            _22846 = lerp(_6903, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21523, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21524, 0.0f).xyz, cbFI_Timestep.xxx), _21261.xxx);
        }
        else
        {
            _22846 = _6903;
        }
        float3 _22845;
        if (_21531)
        {
            float3 _14259 = r_current_interpolation_source.Load(int3(_4848, 0)).xyz;
            float3 _22847;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10949)
            {
                uint _14266_dummy_parameter;
                float _21654;
                _21654 = r_depth_tm1.Load(int3(int2(floor(_19742 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14266_dummy_parameter))))), 0)).x;
                float _6984;
                for (int _21653 = 0; _21653 < 24; _21654 = _6984, _21653++)
                {
                    float _6956 = float(_21653 & 7) * 0.785398185253143310546875f;
                    int _6958 = _21653 >> 3;
                    int _23114;
                    if (_6958 == 0)
                    {
                        _23114 = 16;
                    }
                    else
                    {
                        _23114 = (_6958 == 1) ? 48 : 96;
                    }
                    uint _14286_dummy_parameter;
                    _6984 = min(_21654, r_depth_tm1.Load(int3(int2(floor(clamp(_19742 + ((cbFI_MvDepthLaneSizeRcp * float(_23114)) * float2(cos(_6956), sin(_6956))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14286_dummy_parameter))))), 0)).x);
                }
                float2 _21655;
                do
                {
                    float _14308 = 1.0f - _19742.y;
                    float4 _14319 = mul(float4((float2(_19742.x, _14308) * 2.0f) - 1.0f.xx, _21654, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14321 = _14319.w;
                    if (!(_14321 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21655 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14334 = ((_14319.xy / _14321.xx) + 1.0f.xx) * 0.5f;
                    _21655 = float2(_14334.x - _19742.x, _14308 - _14334.y);
                    break;
                } while(false);
                float2 _6995 = _19742 + _21655;
                bool _14352 = all(bool2(_6995.x > 0.0f.xx.x, _6995.y > 0.0f.xx.y));
                bool _14358;
                if (_14352)
                {
                    _14358 = all(bool2(_6995.x < 1.0f.xx.x, _6995.y < 1.0f.xx.y));
                }
                else
                {
                    _14358 = _14352;
                }
                float3 _22848;
                if (_14358)
                {
                    float _7001 = abs(cbFI_DeviceToViewDepth.y / (_21654 - cbFI_DeviceToViewDepth.x));
                    uint _14378_dummy_parameter;
                    int2 _14378 = int2(spvTextureSize(r_depth_m2, uint(0), _14378_dummy_parameter));
                    float _7005 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6995 * float2(_14378))), int2(0, 0), _14378 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22853;
                    if (abs(_7005 - _7001) <= (0.20000000298023223876953125f * max(_7005, _7001)))
                    {
                        uint _14412_dummy_parameter;
                        int2 _14412 = int2(spvTextureSize(r_colour_m2, uint(0), _14412_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14435;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14435);
                        }
                        _22853 = r_colour_m2.Load(int3(clamp(int2(floor(_6995 * float2(_14412))), int2(0, 0), _14412 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14445;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14445);
                        }
                        _22853 = _14259;
                    }
                    _22848 = _22853;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14455;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14455);
                    }
                    _22848 = _14259;
                }
                _22847 = _22848;
            }
            else
            {
                _22847 = _14259;
            }
            _22845 = _22847;
        }
        else
        {
            _22845 = _22846;
        }
        bool _7030 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22844;
        float _22920;
        if (_7030)
        {
            float _14632;
            float2 _7034 = float2(cbFI_DisplaySize);
            float3 _21712;
            do
            {
                bool _14693;
                float4x4 _21662;
                do
                {
                    float4x4 _14669;
                    bool _21661;
                    do
                    {
                        _14669 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14693 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14693)
                        {
                            _21661 = false;
                            break;
                        }
                        uint _14703 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14703 + 32u) * 4 + 0) != 1u)
                        {
                            _21661 = false;
                            break;
                        }
                        uint _21658;
                        _21658 = 0u;
                        for (; _21658 < 4u; _21658++)
                        {
                            for (uint _21659 = 0u; _21659 < 4u; )
                            {
                                _14669[_21658][_21659] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14703 + (_21658 * 4u)) + _21659) * 4 + 0));
                                _21659++;
                                continue;
                            }
                        }
                        _21661 = true;
                        break;
                    } while(false);
                    if (_21661)
                    {
                        _21662 = _14669;
                        break;
                    }
                    _21662 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14780;
                float _14783;
                float4 _14793;
                float2 _21663;
                do
                {
                    _14780 = _5347.x;
                    _14783 = 1.0f - _5347.y;
                    _14793 = float4((float2(_14780, _14783) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _14794 = mul(_14793, _21662);
                    float _14796 = _14794.w;
                    if (!(_14796 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21663 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14809 = ((_14794.xy / _14796.xx) + 1.0f.xx) * 0.5f;
                    _21663 = float2(_14809.x - _14780, _14783 - _14809.y);
                    break;
                } while(false);
                float4x4 _21668;
                do
                {
                    float4x4 _14827;
                    bool _21667;
                    do
                    {
                        _14827 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14693)
                        {
                            _21667 = false;
                            break;
                        }
                        uint _14861 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14861 + 32u) * 4 + 0) != 1u)
                        {
                            _21667 = false;
                            break;
                        }
                        uint _21664;
                        _21664 = 0u;
                        for (; _21664 < 4u; _21664++)
                        {
                            for (uint _21665 = 0u; _21665 < 4u; )
                            {
                                _14827[_21664][_21665] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14861 + 16u) + (_21664 * 4u)) + _21665) * 4 + 0));
                                _21665++;
                                continue;
                            }
                        }
                        _21667 = true;
                        break;
                    } while(false);
                    if (_21667)
                    {
                        _21668 = _14827;
                        break;
                    }
                    _21668 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21669;
                do
                {
                    float4 _14952 = mul(_14793, _21668);
                    float _14954 = _14952.w;
                    if (!(_14954 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21669 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14967 = ((_14952.xy / _14954.xx) + 1.0f.xx) * 0.5f;
                    _21669 = float2(_14967.x - _14780, _14783 - _14967.y);
                    break;
                } while(false);
                float2 _14510 = abs(_21663);
                bool2 _23648 = any(bool2(_14510.x > 4.0f.xx.x, _14510.y > 4.0f.xx.y)).xx;
                float2 _14516 = abs(_21669);
                bool2 _23650 = any(bool2(_14516.x > 4.0f.xx.x, _14516.y > 4.0f.xx.y)).xx;
                float2 _14981[3];
                _14981[0] = _5347;
                float2 _15097 = clamp(_5347, 0.0f.xx, 1.0f.xx);
                uint _15105_dummy_parameter;
                _14981[1] = _5347 - ((r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15105_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572);
                _14981[2] = _5347 - (float2(_23648.x ? 0.0f.xx.x : _21663.x, _23648.y ? 0.0f.xx.y : _21663.y) * _5572);
                float _21679;
                float2 _21680;
                _21680 = _5347;
                _21679 = 1000000000.0f;
                float _23652;
                float2 _23654;
                float _23655;
                int _21678 = 0;
                float _23106 = -1.0f;
                for (; _21678 < 3; _23106 = _23652, _21680 = _23654, _21679 = _23655, _21678++)
                {
                    float2 _23096;
                    _23096 = _14981[_21678];
                    for (int _23095 = 0; _23095 < 30; )
                    {
                        uint _15721_dummy_parameter;
                        _23096 += (((_5347 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23096, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15721_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572)) - _23096) * 0.699999988079071044921875f);
                        _23095++;
                        continue;
                    }
                    float2 _16257 = clamp(_23096, 0.0f.xx, 1.0f.xx);
                    uint _16265_dummy_parameter;
                    bool _16801 = all(bool2(_23096.x > 0.0f.xx.x, _23096.y > 0.0f.xx.y));
                    bool _16807;
                    if (_16801)
                    {
                        _16807 = all(bool2(_23096.x < 1.0f.xx.x, _23096.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16807 = _16801;
                    }
                    float _23098;
                    if (_16807)
                    {
                        _23098 = length(((_23096 + ((r_motion_tp1.Load(int3(int2(floor(_16257 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16265_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572)) - _5347) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23098 = 1000000000.0f;
                    }
                    uint _16818_dummy_parameter;
                    float _16858 = log((r_depth_tp1.Load(int3(int2(floor(_16257 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16818_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15057 = _23098 < 0.3499999940395355224609375f;
                    bool _15059 = _21679 < 0.3499999940395355224609375f;
                    bool _15069;
                    if (_15057)
                    {
                        _15069 = (!_15059) || (_16858 > _23106);
                    }
                    else
                    {
                        _15069 = _15057;
                    }
                    bool _15082;
                    if (!_15069)
                    {
                        _15082 = ((!_15057) && (!_15059)) && (_23098 < _21679);
                    }
                    else
                    {
                        _15082 = _15069;
                    }
                    _23652 = _15082 ? _16858 : _23106;
                    bool2 _23653 = _15082.xx;
                    _23654 = float2(_23653.x ? _23096.x : _21680.x, _23653.y ? _23096.y : _21680.y);
                    _23655 = _15082 ? _23098 : _21679;
                }
                float2 _16860[3];
                _16860[0] = _5347;
                float2 _21708;
                do
                {
                    bool _21689;
                    do
                    {
                        bool _17103 = all(bool2(_15097.x > 0.0f.xx.x, _15097.y > 0.0f.xx.y));
                        bool _17109;
                        if (_17103)
                        {
                            _17109 = all(bool2(_15097.x < 1.0f.xx.x, _15097.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17109 = _17103;
                        }
                        if (!_17109)
                        {
                            _21689 = false;
                            break;
                        }
                        uint _17116_dummy_parameter;
                        float4x4 _21687;
                        do
                        {
                            float4x4 _17130;
                            bool _21686;
                            do
                            {
                                _17130 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14693)
                                {
                                    _21686 = false;
                                    break;
                                }
                                uint _17164 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17164 + 32u) * 4 + 0) != 1u)
                                {
                                    _21686 = false;
                                    break;
                                }
                                uint _21683;
                                _21683 = 0u;
                                for (; _21683 < 4u; _21683++)
                                {
                                    for (uint _21684 = 0u; _21684 < 4u; )
                                    {
                                        _17130[_21683][_21684] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17164 + (_21683 * 4u)) + _21684) * 4 + 0));
                                        _21684++;
                                        continue;
                                    }
                                }
                                _21686 = true;
                                break;
                            } while(false);
                            if (_21686)
                            {
                                _21687 = _17130;
                                break;
                            }
                            _21687 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21688;
                        do
                        {
                            float _17241 = _15097.x;
                            float _17244 = 1.0f - _15097.y;
                            float4 _17255 = mul(float4((float2(_17241, _17244) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17116_dummy_parameter))))), 0)).x, 1.0f), _21687);
                            float _17257 = _17255.w;
                            if (!(_17257 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21688 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17270 = ((_17255.xy / _17257.xx) + 1.0f.xx) * 0.5f;
                            _21688 = float2(_17270.x - _17241, _17244 - _17270.y);
                            break;
                        } while(false);
                        float2 _17067 = abs(_21688);
                        if (any(bool2(_17067.x > 100000.0f.xx.x, _17067.y > 100000.0f.xx.y)))
                        {
                            _21689 = false;
                            break;
                        }
                        float _17075 = length(_21688 * _7034);
                        uint _17290_dummy_parameter;
                        bool _17089 = _17075 > ((8.0f * _7034.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17096;
                        if (_17089)
                        {
                            _17096 = length((r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17290_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7034) < (0.20000000298023223876953125f * _17075);
                        }
                        else
                        {
                            _17096 = _17089;
                        }
                        _21689 = _17096;
                        break;
                    } while(false);
                    if (_21689)
                    {
                        uint _17321_dummy_parameter;
                        _21708 = -(r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17321_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17348_dummy_parameter;
                    float4x4 _21702;
                    do
                    {
                        float4x4 _17362;
                        bool _21701;
                        do
                        {
                            _17362 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14693)
                            {
                                _21701 = false;
                                break;
                            }
                            uint _17396 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17396 + 32u) * 4 + 0) != 1u)
                            {
                                _21701 = false;
                                break;
                            }
                            uint _21698;
                            _21698 = 0u;
                            for (; _21698 < 4u; _21698++)
                            {
                                for (uint _21699 = 0u; _21699 < 4u; )
                                {
                                    _17362[_21698][_21699] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17396 + 16u) + (_21698 * 4u)) + _21699) * 4 + 0));
                                    _21699++;
                                    continue;
                                }
                            }
                            _21701 = true;
                            break;
                        } while(false);
                        if (_21701)
                        {
                            _21702 = _17362;
                            break;
                        }
                        _21702 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _21707;
                    do
                    {
                        float _17473 = _15097.x;
                        float _17476 = 1.0f - _15097.y;
                        float4 _17487 = mul(float4((float2(_17473, _17476) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17348_dummy_parameter))))), 0)).x, 1.0f), _21702);
                        float _17489 = _17487.w;
                        if (!(_17489 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21707 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17502 = ((_17487.xy / _17489.xx) + 1.0f.xx) * 0.5f;
                        _21707 = float2(_17502.x - _17473, _17476 - _17502.y);
                        break;
                    } while(false);
                    float2 _17034 = abs(_21707);
                    bool2 _17038 = any(bool2(_17034.x > 4.0f.xx.x, _17034.y > 4.0f.xx.y)).xx;
                    _21708 = float2(_17038.x ? 0.0f.xx.x : _21707.x, _17038.y ? 0.0f.xx.y : _21707.y);
                    break;
                } while(false);
                _16860[1] = _5347 - (_21708 * cbFI_Timestep);
                _16860[2] = _5347 - (float2(_23650.x ? 0.0f.xx.x : _21669.x, _23650.y ? 0.0f.xx.y : _21669.y) * cbFI_Timestep);
                float _21710;
                float2 _21711;
                _21711 = _5347;
                _21710 = 1000000000.0f;
                float _23656;
                float2 _23658;
                float _23659;
                float4x4 _17746;
                float4x4 _17978;
                float4x4 _18290;
                float4x4 _18522;
                int _21709 = 0;
                float _23008 = -1.0f;
                for (; _21709 < 3; _23008 = _23656, _21711 = _23658, _21710 = _23659, _21709++)
                {
                    float2 _22941;
                    _22941 = _16860[_21709];
                    float2 _17556;
                    for (int _22940 = 0; _22940 < 30; _22941 = _17556, _22940++)
                    {
                        float2 _23066;
                        do
                        {
                            float2 _17635 = clamp(_22941, 0.0f.xx, 1.0f.xx);
                            bool _23047;
                            do
                            {
                                bool _17719 = all(bool2(_17635.x > 0.0f.xx.x, _17635.y > 0.0f.xx.y));
                                bool _17725;
                                if (_17719)
                                {
                                    _17725 = all(bool2(_17635.x < 1.0f.xx.x, _17635.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17725 = _17719;
                                }
                                if (!_17725)
                                {
                                    _23047 = false;
                                    break;
                                }
                                uint _17732_dummy_parameter;
                                float4x4 _23045;
                                do
                                {
                                    bool _23044;
                                    do
                                    {
                                        _17746 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14693)
                                        {
                                            _23044 = false;
                                            break;
                                        }
                                        uint _17780 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17780 + 32u) * 4 + 0) != 1u)
                                        {
                                            _23044 = false;
                                            break;
                                        }
                                        uint _23041;
                                        _23041 = 0u;
                                        for (; _23041 < 4u; _23041++)
                                        {
                                            for (uint _23042 = 0u; _23042 < 4u; )
                                            {
                                                _17746[_23041][_23042] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17780 + (_23041 * 4u)) + _23042) * 4 + 0));
                                                _23042++;
                                                continue;
                                            }
                                        }
                                        _23044 = true;
                                        break;
                                    } while(false);
                                    if (_23044)
                                    {
                                        _23045 = _17746;
                                        break;
                                    }
                                    _23045 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _23046;
                                do
                                {
                                    float _17857 = _17635.x;
                                    float _17860 = 1.0f - _17635.y;
                                    float4 _17871 = mul(float4((float2(_17857, _17860) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17635 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17732_dummy_parameter))))), 0)).x, 1.0f), _23045);
                                    float _17873 = _17871.w;
                                    if (!(_17873 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _23046 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17886 = ((_17871.xy / _17873.xx) + 1.0f.xx) * 0.5f;
                                    _23046 = float2(_17886.x - _17857, _17860 - _17886.y);
                                    break;
                                } while(false);
                                float2 _17683 = abs(_23046);
                                if (any(bool2(_17683.x > 100000.0f.xx.x, _17683.y > 100000.0f.xx.y)))
                                {
                                    _23047 = false;
                                    break;
                                }
                                float _17691 = length(_23046 * _7034);
                                uint _17906_dummy_parameter;
                                bool _17705 = _17691 > ((8.0f * _7034.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17712;
                                if (_17705)
                                {
                                    _17712 = length((r_motion_tp1.Load(int3(int2(floor(_17635 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17906_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7034) < (0.20000000298023223876953125f * _17691);
                                }
                                else
                                {
                                    _17712 = _17705;
                                }
                                _23047 = _17712;
                                break;
                            } while(false);
                            if (_23047)
                            {
                                uint _17937_dummy_parameter;
                                _23066 = -(r_motion_tp1.Load(int3(int2(floor(_17635 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17937_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17964_dummy_parameter;
                            float4x4 _23060;
                            do
                            {
                                bool _23059;
                                do
                                {
                                    _17978 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14693)
                                    {
                                        _23059 = false;
                                        break;
                                    }
                                    uint _18012 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18012 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23059 = false;
                                        break;
                                    }
                                    uint _23056;
                                    _23056 = 0u;
                                    for (; _23056 < 4u; _23056++)
                                    {
                                        for (uint _23057 = 0u; _23057 < 4u; )
                                        {
                                            _17978[_23056][_23057] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18012 + 16u) + (_23056 * 4u)) + _23057) * 4 + 0));
                                            _23057++;
                                            continue;
                                        }
                                    }
                                    _23059 = true;
                                    break;
                                } while(false);
                                if (_23059)
                                {
                                    _23060 = _17978;
                                    break;
                                }
                                _23060 = cbFI_MotionTM1ToTP1;
                                break;
                            } while(false);
                            float2 _23065;
                            do
                            {
                                float _18089 = _17635.x;
                                float _18092 = 1.0f - _17635.y;
                                float4 _18103 = mul(float4((float2(_18089, _18092) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17635 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17964_dummy_parameter))))), 0)).x, 1.0f), _23060);
                                float _18105 = _18103.w;
                                if (!(_18105 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23065 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18118 = ((_18103.xy / _18105.xx) + 1.0f.xx) * 0.5f;
                                _23065 = float2(_18118.x - _18089, _18092 - _18118.y);
                                break;
                            } while(false);
                            float2 _17650 = abs(_23065);
                            bool2 _17654 = any(bool2(_17650.x > 4.0f.xx.x, _17650.y > 4.0f.xx.y)).xx;
                            _23066 = float2(_17654.x ? 0.0f.xx.x : _23065.x, _17654.y ? 0.0f.xx.y : _23065.y);
                            break;
                        } while(false);
                        _17556 = _22941 + (((_5347 - (_23066 * cbFI_Timestep)) - _22941) * 0.699999988079071044921875f);
                    }
                    float2 _18179;
                    float2 _22967;
                    do
                    {
                        _18179 = clamp(_22941, 0.0f.xx, 1.0f.xx);
                        bool _22948;
                        do
                        {
                            bool _18263 = all(bool2(_18179.x > 0.0f.xx.x, _18179.y > 0.0f.xx.y));
                            bool _18269;
                            if (_18263)
                            {
                                _18269 = all(bool2(_18179.x < 1.0f.xx.x, _18179.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18269 = _18263;
                            }
                            if (!_18269)
                            {
                                _22948 = false;
                                break;
                            }
                            uint _18276_dummy_parameter;
                            float4x4 _22946;
                            do
                            {
                                bool _22945;
                                do
                                {
                                    _18290 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14693)
                                    {
                                        _22945 = false;
                                        break;
                                    }
                                    uint _18324 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18324 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22945 = false;
                                        break;
                                    }
                                    uint _22942;
                                    _22942 = 0u;
                                    for (; _22942 < 4u; _22942++)
                                    {
                                        for (uint _22943 = 0u; _22943 < 4u; )
                                        {
                                            _18290[_22942][_22943] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18324 + (_22942 * 4u)) + _22943) * 4 + 0));
                                            _22943++;
                                            continue;
                                        }
                                    }
                                    _22945 = true;
                                    break;
                                } while(false);
                                if (_22945)
                                {
                                    _22946 = _18290;
                                    break;
                                }
                                _22946 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22947;
                            do
                            {
                                float _18404 = 1.0f - _18179.y;
                                float4 _18415 = mul(float4((float2(_18179.x, _18404) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18179 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18276_dummy_parameter))))), 0)).x, 1.0f), _22946);
                                float _18417 = _18415.w;
                                if (!(_18417 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22947 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18430 = ((_18415.xy / _18417.xx) + 1.0f.xx) * 0.5f;
                                _22947 = float2(_18430.x - _18179.x, _18404 - _18430.y);
                                break;
                            } while(false);
                            float2 _18227 = abs(_22947);
                            if (any(bool2(_18227.x > 100000.0f.xx.x, _18227.y > 100000.0f.xx.y)))
                            {
                                _22948 = false;
                                break;
                            }
                            float _18235 = length(_22947 * _7034);
                            uint _18450_dummy_parameter;
                            bool _18249 = _18235 > ((8.0f * _7034.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18256;
                            if (_18249)
                            {
                                _18256 = length((r_motion_tp1.Load(int3(int2(floor(_18179 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18450_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7034) < (0.20000000298023223876953125f * _18235);
                            }
                            else
                            {
                                _18256 = _18249;
                            }
                            _22948 = _18256;
                            break;
                        } while(false);
                        if (_22948)
                        {
                            uint _18481_dummy_parameter;
                            _22967 = -(r_motion_tp1.Load(int3(int2(floor(_18179 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18481_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18508_dummy_parameter;
                        float4x4 _22961;
                        do
                        {
                            bool _22960;
                            do
                            {
                                _18522 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14693)
                                {
                                    _22960 = false;
                                    break;
                                }
                                uint _18556 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18556 + 32u) * 4 + 0) != 1u)
                                {
                                    _22960 = false;
                                    break;
                                }
                                uint _22957;
                                _22957 = 0u;
                                for (; _22957 < 4u; _22957++)
                                {
                                    for (uint _22958 = 0u; _22958 < 4u; )
                                    {
                                        _18522[_22957][_22958] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18556 + 16u) + (_22957 * 4u)) + _22958) * 4 + 0));
                                        _22958++;
                                        continue;
                                    }
                                }
                                _22960 = true;
                                break;
                            } while(false);
                            if (_22960)
                            {
                                _22961 = _18522;
                                break;
                            }
                            _22961 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _22966;
                        do
                        {
                            float _18636 = 1.0f - _18179.y;
                            float4 _18647 = mul(float4((float2(_18179.x, _18636) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18179 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18508_dummy_parameter))))), 0)).x, 1.0f), _22961);
                            float _18649 = _18647.w;
                            if (!(_18649 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22966 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18662 = ((_18647.xy / _18649.xx) + 1.0f.xx) * 0.5f;
                            _22966 = float2(_18662.x - _18179.x, _18636 - _18662.y);
                            break;
                        } while(false);
                        float2 _18194 = abs(_22966);
                        bool2 _18198 = any(bool2(_18194.x > 4.0f.xx.x, _18194.y > 4.0f.xx.y)).xx;
                        _22967 = float2(_18198.x ? 0.0f.xx.x : _22966.x, _18198.y ? 0.0f.xx.y : _22966.y);
                        break;
                    } while(false);
                    bool _18680 = all(bool2(_22941.x > 0.0f.xx.x, _22941.y > 0.0f.xx.y));
                    bool _18686;
                    if (_18680)
                    {
                        _18686 = all(bool2(_22941.x < 1.0f.xx.x, _22941.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18686 = _18680;
                    }
                    float _22983;
                    if (_18686)
                    {
                        _22983 = length(((_22941 + (_22967 * cbFI_Timestep)) - _5347) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22983 = 1000000000.0f;
                    }
                    uint _18713_dummy_parameter;
                    float _18737 = log((r_depth_tm1.Load(int3(int2(floor(_18179 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18713_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16936 = _22983 < 0.3499999940395355224609375f;
                    bool _16938 = _21710 < 0.3499999940395355224609375f;
                    bool _16948;
                    if (_16936)
                    {
                        _16948 = (!_16938) || (_18737 > _23008);
                    }
                    else
                    {
                        _16948 = _16936;
                    }
                    bool _16961;
                    if (!_16948)
                    {
                        _16961 = ((!_16936) && (!_16938)) && (_22983 < _21710);
                    }
                    else
                    {
                        _16961 = _16948;
                    }
                    _23656 = _16961 ? _18737 : _23008;
                    bool2 _23657 = _16961.xx;
                    _23658 = float2(_23657.x ? _22941.x : _21711.x, _23657.y ? _22941.y : _21711.y);
                    _23659 = _16961 ? _22983 : _21710;
                }
                float3 _18746 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21680, 0.0f).xyz;
                float3 _18754 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21711, 0.0f).xyz;
                uint _18761_dummy_parameter;
                uint _18792_dummy_parameter;
                float _14554 = exp((_21679 * (-2.0f)) * (_21679 * 2.0f));
                float _14561 = exp((_21710 * (-2.0f)) * (_21710 * 2.0f));
                float _14574 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21711, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18792_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21680, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18761_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14588 = ((_14554 * cbFI_Timestep) * ((1.0f - _14561) + ((_14561 * 2.0f) * _14574))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14598 = 1.0f - _14574;
                float _14605 = ((_14561 * _5572) * ((1.0f - _14554) + ((_14554 * 2.0f) * _14598))) + (9.9999997473787516355514526367188e-05f * _5572);
                float _14614 = (((_14554 * _14561) * 4.0f) * _14574) * _14598;
                _14632 = (_14614 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18754 - _18746, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14614)) * max(_14554, _14561));
                if (_6720 == 30u)
                {
                    _21712 = _18746;
                    break;
                }
                if (_6720 == 31u)
                {
                    _21712 = _18754;
                    break;
                }
                if (_6720 == 32u)
                {
                    _21712 = float3(_14554, _14561, _14574);
                    break;
                }
                _21712 = ((_18746 * _14588) + (_18754 * _14605)) / (_14588 + _14605).xxx;
                break;
            } while(false);
            _22920 = _14632;
            _22844 = _21712;
        }
        else
        {
            _22920 = 1.0f;
            _22844 = _22845;
        }
        uint _7050 = cbFI_pad0 & 255u;
        bool _22688;
        float3 _22843;
        if (_7050 != 0u)
        {
            float3 _7055 = r_present_backbuffer.Load(int3(_4848, 0)).xyz;
            float3 _7059 = r_current_interpolation_source.Load(int3(_4848, 0)).xyz;
            float3 _7063 = abs(_7055 - _7059);
            float3 _21713;
            if (_7050 == 2u)
            {
                _21713 = (abs(_7059) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21713 = 0.000244140625f.xxx;
            }
            bool _7079 = any(bool3(_7063.x > _21713.x, _7063.y > _21713.y, _7063.z > _21713.z));
            bool3 _23660 = _7079.xxx;
            _22843 = float3(_23660.x ? _7055.x : _22844.x, _23660.y ? _7055.y : _22844.y, _23660.z ? _7055.z : _22844.z);
            _22688 = _7079;
        }
        else
        {
            _22843 = _22844;
            _22688 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18830;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18830);
        }
        float3 _22825;
        if (_6720 == 1u)
        {
            _22825 = lerp(_8552, _8560, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22826;
            if (_6720 == 2u)
            {
                _22826 = lerp(_8568, _8576, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22827;
                if (_6720 == 3u)
                {
                    _22827 = float(_22688).xxx;
                }
                else
                {
                    float3 _22828;
                    if (_6720 == 4u)
                    {
                        _22828 = float3(((_19740 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22829;
                        if (_6720 == 5u)
                        {
                            _22829 = float3(((_7847 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22830;
                            if (_6720 == 6u)
                            {
                                _22830 = float3(_21246.xy, _21246.z + _21246.w);
                            }
                            else
                            {
                                float3 _22831;
                                if (_6720 == 7u)
                                {
                                    _22831 = r_current_interpolation_source.Load(int3(_4848, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22832;
                                    if (_6720 == 8u)
                                    {
                                        _22832 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5347, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22833;
                                        if (_6724)
                                        {
                                            uint _18852_dummy_parameter;
                                            uint _18884_dummy_parameter;
                                            _22833 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5347 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18852_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5347 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18884_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22834;
                                            if (_6727)
                                            {
                                                _22834 = _8568;
                                            }
                                            else
                                            {
                                                float3 _22835;
                                                if (_6720 == 20u)
                                                {
                                                    _22835 = _8552;
                                                }
                                                else
                                                {
                                                    float3 _22836;
                                                    if (_6720 == 21u)
                                                    {
                                                        _22836 = _8560;
                                                    }
                                                    else
                                                    {
                                                        float3 _22837;
                                                        if (_6720 == 22u)
                                                        {
                                                            _22837 = _8576;
                                                        }
                                                        else
                                                        {
                                                            float3 _22838;
                                                            if (_6720 == 18u)
                                                            {
                                                                _22838 = _22247;
                                                            }
                                                            else
                                                            {
                                                                float3 _22839;
                                                                if (_6720 == 19u)
                                                                {
                                                                    _22839 = _21981;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22840;
                                                                    if (_6720 == 23u)
                                                                    {
                                                                        _22840 = _21721;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22841;
                                                                        if (_6720 == 24u)
                                                                        {
                                                                            uint _7223 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7228 = float(rw_nfru_diagnostics.Load<uint>((_7223 + 35u) * 4 + 0));
                                                                            float _21714;
                                                                            if (_7228 > 0.0f)
                                                                            {
                                                                                _21714 = float(rw_nfru_diagnostics.Load<uint>((_7223 + 34u) * 4 + 0)) / _7228;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21714 = 0.0f;
                                                                            }
                                                                            _22841 = float3(float(rw_nfru_diagnostics.Load<uint>((_7223 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7223 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21714);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22841 = _22843;
                                                                        }
                                                                        _22840 = _22841;
                                                                    }
                                                                    _22839 = _22840;
                                                                }
                                                                _22838 = _22839;
                                                            }
                                                            _22837 = _22838;
                                                        }
                                                        _22836 = _22837;
                                                    }
                                                    _22835 = _22836;
                                                }
                                                _22834 = _22835;
                                            }
                                            _22833 = _22834;
                                        }
                                        _22832 = _22833;
                                    }
                                    _22831 = _22832;
                                }
                                _22830 = _22831;
                            }
                            _22829 = _22830;
                        }
                        _22828 = _22829;
                    }
                    _22827 = _22828;
                }
                _22826 = _22827;
            }
            _22825 = _22826;
        }
        float3 _22824;
        if ((_6720 >= 9u) && (_6720 <= 11u))
        {
            uint _7288 = 64u + uint((_19963.y * cbFI_MvDepthLaneSize.x) + _19963.x);
            uint _7292 = rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) & 15u;
            float3 _22858;
            if (_6720 == 10u)
            {
                float3 _22823;
                if ((rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) & 32u) != 0u)
                {
                    _22823 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22822;
                    if ((rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) & 16u) != 0u)
                    {
                        _22822 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7313 = ((rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) & 64u) != 0u).xxx;
                        _22822 = float3(_7313.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7313.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7313.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22823 = _22822;
                }
                _22858 = _22823;
            }
            else
            {
                float3 _22859;
                if (_6720 == 11u)
                {
                    uint _7326 = (rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) >> 8u) & 15u;
                    uint _7329 = (rw_nfru_diagnostics.Load<uint>(_7288 * 4 + 0) >> 12u) & 15u;
                    float3 _22815;
                    if ((_7292 == 2u) || (_7292 == 3u))
                    {
                        _22815 = _4547[_7292];
                    }
                    else
                    {
                        bool _7341 = _7326 == 3u;
                        bool _7343 = _7329 == 3u;
                        float3 _22816;
                        if (_7341 && _7343)
                        {
                            _22816 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22817;
                            if (_7341)
                            {
                                _22817 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22818;
                                if (_7343)
                                {
                                    _22818 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22819;
                                    if ((_7326 == 4u) || (_7329 == 4u))
                                    {
                                        _22819 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22820;
                                        if ((_7326 == 1u) || (_7329 == 1u))
                                        {
                                            _22820 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23662 = (_7292 == 1u).xxx;
                                            _22820 = float3(_23662.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23662.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23662.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22819 = _22820;
                                    }
                                    _22818 = _22819;
                                }
                                _22817 = _22818;
                            }
                            _22816 = _22817;
                        }
                        _22815 = _22816;
                    }
                    _22859 = _22815;
                }
                else
                {
                    _22859 = _4547[min(_7292, 7u)];
                }
                _22858 = _22859;
            }
            _22824 = _22858;
        }
        else
        {
            _22824 = _22825;
        }
        float4 _22862;
        if ((_6720 >= 14u) && (_6720 <= 16u))
        {
            float2 _22860;
            if (_6720 == 14u)
            {
                uint _7399_dummy_parameter;
                uint _7405_dummy_parameter;
                _22860 = r_flow_tm1.Load(int3(clamp(int2(floor(_5347 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7399_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7405_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22861;
                if (_6720 == 16u)
                {
                    uint _18960 = r_warped_flow_qdata_tm1.Load(int3(_5363, 0)).x & 2147483647u;
                    uint _18992 = uint(max((int((_18960 >> 16u) & 15u) - 6), 0));
                    _22861 = ((float2(float((1 - (2 * int((_18960 >> 15u) & 1u))) * int(((_18960 >> uint(7)) & 127u) << _18992)), float((1 - (2 * int((_18960 >> 14u) & 1u))) * int((_18960 & 127u) << _18992))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22861 = _7847 * float2(cbFI_DisplaySize);
                }
                _22860 = _22861;
            }
            uint2 _7438 = uint2(clamp(round(_22860 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7440 = _7438.x;
            uint _7447 = _7438.y;
            _22862 = float4(float(_7440 & 255u), float((_7440 >> 8u) | ((_7447 & 15u) << 4u)), float(_7447 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22863;
            if (_6720 == 17u)
            {
                _22863 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5363, 0)).x != 0u), _5807, 0.0f, 1.0f);
            }
            else
            {
                _22863 = float4(_22824, 1.0f);
            }
            _22862 = _22863;
        }
        rw_output[_4848] = _22862.xyz;
        if (_7030)
        {
            uint _19037 = uint((_4848.y * cbFI_DisplaySize.x) + _4848.x) * 2u;
            rw_nfru_select.Store<uint>(_19037 * 4 + 0, spvPackHalf2x16(_22862.xy));
            rw_nfru_select.Store<uint>((_19037 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22862.z, (_22688 || (_6720 != 0u)) ? 2.0f : _22920)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7505 = ((uint(_4848.y) * uint(cbFI_DisplaySize.x)) + uint(_4848.x)) * 6u;
            uint _19063 = spvPackHalf2x16(clamp(_8551.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7505 * 4 + 0, (((_19063 & 32767u) >> 4u) | ((((_19063 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8551.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19098 = spvPackHalf2x16(clamp(_8559.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7505 + 1u) * 4 + 0, (((_19098 & 32767u) >> 4u) | ((((_19098 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8559.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19133 = spvPackHalf2x16(clamp(_8567.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7505 + 2u) * 4 + 0, (((_19133 & 32767u) >> 4u) | ((((_19133 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8567.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19168 = spvPackHalf2x16(clamp(_8575.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7505 + 3u) * 4 + 0, (((_19168 & 32767u) >> 4u) | ((((_19168 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8575.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19195 = r_current_interpolation_source.Load(int3(_4848, 0));
            uint _19209 = spvPackHalf2x16(clamp(_19195.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7505 + 4u) * 4 + 0, (((_19209 & 32767u) >> 4u) | ((((_19209 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19195.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22939;
            if (_22688 || (_6720 != 0u))
            {
                _22939 = 4294967295u;
            }
            else
            {
                uint _19244 = spvPackHalf2x16(clamp(_22862.xy, 0.0f.xx, 65000.0f.xx));
                _22939 = (((_19244 & 32767u) >> 4u) | ((((_19244 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22862.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7505 + 5u) * 4 + 0, _22939);
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
