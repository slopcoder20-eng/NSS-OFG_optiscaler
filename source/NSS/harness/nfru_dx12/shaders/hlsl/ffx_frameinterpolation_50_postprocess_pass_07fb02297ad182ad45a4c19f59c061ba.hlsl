static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19727;

static const int2 _1240[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1249[5] = { 2, 4, 7, 11, 16 };
static const float3 _4548[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4849 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4849.x >= cbFI_DisplaySize.x, _4849.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4849] = float4(r_present_backbuffer.Load(int3(_4849, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7702 = cbFI_DisplaySize - int2(1, 1);
                int2 _7703 = clamp(_4849, int2(0, 0), _7702);
                uint _7713 = uint((_7703.y * cbFI_DisplaySize.x) + _7703.x) * 2u;
                uint _7716 = rw_nfru_select.Load<uint>(_7713 * 4 + 0);
                float2 _7717 = spvUnpackHalf2x16(_7716);
                uint _7721 = rw_nfru_select.Load<uint>((_7713 + 1u) * 4 + 0);
                float2 _7722 = spvUnpackHalf2x16(_7721);
                float _7723 = _7717.x;
                float _7725 = _7722.x;
                if (_7722.y > 1.5f)
                {
                    rw_output[_4849] = float4(_7723, _7717.y, _7725, 1.0f).xyz;
                    break;
                }
                int _23164;
                float _23165;
                float3 _23166;
                float _23167;
                float _23168;
                _23168 = 0.0f;
                _23167 = 0.0f;
                _23166 = 0.0f.xxx;
                _23165 = 0.0f;
                _23164 = -2;
                float3 _23171;
                float _23172;
                float _23173;
                float _23174;
                for (; _23164 <= 2; _23168 = _23174, _23167 = _23173, _23166 = _23171, _23165 = _23172, _23164++)
                {
                    _23174 = _23168;
                    _23173 = _23167;
                    _23172 = _23165;
                    _23171 = _23166;
                    for (int _23169 = -2; _23169 <= 2; )
                    {
                        float _7619 = float((_23169 * _23169) + (_23164 * _23164));
                        float _7624 = exp(_7619 * (-0.319999992847442626953125f));
                        int2 _7629 = int2(_23169, _23164);
                        int2 _7739 = clamp(_4849 + (_7629 * int2(2, 2)), int2(0, 0), _7702);
                        uint _7749 = uint((_7739.y * cbFI_DisplaySize.x) + _7739.x) * 2u;
                        float _7646 = exp(_7619 * (-0.5f));
                        int2 _7771 = clamp(_4849 + (_7629 * int2(6, 6)), int2(0, 0), _7702);
                        _23174 += _7646;
                        _23173 += (_7646 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7771.y * cbFI_DisplaySize.x) + _7771.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23172 += _7624;
                        _23171 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7749 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7749 + 1u) * 4 + 0)).x, _19727).xyz * _7624);
                        _23169++;
                        continue;
                    }
                }
                float3 _7676 = _23166 / _23165.xxx;
                rw_output[_4849] = float4(_7676 + ((float4(_7723, _7717.y, _7725, _7722.y).xyz - _7676) * clamp(_23167 / _23168, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5348 = (float2(_4849) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5350 = float2(cbFI_MvDepthLaneSize);
        int2 _5359 = int2(floor(_5348 * _5350));
        int2 _5364 = int2(floor(_5348 * float2(cbFI_FlowLaneSize)));
        float4 _7842 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5348 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7848 = r_warped_filled_flow_tm1.Load(int3(_5364, 0)).xy;
        float2 _7854 = r_warped_filled_motion_tp1.Load(int3(_5359, 0)).xy;
        bool _7876 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19728;
        if (_7876)
        {
            float _7889 = ((2.0f * _5348.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19728 = float2(atan(_7889) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5348.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7889 * _7889))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19728 = _5348;
        }
        bool _5385 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19749;
        bool _19891;
        int2 _19972;
        float3 _22256;
        if (_5385)
        {
            float _19730;
            float _19732;
            _19732 = 2.0f;
            _19730 = -1.0f;
            uint _4946[9];
            float _23175;
            float _23178;
            for (int _19729 = 0; _19729 < 9; _19732 = _23178, _19730 = _23175, _19729++)
            {
                _4946[_19729] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5359 + int2((_19729 % 3) - 1, (_19729 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4946[_19729] != 0u)
                {
                    float _23159;
                    if (_4946[_19729] == 0u)
                    {
                        _23159 = -1.0f;
                    }
                    else
                    {
                        _23159 = float((_4946[_19729] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23178 = min(_19732, _23159);
                    _23175 = max(_19730, _23159);
                }
                else
                {
                    _23178 = _19732;
                    _23175 = _19730;
                }
            }
            float _5431 = float(_19730 >= 0.0f);
            float3 _19295 = 0.0f.xxx;
            _19295.y = _5431;
            float2 _19750;
            bool _19892;
            int2 _19973;
            float3 _22257;
            if ((_19730 - _19732) > 0.0199999995529651641845703125f)
            {
                float _19738;
                int2 _19739;
                float2 _19740;
                int2 _19742;
                float2 _19748;
                _19748 = _7854;
                _19742 = _5359;
                _19740 = _7854;
                _19739 = _5359;
                _19738 = -1.0f;
                float _23183;
                int2 _23187;
                float2 _23198;
                int2 _23209;
                float2 _23242;
                float _23627;
                int _19737 = 0;
                float _23140 = 1000000000.0f;
                for (; _19737 < 9; _23140 = _23627, _19748 = _23242, _19742 = _23209, _19740 = _23198, _19739 = _23187, _19738 = _23183, _19737++)
                {
                    if (_4946[_19737] == 0u)
                    {
                        _23627 = _23140;
                        _23242 = _19748;
                        _23209 = _19742;
                        _23198 = _19740;
                        _23187 = _19739;
                        _23183 = _19738;
                        continue;
                    }
                    int2 _5466 = clamp(_5359 + int2((_19737 % 3) - 1, (_19737 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7964 = _4946[_19737] & 2147483647u;
                    uint _7996 = uint(max((int((_7964 >> 16u) & 15u) - 6), 0));
                    float2 _5472 = (float2(float((1 - (2 * int((_7964 >> 15u) & 1u))) * int(((_7964 >> uint(7)) & 127u) << _7996)), float((1 - (2 * int((_7964 >> 14u) & 1u))) * int((_7964 & 127u) << _7996))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23126;
                    if (_4946[_19737] == 0u)
                    {
                        _23126 = -1.0f;
                    }
                    else
                    {
                        _23126 = float((_4946[_19737] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5477 = _23126 - 0.100000001490116119384765625f;
                    float2 _23127;
                    if (_7876)
                    {
                        float2 _8073 = clamp((((_19728 + (_5472 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8076 = tan(_8073.x);
                        _23127 = (float2(_8076 / cbFI_DeviceToViewDepth.z, (tan(_8073.y) * sqrt(1.0f + (_8076 * _8076))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23127 = _19728 + (_5472 * cbFI_Timestep);
                    }
                    float _5484 = cbFI_Timestep - 1.0f;
                    float2 _23128;
                    if (_7876)
                    {
                        float2 _8144 = clamp((((_19728 + (_5472 * _5484)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8147 = tan(_8144.x);
                        _23128 = (float2(_8147 / cbFI_DeviceToViewDepth.z, (tan(_8144.y) * sqrt(1.0f + (_8147 * _8147))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23128 = _19728 + (_5472 * _5484);
                    }
                    bool _8180 = all(bool2(_23127.x > 0.0f.xx.x, _23127.y > 0.0f.xx.y));
                    bool _8186;
                    if (_8180)
                    {
                        _8186 = all(bool2(_23127.x < 1.0f.xx.x, _23127.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8186 = _8180;
                    }
                    float _23131;
                    if (_8186)
                    {
                        uint _8193_dummy_parameter;
                        _23131 = max((_5477 - (log(((r_depth_tm1.Load(int3(int2(floor(_23127 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8193_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23131 = 0.0f;
                    }
                    bool _8223 = all(bool2(_23128.x > 0.0f.xx.x, _23128.y > 0.0f.xx.y));
                    bool _8229;
                    if (_8223)
                    {
                        _8229 = all(bool2(_23128.x < 1.0f.xx.x, _23128.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8229 = _8223;
                    }
                    float _23132;
                    if (_8229)
                    {
                        uint _8236_dummy_parameter;
                        _23132 = _23131 + max((_5477 - (log(((r_depth_tp1.Load(int3(int2(floor(_23128 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8236_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23132 = _23131;
                    }
                    float _23184;
                    int2 _23188;
                    float2 _23199;
                    int2 _23210;
                    float2 _23243;
                    float _23628;
                    if (_23132 == 0.0f)
                    {
                        bool _5519 = _5477 > _19738;
                        bool2 _23636 = _5519.xx;
                        _23628 = _23140;
                        _23243 = float2(_23636.x ? _5472.x : _19748.x, _23636.y ? _5472.y : _19748.y);
                        _23210 = int2(_23636.x ? _5466.x : _19742.x, _23636.y ? _5466.y : _19742.y);
                        _23199 = _19740;
                        _23188 = _19739;
                        _23184 = _5519 ? _5477 : _19738;
                    }
                    else
                    {
                        bool _5528 = _23132 < _23140;
                        bool2 _23632 = _5528.xx;
                        _23628 = _5528 ? _23132 : _23140;
                        _23243 = _19748;
                        _23210 = _19742;
                        _23199 = float2(_23632.x ? _5472.x : _19740.x, _23632.y ? _5472.y : _19740.y);
                        _23188 = int2(_23632.x ? _5466.x : _19739.x, _23632.y ? _5466.y : _19739.y);
                        _23184 = _19738;
                    }
                    _23627 = _23628;
                    _23242 = _23243;
                    _23209 = _23210;
                    _23198 = _23199;
                    _23187 = _23188;
                    _23183 = _23184;
                }
                bool _5540 = _19738 < 0.0f;
                bool2 _23642 = _5540.xx;
                int2 _23645 = int2(_23642.x ? _19739.x : _19742.x, _23642.y ? _19739.y : _19742.y);
                _22257 = float3(1.0f, _5431, float(any(bool2(_23645.x != _5359.x, _23645.y != _5359.y))));
                _19973 = _23645;
                _19892 = _5540 ? false : true;
                _19750 = float2(_23642.x ? _19740.x : _19748.x, _23642.y ? _19740.y : _19748.y);
            }
            else
            {
                _22257 = _19295;
                _19973 = _5359;
                _19892 = false;
                _19750 = _7854;
            }
            _22256 = _22257;
            _19972 = _19973;
            _19891 = _19892;
            _19749 = _19750;
        }
        else
        {
            _22256 = 0.0f.xxx;
            _19972 = _5359;
            _19891 = false;
            _19749 = _7854;
        }
        float2 _19751;
        if (_7876)
        {
            float2 _8301 = clamp((((_19728 + (_19749 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8304 = tan(_8301.x);
            _19751 = (float2(_8304 / cbFI_DeviceToViewDepth.z, (tan(_8301.y) * sqrt(1.0f + (_8304 * _8304))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19751 = _19728 + (_19749 * cbFI_Timestep);
        }
        float _5563 = cbFI_Timestep - 1.0f;
        float2 _19753;
        if (_7876)
        {
            float2 _8372 = clamp((((_19728 + (_19749 * _5563)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8375 = tan(_8372.x);
            _19753 = (float2(_8375 / cbFI_DeviceToViewDepth.z, (tan(_8372.y) * sqrt(1.0f + (_8375 * _8375))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19753 = _19728 + (_19749 * _5563);
        }
        float _5568 = -cbFI_Timestep;
        float2 _19754;
        if (_7876)
        {
            float2 _8443 = clamp((((_19728 + (_7848 * _5568)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8446 = tan(_8443.x);
            _19754 = (float2(_8446 / cbFI_DeviceToViewDepth.z, (tan(_8443.y) * sqrt(1.0f + (_8446 * _8446))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19754 = _19728 + (_7848 * _5568);
        }
        float _5573 = 1.0f - cbFI_Timestep;
        float2 _19755;
        if (_7876)
        {
            float2 _8514 = clamp((((_19728 + (_7848 * _5573)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8517 = tan(_8514.x);
            _19755 = (float2(_8517 / cbFI_DeviceToViewDepth.z, (tan(_8514.y) * sqrt(1.0f + (_8517 * _8517))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19755 = _19728 + (_7848 * _5573);
        }
        float4 _8552 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19751, 0.0f);
        float3 _8553 = _8552.xyz;
        float4 _8560 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19753, 0.0f);
        float3 _8561 = _8560.xyz;
        float4 _8568 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19754, 0.0f);
        float3 _8569 = _8568.xyz;
        float4 _8576 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19755, 0.0f);
        float3 _8577 = _8576.xyz;
        float4 _8591 = exp(_7842 - max(max(max(_7842.x, _7842.y), _7842.z), _7842.w).xxxx);
        float4 _8598 = _8591 / (dot(_8591, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5589 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19962;
        float _21270;
        if (_5589)
        {
            float2 _5595 = 0.5f.xx / _5350;
            float _5598 = _5595.x;
            float _5599 = -_5598;
            float _5601 = _5595.y;
            float _5602 = -_5601;
            float2 _5604 = _5348 + float2(_5599, _5602);
            float2 _5606 = float2(cbFI_DisplaySize);
            bool _19772;
            do
            {
                bool _8678 = all(bool2(_5604.x > 0.0f.xx.x, _5604.y > 0.0f.xx.y));
                bool _8684;
                if (_8678)
                {
                    _8684 = all(bool2(_5604.x < 1.0f.xx.x, _5604.y < 1.0f.xx.y));
                }
                else
                {
                    _8684 = _8678;
                }
                if (!_8684)
                {
                    _19772 = false;
                    break;
                }
                uint _8691_dummy_parameter;
                float4x4 _19770;
                do
                {
                    float4x4 _8705;
                    bool _19769;
                    do
                    {
                        _8705 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19769 = false;
                            break;
                        }
                        uint _8739 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8739 + 32u) * 4 + 0) != 1u)
                        {
                            _19769 = false;
                            break;
                        }
                        uint _19766;
                        _19766 = 0u;
                        for (; _19766 < 4u; _19766++)
                        {
                            for (uint _19767 = 0u; _19767 < 4u; )
                            {
                                _8705[_19766][_19767] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8739 + (_19766 * 4u)) + _19767) * 4 + 0));
                                _19767++;
                                continue;
                            }
                        }
                        _19769 = true;
                        break;
                    } while(false);
                    if (_19769)
                    {
                        _19770 = _8705;
                        break;
                    }
                    _19770 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19771;
                do
                {
                    float _8816 = _5604.x;
                    float _8819 = 1.0f - _5604.y;
                    float4 _8830 = mul(float4((float2(_8816, _8819) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5604 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8691_dummy_parameter))))), 0)).x, 1.0f), _19770);
                    float _8832 = _8830.w;
                    if (!(_8832 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19771 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8845 = ((_8830.xy / _8832.xx) + 1.0f.xx) * 0.5f;
                    _19771 = float2(_8845.x - _8816, _8819 - _8845.y);
                    break;
                } while(false);
                float2 _8642 = abs(_19771);
                if (any(bool2(_8642.x > 100000.0f.xx.x, _8642.y > 100000.0f.xx.y)))
                {
                    _19772 = false;
                    break;
                }
                float _8650 = length(_19771 * _5606);
                uint _8865_dummy_parameter;
                bool _8664 = _8650 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8671;
                if (_8664)
                {
                    _8671 = length((r_motion_tp1.Load(int3(int2(floor(_5604 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8865_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _8650);
                }
                else
                {
                    _8671 = _8664;
                }
                _19772 = _8671;
                break;
            } while(false);
            float2 _5616 = _5348 + float2(_5598, _5602);
            bool _19779;
            do
            {
                bool _8951 = all(bool2(_5616.x > 0.0f.xx.x, _5616.y > 0.0f.xx.y));
                bool _8957;
                if (_8951)
                {
                    _8957 = all(bool2(_5616.x < 1.0f.xx.x, _5616.y < 1.0f.xx.y));
                }
                else
                {
                    _8957 = _8951;
                }
                if (!_8957)
                {
                    _19779 = false;
                    break;
                }
                uint _8964_dummy_parameter;
                float4x4 _19777;
                do
                {
                    float4x4 _8978;
                    bool _19776;
                    do
                    {
                        _8978 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19776 = false;
                            break;
                        }
                        uint _9012 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9012 + 32u) * 4 + 0) != 1u)
                        {
                            _19776 = false;
                            break;
                        }
                        uint _19773;
                        _19773 = 0u;
                        for (; _19773 < 4u; _19773++)
                        {
                            for (uint _19774 = 0u; _19774 < 4u; )
                            {
                                _8978[_19773][_19774] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9012 + (_19773 * 4u)) + _19774) * 4 + 0));
                                _19774++;
                                continue;
                            }
                        }
                        _19776 = true;
                        break;
                    } while(false);
                    if (_19776)
                    {
                        _19777 = _8978;
                        break;
                    }
                    _19777 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19778;
                do
                {
                    float _9089 = _5616.x;
                    float _9092 = 1.0f - _5616.y;
                    float4 _9103 = mul(float4((float2(_9089, _9092) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5616 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8964_dummy_parameter))))), 0)).x, 1.0f), _19777);
                    float _9105 = _9103.w;
                    if (!(_9105 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19778 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9118 = ((_9103.xy / _9105.xx) + 1.0f.xx) * 0.5f;
                    _19778 = float2(_9118.x - _9089, _9092 - _9118.y);
                    break;
                } while(false);
                float2 _8915 = abs(_19778);
                if (any(bool2(_8915.x > 100000.0f.xx.x, _8915.y > 100000.0f.xx.y)))
                {
                    _19779 = false;
                    break;
                }
                float _8923 = length(_19778 * _5606);
                uint _9138_dummy_parameter;
                bool _8937 = _8923 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8944;
                if (_8937)
                {
                    _8944 = length((r_motion_tp1.Load(int3(int2(floor(_5616 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9138_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _8923);
                }
                else
                {
                    _8944 = _8937;
                }
                _19779 = _8944;
                break;
            } while(false);
            float2 _5629 = _5348 + float2(_5599, _5601);
            bool _19786;
            do
            {
                bool _9224 = all(bool2(_5629.x > 0.0f.xx.x, _5629.y > 0.0f.xx.y));
                bool _9230;
                if (_9224)
                {
                    _9230 = all(bool2(_5629.x < 1.0f.xx.x, _5629.y < 1.0f.xx.y));
                }
                else
                {
                    _9230 = _9224;
                }
                if (!_9230)
                {
                    _19786 = false;
                    break;
                }
                uint _9237_dummy_parameter;
                float4x4 _19784;
                do
                {
                    float4x4 _9251;
                    bool _19783;
                    do
                    {
                        _9251 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19783 = false;
                            break;
                        }
                        uint _9285 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9285 + 32u) * 4 + 0) != 1u)
                        {
                            _19783 = false;
                            break;
                        }
                        uint _19780;
                        _19780 = 0u;
                        for (; _19780 < 4u; _19780++)
                        {
                            for (uint _19781 = 0u; _19781 < 4u; )
                            {
                                _9251[_19780][_19781] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9285 + (_19780 * 4u)) + _19781) * 4 + 0));
                                _19781++;
                                continue;
                            }
                        }
                        _19783 = true;
                        break;
                    } while(false);
                    if (_19783)
                    {
                        _19784 = _9251;
                        break;
                    }
                    _19784 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19785;
                do
                {
                    float _9362 = _5629.x;
                    float _9365 = 1.0f - _5629.y;
                    float4 _9376 = mul(float4((float2(_9362, _9365) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5629 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9237_dummy_parameter))))), 0)).x, 1.0f), _19784);
                    float _9378 = _9376.w;
                    if (!(_9378 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19785 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9391 = ((_9376.xy / _9378.xx) + 1.0f.xx) * 0.5f;
                    _19785 = float2(_9391.x - _9362, _9365 - _9391.y);
                    break;
                } while(false);
                float2 _9188 = abs(_19785);
                if (any(bool2(_9188.x > 100000.0f.xx.x, _9188.y > 100000.0f.xx.y)))
                {
                    _19786 = false;
                    break;
                }
                float _9196 = length(_19785 * _5606);
                uint _9411_dummy_parameter;
                bool _9210 = _9196 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9217;
                if (_9210)
                {
                    _9217 = length((r_motion_tp1.Load(int3(int2(floor(_5629 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9411_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _9196);
                }
                else
                {
                    _9217 = _9210;
                }
                _19786 = _9217;
                break;
            } while(false);
            float2 _5641 = _5348 + _5595;
            bool _19793;
            do
            {
                bool _9497 = all(bool2(_5641.x > 0.0f.xx.x, _5641.y > 0.0f.xx.y));
                bool _9503;
                if (_9497)
                {
                    _9503 = all(bool2(_5641.x < 1.0f.xx.x, _5641.y < 1.0f.xx.y));
                }
                else
                {
                    _9503 = _9497;
                }
                if (!_9503)
                {
                    _19793 = false;
                    break;
                }
                uint _9510_dummy_parameter;
                float4x4 _19791;
                do
                {
                    float4x4 _9524;
                    bool _19790;
                    do
                    {
                        _9524 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19790 = false;
                            break;
                        }
                        uint _9558 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9558 + 32u) * 4 + 0) != 1u)
                        {
                            _19790 = false;
                            break;
                        }
                        uint _19787;
                        _19787 = 0u;
                        for (; _19787 < 4u; _19787++)
                        {
                            for (uint _19788 = 0u; _19788 < 4u; )
                            {
                                _9524[_19787][_19788] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9558 + (_19787 * 4u)) + _19788) * 4 + 0));
                                _19788++;
                                continue;
                            }
                        }
                        _19790 = true;
                        break;
                    } while(false);
                    if (_19790)
                    {
                        _19791 = _9524;
                        break;
                    }
                    _19791 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19792;
                do
                {
                    float _9635 = _5641.x;
                    float _9638 = 1.0f - _5641.y;
                    float4 _9649 = mul(float4((float2(_9635, _9638) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5641 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9510_dummy_parameter))))), 0)).x, 1.0f), _19791);
                    float _9651 = _9649.w;
                    if (!(_9651 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19792 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9664 = ((_9649.xy / _9651.xx) + 1.0f.xx) * 0.5f;
                    _19792 = float2(_9664.x - _9635, _9638 - _9664.y);
                    break;
                } while(false);
                float2 _9461 = abs(_19792);
                if (any(bool2(_9461.x > 100000.0f.xx.x, _9461.y > 100000.0f.xx.y)))
                {
                    _19793 = false;
                    break;
                }
                float _9469 = length(_19792 * _5606);
                uint _9684_dummy_parameter;
                bool _9483 = _9469 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9490;
                if (_9483)
                {
                    _9490 = length((r_motion_tp1.Load(int3(int2(floor(_5641 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9684_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _9469);
                }
                else
                {
                    _9490 = _9483;
                }
                _19793 = _9490;
                break;
            } while(false);
            float _5647 = 0.25f * (((float(_19772) + float(_19779)) + float(_19786)) + float(_19793));
            float4 _19963;
            if (_5647 < 1.0f)
            {
                bool _19800;
                do
                {
                    bool _9770 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                    bool _9776;
                    if (_9770)
                    {
                        _9776 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9776 = _9770;
                    }
                    if (!_9776)
                    {
                        _19800 = false;
                        break;
                    }
                    uint _9783_dummy_parameter;
                    float4x4 _19798;
                    do
                    {
                        float4x4 _9797;
                        bool _19797;
                        do
                        {
                            _9797 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19797 = false;
                                break;
                            }
                            uint _9831 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9831 + 32u) * 4 + 0) != 1u)
                            {
                                _19797 = false;
                                break;
                            }
                            uint _19794;
                            _19794 = 0u;
                            for (; _19794 < 4u; _19794++)
                            {
                                for (uint _19795 = 0u; _19795 < 4u; )
                                {
                                    _9797[_19794][_19795] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9831 + (_19794 * 4u)) + _19795) * 4 + 0));
                                    _19795++;
                                    continue;
                                }
                            }
                            _19797 = true;
                            break;
                        } while(false);
                        if (_19797)
                        {
                            _19798 = _9797;
                            break;
                        }
                        _19798 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19799;
                    do
                    {
                        float _9911 = 1.0f - _19751.y;
                        float4 _9922 = mul(float4((float2(_19751.x, _9911) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9783_dummy_parameter))))), 0)).x, 1.0f), _19798);
                        float _9924 = _9922.w;
                        if (!(_9924 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19799 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9937 = ((_9922.xy / _9924.xx) + 1.0f.xx) * 0.5f;
                        _19799 = float2(_9937.x - _19751.x, _9911 - _9937.y);
                        break;
                    } while(false);
                    float2 _9734 = abs(_19799);
                    if (any(bool2(_9734.x > 100000.0f.xx.x, _9734.y > 100000.0f.xx.y)))
                    {
                        _19800 = false;
                        break;
                    }
                    float _9742 = length(_19799 * _5606);
                    uint _9957_dummy_parameter;
                    bool _9756 = _9742 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9763;
                    if (_9756)
                    {
                        _9763 = length((r_motion_tp1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9957_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _9742);
                    }
                    else
                    {
                        _9763 = _9756;
                    }
                    _19800 = _9763;
                    break;
                } while(false);
                bool _19807;
                do
                {
                    bool _10043 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                    bool _10049;
                    if (_10043)
                    {
                        _10049 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10049 = _10043;
                    }
                    if (!_10049)
                    {
                        _19807 = false;
                        break;
                    }
                    uint _10056_dummy_parameter;
                    float4x4 _19805;
                    do
                    {
                        float4x4 _10070;
                        bool _19804;
                        do
                        {
                            _10070 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19804 = false;
                                break;
                            }
                            uint _10104 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10104 + 32u) * 4 + 0) != 1u)
                            {
                                _19804 = false;
                                break;
                            }
                            uint _19801;
                            _19801 = 0u;
                            for (; _19801 < 4u; _19801++)
                            {
                                for (uint _19802 = 0u; _19802 < 4u; )
                                {
                                    _10070[_19801][_19802] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10104 + (_19801 * 4u)) + _19802) * 4 + 0));
                                    _19802++;
                                    continue;
                                }
                            }
                            _19804 = true;
                            break;
                        } while(false);
                        if (_19804)
                        {
                            _19805 = _10070;
                            break;
                        }
                        _19805 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19806;
                    do
                    {
                        float _10184 = 1.0f - _19753.y;
                        float4 _10195 = mul(float4((float2(_19753.x, _10184) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10056_dummy_parameter))))), 0)).x, 1.0f), _19805);
                        float _10197 = _10195.w;
                        if (!(_10197 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19806 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10210 = ((_10195.xy / _10197.xx) + 1.0f.xx) * 0.5f;
                        _19806 = float2(_10210.x - _19753.x, _10184 - _10210.y);
                        break;
                    } while(false);
                    float2 _10007 = abs(_19806);
                    if (any(bool2(_10007.x > 100000.0f.xx.x, _10007.y > 100000.0f.xx.y)))
                    {
                        _19807 = false;
                        break;
                    }
                    float _10015 = length(_19806 * _5606);
                    uint _10230_dummy_parameter;
                    bool _10029 = _10015 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10036;
                    if (_10029)
                    {
                        _10036 = length((r_motion_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10230_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _10015);
                    }
                    else
                    {
                        _10036 = _10029;
                    }
                    _19807 = _10036;
                    break;
                } while(false);
                bool _19814;
                do
                {
                    bool _10316 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _10322;
                    if (_10316)
                    {
                        _10322 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10322 = _10316;
                    }
                    if (!_10322)
                    {
                        _19814 = false;
                        break;
                    }
                    uint _10329_dummy_parameter;
                    float4x4 _19812;
                    do
                    {
                        float4x4 _10343;
                        bool _19811;
                        do
                        {
                            _10343 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19811 = false;
                                break;
                            }
                            uint _10377 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10377 + 32u) * 4 + 0) != 1u)
                            {
                                _19811 = false;
                                break;
                            }
                            uint _19808;
                            _19808 = 0u;
                            for (; _19808 < 4u; _19808++)
                            {
                                for (uint _19809 = 0u; _19809 < 4u; )
                                {
                                    _10343[_19808][_19809] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10377 + (_19808 * 4u)) + _19809) * 4 + 0));
                                    _19809++;
                                    continue;
                                }
                            }
                            _19811 = true;
                            break;
                        } while(false);
                        if (_19811)
                        {
                            _19812 = _10343;
                            break;
                        }
                        _19812 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19813;
                    do
                    {
                        float _10457 = 1.0f - _19754.y;
                        float4 _10468 = mul(float4((float2(_19754.x, _10457) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10329_dummy_parameter))))), 0)).x, 1.0f), _19812);
                        float _10470 = _10468.w;
                        if (!(_10470 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19813 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10483 = ((_10468.xy / _10470.xx) + 1.0f.xx) * 0.5f;
                        _19813 = float2(_10483.x - _19754.x, _10457 - _10483.y);
                        break;
                    } while(false);
                    float2 _10280 = abs(_19813);
                    if (any(bool2(_10280.x > 100000.0f.xx.x, _10280.y > 100000.0f.xx.y)))
                    {
                        _19814 = false;
                        break;
                    }
                    float _10288 = length(_19813 * _5606);
                    uint _10503_dummy_parameter;
                    bool _10302 = _10288 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10309;
                    if (_10302)
                    {
                        _10309 = length((r_motion_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10503_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _10288);
                    }
                    else
                    {
                        _10309 = _10302;
                    }
                    _19814 = _10309;
                    break;
                } while(false);
                bool _19821;
                do
                {
                    bool _10589 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                    bool _10595;
                    if (_10589)
                    {
                        _10595 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10595 = _10589;
                    }
                    if (!_10595)
                    {
                        _19821 = false;
                        break;
                    }
                    uint _10602_dummy_parameter;
                    float4x4 _19819;
                    do
                    {
                        float4x4 _10616;
                        bool _19818;
                        do
                        {
                            _10616 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19818 = false;
                                break;
                            }
                            uint _10650 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10650 + 32u) * 4 + 0) != 1u)
                            {
                                _19818 = false;
                                break;
                            }
                            uint _19815;
                            _19815 = 0u;
                            for (; _19815 < 4u; _19815++)
                            {
                                for (uint _19816 = 0u; _19816 < 4u; )
                                {
                                    _10616[_19815][_19816] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10650 + (_19815 * 4u)) + _19816) * 4 + 0));
                                    _19816++;
                                    continue;
                                }
                            }
                            _19818 = true;
                            break;
                        } while(false);
                        if (_19818)
                        {
                            _19819 = _10616;
                            break;
                        }
                        _19819 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19820;
                    do
                    {
                        float _10730 = 1.0f - _19755.y;
                        float4 _10741 = mul(float4((float2(_19755.x, _10730) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10602_dummy_parameter))))), 0)).x, 1.0f), _19819);
                        float _10743 = _10741.w;
                        if (!(_10743 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19820 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10756 = ((_10741.xy / _10743.xx) + 1.0f.xx) * 0.5f;
                        _19820 = float2(_10756.x - _19755.x, _10730 - _10756.y);
                        break;
                    } while(false);
                    float2 _10553 = abs(_19820);
                    if (any(bool2(_10553.x > 100000.0f.xx.x, _10553.y > 100000.0f.xx.y)))
                    {
                        _19821 = false;
                        break;
                    }
                    float _10561 = length(_19820 * _5606);
                    uint _10776_dummy_parameter;
                    bool _10575 = _10561 > ((8.0f * _5606.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10582;
                    if (_10575)
                    {
                        _10582 = length((r_motion_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10776_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5606) < (0.20000000298023223876953125f * _10561);
                    }
                    else
                    {
                        _10582 = _10575;
                    }
                    _19821 = _10582;
                    break;
                } while(false);
                float4 _5674 = _8598 * float4(_19800 ? 0.0f : 1.0f, _19807 ? 0.0f : 1.0f, _19814 ? 0.0f : 1.0f, _19821 ? 0.0f : 1.0f);
                float _5676 = dot(_5674, 1.0f.xxxx);
                float4 _19964;
                if (_5676 > 0.001000000047497451305389404296875f)
                {
                    _19964 = _5674 / _5676.xxxx;
                }
                else
                {
                    _19964 = _8598;
                }
                _19963 = _19964;
            }
            else
            {
                _19963 = _8598;
            }
            _21270 = _5647;
            _19962 = _19963;
        }
        else
        {
            _21270 = 0.0f;
            _19962 = _8598;
        }
        bool _5693 = _5385 && (!_19891);
        bool _5702;
        if (_5693)
        {
            _5702 = (_19962.z + _19962.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5702 = _5693;
        }
        bool _5713;
        if (_5702)
        {
            _5713 = length((_19754 - _19751) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5713 = _5702;
        }
        bool _20051;
        if (_5713)
        {
            uint4 _10805 = r_warped_motion_qdata_tp1.Load(int3(_19972, 0));
            uint _10806 = _10805.x;
            bool _20054;
            if (_10806 != 0u)
            {
                float _20040;
                if (_10806 == 0u)
                {
                    _20040 = -1.0f;
                }
                else
                {
                    _20040 = float((_10806 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5723 = _20040 - 0.12000000476837158203125f;
                bool _10825 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _10831;
                if (_10825)
                {
                    _10831 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _10831 = _10825;
                }
                bool _5733;
                if (_10831)
                {
                    uint _10838_dummy_parameter;
                    _5733 = (log(((r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10838_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5723;
                }
                else
                {
                    _5733 = _10831;
                }
                bool _5747;
                if (!_5733)
                {
                    bool _10868 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                    bool _10874;
                    if (_10868)
                    {
                        _10874 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10874 = _10868;
                    }
                    bool _5745;
                    if (_10874)
                    {
                        uint _10881_dummy_parameter;
                        _5745 = (log(((r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10881_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5723;
                    }
                    else
                    {
                        _5745 = _10874;
                    }
                    _5747 = _5745;
                }
                else
                {
                    _5747 = _5733;
                }
                _20054 = _5747;
            }
            else
            {
                _20054 = false;
            }
            _20051 = _20054;
        }
        else
        {
            _20051 = false;
        }
        bool _5752 = _19891 || _20051;
        bool _5757;
        if (_5752)
        {
            bool _10911 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
            bool _10917;
            if (_10911)
            {
                _10917 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
            }
            else
            {
                _10917 = _10911;
            }
            _5757 = _10917;
        }
        else
        {
            _5757 = _5752;
        }
        bool _5762;
        if (_5757)
        {
            bool _10922 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
            bool _10928;
            if (_10922)
            {
                _10928 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
            }
            else
            {
                _10928 = _10922;
            }
            _5762 = _10928;
        }
        else
        {
            _5762 = _5757;
        }
        float4 _20174;
        if (_5762)
        {
            float _5768 = _19962.x + _19962.y;
            float _5773 = _19962.z + _19962.w;
            float _20069;
            if (_5768 > 0.001000000047497451305389404296875f)
            {
                _20069 = _19962.x / _5768;
            }
            else
            {
                _20069 = _5573;
            }
            _20174 = float4(_19962.x + (_5773 * _20069), _19962.y + (_5773 * (1.0f - _20069)), 0.0f, 0.0f);
        }
        else
        {
            _20174 = _19962;
        }
        bool _10956 = (cbFI_pad0 & 1024u) != 0u;
        bool _10932 = !_10956;
        bool _10933 = !_10932;
        bool _10950;
        if (_10933)
        {
            _10950 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19972.y * cbFI_MvDepthLaneSize.x) + _19972.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10950 = _10932;
        }
        bool _10982;
        if (_10933)
        {
            _10982 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5364.y * cbFI_FlowLaneSize.x) + _5364.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10982 = _10932;
        }
        float _5808 = float(_10982);
        bool _20195;
        float4 _20234;
        float3 _21990;
        if (_10956)
        {
            bool _5818;
            if (_10950)
            {
                _5818 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
            }
            else
            {
                _5818 = _10950;
            }
            bool _5824;
            if (_5818)
            {
                _5824 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
            }
            else
            {
                _5824 = _5818;
            }
            bool _5831;
            if (_10950)
            {
                _5831 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
            }
            else
            {
                _5831 = _10950;
            }
            bool _5837;
            if (_5831)
            {
                _5837 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
            }
            else
            {
                _5837 = _5831;
            }
            bool _5844;
            if (_10982)
            {
                _5844 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
            }
            else
            {
                _5844 = _10982;
            }
            bool _5850;
            if (_5844)
            {
                _5850 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
            }
            else
            {
                _5850 = _5844;
            }
            bool _5857;
            if (_10982)
            {
                _5857 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
            }
            else
            {
                _5857 = _10982;
            }
            bool _5863;
            if (_5857)
            {
                _5863 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
            }
            else
            {
                _5863 = _5857;
            }
            bool _5865 = !_10950;
            if (_5865)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11024;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11024);
                }
            }
            bool _5870 = !_10982;
            if (_5870)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11034;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11034);
                }
            }
            if (_10950 && _5870)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11044;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11044);
                }
            }
            if (_5865 && _10982)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11054;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11054);
                }
            }
            float _5889 = float(_5824);
            float _5891 = float(_5837);
            bool _5894 = _5850 && _5863;
            float _20103;
            if (_5894)
            {
                _20103 = 1.0f;
            }
            else
            {
                _20103 = (_5850 || _5863) ? 0.5f : 0.0f;
            }
            bool _20118;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5824)) && (!_5837))
            {
                bool _5924;
                if (_5894)
                {
                    float _20111;
                    do
                    {
                        bool _11138 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                        bool _11144;
                        if (_11138)
                        {
                            _11144 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11144 = _11138;
                        }
                        bool _11075 = !_11144;
                        bool _11082;
                        if (!_11075)
                        {
                            bool _11149 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                            bool _11155;
                            if (_11149)
                            {
                                _11155 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11155 = _11149;
                            }
                            _11082 = !_11155;
                        }
                        else
                        {
                            _11082 = _11075;
                        }
                        if (_11082)
                        {
                            _20111 = 0.0f;
                            break;
                        }
                        uint _11162_dummy_parameter;
                        uint _11178_dummy_parameter;
                        float4x4 _20110;
                        do
                        {
                            float4x4 _11192;
                            bool _20109;
                            do
                            {
                                _11192 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20109 = false;
                                    break;
                                }
                                uint _11226 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11226 + 32u) * 4 + 0) != 1u)
                                {
                                    _20109 = false;
                                    break;
                                }
                                uint _20106;
                                _20106 = 0u;
                                for (; _20106 < 4u; _20106++)
                                {
                                    for (uint _20107 = 0u; _20107 < 4u; )
                                    {
                                        _11192[_20106][_20107] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11226 + 16u) + (_20106 * 4u)) + _20107) * 4 + 0));
                                        _20107++;
                                        continue;
                                    }
                                }
                                _20109 = true;
                                break;
                            } while(false);
                            if (_20109)
                            {
                                _20110 = _11192;
                                break;
                            }
                            _20110 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11103 = mul(float4((float2(_19754.x, 1.0f - _19754.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11162_dummy_parameter))))), 0)).x, 1.0f), _20110);
                        float _11105 = _11103.w;
                        if (abs(_11105) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20111 = 0.0f;
                            break;
                        }
                        float _11116 = abs(cbFI_DeviceToViewDepth.y / ((_11103.z / _11105) - cbFI_DeviceToViewDepth.x));
                        float _11119 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11178_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20111 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11116 - _11119) / max(max(_11116, _11119), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5924 = _20111 >= 0.5f;
                }
                else
                {
                    _5924 = _5894;
                }
                bool _5932;
                if (_5924)
                {
                    _5932 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5932 = _5924;
                }
                bool _20119;
                if (_5932)
                {
                    uint _11330_dummy_parameter;
                    float4x4 _20116;
                    do
                    {
                        float4x4 _11344;
                        bool _20115;
                        do
                        {
                            _11344 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20115 = false;
                                break;
                            }
                            uint _11378 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11378 + 32u) * 4 + 0) != 1u)
                            {
                                _20115 = false;
                                break;
                            }
                            uint _20112;
                            _20112 = 0u;
                            for (; _20112 < 4u; _20112++)
                            {
                                for (uint _20113 = 0u; _20113 < 4u; )
                                {
                                    _11344[_20112][_20113] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11378 + 16u) + (_20112 * 4u)) + _20113) * 4 + 0));
                                    _20113++;
                                    continue;
                                }
                            }
                            _20115 = true;
                            break;
                        } while(false);
                        if (_20115)
                        {
                            _20116 = _11344;
                            break;
                        }
                        _20116 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20117;
                    do
                    {
                        float _11458 = 1.0f - _19754.y;
                        float4 _11469 = mul(float4((float2(_19754.x, _11458) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11330_dummy_parameter))))), 0)).x, 1.0f), _20116);
                        float _11471 = _11469.w;
                        if (!(_11471 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20117 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11484 = ((_11469.xy / _11471.xx) + 1.0f.xx) * 0.5f;
                        _20117 = float2(_11484.x - _19754.x, _11458 - _11484.y);
                        break;
                    } while(false);
                    float2 _5945 = float2(cbFI_DisplaySize);
                    _20119 = length(((_19754 + _20117) - _19755) * _5945) <= ((0.100000001490116119384765625f * length(_20117 * _5945)) + 8.0f);
                }
                else
                {
                    _20119 = _5924;
                }
                _20118 = _20119;
            }
            else
            {
                _20118 = true;
            }
            bool _5959 = !_20118;
            bool _23646 = _5959 ? false : _5863;
            bool _23647 = _5959 ? false : _5850;
            bool _20196;
            float4 _20235;
            if (!(((_5824 && _5837) && _23647) && _23646))
            {
                float4 _5981 = _20174 * float4(_5889, _5891, float(_23647), float(_23646));
                float _5983 = dot(_5981, 1.0f.xxxx);
                bool _5986 = !(_5983 > 0.0f);
                float4 _20236;
                if (!_5986)
                {
                    _20236 = _5981 / _5983.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11506;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11506);
                    }
                    _20236 = 0.0f.xxxx;
                }
                _20235 = _20236;
                _20196 = _5986;
            }
            else
            {
                _20235 = _20174;
                _20196 = false;
            }
            _21990 = float3(_5889, _5891, _20103);
            _20234 = _20235;
            _20195 = _20196;
        }
        else
        {
            _21990 = float3(float(_10950), _5808, 0.0f);
            _20234 = _20174;
            _20195 = false;
        }
        bool _6004 = !_20195;
        float4 _20327;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6004)
        {
            float _6011 = _20234.x + _20234.y;
            float4 _20328;
            if (_6011 > 0.001000000047497451305389404296875f)
            {
                _20328 = float4(_20234.x / _6011, _20234.y / _6011, 0.0f, 0.0f);
            }
            else
            {
                _20328 = float4(_5573, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20327 = _20328;
        }
        else
        {
            _20327 = _20234;
        }
        float4 _20504;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6004) && _10950)
        {
            float _20301;
            do
            {
                uint4 _11646 = r_warped_motion_qdata_tp1.Load(int3(_19972, 0));
                uint _11647 = _11646.x;
                if (_11647 != 0u)
                {
                    float _20300;
                    if (_11647 == 0u)
                    {
                        _20300 = -1.0f;
                    }
                    else
                    {
                        _20300 = float((_11647 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20301 = _20300;
                    break;
                }
                int _20283;
                uint _20284;
                _20284 = _11647;
                _20283 = -1;
                uint _20299;
                for (; _20283 <= 1; _20284 = _20299, _20283++)
                {
                    _20299 = _20284;
                    for (int _20297 = -1; _20297 <= 1; )
                    {
                        _20299 = max(_20299, r_warped_motion_qdata_tp1.Load(int3(clamp(_19972 + int2(_20297, _20283), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20297++;
                        continue;
                    }
                }
                if (_20284 != 0u)
                {
                    float _20296;
                    if (_20284 == 0u)
                    {
                        _20296 = -1.0f;
                    }
                    else
                    {
                        _20296 = float((_20284 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20301 = _20296;
                    break;
                }
                uint _20286;
                _20286 = 4294967295u;
                uint _23279;
                for (int _20285 = 0; _20285 < 8; _20286 = _23279, _20285++)
                {
                    int _20289 = 0;
                    for (;;)
                    {
                        if (_20289 < 5)
                        {
                            int2 _11597 = _19972 + (_1240[_20285] * _1249[_20289].xx);
                            bool _11600 = any(bool2(_11597.x < int2(0, 0).x, _11597.y < int2(0, 0).y));
                            bool _11608;
                            if (!_11600)
                            {
                                _11608 = any(bool2(_11597.x >= cbFI_MvDepthLaneSize.x, _11597.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11608 = _11600;
                            }
                            if (_11608)
                            {
                                _23279 = _20286;
                                break;
                            }
                            uint4 _11686 = r_warped_motion_qdata_tp1.Load(int3(_11597, 0));
                            uint _11687 = _11686.x;
                            if (_11687 != 0u)
                            {
                                _23279 = min(_20286, _11687);
                                break;
                            }
                            _20289++;
                            continue;
                        }
                        else
                        {
                            _23279 = _20286;
                            break;
                        }
                    }
                }
                float _20288;
                if (_20286 == 4294967295u)
                {
                    _20288 = -1.0f;
                }
                else
                {
                    float _20287;
                    if (_20286 == 0u)
                    {
                        _20287 = -1.0f;
                    }
                    else
                    {
                        _20287 = float((_20286 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20288 = _20287;
                }
                _20301 = _20288;
                break;
            } while(false);
            float _6047 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6050 = r_warped_motion_qdata_tp1.Load(int3(_19972, 0)).x == 0u;
            bool _6056;
            if (_6050)
            {
                bool _11712 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                bool _11718;
                if (_11712)
                {
                    _11718 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                }
                else
                {
                    _11718 = _11712;
                }
                _6056 = _11718;
            }
            else
            {
                _6056 = _6050;
            }
            bool _6061;
            if (_6056)
            {
                bool _11723 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _11729;
                if (_11723)
                {
                    _11729 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _11729 = _11723;
                }
                _6061 = _11729;
            }
            else
            {
                _6061 = _6056;
            }
            bool _20313;
            float4 _20322;
            if (_6061)
            {
                uint _11736_dummy_parameter;
                float _11760 = log(((r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11736_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11768_dummy_parameter;
                float _11792 = log(((r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11768_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6072 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6079;
                if (_6072)
                {
                    _6079 = _11792 > (_11760 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6079 = _6072;
                }
                bool _20318;
                float4 _20340;
                if (_6079)
                {
                    _20340 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20318 = true;
                }
                else
                {
                    bool _6085 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6092;
                    if (_6085)
                    {
                        _6092 = _11760 > (_11792 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6092 = _6085;
                    }
                    bool4 _23648 = _6092.xxxx;
                    _20340 = float4(_23648.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20327.x, _23648.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20327.y, _23648.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20327.z, _23648.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20327.w);
                    _20318 = _6092 ? true : false;
                }
                _20322 = _20340;
                _20313 = _20318;
            }
            else
            {
                _20322 = _20327;
                _20313 = false;
            }
            float4 _20395;
            if (_20313)
            {
                _20395 = 1.0f.xxxx;
            }
            else
            {
                bool _6103 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6109;
                if (_6103)
                {
                    _6109 = _20322.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6109 = _6103;
                }
                bool _6114;
                if (_6109)
                {
                    bool _11798 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                    bool _11804;
                    if (_11798)
                    {
                        _11804 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11804 = _11798;
                    }
                    _6114 = _11804;
                }
                else
                {
                    _6114 = _6109;
                }
                float4 _20396;
                if (_6114)
                {
                    float _20349;
                    if (_20301 >= 0.0f)
                    {
                        _20349 = _20301 - _6047;
                    }
                    else
                    {
                        float _20345;
                        _20345 = 2.0f;
                        float _11861;
                        for (int _20344 = 0; _20344 < 24; _20345 = _11861, _20344++)
                        {
                            float _11825 = float(_20344 & 7) * 0.785398185253143310546875f;
                            int _11827 = _20344 >> 3;
                            int _20346;
                            if (_11827 == 0)
                            {
                                _20346 = 16;
                            }
                            else
                            {
                                _20346 = (_11827 == 1) ? 48 : 96;
                            }
                            uint _11893_dummy_parameter;
                            _11861 = min(_20345, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19753 + ((cbFI_MvDepthLaneSizeRcp * float(_20346)) * float2(cos(_11825), sin(_11825))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11893_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20349 = _20345;
                    }
                    uint _11925_dummy_parameter;
                    float4 _20397;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11925_dummy_parameter))))), 0)).x) > ((exp((_20349 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20397 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20397 = 1.0f.xxxx;
                    }
                    _20396 = _20397;
                }
                else
                {
                    _20396 = 1.0f.xxxx;
                }
                _20395 = _20396;
            }
            bool _6142 = _20301 >= 0.0f;
            bool _6143 = (!_20313) && _6142;
            bool _6150;
            if (_6143)
            {
                _6150 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6150 = _6143;
            }
            bool _6156;
            if (_6150)
            {
                _6156 = _20322.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6156 = _6150;
            }
            bool _6161;
            if (_6156)
            {
                bool _11950 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                bool _11956;
                if (_11950)
                {
                    _11956 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                }
                else
                {
                    _11956 = _11950;
                }
                _6161 = _11956;
            }
            else
            {
                _6161 = _6156;
            }
            float4 _20420;
            if (_6161)
            {
                float _20389;
                if (_6142)
                {
                    _20389 = _20301 - _6047;
                }
                else
                {
                    float _20385;
                    _20385 = 2.0f;
                    float _12013;
                    for (int _20384 = 0; _20384 < 24; _20385 = _12013, _20384++)
                    {
                        float _11977 = float(_20384 & 7) * 0.785398185253143310546875f;
                        int _11979 = _20384 >> 3;
                        int _20386;
                        if (_11979 == 0)
                        {
                            _20386 = 16;
                        }
                        else
                        {
                            _20386 = (_11979 == 1) ? 48 : 96;
                        }
                        uint _12029_dummy_parameter;
                        _12013 = min(_20385, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19751 + ((cbFI_MvDepthLaneSizeRcp * float(_20386)) * float2(cos(_11977), sin(_11977))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12029_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20389 = _20385;
                }
                uint _12077_dummy_parameter;
                float4 _20421;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12077_dummy_parameter))))), 0)).x) > ((exp((_20389 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19447 = _20395;
                    _19447.x = 0.0f;
                    _20421 = _19447;
                }
                else
                {
                    _20421 = _20395;
                }
                _20420 = _20421;
            }
            else
            {
                _20420 = _20395;
            }
            float4 _20433;
            if (_6143)
            {
                float _12104 = (exp(((_20301 - _6047) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6199 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6205;
                if (_6199)
                {
                    _6205 = _20322.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6205 = _6199;
                }
                bool _6210;
                if (_6205)
                {
                    bool _12109 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                    bool _12115;
                    if (_12109)
                    {
                        _12115 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12115 = _12109;
                    }
                    _6210 = _12115;
                }
                else
                {
                    _6210 = _6205;
                }
                bool _6218;
                if (_6210)
                {
                    uint _12122_dummy_parameter;
                    _6218 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12122_dummy_parameter))))), 0)).x) > _12104;
                }
                else
                {
                    _6218 = _6210;
                }
                float4 _20431;
                if (_6218)
                {
                    float4 _19450 = _20420;
                    _19450.w = 0.0f;
                    _20431 = _19450;
                }
                else
                {
                    _20431 = _20420;
                }
                bool _6225 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6231;
                if (_6225)
                {
                    _6231 = _20322.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6231 = _6225;
                }
                bool _6236;
                if (_6231)
                {
                    bool _12140 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _12146;
                    if (_12140)
                    {
                        _12146 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12146 = _12140;
                    }
                    _6236 = _12146;
                }
                else
                {
                    _6236 = _6231;
                }
                bool _6244;
                if (_6236)
                {
                    uint _12153_dummy_parameter;
                    _6244 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12153_dummy_parameter))))), 0)).x) > _12104;
                }
                else
                {
                    _6244 = _6236;
                }
                float4 _20434;
                if (_6244)
                {
                    float4 _19453 = _20431;
                    _19453.z = 0.0f;
                    _20434 = _19453;
                }
                else
                {
                    _20434 = _20431;
                }
                _20433 = _20434;
            }
            else
            {
                _20433 = _20420;
            }
            float4 _20505;
            if (any(bool4(_20433.x < 1.0f.xxxx.x, _20433.y < 1.0f.xxxx.y, _20433.z < 1.0f.xxxx.z, _20433.w < 1.0f.xxxx.w)))
            {
                float4 _6255 = _20322 * _20433;
                float _6257 = dot(_6255, 1.0f.xxxx);
                float4 _20506;
                if (_6257 > 0.0f)
                {
                    _20506 = _6255 / _6257.xxxx;
                }
                else
                {
                    bool _6268 = _20433.y == 0.0f;
                    bool _6274;
                    if (_6268)
                    {
                        _6274 = _20433.x > 0.0f;
                    }
                    else
                    {
                        _6274 = _6268;
                    }
                    bool _6279;
                    if (_6274)
                    {
                        bool _12171 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                        bool _12177;
                        if (_12171)
                        {
                            _12177 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12177 = _12171;
                        }
                        _6279 = _12177;
                    }
                    else
                    {
                        _6279 = _6274;
                    }
                    float4 _20507;
                    if (_6279)
                    {
                        _20507 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6284 = _20433.x == 0.0f;
                        bool _6290;
                        if (_6284)
                        {
                            _6290 = _20433.y > 0.0f;
                        }
                        else
                        {
                            _6290 = _6284;
                        }
                        bool _6295;
                        if (_6290)
                        {
                            bool _12182 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                            bool _12188;
                            if (_12182)
                            {
                                _12188 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12188 = _12182;
                            }
                            _6295 = _12188;
                        }
                        else
                        {
                            _6295 = _6290;
                        }
                        bool4 _23651 = _6295.xxxx;
                        _20507 = float4(_23651.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20322.x, _23651.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20322.y, _23651.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20322.z, _23651.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20322.w);
                    }
                    _20506 = _20507;
                }
                _20505 = _20506;
            }
            else
            {
                _20505 = _20322;
            }
            _20504 = _20505;
        }
        else
        {
            _20504 = _20327;
        }
        float4 _21234;
        bool _21540;
        float3 _21730;
        if (((cbFI_pad0 & 32768u) != 0u) && _6004)
        {
            bool _6312 = _20504.x > 0.00999999977648258209228515625f;
            bool _6315 = _20504.y > 0.00999999977648258209228515625f;
            bool _6324 = (_20504.z + _20504.w) > 0.0199999995529651641845703125f;
            bool _6330;
            if (_6324)
            {
                bool _12193 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _12199;
                if (_12193)
                {
                    _12199 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _12199 = _12193;
                }
                _6330 = _12199;
            }
            else
            {
                _6330 = _6324;
            }
            bool _6335;
            if (_6330)
            {
                bool _12204 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                bool _12210;
                if (_12204)
                {
                    _12210 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                }
                else
                {
                    _12210 = _12204;
                }
                _6335 = _12210;
            }
            else
            {
                _6335 = _6330;
            }
            bool _6342;
            if (_6335)
            {
                float _20520;
                do
                {
                    bool _12293 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _12299;
                    if (_12293)
                    {
                        _12299 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12299 = _12293;
                    }
                    bool _12230 = !_12299;
                    bool _12237;
                    if (!_12230)
                    {
                        bool _12304 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                        bool _12310;
                        if (_12304)
                        {
                            _12310 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12310 = _12304;
                        }
                        _12237 = !_12310;
                    }
                    else
                    {
                        _12237 = _12230;
                    }
                    if (_12237)
                    {
                        _20520 = 0.0f;
                        break;
                    }
                    uint _12317_dummy_parameter;
                    uint _12333_dummy_parameter;
                    float4x4 _20519;
                    do
                    {
                        float4x4 _12347;
                        bool _20518;
                        do
                        {
                            _12347 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20518 = false;
                                break;
                            }
                            uint _12381 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12381 + 32u) * 4 + 0) != 1u)
                            {
                                _20518 = false;
                                break;
                            }
                            uint _20515;
                            _20515 = 0u;
                            for (; _20515 < 4u; _20515++)
                            {
                                for (uint _20516 = 0u; _20516 < 4u; )
                                {
                                    _12347[_20515][_20516] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12381 + 16u) + (_20515 * 4u)) + _20516) * 4 + 0));
                                    _20516++;
                                    continue;
                                }
                            }
                            _20518 = true;
                            break;
                        } while(false);
                        if (_20518)
                        {
                            _20519 = _12347;
                            break;
                        }
                        _20519 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12258 = mul(float4((float2(_19754.x, 1.0f - _19754.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12317_dummy_parameter))))), 0)).x, 1.0f), _20519);
                    float _12260 = _12258.w;
                    if (abs(_12260) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20520 = 0.0f;
                        break;
                    }
                    float _12271 = abs(cbFI_DeviceToViewDepth.y / ((_12258.z / _12260) - cbFI_DeviceToViewDepth.x));
                    float _12274 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12333_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20520 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12271 - _12274) / max(max(_12271, _12274), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6342 = _20520 < 0.5f;
            }
            else
            {
                _6342 = _6335;
            }
            float4 _20539;
            if (_6342)
            {
                uint _12485_dummy_parameter;
                uint _12516_dummy_parameter;
                float4 _20540;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12485_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12516_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20540 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20540 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20539 = _20540;
            }
            else
            {
                _20539 = 1.0f.xxxx;
            }
            bool _6366;
            if (_10950)
            {
                bool _12545 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                bool _12551;
                if (_12545)
                {
                    _12551 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                }
                else
                {
                    _12551 = _12545;
                }
                _6366 = _12551;
            }
            else
            {
                _6366 = _10950;
            }
            bool _6372;
            if (_10950)
            {
                bool _12556 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _12562;
                if (_12556)
                {
                    _12562 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _12562 = _12556;
                }
                _6372 = _12562;
            }
            else
            {
                _6372 = _10950;
            }
            bool _6378;
            if (_10982)
            {
                bool _12567 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _12573;
                if (_12567)
                {
                    _12573 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _12573 = _12567;
                }
                _6378 = _12573;
            }
            else
            {
                _6378 = _10982;
            }
            bool _6384;
            if (_10982)
            {
                bool _12578 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                bool _12584;
                if (_12578)
                {
                    _12584 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                }
                else
                {
                    _12584 = _12578;
                }
                _6384 = _12584;
            }
            else
            {
                _6384 = _10982;
            }
            bool _6387 = _6378 != _6384;
            bool _6393;
            if (_6387)
            {
                _6393 = _6366 || _6372;
            }
            else
            {
                _6393 = _6387;
            }
            float4 _20642;
            if (_6393)
            {
                float4 _19480 = _20539;
                _19480.z = 0.0f;
                _19480.w = 0.0f;
                _20642 = _19480;
            }
            else
            {
                _20642 = _20539;
            }
            bool _6400 = _6366 && _6312;
            bool _6403 = _6372 && _6315;
            float4 _20747;
            float3 _21839;
            if (_6400 || _6403)
            {
                float _20637;
                do
                {
                    uint4 _12723 = r_warped_motion_qdata_tp1.Load(int3(_19972, 0));
                    uint _12724 = _12723.x;
                    if (_12724 != 0u)
                    {
                        float _20636;
                        if (_12724 == 0u)
                        {
                            _20636 = -1.0f;
                        }
                        else
                        {
                            _20636 = float((_12724 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20637 = _20636;
                        break;
                    }
                    int _20619;
                    uint _20620;
                    _20620 = _12724;
                    _20619 = -1;
                    uint _20635;
                    for (; _20619 <= 1; _20620 = _20635, _20619++)
                    {
                        _20635 = _20620;
                        for (int _20633 = -1; _20633 <= 1; )
                        {
                            _20635 = max(_20635, r_warped_motion_qdata_tp1.Load(int3(clamp(_19972 + int2(_20633, _20619), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20633++;
                            continue;
                        }
                    }
                    if (_20620 != 0u)
                    {
                        float _20632;
                        if (_20620 == 0u)
                        {
                            _20632 = -1.0f;
                        }
                        else
                        {
                            _20632 = float((_20620 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20637 = _20632;
                        break;
                    }
                    uint _20622;
                    _20622 = 4294967295u;
                    uint _23280;
                    for (int _20621 = 0; _20621 < 8; _20622 = _23280, _20621++)
                    {
                        int _20625 = 0;
                        for (;;)
                        {
                            if (_20625 < 5)
                            {
                                int2 _12674 = _19972 + (_1240[_20621] * _1249[_20625].xx);
                                bool _12677 = any(bool2(_12674.x < int2(0, 0).x, _12674.y < int2(0, 0).y));
                                bool _12685;
                                if (!_12677)
                                {
                                    _12685 = any(bool2(_12674.x >= cbFI_MvDepthLaneSize.x, _12674.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12685 = _12677;
                                }
                                if (_12685)
                                {
                                    _23280 = _20622;
                                    break;
                                }
                                uint4 _12763 = r_warped_motion_qdata_tp1.Load(int3(_12674, 0));
                                uint _12764 = _12763.x;
                                if (_12764 != 0u)
                                {
                                    _23280 = min(_20622, _12764);
                                    break;
                                }
                                _20625++;
                                continue;
                            }
                            else
                            {
                                _23280 = _20622;
                                break;
                            }
                        }
                    }
                    float _20624;
                    if (_20622 == 4294967295u)
                    {
                        _20624 = -1.0f;
                    }
                    else
                    {
                        float _20623;
                        if (_20622 == 0u)
                        {
                            _20623 = -1.0f;
                        }
                        else
                        {
                            _20623 = float((_20622 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20624 = _20623;
                    }
                    _20637 = _20624;
                    break;
                } while(false);
                bool _6411 = _20637 < 0.0f;
                float _20638;
                if (_6411)
                {
                    _20638 = 0.0f;
                }
                else
                {
                    _20638 = _20637 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12785_dummy_parameter;
                uint _12817_dummy_parameter;
                float4 _20675;
                if ((_6411 && _6400) && _6403)
                {
                    uint _12849_dummy_parameter;
                    float _12873 = log(((r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12849_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12881_dummy_parameter;
                    float _12905 = log(((r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12881_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20676;
                    if (_12873 > (_12905 + 0.07999999821186065673828125f))
                    {
                        float4 _19484 = _20642;
                        _19484.x = 0.0f;
                        _20676 = _19484;
                    }
                    else
                    {
                        float4 _20677;
                        if (_12905 > (_12873 + 0.07999999821186065673828125f))
                        {
                            float4 _19486 = _20642;
                            _19486.y = 0.0f;
                            _20677 = _19486;
                        }
                        else
                        {
                            _20677 = _20642;
                        }
                        _20676 = _20677;
                    }
                    _20675 = _20676;
                }
                else
                {
                    _20675 = _20642;
                }
                float _6463 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6465 = _20637 >= 0.0f;
                float _20658;
                if (_6465)
                {
                    _20658 = _20637 - _6463;
                }
                else
                {
                    float _20654;
                    if (_6400)
                    {
                        float _20653;
                        _20653 = 2.0f;
                        float _12963;
                        for (int _20652 = 0; _20652 < 24; _20653 = _12963, _20652++)
                        {
                            float _12927 = float(_20652 & 7) * 0.785398185253143310546875f;
                            int _12929 = _20652 >> 3;
                            int _20655;
                            if (_12929 == 0)
                            {
                                _20655 = 16;
                            }
                            else
                            {
                                _20655 = (_12929 == 1) ? 48 : 96;
                            }
                            uint _12979_dummy_parameter;
                            _12963 = min(_20653, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19751 + ((cbFI_MvDepthLaneSizeRcp * float(_20655)) * float2(cos(_12927), sin(_12927))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12979_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20654 = _20653;
                    }
                    else
                    {
                        _20654 = 0.0f;
                    }
                    _20658 = _20654;
                }
                float _20665;
                if (_6465)
                {
                    _20665 = _20637 - _6463;
                }
                else
                {
                    float _20661;
                    if (_6403)
                    {
                        float _20660;
                        _20660 = 2.0f;
                        float _13077;
                        for (int _20659 = 0; _20659 < 24; _20660 = _13077, _20659++)
                        {
                            float _13041 = float(_20659 & 7) * 0.785398185253143310546875f;
                            int _13043 = _20659 >> 3;
                            int _20662;
                            if (_13043 == 0)
                            {
                                _20662 = 16;
                            }
                            else
                            {
                                _20662 = (_13043 == 1) ? 48 : 96;
                            }
                            uint _13109_dummy_parameter;
                            _13077 = min(_20660, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19753 + ((cbFI_MvDepthLaneSizeRcp * float(_20662)) * float2(cos(_13041), sin(_13041))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13109_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20661 = _20660;
                    }
                    else
                    {
                        _20661 = 0.0f;
                    }
                    _20665 = _20661;
                }
                float _20666;
                if (_6400)
                {
                    uint _13141_dummy_parameter;
                    _20666 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13141_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20666 = 0.0f;
                }
                float _20667;
                if (_6403)
                {
                    uint _13161_dummy_parameter;
                    _20667 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13161_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20667 = 0.0f;
                }
                bool _6520;
                if (_6400)
                {
                    _6520 = _20666 > ((exp((_20658 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6520 = _6400;
                }
                float4 _20683;
                if (_6520)
                {
                    float4 _19488 = _20675;
                    _19488.x = 0.0f;
                    _20683 = _19488;
                }
                else
                {
                    _20683 = _20675;
                }
                bool _6532;
                if (_6403)
                {
                    _6532 = _20667 > ((exp((_20665 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6532 = _6403;
                }
                float4 _20685;
                if (_6532)
                {
                    float4 _19490 = _20683;
                    _19490.y = 0.0f;
                    _20685 = _19490;
                }
                else
                {
                    _20685 = _20683;
                }
                float4 _20748;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6465)
                {
                    bool _6552;
                    if (_6400)
                    {
                        _6552 = _20666 < ((exp((_20658 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6552 = _6400;
                    }
                    float4 _20687;
                    if (_6552)
                    {
                        float4 _19492 = _20685;
                        _19492.x = 0.0f;
                        _20687 = _19492;
                    }
                    else
                    {
                        _20687 = _20685;
                    }
                    bool _6564;
                    if (_6403)
                    {
                        _6564 = _20667 < ((exp((_20665 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6564 = _6403;
                    }
                    float4 _20749;
                    if (_6564)
                    {
                        float4 _19494 = _20687;
                        _19494.y = 0.0f;
                        _20749 = _19494;
                    }
                    else
                    {
                        _20749 = _20687;
                    }
                    _20748 = _20749;
                }
                else
                {
                    _20748 = _20685;
                }
                _21839 = float3(_20638, log(((r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12785_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12817_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20747 = _20748;
            }
            else
            {
                _21839 = float3(0.0f, 0.0f, 0.5f);
                _20747 = _20642;
            }
            bool _6575 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6324;
            bool _6581;
            if (_6575)
            {
                _6581 = _6378 || _6384;
            }
            else
            {
                _6581 = _6575;
            }
            float4 _20790;
            if (_6581)
            {
                float _20742;
                do
                {
                    uint4 _13341 = r_warped_motion_qdata_tp1.Load(int3(_19972, 0));
                    uint _13342 = _13341.x;
                    if (_13342 != 0u)
                    {
                        float _20741;
                        if (_13342 == 0u)
                        {
                            _20741 = -1.0f;
                        }
                        else
                        {
                            _20741 = float((_13342 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20742 = _20741;
                        break;
                    }
                    int _20724;
                    uint _20725;
                    _20725 = _13342;
                    _20724 = -1;
                    uint _20740;
                    for (; _20724 <= 1; _20725 = _20740, _20724++)
                    {
                        _20740 = _20725;
                        for (int _20738 = -1; _20738 <= 1; )
                        {
                            _20740 = max(_20740, r_warped_motion_qdata_tp1.Load(int3(clamp(_19972 + int2(_20738, _20724), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20738++;
                            continue;
                        }
                    }
                    if (_20725 != 0u)
                    {
                        float _20737;
                        if (_20725 == 0u)
                        {
                            _20737 = -1.0f;
                        }
                        else
                        {
                            _20737 = float((_20725 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20742 = _20737;
                        break;
                    }
                    uint _20727;
                    _20727 = 4294967295u;
                    uint _23281;
                    for (int _20726 = 0; _20726 < 8; _20727 = _23281, _20726++)
                    {
                        int _20730 = 0;
                        for (;;)
                        {
                            if (_20730 < 5)
                            {
                                int2 _13292 = _19972 + (_1240[_20726] * _1249[_20730].xx);
                                bool _13295 = any(bool2(_13292.x < int2(0, 0).x, _13292.y < int2(0, 0).y));
                                bool _13303;
                                if (!_13295)
                                {
                                    _13303 = any(bool2(_13292.x >= cbFI_MvDepthLaneSize.x, _13292.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13303 = _13295;
                                }
                                if (_13303)
                                {
                                    _23281 = _20727;
                                    break;
                                }
                                uint4 _13381 = r_warped_motion_qdata_tp1.Load(int3(_13292, 0));
                                uint _13382 = _13381.x;
                                if (_13382 != 0u)
                                {
                                    _23281 = min(_20727, _13382);
                                    break;
                                }
                                _20730++;
                                continue;
                            }
                            else
                            {
                                _23281 = _20727;
                                break;
                            }
                        }
                    }
                    float _20729;
                    if (_20727 == 4294967295u)
                    {
                        _20729 = -1.0f;
                    }
                    else
                    {
                        float _20728;
                        if (_20727 == 0u)
                        {
                            _20728 = -1.0f;
                        }
                        else
                        {
                            _20728 = float((_20727 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20729 = _20728;
                    }
                    _20742 = _20729;
                    break;
                } while(false);
                float4 _20791;
                if (_20742 >= 0.0f)
                {
                    float _13403 = (exp((_20742 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6600;
                    if (_6378)
                    {
                        uint _13410_dummy_parameter;
                        _6600 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13410_dummy_parameter))))), 0)).x) > _13403;
                    }
                    else
                    {
                        _6600 = _6378;
                    }
                    float4 _20760;
                    if (_6600)
                    {
                        float4 _19496 = _20747;
                        _19496.z = 0.0f;
                        _20760 = _19496;
                    }
                    else
                    {
                        _20760 = _20747;
                    }
                    bool _6612;
                    if (_6384)
                    {
                        uint _13430_dummy_parameter;
                        _6612 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13430_dummy_parameter))))), 0)).x) > _13403;
                    }
                    else
                    {
                        _6612 = _6384;
                    }
                    float4 _20792;
                    if (_6612)
                    {
                        float4 _19498 = _20760;
                        _19498.w = 0.0f;
                        _20792 = _19498;
                    }
                    else
                    {
                        _20792 = _20760;
                    }
                    _20791 = _20792;
                }
                else
                {
                    _20791 = _20747;
                }
                _20790 = _20791;
            }
            else
            {
                _20790 = _20747;
            }
            bool _6620 = _6366 != _6372;
            bool _6627;
            if (_6620)
            {
                _6627 = _6366 ? _6312 : _6315;
            }
            else
            {
                _6627 = _6620;
            }
            bool _6634;
            if (_6627)
            {
                _6634 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6634 = _6627;
            }
            float4 _20893;
            if (_6634)
            {
                bool2 _6639 = _6366.xx;
                float2 _6640 = float2(_6639.x ? _19751.x : _19753.x, _6639.y ? _19751.y : _19753.y);
                float _20774;
                if (_6366)
                {
                    uint _13450_dummy_parameter;
                    _20774 = r_depth_tm1.Load(int3(int2(floor(_6640 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13450_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13466_dummy_parameter;
                    _20774 = r_depth_tp1.Load(int3(int2(floor(_6640 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13466_dummy_parameter))))), 0)).x;
                }
                float4x4 _20781;
                if (_6366)
                {
                    float4x4 _20770;
                    do
                    {
                        float4x4 _13480;
                        bool _20769;
                        do
                        {
                            _13480 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20769 = false;
                                break;
                            }
                            uint _13514 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13514 + 32u) * 4 + 0) != 1u)
                            {
                                _20769 = false;
                                break;
                            }
                            uint _20766;
                            _20766 = 0u;
                            for (; _20766 < 4u; _20766++)
                            {
                                for (uint _20767 = 0u; _20767 < 4u; )
                                {
                                    _13480[_20766][_20767] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13514 + 16u) + (_20766 * 4u)) + _20767) * 4 + 0));
                                    _20767++;
                                    continue;
                                }
                            }
                            _20769 = true;
                            break;
                        } while(false);
                        if (_20769)
                        {
                            _20770 = _13480;
                            break;
                        }
                        _20770 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20781 = _20770;
                }
                else
                {
                    float4x4 _20765;
                    do
                    {
                        float4x4 _13586;
                        bool _20764;
                        do
                        {
                            _13586 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20764 = false;
                                break;
                            }
                            uint _13620 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13620 + 32u) * 4 + 0) != 1u)
                            {
                                _20764 = false;
                                break;
                            }
                            uint _20761;
                            _20761 = 0u;
                            for (; _20761 < 4u; _20761++)
                            {
                                for (uint _20762 = 0u; _20762 < 4u; )
                                {
                                    _13586[_20761][_20762] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13620 + (_20761 * 4u)) + _20762) * 4 + 0));
                                    _20762++;
                                    continue;
                                }
                            }
                            _20764 = true;
                            break;
                        } while(false);
                        if (_20764)
                        {
                            _20765 = _13586;
                            break;
                        }
                        _20765 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20781 = _20765;
                }
                float2 _20782;
                do
                {
                    float _13697 = _6640.x;
                    float _13700 = 1.0f - _6640.y;
                    float4 _13711 = mul(float4((float2(_13697, _13700) * 2.0f) - 1.0f.xx, _20774, 1.0f), _20781);
                    float _13713 = _13711.w;
                    if (!(_13713 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20782 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13726 = ((_13711.xy / _13713.xx) + 1.0f.xx) * 0.5f;
                    _20782 = float2(_13726.x - _13697, _13700 - _13726.y);
                    break;
                } while(false);
                float2 _6670 = float2(cbFI_DisplaySize);
                float4 _20894;
                if (!(length(((_6640 + _20782) - float2(_6639.x ? _19753.x : _19751.x, _6639.y ? _19753.y : _19751.y)) * _6670) <= ((0.100000001490116119384765625f * length(_20782 * _6670)) + 8.0f)))
                {
                    float4 _20895;
                    if (_6366)
                    {
                        float4 _19508 = _20790;
                        _19508.x = 0.0f;
                        _20895 = _19508;
                    }
                    else
                    {
                        float4 _19510 = _20790;
                        _19510.y = 0.0f;
                        _20895 = _19510;
                    }
                    _20894 = _20895;
                }
                else
                {
                    _20894 = _20790;
                }
                _20893 = _20894;
            }
            else
            {
                _20893 = _20790;
            }
            float4 _6695 = _20504 * _20893;
            float _6697 = dot(_6695, 1.0f.xxxx);
            float4 _21235;
            bool _21541;
            if (_6697 > 0.0f)
            {
                _21541 = _20195;
                _21235 = _6695 / _6697.xxxx;
            }
            else
            {
                bool _6708 = any(bool4(_20893.x < 1.0f.xxxx.x, _20893.y < 1.0f.xxxx.y, _20893.z < 1.0f.xxxx.z, _20893.w < 1.0f.xxxx.w));
                if (_6708)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13748;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13748);
                    }
                }
                bool4 _23654 = _6708.xxxx;
                _21541 = _6708 ? true : _20195;
                _21235 = float4(_23654.x ? 0.0f.xxxx.x : _20504.x, _23654.y ? 0.0f.xxxx.y : _20504.y, _23654.z ? 0.0f.xxxx.z : _20504.z, _23654.w ? 0.0f.xxxx.w : _20504.w);
            }
            _21730 = _21839;
            _21540 = _21541;
            _21234 = _21235;
        }
        else
        {
            _21730 = float3(0.0f, 0.0f, 0.5f);
            _21540 = _20195;
            _21234 = _20504;
        }
        uint _6717 = (cbFI_pad0 >> 24u) & 31u;
        uint _6721 = (cbFI_pad0 >> 16u) & 255u;
        bool _6723 = _6717 != 0u;
        bool _6725 = _6721 == 12u;
        bool _6728 = _6721 == 13u;
        float4 _21255;
        if ((_6723 || _6725) || _6728)
        {
            float _20901;
            do
            {
                bool _13832 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _13838;
                if (_13832)
                {
                    _13838 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _13838 = _13832;
                }
                bool _13769 = !_13838;
                bool _13776;
                if (!_13769)
                {
                    bool _13843 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
                    bool _13849;
                    if (_13843)
                    {
                        _13849 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13849 = _13843;
                    }
                    _13776 = !_13849;
                }
                else
                {
                    _13776 = _13769;
                }
                if (_13776)
                {
                    _20901 = 0.0f;
                    break;
                }
                uint _13856_dummy_parameter;
                uint _13872_dummy_parameter;
                float4x4 _20900;
                do
                {
                    float4x4 _13886;
                    bool _20899;
                    do
                    {
                        _13886 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20899 = false;
                            break;
                        }
                        uint _13920 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13920 + 32u) * 4 + 0) != 1u)
                        {
                            _20899 = false;
                            break;
                        }
                        uint _20896;
                        _20896 = 0u;
                        for (; _20896 < 4u; _20896++)
                        {
                            for (uint _20897 = 0u; _20897 < 4u; )
                            {
                                _13886[_20896][_20897] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13920 + 16u) + (_20896 * 4u)) + _20897) * 4 + 0));
                                _20897++;
                                continue;
                            }
                        }
                        _20899 = true;
                        break;
                    } while(false);
                    if (_20899)
                    {
                        _20900 = _13886;
                        break;
                    }
                    _20900 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13797 = mul(float4((float2(_19754.x, 1.0f - _19754.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13856_dummy_parameter))))), 0)).x, 1.0f), _20900);
                float _13799 = _13797.w;
                if (abs(_13799) < 9.9999999747524270787835121154785e-07f)
                {
                    _20901 = 0.0f;
                    break;
                }
                float _13810 = abs(cbFI_DeviceToViewDepth.y / ((_13797.z / _13799) - cbFI_DeviceToViewDepth.x));
                float _13813 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13872_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20901 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13810 - _13813) / max(max(_13810, _13813), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14022 = all(bool2(_19755.x > 0.0f.xx.x, _19755.y > 0.0f.xx.y));
            bool _14028;
            if (_14022)
            {
                _14028 = all(bool2(_19755.x < 1.0f.xx.x, _19755.y < 1.0f.xx.y));
            }
            else
            {
                _14028 = _14022;
            }
            float _20902;
            if (_14028)
            {
                uint _14035_dummy_parameter;
                _20902 = length((_7848 + (r_motion_tp1.Load(int3(int2(floor(_19755 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14035_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20902 = 1000000.0f;
            }
            float _20917;
            if ((_6717 & 1u) != 0u)
            {
                _20917 = _20901;
            }
            else
            {
                _20917 = 1.0f;
            }
            float _20918;
            if ((_6717 & 2u) != 0u)
            {
                _20918 = _20917 * (1.0f - smoothstep(2.0f, 8.0f, _20902));
            }
            else
            {
                _20918 = _20917;
            }
            float _20919;
            if ((_6717 & 4u) != 0u)
            {
                _20919 = _20918 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8569 - _8577) - length(_8553 - _8561))));
            }
            else
            {
                _20919 = _20918;
            }
            float _21249;
            if ((_6717 & 8u) != 0u)
            {
                _21249 = lerp(1.0f, _20919, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8553 - _8561)));
            }
            else
            {
                _21249 = _20919;
            }
            bool _6803 = (_6717 & 16u) != 0u;
            bool _6812;
            if (_6803)
            {
                _6812 = length(_19749 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6812 = _6803;
            }
            float _23656 = _6812 ? 1.0f : _21249;
            bool _6818 = _6723 && _10950;
            bool _6823;
            if (_6818)
            {
                bool _14060 = all(bool2(_19751.x > 0.0f.xx.x, _19751.y > 0.0f.xx.y));
                bool _14066;
                if (_14060)
                {
                    _14066 = all(bool2(_19751.x < 1.0f.xx.x, _19751.y < 1.0f.xx.y));
                }
                else
                {
                    _14066 = _14060;
                }
                _6823 = _14066;
            }
            else
            {
                _6823 = _6818;
            }
            bool _6828;
            if (_6823)
            {
                bool _14071 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _14077;
                if (_14071)
                {
                    _14077 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _14077 = _14071;
                }
                _6828 = _14077;
            }
            else
            {
                _6828 = _6823;
            }
            float4 _21256;
            if (_6828)
            {
                float _6834 = _21234.x + _21234.y;
                float _6843 = (_21234.z + _21234.w) * (1.0f - _23656);
                float _21252;
                if (_6834 > 9.9999997473787516355514526367188e-06f)
                {
                    _21252 = _21234.x / _6834;
                }
                else
                {
                    _21252 = _5573;
                }
                _21256 = float4(_21234.x + (_6843 * _21252), _21234.y + (_6843 * (1.0f - _21252)), _21234.zw * _23656);
            }
            else
            {
                _21256 = _21234;
            }
            _21255 = _21256;
        }
        else
        {
            _21255 = _21234;
        }
        float3 _6904 = (((_8553 * _21255.x) + (_8561 * _21255.y)) + (_8569 * _21255.z)) + (_8577 * _21255.w);
        float3 _22855;
        if (_5589 && (_21270 > 0.0f))
        {
            uint _14084_dummy_parameter;
            float2 _14099 = r_motion_tp1.Load(int3(int2(floor(_5348 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14084_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21532;
            if (_7876)
            {
                float2 _14144 = clamp((((_19728 + (_14099 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14147 = tan(_14144.x);
                _21532 = (float2(_14147 / cbFI_DeviceToViewDepth.z, (tan(_14144.y) * sqrt(1.0f + (_14147 * _14147))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21532 = _19728 + (_14099 * cbFI_Timestep);
            }
            float2 _21533;
            if (_7876)
            {
                float2 _14223 = clamp((((_19728 + (_14099 * _5563)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14226 = tan(_14223.x);
                _21533 = (float2(_14226 / cbFI_DeviceToViewDepth.z, (tan(_14223.y) * sqrt(1.0f + (_14226 * _14226))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21533 = _19728 + (_14099 * _5563);
            }
            _22855 = lerp(_6904, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21532, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21533, 0.0f).xyz, cbFI_Timestep.xxx), _21270.xxx);
        }
        else
        {
            _22855 = _6904;
        }
        float3 _22854;
        if (_21540)
        {
            float3 _14268 = r_current_interpolation_source.Load(int3(_4849, 0)).xyz;
            float3 _22856;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10950)
            {
                uint _14275_dummy_parameter;
                float _21663;
                _21663 = r_depth_tm1.Load(int3(int2(floor(_19751 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14275_dummy_parameter))))), 0)).x;
                float _6985;
                for (int _21662 = 0; _21662 < 24; _21663 = _6985, _21662++)
                {
                    float _6957 = float(_21662 & 7) * 0.785398185253143310546875f;
                    int _6959 = _21662 >> 3;
                    int _23123;
                    if (_6959 == 0)
                    {
                        _23123 = 16;
                    }
                    else
                    {
                        _23123 = (_6959 == 1) ? 48 : 96;
                    }
                    uint _14295_dummy_parameter;
                    _6985 = max(_21663, r_depth_tm1.Load(int3(int2(floor(clamp(_19751 + ((cbFI_MvDepthLaneSizeRcp * float(_23123)) * float2(cos(_6957), sin(_6957))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14295_dummy_parameter))))), 0)).x);
                }
                float2 _21664;
                do
                {
                    float _14317 = 1.0f - _19751.y;
                    float4 _14328 = mul(float4((float2(_19751.x, _14317) * 2.0f) - 1.0f.xx, _21663, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14330 = _14328.w;
                    if (!(_14330 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21664 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14343 = ((_14328.xy / _14330.xx) + 1.0f.xx) * 0.5f;
                    _21664 = float2(_14343.x - _19751.x, _14317 - _14343.y);
                    break;
                } while(false);
                float2 _6996 = _19751 + _21664;
                bool _14361 = all(bool2(_6996.x > 0.0f.xx.x, _6996.y > 0.0f.xx.y));
                bool _14367;
                if (_14361)
                {
                    _14367 = all(bool2(_6996.x < 1.0f.xx.x, _6996.y < 1.0f.xx.y));
                }
                else
                {
                    _14367 = _14361;
                }
                float3 _22857;
                if (_14367)
                {
                    float _7002 = abs(cbFI_DeviceToViewDepth.y / (_21663 - cbFI_DeviceToViewDepth.x));
                    uint _14387_dummy_parameter;
                    int2 _14387 = int2(spvTextureSize(r_depth_m2, uint(0), _14387_dummy_parameter));
                    float _7006 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6996 * float2(_14387))), int2(0, 0), _14387 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22862;
                    if (abs(_7006 - _7002) <= (0.20000000298023223876953125f * max(_7006, _7002)))
                    {
                        uint _14421_dummy_parameter;
                        int2 _14421 = int2(spvTextureSize(r_colour_m2, uint(0), _14421_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14444;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14444);
                        }
                        _22862 = r_colour_m2.Load(int3(clamp(int2(floor(_6996 * float2(_14421))), int2(0, 0), _14421 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14454;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14454);
                        }
                        _22862 = _14268;
                    }
                    _22857 = _22862;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14464;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14464);
                    }
                    _22857 = _14268;
                }
                _22856 = _22857;
            }
            else
            {
                _22856 = _14268;
            }
            _22854 = _22856;
        }
        else
        {
            _22854 = _22855;
        }
        bool _7031 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22853;
        float _22929;
        if (_7031)
        {
            float _14641;
            float2 _7035 = float2(cbFI_DisplaySize);
            float3 _21721;
            do
            {
                bool _14702;
                float4x4 _21671;
                do
                {
                    float4x4 _14678;
                    bool _21670;
                    do
                    {
                        _14678 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14702 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14702)
                        {
                            _21670 = false;
                            break;
                        }
                        uint _14712 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14712 + 32u) * 4 + 0) != 1u)
                        {
                            _21670 = false;
                            break;
                        }
                        uint _21667;
                        _21667 = 0u;
                        for (; _21667 < 4u; _21667++)
                        {
                            for (uint _21668 = 0u; _21668 < 4u; )
                            {
                                _14678[_21667][_21668] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14712 + (_21667 * 4u)) + _21668) * 4 + 0));
                                _21668++;
                                continue;
                            }
                        }
                        _21670 = true;
                        break;
                    } while(false);
                    if (_21670)
                    {
                        _21671 = _14678;
                        break;
                    }
                    _21671 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14789;
                float _14792;
                float4 _14802;
                float2 _21672;
                do
                {
                    _14789 = _5348.x;
                    _14792 = 1.0f - _5348.y;
                    _14802 = float4((float2(_14789, _14792) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _14803 = mul(_14802, _21671);
                    float _14805 = _14803.w;
                    if (!(_14805 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21672 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14818 = ((_14803.xy / _14805.xx) + 1.0f.xx) * 0.5f;
                    _21672 = float2(_14818.x - _14789, _14792 - _14818.y);
                    break;
                } while(false);
                float4x4 _21677;
                do
                {
                    float4x4 _14836;
                    bool _21676;
                    do
                    {
                        _14836 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14702)
                        {
                            _21676 = false;
                            break;
                        }
                        uint _14870 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14870 + 32u) * 4 + 0) != 1u)
                        {
                            _21676 = false;
                            break;
                        }
                        uint _21673;
                        _21673 = 0u;
                        for (; _21673 < 4u; _21673++)
                        {
                            for (uint _21674 = 0u; _21674 < 4u; )
                            {
                                _14836[_21673][_21674] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14870 + 16u) + (_21673 * 4u)) + _21674) * 4 + 0));
                                _21674++;
                                continue;
                            }
                        }
                        _21676 = true;
                        break;
                    } while(false);
                    if (_21676)
                    {
                        _21677 = _14836;
                        break;
                    }
                    _21677 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21678;
                do
                {
                    float4 _14961 = mul(_14802, _21677);
                    float _14963 = _14961.w;
                    if (!(_14963 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21678 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14976 = ((_14961.xy / _14963.xx) + 1.0f.xx) * 0.5f;
                    _21678 = float2(_14976.x - _14789, _14792 - _14976.y);
                    break;
                } while(false);
                float2 _14519 = abs(_21672);
                bool2 _23657 = any(bool2(_14519.x > 4.0f.xx.x, _14519.y > 4.0f.xx.y)).xx;
                float2 _14525 = abs(_21678);
                bool2 _23659 = any(bool2(_14525.x > 4.0f.xx.x, _14525.y > 4.0f.xx.y)).xx;
                float2 _14990[3];
                _14990[0] = _5348;
                float2 _15106 = clamp(_5348, 0.0f.xx, 1.0f.xx);
                uint _15114_dummy_parameter;
                _14990[1] = _5348 - ((r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15114_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5573);
                _14990[2] = _5348 - (float2(_23657.x ? 0.0f.xx.x : _21672.x, _23657.y ? 0.0f.xx.y : _21672.y) * _5573);
                float _21688;
                float2 _21689;
                _21689 = _5348;
                _21688 = 1000000000.0f;
                float _23661;
                float2 _23663;
                float _23664;
                int _21687 = 0;
                float _23115 = -1.0f;
                for (; _21687 < 3; _23115 = _23661, _21689 = _23663, _21688 = _23664, _21687++)
                {
                    float2 _23105;
                    _23105 = _14990[_21687];
                    for (int _23104 = 0; _23104 < 30; )
                    {
                        uint _15730_dummy_parameter;
                        _23105 += (((_5348 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23105, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15730_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5573)) - _23105) * 0.699999988079071044921875f);
                        _23104++;
                        continue;
                    }
                    float2 _16266 = clamp(_23105, 0.0f.xx, 1.0f.xx);
                    uint _16274_dummy_parameter;
                    bool _16810 = all(bool2(_23105.x > 0.0f.xx.x, _23105.y > 0.0f.xx.y));
                    bool _16816;
                    if (_16810)
                    {
                        _16816 = all(bool2(_23105.x < 1.0f.xx.x, _23105.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16816 = _16810;
                    }
                    float _23107;
                    if (_16816)
                    {
                        _23107 = length(((_23105 + ((r_motion_tp1.Load(int3(int2(floor(_16266 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16274_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5573)) - _5348) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23107 = 1000000000.0f;
                    }
                    uint _16827_dummy_parameter;
                    float _16867 = log(((r_depth_tp1.Load(int3(int2(floor(_16266 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16827_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15066 = _23107 < 0.3499999940395355224609375f;
                    bool _15068 = _21688 < 0.3499999940395355224609375f;
                    bool _15078;
                    if (_15066)
                    {
                        _15078 = (!_15068) || (_16867 > _23115);
                    }
                    else
                    {
                        _15078 = _15066;
                    }
                    bool _15091;
                    if (!_15078)
                    {
                        _15091 = ((!_15066) && (!_15068)) && (_23107 < _21688);
                    }
                    else
                    {
                        _15091 = _15078;
                    }
                    _23661 = _15091 ? _16867 : _23115;
                    bool2 _23662 = _15091.xx;
                    _23663 = float2(_23662.x ? _23105.x : _21689.x, _23662.y ? _23105.y : _21689.y);
                    _23664 = _15091 ? _23107 : _21688;
                }
                float2 _16869[3];
                _16869[0] = _5348;
                float2 _21717;
                do
                {
                    bool _21698;
                    do
                    {
                        bool _17112 = all(bool2(_15106.x > 0.0f.xx.x, _15106.y > 0.0f.xx.y));
                        bool _17118;
                        if (_17112)
                        {
                            _17118 = all(bool2(_15106.x < 1.0f.xx.x, _15106.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17118 = _17112;
                        }
                        if (!_17118)
                        {
                            _21698 = false;
                            break;
                        }
                        uint _17125_dummy_parameter;
                        float4x4 _21696;
                        do
                        {
                            float4x4 _17139;
                            bool _21695;
                            do
                            {
                                _17139 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14702)
                                {
                                    _21695 = false;
                                    break;
                                }
                                uint _17173 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17173 + 32u) * 4 + 0) != 1u)
                                {
                                    _21695 = false;
                                    break;
                                }
                                uint _21692;
                                _21692 = 0u;
                                for (; _21692 < 4u; _21692++)
                                {
                                    for (uint _21693 = 0u; _21693 < 4u; )
                                    {
                                        _17139[_21692][_21693] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17173 + (_21692 * 4u)) + _21693) * 4 + 0));
                                        _21693++;
                                        continue;
                                    }
                                }
                                _21695 = true;
                                break;
                            } while(false);
                            if (_21695)
                            {
                                _21696 = _17139;
                                break;
                            }
                            _21696 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21697;
                        do
                        {
                            float _17250 = _15106.x;
                            float _17253 = 1.0f - _15106.y;
                            float4 _17264 = mul(float4((float2(_17250, _17253) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17125_dummy_parameter))))), 0)).x, 1.0f), _21696);
                            float _17266 = _17264.w;
                            if (!(_17266 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21697 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17279 = ((_17264.xy / _17266.xx) + 1.0f.xx) * 0.5f;
                            _21697 = float2(_17279.x - _17250, _17253 - _17279.y);
                            break;
                        } while(false);
                        float2 _17076 = abs(_21697);
                        if (any(bool2(_17076.x > 100000.0f.xx.x, _17076.y > 100000.0f.xx.y)))
                        {
                            _21698 = false;
                            break;
                        }
                        float _17084 = length(_21697 * _7035);
                        uint _17299_dummy_parameter;
                        bool _17098 = _17084 > ((8.0f * _7035.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17105;
                        if (_17098)
                        {
                            _17105 = length((r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17299_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7035) < (0.20000000298023223876953125f * _17084);
                        }
                        else
                        {
                            _17105 = _17098;
                        }
                        _21698 = _17105;
                        break;
                    } while(false);
                    if (_21698)
                    {
                        uint _17330_dummy_parameter;
                        _21717 = -(r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17330_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17357_dummy_parameter;
                    float4x4 _21711;
                    do
                    {
                        float4x4 _17371;
                        bool _21710;
                        do
                        {
                            _17371 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14702)
                            {
                                _21710 = false;
                                break;
                            }
                            uint _17405 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17405 + 32u) * 4 + 0) != 1u)
                            {
                                _21710 = false;
                                break;
                            }
                            uint _21707;
                            _21707 = 0u;
                            for (; _21707 < 4u; _21707++)
                            {
                                for (uint _21708 = 0u; _21708 < 4u; )
                                {
                                    _17371[_21707][_21708] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17405 + 16u) + (_21707 * 4u)) + _21708) * 4 + 0));
                                    _21708++;
                                    continue;
                                }
                            }
                            _21710 = true;
                            break;
                        } while(false);
                        if (_21710)
                        {
                            _21711 = _17371;
                            break;
                        }
                        _21711 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _21716;
                    do
                    {
                        float _17482 = _15106.x;
                        float _17485 = 1.0f - _15106.y;
                        float4 _17496 = mul(float4((float2(_17482, _17485) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17357_dummy_parameter))))), 0)).x, 1.0f), _21711);
                        float _17498 = _17496.w;
                        if (!(_17498 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21716 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17511 = ((_17496.xy / _17498.xx) + 1.0f.xx) * 0.5f;
                        _21716 = float2(_17511.x - _17482, _17485 - _17511.y);
                        break;
                    } while(false);
                    float2 _17043 = abs(_21716);
                    bool2 _17047 = any(bool2(_17043.x > 4.0f.xx.x, _17043.y > 4.0f.xx.y)).xx;
                    _21717 = float2(_17047.x ? 0.0f.xx.x : _21716.x, _17047.y ? 0.0f.xx.y : _21716.y);
                    break;
                } while(false);
                _16869[1] = _5348 - (_21717 * cbFI_Timestep);
                _16869[2] = _5348 - (float2(_23659.x ? 0.0f.xx.x : _21678.x, _23659.y ? 0.0f.xx.y : _21678.y) * cbFI_Timestep);
                float _21719;
                float2 _21720;
                _21720 = _5348;
                _21719 = 1000000000.0f;
                float _23665;
                float2 _23667;
                float _23668;
                float4x4 _17755;
                float4x4 _17987;
                float4x4 _18299;
                float4x4 _18531;
                int _21718 = 0;
                float _23017 = -1.0f;
                for (; _21718 < 3; _23017 = _23665, _21720 = _23667, _21719 = _23668, _21718++)
                {
                    float2 _22950;
                    _22950 = _16869[_21718];
                    float2 _17565;
                    for (int _22949 = 0; _22949 < 30; _22950 = _17565, _22949++)
                    {
                        float2 _23075;
                        do
                        {
                            float2 _17644 = clamp(_22950, 0.0f.xx, 1.0f.xx);
                            bool _23056;
                            do
                            {
                                bool _17728 = all(bool2(_17644.x > 0.0f.xx.x, _17644.y > 0.0f.xx.y));
                                bool _17734;
                                if (_17728)
                                {
                                    _17734 = all(bool2(_17644.x < 1.0f.xx.x, _17644.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17734 = _17728;
                                }
                                if (!_17734)
                                {
                                    _23056 = false;
                                    break;
                                }
                                uint _17741_dummy_parameter;
                                float4x4 _23054;
                                do
                                {
                                    bool _23053;
                                    do
                                    {
                                        _17755 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14702)
                                        {
                                            _23053 = false;
                                            break;
                                        }
                                        uint _17789 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17789 + 32u) * 4 + 0) != 1u)
                                        {
                                            _23053 = false;
                                            break;
                                        }
                                        uint _23050;
                                        _23050 = 0u;
                                        for (; _23050 < 4u; _23050++)
                                        {
                                            for (uint _23051 = 0u; _23051 < 4u; )
                                            {
                                                _17755[_23050][_23051] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17789 + (_23050 * 4u)) + _23051) * 4 + 0));
                                                _23051++;
                                                continue;
                                            }
                                        }
                                        _23053 = true;
                                        break;
                                    } while(false);
                                    if (_23053)
                                    {
                                        _23054 = _17755;
                                        break;
                                    }
                                    _23054 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _23055;
                                do
                                {
                                    float _17866 = _17644.x;
                                    float _17869 = 1.0f - _17644.y;
                                    float4 _17880 = mul(float4((float2(_17866, _17869) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17644 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17741_dummy_parameter))))), 0)).x, 1.0f), _23054);
                                    float _17882 = _17880.w;
                                    if (!(_17882 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _23055 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17895 = ((_17880.xy / _17882.xx) + 1.0f.xx) * 0.5f;
                                    _23055 = float2(_17895.x - _17866, _17869 - _17895.y);
                                    break;
                                } while(false);
                                float2 _17692 = abs(_23055);
                                if (any(bool2(_17692.x > 100000.0f.xx.x, _17692.y > 100000.0f.xx.y)))
                                {
                                    _23056 = false;
                                    break;
                                }
                                float _17700 = length(_23055 * _7035);
                                uint _17915_dummy_parameter;
                                bool _17714 = _17700 > ((8.0f * _7035.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17721;
                                if (_17714)
                                {
                                    _17721 = length((r_motion_tp1.Load(int3(int2(floor(_17644 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17915_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7035) < (0.20000000298023223876953125f * _17700);
                                }
                                else
                                {
                                    _17721 = _17714;
                                }
                                _23056 = _17721;
                                break;
                            } while(false);
                            if (_23056)
                            {
                                uint _17946_dummy_parameter;
                                _23075 = -(r_motion_tp1.Load(int3(int2(floor(_17644 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17946_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17973_dummy_parameter;
                            float4x4 _23069;
                            do
                            {
                                bool _23068;
                                do
                                {
                                    _17987 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14702)
                                    {
                                        _23068 = false;
                                        break;
                                    }
                                    uint _18021 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18021 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23068 = false;
                                        break;
                                    }
                                    uint _23065;
                                    _23065 = 0u;
                                    for (; _23065 < 4u; _23065++)
                                    {
                                        for (uint _23066 = 0u; _23066 < 4u; )
                                        {
                                            _17987[_23065][_23066] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18021 + 16u) + (_23065 * 4u)) + _23066) * 4 + 0));
                                            _23066++;
                                            continue;
                                        }
                                    }
                                    _23068 = true;
                                    break;
                                } while(false);
                                if (_23068)
                                {
                                    _23069 = _17987;
                                    break;
                                }
                                _23069 = cbFI_MotionTM1ToTP1;
                                break;
                            } while(false);
                            float2 _23074;
                            do
                            {
                                float _18098 = _17644.x;
                                float _18101 = 1.0f - _17644.y;
                                float4 _18112 = mul(float4((float2(_18098, _18101) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17644 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17973_dummy_parameter))))), 0)).x, 1.0f), _23069);
                                float _18114 = _18112.w;
                                if (!(_18114 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23074 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18127 = ((_18112.xy / _18114.xx) + 1.0f.xx) * 0.5f;
                                _23074 = float2(_18127.x - _18098, _18101 - _18127.y);
                                break;
                            } while(false);
                            float2 _17659 = abs(_23074);
                            bool2 _17663 = any(bool2(_17659.x > 4.0f.xx.x, _17659.y > 4.0f.xx.y)).xx;
                            _23075 = float2(_17663.x ? 0.0f.xx.x : _23074.x, _17663.y ? 0.0f.xx.y : _23074.y);
                            break;
                        } while(false);
                        _17565 = _22950 + (((_5348 - (_23075 * cbFI_Timestep)) - _22950) * 0.699999988079071044921875f);
                    }
                    float2 _18188;
                    float2 _22976;
                    do
                    {
                        _18188 = clamp(_22950, 0.0f.xx, 1.0f.xx);
                        bool _22957;
                        do
                        {
                            bool _18272 = all(bool2(_18188.x > 0.0f.xx.x, _18188.y > 0.0f.xx.y));
                            bool _18278;
                            if (_18272)
                            {
                                _18278 = all(bool2(_18188.x < 1.0f.xx.x, _18188.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18278 = _18272;
                            }
                            if (!_18278)
                            {
                                _22957 = false;
                                break;
                            }
                            uint _18285_dummy_parameter;
                            float4x4 _22955;
                            do
                            {
                                bool _22954;
                                do
                                {
                                    _18299 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14702)
                                    {
                                        _22954 = false;
                                        break;
                                    }
                                    uint _18333 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18333 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22954 = false;
                                        break;
                                    }
                                    uint _22951;
                                    _22951 = 0u;
                                    for (; _22951 < 4u; _22951++)
                                    {
                                        for (uint _22952 = 0u; _22952 < 4u; )
                                        {
                                            _18299[_22951][_22952] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18333 + (_22951 * 4u)) + _22952) * 4 + 0));
                                            _22952++;
                                            continue;
                                        }
                                    }
                                    _22954 = true;
                                    break;
                                } while(false);
                                if (_22954)
                                {
                                    _22955 = _18299;
                                    break;
                                }
                                _22955 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22956;
                            do
                            {
                                float _18413 = 1.0f - _18188.y;
                                float4 _18424 = mul(float4((float2(_18188.x, _18413) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18188 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18285_dummy_parameter))))), 0)).x, 1.0f), _22955);
                                float _18426 = _18424.w;
                                if (!(_18426 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22956 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18439 = ((_18424.xy / _18426.xx) + 1.0f.xx) * 0.5f;
                                _22956 = float2(_18439.x - _18188.x, _18413 - _18439.y);
                                break;
                            } while(false);
                            float2 _18236 = abs(_22956);
                            if (any(bool2(_18236.x > 100000.0f.xx.x, _18236.y > 100000.0f.xx.y)))
                            {
                                _22957 = false;
                                break;
                            }
                            float _18244 = length(_22956 * _7035);
                            uint _18459_dummy_parameter;
                            bool _18258 = _18244 > ((8.0f * _7035.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18265;
                            if (_18258)
                            {
                                _18265 = length((r_motion_tp1.Load(int3(int2(floor(_18188 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18459_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7035) < (0.20000000298023223876953125f * _18244);
                            }
                            else
                            {
                                _18265 = _18258;
                            }
                            _22957 = _18265;
                            break;
                        } while(false);
                        if (_22957)
                        {
                            uint _18490_dummy_parameter;
                            _22976 = -(r_motion_tp1.Load(int3(int2(floor(_18188 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18490_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18517_dummy_parameter;
                        float4x4 _22970;
                        do
                        {
                            bool _22969;
                            do
                            {
                                _18531 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14702)
                                {
                                    _22969 = false;
                                    break;
                                }
                                uint _18565 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18565 + 32u) * 4 + 0) != 1u)
                                {
                                    _22969 = false;
                                    break;
                                }
                                uint _22966;
                                _22966 = 0u;
                                for (; _22966 < 4u; _22966++)
                                {
                                    for (uint _22967 = 0u; _22967 < 4u; )
                                    {
                                        _18531[_22966][_22967] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18565 + 16u) + (_22966 * 4u)) + _22967) * 4 + 0));
                                        _22967++;
                                        continue;
                                    }
                                }
                                _22969 = true;
                                break;
                            } while(false);
                            if (_22969)
                            {
                                _22970 = _18531;
                                break;
                            }
                            _22970 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _22975;
                        do
                        {
                            float _18645 = 1.0f - _18188.y;
                            float4 _18656 = mul(float4((float2(_18188.x, _18645) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18188 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18517_dummy_parameter))))), 0)).x, 1.0f), _22970);
                            float _18658 = _18656.w;
                            if (!(_18658 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22975 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18671 = ((_18656.xy / _18658.xx) + 1.0f.xx) * 0.5f;
                            _22975 = float2(_18671.x - _18188.x, _18645 - _18671.y);
                            break;
                        } while(false);
                        float2 _18203 = abs(_22975);
                        bool2 _18207 = any(bool2(_18203.x > 4.0f.xx.x, _18203.y > 4.0f.xx.y)).xx;
                        _22976 = float2(_18207.x ? 0.0f.xx.x : _22975.x, _18207.y ? 0.0f.xx.y : _22975.y);
                        break;
                    } while(false);
                    bool _18689 = all(bool2(_22950.x > 0.0f.xx.x, _22950.y > 0.0f.xx.y));
                    bool _18695;
                    if (_18689)
                    {
                        _18695 = all(bool2(_22950.x < 1.0f.xx.x, _22950.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18695 = _18689;
                    }
                    float _22992;
                    if (_18695)
                    {
                        _22992 = length(((_22950 + (_22976 * cbFI_Timestep)) - _5348) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22992 = 1000000000.0f;
                    }
                    uint _18722_dummy_parameter;
                    float _18746 = log(((r_depth_tm1.Load(int3(int2(floor(_18188 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18722_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16945 = _22992 < 0.3499999940395355224609375f;
                    bool _16947 = _21719 < 0.3499999940395355224609375f;
                    bool _16957;
                    if (_16945)
                    {
                        _16957 = (!_16947) || (_18746 > _23017);
                    }
                    else
                    {
                        _16957 = _16945;
                    }
                    bool _16970;
                    if (!_16957)
                    {
                        _16970 = ((!_16945) && (!_16947)) && (_22992 < _21719);
                    }
                    else
                    {
                        _16970 = _16957;
                    }
                    _23665 = _16970 ? _18746 : _23017;
                    bool2 _23666 = _16970.xx;
                    _23667 = float2(_23666.x ? _22950.x : _21720.x, _23666.y ? _22950.y : _21720.y);
                    _23668 = _16970 ? _22992 : _21719;
                }
                float3 _18755 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21689, 0.0f).xyz;
                float3 _18763 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21720, 0.0f).xyz;
                uint _18770_dummy_parameter;
                uint _18801_dummy_parameter;
                float _14563 = exp((_21688 * (-2.0f)) * (_21688 * 2.0f));
                float _14570 = exp((_21719 * (-2.0f)) * (_21719 * 2.0f));
                float _14583 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21720, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18801_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21689, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18770_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14597 = ((_14563 * cbFI_Timestep) * ((1.0f - _14570) + ((_14570 * 2.0f) * _14583))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14607 = 1.0f - _14583;
                float _14614 = ((_14570 * _5573) * ((1.0f - _14563) + ((_14563 * 2.0f) * _14607))) + (9.9999997473787516355514526367188e-05f * _5573);
                float _14623 = (((_14563 * _14570) * 4.0f) * _14583) * _14607;
                _14641 = (_14623 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18763 - _18755, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14623)) * max(_14563, _14570));
                if (_6721 == 30u)
                {
                    _21721 = _18755;
                    break;
                }
                if (_6721 == 31u)
                {
                    _21721 = _18763;
                    break;
                }
                if (_6721 == 32u)
                {
                    _21721 = float3(_14563, _14570, _14583);
                    break;
                }
                _21721 = ((_18755 * _14597) + (_18763 * _14614)) / (_14597 + _14614).xxx;
                break;
            } while(false);
            _22929 = _14641;
            _22853 = _21721;
        }
        else
        {
            _22929 = 1.0f;
            _22853 = _22854;
        }
        uint _7051 = cbFI_pad0 & 255u;
        bool _22697;
        float3 _22852;
        if (_7051 != 0u)
        {
            float3 _7056 = r_present_backbuffer.Load(int3(_4849, 0)).xyz;
            float3 _7060 = r_current_interpolation_source.Load(int3(_4849, 0)).xyz;
            float3 _7064 = abs(_7056 - _7060);
            float3 _21722;
            if (_7051 == 2u)
            {
                _21722 = (abs(_7060) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21722 = 0.000244140625f.xxx;
            }
            bool _7080 = any(bool3(_7064.x > _21722.x, _7064.y > _21722.y, _7064.z > _21722.z));
            bool3 _23669 = _7080.xxx;
            _22852 = float3(_23669.x ? _7056.x : _22853.x, _23669.y ? _7056.y : _22853.y, _23669.z ? _7056.z : _22853.z);
            _22697 = _7080;
        }
        else
        {
            _22852 = _22853;
            _22697 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18839;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18839);
        }
        float3 _22834;
        if (_6721 == 1u)
        {
            _22834 = lerp(_8553, _8561, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22835;
            if (_6721 == 2u)
            {
                _22835 = lerp(_8569, _8577, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22836;
                if (_6721 == 3u)
                {
                    _22836 = float(_22697).xxx;
                }
                else
                {
                    float3 _22837;
                    if (_6721 == 4u)
                    {
                        _22837 = float3(((_19749 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22838;
                        if (_6721 == 5u)
                        {
                            _22838 = float3(((_7848 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22839;
                            if (_6721 == 6u)
                            {
                                _22839 = float3(_21255.xy, _21255.z + _21255.w);
                            }
                            else
                            {
                                float3 _22840;
                                if (_6721 == 7u)
                                {
                                    _22840 = r_current_interpolation_source.Load(int3(_4849, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22841;
                                    if (_6721 == 8u)
                                    {
                                        _22841 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5348, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22842;
                                        if (_6725)
                                        {
                                            uint _18861_dummy_parameter;
                                            uint _18893_dummy_parameter;
                                            _22842 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5348 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18861_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5348 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18893_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22843;
                                            if (_6728)
                                            {
                                                _22843 = _8569;
                                            }
                                            else
                                            {
                                                float3 _22844;
                                                if (_6721 == 20u)
                                                {
                                                    _22844 = _8553;
                                                }
                                                else
                                                {
                                                    float3 _22845;
                                                    if (_6721 == 21u)
                                                    {
                                                        _22845 = _8561;
                                                    }
                                                    else
                                                    {
                                                        float3 _22846;
                                                        if (_6721 == 22u)
                                                        {
                                                            _22846 = _8577;
                                                        }
                                                        else
                                                        {
                                                            float3 _22847;
                                                            if (_6721 == 18u)
                                                            {
                                                                _22847 = _22256;
                                                            }
                                                            else
                                                            {
                                                                float3 _22848;
                                                                if (_6721 == 19u)
                                                                {
                                                                    _22848 = _21990;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22849;
                                                                    if (_6721 == 23u)
                                                                    {
                                                                        _22849 = _21730;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22850;
                                                                        if (_6721 == 24u)
                                                                        {
                                                                            uint _7224 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7229 = float(rw_nfru_diagnostics.Load<uint>((_7224 + 35u) * 4 + 0));
                                                                            float _21723;
                                                                            if (_7229 > 0.0f)
                                                                            {
                                                                                _21723 = float(rw_nfru_diagnostics.Load<uint>((_7224 + 34u) * 4 + 0)) / _7229;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21723 = 0.0f;
                                                                            }
                                                                            _22850 = float3(float(rw_nfru_diagnostics.Load<uint>((_7224 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7224 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21723);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22850 = _22852;
                                                                        }
                                                                        _22849 = _22850;
                                                                    }
                                                                    _22848 = _22849;
                                                                }
                                                                _22847 = _22848;
                                                            }
                                                            _22846 = _22847;
                                                        }
                                                        _22845 = _22846;
                                                    }
                                                    _22844 = _22845;
                                                }
                                                _22843 = _22844;
                                            }
                                            _22842 = _22843;
                                        }
                                        _22841 = _22842;
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
        float3 _22833;
        if ((_6721 >= 9u) && (_6721 <= 11u))
        {
            uint _7289 = 64u + uint((_19972.y * cbFI_MvDepthLaneSize.x) + _19972.x);
            uint _7293 = rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) & 15u;
            float3 _22867;
            if (_6721 == 10u)
            {
                float3 _22832;
                if ((rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) & 32u) != 0u)
                {
                    _22832 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22831;
                    if ((rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) & 16u) != 0u)
                    {
                        _22831 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7314 = ((rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) & 64u) != 0u).xxx;
                        _22831 = float3(_7314.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7314.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7314.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22832 = _22831;
                }
                _22867 = _22832;
            }
            else
            {
                float3 _22868;
                if (_6721 == 11u)
                {
                    uint _7327 = (rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) >> 8u) & 15u;
                    uint _7330 = (rw_nfru_diagnostics.Load<uint>(_7289 * 4 + 0) >> 12u) & 15u;
                    float3 _22824;
                    if ((_7293 == 2u) || (_7293 == 3u))
                    {
                        _22824 = _4548[_7293];
                    }
                    else
                    {
                        bool _7342 = _7327 == 3u;
                        bool _7344 = _7330 == 3u;
                        float3 _22825;
                        if (_7342 && _7344)
                        {
                            _22825 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22826;
                            if (_7342)
                            {
                                _22826 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22827;
                                if (_7344)
                                {
                                    _22827 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22828;
                                    if ((_7327 == 4u) || (_7330 == 4u))
                                    {
                                        _22828 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22829;
                                        if ((_7327 == 1u) || (_7330 == 1u))
                                        {
                                            _22829 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23671 = (_7293 == 1u).xxx;
                                            _22829 = float3(_23671.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23671.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23671.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22828 = _22829;
                                    }
                                    _22827 = _22828;
                                }
                                _22826 = _22827;
                            }
                            _22825 = _22826;
                        }
                        _22824 = _22825;
                    }
                    _22868 = _22824;
                }
                else
                {
                    _22868 = _4548[min(_7293, 7u)];
                }
                _22867 = _22868;
            }
            _22833 = _22867;
        }
        else
        {
            _22833 = _22834;
        }
        float4 _22871;
        if ((_6721 >= 14u) && (_6721 <= 16u))
        {
            float2 _22869;
            if (_6721 == 14u)
            {
                uint _7400_dummy_parameter;
                uint _7406_dummy_parameter;
                _22869 = r_flow_tm1.Load(int3(clamp(int2(floor(_5348 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7400_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7406_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22870;
                if (_6721 == 16u)
                {
                    uint _18969 = r_warped_flow_qdata_tm1.Load(int3(_5364, 0)).x & 2147483647u;
                    uint _19001 = uint(max((int((_18969 >> 16u) & 15u) - 6), 0));
                    _22870 = ((float2(float((1 - (2 * int((_18969 >> 15u) & 1u))) * int(((_18969 >> uint(7)) & 127u) << _19001)), float((1 - (2 * int((_18969 >> 14u) & 1u))) * int((_18969 & 127u) << _19001))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22870 = _7848 * float2(cbFI_DisplaySize);
                }
                _22869 = _22870;
            }
            uint2 _7439 = uint2(clamp(round(_22869 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7441 = _7439.x;
            uint _7448 = _7439.y;
            _22871 = float4(float(_7441 & 255u), float((_7441 >> 8u) | ((_7448 & 15u) << 4u)), float(_7448 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22872;
            if (_6721 == 17u)
            {
                _22872 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5364, 0)).x != 0u), _5808, 0.0f, 1.0f);
            }
            else
            {
                _22872 = float4(_22833, 1.0f);
            }
            _22871 = _22872;
        }
        rw_output[_4849] = _22871.xyz;
        if (_7031)
        {
            uint _19046 = uint((_4849.y * cbFI_DisplaySize.x) + _4849.x) * 2u;
            rw_nfru_select.Store<uint>(_19046 * 4 + 0, spvPackHalf2x16(_22871.xy));
            rw_nfru_select.Store<uint>((_19046 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22871.z, (_22697 || (_6721 != 0u)) ? 2.0f : _22929)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7506 = ((uint(_4849.y) * uint(cbFI_DisplaySize.x)) + uint(_4849.x)) * 6u;
            uint _19072 = spvPackHalf2x16(clamp(_8552.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7506 * 4 + 0, (((_19072 & 32767u) >> 4u) | ((((_19072 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8552.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19107 = spvPackHalf2x16(clamp(_8560.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7506 + 1u) * 4 + 0, (((_19107 & 32767u) >> 4u) | ((((_19107 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8560.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19142 = spvPackHalf2x16(clamp(_8568.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7506 + 2u) * 4 + 0, (((_19142 & 32767u) >> 4u) | ((((_19142 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8568.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19177 = spvPackHalf2x16(clamp(_8576.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7506 + 3u) * 4 + 0, (((_19177 & 32767u) >> 4u) | ((((_19177 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8576.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19204 = r_current_interpolation_source.Load(int3(_4849, 0));
            uint _19218 = spvPackHalf2x16(clamp(_19204.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7506 + 4u) * 4 + 0, (((_19218 & 32767u) >> 4u) | ((((_19218 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19204.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22948;
            if (_22697 || (_6721 != 0u))
            {
                _22948 = 4294967295u;
            }
            else
            {
                uint _19253 = spvPackHalf2x16(clamp(_22871.xy, 0.0f.xx, 65000.0f.xx));
                _22948 = (((_19253 & 32767u) >> 4u) | ((((_19253 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22871.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7506 + 5u) * 4 + 0, _22948);
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
