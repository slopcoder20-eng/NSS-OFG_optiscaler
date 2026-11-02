static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3292[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3596 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3596.x >= cbFI_DisplaySize.x, _3596.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3596] = float4(r_present_backbuffer.Load(int3(_3596, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3596] = float4(r_current_interpolation_source.Load(int3(_3596, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3996 = (float2(_3596) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4007 = int2(floor(_3996 * float2(cbFI_MvDepthLaneSize)));
        int2 _4012 = int2(floor(_3996 * float2(cbFI_FlowLaneSize)));
        float4 _5913 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3996 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5919 = r_warped_filled_flow_tm1.Load(int3(_4012, 0)).xy;
        float2 _5925 = r_warped_filled_motion_tp1.Load(int3(_4007, 0)).xy;
        bool _5947 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10013;
        if (_5947)
        {
            float _5960 = ((2.0f * _3996.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10013 = float2(atan(_5960) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3996.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5960 * _5960))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10013 = _3996;
        }
        bool _4033 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10034;
        bool _10055;
        int2 _10066;
        float3 _11419;
        if (_4033)
        {
            float _10015;
            float _10017;
            _10017 = 2.0f;
            _10015 = -1.0f;
            uint _3660[9];
            float _11851;
            float _11854;
            for (int _10014 = 0; _10014 < 9; _10017 = _11854, _10015 = _11851, _10014++)
            {
                _3660[_10014] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4007 + int2((_10014 % 3) - 1, (_10014 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3660[_10014] != 0u)
                {
                    float _11846;
                    if (_3660[_10014] == 0u)
                    {
                        _11846 = -1.0f;
                    }
                    else
                    {
                        _11846 = float((_3660[_10014] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11854 = min(_10017, _11846);
                    _11851 = max(_10015, _11846);
                }
                else
                {
                    _11854 = _10017;
                    _11851 = _10015;
                }
            }
            float _4079 = float(_10015 >= 0.0f);
            float3 _9814 = 0.0f.xxx;
            _9814.y = _4079;
            float2 _10035;
            bool _10056;
            int2 _10067;
            float3 _11420;
            if ((_10015 - _10017) > 0.0199999995529651641845703125f)
            {
                float _10023;
                int2 _10024;
                float2 _10025;
                int2 _10027;
                float2 _10033;
                _10033 = _5925;
                _10027 = _4007;
                _10025 = _5925;
                _10024 = _4007;
                _10023 = -1.0f;
                float _11859;
                int2 _11863;
                float2 _11874;
                int2 _11885;
                float2 _11918;
                float _11965;
                int _10022 = 0;
                float _11827 = 1000000000.0f;
                for (; _10022 < 9; _11827 = _11965, _10033 = _11918, _10027 = _11885, _10025 = _11874, _10024 = _11863, _10023 = _11859, _10022++)
                {
                    if (_3660[_10022] == 0u)
                    {
                        _11965 = _11827;
                        _11918 = _10033;
                        _11885 = _10027;
                        _11874 = _10025;
                        _11863 = _10024;
                        _11859 = _10023;
                        continue;
                    }
                    int2 _4114 = clamp(_4007 + int2((_10022 % 3) - 1, (_10022 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6035 = _3660[_10022] & 2147483647u;
                    uint _6067 = uint(max((int((_6035 >> 16u) & 15u) - 6), 0));
                    float2 _4120 = (float2(float((1 - (2 * int((_6035 >> 15u) & 1u))) * int(((_6035 >> uint(7)) & 127u) << _6067)), float((1 - (2 * int((_6035 >> 14u) & 1u))) * int((_6035 & 127u) << _6067))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11813;
                    if (_3660[_10022] == 0u)
                    {
                        _11813 = -1.0f;
                    }
                    else
                    {
                        _11813 = float((_3660[_10022] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4125 = _11813 - 0.100000001490116119384765625f;
                    float2 _11814;
                    if (_5947)
                    {
                        float2 _6144 = clamp((((_10013 + (_4120 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6147 = tan(_6144.x);
                        _11814 = (float2(_6147 / cbFI_DeviceToViewDepth.z, (tan(_6144.y) * sqrt(1.0f + (_6147 * _6147))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11814 = _10013 + (_4120 * cbFI_Timestep);
                    }
                    float _4132 = cbFI_Timestep - 1.0f;
                    float2 _11815;
                    if (_5947)
                    {
                        float2 _6215 = clamp((((_10013 + (_4120 * _4132)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6218 = tan(_6215.x);
                        _11815 = (float2(_6218 / cbFI_DeviceToViewDepth.z, (tan(_6215.y) * sqrt(1.0f + (_6218 * _6218))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11815 = _10013 + (_4120 * _4132);
                    }
                    bool _6251 = all(bool2(_11814.x > 0.0f.xx.x, _11814.y > 0.0f.xx.y));
                    bool _6257;
                    if (_6251)
                    {
                        _6257 = all(bool2(_11814.x < 1.0f.xx.x, _11814.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6257 = _6251;
                    }
                    float _11818;
                    if (_6257)
                    {
                        uint _6264_dummy_parameter;
                        _11818 = max((_4125 - (log((r_depth_tm1.Load(int3(int2(floor(_11814 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6264_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11818 = 0.0f;
                    }
                    bool _6294 = all(bool2(_11815.x > 0.0f.xx.x, _11815.y > 0.0f.xx.y));
                    bool _6300;
                    if (_6294)
                    {
                        _6300 = all(bool2(_11815.x < 1.0f.xx.x, _11815.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6300 = _6294;
                    }
                    float _11819;
                    if (_6300)
                    {
                        uint _6307_dummy_parameter;
                        _11819 = _11818 + max((_4125 - (log((r_depth_tp1.Load(int3(int2(floor(_11815 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6307_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11819 = _11818;
                    }
                    float _11860;
                    int2 _11864;
                    float2 _11875;
                    int2 _11886;
                    float2 _11919;
                    float _11966;
                    if (_11819 == 0.0f)
                    {
                        bool _4167 = _4125 > _10023;
                        bool2 _11974 = _4167.xx;
                        _11966 = _11827;
                        _11919 = float2(_11974.x ? _4120.x : _10033.x, _11974.y ? _4120.y : _10033.y);
                        _11886 = int2(_11974.x ? _4114.x : _10027.x, _11974.y ? _4114.y : _10027.y);
                        _11875 = _10025;
                        _11864 = _10024;
                        _11860 = _4167 ? _4125 : _10023;
                    }
                    else
                    {
                        bool _4176 = _11819 < _11827;
                        bool2 _11970 = _4176.xx;
                        _11966 = _4176 ? _11819 : _11827;
                        _11919 = _10033;
                        _11886 = _10027;
                        _11875 = float2(_11970.x ? _4120.x : _10025.x, _11970.y ? _4120.y : _10025.y);
                        _11864 = int2(_11970.x ? _4114.x : _10024.x, _11970.y ? _4114.y : _10024.y);
                        _11860 = _10023;
                    }
                    _11965 = _11966;
                    _11918 = _11919;
                    _11885 = _11886;
                    _11874 = _11875;
                    _11863 = _11864;
                    _11859 = _11860;
                }
                bool _4188 = _10023 < 0.0f;
                bool2 _11980 = _4188.xx;
                int2 _11983 = int2(_11980.x ? _10024.x : _10027.x, _11980.y ? _10024.y : _10027.y);
                _11420 = float3(1.0f, _4079, float(any(bool2(_11983.x != _4007.x, _11983.y != _4007.y))));
                _10067 = _11983;
                _10056 = _4188 ? false : true;
                _10035 = float2(_11980.x ? _10025.x : _10033.x, _11980.y ? _10025.y : _10033.y);
            }
            else
            {
                _11420 = _9814;
                _10067 = _4007;
                _10056 = false;
                _10035 = _5925;
            }
            _11419 = _11420;
            _10066 = _10067;
            _10055 = _10056;
            _10034 = _10035;
        }
        else
        {
            _11419 = 0.0f.xxx;
            _10066 = _4007;
            _10055 = false;
            _10034 = _5925;
        }
        float2 _10036;
        if (_5947)
        {
            float2 _6372 = clamp((((_10013 + (_10034 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6375 = tan(_6372.x);
            _10036 = (float2(_6375 / cbFI_DeviceToViewDepth.z, (tan(_6372.y) * sqrt(1.0f + (_6375 * _6375))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10036 = _10013 + (_10034 * cbFI_Timestep);
        }
        float _4211 = cbFI_Timestep - 1.0f;
        float2 _10038;
        if (_5947)
        {
            float2 _6443 = clamp((((_10013 + (_10034 * _4211)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6446 = tan(_6443.x);
            _10038 = (float2(_6446 / cbFI_DeviceToViewDepth.z, (tan(_6443.y) * sqrt(1.0f + (_6446 * _6446))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10038 = _10013 + (_10034 * _4211);
        }
        float _4216 = -cbFI_Timestep;
        float2 _10039;
        if (_5947)
        {
            float2 _6514 = clamp((((_10013 + (_5919 * _4216)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6517 = tan(_6514.x);
            _10039 = (float2(_6517 / cbFI_DeviceToViewDepth.z, (tan(_6514.y) * sqrt(1.0f + (_6517 * _6517))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10039 = _10013 + (_5919 * _4216);
        }
        float _4221 = 1.0f - cbFI_Timestep;
        float2 _10040;
        if (_5947)
        {
            float2 _6585 = clamp((((_10013 + (_5919 * _4221)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6588 = tan(_6585.x);
            _10040 = (float2(_6588 / cbFI_DeviceToViewDepth.z, (tan(_6585.y) * sqrt(1.0f + (_6588 * _6588))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10040 = _10013 + (_5919 * _4221);
        }
        float4 _6623 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10036, 0.0f);
        float3 _6624 = _6623.xyz;
        float4 _6631 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10038, 0.0f);
        float3 _6632 = _6631.xyz;
        float4 _6639 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10039, 0.0f);
        float3 _6640 = _6639.xyz;
        float4 _6647 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10040, 0.0f);
        float3 _6648 = _6647.xyz;
        float4 _6662 = exp(_5913 - max(max(max(_5913.x, _5913.y), _5913.z), _5913.w).xxxx);
        float4 _6669 = _6662 / (dot(_6662, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4240 = _4033 && (!_10055);
        bool _4249;
        if (_4240)
        {
            _4249 = (_6669.z + _6669.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4249 = _4240;
        }
        bool _4260;
        if (_4249)
        {
            _4260 = length((_10039 - _10036) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4260 = _4249;
        }
        bool _10079;
        if (_4260)
        {
            uint4 _6688 = r_warped_motion_qdata_tp1.Load(int3(_10066, 0));
            uint _6689 = _6688.x;
            bool _10082;
            if (_6689 != 0u)
            {
                float _10068;
                if (_6689 == 0u)
                {
                    _10068 = -1.0f;
                }
                else
                {
                    _10068 = float((_6689 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4270 = _10068 - 0.12000000476837158203125f;
                bool _6708 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                bool _6714;
                if (_6708)
                {
                    _6714 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                }
                else
                {
                    _6714 = _6708;
                }
                bool _4280;
                if (_6714)
                {
                    uint _6721_dummy_parameter;
                    _4280 = (log((r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6721_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4270;
                }
                else
                {
                    _4280 = _6714;
                }
                bool _4294;
                if (!_4280)
                {
                    bool _6751 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                    bool _6757;
                    if (_6751)
                    {
                        _6757 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6757 = _6751;
                    }
                    bool _4292;
                    if (_6757)
                    {
                        uint _6764_dummy_parameter;
                        _4292 = (log((r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6764_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4270;
                    }
                    else
                    {
                        _4292 = _6757;
                    }
                    _4294 = _4292;
                }
                else
                {
                    _4294 = _4280;
                }
                _10082 = _4294;
            }
            else
            {
                _10082 = false;
            }
            _10079 = _10082;
        }
        else
        {
            _10079 = false;
        }
        bool _4299 = _10055 || _10079;
        bool _4304;
        if (_4299)
        {
            bool _6794 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
            bool _6800;
            if (_6794)
            {
                _6800 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
            }
            else
            {
                _6800 = _6794;
            }
            _4304 = _6800;
        }
        else
        {
            _4304 = _4299;
        }
        bool _4309;
        if (_4304)
        {
            bool _6805 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
            bool _6811;
            if (_6805)
            {
                _6811 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
            }
            else
            {
                _6811 = _6805;
            }
            _4309 = _6811;
        }
        else
        {
            _4309 = _4304;
        }
        float4 _10176;
        if (_4309)
        {
            float _4312 = _6669.x;
            float _4314 = _6669.y;
            float _4315 = _4312 + _4314;
            float _4320 = _6669.z + _6669.w;
            float _10097;
            if (_4315 > 0.001000000047497451305389404296875f)
            {
                _10097 = _4312 / _4315;
            }
            else
            {
                _10097 = _4221;
            }
            _10176 = float4(_4312 + (_4320 * _10097), _4314 + (_4320 * (1.0f - _10097)), 0.0f, 0.0f);
        }
        else
        {
            _10176 = _6669;
        }
        bool _6839 = (cbFI_pad0 & 1024u) != 0u;
        bool _6815 = !_6839;
        bool _6816 = !_6815;
        bool _6833;
        if (_6816)
        {
            _6833 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10066.y * cbFI_MvDepthLaneSize.x) + _10066.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6833 = _6815;
        }
        bool _6865;
        if (_6816)
        {
            _6865 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4012.y * cbFI_FlowLaneSize.x) + _4012.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6865 = _6815;
        }
        float _4355 = float(_6865);
        bool _10189;
        float4 _10274;
        float3 _11234;
        if (_6839)
        {
            bool _4365;
            if (_6833)
            {
                _4365 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
            }
            else
            {
                _4365 = _6833;
            }
            bool _4371;
            if (_4365)
            {
                _4371 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
            }
            else
            {
                _4371 = _4365;
            }
            bool _4378;
            if (_6833)
            {
                _4378 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
            }
            else
            {
                _4378 = _6833;
            }
            bool _4384;
            if (_4378)
            {
                _4384 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
            }
            else
            {
                _4384 = _4378;
            }
            bool _4391;
            if (_6865)
            {
                _4391 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
            }
            else
            {
                _4391 = _6865;
            }
            bool _4397;
            if (_4391)
            {
                _4397 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
            }
            else
            {
                _4397 = _4391;
            }
            bool _4404;
            if (_6865)
            {
                _4404 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
            }
            else
            {
                _4404 = _6865;
            }
            bool _4410;
            if (_4404)
            {
                _4410 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
            }
            else
            {
                _4410 = _4404;
            }
            bool _4412 = !_6833;
            if (_4412)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6907;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6907);
                }
            }
            bool _4417 = !_6865;
            if (_4417)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6917;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6917);
                }
            }
            if (_6833 && _4417)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6927;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6927);
                }
            }
            if (_4412 && _6865)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6937;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6937);
                }
            }
            float _4436 = float(_4371);
            float _4438 = float(_4384);
            bool _4441 = _4397 && _4410;
            float _10131;
            if (_4441)
            {
                _10131 = 1.0f;
            }
            else
            {
                _10131 = (_4397 || _4410) ? 0.5f : 0.0f;
            }
            bool _10136;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4371)) && (!_4384))
            {
                bool _4471;
                if (_4441)
                {
                    float _10134;
                    do
                    {
                        bool _7021 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                        bool _7027;
                        if (_7021)
                        {
                            _7027 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7027 = _7021;
                        }
                        bool _6958 = !_7027;
                        bool _6965;
                        if (!_6958)
                        {
                            bool _7032 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                            bool _7038;
                            if (_7032)
                            {
                                _7038 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7038 = _7032;
                            }
                            _6965 = !_7038;
                        }
                        else
                        {
                            _6965 = _6958;
                        }
                        if (_6965)
                        {
                            _10134 = 0.0f;
                            break;
                        }
                        uint _7045_dummy_parameter;
                        uint _7061_dummy_parameter;
                        float4 _6986 = mul(float4((float2(_10039.x, 1.0f - _10039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7045_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6988 = _6986.w;
                        if (abs(_6988) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10134 = 0.0f;
                            break;
                        }
                        float _6999 = abs(cbFI_DeviceToViewDepth.y / ((_6986.z / _6988) - cbFI_DeviceToViewDepth.x));
                        float _7002 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7061_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10134 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6999 - _7002) / max(max(_6999, _7002), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4471 = _10134 >= 0.5f;
                }
                else
                {
                    _4471 = _4441;
                }
                bool _4479;
                if (_4471)
                {
                    _4479 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4479 = _4471;
                }
                bool _10137;
                if (_4479)
                {
                    uint _7111_dummy_parameter;
                    float2 _10135;
                    do
                    {
                        float _7137 = 1.0f - _10039.y;
                        float4 _7148 = mul(float4((float2(_10039.x, _7137) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7111_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7150 = _7148.w;
                        if (!(_7150 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10135 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7163 = ((_7148.xy / _7150.xx) + 1.0f.xx) * 0.5f;
                        _10135 = float2(_7163.x - _10039.x, _7137 - _7163.y);
                        break;
                    } while(false);
                    float2 _4492 = float2(cbFI_DisplaySize);
                    _10137 = length(((_10039 + _10135) - _10040) * _4492) <= ((0.100000001490116119384765625f * length(_10135 * _4492)) + 8.0f);
                }
                else
                {
                    _10137 = _4471;
                }
                _10136 = _10137;
            }
            else
            {
                _10136 = true;
            }
            bool _4506 = !_10136;
            bool _11984 = _4506 ? false : _4410;
            bool _11985 = _4506 ? false : _4397;
            bool _10190;
            float4 _10275;
            if (!(((_4371 && _4384) && _11985) && _11984))
            {
                float4 _4528 = _10176 * float4(_4436, _4438, float(_11985), float(_11984));
                float _4530 = dot(_4528, 1.0f.xxxx);
                bool _4533 = !(_4530 > 0.0f);
                float4 _10276;
                if (!_4533)
                {
                    _10276 = _4528 / _4530.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7185;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7185);
                    }
                    _10276 = 0.0f.xxxx;
                }
                _10275 = _10276;
                _10190 = _4533;
            }
            else
            {
                _10275 = _10176;
                _10190 = false;
            }
            _11234 = float3(_4436, _4438, _10131);
            _10274 = _10275;
            _10189 = _10190;
        }
        else
        {
            _11234 = float3(float(_6833), _4355, 0.0f);
            _10274 = _10176;
            _10189 = false;
        }
        bool _4551 = !_10189;
        float4 _10375;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4551) && _6833)
        {
            float _10271;
            do
            {
                uint4 _7325 = r_warped_motion_qdata_tp1.Load(int3(_10066, 0));
                uint _7326 = _7325.x;
                if (_7326 != 0u)
                {
                    float _10270;
                    if (_7326 == 0u)
                    {
                        _10270 = -1.0f;
                    }
                    else
                    {
                        _10270 = float((_7326 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10271 = _10270;
                    break;
                }
                int _10253;
                uint _10254;
                _10254 = _7326;
                _10253 = -1;
                uint _10269;
                for (; _10253 <= 1; _10254 = _10269, _10253++)
                {
                    _10269 = _10254;
                    for (int _10267 = -1; _10267 <= 1; )
                    {
                        _10269 = max(_10269, r_warped_motion_qdata_tp1.Load(int3(clamp(_10066 + int2(_10267, _10253), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10267++;
                        continue;
                    }
                }
                if (_10254 != 0u)
                {
                    float _10266;
                    if (_10254 == 0u)
                    {
                        _10266 = -1.0f;
                    }
                    else
                    {
                        _10266 = float((_10254 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10271 = _10266;
                    break;
                }
                uint _10256;
                _10256 = 4294967295u;
                uint _11955;
                for (int _10255 = 0; _10255 < 8; _10256 = _11955, _10255++)
                {
                    int _10259 = 0;
                    for (;;)
                    {
                        if (_10259 < 5)
                        {
                            int2 _7276 = _10066 + (_1093[_10255] * _1102[_10259].xx);
                            bool _7279 = any(bool2(_7276.x < int2(0, 0).x, _7276.y < int2(0, 0).y));
                            bool _7287;
                            if (!_7279)
                            {
                                _7287 = any(bool2(_7276.x >= cbFI_MvDepthLaneSize.x, _7276.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7287 = _7279;
                            }
                            if (_7287)
                            {
                                _11955 = _10256;
                                break;
                            }
                            uint4 _7365 = r_warped_motion_qdata_tp1.Load(int3(_7276, 0));
                            uint _7366 = _7365.x;
                            if (_7366 != 0u)
                            {
                                _11955 = min(_10256, _7366);
                                break;
                            }
                            _10259++;
                            continue;
                        }
                        else
                        {
                            _11955 = _10256;
                            break;
                        }
                    }
                }
                float _10258;
                if (_10256 == 4294967295u)
                {
                    _10258 = -1.0f;
                }
                else
                {
                    float _10257;
                    if (_10256 == 0u)
                    {
                        _10257 = -1.0f;
                    }
                    else
                    {
                        _10257 = float((_10256 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10258 = _10257;
                }
                _10271 = _10258;
                break;
            } while(false);
            float _4562 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4566 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4572;
            if (_4566)
            {
                _4572 = _10274.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4572 = _4566;
            }
            bool _4577;
            if (_4572)
            {
                bool _7385 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
                bool _7391;
                if (_7385)
                {
                    _7391 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
                }
                else
                {
                    _7391 = _7385;
                }
                _4577 = _7391;
            }
            else
            {
                _4577 = _4572;
            }
            float4 _10317;
            if (_4577)
            {
                float _10292;
                if (_10271 >= 0.0f)
                {
                    _10292 = _10271 - _4562;
                }
                else
                {
                    float _10288;
                    _10288 = 2.0f;
                    float _7448;
                    for (int _10287 = 0; _10287 < 24; _10288 = _7448, _10287++)
                    {
                        float _7412 = float(_10287 & 7) * 0.785398185253143310546875f;
                        int _7414 = _10287 >> 3;
                        int _10289;
                        if (_7414 == 0)
                        {
                            _10289 = 16;
                        }
                        else
                        {
                            _10289 = (_7414 == 1) ? 48 : 96;
                        }
                        uint _7480_dummy_parameter;
                        _7448 = min(_10288, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10038 + ((cbFI_MvDepthLaneSizeRcp * float(_10289)) * float2(cos(_7412), sin(_7412))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7480_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10292 = _10288;
                }
                uint _7512_dummy_parameter;
                float4 _10318;
                if (r_depth_tp1.Load(int3(int2(floor(_10038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7512_dummy_parameter))))), 0)).x > ((exp((_10292 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10318 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10318 = 1.0f.xxxx;
                }
                _10317 = _10318;
            }
            else
            {
                _10317 = 1.0f.xxxx;
            }
            bool _4604 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4610;
            if (_4604)
            {
                _4610 = _10274.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4610 = _4604;
            }
            bool _4615;
            if (_4610)
            {
                bool _7536 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
                bool _7542;
                if (_7536)
                {
                    _7542 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
                }
                else
                {
                    _7542 = _7536;
                }
                _4615 = _7542;
            }
            else
            {
                _4615 = _4610;
            }
            float4 _10321;
            if (_4615)
            {
                float _10312;
                if (_10271 >= 0.0f)
                {
                    _10312 = _10271 - _4562;
                }
                else
                {
                    float _10308;
                    _10308 = 2.0f;
                    float _7599;
                    for (int _10307 = 0; _10307 < 24; _10308 = _7599, _10307++)
                    {
                        float _7563 = float(_10307 & 7) * 0.785398185253143310546875f;
                        int _7565 = _10307 >> 3;
                        int _10309;
                        if (_7565 == 0)
                        {
                            _10309 = 16;
                        }
                        else
                        {
                            _10309 = (_7565 == 1) ? 48 : 96;
                        }
                        uint _7615_dummy_parameter;
                        _7599 = min(_10308, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10036 + ((cbFI_MvDepthLaneSizeRcp * float(_10309)) * float2(cos(_7563), sin(_7563))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7615_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10312 = _10308;
                }
                uint _7663_dummy_parameter;
                float4 _10322;
                if (r_depth_tm1.Load(int3(int2(floor(_10036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7663_dummy_parameter))))), 0)).x > ((exp((_10312 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9882 = _10317;
                    _9882.x = 0.0f;
                    _10322 = _9882;
                }
                else
                {
                    _10322 = _10317;
                }
                _10321 = _10322;
            }
            else
            {
                _10321 = _10317;
            }
            float4 _10376;
            if (any(bool4(_10321.x < 1.0f.xxxx.x, _10321.y < 1.0f.xxxx.y, _10321.z < 1.0f.xxxx.z, _10321.w < 1.0f.xxxx.w)))
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7691;
                    rw_nfru_diagnostics.InterlockedAdd(240, 1u, _7691);
                }
                float4 _4646 = _10274 * _10321;
                float _4648 = dot(_4646, 1.0f.xxxx);
                float4 _10377;
                if (_4648 > 0.0f)
                {
                    _10377 = _4646 / _4648.xxxx;
                }
                else
                {
                    bool _4659 = _10321.y == 0.0f;
                    bool _4665;
                    if (_4659)
                    {
                        _4665 = _10321.x > 0.0f;
                    }
                    else
                    {
                        _4665 = _4659;
                    }
                    bool _4670;
                    if (_4665)
                    {
                        bool _7697 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
                        bool _7703;
                        if (_7697)
                        {
                            _7703 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7703 = _7697;
                        }
                        _4670 = _7703;
                    }
                    else
                    {
                        _4670 = _4665;
                    }
                    float4 _10378;
                    if (_4670)
                    {
                        _10378 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4675 = _10321.x == 0.0f;
                        bool _4681;
                        if (_4675)
                        {
                            _4681 = _10321.y > 0.0f;
                        }
                        else
                        {
                            _4681 = _4675;
                        }
                        bool _4686;
                        if (_4681)
                        {
                            bool _7708 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
                            bool _7714;
                            if (_7708)
                            {
                                _7714 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7714 = _7708;
                            }
                            _4686 = _7714;
                        }
                        else
                        {
                            _4686 = _4681;
                        }
                        bool4 _11986 = _4686.xxxx;
                        _10378 = float4(_11986.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10274.x, _11986.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10274.y, _11986.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10274.z, _11986.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10274.w);
                    }
                    _10377 = _10378;
                }
                _10376 = _10377;
            }
            else
            {
                _10376 = _10274;
            }
            _10375 = _10376;
        }
        else
        {
            _10375 = _10274;
        }
        float4 _10921;
        bool _10941;
        float3 _11055;
        if (((cbFI_pad0 & 32768u) != 0u) && _4551)
        {
            bool _4703 = _10375.x > 0.00999999977648258209228515625f;
            bool _4706 = _10375.y > 0.00999999977648258209228515625f;
            bool _4715 = (_10375.z + _10375.w) > 0.0199999995529651641845703125f;
            bool _4721;
            if (_4715)
            {
                bool _7719 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                bool _7725;
                if (_7719)
                {
                    _7725 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                }
                else
                {
                    _7725 = _7719;
                }
                _4721 = _7725;
            }
            else
            {
                _4721 = _4715;
            }
            bool _4726;
            if (_4721)
            {
                bool _7730 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                bool _7736;
                if (_7730)
                {
                    _7736 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                }
                else
                {
                    _7736 = _7730;
                }
                _4726 = _7736;
            }
            else
            {
                _4726 = _4721;
            }
            bool _4733;
            if (_4726)
            {
                float _10386;
                do
                {
                    bool _7819 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                    bool _7825;
                    if (_7819)
                    {
                        _7825 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7825 = _7819;
                    }
                    bool _7756 = !_7825;
                    bool _7763;
                    if (!_7756)
                    {
                        bool _7830 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                        bool _7836;
                        if (_7830)
                        {
                            _7836 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7836 = _7830;
                        }
                        _7763 = !_7836;
                    }
                    else
                    {
                        _7763 = _7756;
                    }
                    if (_7763)
                    {
                        _10386 = 0.0f;
                        break;
                    }
                    uint _7843_dummy_parameter;
                    uint _7859_dummy_parameter;
                    float4 _7784 = mul(float4((float2(_10039.x, 1.0f - _10039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7843_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7786 = _7784.w;
                    if (abs(_7786) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10386 = 0.0f;
                        break;
                    }
                    float _7797 = abs(cbFI_DeviceToViewDepth.y / ((_7784.z / _7786) - cbFI_DeviceToViewDepth.x));
                    float _7800 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7859_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10386 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7797 - _7800) / max(max(_7797, _7800), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4733 = _10386 < 0.5f;
            }
            else
            {
                _4733 = _4726;
            }
            float4 _10401;
            if (_4733)
            {
                uint _7909_dummy_parameter;
                uint _7940_dummy_parameter;
                float4 _10402;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7909_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7940_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10402 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10402 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10401 = _10402;
            }
            else
            {
                _10401 = 1.0f.xxxx;
            }
            bool _4757;
            if (_6833)
            {
                bool _7969 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
                bool _7975;
                if (_7969)
                {
                    _7975 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
                }
                else
                {
                    _7975 = _7969;
                }
                _4757 = _7975;
            }
            else
            {
                _4757 = _6833;
            }
            bool _4763;
            if (_6833)
            {
                bool _7980 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
                bool _7986;
                if (_7980)
                {
                    _7986 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
                }
                else
                {
                    _7986 = _7980;
                }
                _4763 = _7986;
            }
            else
            {
                _4763 = _6833;
            }
            bool _4769;
            if (_6865)
            {
                bool _7991 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                bool _7997;
                if (_7991)
                {
                    _7997 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                }
                else
                {
                    _7997 = _7991;
                }
                _4769 = _7997;
            }
            else
            {
                _4769 = _6865;
            }
            bool _4775;
            if (_6865)
            {
                bool _8002 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                bool _8008;
                if (_8002)
                {
                    _8008 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                }
                else
                {
                    _8008 = _8002;
                }
                _4775 = _8008;
            }
            else
            {
                _4775 = _6865;
            }
            bool _4778 = _4769 != _4775;
            bool _4784;
            if (_4778)
            {
                _4784 = _4757 || _4763;
            }
            else
            {
                _4784 = _4778;
            }
            float4 _10490;
            if (_4784)
            {
                float4 _9909 = _10401;
                _9909.z = 0.0f;
                _9909.w = 0.0f;
                _10490 = _9909;
            }
            else
            {
                _10490 = _10401;
            }
            bool _4791 = _4757 && _4703;
            bool _4794 = _4763 && _4706;
            float4 _10595;
            float3 _11133;
            if (_4791 || _4794)
            {
                float _10485;
                do
                {
                    uint4 _8147 = r_warped_motion_qdata_tp1.Load(int3(_10066, 0));
                    uint _8148 = _8147.x;
                    if (_8148 != 0u)
                    {
                        float _10484;
                        if (_8148 == 0u)
                        {
                            _10484 = -1.0f;
                        }
                        else
                        {
                            _10484 = float((_8148 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10485 = _10484;
                        break;
                    }
                    int _10467;
                    uint _10468;
                    _10468 = _8148;
                    _10467 = -1;
                    uint _10483;
                    for (; _10467 <= 1; _10468 = _10483, _10467++)
                    {
                        _10483 = _10468;
                        for (int _10481 = -1; _10481 <= 1; )
                        {
                            _10483 = max(_10483, r_warped_motion_qdata_tp1.Load(int3(clamp(_10066 + int2(_10481, _10467), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10481++;
                            continue;
                        }
                    }
                    if (_10468 != 0u)
                    {
                        float _10480;
                        if (_10468 == 0u)
                        {
                            _10480 = -1.0f;
                        }
                        else
                        {
                            _10480 = float((_10468 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10485 = _10480;
                        break;
                    }
                    uint _10470;
                    _10470 = 4294967295u;
                    uint _11956;
                    for (int _10469 = 0; _10469 < 8; _10470 = _11956, _10469++)
                    {
                        int _10473 = 0;
                        for (;;)
                        {
                            if (_10473 < 5)
                            {
                                int2 _8098 = _10066 + (_1093[_10469] * _1102[_10473].xx);
                                bool _8101 = any(bool2(_8098.x < int2(0, 0).x, _8098.y < int2(0, 0).y));
                                bool _8109;
                                if (!_8101)
                                {
                                    _8109 = any(bool2(_8098.x >= cbFI_MvDepthLaneSize.x, _8098.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8109 = _8101;
                                }
                                if (_8109)
                                {
                                    _11956 = _10470;
                                    break;
                                }
                                uint4 _8187 = r_warped_motion_qdata_tp1.Load(int3(_8098, 0));
                                uint _8188 = _8187.x;
                                if (_8188 != 0u)
                                {
                                    _11956 = min(_10470, _8188);
                                    break;
                                }
                                _10473++;
                                continue;
                            }
                            else
                            {
                                _11956 = _10470;
                                break;
                            }
                        }
                    }
                    float _10472;
                    if (_10470 == 4294967295u)
                    {
                        _10472 = -1.0f;
                    }
                    else
                    {
                        float _10471;
                        if (_10470 == 0u)
                        {
                            _10471 = -1.0f;
                        }
                        else
                        {
                            _10471 = float((_10470 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10472 = _10471;
                    }
                    _10485 = _10472;
                    break;
                } while(false);
                bool _4802 = _10485 < 0.0f;
                float _10486;
                if (_4802)
                {
                    _10486 = 0.0f;
                }
                else
                {
                    _10486 = _10485 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8209_dummy_parameter;
                uint _8241_dummy_parameter;
                float4 _10523;
                if ((_4802 && _4791) && _4794)
                {
                    uint _8273_dummy_parameter;
                    float _8297 = log((r_depth_tm1.Load(int3(int2(floor(_10036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8273_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8305_dummy_parameter;
                    float _8329 = log((r_depth_tp1.Load(int3(int2(floor(_10038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8305_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10524;
                    if (_8297 > (_8329 + 0.07999999821186065673828125f))
                    {
                        float4 _9913 = _10490;
                        _9913.x = 0.0f;
                        _10524 = _9913;
                    }
                    else
                    {
                        float4 _10525;
                        if (_8329 > (_8297 + 0.07999999821186065673828125f))
                        {
                            float4 _9915 = _10490;
                            _9915.y = 0.0f;
                            _10525 = _9915;
                        }
                        else
                        {
                            _10525 = _10490;
                        }
                        _10524 = _10525;
                    }
                    _10523 = _10524;
                }
                else
                {
                    _10523 = _10490;
                }
                float _4854 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4856 = _10485 >= 0.0f;
                float _10506;
                if (_4856)
                {
                    _10506 = _10485 - _4854;
                }
                else
                {
                    float _10502;
                    if (_4791)
                    {
                        float _10501;
                        _10501 = 2.0f;
                        float _8387;
                        for (int _10500 = 0; _10500 < 24; _10501 = _8387, _10500++)
                        {
                            float _8351 = float(_10500 & 7) * 0.785398185253143310546875f;
                            int _8353 = _10500 >> 3;
                            int _10503;
                            if (_8353 == 0)
                            {
                                _10503 = 16;
                            }
                            else
                            {
                                _10503 = (_8353 == 1) ? 48 : 96;
                            }
                            uint _8403_dummy_parameter;
                            _8387 = min(_10501, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10036 + ((cbFI_MvDepthLaneSizeRcp * float(_10503)) * float2(cos(_8351), sin(_8351))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8403_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10502 = _10501;
                    }
                    else
                    {
                        _10502 = 0.0f;
                    }
                    _10506 = _10502;
                }
                float _10513;
                if (_4856)
                {
                    _10513 = _10485 - _4854;
                }
                else
                {
                    float _10509;
                    if (_4794)
                    {
                        float _10508;
                        _10508 = 2.0f;
                        float _8501;
                        for (int _10507 = 0; _10507 < 24; _10508 = _8501, _10507++)
                        {
                            float _8465 = float(_10507 & 7) * 0.785398185253143310546875f;
                            int _8467 = _10507 >> 3;
                            int _10510;
                            if (_8467 == 0)
                            {
                                _10510 = 16;
                            }
                            else
                            {
                                _10510 = (_8467 == 1) ? 48 : 96;
                            }
                            uint _8533_dummy_parameter;
                            _8501 = min(_10508, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10038 + ((cbFI_MvDepthLaneSizeRcp * float(_10510)) * float2(cos(_8465), sin(_8465))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8533_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10509 = _10508;
                    }
                    else
                    {
                        _10509 = 0.0f;
                    }
                    _10513 = _10509;
                }
                float _10514;
                if (_4791)
                {
                    uint _8565_dummy_parameter;
                    _10514 = r_depth_tm1.Load(int3(int2(floor(_10036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8565_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10514 = 0.0f;
                }
                float _10515;
                if (_4794)
                {
                    uint _8584_dummy_parameter;
                    _10515 = r_depth_tp1.Load(int3(int2(floor(_10038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8584_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10515 = 0.0f;
                }
                bool _4911;
                if (_4791)
                {
                    _4911 = _10514 > ((exp((_10506 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4911 = _4791;
                }
                float4 _10531;
                if (_4911)
                {
                    float4 _9917 = _10523;
                    _9917.x = 0.0f;
                    _10531 = _9917;
                }
                else
                {
                    _10531 = _10523;
                }
                bool _4923;
                if (_4794)
                {
                    _4923 = _10515 > ((exp((_10513 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4923 = _4794;
                }
                float4 _10533;
                if (_4923)
                {
                    float4 _9919 = _10531;
                    _9919.y = 0.0f;
                    _10533 = _9919;
                }
                else
                {
                    _10533 = _10531;
                }
                float4 _10596;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4856)
                {
                    bool _4943;
                    if (_4791)
                    {
                        _4943 = _10514 < ((exp((_10506 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4943 = _4791;
                    }
                    float4 _10535;
                    if (_4943)
                    {
                        float4 _9921 = _10533;
                        _9921.x = 0.0f;
                        _10535 = _9921;
                    }
                    else
                    {
                        _10535 = _10533;
                    }
                    bool _4955;
                    if (_4794)
                    {
                        _4955 = _10515 < ((exp((_10513 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4955 = _4794;
                    }
                    float4 _10597;
                    if (_4955)
                    {
                        float4 _9923 = _10535;
                        _9923.y = 0.0f;
                        _10597 = _9923;
                    }
                    else
                    {
                        _10597 = _10535;
                    }
                    _10596 = _10597;
                }
                else
                {
                    _10596 = _10533;
                }
                _11133 = float3(_10486, log((r_depth_tm1.Load(int3(int2(floor(_10036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8209_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8241_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10595 = _10596;
            }
            else
            {
                _11133 = float3(0.0f, 0.0f, 0.5f);
                _10595 = _10490;
            }
            bool _4966 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4715;
            bool _4972;
            if (_4966)
            {
                _4972 = _4769 || _4775;
            }
            else
            {
                _4972 = _4966;
            }
            float4 _10618;
            if (_4972)
            {
                float _10590;
                do
                {
                    uint4 _8763 = r_warped_motion_qdata_tp1.Load(int3(_10066, 0));
                    uint _8764 = _8763.x;
                    if (_8764 != 0u)
                    {
                        float _10589;
                        if (_8764 == 0u)
                        {
                            _10589 = -1.0f;
                        }
                        else
                        {
                            _10589 = float((_8764 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10590 = _10589;
                        break;
                    }
                    int _10572;
                    uint _10573;
                    _10573 = _8764;
                    _10572 = -1;
                    uint _10588;
                    for (; _10572 <= 1; _10573 = _10588, _10572++)
                    {
                        _10588 = _10573;
                        for (int _10586 = -1; _10586 <= 1; )
                        {
                            _10588 = max(_10588, r_warped_motion_qdata_tp1.Load(int3(clamp(_10066 + int2(_10586, _10572), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10586++;
                            continue;
                        }
                    }
                    if (_10573 != 0u)
                    {
                        float _10585;
                        if (_10573 == 0u)
                        {
                            _10585 = -1.0f;
                        }
                        else
                        {
                            _10585 = float((_10573 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10590 = _10585;
                        break;
                    }
                    uint _10575;
                    _10575 = 4294967295u;
                    uint _11957;
                    for (int _10574 = 0; _10574 < 8; _10575 = _11957, _10574++)
                    {
                        int _10578 = 0;
                        for (;;)
                        {
                            if (_10578 < 5)
                            {
                                int2 _8714 = _10066 + (_1093[_10574] * _1102[_10578].xx);
                                bool _8717 = any(bool2(_8714.x < int2(0, 0).x, _8714.y < int2(0, 0).y));
                                bool _8725;
                                if (!_8717)
                                {
                                    _8725 = any(bool2(_8714.x >= cbFI_MvDepthLaneSize.x, _8714.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8725 = _8717;
                                }
                                if (_8725)
                                {
                                    _11957 = _10575;
                                    break;
                                }
                                uint4 _8803 = r_warped_motion_qdata_tp1.Load(int3(_8714, 0));
                                uint _8804 = _8803.x;
                                if (_8804 != 0u)
                                {
                                    _11957 = min(_10575, _8804);
                                    break;
                                }
                                _10578++;
                                continue;
                            }
                            else
                            {
                                _11957 = _10575;
                                break;
                            }
                        }
                    }
                    float _10577;
                    if (_10575 == 4294967295u)
                    {
                        _10577 = -1.0f;
                    }
                    else
                    {
                        float _10576;
                        if (_10575 == 0u)
                        {
                            _10576 = -1.0f;
                        }
                        else
                        {
                            _10576 = float((_10575 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10577 = _10576;
                    }
                    _10590 = _10577;
                    break;
                } while(false);
                float4 _10619;
                if (_10590 >= 0.0f)
                {
                    float _8825 = (exp((_10590 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4991;
                    if (_4769)
                    {
                        uint _8832_dummy_parameter;
                        _4991 = r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8832_dummy_parameter))))), 0)).x > _8825;
                    }
                    else
                    {
                        _4991 = _4769;
                    }
                    float4 _10608;
                    if (_4991)
                    {
                        float4 _9925 = _10595;
                        _9925.z = 0.0f;
                        _10608 = _9925;
                    }
                    else
                    {
                        _10608 = _10595;
                    }
                    bool _5003;
                    if (_4775)
                    {
                        uint _8851_dummy_parameter;
                        _5003 = r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8851_dummy_parameter))))), 0)).x > _8825;
                    }
                    else
                    {
                        _5003 = _4775;
                    }
                    float4 _10620;
                    if (_5003)
                    {
                        float4 _9927 = _10608;
                        _9927.w = 0.0f;
                        _10620 = _9927;
                    }
                    else
                    {
                        _10620 = _10608;
                    }
                    _10619 = _10620;
                }
                else
                {
                    _10619 = _10595;
                }
                _10618 = _10619;
            }
            else
            {
                _10618 = _10595;
            }
            bool _5011 = _4757 != _4763;
            bool _5018;
            if (_5011)
            {
                _5018 = _4757 ? _4703 : _4706;
            }
            else
            {
                _5018 = _5011;
            }
            bool _5025;
            if (_5018)
            {
                _5025 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5025 = _5018;
            }
            float4 _10703;
            if (_5025)
            {
                bool2 _5030 = _4757.xx;
                float2 _5031 = float2(_5030.x ? _10036.x : _10038.x, _5030.y ? _10036.y : _10038.y);
                float _10610;
                if (_4757)
                {
                    uint _8870_dummy_parameter;
                    _10610 = r_depth_tm1.Load(int3(int2(floor(_5031 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8870_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8886_dummy_parameter;
                    _10610 = r_depth_tp1.Load(int3(int2(floor(_5031 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8886_dummy_parameter))))), 0)).x;
                }
                float4x4 _10611;
                if (_4757)
                {
                    _10611 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10611 = cbFI_MotionTP1ToTM1;
                }
                float2 _10612;
                do
                {
                    float _8913 = _5031.x;
                    float _8916 = 1.0f - _5031.y;
                    float4 _8927 = mul(float4((float2(_8913, _8916) * 2.0f) - 1.0f.xx, _10610, 1.0f), _10611);
                    float _8929 = _8927.w;
                    if (!(_8929 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10612 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8942 = ((_8927.xy / _8929.xx) + 1.0f.xx) * 0.5f;
                    _10612 = float2(_8942.x - _8913, _8916 - _8942.y);
                    break;
                } while(false);
                float2 _5061 = float2(cbFI_DisplaySize);
                float4 _10704;
                if (!(length(((_5031 + _10612) - float2(_5030.x ? _10038.x : _10036.x, _5030.y ? _10038.y : _10036.y)) * _5061) <= ((0.100000001490116119384765625f * length(_10612 * _5061)) + 8.0f)))
                {
                    float4 _10705;
                    if (_4757)
                    {
                        float4 _9937 = _10618;
                        _9937.x = 0.0f;
                        _10705 = _9937;
                    }
                    else
                    {
                        float4 _9939 = _10618;
                        _9939.y = 0.0f;
                        _10705 = _9939;
                    }
                    _10704 = _10705;
                }
                else
                {
                    _10704 = _10618;
                }
                _10703 = _10704;
            }
            else
            {
                _10703 = _10618;
            }
            float4 _5086 = _10375 * _10703;
            float _5088 = dot(_5086, 1.0f.xxxx);
            float4 _10922;
            bool _10942;
            if (_5088 > 0.0f)
            {
                _10942 = _10189;
                _10922 = _5086 / _5088.xxxx;
            }
            else
            {
                bool _5099 = any(bool4(_10703.x < 1.0f.xxxx.x, _10703.y < 1.0f.xxxx.y, _10703.z < 1.0f.xxxx.z, _10703.w < 1.0f.xxxx.w));
                if (_5099)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8964;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8964);
                    }
                }
                bool4 _11989 = _5099.xxxx;
                _10942 = _5099 ? true : _10189;
                _10922 = float4(_11989.x ? 0.0f.xxxx.x : _10375.x, _11989.y ? 0.0f.xxxx.y : _10375.y, _11989.z ? 0.0f.xxxx.z : _10375.z, _11989.w ? 0.0f.xxxx.w : _10375.w);
            }
            _11055 = _11133;
            _10941 = _10942;
            _10921 = _10922;
        }
        else
        {
            _11055 = float3(0.0f, 0.0f, 0.5f);
            _10941 = _10189;
            _10921 = _10375;
        }
        uint _5108 = (cbFI_pad0 >> 24u) & 31u;
        uint _5112 = (cbFI_pad0 >> 16u) & 255u;
        bool _5114 = _5108 != 0u;
        bool _5116 = _5112 == 12u;
        bool _5119 = _5112 == 13u;
        float4 _10938;
        if ((_5114 || _5116) || _5119)
        {
            float _10706;
            do
            {
                bool _9048 = all(bool2(_10039.x > 0.0f.xx.x, _10039.y > 0.0f.xx.y));
                bool _9054;
                if (_9048)
                {
                    _9054 = all(bool2(_10039.x < 1.0f.xx.x, _10039.y < 1.0f.xx.y));
                }
                else
                {
                    _9054 = _9048;
                }
                bool _8985 = !_9054;
                bool _8992;
                if (!_8985)
                {
                    bool _9059 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
                    bool _9065;
                    if (_9059)
                    {
                        _9065 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9065 = _9059;
                    }
                    _8992 = !_9065;
                }
                else
                {
                    _8992 = _8985;
                }
                if (_8992)
                {
                    _10706 = 0.0f;
                    break;
                }
                uint _9072_dummy_parameter;
                uint _9088_dummy_parameter;
                float4 _9013 = mul(float4((float2(_10039.x, 1.0f - _10039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9072_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9015 = _9013.w;
                if (abs(_9015) < 9.9999999747524270787835121154785e-07f)
                {
                    _10706 = 0.0f;
                    break;
                }
                float _9026 = abs(cbFI_DeviceToViewDepth.y / ((_9013.z / _9015) - cbFI_DeviceToViewDepth.x));
                float _9029 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9088_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10706 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9026 - _9029) / max(max(_9026, _9029), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9136 = all(bool2(_10040.x > 0.0f.xx.x, _10040.y > 0.0f.xx.y));
            bool _9142;
            if (_9136)
            {
                _9142 = all(bool2(_10040.x < 1.0f.xx.x, _10040.y < 1.0f.xx.y));
            }
            else
            {
                _9142 = _9136;
            }
            float _10707;
            if (_9142)
            {
                uint _9149_dummy_parameter;
                _10707 = length((_5919 + (r_motion_tp1.Load(int3(int2(floor(_10040 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9149_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10707 = 1000000.0f;
            }
            float _10718;
            if ((_5108 & 1u) != 0u)
            {
                _10718 = _10706;
            }
            else
            {
                _10718 = 1.0f;
            }
            float _10719;
            if ((_5108 & 2u) != 0u)
            {
                _10719 = _10718 * (1.0f - smoothstep(2.0f, 8.0f, _10707));
            }
            else
            {
                _10719 = _10718;
            }
            float _10720;
            if ((_5108 & 4u) != 0u)
            {
                _10720 = _10719 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6640 - _6648) - length(_6624 - _6632))));
            }
            else
            {
                _10720 = _10719;
            }
            float _10932;
            if ((_5108 & 8u) != 0u)
            {
                _10932 = lerp(1.0f, _10720, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6624 - _6632)));
            }
            else
            {
                _10932 = _10720;
            }
            bool _5194 = (_5108 & 16u) != 0u;
            bool _5203;
            if (_5194)
            {
                _5203 = length(_10034 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5203 = _5194;
            }
            float _11991 = _5203 ? 1.0f : _10932;
            bool _5209 = _5114 && _6833;
            bool _5214;
            if (_5209)
            {
                bool _9174 = all(bool2(_10036.x > 0.0f.xx.x, _10036.y > 0.0f.xx.y));
                bool _9180;
                if (_9174)
                {
                    _9180 = all(bool2(_10036.x < 1.0f.xx.x, _10036.y < 1.0f.xx.y));
                }
                else
                {
                    _9180 = _9174;
                }
                _5214 = _9180;
            }
            else
            {
                _5214 = _5209;
            }
            bool _5219;
            if (_5214)
            {
                bool _9185 = all(bool2(_10038.x > 0.0f.xx.x, _10038.y > 0.0f.xx.y));
                bool _9191;
                if (_9185)
                {
                    _9191 = all(bool2(_10038.x < 1.0f.xx.x, _10038.y < 1.0f.xx.y));
                }
                else
                {
                    _9191 = _9185;
                }
                _5219 = _9191;
            }
            else
            {
                _5219 = _5214;
            }
            float4 _10939;
            if (_5219)
            {
                float _5225 = _10921.x + _10921.y;
                float _5234 = (_10921.z + _10921.w) * (1.0f - _11991);
                float _10935;
                if (_5225 > 9.9999997473787516355514526367188e-06f)
                {
                    _10935 = _10921.x / _5225;
                }
                else
                {
                    _10935 = _4221;
                }
                _10939 = float4(_10921.x + (_5234 * _10935), _10921.y + (_5234 * (1.0f - _10935)), _10921.zw * _11991);
            }
            else
            {
                _10939 = _10921;
            }
            _10938 = _10939;
        }
        else
        {
            _10938 = _10921;
        }
        float3 _11759;
        if (_10941)
        {
            float3 _9197 = r_current_interpolation_source.Load(int3(_3596, 0)).xyz;
            float3 _11760;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6833)
            {
                uint _9204_dummy_parameter;
                float _11046;
                _11046 = r_depth_tm1.Load(int3(int2(floor(_10036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9204_dummy_parameter))))), 0)).x;
                float _5346;
                for (int _11045 = 0; _11045 < 24; _11046 = _5346, _11045++)
                {
                    float _5318 = float(_11045 & 7) * 0.785398185253143310546875f;
                    int _5320 = _11045 >> 3;
                    int _11810;
                    if (_5320 == 0)
                    {
                        _11810 = 16;
                    }
                    else
                    {
                        _11810 = (_5320 == 1) ? 48 : 96;
                    }
                    uint _9224_dummy_parameter;
                    _5346 = min(_11046, r_depth_tm1.Load(int3(int2(floor(clamp(_10036 + ((cbFI_MvDepthLaneSizeRcp * float(_11810)) * float2(cos(_5318), sin(_5318))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9224_dummy_parameter))))), 0)).x);
                }
                float2 _11047;
                do
                {
                    float _9246 = 1.0f - _10036.y;
                    float4 _9257 = mul(float4((float2(_10036.x, _9246) * 2.0f) - 1.0f.xx, _11046, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9259 = _9257.w;
                    if (!(_9259 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11047 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9272 = ((_9257.xy / _9259.xx) + 1.0f.xx) * 0.5f;
                    _11047 = float2(_9272.x - _10036.x, _9246 - _9272.y);
                    break;
                } while(false);
                float2 _5357 = _10036 + _11047;
                bool _9290 = all(bool2(_5357.x > 0.0f.xx.x, _5357.y > 0.0f.xx.y));
                bool _9296;
                if (_9290)
                {
                    _9296 = all(bool2(_5357.x < 1.0f.xx.x, _5357.y < 1.0f.xx.y));
                }
                else
                {
                    _9296 = _9290;
                }
                float3 _11761;
                if (_9296)
                {
                    float _5363 = abs(cbFI_DeviceToViewDepth.y / (_11046 - cbFI_DeviceToViewDepth.x));
                    uint _9316_dummy_parameter;
                    int2 _9316 = int2(spvTextureSize(r_depth_m2, uint(0), _9316_dummy_parameter));
                    float _5367 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5357 * float2(_9316))), int2(0, 0), _9316 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11766;
                    if (abs(_5367 - _5363) <= (0.20000000298023223876953125f * max(_5367, _5363)))
                    {
                        uint _9350_dummy_parameter;
                        int2 _9350 = int2(spvTextureSize(r_colour_m2, uint(0), _9350_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9373;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9373);
                        }
                        _11766 = r_colour_m2.Load(int3(clamp(int2(floor(_5357 * float2(_9350))), int2(0, 0), _9350 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9383;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9383);
                        }
                        _11766 = _9197;
                    }
                    _11761 = _11766;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9393;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9393);
                    }
                    _11761 = _9197;
                }
                _11760 = _11761;
            }
            else
            {
                _11760 = _9197;
            }
            _11759 = _11760;
        }
        else
        {
            _11759 = (((_6624 * _10938.x) + (_6632 * _10938.y)) + (_6640 * _10938.z)) + (_6648 * _10938.w);
        }
        uint _5395 = cbFI_pad0 & 255u;
        bool _11651;
        float3 _11758;
        if (_5395 != 0u)
        {
            float3 _5400 = r_present_backbuffer.Load(int3(_3596, 0)).xyz;
            float3 _5404 = r_current_interpolation_source.Load(int3(_3596, 0)).xyz;
            float3 _5408 = abs(_5400 - _5404);
            float3 _11050;
            if (_5395 == 2u)
            {
                _11050 = (abs(_5404) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11050 = 0.000244140625f.xxx;
            }
            bool _5424 = any(bool3(_5408.x > _11050.x, _5408.y > _11050.y, _5408.z > _11050.z));
            bool3 _11992 = _5424.xxx;
            _11758 = float3(_11992.x ? _5400.x : _11759.x, _11992.y ? _5400.y : _11759.y, _11992.z ? _5400.z : _11759.z);
            _11651 = _5424;
        }
        else
        {
            _11758 = _11759;
            _11651 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9408;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9408);
        }
        float3 _11741;
        if (_5112 == 1u)
        {
            _11741 = lerp(_6624, _6632, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11742;
            if (_5112 == 2u)
            {
                _11742 = lerp(_6640, _6648, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11743;
                if (_5112 == 3u)
                {
                    _11743 = float(_11651).xxx;
                }
                else
                {
                    float3 _11744;
                    if (_5112 == 4u)
                    {
                        _11744 = float3(((_10034 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11745;
                        if (_5112 == 5u)
                        {
                            _11745 = float3(((_5919 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11746;
                            if (_5112 == 6u)
                            {
                                _11746 = float3(_10938.xy, _10938.z + _10938.w);
                            }
                            else
                            {
                                float3 _11747;
                                if (_5112 == 7u)
                                {
                                    _11747 = r_current_interpolation_source.Load(int3(_3596, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11748;
                                    if (_5112 == 8u)
                                    {
                                        _11748 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3996, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11749;
                                        if (_5116)
                                        {
                                            uint _9430_dummy_parameter;
                                            uint _9462_dummy_parameter;
                                            _11749 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3996 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9430_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3996 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9462_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11750;
                                            if (_5119)
                                            {
                                                _11750 = _6640;
                                            }
                                            else
                                            {
                                                float3 _11751;
                                                if (_5112 == 20u)
                                                {
                                                    _11751 = _6624;
                                                }
                                                else
                                                {
                                                    float3 _11752;
                                                    if (_5112 == 21u)
                                                    {
                                                        _11752 = _6632;
                                                    }
                                                    else
                                                    {
                                                        float3 _11753;
                                                        if (_5112 == 22u)
                                                        {
                                                            _11753 = _6648;
                                                        }
                                                        else
                                                        {
                                                            float3 _11754;
                                                            if (_5112 == 18u)
                                                            {
                                                                _11754 = _11419;
                                                            }
                                                            else
                                                            {
                                                                float3 _11755;
                                                                if (_5112 == 19u)
                                                                {
                                                                    _11755 = _11234;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11994 = (_5112 == 23u).xxx;
                                                                    _11755 = float3(_11994.x ? _11055.x : _11758.x, _11994.y ? _11055.y : _11758.y, _11994.z ? _11055.z : _11758.z);
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
                                    _11747 = _11748;
                                }
                                _11746 = _11747;
                            }
                            _11745 = _11746;
                        }
                        _11744 = _11745;
                    }
                    _11743 = _11744;
                }
                _11742 = _11743;
            }
            _11741 = _11742;
        }
        float3 _11740;
        if ((_5112 >= 9u) && (_5112 <= 11u))
        {
            uint _5588 = 64u + uint((_10066.y * cbFI_MvDepthLaneSize.x) + _10066.x);
            uint _5592 = rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) & 15u;
            float3 _11771;
            if (_5112 == 10u)
            {
                float3 _11739;
                if ((rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) & 32u) != 0u)
                {
                    _11739 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11738;
                    if ((rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) & 16u) != 0u)
                    {
                        _11738 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5613 = ((rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) & 64u) != 0u).xxx;
                        _11738 = float3(_5613.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5613.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5613.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11739 = _11738;
                }
                _11771 = _11739;
            }
            else
            {
                float3 _11772;
                if (_5112 == 11u)
                {
                    uint _5626 = (rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) >> 8u) & 15u;
                    uint _5629 = (rw_nfru_diagnostics.Load<uint>(_5588 * 4 + 0) >> 12u) & 15u;
                    float3 _11731;
                    if ((_5592 == 2u) || (_5592 == 3u))
                    {
                        _11731 = _3292[_5592];
                    }
                    else
                    {
                        bool _5641 = _5626 == 3u;
                        bool _5643 = _5629 == 3u;
                        float3 _11732;
                        if (_5641 && _5643)
                        {
                            _11732 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11733;
                            if (_5641)
                            {
                                _11733 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11734;
                                if (_5643)
                                {
                                    _11734 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11735;
                                    if ((_5626 == 4u) || (_5629 == 4u))
                                    {
                                        _11735 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11736;
                                        if ((_5626 == 1u) || (_5629 == 1u))
                                        {
                                            _11736 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11996 = (_5592 == 1u).xxx;
                                            _11736 = float3(_11996.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11996.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11996.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
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
                    _11772 = _11731;
                }
                else
                {
                    _11772 = _3292[min(_5592, 7u)];
                }
                _11771 = _11772;
            }
            _11740 = _11771;
        }
        else
        {
            _11740 = _11741;
        }
        float4 _11775;
        if ((_5112 >= 14u) && (_5112 <= 16u))
        {
            float2 _11773;
            if (_5112 == 14u)
            {
                uint _5699_dummy_parameter;
                uint _5705_dummy_parameter;
                _11773 = r_flow_tm1.Load(int3(clamp(int2(floor(_3996 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5699_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5705_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11774;
                if (_5112 == 16u)
                {
                    uint _9513 = r_warped_flow_qdata_tm1.Load(int3(_4012, 0)).x & 2147483647u;
                    uint _9545 = uint(max((int((_9513 >> 16u) & 15u) - 6), 0));
                    _11774 = ((float2(float((1 - (2 * int((_9513 >> 15u) & 1u))) * int(((_9513 >> uint(7)) & 127u) << _9545)), float((1 - (2 * int((_9513 >> 14u) & 1u))) * int((_9513 & 127u) << _9545))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11774 = _5919 * float2(cbFI_DisplaySize);
                }
                _11773 = _11774;
            }
            uint2 _5738 = uint2(clamp(round(_11773 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5740 = _5738.x;
            uint _5747 = _5738.y;
            _11775 = float4(float(_5740 & 255u), float((_5740 >> 8u) | ((_5747 & 15u) << 4u)), float(_5747 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11776;
            if (_5112 == 17u)
            {
                _11776 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4012, 0)).x != 0u), _4355, 0.0f, 1.0f);
            }
            else
            {
                _11776 = float4(_11740, 1.0f);
            }
            _11775 = _11776;
        }
        rw_output[_3596] = _11775.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5791 = ((uint(_3596.y) * uint(cbFI_DisplaySize.x)) + uint(_3596.x)) * 6u;
            uint _9591 = spvPackHalf2x16(clamp(_6623.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5791 * 4 + 0, (((_9591 & 32767u) >> 4u) | ((((_9591 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6623.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9626 = spvPackHalf2x16(clamp(_6631.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5791 + 1u) * 4 + 0, (((_9626 & 32767u) >> 4u) | ((((_9626 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6631.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9661 = spvPackHalf2x16(clamp(_6639.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5791 + 2u) * 4 + 0, (((_9661 & 32767u) >> 4u) | ((((_9661 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6639.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9696 = spvPackHalf2x16(clamp(_6647.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5791 + 3u) * 4 + 0, (((_9696 & 32767u) >> 4u) | ((((_9696 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6647.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9723 = r_current_interpolation_source.Load(int3(_3596, 0));
            uint _9737 = spvPackHalf2x16(clamp(_9723.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5791 + 4u) * 4 + 0, (((_9737 & 32767u) >> 4u) | ((((_9737 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9723.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11809;
            if (_11651 || (_5112 != 0u))
            {
                _11809 = 4294967295u;
            }
            else
            {
                uint _9772 = spvPackHalf2x16(clamp(_11775.xy, 0.0f.xx, 65000.0f.xx));
                _11809 = (((_9772 & 32767u) >> 4u) | ((((_9772 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11775.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5791 + 5u) * 4 + 0, _11809);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3596] = float4(r_current_interpolation_source.Load(int3(_3596, 0)).xyz, 1.0f).xyz;
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
