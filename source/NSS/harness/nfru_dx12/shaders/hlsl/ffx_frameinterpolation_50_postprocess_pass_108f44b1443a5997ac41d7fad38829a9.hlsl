static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3385[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3689 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3689.x >= cbFI_DisplaySize.x, _3689.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3689] = float4(r_present_backbuffer.Load(int3(_3689, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3689] = float4(r_current_interpolation_source.Load(int3(_3689, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4097 = (float2(_3689) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4108 = int2(floor(_4097 * float2(cbFI_MvDepthLaneSize)));
        int2 _4113 = int2(floor(_4097 * float2(cbFI_FlowLaneSize)));
        float4 _6099 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4097 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6105 = r_warped_filled_flow_tm1.Load(int3(_4113, 0)).xy;
        float2 _6111 = r_warped_filled_motion_tp1.Load(int3(_4108, 0)).xy;
        bool _6133 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10289;
        if (_6133)
        {
            float _6146 = ((2.0f * _4097.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10289 = float2(atan(_6146) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4097.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6146 * _6146))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10289 = _4097;
        }
        bool _4134 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10310;
        bool _10331;
        int2 _10342;
        float3 _11771;
        if (_4134)
        {
            float _10291;
            float _10293;
            _10293 = 2.0f;
            _10291 = -1.0f;
            uint _3753[9];
            float _12213;
            float _12216;
            for (int _10290 = 0; _10290 < 9; _10293 = _12216, _10291 = _12213, _10290++)
            {
                _3753[_10290] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4108 + int2((_10290 % 3) - 1, (_10290 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3753[_10290] != 0u)
                {
                    float _12208;
                    if (_3753[_10290] == 0u)
                    {
                        _12208 = -1.0f;
                    }
                    else
                    {
                        _12208 = float((_3753[_10290] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12216 = min(_10293, _12208);
                    _12213 = max(_10291, _12208);
                }
                else
                {
                    _12216 = _10293;
                    _12213 = _10291;
                }
            }
            float _4180 = float(_10291 >= 0.0f);
            float3 _10082 = 0.0f.xxx;
            _10082.y = _4180;
            float2 _10311;
            bool _10332;
            int2 _10343;
            float3 _11772;
            if ((_10291 - _10293) > 0.0199999995529651641845703125f)
            {
                float _10299;
                int2 _10300;
                float2 _10301;
                int2 _10303;
                float2 _10309;
                _10309 = _6111;
                _10303 = _4108;
                _10301 = _6111;
                _10300 = _4108;
                _10299 = -1.0f;
                float _12221;
                int2 _12225;
                float2 _12236;
                int2 _12247;
                float2 _12280;
                float _12327;
                int _10298 = 0;
                float _12189 = 1000000000.0f;
                for (; _10298 < 9; _12189 = _12327, _10309 = _12280, _10303 = _12247, _10301 = _12236, _10300 = _12225, _10299 = _12221, _10298++)
                {
                    if (_3753[_10298] == 0u)
                    {
                        _12327 = _12189;
                        _12280 = _10309;
                        _12247 = _10303;
                        _12236 = _10301;
                        _12225 = _10300;
                        _12221 = _10299;
                        continue;
                    }
                    int2 _4215 = clamp(_4108 + int2((_10298 % 3) - 1, (_10298 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6221 = _3753[_10298] & 2147483647u;
                    uint _6253 = uint(max((int((_6221 >> 16u) & 15u) - 6), 0));
                    float2 _4221 = (float2(float((1 - (2 * int((_6221 >> 15u) & 1u))) * int(((_6221 >> uint(7)) & 127u) << _6253)), float((1 - (2 * int((_6221 >> 14u) & 1u))) * int((_6221 & 127u) << _6253))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12175;
                    if (_3753[_10298] == 0u)
                    {
                        _12175 = -1.0f;
                    }
                    else
                    {
                        _12175 = float((_3753[_10298] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4226 = _12175 - 0.100000001490116119384765625f;
                    float2 _12176;
                    if (_6133)
                    {
                        float2 _6330 = clamp((((_10289 + (_4221 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6333 = tan(_6330.x);
                        _12176 = (float2(_6333 / cbFI_DeviceToViewDepth.z, (tan(_6330.y) * sqrt(1.0f + (_6333 * _6333))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12176 = _10289 + (_4221 * cbFI_Timestep);
                    }
                    float _4233 = cbFI_Timestep - 1.0f;
                    float2 _12177;
                    if (_6133)
                    {
                        float2 _6401 = clamp((((_10289 + (_4221 * _4233)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6404 = tan(_6401.x);
                        _12177 = (float2(_6404 / cbFI_DeviceToViewDepth.z, (tan(_6401.y) * sqrt(1.0f + (_6404 * _6404))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12177 = _10289 + (_4221 * _4233);
                    }
                    bool _6437 = all(bool2(_12176.x > 0.0f.xx.x, _12176.y > 0.0f.xx.y));
                    bool _6443;
                    if (_6437)
                    {
                        _6443 = all(bool2(_12176.x < 1.0f.xx.x, _12176.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6443 = _6437;
                    }
                    float _12180;
                    if (_6443)
                    {
                        uint _6450_dummy_parameter;
                        _12180 = max((_4226 - (log(((r_depth_tm1.Load(int3(int2(floor(_12176 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6450_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12180 = 0.0f;
                    }
                    bool _6480 = all(bool2(_12177.x > 0.0f.xx.x, _12177.y > 0.0f.xx.y));
                    bool _6486;
                    if (_6480)
                    {
                        _6486 = all(bool2(_12177.x < 1.0f.xx.x, _12177.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6486 = _6480;
                    }
                    float _12181;
                    if (_6486)
                    {
                        uint _6493_dummy_parameter;
                        _12181 = _12180 + max((_4226 - (log(((r_depth_tp1.Load(int3(int2(floor(_12177 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6493_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12181 = _12180;
                    }
                    float _12222;
                    int2 _12226;
                    float2 _12237;
                    int2 _12248;
                    float2 _12281;
                    float _12328;
                    if (_12181 == 0.0f)
                    {
                        bool _4268 = _4226 > _10299;
                        bool2 _12336 = _4268.xx;
                        _12328 = _12189;
                        _12281 = float2(_12336.x ? _4221.x : _10309.x, _12336.y ? _4221.y : _10309.y);
                        _12248 = int2(_12336.x ? _4215.x : _10303.x, _12336.y ? _4215.y : _10303.y);
                        _12237 = _10301;
                        _12226 = _10300;
                        _12222 = _4268 ? _4226 : _10299;
                    }
                    else
                    {
                        bool _4277 = _12181 < _12189;
                        bool2 _12332 = _4277.xx;
                        _12328 = _4277 ? _12181 : _12189;
                        _12281 = _10309;
                        _12248 = _10303;
                        _12237 = float2(_12332.x ? _4221.x : _10301.x, _12332.y ? _4221.y : _10301.y);
                        _12226 = int2(_12332.x ? _4215.x : _10300.x, _12332.y ? _4215.y : _10300.y);
                        _12222 = _10299;
                    }
                    _12327 = _12328;
                    _12280 = _12281;
                    _12247 = _12248;
                    _12236 = _12237;
                    _12225 = _12226;
                    _12221 = _12222;
                }
                bool _4289 = _10299 < 0.0f;
                bool2 _12342 = _4289.xx;
                int2 _12345 = int2(_12342.x ? _10300.x : _10303.x, _12342.y ? _10300.y : _10303.y);
                _11772 = float3(1.0f, _4180, float(any(bool2(_12345.x != _4108.x, _12345.y != _4108.y))));
                _10343 = _12345;
                _10332 = _4289 ? false : true;
                _10311 = float2(_12342.x ? _10301.x : _10309.x, _12342.y ? _10301.y : _10309.y);
            }
            else
            {
                _11772 = _10082;
                _10343 = _4108;
                _10332 = false;
                _10311 = _6111;
            }
            _11771 = _11772;
            _10342 = _10343;
            _10331 = _10332;
            _10310 = _10311;
        }
        else
        {
            _11771 = 0.0f.xxx;
            _10342 = _4108;
            _10331 = false;
            _10310 = _6111;
        }
        float2 _10312;
        if (_6133)
        {
            float2 _6558 = clamp((((_10289 + (_10310 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6561 = tan(_6558.x);
            _10312 = (float2(_6561 / cbFI_DeviceToViewDepth.z, (tan(_6558.y) * sqrt(1.0f + (_6561 * _6561))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10312 = _10289 + (_10310 * cbFI_Timestep);
        }
        float _4312 = cbFI_Timestep - 1.0f;
        float2 _10314;
        if (_6133)
        {
            float2 _6629 = clamp((((_10289 + (_10310 * _4312)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6632 = tan(_6629.x);
            _10314 = (float2(_6632 / cbFI_DeviceToViewDepth.z, (tan(_6629.y) * sqrt(1.0f + (_6632 * _6632))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10314 = _10289 + (_10310 * _4312);
        }
        float _4317 = -cbFI_Timestep;
        float2 _10315;
        if (_6133)
        {
            float2 _6700 = clamp((((_10289 + (_6105 * _4317)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6703 = tan(_6700.x);
            _10315 = (float2(_6703 / cbFI_DeviceToViewDepth.z, (tan(_6700.y) * sqrt(1.0f + (_6703 * _6703))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10315 = _10289 + (_6105 * _4317);
        }
        float _4322 = 1.0f - cbFI_Timestep;
        float2 _10316;
        if (_6133)
        {
            float2 _6771 = clamp((((_10289 + (_6105 * _4322)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6774 = tan(_6771.x);
            _10316 = (float2(_6774 / cbFI_DeviceToViewDepth.z, (tan(_6771.y) * sqrt(1.0f + (_6774 * _6774))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10316 = _10289 + (_6105 * _4322);
        }
        float4 _6809 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10312, 0.0f);
        float3 _6810 = _6809.xyz;
        float4 _6817 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10314, 0.0f);
        float3 _6818 = _6817.xyz;
        float4 _6825 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10315, 0.0f);
        float3 _6826 = _6825.xyz;
        float4 _6833 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10316, 0.0f);
        float3 _6834 = _6833.xyz;
        float4 _6848 = exp(_6099 - max(max(max(_6099.x, _6099.y), _6099.z), _6099.w).xxxx);
        float4 _6855 = _6848 / (dot(_6848, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4341 = _4134 && (!_10331);
        bool _4350;
        if (_4341)
        {
            _4350 = (_6855.z + _6855.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4350 = _4341;
        }
        bool _4361;
        if (_4350)
        {
            _4361 = length((_10315 - _10312) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4361 = _4350;
        }
        bool _10355;
        if (_4361)
        {
            uint4 _6874 = r_warped_motion_qdata_tp1.Load(int3(_10342, 0));
            uint _6875 = _6874.x;
            bool _10358;
            if (_6875 != 0u)
            {
                float _10344;
                if (_6875 == 0u)
                {
                    _10344 = -1.0f;
                }
                else
                {
                    _10344 = float((_6875 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4371 = _10344 - 0.12000000476837158203125f;
                bool _6894 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                bool _6900;
                if (_6894)
                {
                    _6900 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                }
                else
                {
                    _6900 = _6894;
                }
                bool _4381;
                if (_6900)
                {
                    uint _6907_dummy_parameter;
                    _4381 = (log(((r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6907_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4371;
                }
                else
                {
                    _4381 = _6900;
                }
                bool _4395;
                if (!_4381)
                {
                    bool _6937 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                    bool _6943;
                    if (_6937)
                    {
                        _6943 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6943 = _6937;
                    }
                    bool _4393;
                    if (_6943)
                    {
                        uint _6950_dummy_parameter;
                        _4393 = (log(((r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6950_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4371;
                    }
                    else
                    {
                        _4393 = _6943;
                    }
                    _4395 = _4393;
                }
                else
                {
                    _4395 = _4381;
                }
                _10358 = _4395;
            }
            else
            {
                _10358 = false;
            }
            _10355 = _10358;
        }
        else
        {
            _10355 = false;
        }
        bool _4400 = _10331 || _10355;
        bool _4405;
        if (_4400)
        {
            bool _6980 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
            bool _6986;
            if (_6980)
            {
                _6986 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
            }
            else
            {
                _6986 = _6980;
            }
            _4405 = _6986;
        }
        else
        {
            _4405 = _4400;
        }
        bool _4410;
        if (_4405)
        {
            bool _6991 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
            bool _6997;
            if (_6991)
            {
                _6997 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
            }
            else
            {
                _6997 = _6991;
            }
            _4410 = _6997;
        }
        else
        {
            _4410 = _4405;
        }
        float4 _10452;
        if (_4410)
        {
            float _4413 = _6855.x;
            float _4415 = _6855.y;
            float _4416 = _4413 + _4415;
            float _4421 = _6855.z + _6855.w;
            float _10373;
            if (_4416 > 0.001000000047497451305389404296875f)
            {
                _10373 = _4413 / _4416;
            }
            else
            {
                _10373 = _4322;
            }
            _10452 = float4(_4413 + (_4421 * _10373), _4415 + (_4421 * (1.0f - _10373)), 0.0f, 0.0f);
        }
        else
        {
            _10452 = _6855;
        }
        bool _7025 = (cbFI_pad0 & 1024u) != 0u;
        bool _7001 = !_7025;
        bool _7002 = !_7001;
        bool _7019;
        if (_7002)
        {
            _7019 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10342.y * cbFI_MvDepthLaneSize.x) + _10342.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7019 = _7001;
        }
        bool _7051;
        if (_7002)
        {
            _7051 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4113.y * cbFI_FlowLaneSize.x) + _4113.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7051 = _7001;
        }
        float _4456 = float(_7051);
        bool _10465;
        float4 _10496;
        float3 _11575;
        if (_7025)
        {
            bool _4466;
            if (_7019)
            {
                _4466 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
            }
            else
            {
                _4466 = _7019;
            }
            bool _4472;
            if (_4466)
            {
                _4472 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
            }
            else
            {
                _4472 = _4466;
            }
            bool _4479;
            if (_7019)
            {
                _4479 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
            }
            else
            {
                _4479 = _7019;
            }
            bool _4485;
            if (_4479)
            {
                _4485 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
            }
            else
            {
                _4485 = _4479;
            }
            bool _4492;
            if (_7051)
            {
                _4492 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
            }
            else
            {
                _4492 = _7051;
            }
            bool _4498;
            if (_4492)
            {
                _4498 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
            }
            else
            {
                _4498 = _4492;
            }
            bool _4505;
            if (_7051)
            {
                _4505 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
            }
            else
            {
                _4505 = _7051;
            }
            bool _4511;
            if (_4505)
            {
                _4511 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
            }
            else
            {
                _4511 = _4505;
            }
            bool _4513 = !_7019;
            if (_4513)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7093;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7093);
                }
            }
            bool _4518 = !_7051;
            if (_4518)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7103;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7103);
                }
            }
            if (_7019 && _4518)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7113;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7113);
                }
            }
            if (_4513 && _7051)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7123;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7123);
                }
            }
            float _4537 = float(_4472);
            float _4539 = float(_4485);
            bool _4542 = _4498 && _4511;
            float _10407;
            if (_4542)
            {
                _10407 = 1.0f;
            }
            else
            {
                _10407 = (_4498 || _4511) ? 0.5f : 0.0f;
            }
            bool _10412;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4472)) && (!_4485))
            {
                bool _4572;
                if (_4542)
                {
                    float _10410;
                    do
                    {
                        bool _7207 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                        bool _7213;
                        if (_7207)
                        {
                            _7213 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7213 = _7207;
                        }
                        bool _7144 = !_7213;
                        bool _7151;
                        if (!_7144)
                        {
                            bool _7218 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                            bool _7224;
                            if (_7218)
                            {
                                _7224 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7224 = _7218;
                            }
                            _7151 = !_7224;
                        }
                        else
                        {
                            _7151 = _7144;
                        }
                        if (_7151)
                        {
                            _10410 = 0.0f;
                            break;
                        }
                        uint _7231_dummy_parameter;
                        uint _7247_dummy_parameter;
                        float4 _7172 = mul(float4((float2(_10315.x, 1.0f - _10315.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7231_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7174 = _7172.w;
                        if (abs(_7174) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10410 = 0.0f;
                            break;
                        }
                        float _7185 = abs(cbFI_DeviceToViewDepth.y / ((_7172.z / _7174) - cbFI_DeviceToViewDepth.x));
                        float _7188 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7247_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10410 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7185 - _7188) / max(max(_7185, _7188), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4572 = _10410 >= 0.5f;
                }
                else
                {
                    _4572 = _4542;
                }
                bool _4580;
                if (_4572)
                {
                    _4580 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4580 = _4572;
                }
                bool _10413;
                if (_4580)
                {
                    uint _7297_dummy_parameter;
                    float2 _10411;
                    do
                    {
                        float _7323 = 1.0f - _10315.y;
                        float4 _7334 = mul(float4((float2(_10315.x, _7323) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7297_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7336 = _7334.w;
                        if (!(_7336 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10411 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7349 = ((_7334.xy / _7336.xx) + 1.0f.xx) * 0.5f;
                        _10411 = float2(_7349.x - _10315.x, _7323 - _7349.y);
                        break;
                    } while(false);
                    float2 _4593 = float2(cbFI_DisplaySize);
                    _10413 = length(((_10315 + _10411) - _10316) * _4593) <= ((0.100000001490116119384765625f * length(_10411 * _4593)) + 8.0f);
                }
                else
                {
                    _10413 = _4572;
                }
                _10412 = _10413;
            }
            else
            {
                _10412 = true;
            }
            bool _4607 = !_10412;
            bool _12346 = _4607 ? false : _4511;
            bool _12347 = _4607 ? false : _4498;
            bool _10466;
            float4 _10497;
            if (!(((_4472 && _4485) && _12347) && _12346))
            {
                float4 _4629 = _10452 * float4(_4537, _4539, float(_12347), float(_12346));
                float _4631 = dot(_4629, 1.0f.xxxx);
                bool _4634 = !(_4631 > 0.0f);
                float4 _10498;
                if (!_4634)
                {
                    _10498 = _4629 / _4631.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7371;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7371);
                    }
                    _10498 = 0.0f.xxxx;
                }
                _10497 = _10498;
                _10466 = _4634;
            }
            else
            {
                _10497 = _10452;
                _10466 = false;
            }
            _11575 = float3(_4537, _4539, _10407);
            _10496 = _10497;
            _10465 = _10466;
        }
        else
        {
            _11575 = float3(float(_7019), _4456, 0.0f);
            _10496 = _10452;
            _10465 = false;
        }
        bool _4652 = !_10465;
        float4 _10560;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4652)
        {
            float _4659 = _10496.x + _10496.y;
            float4 _10561;
            if (_4659 > 0.001000000047497451305389404296875f)
            {
                _10561 = float4(_10496.x / _4659, _10496.y / _4659, 0.0f, 0.0f);
            }
            else
            {
                _10561 = float4(_4322, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10560 = _10561;
        }
        else
        {
            _10560 = _10496;
        }
        float4 _10684;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4652) && _7019)
        {
            float _10555;
            do
            {
                uint4 _7511 = r_warped_motion_qdata_tp1.Load(int3(_10342, 0));
                uint _7512 = _7511.x;
                if (_7512 != 0u)
                {
                    float _10554;
                    if (_7512 == 0u)
                    {
                        _10554 = -1.0f;
                    }
                    else
                    {
                        _10554 = float((_7512 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10555 = _10554;
                    break;
                }
                int _10537;
                uint _10538;
                _10538 = _7512;
                _10537 = -1;
                uint _10553;
                for (; _10537 <= 1; _10538 = _10553, _10537++)
                {
                    _10553 = _10538;
                    for (int _10551 = -1; _10551 <= 1; )
                    {
                        _10553 = max(_10553, r_warped_motion_qdata_tp1.Load(int3(clamp(_10342 + int2(_10551, _10537), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10551++;
                        continue;
                    }
                }
                if (_10538 != 0u)
                {
                    float _10550;
                    if (_10538 == 0u)
                    {
                        _10550 = -1.0f;
                    }
                    else
                    {
                        _10550 = float((_10538 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10555 = _10550;
                    break;
                }
                uint _10540;
                _10540 = 4294967295u;
                uint _12317;
                for (int _10539 = 0; _10539 < 8; _10540 = _12317, _10539++)
                {
                    int _10543 = 0;
                    for (;;)
                    {
                        if (_10543 < 5)
                        {
                            int2 _7462 = _10342 + (_1093[_10539] * _1102[_10543].xx);
                            bool _7465 = any(bool2(_7462.x < int2(0, 0).x, _7462.y < int2(0, 0).y));
                            bool _7473;
                            if (!_7465)
                            {
                                _7473 = any(bool2(_7462.x >= cbFI_MvDepthLaneSize.x, _7462.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7473 = _7465;
                            }
                            if (_7473)
                            {
                                _12317 = _10540;
                                break;
                            }
                            uint4 _7551 = r_warped_motion_qdata_tp1.Load(int3(_7462, 0));
                            uint _7552 = _7551.x;
                            if (_7552 != 0u)
                            {
                                _12317 = min(_10540, _7552);
                                break;
                            }
                            _10543++;
                            continue;
                        }
                        else
                        {
                            _12317 = _10540;
                            break;
                        }
                    }
                }
                float _10542;
                if (_10540 == 4294967295u)
                {
                    _10542 = -1.0f;
                }
                else
                {
                    float _10541;
                    if (_10540 == 0u)
                    {
                        _10541 = -1.0f;
                    }
                    else
                    {
                        _10541 = float((_10540 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10542 = _10541;
                }
                _10555 = _10542;
                break;
            } while(false);
            float _4695 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4697 = _10555 < 0.0f;
            bool _4702;
            if (_4697)
            {
                bool _7571 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
                bool _7577;
                if (_7571)
                {
                    _7577 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
                }
                else
                {
                    _7577 = _7571;
                }
                _4702 = _7577;
            }
            else
            {
                _4702 = _4697;
            }
            bool _4707;
            if (_4702)
            {
                bool _7582 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
                bool _7588;
                if (_7582)
                {
                    _7588 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
                }
                else
                {
                    _7588 = _7582;
                }
                _4707 = _7588;
            }
            else
            {
                _4707 = _4702;
            }
            float4 _10617;
            if (_4707)
            {
                uint _7595_dummy_parameter;
                float _7619 = log(((r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7595_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7627_dummy_parameter;
                float _7651 = log(((r_depth_tp1.Load(int3(int2(floor(_10314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7627_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4718 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4725;
                if (_4718)
                {
                    _4725 = _7651 > (_7619 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4725 = _4718;
                }
                float4 _10591;
                if (_4725)
                {
                    _10591 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10591 = 1.0f.xxxx;
                }
                bool _4732 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4739;
                if (_4732)
                {
                    _4739 = _7619 > (_7651 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4739 = _4732;
                }
                float4 _10620;
                if (_4739)
                {
                    float4 _10152 = _10591;
                    _10152.x = 0.0f;
                    _10620 = _10152;
                }
                else
                {
                    _10620 = _10591;
                }
                _10617 = _10620;
            }
            else
            {
                bool _4747 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4753;
                if (_4747)
                {
                    _4753 = _10560.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4753 = _4747;
                }
                bool _4758;
                if (_4753)
                {
                    bool _7657 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
                    bool _7663;
                    if (_7657)
                    {
                        _7663 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7663 = _7657;
                    }
                    _4758 = _7663;
                }
                else
                {
                    _4758 = _4753;
                }
                float4 _10618;
                if (_4758)
                {
                    float _10578;
                    if (_10555 >= 0.0f)
                    {
                        _10578 = _10555 - _4695;
                    }
                    else
                    {
                        float _10574;
                        _10574 = 2.0f;
                        float _7720;
                        for (int _10573 = 0; _10573 < 24; _10574 = _7720, _10573++)
                        {
                            float _7684 = float(_10573 & 7) * 0.785398185253143310546875f;
                            int _7686 = _10573 >> 3;
                            int _10575;
                            if (_7686 == 0)
                            {
                                _10575 = 16;
                            }
                            else
                            {
                                _10575 = (_7686 == 1) ? 48 : 96;
                            }
                            uint _7752_dummy_parameter;
                            _7720 = min(_10574, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10314 + ((cbFI_MvDepthLaneSizeRcp * float(_10575)) * float2(cos(_7684), sin(_7684))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7752_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10578 = _10574;
                    }
                    uint _7784_dummy_parameter;
                    float4 _10619;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7784_dummy_parameter))))), 0)).x) > ((exp((_10578 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10619 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10619 = 1.0f.xxxx;
                    }
                    _10618 = _10619;
                }
                else
                {
                    _10618 = 1.0f.xxxx;
                }
                _10617 = _10618;
            }
            bool _4784 = _10555 >= 0.0f;
            bool _4791;
            if (_4784)
            {
                _4791 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4791 = _4784;
            }
            bool _4797;
            if (_4791)
            {
                _4797 = _10560.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4797 = _4791;
            }
            bool _4802;
            if (_4797)
            {
                bool _7809 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
                bool _7815;
                if (_7809)
                {
                    _7815 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
                }
                else
                {
                    _7815 = _7809;
                }
                _4802 = _7815;
            }
            else
            {
                _4802 = _4797;
            }
            float4 _10623;
            if (_4802)
            {
                float _10611;
                if (_4784)
                {
                    _10611 = _10555 - _4695;
                }
                else
                {
                    float _10607;
                    _10607 = 2.0f;
                    float _7872;
                    for (int _10606 = 0; _10606 < 24; _10607 = _7872, _10606++)
                    {
                        float _7836 = float(_10606 & 7) * 0.785398185253143310546875f;
                        int _7838 = _10606 >> 3;
                        int _10608;
                        if (_7838 == 0)
                        {
                            _10608 = 16;
                        }
                        else
                        {
                            _10608 = (_7838 == 1) ? 48 : 96;
                        }
                        uint _7888_dummy_parameter;
                        _7872 = min(_10607, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10312 + ((cbFI_MvDepthLaneSizeRcp * float(_10608)) * float2(cos(_7836), sin(_7836))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7888_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10611 = _10607;
                }
                uint _7936_dummy_parameter;
                float4 _10624;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7936_dummy_parameter))))), 0)).x) > ((exp((_10611 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10158 = _10617;
                    _10158.x = 0.0f;
                    _10624 = _10158;
                }
                else
                {
                    _10624 = _10617;
                }
                _10623 = _10624;
            }
            else
            {
                _10623 = _10617;
            }
            float4 _10685;
            if (any(bool4(_10623.x < 1.0f.xxxx.x, _10623.y < 1.0f.xxxx.y, _10623.z < 1.0f.xxxx.z, _10623.w < 1.0f.xxxx.w)))
            {
                float4 _4832 = _10560 * _10623;
                float _4834 = dot(_4832, 1.0f.xxxx);
                float4 _10686;
                if (_4834 > 0.0f)
                {
                    _10686 = _4832 / _4834.xxxx;
                }
                else
                {
                    bool _4845 = _10623.y == 0.0f;
                    bool _4851;
                    if (_4845)
                    {
                        _4851 = _10623.x > 0.0f;
                    }
                    else
                    {
                        _4851 = _4845;
                    }
                    bool _4856;
                    if (_4851)
                    {
                        bool _7961 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
                        bool _7967;
                        if (_7961)
                        {
                            _7967 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7967 = _7961;
                        }
                        _4856 = _7967;
                    }
                    else
                    {
                        _4856 = _4851;
                    }
                    float4 _10687;
                    if (_4856)
                    {
                        _10687 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4861 = _10623.x == 0.0f;
                        bool _4867;
                        if (_4861)
                        {
                            _4867 = _10623.y > 0.0f;
                        }
                        else
                        {
                            _4867 = _4861;
                        }
                        bool _4872;
                        if (_4867)
                        {
                            bool _7972 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
                            bool _7978;
                            if (_7972)
                            {
                                _7978 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7978 = _7972;
                            }
                            _4872 = _7978;
                        }
                        else
                        {
                            _4872 = _4867;
                        }
                        bool4 _12348 = _4872.xxxx;
                        _10687 = float4(_12348.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10560.x, _12348.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10560.y, _12348.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10560.z, _12348.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10560.w);
                    }
                    _10686 = _10687;
                }
                _10685 = _10686;
            }
            else
            {
                _10685 = _10560;
            }
            _10684 = _10685;
        }
        else
        {
            _10684 = _10560;
        }
        float4 _11250;
        bool _11270;
        float3 _11384;
        if (((cbFI_pad0 & 32768u) != 0u) && _4652)
        {
            bool _4889 = _10684.x > 0.00999999977648258209228515625f;
            bool _4892 = _10684.y > 0.00999999977648258209228515625f;
            bool _4901 = (_10684.z + _10684.w) > 0.0199999995529651641845703125f;
            bool _4907;
            if (_4901)
            {
                bool _7983 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                bool _7989;
                if (_7983)
                {
                    _7989 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                }
                else
                {
                    _7989 = _7983;
                }
                _4907 = _7989;
            }
            else
            {
                _4907 = _4901;
            }
            bool _4912;
            if (_4907)
            {
                bool _7994 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                bool _8000;
                if (_7994)
                {
                    _8000 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                }
                else
                {
                    _8000 = _7994;
                }
                _4912 = _8000;
            }
            else
            {
                _4912 = _4907;
            }
            bool _4919;
            if (_4912)
            {
                float _10695;
                do
                {
                    bool _8083 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                    bool _8089;
                    if (_8083)
                    {
                        _8089 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8089 = _8083;
                    }
                    bool _8020 = !_8089;
                    bool _8027;
                    if (!_8020)
                    {
                        bool _8094 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                        bool _8100;
                        if (_8094)
                        {
                            _8100 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8100 = _8094;
                        }
                        _8027 = !_8100;
                    }
                    else
                    {
                        _8027 = _8020;
                    }
                    if (_8027)
                    {
                        _10695 = 0.0f;
                        break;
                    }
                    uint _8107_dummy_parameter;
                    uint _8123_dummy_parameter;
                    float4 _8048 = mul(float4((float2(_10315.x, 1.0f - _10315.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8107_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8050 = _8048.w;
                    if (abs(_8050) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10695 = 0.0f;
                        break;
                    }
                    float _8061 = abs(cbFI_DeviceToViewDepth.y / ((_8048.z / _8050) - cbFI_DeviceToViewDepth.x));
                    float _8064 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8123_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10695 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8061 - _8064) / max(max(_8061, _8064), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4919 = _10695 < 0.5f;
            }
            else
            {
                _4919 = _4912;
            }
            float4 _10710;
            if (_4919)
            {
                uint _8173_dummy_parameter;
                uint _8204_dummy_parameter;
                float4 _10711;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8173_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8204_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10711 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10711 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10710 = _10711;
            }
            else
            {
                _10710 = 1.0f.xxxx;
            }
            bool _4943;
            if (_7019)
            {
                bool _8233 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
                bool _8239;
                if (_8233)
                {
                    _8239 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
                }
                else
                {
                    _8239 = _8233;
                }
                _4943 = _8239;
            }
            else
            {
                _4943 = _7019;
            }
            bool _4949;
            if (_7019)
            {
                bool _8244 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
                bool _8250;
                if (_8244)
                {
                    _8250 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
                }
                else
                {
                    _8250 = _8244;
                }
                _4949 = _8250;
            }
            else
            {
                _4949 = _7019;
            }
            bool _4955;
            if (_7051)
            {
                bool _8255 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                bool _8261;
                if (_8255)
                {
                    _8261 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                }
                else
                {
                    _8261 = _8255;
                }
                _4955 = _8261;
            }
            else
            {
                _4955 = _7051;
            }
            bool _4961;
            if (_7051)
            {
                bool _8266 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                bool _8272;
                if (_8266)
                {
                    _8272 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                }
                else
                {
                    _8272 = _8266;
                }
                _4961 = _8272;
            }
            else
            {
                _4961 = _7051;
            }
            bool _4964 = _4955 != _4961;
            bool _4970;
            if (_4964)
            {
                _4970 = _4943 || _4949;
            }
            else
            {
                _4970 = _4964;
            }
            float4 _10808;
            if (_4970)
            {
                float4 _10185 = _10710;
                _10185.z = 0.0f;
                _10185.w = 0.0f;
                _10808 = _10185;
            }
            else
            {
                _10808 = _10710;
            }
            bool _4977 = _4943 && _4889;
            bool _4980 = _4949 && _4892;
            float4 _10913;
            float3 _11473;
            if (_4977 || _4980)
            {
                float _10803;
                do
                {
                    uint4 _8411 = r_warped_motion_qdata_tp1.Load(int3(_10342, 0));
                    uint _8412 = _8411.x;
                    if (_8412 != 0u)
                    {
                        float _10802;
                        if (_8412 == 0u)
                        {
                            _10802 = -1.0f;
                        }
                        else
                        {
                            _10802 = float((_8412 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10803 = _10802;
                        break;
                    }
                    int _10785;
                    uint _10786;
                    _10786 = _8412;
                    _10785 = -1;
                    uint _10801;
                    for (; _10785 <= 1; _10786 = _10801, _10785++)
                    {
                        _10801 = _10786;
                        for (int _10799 = -1; _10799 <= 1; )
                        {
                            _10801 = max(_10801, r_warped_motion_qdata_tp1.Load(int3(clamp(_10342 + int2(_10799, _10785), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10799++;
                            continue;
                        }
                    }
                    if (_10786 != 0u)
                    {
                        float _10798;
                        if (_10786 == 0u)
                        {
                            _10798 = -1.0f;
                        }
                        else
                        {
                            _10798 = float((_10786 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10803 = _10798;
                        break;
                    }
                    uint _10788;
                    _10788 = 4294967295u;
                    uint _12318;
                    for (int _10787 = 0; _10787 < 8; _10788 = _12318, _10787++)
                    {
                        int _10791 = 0;
                        for (;;)
                        {
                            if (_10791 < 5)
                            {
                                int2 _8362 = _10342 + (_1093[_10787] * _1102[_10791].xx);
                                bool _8365 = any(bool2(_8362.x < int2(0, 0).x, _8362.y < int2(0, 0).y));
                                bool _8373;
                                if (!_8365)
                                {
                                    _8373 = any(bool2(_8362.x >= cbFI_MvDepthLaneSize.x, _8362.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8373 = _8365;
                                }
                                if (_8373)
                                {
                                    _12318 = _10788;
                                    break;
                                }
                                uint4 _8451 = r_warped_motion_qdata_tp1.Load(int3(_8362, 0));
                                uint _8452 = _8451.x;
                                if (_8452 != 0u)
                                {
                                    _12318 = min(_10788, _8452);
                                    break;
                                }
                                _10791++;
                                continue;
                            }
                            else
                            {
                                _12318 = _10788;
                                break;
                            }
                        }
                    }
                    float _10790;
                    if (_10788 == 4294967295u)
                    {
                        _10790 = -1.0f;
                    }
                    else
                    {
                        float _10789;
                        if (_10788 == 0u)
                        {
                            _10789 = -1.0f;
                        }
                        else
                        {
                            _10789 = float((_10788 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10790 = _10789;
                    }
                    _10803 = _10790;
                    break;
                } while(false);
                bool _4988 = _10803 < 0.0f;
                float _10804;
                if (_4988)
                {
                    _10804 = 0.0f;
                }
                else
                {
                    _10804 = _10803 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8473_dummy_parameter;
                uint _8505_dummy_parameter;
                float4 _10841;
                if ((_4988 && _4977) && _4980)
                {
                    uint _8537_dummy_parameter;
                    float _8561 = log(((r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8537_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8569_dummy_parameter;
                    float _8593 = log(((r_depth_tp1.Load(int3(int2(floor(_10314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8569_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10842;
                    if (_8561 > (_8593 + 0.07999999821186065673828125f))
                    {
                        float4 _10189 = _10808;
                        _10189.x = 0.0f;
                        _10842 = _10189;
                    }
                    else
                    {
                        float4 _10843;
                        if (_8593 > (_8561 + 0.07999999821186065673828125f))
                        {
                            float4 _10191 = _10808;
                            _10191.y = 0.0f;
                            _10843 = _10191;
                        }
                        else
                        {
                            _10843 = _10808;
                        }
                        _10842 = _10843;
                    }
                    _10841 = _10842;
                }
                else
                {
                    _10841 = _10808;
                }
                float _5040 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5042 = _10803 >= 0.0f;
                float _10824;
                if (_5042)
                {
                    _10824 = _10803 - _5040;
                }
                else
                {
                    float _10820;
                    if (_4977)
                    {
                        float _10819;
                        _10819 = 2.0f;
                        float _8651;
                        for (int _10818 = 0; _10818 < 24; _10819 = _8651, _10818++)
                        {
                            float _8615 = float(_10818 & 7) * 0.785398185253143310546875f;
                            int _8617 = _10818 >> 3;
                            int _10821;
                            if (_8617 == 0)
                            {
                                _10821 = 16;
                            }
                            else
                            {
                                _10821 = (_8617 == 1) ? 48 : 96;
                            }
                            uint _8667_dummy_parameter;
                            _8651 = min(_10819, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10312 + ((cbFI_MvDepthLaneSizeRcp * float(_10821)) * float2(cos(_8615), sin(_8615))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8667_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10820 = _10819;
                    }
                    else
                    {
                        _10820 = 0.0f;
                    }
                    _10824 = _10820;
                }
                float _10831;
                if (_5042)
                {
                    _10831 = _10803 - _5040;
                }
                else
                {
                    float _10827;
                    if (_4980)
                    {
                        float _10826;
                        _10826 = 2.0f;
                        float _8765;
                        for (int _10825 = 0; _10825 < 24; _10826 = _8765, _10825++)
                        {
                            float _8729 = float(_10825 & 7) * 0.785398185253143310546875f;
                            int _8731 = _10825 >> 3;
                            int _10828;
                            if (_8731 == 0)
                            {
                                _10828 = 16;
                            }
                            else
                            {
                                _10828 = (_8731 == 1) ? 48 : 96;
                            }
                            uint _8797_dummy_parameter;
                            _8765 = min(_10826, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10314 + ((cbFI_MvDepthLaneSizeRcp * float(_10828)) * float2(cos(_8729), sin(_8729))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8797_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10827 = _10826;
                    }
                    else
                    {
                        _10827 = 0.0f;
                    }
                    _10831 = _10827;
                }
                float _10832;
                if (_4977)
                {
                    uint _8829_dummy_parameter;
                    _10832 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8829_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10832 = 0.0f;
                }
                float _10833;
                if (_4980)
                {
                    uint _8849_dummy_parameter;
                    _10833 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8849_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10833 = 0.0f;
                }
                bool _5097;
                if (_4977)
                {
                    _5097 = _10832 > ((exp((_10824 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5097 = _4977;
                }
                float4 _10849;
                if (_5097)
                {
                    float4 _10193 = _10841;
                    _10193.x = 0.0f;
                    _10849 = _10193;
                }
                else
                {
                    _10849 = _10841;
                }
                bool _5109;
                if (_4980)
                {
                    _5109 = _10833 > ((exp((_10831 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5109 = _4980;
                }
                float4 _10851;
                if (_5109)
                {
                    float4 _10195 = _10849;
                    _10195.y = 0.0f;
                    _10851 = _10195;
                }
                else
                {
                    _10851 = _10849;
                }
                float4 _10914;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5042)
                {
                    bool _5129;
                    if (_4977)
                    {
                        _5129 = _10832 < ((exp((_10824 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5129 = _4977;
                    }
                    float4 _10853;
                    if (_5129)
                    {
                        float4 _10197 = _10851;
                        _10197.x = 0.0f;
                        _10853 = _10197;
                    }
                    else
                    {
                        _10853 = _10851;
                    }
                    bool _5141;
                    if (_4980)
                    {
                        _5141 = _10833 < ((exp((_10831 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5141 = _4980;
                    }
                    float4 _10915;
                    if (_5141)
                    {
                        float4 _10199 = _10853;
                        _10199.y = 0.0f;
                        _10915 = _10199;
                    }
                    else
                    {
                        _10915 = _10853;
                    }
                    _10914 = _10915;
                }
                else
                {
                    _10914 = _10851;
                }
                _11473 = float3(_10804, log(((r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8473_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8505_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10913 = _10914;
            }
            else
            {
                _11473 = float3(0.0f, 0.0f, 0.5f);
                _10913 = _10808;
            }
            bool _5152 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4901;
            bool _5158;
            if (_5152)
            {
                _5158 = _4955 || _4961;
            }
            else
            {
                _5158 = _5152;
            }
            float4 _10936;
            if (_5158)
            {
                float _10908;
                do
                {
                    uint4 _9029 = r_warped_motion_qdata_tp1.Load(int3(_10342, 0));
                    uint _9030 = _9029.x;
                    if (_9030 != 0u)
                    {
                        float _10907;
                        if (_9030 == 0u)
                        {
                            _10907 = -1.0f;
                        }
                        else
                        {
                            _10907 = float((_9030 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10908 = _10907;
                        break;
                    }
                    int _10890;
                    uint _10891;
                    _10891 = _9030;
                    _10890 = -1;
                    uint _10906;
                    for (; _10890 <= 1; _10891 = _10906, _10890++)
                    {
                        _10906 = _10891;
                        for (int _10904 = -1; _10904 <= 1; )
                        {
                            _10906 = max(_10906, r_warped_motion_qdata_tp1.Load(int3(clamp(_10342 + int2(_10904, _10890), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10904++;
                            continue;
                        }
                    }
                    if (_10891 != 0u)
                    {
                        float _10903;
                        if (_10891 == 0u)
                        {
                            _10903 = -1.0f;
                        }
                        else
                        {
                            _10903 = float((_10891 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10908 = _10903;
                        break;
                    }
                    uint _10893;
                    _10893 = 4294967295u;
                    uint _12319;
                    for (int _10892 = 0; _10892 < 8; _10893 = _12319, _10892++)
                    {
                        int _10896 = 0;
                        for (;;)
                        {
                            if (_10896 < 5)
                            {
                                int2 _8980 = _10342 + (_1093[_10892] * _1102[_10896].xx);
                                bool _8983 = any(bool2(_8980.x < int2(0, 0).x, _8980.y < int2(0, 0).y));
                                bool _8991;
                                if (!_8983)
                                {
                                    _8991 = any(bool2(_8980.x >= cbFI_MvDepthLaneSize.x, _8980.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8991 = _8983;
                                }
                                if (_8991)
                                {
                                    _12319 = _10893;
                                    break;
                                }
                                uint4 _9069 = r_warped_motion_qdata_tp1.Load(int3(_8980, 0));
                                uint _9070 = _9069.x;
                                if (_9070 != 0u)
                                {
                                    _12319 = min(_10893, _9070);
                                    break;
                                }
                                _10896++;
                                continue;
                            }
                            else
                            {
                                _12319 = _10893;
                                break;
                            }
                        }
                    }
                    float _10895;
                    if (_10893 == 4294967295u)
                    {
                        _10895 = -1.0f;
                    }
                    else
                    {
                        float _10894;
                        if (_10893 == 0u)
                        {
                            _10894 = -1.0f;
                        }
                        else
                        {
                            _10894 = float((_10893 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10895 = _10894;
                    }
                    _10908 = _10895;
                    break;
                } while(false);
                float4 _10937;
                if (_10908 >= 0.0f)
                {
                    float _9091 = (exp((_10908 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5177;
                    if (_4955)
                    {
                        uint _9098_dummy_parameter;
                        _5177 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9098_dummy_parameter))))), 0)).x) > _9091;
                    }
                    else
                    {
                        _5177 = _4955;
                    }
                    float4 _10926;
                    if (_5177)
                    {
                        float4 _10201 = _10913;
                        _10201.z = 0.0f;
                        _10926 = _10201;
                    }
                    else
                    {
                        _10926 = _10913;
                    }
                    bool _5189;
                    if (_4961)
                    {
                        uint _9118_dummy_parameter;
                        _5189 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9118_dummy_parameter))))), 0)).x) > _9091;
                    }
                    else
                    {
                        _5189 = _4961;
                    }
                    float4 _10938;
                    if (_5189)
                    {
                        float4 _10203 = _10926;
                        _10203.w = 0.0f;
                        _10938 = _10203;
                    }
                    else
                    {
                        _10938 = _10926;
                    }
                    _10937 = _10938;
                }
                else
                {
                    _10937 = _10913;
                }
                _10936 = _10937;
            }
            else
            {
                _10936 = _10913;
            }
            bool _5197 = _4943 != _4949;
            bool _5204;
            if (_5197)
            {
                _5204 = _4943 ? _4889 : _4892;
            }
            else
            {
                _5204 = _5197;
            }
            bool _5211;
            if (_5204)
            {
                _5211 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5211 = _5204;
            }
            float4 _11021;
            if (_5211)
            {
                bool2 _5216 = _4943.xx;
                float2 _5217 = float2(_5216.x ? _10312.x : _10314.x, _5216.y ? _10312.y : _10314.y);
                float _10928;
                if (_4943)
                {
                    uint _9138_dummy_parameter;
                    _10928 = r_depth_tm1.Load(int3(int2(floor(_5217 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9138_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9154_dummy_parameter;
                    _10928 = r_depth_tp1.Load(int3(int2(floor(_5217 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9154_dummy_parameter))))), 0)).x;
                }
                float4x4 _10929;
                if (_4943)
                {
                    _10929 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10929 = cbFI_MotionTP1ToTM1;
                }
                float2 _10930;
                do
                {
                    float _9181 = _5217.x;
                    float _9184 = 1.0f - _5217.y;
                    float4 _9195 = mul(float4((float2(_9181, _9184) * 2.0f) - 1.0f.xx, _10928, 1.0f), _10929);
                    float _9197 = _9195.w;
                    if (!(_9197 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10930 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9210 = ((_9195.xy / _9197.xx) + 1.0f.xx) * 0.5f;
                    _10930 = float2(_9210.x - _9181, _9184 - _9210.y);
                    break;
                } while(false);
                float2 _5247 = float2(cbFI_DisplaySize);
                float4 _11022;
                if (!(length(((_5217 + _10930) - float2(_5216.x ? _10314.x : _10312.x, _5216.y ? _10314.y : _10312.y)) * _5247) <= ((0.100000001490116119384765625f * length(_10930 * _5247)) + 8.0f)))
                {
                    float4 _11023;
                    if (_4943)
                    {
                        float4 _10213 = _10936;
                        _10213.x = 0.0f;
                        _11023 = _10213;
                    }
                    else
                    {
                        float4 _10215 = _10936;
                        _10215.y = 0.0f;
                        _11023 = _10215;
                    }
                    _11022 = _11023;
                }
                else
                {
                    _11022 = _10936;
                }
                _11021 = _11022;
            }
            else
            {
                _11021 = _10936;
            }
            float4 _5272 = _10684 * _11021;
            float _5274 = dot(_5272, 1.0f.xxxx);
            float4 _11251;
            bool _11271;
            if (_5274 > 0.0f)
            {
                _11271 = _10465;
                _11251 = _5272 / _5274.xxxx;
            }
            else
            {
                bool _5285 = any(bool4(_11021.x < 1.0f.xxxx.x, _11021.y < 1.0f.xxxx.y, _11021.z < 1.0f.xxxx.z, _11021.w < 1.0f.xxxx.w));
                if (_5285)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9232;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9232);
                    }
                }
                bool4 _12351 = _5285.xxxx;
                _11271 = _5285 ? true : _10465;
                _11251 = float4(_12351.x ? 0.0f.xxxx.x : _10684.x, _12351.y ? 0.0f.xxxx.y : _10684.y, _12351.z ? 0.0f.xxxx.z : _10684.z, _12351.w ? 0.0f.xxxx.w : _10684.w);
            }
            _11384 = _11473;
            _11270 = _11271;
            _11250 = _11251;
        }
        else
        {
            _11384 = float3(0.0f, 0.0f, 0.5f);
            _11270 = _10465;
            _11250 = _10684;
        }
        uint _5294 = (cbFI_pad0 >> 24u) & 31u;
        uint _5298 = (cbFI_pad0 >> 16u) & 255u;
        bool _5300 = _5294 != 0u;
        bool _5302 = _5298 == 12u;
        bool _5305 = _5298 == 13u;
        float4 _11267;
        if ((_5300 || _5302) || _5305)
        {
            float _11024;
            do
            {
                bool _9316 = all(bool2(_10315.x > 0.0f.xx.x, _10315.y > 0.0f.xx.y));
                bool _9322;
                if (_9316)
                {
                    _9322 = all(bool2(_10315.x < 1.0f.xx.x, _10315.y < 1.0f.xx.y));
                }
                else
                {
                    _9322 = _9316;
                }
                bool _9253 = !_9322;
                bool _9260;
                if (!_9253)
                {
                    bool _9327 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
                    bool _9333;
                    if (_9327)
                    {
                        _9333 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9333 = _9327;
                    }
                    _9260 = !_9333;
                }
                else
                {
                    _9260 = _9253;
                }
                if (_9260)
                {
                    _11024 = 0.0f;
                    break;
                }
                uint _9340_dummy_parameter;
                uint _9356_dummy_parameter;
                float4 _9281 = mul(float4((float2(_10315.x, 1.0f - _10315.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10315 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9340_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9283 = _9281.w;
                if (abs(_9283) < 9.9999999747524270787835121154785e-07f)
                {
                    _11024 = 0.0f;
                    break;
                }
                float _9294 = abs(cbFI_DeviceToViewDepth.y / ((_9281.z / _9283) - cbFI_DeviceToViewDepth.x));
                float _9297 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9356_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11024 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9294 - _9297) / max(max(_9294, _9297), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9404 = all(bool2(_10316.x > 0.0f.xx.x, _10316.y > 0.0f.xx.y));
            bool _9410;
            if (_9404)
            {
                _9410 = all(bool2(_10316.x < 1.0f.xx.x, _10316.y < 1.0f.xx.y));
            }
            else
            {
                _9410 = _9404;
            }
            float _11025;
            if (_9410)
            {
                uint _9417_dummy_parameter;
                _11025 = length((_6105 + (r_motion_tp1.Load(int3(int2(floor(_10316 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9417_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11025 = 1000000.0f;
            }
            float _11036;
            if ((_5294 & 1u) != 0u)
            {
                _11036 = _11024;
            }
            else
            {
                _11036 = 1.0f;
            }
            float _11037;
            if ((_5294 & 2u) != 0u)
            {
                _11037 = _11036 * (1.0f - smoothstep(2.0f, 8.0f, _11025));
            }
            else
            {
                _11037 = _11036;
            }
            float _11038;
            if ((_5294 & 4u) != 0u)
            {
                _11038 = _11037 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6826 - _6834) - length(_6810 - _6818))));
            }
            else
            {
                _11038 = _11037;
            }
            float _11261;
            if ((_5294 & 8u) != 0u)
            {
                _11261 = lerp(1.0f, _11038, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6810 - _6818)));
            }
            else
            {
                _11261 = _11038;
            }
            bool _5380 = (_5294 & 16u) != 0u;
            bool _5389;
            if (_5380)
            {
                _5389 = length(_10310 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5389 = _5380;
            }
            float _12353 = _5389 ? 1.0f : _11261;
            bool _5395 = _5300 && _7019;
            bool _5400;
            if (_5395)
            {
                bool _9442 = all(bool2(_10312.x > 0.0f.xx.x, _10312.y > 0.0f.xx.y));
                bool _9448;
                if (_9442)
                {
                    _9448 = all(bool2(_10312.x < 1.0f.xx.x, _10312.y < 1.0f.xx.y));
                }
                else
                {
                    _9448 = _9442;
                }
                _5400 = _9448;
            }
            else
            {
                _5400 = _5395;
            }
            bool _5405;
            if (_5400)
            {
                bool _9453 = all(bool2(_10314.x > 0.0f.xx.x, _10314.y > 0.0f.xx.y));
                bool _9459;
                if (_9453)
                {
                    _9459 = all(bool2(_10314.x < 1.0f.xx.x, _10314.y < 1.0f.xx.y));
                }
                else
                {
                    _9459 = _9453;
                }
                _5405 = _9459;
            }
            else
            {
                _5405 = _5400;
            }
            float4 _11268;
            if (_5405)
            {
                float _5411 = _11250.x + _11250.y;
                float _5420 = (_11250.z + _11250.w) * (1.0f - _12353);
                float _11264;
                if (_5411 > 9.9999997473787516355514526367188e-06f)
                {
                    _11264 = _11250.x / _5411;
                }
                else
                {
                    _11264 = _4322;
                }
                _11268 = float4(_11250.x + (_5420 * _11264), _11250.y + (_5420 * (1.0f - _11264)), _11250.zw * _12353);
            }
            else
            {
                _11268 = _11250;
            }
            _11267 = _11268;
        }
        else
        {
            _11267 = _11250;
        }
        float3 _12121;
        if (_11270)
        {
            float3 _9465 = r_current_interpolation_source.Load(int3(_3689, 0)).xyz;
            float3 _12122;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7019)
            {
                uint _9472_dummy_parameter;
                float _11375;
                _11375 = r_depth_tm1.Load(int3(int2(floor(_10312 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9472_dummy_parameter))))), 0)).x;
                float _5532;
                for (int _11374 = 0; _11374 < 24; _11375 = _5532, _11374++)
                {
                    float _5504 = float(_11374 & 7) * 0.785398185253143310546875f;
                    int _5506 = _11374 >> 3;
                    int _12172;
                    if (_5506 == 0)
                    {
                        _12172 = 16;
                    }
                    else
                    {
                        _12172 = (_5506 == 1) ? 48 : 96;
                    }
                    uint _9492_dummy_parameter;
                    _5532 = max(_11375, r_depth_tm1.Load(int3(int2(floor(clamp(_10312 + ((cbFI_MvDepthLaneSizeRcp * float(_12172)) * float2(cos(_5504), sin(_5504))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9492_dummy_parameter))))), 0)).x);
                }
                float2 _11376;
                do
                {
                    float _9514 = 1.0f - _10312.y;
                    float4 _9525 = mul(float4((float2(_10312.x, _9514) * 2.0f) - 1.0f.xx, _11375, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9527 = _9525.w;
                    if (!(_9527 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11376 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9540 = ((_9525.xy / _9527.xx) + 1.0f.xx) * 0.5f;
                    _11376 = float2(_9540.x - _10312.x, _9514 - _9540.y);
                    break;
                } while(false);
                float2 _5543 = _10312 + _11376;
                bool _9558 = all(bool2(_5543.x > 0.0f.xx.x, _5543.y > 0.0f.xx.y));
                bool _9564;
                if (_9558)
                {
                    _9564 = all(bool2(_5543.x < 1.0f.xx.x, _5543.y < 1.0f.xx.y));
                }
                else
                {
                    _9564 = _9558;
                }
                float3 _12123;
                if (_9564)
                {
                    float _5549 = abs(cbFI_DeviceToViewDepth.y / (_11375 - cbFI_DeviceToViewDepth.x));
                    uint _9584_dummy_parameter;
                    int2 _9584 = int2(spvTextureSize(r_depth_m2, uint(0), _9584_dummy_parameter));
                    float _5553 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5543 * float2(_9584))), int2(0, 0), _9584 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12128;
                    if (abs(_5553 - _5549) <= (0.20000000298023223876953125f * max(_5553, _5549)))
                    {
                        uint _9618_dummy_parameter;
                        int2 _9618 = int2(spvTextureSize(r_colour_m2, uint(0), _9618_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9641;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9641);
                        }
                        _12128 = r_colour_m2.Load(int3(clamp(int2(floor(_5543 * float2(_9618))), int2(0, 0), _9618 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9651;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9651);
                        }
                        _12128 = _9465;
                    }
                    _12123 = _12128;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9661;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9661);
                    }
                    _12123 = _9465;
                }
                _12122 = _12123;
            }
            else
            {
                _12122 = _9465;
            }
            _12121 = _12122;
        }
        else
        {
            _12121 = (((_6810 * _11267.x) + (_6818 * _11267.y)) + (_6826 * _11267.z)) + (_6834 * _11267.w);
        }
        uint _5581 = cbFI_pad0 & 255u;
        bool _12013;
        float3 _12120;
        if (_5581 != 0u)
        {
            float3 _5586 = r_present_backbuffer.Load(int3(_3689, 0)).xyz;
            float3 _5590 = r_current_interpolation_source.Load(int3(_3689, 0)).xyz;
            float3 _5594 = abs(_5586 - _5590);
            float3 _11379;
            if (_5581 == 2u)
            {
                _11379 = (abs(_5590) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11379 = 0.000244140625f.xxx;
            }
            bool _5610 = any(bool3(_5594.x > _11379.x, _5594.y > _11379.y, _5594.z > _11379.z));
            bool3 _12354 = _5610.xxx;
            _12120 = float3(_12354.x ? _5586.x : _12121.x, _12354.y ? _5586.y : _12121.y, _12354.z ? _5586.z : _12121.z);
            _12013 = _5610;
        }
        else
        {
            _12120 = _12121;
            _12013 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9676;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9676);
        }
        float3 _12103;
        if (_5298 == 1u)
        {
            _12103 = lerp(_6810, _6818, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12104;
            if (_5298 == 2u)
            {
                _12104 = lerp(_6826, _6834, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12105;
                if (_5298 == 3u)
                {
                    _12105 = float(_12013).xxx;
                }
                else
                {
                    float3 _12106;
                    if (_5298 == 4u)
                    {
                        _12106 = float3(((_10310 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12107;
                        if (_5298 == 5u)
                        {
                            _12107 = float3(((_6105 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12108;
                            if (_5298 == 6u)
                            {
                                _12108 = float3(_11267.xy, _11267.z + _11267.w);
                            }
                            else
                            {
                                float3 _12109;
                                if (_5298 == 7u)
                                {
                                    _12109 = r_current_interpolation_source.Load(int3(_3689, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12110;
                                    if (_5298 == 8u)
                                    {
                                        _12110 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4097, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12111;
                                        if (_5302)
                                        {
                                            uint _9698_dummy_parameter;
                                            uint _9730_dummy_parameter;
                                            _12111 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4097 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9698_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4097 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9730_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12112;
                                            if (_5305)
                                            {
                                                _12112 = _6826;
                                            }
                                            else
                                            {
                                                float3 _12113;
                                                if (_5298 == 20u)
                                                {
                                                    _12113 = _6810;
                                                }
                                                else
                                                {
                                                    float3 _12114;
                                                    if (_5298 == 21u)
                                                    {
                                                        _12114 = _6818;
                                                    }
                                                    else
                                                    {
                                                        float3 _12115;
                                                        if (_5298 == 22u)
                                                        {
                                                            _12115 = _6834;
                                                        }
                                                        else
                                                        {
                                                            float3 _12116;
                                                            if (_5298 == 18u)
                                                            {
                                                                _12116 = _11771;
                                                            }
                                                            else
                                                            {
                                                                float3 _12117;
                                                                if (_5298 == 19u)
                                                                {
                                                                    _12117 = _11575;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12356 = (_5298 == 23u).xxx;
                                                                    _12117 = float3(_12356.x ? _11384.x : _12120.x, _12356.y ? _11384.y : _12120.y, _12356.z ? _11384.z : _12120.z);
                                                                }
                                                                _12116 = _12117;
                                                            }
                                                            _12115 = _12116;
                                                        }
                                                        _12114 = _12115;
                                                    }
                                                    _12113 = _12114;
                                                }
                                                _12112 = _12113;
                                            }
                                            _12111 = _12112;
                                        }
                                        _12110 = _12111;
                                    }
                                    _12109 = _12110;
                                }
                                _12108 = _12109;
                            }
                            _12107 = _12108;
                        }
                        _12106 = _12107;
                    }
                    _12105 = _12106;
                }
                _12104 = _12105;
            }
            _12103 = _12104;
        }
        float3 _12102;
        if ((_5298 >= 9u) && (_5298 <= 11u))
        {
            uint _5774 = 64u + uint((_10342.y * cbFI_MvDepthLaneSize.x) + _10342.x);
            uint _5778 = rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) & 15u;
            float3 _12133;
            if (_5298 == 10u)
            {
                float3 _12101;
                if ((rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) & 32u) != 0u)
                {
                    _12101 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12100;
                    if ((rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) & 16u) != 0u)
                    {
                        _12100 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5799 = ((rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) & 64u) != 0u).xxx;
                        _12100 = float3(_5799.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5799.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5799.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12101 = _12100;
                }
                _12133 = _12101;
            }
            else
            {
                float3 _12134;
                if (_5298 == 11u)
                {
                    uint _5812 = (rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) >> 8u) & 15u;
                    uint _5815 = (rw_nfru_diagnostics.Load<uint>(_5774 * 4 + 0) >> 12u) & 15u;
                    float3 _12093;
                    if ((_5778 == 2u) || (_5778 == 3u))
                    {
                        _12093 = _3385[_5778];
                    }
                    else
                    {
                        bool _5827 = _5812 == 3u;
                        bool _5829 = _5815 == 3u;
                        float3 _12094;
                        if (_5827 && _5829)
                        {
                            _12094 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12095;
                            if (_5827)
                            {
                                _12095 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12096;
                                if (_5829)
                                {
                                    _12096 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12097;
                                    if ((_5812 == 4u) || (_5815 == 4u))
                                    {
                                        _12097 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12098;
                                        if ((_5812 == 1u) || (_5815 == 1u))
                                        {
                                            _12098 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12358 = (_5778 == 1u).xxx;
                                            _12098 = float3(_12358.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12358.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12358.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12097 = _12098;
                                    }
                                    _12096 = _12097;
                                }
                                _12095 = _12096;
                            }
                            _12094 = _12095;
                        }
                        _12093 = _12094;
                    }
                    _12134 = _12093;
                }
                else
                {
                    _12134 = _3385[min(_5778, 7u)];
                }
                _12133 = _12134;
            }
            _12102 = _12133;
        }
        else
        {
            _12102 = _12103;
        }
        float4 _12137;
        if ((_5298 >= 14u) && (_5298 <= 16u))
        {
            float2 _12135;
            if (_5298 == 14u)
            {
                uint _5885_dummy_parameter;
                uint _5891_dummy_parameter;
                _12135 = r_flow_tm1.Load(int3(clamp(int2(floor(_4097 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5885_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5891_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12136;
                if (_5298 == 16u)
                {
                    uint _9781 = r_warped_flow_qdata_tm1.Load(int3(_4113, 0)).x & 2147483647u;
                    uint _9813 = uint(max((int((_9781 >> 16u) & 15u) - 6), 0));
                    _12136 = ((float2(float((1 - (2 * int((_9781 >> 15u) & 1u))) * int(((_9781 >> uint(7)) & 127u) << _9813)), float((1 - (2 * int((_9781 >> 14u) & 1u))) * int((_9781 & 127u) << _9813))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12136 = _6105 * float2(cbFI_DisplaySize);
                }
                _12135 = _12136;
            }
            uint2 _5924 = uint2(clamp(round(_12135 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5926 = _5924.x;
            uint _5933 = _5924.y;
            _12137 = float4(float(_5926 & 255u), float((_5926 >> 8u) | ((_5933 & 15u) << 4u)), float(_5933 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12138;
            if (_5298 == 17u)
            {
                _12138 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4113, 0)).x != 0u), _4456, 0.0f, 1.0f);
            }
            else
            {
                _12138 = float4(_12102, 1.0f);
            }
            _12137 = _12138;
        }
        rw_output[_3689] = _12137.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5977 = ((uint(_3689.y) * uint(cbFI_DisplaySize.x)) + uint(_3689.x)) * 6u;
            uint _9859 = spvPackHalf2x16(clamp(_6809.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5977 * 4 + 0, (((_9859 & 32767u) >> 4u) | ((((_9859 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6809.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9894 = spvPackHalf2x16(clamp(_6817.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5977 + 1u) * 4 + 0, (((_9894 & 32767u) >> 4u) | ((((_9894 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6817.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9929 = spvPackHalf2x16(clamp(_6825.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5977 + 2u) * 4 + 0, (((_9929 & 32767u) >> 4u) | ((((_9929 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6825.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9964 = spvPackHalf2x16(clamp(_6833.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5977 + 3u) * 4 + 0, (((_9964 & 32767u) >> 4u) | ((((_9964 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6833.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9991 = r_current_interpolation_source.Load(int3(_3689, 0));
            uint _10005 = spvPackHalf2x16(clamp(_9991.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5977 + 4u) * 4 + 0, (((_10005 & 32767u) >> 4u) | ((((_10005 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9991.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12171;
            if (_12013 || (_5298 != 0u))
            {
                _12171 = 4294967295u;
            }
            else
            {
                uint _10040 = spvPackHalf2x16(clamp(_12137.xy, 0.0f.xx, 65000.0f.xx));
                _12171 = (((_10040 & 32767u) >> 4u) | ((((_10040 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12137.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5977 + 5u) * 4 + 0, _12171);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3689] = float4(r_current_interpolation_source.Load(int3(_3689, 0)).xyz, 1.0f).xyz;
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
