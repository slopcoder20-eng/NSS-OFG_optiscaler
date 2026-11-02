static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3066[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3370 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3370.x >= cbFI_DisplaySize.x, _3370.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3370] = float4(r_present_backbuffer.Load(int3(_3370, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3370] = float4(r_current_interpolation_source.Load(int3(_3370, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3739 = (float2(_3370) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3750 = int2(floor(_3739 * float2(cbFI_MvDepthLaneSize)));
        int2 _3755 = int2(floor(_3739 * float2(cbFI_FlowLaneSize)));
        float4 _5469 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3739 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5475 = r_warped_filled_flow_tm1.Load(int3(_3755, 0)).xy;
        float2 _5481 = r_warped_filled_motion_tp1.Load(int3(_3750, 0)).xy;
        bool _5503 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8967;
        if (_5503)
        {
            float _5516 = ((2.0f * _3739.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8967 = float2(atan(_5516) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3739.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5516 * _5516))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8967 = _3739;
        }
        bool _3776 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8988;
        bool _9009;
        int2 _9020;
        float3 _9929;
        if (_3776)
        {
            float _8969;
            float _8971;
            _8971 = 2.0f;
            _8969 = -1.0f;
            uint _3434[9];
            float _10316;
            float _10319;
            for (int _8968 = 0; _8968 < 9; _8971 = _10319, _8969 = _10316, _8968++)
            {
                _3434[_8968] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3750 + int2((_8968 % 3) - 1, (_8968 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3434[_8968] != 0u)
                {
                    float _10311;
                    if (_3434[_8968] == 0u)
                    {
                        _10311 = -1.0f;
                    }
                    else
                    {
                        _10311 = float((_3434[_8968] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10319 = min(_8971, _10311);
                    _10316 = max(_8969, _10311);
                }
                else
                {
                    _10319 = _8971;
                    _10316 = _8969;
                }
            }
            float _3822 = float(_8969 >= 0.0f);
            float3 _8778 = 0.0f.xxx;
            _8778.y = _3822;
            float2 _8989;
            bool _9010;
            int2 _9021;
            float3 _9930;
            if ((_8969 - _8971) > 0.0199999995529651641845703125f)
            {
                float _8977;
                int2 _8978;
                float2 _8979;
                int2 _8981;
                float2 _8987;
                _8987 = _5481;
                _8981 = _3750;
                _8979 = _5481;
                _8978 = _3750;
                _8977 = -1.0f;
                float _10324;
                int2 _10328;
                float2 _10339;
                int2 _10350;
                float2 _10383;
                float _10428;
                int _8976 = 0;
                float _10292 = 1000000000.0f;
                for (; _8976 < 9; _10292 = _10428, _8987 = _10383, _8981 = _10350, _8979 = _10339, _8978 = _10328, _8977 = _10324, _8976++)
                {
                    if (_3434[_8976] == 0u)
                    {
                        _10428 = _10292;
                        _10383 = _8987;
                        _10350 = _8981;
                        _10339 = _8979;
                        _10328 = _8978;
                        _10324 = _8977;
                        continue;
                    }
                    int2 _3857 = clamp(_3750 + int2((_8976 % 3) - 1, (_8976 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5591 = _3434[_8976] & 2147483647u;
                    uint _5623 = uint(max((int((_5591 >> 16u) & 15u) - 6), 0));
                    float2 _3863 = (float2(float((1 - (2 * int((_5591 >> 15u) & 1u))) * int(((_5591 >> uint(7)) & 127u) << _5623)), float((1 - (2 * int((_5591 >> 14u) & 1u))) * int((_5591 & 127u) << _5623))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10278;
                    if (_3434[_8976] == 0u)
                    {
                        _10278 = -1.0f;
                    }
                    else
                    {
                        _10278 = float((_3434[_8976] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3868 = _10278 - 0.100000001490116119384765625f;
                    float2 _10279;
                    if (_5503)
                    {
                        float2 _5700 = clamp((((_8967 + (_3863 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5703 = tan(_5700.x);
                        _10279 = (float2(_5703 / cbFI_DeviceToViewDepth.z, (tan(_5700.y) * sqrt(1.0f + (_5703 * _5703))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10279 = _8967 + (_3863 * cbFI_Timestep);
                    }
                    float _3875 = cbFI_Timestep - 1.0f;
                    float2 _10280;
                    if (_5503)
                    {
                        float2 _5771 = clamp((((_8967 + (_3863 * _3875)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5774 = tan(_5771.x);
                        _10280 = (float2(_5774 / cbFI_DeviceToViewDepth.z, (tan(_5771.y) * sqrt(1.0f + (_5774 * _5774))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10280 = _8967 + (_3863 * _3875);
                    }
                    bool _5807 = all(bool2(_10279.x > 0.0f.xx.x, _10279.y > 0.0f.xx.y));
                    bool _5813;
                    if (_5807)
                    {
                        _5813 = all(bool2(_10279.x < 1.0f.xx.x, _10279.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5813 = _5807;
                    }
                    float _10283;
                    if (_5813)
                    {
                        uint _5820_dummy_parameter;
                        _10283 = max((_3868 - (log((r_depth_tm1.Load(int3(int2(floor(_10279 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5820_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10283 = 0.0f;
                    }
                    bool _5850 = all(bool2(_10280.x > 0.0f.xx.x, _10280.y > 0.0f.xx.y));
                    bool _5856;
                    if (_5850)
                    {
                        _5856 = all(bool2(_10280.x < 1.0f.xx.x, _10280.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5856 = _5850;
                    }
                    float _10284;
                    if (_5856)
                    {
                        uint _5863_dummy_parameter;
                        _10284 = _10283 + max((_3868 - (log((r_depth_tp1.Load(int3(int2(floor(_10280 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5863_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10284 = _10283;
                    }
                    float _10325;
                    int2 _10329;
                    float2 _10340;
                    int2 _10351;
                    float2 _10384;
                    float _10429;
                    if (_10284 == 0.0f)
                    {
                        bool _3910 = _3868 > _8977;
                        bool2 _10437 = _3910.xx;
                        _10429 = _10292;
                        _10384 = float2(_10437.x ? _3863.x : _8987.x, _10437.y ? _3863.y : _8987.y);
                        _10351 = int2(_10437.x ? _3857.x : _8981.x, _10437.y ? _3857.y : _8981.y);
                        _10340 = _8979;
                        _10329 = _8978;
                        _10325 = _3910 ? _3868 : _8977;
                    }
                    else
                    {
                        bool _3919 = _10284 < _10292;
                        bool2 _10433 = _3919.xx;
                        _10429 = _3919 ? _10284 : _10292;
                        _10384 = _8987;
                        _10351 = _8981;
                        _10340 = float2(_10433.x ? _3863.x : _8979.x, _10433.y ? _3863.y : _8979.y);
                        _10329 = int2(_10433.x ? _3857.x : _8978.x, _10433.y ? _3857.y : _8978.y);
                        _10325 = _8977;
                    }
                    _10428 = _10429;
                    _10383 = _10384;
                    _10350 = _10351;
                    _10339 = _10340;
                    _10328 = _10329;
                    _10324 = _10325;
                }
                bool _3931 = _8977 < 0.0f;
                bool2 _10443 = _3931.xx;
                int2 _10446 = int2(_10443.x ? _8978.x : _8981.x, _10443.y ? _8978.y : _8981.y);
                _9930 = float3(1.0f, _3822, float(any(bool2(_10446.x != _3750.x, _10446.y != _3750.y))));
                _9021 = _10446;
                _9010 = _3931 ? false : true;
                _8989 = float2(_10443.x ? _8979.x : _8987.x, _10443.y ? _8979.y : _8987.y);
            }
            else
            {
                _9930 = _8778;
                _9021 = _3750;
                _9010 = false;
                _8989 = _5481;
            }
            _9929 = _9930;
            _9020 = _9021;
            _9009 = _9010;
            _8988 = _8989;
        }
        else
        {
            _9929 = 0.0f.xxx;
            _9020 = _3750;
            _9009 = false;
            _8988 = _5481;
        }
        float2 _8990;
        if (_5503)
        {
            float2 _5928 = clamp((((_8967 + (_8988 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5931 = tan(_5928.x);
            _8990 = (float2(_5931 / cbFI_DeviceToViewDepth.z, (tan(_5928.y) * sqrt(1.0f + (_5931 * _5931))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8990 = _8967 + (_8988 * cbFI_Timestep);
        }
        float _3954 = cbFI_Timestep - 1.0f;
        float2 _8992;
        if (_5503)
        {
            float2 _5999 = clamp((((_8967 + (_8988 * _3954)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6002 = tan(_5999.x);
            _8992 = (float2(_6002 / cbFI_DeviceToViewDepth.z, (tan(_5999.y) * sqrt(1.0f + (_6002 * _6002))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8992 = _8967 + (_8988 * _3954);
        }
        float _3959 = -cbFI_Timestep;
        float2 _8993;
        if (_5503)
        {
            float2 _6070 = clamp((((_8967 + (_5475 * _3959)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6073 = tan(_6070.x);
            _8993 = (float2(_6073 / cbFI_DeviceToViewDepth.z, (tan(_6070.y) * sqrt(1.0f + (_6073 * _6073))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8993 = _8967 + (_5475 * _3959);
        }
        float _3964 = 1.0f - cbFI_Timestep;
        float2 _8994;
        if (_5503)
        {
            float2 _6141 = clamp((((_8967 + (_5475 * _3964)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6144 = tan(_6141.x);
            _8994 = (float2(_6144 / cbFI_DeviceToViewDepth.z, (tan(_6141.y) * sqrt(1.0f + (_6144 * _6144))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8994 = _8967 + (_5475 * _3964);
        }
        float4 _6179 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8990, 0.0f);
        float3 _6180 = _6179.xyz;
        float4 _6187 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8992, 0.0f);
        float3 _6188 = _6187.xyz;
        float4 _6195 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8993, 0.0f);
        float3 _6196 = _6195.xyz;
        float4 _6203 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8994, 0.0f);
        float3 _6204 = _6203.xyz;
        float4 _6218 = exp(_5469 - max(max(max(_5469.x, _5469.y), _5469.z), _5469.w).xxxx);
        float4 _6225 = _6218 / (dot(_6218, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3983 = _3776 && (!_9009);
        bool _3992;
        if (_3983)
        {
            _3992 = (_6225.z + _6225.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3992 = _3983;
        }
        bool _4003;
        if (_3992)
        {
            _4003 = length((_8993 - _8990) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4003 = _3992;
        }
        bool _9033;
        if (_4003)
        {
            uint4 _6244 = r_warped_motion_qdata_tp1.Load(int3(_9020, 0));
            uint _6245 = _6244.x;
            bool _9036;
            if (_6245 != 0u)
            {
                float _9022;
                if (_6245 == 0u)
                {
                    _9022 = -1.0f;
                }
                else
                {
                    _9022 = float((_6245 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4013 = _9022 - 0.12000000476837158203125f;
                bool _6264 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                bool _6270;
                if (_6264)
                {
                    _6270 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                }
                else
                {
                    _6270 = _6264;
                }
                bool _4023;
                if (_6270)
                {
                    uint _6277_dummy_parameter;
                    _4023 = (log((r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6277_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4013;
                }
                else
                {
                    _4023 = _6270;
                }
                bool _4037;
                if (!_4023)
                {
                    bool _6307 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                    bool _6313;
                    if (_6307)
                    {
                        _6313 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6313 = _6307;
                    }
                    bool _4035;
                    if (_6313)
                    {
                        uint _6320_dummy_parameter;
                        _4035 = (log((r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6320_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4013;
                    }
                    else
                    {
                        _4035 = _6313;
                    }
                    _4037 = _4035;
                }
                else
                {
                    _4037 = _4023;
                }
                _9036 = _4037;
            }
            else
            {
                _9036 = false;
            }
            _9033 = _9036;
        }
        else
        {
            _9033 = false;
        }
        bool _4042 = _9009 || _9033;
        bool _4047;
        if (_4042)
        {
            bool _6350 = all(bool2(_8990.x > 0.0f.xx.x, _8990.y > 0.0f.xx.y));
            bool _6356;
            if (_6350)
            {
                _6356 = all(bool2(_8990.x < 1.0f.xx.x, _8990.y < 1.0f.xx.y));
            }
            else
            {
                _6356 = _6350;
            }
            _4047 = _6356;
        }
        else
        {
            _4047 = _4042;
        }
        bool _4052;
        if (_4047)
        {
            bool _6361 = all(bool2(_8992.x > 0.0f.xx.x, _8992.y > 0.0f.xx.y));
            bool _6367;
            if (_6361)
            {
                _6367 = all(bool2(_8992.x < 1.0f.xx.x, _8992.y < 1.0f.xx.y));
            }
            else
            {
                _6367 = _6361;
            }
            _4052 = _6367;
        }
        else
        {
            _4052 = _4047;
        }
        float4 _9127;
        if (_4052)
        {
            float _4055 = _6225.x;
            float _4057 = _6225.y;
            float _4058 = _4055 + _4057;
            float _4063 = _6225.z + _6225.w;
            float _9051;
            if (_4058 > 0.001000000047497451305389404296875f)
            {
                _9051 = _4055 / _4058;
            }
            else
            {
                _9051 = _3964;
            }
            _9127 = float4(_4055 + (_4063 * _9051), _4057 + (_4063 * (1.0f - _9051)), 0.0f, 0.0f);
        }
        else
        {
            _9127 = _6225;
        }
        bool _6395 = (cbFI_pad0 & 1024u) != 0u;
        bool _6371 = !_6395;
        bool _6372 = !_6371;
        bool _6389;
        if (_6372)
        {
            _6389 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9020.y * cbFI_MvDepthLaneSize.x) + _9020.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6389 = _6371;
        }
        bool _6421;
        if (_6372)
        {
            _6421 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3755.y * cbFI_FlowLaneSize.x) + _3755.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6421 = _6371;
        }
        float _4098 = float(_6421);
        bool _9139;
        float4 _9169;
        float3 _9786;
        if (_6395)
        {
            bool _4108;
            if (_6389)
            {
                _4108 = all(bool2(_8990.x > 0.0f.xx.x, _8990.y > 0.0f.xx.y));
            }
            else
            {
                _4108 = _6389;
            }
            bool _4114;
            if (_4108)
            {
                _4114 = all(bool2(_8990.x < 1.0f.xx.x, _8990.y < 1.0f.xx.y));
            }
            else
            {
                _4114 = _4108;
            }
            bool _4121;
            if (_6389)
            {
                _4121 = all(bool2(_8992.x > 0.0f.xx.x, _8992.y > 0.0f.xx.y));
            }
            else
            {
                _4121 = _6389;
            }
            bool _4127;
            if (_4121)
            {
                _4127 = all(bool2(_8992.x < 1.0f.xx.x, _8992.y < 1.0f.xx.y));
            }
            else
            {
                _4127 = _4121;
            }
            bool _4134;
            if (_6421)
            {
                _4134 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
            }
            else
            {
                _4134 = _6421;
            }
            bool _4140;
            if (_4134)
            {
                _4140 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
            }
            else
            {
                _4140 = _4134;
            }
            bool _4147;
            if (_6421)
            {
                _4147 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
            }
            else
            {
                _4147 = _6421;
            }
            bool _4153;
            if (_4147)
            {
                _4153 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
            }
            else
            {
                _4153 = _4147;
            }
            bool _4155 = !_6389;
            if (_4155)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6463;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6463);
                }
            }
            bool _4160 = !_6421;
            if (_4160)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6473;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6473);
                }
            }
            if (_6389 && _4160)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6483;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6483);
                }
            }
            if (_4155 && _6421)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6493;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6493);
                }
            }
            float _4179 = float(_4114);
            float _4181 = float(_4127);
            bool _4184 = _4140 && _4153;
            float _9085;
            if (_4184)
            {
                _9085 = 1.0f;
            }
            else
            {
                _9085 = (_4140 || _4153) ? 0.5f : 0.0f;
            }
            bool _9090;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4114)) && (!_4127))
            {
                bool _4214;
                if (_4184)
                {
                    float _9088;
                    do
                    {
                        bool _6577 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                        bool _6583;
                        if (_6577)
                        {
                            _6583 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6583 = _6577;
                        }
                        bool _6514 = !_6583;
                        bool _6521;
                        if (!_6514)
                        {
                            bool _6588 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                            bool _6594;
                            if (_6588)
                            {
                                _6594 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6594 = _6588;
                            }
                            _6521 = !_6594;
                        }
                        else
                        {
                            _6521 = _6514;
                        }
                        if (_6521)
                        {
                            _9088 = 0.0f;
                            break;
                        }
                        uint _6601_dummy_parameter;
                        uint _6617_dummy_parameter;
                        float4 _6542 = mul(float4((float2(_8993.x, 1.0f - _8993.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6601_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6544 = _6542.w;
                        if (abs(_6544) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9088 = 0.0f;
                            break;
                        }
                        float _6555 = abs(cbFI_DeviceToViewDepth.y / ((_6542.z / _6544) - cbFI_DeviceToViewDepth.x));
                        float _6558 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6617_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9088 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6555 - _6558) / max(max(_6555, _6558), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4214 = _9088 >= 0.5f;
                }
                else
                {
                    _4214 = _4184;
                }
                bool _9091;
                if (_4214)
                {
                    uint _6667_dummy_parameter;
                    float2 _9089;
                    do
                    {
                        float _6693 = 1.0f - _8993.y;
                        float4 _6704 = mul(float4((float2(_8993.x, _6693) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6667_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6706 = _6704.w;
                        if (!(_6706 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9089 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6719 = ((_6704.xy / _6706.xx) + 1.0f.xx) * 0.5f;
                        _9089 = float2(_6719.x - _8993.x, _6693 - _6719.y);
                        break;
                    } while(false);
                    float2 _4228 = float2(cbFI_DisplaySize);
                    _9091 = length(((_8993 + _9089) - _8994) * _4228) <= ((0.100000001490116119384765625f * length(_9089 * _4228)) + 8.0f);
                }
                else
                {
                    _9091 = _4214;
                }
                _9090 = _9091;
            }
            else
            {
                _9090 = true;
            }
            bool _4242 = !_9090;
            bool _10447 = _4242 ? false : _4153;
            bool _10448 = _4242 ? false : _4140;
            bool _9140;
            float4 _9170;
            if (!(((_4114 && _4127) && _10448) && _10447))
            {
                float4 _4264 = _9127 * float4(_4179, _4181, float(_10448), float(_10447));
                float _4266 = dot(_4264, 1.0f.xxxx);
                bool _4269 = !(_4266 > 0.0f);
                float4 _9171;
                if (!_4269)
                {
                    _9171 = _4264 / _4266.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6741;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6741);
                    }
                    _9171 = 0.0f.xxxx;
                }
                _9170 = _9171;
                _9140 = _4269;
            }
            else
            {
                _9170 = _9127;
                _9140 = false;
            }
            _9786 = float3(_4179, _4181, _9085);
            _9169 = _9170;
            _9139 = _9140;
        }
        else
        {
            _9786 = float3(float(_6389), _4098, 0.0f);
            _9169 = _9127;
            _9139 = false;
        }
        float4 _9653;
        bool _9673;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9139))
        {
            bool _4292 = _9169.x > 0.00999999977648258209228515625f;
            bool _4295 = _9169.y > 0.00999999977648258209228515625f;
            bool _4304 = (_9169.z + _9169.w) > 0.0199999995529651641845703125f;
            bool _4310;
            if (_4304)
            {
                bool _6747 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                bool _6753;
                if (_6747)
                {
                    _6753 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                }
                else
                {
                    _6753 = _6747;
                }
                _4310 = _6753;
            }
            else
            {
                _4310 = _4304;
            }
            bool _4315;
            if (_4310)
            {
                bool _6758 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                bool _6764;
                if (_6758)
                {
                    _6764 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                }
                else
                {
                    _6764 = _6758;
                }
                _4315 = _6764;
            }
            else
            {
                _4315 = _4310;
            }
            bool _4322;
            if (_4315)
            {
                float _9173;
                do
                {
                    bool _6847 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                    bool _6853;
                    if (_6847)
                    {
                        _6853 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6853 = _6847;
                    }
                    bool _6784 = !_6853;
                    bool _6791;
                    if (!_6784)
                    {
                        bool _6858 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                        bool _6864;
                        if (_6858)
                        {
                            _6864 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6864 = _6858;
                        }
                        _6791 = !_6864;
                    }
                    else
                    {
                        _6791 = _6784;
                    }
                    if (_6791)
                    {
                        _9173 = 0.0f;
                        break;
                    }
                    uint _6871_dummy_parameter;
                    uint _6887_dummy_parameter;
                    float4 _6812 = mul(float4((float2(_8993.x, 1.0f - _8993.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6871_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6814 = _6812.w;
                    if (abs(_6814) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9173 = 0.0f;
                        break;
                    }
                    float _6825 = abs(cbFI_DeviceToViewDepth.y / ((_6812.z / _6814) - cbFI_DeviceToViewDepth.x));
                    float _6828 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6887_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9173 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6825 - _6828) / max(max(_6825, _6828), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4322 = _9173 < 0.5f;
            }
            else
            {
                _4322 = _4315;
            }
            float4 _9188;
            if (_4322)
            {
                uint _6937_dummy_parameter;
                uint _6968_dummy_parameter;
                float4 _9189;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6937_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6968_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9189 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9189 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9188 = _9189;
            }
            else
            {
                _9188 = 1.0f.xxxx;
            }
            bool _4346;
            if (_6389)
            {
                bool _6997 = all(bool2(_8990.x > 0.0f.xx.x, _8990.y > 0.0f.xx.y));
                bool _7003;
                if (_6997)
                {
                    _7003 = all(bool2(_8990.x < 1.0f.xx.x, _8990.y < 1.0f.xx.y));
                }
                else
                {
                    _7003 = _6997;
                }
                _4346 = _7003;
            }
            else
            {
                _4346 = _6389;
            }
            bool _4352;
            if (_6389)
            {
                bool _7008 = all(bool2(_8992.x > 0.0f.xx.x, _8992.y > 0.0f.xx.y));
                bool _7014;
                if (_7008)
                {
                    _7014 = all(bool2(_8992.x < 1.0f.xx.x, _8992.y < 1.0f.xx.y));
                }
                else
                {
                    _7014 = _7008;
                }
                _4352 = _7014;
            }
            else
            {
                _4352 = _6389;
            }
            bool _4358;
            if (_6421)
            {
                bool _7019 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                bool _7025;
                if (_7019)
                {
                    _7025 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                }
                else
                {
                    _7025 = _7019;
                }
                _4358 = _7025;
            }
            else
            {
                _4358 = _6421;
            }
            bool _4364;
            if (_6421)
            {
                bool _7030 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                bool _7036;
                if (_7030)
                {
                    _7036 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                }
                else
                {
                    _7036 = _7030;
                }
                _4364 = _7036;
            }
            else
            {
                _4364 = _6421;
            }
            bool _4367 = _4358 != _4364;
            bool _4373;
            if (_4367)
            {
                _4373 = _4346 || _4352;
            }
            else
            {
                _4373 = _4367;
            }
            float4 _9268;
            if (_4373)
            {
                float4 _8863 = _9188;
                _8863.z = 0.0f;
                _8863.w = 0.0f;
                _9268 = _8863;
            }
            else
            {
                _9268 = _9188;
            }
            bool _4380 = _4346 && _4292;
            bool _4383 = _4352 && _4295;
            float4 _9372;
            if (_4380 || _4383)
            {
                float _9265;
                do
                {
                    uint4 _7175 = r_warped_motion_qdata_tp1.Load(int3(_9020, 0));
                    uint _7176 = _7175.x;
                    if (_7176 != 0u)
                    {
                        float _9264;
                        if (_7176 == 0u)
                        {
                            _9264 = -1.0f;
                        }
                        else
                        {
                            _9264 = float((_7176 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9265 = _9264;
                        break;
                    }
                    int _9247;
                    uint _9248;
                    _9248 = _7176;
                    _9247 = -1;
                    uint _9263;
                    for (; _9247 <= 1; _9248 = _9263, _9247++)
                    {
                        _9263 = _9248;
                        for (int _9261 = -1; _9261 <= 1; )
                        {
                            _9263 = max(_9263, r_warped_motion_qdata_tp1.Load(int3(clamp(_9020 + int2(_9261, _9247), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9261++;
                            continue;
                        }
                    }
                    if (_9248 != 0u)
                    {
                        float _9260;
                        if (_9248 == 0u)
                        {
                            _9260 = -1.0f;
                        }
                        else
                        {
                            _9260 = float((_9248 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9265 = _9260;
                        break;
                    }
                    uint _9250;
                    _9250 = 4294967295u;
                    uint _10420;
                    for (int _9249 = 0; _9249 < 8; _9250 = _10420, _9249++)
                    {
                        int _9253 = 0;
                        for (;;)
                        {
                            if (_9253 < 5)
                            {
                                int2 _7126 = _9020 + (_1093[_9249] * _1102[_9253].xx);
                                bool _7129 = any(bool2(_7126.x < int2(0, 0).x, _7126.y < int2(0, 0).y));
                                bool _7137;
                                if (!_7129)
                                {
                                    _7137 = any(bool2(_7126.x >= cbFI_MvDepthLaneSize.x, _7126.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7137 = _7129;
                                }
                                if (_7137)
                                {
                                    _10420 = _9250;
                                    break;
                                }
                                uint4 _7215 = r_warped_motion_qdata_tp1.Load(int3(_7126, 0));
                                uint _7216 = _7215.x;
                                if (_7216 != 0u)
                                {
                                    _10420 = min(_9250, _7216);
                                    break;
                                }
                                _9253++;
                                continue;
                            }
                            else
                            {
                                _10420 = _9250;
                                break;
                            }
                        }
                    }
                    float _9252;
                    if (_9250 == 4294967295u)
                    {
                        _9252 = -1.0f;
                    }
                    else
                    {
                        float _9251;
                        if (_9250 == 0u)
                        {
                            _9251 = -1.0f;
                        }
                        else
                        {
                            _9251 = float((_9250 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9252 = _9251;
                    }
                    _9265 = _9252;
                    break;
                } while(false);
                float4 _9301;
                if (((_9265 < 0.0f) && _4380) && _4383)
                {
                    uint _7237_dummy_parameter;
                    float _7261 = log((r_depth_tm1.Load(int3(int2(floor(_8990 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7237_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7269_dummy_parameter;
                    float _7293 = log((r_depth_tp1.Load(int3(int2(floor(_8992 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7269_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9302;
                    if (_7261 > (_7293 + 0.07999999821186065673828125f))
                    {
                        float4 _8867 = _9268;
                        _8867.x = 0.0f;
                        _9302 = _8867;
                    }
                    else
                    {
                        float4 _9303;
                        if (_7293 > (_7261 + 0.07999999821186065673828125f))
                        {
                            float4 _8869 = _9268;
                            _8869.y = 0.0f;
                            _9303 = _8869;
                        }
                        else
                        {
                            _9303 = _9268;
                        }
                        _9302 = _9303;
                    }
                    _9301 = _9302;
                }
                else
                {
                    _9301 = _9268;
                }
                float _4423 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4425 = _9265 >= 0.0f;
                float _9284;
                if (_4425)
                {
                    _9284 = _9265 - _4423;
                }
                else
                {
                    float _9280;
                    if (_4380)
                    {
                        float _9279;
                        _9279 = 2.0f;
                        float _7351;
                        for (int _9278 = 0; _9278 < 24; _9279 = _7351, _9278++)
                        {
                            float _7315 = float(_9278 & 7) * 0.785398185253143310546875f;
                            int _7317 = _9278 >> 3;
                            int _9281;
                            if (_7317 == 0)
                            {
                                _9281 = 16;
                            }
                            else
                            {
                                _9281 = (_7317 == 1) ? 48 : 96;
                            }
                            uint _7367_dummy_parameter;
                            _7351 = min(_9279, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8990 + ((cbFI_MvDepthLaneSizeRcp * float(_9281)) * float2(cos(_7315), sin(_7315))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7367_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9280 = _9279;
                    }
                    else
                    {
                        _9280 = 0.0f;
                    }
                    _9284 = _9280;
                }
                float _9291;
                if (_4425)
                {
                    _9291 = _9265 - _4423;
                }
                else
                {
                    float _9287;
                    if (_4383)
                    {
                        float _9286;
                        _9286 = 2.0f;
                        float _7465;
                        for (int _9285 = 0; _9285 < 24; _9286 = _7465, _9285++)
                        {
                            float _7429 = float(_9285 & 7) * 0.785398185253143310546875f;
                            int _7431 = _9285 >> 3;
                            int _9288;
                            if (_7431 == 0)
                            {
                                _9288 = 16;
                            }
                            else
                            {
                                _9288 = (_7431 == 1) ? 48 : 96;
                            }
                            uint _7497_dummy_parameter;
                            _7465 = min(_9286, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8992 + ((cbFI_MvDepthLaneSizeRcp * float(_9288)) * float2(cos(_7429), sin(_7429))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7497_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9287 = _9286;
                    }
                    else
                    {
                        _9287 = 0.0f;
                    }
                    _9291 = _9287;
                }
                float _9292;
                if (_4380)
                {
                    uint _7529_dummy_parameter;
                    _9292 = r_depth_tm1.Load(int3(int2(floor(_8990 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7529_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9292 = 0.0f;
                }
                float _9293;
                if (_4383)
                {
                    uint _7548_dummy_parameter;
                    _9293 = r_depth_tp1.Load(int3(int2(floor(_8992 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7548_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9293 = 0.0f;
                }
                bool _4480;
                if (_4380)
                {
                    _4480 = _9292 > ((exp((_9284 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4480 = _4380;
                }
                float4 _9309;
                if (_4480)
                {
                    float4 _8871 = _9301;
                    _8871.x = 0.0f;
                    _9309 = _8871;
                }
                else
                {
                    _9309 = _9301;
                }
                bool _4492;
                if (_4383)
                {
                    _4492 = _9293 > ((exp((_9291 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4492 = _4383;
                }
                float4 _9311;
                if (_4492)
                {
                    float4 _8873 = _9309;
                    _8873.y = 0.0f;
                    _9311 = _8873;
                }
                else
                {
                    _9311 = _9309;
                }
                float4 _9373;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4425)
                {
                    bool _4512;
                    if (_4380)
                    {
                        _4512 = _9292 < ((exp((_9284 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4512 = _4380;
                    }
                    float4 _9313;
                    if (_4512)
                    {
                        float4 _8875 = _9311;
                        _8875.x = 0.0f;
                        _9313 = _8875;
                    }
                    else
                    {
                        _9313 = _9311;
                    }
                    bool _4524;
                    if (_4383)
                    {
                        _4524 = _9293 < ((exp((_9291 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4524 = _4383;
                    }
                    float4 _9374;
                    if (_4524)
                    {
                        float4 _8877 = _9313;
                        _8877.y = 0.0f;
                        _9374 = _8877;
                    }
                    else
                    {
                        _9374 = _9313;
                    }
                    _9373 = _9374;
                }
                else
                {
                    _9373 = _9311;
                }
                _9372 = _9373;
            }
            else
            {
                _9372 = _9268;
            }
            bool _4535 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4304;
            bool _4541;
            if (_4535)
            {
                _4541 = _4358 || _4364;
            }
            else
            {
                _4541 = _4535;
            }
            float4 _9394;
            if (_4541)
            {
                float _9367;
                do
                {
                    uint4 _7727 = r_warped_motion_qdata_tp1.Load(int3(_9020, 0));
                    uint _7728 = _7727.x;
                    if (_7728 != 0u)
                    {
                        float _9366;
                        if (_7728 == 0u)
                        {
                            _9366 = -1.0f;
                        }
                        else
                        {
                            _9366 = float((_7728 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9367 = _9366;
                        break;
                    }
                    int _9349;
                    uint _9350;
                    _9350 = _7728;
                    _9349 = -1;
                    uint _9365;
                    for (; _9349 <= 1; _9350 = _9365, _9349++)
                    {
                        _9365 = _9350;
                        for (int _9363 = -1; _9363 <= 1; )
                        {
                            _9365 = max(_9365, r_warped_motion_qdata_tp1.Load(int3(clamp(_9020 + int2(_9363, _9349), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9363++;
                            continue;
                        }
                    }
                    if (_9350 != 0u)
                    {
                        float _9362;
                        if (_9350 == 0u)
                        {
                            _9362 = -1.0f;
                        }
                        else
                        {
                            _9362 = float((_9350 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9367 = _9362;
                        break;
                    }
                    uint _9352;
                    _9352 = 4294967295u;
                    uint _10421;
                    for (int _9351 = 0; _9351 < 8; _9352 = _10421, _9351++)
                    {
                        int _9355 = 0;
                        for (;;)
                        {
                            if (_9355 < 5)
                            {
                                int2 _7678 = _9020 + (_1093[_9351] * _1102[_9355].xx);
                                bool _7681 = any(bool2(_7678.x < int2(0, 0).x, _7678.y < int2(0, 0).y));
                                bool _7689;
                                if (!_7681)
                                {
                                    _7689 = any(bool2(_7678.x >= cbFI_MvDepthLaneSize.x, _7678.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7689 = _7681;
                                }
                                if (_7689)
                                {
                                    _10421 = _9352;
                                    break;
                                }
                                uint4 _7767 = r_warped_motion_qdata_tp1.Load(int3(_7678, 0));
                                uint _7768 = _7767.x;
                                if (_7768 != 0u)
                                {
                                    _10421 = min(_9352, _7768);
                                    break;
                                }
                                _9355++;
                                continue;
                            }
                            else
                            {
                                _10421 = _9352;
                                break;
                            }
                        }
                    }
                    float _9354;
                    if (_9352 == 4294967295u)
                    {
                        _9354 = -1.0f;
                    }
                    else
                    {
                        float _9353;
                        if (_9352 == 0u)
                        {
                            _9353 = -1.0f;
                        }
                        else
                        {
                            _9353 = float((_9352 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9354 = _9353;
                    }
                    _9367 = _9354;
                    break;
                } while(false);
                float4 _9395;
                if (_9367 >= 0.0f)
                {
                    float _7789 = (exp((_9367 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4560;
                    if (_4358)
                    {
                        uint _7796_dummy_parameter;
                        _4560 = r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7796_dummy_parameter))))), 0)).x > _7789;
                    }
                    else
                    {
                        _4560 = _4358;
                    }
                    float4 _9385;
                    if (_4560)
                    {
                        float4 _8879 = _9372;
                        _8879.z = 0.0f;
                        _9385 = _8879;
                    }
                    else
                    {
                        _9385 = _9372;
                    }
                    bool _4572;
                    if (_4364)
                    {
                        uint _7815_dummy_parameter;
                        _4572 = r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7815_dummy_parameter))))), 0)).x > _7789;
                    }
                    else
                    {
                        _4572 = _4364;
                    }
                    float4 _9396;
                    if (_4572)
                    {
                        float4 _8881 = _9385;
                        _8881.w = 0.0f;
                        _9396 = _8881;
                    }
                    else
                    {
                        _9396 = _9385;
                    }
                    _9395 = _9396;
                }
                else
                {
                    _9395 = _9372;
                }
                _9394 = _9395;
            }
            else
            {
                _9394 = _9372;
            }
            bool _4580 = _4346 != _4352;
            bool _4587;
            if (_4580)
            {
                _4587 = _4346 ? _4292 : _4295;
            }
            else
            {
                _4587 = _4580;
            }
            float4 _9477;
            if (_4587)
            {
                bool2 _4592 = _4346.xx;
                float2 _4593 = float2(_4592.x ? _8990.x : _8992.x, _4592.y ? _8990.y : _8992.y);
                float _9387;
                if (_4346)
                {
                    uint _7834_dummy_parameter;
                    _9387 = r_depth_tm1.Load(int3(int2(floor(_4593 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7834_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7850_dummy_parameter;
                    _9387 = r_depth_tp1.Load(int3(int2(floor(_4593 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7850_dummy_parameter))))), 0)).x;
                }
                float4x4 _9388;
                if (_4346)
                {
                    _9388 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9388 = cbFI_MotionTP1ToTM1;
                }
                float2 _9389;
                do
                {
                    float _7877 = _4593.x;
                    float _7880 = 1.0f - _4593.y;
                    float4 _7891 = mul(float4((float2(_7877, _7880) * 2.0f) - 1.0f.xx, _9387, 1.0f), _9388);
                    float _7893 = _7891.w;
                    if (!(_7893 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9389 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7906 = ((_7891.xy / _7893.xx) + 1.0f.xx) * 0.5f;
                    _9389 = float2(_7906.x - _7877, _7880 - _7906.y);
                    break;
                } while(false);
                float2 _4623 = float2(cbFI_DisplaySize);
                float4 _9478;
                if (!(length(((_4593 + _9389) - float2(_4592.x ? _8992.x : _8990.x, _4592.y ? _8992.y : _8990.y)) * _4623) <= ((0.100000001490116119384765625f * length(_9389 * _4623)) + 8.0f)))
                {
                    float4 _9479;
                    if (_4346)
                    {
                        float4 _8891 = _9394;
                        _8891.x = 0.0f;
                        _9479 = _8891;
                    }
                    else
                    {
                        float4 _8893 = _9394;
                        _8893.y = 0.0f;
                        _9479 = _8893;
                    }
                    _9478 = _9479;
                }
                else
                {
                    _9478 = _9394;
                }
                _9477 = _9478;
            }
            else
            {
                _9477 = _9394;
            }
            float4 _4648 = _9169 * _9477;
            float _4650 = dot(_4648, 1.0f.xxxx);
            float4 _9654;
            bool _9674;
            if (_4650 > 0.0f)
            {
                _9674 = _9139;
                _9654 = _4648 / _4650.xxxx;
            }
            else
            {
                bool _4661 = any(bool4(_9477.x < 1.0f.xxxx.x, _9477.y < 1.0f.xxxx.y, _9477.z < 1.0f.xxxx.z, _9477.w < 1.0f.xxxx.w));
                if (_4661)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7928;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7928);
                    }
                }
                bool4 _10450 = _4661.xxxx;
                _9674 = _4661 ? true : _9139;
                _9654 = float4(_10450.x ? 0.0f.xxxx.x : _9169.x, _10450.y ? 0.0f.xxxx.y : _9169.y, _10450.z ? 0.0f.xxxx.z : _9169.z, _10450.w ? 0.0f.xxxx.w : _9169.w);
            }
            _9673 = _9674;
            _9653 = _9654;
        }
        else
        {
            _9673 = _9139;
            _9653 = _9169;
        }
        uint _4670 = (cbFI_pad0 >> 24u) & 31u;
        uint _4674 = (cbFI_pad0 >> 16u) & 255u;
        bool _4676 = _4670 != 0u;
        bool _4678 = _4674 == 12u;
        bool _4681 = _4674 == 13u;
        float4 _9670;
        if ((_4676 || _4678) || _4681)
        {
            float _9480;
            do
            {
                bool _8012 = all(bool2(_8993.x > 0.0f.xx.x, _8993.y > 0.0f.xx.y));
                bool _8018;
                if (_8012)
                {
                    _8018 = all(bool2(_8993.x < 1.0f.xx.x, _8993.y < 1.0f.xx.y));
                }
                else
                {
                    _8018 = _8012;
                }
                bool _7949 = !_8018;
                bool _7956;
                if (!_7949)
                {
                    bool _8023 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
                    bool _8029;
                    if (_8023)
                    {
                        _8029 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8029 = _8023;
                    }
                    _7956 = !_8029;
                }
                else
                {
                    _7956 = _7949;
                }
                if (_7956)
                {
                    _9480 = 0.0f;
                    break;
                }
                uint _8036_dummy_parameter;
                uint _8052_dummy_parameter;
                float4 _7977 = mul(float4((float2(_8993.x, 1.0f - _8993.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8993 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8036_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7979 = _7977.w;
                if (abs(_7979) < 9.9999999747524270787835121154785e-07f)
                {
                    _9480 = 0.0f;
                    break;
                }
                float _7990 = abs(cbFI_DeviceToViewDepth.y / ((_7977.z / _7979) - cbFI_DeviceToViewDepth.x));
                float _7993 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8052_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9480 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7990 - _7993) / max(max(_7990, _7993), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8100 = all(bool2(_8994.x > 0.0f.xx.x, _8994.y > 0.0f.xx.y));
            bool _8106;
            if (_8100)
            {
                _8106 = all(bool2(_8994.x < 1.0f.xx.x, _8994.y < 1.0f.xx.y));
            }
            else
            {
                _8106 = _8100;
            }
            float _9481;
            if (_8106)
            {
                uint _8113_dummy_parameter;
                _9481 = length((_5475 + (r_motion_tp1.Load(int3(int2(floor(_8994 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8113_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9481 = 1000000.0f;
            }
            float _9492;
            if ((_4670 & 1u) != 0u)
            {
                _9492 = _9480;
            }
            else
            {
                _9492 = 1.0f;
            }
            float _9493;
            if ((_4670 & 2u) != 0u)
            {
                _9493 = _9492 * (1.0f - smoothstep(2.0f, 8.0f, _9481));
            }
            else
            {
                _9493 = _9492;
            }
            float _9494;
            if ((_4670 & 4u) != 0u)
            {
                _9494 = _9493 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6196 - _6204) - length(_6180 - _6188))));
            }
            else
            {
                _9494 = _9493;
            }
            float _9664;
            if ((_4670 & 8u) != 0u)
            {
                _9664 = lerp(1.0f, _9494, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6180 - _6188)));
            }
            else
            {
                _9664 = _9494;
            }
            bool _4756 = (_4670 & 16u) != 0u;
            bool _4765;
            if (_4756)
            {
                _4765 = length(_8988 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4765 = _4756;
            }
            float _10452 = _4765 ? 1.0f : _9664;
            bool _4771 = _4676 && _6389;
            bool _4776;
            if (_4771)
            {
                bool _8138 = all(bool2(_8990.x > 0.0f.xx.x, _8990.y > 0.0f.xx.y));
                bool _8144;
                if (_8138)
                {
                    _8144 = all(bool2(_8990.x < 1.0f.xx.x, _8990.y < 1.0f.xx.y));
                }
                else
                {
                    _8144 = _8138;
                }
                _4776 = _8144;
            }
            else
            {
                _4776 = _4771;
            }
            bool _4781;
            if (_4776)
            {
                bool _8149 = all(bool2(_8992.x > 0.0f.xx.x, _8992.y > 0.0f.xx.y));
                bool _8155;
                if (_8149)
                {
                    _8155 = all(bool2(_8992.x < 1.0f.xx.x, _8992.y < 1.0f.xx.y));
                }
                else
                {
                    _8155 = _8149;
                }
                _4781 = _8155;
            }
            else
            {
                _4781 = _4776;
            }
            float4 _9671;
            if (_4781)
            {
                float _4787 = _9653.x + _9653.y;
                float _4796 = (_9653.z + _9653.w) * (1.0f - _10452);
                float _9667;
                if (_4787 > 9.9999997473787516355514526367188e-06f)
                {
                    _9667 = _9653.x / _4787;
                }
                else
                {
                    _9667 = _3964;
                }
                _9671 = float4(_9653.x + (_4796 * _9667), _9653.y + (_4796 * (1.0f - _9667)), _9653.zw * _10452);
            }
            else
            {
                _9671 = _9653;
            }
            _9670 = _9671;
        }
        else
        {
            _9670 = _9653;
        }
        float3 _10225;
        if (_9673)
        {
            float3 _8161 = r_current_interpolation_source.Load(int3(_3370, 0)).xyz;
            float3 _10226;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6389)
            {
                uint _8168_dummy_parameter;
                float _9776;
                _9776 = r_depth_tm1.Load(int3(int2(floor(_8990 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8168_dummy_parameter))))), 0)).x;
                float _4908;
                for (int _9775 = 0; _9775 < 24; _9776 = _4908, _9775++)
                {
                    float _4880 = float(_9775 & 7) * 0.785398185253143310546875f;
                    int _4882 = _9775 >> 3;
                    int _10275;
                    if (_4882 == 0)
                    {
                        _10275 = 16;
                    }
                    else
                    {
                        _10275 = (_4882 == 1) ? 48 : 96;
                    }
                    uint _8188_dummy_parameter;
                    _4908 = min(_9776, r_depth_tm1.Load(int3(int2(floor(clamp(_8990 + ((cbFI_MvDepthLaneSizeRcp * float(_10275)) * float2(cos(_4880), sin(_4880))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8188_dummy_parameter))))), 0)).x);
                }
                float2 _9777;
                do
                {
                    float _8210 = 1.0f - _8990.y;
                    float4 _8221 = mul(float4((float2(_8990.x, _8210) * 2.0f) - 1.0f.xx, _9776, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8223 = _8221.w;
                    if (!(_8223 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9777 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8236 = ((_8221.xy / _8223.xx) + 1.0f.xx) * 0.5f;
                    _9777 = float2(_8236.x - _8990.x, _8210 - _8236.y);
                    break;
                } while(false);
                float2 _4919 = _8990 + _9777;
                bool _8254 = all(bool2(_4919.x > 0.0f.xx.x, _4919.y > 0.0f.xx.y));
                bool _8260;
                if (_8254)
                {
                    _8260 = all(bool2(_4919.x < 1.0f.xx.x, _4919.y < 1.0f.xx.y));
                }
                else
                {
                    _8260 = _8254;
                }
                float3 _10227;
                if (_8260)
                {
                    float _4925 = abs(cbFI_DeviceToViewDepth.y / (_9776 - cbFI_DeviceToViewDepth.x));
                    uint _8280_dummy_parameter;
                    int2 _8280 = int2(spvTextureSize(r_depth_m2, uint(0), _8280_dummy_parameter));
                    float _4929 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4919 * float2(_8280))), int2(0, 0), _8280 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10232;
                    if (abs(_4929 - _4925) <= (0.20000000298023223876953125f * max(_4929, _4925)))
                    {
                        uint _8314_dummy_parameter;
                        int2 _8314 = int2(spvTextureSize(r_colour_m2, uint(0), _8314_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8337;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8337);
                        }
                        _10232 = r_colour_m2.Load(int3(clamp(int2(floor(_4919 * float2(_8314))), int2(0, 0), _8314 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8347;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8347);
                        }
                        _10232 = _8161;
                    }
                    _10227 = _10232;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8357;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8357);
                    }
                    _10227 = _8161;
                }
                _10226 = _10227;
            }
            else
            {
                _10226 = _8161;
            }
            _10225 = _10226;
        }
        else
        {
            _10225 = (((_6180 * _9670.x) + (_6188 * _9670.y)) + (_6196 * _9670.z)) + (_6204 * _9670.w);
        }
        uint _4957 = cbFI_pad0 & 255u;
        bool _10120;
        float3 _10224;
        if (_4957 != 0u)
        {
            float3 _4962 = r_present_backbuffer.Load(int3(_3370, 0)).xyz;
            float3 _4966 = r_current_interpolation_source.Load(int3(_3370, 0)).xyz;
            float3 _4970 = abs(_4962 - _4966);
            float3 _9780;
            if (_4957 == 2u)
            {
                _9780 = (abs(_4966) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9780 = 0.000244140625f.xxx;
            }
            bool _4986 = any(bool3(_4970.x > _9780.x, _4970.y > _9780.y, _4970.z > _9780.z));
            bool3 _10453 = _4986.xxx;
            _10224 = float3(_10453.x ? _4962.x : _10225.x, _10453.y ? _4962.y : _10225.y, _10453.z ? _4962.z : _10225.z);
            _10120 = _4986;
        }
        else
        {
            _10224 = _10225;
            _10120 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8372;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8372);
        }
        float3 _10208;
        if (_4674 == 1u)
        {
            _10208 = lerp(_6180, _6188, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10209;
            if (_4674 == 2u)
            {
                _10209 = lerp(_6196, _6204, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10210;
                if (_4674 == 3u)
                {
                    _10210 = float(_10120).xxx;
                }
                else
                {
                    float3 _10211;
                    if (_4674 == 4u)
                    {
                        _10211 = float3(((_8988 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10212;
                        if (_4674 == 5u)
                        {
                            _10212 = float3(((_5475 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10213;
                            if (_4674 == 6u)
                            {
                                _10213 = float3(_9670.xy, _9670.z + _9670.w);
                            }
                            else
                            {
                                float3 _10214;
                                if (_4674 == 7u)
                                {
                                    _10214 = r_current_interpolation_source.Load(int3(_3370, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10215;
                                    if (_4674 == 8u)
                                    {
                                        _10215 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3739, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10216;
                                        if (_4678)
                                        {
                                            uint _8394_dummy_parameter;
                                            uint _8426_dummy_parameter;
                                            _10216 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3739 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8394_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3739 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8426_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10217;
                                            if (_4681)
                                            {
                                                _10217 = _6196;
                                            }
                                            else
                                            {
                                                float3 _10218;
                                                if (_4674 == 20u)
                                                {
                                                    _10218 = _6180;
                                                }
                                                else
                                                {
                                                    float3 _10219;
                                                    if (_4674 == 21u)
                                                    {
                                                        _10219 = _6188;
                                                    }
                                                    else
                                                    {
                                                        float3 _10220;
                                                        if (_4674 == 22u)
                                                        {
                                                            _10220 = _6204;
                                                        }
                                                        else
                                                        {
                                                            float3 _10221;
                                                            if (_4674 == 18u)
                                                            {
                                                                _10221 = _9929;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10455 = (_4674 == 19u).xxx;
                                                                _10221 = float3(_10455.x ? _9786.x : _10224.x, _10455.y ? _9786.y : _10224.y, _10455.z ? _9786.z : _10224.z);
                                                            }
                                                            _10220 = _10221;
                                                        }
                                                        _10219 = _10220;
                                                    }
                                                    _10218 = _10219;
                                                }
                                                _10217 = _10218;
                                            }
                                            _10216 = _10217;
                                        }
                                        _10215 = _10216;
                                    }
                                    _10214 = _10215;
                                }
                                _10213 = _10214;
                            }
                            _10212 = _10213;
                        }
                        _10211 = _10212;
                    }
                    _10210 = _10211;
                }
                _10209 = _10210;
            }
            _10208 = _10209;
        }
        float3 _10207;
        if ((_4674 >= 9u) && (_4674 <= 11u))
        {
            uint _5144 = 64u + uint((_9020.y * cbFI_MvDepthLaneSize.x) + _9020.x);
            uint _5148 = rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) & 15u;
            float3 _10237;
            if (_4674 == 10u)
            {
                float3 _10206;
                if ((rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) & 32u) != 0u)
                {
                    _10206 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10205;
                    if ((rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) & 16u) != 0u)
                    {
                        _10205 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5169 = ((rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) & 64u) != 0u).xxx;
                        _10205 = float3(_5169.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5169.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5169.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10206 = _10205;
                }
                _10237 = _10206;
            }
            else
            {
                float3 _10238;
                if (_4674 == 11u)
                {
                    uint _5182 = (rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) >> 8u) & 15u;
                    uint _5185 = (rw_nfru_diagnostics.Load<uint>(_5144 * 4 + 0) >> 12u) & 15u;
                    float3 _10198;
                    if ((_5148 == 2u) || (_5148 == 3u))
                    {
                        _10198 = _3066[_5148];
                    }
                    else
                    {
                        bool _5197 = _5182 == 3u;
                        bool _5199 = _5185 == 3u;
                        float3 _10199;
                        if (_5197 && _5199)
                        {
                            _10199 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10200;
                            if (_5197)
                            {
                                _10200 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10201;
                                if (_5199)
                                {
                                    _10201 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10202;
                                    if ((_5182 == 4u) || (_5185 == 4u))
                                    {
                                        _10202 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10203;
                                        if ((_5182 == 1u) || (_5185 == 1u))
                                        {
                                            _10203 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10457 = (_5148 == 1u).xxx;
                                            _10203 = float3(_10457.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10457.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10457.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10202 = _10203;
                                    }
                                    _10201 = _10202;
                                }
                                _10200 = _10201;
                            }
                            _10199 = _10200;
                        }
                        _10198 = _10199;
                    }
                    _10238 = _10198;
                }
                else
                {
                    _10238 = _3066[min(_5148, 7u)];
                }
                _10237 = _10238;
            }
            _10207 = _10237;
        }
        else
        {
            _10207 = _10208;
        }
        float4 _10241;
        if ((_4674 >= 14u) && (_4674 <= 16u))
        {
            float2 _10239;
            if (_4674 == 14u)
            {
                uint _5255_dummy_parameter;
                uint _5261_dummy_parameter;
                _10239 = r_flow_tm1.Load(int3(clamp(int2(floor(_3739 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5255_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5261_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10240;
                if (_4674 == 16u)
                {
                    uint _8477 = r_warped_flow_qdata_tm1.Load(int3(_3755, 0)).x & 2147483647u;
                    uint _8509 = uint(max((int((_8477 >> 16u) & 15u) - 6), 0));
                    _10240 = ((float2(float((1 - (2 * int((_8477 >> 15u) & 1u))) * int(((_8477 >> uint(7)) & 127u) << _8509)), float((1 - (2 * int((_8477 >> 14u) & 1u))) * int((_8477 & 127u) << _8509))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10240 = _5475 * float2(cbFI_DisplaySize);
                }
                _10239 = _10240;
            }
            uint2 _5294 = uint2(clamp(round(_10239 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5296 = _5294.x;
            uint _5303 = _5294.y;
            _10241 = float4(float(_5296 & 255u), float((_5296 >> 8u) | ((_5303 & 15u) << 4u)), float(_5303 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10242;
            if (_4674 == 17u)
            {
                _10242 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3755, 0)).x != 0u), _4098, 0.0f, 1.0f);
            }
            else
            {
                _10242 = float4(_10207, 1.0f);
            }
            _10241 = _10242;
        }
        rw_output[_3370] = _10241.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5347 = ((uint(_3370.y) * uint(cbFI_DisplaySize.x)) + uint(_3370.x)) * 6u;
            uint _8555 = spvPackHalf2x16(clamp(_6179.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5347 * 4 + 0, (((_8555 & 32767u) >> 4u) | ((((_8555 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6179.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8590 = spvPackHalf2x16(clamp(_6187.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5347 + 1u) * 4 + 0, (((_8590 & 32767u) >> 4u) | ((((_8590 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6187.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8625 = spvPackHalf2x16(clamp(_6195.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5347 + 2u) * 4 + 0, (((_8625 & 32767u) >> 4u) | ((((_8625 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6195.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8660 = spvPackHalf2x16(clamp(_6203.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5347 + 3u) * 4 + 0, (((_8660 & 32767u) >> 4u) | ((((_8660 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6203.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8687 = r_current_interpolation_source.Load(int3(_3370, 0));
            uint _8701 = spvPackHalf2x16(clamp(_8687.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5347 + 4u) * 4 + 0, (((_8701 & 32767u) >> 4u) | ((((_8701 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8687.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10274;
            if (_10120 || (_4674 != 0u))
            {
                _10274 = 4294967295u;
            }
            else
            {
                uint _8736 = spvPackHalf2x16(clamp(_10241.xy, 0.0f.xx, 65000.0f.xx));
                _10274 = (((_8736 & 32767u) >> 4u) | ((((_8736 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10241.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5347 + 5u) * 4 + 0, _10274);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3370] = float4(r_current_interpolation_source.Load(int3(_3370, 0)).xyz, 1.0f).xyz;
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
