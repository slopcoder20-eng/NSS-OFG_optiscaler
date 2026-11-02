static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3289[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3593 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3593.x >= cbFI_DisplaySize.x, _3593.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3593] = float4(r_present_backbuffer.Load(int3(_3593, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3593] = float4(r_current_interpolation_source.Load(int3(_3593, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3992 = (float2(_3593) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4003 = int2(floor(_3992 * float2(cbFI_MvDepthLaneSize)));
        int2 _4008 = int2(floor(_3992 * float2(cbFI_FlowLaneSize)));
        float4 _5908 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3992 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5914 = r_warped_filled_flow_tm1.Load(int3(_4008, 0)).xy;
        float2 _5920 = r_warped_filled_motion_tp1.Load(int3(_4003, 0)).xy;
        bool _5942 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9998;
        if (_5942)
        {
            float _5955 = ((2.0f * _3992.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9998 = float2(atan(_5955) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3992.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5955 * _5955))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9998 = _3992;
        }
        bool _4029 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10019;
        bool _10040;
        int2 _10051;
        float3 _11397;
        if (_4029)
        {
            float _10000;
            float _10002;
            _10002 = 2.0f;
            _10000 = -1.0f;
            uint _3657[9];
            float _11828;
            float _11831;
            for (int _9999 = 0; _9999 < 9; _10002 = _11831, _10000 = _11828, _9999++)
            {
                _3657[_9999] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4003 + int2((_9999 % 3) - 1, (_9999 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3657[_9999] != 0u)
                {
                    float _11823;
                    if (_3657[_9999] == 0u)
                    {
                        _11823 = -1.0f;
                    }
                    else
                    {
                        _11823 = float((_3657[_9999] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11831 = min(_10002, _11823);
                    _11828 = max(_10000, _11823);
                }
                else
                {
                    _11831 = _10002;
                    _11828 = _10000;
                }
            }
            float _4075 = float(_10000 >= 0.0f);
            float3 _9799 = 0.0f.xxx;
            _9799.y = _4075;
            float2 _10020;
            bool _10041;
            int2 _10052;
            float3 _11398;
            if ((_10000 - _10002) > 0.0199999995529651641845703125f)
            {
                float _10008;
                int2 _10009;
                float2 _10010;
                int2 _10012;
                float2 _10018;
                _10018 = _5920;
                _10012 = _4003;
                _10010 = _5920;
                _10009 = _4003;
                _10008 = -1.0f;
                float _11836;
                int2 _11840;
                float2 _11851;
                int2 _11862;
                float2 _11895;
                float _11942;
                int _10007 = 0;
                float _11804 = 1000000000.0f;
                for (; _10007 < 9; _11804 = _11942, _10018 = _11895, _10012 = _11862, _10010 = _11851, _10009 = _11840, _10008 = _11836, _10007++)
                {
                    if (_3657[_10007] == 0u)
                    {
                        _11942 = _11804;
                        _11895 = _10018;
                        _11862 = _10012;
                        _11851 = _10010;
                        _11840 = _10009;
                        _11836 = _10008;
                        continue;
                    }
                    int2 _4110 = clamp(_4003 + int2((_10007 % 3) - 1, (_10007 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6030 = _3657[_10007] & 2147483647u;
                    uint _6062 = uint(max((int((_6030 >> 16u) & 15u) - 6), 0));
                    float2 _4116 = (float2(float((1 - (2 * int((_6030 >> 15u) & 1u))) * int(((_6030 >> uint(7)) & 127u) << _6062)), float((1 - (2 * int((_6030 >> 14u) & 1u))) * int((_6030 & 127u) << _6062))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11790;
                    if (_3657[_10007] == 0u)
                    {
                        _11790 = -1.0f;
                    }
                    else
                    {
                        _11790 = float((_3657[_10007] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4121 = _11790 - 0.100000001490116119384765625f;
                    float2 _11791;
                    if (_5942)
                    {
                        float2 _6139 = clamp((((_9998 + (_4116 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6142 = tan(_6139.x);
                        _11791 = (float2(_6142 / cbFI_DeviceToViewDepth.z, (tan(_6139.y) * sqrt(1.0f + (_6142 * _6142))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11791 = _9998 + (_4116 * cbFI_Timestep);
                    }
                    float _4128 = cbFI_Timestep - 1.0f;
                    float2 _11792;
                    if (_5942)
                    {
                        float2 _6210 = clamp((((_9998 + (_4116 * _4128)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6213 = tan(_6210.x);
                        _11792 = (float2(_6213 / cbFI_DeviceToViewDepth.z, (tan(_6210.y) * sqrt(1.0f + (_6213 * _6213))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11792 = _9998 + (_4116 * _4128);
                    }
                    bool _6246 = all(bool2(_11791.x > 0.0f.xx.x, _11791.y > 0.0f.xx.y));
                    bool _6252;
                    if (_6246)
                    {
                        _6252 = all(bool2(_11791.x < 1.0f.xx.x, _11791.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6252 = _6246;
                    }
                    float _11795;
                    if (_6252)
                    {
                        uint _6259_dummy_parameter;
                        _11795 = max((_4121 - (log((r_depth_tm1.Load(int3(int2(floor(_11791 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6259_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11795 = 0.0f;
                    }
                    bool _6289 = all(bool2(_11792.x > 0.0f.xx.x, _11792.y > 0.0f.xx.y));
                    bool _6295;
                    if (_6289)
                    {
                        _6295 = all(bool2(_11792.x < 1.0f.xx.x, _11792.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6295 = _6289;
                    }
                    float _11796;
                    if (_6295)
                    {
                        uint _6302_dummy_parameter;
                        _11796 = _11795 + max((_4121 - (log((r_depth_tp1.Load(int3(int2(floor(_11792 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6302_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11796 = _11795;
                    }
                    float _11837;
                    int2 _11841;
                    float2 _11852;
                    int2 _11863;
                    float2 _11896;
                    float _11943;
                    if (_11796 == 0.0f)
                    {
                        bool _4163 = _4121 > _10008;
                        bool2 _11951 = _4163.xx;
                        _11943 = _11804;
                        _11896 = float2(_11951.x ? _4116.x : _10018.x, _11951.y ? _4116.y : _10018.y);
                        _11863 = int2(_11951.x ? _4110.x : _10012.x, _11951.y ? _4110.y : _10012.y);
                        _11852 = _10010;
                        _11841 = _10009;
                        _11837 = _4163 ? _4121 : _10008;
                    }
                    else
                    {
                        bool _4172 = _11796 < _11804;
                        bool2 _11947 = _4172.xx;
                        _11943 = _4172 ? _11796 : _11804;
                        _11896 = _10018;
                        _11863 = _10012;
                        _11852 = float2(_11947.x ? _4116.x : _10010.x, _11947.y ? _4116.y : _10010.y);
                        _11841 = int2(_11947.x ? _4110.x : _10009.x, _11947.y ? _4110.y : _10009.y);
                        _11837 = _10008;
                    }
                    _11942 = _11943;
                    _11895 = _11896;
                    _11862 = _11863;
                    _11851 = _11852;
                    _11840 = _11841;
                    _11836 = _11837;
                }
                bool _4184 = _10008 < 0.0f;
                bool2 _11957 = _4184.xx;
                int2 _11960 = int2(_11957.x ? _10009.x : _10012.x, _11957.y ? _10009.y : _10012.y);
                _11398 = float3(1.0f, _4075, float(any(bool2(_11960.x != _4003.x, _11960.y != _4003.y))));
                _10052 = _11960;
                _10041 = _4184 ? false : true;
                _10020 = float2(_11957.x ? _10010.x : _10018.x, _11957.y ? _10010.y : _10018.y);
            }
            else
            {
                _11398 = _9799;
                _10052 = _4003;
                _10041 = false;
                _10020 = _5920;
            }
            _11397 = _11398;
            _10051 = _10052;
            _10040 = _10041;
            _10019 = _10020;
        }
        else
        {
            _11397 = 0.0f.xxx;
            _10051 = _4003;
            _10040 = false;
            _10019 = _5920;
        }
        float2 _10021;
        if (_5942)
        {
            float2 _6367 = clamp((((_9998 + (_10019 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6370 = tan(_6367.x);
            _10021 = (float2(_6370 / cbFI_DeviceToViewDepth.z, (tan(_6367.y) * sqrt(1.0f + (_6370 * _6370))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10021 = _9998 + (_10019 * cbFI_Timestep);
        }
        float _4207 = cbFI_Timestep - 1.0f;
        float2 _10023;
        if (_5942)
        {
            float2 _6438 = clamp((((_9998 + (_10019 * _4207)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6441 = tan(_6438.x);
            _10023 = (float2(_6441 / cbFI_DeviceToViewDepth.z, (tan(_6438.y) * sqrt(1.0f + (_6441 * _6441))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10023 = _9998 + (_10019 * _4207);
        }
        float _4212 = -cbFI_Timestep;
        float2 _10024;
        if (_5942)
        {
            float2 _6509 = clamp((((_9998 + (_5914 * _4212)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6512 = tan(_6509.x);
            _10024 = (float2(_6512 / cbFI_DeviceToViewDepth.z, (tan(_6509.y) * sqrt(1.0f + (_6512 * _6512))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10024 = _9998 + (_5914 * _4212);
        }
        float _4217 = 1.0f - cbFI_Timestep;
        float2 _10025;
        if (_5942)
        {
            float2 _6580 = clamp((((_9998 + (_5914 * _4217)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6583 = tan(_6580.x);
            _10025 = (float2(_6583 / cbFI_DeviceToViewDepth.z, (tan(_6580.y) * sqrt(1.0f + (_6583 * _6583))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10025 = _9998 + (_5914 * _4217);
        }
        float4 _6618 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10021, 0.0f);
        float3 _6619 = _6618.xyz;
        float4 _6626 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10023, 0.0f);
        float3 _6627 = _6626.xyz;
        float4 _6634 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10024, 0.0f);
        float3 _6635 = _6634.xyz;
        float4 _6642 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10025, 0.0f);
        float3 _6643 = _6642.xyz;
        float4 _6657 = exp(_5908 - max(max(max(_5908.x, _5908.y), _5908.z), _5908.w).xxxx);
        float4 _6664 = _6657 / (dot(_6657, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4236 = _4029 && (!_10040);
        bool _4245;
        if (_4236)
        {
            _4245 = (_6664.z + _6664.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4245 = _4236;
        }
        bool _4256;
        if (_4245)
        {
            _4256 = length((_10024 - _10021) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4256 = _4245;
        }
        bool _10064;
        if (_4256)
        {
            uint4 _6683 = r_warped_motion_qdata_tp1.Load(int3(_10051, 0));
            uint _6684 = _6683.x;
            bool _10067;
            if (_6684 != 0u)
            {
                float _10053;
                if (_6684 == 0u)
                {
                    _10053 = -1.0f;
                }
                else
                {
                    _10053 = float((_6684 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4266 = _10053 - 0.12000000476837158203125f;
                bool _6703 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                bool _6709;
                if (_6703)
                {
                    _6709 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                }
                else
                {
                    _6709 = _6703;
                }
                bool _4276;
                if (_6709)
                {
                    uint _6716_dummy_parameter;
                    _4276 = (log((r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6716_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4266;
                }
                else
                {
                    _4276 = _6709;
                }
                bool _4290;
                if (!_4276)
                {
                    bool _6746 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                    bool _6752;
                    if (_6746)
                    {
                        _6752 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6752 = _6746;
                    }
                    bool _4288;
                    if (_6752)
                    {
                        uint _6759_dummy_parameter;
                        _4288 = (log((r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6759_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4266;
                    }
                    else
                    {
                        _4288 = _6752;
                    }
                    _4290 = _4288;
                }
                else
                {
                    _4290 = _4276;
                }
                _10067 = _4290;
            }
            else
            {
                _10067 = false;
            }
            _10064 = _10067;
        }
        else
        {
            _10064 = false;
        }
        bool _4295 = _10040 || _10064;
        bool _4300;
        if (_4295)
        {
            bool _6789 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
            bool _6795;
            if (_6789)
            {
                _6795 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
            }
            else
            {
                _6795 = _6789;
            }
            _4300 = _6795;
        }
        else
        {
            _4300 = _4295;
        }
        bool _4305;
        if (_4300)
        {
            bool _6800 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
            bool _6806;
            if (_6800)
            {
                _6806 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
            }
            else
            {
                _6806 = _6800;
            }
            _4305 = _6806;
        }
        else
        {
            _4305 = _4300;
        }
        float4 _10161;
        if (_4305)
        {
            float _4308 = _6664.x;
            float _4310 = _6664.y;
            float _4311 = _4308 + _4310;
            float _4316 = _6664.z + _6664.w;
            float _10082;
            if (_4311 > 0.001000000047497451305389404296875f)
            {
                _10082 = _4308 / _4311;
            }
            else
            {
                _10082 = _4217;
            }
            _10161 = float4(_4308 + (_4316 * _10082), _4310 + (_4316 * (1.0f - _10082)), 0.0f, 0.0f);
        }
        else
        {
            _10161 = _6664;
        }
        bool _6834 = (cbFI_pad0 & 1024u) != 0u;
        bool _6810 = !_6834;
        bool _6811 = !_6810;
        bool _6828;
        if (_6811)
        {
            _6828 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10051.y * cbFI_MvDepthLaneSize.x) + _10051.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6828 = _6810;
        }
        bool _6860;
        if (_6811)
        {
            _6860 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4008.y * cbFI_FlowLaneSize.x) + _4008.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6860 = _6810;
        }
        float _4351 = float(_6860);
        bool _10174;
        float4 _10259;
        float3 _11213;
        if (_6834)
        {
            bool _4361;
            if (_6828)
            {
                _4361 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
            }
            else
            {
                _4361 = _6828;
            }
            bool _4367;
            if (_4361)
            {
                _4367 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
            }
            else
            {
                _4367 = _4361;
            }
            bool _4374;
            if (_6828)
            {
                _4374 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
            }
            else
            {
                _4374 = _6828;
            }
            bool _4380;
            if (_4374)
            {
                _4380 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
            }
            else
            {
                _4380 = _4374;
            }
            bool _4387;
            if (_6860)
            {
                _4387 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
            }
            else
            {
                _4387 = _6860;
            }
            bool _4393;
            if (_4387)
            {
                _4393 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
            }
            else
            {
                _4393 = _4387;
            }
            bool _4400;
            if (_6860)
            {
                _4400 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
            }
            else
            {
                _4400 = _6860;
            }
            bool _4406;
            if (_4400)
            {
                _4406 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
            }
            else
            {
                _4406 = _4400;
            }
            bool _4408 = !_6828;
            if (_4408)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6902;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6902);
                }
            }
            bool _4413 = !_6860;
            if (_4413)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6912;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6912);
                }
            }
            if (_6828 && _4413)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6922;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6922);
                }
            }
            if (_4408 && _6860)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6932;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6932);
                }
            }
            float _4432 = float(_4367);
            float _4434 = float(_4380);
            bool _4437 = _4393 && _4406;
            float _10116;
            if (_4437)
            {
                _10116 = 1.0f;
            }
            else
            {
                _10116 = (_4393 || _4406) ? 0.5f : 0.0f;
            }
            bool _10121;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4367)) && (!_4380))
            {
                bool _4467;
                if (_4437)
                {
                    float _10119;
                    do
                    {
                        bool _7016 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                        bool _7022;
                        if (_7016)
                        {
                            _7022 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7022 = _7016;
                        }
                        bool _6953 = !_7022;
                        bool _6960;
                        if (!_6953)
                        {
                            bool _7027 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                            bool _7033;
                            if (_7027)
                            {
                                _7033 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7033 = _7027;
                            }
                            _6960 = !_7033;
                        }
                        else
                        {
                            _6960 = _6953;
                        }
                        if (_6960)
                        {
                            _10119 = 0.0f;
                            break;
                        }
                        uint _7040_dummy_parameter;
                        uint _7056_dummy_parameter;
                        float4 _6981 = mul(float4((float2(_10024.x, 1.0f - _10024.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7040_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6983 = _6981.w;
                        if (abs(_6983) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10119 = 0.0f;
                            break;
                        }
                        float _6994 = abs(cbFI_DeviceToViewDepth.y / ((_6981.z / _6983) - cbFI_DeviceToViewDepth.x));
                        float _6997 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7056_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10119 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6994 - _6997) / max(max(_6994, _6997), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4467 = _10119 >= 0.5f;
                }
                else
                {
                    _4467 = _4437;
                }
                bool _4475;
                if (_4467)
                {
                    _4475 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4475 = _4467;
                }
                bool _10122;
                if (_4475)
                {
                    uint _7106_dummy_parameter;
                    float2 _10120;
                    do
                    {
                        float _7132 = 1.0f - _10024.y;
                        float4 _7143 = mul(float4((float2(_10024.x, _7132) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7106_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7145 = _7143.w;
                        if (!(_7145 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10120 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7158 = ((_7143.xy / _7145.xx) + 1.0f.xx) * 0.5f;
                        _10120 = float2(_7158.x - _10024.x, _7132 - _7158.y);
                        break;
                    } while(false);
                    float2 _4488 = float2(cbFI_DisplaySize);
                    _10122 = length(((_10024 + _10120) - _10025) * _4488) <= ((0.100000001490116119384765625f * length(_10120 * _4488)) + 8.0f);
                }
                else
                {
                    _10122 = _4467;
                }
                _10121 = _10122;
            }
            else
            {
                _10121 = true;
            }
            bool _4502 = !_10121;
            bool _11961 = _4502 ? false : _4406;
            bool _11962 = _4502 ? false : _4393;
            bool _10175;
            float4 _10260;
            if (!(((_4367 && _4380) && _11962) && _11961))
            {
                float4 _4524 = _10161 * float4(_4432, _4434, float(_11962), float(_11961));
                float _4526 = dot(_4524, 1.0f.xxxx);
                bool _4529 = !(_4526 > 0.0f);
                float4 _10261;
                if (!_4529)
                {
                    _10261 = _4524 / _4526.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7180;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7180);
                    }
                    _10261 = 0.0f.xxxx;
                }
                _10260 = _10261;
                _10175 = _4529;
            }
            else
            {
                _10260 = _10161;
                _10175 = false;
            }
            _11213 = float3(_4432, _4434, _10116);
            _10259 = _10260;
            _10174 = _10175;
        }
        else
        {
            _11213 = float3(float(_6828), _4351, 0.0f);
            _10259 = _10161;
            _10174 = false;
        }
        bool _4547 = !_10174;
        float4 _10357;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4547) && _6828)
        {
            float _10256;
            do
            {
                uint4 _7320 = r_warped_motion_qdata_tp1.Load(int3(_10051, 0));
                uint _7321 = _7320.x;
                if (_7321 != 0u)
                {
                    float _10255;
                    if (_7321 == 0u)
                    {
                        _10255 = -1.0f;
                    }
                    else
                    {
                        _10255 = float((_7321 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10256 = _10255;
                    break;
                }
                int _10238;
                uint _10239;
                _10239 = _7321;
                _10238 = -1;
                uint _10254;
                for (; _10238 <= 1; _10239 = _10254, _10238++)
                {
                    _10254 = _10239;
                    for (int _10252 = -1; _10252 <= 1; )
                    {
                        _10254 = max(_10254, r_warped_motion_qdata_tp1.Load(int3(clamp(_10051 + int2(_10252, _10238), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10252++;
                        continue;
                    }
                }
                if (_10239 != 0u)
                {
                    float _10251;
                    if (_10239 == 0u)
                    {
                        _10251 = -1.0f;
                    }
                    else
                    {
                        _10251 = float((_10239 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10256 = _10251;
                    break;
                }
                uint _10241;
                _10241 = 4294967295u;
                uint _11932;
                for (int _10240 = 0; _10240 < 8; _10241 = _11932, _10240++)
                {
                    int _10244 = 0;
                    for (;;)
                    {
                        if (_10244 < 5)
                        {
                            int2 _7271 = _10051 + (_1093[_10240] * _1102[_10244].xx);
                            bool _7274 = any(bool2(_7271.x < int2(0, 0).x, _7271.y < int2(0, 0).y));
                            bool _7282;
                            if (!_7274)
                            {
                                _7282 = any(bool2(_7271.x >= cbFI_MvDepthLaneSize.x, _7271.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7282 = _7274;
                            }
                            if (_7282)
                            {
                                _11932 = _10241;
                                break;
                            }
                            uint4 _7360 = r_warped_motion_qdata_tp1.Load(int3(_7271, 0));
                            uint _7361 = _7360.x;
                            if (_7361 != 0u)
                            {
                                _11932 = min(_10241, _7361);
                                break;
                            }
                            _10244++;
                            continue;
                        }
                        else
                        {
                            _11932 = _10241;
                            break;
                        }
                    }
                }
                float _10243;
                if (_10241 == 4294967295u)
                {
                    _10243 = -1.0f;
                }
                else
                {
                    float _10242;
                    if (_10241 == 0u)
                    {
                        _10242 = -1.0f;
                    }
                    else
                    {
                        _10242 = float((_10241 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10243 = _10242;
                }
                _10256 = _10243;
                break;
            } while(false);
            float _4558 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4562 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4568;
            if (_4562)
            {
                _4568 = _10259.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4568 = _4562;
            }
            bool _4573;
            if (_4568)
            {
                bool _7380 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
                bool _7386;
                if (_7380)
                {
                    _7386 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
                }
                else
                {
                    _7386 = _7380;
                }
                _4573 = _7386;
            }
            else
            {
                _4573 = _4568;
            }
            float4 _10302;
            if (_4573)
            {
                float _10277;
                if (_10256 >= 0.0f)
                {
                    _10277 = _10256 - _4558;
                }
                else
                {
                    float _10273;
                    _10273 = 2.0f;
                    float _7443;
                    for (int _10272 = 0; _10272 < 24; _10273 = _7443, _10272++)
                    {
                        float _7407 = float(_10272 & 7) * 0.785398185253143310546875f;
                        int _7409 = _10272 >> 3;
                        int _10274;
                        if (_7409 == 0)
                        {
                            _10274 = 16;
                        }
                        else
                        {
                            _10274 = (_7409 == 1) ? 48 : 96;
                        }
                        uint _7475_dummy_parameter;
                        _7443 = min(_10273, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10023 + ((cbFI_MvDepthLaneSizeRcp * float(_10274)) * float2(cos(_7407), sin(_7407))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7475_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10277 = _10273;
                }
                uint _7507_dummy_parameter;
                float4 _10303;
                if (r_depth_tp1.Load(int3(int2(floor(_10023 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7507_dummy_parameter))))), 0)).x > ((exp((_10277 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10303 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10303 = 1.0f.xxxx;
                }
                _10302 = _10303;
            }
            else
            {
                _10302 = 1.0f.xxxx;
            }
            bool _4600 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4606;
            if (_4600)
            {
                _4606 = _10259.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4606 = _4600;
            }
            bool _4611;
            if (_4606)
            {
                bool _7531 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
                bool _7537;
                if (_7531)
                {
                    _7537 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
                }
                else
                {
                    _7537 = _7531;
                }
                _4611 = _7537;
            }
            else
            {
                _4611 = _4606;
            }
            float4 _10306;
            if (_4611)
            {
                float _10297;
                if (_10256 >= 0.0f)
                {
                    _10297 = _10256 - _4558;
                }
                else
                {
                    float _10293;
                    _10293 = 2.0f;
                    float _7594;
                    for (int _10292 = 0; _10292 < 24; _10293 = _7594, _10292++)
                    {
                        float _7558 = float(_10292 & 7) * 0.785398185253143310546875f;
                        int _7560 = _10292 >> 3;
                        int _10294;
                        if (_7560 == 0)
                        {
                            _10294 = 16;
                        }
                        else
                        {
                            _10294 = (_7560 == 1) ? 48 : 96;
                        }
                        uint _7610_dummy_parameter;
                        _7594 = min(_10293, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10021 + ((cbFI_MvDepthLaneSizeRcp * float(_10294)) * float2(cos(_7558), sin(_7558))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7610_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10297 = _10293;
                }
                uint _7658_dummy_parameter;
                float4 _10307;
                if (r_depth_tm1.Load(int3(int2(floor(_10021 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7658_dummy_parameter))))), 0)).x > ((exp((_10297 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9867 = _10302;
                    _9867.x = 0.0f;
                    _10307 = _9867;
                }
                else
                {
                    _10307 = _10302;
                }
                _10306 = _10307;
            }
            else
            {
                _10306 = _10302;
            }
            float4 _10358;
            if (any(bool4(_10306.x < 1.0f.xxxx.x, _10306.y < 1.0f.xxxx.y, _10306.z < 1.0f.xxxx.z, _10306.w < 1.0f.xxxx.w)))
            {
                float4 _4641 = _10259 * _10306;
                float _4643 = dot(_4641, 1.0f.xxxx);
                float4 _10359;
                if (_4643 > 0.0f)
                {
                    _10359 = _4641 / _4643.xxxx;
                }
                else
                {
                    bool _4654 = _10306.y == 0.0f;
                    bool _4660;
                    if (_4654)
                    {
                        _4660 = _10306.x > 0.0f;
                    }
                    else
                    {
                        _4660 = _4654;
                    }
                    bool _4665;
                    if (_4660)
                    {
                        bool _7682 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
                        bool _7688;
                        if (_7682)
                        {
                            _7688 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7688 = _7682;
                        }
                        _4665 = _7688;
                    }
                    else
                    {
                        _4665 = _4660;
                    }
                    float4 _10360;
                    if (_4665)
                    {
                        _10360 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4670 = _10306.x == 0.0f;
                        bool _4676;
                        if (_4670)
                        {
                            _4676 = _10306.y > 0.0f;
                        }
                        else
                        {
                            _4676 = _4670;
                        }
                        bool _4681;
                        if (_4676)
                        {
                            bool _7693 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
                            bool _7699;
                            if (_7693)
                            {
                                _7699 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7699 = _7693;
                            }
                            _4681 = _7699;
                        }
                        else
                        {
                            _4681 = _4676;
                        }
                        bool4 _11963 = _4681.xxxx;
                        _10360 = float4(_11963.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10259.x, _11963.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10259.y, _11963.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10259.z, _11963.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10259.w);
                    }
                    _10359 = _10360;
                }
                _10358 = _10359;
            }
            else
            {
                _10358 = _10259;
            }
            _10357 = _10358;
        }
        else
        {
            _10357 = _10259;
        }
        float4 _10901;
        bool _10921;
        float3 _11035;
        if (((cbFI_pad0 & 32768u) != 0u) && _4547)
        {
            bool _4698 = _10357.x > 0.00999999977648258209228515625f;
            bool _4701 = _10357.y > 0.00999999977648258209228515625f;
            bool _4710 = (_10357.z + _10357.w) > 0.0199999995529651641845703125f;
            bool _4716;
            if (_4710)
            {
                bool _7704 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                bool _7710;
                if (_7704)
                {
                    _7710 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                }
                else
                {
                    _7710 = _7704;
                }
                _4716 = _7710;
            }
            else
            {
                _4716 = _4710;
            }
            bool _4721;
            if (_4716)
            {
                bool _7715 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                bool _7721;
                if (_7715)
                {
                    _7721 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                }
                else
                {
                    _7721 = _7715;
                }
                _4721 = _7721;
            }
            else
            {
                _4721 = _4716;
            }
            bool _4728;
            if (_4721)
            {
                float _10368;
                do
                {
                    bool _7804 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                    bool _7810;
                    if (_7804)
                    {
                        _7810 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7810 = _7804;
                    }
                    bool _7741 = !_7810;
                    bool _7748;
                    if (!_7741)
                    {
                        bool _7815 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                        bool _7821;
                        if (_7815)
                        {
                            _7821 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7821 = _7815;
                        }
                        _7748 = !_7821;
                    }
                    else
                    {
                        _7748 = _7741;
                    }
                    if (_7748)
                    {
                        _10368 = 0.0f;
                        break;
                    }
                    uint _7828_dummy_parameter;
                    uint _7844_dummy_parameter;
                    float4 _7769 = mul(float4((float2(_10024.x, 1.0f - _10024.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7828_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7771 = _7769.w;
                    if (abs(_7771) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10368 = 0.0f;
                        break;
                    }
                    float _7782 = abs(cbFI_DeviceToViewDepth.y / ((_7769.z / _7771) - cbFI_DeviceToViewDepth.x));
                    float _7785 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7844_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10368 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7782 - _7785) / max(max(_7782, _7785), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4728 = _10368 < 0.5f;
            }
            else
            {
                _4728 = _4721;
            }
            float4 _10383;
            if (_4728)
            {
                uint _7894_dummy_parameter;
                uint _7925_dummy_parameter;
                float4 _10384;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7894_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7925_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10384 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10384 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10383 = _10384;
            }
            else
            {
                _10383 = 1.0f.xxxx;
            }
            bool _4752;
            if (_6828)
            {
                bool _7954 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
                bool _7960;
                if (_7954)
                {
                    _7960 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
                }
                else
                {
                    _7960 = _7954;
                }
                _4752 = _7960;
            }
            else
            {
                _4752 = _6828;
            }
            bool _4758;
            if (_6828)
            {
                bool _7965 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
                bool _7971;
                if (_7965)
                {
                    _7971 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
                }
                else
                {
                    _7971 = _7965;
                }
                _4758 = _7971;
            }
            else
            {
                _4758 = _6828;
            }
            bool _4764;
            if (_6860)
            {
                bool _7976 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                bool _7982;
                if (_7976)
                {
                    _7982 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                }
                else
                {
                    _7982 = _7976;
                }
                _4764 = _7982;
            }
            else
            {
                _4764 = _6860;
            }
            bool _4770;
            if (_6860)
            {
                bool _7987 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                bool _7993;
                if (_7987)
                {
                    _7993 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                }
                else
                {
                    _7993 = _7987;
                }
                _4770 = _7993;
            }
            else
            {
                _4770 = _6860;
            }
            bool _4773 = _4764 != _4770;
            bool _4779;
            if (_4773)
            {
                _4779 = _4752 || _4758;
            }
            else
            {
                _4779 = _4773;
            }
            float4 _10471;
            if (_4779)
            {
                float4 _9894 = _10383;
                _9894.z = 0.0f;
                _9894.w = 0.0f;
                _10471 = _9894;
            }
            else
            {
                _10471 = _10383;
            }
            bool _4786 = _4752 && _4698;
            bool _4789 = _4758 && _4701;
            float4 _10576;
            float3 _11112;
            if (_4786 || _4789)
            {
                float _10466;
                do
                {
                    uint4 _8132 = r_warped_motion_qdata_tp1.Load(int3(_10051, 0));
                    uint _8133 = _8132.x;
                    if (_8133 != 0u)
                    {
                        float _10465;
                        if (_8133 == 0u)
                        {
                            _10465 = -1.0f;
                        }
                        else
                        {
                            _10465 = float((_8133 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10466 = _10465;
                        break;
                    }
                    int _10448;
                    uint _10449;
                    _10449 = _8133;
                    _10448 = -1;
                    uint _10464;
                    for (; _10448 <= 1; _10449 = _10464, _10448++)
                    {
                        _10464 = _10449;
                        for (int _10462 = -1; _10462 <= 1; )
                        {
                            _10464 = max(_10464, r_warped_motion_qdata_tp1.Load(int3(clamp(_10051 + int2(_10462, _10448), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10462++;
                            continue;
                        }
                    }
                    if (_10449 != 0u)
                    {
                        float _10461;
                        if (_10449 == 0u)
                        {
                            _10461 = -1.0f;
                        }
                        else
                        {
                            _10461 = float((_10449 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10466 = _10461;
                        break;
                    }
                    uint _10451;
                    _10451 = 4294967295u;
                    uint _11933;
                    for (int _10450 = 0; _10450 < 8; _10451 = _11933, _10450++)
                    {
                        int _10454 = 0;
                        for (;;)
                        {
                            if (_10454 < 5)
                            {
                                int2 _8083 = _10051 + (_1093[_10450] * _1102[_10454].xx);
                                bool _8086 = any(bool2(_8083.x < int2(0, 0).x, _8083.y < int2(0, 0).y));
                                bool _8094;
                                if (!_8086)
                                {
                                    _8094 = any(bool2(_8083.x >= cbFI_MvDepthLaneSize.x, _8083.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8094 = _8086;
                                }
                                if (_8094)
                                {
                                    _11933 = _10451;
                                    break;
                                }
                                uint4 _8172 = r_warped_motion_qdata_tp1.Load(int3(_8083, 0));
                                uint _8173 = _8172.x;
                                if (_8173 != 0u)
                                {
                                    _11933 = min(_10451, _8173);
                                    break;
                                }
                                _10454++;
                                continue;
                            }
                            else
                            {
                                _11933 = _10451;
                                break;
                            }
                        }
                    }
                    float _10453;
                    if (_10451 == 4294967295u)
                    {
                        _10453 = -1.0f;
                    }
                    else
                    {
                        float _10452;
                        if (_10451 == 0u)
                        {
                            _10452 = -1.0f;
                        }
                        else
                        {
                            _10452 = float((_10451 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10453 = _10452;
                    }
                    _10466 = _10453;
                    break;
                } while(false);
                bool _4797 = _10466 < 0.0f;
                float _10467;
                if (_4797)
                {
                    _10467 = 0.0f;
                }
                else
                {
                    _10467 = _10466 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8194_dummy_parameter;
                uint _8226_dummy_parameter;
                float4 _10504;
                if ((_4797 && _4786) && _4789)
                {
                    uint _8258_dummy_parameter;
                    float _8282 = log((r_depth_tm1.Load(int3(int2(floor(_10021 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8258_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8290_dummy_parameter;
                    float _8314 = log((r_depth_tp1.Load(int3(int2(floor(_10023 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8290_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10505;
                    if (_8282 > (_8314 + 0.07999999821186065673828125f))
                    {
                        float4 _9898 = _10471;
                        _9898.x = 0.0f;
                        _10505 = _9898;
                    }
                    else
                    {
                        float4 _10506;
                        if (_8314 > (_8282 + 0.07999999821186065673828125f))
                        {
                            float4 _9900 = _10471;
                            _9900.y = 0.0f;
                            _10506 = _9900;
                        }
                        else
                        {
                            _10506 = _10471;
                        }
                        _10505 = _10506;
                    }
                    _10504 = _10505;
                }
                else
                {
                    _10504 = _10471;
                }
                float _4849 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4851 = _10466 >= 0.0f;
                float _10487;
                if (_4851)
                {
                    _10487 = _10466 - _4849;
                }
                else
                {
                    float _10483;
                    if (_4786)
                    {
                        float _10482;
                        _10482 = 2.0f;
                        float _8372;
                        for (int _10481 = 0; _10481 < 24; _10482 = _8372, _10481++)
                        {
                            float _8336 = float(_10481 & 7) * 0.785398185253143310546875f;
                            int _8338 = _10481 >> 3;
                            int _10484;
                            if (_8338 == 0)
                            {
                                _10484 = 16;
                            }
                            else
                            {
                                _10484 = (_8338 == 1) ? 48 : 96;
                            }
                            uint _8388_dummy_parameter;
                            _8372 = min(_10482, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10021 + ((cbFI_MvDepthLaneSizeRcp * float(_10484)) * float2(cos(_8336), sin(_8336))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8388_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10483 = _10482;
                    }
                    else
                    {
                        _10483 = 0.0f;
                    }
                    _10487 = _10483;
                }
                float _10494;
                if (_4851)
                {
                    _10494 = _10466 - _4849;
                }
                else
                {
                    float _10490;
                    if (_4789)
                    {
                        float _10489;
                        _10489 = 2.0f;
                        float _8486;
                        for (int _10488 = 0; _10488 < 24; _10489 = _8486, _10488++)
                        {
                            float _8450 = float(_10488 & 7) * 0.785398185253143310546875f;
                            int _8452 = _10488 >> 3;
                            int _10491;
                            if (_8452 == 0)
                            {
                                _10491 = 16;
                            }
                            else
                            {
                                _10491 = (_8452 == 1) ? 48 : 96;
                            }
                            uint _8518_dummy_parameter;
                            _8486 = min(_10489, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10023 + ((cbFI_MvDepthLaneSizeRcp * float(_10491)) * float2(cos(_8450), sin(_8450))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8518_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10490 = _10489;
                    }
                    else
                    {
                        _10490 = 0.0f;
                    }
                    _10494 = _10490;
                }
                float _10495;
                if (_4786)
                {
                    uint _8550_dummy_parameter;
                    _10495 = r_depth_tm1.Load(int3(int2(floor(_10021 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8550_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10495 = 0.0f;
                }
                float _10496;
                if (_4789)
                {
                    uint _8569_dummy_parameter;
                    _10496 = r_depth_tp1.Load(int3(int2(floor(_10023 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8569_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10496 = 0.0f;
                }
                bool _4906;
                if (_4786)
                {
                    _4906 = _10495 > ((exp((_10487 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4906 = _4786;
                }
                float4 _10512;
                if (_4906)
                {
                    float4 _9902 = _10504;
                    _9902.x = 0.0f;
                    _10512 = _9902;
                }
                else
                {
                    _10512 = _10504;
                }
                bool _4918;
                if (_4789)
                {
                    _4918 = _10496 > ((exp((_10494 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4918 = _4789;
                }
                float4 _10514;
                if (_4918)
                {
                    float4 _9904 = _10512;
                    _9904.y = 0.0f;
                    _10514 = _9904;
                }
                else
                {
                    _10514 = _10512;
                }
                float4 _10577;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4851)
                {
                    bool _4938;
                    if (_4786)
                    {
                        _4938 = _10495 < ((exp((_10487 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4938 = _4786;
                    }
                    float4 _10516;
                    if (_4938)
                    {
                        float4 _9906 = _10514;
                        _9906.x = 0.0f;
                        _10516 = _9906;
                    }
                    else
                    {
                        _10516 = _10514;
                    }
                    bool _4950;
                    if (_4789)
                    {
                        _4950 = _10496 < ((exp((_10494 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4950 = _4789;
                    }
                    float4 _10578;
                    if (_4950)
                    {
                        float4 _9908 = _10516;
                        _9908.y = 0.0f;
                        _10578 = _9908;
                    }
                    else
                    {
                        _10578 = _10516;
                    }
                    _10577 = _10578;
                }
                else
                {
                    _10577 = _10514;
                }
                _11112 = float3(_10467, log((r_depth_tm1.Load(int3(int2(floor(_10021 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8194_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10023 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8226_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10576 = _10577;
            }
            else
            {
                _11112 = float3(0.0f, 0.0f, 0.5f);
                _10576 = _10471;
            }
            bool _4961 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4710;
            bool _4967;
            if (_4961)
            {
                _4967 = _4764 || _4770;
            }
            else
            {
                _4967 = _4961;
            }
            float4 _10599;
            if (_4967)
            {
                float _10571;
                do
                {
                    uint4 _8748 = r_warped_motion_qdata_tp1.Load(int3(_10051, 0));
                    uint _8749 = _8748.x;
                    if (_8749 != 0u)
                    {
                        float _10570;
                        if (_8749 == 0u)
                        {
                            _10570 = -1.0f;
                        }
                        else
                        {
                            _10570 = float((_8749 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10571 = _10570;
                        break;
                    }
                    int _10553;
                    uint _10554;
                    _10554 = _8749;
                    _10553 = -1;
                    uint _10569;
                    for (; _10553 <= 1; _10554 = _10569, _10553++)
                    {
                        _10569 = _10554;
                        for (int _10567 = -1; _10567 <= 1; )
                        {
                            _10569 = max(_10569, r_warped_motion_qdata_tp1.Load(int3(clamp(_10051 + int2(_10567, _10553), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10567++;
                            continue;
                        }
                    }
                    if (_10554 != 0u)
                    {
                        float _10566;
                        if (_10554 == 0u)
                        {
                            _10566 = -1.0f;
                        }
                        else
                        {
                            _10566 = float((_10554 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10571 = _10566;
                        break;
                    }
                    uint _10556;
                    _10556 = 4294967295u;
                    uint _11934;
                    for (int _10555 = 0; _10555 < 8; _10556 = _11934, _10555++)
                    {
                        int _10559 = 0;
                        for (;;)
                        {
                            if (_10559 < 5)
                            {
                                int2 _8699 = _10051 + (_1093[_10555] * _1102[_10559].xx);
                                bool _8702 = any(bool2(_8699.x < int2(0, 0).x, _8699.y < int2(0, 0).y));
                                bool _8710;
                                if (!_8702)
                                {
                                    _8710 = any(bool2(_8699.x >= cbFI_MvDepthLaneSize.x, _8699.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8710 = _8702;
                                }
                                if (_8710)
                                {
                                    _11934 = _10556;
                                    break;
                                }
                                uint4 _8788 = r_warped_motion_qdata_tp1.Load(int3(_8699, 0));
                                uint _8789 = _8788.x;
                                if (_8789 != 0u)
                                {
                                    _11934 = min(_10556, _8789);
                                    break;
                                }
                                _10559++;
                                continue;
                            }
                            else
                            {
                                _11934 = _10556;
                                break;
                            }
                        }
                    }
                    float _10558;
                    if (_10556 == 4294967295u)
                    {
                        _10558 = -1.0f;
                    }
                    else
                    {
                        float _10557;
                        if (_10556 == 0u)
                        {
                            _10557 = -1.0f;
                        }
                        else
                        {
                            _10557 = float((_10556 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10558 = _10557;
                    }
                    _10571 = _10558;
                    break;
                } while(false);
                float4 _10600;
                if (_10571 >= 0.0f)
                {
                    float _8810 = (exp((_10571 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4986;
                    if (_4764)
                    {
                        uint _8817_dummy_parameter;
                        _4986 = r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8817_dummy_parameter))))), 0)).x > _8810;
                    }
                    else
                    {
                        _4986 = _4764;
                    }
                    float4 _10589;
                    if (_4986)
                    {
                        float4 _9910 = _10576;
                        _9910.z = 0.0f;
                        _10589 = _9910;
                    }
                    else
                    {
                        _10589 = _10576;
                    }
                    bool _4998;
                    if (_4770)
                    {
                        uint _8836_dummy_parameter;
                        _4998 = r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8836_dummy_parameter))))), 0)).x > _8810;
                    }
                    else
                    {
                        _4998 = _4770;
                    }
                    float4 _10601;
                    if (_4998)
                    {
                        float4 _9912 = _10589;
                        _9912.w = 0.0f;
                        _10601 = _9912;
                    }
                    else
                    {
                        _10601 = _10589;
                    }
                    _10600 = _10601;
                }
                else
                {
                    _10600 = _10576;
                }
                _10599 = _10600;
            }
            else
            {
                _10599 = _10576;
            }
            bool _5006 = _4752 != _4758;
            bool _5013;
            if (_5006)
            {
                _5013 = _4752 ? _4698 : _4701;
            }
            else
            {
                _5013 = _5006;
            }
            bool _5020;
            if (_5013)
            {
                _5020 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5020 = _5013;
            }
            float4 _10684;
            if (_5020)
            {
                bool2 _5025 = _4752.xx;
                float2 _5026 = float2(_5025.x ? _10021.x : _10023.x, _5025.y ? _10021.y : _10023.y);
                float _10591;
                if (_4752)
                {
                    uint _8855_dummy_parameter;
                    _10591 = r_depth_tm1.Load(int3(int2(floor(_5026 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8855_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8871_dummy_parameter;
                    _10591 = r_depth_tp1.Load(int3(int2(floor(_5026 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8871_dummy_parameter))))), 0)).x;
                }
                float4x4 _10592;
                if (_4752)
                {
                    _10592 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10592 = cbFI_MotionTP1ToTM1;
                }
                float2 _10593;
                do
                {
                    float _8898 = _5026.x;
                    float _8901 = 1.0f - _5026.y;
                    float4 _8912 = mul(float4((float2(_8898, _8901) * 2.0f) - 1.0f.xx, _10591, 1.0f), _10592);
                    float _8914 = _8912.w;
                    if (!(_8914 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10593 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8927 = ((_8912.xy / _8914.xx) + 1.0f.xx) * 0.5f;
                    _10593 = float2(_8927.x - _8898, _8901 - _8927.y);
                    break;
                } while(false);
                float2 _5056 = float2(cbFI_DisplaySize);
                float4 _10685;
                if (!(length(((_5026 + _10593) - float2(_5025.x ? _10023.x : _10021.x, _5025.y ? _10023.y : _10021.y)) * _5056) <= ((0.100000001490116119384765625f * length(_10593 * _5056)) + 8.0f)))
                {
                    float4 _10686;
                    if (_4752)
                    {
                        float4 _9922 = _10599;
                        _9922.x = 0.0f;
                        _10686 = _9922;
                    }
                    else
                    {
                        float4 _9924 = _10599;
                        _9924.y = 0.0f;
                        _10686 = _9924;
                    }
                    _10685 = _10686;
                }
                else
                {
                    _10685 = _10599;
                }
                _10684 = _10685;
            }
            else
            {
                _10684 = _10599;
            }
            float4 _5081 = _10357 * _10684;
            float _5083 = dot(_5081, 1.0f.xxxx);
            float4 _10902;
            bool _10922;
            if (_5083 > 0.0f)
            {
                _10922 = _10174;
                _10902 = _5081 / _5083.xxxx;
            }
            else
            {
                bool _5094 = any(bool4(_10684.x < 1.0f.xxxx.x, _10684.y < 1.0f.xxxx.y, _10684.z < 1.0f.xxxx.z, _10684.w < 1.0f.xxxx.w));
                if (_5094)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8949;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8949);
                    }
                }
                bool4 _11966 = _5094.xxxx;
                _10922 = _5094 ? true : _10174;
                _10902 = float4(_11966.x ? 0.0f.xxxx.x : _10357.x, _11966.y ? 0.0f.xxxx.y : _10357.y, _11966.z ? 0.0f.xxxx.z : _10357.z, _11966.w ? 0.0f.xxxx.w : _10357.w);
            }
            _11035 = _11112;
            _10921 = _10922;
            _10901 = _10902;
        }
        else
        {
            _11035 = float3(0.0f, 0.0f, 0.5f);
            _10921 = _10174;
            _10901 = _10357;
        }
        uint _5103 = (cbFI_pad0 >> 24u) & 31u;
        uint _5107 = (cbFI_pad0 >> 16u) & 255u;
        bool _5109 = _5103 != 0u;
        bool _5111 = _5107 == 12u;
        bool _5114 = _5107 == 13u;
        float4 _10918;
        if ((_5109 || _5111) || _5114)
        {
            float _10687;
            do
            {
                bool _9033 = all(bool2(_10024.x > 0.0f.xx.x, _10024.y > 0.0f.xx.y));
                bool _9039;
                if (_9033)
                {
                    _9039 = all(bool2(_10024.x < 1.0f.xx.x, _10024.y < 1.0f.xx.y));
                }
                else
                {
                    _9039 = _9033;
                }
                bool _8970 = !_9039;
                bool _8977;
                if (!_8970)
                {
                    bool _9044 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
                    bool _9050;
                    if (_9044)
                    {
                        _9050 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9050 = _9044;
                    }
                    _8977 = !_9050;
                }
                else
                {
                    _8977 = _8970;
                }
                if (_8977)
                {
                    _10687 = 0.0f;
                    break;
                }
                uint _9057_dummy_parameter;
                uint _9073_dummy_parameter;
                float4 _8998 = mul(float4((float2(_10024.x, 1.0f - _10024.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9057_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9000 = _8998.w;
                if (abs(_9000) < 9.9999999747524270787835121154785e-07f)
                {
                    _10687 = 0.0f;
                    break;
                }
                float _9011 = abs(cbFI_DeviceToViewDepth.y / ((_8998.z / _9000) - cbFI_DeviceToViewDepth.x));
                float _9014 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9073_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10687 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9011 - _9014) / max(max(_9011, _9014), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9121 = all(bool2(_10025.x > 0.0f.xx.x, _10025.y > 0.0f.xx.y));
            bool _9127;
            if (_9121)
            {
                _9127 = all(bool2(_10025.x < 1.0f.xx.x, _10025.y < 1.0f.xx.y));
            }
            else
            {
                _9127 = _9121;
            }
            float _10688;
            if (_9127)
            {
                uint _9134_dummy_parameter;
                _10688 = length((_5914 + (r_motion_tp1.Load(int3(int2(floor(_10025 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9134_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10688 = 1000000.0f;
            }
            float _10699;
            if ((_5103 & 1u) != 0u)
            {
                _10699 = _10687;
            }
            else
            {
                _10699 = 1.0f;
            }
            float _10700;
            if ((_5103 & 2u) != 0u)
            {
                _10700 = _10699 * (1.0f - smoothstep(2.0f, 8.0f, _10688));
            }
            else
            {
                _10700 = _10699;
            }
            float _10701;
            if ((_5103 & 4u) != 0u)
            {
                _10701 = _10700 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6635 - _6643) - length(_6619 - _6627))));
            }
            else
            {
                _10701 = _10700;
            }
            float _10912;
            if ((_5103 & 8u) != 0u)
            {
                _10912 = lerp(1.0f, _10701, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6619 - _6627)));
            }
            else
            {
                _10912 = _10701;
            }
            bool _5189 = (_5103 & 16u) != 0u;
            bool _5198;
            if (_5189)
            {
                _5198 = length(_10019 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5198 = _5189;
            }
            float _11968 = _5198 ? 1.0f : _10912;
            bool _5204 = _5109 && _6828;
            bool _5209;
            if (_5204)
            {
                bool _9159 = all(bool2(_10021.x > 0.0f.xx.x, _10021.y > 0.0f.xx.y));
                bool _9165;
                if (_9159)
                {
                    _9165 = all(bool2(_10021.x < 1.0f.xx.x, _10021.y < 1.0f.xx.y));
                }
                else
                {
                    _9165 = _9159;
                }
                _5209 = _9165;
            }
            else
            {
                _5209 = _5204;
            }
            bool _5214;
            if (_5209)
            {
                bool _9170 = all(bool2(_10023.x > 0.0f.xx.x, _10023.y > 0.0f.xx.y));
                bool _9176;
                if (_9170)
                {
                    _9176 = all(bool2(_10023.x < 1.0f.xx.x, _10023.y < 1.0f.xx.y));
                }
                else
                {
                    _9176 = _9170;
                }
                _5214 = _9176;
            }
            else
            {
                _5214 = _5209;
            }
            float4 _10919;
            if (_5214)
            {
                float _5220 = _10901.x + _10901.y;
                float _5229 = (_10901.z + _10901.w) * (1.0f - _11968);
                float _10915;
                if (_5220 > 9.9999997473787516355514526367188e-06f)
                {
                    _10915 = _10901.x / _5220;
                }
                else
                {
                    _10915 = _4217;
                }
                _10919 = float4(_10901.x + (_5229 * _10915), _10901.y + (_5229 * (1.0f - _10915)), _10901.zw * _11968);
            }
            else
            {
                _10919 = _10901;
            }
            _10918 = _10919;
        }
        else
        {
            _10918 = _10901;
        }
        float3 _11736;
        if (_10921)
        {
            float3 _9182 = r_current_interpolation_source.Load(int3(_3593, 0)).xyz;
            float3 _11737;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6828)
            {
                uint _9189_dummy_parameter;
                float _11026;
                _11026 = r_depth_tm1.Load(int3(int2(floor(_10021 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9189_dummy_parameter))))), 0)).x;
                float _5341;
                for (int _11025 = 0; _11025 < 24; _11026 = _5341, _11025++)
                {
                    float _5313 = float(_11025 & 7) * 0.785398185253143310546875f;
                    int _5315 = _11025 >> 3;
                    int _11787;
                    if (_5315 == 0)
                    {
                        _11787 = 16;
                    }
                    else
                    {
                        _11787 = (_5315 == 1) ? 48 : 96;
                    }
                    uint _9209_dummy_parameter;
                    _5341 = min(_11026, r_depth_tm1.Load(int3(int2(floor(clamp(_10021 + ((cbFI_MvDepthLaneSizeRcp * float(_11787)) * float2(cos(_5313), sin(_5313))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9209_dummy_parameter))))), 0)).x);
                }
                float2 _11027;
                do
                {
                    float _9231 = 1.0f - _10021.y;
                    float4 _9242 = mul(float4((float2(_10021.x, _9231) * 2.0f) - 1.0f.xx, _11026, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9244 = _9242.w;
                    if (!(_9244 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11027 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9257 = ((_9242.xy / _9244.xx) + 1.0f.xx) * 0.5f;
                    _11027 = float2(_9257.x - _10021.x, _9231 - _9257.y);
                    break;
                } while(false);
                float2 _5352 = _10021 + _11027;
                bool _9275 = all(bool2(_5352.x > 0.0f.xx.x, _5352.y > 0.0f.xx.y));
                bool _9281;
                if (_9275)
                {
                    _9281 = all(bool2(_5352.x < 1.0f.xx.x, _5352.y < 1.0f.xx.y));
                }
                else
                {
                    _9281 = _9275;
                }
                float3 _11738;
                if (_9281)
                {
                    float _5358 = abs(cbFI_DeviceToViewDepth.y / (_11026 - cbFI_DeviceToViewDepth.x));
                    uint _9301_dummy_parameter;
                    int2 _9301 = int2(spvTextureSize(r_depth_m2, uint(0), _9301_dummy_parameter));
                    float _5362 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5352 * float2(_9301))), int2(0, 0), _9301 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11743;
                    if (abs(_5362 - _5358) <= (0.20000000298023223876953125f * max(_5362, _5358)))
                    {
                        uint _9335_dummy_parameter;
                        int2 _9335 = int2(spvTextureSize(r_colour_m2, uint(0), _9335_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9358;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9358);
                        }
                        _11743 = r_colour_m2.Load(int3(clamp(int2(floor(_5352 * float2(_9335))), int2(0, 0), _9335 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9368;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9368);
                        }
                        _11743 = _9182;
                    }
                    _11738 = _11743;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9378;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9378);
                    }
                    _11738 = _9182;
                }
                _11737 = _11738;
            }
            else
            {
                _11737 = _9182;
            }
            _11736 = _11737;
        }
        else
        {
            _11736 = (((_6619 * _10918.x) + (_6627 * _10918.y)) + (_6635 * _10918.z)) + (_6643 * _10918.w);
        }
        uint _5390 = cbFI_pad0 & 255u;
        bool _11628;
        float3 _11735;
        if (_5390 != 0u)
        {
            float3 _5395 = r_present_backbuffer.Load(int3(_3593, 0)).xyz;
            float3 _5399 = r_current_interpolation_source.Load(int3(_3593, 0)).xyz;
            float3 _5403 = abs(_5395 - _5399);
            float3 _11030;
            if (_5390 == 2u)
            {
                _11030 = (abs(_5399) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11030 = 0.000244140625f.xxx;
            }
            bool _5419 = any(bool3(_5403.x > _11030.x, _5403.y > _11030.y, _5403.z > _11030.z));
            bool3 _11969 = _5419.xxx;
            _11735 = float3(_11969.x ? _5395.x : _11736.x, _11969.y ? _5395.y : _11736.y, _11969.z ? _5395.z : _11736.z);
            _11628 = _5419;
        }
        else
        {
            _11735 = _11736;
            _11628 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9393;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9393);
        }
        float3 _11718;
        if (_5107 == 1u)
        {
            _11718 = lerp(_6619, _6627, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11719;
            if (_5107 == 2u)
            {
                _11719 = lerp(_6635, _6643, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11720;
                if (_5107 == 3u)
                {
                    _11720 = float(_11628).xxx;
                }
                else
                {
                    float3 _11721;
                    if (_5107 == 4u)
                    {
                        _11721 = float3(((_10019 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11722;
                        if (_5107 == 5u)
                        {
                            _11722 = float3(((_5914 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11723;
                            if (_5107 == 6u)
                            {
                                _11723 = float3(_10918.xy, _10918.z + _10918.w);
                            }
                            else
                            {
                                float3 _11724;
                                if (_5107 == 7u)
                                {
                                    _11724 = r_current_interpolation_source.Load(int3(_3593, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11725;
                                    if (_5107 == 8u)
                                    {
                                        _11725 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3992, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11726;
                                        if (_5111)
                                        {
                                            uint _9415_dummy_parameter;
                                            uint _9447_dummy_parameter;
                                            _11726 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3992 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9415_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3992 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9447_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11727;
                                            if (_5114)
                                            {
                                                _11727 = _6635;
                                            }
                                            else
                                            {
                                                float3 _11728;
                                                if (_5107 == 20u)
                                                {
                                                    _11728 = _6619;
                                                }
                                                else
                                                {
                                                    float3 _11729;
                                                    if (_5107 == 21u)
                                                    {
                                                        _11729 = _6627;
                                                    }
                                                    else
                                                    {
                                                        float3 _11730;
                                                        if (_5107 == 22u)
                                                        {
                                                            _11730 = _6643;
                                                        }
                                                        else
                                                        {
                                                            float3 _11731;
                                                            if (_5107 == 18u)
                                                            {
                                                                _11731 = _11397;
                                                            }
                                                            else
                                                            {
                                                                float3 _11732;
                                                                if (_5107 == 19u)
                                                                {
                                                                    _11732 = _11213;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11971 = (_5107 == 23u).xxx;
                                                                    _11732 = float3(_11971.x ? _11035.x : _11735.x, _11971.y ? _11035.y : _11735.y, _11971.z ? _11035.z : _11735.z);
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
                                    _11724 = _11725;
                                }
                                _11723 = _11724;
                            }
                            _11722 = _11723;
                        }
                        _11721 = _11722;
                    }
                    _11720 = _11721;
                }
                _11719 = _11720;
            }
            _11718 = _11719;
        }
        float3 _11717;
        if ((_5107 >= 9u) && (_5107 <= 11u))
        {
            uint _5583 = 64u + uint((_10051.y * cbFI_MvDepthLaneSize.x) + _10051.x);
            uint _5587 = rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) & 15u;
            float3 _11748;
            if (_5107 == 10u)
            {
                float3 _11716;
                if ((rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) & 32u) != 0u)
                {
                    _11716 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11715;
                    if ((rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) & 16u) != 0u)
                    {
                        _11715 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5608 = ((rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) & 64u) != 0u).xxx;
                        _11715 = float3(_5608.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5608.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5608.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11716 = _11715;
                }
                _11748 = _11716;
            }
            else
            {
                float3 _11749;
                if (_5107 == 11u)
                {
                    uint _5621 = (rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) >> 8u) & 15u;
                    uint _5624 = (rw_nfru_diagnostics.Load<uint>(_5583 * 4 + 0) >> 12u) & 15u;
                    float3 _11708;
                    if ((_5587 == 2u) || (_5587 == 3u))
                    {
                        _11708 = _3289[_5587];
                    }
                    else
                    {
                        bool _5636 = _5621 == 3u;
                        bool _5638 = _5624 == 3u;
                        float3 _11709;
                        if (_5636 && _5638)
                        {
                            _11709 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11710;
                            if (_5636)
                            {
                                _11710 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11711;
                                if (_5638)
                                {
                                    _11711 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11712;
                                    if ((_5621 == 4u) || (_5624 == 4u))
                                    {
                                        _11712 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11713;
                                        if ((_5621 == 1u) || (_5624 == 1u))
                                        {
                                            _11713 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11973 = (_5587 == 1u).xxx;
                                            _11713 = float3(_11973.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11973.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11973.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11712 = _11713;
                                    }
                                    _11711 = _11712;
                                }
                                _11710 = _11711;
                            }
                            _11709 = _11710;
                        }
                        _11708 = _11709;
                    }
                    _11749 = _11708;
                }
                else
                {
                    _11749 = _3289[min(_5587, 7u)];
                }
                _11748 = _11749;
            }
            _11717 = _11748;
        }
        else
        {
            _11717 = _11718;
        }
        float4 _11752;
        if ((_5107 >= 14u) && (_5107 <= 16u))
        {
            float2 _11750;
            if (_5107 == 14u)
            {
                uint _5694_dummy_parameter;
                uint _5700_dummy_parameter;
                _11750 = r_flow_tm1.Load(int3(clamp(int2(floor(_3992 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5694_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5700_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11751;
                if (_5107 == 16u)
                {
                    uint _9498 = r_warped_flow_qdata_tm1.Load(int3(_4008, 0)).x & 2147483647u;
                    uint _9530 = uint(max((int((_9498 >> 16u) & 15u) - 6), 0));
                    _11751 = ((float2(float((1 - (2 * int((_9498 >> 15u) & 1u))) * int(((_9498 >> uint(7)) & 127u) << _9530)), float((1 - (2 * int((_9498 >> 14u) & 1u))) * int((_9498 & 127u) << _9530))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11751 = _5914 * float2(cbFI_DisplaySize);
                }
                _11750 = _11751;
            }
            uint2 _5733 = uint2(clamp(round(_11750 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5735 = _5733.x;
            uint _5742 = _5733.y;
            _11752 = float4(float(_5735 & 255u), float((_5735 >> 8u) | ((_5742 & 15u) << 4u)), float(_5742 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11753;
            if (_5107 == 17u)
            {
                _11753 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4008, 0)).x != 0u), _4351, 0.0f, 1.0f);
            }
            else
            {
                _11753 = float4(_11717, 1.0f);
            }
            _11752 = _11753;
        }
        rw_output[_3593] = _11752.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5786 = ((uint(_3593.y) * uint(cbFI_DisplaySize.x)) + uint(_3593.x)) * 6u;
            uint _9576 = spvPackHalf2x16(clamp(_6618.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5786 * 4 + 0, (((_9576 & 32767u) >> 4u) | ((((_9576 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6618.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9611 = spvPackHalf2x16(clamp(_6626.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5786 + 1u) * 4 + 0, (((_9611 & 32767u) >> 4u) | ((((_9611 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6626.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9646 = spvPackHalf2x16(clamp(_6634.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5786 + 2u) * 4 + 0, (((_9646 & 32767u) >> 4u) | ((((_9646 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6634.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9681 = spvPackHalf2x16(clamp(_6642.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5786 + 3u) * 4 + 0, (((_9681 & 32767u) >> 4u) | ((((_9681 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6642.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9708 = r_current_interpolation_source.Load(int3(_3593, 0));
            uint _9722 = spvPackHalf2x16(clamp(_9708.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5786 + 4u) * 4 + 0, (((_9722 & 32767u) >> 4u) | ((((_9722 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9708.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11786;
            if (_11628 || (_5107 != 0u))
            {
                _11786 = 4294967295u;
            }
            else
            {
                uint _9757 = spvPackHalf2x16(clamp(_11752.xy, 0.0f.xx, 65000.0f.xx));
                _11786 = (((_9757 & 32767u) >> 4u) | ((((_9757 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11752.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5786 + 5u) * 4 + 0, _11786);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3593] = float4(r_current_interpolation_source.Load(int3(_3593, 0)).xyz, 1.0f).xyz;
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
