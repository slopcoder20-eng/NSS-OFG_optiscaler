static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3435[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3722 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3722.x >= cbFI_DisplaySize.x, _3722.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3722] = float4(r_present_backbuffer.Load(int3(_3722, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4125 = (float2(_3722) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4136 = int2(floor(_4125 * float2(cbFI_MvDepthLaneSize)));
        int2 _4141 = int2(floor(_4125 * float2(cbFI_FlowLaneSize)));
        float4 _6164 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4125 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6170 = r_warped_filled_flow_tm1.Load(int3(_4141, 0)).xy;
        float2 _6176 = r_warped_filled_motion_tp1.Load(int3(_4136, 0)).xy;
        bool _6198 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10419;
        if (_6198)
        {
            float _6211 = ((2.0f * _4125.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10419 = float2(atan(_6211) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4125.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6211 * _6211))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10419 = _4125;
        }
        bool _4162 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10440;
        bool _10461;
        int2 _10472;
        float3 _11978;
        if (_4162)
        {
            float _10421;
            float _10423;
            _10423 = 2.0f;
            _10421 = -1.0f;
            uint _3784[9];
            float _12431;
            float _12434;
            for (int _10420 = 0; _10420 < 9; _10423 = _12434, _10421 = _12431, _10420++)
            {
                _3784[_10420] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4136 + int2((_10420 % 3) - 1, (_10420 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3784[_10420] != 0u)
                {
                    float _12426;
                    if (_3784[_10420] == 0u)
                    {
                        _12426 = -1.0f;
                    }
                    else
                    {
                        _12426 = float((_3784[_10420] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12434 = min(_10423, _12426);
                    _12431 = max(_10421, _12426);
                }
                else
                {
                    _12434 = _10423;
                    _12431 = _10421;
                }
            }
            float _4208 = float(_10421 >= 0.0f);
            float3 _10206 = 0.0f.xxx;
            _10206.y = _4208;
            float2 _10441;
            bool _10462;
            int2 _10473;
            float3 _11979;
            if ((_10421 - _10423) > 0.0199999995529651641845703125f)
            {
                float _10429;
                int2 _10430;
                float2 _10431;
                int2 _10433;
                float2 _10439;
                _10439 = _6176;
                _10433 = _4136;
                _10431 = _6176;
                _10430 = _4136;
                _10429 = -1.0f;
                float _12439;
                int2 _12443;
                float2 _12454;
                int2 _12465;
                float2 _12498;
                float _12545;
                int _10428 = 0;
                float _12407 = 1000000000.0f;
                for (; _10428 < 9; _12407 = _12545, _10439 = _12498, _10433 = _12465, _10431 = _12454, _10430 = _12443, _10429 = _12439, _10428++)
                {
                    if (_3784[_10428] == 0u)
                    {
                        _12545 = _12407;
                        _12498 = _10439;
                        _12465 = _10433;
                        _12454 = _10431;
                        _12443 = _10430;
                        _12439 = _10429;
                        continue;
                    }
                    int2 _4243 = clamp(_4136 + int2((_10428 % 3) - 1, (_10428 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6286 = _3784[_10428] & 2147483647u;
                    uint _6318 = uint(max((int((_6286 >> 16u) & 15u) - 6), 0));
                    float2 _4249 = (float2(float((1 - (2 * int((_6286 >> 15u) & 1u))) * int(((_6286 >> uint(7)) & 127u) << _6318)), float((1 - (2 * int((_6286 >> 14u) & 1u))) * int((_6286 & 127u) << _6318))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12393;
                    if (_3784[_10428] == 0u)
                    {
                        _12393 = -1.0f;
                    }
                    else
                    {
                        _12393 = float((_3784[_10428] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4254 = _12393 - 0.100000001490116119384765625f;
                    float2 _12394;
                    if (_6198)
                    {
                        float2 _6395 = clamp((((_10419 + (_4249 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6398 = tan(_6395.x);
                        _12394 = (float2(_6398 / cbFI_DeviceToViewDepth.z, (tan(_6395.y) * sqrt(1.0f + (_6398 * _6398))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12394 = _10419 + (_4249 * cbFI_Timestep);
                    }
                    float _4261 = cbFI_Timestep - 1.0f;
                    float2 _12395;
                    if (_6198)
                    {
                        float2 _6466 = clamp((((_10419 + (_4249 * _4261)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6469 = tan(_6466.x);
                        _12395 = (float2(_6469 / cbFI_DeviceToViewDepth.z, (tan(_6466.y) * sqrt(1.0f + (_6469 * _6469))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12395 = _10419 + (_4249 * _4261);
                    }
                    bool _6502 = all(bool2(_12394.x > 0.0f.xx.x, _12394.y > 0.0f.xx.y));
                    bool _6508;
                    if (_6502)
                    {
                        _6508 = all(bool2(_12394.x < 1.0f.xx.x, _12394.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6508 = _6502;
                    }
                    float _12398;
                    if (_6508)
                    {
                        uint _6515_dummy_parameter;
                        _12398 = max((_4254 - (log(((r_depth_tm1.Load(int3(int2(floor(_12394 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6515_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12398 = 0.0f;
                    }
                    bool _6545 = all(bool2(_12395.x > 0.0f.xx.x, _12395.y > 0.0f.xx.y));
                    bool _6551;
                    if (_6545)
                    {
                        _6551 = all(bool2(_12395.x < 1.0f.xx.x, _12395.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6551 = _6545;
                    }
                    float _12399;
                    if (_6551)
                    {
                        uint _6558_dummy_parameter;
                        _12399 = _12398 + max((_4254 - (log(((r_depth_tp1.Load(int3(int2(floor(_12395 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6558_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12399 = _12398;
                    }
                    float _12440;
                    int2 _12444;
                    float2 _12455;
                    int2 _12466;
                    float2 _12499;
                    float _12546;
                    if (_12399 == 0.0f)
                    {
                        bool _4296 = _4254 > _10429;
                        bool2 _12554 = _4296.xx;
                        _12546 = _12407;
                        _12499 = float2(_12554.x ? _4249.x : _10439.x, _12554.y ? _4249.y : _10439.y);
                        _12466 = int2(_12554.x ? _4243.x : _10433.x, _12554.y ? _4243.y : _10433.y);
                        _12455 = _10431;
                        _12444 = _10430;
                        _12440 = _4296 ? _4254 : _10429;
                    }
                    else
                    {
                        bool _4305 = _12399 < _12407;
                        bool2 _12550 = _4305.xx;
                        _12546 = _4305 ? _12399 : _12407;
                        _12499 = _10439;
                        _12466 = _10433;
                        _12455 = float2(_12550.x ? _4249.x : _10431.x, _12550.y ? _4249.y : _10431.y);
                        _12444 = int2(_12550.x ? _4243.x : _10430.x, _12550.y ? _4243.y : _10430.y);
                        _12440 = _10429;
                    }
                    _12545 = _12546;
                    _12498 = _12499;
                    _12465 = _12466;
                    _12454 = _12455;
                    _12443 = _12444;
                    _12439 = _12440;
                }
                bool _4317 = _10429 < 0.0f;
                bool2 _12560 = _4317.xx;
                int2 _12563 = int2(_12560.x ? _10430.x : _10433.x, _12560.y ? _10430.y : _10433.y);
                _11979 = float3(1.0f, _4208, float(any(bool2(_12563.x != _4136.x, _12563.y != _4136.y))));
                _10473 = _12563;
                _10462 = _4317 ? false : true;
                _10441 = float2(_12560.x ? _10431.x : _10439.x, _12560.y ? _10431.y : _10439.y);
            }
            else
            {
                _11979 = _10206;
                _10473 = _4136;
                _10462 = false;
                _10441 = _6176;
            }
            _11978 = _11979;
            _10472 = _10473;
            _10461 = _10462;
            _10440 = _10441;
        }
        else
        {
            _11978 = 0.0f.xxx;
            _10472 = _4136;
            _10461 = false;
            _10440 = _6176;
        }
        float2 _10442;
        if (_6198)
        {
            float2 _6623 = clamp((((_10419 + (_10440 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6626 = tan(_6623.x);
            _10442 = (float2(_6626 / cbFI_DeviceToViewDepth.z, (tan(_6623.y) * sqrt(1.0f + (_6626 * _6626))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10442 = _10419 + (_10440 * cbFI_Timestep);
        }
        float _4340 = cbFI_Timestep - 1.0f;
        float2 _10444;
        if (_6198)
        {
            float2 _6694 = clamp((((_10419 + (_10440 * _4340)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6697 = tan(_6694.x);
            _10444 = (float2(_6697 / cbFI_DeviceToViewDepth.z, (tan(_6694.y) * sqrt(1.0f + (_6697 * _6697))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10444 = _10419 + (_10440 * _4340);
        }
        float _4345 = -cbFI_Timestep;
        float2 _10445;
        if (_6198)
        {
            float2 _6765 = clamp((((_10419 + (_6170 * _4345)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6768 = tan(_6765.x);
            _10445 = (float2(_6768 / cbFI_DeviceToViewDepth.z, (tan(_6765.y) * sqrt(1.0f + (_6768 * _6768))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10445 = _10419 + (_6170 * _4345);
        }
        float _4350 = 1.0f - cbFI_Timestep;
        float2 _10446;
        if (_6198)
        {
            float2 _6836 = clamp((((_10419 + (_6170 * _4350)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6839 = tan(_6836.x);
            _10446 = (float2(_6839 / cbFI_DeviceToViewDepth.z, (tan(_6836.y) * sqrt(1.0f + (_6839 * _6839))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10446 = _10419 + (_6170 * _4350);
        }
        float4 _6874 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10442, 0.0f);
        float3 _6875 = _6874.xyz;
        float4 _6882 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10444, 0.0f);
        float3 _6883 = _6882.xyz;
        float4 _6890 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10445, 0.0f);
        float3 _6891 = _6890.xyz;
        float4 _6898 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10446, 0.0f);
        float3 _6899 = _6898.xyz;
        float4 _6913 = exp(_6164 - max(max(max(_6164.x, _6164.y), _6164.z), _6164.w).xxxx);
        float4 _6920 = _6913 / (dot(_6913, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4369 = _4162 && (!_10461);
        bool _4378;
        if (_4369)
        {
            _4378 = (_6920.z + _6920.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4378 = _4369;
        }
        bool _4389;
        if (_4378)
        {
            _4389 = length((_10445 - _10442) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4389 = _4378;
        }
        bool _10485;
        if (_4389)
        {
            uint4 _6939 = r_warped_motion_qdata_tp1.Load(int3(_10472, 0));
            uint _6940 = _6939.x;
            bool _10488;
            if (_6940 != 0u)
            {
                float _10474;
                if (_6940 == 0u)
                {
                    _10474 = -1.0f;
                }
                else
                {
                    _10474 = float((_6940 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4399 = _10474 - 0.12000000476837158203125f;
                bool _6959 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                bool _6965;
                if (_6959)
                {
                    _6965 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                }
                else
                {
                    _6965 = _6959;
                }
                bool _4409;
                if (_6965)
                {
                    uint _6972_dummy_parameter;
                    _4409 = (log(((r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6972_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4399;
                }
                else
                {
                    _4409 = _6965;
                }
                bool _4423;
                if (!_4409)
                {
                    bool _7002 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                    bool _7008;
                    if (_7002)
                    {
                        _7008 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7008 = _7002;
                    }
                    bool _4421;
                    if (_7008)
                    {
                        uint _7015_dummy_parameter;
                        _4421 = (log(((r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7015_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4399;
                    }
                    else
                    {
                        _4421 = _7008;
                    }
                    _4423 = _4421;
                }
                else
                {
                    _4423 = _4409;
                }
                _10488 = _4423;
            }
            else
            {
                _10488 = false;
            }
            _10485 = _10488;
        }
        else
        {
            _10485 = false;
        }
        bool _4428 = _10461 || _10485;
        bool _4433;
        if (_4428)
        {
            bool _7045 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
            bool _7051;
            if (_7045)
            {
                _7051 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
            }
            else
            {
                _7051 = _7045;
            }
            _4433 = _7051;
        }
        else
        {
            _4433 = _4428;
        }
        bool _4438;
        if (_4433)
        {
            bool _7056 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
            bool _7062;
            if (_7056)
            {
                _7062 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
            }
            else
            {
                _7062 = _7056;
            }
            _4438 = _7062;
        }
        else
        {
            _4438 = _4433;
        }
        float4 _10582;
        if (_4438)
        {
            float _4441 = _6920.x;
            float _4443 = _6920.y;
            float _4444 = _4441 + _4443;
            float _4449 = _6920.z + _6920.w;
            float _10503;
            if (_4444 > 0.001000000047497451305389404296875f)
            {
                _10503 = _4441 / _4444;
            }
            else
            {
                _10503 = _4350;
            }
            _10582 = float4(_4441 + (_4449 * _10503), _4443 + (_4449 * (1.0f - _10503)), 0.0f, 0.0f);
        }
        else
        {
            _10582 = _6920;
        }
        bool _7090 = (cbFI_pad0 & 1024u) != 0u;
        bool _7066 = !_7090;
        bool _7067 = !_7066;
        bool _7084;
        if (_7067)
        {
            _7084 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10472.y * cbFI_MvDepthLaneSize.x) + _10472.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7084 = _7066;
        }
        bool _7116;
        if (_7067)
        {
            _7116 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4141.y * cbFI_FlowLaneSize.x) + _4141.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7116 = _7066;
        }
        float _4484 = float(_7116);
        bool _10595;
        float4 _10626;
        float3 _11771;
        if (_7090)
        {
            bool _4494;
            if (_7084)
            {
                _4494 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
            }
            else
            {
                _4494 = _7084;
            }
            bool _4500;
            if (_4494)
            {
                _4500 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
            }
            else
            {
                _4500 = _4494;
            }
            bool _4507;
            if (_7084)
            {
                _4507 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
            }
            else
            {
                _4507 = _7084;
            }
            bool _4513;
            if (_4507)
            {
                _4513 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
            }
            else
            {
                _4513 = _4507;
            }
            bool _4520;
            if (_7116)
            {
                _4520 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
            }
            else
            {
                _4520 = _7116;
            }
            bool _4526;
            if (_4520)
            {
                _4526 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
            }
            else
            {
                _4526 = _4520;
            }
            bool _4533;
            if (_7116)
            {
                _4533 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
            }
            else
            {
                _4533 = _7116;
            }
            bool _4539;
            if (_4533)
            {
                _4539 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
            }
            else
            {
                _4539 = _4533;
            }
            bool _4541 = !_7084;
            if (_4541)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7158;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7158);
                }
            }
            bool _4546 = !_7116;
            if (_4546)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7168;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7168);
                }
            }
            if (_7084 && _4546)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7178;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7178);
                }
            }
            if (_4541 && _7116)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7188;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7188);
                }
            }
            float _4565 = float(_4500);
            float _4567 = float(_4513);
            bool _4570 = _4526 && _4539;
            float _10537;
            if (_4570)
            {
                _10537 = 1.0f;
            }
            else
            {
                _10537 = (_4526 || _4539) ? 0.5f : 0.0f;
            }
            bool _10542;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4500)) && (!_4513))
            {
                bool _4600;
                if (_4570)
                {
                    float _10540;
                    do
                    {
                        bool _7272 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                        bool _7278;
                        if (_7272)
                        {
                            _7278 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7278 = _7272;
                        }
                        bool _7209 = !_7278;
                        bool _7216;
                        if (!_7209)
                        {
                            bool _7283 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                            bool _7289;
                            if (_7283)
                            {
                                _7289 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7289 = _7283;
                            }
                            _7216 = !_7289;
                        }
                        else
                        {
                            _7216 = _7209;
                        }
                        if (_7216)
                        {
                            _10540 = 0.0f;
                            break;
                        }
                        uint _7296_dummy_parameter;
                        uint _7312_dummy_parameter;
                        float4 _7237 = mul(float4((float2(_10445.x, 1.0f - _10445.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7296_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7239 = _7237.w;
                        if (abs(_7239) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10540 = 0.0f;
                            break;
                        }
                        float _7250 = abs(cbFI_DeviceToViewDepth.y / ((_7237.z / _7239) - cbFI_DeviceToViewDepth.x));
                        float _7253 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7312_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10540 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7250 - _7253) / max(max(_7250, _7253), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4600 = _10540 >= 0.5f;
                }
                else
                {
                    _4600 = _4570;
                }
                bool _4608;
                if (_4600)
                {
                    _4608 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4608 = _4600;
                }
                bool _10543;
                if (_4608)
                {
                    uint _7362_dummy_parameter;
                    float2 _10541;
                    do
                    {
                        float _7388 = 1.0f - _10445.y;
                        float4 _7399 = mul(float4((float2(_10445.x, _7388) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7362_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7401 = _7399.w;
                        if (!(_7401 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10541 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7414 = ((_7399.xy / _7401.xx) + 1.0f.xx) * 0.5f;
                        _10541 = float2(_7414.x - _10445.x, _7388 - _7414.y);
                        break;
                    } while(false);
                    float2 _4621 = float2(cbFI_DisplaySize);
                    _10543 = length(((_10445 + _10541) - _10446) * _4621) <= ((0.100000001490116119384765625f * length(_10541 * _4621)) + 8.0f);
                }
                else
                {
                    _10543 = _4600;
                }
                _10542 = _10543;
            }
            else
            {
                _10542 = true;
            }
            bool _4635 = !_10542;
            bool _12564 = _4635 ? false : _4539;
            bool _12565 = _4635 ? false : _4526;
            bool _10596;
            float4 _10627;
            if (!(((_4500 && _4513) && _12565) && _12564))
            {
                float4 _4657 = _10582 * float4(_4565, _4567, float(_12565), float(_12564));
                float _4659 = dot(_4657, 1.0f.xxxx);
                bool _4662 = !(_4659 > 0.0f);
                float4 _10628;
                if (!_4662)
                {
                    _10628 = _4657 / _4659.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7436;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7436);
                    }
                    _10628 = 0.0f.xxxx;
                }
                _10627 = _10628;
                _10596 = _4662;
            }
            else
            {
                _10627 = _10582;
                _10596 = false;
            }
            _11771 = float3(_4565, _4567, _10537);
            _10626 = _10627;
            _10595 = _10596;
        }
        else
        {
            _11771 = float3(float(_7084), _4484, 0.0f);
            _10626 = _10582;
            _10595 = false;
        }
        bool _4680 = !_10595;
        float4 _10690;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4680)
        {
            float _4687 = _10626.x + _10626.y;
            float4 _10691;
            if (_4687 > 0.001000000047497451305389404296875f)
            {
                _10691 = float4(_10626.x / _4687, _10626.y / _4687, 0.0f, 0.0f);
            }
            else
            {
                _10691 = float4(_4350, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10690 = _10691;
        }
        else
        {
            _10690 = _10626;
        }
        float4 _10847;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4680) && _7084)
        {
            float _10685;
            do
            {
                uint4 _7576 = r_warped_motion_qdata_tp1.Load(int3(_10472, 0));
                uint _7577 = _7576.x;
                if (_7577 != 0u)
                {
                    float _10684;
                    if (_7577 == 0u)
                    {
                        _10684 = -1.0f;
                    }
                    else
                    {
                        _10684 = float((_7577 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10685 = _10684;
                    break;
                }
                int _10667;
                uint _10668;
                _10668 = _7577;
                _10667 = -1;
                uint _10683;
                for (; _10667 <= 1; _10668 = _10683, _10667++)
                {
                    _10683 = _10668;
                    for (int _10681 = -1; _10681 <= 1; )
                    {
                        _10683 = max(_10683, r_warped_motion_qdata_tp1.Load(int3(clamp(_10472 + int2(_10681, _10667), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10681++;
                        continue;
                    }
                }
                if (_10668 != 0u)
                {
                    float _10680;
                    if (_10668 == 0u)
                    {
                        _10680 = -1.0f;
                    }
                    else
                    {
                        _10680 = float((_10668 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10685 = _10680;
                    break;
                }
                uint _10670;
                _10670 = 4294967295u;
                uint _12535;
                for (int _10669 = 0; _10669 < 8; _10670 = _12535, _10669++)
                {
                    int _10673 = 0;
                    for (;;)
                    {
                        if (_10673 < 5)
                        {
                            int2 _7527 = _10472 + (_1085[_10669] * _1094[_10673].xx);
                            bool _7530 = any(bool2(_7527.x < int2(0, 0).x, _7527.y < int2(0, 0).y));
                            bool _7538;
                            if (!_7530)
                            {
                                _7538 = any(bool2(_7527.x >= cbFI_MvDepthLaneSize.x, _7527.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7538 = _7530;
                            }
                            if (_7538)
                            {
                                _12535 = _10670;
                                break;
                            }
                            uint4 _7616 = r_warped_motion_qdata_tp1.Load(int3(_7527, 0));
                            uint _7617 = _7616.x;
                            if (_7617 != 0u)
                            {
                                _12535 = min(_10670, _7617);
                                break;
                            }
                            _10673++;
                            continue;
                        }
                        else
                        {
                            _12535 = _10670;
                            break;
                        }
                    }
                }
                float _10672;
                if (_10670 == 4294967295u)
                {
                    _10672 = -1.0f;
                }
                else
                {
                    float _10671;
                    if (_10670 == 0u)
                    {
                        _10671 = -1.0f;
                    }
                    else
                    {
                        _10671 = float((_10670 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10672 = _10671;
                }
                _10685 = _10672;
                break;
            } while(false);
            float _4723 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4725 = _10685 < 0.0f;
            bool _4730;
            if (_4725)
            {
                bool _7636 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
                bool _7642;
                if (_7636)
                {
                    _7642 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
                }
                else
                {
                    _7642 = _7636;
                }
                _4730 = _7642;
            }
            else
            {
                _4730 = _4725;
            }
            bool _4735;
            if (_4730)
            {
                bool _7647 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                bool _7653;
                if (_7647)
                {
                    _7653 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                }
                else
                {
                    _7653 = _7647;
                }
                _4735 = _7653;
            }
            else
            {
                _4735 = _4730;
            }
            float4 _10747;
            if (_4735)
            {
                uint _7660_dummy_parameter;
                float _7684 = log(((r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7660_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7692_dummy_parameter;
                float _7716 = log(((r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7692_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4746 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4753;
                if (_4746)
                {
                    _4753 = _7716 > (_7684 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4753 = _4746;
                }
                float4 _10721;
                if (_4753)
                {
                    _10721 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10721 = 1.0f.xxxx;
                }
                bool _4760 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4767;
                if (_4760)
                {
                    _4767 = _7684 > (_7716 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4767 = _4760;
                }
                float4 _10750;
                if (_4767)
                {
                    float4 _10276 = _10721;
                    _10276.x = 0.0f;
                    _10750 = _10276;
                }
                else
                {
                    _10750 = _10721;
                }
                _10747 = _10750;
            }
            else
            {
                bool _4775 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4781;
                if (_4775)
                {
                    _4781 = _10690.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4781 = _4775;
                }
                bool _4786;
                if (_4781)
                {
                    bool _7722 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                    bool _7728;
                    if (_7722)
                    {
                        _7728 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7728 = _7722;
                    }
                    _4786 = _7728;
                }
                else
                {
                    _4786 = _4781;
                }
                float4 _10748;
                if (_4786)
                {
                    float _10708;
                    if (_10685 >= 0.0f)
                    {
                        _10708 = _10685 - _4723;
                    }
                    else
                    {
                        float _10704;
                        _10704 = 2.0f;
                        float _7785;
                        for (int _10703 = 0; _10703 < 24; _10704 = _7785, _10703++)
                        {
                            float _7749 = float(_10703 & 7) * 0.785398185253143310546875f;
                            int _7751 = _10703 >> 3;
                            int _10705;
                            if (_7751 == 0)
                            {
                                _10705 = 16;
                            }
                            else
                            {
                                _10705 = (_7751 == 1) ? 48 : 96;
                            }
                            uint _7817_dummy_parameter;
                            _7785 = min(_10704, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10444 + ((cbFI_MvDepthLaneSizeRcp * float(_10705)) * float2(cos(_7749), sin(_7749))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7817_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10708 = _10704;
                    }
                    uint _7849_dummy_parameter;
                    float4 _10749;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7849_dummy_parameter))))), 0)).x) > ((exp((_10708 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10749 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10749 = 1.0f.xxxx;
                    }
                    _10748 = _10749;
                }
                else
                {
                    _10748 = 1.0f.xxxx;
                }
                _10747 = _10748;
            }
            bool _4812 = _10685 >= 0.0f;
            bool _4819;
            if (_4812)
            {
                _4819 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4819 = _4812;
            }
            bool _4825;
            if (_4819)
            {
                _4825 = _10690.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4825 = _4819;
            }
            bool _4830;
            if (_4825)
            {
                bool _7874 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
                bool _7880;
                if (_7874)
                {
                    _7880 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
                }
                else
                {
                    _7880 = _7874;
                }
                _4830 = _7880;
            }
            else
            {
                _4830 = _4825;
            }
            float4 _10764;
            if (_4830)
            {
                float _10741;
                if (_4812)
                {
                    _10741 = _10685 - _4723;
                }
                else
                {
                    float _10737;
                    _10737 = 2.0f;
                    float _7937;
                    for (int _10736 = 0; _10736 < 24; _10737 = _7937, _10736++)
                    {
                        float _7901 = float(_10736 & 7) * 0.785398185253143310546875f;
                        int _7903 = _10736 >> 3;
                        int _10738;
                        if (_7903 == 0)
                        {
                            _10738 = 16;
                        }
                        else
                        {
                            _10738 = (_7903 == 1) ? 48 : 96;
                        }
                        uint _7953_dummy_parameter;
                        _7937 = min(_10737, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10442 + ((cbFI_MvDepthLaneSizeRcp * float(_10738)) * float2(cos(_7901), sin(_7901))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7953_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10741 = _10737;
                }
                uint _8001_dummy_parameter;
                float4 _10765;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8001_dummy_parameter))))), 0)).x) > ((exp((_10741 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10282 = _10747;
                    _10282.x = 0.0f;
                    _10765 = _10282;
                }
                else
                {
                    _10765 = _10747;
                }
                _10764 = _10765;
            }
            else
            {
                _10764 = _10747;
            }
            float4 _10777;
            if (_4812)
            {
                float _8028 = (exp(((_10685 - _4723) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4865 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4871;
                if (_4865)
                {
                    _4871 = _10690.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4871 = _4865;
                }
                bool _4876;
                if (_4871)
                {
                    bool _8033 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                    bool _8039;
                    if (_8033)
                    {
                        _8039 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8039 = _8033;
                    }
                    _4876 = _8039;
                }
                else
                {
                    _4876 = _4871;
                }
                bool _4884;
                if (_4876)
                {
                    uint _8046_dummy_parameter;
                    _4884 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8046_dummy_parameter))))), 0)).x) > _8028;
                }
                else
                {
                    _4884 = _4876;
                }
                float4 _10775;
                if (_4884)
                {
                    float4 _10285 = _10764;
                    _10285.w = 0.0f;
                    _10775 = _10285;
                }
                else
                {
                    _10775 = _10764;
                }
                bool _4891 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4897;
                if (_4891)
                {
                    _4897 = _10690.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4897 = _4891;
                }
                bool _4902;
                if (_4897)
                {
                    bool _8064 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                    bool _8070;
                    if (_8064)
                    {
                        _8070 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8070 = _8064;
                    }
                    _4902 = _8070;
                }
                else
                {
                    _4902 = _4897;
                }
                bool _4910;
                if (_4902)
                {
                    uint _8077_dummy_parameter;
                    _4910 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8077_dummy_parameter))))), 0)).x) > _8028;
                }
                else
                {
                    _4910 = _4902;
                }
                float4 _10778;
                if (_4910)
                {
                    float4 _10288 = _10775;
                    _10288.z = 0.0f;
                    _10778 = _10288;
                }
                else
                {
                    _10778 = _10775;
                }
                _10777 = _10778;
            }
            else
            {
                _10777 = _10764;
            }
            float4 _10848;
            if (any(bool4(_10777.x < 1.0f.xxxx.x, _10777.y < 1.0f.xxxx.y, _10777.z < 1.0f.xxxx.z, _10777.w < 1.0f.xxxx.w)))
            {
                float4 _4921 = _10690 * _10777;
                float _4923 = dot(_4921, 1.0f.xxxx);
                float4 _10849;
                if (_4923 > 0.0f)
                {
                    _10849 = _4921 / _4923.xxxx;
                }
                else
                {
                    bool _4934 = _10777.y == 0.0f;
                    bool _4940;
                    if (_4934)
                    {
                        _4940 = _10777.x > 0.0f;
                    }
                    else
                    {
                        _4940 = _4934;
                    }
                    bool _4945;
                    if (_4940)
                    {
                        bool _8095 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
                        bool _8101;
                        if (_8095)
                        {
                            _8101 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8101 = _8095;
                        }
                        _4945 = _8101;
                    }
                    else
                    {
                        _4945 = _4940;
                    }
                    float4 _10850;
                    if (_4945)
                    {
                        _10850 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4950 = _10777.x == 0.0f;
                        bool _4956;
                        if (_4950)
                        {
                            _4956 = _10777.y > 0.0f;
                        }
                        else
                        {
                            _4956 = _4950;
                        }
                        bool _4961;
                        if (_4956)
                        {
                            bool _8106 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                            bool _8112;
                            if (_8106)
                            {
                                _8112 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8112 = _8106;
                            }
                            _4961 = _8112;
                        }
                        else
                        {
                            _4961 = _4956;
                        }
                        bool4 _12566 = _4961.xxxx;
                        _10850 = float4(_12566.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10690.x, _12566.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10690.y, _12566.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10690.z, _12566.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10690.w);
                    }
                    _10849 = _10850;
                }
                _10848 = _10849;
            }
            else
            {
                _10848 = _10690;
            }
            _10847 = _10848;
        }
        else
        {
            _10847 = _10690;
        }
        float4 _11435;
        bool _11455;
        float3 _11569;
        if (((cbFI_pad0 & 32768u) != 0u) && _4680)
        {
            bool _4978 = _10847.x > 0.00999999977648258209228515625f;
            bool _4981 = _10847.y > 0.00999999977648258209228515625f;
            bool _4990 = (_10847.z + _10847.w) > 0.0199999995529651641845703125f;
            bool _4996;
            if (_4990)
            {
                bool _8117 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                bool _8123;
                if (_8117)
                {
                    _8123 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                }
                else
                {
                    _8123 = _8117;
                }
                _4996 = _8123;
            }
            else
            {
                _4996 = _4990;
            }
            bool _5001;
            if (_4996)
            {
                bool _8128 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                bool _8134;
                if (_8128)
                {
                    _8134 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                }
                else
                {
                    _8134 = _8128;
                }
                _5001 = _8134;
            }
            else
            {
                _5001 = _4996;
            }
            bool _5008;
            if (_5001)
            {
                float _10858;
                do
                {
                    bool _8217 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                    bool _8223;
                    if (_8217)
                    {
                        _8223 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8223 = _8217;
                    }
                    bool _8154 = !_8223;
                    bool _8161;
                    if (!_8154)
                    {
                        bool _8228 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                        bool _8234;
                        if (_8228)
                        {
                            _8234 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8234 = _8228;
                        }
                        _8161 = !_8234;
                    }
                    else
                    {
                        _8161 = _8154;
                    }
                    if (_8161)
                    {
                        _10858 = 0.0f;
                        break;
                    }
                    uint _8241_dummy_parameter;
                    uint _8257_dummy_parameter;
                    float4 _8182 = mul(float4((float2(_10445.x, 1.0f - _10445.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8241_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8184 = _8182.w;
                    if (abs(_8184) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10858 = 0.0f;
                        break;
                    }
                    float _8195 = abs(cbFI_DeviceToViewDepth.y / ((_8182.z / _8184) - cbFI_DeviceToViewDepth.x));
                    float _8198 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8257_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10858 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8195 - _8198) / max(max(_8195, _8198), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5008 = _10858 < 0.5f;
            }
            else
            {
                _5008 = _5001;
            }
            float4 _10873;
            if (_5008)
            {
                uint _8307_dummy_parameter;
                uint _8338_dummy_parameter;
                float4 _10874;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8307_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8338_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10874 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10874 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10873 = _10874;
            }
            else
            {
                _10873 = 1.0f.xxxx;
            }
            bool _5032;
            if (_7084)
            {
                bool _8367 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
                bool _8373;
                if (_8367)
                {
                    _8373 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
                }
                else
                {
                    _8373 = _8367;
                }
                _5032 = _8373;
            }
            else
            {
                _5032 = _7084;
            }
            bool _5038;
            if (_7084)
            {
                bool _8378 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                bool _8384;
                if (_8378)
                {
                    _8384 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                }
                else
                {
                    _8384 = _8378;
                }
                _5038 = _8384;
            }
            else
            {
                _5038 = _7084;
            }
            bool _5044;
            if (_7116)
            {
                bool _8389 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                bool _8395;
                if (_8389)
                {
                    _8395 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                }
                else
                {
                    _8395 = _8389;
                }
                _5044 = _8395;
            }
            else
            {
                _5044 = _7116;
            }
            bool _5050;
            if (_7116)
            {
                bool _8400 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                bool _8406;
                if (_8400)
                {
                    _8406 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                }
                else
                {
                    _8406 = _8400;
                }
                _5050 = _8406;
            }
            else
            {
                _5050 = _7116;
            }
            bool _5053 = _5044 != _5050;
            bool _5059;
            if (_5053)
            {
                _5059 = _5032 || _5038;
            }
            else
            {
                _5059 = _5053;
            }
            float4 _10982;
            if (_5059)
            {
                float4 _10315 = _10873;
                _10315.z = 0.0f;
                _10315.w = 0.0f;
                _10982 = _10315;
            }
            else
            {
                _10982 = _10873;
            }
            bool _5066 = _5032 && _4978;
            bool _5069 = _5038 && _4981;
            float4 _11087;
            float3 _11669;
            if (_5066 || _5069)
            {
                float _10977;
                do
                {
                    uint4 _8545 = r_warped_motion_qdata_tp1.Load(int3(_10472, 0));
                    uint _8546 = _8545.x;
                    if (_8546 != 0u)
                    {
                        float _10976;
                        if (_8546 == 0u)
                        {
                            _10976 = -1.0f;
                        }
                        else
                        {
                            _10976 = float((_8546 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10977 = _10976;
                        break;
                    }
                    int _10959;
                    uint _10960;
                    _10960 = _8546;
                    _10959 = -1;
                    uint _10975;
                    for (; _10959 <= 1; _10960 = _10975, _10959++)
                    {
                        _10975 = _10960;
                        for (int _10973 = -1; _10973 <= 1; )
                        {
                            _10975 = max(_10975, r_warped_motion_qdata_tp1.Load(int3(clamp(_10472 + int2(_10973, _10959), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10973++;
                            continue;
                        }
                    }
                    if (_10960 != 0u)
                    {
                        float _10972;
                        if (_10960 == 0u)
                        {
                            _10972 = -1.0f;
                        }
                        else
                        {
                            _10972 = float((_10960 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10977 = _10972;
                        break;
                    }
                    uint _10962;
                    _10962 = 4294967295u;
                    uint _12536;
                    for (int _10961 = 0; _10961 < 8; _10962 = _12536, _10961++)
                    {
                        int _10965 = 0;
                        for (;;)
                        {
                            if (_10965 < 5)
                            {
                                int2 _8496 = _10472 + (_1085[_10961] * _1094[_10965].xx);
                                bool _8499 = any(bool2(_8496.x < int2(0, 0).x, _8496.y < int2(0, 0).y));
                                bool _8507;
                                if (!_8499)
                                {
                                    _8507 = any(bool2(_8496.x >= cbFI_MvDepthLaneSize.x, _8496.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8507 = _8499;
                                }
                                if (_8507)
                                {
                                    _12536 = _10962;
                                    break;
                                }
                                uint4 _8585 = r_warped_motion_qdata_tp1.Load(int3(_8496, 0));
                                uint _8586 = _8585.x;
                                if (_8586 != 0u)
                                {
                                    _12536 = min(_10962, _8586);
                                    break;
                                }
                                _10965++;
                                continue;
                            }
                            else
                            {
                                _12536 = _10962;
                                break;
                            }
                        }
                    }
                    float _10964;
                    if (_10962 == 4294967295u)
                    {
                        _10964 = -1.0f;
                    }
                    else
                    {
                        float _10963;
                        if (_10962 == 0u)
                        {
                            _10963 = -1.0f;
                        }
                        else
                        {
                            _10963 = float((_10962 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10964 = _10963;
                    }
                    _10977 = _10964;
                    break;
                } while(false);
                bool _5077 = _10977 < 0.0f;
                float _10978;
                if (_5077)
                {
                    _10978 = 0.0f;
                }
                else
                {
                    _10978 = _10977 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8607_dummy_parameter;
                uint _8639_dummy_parameter;
                float4 _11015;
                if ((_5077 && _5066) && _5069)
                {
                    uint _8671_dummy_parameter;
                    float _8695 = log(((r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8671_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8703_dummy_parameter;
                    float _8727 = log(((r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8703_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11016;
                    if (_8695 > (_8727 + 0.07999999821186065673828125f))
                    {
                        float4 _10319 = _10982;
                        _10319.x = 0.0f;
                        _11016 = _10319;
                    }
                    else
                    {
                        float4 _11017;
                        if (_8727 > (_8695 + 0.07999999821186065673828125f))
                        {
                            float4 _10321 = _10982;
                            _10321.y = 0.0f;
                            _11017 = _10321;
                        }
                        else
                        {
                            _11017 = _10982;
                        }
                        _11016 = _11017;
                    }
                    _11015 = _11016;
                }
                else
                {
                    _11015 = _10982;
                }
                float _5129 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5131 = _10977 >= 0.0f;
                float _10998;
                if (_5131)
                {
                    _10998 = _10977 - _5129;
                }
                else
                {
                    float _10994;
                    if (_5066)
                    {
                        float _10993;
                        _10993 = 2.0f;
                        float _8785;
                        for (int _10992 = 0; _10992 < 24; _10993 = _8785, _10992++)
                        {
                            float _8749 = float(_10992 & 7) * 0.785398185253143310546875f;
                            int _8751 = _10992 >> 3;
                            int _10995;
                            if (_8751 == 0)
                            {
                                _10995 = 16;
                            }
                            else
                            {
                                _10995 = (_8751 == 1) ? 48 : 96;
                            }
                            uint _8801_dummy_parameter;
                            _8785 = min(_10993, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10442 + ((cbFI_MvDepthLaneSizeRcp * float(_10995)) * float2(cos(_8749), sin(_8749))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8801_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10994 = _10993;
                    }
                    else
                    {
                        _10994 = 0.0f;
                    }
                    _10998 = _10994;
                }
                float _11005;
                if (_5131)
                {
                    _11005 = _10977 - _5129;
                }
                else
                {
                    float _11001;
                    if (_5069)
                    {
                        float _11000;
                        _11000 = 2.0f;
                        float _8899;
                        for (int _10999 = 0; _10999 < 24; _11000 = _8899, _10999++)
                        {
                            float _8863 = float(_10999 & 7) * 0.785398185253143310546875f;
                            int _8865 = _10999 >> 3;
                            int _11002;
                            if (_8865 == 0)
                            {
                                _11002 = 16;
                            }
                            else
                            {
                                _11002 = (_8865 == 1) ? 48 : 96;
                            }
                            uint _8931_dummy_parameter;
                            _8899 = min(_11000, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10444 + ((cbFI_MvDepthLaneSizeRcp * float(_11002)) * float2(cos(_8863), sin(_8863))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8931_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11001 = _11000;
                    }
                    else
                    {
                        _11001 = 0.0f;
                    }
                    _11005 = _11001;
                }
                float _11006;
                if (_5066)
                {
                    uint _8963_dummy_parameter;
                    _11006 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8963_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11006 = 0.0f;
                }
                float _11007;
                if (_5069)
                {
                    uint _8983_dummy_parameter;
                    _11007 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8983_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11007 = 0.0f;
                }
                bool _5186;
                if (_5066)
                {
                    _5186 = _11006 > ((exp((_10998 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5186 = _5066;
                }
                float4 _11023;
                if (_5186)
                {
                    float4 _10323 = _11015;
                    _10323.x = 0.0f;
                    _11023 = _10323;
                }
                else
                {
                    _11023 = _11015;
                }
                bool _5198;
                if (_5069)
                {
                    _5198 = _11007 > ((exp((_11005 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5198 = _5069;
                }
                float4 _11025;
                if (_5198)
                {
                    float4 _10325 = _11023;
                    _10325.y = 0.0f;
                    _11025 = _10325;
                }
                else
                {
                    _11025 = _11023;
                }
                float4 _11088;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5131)
                {
                    bool _5218;
                    if (_5066)
                    {
                        _5218 = _11006 < ((exp((_10998 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5218 = _5066;
                    }
                    float4 _11027;
                    if (_5218)
                    {
                        float4 _10327 = _11025;
                        _10327.x = 0.0f;
                        _11027 = _10327;
                    }
                    else
                    {
                        _11027 = _11025;
                    }
                    bool _5230;
                    if (_5069)
                    {
                        _5230 = _11007 < ((exp((_11005 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5230 = _5069;
                    }
                    float4 _11089;
                    if (_5230)
                    {
                        float4 _10329 = _11027;
                        _10329.y = 0.0f;
                        _11089 = _10329;
                    }
                    else
                    {
                        _11089 = _11027;
                    }
                    _11088 = _11089;
                }
                else
                {
                    _11088 = _11025;
                }
                _11669 = float3(_10978, log(((r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8607_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8639_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _11087 = _11088;
            }
            else
            {
                _11669 = float3(0.0f, 0.0f, 0.5f);
                _11087 = _10982;
            }
            bool _5241 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4990;
            bool _5247;
            if (_5241)
            {
                _5247 = _5044 || _5050;
            }
            else
            {
                _5247 = _5241;
            }
            float4 _11110;
            if (_5247)
            {
                float _11082;
                do
                {
                    uint4 _9163 = r_warped_motion_qdata_tp1.Load(int3(_10472, 0));
                    uint _9164 = _9163.x;
                    if (_9164 != 0u)
                    {
                        float _11081;
                        if (_9164 == 0u)
                        {
                            _11081 = -1.0f;
                        }
                        else
                        {
                            _11081 = float((_9164 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11082 = _11081;
                        break;
                    }
                    int _11064;
                    uint _11065;
                    _11065 = _9164;
                    _11064 = -1;
                    uint _11080;
                    for (; _11064 <= 1; _11065 = _11080, _11064++)
                    {
                        _11080 = _11065;
                        for (int _11078 = -1; _11078 <= 1; )
                        {
                            _11080 = max(_11080, r_warped_motion_qdata_tp1.Load(int3(clamp(_10472 + int2(_11078, _11064), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11078++;
                            continue;
                        }
                    }
                    if (_11065 != 0u)
                    {
                        float _11077;
                        if (_11065 == 0u)
                        {
                            _11077 = -1.0f;
                        }
                        else
                        {
                            _11077 = float((_11065 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11082 = _11077;
                        break;
                    }
                    uint _11067;
                    _11067 = 4294967295u;
                    uint _12537;
                    for (int _11066 = 0; _11066 < 8; _11067 = _12537, _11066++)
                    {
                        int _11070 = 0;
                        for (;;)
                        {
                            if (_11070 < 5)
                            {
                                int2 _9114 = _10472 + (_1085[_11066] * _1094[_11070].xx);
                                bool _9117 = any(bool2(_9114.x < int2(0, 0).x, _9114.y < int2(0, 0).y));
                                bool _9125;
                                if (!_9117)
                                {
                                    _9125 = any(bool2(_9114.x >= cbFI_MvDepthLaneSize.x, _9114.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9125 = _9117;
                                }
                                if (_9125)
                                {
                                    _12537 = _11067;
                                    break;
                                }
                                uint4 _9203 = r_warped_motion_qdata_tp1.Load(int3(_9114, 0));
                                uint _9204 = _9203.x;
                                if (_9204 != 0u)
                                {
                                    _12537 = min(_11067, _9204);
                                    break;
                                }
                                _11070++;
                                continue;
                            }
                            else
                            {
                                _12537 = _11067;
                                break;
                            }
                        }
                    }
                    float _11069;
                    if (_11067 == 4294967295u)
                    {
                        _11069 = -1.0f;
                    }
                    else
                    {
                        float _11068;
                        if (_11067 == 0u)
                        {
                            _11068 = -1.0f;
                        }
                        else
                        {
                            _11068 = float((_11067 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11069 = _11068;
                    }
                    _11082 = _11069;
                    break;
                } while(false);
                float4 _11111;
                if (_11082 >= 0.0f)
                {
                    float _9225 = (exp((_11082 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5266;
                    if (_5044)
                    {
                        uint _9232_dummy_parameter;
                        _5266 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9232_dummy_parameter))))), 0)).x) > _9225;
                    }
                    else
                    {
                        _5266 = _5044;
                    }
                    float4 _11100;
                    if (_5266)
                    {
                        float4 _10331 = _11087;
                        _10331.z = 0.0f;
                        _11100 = _10331;
                    }
                    else
                    {
                        _11100 = _11087;
                    }
                    bool _5278;
                    if (_5050)
                    {
                        uint _9252_dummy_parameter;
                        _5278 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9252_dummy_parameter))))), 0)).x) > _9225;
                    }
                    else
                    {
                        _5278 = _5050;
                    }
                    float4 _11112;
                    if (_5278)
                    {
                        float4 _10333 = _11100;
                        _10333.w = 0.0f;
                        _11112 = _10333;
                    }
                    else
                    {
                        _11112 = _11100;
                    }
                    _11111 = _11112;
                }
                else
                {
                    _11111 = _11087;
                }
                _11110 = _11111;
            }
            else
            {
                _11110 = _11087;
            }
            bool _5286 = _5032 != _5038;
            bool _5293;
            if (_5286)
            {
                _5293 = _5032 ? _4978 : _4981;
            }
            else
            {
                _5293 = _5286;
            }
            bool _5300;
            if (_5293)
            {
                _5300 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5300 = _5293;
            }
            float4 _11195;
            if (_5300)
            {
                bool2 _5305 = _5032.xx;
                float2 _5306 = float2(_5305.x ? _10442.x : _10444.x, _5305.y ? _10442.y : _10444.y);
                float _11102;
                if (_5032)
                {
                    uint _9272_dummy_parameter;
                    _11102 = r_depth_tm1.Load(int3(int2(floor(_5306 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9272_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9288_dummy_parameter;
                    _11102 = r_depth_tp1.Load(int3(int2(floor(_5306 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9288_dummy_parameter))))), 0)).x;
                }
                float4x4 _11103;
                if (_5032)
                {
                    _11103 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11103 = cbFI_MotionTP1ToTM1;
                }
                float2 _11104;
                do
                {
                    float _9315 = _5306.x;
                    float _9318 = 1.0f - _5306.y;
                    float4 _9329 = mul(float4((float2(_9315, _9318) * 2.0f) - 1.0f.xx, _11102, 1.0f), _11103);
                    float _9331 = _9329.w;
                    if (!(_9331 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11104 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9344 = ((_9329.xy / _9331.xx) + 1.0f.xx) * 0.5f;
                    _11104 = float2(_9344.x - _9315, _9318 - _9344.y);
                    break;
                } while(false);
                float2 _5336 = float2(cbFI_DisplaySize);
                float4 _11196;
                if (!(length(((_5306 + _11104) - float2(_5305.x ? _10444.x : _10442.x, _5305.y ? _10444.y : _10442.y)) * _5336) <= ((0.100000001490116119384765625f * length(_11104 * _5336)) + 8.0f)))
                {
                    float4 _11197;
                    if (_5032)
                    {
                        float4 _10343 = _11110;
                        _10343.x = 0.0f;
                        _11197 = _10343;
                    }
                    else
                    {
                        float4 _10345 = _11110;
                        _10345.y = 0.0f;
                        _11197 = _10345;
                    }
                    _11196 = _11197;
                }
                else
                {
                    _11196 = _11110;
                }
                _11195 = _11196;
            }
            else
            {
                _11195 = _11110;
            }
            float4 _5361 = _10847 * _11195;
            float _5363 = dot(_5361, 1.0f.xxxx);
            float4 _11436;
            bool _11456;
            if (_5363 > 0.0f)
            {
                _11456 = _10595;
                _11436 = _5361 / _5363.xxxx;
            }
            else
            {
                bool _5374 = any(bool4(_11195.x < 1.0f.xxxx.x, _11195.y < 1.0f.xxxx.y, _11195.z < 1.0f.xxxx.z, _11195.w < 1.0f.xxxx.w));
                if (_5374)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9366;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9366);
                    }
                }
                bool4 _12569 = _5374.xxxx;
                _11456 = _5374 ? true : _10595;
                _11436 = float4(_12569.x ? 0.0f.xxxx.x : _10847.x, _12569.y ? 0.0f.xxxx.y : _10847.y, _12569.z ? 0.0f.xxxx.z : _10847.z, _12569.w ? 0.0f.xxxx.w : _10847.w);
            }
            _11569 = _11669;
            _11455 = _11456;
            _11435 = _11436;
        }
        else
        {
            _11569 = float3(0.0f, 0.0f, 0.5f);
            _11455 = _10595;
            _11435 = _10847;
        }
        uint _5383 = (cbFI_pad0 >> 24u) & 31u;
        uint _5387 = (cbFI_pad0 >> 16u) & 255u;
        bool _5389 = _5383 != 0u;
        bool _5391 = _5387 == 12u;
        bool _5394 = _5387 == 13u;
        float4 _11452;
        if ((_5389 || _5391) || _5394)
        {
            float _11198;
            do
            {
                bool _9450 = all(bool2(_10445.x > 0.0f.xx.x, _10445.y > 0.0f.xx.y));
                bool _9456;
                if (_9450)
                {
                    _9456 = all(bool2(_10445.x < 1.0f.xx.x, _10445.y < 1.0f.xx.y));
                }
                else
                {
                    _9456 = _9450;
                }
                bool _9387 = !_9456;
                bool _9394;
                if (!_9387)
                {
                    bool _9461 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
                    bool _9467;
                    if (_9461)
                    {
                        _9467 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9467 = _9461;
                    }
                    _9394 = !_9467;
                }
                else
                {
                    _9394 = _9387;
                }
                if (_9394)
                {
                    _11198 = 0.0f;
                    break;
                }
                uint _9474_dummy_parameter;
                uint _9490_dummy_parameter;
                float4 _9415 = mul(float4((float2(_10445.x, 1.0f - _10445.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10445 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9474_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9417 = _9415.w;
                if (abs(_9417) < 9.9999999747524270787835121154785e-07f)
                {
                    _11198 = 0.0f;
                    break;
                }
                float _9428 = abs(cbFI_DeviceToViewDepth.y / ((_9415.z / _9417) - cbFI_DeviceToViewDepth.x));
                float _9431 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9490_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11198 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9428 - _9431) / max(max(_9428, _9431), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9538 = all(bool2(_10446.x > 0.0f.xx.x, _10446.y > 0.0f.xx.y));
            bool _9544;
            if (_9538)
            {
                _9544 = all(bool2(_10446.x < 1.0f.xx.x, _10446.y < 1.0f.xx.y));
            }
            else
            {
                _9544 = _9538;
            }
            float _11199;
            if (_9544)
            {
                uint _9551_dummy_parameter;
                _11199 = length((_6170 + (r_motion_tp1.Load(int3(int2(floor(_10446 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9551_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11199 = 1000000.0f;
            }
            float _11210;
            if ((_5383 & 1u) != 0u)
            {
                _11210 = _11198;
            }
            else
            {
                _11210 = 1.0f;
            }
            float _11211;
            if ((_5383 & 2u) != 0u)
            {
                _11211 = _11210 * (1.0f - smoothstep(2.0f, 8.0f, _11199));
            }
            else
            {
                _11211 = _11210;
            }
            float _11212;
            if ((_5383 & 4u) != 0u)
            {
                _11212 = _11211 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6891 - _6899) - length(_6875 - _6883))));
            }
            else
            {
                _11212 = _11211;
            }
            float _11446;
            if ((_5383 & 8u) != 0u)
            {
                _11446 = lerp(1.0f, _11212, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6875 - _6883)));
            }
            else
            {
                _11446 = _11212;
            }
            bool _5469 = (_5383 & 16u) != 0u;
            bool _5478;
            if (_5469)
            {
                _5478 = length(_10440 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5478 = _5469;
            }
            float _12571 = _5478 ? 1.0f : _11446;
            bool _5484 = _5389 && _7084;
            bool _5489;
            if (_5484)
            {
                bool _9576 = all(bool2(_10442.x > 0.0f.xx.x, _10442.y > 0.0f.xx.y));
                bool _9582;
                if (_9576)
                {
                    _9582 = all(bool2(_10442.x < 1.0f.xx.x, _10442.y < 1.0f.xx.y));
                }
                else
                {
                    _9582 = _9576;
                }
                _5489 = _9582;
            }
            else
            {
                _5489 = _5484;
            }
            bool _5494;
            if (_5489)
            {
                bool _9587 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                bool _9593;
                if (_9587)
                {
                    _9593 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                }
                else
                {
                    _9593 = _9587;
                }
                _5494 = _9593;
            }
            else
            {
                _5494 = _5489;
            }
            float4 _11453;
            if (_5494)
            {
                float _5500 = _11435.x + _11435.y;
                float _5509 = (_11435.z + _11435.w) * (1.0f - _12571);
                float _11449;
                if (_5500 > 9.9999997473787516355514526367188e-06f)
                {
                    _11449 = _11435.x / _5500;
                }
                else
                {
                    _11449 = _4350;
                }
                _11453 = float4(_11435.x + (_5509 * _11449), _11435.y + (_5509 * (1.0f - _11449)), _11435.zw * _12571);
            }
            else
            {
                _11453 = _11435;
            }
            _11452 = _11453;
        }
        else
        {
            _11452 = _11435;
        }
        float3 _12339;
        if (_11455)
        {
            float3 _9599 = r_current_interpolation_source.Load(int3(_3722, 0)).xyz;
            float3 _12340;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7084)
            {
                uint _9606_dummy_parameter;
                float _11560;
                _11560 = r_depth_tm1.Load(int3(int2(floor(_10442 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9606_dummy_parameter))))), 0)).x;
                float _5621;
                for (int _11559 = 0; _11559 < 24; _11560 = _5621, _11559++)
                {
                    float _5593 = float(_11559 & 7) * 0.785398185253143310546875f;
                    int _5595 = _11559 >> 3;
                    int _12390;
                    if (_5595 == 0)
                    {
                        _12390 = 16;
                    }
                    else
                    {
                        _12390 = (_5595 == 1) ? 48 : 96;
                    }
                    uint _9626_dummy_parameter;
                    _5621 = max(_11560, r_depth_tm1.Load(int3(int2(floor(clamp(_10442 + ((cbFI_MvDepthLaneSizeRcp * float(_12390)) * float2(cos(_5593), sin(_5593))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9626_dummy_parameter))))), 0)).x);
                }
                float2 _11561;
                do
                {
                    float _9648 = 1.0f - _10442.y;
                    float4 _9659 = mul(float4((float2(_10442.x, _9648) * 2.0f) - 1.0f.xx, _11560, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9661 = _9659.w;
                    if (!(_9661 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11561 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9674 = ((_9659.xy / _9661.xx) + 1.0f.xx) * 0.5f;
                    _11561 = float2(_9674.x - _10442.x, _9648 - _9674.y);
                    break;
                } while(false);
                float2 _5632 = _10442 + _11561;
                bool _9692 = all(bool2(_5632.x > 0.0f.xx.x, _5632.y > 0.0f.xx.y));
                bool _9698;
                if (_9692)
                {
                    _9698 = all(bool2(_5632.x < 1.0f.xx.x, _5632.y < 1.0f.xx.y));
                }
                else
                {
                    _9698 = _9692;
                }
                float3 _12341;
                if (_9698)
                {
                    float _5638 = abs(cbFI_DeviceToViewDepth.y / (_11560 - cbFI_DeviceToViewDepth.x));
                    uint _9718_dummy_parameter;
                    int2 _9718 = int2(spvTextureSize(r_depth_m2, uint(0), _9718_dummy_parameter));
                    float _5642 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5632 * float2(_9718))), int2(0, 0), _9718 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12346;
                    if (abs(_5642 - _5638) <= (0.20000000298023223876953125f * max(_5642, _5638)))
                    {
                        uint _9752_dummy_parameter;
                        int2 _9752 = int2(spvTextureSize(r_colour_m2, uint(0), _9752_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9775;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9775);
                        }
                        _12346 = r_colour_m2.Load(int3(clamp(int2(floor(_5632 * float2(_9752))), int2(0, 0), _9752 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9785;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9785);
                        }
                        _12346 = _9599;
                    }
                    _12341 = _12346;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9795;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9795);
                    }
                    _12341 = _9599;
                }
                _12340 = _12341;
            }
            else
            {
                _12340 = _9599;
            }
            _12339 = _12340;
        }
        else
        {
            _12339 = (((_6875 * _11452.x) + (_6883 * _11452.y)) + (_6891 * _11452.z)) + (_6899 * _11452.w);
        }
        uint _5670 = cbFI_pad0 & 255u;
        bool _12231;
        float3 _12338;
        if (_5670 != 0u)
        {
            float3 _5675 = r_present_backbuffer.Load(int3(_3722, 0)).xyz;
            float3 _5679 = r_current_interpolation_source.Load(int3(_3722, 0)).xyz;
            float3 _5683 = abs(_5675 - _5679);
            float3 _11564;
            if (_5670 == 2u)
            {
                _11564 = (abs(_5679) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11564 = 0.000244140625f.xxx;
            }
            bool _5699 = any(bool3(_5683.x > _11564.x, _5683.y > _11564.y, _5683.z > _11564.z));
            bool3 _12572 = _5699.xxx;
            _12338 = float3(_12572.x ? _5675.x : _12339.x, _12572.y ? _5675.y : _12339.y, _12572.z ? _5675.z : _12339.z);
            _12231 = _5699;
        }
        else
        {
            _12338 = _12339;
            _12231 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9810;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9810);
        }
        float3 _12321;
        if (_5387 == 1u)
        {
            _12321 = lerp(_6875, _6883, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12322;
            if (_5387 == 2u)
            {
                _12322 = lerp(_6891, _6899, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12323;
                if (_5387 == 3u)
                {
                    _12323 = float(_12231).xxx;
                }
                else
                {
                    float3 _12324;
                    if (_5387 == 4u)
                    {
                        _12324 = float3(((_10440 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12325;
                        if (_5387 == 5u)
                        {
                            _12325 = float3(((_6170 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12326;
                            if (_5387 == 6u)
                            {
                                _12326 = float3(_11452.xy, _11452.z + _11452.w);
                            }
                            else
                            {
                                float3 _12327;
                                if (_5387 == 7u)
                                {
                                    _12327 = r_current_interpolation_source.Load(int3(_3722, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12328;
                                    if (_5387 == 8u)
                                    {
                                        _12328 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4125, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12329;
                                        if (_5391)
                                        {
                                            uint _9832_dummy_parameter;
                                            uint _9864_dummy_parameter;
                                            _12329 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4125 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9832_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9864_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12330;
                                            if (_5394)
                                            {
                                                _12330 = _6891;
                                            }
                                            else
                                            {
                                                float3 _12331;
                                                if (_5387 == 20u)
                                                {
                                                    _12331 = _6875;
                                                }
                                                else
                                                {
                                                    float3 _12332;
                                                    if (_5387 == 21u)
                                                    {
                                                        _12332 = _6883;
                                                    }
                                                    else
                                                    {
                                                        float3 _12333;
                                                        if (_5387 == 22u)
                                                        {
                                                            _12333 = _6899;
                                                        }
                                                        else
                                                        {
                                                            float3 _12334;
                                                            if (_5387 == 18u)
                                                            {
                                                                _12334 = _11978;
                                                            }
                                                            else
                                                            {
                                                                float3 _12335;
                                                                if (_5387 == 19u)
                                                                {
                                                                    _12335 = _11771;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12574 = (_5387 == 23u).xxx;
                                                                    _12335 = float3(_12574.x ? _11569.x : _12338.x, _12574.y ? _11569.y : _12338.y, _12574.z ? _11569.z : _12338.z);
                                                                }
                                                                _12334 = _12335;
                                                            }
                                                            _12333 = _12334;
                                                        }
                                                        _12332 = _12333;
                                                    }
                                                    _12331 = _12332;
                                                }
                                                _12330 = _12331;
                                            }
                                            _12329 = _12330;
                                        }
                                        _12328 = _12329;
                                    }
                                    _12327 = _12328;
                                }
                                _12326 = _12327;
                            }
                            _12325 = _12326;
                        }
                        _12324 = _12325;
                    }
                    _12323 = _12324;
                }
                _12322 = _12323;
            }
            _12321 = _12322;
        }
        float3 _12320;
        if ((_5387 >= 9u) && (_5387 <= 11u))
        {
            uint _5863 = 64u + uint((_10472.y * cbFI_MvDepthLaneSize.x) + _10472.x);
            uint _5867 = rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) & 15u;
            float3 _12351;
            if (_5387 == 10u)
            {
                float3 _12319;
                if ((rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) & 32u) != 0u)
                {
                    _12319 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12318;
                    if ((rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) & 16u) != 0u)
                    {
                        _12318 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5888 = ((rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) & 64u) != 0u).xxx;
                        _12318 = float3(_5888.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5888.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5888.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12319 = _12318;
                }
                _12351 = _12319;
            }
            else
            {
                float3 _12352;
                if (_5387 == 11u)
                {
                    uint _5901 = (rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) >> 8u) & 15u;
                    uint _5904 = (rw_nfru_diagnostics.Load<uint>(_5863 * 4 + 0) >> 12u) & 15u;
                    float3 _12311;
                    if ((_5867 == 2u) || (_5867 == 3u))
                    {
                        _12311 = _3435[_5867];
                    }
                    else
                    {
                        bool _5916 = _5901 == 3u;
                        bool _5918 = _5904 == 3u;
                        float3 _12312;
                        if (_5916 && _5918)
                        {
                            _12312 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12313;
                            if (_5916)
                            {
                                _12313 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12314;
                                if (_5918)
                                {
                                    _12314 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12315;
                                    if ((_5901 == 4u) || (_5904 == 4u))
                                    {
                                        _12315 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12316;
                                        if ((_5901 == 1u) || (_5904 == 1u))
                                        {
                                            _12316 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12576 = (_5867 == 1u).xxx;
                                            _12316 = float3(_12576.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12576.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12576.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12315 = _12316;
                                    }
                                    _12314 = _12315;
                                }
                                _12313 = _12314;
                            }
                            _12312 = _12313;
                        }
                        _12311 = _12312;
                    }
                    _12352 = _12311;
                }
                else
                {
                    _12352 = _3435[min(_5867, 7u)];
                }
                _12351 = _12352;
            }
            _12320 = _12351;
        }
        else
        {
            _12320 = _12321;
        }
        float4 _12355;
        if ((_5387 >= 14u) && (_5387 <= 16u))
        {
            float2 _12353;
            if (_5387 == 14u)
            {
                uint _5974_dummy_parameter;
                uint _5980_dummy_parameter;
                _12353 = r_flow_tm1.Load(int3(clamp(int2(floor(_4125 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5974_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5980_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12354;
                if (_5387 == 16u)
                {
                    uint _9915 = r_warped_flow_qdata_tm1.Load(int3(_4141, 0)).x & 2147483647u;
                    uint _9947 = uint(max((int((_9915 >> 16u) & 15u) - 6), 0));
                    _12354 = ((float2(float((1 - (2 * int((_9915 >> 15u) & 1u))) * int(((_9915 >> uint(7)) & 127u) << _9947)), float((1 - (2 * int((_9915 >> 14u) & 1u))) * int((_9915 & 127u) << _9947))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12354 = _6170 * float2(cbFI_DisplaySize);
                }
                _12353 = _12354;
            }
            uint2 _6013 = uint2(clamp(round(_12353 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6015 = _6013.x;
            uint _6022 = _6013.y;
            _12355 = float4(float(_6015 & 255u), float((_6015 >> 8u) | ((_6022 & 15u) << 4u)), float(_6022 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12356;
            if (_5387 == 17u)
            {
                _12356 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4141, 0)).x != 0u), _4484, 0.0f, 1.0f);
            }
            else
            {
                _12356 = float4(_12320, 1.0f);
            }
            _12355 = _12356;
        }
        rw_output[_3722] = _12355.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6066 = ((uint(_3722.y) * uint(cbFI_DisplaySize.x)) + uint(_3722.x)) * 6u;
            uint _9993 = spvPackHalf2x16(clamp(_6874.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6066 * 4 + 0, (((_9993 & 32767u) >> 4u) | ((((_9993 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6874.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10028 = spvPackHalf2x16(clamp(_6882.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6066 + 1u) * 4 + 0, (((_10028 & 32767u) >> 4u) | ((((_10028 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6882.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10063 = spvPackHalf2x16(clamp(_6890.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6066 + 2u) * 4 + 0, (((_10063 & 32767u) >> 4u) | ((((_10063 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6890.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10098 = spvPackHalf2x16(clamp(_6898.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6066 + 3u) * 4 + 0, (((_10098 & 32767u) >> 4u) | ((((_10098 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6898.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10125 = r_current_interpolation_source.Load(int3(_3722, 0));
            uint _10139 = spvPackHalf2x16(clamp(_10125.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6066 + 4u) * 4 + 0, (((_10139 & 32767u) >> 4u) | ((((_10139 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10125.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12389;
            if (_12231 || (_5387 != 0u))
            {
                _12389 = 4294967295u;
            }
            else
            {
                uint _10174 = spvPackHalf2x16(clamp(_12355.xy, 0.0f.xx, 65000.0f.xx));
                _12389 = (((_10174 & 32767u) >> 4u) | ((((_10174 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12355.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6066 + 5u) * 4 + 0, _12389);
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
