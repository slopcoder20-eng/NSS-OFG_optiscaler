static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3366[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3653 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3653.x >= cbFI_DisplaySize.x, _3653.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3653] = float4(r_present_backbuffer.Load(int3(_3653, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4048 = (float2(_3653) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4059 = int2(floor(_4048 * float2(cbFI_MvDepthLaneSize)));
        int2 _4064 = int2(floor(_4048 * float2(cbFI_FlowLaneSize)));
        float4 _6026 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4048 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6032 = r_warped_filled_flow_tm1.Load(int3(_4064, 0)).xy;
        float2 _6038 = r_warped_filled_motion_tp1.Load(int3(_4059, 0)).xy;
        bool _6060 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10206;
        if (_6060)
        {
            float _6073 = ((2.0f * _4048.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10206 = float2(atan(_6073) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4048.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6073 * _6073))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10206 = _4048;
        }
        bool _4085 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10227;
        bool _10248;
        int2 _10259;
        float3 _11688;
        if (_4085)
        {
            float _10208;
            float _10210;
            _10210 = 2.0f;
            _10208 = -1.0f;
            uint _3715[9];
            float _12130;
            float _12133;
            for (int _10207 = 0; _10207 < 9; _10210 = _12133, _10208 = _12130, _10207++)
            {
                _3715[_10207] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4059 + int2((_10207 % 3) - 1, (_10207 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3715[_10207] != 0u)
                {
                    float _12125;
                    if (_3715[_10207] == 0u)
                    {
                        _12125 = -1.0f;
                    }
                    else
                    {
                        _12125 = float((_3715[_10207] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12133 = min(_10210, _12125);
                    _12130 = max(_10208, _12125);
                }
                else
                {
                    _12133 = _10210;
                    _12130 = _10208;
                }
            }
            float _4131 = float(_10208 >= 0.0f);
            float3 _9999 = 0.0f.xxx;
            _9999.y = _4131;
            float2 _10228;
            bool _10249;
            int2 _10260;
            float3 _11689;
            if ((_10208 - _10210) > 0.0199999995529651641845703125f)
            {
                float _10216;
                int2 _10217;
                float2 _10218;
                int2 _10220;
                float2 _10226;
                _10226 = _6038;
                _10220 = _4059;
                _10218 = _6038;
                _10217 = _4059;
                _10216 = -1.0f;
                float _12138;
                int2 _12142;
                float2 _12153;
                int2 _12164;
                float2 _12197;
                float _12244;
                int _10215 = 0;
                float _12106 = 1000000000.0f;
                for (; _10215 < 9; _12106 = _12244, _10226 = _12197, _10220 = _12164, _10218 = _12153, _10217 = _12142, _10216 = _12138, _10215++)
                {
                    if (_3715[_10215] == 0u)
                    {
                        _12244 = _12106;
                        _12197 = _10226;
                        _12164 = _10220;
                        _12153 = _10218;
                        _12142 = _10217;
                        _12138 = _10216;
                        continue;
                    }
                    int2 _4166 = clamp(_4059 + int2((_10215 % 3) - 1, (_10215 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6148 = _3715[_10215] & 2147483647u;
                    uint _6180 = uint(max((int((_6148 >> 16u) & 15u) - 6), 0));
                    float2 _4172 = (float2(float((1 - (2 * int((_6148 >> 15u) & 1u))) * int(((_6148 >> uint(7)) & 127u) << _6180)), float((1 - (2 * int((_6148 >> 14u) & 1u))) * int((_6148 & 127u) << _6180))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12092;
                    if (_3715[_10215] == 0u)
                    {
                        _12092 = -1.0f;
                    }
                    else
                    {
                        _12092 = float((_3715[_10215] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4177 = _12092 - 0.100000001490116119384765625f;
                    float2 _12093;
                    if (_6060)
                    {
                        float2 _6257 = clamp((((_10206 + (_4172 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6260 = tan(_6257.x);
                        _12093 = (float2(_6260 / cbFI_DeviceToViewDepth.z, (tan(_6257.y) * sqrt(1.0f + (_6260 * _6260))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12093 = _10206 + (_4172 * cbFI_Timestep);
                    }
                    float _4184 = cbFI_Timestep - 1.0f;
                    float2 _12094;
                    if (_6060)
                    {
                        float2 _6328 = clamp((((_10206 + (_4172 * _4184)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6331 = tan(_6328.x);
                        _12094 = (float2(_6331 / cbFI_DeviceToViewDepth.z, (tan(_6328.y) * sqrt(1.0f + (_6331 * _6331))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12094 = _10206 + (_4172 * _4184);
                    }
                    bool _6364 = all(bool2(_12093.x > 0.0f.xx.x, _12093.y > 0.0f.xx.y));
                    bool _6370;
                    if (_6364)
                    {
                        _6370 = all(bool2(_12093.x < 1.0f.xx.x, _12093.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6370 = _6364;
                    }
                    float _12097;
                    if (_6370)
                    {
                        uint _6377_dummy_parameter;
                        _12097 = max((_4177 - (log(((r_depth_tm1.Load(int3(int2(floor(_12093 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6377_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12097 = 0.0f;
                    }
                    bool _6407 = all(bool2(_12094.x > 0.0f.xx.x, _12094.y > 0.0f.xx.y));
                    bool _6413;
                    if (_6407)
                    {
                        _6413 = all(bool2(_12094.x < 1.0f.xx.x, _12094.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6413 = _6407;
                    }
                    float _12098;
                    if (_6413)
                    {
                        uint _6420_dummy_parameter;
                        _12098 = _12097 + max((_4177 - (log(((r_depth_tp1.Load(int3(int2(floor(_12094 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6420_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12098 = _12097;
                    }
                    float _12139;
                    int2 _12143;
                    float2 _12154;
                    int2 _12165;
                    float2 _12198;
                    float _12245;
                    if (_12098 == 0.0f)
                    {
                        bool _4219 = _4177 > _10216;
                        bool2 _12253 = _4219.xx;
                        _12245 = _12106;
                        _12198 = float2(_12253.x ? _4172.x : _10226.x, _12253.y ? _4172.y : _10226.y);
                        _12165 = int2(_12253.x ? _4166.x : _10220.x, _12253.y ? _4166.y : _10220.y);
                        _12154 = _10218;
                        _12143 = _10217;
                        _12139 = _4219 ? _4177 : _10216;
                    }
                    else
                    {
                        bool _4228 = _12098 < _12106;
                        bool2 _12249 = _4228.xx;
                        _12245 = _4228 ? _12098 : _12106;
                        _12198 = _10226;
                        _12165 = _10220;
                        _12154 = float2(_12249.x ? _4172.x : _10218.x, _12249.y ? _4172.y : _10218.y);
                        _12143 = int2(_12249.x ? _4166.x : _10217.x, _12249.y ? _4166.y : _10217.y);
                        _12139 = _10216;
                    }
                    _12244 = _12245;
                    _12197 = _12198;
                    _12164 = _12165;
                    _12153 = _12154;
                    _12142 = _12143;
                    _12138 = _12139;
                }
                bool _4240 = _10216 < 0.0f;
                bool2 _12259 = _4240.xx;
                int2 _12262 = int2(_12259.x ? _10217.x : _10220.x, _12259.y ? _10217.y : _10220.y);
                _11689 = float3(1.0f, _4131, float(any(bool2(_12262.x != _4059.x, _12262.y != _4059.y))));
                _10260 = _12262;
                _10249 = _4240 ? false : true;
                _10228 = float2(_12259.x ? _10218.x : _10226.x, _12259.y ? _10218.y : _10226.y);
            }
            else
            {
                _11689 = _9999;
                _10260 = _4059;
                _10249 = false;
                _10228 = _6038;
            }
            _11688 = _11689;
            _10259 = _10260;
            _10248 = _10249;
            _10227 = _10228;
        }
        else
        {
            _11688 = 0.0f.xxx;
            _10259 = _4059;
            _10248 = false;
            _10227 = _6038;
        }
        float2 _10229;
        if (_6060)
        {
            float2 _6485 = clamp((((_10206 + (_10227 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6488 = tan(_6485.x);
            _10229 = (float2(_6488 / cbFI_DeviceToViewDepth.z, (tan(_6485.y) * sqrt(1.0f + (_6488 * _6488))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10229 = _10206 + (_10227 * cbFI_Timestep);
        }
        float _4263 = cbFI_Timestep - 1.0f;
        float2 _10231;
        if (_6060)
        {
            float2 _6556 = clamp((((_10206 + (_10227 * _4263)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6559 = tan(_6556.x);
            _10231 = (float2(_6559 / cbFI_DeviceToViewDepth.z, (tan(_6556.y) * sqrt(1.0f + (_6559 * _6559))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10231 = _10206 + (_10227 * _4263);
        }
        float _4268 = -cbFI_Timestep;
        float2 _10232;
        if (_6060)
        {
            float2 _6627 = clamp((((_10206 + (_6032 * _4268)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6630 = tan(_6627.x);
            _10232 = (float2(_6630 / cbFI_DeviceToViewDepth.z, (tan(_6627.y) * sqrt(1.0f + (_6630 * _6630))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10232 = _10206 + (_6032 * _4268);
        }
        float _4273 = 1.0f - cbFI_Timestep;
        float2 _10233;
        if (_6060)
        {
            float2 _6698 = clamp((((_10206 + (_6032 * _4273)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6701 = tan(_6698.x);
            _10233 = (float2(_6701 / cbFI_DeviceToViewDepth.z, (tan(_6698.y) * sqrt(1.0f + (_6701 * _6701))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10233 = _10206 + (_6032 * _4273);
        }
        float4 _6736 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10229, 0.0f);
        float3 _6737 = _6736.xyz;
        float4 _6744 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10231, 0.0f);
        float3 _6745 = _6744.xyz;
        float4 _6752 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10232, 0.0f);
        float3 _6753 = _6752.xyz;
        float4 _6760 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10233, 0.0f);
        float3 _6761 = _6760.xyz;
        float4 _6775 = exp(_6026 - max(max(max(_6026.x, _6026.y), _6026.z), _6026.w).xxxx);
        float4 _6782 = _6775 / (dot(_6775, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4292 = _4085 && (!_10248);
        bool _4301;
        if (_4292)
        {
            _4301 = (_6782.z + _6782.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4301 = _4292;
        }
        bool _4312;
        if (_4301)
        {
            _4312 = length((_10232 - _10229) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4312 = _4301;
        }
        bool _10272;
        if (_4312)
        {
            uint4 _6801 = r_warped_motion_qdata_tp1.Load(int3(_10259, 0));
            uint _6802 = _6801.x;
            bool _10275;
            if (_6802 != 0u)
            {
                float _10261;
                if (_6802 == 0u)
                {
                    _10261 = -1.0f;
                }
                else
                {
                    _10261 = float((_6802 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4322 = _10261 - 0.12000000476837158203125f;
                bool _6821 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                bool _6827;
                if (_6821)
                {
                    _6827 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                }
                else
                {
                    _6827 = _6821;
                }
                bool _4332;
                if (_6827)
                {
                    uint _6834_dummy_parameter;
                    _4332 = (log(((r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6834_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4322;
                }
                else
                {
                    _4332 = _6827;
                }
                bool _4346;
                if (!_4332)
                {
                    bool _6864 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                    bool _6870;
                    if (_6864)
                    {
                        _6870 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6870 = _6864;
                    }
                    bool _4344;
                    if (_6870)
                    {
                        uint _6877_dummy_parameter;
                        _4344 = (log(((r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6877_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4322;
                    }
                    else
                    {
                        _4344 = _6870;
                    }
                    _4346 = _4344;
                }
                else
                {
                    _4346 = _4332;
                }
                _10275 = _4346;
            }
            else
            {
                _10275 = false;
            }
            _10272 = _10275;
        }
        else
        {
            _10272 = false;
        }
        bool _4351 = _10248 || _10272;
        bool _4356;
        if (_4351)
        {
            bool _6907 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
            bool _6913;
            if (_6907)
            {
                _6913 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
            }
            else
            {
                _6913 = _6907;
            }
            _4356 = _6913;
        }
        else
        {
            _4356 = _4351;
        }
        bool _4361;
        if (_4356)
        {
            bool _6918 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
            bool _6924;
            if (_6918)
            {
                _6924 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
            }
            else
            {
                _6924 = _6918;
            }
            _4361 = _6924;
        }
        else
        {
            _4361 = _4356;
        }
        float4 _10369;
        if (_4361)
        {
            float _4364 = _6782.x;
            float _4366 = _6782.y;
            float _4367 = _4364 + _4366;
            float _4372 = _6782.z + _6782.w;
            float _10290;
            if (_4367 > 0.001000000047497451305389404296875f)
            {
                _10290 = _4364 / _4367;
            }
            else
            {
                _10290 = _4273;
            }
            _10369 = float4(_4364 + (_4372 * _10290), _4366 + (_4372 * (1.0f - _10290)), 0.0f, 0.0f);
        }
        else
        {
            _10369 = _6782;
        }
        bool _6952 = (cbFI_pad0 & 1024u) != 0u;
        bool _6928 = !_6952;
        bool _6929 = !_6928;
        bool _6946;
        if (_6929)
        {
            _6946 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10259.y * cbFI_MvDepthLaneSize.x) + _10259.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6946 = _6928;
        }
        bool _6978;
        if (_6929)
        {
            _6978 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4064.y * cbFI_FlowLaneSize.x) + _4064.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6978 = _6928;
        }
        float _4407 = float(_6978);
        bool _10382;
        float4 _10413;
        float3 _11492;
        if (_6952)
        {
            bool _4417;
            if (_6946)
            {
                _4417 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
            }
            else
            {
                _4417 = _6946;
            }
            bool _4423;
            if (_4417)
            {
                _4423 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
            }
            else
            {
                _4423 = _4417;
            }
            bool _4430;
            if (_6946)
            {
                _4430 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
            }
            else
            {
                _4430 = _6946;
            }
            bool _4436;
            if (_4430)
            {
                _4436 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
            }
            else
            {
                _4436 = _4430;
            }
            bool _4443;
            if (_6978)
            {
                _4443 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
            }
            else
            {
                _4443 = _6978;
            }
            bool _4449;
            if (_4443)
            {
                _4449 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
            }
            else
            {
                _4449 = _4443;
            }
            bool _4456;
            if (_6978)
            {
                _4456 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
            }
            else
            {
                _4456 = _6978;
            }
            bool _4462;
            if (_4456)
            {
                _4462 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
            }
            else
            {
                _4462 = _4456;
            }
            bool _4464 = !_6946;
            if (_4464)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7020;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7020);
                }
            }
            bool _4469 = !_6978;
            if (_4469)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7030;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7030);
                }
            }
            if (_6946 && _4469)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7040;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7040);
                }
            }
            if (_4464 && _6978)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7050;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7050);
                }
            }
            float _4488 = float(_4423);
            float _4490 = float(_4436);
            bool _4493 = _4449 && _4462;
            float _10324;
            if (_4493)
            {
                _10324 = 1.0f;
            }
            else
            {
                _10324 = (_4449 || _4462) ? 0.5f : 0.0f;
            }
            bool _10329;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4423)) && (!_4436))
            {
                bool _4523;
                if (_4493)
                {
                    float _10327;
                    do
                    {
                        bool _7134 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                        bool _7140;
                        if (_7134)
                        {
                            _7140 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7140 = _7134;
                        }
                        bool _7071 = !_7140;
                        bool _7078;
                        if (!_7071)
                        {
                            bool _7145 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                            bool _7151;
                            if (_7145)
                            {
                                _7151 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7151 = _7145;
                            }
                            _7078 = !_7151;
                        }
                        else
                        {
                            _7078 = _7071;
                        }
                        if (_7078)
                        {
                            _10327 = 0.0f;
                            break;
                        }
                        uint _7158_dummy_parameter;
                        uint _7174_dummy_parameter;
                        float4 _7099 = mul(float4((float2(_10232.x, 1.0f - _10232.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7158_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7101 = _7099.w;
                        if (abs(_7101) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10327 = 0.0f;
                            break;
                        }
                        float _7112 = abs(cbFI_DeviceToViewDepth.y / ((_7099.z / _7101) - cbFI_DeviceToViewDepth.x));
                        float _7115 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7174_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10327 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7112 - _7115) / max(max(_7112, _7115), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4523 = _10327 >= 0.5f;
                }
                else
                {
                    _4523 = _4493;
                }
                bool _4531;
                if (_4523)
                {
                    _4531 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4531 = _4523;
                }
                bool _10330;
                if (_4531)
                {
                    uint _7224_dummy_parameter;
                    float2 _10328;
                    do
                    {
                        float _7250 = 1.0f - _10232.y;
                        float4 _7261 = mul(float4((float2(_10232.x, _7250) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7224_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7263 = _7261.w;
                        if (!(_7263 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10328 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7276 = ((_7261.xy / _7263.xx) + 1.0f.xx) * 0.5f;
                        _10328 = float2(_7276.x - _10232.x, _7250 - _7276.y);
                        break;
                    } while(false);
                    float2 _4544 = float2(cbFI_DisplaySize);
                    _10330 = length(((_10232 + _10328) - _10233) * _4544) <= ((0.100000001490116119384765625f * length(_10328 * _4544)) + 8.0f);
                }
                else
                {
                    _10330 = _4523;
                }
                _10329 = _10330;
            }
            else
            {
                _10329 = true;
            }
            bool _4558 = !_10329;
            bool _12263 = _4558 ? false : _4462;
            bool _12264 = _4558 ? false : _4449;
            bool _10383;
            float4 _10414;
            if (!(((_4423 && _4436) && _12264) && _12263))
            {
                float4 _4580 = _10369 * float4(_4488, _4490, float(_12264), float(_12263));
                float _4582 = dot(_4580, 1.0f.xxxx);
                bool _4585 = !(_4582 > 0.0f);
                float4 _10415;
                if (!_4585)
                {
                    _10415 = _4580 / _4582.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7298;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7298);
                    }
                    _10415 = 0.0f.xxxx;
                }
                _10414 = _10415;
                _10383 = _4585;
            }
            else
            {
                _10414 = _10369;
                _10383 = false;
            }
            _11492 = float3(_4488, _4490, _10324);
            _10413 = _10414;
            _10382 = _10383;
        }
        else
        {
            _11492 = float3(float(_6946), _4407, 0.0f);
            _10413 = _10369;
            _10382 = false;
        }
        bool _4603 = !_10382;
        float4 _10477;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4603)
        {
            float _4610 = _10413.x + _10413.y;
            float4 _10478;
            if (_4610 > 0.001000000047497451305389404296875f)
            {
                _10478 = float4(_10413.x / _4610, _10413.y / _4610, 0.0f, 0.0f);
            }
            else
            {
                _10478 = float4(_4273, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10477 = _10478;
        }
        else
        {
            _10477 = _10413;
        }
        float4 _10601;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4603) && _6946)
        {
            float _10472;
            do
            {
                uint4 _7438 = r_warped_motion_qdata_tp1.Load(int3(_10259, 0));
                uint _7439 = _7438.x;
                if (_7439 != 0u)
                {
                    float _10471;
                    if (_7439 == 0u)
                    {
                        _10471 = -1.0f;
                    }
                    else
                    {
                        _10471 = float((_7439 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10472 = _10471;
                    break;
                }
                int _10454;
                uint _10455;
                _10455 = _7439;
                _10454 = -1;
                uint _10470;
                for (; _10454 <= 1; _10455 = _10470, _10454++)
                {
                    _10470 = _10455;
                    for (int _10468 = -1; _10468 <= 1; )
                    {
                        _10470 = max(_10470, r_warped_motion_qdata_tp1.Load(int3(clamp(_10259 + int2(_10468, _10454), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10468++;
                        continue;
                    }
                }
                if (_10455 != 0u)
                {
                    float _10467;
                    if (_10455 == 0u)
                    {
                        _10467 = -1.0f;
                    }
                    else
                    {
                        _10467 = float((_10455 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10472 = _10467;
                    break;
                }
                uint _10457;
                _10457 = 4294967295u;
                uint _12234;
                for (int _10456 = 0; _10456 < 8; _10457 = _12234, _10456++)
                {
                    int _10460 = 0;
                    for (;;)
                    {
                        if (_10460 < 5)
                        {
                            int2 _7389 = _10259 + (_1085[_10456] * _1094[_10460].xx);
                            bool _7392 = any(bool2(_7389.x < int2(0, 0).x, _7389.y < int2(0, 0).y));
                            bool _7400;
                            if (!_7392)
                            {
                                _7400 = any(bool2(_7389.x >= cbFI_MvDepthLaneSize.x, _7389.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7400 = _7392;
                            }
                            if (_7400)
                            {
                                _12234 = _10457;
                                break;
                            }
                            uint4 _7478 = r_warped_motion_qdata_tp1.Load(int3(_7389, 0));
                            uint _7479 = _7478.x;
                            if (_7479 != 0u)
                            {
                                _12234 = min(_10457, _7479);
                                break;
                            }
                            _10460++;
                            continue;
                        }
                        else
                        {
                            _12234 = _10457;
                            break;
                        }
                    }
                }
                float _10459;
                if (_10457 == 4294967295u)
                {
                    _10459 = -1.0f;
                }
                else
                {
                    float _10458;
                    if (_10457 == 0u)
                    {
                        _10458 = -1.0f;
                    }
                    else
                    {
                        _10458 = float((_10457 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10459 = _10458;
                }
                _10472 = _10459;
                break;
            } while(false);
            float _4646 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4648 = _10472 < 0.0f;
            bool _4653;
            if (_4648)
            {
                bool _7498 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
                bool _7504;
                if (_7498)
                {
                    _7504 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
                }
                else
                {
                    _7504 = _7498;
                }
                _4653 = _7504;
            }
            else
            {
                _4653 = _4648;
            }
            bool _4658;
            if (_4653)
            {
                bool _7509 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
                bool _7515;
                if (_7509)
                {
                    _7515 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
                }
                else
                {
                    _7515 = _7509;
                }
                _4658 = _7515;
            }
            else
            {
                _4658 = _4653;
            }
            float4 _10534;
            if (_4658)
            {
                uint _7522_dummy_parameter;
                float _7546 = log(((r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7522_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7554_dummy_parameter;
                float _7578 = log(((r_depth_tp1.Load(int3(int2(floor(_10231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7554_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4669 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4676;
                if (_4669)
                {
                    _4676 = _7578 > (_7546 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4676 = _4669;
                }
                float4 _10508;
                if (_4676)
                {
                    _10508 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10508 = 1.0f.xxxx;
                }
                bool _4683 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4690;
                if (_4683)
                {
                    _4690 = _7546 > (_7578 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4690 = _4683;
                }
                float4 _10537;
                if (_4690)
                {
                    float4 _10069 = _10508;
                    _10069.x = 0.0f;
                    _10537 = _10069;
                }
                else
                {
                    _10537 = _10508;
                }
                _10534 = _10537;
            }
            else
            {
                bool _4698 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4704;
                if (_4698)
                {
                    _4704 = _10477.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4704 = _4698;
                }
                bool _4709;
                if (_4704)
                {
                    bool _7584 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
                    bool _7590;
                    if (_7584)
                    {
                        _7590 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7590 = _7584;
                    }
                    _4709 = _7590;
                }
                else
                {
                    _4709 = _4704;
                }
                float4 _10535;
                if (_4709)
                {
                    float _10495;
                    if (_10472 >= 0.0f)
                    {
                        _10495 = _10472 - _4646;
                    }
                    else
                    {
                        float _10491;
                        _10491 = 2.0f;
                        float _7647;
                        for (int _10490 = 0; _10490 < 24; _10491 = _7647, _10490++)
                        {
                            float _7611 = float(_10490 & 7) * 0.785398185253143310546875f;
                            int _7613 = _10490 >> 3;
                            int _10492;
                            if (_7613 == 0)
                            {
                                _10492 = 16;
                            }
                            else
                            {
                                _10492 = (_7613 == 1) ? 48 : 96;
                            }
                            uint _7679_dummy_parameter;
                            _7647 = min(_10491, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10231 + ((cbFI_MvDepthLaneSizeRcp * float(_10492)) * float2(cos(_7611), sin(_7611))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7679_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10495 = _10491;
                    }
                    uint _7711_dummy_parameter;
                    float4 _10536;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7711_dummy_parameter))))), 0)).x) > ((exp((_10495 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10536 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10536 = 1.0f.xxxx;
                    }
                    _10535 = _10536;
                }
                else
                {
                    _10535 = 1.0f.xxxx;
                }
                _10534 = _10535;
            }
            bool _4735 = _10472 >= 0.0f;
            bool _4742;
            if (_4735)
            {
                _4742 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4742 = _4735;
            }
            bool _4748;
            if (_4742)
            {
                _4748 = _10477.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4748 = _4742;
            }
            bool _4753;
            if (_4748)
            {
                bool _7736 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
                bool _7742;
                if (_7736)
                {
                    _7742 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
                }
                else
                {
                    _7742 = _7736;
                }
                _4753 = _7742;
            }
            else
            {
                _4753 = _4748;
            }
            float4 _10540;
            if (_4753)
            {
                float _10528;
                if (_4735)
                {
                    _10528 = _10472 - _4646;
                }
                else
                {
                    float _10524;
                    _10524 = 2.0f;
                    float _7799;
                    for (int _10523 = 0; _10523 < 24; _10524 = _7799, _10523++)
                    {
                        float _7763 = float(_10523 & 7) * 0.785398185253143310546875f;
                        int _7765 = _10523 >> 3;
                        int _10525;
                        if (_7765 == 0)
                        {
                            _10525 = 16;
                        }
                        else
                        {
                            _10525 = (_7765 == 1) ? 48 : 96;
                        }
                        uint _7815_dummy_parameter;
                        _7799 = min(_10524, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10229 + ((cbFI_MvDepthLaneSizeRcp * float(_10525)) * float2(cos(_7763), sin(_7763))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7815_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10528 = _10524;
                }
                uint _7863_dummy_parameter;
                float4 _10541;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7863_dummy_parameter))))), 0)).x) > ((exp((_10528 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10075 = _10534;
                    _10075.x = 0.0f;
                    _10541 = _10075;
                }
                else
                {
                    _10541 = _10534;
                }
                _10540 = _10541;
            }
            else
            {
                _10540 = _10534;
            }
            float4 _10602;
            if (any(bool4(_10540.x < 1.0f.xxxx.x, _10540.y < 1.0f.xxxx.y, _10540.z < 1.0f.xxxx.z, _10540.w < 1.0f.xxxx.w)))
            {
                float4 _4783 = _10477 * _10540;
                float _4785 = dot(_4783, 1.0f.xxxx);
                float4 _10603;
                if (_4785 > 0.0f)
                {
                    _10603 = _4783 / _4785.xxxx;
                }
                else
                {
                    bool _4796 = _10540.y == 0.0f;
                    bool _4802;
                    if (_4796)
                    {
                        _4802 = _10540.x > 0.0f;
                    }
                    else
                    {
                        _4802 = _4796;
                    }
                    bool _4807;
                    if (_4802)
                    {
                        bool _7888 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
                        bool _7894;
                        if (_7888)
                        {
                            _7894 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7894 = _7888;
                        }
                        _4807 = _7894;
                    }
                    else
                    {
                        _4807 = _4802;
                    }
                    float4 _10604;
                    if (_4807)
                    {
                        _10604 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4812 = _10540.x == 0.0f;
                        bool _4818;
                        if (_4812)
                        {
                            _4818 = _10540.y > 0.0f;
                        }
                        else
                        {
                            _4818 = _4812;
                        }
                        bool _4823;
                        if (_4818)
                        {
                            bool _7899 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
                            bool _7905;
                            if (_7899)
                            {
                                _7905 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7905 = _7899;
                            }
                            _4823 = _7905;
                        }
                        else
                        {
                            _4823 = _4818;
                        }
                        bool4 _12265 = _4823.xxxx;
                        _10604 = float4(_12265.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10477.x, _12265.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10477.y, _12265.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10477.z, _12265.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10477.w);
                    }
                    _10603 = _10604;
                }
                _10602 = _10603;
            }
            else
            {
                _10602 = _10477;
            }
            _10601 = _10602;
        }
        else
        {
            _10601 = _10477;
        }
        float4 _11167;
        bool _11187;
        float3 _11301;
        if (((cbFI_pad0 & 32768u) != 0u) && _4603)
        {
            bool _4840 = _10601.x > 0.00999999977648258209228515625f;
            bool _4843 = _10601.y > 0.00999999977648258209228515625f;
            bool _4852 = (_10601.z + _10601.w) > 0.0199999995529651641845703125f;
            bool _4858;
            if (_4852)
            {
                bool _7910 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                bool _7916;
                if (_7910)
                {
                    _7916 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                }
                else
                {
                    _7916 = _7910;
                }
                _4858 = _7916;
            }
            else
            {
                _4858 = _4852;
            }
            bool _4863;
            if (_4858)
            {
                bool _7921 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                bool _7927;
                if (_7921)
                {
                    _7927 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                }
                else
                {
                    _7927 = _7921;
                }
                _4863 = _7927;
            }
            else
            {
                _4863 = _4858;
            }
            bool _4870;
            if (_4863)
            {
                float _10612;
                do
                {
                    bool _8010 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                    bool _8016;
                    if (_8010)
                    {
                        _8016 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8016 = _8010;
                    }
                    bool _7947 = !_8016;
                    bool _7954;
                    if (!_7947)
                    {
                        bool _8021 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                        bool _8027;
                        if (_8021)
                        {
                            _8027 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8027 = _8021;
                        }
                        _7954 = !_8027;
                    }
                    else
                    {
                        _7954 = _7947;
                    }
                    if (_7954)
                    {
                        _10612 = 0.0f;
                        break;
                    }
                    uint _8034_dummy_parameter;
                    uint _8050_dummy_parameter;
                    float4 _7975 = mul(float4((float2(_10232.x, 1.0f - _10232.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8034_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7977 = _7975.w;
                    if (abs(_7977) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10612 = 0.0f;
                        break;
                    }
                    float _7988 = abs(cbFI_DeviceToViewDepth.y / ((_7975.z / _7977) - cbFI_DeviceToViewDepth.x));
                    float _7991 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8050_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10612 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7988 - _7991) / max(max(_7988, _7991), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4870 = _10612 < 0.5f;
            }
            else
            {
                _4870 = _4863;
            }
            float4 _10627;
            if (_4870)
            {
                uint _8100_dummy_parameter;
                uint _8131_dummy_parameter;
                float4 _10628;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8100_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8131_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10628 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10628 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10627 = _10628;
            }
            else
            {
                _10627 = 1.0f.xxxx;
            }
            bool _4894;
            if (_6946)
            {
                bool _8160 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
                bool _8166;
                if (_8160)
                {
                    _8166 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
                }
                else
                {
                    _8166 = _8160;
                }
                _4894 = _8166;
            }
            else
            {
                _4894 = _6946;
            }
            bool _4900;
            if (_6946)
            {
                bool _8171 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
                bool _8177;
                if (_8171)
                {
                    _8177 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
                }
                else
                {
                    _8177 = _8171;
                }
                _4900 = _8177;
            }
            else
            {
                _4900 = _6946;
            }
            bool _4906;
            if (_6978)
            {
                bool _8182 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                bool _8188;
                if (_8182)
                {
                    _8188 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                }
                else
                {
                    _8188 = _8182;
                }
                _4906 = _8188;
            }
            else
            {
                _4906 = _6978;
            }
            bool _4912;
            if (_6978)
            {
                bool _8193 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                bool _8199;
                if (_8193)
                {
                    _8199 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                }
                else
                {
                    _8199 = _8193;
                }
                _4912 = _8199;
            }
            else
            {
                _4912 = _6978;
            }
            bool _4915 = _4906 != _4912;
            bool _4921;
            if (_4915)
            {
                _4921 = _4894 || _4900;
            }
            else
            {
                _4921 = _4915;
            }
            float4 _10725;
            if (_4921)
            {
                float4 _10102 = _10627;
                _10102.z = 0.0f;
                _10102.w = 0.0f;
                _10725 = _10102;
            }
            else
            {
                _10725 = _10627;
            }
            bool _4928 = _4894 && _4840;
            bool _4931 = _4900 && _4843;
            float4 _10830;
            float3 _11390;
            if (_4928 || _4931)
            {
                float _10720;
                do
                {
                    uint4 _8338 = r_warped_motion_qdata_tp1.Load(int3(_10259, 0));
                    uint _8339 = _8338.x;
                    if (_8339 != 0u)
                    {
                        float _10719;
                        if (_8339 == 0u)
                        {
                            _10719 = -1.0f;
                        }
                        else
                        {
                            _10719 = float((_8339 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10720 = _10719;
                        break;
                    }
                    int _10702;
                    uint _10703;
                    _10703 = _8339;
                    _10702 = -1;
                    uint _10718;
                    for (; _10702 <= 1; _10703 = _10718, _10702++)
                    {
                        _10718 = _10703;
                        for (int _10716 = -1; _10716 <= 1; )
                        {
                            _10718 = max(_10718, r_warped_motion_qdata_tp1.Load(int3(clamp(_10259 + int2(_10716, _10702), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10716++;
                            continue;
                        }
                    }
                    if (_10703 != 0u)
                    {
                        float _10715;
                        if (_10703 == 0u)
                        {
                            _10715 = -1.0f;
                        }
                        else
                        {
                            _10715 = float((_10703 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10720 = _10715;
                        break;
                    }
                    uint _10705;
                    _10705 = 4294967295u;
                    uint _12235;
                    for (int _10704 = 0; _10704 < 8; _10705 = _12235, _10704++)
                    {
                        int _10708 = 0;
                        for (;;)
                        {
                            if (_10708 < 5)
                            {
                                int2 _8289 = _10259 + (_1085[_10704] * _1094[_10708].xx);
                                bool _8292 = any(bool2(_8289.x < int2(0, 0).x, _8289.y < int2(0, 0).y));
                                bool _8300;
                                if (!_8292)
                                {
                                    _8300 = any(bool2(_8289.x >= cbFI_MvDepthLaneSize.x, _8289.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8300 = _8292;
                                }
                                if (_8300)
                                {
                                    _12235 = _10705;
                                    break;
                                }
                                uint4 _8378 = r_warped_motion_qdata_tp1.Load(int3(_8289, 0));
                                uint _8379 = _8378.x;
                                if (_8379 != 0u)
                                {
                                    _12235 = min(_10705, _8379);
                                    break;
                                }
                                _10708++;
                                continue;
                            }
                            else
                            {
                                _12235 = _10705;
                                break;
                            }
                        }
                    }
                    float _10707;
                    if (_10705 == 4294967295u)
                    {
                        _10707 = -1.0f;
                    }
                    else
                    {
                        float _10706;
                        if (_10705 == 0u)
                        {
                            _10706 = -1.0f;
                        }
                        else
                        {
                            _10706 = float((_10705 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10707 = _10706;
                    }
                    _10720 = _10707;
                    break;
                } while(false);
                bool _4939 = _10720 < 0.0f;
                float _10721;
                if (_4939)
                {
                    _10721 = 0.0f;
                }
                else
                {
                    _10721 = _10720 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8400_dummy_parameter;
                uint _8432_dummy_parameter;
                float4 _10758;
                if ((_4939 && _4928) && _4931)
                {
                    uint _8464_dummy_parameter;
                    float _8488 = log(((r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8464_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8496_dummy_parameter;
                    float _8520 = log(((r_depth_tp1.Load(int3(int2(floor(_10231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8496_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10759;
                    if (_8488 > (_8520 + 0.07999999821186065673828125f))
                    {
                        float4 _10106 = _10725;
                        _10106.x = 0.0f;
                        _10759 = _10106;
                    }
                    else
                    {
                        float4 _10760;
                        if (_8520 > (_8488 + 0.07999999821186065673828125f))
                        {
                            float4 _10108 = _10725;
                            _10108.y = 0.0f;
                            _10760 = _10108;
                        }
                        else
                        {
                            _10760 = _10725;
                        }
                        _10759 = _10760;
                    }
                    _10758 = _10759;
                }
                else
                {
                    _10758 = _10725;
                }
                float _4991 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4993 = _10720 >= 0.0f;
                float _10741;
                if (_4993)
                {
                    _10741 = _10720 - _4991;
                }
                else
                {
                    float _10737;
                    if (_4928)
                    {
                        float _10736;
                        _10736 = 2.0f;
                        float _8578;
                        for (int _10735 = 0; _10735 < 24; _10736 = _8578, _10735++)
                        {
                            float _8542 = float(_10735 & 7) * 0.785398185253143310546875f;
                            int _8544 = _10735 >> 3;
                            int _10738;
                            if (_8544 == 0)
                            {
                                _10738 = 16;
                            }
                            else
                            {
                                _10738 = (_8544 == 1) ? 48 : 96;
                            }
                            uint _8594_dummy_parameter;
                            _8578 = min(_10736, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10229 + ((cbFI_MvDepthLaneSizeRcp * float(_10738)) * float2(cos(_8542), sin(_8542))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8594_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10737 = _10736;
                    }
                    else
                    {
                        _10737 = 0.0f;
                    }
                    _10741 = _10737;
                }
                float _10748;
                if (_4993)
                {
                    _10748 = _10720 - _4991;
                }
                else
                {
                    float _10744;
                    if (_4931)
                    {
                        float _10743;
                        _10743 = 2.0f;
                        float _8692;
                        for (int _10742 = 0; _10742 < 24; _10743 = _8692, _10742++)
                        {
                            float _8656 = float(_10742 & 7) * 0.785398185253143310546875f;
                            int _8658 = _10742 >> 3;
                            int _10745;
                            if (_8658 == 0)
                            {
                                _10745 = 16;
                            }
                            else
                            {
                                _10745 = (_8658 == 1) ? 48 : 96;
                            }
                            uint _8724_dummy_parameter;
                            _8692 = min(_10743, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10231 + ((cbFI_MvDepthLaneSizeRcp * float(_10745)) * float2(cos(_8656), sin(_8656))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8724_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10744 = _10743;
                    }
                    else
                    {
                        _10744 = 0.0f;
                    }
                    _10748 = _10744;
                }
                float _10749;
                if (_4928)
                {
                    uint _8756_dummy_parameter;
                    _10749 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8756_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10749 = 0.0f;
                }
                float _10750;
                if (_4931)
                {
                    uint _8776_dummy_parameter;
                    _10750 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8776_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10750 = 0.0f;
                }
                bool _5048;
                if (_4928)
                {
                    _5048 = _10749 > ((exp((_10741 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5048 = _4928;
                }
                float4 _10766;
                if (_5048)
                {
                    float4 _10110 = _10758;
                    _10110.x = 0.0f;
                    _10766 = _10110;
                }
                else
                {
                    _10766 = _10758;
                }
                bool _5060;
                if (_4931)
                {
                    _5060 = _10750 > ((exp((_10748 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5060 = _4931;
                }
                float4 _10768;
                if (_5060)
                {
                    float4 _10112 = _10766;
                    _10112.y = 0.0f;
                    _10768 = _10112;
                }
                else
                {
                    _10768 = _10766;
                }
                float4 _10831;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4993)
                {
                    bool _5080;
                    if (_4928)
                    {
                        _5080 = _10749 < ((exp((_10741 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5080 = _4928;
                    }
                    float4 _10770;
                    if (_5080)
                    {
                        float4 _10114 = _10768;
                        _10114.x = 0.0f;
                        _10770 = _10114;
                    }
                    else
                    {
                        _10770 = _10768;
                    }
                    bool _5092;
                    if (_4931)
                    {
                        _5092 = _10750 < ((exp((_10748 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5092 = _4931;
                    }
                    float4 _10832;
                    if (_5092)
                    {
                        float4 _10116 = _10770;
                        _10116.y = 0.0f;
                        _10832 = _10116;
                    }
                    else
                    {
                        _10832 = _10770;
                    }
                    _10831 = _10832;
                }
                else
                {
                    _10831 = _10768;
                }
                _11390 = float3(_10721, log(((r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8400_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8432_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10830 = _10831;
            }
            else
            {
                _11390 = float3(0.0f, 0.0f, 0.5f);
                _10830 = _10725;
            }
            bool _5103 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4852;
            bool _5109;
            if (_5103)
            {
                _5109 = _4906 || _4912;
            }
            else
            {
                _5109 = _5103;
            }
            float4 _10853;
            if (_5109)
            {
                float _10825;
                do
                {
                    uint4 _8956 = r_warped_motion_qdata_tp1.Load(int3(_10259, 0));
                    uint _8957 = _8956.x;
                    if (_8957 != 0u)
                    {
                        float _10824;
                        if (_8957 == 0u)
                        {
                            _10824 = -1.0f;
                        }
                        else
                        {
                            _10824 = float((_8957 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10825 = _10824;
                        break;
                    }
                    int _10807;
                    uint _10808;
                    _10808 = _8957;
                    _10807 = -1;
                    uint _10823;
                    for (; _10807 <= 1; _10808 = _10823, _10807++)
                    {
                        _10823 = _10808;
                        for (int _10821 = -1; _10821 <= 1; )
                        {
                            _10823 = max(_10823, r_warped_motion_qdata_tp1.Load(int3(clamp(_10259 + int2(_10821, _10807), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10821++;
                            continue;
                        }
                    }
                    if (_10808 != 0u)
                    {
                        float _10820;
                        if (_10808 == 0u)
                        {
                            _10820 = -1.0f;
                        }
                        else
                        {
                            _10820 = float((_10808 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10825 = _10820;
                        break;
                    }
                    uint _10810;
                    _10810 = 4294967295u;
                    uint _12236;
                    for (int _10809 = 0; _10809 < 8; _10810 = _12236, _10809++)
                    {
                        int _10813 = 0;
                        for (;;)
                        {
                            if (_10813 < 5)
                            {
                                int2 _8907 = _10259 + (_1085[_10809] * _1094[_10813].xx);
                                bool _8910 = any(bool2(_8907.x < int2(0, 0).x, _8907.y < int2(0, 0).y));
                                bool _8918;
                                if (!_8910)
                                {
                                    _8918 = any(bool2(_8907.x >= cbFI_MvDepthLaneSize.x, _8907.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8918 = _8910;
                                }
                                if (_8918)
                                {
                                    _12236 = _10810;
                                    break;
                                }
                                uint4 _8996 = r_warped_motion_qdata_tp1.Load(int3(_8907, 0));
                                uint _8997 = _8996.x;
                                if (_8997 != 0u)
                                {
                                    _12236 = min(_10810, _8997);
                                    break;
                                }
                                _10813++;
                                continue;
                            }
                            else
                            {
                                _12236 = _10810;
                                break;
                            }
                        }
                    }
                    float _10812;
                    if (_10810 == 4294967295u)
                    {
                        _10812 = -1.0f;
                    }
                    else
                    {
                        float _10811;
                        if (_10810 == 0u)
                        {
                            _10811 = -1.0f;
                        }
                        else
                        {
                            _10811 = float((_10810 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10812 = _10811;
                    }
                    _10825 = _10812;
                    break;
                } while(false);
                float4 _10854;
                if (_10825 >= 0.0f)
                {
                    float _9018 = (exp((_10825 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5128;
                    if (_4906)
                    {
                        uint _9025_dummy_parameter;
                        _5128 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9025_dummy_parameter))))), 0)).x) > _9018;
                    }
                    else
                    {
                        _5128 = _4906;
                    }
                    float4 _10843;
                    if (_5128)
                    {
                        float4 _10118 = _10830;
                        _10118.z = 0.0f;
                        _10843 = _10118;
                    }
                    else
                    {
                        _10843 = _10830;
                    }
                    bool _5140;
                    if (_4912)
                    {
                        uint _9045_dummy_parameter;
                        _5140 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9045_dummy_parameter))))), 0)).x) > _9018;
                    }
                    else
                    {
                        _5140 = _4912;
                    }
                    float4 _10855;
                    if (_5140)
                    {
                        float4 _10120 = _10843;
                        _10120.w = 0.0f;
                        _10855 = _10120;
                    }
                    else
                    {
                        _10855 = _10843;
                    }
                    _10854 = _10855;
                }
                else
                {
                    _10854 = _10830;
                }
                _10853 = _10854;
            }
            else
            {
                _10853 = _10830;
            }
            bool _5148 = _4894 != _4900;
            bool _5155;
            if (_5148)
            {
                _5155 = _4894 ? _4840 : _4843;
            }
            else
            {
                _5155 = _5148;
            }
            bool _5162;
            if (_5155)
            {
                _5162 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5162 = _5155;
            }
            float4 _10938;
            if (_5162)
            {
                bool2 _5167 = _4894.xx;
                float2 _5168 = float2(_5167.x ? _10229.x : _10231.x, _5167.y ? _10229.y : _10231.y);
                float _10845;
                if (_4894)
                {
                    uint _9065_dummy_parameter;
                    _10845 = r_depth_tm1.Load(int3(int2(floor(_5168 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9065_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9081_dummy_parameter;
                    _10845 = r_depth_tp1.Load(int3(int2(floor(_5168 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9081_dummy_parameter))))), 0)).x;
                }
                float4x4 _10846;
                if (_4894)
                {
                    _10846 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10846 = cbFI_MotionTP1ToTM1;
                }
                float2 _10847;
                do
                {
                    float _9108 = _5168.x;
                    float _9111 = 1.0f - _5168.y;
                    float4 _9122 = mul(float4((float2(_9108, _9111) * 2.0f) - 1.0f.xx, _10845, 1.0f), _10846);
                    float _9124 = _9122.w;
                    if (!(_9124 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10847 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9137 = ((_9122.xy / _9124.xx) + 1.0f.xx) * 0.5f;
                    _10847 = float2(_9137.x - _9108, _9111 - _9137.y);
                    break;
                } while(false);
                float2 _5198 = float2(cbFI_DisplaySize);
                float4 _10939;
                if (!(length(((_5168 + _10847) - float2(_5167.x ? _10231.x : _10229.x, _5167.y ? _10231.y : _10229.y)) * _5198) <= ((0.100000001490116119384765625f * length(_10847 * _5198)) + 8.0f)))
                {
                    float4 _10940;
                    if (_4894)
                    {
                        float4 _10130 = _10853;
                        _10130.x = 0.0f;
                        _10940 = _10130;
                    }
                    else
                    {
                        float4 _10132 = _10853;
                        _10132.y = 0.0f;
                        _10940 = _10132;
                    }
                    _10939 = _10940;
                }
                else
                {
                    _10939 = _10853;
                }
                _10938 = _10939;
            }
            else
            {
                _10938 = _10853;
            }
            float4 _5223 = _10601 * _10938;
            float _5225 = dot(_5223, 1.0f.xxxx);
            float4 _11168;
            bool _11188;
            if (_5225 > 0.0f)
            {
                _11188 = _10382;
                _11168 = _5223 / _5225.xxxx;
            }
            else
            {
                bool _5236 = any(bool4(_10938.x < 1.0f.xxxx.x, _10938.y < 1.0f.xxxx.y, _10938.z < 1.0f.xxxx.z, _10938.w < 1.0f.xxxx.w));
                if (_5236)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9159;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9159);
                    }
                }
                bool4 _12268 = _5236.xxxx;
                _11188 = _5236 ? true : _10382;
                _11168 = float4(_12268.x ? 0.0f.xxxx.x : _10601.x, _12268.y ? 0.0f.xxxx.y : _10601.y, _12268.z ? 0.0f.xxxx.z : _10601.z, _12268.w ? 0.0f.xxxx.w : _10601.w);
            }
            _11301 = _11390;
            _11187 = _11188;
            _11167 = _11168;
        }
        else
        {
            _11301 = float3(0.0f, 0.0f, 0.5f);
            _11187 = _10382;
            _11167 = _10601;
        }
        uint _5245 = (cbFI_pad0 >> 24u) & 31u;
        uint _5249 = (cbFI_pad0 >> 16u) & 255u;
        bool _5251 = _5245 != 0u;
        bool _5253 = _5249 == 12u;
        bool _5256 = _5249 == 13u;
        float4 _11184;
        if ((_5251 || _5253) || _5256)
        {
            float _10941;
            do
            {
                bool _9243 = all(bool2(_10232.x > 0.0f.xx.x, _10232.y > 0.0f.xx.y));
                bool _9249;
                if (_9243)
                {
                    _9249 = all(bool2(_10232.x < 1.0f.xx.x, _10232.y < 1.0f.xx.y));
                }
                else
                {
                    _9249 = _9243;
                }
                bool _9180 = !_9249;
                bool _9187;
                if (!_9180)
                {
                    bool _9254 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
                    bool _9260;
                    if (_9254)
                    {
                        _9260 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9260 = _9254;
                    }
                    _9187 = !_9260;
                }
                else
                {
                    _9187 = _9180;
                }
                if (_9187)
                {
                    _10941 = 0.0f;
                    break;
                }
                uint _9267_dummy_parameter;
                uint _9283_dummy_parameter;
                float4 _9208 = mul(float4((float2(_10232.x, 1.0f - _10232.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9267_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9210 = _9208.w;
                if (abs(_9210) < 9.9999999747524270787835121154785e-07f)
                {
                    _10941 = 0.0f;
                    break;
                }
                float _9221 = abs(cbFI_DeviceToViewDepth.y / ((_9208.z / _9210) - cbFI_DeviceToViewDepth.x));
                float _9224 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9283_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10941 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9221 - _9224) / max(max(_9221, _9224), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9331 = all(bool2(_10233.x > 0.0f.xx.x, _10233.y > 0.0f.xx.y));
            bool _9337;
            if (_9331)
            {
                _9337 = all(bool2(_10233.x < 1.0f.xx.x, _10233.y < 1.0f.xx.y));
            }
            else
            {
                _9337 = _9331;
            }
            float _10942;
            if (_9337)
            {
                uint _9344_dummy_parameter;
                _10942 = length((_6032 + (r_motion_tp1.Load(int3(int2(floor(_10233 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9344_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10942 = 1000000.0f;
            }
            float _10953;
            if ((_5245 & 1u) != 0u)
            {
                _10953 = _10941;
            }
            else
            {
                _10953 = 1.0f;
            }
            float _10954;
            if ((_5245 & 2u) != 0u)
            {
                _10954 = _10953 * (1.0f - smoothstep(2.0f, 8.0f, _10942));
            }
            else
            {
                _10954 = _10953;
            }
            float _10955;
            if ((_5245 & 4u) != 0u)
            {
                _10955 = _10954 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6753 - _6761) - length(_6737 - _6745))));
            }
            else
            {
                _10955 = _10954;
            }
            float _11178;
            if ((_5245 & 8u) != 0u)
            {
                _11178 = lerp(1.0f, _10955, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6737 - _6745)));
            }
            else
            {
                _11178 = _10955;
            }
            bool _5331 = (_5245 & 16u) != 0u;
            bool _5340;
            if (_5331)
            {
                _5340 = length(_10227 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5340 = _5331;
            }
            float _12270 = _5340 ? 1.0f : _11178;
            bool _5346 = _5251 && _6946;
            bool _5351;
            if (_5346)
            {
                bool _9369 = all(bool2(_10229.x > 0.0f.xx.x, _10229.y > 0.0f.xx.y));
                bool _9375;
                if (_9369)
                {
                    _9375 = all(bool2(_10229.x < 1.0f.xx.x, _10229.y < 1.0f.xx.y));
                }
                else
                {
                    _9375 = _9369;
                }
                _5351 = _9375;
            }
            else
            {
                _5351 = _5346;
            }
            bool _5356;
            if (_5351)
            {
                bool _9380 = all(bool2(_10231.x > 0.0f.xx.x, _10231.y > 0.0f.xx.y));
                bool _9386;
                if (_9380)
                {
                    _9386 = all(bool2(_10231.x < 1.0f.xx.x, _10231.y < 1.0f.xx.y));
                }
                else
                {
                    _9386 = _9380;
                }
                _5356 = _9386;
            }
            else
            {
                _5356 = _5351;
            }
            float4 _11185;
            if (_5356)
            {
                float _5362 = _11167.x + _11167.y;
                float _5371 = (_11167.z + _11167.w) * (1.0f - _12270);
                float _11181;
                if (_5362 > 9.9999997473787516355514526367188e-06f)
                {
                    _11181 = _11167.x / _5362;
                }
                else
                {
                    _11181 = _4273;
                }
                _11185 = float4(_11167.x + (_5371 * _11181), _11167.y + (_5371 * (1.0f - _11181)), _11167.zw * _12270);
            }
            else
            {
                _11185 = _11167;
            }
            _11184 = _11185;
        }
        else
        {
            _11184 = _11167;
        }
        float3 _12038;
        if (_11187)
        {
            float3 _9392 = r_current_interpolation_source.Load(int3(_3653, 0)).xyz;
            float3 _12039;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6946)
            {
                uint _9399_dummy_parameter;
                float _11292;
                _11292 = r_depth_tm1.Load(int3(int2(floor(_10229 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9399_dummy_parameter))))), 0)).x;
                float _5483;
                for (int _11291 = 0; _11291 < 24; _11292 = _5483, _11291++)
                {
                    float _5455 = float(_11291 & 7) * 0.785398185253143310546875f;
                    int _5457 = _11291 >> 3;
                    int _12089;
                    if (_5457 == 0)
                    {
                        _12089 = 16;
                    }
                    else
                    {
                        _12089 = (_5457 == 1) ? 48 : 96;
                    }
                    uint _9419_dummy_parameter;
                    _5483 = max(_11292, r_depth_tm1.Load(int3(int2(floor(clamp(_10229 + ((cbFI_MvDepthLaneSizeRcp * float(_12089)) * float2(cos(_5455), sin(_5455))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9419_dummy_parameter))))), 0)).x);
                }
                float2 _11293;
                do
                {
                    float _9441 = 1.0f - _10229.y;
                    float4 _9452 = mul(float4((float2(_10229.x, _9441) * 2.0f) - 1.0f.xx, _11292, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9454 = _9452.w;
                    if (!(_9454 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11293 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9467 = ((_9452.xy / _9454.xx) + 1.0f.xx) * 0.5f;
                    _11293 = float2(_9467.x - _10229.x, _9441 - _9467.y);
                    break;
                } while(false);
                float2 _5494 = _10229 + _11293;
                bool _9485 = all(bool2(_5494.x > 0.0f.xx.x, _5494.y > 0.0f.xx.y));
                bool _9491;
                if (_9485)
                {
                    _9491 = all(bool2(_5494.x < 1.0f.xx.x, _5494.y < 1.0f.xx.y));
                }
                else
                {
                    _9491 = _9485;
                }
                float3 _12040;
                if (_9491)
                {
                    float _5500 = abs(cbFI_DeviceToViewDepth.y / (_11292 - cbFI_DeviceToViewDepth.x));
                    uint _9511_dummy_parameter;
                    int2 _9511 = int2(spvTextureSize(r_depth_m2, uint(0), _9511_dummy_parameter));
                    float _5504 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5494 * float2(_9511))), int2(0, 0), _9511 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12045;
                    if (abs(_5504 - _5500) <= (0.20000000298023223876953125f * max(_5504, _5500)))
                    {
                        uint _9545_dummy_parameter;
                        int2 _9545 = int2(spvTextureSize(r_colour_m2, uint(0), _9545_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9568;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9568);
                        }
                        _12045 = r_colour_m2.Load(int3(clamp(int2(floor(_5494 * float2(_9545))), int2(0, 0), _9545 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9578;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9578);
                        }
                        _12045 = _9392;
                    }
                    _12040 = _12045;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9588;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9588);
                    }
                    _12040 = _9392;
                }
                _12039 = _12040;
            }
            else
            {
                _12039 = _9392;
            }
            _12038 = _12039;
        }
        else
        {
            _12038 = (((_6737 * _11184.x) + (_6745 * _11184.y)) + (_6753 * _11184.z)) + (_6761 * _11184.w);
        }
        uint _5532 = cbFI_pad0 & 255u;
        bool _11930;
        float3 _12037;
        if (_5532 != 0u)
        {
            float3 _5537 = r_present_backbuffer.Load(int3(_3653, 0)).xyz;
            float3 _5541 = r_current_interpolation_source.Load(int3(_3653, 0)).xyz;
            float3 _5545 = abs(_5537 - _5541);
            float3 _11296;
            if (_5532 == 2u)
            {
                _11296 = (abs(_5541) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11296 = 0.000244140625f.xxx;
            }
            bool _5561 = any(bool3(_5545.x > _11296.x, _5545.y > _11296.y, _5545.z > _11296.z));
            bool3 _12271 = _5561.xxx;
            _12037 = float3(_12271.x ? _5537.x : _12038.x, _12271.y ? _5537.y : _12038.y, _12271.z ? _5537.z : _12038.z);
            _11930 = _5561;
        }
        else
        {
            _12037 = _12038;
            _11930 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9603;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9603);
        }
        float3 _12020;
        if (_5249 == 1u)
        {
            _12020 = lerp(_6737, _6745, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12021;
            if (_5249 == 2u)
            {
                _12021 = lerp(_6753, _6761, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12022;
                if (_5249 == 3u)
                {
                    _12022 = float(_11930).xxx;
                }
                else
                {
                    float3 _12023;
                    if (_5249 == 4u)
                    {
                        _12023 = float3(((_10227 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12024;
                        if (_5249 == 5u)
                        {
                            _12024 = float3(((_6032 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12025;
                            if (_5249 == 6u)
                            {
                                _12025 = float3(_11184.xy, _11184.z + _11184.w);
                            }
                            else
                            {
                                float3 _12026;
                                if (_5249 == 7u)
                                {
                                    _12026 = r_current_interpolation_source.Load(int3(_3653, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12027;
                                    if (_5249 == 8u)
                                    {
                                        _12027 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4048, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12028;
                                        if (_5253)
                                        {
                                            uint _9625_dummy_parameter;
                                            uint _9657_dummy_parameter;
                                            _12028 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4048 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9625_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9657_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12029;
                                            if (_5256)
                                            {
                                                _12029 = _6753;
                                            }
                                            else
                                            {
                                                float3 _12030;
                                                if (_5249 == 20u)
                                                {
                                                    _12030 = _6737;
                                                }
                                                else
                                                {
                                                    float3 _12031;
                                                    if (_5249 == 21u)
                                                    {
                                                        _12031 = _6745;
                                                    }
                                                    else
                                                    {
                                                        float3 _12032;
                                                        if (_5249 == 22u)
                                                        {
                                                            _12032 = _6761;
                                                        }
                                                        else
                                                        {
                                                            float3 _12033;
                                                            if (_5249 == 18u)
                                                            {
                                                                _12033 = _11688;
                                                            }
                                                            else
                                                            {
                                                                float3 _12034;
                                                                if (_5249 == 19u)
                                                                {
                                                                    _12034 = _11492;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12273 = (_5249 == 23u).xxx;
                                                                    _12034 = float3(_12273.x ? _11301.x : _12037.x, _12273.y ? _11301.y : _12037.y, _12273.z ? _11301.z : _12037.z);
                                                                }
                                                                _12033 = _12034;
                                                            }
                                                            _12032 = _12033;
                                                        }
                                                        _12031 = _12032;
                                                    }
                                                    _12030 = _12031;
                                                }
                                                _12029 = _12030;
                                            }
                                            _12028 = _12029;
                                        }
                                        _12027 = _12028;
                                    }
                                    _12026 = _12027;
                                }
                                _12025 = _12026;
                            }
                            _12024 = _12025;
                        }
                        _12023 = _12024;
                    }
                    _12022 = _12023;
                }
                _12021 = _12022;
            }
            _12020 = _12021;
        }
        float3 _12019;
        if ((_5249 >= 9u) && (_5249 <= 11u))
        {
            uint _5725 = 64u + uint((_10259.y * cbFI_MvDepthLaneSize.x) + _10259.x);
            uint _5729 = rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) & 15u;
            float3 _12050;
            if (_5249 == 10u)
            {
                float3 _12018;
                if ((rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) & 32u) != 0u)
                {
                    _12018 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12017;
                    if ((rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) & 16u) != 0u)
                    {
                        _12017 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5750 = ((rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) & 64u) != 0u).xxx;
                        _12017 = float3(_5750.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5750.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5750.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12018 = _12017;
                }
                _12050 = _12018;
            }
            else
            {
                float3 _12051;
                if (_5249 == 11u)
                {
                    uint _5763 = (rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) >> 8u) & 15u;
                    uint _5766 = (rw_nfru_diagnostics.Load<uint>(_5725 * 4 + 0) >> 12u) & 15u;
                    float3 _12010;
                    if ((_5729 == 2u) || (_5729 == 3u))
                    {
                        _12010 = _3366[_5729];
                    }
                    else
                    {
                        bool _5778 = _5763 == 3u;
                        bool _5780 = _5766 == 3u;
                        float3 _12011;
                        if (_5778 && _5780)
                        {
                            _12011 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12012;
                            if (_5778)
                            {
                                _12012 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12013;
                                if (_5780)
                                {
                                    _12013 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12014;
                                    if ((_5763 == 4u) || (_5766 == 4u))
                                    {
                                        _12014 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12015;
                                        if ((_5763 == 1u) || (_5766 == 1u))
                                        {
                                            _12015 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12275 = (_5729 == 1u).xxx;
                                            _12015 = float3(_12275.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12275.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12275.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12014 = _12015;
                                    }
                                    _12013 = _12014;
                                }
                                _12012 = _12013;
                            }
                            _12011 = _12012;
                        }
                        _12010 = _12011;
                    }
                    _12051 = _12010;
                }
                else
                {
                    _12051 = _3366[min(_5729, 7u)];
                }
                _12050 = _12051;
            }
            _12019 = _12050;
        }
        else
        {
            _12019 = _12020;
        }
        float4 _12054;
        if ((_5249 >= 14u) && (_5249 <= 16u))
        {
            float2 _12052;
            if (_5249 == 14u)
            {
                uint _5836_dummy_parameter;
                uint _5842_dummy_parameter;
                _12052 = r_flow_tm1.Load(int3(clamp(int2(floor(_4048 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5836_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5842_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12053;
                if (_5249 == 16u)
                {
                    uint _9708 = r_warped_flow_qdata_tm1.Load(int3(_4064, 0)).x & 2147483647u;
                    uint _9740 = uint(max((int((_9708 >> 16u) & 15u) - 6), 0));
                    _12053 = ((float2(float((1 - (2 * int((_9708 >> 15u) & 1u))) * int(((_9708 >> uint(7)) & 127u) << _9740)), float((1 - (2 * int((_9708 >> 14u) & 1u))) * int((_9708 & 127u) << _9740))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12053 = _6032 * float2(cbFI_DisplaySize);
                }
                _12052 = _12053;
            }
            uint2 _5875 = uint2(clamp(round(_12052 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5877 = _5875.x;
            uint _5884 = _5875.y;
            _12054 = float4(float(_5877 & 255u), float((_5877 >> 8u) | ((_5884 & 15u) << 4u)), float(_5884 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12055;
            if (_5249 == 17u)
            {
                _12055 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4064, 0)).x != 0u), _4407, 0.0f, 1.0f);
            }
            else
            {
                _12055 = float4(_12019, 1.0f);
            }
            _12054 = _12055;
        }
        rw_output[_3653] = _12054.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5928 = ((uint(_3653.y) * uint(cbFI_DisplaySize.x)) + uint(_3653.x)) * 6u;
            uint _9786 = spvPackHalf2x16(clamp(_6736.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5928 * 4 + 0, (((_9786 & 32767u) >> 4u) | ((((_9786 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6736.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9821 = spvPackHalf2x16(clamp(_6744.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5928 + 1u) * 4 + 0, (((_9821 & 32767u) >> 4u) | ((((_9821 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6744.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9856 = spvPackHalf2x16(clamp(_6752.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5928 + 2u) * 4 + 0, (((_9856 & 32767u) >> 4u) | ((((_9856 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6752.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9891 = spvPackHalf2x16(clamp(_6760.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5928 + 3u) * 4 + 0, (((_9891 & 32767u) >> 4u) | ((((_9891 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6760.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9918 = r_current_interpolation_source.Load(int3(_3653, 0));
            uint _9932 = spvPackHalf2x16(clamp(_9918.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5928 + 4u) * 4 + 0, (((_9932 & 32767u) >> 4u) | ((((_9932 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9918.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12088;
            if (_11930 || (_5249 != 0u))
            {
                _12088 = 4294967295u;
            }
            else
            {
                uint _9967 = spvPackHalf2x16(clamp(_12054.xy, 0.0f.xx, 65000.0f.xx));
                _12088 = (((_9967 & 32767u) >> 4u) | ((((_9967 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12054.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5928 + 5u) * 4 + 0, _12088);
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
